locals {
  tags = merge(var.tags, {
    project   = "dev-environment"
    owner     = var.user_net_id
  })
  prefix = var.user_net_id
}

data "aws_ami" "cloud9_amz_linux2" {
  most_recent = true

  filter {
    name = "name"
    values = ["Cloud9AmazonLinux2-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["327094444948"]
}

resource "aws_instance" "cloud9_ide_instance" {
  ami                     = data.aws_ami.cloud9_amz_linux2.id
  instance_type           = "t3.large"
  iam_instance_profile    = aws_iam_instance_profile.ide_instance_profile.name

  tags = local.tags

  # Ignore everything because this resource is actually managed by
  # Cloud9. We just need to change the root volume size.
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [
      ami, associate_public_ip_address, availability_zone, 
      capacity_reservation_specification, cpu_core_count, cpu_threads_per_core, 
      credit_specification, disable_api_termination, ebs_block_device, 
      ebs_optimized, enclave_options, ephemeral_block_device, 
      get_password_data, hibernation, host_id, 
      instance_initiated_shutdown_behavior, instance_type, 
      ipv6_address_count, ipv6_addresses, key_name, 
      launch_template, metadata_options, monitoring, 
      network_interface, placement_group, placement_partition_number, 
      private_ip, root_block_device, secondary_private_ips, 
      security_groups, source_dest_check, subnet_id, 
      tags, tenancy, user_data, user_data_base64,
      user_data_replace_on_change, volume_tags, vpc_security_group_ids
    ]
  }
}

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

data "aws_iam_policy_document" "owner_full_access" {
  statement {
    sid       = "OwnerFullAccess"
    effect    = "Allow"
    actions   = ["*"]
    resources = flatten([
      aws_media_convert_queue.transcode_queue.arn,
      [for bucket in values(aws_s3_bucket.meadow_buckets)[*]: [bucket.arn, "${bucket.arn}/*"]],
      [for topic  in values(aws_sns_topic.sequins_topics)[*]: topic.arn],
      [for queue  in values(aws_sqs_queue.sequins_queues)[*]: queue.arn]
    ])
  }
}

resource "aws_iam_policy" "owner_full_access" {
  name    = "${local.prefix}-owner-full-access"
  policy  = data.aws_iam_policy_document.owner_full_access.json
  tags    = local.tags
}

resource "aws_iam_role_policy_attachment" "read_only_access" {
  role          = aws_iam_role.ide_instance_role.name
  policy_arn    = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "owner_full_access" {
  role          = aws_iam_role.ide_instance_role.name
  policy_arn    = aws_iam_policy.owner_full_access.arn
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
