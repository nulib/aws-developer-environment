terraform {
  backend "s3" {
    key = "cloud9.tfstate"
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
  backend_config    = jsondecode(file("${path.module}/../common/.terraform/terraform.tfstate")).backend.config
  envs              = ["dev", "test"]
}

data "terraform_remote_state" "common" {
  backend = "s3"
  config  = {
    bucket    = local.backend_config.bucket
    key       = local.backend_config.key
  }
}