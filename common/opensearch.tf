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
  engine_version        = "OpenSearch_2.13"
  advanced_options      = {
    "rest.action.multi.allow_explicit_index" = "true"
  }  
  cluster_config {
    instance_type  = "m6g.large.search"
    instance_count = 1
  }
  ebs_options {
    ebs_enabled = "true"
    volume_size = 30
  }

  vpc_options {
    security_group_ids    = [aws_security_group.search_index.id]
    subnet_ids            = [module.vpc.private_subnets[0]]
  }

  access_policies = data.aws_iam_policy_document.search_index_http_access.json
  lifecycle {
    ignore_changes = [ebs_options, log_publishing_options]
  }
}

resource "aws_s3_bucket" "search_snapshot_bucket" {
  bucket = "${local.opensearch_domain}-snapshots"
}

resource "aws_s3_bucket_public_access_block" "search_snapshot_public_access" {
  bucket = aws_s3_bucket.search_snapshot_bucket.id

  block_public_acls         = true
  block_public_policy       = true
  ignore_public_acls        = true
  restrict_public_buckets   = true
}

resource "aws_iam_role" "search_snapshot_bucket_access" {
  path                  = local.iam_path
  name                  = "${local.opensearch_domain}-snapshot-role"
  assume_role_policy    = data.aws_iam_policy_document.search_snapshot_assume_role.json
}

resource "aws_iam_role_policy" "search_snapshot_bucket_access" {
  name    = "${local.opensearch_domain}-snapshot-policy"
  role    = aws_iam_role.search_snapshot_bucket_access.name
  policy  = data.aws_iam_policy_document.search_snapshot_bucket_access.json
}

data "aws_iam_policy_document" "search_snapshot_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["es.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "search_snapshot_bucket_access" {
  statement {
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.search_snapshot_bucket.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.search_snapshot_bucket.arn}/*"]
  }
}
