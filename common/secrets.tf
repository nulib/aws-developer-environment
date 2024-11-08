locals {
  samvera_stack_host = join(".", [aws_service_discovery_service.samvera_stack.name, aws_service_discovery_private_dns_namespace.internal.name])

  secrets = merge({
    db = {
      host        = module.aurora_postgresql.cluster_endpoint
      port        = module.aurora_postgresql.cluster_port
      username    = module.aurora_postgresql.cluster_master_username
      password    = module.aurora_postgresql.cluster_master_password
    }

    fcrepo = {
      endpoint = "http://${local.samvera_stack_host}:8080/rest/"
    }

    index = {
      endpoint                = "https://${aws_opensearch_domain.search_index.endpoint}"
      dashboard               = "https://${aws_opensearch_domain.search_index.dashboard_endpoint}"
      embedding_model         = lookup(local.deploy_model_body, "model_id", "DEPLOY ERROR")
      embedding_dimensions    = var.embedding_dimensions
    }

    iiif = {
      base              = "https://${local.iiif_server_hostname}/"
      v2                = "https://${local.iiif_server_hostname}/iiif/2/"
      v3                = "https://${local.iiif_server_hostname}/iiif/3/"
      distribution_id   = aws_cloudfront_distribution.iiif_server.id
    }

    inference = {
      name        = var.embedding_model_name
      endpoint    = "https://bedrock-runtime.${data.aws_region.current.name}.amazonaws.com/model/${var.embedding_model_name}/invoke"
      dimensions  = var.embedding_dimensions
    }

    ldap = merge(var.ldap_config, {
      host = join(".", [aws_service_discovery_service.ldap.name, aws_service_discovery_private_dns_namespace.internal.name]),
      port = tonumber(var.ldap_config["port"])
    })

    solrcloud = {
      solr_url = "http://${local.samvera_stack_host}:8983/solr"
      zookeeper_servers = ["${local.samvera_stack_host}:9983"]
    }

    wildcard_ssl = {
      certificate = fileexists(var.ssl_certificate_file) ? file(var.ssl_certificate_file) : ""
      key         = fileexists(var.ssl_key_file) ? file(var.ssl_key_file) : ""
    }
  }, var.config_secrets)

  dcapi = {
    base_url         = var.dc_api_url
    api_token_secret = var.dc_api_secret
    api_token_ttl    = tonumber(var.dc_api_ttl)
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

resource "aws_secretsmanager_secret" "dcapi" {
  name        = "${local.project}/config/dcapi"
  description = "DC API Configuration"
}

resource "aws_secretsmanager_secret_version" "dcapi" {
  secret_id     = aws_secretsmanager_secret.dcapi.id
  secret_string = jsonencode(local.dcapi)
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
