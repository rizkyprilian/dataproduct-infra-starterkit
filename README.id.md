# Data Product Infrastructure Starter Kit

[English](./README.md) | **Bahasa Indonesia**

Koleksi Helm chart siap produksi untuk membangun infrastruktur data product di Kubernetes. Starter kit ini menyediakan template dan chart yang dapat digunakan kembali untuk deploy dan mengelola database (PostgreSQL, MySQL), object storage (Ceph RGW), sertifikat TLS, dan manajemen secrets.

## Gambaran Umum

Repository ini berisi Helm chart yang dirancang untuk bekerja bersama menyediakan stack infrastruktur lengkap untuk data product. Semua chart mengikuti praktik terbaik cloud-native dan secara otomatis dikemas dan dipublikasikan ke GitHub Container Registry setiap push ke branch main.

## Chart yang Tersedia

### 1. [cnpg-database](./charts/cnpg-database)

**Versi:** 0.3.0 | **Tipe:** Application

Helm chart komprehensif untuk deploy cluster PostgreSQL CloudNativePG dengan fitur enterprise.

**Fitur Utama:**
- Multiple bootstrap methods (initdb, recovery, pg_basebackup)
- Manajemen database deklaratif dengan extensions dan schemas
- Backup otomatis ke S3, GCS, atau volume snapshots
- Point-in-Time Recovery (PITR)
- High availability dengan streaming replication
- Enkripsi TLS/SSL dengan integrasi Vault
- Managed database roles dan custom pg_hba rules

**Use Case:**
- Database PostgreSQL produksi
- Environment development dan staging
- Kloning dan testing database
- Skenario disaster recovery
- Aplikasi multi-database

[📖 Dokumentasi Lengkap](./charts/cnpg-database/README.md) | [🇮🇩 Bahasa Indonesia](./charts/cnpg-database/README.id.md)

---

### 2. [mysql-innodb-cluster](./charts/mysql-innodb-cluster)

**Versi:** 0.2.0 | **Tipe:** Application

Helm chart untuk deploy MySQL InnoDB Cluster menggunakan MySQL Operator for Kubernetes dengan clustering, high availability, dan backup.

**Fitur Utama:**
- High availability InnoDB Cluster dengan Group Replication
- MySQL Router untuk intelligent connection routing
- Backup otomatis ke PVC, S3, atau OCI Object Storage
- Scheduled backups menggunakan Kubernetes CronJobs
- Enkripsi TLS/SSL dengan integrasi Vault
- Clone dari MySQL instance yang ada
- Restore dari dumps

**Use Case:**
- Database MySQL produksi dengan HA
- Multi-instance MySQL clusters
- Kloning dan migrasi database
- Backup dan recovery otomatis

[📖 Dokumentasi Lengkap](./charts/mysql-innodb-cluster/README.md) | [🇮🇩 Bahasa Indonesia](./charts/mysql-innodb-cluster/README.id.md)

---

### 3. [ceph-rgw-resources](./charts/ceph-rgw-resources)

**Versi:** 0.1.0 | **Tipe:** Application

Helm chart sederhana untuk mengelola bucket dan user Ceph RGW (RADOS Gateway) secara deklaratif menggunakan Rook.

**Fitur Utama:**
- Manajemen user S3-compatible secara deklaratif
- Manajemen bucket S3-compatible secara deklaratif
- Konfigurasi user quotas dan capabilities
- Bucket policies dan lifecycle rules
- Generasi credential otomatis

**Use Case:**
- Provisioning object storage S3-compatible
- Manajemen bucket dan user aplikasi
- Manajemen credential otomatis
- Object storage multi-tenant

[📖 Dokumentasi Lengkap](./charts/ceph-rgw-resources/README.md) | [🇮🇩 Bahasa Indonesia](./charts/ceph-rgw-resources/README.id.md)

---

### 4. [database-tls-cert](./charts/database-tls-cert)

**Versi:** 0.1.9 | **Tipe:** Application

Otomatisasi generasi dan manajemen sertifikat TLS untuk database PostgreSQL menggunakan cert-manager dan HashiCorp Vault.

**Fitur Utama:**
- Manajemen lifecycle sertifikat otomatis
- Integrasi Vault PKI
- Support multiple certificates
- Otomasi service account dan RBAC

**Use Case:**
- Koneksi database yang aman
- Autentikasi berbasis sertifikat
- Rotasi sertifikat otomatis

[📖 Dokumentasi Lengkap](./charts/database-tls-cert/README.md)

---

### 5. [eso-secrets](./charts/eso-secrets)

**Versi:** 0.1.0 | **Tipe:** Application

Mengelola Kubernetes secrets menggunakan External Secrets Operator (ESO) dengan backend HashiCorp Vault.

**Fitur Utama:**
- Sinkronisasi secret otomatis dari Vault
- Support multiple secrets
- Integrasi Vault KV v2

**Use Case:**
- Manajemen secrets aplikasi
- Sinkronisasi credentials database
- Manajemen API keys dan tokens

[📖 Dokumentasi Lengkap](./charts/eso-secrets/README.md)

---

### 6. [letsencrypt-tls-cert](./charts/letsencrypt-tls-cert)

**Versi:** 0.1.0 | **Tipe:** Application

Deploy sertifikat TLS Let's Encrypt menggunakan cert-manager untuk layanan public-facing.

**Fitur Utama:**
- Konfigurasi certificate berbasis array
- Support Issuer dan ClusterIssuer
- Multiple DNS names per certificate (SAN)
- Support wildcard certificates

