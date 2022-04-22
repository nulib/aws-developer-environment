terraform {
  backend "s3" {
    key = "shared.tfstate"
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
  name = "dev-environment"
  tags = {
    project = local.name
    owner   = "shared"  
  }
}

