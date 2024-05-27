# Take Snapshot and Migrate EBS Volumes Pre-selected

Here we have two scripts which contains the code to take snapshot, and then migrate the volume from gp2 to gp3.

gp2_snapshot_selected_volumes.sh -> take volumes snapshot
gp2_migration_selected_volumes.sh -> migrate volumes to gp3


## The Tool

Make sure you create the file *volumes.txt* in the same path the scripts will be executed.

A full log will be created showing all snapshots taken and all volumes migrated.

## Tool Execution
./gp2_snapshot_selected_volumes.sh account_id region_id

./gp2_migration_selected_volumes.sh account_id region_id

