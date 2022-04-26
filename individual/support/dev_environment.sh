instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
export DEV_PREFIX=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Owner" | jq -r '.Tags[].Value')
export DEV_ENV=dev
