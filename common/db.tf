module "aurora_postgresql" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "~> 7.7"

  name                                = "${local.project}-db-cluster"
  engine                              = "aurora-postgresql"
  engine_version                      = "16.8"
  engine_mode                         = "provisioned"
  vpc_id                              = module.vpc.vpc_id
  subnets                             = module.vpc.public_subnets
  allowed_cidr_blocks                 = [module.vpc.vpc_cidr_block]
  allow_major_version_upgrade         = true
  apply_immediately                   = true
  create_db_cluster_parameter_group   = true
  create_db_parameter_group           = true
  enable_http_endpoint                = true

  serverlessv2_scaling_configuration = {
    min_capacity = 0.5
    max_capacity = 16
  }

  instance_class                = "db.serverless"
  instances = {
    one = {}
  }

  db_cluster_parameter_group_family     = "aurora-postgresql16"
  db_cluster_parameter_group_parameters = [
    {
      name            = "rds.logical_replication"
      value           = 1
      apply_method    = "pending-reboot"
    },
  ]

  db_parameter_group_family     = "aurora-postgresql16"
  db_parameter_group_parameters = [
    {
      name            = "max_locks_per_transaction"
      value           = 1024
      apply_method    = "pending-reboot"
    }
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
