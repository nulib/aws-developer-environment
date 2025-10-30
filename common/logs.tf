resource "aws_cloudwatch_log_group" "dev_environment" {
  name                = "/nul/${local.project}"
  retention_in_days   = 3
}
