resource "aws_ssm_parameter" "db_user" {
  name    = "/${local.name}/db/user"
  type    = "SecureString"
  value   = module.aurora_postgresql.cluster_master_username
  tags    = local.tags
}

resource "aws_ssm_parameter" "db_password" {
  name    = "/${local.name}/db/password"
  type    = "SecureString"
  value   = module.aurora_postgresql.cluster_master_password
  tags    = local.tags
}

resource "aws_ssm_parameter" "db_host" {
  name    = "/${local.name}/db/host"
  type    = "String"
  value   = module.aurora_postgresql.cluster_endpoint
  tags    = local.tags
}

resource "aws_ssm_parameter" "db_port" {
  name    = "/${local.name}/db/port"
  type    = "String"
  value   = module.aurora_postgresql.cluster_port
  tags    = local.tags
}

resource "aws_ssm_parameter" "index_endpoint" {
  name    = "/${local.name}/index/endpoint"
  type    = "String"
  value   = "https://${aws_elasticsearch_domain.elasticsearch.endpoint}"
  tags    = local.tags
}

resource "aws_ssm_parameter" "index_kibana_endpoint" {
  name    = "/${local.name}/index/kibana_endpoint"
  type    = "String"
  value   = "https://${aws_elasticsearch_domain.elasticsearch.kibana_endpoint}"
  tags    = local.tags
}

resource "aws_ssm_parameter" "ldap_host" {
  name    = "/${local.name}/ldap/host"
  type    = "String"
  value   = join(".", [aws_service_discovery_service.ldap.name, aws_service_discovery_private_dns_namespace.internal.name])
  tags    = local.tags
}

resource "aws_ssm_parameter" "ldap_base" {
  name    = "/${local.name}/ldap/base"
  type    = "String"
  value   = "DC=library,DC=northwestern,DC=edu"
  tags    = local.tags
}

resource "aws_ssm_parameter" "ldap_port" {
  name    = "/${local.name}/ldap/port"
  type    = "String"
  value   = "389"
  tags    = local.tags
}

resource "aws_ssm_parameter" "ldap_user_dn" {
  name    = "/${local.name}/ldap/user_dn"
  type    = "SecureString"
  value   = "cn=Administrator,cn=Users,dc=library,dc=northwestern,dc=edu"
  tags    = local.tags
}

resource "aws_ssm_parameter" "ldap_password" {
  name    = "/${local.name}/ldap/password"
  type    = "SecureString"
  value   = "d0ck3rAdm1n!"
  tags    = local.tags
}

resource "aws_ssm_parameter" "ldap_ssl" {
  name    = "/${local.name}/ldap/ssl"
  type    = "String"
  value   = "false"
  tags    = local.tags
}
