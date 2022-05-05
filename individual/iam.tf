data "aws_iam_role" "pipeline_lambda_role" {
  name = "${local.project}-pipeline-lambda-role"
}

resource "aws_iam_role_policy_attachment" "developer_access_lambda" {
  role          = data.aws_iam_role.pipeline_lambda_role.name
  policy_arn    = aws_iam_policy.developer_access.arn
}
