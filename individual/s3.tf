locals {
  buckets                 = ["ingest", "uploads", "preservation", "preservation-checks", "pyramids", "streaming" ]
  env_buckets             = [for entry in setproduct(local.envs, local.buckets): join("-", entry)]
  notification_buckets    = [for entry in setproduct(local.envs, ["ingest", "uploads"]): join("-", entry)]
}

resource "aws_s3_bucket" "meadow_buckets" {
  for_each = toset(local.env_buckets)
  bucket   = "${local.prefix}-${each.key}"
  tags     = local.tags
}

resource "aws_s3_bucket_cors_configuration" "meadow_uploads" {
  for_each    = toset(local.envs)
  bucket      = aws_s3_bucket.meadow_buckets[join("-", [each.key, "uploads"])].id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_cors_configuration" "meadow_streaming" {
  for_each    = toset(local.envs)
  bucket      = aws_s3_bucket.meadow_buckets[join("-", [each.key, "streaming"])].id

  cors_rule {
    allowed_headers = ["Authorization", "Access-Control-Allow-Origin", "Range", "*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["Access-Control-Allow-Origin", "Access-Control-Allow-Headers"]
    max_age_seconds = 3000
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "meadow_streaming" {
  for_each    = toset(local.envs)
  bucket      = aws_s3_bucket.meadow_buckets[join("-", [each.key, "streaming"])].id

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

resource "aws_iam_policy_attachment" "fixity_bucket_access" {
  name          = "${local.prefix}-fixity-bucket-access"
  roles         = [data.terraform_remote_state.common.outputs.fixity_function.role_name]
  policy_arn    = aws_iam_policy.owner_full_access.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  depends_on  = [aws_lambda_permission.allow_invoke_from_bucket]

  for_each    = toset(local.notification_buckets)
  bucket      = aws_s3_bucket.meadow_buckets[each.key].id
  lambda_function {
    lambda_function_arn = data.terraform_remote_state.common.outputs.fixity_function.function_arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_lambda_permission" "allow_invoke_from_bucket" {
  for_each        = toset(local.notification_buckets)
  statement_id    = "AllowExecutionFrom${replace(title(each.key), "-", "")}Bucket"
  action          = "lambda:InvokeFunction"
  function_name   = data.terraform_remote_state.common.outputs.fixity_function.function_name
  principal       = "s3.amazonaws.com"
  source_arn      = aws_s3_bucket.meadow_buckets[each.key].arn
}
