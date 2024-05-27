# AWS EBS Volume Migration from gp2 to gp3

This repository contains the code to migrate AWS EBS volumes from gp2 to gp3. 

By migrating to gp3, we can save up to 20% lower price-point per GB than existing gp2 volumes.

## The Tool

This bash script will read the file _account.txt_ **which must contain all AWS accounts with the volumes to be migrated**. _The script was created this way due to the necessity of splitting the accounts to be migrated in 3 differente phases._

**Make sure the accounts.txt file is created in the same path the script will be executed.**

It will run over each region on all accounts (mentioned on the account.txt) searching for gp2 volumes.

For each found volume, a snapshot will be taken.

If snapshot completes successfully, the migrations starts.

Then it checks IOPS value. If its grater than 3000, the volume is migrated with the current IOPS value.


## Diagram

![Diagram](images/diagram.png)

## Flow chart

```mermaid
graph TD
    A[Start]     

    A --> F[Read accounts from account.txt]

    F -->|For each account| I[Print account]
    
    I --> J[Assume role]
    J -->|Check if assumed role is valid| K{Valid role?}
    K -->|Yes| L[Set up temporary credentials]
    K -->|No| M[Log account access denied]
    
    L --> N[Get AWS regions]

    N -->|For each region| P[Get all gp2 volumes]
    
    P -->|Check if any gp2 volumes exist| Q{gp2 volumes exist?}
    Q -->|Yes| R[Read EACH volume]
    Q -->|No| S[Log: NO gp2 volumes in region]

    R --> U[Take a snapshot]
    
    U -->|Check if snapshot was taken| V{Snapshot taken successfully?}
    V -->|Yes| W[Generate snapshot log file]
    V -->|No| X[Log: snapshot not created]

    W --> Y[Get snapshot state]
    
    Y -->|Check snapshot state| Z{Snapshot state}
    Z -->|Pending| AA[Get snapshot progress]
    AA -->|While pending| BB[Wait and check progress]
    BB --> Y

    Z -->|Completed| CC[Check if IOPS > 3000]
    
    CC -->|Yes| DD[Migrate to gp3 - keep current IOPS]
    CC -->|No| EE[Migrate to gp3 - default IOPS value]
    
    DD -->|Check migration status| FF{Migration status?}
    EE -->|Check migration status| GG{Migration status?}

    FF -->|Success| HH[Log: migration success]
    FF -->|Fail| II[Log: migration failure]

    GG -->|Success| JJ[Log migration success]
    GG -->|Fail| II

    Z -->|Not pending or not completed| LL[Log: snapshot error]
    
    LL --> X

    S --> N
    HH --> N
    JJ --> N
    II --> N
    
    N -->|All regions processed| MM[Unset assumed role credentials]
    MM --> F

    F -->|All accounts processed| NN[End]
```
<br>

## Tool Execution

![Diagram](images/run_script.png)

## Logs

The tool generates three logs.

1. Snapshot taken before before migration. 
It will show account ID, region, volume ID and snapshot ID.
![Diagram](images/snapshot.png)

2. Volumes migrated.
It will show account ID, region and volume ID.
![Diagram](images/migration.png)

3. Full log during execution.
![Diagram](images/full_log.png)