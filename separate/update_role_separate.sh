#!/bin/bash

#set -x

clear

# Set master account
account=$1

rolearn="arn:aws:iam::$account:role/Terraform"

eval $(aws sts assume-role --role-arn $rolearn \
        --role-session-name TestSession \
        --profile master | \
        jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')

update_role=$(aws iam update-role --role-name Terraform --max-session-duration 43200)

echo "$account"
echo "Role max session durante updated to: ${update_role} seconds"
echo "$(aws iam get-role --role-name terraform --query 'Role.MaxSessionDuration')"
echo ""