locals {
  elasticsearch_domain = "${local.name}-shared-index"
  elasticsearch_arn    = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current_user.account_id}:domain/${local.elasticsearch_domain}/*"
}

data "aws_iam_policy_document" "elasticsearch_http_access" {
  statement {
    sid       = "allow-from-aws"
    effect    = "Allow"
    actions   = ["es:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current_user.account_id}:root"]
    }

    # Can't simply use "${aws_elasticsearch_domain.elasticsearch.arn}/*" here because
    # it creates a circular reference with that resource.
    resources = [local.elasticsearch_arn]
  }
}

resource "aws_elasticsearch_domain" "elasticsearch" {
  domain_name           = local.elasticsearch_domain
  elasticsearch_version = "7.10"
  tags                  = local.tags
  advanced_options      = {
    "rest.action.multi.allow_explicit_index" = "true"
  }  
  cluster_config {
    instance_type  = "t3.medium.elasticsearch"
    instance_count = 1
  }
  ebs_options {
    ebs_enabled = "true"
    volume_size = 10
  }
  access_policies = data.aws_iam_policy_document.elasticsearch_http_access.json
  lifecycle {
    ignore_changes = [ebs_options]
  }
}