# mysql-innodb-cluster

**English** | [Bahasa Indonesia](./README.id.md)

A Helm chart for deploying MySQL InnoDB Cluster using the MySQL Operator for Kubernetes with comprehensive clustering, high availability, and backup capabilities.

## Overview

This chart deploys production-ready MySQL InnoDB Clusters using the [MySQL Operator for Kubernetes](https://dev.mysql.com/doc/mysql-operator/en/). It provides enterprise-grade features including automated clustering, high availability with MySQL Router, automated backups, and point-in-time recovery capabilities.

## Features

- **High Availability InnoDB Cluster**:
  - Multi-instance MySQL clusters with automatic failover
  - Group Replication for data consistency
  - MySQL Router for intelligent connection routing
  - Configurable cluster size (minimum 3 instances recommended)

- **Automated Backups**:
  - Support for PersistentVolumeClaim backups
  - Support for OCI Object Storage backups
  - Support for S3-compatible storage (MySQL Operator 9.1.0+)
  - Scheduled backups using Kubernetes CronJobs
  - Reusable backup profiles

- **Flexible Initialization**:
  - Bootstrap from scratch
  - Clone from existing MySQL instances
  - Restore from dumps (OCI, S3, or PVC)

- **Security**:
  - TLS/SSL encryption support
  - Self-signed or custom certificates
  - Secure credential management via Kubernetes Secrets

- **Kubernetes Native**:
  - Pod anti-affinity for resilience
  - Resource limits and requests
  - Custom storage classes
  - Service configuration options

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- **MySQL Operator for Kubernetes** installed in your cluster
  - Installation guide: https://dev.mysql.com/doc/mysql-operator/en/mysql-operator-installation.html
- Storage class for persistent volumes
- (Optional) S3 or OCI Object Storage for backups

## Installing MySQL Operator

Before deploying this chart, you must install the MySQL Operator:

```bash
# Install using kubectl
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-crds.yaml
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-operator.yaml

# Verify installation
kubectl get deployment -n mysql-operator mysql-operator
```

Or using Helm:

```bash
helm repo add mysql-operator https://mysql.github.io/mysql-operator/
helm repo update
helm install mysql-operator mysql-operator/mysql-operator --namespace mysql-operator --create-namespace
```

## Installation

### 1. Create Root User Secret

Before installing the chart, create a secret with MySQL root credentials:

```bash
kubectl create secret generic mysql-root-secret \
  --from-literal=rootUser=root \
  --from-literal=rootHost=% \
  --from-literal=rootPassword=your-secure-password \
  -n your-namespace
```

### 2. Install the Chart

```bash
cd charts/mysql-innodb-cluster
helm install my-mysql-cluster . -f values.yaml -n your-namespace --create-namespace
```

## Configuration

### Basic Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `mysql.instances` | Number of MySQL instances in the cluster | `3` |
| `mysql.version` | MySQL version to deploy | `9.1.0` |
| `mysql.baseServerId` | Base server ID for cluster instances | `1000` |
| `router.instances` | Number of MySQL Router instances | `1` |
| `router.version` | MySQL Router version | `9.1.0` |
| `storage.size` | Storage size for each MySQL instance | `20Gi` |
| `storage.storageClass` | Storage class name | `standard` |
| `secretName` | Name of the secret containing root credentials | `mysql-root-secret` |

### Clustering Configuration

#### High Availability Setup (3 instances)

```yaml
mysql:
  instances: 3
  version: "9.1.0"
  baseServerId: 1000

router:
  instances: 2  # Multiple routers for HA

storage:
  size: 50Gi
  storageClass: "fast-ssd"

affinity:
  enablePodAntiAffinity: true
  podAntiAffinityType: required  # Ensure instances on different nodes
  topologyKey: kubernetes.io/hostname
```

#### Development Setup (Single instance)

```yaml
mysql:
  instances: 1
  version: "9.1.0"

router:
  instances: 1

storage:
  size: 10Gi
  storageClass: "standard"

affinity:
  enablePodAntiAffinity: false
```

### Backup Configuration

#### PersistentVolumeClaim Backup

```yaml
backup:
  enabled: true
  profiles:
    - name: daily-backup
      dumpInstance:
        dumpOptions:
          excludeTables: []
        storage:
          persistentVolumeClaim:
            claimName: mysql-backup-pvc
  
  schedules:
    - name: daily-backup-schedule
      schedule: "0 2 * * *"  # Daily at 2 AM
      backupProfileName: daily-backup
      enabled: true
```

Create the PVC before deploying:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-backup-pvc
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
```

#### S3-Compatible Storage Backup (MySQL Operator 9.1.0+)

```yaml
backup:
  enabled: true
  profiles:
    - name: s3-backup
      dumpInstance:
        storage:
          s3:
            bucketName: my-mysql-backups
            prefix: prod-cluster
            endpoint: https://s3.amazonaws.com
            region: us-east-1
            credentials: s3-backup-credentials
  
  schedules:
    - name: hourly-backup
      schedule: "0 * * * *"  # Hourly
      backupProfileName: s3-backup
      enabled: true
```

Create S3 credentials secret:

```bash
kubectl create secret generic s3-backup-credentials \
  --from-literal=accessKey=YOUR_ACCESS_KEY \
  --from-literal=secretKey=YOUR_SECRET_KEY \
  -n your-namespace
```

#### OCI Object Storage Backup

```yaml
backup:
  enabled: true
  profiles:
    - name: oci-backup
      dumpInstance:
        storage:
          ociObjectStorage:
            prefix: mysql-backups
            bucketName: my-oci-bucket
            credentials: oci-backup-credentials
  
  schedules:
    - name: daily-oci-backup
      schedule: "0 3 * * *"
      backupProfileName: oci-backup
      enabled: true
```

### Initialize from Clone

Clone from an existing MySQL instance:

```yaml
initDB:
  enabled: true
  clone:
    donorUrl: source-cluster-0.source-cluster-instances.default.svc.cluster.local:3306
    rootUser: root
    secretKeyRef:
      name: source-mysql-root-secret
```

### Initialize from Dump

Restore from a backup dump:

```yaml
initDB:
  enabled: true
  dump:
    name: my-dump-20240101
    storage:
      ociObjectStorage:
        prefix: dump-20240101-120000
        bucketName: my-backup-bucket
        credentials: oci-restore-credentials
```

### Custom MySQL Configuration

Add custom my.cnf settings:

```yaml
mycnf: |
  [mysqld]
  max_connections=500
  innodb_buffer_pool_size=4G
  innodb_log_file_size=512M
  slow_query_log=1
  long_query_time=2
```

### TLS Configuration

#### Self-Signed Certificates (Default)

```yaml
tls:
  useSelfSigned: true
```

#### Vault-Issued Certificates (Recommended for Production)

Use cert-manager with Vault issuer to automatically generate and rotate TLS certificates:

```yaml
# Disable self-signed certificates
tls:
  useSelfSigned: false

# Enable Vault-issued certificates
serverCerts:
  enabled: true
  commonName: mysql-cluster-primary
  dnsNames:
    - mysql.prod.db.example.com
    - mysql-ro.prod.db.example.com
    - my-mysql-cluster
    - my-mysql-cluster.default.svc.cluster.local
  issuer:
    vaultPath: pki_int_dev_db/sign/mysql-role
    vaultServer: https://vault.example.com
    kubernetesAuth:
      role: mysql-cert-issuer
      mountPath: /v1/auth/kubernetes
```

**Prerequisites for Vault certificates:**

- cert-manager installed in the cluster
- Vault PKI engine configured
- Kubernetes auth method enabled in Vault
- Appropriate role created in Vault for certificate issuance

**Note**: The certificate format is compatible with PostgreSQL certificates. You can use the same Vault PKI setup for both MySQL and PostgreSQL clusters.

#### Custom Certificates

```yaml
tls:
  useSelfSigned: false
  tlsSecret: my-mysql-tls-secret
  tlsCASecret: my-mysql-ca-secret
```

## Accessing the Cluster

### Get Connection Information

```bash
# Get the primary service (read-write)
kubectl get svc -n your-namespace | grep mysql

# Get the root password
kubectl get secret mysql-root-secret \
  -n your-namespace \
  -o jsonpath='{.data.rootPassword}' | base64 -d
```

### Connect to MySQL

```bash
# Port-forward to local machine
kubectl port-forward svc/my-mysql-cluster 3306:3306 -n your-namespace

# Connect using mysql client
mysql -h 127.0.0.1 -P 3306 -u root -p
```

### Connection Endpoints

The MySQL Operator creates multiple services:

- `<cluster-name>` - Primary service (read-write) on port 3306
- `<cluster-name>-instances` - Headless service for direct pod access
- MySQL Router ports:
  - `6446` - Read-write connections
  - `6447` - Read-only connections
  - `6448` - Read-write with X Protocol
  - `6449` - Read-only with X Protocol

## Monitoring

### Check Cluster Status

```bash
# Get cluster status
kubectl get innodbcluster -n your-namespace

# Describe cluster
kubectl describe innodbcluster my-mysql-cluster -n your-namespace

# Check pods
kubectl get pods -n your-namespace -l app.kubernetes.io/instance=my-mysql-cluster
```

### Check Backups

```bash
# List backups
kubectl get mysqlbackup -n your-namespace

# Describe a backup
kubectl describe mysqlbackup <backup-name> -n your-namespace
```

### View Logs

```bash
# MySQL instance logs
kubectl logs my-mysql-cluster-0 -n your-namespace -c mysql

# Router logs
kubectl logs my-mysql-cluster-router-<pod-id> -n your-namespace
```

## Upgrading

### Upgrade Chart Version

```bash
helm upgrade my-mysql-cluster . -f values.yaml -n your-namespace
```

### Upgrade MySQL Version

Update the `mysql.version` in your values file:

```yaml
mysql:
  version: "9.2.0"
```

Then upgrade:

```bash
helm upgrade my-mysql-cluster . -f values.yaml -n your-namespace
```

**Note**: The MySQL Operator handles rolling upgrades automatically.

## Scaling

### Scale Up

Increase the number of instances:

```yaml
mysql:
  instances: 5
```

```bash
helm upgrade my-mysql-cluster . -f values.yaml -n your-namespace
```

### Scale Down

Decrease the number of instances (minimum 3 for HA):

```yaml
mysql:
  instances: 3
```

```bash
helm upgrade my-mysql-cluster . -f values.yaml -n your-namespace
```

## Backup and Restore

### Manual Backup

Create a one-off backup:

```yaml
apiVersion: mysql.oracle.com/v2
kind: MySQLBackup
metadata:
  name: manual-backup-20240101
spec:
  clusterName: my-mysql-cluster
  backupProfileName: daily-backup
```

```bash
kubectl apply -f manual-backup.yaml -n your-namespace
```

### Restore from Backup

Create a new cluster from a backup:

```yaml
initDB:
  enabled: true
  dump:
    name: manual-backup-20240101
    storage:
      persistentVolumeClaim:
        claimName: mysql-backup-pvc
```

## Troubleshooting

### Cluster Not Starting

Check operator logs:

```bash
kubectl logs -n mysql-operator deployment/mysql-operator
```

Check cluster events:

```bash
kubectl describe innodbcluster my-mysql-cluster -n your-namespace
```

### Connection Issues

Verify services are running:

```bash
kubectl get svc -n your-namespace
kubectl get pods -n your-namespace
```

Check MySQL Router status:

```bash
kubectl logs <router-pod-name> -n your-namespace
```

### Backup Failures

Check backup status:

```bash
kubectl get mysqlbackup -n your-namespace
kubectl describe mysqlbackup <backup-name> -n your-namespace
```

Verify storage credentials:

```bash
kubectl get secret <credentials-secret> -n your-namespace
```

## Uninstalling

```bash
helm uninstall my-mysql-cluster -n your-namespace
```

**Warning**: This will delete the cluster and all data. Ensure you have backups before uninstalling.

To also delete PVCs:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=my-mysql-cluster -n your-namespace
```

## Additional Documentation

- [MySQL Operator Documentation](https://dev.mysql.com/doc/mysql-operator/en/)
- [MySQL InnoDB Cluster](https://dev.mysql.com/doc/refman/en/mysql-innodb-cluster-introduction.html)
- [MySQL Router](https://dev.mysql.com/doc/mysql-router/en/)

## Chart Values Reference

For a complete list of all configurable parameters, see [values.yaml](./values.yaml).

Example values files:

- [values-production-ha.yaml](./values-production-ha.yaml) - Production HA configuration
- [values-development.yaml](./values-development.yaml) - Development configuration
- [values-clone-example.yaml](./values-clone-example.yaml) - Clone from existing cluster
- [values-vault-tls-example.yaml](./values-vault-tls-example.yaml) - Production with Vault TLS certificates

## Version

- **Chart Version**: 0.2.0
- **MySQL Version**: 9.1.0 (default)
- **MySQL Operator**: Compatible with v2.0.0+

## Contributing

This chart is part of the dataproduct-starterkit project. Contributions are welcome!

## License

See the [LICENSE](../../LICENSE) file in the repository root.
