#!/bin/bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

# Configuration
# Change these values to reflect your environment
# AWS_PROFILE=
# AWS_REGION=
MAX_ITERATION=5
SLEEP_DURATION=5

# Arguments passed from SSH client
HOST=$1
PORT=$2

export PATH=$HOME/.asdf/shims:$HOME/.asdf/bin:/usr/local/bin:$PATH

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

# If the instance is online, start the session
if [ $STATUS == 'Online' ]; then
    $AWS_COMMAND ssm start-session --target $HOST --document-name AWS-StartSSHSession --parameters portNumber=${PORT} --profile ${AWS_PROFILE} --region ${AWS_REGION}
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
    $AWS_COMMAND ssm start-session --target $HOST --document-name AWS-StartSSHSession --parameters portNumber=${PORT} --profile ${AWS_PROFILE} --region ${AWS_REGION}
fi
