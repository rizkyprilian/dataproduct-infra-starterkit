# mysql-innodb-cluster

[English](./README.md) | **Bahasa Indonesia**

Helm chart untuk deploy MySQL InnoDB Cluster menggunakan MySQL Operator for Kubernetes dengan clustering, high availability, dan backup yang komprehensif.

## Gambaran Umum

Chart ini men-deploy cluster MySQL siap produksi menggunakan [MySQL Operator for Kubernetes](https://dev.mysql.com/doc/mysql-operator/en/). Menyediakan fitur enterprise-grade termasuk clustering otomatis, high availability dengan MySQL Router, backup otomatis, dan kemampuan point-in-time recovery.

## Fitur

- **High Availability InnoDB Cluster**:
  - Multi-instance MySQL clusters dengan automatic failover
  - Group Replication untuk konsistensi data
  - MySQL Router untuk intelligent connection routing
  - Ukuran cluster yang dapat dikonfigurasi (minimum 3 instance direkomendasikan)

- **Automated Backups**:
  - Support backup ke PersistentVolumeClaim
  - Support backup ke OCI Object Storage
  - Support backup ke S3-compatible storage (MySQL Operator 9.1.0+)
  - Scheduled backups menggunakan Kubernetes CronJobs
  - Reusable backup profiles

- **Flexible Initialization**:
  - Bootstrap dari scratch (default)
  - Clone dari MySQL instance yang ada
  - Restore dari dumps (OCI, S3, atau PVC)

- **Security**:
  - Enkripsi TLS/SSL dengan integrasi Vault
  - Self-signed atau custom certificates
  - Manajemen credential aman via Kubernetes Secrets

## Prasyarat

- Kubernetes 1.19+
- Helm 3.0+
- **MySQL Operator for Kubernetes** terinstall di cluster
- Storage class untuk persistent volumes
- (Opsional) S3 atau OCI Object Storage untuk backups

## Instalasi MySQL Operator

Sebelum deploy chart ini, install MySQL Operator terlebih dahulu:

```bash
# Install menggunakan kubectl
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-crds.yaml
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-operator.yaml

# Verifikasi instalasi
kubectl get deployment -n mysql-operator mysql-operator
```

## Instalasi

### 1. Buat Root User Secret

```bash
kubectl create secret generic mysql-root-secret \
  --from-literal=rootUser=root \
  --from-literal=rootHost=% \
  --from-literal=rootPassword=password-aman-anda \
  -n your-namespace
```

### 2. Install Chart

```bash
cd charts/mysql-innodb-cluster
helm install my-mysql-cluster . -f values.yaml -n your-namespace --create-namespace
```

## Konfigurasi

### High Availability Setup (3 instances)

```yaml
mysql:
  instances: 3
  version: "9.1.0"

router:
  instances: 2  # Multiple routers untuk HA

storage:
  size: 50Gi
  storageClass: "fast-ssd"

affinity:
  enablePodAntiAffinity: true
  podAntiAffinityType: required
```

### Konfigurasi Backup

#### S3-Compatible Storage Backup

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
      schedule: "0 * * * *"  # Setiap jam
      backupProfileName: s3-backup
      enabled: true
```

### Konfigurasi TLS dengan Vault

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
    - my-mysql-cluster.default.svc.cluster.local
  issuer:
    vaultPath: pki_int_dev_db/sign/mysql-role
    vaultServer: https://vault.example.com
    kubernetesAuth:
      role: mysql-cert-issuer
      mountPath: /v1/auth/kubernetes
```

**Catatan**: Format certificate compatible dengan PostgreSQL certificates. Anda dapat menggunakan Vault PKI setup yang sama untuk MySQL dan PostgreSQL.

### Clone dari Cluster yang Ada

```yaml
initDB:
  enabled: true
  clone:
    donorUrl: source-cluster-0.source-cluster-instances.default.svc.cluster.local:3306
    rootUser: root
    secretKeyRef:
      name: source-mysql-root-secret
```

## Mengakses Cluster

### Get Connection Information

```bash
# Get primary service (read-write)
kubectl get svc -n your-namespace | grep mysql

# Get root password
kubectl get secret mysql-root-secret \
  -n your-namespace \
  -o jsonpath='{.data.rootPassword}' | base64 -d
```

### Connect ke MySQL

```bash
# Port-forward ke local machine
kubectl port-forward svc/my-mysql-cluster 3306:3306 -n your-namespace

# Connect menggunakan mysql client
mysql -h 127.0.0.1 -P 3306 -u root -p
```

### Connection Endpoints

MySQL Operator membuat multiple services:

- `<cluster-name>` - Primary service (read-write) pada port 3306
- `<cluster-name>-instances` - Headless service untuk direct pod access
- MySQL Router ports:
  - `6446` - Read-write connections
  - `6447` - Read-only connections

## Monitoring

### Check Cluster Status

```bash
# Get cluster status
kubectl get innodbcluster -n your-namespace

# Describe cluster
kubectl describe innodbcluster my-mysql-cluster -n your-namespace

# Check pods
kubectl get pods -n your-namespace
```

### Check Backups

```bash
# List backups
kubectl get mysqlbackup -n your-namespace

# Describe backup
kubectl describe mysqlbackup <backup-name> -n your-namespace
```

## Scaling

### Scale Up

```yaml
mysql:
  instances: 5
```

```bash
helm upgrade my-mysql-cluster . -f values.yaml -n your-namespace
```

## Troubleshooting

### Cluster Tidak Starting

Check operator logs:

```bash
kubectl logs -n mysql-operator deployment/mysql-operator
```

Check cluster events:

```bash
kubectl describe innodbcluster my-mysql-cluster -n your-namespace
```

### Connection Issues

Verify services berjalan:

```bash
kubectl get svc -n your-namespace
kubectl get pods -n your-namespace
```

## Dokumentasi Tambahan

- [MySQL Operator Documentation](https://dev.mysql.com/doc/mysql-operator/en/)
- [MySQL InnoDB Cluster](https://dev.mysql.com/doc/refman/en/mysql-innodb-cluster-introduction.html)
- [MySQL Router](https://dev.mysql.com/doc/mysql-router/en/)

## Versi

- **Chart Version**: 0.2.0
- **MySQL Version**: 9.1.0 (default)
- **MySQL Operator**: Compatible dengan v2.0.0+

## Lisensi

Lihat file [LICENSE](../../LICENSE) di root repository.
