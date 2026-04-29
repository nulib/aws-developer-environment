#!/bin/bash

MAX_ITERATION=5
SLEEP_DURATION=5

echo "Starting Tailscale Proxy with params $@" >&2

# Arguments passed from SSH client
HOST=$1
PORT=$2

ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
if [ -e $HOME/.local/bin/mise ]; then
  eval "$($HOME/.local/bin/mise activate bash)"
elif [ -e ${ASDF_DATA_DIR}/shims ]; then
  export PATH="${ASDF_DATA_DIR}/shims:$PATH"
fi
if ! grep -q "/usr/local/bin" <<< "$PATH"; then
  export PATH="$PATH:/usr/local/bin"
fi

if [[ -x $AWS_COMMAND ]]; then
  true # noop
elif (type aws > /dev/null) && [[ -x $(which aws) ]]; then
  AWS_COMMAND=$(which aws)
elif [[ -x /usr/local/bin/aws ]]; then
  AWS_COMMAND=/usr/local/bin/aws
elif [[ -x /usr/bin/aws ]]; then
  AWS_COMMAND=/usr/bin/aws
fi

if [[ $HOST =~ ^([^.]+)\.dev\.rdc\.library\.northwestern\.edu$ ]]; then
  export OWNER=${BASH_REMATCH[1]}
  export PROJECT=dev-environment
  export AWS_PROFILE=dev-environment
  export AWS_REGION=us-east-1

  HOST=$($AWS_COMMAND --profile $AWS_PROFILE ec2 describe-instances --filters "Name=tag:Owner,Values=${OWNER}" "Name=tag:Project,Values=${PROJECT}" "Name=instance-state-name,Values=pending,running,stopping,stopped" --query 'Reservations[].Instances[].InstanceId | [0]' --output text)
  if [[ $HOST == "None" ]]; then
    echo "Unable to find instance for owner ${OWNER} in project ${PROJECT}."
    exit 255
  fi
fi

STATUS=$($AWS_COMMAND --profile $AWS_PROFILE ssm describe-instance-information --filters Key=InstanceIds,Values=${HOST} --output text --query 'InstanceInformationList[0].PingStatus' --profile ${AWS_PROFILE} --region ${AWS_REGION})

login() {
  exec nc $OWNER $PORT
}

# If the instance is online, start the session
if [ $STATUS == 'Online' ]; then
    login
else
    # Instance is offline - start the instance
    $AWS_COMMAND ec2 start-instances --instance-ids $HOST --profile ${AWS_PROFILE} --region ${AWS_REGION}
    sleep ${SLEEP_DURATION}
    COUNT=0
    while [ ${COUNT} -le ${MAX_ITERATION} ]; do
        STATUS=$($AWS_COMMAND --profile $AWS_PROFILE ssm describe-instance-information --filters Key=InstanceIds,Values=${HOST} --output text --query 'InstanceInformationList[0].PingStatus' --profile ${AWS_PROFILE} --region ${AWS_REGION})
        if [ ${STATUS} == 'Online' ]; then
            break
        fi
        # Max attempts reached, exit
        if [ ${COUNT} -eq ${MAX_ITERATION} ]; then
            exit 1
        else
            let COUNT=COUNT+1
            sleep ${SLEEP_DURATION}
        fi
    done
    # Instance is online now - start the session
    login
fi
