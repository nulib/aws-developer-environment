resource "aws_iam_role" "ide_instance_role" {
  name    = "${local.prefix}-ide-instance-role"
  path    = "/"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Sid       = ""
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

data "aws_iam_policy_document" "developer_access" {
#  statement {
#    sid       = "DeveloperAccess"
#    effect    = "Allow"
#    actions   = ["*"]
#    resources = ["*"]
#    condition {
#      test        = "StringEquals"
#      variable    = "aws:ResourceTag/Project"
#      values      = [local.project]
#    }
#
#    condition {
#      test        = "StringEquals"
#      variable    = "aws:ResourceTag/Owner"
#      values      = [local.owner]
#    }
#  }

  statement {
    sid       = "DeveloperBucketAccess"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${local.owner}-*", "arn:aws:s3:::${local.owner}-*/*"]
  }

  statement {
    sid       = "DeveloperLambdaInvocation"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [
      "arn:aws:lambda:${local.regional_id}:function:${local.owner}-*",
      "arn:aws:lambda:${local.regional_id}:function:${local.project}-*"
    ]
  }

  statement {
    sid       = "DeveloperMediaConvertAccess"
    effect    = "Allow"
    actions   = ["mediaconvert:*"]
    resources = [
      "arn:aws:mediaconvert:${local.regional_id}:${local.owner}-*",
      "arn:aws:mediaconvert:${local.regional_id}:${local.project}-*"
    ]
  }

  statement {
    sid       = "DeveloperSQSAccess"
    effect    = "Allow"
    actions   = ["sqs:*"]
    resources = [
      "arn:aws:sqs:${local.regional_id}:${local.owner}-*",
      "arn:aws:sqs:${local.regional_id}:${local.project}-*"
    ]
  }

  statement {
    sid       = "DeveloperSNSAccess"
    effect    = "Allow"
    actions   = ["sns:*"]
    resources = [
      "arn:aws:sns:${local.regional_id}:${local.owner}-*",
      "arn:aws:sns:${local.regional_id}:${local.project}-*"
    ]
  }

  statement {
    sid       = "DeveloperSecretsAccess"
    effect    = "Allow"
    actions   = ["secretsmanager:Get*"]
    resources = [
      "arn:aws:secretsmanager:${local.regional_id}:secret:${local.owner}/*",
      "arn:aws:secretsmanager:${local.regional_id}:secret:${local.project}/*"
    ]
  }
}

resource "aws_iam_policy" "developer_access" {
  name    = "${local.prefix}-developer-access"
  policy  = data.aws_iam_policy_document.developer_access.json
}

resource "aws_iam_role_policy_attachment" "developer_access_ide" {
  role          = aws_iam_role.ide_instance_role.name
  policy_arn    = aws_iam_policy.developer_access.arn
}

resource "aws_iam_role_policy_attachment" "read_only_access" {
  role          = aws_iam_role.ide_instance_role.name
  policy_arn    = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "service_discovery" {
  role          = aws_iam_role.ide_instance_role.name
  policy_arn    = "arn:aws:iam::aws:policy/AWSCloudMapDiscoverInstanceAccess"
}

resource "aws_iam_role_policy_attachment" "cloud9_ssm_policy" {
  role          = aws_iam_role.ide_instance_role.name
  policy_arn    = "arn:aws:iam::aws:policy/AWSCloud9SSMInstanceProfile"
}

resource "aws_iam_instance_profile" "ide_instance_profile" {
  name = "${local.prefix}-ide-instance-profile"
  role    = aws_iam_role.ide_instance_role.name
}

resource "aws_ssm_parameter" "ide_config" {
  for_each = {
    instance_role_name    = aws_iam_role.ide_instance_role.name
    instance_profile_arn  = aws_iam_instance_profile.ide_instance_profile.arn
  }

  name        = "/${local.project}/terraform/${local.owner}/ide/${each.key}"
  type        = "String"
  value       = each.value
}
