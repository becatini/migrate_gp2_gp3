#!/bin/bash

# set -x

clear

# Function - get initial snapshot state
get_snapshot_state() {
    aws ec2 describe-snapshots \
        --owner-ids self \
        --filters Name=volume-id,Values=$1 \
        --region $region \
        --query 'Snapshots[0].[State]' \
        --output text
}

# Function - get current date and time
get_date_time() {
    date +%Y-%m-%d" "%H:%M
}

# Function - get snapshot progress
get_snapshot_progress() {
    aws ec2 describe-snapshots \
        --region $region \
        --snapshot-ids $1 \
        --query 'Snapshots[].Progress' \
        --output text
}

# Set account | region
account=$1
read_region=$2

# Assume role Terraform
rolearn="arn:aws:iam::$account:role/Terraform"
assumed_role=$(aws sts assume-role \
                --role-arn $rolearn \
                --role-session-name AssumeRoleSession \
                --duration-seconds 43200 \
                --profile master \
                --query 'Credentials.{AccessKeyId:AccessKeyId,SecretAccessKey:SecretAccessKey,SessionToken:SessionToken}')
# Set up the credentials
export AWS_ACCESS_KEY_ID=$(echo $assumed_role | jq -r '.AccessKeyId')
export AWS_SECRET_ACCESS_KEY=$(echo $assumed_role | jq -r '.SecretAccessKey')
export AWS_SESSION_TOKEN=$(echo $assumed_role | jq -r '.SessionToken')

# List of valid AWS regions
aws_regions=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "af-south-1" "ap-east-1" "ap-south-1" "ap-northeast-1" "ap-northeast-2" "ap-northeast-3" "ap-southeast-1" "ap-southeast-2" "ca-central-1" "eu-central-1" "eu-west-1" "eu-west-2" "eu-south-1" "eu-west-3" "eu-north-1" "me-south-1" "sa-east-1")

# Convert the entered region to lowercase
region=$(echo $read_region | tr '[:upper:]' '[:lower:]')

# Global variables
current_date=$(date +%Y-%m-%d)
full_log="full_log_${account}_${current_date}.txt"

# Account variables
snapshot_file="${account}_${region}_snapshot_${current_date}.txt"

# Check if the entered region is valid
if [[ " ${aws_regions[@]} " =~ " ${region} " ]]; then
    
    echo "" | tee -a $full_log
    echo "Processing region: $region" | tee -a $full_log

    # Get all gp2 volumes in the region
    volume_ids=$(aws ec2 describe-volumes \
                    --filters Name=volume-type,Values=gp2 \
                    --region $region \
                    --query 'Volumes[*].[VolumeId,Iops]' \
                    --output text)

    # Check if there is any gp2 volume
    if [ -z "$volume_ids" ]; then
        echo "Region $region has no gp2 volumes" | tee -a $full_log
    else
        # Read the volumes
        echo "$volume_ids" | while read -r line; do

            # Get volumeID and IOPS
            volume_id=$(echo "$line" | awk '{print $1}')
            iops=$(echo "$line" | awk '{print $2}')

            # Take a snapshot
            echo "$(get_date_time)" | tee -a $full_log
            echo "Taking volume $volume_id snapshot..." | tee -a $full_log
            snapshot=$(aws ec2 create-snapshot \
                        --volume-id $volume_id \
                        --description "Migrate gp2 to gp3" \
                        --region $region)

            # Get snapshot ID
            current_snapshot_id=$(echo $snapshot | jq -r '.SnapshotId')
            
            # Genereate snapshot log file
            echo $snapshot | \
                jq -r '.VolumeId, .SnapshotId' | tr '\n' ' ' | \
                awk -v p1="$account" -v p2="$region" '{print p1, p2, $0}' >> $snapshot_file
        done
    fi
    # Change Terraform role max session duration back to 1hour
    aws iam update-role --role-name Terraform --max-session-duration 3600

    # Unset the assumed role credentials
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    
else
    echo "Invalid AWS region ID: $region"
fi



