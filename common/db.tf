module "aurora_postgresql" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 7.7"

  name                          = "${local.project}-db-cluster"
  engine                        = "aurora-postgresql"
  engine_version                = "16.1"
  engine_mode                   = "provisioned"
  vpc_id                        = module.vpc.vpc_id
  subnets                       = module.vpc.public_subnets
  allowed_cidr_blocks           = [module.vpc.vpc_cidr_block]
  allow_major_version_upgrade   = true
  apply_immediately             = true
  create_db_parameter_group     = false
  enable_http_endpoint          = true

  serverlessv2_scaling_configuration = {
    min_capacity = 0.5
    max_capacity = 16
  }

  instance_class                = "db.serverless"
  instances = {
    one = {}
  }

  db_parameter_group_family     = "aurora-postgresql16"
  db_parameter_group_parameters = [ 
  ]
}

data "aws_iam_policy_document" "rds_assume_role" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]

    principals {
      type          = "Service"
      identifiers   = ["rds.amazonaws.com"]
    }
  }
}
