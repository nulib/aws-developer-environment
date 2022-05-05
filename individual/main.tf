terraform {
  backend "s3" {
    key = "ide.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8"
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

locals {
  project       = "dev-environment"
  owner         = terraform.workspace
  prefix        = local.owner
  iam_path      = join("/", ["", local.project, local.owner, ""])
  regional_id   = join(":", [data.aws_region.current.name, data.aws_caller_identity.current_user.id])

  common_config_ssm_path = "/${local.project}/terraform/common/"

  common_config = zipmap(
    [for name in data.aws_ssm_parameters_by_path.common.names: trimprefix(name, local.common_config_ssm_path)],
    data.aws_ssm_parameters_by_path.common.values
  )

  tags = merge(var.tags, {
    Project = local.project
    Owner   = local.owner
  })
}

data "aws_ssm_parameters_by_path" "common" {
  path              = local.common_config_ssm_path
  recursive         = true
  with_decryption   = true
}

