#!/bin/bash

AWS_PROFILE=staging
aws-adfs login --profile $AWS_PROFILE
aws_config=$(aws secretsmanager get-secret-value --secret-id dev-environment/common/ide-session-key --query SecretString --output text)

aws --profile dev-environment configure set region us-east-1
for var in aws_access_key_id aws_secret_access_key; do
  aws --profile dev-environment configure set $var $(jq -r ".$var" <<< $aws_config)
done
