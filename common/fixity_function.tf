resource "aws_cloudformation_stack" "serverless_fixity_solution" {
  name            = "${local.project}-fixity"
  template_url    = "https://s3.amazonaws.com/solutions-reference/serverless-fixity-for-digital-preservation-compliance/latest/serverless-fixity-for-digital-preservation-compliance.template"
  parameters      = {
    # The fixity stack won't deploy without an email address, so we'll give it a black hole address 
    # that we'll unsubscribe manually as soon as the stack finishes deploying
    Email = "fixity-blackhole@mailinator.com"
  }
  capabilities    = ["CAPABILITY_IAM"]
}

data "aws_sfn_state_machine" "fixity_state_machine" {
  name = aws_cloudformation_stack.serverless_fixity_solution.outputs.StateMachineName
}

module "execute_fixity_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.1"
  
  function_name   = "${local.project}-execute-fixity"
  description     = "Function that receives S3 upload notification and triggers fixity step function execution"
  handler         = "index.handler"
  memory_size     = 256
  runtime         = "nodejs16.x"
  timeout         = 60
  role_path       = local.iam_path

  source_path = [
    {
      path     = "${path.module}/lambdas/execute-fixity"
      commands = ["npm install --only prod --no-bin-links --no-fund", ":zip"]
    }
  ]

  environment_variables = {
    stateMachineArn = data.aws_sfn_state_machine.fixity_state_machine.arn
  }
}

resource "aws_iam_policy" "execute_step_function" {
  path   = local.iam_path
  name   = "${local.project}-fixity-trigger-step-function"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = ""
      Effect    = "Allow"
      Action    = ["states:StartExecution"]
      Resource  = [data.aws_sfn_state_machine.fixity_state_machine.arn]
    }]
  })
}

resource "aws_iam_policy_attachment" "fixity_execute_step_function" {
  name          = "${local.project}-allow-fixity-trigger-function"
  roles         = [module.execute_fixity_function.lambda_role_name]
  policy_arn    = aws_iam_policy.execute_step_function.arn
}

resource "aws_lambda_permission" "allow_invoke_from_bucket" {
  statement_id    = "AllowExecutionFromBucketNotifications"
  action          = "lambda:InvokeFunction"
  function_name   = module.execute_fixity_function.lambda_function_name
  principal       = "s3.amazonaws.com"
  source_arn      = "arn:aws:s3:::*"
}
