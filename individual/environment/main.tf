data "aws_caller_identity" "current_user" {}
data "aws_region" "current" {}

locals {
  project                   = "dev-environment"
  prefix                    = var.name
  owner                     = split("-", local.prefix)[0]
  environment               = split("-", local.prefix)[1]
  regional_id               = join(":", [data.aws_region.current.name, data.aws_caller_identity.current_user.id])
}
