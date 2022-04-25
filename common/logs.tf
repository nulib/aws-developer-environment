resource "aws_cloudwatch_log_group" "dev_environment" {
  name                = "/${local.project}"
  retention_in_days   = 3
}
