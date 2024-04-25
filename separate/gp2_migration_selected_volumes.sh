#!/bin/bash

# set -x
clear

# Function - get current date and time
get_date_time() {
    date +%Y-%m-%d" "%H:%M
}

# Set account | region
account=$1
read_region=$2

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

# List of valid AWS regions
aws_regions=("us-east-1" "us-east-2" "us-west-1" "us-west-2" "af-south-1" "ap-east-1" "ap-south-1" "ap-northeast-1" "ap-northeast-2" "ap-northeast-3" "ap-southeast-1" "ap-southeast-2" "ca-central-1" "eu-central-1" "eu-west-1" "eu-west-2" "eu-south-1" "eu-west-3" "eu-north-1" "me-south-1" "sa-east-1")

# Convert the entered region to lowercase
region=$(echo $read_region | tr '[:upper:]' '[:lower:]')

# Global variables
current_date=$(date +%Y-%m-%d)
full_log="migration_full_log_${account}_${region}_${current_date}.txt"
migration_file="${account}_${region}_migration_${current_date}.txt"

# Check if the entered region is valid
if [[ "${aws_regions[@]}" =~ "${region}" ]]; then
    
    echo "" | tee -a $full_log
    echo "Processing region: $region" | tee -a $full_log    
   
    echo "$(get_date_time)" | tee -a $full_log
	
    # Read the volumes
    for volume_id in $(cat volumes.txt); do
	
        # Get IOPS
        iops=$(aws ec2 describe-volumes \
                --volume-ids $volume_id \
                --region $region \
                --query 'Volumes[*].[Iops]' \
                --output text)
	
        # Check if IOPS greater than 3000                        
        if [ "$iops" -gt 3000 ]; then
            # Migrate to gp3 and maintain IOPS value
            echo "Migrating volume $volume_id to gp3..." | tee -a $full_log
            migration=$(aws ec2 modify-volume \
                            --volume-id $volume_id \
                            --volume-type gp3 \
                            --iops $iops \
                            --region $region | \
                            jq '.VolumeModification.ModificationState' | \
                            sed 's/"//g')
            
            echo "$account $region $volume_id" >> $migration_file
            echo "Volume $volume_id type changed to gp3" | tee -a $full_log
            echo "---" | tee -a $full_log                            
	
        # Check if IOPS lower than 3000
        else
            # Migrate to gp3 and set default IOPS value (3000)
            echo "Migrating volume $volume_id to gp3..." | tee -a $full_log
            migration=$(aws ec2 modify-volume \
                            --volume-id $volume_id \
                            --volume-type gp3 \
                            --region $region | \
                            jq '.VolumeModification.ModificationState' | \
                            sed 's/"//g')
            
            echo "$account $region $volume_id" >> $migration_file
            echo "Volume $volume_id type changed to gp3" | tee -a $full_log
            echo "---" | tee -a $full_log                            
        fi            
    done
    # Unset the assumed role credentials
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    
else
    echo "Invalid AWS region ID: ${region}"
fi