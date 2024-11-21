# AWS EBS Volume Migration gp2 to gp3

![Diagram](images/diagram.png)

```bash
ls -l
```

```mermaid
graph TD
    Start((Start))
    subgraph "Function - get_snapshot_state"
        get_snapshot_state
    end
    subgraph "Function - get_date_time"
        get_date_time
    end
    subgraph "List of accounts"
        loop_start((Start))
        loop_end((End))
    end
    subgraph "Assume role"
        assume_role
    end
    subgraph "Export temporary credentials"
        export_credentials
    end
    subgraph "Change Terraform role max session duration to 12 hours"
        update_role
    end
    subgraph "Get AWS regions"
        get_regions
    end
    subgraph "Loop to work on all regions"
        region_start((Start))
        region_end((End))
    end
    subgraph "Check if there is any gp2 volume"
        check_gp2_volumes
    end
    subgraph "Read the volumes"
        read_volumes
    end
    subgraph "IOPS greater than 3000"
        iops_greater_3000
    end
    subgraph "Take a snapshot"
        take_snapshot
    end
    subgraph "Check if snapshot was taken"
        check_snapshot_taken
    end
    subgraph "Genereate snapshot output"
        generate_output
    end
    subgraph "Check SnapshotState behaviour"
        check_snapshot_state
    end
    subgraph "Migrate to gp3 and maintain IOPS value"
        migrate_to_gp3
    end
    subgraph "Check migration status"
        check_migration_status
    end
    subgraph "IOPS NOT greater than 3000"
        iops_not_greater_3000
    end

    Start --> get_snapshot_state
    get_snapshot_state --> get_date_time
    get_date_time --> loop_start
    loop_start --> assume_role
    assume_role --> export_credentials
    export_credentials --> update_role
    update_role --> get_regions
    get_regions --> region_start
    region_start --> check_gp2_volumes
    check_gp2_volumes --> read_volumes
    read_volumes --> iops_greater_3000
    iops_greater_3000 --> take_snapshot
    take_snapshot --> check_snapshot_taken
    check_snapshot_taken --> generate_output
    generate_output --> check_snapshot_state
    check_snapshot_state --> migrate_to_gp3
    migrate_to_gp3 --> check_migration_status
    check_migration_status --> region_end
    region_end --> loop_end
    loop_end --> loop_start

```

