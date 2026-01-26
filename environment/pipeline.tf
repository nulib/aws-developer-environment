locals {
  actions = [
    "attach-transcription",
    "ingest-file-set",
    "extract-mime-type",
    "initialize-dispatch",
    "dispatcher",
    "generate-file-set-digests",
    "extract-exif-metadata",
    "extract-media-metadata",
    "copy-file-to-preservation",
    "create-derivative-copy",
    "create-pyramid-tiff",
    "create-transcode-job",
    "generate-poster-image",
    "transcode-complete",
    "file-set-complete"
  ]
}

resource "aws_sqs_queue" "sequins_queues" {
  for_each = toset(local.actions)
  name     = "${local.prefix}-${each.key}"
  policy   = jsonencode({
    Statement = [
      {
        Action = "SQS:SendMessage"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:events:${local.regional_id}:rule/${local.prefix}-*"
          }
        }
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Resource = "arn:aws:sqs:${local.regional_id}:${local.prefix}-${each.key}"
        Sid = "eventbridge-queue-access"
      },
    ]
    Version = "2012-10-17"
  })
}
