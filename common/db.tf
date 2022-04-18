module "aurora_postgresql" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 6.2.0"

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

