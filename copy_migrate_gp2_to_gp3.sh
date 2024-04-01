#!/bin/bash

clear

# Function - get initial snapshot state
get_snapshot_state() {
    aws ec2 describe-snapshots \
        --owner-ids self \
        --filters Name=volume-id,Values=$volume_id \
        --region $region \
        --query 'Snapshots[0].[State]' \
        --output text
}

# Function - get current date and time
get_date_time() {
    date +%Y-%m-%d" "%H:%M
}

# List accounts
for account in $(cat account.txt); do

    # Global variables
    current_date=$(date +%Y-%m-%d)
    migration_log="migration_log_${account}_${current_date}.txt"
    migration_account_access_denied="migration_account_access_denied_${current_date}.txt"
    
    # Account variables
    snapshot_file="${account}_snapshot_${current_date}.txt"
    snapshot_error_file="${account}_snapshot_error_${current_date}.txt"
    migration_file="${account}_migration_${current_date}.txt"
    not_migrated_file="${account}_not_migrated_${current_date}.txt"

    echo "" | tee -a $migration_log
    echo "+------------------------------+" | tee -a $migration_log
    echo "Processing account: $account" | tee -a $migration_log
    echo "+------------------------------+" | tee -a $migration_log

    # Assume role Terraform
    rolearn="arn:aws:iam::$account:role/Terraform"
    check_account=$(aws sts assume-role \
                        --role-arn $rolearn \
                        --role-session-name TestSession \
                        --profile master 2>&1)
    
    # Export temporary credentials
    eval $(echo $check_account | \
    jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')

    # Change Terraform role max session duration to 12hours
    aws iam update-role --role-name Terraform --max-session-duration 43200
    check_account=$(aws sts assume-role \
                        --role-arn $rolearn \
                        --role-session-name TestSession \
                        --duration-seconds 43100 \
                        --profile master 2>&1)
    eval $(echo $check_account | \
    jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')
    
    # Get AWS regions
    aws_regions=$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text)

    # Loop to work on all regions
    for region in $aws_regions; do

        # Assume role increase durantion variables
        start=$(date +%s)
        end=$((start + 420*60))        
        
        echo "" | tee -a $migration_log
        echo "Processing region: $region" | tee -a $migration_log

        # Get all gp2 volumes in the region
        volume_ids=$(aws ec2 describe-volumes \
                        --filters Name=volume-type,Values=gp2 \
                        --region $region \
                        --query 'Volumes[*].[VolumeId,Iops]' \
                        --output text)

        # Check if there is any gp2 volume
        if [ -z "$volume_ids" ]; then        
            echo "Region $region has no gp2 volumes" | tee -a $migration_log

        else    	
            # Read the volumes
            echo "$volume_ids" | while read -r line; do

                # Assume role increase duration
                current=$(date +%s)
                if [ $end -lt $current ]; then    
                    check_account=$(aws sts assume-role --role-arn $rolearn --role-session-name TestSession --profile master 2>&1)
                    eval $(echo $check_account | \
                    jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId)\nexport AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)\nexport AWS_SESSION_TOKEN=\(.SessionToken)\n"')
                fi
                
                # Take a snapshot            
                echo "$(get_date_time)" | tee -a $migration_log
                echo "Taking volume $volume_id snapshot..." | tee -a $migration_log
                snapshot=$(aws ec2 create-snapshot \
                            --volume-id $volume_id \
                            --description "Migrate gp2 to gp3" \
                            --region $region 2>&1)                        
                    
                # Get snapshot ID
                current_snapshot_id=$(echo $snapshot | jq -r '.SnapshotId')
                    
                # Get snapshot progress
                snapshot_progress=$(aws ec2 describe-snapshots \
                                        --region $region \
                                        --snapshot-ids $current_snapshot_id \
                                        --query 'Snapshots[].Progress' \
                                        --output text)
                
                # Check if snapshot was taken
                if [ -z "$snapshot" ]; then        
                    echo "Snapshot not created from volume: $volume_id. Double-check it."                
                else                    
                    # Genereate snapshot log file
                    echo $snapshot | \
                        jq -r '.VolumeId, .SnapshotId' | tr '\n' ' ' | \
                        awk -v p1="$account" -v p2="$region" '{print p1, p2, $0}' >> $snapshot_file
                                                        
                    SnapshotState=$(get_snapshot_state)
            
                    # Check SnapshotState behaviour
                    while [ "$SnapshotState" == "pending" ]; do                                    
                        echo "Snapshot $current_snapshot_id progress is $snapshot_progress. Waiting for completion..." | tee -a $migration_log
                        sleep 10
                        SnapshotState=$(get_snapshot_state)
                    done
                    if [ "$SnapshotState" == "completed" ]; then
                        echo "Volume $volume_id snapshot state is: $SnapshotState" | tee -a $migration_log
                        
                        # Get volume ID and IOPS
                        volume_id=$(echo "$line" | awk '{print $1}')
                        iops=$(echo "$line" | awk '{print $2}')
                        
                        # Check if IOPS greater than 3000
                        if [ "$iops" -gt 3000 ]; then                        
                            # Migrate to gp3 and maintain IOPS value
                            echo "Migrating volume $volume_id to gp3..." | tee -a $migration_log
                            migration=$(aws ec2 modify-volume \
                                            --volume-id $volume_id \
                                            --volume-type gp3 \
                                            --iops $iops \
                                            --region $region | \
                                            jq '.VolumeModification.ModificationState' | \
                                            sed 's/"//g')                                    
                            # Check migration status                
                            if [ $? -eq 0 ] && [ "$migration" == "modifying" ];then
                                echo "$account $region $volume_id" >> $migration_file
                                echo "Volume $volume_id type changed to gp3" | tee -a $migration_log
                                echo "---" | tee -a $migration_log
                            else
                                echo "ERROR: couldn't change volume ${volume_id} type to gp3!" | tee -a $migration_log
                                echo "$account $region $volume_id" >> $not_migrated_file
                                read -p "Press any key to resume ..."
                            fi
                        
                        # Check if IOPS lower than 3000
                        else
                            # Migrate to gp3 and set default IOPS value (3000)
                            echo "Migrating volume $volume_id to gp3..." | tee -a $migration_log
                            migration=$(aws ec2 modify-volume \
                                            --volume-id $volume_id \
                                            --volume-type gp3 \
                                            --region $region | \
                                            jq '.VolumeModification.ModificationState' | \
                                            sed 's/"//g')                                    
                            # Check migration status                
                            if [ $? -eq 0 ] && [ "$migration" == "modifying" ];then
                                echo "$account $region $volume_id" >> $migration_file
                                echo "Volume $volume_id type changed to gp3" | tee -a $migration_log
                                echo "---" | tee -a $migration_log
                            else
                                echo "ERROR: couldn't change volume ${volume_id} type to gp3!" | tee -a $migration_log
                                echo "$account $region $volume_id" >> $not_migrated_file
                                read -p "Press any key to resume ..."
                            fi
                        fi
                    
                    # Snapshot not completed
                    elif [ "$SnapshotState" != "completed" && "$SnapshotState" != "pending" ]; then
                        echo "Snapshot NOT TAKEN. State is now $SnapshotState." | tee -a $migration_log
                        echo "Volume $volume_id WILL NOT be migrated" | tee -a $migration_log
                        echo "$account $region $volume_id" >> $snapshot_error_file
                        read -p "Press any key to resume ..."
                    fi
                fi
            done
        fi
    done
    # Change Terraform role max session duration back to 1hour
    aws iam update-role --role-name Terraform --max-session-duration 3600
done