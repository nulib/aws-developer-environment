data "aws_ami" "amazon_linux_2022" {
  most_recent   = true
  owners        = ["amazon"]
  name_regex    = "al2022-ami-2022"
  filter {
    name = "architecture"
    values = ["x86_64"]
  }
}

resource "random_shuffle" "az" {
  input           = local.common_config.subnets.public
  result_count    = 1
}

data "aws_subnet" "ide_instance_subnet" {
  id = random_shuffle.az.result[0]
}

resource "aws_instance" "ide_instance" {
  ami             = data.aws_ami.amazon_linux_2022.image_id
  instance_type   = var.ide_instance_type

  disable_api_termination                 = true
  instance_initiated_shutdown_behavior    = "stop"

  availability_zone             = data.aws_subnet.ide_instance_subnet.availability_zone
  subnet_id                     = data.aws_subnet.ide_instance_subnet.id
  iam_instance_profile          = aws_iam_instance_profile.ide_instance_profile.name
  security_groups               = [aws_security_group.ide_instance_security_group.id]
  associate_public_ip_address   = true

  ebs_block_device {
    device_name             = "/dev/xvda"
    encrypted               = false
    delete_on_termination   = true
    volume_size             = 50
    volume_type             = "gp3"
    throughput              = 125
  }

  user_data = file("${path.module}/support/al-2022-init.sh")

  tags = merge(
    var.user_tags[local.owner], 
    { 
      Name = "${local.owner}-dev-environment-ide"
    }
  )
}

resource "aws_security_group" "ide_instance_security_group" {
  name    = "${local.prefix}-ide-security-group"
  vpc_id  = local.common_config.vpc_id
}

resource "aws_security_group_rule" "ide_instance_security_group_egress" {
  security_group_id   = aws_security_group.ide_instance_security_group.id
  type                = "egress"
  from_port           = 0
  to_port             = 65535
  cidr_blocks         = ["0.0.0.0/0"]
  protocol            = "all"
}

resource "aws_iam_role" "ide_instance_role" {
  name    = "${local.prefix}-ide-instance-role"
  path    = local.iam_path

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
      variable    = "aws:ResourceTag/Project"
      values      = [local.project]
    }

    condition {
      test        = "StringEquals"
      variable    = "aws:ResourceTag/Owner"
      values      = [local.owner]
    }
  }

  statement {
    sid       = "DeveloperBucketAccess"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.owner}-*",
      "arn:aws:s3:::${local.owner}-*/*",
      local.common_config.shared_bucket_arn,
      "${local.common_config.shared_bucket_arn}/*",
    ]
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

  statement {
    sid       = "DeveloperMessageAccess"
    effect    = "Allow"
    actions   = ["sts:DecodeAuthorizationMessage"]
    resources = ["*"]
  }

  statement {
    sid       = "DeveloperOpensearchAccess"
    effect    = "Allow"
    actions   = ["iam:Passrole"]
    resources = [local.common_config.elasticsearch_snapshot_role]
  }
}

resource "aws_iam_policy" "developer_access" {
  path    = local.iam_path
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

resource "aws_cloudwatch_metric_alarm" "ide_uptime_alarm" {
  alarm_name                  = "${local.owner}-ide-uptime"
  alarm_description           = "Monitor Developer IDE Uptime for ${local.prefix}"
  namespace                   = "NUL/DevEnvironment"
  metric_name                 = "ContinuousUptime"
  statistic                   = "Minimum"
  comparison_operator         = "GreaterThanOrEqualToThreshold"
  threshold                   = 16200

  dimensions = {
    Owner = local.owner
  }

  evaluation_periods          = 2
  datapoints_to_alarm         = 1
  period                      = 300
  treat_missing_data          = "notBreaching"

  alarm_actions               = [local.common_config.ide_uptime_alert_topic]
  ok_actions                  = [local.common_config.ide_uptime_alert_topic]
  insufficient_data_actions   = []
}