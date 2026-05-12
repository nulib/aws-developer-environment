terraform {
  backend "s3" {
    key       = "tailnet.tfstate"
    region    = "us-east-1"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = local.tags
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  default_tags {
    tags = local.tags
  }
}

provider "azuread" {}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "domain" {
  name         = "${var.domain}."
  private_zone = false
  tags = {
    visibility = "public"
  }
}

data "aws_route53_zone" "private_domain" {
  name         = "${var.domain}."
  private_zone = false
  tags = {
    visibility = "tailnet"
  }
}

data "aws_acm_certificate" "existing_wildcard" {
  provider   = aws.us_east_1
  domain     = "*.${var.domain}"
  statuses   = ["ISSUED"]
  types      = ["AMAZON_ISSUED"]
  most_recent = true
}

locals {
  project               = "dev-environment"
  cognito_auth_domain   = "auth.${var.domain}"

  tags    = {
    Project = local.project
    Owner   = "shared"  
  }
}

# ============================================================
# Azure — app registration, Cognito URI
# ============================================================

data "azuread_client_config" "current" {}

resource "azuread_application" "tailscale_cognito" {
  display_name = "Tailscale Cognito"
  owners       = [data.azuread_client_config.current.object_id]

  web {
    redirect_uris = [
      "https://${local.cognito_auth_domain}/oauth2/idpresponse",
    ]
  }
}

resource "azuread_application_password" "tailscale_cognito" {
  application_id = azuread_application.tailscale_cognito.id
  display_name   = "Cognito federation secret"
}

# ============================================================
# IAM role for Lambda functions
# ============================================================

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "tailnet-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ============================================================
# Pre Token Generation Lambda
# ============================================================

data "archive_file" "pre_token_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/pre_token"
  output_path = "${path.module}/.build/pre_token.zip"
}

resource "aws_lambda_function" "pre_token" {
  function_name    = "tailnet-pre-token-generation"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs24.x"
  filename         = data.archive_file.pre_token_zip.output_path
  source_code_hash = data.archive_file.pre_token_zip.output_base64sha256
  environment {
    variables = {
      AUTH_DOMAIN = var.domain
    }
  }
}

resource "aws_lambda_permission" "cognito_pre_token" {
  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_token.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = "arn:aws:cognito-idp:${var.aws_region}:${data.aws_caller_identity.current.account_id}:userpool/*"
}

# ============================================================
# Cognito User Pool
# ============================================================

resource "aws_cognito_user_pool" "tailnet" {
  name = "tailnet-dev-library"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  lambda_config {
    pre_token_generation_config {
      lambda_arn     = aws_lambda_function.pre_token.arn
      lambda_version = "V2_0"
    }
  }

  depends_on = [aws_lambda_permission.cognito_pre_token]
}

resource "aws_cognito_user_pool_domain" "tailnet" {
  domain          = local.cognito_auth_domain
  certificate_arn = data.aws_acm_certificate.existing_wildcard.arn
  user_pool_id    = aws_cognito_user_pool.tailnet.id
}

# Alias record pointing auth.dev.rdc.library.northwestern.edu at the
# CloudFront distribution Cognito creates for the custom hosted UI domain
resource "aws_route53_record" "cognito_auth" {
  for_each = {
    "public"  = data.aws_route53_zone.domain
    "private" = data.aws_route53_zone.private_domain
  }
  zone_id = each.value.id
  name    = local.cognito_auth_domain
  type    = "A"

  alias {
    name                   = aws_cognito_user_pool_domain.tailnet.cloudfront_distribution
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront's fixed hosted zone ID
    evaluate_target_health = false
  }
}

resource "aws_cognito_identity_provider" "entra" {
  user_pool_id  = aws_cognito_user_pool.tailnet.id
  provider_name = "EntraID"
  provider_type = "OIDC"

  provider_details = {
    client_id                 = azuread_application.tailscale_cognito.client_id
    client_secret             = azuread_application_password.tailscale_cognito.value
    attributes_request_method = "GET"
    oidc_issuer               = "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"
    authorize_scopes          = "openid profile email"
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

resource "aws_cognito_user_pool_client" "tailscale" {
  name            = "tailscale"
  user_pool_id    = aws_cognito_user_pool.tailnet.id
  generate_secret = true

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "profile", "email"]

  callback_urls                   = var.tailscale_callback_urls
  supported_identity_providers    = ["EntraID"]
  depends_on                      = [aws_cognito_identity_provider.entra]
}

# ============================================================
# WebFinger Lambda
# ============================================================

data "archive_file" "webfinger_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/webfinger"
  output_path = "${path.module}/.build/webfinger.zip"
}

resource "aws_lambda_function" "webfinger" {
  function_name    = "tailnet-webfinger"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "index.handler"
  runtime          = "nodejs24.x"
  filename         = data.archive_file.webfinger_zip.output_path
  source_code_hash = data.archive_file.webfinger_zip.output_base64sha256

  environment {
    variables = {
      COGNITO_ISSUER_URL = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.tailnet.id}"
    }
  }
}

resource "aws_lambda_permission" "apigw_webfinger" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webfinger.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webfinger.execution_arn}/*/*"
}

# ============================================================
# API Gateway — WebFinger endpoint
# ============================================================

resource "aws_apigatewayv2_api" "webfinger" {
  name          = "tailnet-webfinger"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "webfinger" {
  api_id                 = aws_apigatewayv2_api.webfinger.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.webfinger.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webfinger" {
  api_id    = aws_apigatewayv2_api.webfinger.id
  route_key = "GET /.well-known/webfinger"
  target    = "integrations/${aws_apigatewayv2_integration.webfinger.id}"
}

resource "aws_apigatewayv2_stage" "webfinger" {
  api_id      = aws_apigatewayv2_api.webfinger.id
  name        = "$default"
  auto_deploy = true
}

# ============================================================
# ACM certificate + API Gateway custom domain
# ============================================================

resource "aws_apigatewayv2_domain_name" "webfinger" {
  domain_name = var.domain

  domain_name_configuration {
    certificate_arn = data.aws_acm_certificate.existing_wildcard.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "webfinger" {
  api_id      = aws_apigatewayv2_api.webfinger.id
  domain_name = aws_apigatewayv2_domain_name.webfinger.id
  stage       = aws_apigatewayv2_stage.webfinger.id
}

resource "aws_route53_record" "webfinger" {
  zone_id = data.aws_route53_zone.domain.id
  name    = var.domain
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.webfinger.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.webfinger.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
