locals {
  iiif_server_hostname = "iiif.${aws_route53_zone.hosted_zone.name}"
}

resource "aws_cloudfront_function" "resolver_function" {
  name = "${local.project}-iiif-resolver"
  runtime = "cloudfront-js-2.0"
  comment = "Function to set the correct S3 location for dev environment IIIF requests"
  publish = true
  code = file("${path.module}/lambdas/iiif_resolver/index.js")
}

locals {
  serverless_iiif_app_id        = "arn:aws:serverlessrepo:us-east-1:${data.aws_caller_identity.current_user.id}:applications/serverless-iiif"
  serverless_iiif_app_version   = "5.1.4"
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

resource "aws_cloudfront_origin_request_policy" "iiif_server" {
  name = "${local.project}-allow-preflight-headers"
  comment = "Allows IIIF preflight headers"
  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["origin", "x-preflight-location", "x-preflight-dimensions"]
    }
  }

  query_strings_config {
    query_string_behavior = "none"
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
    origin_request_policy_id      = aws_cloudfront_origin_request_policy.iiif_server.id
    response_headers_policy_id    = aws_cloudfront_response_headers_policy.iiif_server.id

    function_association {
      event_type    = "viewer-request"
      function_arn  = aws_cloudfront_function.resolver_function.arn
    }

    function_association {
      event_type    = "viewer-response"
      function_arn  = aws_cloudfront_function.resolver_function.arn
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

