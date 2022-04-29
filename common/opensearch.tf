locals {
  opensearch_domain = "${local.project}-shared-index"
  search_index_arn  = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current_user.account_id}:domain/${local.opensearch_domain}/*"
}

data "aws_iam_policy_document" "search_index_http_access" {
  statement {
    sid       = "allow-from-vpc"
    effect    = "Allow"
    actions   = ["es:*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    
    # Can't simply use "${aws_opensearch_domain.search_index.arn}/*" here because
    # it creates a circular reference with that resource.
    resources = [local.search_index_arn]
  }
}

resource "aws_security_group" "search_index" {
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

  
resource "aws_opensearch_domain" "search_index" {
  domain_name           = local.opensearch_domain
  engine_version        = "OpenSearch_1.2"
  advanced_options      = {
    "rest.action.multi.allow_explicit_index" = "true"
  }  
  cluster_config {
    instance_type  = "t3.medium.search"
    instance_count = 1
  }
  ebs_options {
    ebs_enabled = "true"
    volume_size = 10
  }

  vpc_options {
    security_group_ids    = [aws_security_group.search_index.id]
    subnet_ids            = [module.vpc.private_subnets[0]]
  }

  access_policies = data.aws_iam_policy_document.search_index_http_access.json
  lifecycle {
    ignore_changes = [ebs_options]
  }
}