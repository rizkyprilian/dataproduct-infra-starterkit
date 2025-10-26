# CloudNativePG Database Recovery Guide

This guide explains how to recover a PostgreSQL database from a backup using the cnpg-database Helm chart.

## Overview

The chart supports two bootstrap modes:
1. **initdb** (default): Creates a new database from scratch
2. **recovery**: Restores from an existing backup

## Recovery Methods

### Method 1: Recovery from a Backup Object

If you have a `Backup` resource already created in your namespace:

```yaml
bootstrapDB:
  recovery:
    source: origin  # Not used for Backup object, but required
    backup:
      name: backup-example  # Name of the Backup resource
    database: app  # Optional: specify if different from backup
    owner: app     # Optional: specify if different from backup
```

### Method 2: Recovery from Object Store (S3/GCS)

To recover from backups stored in an object store, you need to define an `externalClusters` entry:

```yaml
bootstrapDB:
  recovery:
    source: origin  # Must match the name in externalClusters
    database: app   # Optional
    owner: app      # Optional

externalClusters:
  - name: origin
    plugin:
      name: barman-cloud.cloudnative-pg.io
      parameters:
        barmanObjectName: cluster-example-backup  # ObjectStore resource name
        serverName: cluster-example  # Original cluster name from backup
```

**Note**: The `externalClusters` configuration references the object store settings already defined in the `backup` section of your values.yaml.

## Point-in-Time Recovery (PITR)

You can recover to a specific point in time instead of the latest backup. Add a `recoveryTarget` to your recovery configuration:

### Recover to a Specific Timestamp

```yaml
bootstrapDB:
  recovery:
    source: origin
    recoveryTarget:
      targetTime: "2024-01-15 10:00:00.000000+00"
```

### Recover to a Transaction ID

```yaml
bootstrapDB:
  recovery:
    source: origin
    recoveryTarget:
      targetXID: "12345"
```

### Recover to a Named Restore Point

```yaml
bootstrapDB:
  recovery:
    source: origin
    recoveryTarget:
      targetName: "before_migration"
```

### Recover to a Log Sequence Number (LSN)

```yaml
bootstrapDB:
  recovery:
    source: origin
    recoveryTarget:
      targetLSN: "0/3000000"
```

### Recover to Earliest Consistent Point

```yaml
bootstrapDB:
  recovery:
    source: origin
    recoveryTarget:
      targetImmediate: true
```

## Complete Example: Recovery from S3 Backup

Here's a complete example for recovering from an S3 backup with PITR:

```yaml
bootstrapDB:
  # Comment out or remove initdb settings when using recovery
  # database: app
  # dbOwner: app
  # postInitSQL: []
  
  recovery:
    source: origin
    database: app
    owner: app
    recoveryTarget:
      targetTime: "2024-10-22 08:00:00.000000+00"

externalClusters:
  - name: origin
    plugin:
      name: barman-cloud.cloudnative-pg.io
      parameters:
        barmanObjectName: cluster-example-backup
        serverName: cluster-example

# Ensure backup configuration matches your original cluster
backup:
  enabled: true
  retentionPolicy: "30d"
  s3:
    enabled: true
    destinationPath: "s3://your-bucket-name/"
    endpointURL: "https://s3.amazonaws.com"
    walCompression: "gzip"
    dataCompression: "gzip"
    credentials:
      accessKeyExistingSecret: "s3-credentials"
      secretKeyExistingSecret: "s3-credentials"
```

## Important Notes

1. **Mutually Exclusive**: When `recovery` is defined under `bootstrapDB`, the `initdb` settings are ignored.

2. **Database Credentials**: The recovery process will use the database name and owner from the backup. If you need different values, explicitly set `database` and `owner` in the recovery section.

3. **Secrets**: Ensure that any secrets (like S3 credentials) referenced in your backup configuration exist in the namespace before deploying.

4. **WAL Archive**: PITR requires a WAL archive. Ensure your backup configuration includes WAL archiving.

5. **First Deployment**: Recovery can only be used during the initial deployment of a cluster. You cannot switch an existing cluster from initdb to recovery mode.

6. **ObjectStore Resource**: When using the Barman Cloud Plugin, you may need to create an `ObjectStore` custom resource. Refer to the [CloudNativePG Barman Cloud Plugin documentation](https://cloudnative-pg.io/plugin-barman-cloud/docs/concepts/) for details.

## Workflow Example

### Step 1: Identify the Backup

List available backups:
```bash
kubectl get backups -n your-namespace
```

### Step 2: Update values.yaml

Uncomment and configure the recovery section in your `values.yaml`:

```yaml
bootstrapDB:
  recovery:
    source: origin
    # Add other recovery options as needed
```

### Step 3: Deploy the Chart

```bash
helm install my-restored-db ./cnpg-database -f values.yaml -n your-namespace
```

### Step 4: Monitor Recovery

Check the cluster status:
```bash
kubectl get cluster -n your-namespace
kubectl describe cluster cluster-my-restored-db -n your-namespace
```

Check pod logs:
```bash
kubectl logs cluster-my-restored-db-1 -n your-namespace
```

## Troubleshooting

### Recovery Fails to Start

- Verify the backup exists: `kubectl get backup <backup-name>`
- Check S3/GCS credentials are valid
- Ensure the object store path is correct

### Recovery Stuck

- Check pod logs for errors
- Verify WAL files are accessible in the object store
- Ensure sufficient storage space

### Database Name Mismatch

If the recovered database has a different name than expected, explicitly set:
```yaml
bootstrapDB:
  recovery:
    database: your-expected-db-name
    owner: your-expected-owner
```

## References

- [CloudNativePG Recovery Documentation](https://cloudnative-pg.io/documentation/current/recovery/)
- [CloudNativePG Backup Documentation](https://cloudnative-pg.io/documentation/current/backup_recovery/)
- [Barman Cloud Plugin](https://cloudnative-pg.io/plugin-barman-cloud/)
