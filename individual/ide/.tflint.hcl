config {
  module = true
}

plugin "aws" {
  enabled = true
  version = "0.13.2"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "aws_resource_missing_tags" {
  enabled   = true
  tags      = ["Project", "Owner"]
}

rule "terraform_module_pinned_source" {
  enabled             = false
  style               = "flexible"
  default_branches    = ["master"]
}