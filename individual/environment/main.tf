terraform {
  backend "s3" {
    key = "environment.tfstate"
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

locals {
  project                   = "dev-environment"
  prefix                    = terraform.workspace
  owner                     = split("-", local.prefix)[0]
  environment               = split("-", local.prefix)[1]
  common_config_ssm_path    = "/${local.project}/terraform/common/"
  ide_config_ssm_path       = "/${local.project}/terraform/${local.owner}/ide/"
}

data "aws_ssm_parameters_by_path" "common" {
  path              = local.common_config_ssm_path
  recursive         = true
  with_decryption   = true
}

data "aws_ssm_parameters_by_path" "ide" {
  path              = local.ide_config_ssm_path
  recursive         = true
  with_decryption   = true
}

locals {
  common_config = zipmap(
    [for name in data.aws_ssm_parameters_by_path.common.names: trimprefix(name, local.common_config_ssm_path)],
    data.aws_ssm_parameters_by_path.common.values
  )

  ide_config = zipmap(
    [for name in data.aws_ssm_parameters_by_path.ide.names: trimprefix(name, local.ide_config_ssm_path)],
    data.aws_ssm_parameters_by_path.ide.values
  )

  tags = merge(var.tags, {
    project   = local.project
    owner     = local.owner
  })
}