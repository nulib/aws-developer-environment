module "vpc" {
  source    = "terraform-aws-modules/vpc/aws"
  version   = "~> 5.5"

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

data "aws_vpc" "staging_vpc" {
  id = var.staging_vpc_id
}

data "aws_route_tables" "staging_route_tables" {
  vpc_id = data.aws_vpc.staging_vpc.id
}

resource "aws_vpc_peering_connection" "dev_to_staging" {
  peer_vpc_id   = data.aws_vpc.staging_vpc.id
  vpc_id        = module.vpc.vpc_id
  auto_accept   = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}

resource "aws_route" "to_staging" {
  for_each                    = toset(module.vpc.public_route_table_ids)
  route_table_id              = each.key
  vpc_peering_connection_id   = aws_vpc_peering_connection.dev_to_staging.id
  destination_cidr_block      = data.aws_vpc.staging_vpc.cidr_block
}

resource "aws_route" "from_staging" {
  for_each                    = toset(data.aws_route_tables.staging_route_tables.ids)
  route_table_id              = each.key
  vpc_peering_connection_id   = aws_vpc_peering_connection.dev_to_staging.id
  destination_cidr_block      = module.vpc.vpc_cidr_block
}