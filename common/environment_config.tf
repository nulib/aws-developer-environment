locals {
  computed_secrets = {
    db = {
      host     = module.aurora_postgresql.cluster_endpoint
      port     = module.aurora_postgresql.cluster_port
      user     = module.aurora_postgresql.cluster_master_username
      password = module.aurora_postgresql.cluster_master_password
    }

    dc_api = {
      v2 = {
        base_url         = var.dc_api_url
        api_token_secret = var.dc_api_secret
        api_token_ttl    = var.dc_api_ttl
      }
    }

    iiif = {
      distribution_id = data.aws_cloudfront_distribution.iiif_server.id
    }

    index = {
      index_endpoint       = "https://${aws_opensearch_domain.search_index.endpoint}"
      kibana_endpoint      = "https://${aws_opensearch_domain.search_index.dashboard_endpoint}"
      embedding_model_id   = lookup(local.deploy_model_body, "model_id", "DEPLOY ERROR")
      embedding_dimensions = var.embedding_dimensions
    }

    search = {
      cluster_endpoint     = "https://${aws_opensearch_domain.search_index.endpoint}"
      dashboard_endpoint   = "https://${aws_opensearch_domain.search_index.dashboard_endpoint}"
      embedding_model_id   = lookup(local.deploy_model_body, "model_id", "DEPLOY ERROR")
      embedding_dimensions = var.embedding_dimensions
    }

    ldap = merge(var.ldap_config, {
      host = join(".", [aws_service_discovery_service.ldap.name, aws_service_discovery_private_dns_namespace.internal.name])
    })

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
