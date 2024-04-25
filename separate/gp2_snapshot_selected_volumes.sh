#!/bin/bash

# set -x
clear

# Function - get current date and time
get_date_time() {
    date +%Y-%m-%d" "%H:%M
}

get_snapshot_state() {
    aws ec2 describe-snapshots \
        --owner-ids self \
        --region $region \
        --filters Name=description,Values="Migrate gp2 to gp3" Name=status,Values=pending \
        --query 'Snapshots[].[SnapshotId,Progress,VolumeId]' \
        --output text
}

# Set account | region
account="364212806617"
region="us-west-2"

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

# Global variables
current_date=$(date +%Y-%m-%d)
full_log="snapshot_full_log_${account}_${region}_${current_date}.txt"

# Account variables
snapshot_file="${account}_${region}_snapshot_${current_date}.txt"
    
    echo "" | tee -a $full_log
    echo "Processing region: $region" | tee -a $full_log    

        echo "$(get_date_time)" | tee -a $full_log
        
        # Read the volumes
        for volume_id in $(cat volumes.txt); do            

            # Take a snapshot            
            echo "Taking volume $volume_id snapshot..." | tee -a $full_log
            snapshot=$(aws ec2 create-snapshot \
                        --volume-id $volume_id \
                        --description "Migrate gp2 to gp3" \
                        --region $region)

            # Get snapshot ID
            current_snapshot_id=$(echo $snapshot | jq -r '.SnapshotId')
            echo "Snapshot ${current_snapshot_id} created" | tee -a $full_log
            echo "---" | tee -a $full_log
            
            # Genereate snapshot log file
            echo $snapshot | \
                jq -r '.VolumeId, .SnapshotId' | tr '\n' ' ' | \
                awk -v p1="$account" -v p2="$region" '{print p1, p2, $0}' >> $snapshot_file            
        done  
    # Unset the assumed role credentials
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN