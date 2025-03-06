data "aws_iam_policy_document" "acme_cert_policy" {
  statement {
    sid       = "AcmeS3ListAccess"
    effect    = "Allow"
    actions   = ["s3:List*"]
    resources = [
      "arn:aws:s3:::${var.acme_cert_state_store.bucket}",
      "arn:aws:s3:::${var.acme_cert_state_store.bucket}/*"
    ]
  }
  statement {
    sid       = "AcmeStateAccess"
    effect    = "Allow"
    actions   = ["s3:Get*", "s3:Put*"]
    resources = ["arn:aws:s3:::${var.acme_cert_state_store.bucket}/${var.acme_cert_state_store.key}"]
  }

  statement {
    sid       = "AcmeSecretsAccess"
    effect    = "Allow"
    actions   = ["secretsmanager:PutSecretValue"]
    resources = [aws_secretsmanager_secret.ssl_certificate.id]
  }

  statement {
    sid       = "AcmeDnsZoneAccess"
    effect    = "Allow"
    actions   = ["route53:ListHostedZones"]
    resources = ["*"]
  }

  statement {
    sid       = "AcmeDnsRecordAccess"
    effect    = "Allow"
    actions   = [
      "route53:ListResourceRecordSets", 
      "route53:ChangeResourceRecordSets"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${aws_route53_zone.hosted_zone.zone_id}"
    ]
  }
}

resource "aws_iam_policy" "acme_cert_task_policy" {
  path    = local.iam_path
  name    = "${local.project}-acme-cert"
  policy  = data.aws_iam_policy_document.acme_cert_policy.json
}

data "aws_iam_policy_document" "github_actions_assume_role_policy" {
  statement {
    sid       = "GitHubActionsAssumeRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [
        for repo in var.acme_cert_actions_repos : "repo:${repo}:*"
      ]
    }
  }
}

resource "aws_iam_role" "acme_cert_github_role" {
  path                  = local.iam_path
  name                  = "github-actions-update-developer-cert"
  assume_role_policy    = data.aws_iam_policy_document.github_actions_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "acme_cert_github_policy" {
  role       = aws_iam_role.acme_cert_github_role.name
  policy_arn = aws_iam_policy.acme_cert_task_policy.arn
}
