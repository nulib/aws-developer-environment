data "aws_iam_policy_document" "owner_full_access" {
  statement {
    sid       = "OwnerFullAccess"
    effect    = "Allow"
    actions   = ["*"]
    resources = flatten([
      aws_media_convert_queue.transcode_queue.arn,
      [for bucket in values(aws_s3_bucket.meadow_buckets)[*]: [bucket.arn, "${bucket.arn}/*"]],
      [for topic  in values(aws_sns_topic.sequins_topics)[*]: topic.arn],
      [for queue  in values(aws_sqs_queue.sequins_queues)[*]: queue.arn]
    ])
  }
}

resource "aws_iam_policy" "owner_full_access" {
  name    = "${local.prefix}-owner-full-access"
  policy  = data.aws_iam_policy_document.owner_full_access.json
  tags    = local.tags
}

resource "aws_iam_role_policy_attachment" "owner_full_access" {
  role          = local.ide_config.instance_role_name
  policy_arn    = aws_iam_policy.owner_full_access.arn
}
