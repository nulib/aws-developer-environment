locals {
  avr_environments = ["dev", "test"]
}

resource "aws_s3_bucket" "avr_masterfiles" {
  for_each    = toset(local.avr_environments)
  bucket      = "${local.project}-shared-${each.key}-avr-masterfiles"
}

resource "aws_s3_bucket_acl" "avr_masterfiles" {
  for_each    = toset(local.avr_environments)
  bucket      = aws_s3_bucket.avr_masterfiles[each.key].id
  acl         = "private"
}

resource "aws_s3_bucket_cors_configuration" "avr_masterfiles" {
  for_each    = toset(local.avr_environments)
  bucket      = aws_s3_bucket.avr_masterfiles[each.key].id
  cors_rule {
    allowed_origins = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]    
  }
}

resource "aws_s3_bucket" "avr_derivatives" {
  for_each    = toset(local.avr_environments)
  bucket      = "${local.project}-shared-${each.key}-avr-derivatives"
}

resource "aws_s3_bucket_policy" "avr_derivatives" {
  for_each    = toset(local.avr_environments)
  bucket      = aws_s3_bucket.avr_derivatives[each.key].id
  
  policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject"]
          Resource = [
            "${aws_s3_bucket.avr_derivatives[each.key].arn}",
            "${aws_s3_bucket.avr_derivatives[each.key].arn}/*"
          ]
          Principal = { 
            AWS = "*"
          }
        }
      ]
  })
}

resource "aws_s3_bucket_acl" "avr_derivatives" {
  for_each    = toset(local.avr_environments)
  bucket      = aws_s3_bucket.avr_derivatives[each.key].id
  acl         = "public-read"
}

resource "aws_s3_bucket_cors_configuration" "avr_derivatives" {
  for_each    = toset(local.avr_environments)
  bucket      = aws_s3_bucket.avr_derivatives[each.key].id

 cors_rule {
    allowed_origins = ["*.northwestern.edu"]
    allowed_methods = ["GET"]
    max_age_seconds = "3000"
    allowed_headers = ["Authorization", "Access-Control-Allow-Origin"]
  }
}

# MediaConvert

resource "aws_iam_role" "transcode_role" {
  name = "${local.project}-transcode-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "mediaconvert.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "${local.project}-transcode-policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:Get*", "s3:List*"]
          Resource = [
            for env in local.avr_environments: "${aws_s3_bucket.avr_masterfiles[env].arn}/*"
          ]
        },
        {
          Effect   = "Allow"
          Action   = ["s3:Put*"]
          Resource = [
            for env in local.avr_environments: "${aws_s3_bucket.avr_derivatives[env].arn}/*"
          ]
        }
      ]
    })
  }
}

data "aws_iam_policy_document" "pass_transcode_role" {
  statement {
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.transcode_role.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "events:ListRules",
      "events:PutRule",
      "events:PutTargets",
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:GetQueryResults",
      "logs:StartQuery",
      "mediaconvert:CancelJob",
      "mediaconvert:CreateJob",
      "mediaconvert:DescribeEndpoints",
      "mediaconvert:GetJob",
      "mediaconvert:GetQueue"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "allow_transcode" {
  name   = "${local.project}-mediaconvert-access"
  policy = data.aws_iam_policy_document.pass_transcode_role.json
}

resource "aws_media_convert_queue" "transcode_queue" {
  name   = local.project
  status = "ACTIVE"
}

resource "aws_cloudwatch_log_group" "mediaconvert_state_change_log" {
  name                = "/aws/events/active-encode/mediaconvert/${aws_media_convert_queue.transcode_queue.name}"
  retention_in_days   = 3
}

resource "aws_cloudwatch_event_rule" "mediaconvert_state_change" {
  name        = "${local.project}-mediaconvert-state-change"
  description = "Send MediaConvert state changes to Meadow"

  event_pattern = jsonencode({
    source        = ["aws.mediaconvert"]
    "detail-type" = ["MediaConvert Job State Change"]
    detail = {
      queue  = [aws_media_convert_queue.transcode_queue.arn]
    }
  })
}

resource "aws_cloudwatch_event_target" "mediaconvert_state_change_cloudwatch_log" {
  rule      = aws_cloudwatch_event_rule.mediaconvert_state_change.name
  target_id = "SendToCloudwatchLogs"
  arn       = aws_cloudwatch_log_group.mediaconvert_state_change_log.arn
}