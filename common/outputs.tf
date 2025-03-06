resource "random_password" "backup_key" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "output_parameter" {
  name = "${local.project}/terraform/common"
}

resource "aws_secretsmanager_secret_version" "output_parameter" {
  secret_id = aws_secretsmanager_secret.output_parameter.id
  secret_string = jsonencode({
    backup_key                   = random_password.backup_key.result
    elasticsearch_snapshot_role  = aws_iam_role.search_snapshot_bucket_access.arn
    fixity_function_arn          = module.execute_fixity_function.lambda_function_arn
    ide_uptime_alert_topic       = aws_sns_topic.ide_uptime_alert.arn
    iiif_distribution_id         = aws_cloudfront_distribution.iiif_server.id
    shared_bucket_arn            = aws_s3_bucket.dev_environment_shared_bucket.arn
    transcode_role               = aws_iam_role.transcode_role.arn
    vpc_id                       = module.vpc.vpc_id

    subnets = {
      public  = module.vpc.public_subnets
      private = module.vpc.private_subnets
    }
  })
}

output "github_actions_secrets" {
  value = {
    ACME_DATA_STORE   = "s3://${var.acme_cert_state_store.bucket}/${var.acme_cert_state_store.key}",
    AWS_ROLE_ARN      = aws_iam_role.acme_cert_github_role.arn,
    CERT_DOMAIN       = var.hosted_zone_name,
    SECRET_PATH       = "${local.project}/config/wildcard_ssl"
  }
}

output "search_snapshot_configuration" {
  value = {
    create_url    = "https://${aws_opensearch_domain.search_index.endpoint}/_snapshot/${local.project}-index-snapshots"
    create_doc    = jsonencode({
      type     = "s3"
      settings = {
        bucket    = aws_s3_bucket.search_snapshot_bucket.id
        region    = data.aws_region.current.name
        role_arn  = aws_iam_role.search_snapshot_bucket_access.arn
      }
    })
  }
}
