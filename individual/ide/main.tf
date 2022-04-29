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

  tags = merge(var.tags, {
    Project = local.project
    Owner   = local.owner
  })
}
