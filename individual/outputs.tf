output "ide_instance_profile_arn" {
  value = aws_iam_instance_profile.ide_instance_profile.arn
}

output "ide_instance_role_name" {
  value = aws_iam_role.ide_instance_role.name
}