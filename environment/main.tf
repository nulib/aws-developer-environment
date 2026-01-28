data "aws_caller_identity" "current_user" {}
data "aws_region" "current" {}

locals {
  project                   = var.project
  prefix                    = var.name
  regional_id               = join(":", [data.aws_region.current.region, data.aws_caller_identity.current_user.id])
}
