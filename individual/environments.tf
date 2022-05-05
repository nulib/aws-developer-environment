module "environment" {
  source                = "../environment"
  for_each              = toset(var.environments)
  name                  = "${local.owner}-${each.key}"
  fixity_function_arn   = local.common_config.fixity_function_arn
}
