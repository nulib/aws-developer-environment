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

module "endpoints" {
  source    = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version   = "~> 3.14"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc.default_security_group_id]

  endpoints = {
    s3        = { 
      route_table_ids   = [module.vpc.vpc_main_route_table_id]
      service           = "s3"
      service_type      = "Gateway"
    }
    lambda    = { service = "lambda" }
    sns       = { service = "sns"    }
    sqs       = { service = "sqs"    }
  }
}
