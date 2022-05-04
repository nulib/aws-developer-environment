data "aws_iam_policy_document" "ide_session_policy" {
  statement {
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = [
      "ec2:DescribeInstances",
      "ssm:DescribeInstanceInformation"
    ]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ec2:StartInstances"]
    resources = ["arn:aws:ec2:${local.regional_id}:instance/*"]
    condition {
      test        = "StringEquals"
      variable    = "aws:ResourceTag/Project"
      values      = [local.project]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:aws:ssm:*::document/AWS-StartSSHSession"]
  }

  statement {
    effect    = "Allow"
    actions   = ["ssm:StartSession"]
    resources = ["arn:aws:ec2:${local.regional_id}:instance/*"]
    condition {
      test        = "StringEquals"
      variable    = "aws:ResourceTag/Project"
      values      = [local.project]
    }
  }
}

resource "aws_iam_user" "ide_session_user" {
  name          = "${local.project}-ide-session"
  path          = "${local.iam_path}"
}

resource "aws_iam_user_policy" "ide_session_policy" {
  name    = "${local.project}-ide-session"
  user    = aws_iam_user.ide_session_user.name
  policy  = data.aws_iam_policy_document.ide_session_policy.json
}

resource "aws_iam_access_key" "ide_session_key" {
  user = aws_iam_user.ide_session_user.name
}

resource "aws_secretsmanager_secret" "ide_session_key" {
  name          = "${local.project}/common/ide-session-key"
  description   = "Keypair for use in creating SSH sessions on IDE VMs"
}

resource "aws_secretsmanager_secret_version" "ide_session_key" {
  secret_id     = aws_secretsmanager_secret.ide_session_key.id
  secret_string = jsonencode({
    aws_access_key_id       = aws_iam_access_key.ide_session_key.id
    aws_secret_access_key   = aws_iam_access_key.ide_session_key.secret
  })
}
