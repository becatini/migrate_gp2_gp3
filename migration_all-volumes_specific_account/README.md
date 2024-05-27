# Snapshot and Migration of All EBS Volumes from Specific Account and Region

Here we have two scripts which contains the code to take snapshot, and then migrate the volume from gp2 to gp3.

When executing both snapshot or migration scripts, you have to provide **account_id** and **region name**.

gp2_snapshot_specific_account.sh -> take volumes snapshot
gp2_migration_specific_account.sh -> migrate volumes to gp3


## The Tool

Make sure all **snapshots are completed** before running migrations script.

A full log will be created showing all snapshots taken and all volumes migrated.

## Tool Execution
./gp2_snapshot_specific_account.sh account_id region_id

./gp2_migration_specific_account.sh account_id region_id

