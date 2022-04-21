data "aws_cloudformation_stack" "fixity_stack" {
  name = "${local.name}-fixity"
}

data "aws_sfn_state_machine" "fixity_state_machine" {
  name = data.aws_cloudformation_stack.fixity_stack.outputs.StateMachineName
}

module "execute_fixity_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 3.1.1"
  
  function_name   = "${local.name}-execute-fixity"
  description     = "Function that receives S3 upload notification and triggers fixity step function execution"
  handler         = "index.handler"
  memory_size     = 256
  runtime         = "nodejs14.x"
  timeout         = 60
  tags            = local.tags

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
  name   = "${local.name}-fixity-trigger-step-function"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = ""
      Effect    = "Allow"
      Action    = ["states:StartExecution"]
      Resource  = [data.aws_sfn_state_machine.fixity_state_machine.arn]
    }]
  })

  tags = local.tags
}

resource "aws_iam_policy_attachment" "fixity_execute_step_function" {
  name          = "${local.name}-allow-fixity-trigger-function"
  roles         = [module.execute_fixity_function.lambda_role_name]
  policy_arn    = aws_iam_policy.execute_step_function.arn
}

resource "aws_ssm_parameter" "output_parameter" {
  for_each = {
    fixity_function_arn          = module.execute_fixity_function.lambda_function_arn
    fixity_function_name         = module.execute_fixity_function.lambda_function_name
    fixity_function_invoke_arn   = module.execute_fixity_function.lambda_function_invoke_arn
    fixity_function_role_arn     = module.execute_fixity_function.lambda_role_arn
    fixity_function_role_name    = module.execute_fixity_function.lambda_role_name
  }

  name        = "/${local.name}/terraform/common/${each.key}"
  type        = "String"
  value       = each.value
}
