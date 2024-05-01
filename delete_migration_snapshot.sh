#!/bin/bash

# set -x

# Function - get current date and time
get_date_time() {
    date +%Y-%m-%d" "%H:%M
}

# List all active accounts in the organization
#for account in $(aws organizations list-accounts --query 'Accounts[?Status==`ACTIVE`].Id' --profile master --output text);
account=$1
do

    # Global variables
    current_date=$(date +%Y-%m-%d)
    full_log="full_log_${account}_${current_date}.txt"

    echo "" | tee -a $full_log
    echo "+------------------------------+" | tee -a $full_log
    echo "Processing account: $account"     | tee -a $full_log
    echo "+------------------------------+" | tee -a $full_log
       
    # Assume role Terraform
    rolearn="arn:aws:iam::$account:role/Terraform"
    assumed_role=$(aws sts assume-role \
                    --role-arn $rolearn \
                    --role-session-name AssumeRoleSession \
                    --profile master \
                    --query 'Credentials.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey,SessionToken:SessionToken}')
    # Set up the credentials
    export AWS_ACCESS_KEY_ID=$(echo $assumed_role | jq -r '.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo $assumed_role | jq -r '.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo $assumed_role | jq -r '.SessionToken')

    # Get AWS regions
    aws_regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

    # Loop to work on all regions
    for region in $aws_regions; do

        echo "" | tee -a $full_log
        echo "Processing region: $region" | tee -a $full_log

        # Get all snapshots with description "Migrate gp2 to gp3"
        snapshots=$(aws ec2 describe-snapshots 
                        --region $region 
                        --owner-ids $account 
                        --filters Name=description,Values="Migrate gp2 to gp3" 
                        --query 'Snapshots[*].SnapshotId' 
                        --output text)

        # Check if there is any pre-migration snapshots
        if [ -z "$snapshots" ]; then
            echo "Region $region has no pre-migration snapshots" | tee -a $full_log

        else
            echo "$(get_date_time)" | tee -a $full_log
            echo "Deleting snapshot ID..." | tee -a $full_log
            # Read the snapshots
            echo "$snapshots" | while read -r line; do
                
                snapshot_id=$(echo "$line" | awk '{print $1}')
                
                # Delete snapshot
                echo "${snapshot_id}"
                aws ec2 delete-snapshot --region $region --snapshot-id ${snapshot_id}                
            done
        fi
    done

    # Unset the assumed role credentials
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
done