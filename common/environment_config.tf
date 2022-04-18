resource "aws_ssm_parameter" "db_user" {
  name    = "/${local.name}/db/user"
  type    = "SecureString"
  value   = module.aurora_postgresql.cluster_master_username
}

resource "aws_ssm_parameter" "db_password" {
  name    = "/${local.name}/db/password"
  type    = "SecureString"
  value   = module.aurora_postgresql.cluster_master_password
}

resource "aws_ssm_parameter" "db_host" {
  name    = "/${local.name}/db/host"
  type    = "String"
  value   = module.aurora_postgresql.cluster_endpoint
}

resource "aws_ssm_parameter" "index_endpoint" {
  name    = "/${local.name}/index/endpoint"
  type    = "String"
  value   = aws_elasticsearch_domain.elasticsearch.endpoint
}