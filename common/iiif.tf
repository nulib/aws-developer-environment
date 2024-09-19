locals {
  iiif_server_hostname = "iiif.${aws_route53_zone.hosted_zone.name}"
}

module "resolver_lambda" {
  source    = "terraform-aws-modules/lambda/aws"
  version   = "~> 7.0"
  
  function_name   = "${local.project}-iiif-resolver"
  description     = "viewer-request function for resolving IIIF requests"
  handler         = "index.handler"
  memory_size     = 128
  runtime         = "nodejs16.x"
  timeout         = 3
  role_path       = local.iam_path
  lambda_at_edge  = true

  source_path = [
    {
      path     = "${path.module}/lambdas/iiif_resolver"
      commands = [":zip"]
    }
  ]
}

resource "aws_lambda_permission" "allow_cloudfront" {
  statement_id  = "AllowExecutionFromCloudFront"
  action        = "lambda:InvokeFunction"
  function_name = module.resolver_lambda.lambda_function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.iiif_server.arn
}

locals {
  serverless_iiif_app_id        = "arn:aws:serverlessrepo:us-east-1:625046682746:applications/serverless-iiif"
  serverless_iiif_app_version   = "5.0.6"
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "serverless_iiif" {
  name                      = "${local.project}-iiif-server"
  application_id            = local.serverless_iiif_app_id
  semantic_version          = local.serverless_iiif_app_version
  capabilities              = ["CAPABILITY_IAM"]
  parameters = {
    Preflight               = true
    ForceHost               = local.iiif_server_hostname
    IiifLambdaMemory        = 2048
    SharpLayer              = "INTERNAL"
    SourceBucket            = "${local.project}-shared-pyramids"
  }
}

resource "aws_cloudfront_response_headers_policy" "iiif_server" {
  name = "${local.project}-allow-cors-response-headers"
  comment = "Allows IIIF CORS response headers"
  cors_config {
    access_control_allow_credentials = false
    access_control_allow_headers {
      items = ["*"]
    }
    access_control_allow_methods {
      items = ["GET", "OPTIONS"]
    }
    access_control_allow_origins {
      items = ["*"]
    }
    access_control_expose_headers {
      items = [
        "cache-control",
        "content-language",
        "content-length",
        "content-type",
        "date",
        "expires",
        "last-modified",
        "pragma"
      ]
    }
    access_control_max_age_sec = 3600
    origin_override = false
  }
}

resource "aws_cloudfront_distribution" "iiif_server" {
  enabled       = true
  price_class   = "PriceClass_100"
  aliases       = [local.iiif_server_hostname]

  origin {
    domain_name = aws_serverlessapplicationrepository_cloudformation_stack.serverless_iiif.outputs.FunctionDomain
    origin_id   = "iiif-lambda"
    custom_origin_config {
      origin_ssl_protocols = ["SSLv3", "TLSv1", "TLSv1.1", "TLSv1.2"]
      http_port = 80
      https_port = 443
      origin_protocol_policy = "https-only"
    }
  }

  viewer_certificate {
    acm_certificate_arn               = aws_acm_certificate.wildcard_cert.arn
    cloudfront_default_certificate    = false
    minimum_protocol_version          = "TLSv1"
    ssl_support_method                = "sni-only"
  }

  default_cache_behavior {
    target_origin_id              = "iiif-lambda"
    viewer_protocol_policy        = "https-only"
    allowed_methods               = ["GET", "HEAD", "OPTIONS"]
    cached_methods                = ["GET", "HEAD"]
    cache_policy_id               = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    response_headers_policy_id    = aws_cloudfront_response_headers_policy.iiif_server.id

    lambda_function_association {
      event_type    = "viewer-request"
      lambda_arn    = module.resolver_lambda.lambda_function_qualified_arn
      include_body  = false
    }

    lambda_function_association {
      event_type    = "viewer-response"
      lambda_arn    = module.resolver_lambda.lambda_function_qualified_arn
      include_body  = false
    }
  }

  restrictions {
    geo_restriction {
      locations           = ["US"]
      restriction_type    = "whitelist"
    }
  }
}

resource "aws_route53_record" "serverless_iiif" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = local.iiif_server_hostname
  type    = "A"

  alias {
    name                      = aws_cloudfront_distribution.iiif_server.domain_name
    zone_id                   = aws_cloudfront_distribution.iiif_server.hosted_zone_id
    evaluate_target_health    = true
  }
}

