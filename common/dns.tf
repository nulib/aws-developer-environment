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
