# CloudNativePG pg_basebackup Bootstrap Guide

This guide explains how to clone a PostgreSQL database from a live cluster using the `pg_basebackup` bootstrap method.

## Overview

The `pg_basebackup` method creates a new cluster as an exact physical copy of an existing PostgreSQL instance through streaming replication. This is useful for:

- **Reporting/BI clusters** that need periodic regeneration
- **Test databases** with live data requiring regular refresh
- **Rapid spin-up** of standalone replica clusters
- **Physical migrations** to different namespaces or Kubernetes clusters

## Requirements

Before using `pg_basebackup`, ensure:

1. **Same hardware architecture** between source and target
2. **Same PostgreSQL major version** (e.g., both PostgreSQL 16)
3. **Same tablespaces** configuration
4. **Sufficient `max_wal_senders`** on source cluster (at least 2: one for backup, one for WAL streaming)
5. **Network connectivity** from target to source PostgreSQL port
6. **Replication user** with `REPLICATION LOGIN` privileges on source
7. **pg_hba.conf** configured on source to accept replication connections

## Authentication Methods

### Method 1: Username/Password Authentication

This method uses a username and password for authentication.

#### Configuration Example

```yaml
bootstrapDB:
  pg_basebackup:
    source: source-cluster
    database: app
    owner: app
    secret:
      name: app-secret  # Optional: update password after clone

externalClusters:
  - name: source-cluster
    connectionParameters:
      host: source-cluster-rw.default.svc.cluster.local
      user: streaming_replica
      dbname: postgres
    password:
      name: source-cluster-replica-user
      key: password
```

#### Create the Password Secret

```bash
kubectl create secret generic source-cluster-replica-user \
  --from-literal=password='your-replication-password' \
  -n your-namespace
```

#### Source Cluster Configuration

On the source cluster, ensure `pg_hba.conf` allows replication connections:

```
# Allow replication connections (use more restrictive rules in production)
host replication streaming_replica all md5
```

### Method 2: TLS Certificate Authentication (Recommended)

This method uses TLS client certificates for authentication, providing better security.

#### Configuration Example

```yaml
bootstrapDB:
  pg_basebackup:
    source: source-cluster
    database: app
    owner: app

externalClusters:
  - name: source-cluster
    connectionParameters:
      host: source-cluster-rw.default.svc.cluster.local
      user: streaming_replica
      sslmode: verify-full
    sslKey:
      name: source-cluster-replication
      key: tls.key
    sslCert:
      name: source-cluster-replication
      key: tls.crt
    sslRootCert:
      name: source-cluster-ca
      key: ca.crt
```

#### Copy Certificates from Source Cluster

If cloning from another CloudNativePG cluster in the same Kubernetes cluster:

```bash
# Copy replication certificate
kubectl get secret source-cluster-replication -n source-namespace -o yaml | \
  sed 's/namespace: source-namespace/namespace: target-namespace/' | \
  kubectl apply -f -

# Copy CA certificate
kubectl get secret source-cluster-ca -n source-namespace -o yaml | \
  sed 's/namespace: source-namespace/namespace: target-namespace/' | \
  kubectl apply -f -
```

## Complete Examples

### Example 1: Clone from Another CloudNativePG Cluster (Same Namespace)

```yaml
instances: 3
imageName: ghcr.io/cloudnative-pg/postgresql:16.2-3

storage:
  size: 10Gi
  storageClass: "ceph-blockpool-ssd-erasurecoded"

bootstrapDB:
  pg_basebackup:
    source: production-db
    database: app
    owner: app
    secret:
      name: app-secret

externalClusters:
  - name: production-db
    connectionParameters:
      host: cluster-production-db-rw.default.svc.cluster.local
      user: streaming_replica
      sslmode: verify-full
    sslKey:
      name: production-db-replication
      key: tls.key
    sslCert:
      name: production-db-replication
      key: tls.crt
    sslRootCert:
      name: production-db-ca
      key: ca.crt
```

### Example 2: Clone from External PostgreSQL Server

```yaml
instances: 1
imageName: ghcr.io/cloudnative-pg/postgresql:16.2-3

storage:
  size: 5Gi
  storageClass: "standard"

bootstrapDB:
  pg_basebackup:
    source: external-postgres
    database: myapp
    owner: myapp

externalClusters:
  - name: external-postgres
    connectionParameters:
      host: postgres.example.com
      port: "5432"
      user: streaming_replica
      dbname: postgres
    password:
      name: external-postgres-replication
      key: password
```

### Example 3: Weekly Test Database Refresh

For a test database that gets refreshed weekly from production:

```yaml
instances: 1
imageName: ghcr.io/cloudnative-pg/postgresql:16.2-3

storage:
  size: 20Gi
  storageClass: "standard"

bootstrapDB:
  pg_basebackup:
    source: production-db
    database: app
    owner: app
    secret:
      name: test-db-secret  # Different credentials for test

externalClusters:
  - name: production-db
    connectionParameters:
      host: cluster-production-db-rw.production.svc.cluster.local
      user: streaming_replica
      sslmode: verify-full
    sslKey:
      name: production-db-replication
      key: tls.key
    sslCert:
      name: production-db-replication
      key: tls.crt
    sslRootCert:
      name: production-db-ca
      key: ca.crt

# Disable backups for test database
backup:
  enabled: false
```

