locals {
  secrets = {
    db = {
      host        = module.aurora_postgresql.cluster_endpoint
      port        = module.aurora_postgresql.cluster_port
      username    = module.aurora_postgresql.cluster_master_username
      password    = module.aurora_postgresql.cluster_master_password
    }

    index = {
      endpoint    = "https://${aws_opensearch_domain.search_index.endpoint}"
      dashboard   = "https://${aws_opensearch_domain.search_index.dashboard_endpoint}"
      models      = { default = lookup(local.deploy_model_body, "model_id", "DEPLOY ERROR") }
    }

    inference = {
      endpoints = { 
        default = {    
          name        = var.embedding_model_name
          endpoint    = "https://bedrock-runtime.${data.aws_region.current.name}.amazonaws.com/model/${var.embedding_model_name}/invoke"
        }
      }
    }

    ldap = merge(var.ldap_config, {
      host = join(".", [aws_service_discovery_service.ldap.name, aws_service_discovery_private_dns_namespace.internal.name])
    })

    wildcard_ssl = {
      certificate = fileexists(var.ssl_certificate_file) ? file(var.ssl_certificate_file) : ""
      key         = fileexists(var.ssl_key_file) ? file(var.ssl_key_file) : ""
    }
  }
}

resource "aws_secretsmanager_secret" "infrastructure" {
  for_each    = local.secrets
  name        = "${local.project}/infrastructure/${each.key}"
  description = "${each.key} secrets for ${local.project}"
}

resource "aws_secretsmanager_secret_version" "infrastructure" {
  for_each      = local.secrets
  secret_id     = aws_secretsmanager_secret.infrastructure[each.key].id
  secret_string = jsonencode(each.value)
}

resource "aws_secretsmanager_secret" "ssl_certificate" {
  name        = "${local.project}/config/wildcard_ssl"
  description = "Wildcard SSL certificate and private key"
}

resource "aws_secretsmanager_secret_version" "ssl_certificate" {
  secret_id     = aws_secretsmanager_secret.ssl_certificate.id
  secret_string = jsonencode(local.ssl_certificate)

  lifecycle {
    ignore_changes = all
  }
}