**Use Case:**
- Aplikasi web public-facing
- Wildcard certificates untuk multiple subdomains
- Multi-domain certificates

[📖 Dokumentasi Lengkap](./charts/letsencrypt-tls-cert/README.md)

---

## Prasyarat

### Komponen Wajib

- **Kubernetes:** 1.19+ (tested on 1.24+)
- **Helm:** 3.0+ (recommended 3.15.1+)
- **HashiCorp Vault:** 1.10+ (untuk certificate dan secrets management)

### Komponen Opsional

Tergantung chart yang digunakan:

- **CloudNativePG Operator:** Untuk chart cnpg-database
- **MySQL Operator for Kubernetes:** Untuk chart mysql-innodb-cluster
- **Rook Ceph Operator:** Untuk chart ceph-rgw-resources
- **cert-manager:** Untuk chart database-tls-cert dan letsencrypt-tls-cert
- **External Secrets Operator:** Untuk chart eso-secrets

## Instalasi

### Dari GitHub Container Registry (OCI)

```bash
# Pull chart tertentu
helm pull oci://ghcr.io/rizkyprilian/<chart-name> --version <version>

# Contoh: Pull cnpg-database chart
helm pull oci://ghcr.io/rizkyprilian/cnpg-database --version 0.3.0

# Extract dan install
tar -xzf cnpg-database-0.3.0.tgz
cd cnpg-database
helm install my-database . -f values.yaml -n database-namespace --create-namespace
```

### Dari Git Repository

```bash
# Clone repository
git clone https://github.com/rizkyprilian/dataproduct-starterkit.git
cd dataproduct-starterkit

# Install chart
cd charts/cnpg-database
helm install my-database . -f values.yaml -n database-namespace --create-namespace
```

## Pola Penggunaan Umum

### Pola 1: Complete Database Stack

Deploy database PostgreSQL dengan TLS certificates dan secrets management:

```bash
# 1. Deploy TLS certificates
helm install db-certs charts/database-tls-cert -f db-certs-values.yaml -n database

# 2. Deploy secrets
helm install db-secrets charts/eso-secrets -f db-secrets-values.yaml -n database

# 3. Deploy PostgreSQL database
helm install postgres charts/cnpg-database -f postgres-values.yaml -n database
```

### Pola 2: MySQL Cluster dengan HA

```bash
# Install MySQL InnoDB Cluster
helm install mysql-prod charts/mysql-innodb-cluster \
  -f values-production-ha.yaml \
  -n mysql --create-namespace
```

### Pola 3: Object Storage dengan Ceph

```bash
# Install Ceph RGW resources
helm install storage charts/ceph-rgw-resources \
  -f values-example.yaml \
  -n rook-ceph
```

## Struktur Direktori

```
dataproduct-starterkit/
├── charts/
│   ├── cnpg-database/              # PostgreSQL database chart
│   ├── mysql-innodb-cluster/       # MySQL InnoDB Cluster chart
│   ├── ceph-rgw-resources/         # Ceph RGW buckets dan users
│   ├── database-tls-cert/          # Database TLS certificate management
│   ├── eso-secrets/                # Secrets management
│   └── letsencrypt-tls-cert/       # Let's Encrypt certificates
├── README.md                       # Dokumentasi (English)
└── README.id.md                    # Dokumentasi (Bahasa Indonesia)
```

## Versioning Chart

Semua chart mengikuti [Semantic Versioning](https://semver.org/):

- **Major version (X.0.0):** Breaking changes
- **Minor version (0.X.0):** Fitur baru, backward compatible
- **Patch version (0.0.X):** Bug fixes, backward compatible

## Kontribusi

Kontribusi sangat diterima! Silakan ikuti panduan berikut:

1. Fork repository
2. Buat feature branch: `git checkout -b feature/fitur-baru`
3. Lakukan perubahan dan test dengan teliti
4. Update dokumentasi sesuai kebutuhan
5. Commit perubahan: `git commit -m 'Tambah fitur baru'`
6. Push ke branch: `git push origin feature/fitur-baru`
7. Buka Pull Request

## Dukungan

Untuk issues, pertanyaan, atau kontribusi:

- **GitHub Issues:** [https://github.com/rizkyprilian/dataproduct-starterkit/issues](https://github.com/rizkyprilian/dataproduct-starterkit/issues)
- **Discussions:** Gunakan GitHub Discussions untuk pertanyaan dan ide

## Lisensi

Proyek ini dilisensikan sesuai dengan ketentuan yang ditentukan dalam file [LICENSE](./LICENSE).

## Roadmap

### Selesai

- [x] **cnpg-database**: PostgreSQL dengan CloudNativePG (v0.3.0)
- [x] **mysql-innodb-cluster**: MySQL InnoDB Cluster dengan HA (v0.2.0)
- [x] **ceph-rgw-resources**: Ceph RGW buckets dan users (v0.1.0)
- [x] **database-tls-cert**: Database TLS certificates dengan Vault
- [x] **eso-secrets**: Integrasi External Secrets Operator
- [x] **letsencrypt-tls-cert**: Let's Encrypt certificates

### Direncanakan

- [ ] **monitoring-stack**: Prometheus, Grafana, dan alerting
- [ ] **backup-manager**: Manajemen backup terpusat
- [ ] **data-pipeline**: Apache Airflow atau similar
- [ ] **message-queue**: RabbitMQ atau Kafka
- [ ] **api-gateway**: Kong atau similar
- [ ] **redis-cluster**: Redis dengan high availability

---

**Maintained by:** Rizky Prilian  
**Last Updated:** Oktober 2025
