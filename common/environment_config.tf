resource "aws_ssm_parameter" "db_user" {
  name    = "/${local.name}/config/db/user"
  type    = "SecureString"
  value   = module.aurora_postgresql.cluster_master_username
}

resource "aws_ssm_parameter" "db_password" {
  name    = "/${local.name}/config/db/password"
  type    = "SecureString"
  value   = module.aurora_postgresql.cluster_master_password
}

resource "aws_ssm_parameter" "db_host" {
  name    = "/${local.name}/config/db/host"
  type    = "String"
  value   = module.aurora_postgresql.cluster_endpoint
}

resource "aws_ssm_parameter" "db_port" {
  name    = "/${local.name}/config/db/port"
  type    = "String"
  value   = module.aurora_postgresql.cluster_port
}

resource "aws_ssm_parameter" "index_endpoint" {
  name    = "/${local.name}/config/index/endpoint"
  type    = "String"
  value   = "https://${aws_elasticsearch_domain.elasticsearch.endpoint}"
}

resource "aws_ssm_parameter" "index_kibana_endpoint" {
  name    = "/${local.name}/config/index/kibana_endpoint"
  type    = "String"
  value   = "https://${aws_elasticsearch_domain.elasticsearch.kibana_endpoint}"
}

resource "aws_ssm_parameter" "ldap_host" {
  name    = "/${local.name}/config/ldap/host"
  type    = "String"
  value   = join(".", [aws_service_discovery_service.ldap.name, aws_service_discovery_private_dns_namespace.internal.name])
}

resource "aws_ssm_parameter" "ldap_base" {
  name    = "/${local.name}/config/ldap/base"
  type    = "String"
  value   = "DC=library,DC=northwestern,DC=edu"
}

resource "aws_ssm_parameter" "ldap_port" {
  name    = "/${local.name}/config/ldap/port"
  type    = "String"
  value   = "389"
}

resource "aws_ssm_parameter" "ldap_user_dn" {
  name    = "/${local.name}/config/ldap/user_dn"
  type    = "SecureString"
  value   = "cn=Administrator,cn=Users,dc=library,dc=northwestern,dc=edu"
}

resource "aws_ssm_parameter" "ldap_password" {
  name    = "/${local.name}/config/ldap/password"
  type    = "SecureString"
  value   = "d0ck3rAdm1n!"
}

resource "aws_ssm_parameter" "ldap_ssl" {
  name    = "/${local.name}/config/ldap/ssl"
  type    = "String"
  value   = "false"
}
