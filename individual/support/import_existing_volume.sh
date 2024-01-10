#!/bin/bash

owner=$(terraform workspace show)
volume_id=$(aws ec2 describe-volumes --filter Name=tag:Project,Values=dev-environment Name=tag:Owner,Values=$(terraform workspace show) Name=tag:Device,Values=home --query 'Volumes[*].VolumeId' --output text)
instance_id=$(aws ec2 describe-instances --filter Name=tag:Project,Values=dev-environment Name=tag:Owner,Values=$owner Name=instance-state-name,Values=pending,running,shutting-down,stopping,stopped --query 'Reservations[*].Instances[*].InstanceId' --output text)
terraform import aws_ebs_volume.home_device $volume_id
terraform import aws_volume_attachment.home_device /dev/sdf:$volume_id:$instance_id
