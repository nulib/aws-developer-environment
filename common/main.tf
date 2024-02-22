terraform {
  backend "s3" {
    key = "shared.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.1"
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
  iam_path      = "/${local.project}/"
  regional_id   = join(":", [data.aws_region.current.name, data.aws_caller_identity.current_user.id])
  tags    = {
    Project = local.project
    Owner   = "shared"  
  }
}

resource "aws_s3_bucket" "dev_environment_shared_bucket" {
  bucket = "nul-${local.project}-shared"
}