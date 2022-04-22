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

locals {
  project = "dev-environment"
  owner   = terraform.workspace
  prefix  = local.owner

  tags = merge(var.tags, {
    project   = local.project
    owner     = local.owner
  })
}
