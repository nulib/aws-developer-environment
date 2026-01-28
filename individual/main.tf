terraform {
  backend "s3" {
    key = "ide.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider aws {
  default_tags {
    tags = local.tags
  }
}

data "aws_caller_identity" "current_user" {}
data "aws_region" "current" {}

data "aws_secretsmanager_secret_version" "common_config" {
  secret_id = "${local.project}/terraform/common"
}

locals {
  project       = "dev-environment"
  owner         = terraform.workspace
  prefix        = local.owner
  iam_path      = join("/", ["", local.project, local.owner, ""])
  regional_id   = join(":", [data.aws_region.current.region, data.aws_caller_identity.current_user.id])

  common_config = jsondecode(data.aws_secretsmanager_secret_version.common_config.secret_string)

  tags = merge(var.tags, {
    Project = local.project
    Owner   = local.owner
  })
}
