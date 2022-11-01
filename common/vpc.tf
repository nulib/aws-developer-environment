module "vpc" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "~> 3.14"

  name = local.project
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_dns_hostnames    = true
  enable_nat_gateway      = false
  enable_vpn_gateway      = false
}

resource "aws_security_group_rule" "default_allows_all_in_vpc" {
  security_group_id   = module.vpc.default_security_group_id
  type                = "ingress"
  from_port           = 0
  to_port             = 65535
  protocol            = "all"
  cidr_blocks         = [module.vpc.vpc_cidr_block]
}

module "endpoints" {
  source    = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version   = "~> 3.14"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.default_security_group_id]

  endpoints = {
    s3        = { 
      route_table_ids   = concat([module.vpc.vpc_main_route_table_id], module.vpc.public_route_table_ids, module.vpc.private_route_table_ids)
      service           = "s3"
      service_type      = "Gateway"
    }
#    ecr_api   = { 
#      service               = "ecr.api"
#      subnet_ids            = module.vpc.private_subnets
#      private_dns_enabled   = true
#    }
#    ecr_dkr   = { 
#      service               = "ecr.dkr"
#      subnet_ids            = module.vpc.private_subnets
#      private_dns_enabled   = true
#    }
    lambda    = {
      service               = "lambda"
      subnet_ids            = module.vpc.private_subnets
      private_dns_enabled   = true
    }
    logs      = { 
      service               = "logs"
      subnet_ids            = module.vpc.private_subnets
      private_dns_enabled   = true
    }
    secrets   = { 
      service               = "secretsmanager"
      subnet_ids            = module.vpc.private_subnets
      private_dns_enabled   = true
    }
    sns       = { 
      service               = "sns"
      subnet_ids            = module.vpc.private_subnets
      private_dns_enabled   = true
    }
    sqs       = { 
      service               = "sqs"
      subnet_ids            = module.vpc.private_subnets
      private_dns_enabled   = true
    }
    ssm       = { 
      service               = "ssm"
      subnet_ids            = module.vpc.private_subnets
      private_dns_enabled   = true
    }
  }
}
