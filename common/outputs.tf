resource "aws_ssm_parameter" "output_parameter" {
  for_each = {
    fixity_function_arn          = module.execute_fixity_function.lambda_function_arn
    ide_uptime_alert_topic       = aws_sns_topic.ide_uptime_alert.arn
    vpc_id                       = module.vpc.vpc_id
    elasticsearch_snapshot_role  = aws_iam_role.search_snapshot_bucket_access.arn
  }

  name        = "/${local.project}/terraform/common/${each.key}"
  type        = "String"
  value       = each.value
}

output "search_snapshot_configuration" {
  value = {
    create_url    = "https://${aws_opensearch_domain.search_index.endpoint}/_snapshot/${local.project}-index-snapshots"
    create_doc    = jsonencode({
      type     = "s3"
      settings = {
        bucket    = aws_s3_bucket.search_snapshot_bucket.id
        region    = data.aws_region.current.name
        role_arn  = aws_iam_role.search_snapshot_bucket_access.arn
      }
    })
  }
}