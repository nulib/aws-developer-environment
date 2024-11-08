locals {
  computed_secrets = {
    db = {
      host     = module.aurora_postgresql.cluster_endpoint
      port     = module.aurora_postgresql.cluster_port
      user     = module.aurora_postgresql.cluster_master_username
      password = module.aurora_postgresql.cluster_master_password
    }

    pipeline = {
      for key in keys(local.pipeline) :
      key => module.pipeline_lambda[key].lambda_function_qualified_arn
    }

    transcode = {
      role_arn = aws_iam_role.transcode_role.arn
    }
  }

  config_secrets = merge(
    var.config_secrets,
    local.computed_secrets
  )

  ssl_certificate = {
    certificate = fileexists(var.ssl_certificate_file) ? file(var.ssl_certificate_file) : ""
    key         = fileexists(var.ssl_key_file) ? file(var.ssl_key_file) : ""
  }
}

resource "aws_secretsmanager_secret" "config_secrets" {
  name        = "${local.project}/config/meadow"
  description = "Meadow configuration secrets"
}

resource "aws_secretsmanager_secret_version" "config_secrets" {
  secret_id     = aws_secretsmanager_secret.config_secrets.id
  secret_string = jsonencode(local.config_secrets)
}
