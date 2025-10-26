# cnpg-database

[English](./README.md) | **Bahasa Indonesia**

Helm chart komprehensif untuk deploy cluster PostgreSQL CloudNativePG dengan fitur enterprise-grade.

## Gambaran Umum

Chart ini men-deploy cluster PostgreSQL siap produksi menggunakan [CloudNativePG](https://cloudnative-pg.io/), Kubernetes operator untuk PostgreSQL. Menyediakan fitur enterprise-grade termasuk automated backups, point-in-time recovery, enkripsi TLS, dan multiple bootstrap methods.

## Fitur

- **Multiple Bootstrap Methods**:
  - `initdb`: Buat cluster baru yang kosong
  - `recovery`: Restore dari backups dengan Point-in-Time Recovery (PITR)
  - `pg_basebackup`: Clone dari cluster PostgreSQL yang hidup
  
- **Declarative Database Management** (Baru di v0.3.0):
  - Buat dan kelola multiple databases secara deklaratif
  - Kelola PostgreSQL extensions per database
  - Kelola schemas dalam databases
  - Automatic reconciliation dan status tracking
  
- **Backup & Recovery**:
  - Automated backups ke S3, GCS, atau volume snapshots
  - Point-in-Time Recovery (PITR) support
  - Scheduled backup jobs
  - Configurable retention policies

- **High Availability**:
  - Multi-instance clusters dengan automatic failover
  - Streaming replication
  - Pod anti-affinity untuk resilience

- **Security**:
  - Enkripsi TLS/SSL untuk client dan replication connections
  - Integrasi dengan HashiCorp Vault untuk certificate management
  - Custom pg_hba.conf rules
  - Managed database roles

## Prasyarat

- Kubernetes 1.19+
- Helm 3.0+
- [CloudNativePG Operator](https://cloudnative-pg.io/documentation/current/installation_upgrade/) terinstall di cluster
- Storage class untuk persistent volumes
- (Opsional) cert-manager untuk TLS certificates
- (Opsional) HashiCorp Vault untuk certificate management
- (Opsional) S3/GCS bucket untuk backups

## Instalasi

### 1. Pull Chart dari GitHub Container Registry

```bash
helm pull oci://ghcr.io/rizkyprilian/cnpg-database --version 0.3.0
tar -xzf cnpg-database-0.3.0.tgz
cd cnpg-database
```

### 2. Customize Values

```bash
cp values.yaml my-values.yaml
# Edit my-values.yaml dengan konfigurasi Anda
```

### 3. Install Chart

```bash
helm install my-database . -f my-values.yaml -n database-namespace --create-namespace
```

## Konfigurasi

### Bootstrap Methods

#### Method 1: Buat Cluster Baru (initdb)

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

#### Method 2: Restore dari Backup (recovery)

```yaml
bootstrapDB:
  recovery:
    source: origin
    backup:
      name: backup-cluster-example-20241022
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

#### Method 3: Clone dari Live Cluster (pg_basebackup)

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
```

### Declarative Database Management (Baru!)

Buat dan kelola multiple databases dengan extensions dan schemas:

```yaml
databases:
  - name: analytics  # Nama database di PostgreSQL
    owner: app       # PostgreSQL role yang memiliki database
    ensure: present  # present atau absent
    
    # Opsional: Kelola extensions dalam database
    extensions:
      - name: pg_stat_statements
        ensure: present
      - name: bloom
        ensure: present
        schema: public
        version: "1.0"
    
    # Opsional: Kelola schemas dalam database
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
```

**Fitur Utama:**
- **Database Management**: Buat multiple databases secara deklaratif dengan automatic reconciliation
- **Extension Management**: Install dan kelola PostgreSQL extensions per database dengan version control
- **Schema Management**: Buat dan kelola schemas dalam databases dengan ownership control
- **Lifecycle Management**: Gunakan `ensure: absent` untuk menghapus databases, extensions, atau schemas

**Catatan Penting:**
- Reserved database names (`postgres`, `template0`, `template1`) tidak dapat digunakan
- Bootstrap database (default: `app`) dibuat otomatis saat cluster initialization
- Database objects di-reconcile oleh CloudNativePG operator

### Konfigurasi Backup

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

Buat S3 credentials secret:

```bash
kubectl create secret generic s3-credentials \
  --from-literal=ACCESS_KEY_ID='your-access-key' \
  --from-literal=ACCESS_SECRET_KEY='your-secret-key' \
  -n database-namespace
```

### Konfigurasi TLS dengan Vault

```yaml
serverCerts:
  enabled: true
  commonName: cluster-app-sample-rw
  dnsNames:
    - sample.prod.db.example.com
    - cluster-dbpg-app-sample-rw.sample.svc
  issuer:
    vaultPath: pki_int_dev_db/sign/your-role-name
    vaultServer: https://vault.example.com
    kubernetesAuth:
      role: your-role-name
      mountPath: /v1/auth/k8s-auth-path
```

## Mengakses Database

### Get Connection Information

```bash
# Get primary service (read-write)
kubectl get svc -n database-namespace | grep rw

# Get superuser password
kubectl get secret cluster-my-database-superuser \
  -n database-namespace \
  -o jsonpath='{.data.password}' | base64 -d
```

### Connect ke Database

```bash
# Port-forward ke local machine
kubectl port-forward svc/cluster-my-database-rw 5432:5432 -n database-namespace

# Connect menggunakan psql
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

### Check Databases (Baru!)

```bash
# List databases
kubectl get database -n database-namespace

# Describe database
kubectl describe database <database-name> -n database-namespace
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

Update `imageName` di values file:

```yaml
imageName: ghcr.io/cloudnative-pg/postgresql:17.0-1
```

Kemudian upgrade:

```bash
helm upgrade my-database . -f my-values.yaml -n database-namespace
```

## Troubleshooting

### Cluster Tidak Starting

Check operator logs:

```bash
kubectl logs -n cnpg-system deployment/cnpg-controller-manager
```

Check cluster events:

```bash
kubectl describe cluster cluster-my-database -n database-namespace
```

### Database Tidak Terbuat

Check database status:

```bash
kubectl describe database <database-name> -n database-namespace
```

Check operator logs untuk errors.

## Dokumentasi Tambahan

- [RECOVERY.md](./RECOVERY.md) - Panduan recovery dan PITR detail
- [PG_BASEBACKUP.md](./PG_BASEBACKUP.md) - Panduan cloning dari live clusters
- [CHANGELOG.md](./CHANGELOG.md) - Version history dan changes
- [CloudNativePG Documentation](https://cloudnative-pg.io/documentation/)

## Versi

- **Chart Version**: 0.3.0
- **PostgreSQL Version**: 16.2-3 (default)
- **CloudNativePG Operator**: Compatible dengan v1.20+

## Lisensi

Lihat file [LICENSE](../../LICENSE) di root repository.

trigger
