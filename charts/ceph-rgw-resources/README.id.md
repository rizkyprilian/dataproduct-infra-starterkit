# ceph-rgw-resources

[English](./README.md) | **Bahasa Indonesia**

Helm chart sederhana untuk mengelola bucket dan user Ceph RGW (RADOS Gateway) secara deklaratif menggunakan Rook.

## Gambaran Umum

Chart ini menyediakan cara sederhana dan deklaratif untuk membuat dan mengelola:
- **Ceph Object Store Users** (user S3-compatible dengan quotas dan capabilities)
- **Object Bucket Claims** (bucket S3-compatible dengan policies dan lifecycle rules)

Semua resource dikelola melalui Custom Resource Definitions (CRDs) Rook.

## Fitur

- **Manajemen User Deklaratif**:
  - Buat user S3-compatible
  - Set user quotas (max buckets, size, objects)
  - Konfigurasi user capabilities (permissions)
  - Generasi credential otomatis

- **Manajemen Bucket Deklaratif**:
  - Buat bucket S3-compatible
  - Set bucket quotas dan policies
  - Konfigurasi lifecycle rules
  - Assign bucket ke user tertentu
  - Generasi credential otomatis per bucket

## Prasyarat

- Kubernetes 1.19+
- Helm 3.0+
- **Rook Ceph Operator** terinstall dan berjalan
- **CephObjectStore** resource sudah dibuat
- **StorageClass** untuk object storage (contoh: `rook-ceph-bucket`)

## Instalasi

### 1. Verifikasi Rook Ceph Berjalan

```bash
# Check Rook operator
kubectl get pods -n rook-ceph | grep operator

# Check CephObjectStore
kubectl get cephobjectstore -n rook-ceph

# Check StorageClass
kubectl get storageclass | grep bucket
```

### 2. Install Chart

```bash
cd charts/ceph-rgw-resources
helm install my-rgw-resources . -f values.yaml -n rook-ceph
```

## Konfigurasi

### Membuat Users

```yaml
users:
  - name: app-user
    displayName: "Application User"
    quotas:
      maxBuckets: 10
      maxSize: 100G
      maxObjects: 100000
    capabilities:
      user: "*"
      bucket: "*"
```

**User Capabilities:**
- `user`: Permissions manajemen user
- `bucket`: Permissions manajemen bucket
- `usage`: Akses statistik usage
- Values: `read`, `write`, `read, write`, atau `*` (full access)

### Membuat Buckets

```yaml
buckets:
  # Dengan nama bucket spesifik
  - name: app-data
    bucketName: my-app-data-bucket
    additionalConfig:
      maxSize: "10G"
      bucketOwner: "app-user"
  
  # Dengan generated bucket name (recommended)
  - name: backups
    generateBucketName: backups
    additionalConfig:
      maxSize: "100G"
      bucketLifecycle: |
        {
          "Rules": [{
            "ID": "ExpireAfter7Days",
            "Status": "Enabled",
            "Expiration": {"Days": 7}
          }]
        }
```

## Mengakses Credentials

### User Credentials

```bash
# Get access key
kubectl get secret <user-name> -n rook-ceph \
  -o jsonpath='{.data.AccessKey}' | base64 -d

# Get secret key
kubectl get secret <user-name> -n rook-ceph \
  -o jsonpath='{.data.SecretKey}' | base64 -d
```

### Bucket Credentials

```bash
# Get bucket name
kubectl get configmap <bucket-name> -n rook-ceph \
  -o jsonpath='{.data.BUCKET_NAME}'

# Get bucket endpoint
kubectl get configmap <bucket-name> -n rook-ceph \
  -o jsonpath='{.data.BUCKET_HOST}'

# Get access credentials
kubectl get secret <bucket-name> -n rook-ceph \
  -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d
```

## Menggunakan S3 Clients

### AWS CLI

```bash
# Configure AWS CLI
export AWS_ACCESS_KEY_ID=$(kubectl get secret myapp-bucket -n rook-ceph -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
export AWS_SECRET_ACCESS_KEY=$(kubectl get secret myapp-bucket -n rook-ceph -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
export BUCKET_HOST=$(kubectl get configmap myapp-bucket -n rook-ceph -o jsonpath='{.data.BUCKET_HOST}')

# List objects
aws s3 ls s3://$BUCKET_NAME --endpoint-url http://$BUCKET_HOST

# Upload file
aws s3 cp myfile.txt s3://$BUCKET_NAME/ --endpoint-url http://$BUCKET_HOST
```

## Monitoring

### Check User Status

```bash
# List users
kubectl get cephobjectstoreuser -n rook-ceph

# Describe user
kubectl describe cephobjectstoreuser <user-name> -n rook-ceph
```

### Check Bucket Status

```bash
# List buckets
kubectl get objectbucketclaim -n rook-ceph

# Describe bucket
kubectl describe objectbucketclaim <bucket-name> -n rook-ceph
```

## Troubleshooting

### User Tidak Terbuat

Check Rook operator logs:

```bash
kubectl logs -n rook-ceph deployment/rook-ceph-operator
```

### Bucket Tidak Ter-provision

Check ObjectBucketClaim status:

```bash
kubectl describe objectbucketclaim <bucket-name> -n rook-ceph
```

Verifikasi StorageClass exists:

```bash
kubectl get storageclass rook-ceph-bucket
```

## Dokumentasi Tambahan

- [Rook Ceph Documentation](https://rook.io/docs/rook/latest/)
- [Object Bucket Claims](https://rook.io/docs/rook/latest/Storage-Configuration/Object-Storage-RGW/ceph-object-bucket-claim/)
- [CephObjectStoreUser CRD](https://rook.io/docs/rook/latest/CRDs/Object-Storage/ceph-object-store-user-crd/)

## Versi

- **Chart Version**: 0.1.0
- **Rook Version**: Compatible dengan Rook 1.10+

## Lisensi

Lihat file [LICENSE](../../LICENSE) di root repository.
