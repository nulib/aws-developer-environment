terraform {
  backend "s3" {
    key       = "post-tailnet.tfstate"
    region    = "us-east-1"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28"
    }
  }
}

provider "aws" {
  default_tags {
    tags = local.tags
  }
}

locals {
  project               = "dev-environment"

  tags    = {
    Project = local.project
    Owner   = "shared"  
  }
}

data "aws_caller_identity" "current_user" {}
data "aws_region" "current" {}

data "aws_wafv2_ip_set" "dev_ips" {
  scope   = "REGIONAL"
  name    = var.waf_ip_set_name
}

module "ip_updater_lambda" {
  source    = "terraform-aws-modules/lambda/aws"
  version   = "~> 8.8"

  function_name   = "${local.project}-tailnet-ip-updater"
  description     = "Updates the WAF IP Set with current Tailnet IPs"
  handler         = "index.handler"
  runtime         = "nodejs24.x"
  memory_size     = 128
  timeout         = 10
  environment_variables = {
    "TAILNET"             = var.tailnet
    "TAILSCALE_API_KEY"   = var.tailscale_api_key
    "WAF_IP_SET_ID"       = data.aws_wafv2_ip_set.dev_ips.id
    "WAF_IP_SET_NAME"     = data.aws_wafv2_ip_set.dev_ips.name
  }

  source_path = [
    {
      path     = "${path.module}/lambda/ip_set_updater"
      commands = ["npm install --only prod --no-bin-links --no-fund", ":zip"]
    }
  ]
}

resource "aws_iam_policy" "update_waf_ip_set" {
  name   = "${local.project}-update-waf-ip-set"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "wafv2:UpdateIPSet",
          "wafv2:GetIPSet"
        ]
        Resource = ["arn:aws:wafv2:${data.aws_region.current.region}:${data.aws_caller_identity.current_user.account_id}:regional/ipset/${data.aws_wafv2_ip_set.dev_ips.name}/${data.aws_wafv2_ip_set.dev_ips.id}"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_waf_update" {
  role       = module.ip_updater_lambda.lambda_role_name
  policy_arn = aws_iam_policy.update_waf_ip_set.arn
}
