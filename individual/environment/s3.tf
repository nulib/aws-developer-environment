locals {
  buckets                 = ["ingest", "uploads", "preservation", "preservation-checks", "pyramids", "streaming" ]
  notification_buckets    = ["ingest", "uploads"]
}

resource "aws_s3_bucket" "meadow_buckets" {
  for_each = toset(local.buckets)
  bucket   = "${local.prefix}-${each.key}"
  tags     = local.tags
}

resource "aws_s3_bucket_cors_configuration" "meadow_uploads" {
  bucket      = aws_s3_bucket.meadow_buckets["uploads"].id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_cors_configuration" "meadow_streaming" {
  bucket      = aws_s3_bucket.meadow_buckets["streaming"].id

  cors_rule {
    allowed_headers = ["Authorization", "Access-Control-Allow-Origin", "Range", "*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["Access-Control-Allow-Origin", "Access-Control-Allow-Headers"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "meadow_streaming" {
  bucket      = aws_s3_bucket.meadow_buckets["streaming"].id

  rule {
    id = "intelligent_tiering"

    status = "Enabled"

    filter {
      prefix = ""
    }

    transition {
      days          = 0
      storage_class = "INTELLIGENT_TIERING"
    }
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  for_each    = toset(local.notification_buckets)
  bucket      = aws_s3_bucket.meadow_buckets[each.key].id
  lambda_function {
    lambda_function_arn = local.common_config.fixity_function_arn
    events              = ["s3:ObjectCreated:*"]
  }
}
