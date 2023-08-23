resource "aws_media_convert_queue" "transcode_queue" {
  name   = "${local.prefix}-dev-transcode"
  status = "ACTIVE"
}

resource "aws_cloudwatch_event_rule" "mediaconvert_state_change" {
  name        = "${local.prefix}-dev-mediaconvert-state-change"
  description = "Send MediaConvert state changes to Meadow"
  event_pattern = jsonencode({
    source        = ["aws.mediaconvert"]
    "detail-type" = ["MediaConvert Job State Change"]
    detail = {
      status = ["COMPLETE", "ERROR"]
      queue  = [aws_media_convert_queue.transcode_queue.arn]
    }
  })
}

resource "aws_cloudwatch_event_target" "mediaconvert_state_change_sqs" {
  rule      = aws_cloudwatch_event_rule.mediaconvert_state_change.name
  target_id = "SendToTranscodeCompleteQueue"
  arn       = "arn:aws:sqs:${local.regional_id}:${local.prefix}-dev-transcode-complete"
}
