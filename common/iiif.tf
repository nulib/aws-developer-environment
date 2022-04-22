module "resolver_lambda" {
  source = "terraform-aws-modules/lambda/aws"

  function_name   = "${local.name}-iiif-resolver"
  description     = "viewer-request function for resolving IIIF requests"
  handler         = "index.handler"
  memory_size     = 128
  runtime         = "nodejs14.x"
  timeout         = 3
  lambda_at_edge  = true

  source_path = [
    {
      path     = "${path.module}/lambdas/iiif_resolver"
      commands = [":zip"]
    }
  ]
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "iiif_server" {
  depends_on = [aws_acm_certificate_validation.wildcard_cert_validation]

  name           = "${local.name}-iiif-server"
  application_id = "arn:aws:serverlessrepo:us-east-1:625046682746:applications/serverless-iiif"
  capabilities = [
    "CAPABILITY_IAM",
    "CAPABILITY_RESOURCE_POLICY",
  ]
  parameters = {
    CacheDomainName       = "iiif.${aws_route53_zone.hosted_zone.name}"
    CacheSSLCertificate   = aws_acm_certificate.wildcard_cert.arn
    SourceBucket          = "${local.name}-shared-pyramids"
    ViewerRequestARN      = module.resolver_lambda.lambda_function_qualified_arn
    ViewerRequestType     = "Lambda@Edge"
    ViewerResponseARN     = module.resolver_lambda.lambda_function_qualified_arn
    ViewerResponseType    = "Lambda@Edge"
  }
}

data "aws_cloudfront_distribution" "iiif_server" {
  id = aws_serverlessapplicationrepository_cloudformation_stack.iiif_server.outputs.DistributionId
}

resource "aws_route53_record" "serverless_iiif" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = "iiif.${aws_route53_zone.hosted_zone.name}"
  type    = "A"

  alias {
    name                      = data.aws_cloudfront_distribution.iiif_server.domain_name
    zone_id                   = data.aws_cloudfront_distribution.iiif_server.hosted_zone_id
    evaluate_target_health    = true
  }
}

