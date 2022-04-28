resource "aws_ssm_parameter" "db_user" {
  name    = "/${local.project}/config/db/user"
  type    = "SecureString"
  value   = module.aurora_postgresql.cluster_master_username
}

resource "aws_ssm_parameter" "db_password" {
  name    = "/${local.project}/config/db/password"
  type    = "SecureString"
  value   = module.aurora_postgresql.cluster_master_password
}

resource "aws_ssm_parameter" "db_host" {
  name    = "/${local.project}/config/db/host"
  type    = "String"
  value   = module.aurora_postgresql.cluster_endpoint
}

resource "aws_ssm_parameter" "db_port" {
  name    = "/${local.project}/config/db/port"
  type    = "String"
  value   = module.aurora_postgresql.cluster_port
}

resource "aws_ssm_parameter" "index_endpoint" {
  name    = "/${local.project}/config/index/endpoint"
  type    = "String"
  value   = "https://${aws_elasticsearch_domain.elasticsearch.endpoint}"
}

resource "aws_ssm_parameter" "index_kibana_endpoint" {
  name    = "/${local.project}/config/index/kibana_endpoint"
  type    = "String"
  value   = "https://${aws_elasticsearch_domain.elasticsearch.kibana_endpoint}"
}

resource "aws_ssm_parameter" "ldap_host" {
  name    = "/${local.project}/config/ldap/host"
  type    = "String"
  value   = join(".", [aws_service_discovery_service.ldap.name, aws_service_discovery_private_dns_namespace.internal.name])
}

resource "aws_ssm_parameter" "pipeline_lambda" {
  for_each    = local.pipeline
  name        = "/${local.project}/config/pipeline/${each.key}"
  type        = "String"
  value       = module.pipeline_lambda[each.key].lambda_function_qualified_arn
}

resource "aws_ssm_parameter" "config_secret" {
  for_each    = var.config_secrets
  name        = "/${local.project}/config/${each.key}"
  type        = "SecureString"
  value       = each.value
}

resource "aws_secretsmanager_secret" "ssl_certificate" {
  name = "${local.project}/ssl/certificate"
}

resource "aws_secretsmanager_secret_version" "ssl_certificate" {
  secret_id       = aws_secretsmanager_secret.ssl_certificate.id
  secret_string   = jsonencode(file(var.ssl_certificate_file))
}

resource "aws_secretsmanager_secret" "ssl_key" {
  name = "${local.project}/ssl/key"
}

resource "aws_secretsmanager_secret_version" "ssl_key" {
  secret_id       = aws_secretsmanager_secret.ssl_key.id
  secret_string   = jsonencode(file(var.ssl_key_file))
}
