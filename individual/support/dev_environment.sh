next_page() {
  SSM_PREFIX=/dev-environment/config/
  cmd="aws ssm get-parameters-by-path --path $SSM_PREFIX --recursive --with-decryption"
  if [[ -n $next_token && $next_token != "null" ]]; then
    cmd="$cmd --next-token $next_token"
  fi
  params=$($(echo $cmd))
  vars=$(jq -r '.Parameters[] | (.Name | sub("^'$SSM_PREFIX'"; "") | gsub("[/-]"; "_") | ascii_upcase) as $name | "DEV_\($name)=\(.Value)"' <<< $params)
  while read -r setting; do
    if 
    export eval $setting
  done <<< $vars
  next_token=$(jq '.NextToken' <<< $params)
}

next_token=""
while [[ $next_token != "null" ]]; do
  next_page
done

instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
export DEV_PREFIX=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Owner" | jq -r '.Tags[].Value')
