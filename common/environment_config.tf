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
