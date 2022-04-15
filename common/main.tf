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

provider aws {}

locals {
  name = "dev-environment"

  tags = {
    project = local.name
    owner   = "shared"
  }
}

