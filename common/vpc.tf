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
