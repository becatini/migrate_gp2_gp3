# Snapshot and Migration of Pre-selected EBS Volumes 

Here we have two scripts which contains the code to take snapshot, and then migrate the volume from gp2 to gp3.

When executing both snapshot or migration scripts, you have to provide **account_id** and **region name**.

Both scripts will be executed on the specific account and specific region provided, and will work only on the volumes provided on **volumes.txt file**.

gp2_snapshot_selected_volumes.sh -> take volumes snapshot
gp2_migration_selected_volumes.sh -> migrate volumes to gp3


## The Tool

Make sure you create the file *volumes.txt* in the same path the scripts will be executed.

Make sure all **snapshots are completed** before running migrations script.

A full log will be created showing all snapshots taken and all volumes migrated.

## Tool Execution
./gp2_snapshot_selected_volumes.sh account_id region_id

./gp2_migration_selected_volumes.sh account_id region_id