## Application Database Configuration

After cloning, you can configure the application database and credentials:

```yaml
bootstrapDB:
  pg_basebackup:
    source: source-cluster
    database: app      # Database name
    owner: app         # Owner username
    secret:
      name: app-secret # Secret containing new credentials
```

The secret should contain:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
type: kubernetes.io/basic-auth
stringData:
  username: app
  password: new-secure-password
```

After bootstrap completes:
1. If the database doesn't exist, it will be created
2. If the user doesn't exist, it will be created
3. If the user isn't the owner, ownership will be granted
4. If username matches, the password will be updated

## Important Considerations

### Snapshot Behavior

`pg_basebackup` creates a **snapshot** of the source cluster:
- The clone diverges immediately after completion
- It's **not** a continuous replica
- For continuous replication, use replica clusters instead

### Downtime Planning

For migrations:
1. **Stop writes** to the source before cloning
2. **Test the procedure** multiple times
3. **Measure downtime** systematically
4. **Verify applications** work with the cloned database

### Network Requirements

Ensure network connectivity:
- Target must reach source PostgreSQL port (default 5432)
- Configure NetworkPolicies if using network isolation
- Consider bandwidth for large databases

### Source Cluster Impact

During cloning:
- Consumes one `max_wal_senders` slot
- Generates network traffic
- May impact source performance
- Plan during low-traffic periods

## Workflow Example

### Step 1: Prepare Source Cluster

Verify replication user exists:

```bash
kubectl exec -it cluster-source-db-1 -n source-namespace -- \
  psql -U postgres -c "\du streaming_replica"
```

### Step 2: Copy Secrets (if using TLS)

```bash
# Copy replication certificate
kubectl get secret source-db-replication -n source-namespace -o yaml | \
  sed 's/namespace: source-namespace/namespace: target-namespace/' | \
  kubectl apply -f -

# Copy CA certificate  
kubectl get secret source-db-ca -n source-namespace -o yaml | \
  sed 's/namespace: source-namespace/namespace: target-namespace/' | \
  kubectl apply -f -
```

### Step 3: Deploy Target Cluster

```bash
helm install target-db ./cnpg-database \
  -f values-pg-basebackup.yaml \
  -n target-namespace
```

### Step 4: Monitor Clone Progress

```bash
# Watch cluster status
kubectl get cluster -n target-namespace -w

# Check pod logs
kubectl logs -f cluster-target-db-1 -n target-namespace

# Verify completion
kubectl describe cluster cluster-target-db -n target-namespace
```

### Step 5: Verify Clone

```bash
# Check database size
kubectl exec -it cluster-target-db-1 -n target-namespace -- \
  psql -U postgres -c "SELECT pg_size_pretty(pg_database_size('app'));"

# Check table count
kubectl exec -it cluster-target-db-1 -n target-namespace -- \
  psql -U app -d app -c "\dt"
```

## Troubleshooting

### Clone Fails to Start

**Check network connectivity:**
```bash
kubectl exec -it cluster-target-db-1 -n target-namespace -- \
  nc -zv source-db-rw.source-namespace.svc.cluster.local 5432
```

**Verify credentials:**
```bash
kubectl get secret source-db-replica-user -n target-namespace
```

### Authentication Errors

**For password auth:**
- Verify secret exists and has correct key
- Check pg_hba.conf on source allows connection

**For TLS auth:**
- Verify all three secrets exist (key, cert, CA)
- Check certificate validity
- Ensure sslmode is set correctly

### Version Mismatch

**Error:** "source and target must have same PostgreSQL version"

**Solution:** Ensure both clusters use the same major version:
```yaml
imageName: ghcr.io/cloudnative-pg/postgresql:16.2-3  # Must match source
```

### Insufficient WAL Senders

**Error:** "number of requested standby connections exceeds max_wal_senders"

**Solution:** Increase `max_wal_senders` on source cluster or wait for available slots.

## Limitations

1. **One-time operation**: Creates a snapshot, not continuous replication
2. **Same architecture required**: Cannot clone across different CPU architectures
3. **Same version required**: Major PostgreSQL version must match
4. **Tablespace compatibility**: Source and target must have same tablespaces
5. **No incremental updates**: Must re-clone entirely for updates

## Best Practices

1. **Use TLS authentication** for better security
2. **Test thoroughly** before production migrations
3. **Plan for downtime** if migrating live databases
4. **Monitor source impact** during cloning
5. **Verify clone** before switching applications
6. **Document procedure** for team members
7. **Automate refreshes** for test/reporting databases

## References

- [CloudNativePG Bootstrap Documentation](https://cloudnative-pg.io/documentation/current/bootstrap/)
- [PostgreSQL pg_basebackup](https://www.postgresql.org/docs/current/app-pgbasebackup.html)
- [PostgreSQL Replication](https://www.postgresql.org/docs/current/high-availability.html)
