data "aws_ami" "fedora_linux" {
  most_recent   = true
  owners        = [125523088429]
  name_regex    = "^Fedora-Cloud-Base-39-.+-gp3-.+$"
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
  ami             = data.aws_ami.fedora_linux.image_id
  instance_type   = var.ide_instance_type

  disable_api_termination                 = true
  instance_initiated_shutdown_behavior    = "stop"
  hibernation                             = false

  availability_zone             = data.aws_subnet.ide_instance_subnet.availability_zone
  subnet_id                     = data.aws_subnet.ide_instance_subnet.id
  iam_instance_profile          = aws_iam_instance_profile.ide_instance_profile.name
  security_groups               = [aws_security_group.ide_instance_security_group.id]
  associate_public_ip_address   = true

  # Root volume
  root_block_device {
    encrypted               = false
    delete_on_termination   = true
    volume_size             = 20
    volume_type             = "gp3"
    throughput              = 125

    tags = merge(
      lookup(var.user_tags, local.owner, {}),
      local.tags,
      { 
        Name   = "${local.owner}-dev-environment-ide"
        Device = "root"
      }
    )
  }

  user_data = file("${path.module}/support/fedora-39-init.sh")

  tags = merge(
    lookup(var.user_tags, local.owner, {}),
    { 
      Name = "${local.owner}-dev-environment-ide"
    }
  )

  lifecycle {
    ignore_changes = all
  }
}

resource "aws_ebs_volume" "home_device" {
  availability_zone   = aws_instance.ide_instance.availability_zone
  encrypted           = false
  size                = 150
  type                = "gp3"
  throughput          = 125

  tags = merge(
    lookup(var.user_tags, local.owner, {}),
    { 
      Name   = "${local.owner}-dev-environment-ide"
      Device = "home"
    }
  )
}

resource "aws_volume_attachment" "home_device" {
  device_name = "/dev/sdf"
  instance_id = aws_instance.ide_instance.id
  volume_id   = aws_ebs_volume.home_device.id
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
  }

  statement {
    sid       = "DeveloperBucketAccess"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.owner}-*",
      "arn:aws:s3:::${local.owner}-*/*",
      "arn:aws:s3:::${local.project}-shared-*",
      "arn:aws:s3:::${local.project}-shared-*/*",
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
    sid       = "DeveloperMediaConvert"
    effect    = "Allow"
    actions   = [
      "events:PutRule",
      "events:PutTargets",
      "logs:*",
      "mediaconvert:CancelJob",
      "mediaconvert:CreateJob",
      "mediaconvert:DescribeEndpoints",
      "mediaconvert:GetJob",
      "mediaconvert:GetQueue"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DeveloperPassRoles"
    effect    = "Allow"
    actions   = ["iam:Passrole"]
    resources = [
      local.common_config.elasticsearch_snapshot_role,
      local.common_config.transcode_role,
      data.aws_iam_role.pipeline_lambda_role.arn
    ]
  }

  statement {
    sid       = "DeveloperECSAccess"
    effect    = "Allow"
    actions   = [
      "ecs:Describe*",
      "ecs:List*",
      "ecs:RunTask",
      "ecs:StartTask",
      "ecs:StopTask",
      "ecs:UpdateService"
    ]
    resources = [
      "arn:aws:ecs:us-east-1:625046682746:cluster/dev-environment",
      "arn:aws:ecs:us-east-1:625046682746:service/dev-environment/*",
      "arn:aws:ecs:us-east-1:625046682746:task/dev-environment/*",
    ]
  }

  statement {
    sid       = "DeveloperCloudFrontDistributionAccess"
    effect    = "Allow"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [
      "arn:aws:cloudfront:${local.regional_id}::distribution/${local.common_config.iiif_distribution_id}"
    ]
  }

  statement {
    sid       = "DeveloperSagemakerInvokeAccess"
    effect    = "Allow"
    actions   = ["sagemaker:InvokeEndpoint"]
    resources = ["*"]
  }

  statement {
    sid       = "DeveloperBedrockInvokeAccess"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
    resources = ["*"]
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