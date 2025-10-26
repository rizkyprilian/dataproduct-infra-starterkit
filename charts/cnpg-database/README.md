# cnpg-database

**English** | [Bahasa Indonesia](./README.id.md)

A Helm chart for deploying CloudNativePG PostgreSQL clusters with comprehensive backup, recovery, and cloning capabilities.

## Overview

This chart deploys production-ready PostgreSQL clusters using [CloudNativePG](https://cloudnative-pg.io/), the Kubernetes operator for PostgreSQL. It provides enterprise-grade features including automated backups, point-in-time recovery, TLS encryption, and multiple bootstrap methods.

## Features

- **Multiple Bootstrap Methods**:
  - `initdb`: Create new empty clusters
  - `recovery`: Restore from backups with Point-in-Time Recovery (PITR)
  - `pg_basebackup`: Clone from live PostgreSQL clusters
  
- **Declarative Database Management**:
  - Create and manage multiple databases declaratively
  - Manage PostgreSQL extensions per database
  - Manage schemas within databases
  - Automatic reconciliation and status tracking
  
- **Backup & Recovery**:
  - Automated backups to S3, GCS, or volume snapshots
  - Point-in-Time Recovery (PITR) support
  - Scheduled backup jobs
  - Configurable retention policies

- **High Availability**:
  - Multi-instance clusters with automatic failover
  - Streaming replication
  - Pod anti-affinity for resilience

- **Security**:
  - TLS/SSL encryption for client and replication connections
  - Integration with HashiCorp Vault for certificate management
  - Custom pg_hba.conf rules
  - Managed database roles

- **Monitoring & Management**:
  - Resource limits and requests
  - Custom PostgreSQL configurations
  - Post-initialization SQL scripts

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- [CloudNativePG Operator](https://cloudnative-pg.io/documentation/current/installation_upgrade/) installed in your cluster
- Storage class for persistent volumes
- (Optional) cert-manager for TLS certificates
- (Optional) HashiCorp Vault for certificate management
- (Optional) S3/GCS bucket for backups

## Installation

### From GitHub Container Registry (OCI)

The charts are automatically published to GitHub Container Registry on every push to the main branch.

#### 1. Pull the chart

```bash
helm pull oci://ghcr.io/rizkyprilian/cnpg-database --version 0.3.0
```

#### 2. Extract the chart

```bash
tar -xzf cnpg-database-0.3.0.tgz
```

#### 3. Customize values

```bash
cd cnpg-database
cp values.yaml my-values.yaml
# Edit my-values.yaml with your configuration
```

#### 4. Install the chart

```bash
helm install my-database . -f my-values.yaml -n database-namespace --create-namespace
```

### From Git Repository

#### 1. Clone the repository

```bash
git clone https://github.com/rizkyprilian/dataproduct-starterkit.git
cd dataproduct-starterkit
```

#### 2. Customize values

```bash
cd charts/cnpg-database
cp values.yaml my-values.yaml
# Edit my-values.yaml with your configuration
```

#### 3. Install the chart

```bash
helm install my-database . -f my-values.yaml -n database-namespace --create-namespace
```

## Configuration

### Basic Configuration

The following table lists the key configurable parameters:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `instances` | Number of PostgreSQL instances | `1` |
| `imageName` | PostgreSQL container image | `ghcr.io/cloudnative-pg/postgresql:16.2-3` |
| `storage.size` | Storage size for each instance | `1Gi` |
| `storage.storageClass` | Storage class name | `ceph-blockpool-ssd-erasurecoded` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.limits.memory` | Memory limit | `1Gi` |
| `resources.limits.cpu` | CPU limit | `1` |

### Bootstrap Methods

#### Method 1: Create New Cluster (initdb)

Default behavior - creates a new empty PostgreSQL cluster:

```yaml
bootstrapDB:
  database: app
  dbOwner: app
  postInitSQL:
    - key: init.sql
      value: |
        CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
        CREATE EXTENSION IF NOT EXISTS "pgcrypto";
```

#### Method 2: Restore from Backup (recovery)

Restore from a backup with optional Point-in-Time Recovery:

```yaml
bootstrapDB:
  recovery:
    source: origin
    backup:
      name: backup-cluster-example-20241022
    # Optional: PITR
    recoveryTarget:
      targetTime: "2024-10-22 08:00:00.000000+00"

externalClusters:
  - name: origin
    plugin:
      name: barman-cloud.cloudnative-pg.io
      parameters:
        barmanObjectName: cluster-example-backup
        serverName: cluster-example
```

See [RECOVERY.md](./RECOVERY.md) for detailed recovery documentation.

#### Method 3: Clone from Live Cluster (pg_basebackup)

Clone from a running PostgreSQL cluster:

```yaml
bootstrapDB:
  pg_basebackup:
    source: production-db
    database: app
    owner: app

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

See [PG_BASEBACKUP.md](./PG_BASEBACKUP.md) for detailed cloning documentation.

### Backup Configuration

#### S3 Backup

```yaml
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

Create the S3 credentials secret:

```bash
kubectl create secret generic s3-credentials \
  --from-literal=ACCESS_KEY_ID='your-access-key' \
  --from-literal=ACCESS_SECRET_KEY='your-secret-key' \
  -n database-namespace
```

#### GCS Backup

```yaml
backup:
  enabled: true
  retentionPolicy: "30d"
  gcs:
    enabled: true
    destinationPath: "gs://your-bucket-name/"
    dataCompression: "gzip"
    googleCredentialsExistingSecret: "gcs-credentials"
```

#### Scheduled Backups

```yaml
backup:
  scheduledBackups:
    enabled: true
    schedules:
      - cronSchedule: "5 1 * * 6"  # Weekly on Saturday at 1:05 AM
        backupOwnerReference: cluster
        immediate: true
        method: barmanObjectStore
        target: primary
```

### TLS Configuration

Configure TLS certificates using HashiCorp Vault:

```yaml
serverCerts:
  enabled: true
  commonName: cluster-app-sample-rw
  dnsNames:
    - sample.prod.db.company.com
    - cluster-dbpg-app-sample-rw.sample.svc
  issuer:
    vaultPath: pki_int_dev_db/sign/your-role-name
    vaultServer: https://vault-private.company.com
    kubernetesAuth:
      role: your-role-name
      mountPath: /v1/auth/k8s-auth-path

replicationClientCerts:
  enabled: true
  commonName: streaming_replica
  issuer:
    vaultPath: pki_int_dev_db/sign/your-role-name
    vaultServer: https://vault-private.company.com
    kubernetesAuth:
      role: your-role-name
      mountPath: /v1/auth/k8s-auth-path
```

### Database Roles

Configure managed PostgreSQL roles:

```yaml
dbRoles:
  - name: app_user
    ensure: present
    login: true
    inherit: true
    connectionLimit: 20
  - name: readonly_user
    ensure: present
    login: true
    inherit: true
    connectionLimit: 10
```

### Declarative Database Management

Create and manage multiple databases beyond the bootstrap database using CloudNativePG's Database CRD:

```yaml
databases:
  - name: analytics  # Database name in PostgreSQL (required)
    owner: app       # PostgreSQL role that owns the database (required)
    ensure: present  # present or absent (default: present)
    
    # Optional: Manage extensions in the database
    extensions:
      - name: pg_stat_statements
        ensure: present
      - name: bloom
        ensure: present
        schema: public
        version: "1.0"
    
    # Optional: Manage schemas in the database
    schemas:
      - name: analytics_schema
        owner: app
        ensure: present
      - name: reporting
        owner: dataops
        ensure: present
  
  - name: reporting
    owner: dataops
    ensure: present
    extensions:
      - name: postgis
        ensure: present
      - name: postgis_topology
        ensure: present
```

**Key Features:**

- **Database Management**: Create multiple databases declaratively with automatic reconciliation
- **Extension Management**: Install and manage PostgreSQL extensions per database with version control
- **Schema Management**: Create and manage schemas within databases with ownership control
- **Lifecycle Management**: Use `ensure: absent` to remove databases, extensions, or schemas

**Important Notes:**

- Reserved database names (`postgres`, `template0`, `template1`) cannot be used
- The bootstrap database (default: `app`) is created automatically during cluster initialization
- Database objects are reconciled by the CloudNativePG operator
- Check the `status.applied` field to verify successful reconciliation

For more details, see the [CloudNativePG Database Management Documentation](https://cloudnative-pg.io/documentation/current/declarative_database_management/).

### Custom pg_hba.conf

Configure client authentication rules:

```yaml
customPgHBA:
  - hostnossl all all 0.0.0.0/0 reject
  - hostnossl all all ::/0 reject
  - hostssl all all ::/0 cert
  - hostssl all all 0.0.0.0/0 cert
```

### Managed Services

Configure custom services for exposing PostgreSQL outside the cluster. This feature allows you to add LoadBalancer, NodePort, or other service types as described in the [CloudNativePG Service Management Documentation](https://cloudnative-pg.io/documentation/1.27/service_management/).

#### Add LoadBalancer Service

```yaml
managedServices:
  # Optional: Disable default services (ro, r)
  # The rw service cannot be disabled as it's essential
  disabledDefaultServices: []
  
  # Add custom services
  additional:
    # LoadBalancer for primary (read-write) instance
    - selectorType: rw
      updateStrategy: patch  # Options: patch (default) or replace
      serviceTemplate:
        metadata:
          name: "mydb-lb"
          labels:
            app: postgres
            type: loadbalancer
          annotations:
            service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
            service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"
        spec:
          type: LoadBalancer
          ports:
          - name: postgres
            port: 5432
            targetPort: 5432
            protocol: TCP
    
    # LoadBalancer for read-only replicas
    - selectorType: ro
      serviceTemplate:
        metadata:
          name: "mydb-ro-lb"
          labels:
            app: postgres
            type: loadbalancer
        spec:
          type: LoadBalancer
          ports:
          - name: postgres
            port: 5432
            targetPort: 5432
            protocol: TCP
```

**Selector Types:**
- `rw`: Read-write service (primary instance)
- `ro`: Read-only service (replicas only)
- `r`: Read service (all instances)

**Update Strategies:**
- `patch`: (Default) Apply changes directly to the service
- `replace`: Delete and recreate the service (may cause disruption)

**Important Notes:**
- Service names must be unique in the namespace
- Cannot use reserved names following `<CLUSTER_NAME>-<SERVICE_NAME>` pattern
- The `selector` field is managed by the operator
- Consider security implications when exposing databases externally

See [values-loadbalancer-example.yaml](./values-loadbalancer-example.yaml) for a complete example.

## Usage Examples

### Example 1: Simple Development Database

```yaml
instances: 1
imageName: ghcr.io/cloudnative-pg/postgresql:16.2-3

storage:
  size: 5Gi
  storageClass: "standard"

bootstrapDB:
  database: myapp
  dbOwner: myapp

backup:
  enabled: false

serverCerts:
  enabled: false

replicationClientCerts:
  enabled: false
```

### Example 2: Production HA Cluster with S3 Backups

```yaml
instances: 3
imageName: ghcr.io/cloudnative-pg/postgresql:16.2-3

storage:
  size: 100Gi
  storageClass: "fast-ssd"

resources:
  requests:
    memory: "4Gi"
    cpu: "2"
  limits:
    memory: "8Gi"
    cpu: "4"

backup:
  enabled: true
  retentionPolicy: "30d"
  s3:
    enabled: true
    destinationPath: "s3://prod-db-backups/"
    endpointURL: "https://s3.amazonaws.com"
    walCompression: "gzip"
    dataCompression: "gzip"
    credentials:
      accessKeyExistingSecret: "s3-credentials"
      secretKeyExistingSecret: "s3-credentials"
  scheduledBackups:
    enabled: true
    schedules:
      - cronSchedule: "0 2 * * *"  # Daily at 2 AM
        backupOwnerReference: cluster
        immediate: true
        method: barmanObjectStore
        target: primary

affinity:
  enablePodAntiAffinity: true
  topologyKey: kubernetes.io/hostname
  podAntiAffinityType: required
```

### Example 3: Test Database Cloned from Production

```yaml
instances: 1
imageName: ghcr.io/cloudnative-pg/postgresql:16.2-3

storage:
  size: 50Gi
  storageClass: "standard"

bootstrapDB:
  pg_basebackup:
    source: production-db
    database: app
    owner: app
    secret:
      name: test-db-credentials

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

backup:
  enabled: false
```

## Accessing the Database

### Get Connection Information

```bash
# Get the primary service (read-write)
kubectl get svc -n database-namespace | grep rw

# Get the read-only service
kubectl get svc -n database-namespace | grep ro

# Get the superuser password
kubectl get secret cluster-my-database-superuser \
  -n database-namespace \
  -o jsonpath='{.data.password}' | base64 -d
```

### Connect to the Database

```bash
# Port-forward to local machine
kubectl port-forward svc/cluster-my-database-rw 5432:5432 -n database-namespace

# Connect using psql
psql -h localhost -p 5432 -U postgres
```

## Monitoring

### Check Cluster Status

```bash
kubectl get cluster -n database-namespace
kubectl describe cluster cluster-my-database -n database-namespace
```

### Check Backups

```bash
kubectl get backup -n database-namespace
kubectl describe backup <backup-name> -n database-namespace
```

### View Logs

```bash
kubectl logs cluster-my-database-1 -n database-namespace
```

## Upgrading

### Upgrade Chart Version

```bash
helm upgrade my-database oci://ghcr.io/rizkyprilian/cnpg-database \
  --version 0.3.0 \
  -f my-values.yaml \
  -n database-namespace
```

### Upgrade PostgreSQL Version

Update the `imageName` in your values file:

```yaml
imageName: ghcr.io/cloudnative-pg/postgresql:17.0-1
```

Then upgrade:

```bash
helm upgrade my-database . -f my-values.yaml -n database-namespace
```

## Uninstalling

```bash
helm uninstall my-database -n database-namespace
```

**Warning**: This will delete the cluster and all data. Ensure you have backups before uninstalling.

## Troubleshooting

### Cluster Not Starting

Check the operator logs:
```bash
kubectl logs -n cnpg-system deployment/cnpg-controller-manager
```

Check cluster events:
```bash
kubectl describe cluster cluster-my-database -n database-namespace
```

### Backup Failures

Check backup status:
```bash
kubectl get backup -n database-namespace
kubectl describe backup <backup-name> -n database-namespace
```

Verify S3/GCS credentials:
```bash
kubectl get secret s3-credentials -n database-namespace
```

### Connection Issues

Verify services are running:
```bash
kubectl get svc -n database-namespace
kubectl get pods -n database-namespace
```

Check pg_hba.conf rules in the cluster spec.

## Additional Documentation

- [RECOVERY.md](./RECOVERY.md) - Detailed recovery and PITR guide
- [PG_BASEBACKUP.md](./PG_BASEBACKUP.md) - Cloning from live clusters guide
- [CHANGELOG.md](./CHANGELOG.md) - Version history and changes
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)

## Chart Values Reference

For a complete list of all configurable parameters, see [values.yaml](./values.yaml).

Example values files:
- [values-recovery-example.yaml](./values-recovery-example.yaml) - Recovery configuration
- [values-pg-basebackup-example.yaml](./values-pg-basebackup-example.yaml) - Cloning configuration
- [values-databases-example.yaml](./values-databases-example.yaml) - Declarative database management configuration

## Contributing

This chart is part of the dataproduct-starterkit project. Contributions are welcome!

## License

See the [LICENSE](../../LICENSE) file in the repository root.

## Support

For issues and questions:
- GitHub Issues: https://github.com/rizkyprilian/dataproduct-starterkit/issues
- CloudNativePG Community: https://cloudnative-pg.io/community/

## Version

- **Chart Version**: 0.3.0
- **PostgreSQL Version**: 16.2-3 (default)
- **CloudNativePG Operator**: Compatible with v1.20+

## Maintainer

- **Maintainer**: Rizky Prilian
- **Email**: rizky.prilian@company.com