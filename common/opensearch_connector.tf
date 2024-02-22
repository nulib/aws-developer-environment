locals {
  connector_spec = {
    name        = "${local.project}-embedding"
    description = "Opensearch Connector for ${aws_sagemaker_endpoint.serverless_inference.name}"
    version     = 1
    protocol    = "aws_sigv4"

    credential = {
      roleArn = aws_iam_role.opensearch_connector.arn
    }

    parameters = {
      region       = data.aws_region.current.name
      service_name = "sagemaker"
    }

    actions = [
      {
        action_type = "predict"
        method      = "POST"

        headers = {
          "content-type" = "application/json"
        }

        url                   = local.embedding_invocation_url
        post_process_function = file("${path.module}/opensearch_connector/post-process.painless")
        request_body          = "{\"inputs\": $${parameters.input}}"
      }
    ]
  }
}

data "aws_iam_policy_document" "opensearch_connector_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["opensearchservice.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "opensearch_connector_role" {
  statement {
    effect = "Allow"
    actions = [
      "sagemaker:InvokeEndpoint",
      "sagemaker:InvokeEndpointAsync"
    ]
    resources = [aws_sagemaker_endpoint.serverless_inference.arn]
  }
}

resource "aws_iam_policy" "opensearch_connector" {
  name   = "${local.project}-opensearch-connector"
  policy = data.aws_iam_policy_document.opensearch_connector_role.json
}

resource "aws_iam_role" "opensearch_connector" {
  name               = "${local.project}-opensearch-connector"
  assume_role_policy = data.aws_iam_policy_document.opensearch_connector_assume_role.json
}

resource "aws_iam_role_policy_attachment" "opensearch_connector" {
  role       = aws_iam_role.opensearch_connector.id
  policy_arn = aws_iam_policy.opensearch_connector.arn
}

data "aws_iam_policy_document" "deploy_model_lambda" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.opensearch_connector.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["es:ESHttpGet", "es:ESHttpPost"]
    resources = ["${aws_opensearch_domain.search_index.arn}/*"]
  }
}

resource "aws_security_group" "lambda_outbound" {
  name        = "${local.project}-deploy-model-lambda"
  description = "Security group for lambda functions"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_security_group_rule" "lambda_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_outbound.id
}

module "deploy_model_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.2.1"

  function_name         = "${local.project}-deploy-opensearch-ml-model"
  description           = "Utility lambda to deploy a SageMaker model within Opensearch"
  handler               = "index.handler"
  runtime               = "nodejs18.x"
  source_path           = "${path.module}/deploy_model_lambda"
  timeout               = 30
  attach_policy_json    = true
  attach_network_policy = true
  policy_json           = data.aws_iam_policy_document.deploy_model_lambda.json
  vpc_subnet_ids        = module.vpc.private_subnets
  vpc_security_group_ids = [
    module.vpc.default_security_group_id,
    aws_security_group.lambda_outbound.id
  ]

  environment_variables = {
    OPENSEARCH_ENDPOINT = aws_opensearch_domain.search_index.endpoint
  }
}

resource "aws_lambda_invocation" "deploy_model" {
  function_name   = module.deploy_model_lambda.lambda_function_name
  lifecycle_scope = "CRUD"

  input = jsonencode({
    namespace      = local.project
    connector_spec = local.connector_spec
    model_name     = "huggingface/${var.model_repository}"
    model_version  = "1.0.0"
  })
}
