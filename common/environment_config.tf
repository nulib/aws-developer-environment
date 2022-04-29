resource "aws_secretsmanager_secret" "db_secrets" {
  name    = "${local.project}/db"
  description = "Database configuration secrets"
}

resource "aws_secretsmanager_secret" "index_secrets" {
  name    = "${local.project}/index"
  description = "OpenSearch index secrets"
}

resource "aws_secretsmanager_secret" "ldap_secrets" {
  name    = "${local.project}/ldap"
  description = "LDAP server secrets"
}

resource "aws_secretsmanager_secret" "pipeline_secrets" {
  name    = "${local.project}/pipeline"
  description = "Ingest pipeline secrets"
}

resource "aws_secretsmanager_secret" "config_secrets" {
  name    = "${local.project}/config"
  description = "Miscellaneous configuration secrets"
}

resource "aws_secretsmanager_secret" "ssl_certificate" {
  name = "${local.project}/ssl"
  description = "Wildcard SSL certificate and private key"
}

resource "aws_secretsmanager_secret_version" "db_secrets" {
  secret_id = aws_secretsmanager_secret.db_secrets.id
  secret_string = jsonencode({
    host        = module.aurora_postgresql.cluster_endpoint
    port        = module.aurora_postgresql.cluster_port
    user        = module.aurora_postgresql.cluster_master_username
    password    = module.aurora_postgresql.cluster_master_password
  })
}

resource "aws_secretsmanager_secret_version" "index_secrets" {
  secret_id = aws_secretsmanager_secret.index_secrets.id
  secret_string = jsonencode({
    index_endpoint    = "https://${aws_opensearch_domain.search_index.endpoint}"
    kibana_endpoint   = "https://${aws_opensearch_domain.search_index.kibana_endpoint}"
  })
}

resource "aws_secretsmanager_secret_version" "ldap_secrets" {
  secret_id = aws_secretsmanager_secret.ldap_secrets.id
  secret_string = jsonencode(merge(var.ldap_config, {
    host = join(".", [aws_service_discovery_service.ldap.name, aws_service_discovery_private_dns_namespace.internal.name])
  }))
}

resource "aws_secretsmanager_secret_version" "pipeline_secrets" {
  secret_id = aws_secretsmanager_secret.pipeline_secrets.id
  secret_string = jsonencode(
    {for key in keys(local.pipeline): key => module.pipeline_lambda[key].lambda_function_qualified_arn}
  )
}

resource "aws_secretsmanager_secret_version" "config_secrets" {
  secret_id = aws_secretsmanager_secret.config_secrets.id
  secret_string = jsonencode(var.config_secrets)
}

resource "aws_secretsmanager_secret_version" "ssl_certificate" {
  secret_id       = aws_secretsmanager_secret.ssl_certificate.id
  secret_string   = jsonencode({
    certificate = file(var.ssl_certificate_file)
    key         = file(var.ssl_key_file)
  })
}
