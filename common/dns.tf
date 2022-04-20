resource "aws_route53_zone" "hosted_zone" {
  name = var.hosted_zone_name
  tags = local.tags
}

resource "aws_service_discovery_private_dns_namespace" "internal" {
  name        = "internal.${var.hosted_zone_name}"
  description = "Service Discovery for ${local.name}"
  vpc         = module.vpc.vpc_id
  tags        = local.tags
}

