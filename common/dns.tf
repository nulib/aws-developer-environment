resource "aws_route53_zone" "hosted_zone" {
  name = var.hosted_zone_name
}

resource "aws_service_discovery_private_dns_namespace" "internal" {
  name        = "internal.${var.hosted_zone_name}"
  description = "Service Discovery for ${local.name}"
  vpc         = module.vpc.vpc_id
}

resource "aws_acm_certificate" "wildcard_cert" {
  domain_name         = "*.${aws_route53_zone.hosted_zone.name}"
  validation_method   = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "wildcart_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.wildcard_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.hosted_zone.zone_id
  type    = each.value.type
  name    = each.value.name
  records = [each.value.record]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "wildcard_cert_validation" {
  certificate_arn         = aws_acm_certificate.wildcard_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.wildcart_cert_validation: record.fqdn]
}

data "aws_iam_policy_document" "dns_update" {
  statement {
    effect    = "Allow"
    actions   = [
      "route53:ChangeResourceRecordSets", 
      "route53:ListResourceRecordSets"
    ]
    resources = [aws_route53_zone.hosted_zone.arn]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "allow_dns_update" {
  name = "${local.name}-dns-update"
  policy = data.aws_iam_policy_document.dns_update.json
}

module "ide_dns_updater" {
  source = "terraform-aws-modules/lambda/aws"

  function_name   = "${local.name}-ide-dns-updater"
  description     = "Updates DNS entries for developer IDE instances on startup"
  handler         = "index.handler"
  memory_size     = 128
  runtime         = "nodejs14.x"
  timeout         = 10
  
  environment_variables = {
    "hosted_zone_id"   = aws_route53_zone.hosted_zone.id
    "hosted_zone_name" = aws_route53_zone.hosted_zone.name
  }

  source_path = [
    {
      path     = "${path.module}/lambdas/dns_update_function"
      commands = ["npm install --only prod --no-bin-links --no-fund", ":zip"]
    }
  ]
}

resource "aws_iam_role_policy_attachment" "ide_dns_updater" {
  role          = module.ide_dns_updater.lambda_function_name
  policy_arn    = aws_iam_policy.allow_dns_update.arn
}

resource "aws_cloudwatch_event_rule" "ide_dns_update" {
  name        = "${local.name}-ide-dns-update"
  description = "Register/deregister developer IDE DNS records"

  event_pattern = jsonencode({
    source = ["aws.ec2"]
    "detail-type" = ["EC2 Instance State-change Notification"]
    detail = {
      state = ["running", "stopping", "stopped"]
    }
  })
}

resource "aws_cloudwatch_event_target" "ide_dns_update" {
  rule        = aws_cloudwatch_event_rule.ide_dns_update.name
  target_id   = "UpdateDNS"
  arn         = module.ide_dns_updater.lambda_function_arn
}

resource "aws_lambda_permission" "ide_dns_update" {
  statement_id    = "AllowDNSUpdateFromEventbridge"
  action          = "lambda:InvokeFunction"
  function_name   = module.ide_dns_updater.lambda_function_name
  principal       = "events.amazonaws.com"
  source_arn      = aws_cloudwatch_event_rule.ide_dns_update.arn
}