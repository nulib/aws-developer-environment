resource "aws_secretsmanager_secret" "user_secrets" {
  name    = "${local.project}/config/${local.prefix}"
  description = "User-specific configuration secrets"
}

resource "aws_secretsmanager_secret_version" "user_secrets" {
  secret_id = aws_secretsmanager_secret.user_secrets.id
  secret_string = jsonencode({
    iiif = {
      base_url        = "${local.common_config.iiif_base_url}${local.prefix}/"
      manifest_url    = "https://${aws_s3_bucket.meadow_buckets["pyramids"].bucket_domain_name}/public/"
    }

    streaming = {
      base_url = "https://${aws_s3_bucket.meadow_buckets["streaming"].bucket_domain_name}/"
    }
  })
}
