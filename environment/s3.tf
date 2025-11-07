locals {
  buckets                 = ["ingest", "uploads", "preservation", "preservation-checks", "pyramids", "streaming", "derivatives"]
  notification_buckets    = ["ingest", "uploads"]
  public_buckets          = ["pyramids", "streaming"]
}

resource "aws_s3_bucket" "meadow_buckets" {
  for_each = toset(local.buckets)
  bucket   = "${local.prefix}-${each.key}"
  
}

resource "aws_s3_bucket_public_access_block" "meadow_buckets" {
  for_each = toset(local.buckets)
  bucket   = aws_s3_bucket.meadow_buckets[each.key].id

  block_public_acls       = !contains(local.public_buckets, each.key)
  block_public_policy     = !contains(local.public_buckets, each.key)
  ignore_public_acls      = !contains(local.public_buckets, each.key)
  restrict_public_buckets = !contains(local.public_buckets, each.key)
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

resource "aws_s3_bucket_versioning" "meadow_preservation" {
  bucket      = aws_s3_bucket.meadow_buckets["preservation"].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "meadow_preservation" {
  bucket      = aws_s3_bucket.meadow_buckets["preservation"].id

  rule {
    id     = "retain-on-delete"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
    expiration {
      expired_object_delete_marker = true
    }
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
    lambda_function_arn = var.fixity_function_arn
    events              = ["s3:ObjectCreated:*"]
  }
}

data "aws_iam_policy_document" "public_bucket_read" {
  for_each = toset(local.public_buckets)

  statement {
    actions   = ["s3:GetBucketLocation", "s3:ListBucket"]
    effect    = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [aws_s3_bucket.meadow_buckets[each.key].arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    effect    = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = ["${aws_s3_bucket.meadow_buckets[each.key].arn}/*"]
  }  
}

resource "aws_s3_bucket_policy" "public_bucket_read" {
  for_each  = toset(local.public_buckets)
  bucket    = aws_s3_bucket.meadow_buckets[each.key].id
  policy    = data.aws_iam_policy_document.public_bucket_read[each.key].json
}

resource "aws_s3_bucket_cors_configuration" "pyramid_bucket_read" {
  bucket = aws_s3_bucket.meadow_buckets["pyramids"].id
  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }  
}