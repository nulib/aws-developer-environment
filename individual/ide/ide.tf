resource "aws_iam_role" "ide_instance_role" {
  name    = "${local.prefix}-ide-instance-role"
  path    = "/"
  tags    = local.tags

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
  statement {
    sid       = "DeveloperAccess"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
    condition {
      test        = "StringEquals"
      variable    = "aws:ResourceTag/project"
      values      = [local.project]
    }

    condition {
      test        = "StringEquals"
      variable    = "aws:ResourceTag/owner"
      values      = [local.owner]
    }
  }
}

resource "aws_iam_policy" "developer_access" {
  name    = "${local.prefix}-developer-access"
  policy  = data.aws_iam_policy_document.developer_access.json
  tags    = local.tags
}

resource "aws_iam_role_policy_attachment" "developer_access" {
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
  tags    = local.tags
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