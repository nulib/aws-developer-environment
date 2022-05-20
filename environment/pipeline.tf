locals {
  actions = [
    "ingest-file-set",
    "extract-mime-type",
    "initialize-dispatch",
    "dispatcher",
    "generate-file-set-digests",
    "extract-exif-metadata",
    "extract-media-metadata",
    "copy-file-to-preservation",
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
}
