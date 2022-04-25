locals {
  elasticsearch_domain = "${local.project}-shared-index"
  elasticsearch_arn    = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current_user.account_id}:domain/${local.elasticsearch_domain}/*"
}

data "aws_iam_policy_document" "elasticsearch_http_access" {
  statement {
    sid       = "allow-from-vpc"
    effect    = "Allow"
    actions   = ["es:*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    
    # Can't simply use "${aws_elasticsearch_domain.elasticsearch.arn}/*" here because
    # it creates a circular reference with that resource.
    resources = [local.elasticsearch_arn]
  }
}

resource "aws_security_group" "index" {
  name        = "${local.project}-index"
  description = "Elasticsearch/OpenSearch Server"
  vpc_id      = module.vpc.vpc_id

 ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_elasticsearch_domain" "elasticsearch" {
  domain_name           = local.elasticsearch_domain
  elasticsearch_version = "7.10"
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

  vpc_options {
    security_group_ids    = [aws_security_group.index.id]
    subnet_ids            = [module.vpc.private_subnets[0]]
  }

  access_policies = data.aws_iam_policy_document.elasticsearch_http_access.json
  lifecycle {
    ignore_changes = [ebs_options]
  }
}