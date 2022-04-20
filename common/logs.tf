resource "aws_cloudwatch_log_group" "dev_environment" {
  name                = "/${local.name}"
  retention_in_days   = 3
  tags                = local.tags
}
