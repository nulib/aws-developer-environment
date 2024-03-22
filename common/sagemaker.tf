locals {
  model_container_spec = {
    framework         = "huggingface"
    base_framework    = "pytorch"
    image_scope       = "inference"
    framework_version = "2.1.0"
    image_version     = "4.37.0"
    python_version    = "py310"
    processor         = "cpu"
    image_os          = "ubuntu22.04"
  }

  model_id         = element(split("/", var.model_repository), length(split("/", var.model_repository))-1)
  model_repository = join("-", [local.model_container_spec.framework, local.model_container_spec.base_framework, local.model_container_spec.image_scope])
  model_image_tag  = "${local.model_container_spec.framework_version}-transformers${local.model_container_spec.image_version}-${local.model_container_spec.processor}-${local.model_container_spec.python_version}-${local.model_container_spec.image_os}"

  embedding_invocation_url = "https://runtime.sagemaker.${data.aws_region.current.name}.amazonaws.com/endpoints/${aws_sagemaker_endpoint.serverless_inference.name}/invocations"
}

resource "aws_s3_bucket" "sagemaker_model_bucket" {
  bucket = "${local.project}-model-artifacts"
}

resource "terraform_data" "inference_model_artifact" {
  triggers_replace = [
    var.model_repository,
    file("${path.module}/model/inference.py")
  ]

  input = "${path.module}/model/.working/${local.model_id}.tar.gz"

  provisioner "local-exec" {
    command     = "./build_model.sh"
    working_dir = "${path.module}/model"

    environment = {
      model_id   = local.model_id
      repository = var.model_repository
    }
  }
}

resource "aws_s3_object" "inference_model_artifact" {
  bucket            = aws_s3_bucket.sagemaker_model_bucket.bucket
  key               = "custom_inference/${local.model_id}/${local.model_id}.tar.gz"
  source            = terraform_data.inference_model_artifact.output
  content_type      = "application/gzip"
}

data "aws_sagemaker_prebuilt_ecr_image" "inference_container" {
  repository_name = local.model_repository
  image_tag       = local.model_image_tag
}

data "aws_iam_policy_document" "embedding_model_execution_assume_role" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]

    principals {
      type          = "Service"
      identifiers   = ["sagemaker.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "embedding_model_execution_role" {
  statement {
    effect    = "Allow"
    actions   = [
      "cloudwatch:PutMetricData",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.sagemaker_model_bucket.bucket}/${aws_s3_object.inference_model_artifact.key}"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "embedding_model_execution_role" {
  name    = "${local.project}-sagemaker-model-execution-role"
  policy  = data.aws_iam_policy_document.embedding_model_execution_role.json
}

resource "aws_iam_role" "embedding_model_execution_role" {
  name                  = "${local.project}-sagemaker-model-execution-role"
  assume_role_policy    = data.aws_iam_policy_document.embedding_model_execution_assume_role.json
}

resource "aws_iam_role_policy_attachment" "embedding_model_execution_role" {
  role          = aws_iam_role.embedding_model_execution_role.id
  policy_arn    = aws_iam_policy.embedding_model_execution_role.arn
}

resource "aws_sagemaker_model" "embedding_model" {
  name                  = "${local.project}-embedding-model"
  execution_role_arn    = aws_iam_role.embedding_model_execution_role.arn
  
  primary_container {
    image             = data.aws_sagemaker_prebuilt_ecr_image.inference_container.registry_path
    mode              = "SingleModel"
    model_data_url    = "s3://${aws_s3_object.inference_model_artifact.bucket}/${aws_s3_object.inference_model_artifact.key}"
  }
}

resource "aws_sagemaker_endpoint_configuration" "serverless_inference" {
  name = "${local.project}-embedding-model"
  production_variants {
    model_name    = aws_sagemaker_model.embedding_model.name
    variant_name  = "AllTraffic"

    serverless_config {
      memory_size_in_mb         = var.sagemaker_inference_memory
      max_concurrency           = var.sagemaker_inference_max_concurrency
      provisioned_concurrency   = var.sagemaker_inference_provisioned_concurrency > 0 ? var.sagemaker_inference_provisioned_concurrency : null
    }
  }
}

resource "aws_sagemaker_endpoint" "serverless_inference" {
  name                    = "${local.project}-embedding"
  endpoint_config_name    = aws_sagemaker_endpoint_configuration.serverless_inference.name
}

data "aws_iam_policy_document" "db_sagemaker_access" {
  statement {
    effect = "Allow"
    actions = [
      "sagemaker:InvokeEndpoint",
      "sagemaker:InvokeEndpointAsync"
    ]
    resources = [aws_sagemaker_endpoint.serverless_inference.arn]
  }
}

resource "aws_iam_role" "db_sagemaker_access" {
  path    = local.iam_path
  name    = "${local.project}-db-sagemaker-access"
  assume_role_policy = data.aws_iam_policy_document.rds_assume_role.json
  inline_policy {
    name    = "${local.project}-db-sagemaker-access"
    policy  = data.aws_iam_policy_document.db_sagemaker_access.json
  }
}

resource "aws_rds_cluster_role_association" "example" {
  db_cluster_identifier = module.aurora_postgresql.cluster_id
  feature_name          = "SageMaker"
  role_arn              = aws_iam_role.db_sagemaker_access.arn
}
