resource "aws_ssm_parameter" "output_parameter" {
  for_each = {
    fixity_function_arn          = module.execute_fixity_function.lambda_function_arn
    vpc_id                       = module.vpc.vpc_id
  }

  name        = "/${local.project}/terraform/common/${each.key}"
  type        = "String"
  value       = each.value
}
