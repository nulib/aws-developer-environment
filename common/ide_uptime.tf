data "aws_iam_policy_document" "uptime_metric" {
  statement {
    effect    = "Allow"
    actions   = [
      "cloudwatch:PutMetricData", 
      "ec2:DescribeInstances",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "allow_uptime_metric" {
  path    = local.iam_path
  name    = "${local.project}-uptime-metric"
  policy  = data.aws_iam_policy_document.uptime_metric.json
}

module "uptime_metric" {
  source    = "terraform-aws-modules/lambda/aws"
  version   = "~> 3.1"
  
  function_name   = "${local.project}-report-ide-uptime-metrics"
  description     = "Reports developer IDE uptime metrics to CloudWatch"
  handler         = "index.handler"
  memory_size     = 128
  runtime         = "nodejs16.x"
  role_path       = local.iam_path
  timeout         = 5
  

  source_path = [
    {
      path     = "${path.module}/lambdas/uptime_metric"
      commands = ["npm install --only prod --no-bin-links --no-fund", ":zip"]
    }
  ]
}

resource "aws_iam_role_policy_attachment" "uptime_metric" {
  role          = module.uptime_metric.lambda_role_name
  policy_arn    = aws_iam_policy.allow_uptime_metric.arn
}

resource "aws_cloudwatch_event_rule" "uptime_metric" {
  name        = "${local.project}-ide-uptime-metric"
  description = "Report developer IDE uptime metrics to CloudWatch"

  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "uptime_metric" {
  rule        = aws_cloudwatch_event_rule.uptime_metric.name
  target_id   = "ReportUptimeMetrics"
  arn         = module.uptime_metric.lambda_function_arn
}

resource "aws_lambda_permission" "uptime_metric_update" {
  statement_id    = "AllowUptimeMetricsFromEventbridge"
  action          = "lambda:InvokeFunction"
  function_name   = module.uptime_metric.lambda_function_name
  principal       = "events.amazonaws.com"
  source_arn      = aws_cloudwatch_event_rule.uptime_metric.arn
}

resource "aws_sns_topic" "ide_uptime_alert" {
  name = "${local.project}-ide-uptime-alert" 
}