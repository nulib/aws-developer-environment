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

resource "aws_ssm_parameter" "ldap_base" {
  name    = "/${local.project}/config/ldap/base"
  type    = "String"
  value   = "DC=library,DC=northwestern,DC=edu"
}

resource "aws_ssm_parameter" "ldap_port" {
  name    = "/${local.project}/config/ldap/port"
  type    = "String"
  value   = "389"
}

resource "aws_ssm_parameter" "ldap_user_dn" {
  name    = "/${local.project}/config/ldap/user_dn"
  type    = "SecureString"
  value   = "cn=Administrator,cn=Users,dc=library,dc=northwestern,dc=edu"
}

resource "aws_ssm_parameter" "ldap_password" {
  name    = "/${local.project}/config/ldap/password"
  type    = "SecureString"
  value   = "d0ck3rAdm1n!"
}

resource "aws_ssm_parameter" "ldap_ssl" {
  name    = "/${local.project}/config/ldap/ssl"
  type    = "String"
  value   = "false"
}

resource "aws_ssm_parameter" "pipeline_lambda" {
  for_each    = local.pipeline
  name        = "/${local.project}/config/pipeline/${each.key}"
  type        = "String"
  value       = module.pipeline_lambda[each.key].lambda_function_qualified_arn
}

resource "aws_secretsmanager_secret" "developer_certificate" {
  name = "${local.project}/ssl/certificate"
}

resource "aws_secretsmanager_secret_version" "developer_certificate" {
  secret_id = aws_secretsmanager_secret.developer_certificate.id
  secret_string = jsonencode(var.developer_certificate)
}
resource "aws_secretsmanager_secret" "developer_key" {
  name = "${local.project}/ssl/key"
}

resource "aws_secretsmanager_secret_version" "developer_key" {
  secret_id = aws_secretsmanager_secret.developer_key.id
  secret_string = jsonencode(var.developer_key)
}
