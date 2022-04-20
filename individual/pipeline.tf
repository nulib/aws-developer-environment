locals {
  actions = {
    "ingest-file-set"           = [],
    "extract-mime-type"         = ["ingest-file-set"],
    "initialize-dispatch"       = ["extract-mime-type"],
    "dispatcher"                = ["initialize-dispatch", "generate-file-set-digests", "copy-file-to-preservation", 
                                   "extract-exif-metadata", "extract-media-metadata", "create-pyramid-tiff", 
                                   "transcode-complete"],
    "generate-file-set-digests" = [],
    "extract-exif-metadata"     = [],
    "extract-media-metadata"    = [],
    "copy-file-to-preservation" = [],
    "create-pyramid-tiff"       = [],
    "create-transcode-job"      = [],
    "generate-poster-image"     = [],
    "transcode-complete"        = [],
    "file-set-complete"         = [],
  }

  # Duplicate each action in the actions map for each environment (dev/test)
  env_actions = zipmap(
    [for action in setproduct(local.envs, keys(local.actions)): join("-", action)],
    [
      for env_targets in setproduct(local.envs, values(local.actions)): 
        flatten([for target in env_targets[1]: join("-", [env_targets[0], target])])
    ]
  )

  # Turn topic => [queues...] map into a topic.queue => { topic: topic, queue: queue }
  # map for easier iteration with for_each
  action_map = {
    for entry in
    distinct(flatten([
      for topic in keys(local.env_actions) : [
        for queue in local.env_actions[topic] : {
          topic = topic
          queue = queue
        }
      ]
    ])) : "${entry.topic}.${entry.queue}" => entry
  }
}

resource "aws_sns_topic_subscription" "ingest_pipeline_retry" {
  for_each  = local.env_actions
  protocol  = "sqs"
  topic_arn = aws_sns_topic.sequins_topics[each.key].arn
  endpoint  = aws_sqs_queue.sequins_queues[each.key].arn

  filter_policy = jsonencode({
    status = ["retry"]
  })
}

resource "aws_sns_topic_subscription" "ingest_pipeline_ok" {
  for_each  = local.action_map
  protocol  = "sqs"
  topic_arn = aws_sns_topic.sequins_topics[each.value.topic].arn
  endpoint  = aws_sqs_queue.sequins_queues[each.value.queue].arn

  filter_policy = jsonencode({
    status = ["ok"]
  })
}

resource "aws_sqs_queue" "sequins_queues" {
  for_each = toset(keys(local.env_actions))
  name     = "${local.prefix}-${each.key}"
  tags     = local.tags

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "sns-notifications-1"
        Effect    = "Allow"
        Principal = { "AWS" : "*" }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:::${local.prefix}-${each.key}"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:sns:::${local.prefix}-*"
          }
        }
      },
      {
        Sid       = "eventbridge-notifications-1"
        Effect    = "Allow"
        Principal = { "AWS" : "*" }
        Action    = "SQS:SendMessage"
        Resource  = "arn:aws:sqs:::${local.prefix}-${each.key}"
        Condition = {
          ArnLike = {
            "aws:SourceArn" = "arn:aws:events:::rule/${local.prefix}-*"
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic" "sequins_topics" {
  for_each = toset(keys(local.env_actions))
  name     = "${local.prefix}-${each.key}"
  tags     = local.tags
}

resource "aws_media_convert_queue" "transcode_queue" {
  name   = local.prefix
  status = "ACTIVE"

  tags = local.tags
}

resource "aws_cloudwatch_event_rule" "mediaconvert_state_change" {
  name        = "${local.prefix}-mediaconvert-state-change"
  description = "Send MediaConvert state changes to Meadow"
  event_pattern = jsonencode({
    source        = ["aws.mediaconvert"]
    "detail-type" = ["MediaConvert Job State Change"]
    detail = {
      status = ["COMPLETE", "ERROR"]
      queue  = [aws_media_convert_queue.transcode_queue.arn]
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "mediaconvert_state_change_sqs" {
  rule      = aws_cloudwatch_event_rule.mediaconvert_state_change.name
  target_id = "SendToTranscodeCompleteQueue"
  arn       = aws_sqs_queue.sequins_queues["dev-transcode-complete"].arn
}
