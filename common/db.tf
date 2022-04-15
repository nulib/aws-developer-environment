module "aurora_postgresql" {
  source  = "terraform-aws-modules/rds-aurora/aws"

  name                  = "${local.name}-db-cluster"
  engine                = "aurora-postgresql"
  engine_version        = "11.12"
  engine_mode           = "serverless"
  vpc_id                = module.vpc.vpc_id
  subnets               = module.vpc.private_subnets
  allowed_cidr_blocks   = [module.vpc.vpc_cidr_block]
  apply_immediately     = true
  tags                  = local.tags

  scaling_configuration = {
    auto_pause               = true
    max_capacity             = 32
    min_capacity             = 2
    seconds_until_auto_pause = 300
    timeout_action           = "ForceApplyCapacityChange"
  }
}

resource "aws_ssm_parameter" "db_user" {
  name    = "/dev-environment/db/user"
  type    = "String"
  value   = module.aurora_postgresql.cluster_master_username
}

resource "aws_ssm_parameter" "db_password" {
  name    = "/dev-environment/db/password"
  type    = "String"
  value   = module.aurora_postgresql.cluster_master_password
}

resource "aws_ssm_parameter" "db_host" {
  name    = "/dev-environment/db/host"
  type    = "String"
  value   = module.aurora_postgresql.cluster_endpoint
}
