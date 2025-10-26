# ceph-rgw-resources

**English** | [Bahasa Indonesia](./README.id.md)

A simple Helm chart for declaratively managing Ceph RGW (RADOS Gateway) buckets and users using Rook.

## Overview

This chart provides a simple, declarative way to create and manage:
- **Ceph Object Store Users** (S3-compatible users with quotas and capabilities)
- **Object Bucket Claims** (S3-compatible buckets with policies and lifecycle rules)

All resources are managed through Rook's Custom Resource Definitions (CRDs).

## Features

- **Declarative User Management**:
  - Create S3-compatible users
  - Set user quotas (max buckets, size, objects)
  - Configure user capabilities (permissions)
  - Automatic credential generation

- **Declarative Bucket Management**:
  - Create S3-compatible buckets
  - Set bucket quotas and policies
  - Configure lifecycle rules
  - Assign buckets to specific users
  - Automatic credential generation per bucket

- **Simple Configuration**:
  - Clean YAML-based configuration
  - Support for multiple users and buckets
  - Automatic secret and configmap creation

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- **Rook Ceph Operator** installed and running
- **CephObjectStore** resource created
- **StorageClass** for object storage (e.g., `rook-ceph-bucket`)

## Installation

### 1. Verify Rook Ceph is Running

```bash
# Check Rook operator
kubectl get pods -n rook-ceph | grep operator

# Check CephObjectStore
kubectl get cephobjectstore -n rook-ceph

# Check StorageClass
kubectl get storageclass | grep bucket
```

### 2. Install the Chart

```bash
cd charts/ceph-rgw-resources
helm install my-rgw-resources . -f values.yaml -n rook-ceph
```

## Configuration

### Basic Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `storageClassName` | StorageClass for object storage | `rook-ceph-bucket` |
| `objectStoreName` | Name of the CephObjectStore | `my-store` |
| `users` | List of users to create | `[]` |
| `buckets` | List of buckets to create | `[]` |

### Creating Users

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
  
  - name: readonly-user
    displayName: "Read-Only User"
    quotas:
      maxBuckets: 5
      maxSize: 10G
    capabilities:
      bucket: "read"
```

**User Capabilities:**
- `user`: User management permissions
- `bucket`: Bucket management permissions
- `usage`: Usage statistics access
- `metadata`: Metadata access
- Values: `read`, `write`, `read, write`, or `*` (full access)

### Creating Buckets

```yaml
buckets:
  # Option 1: Specific bucket name
  - name: app-data
    bucketName: my-app-data-bucket
    additionalConfig:
      maxSize: "10G"
      maxObjects: "10000"
  
  # Option 2: Generated bucket name (recommended)
  - name: backups
    generateBucketName: backups
    additionalConfig:
      maxSize: "100G"
      bucketOwner: "app-user"
  
  # Option 3: With lifecycle policy
  - name: temp-data
    generateBucketName: temp-data
    additionalConfig:
      bucketLifecycle: |
        {
          "Rules": [{
            "ID": "ExpireAfter7Days",
            "Status": "Enabled",
            "Prefix": "",
            "Expiration": {"Days": 7}
          }]
        }
```

**Bucket Configuration Options:**
- `maxObjects`: User quota for max objects
- `maxSize`: User quota for max size
- `bucketMaxObjects`: Bucket-specific quota for max objects
- `bucketMaxSize`: Bucket-specific quota for max size
- `bucketOwner`: Assign bucket to existing user
- `bucketPolicy`: S3 bucket policy (JSON)
- `bucketLifecycle`: S3 lifecycle configuration (JSON)

## Usage Examples

### Example 1: Simple User and Bucket

```yaml
objectStoreName: my-store
storageClassName: rook-ceph-bucket

users:
  - name: myapp-user
    displayName: "My Application User"
    quotas:
      maxBuckets: 5
      maxSize: 50G

buckets:
  - name: myapp-bucket
    generateBucketName: myapp-data
    additionalConfig:
      maxSize: "10G"
      bucketOwner: "myapp-user"
```

### Example 2: Multiple Users with Different Permissions

```yaml
users:
  - name: admin-user
    displayName: "Administrator"
    capabilities:
      user: "*"
      bucket: "*"
      usage: "*"
  
  - name: app-user
    displayName: "Application"
    quotas:
      maxBuckets: 10
      maxSize: 100G
    capabilities:
      bucket: "read, write"
  
  - name: readonly-user
    displayName: "Read Only"
    quotas:
      maxBuckets: 5
    capabilities:
      bucket: "read"
```

### Example 3: Buckets with Lifecycle Policies

```yaml
buckets:
  - name: logs
    generateBucketName: application-logs
    additionalConfig:
      maxSize: "50G"
      bucketLifecycle: |
        {
          "Rules": [
            {
              "ID": "DeleteOldLogs",
              "Status": "Enabled",
              "Prefix": "",
              "Expiration": {"Days": 30}
            },
            {
              "ID": "AbortIncompleteUploads",
              "Status": "Enabled",
              "Prefix": "",
              "AbortIncompleteMultipartUpload": {"DaysAfterInitiation": 1}
            }
          ]
        }
```

## Accessing Credentials

### User Credentials

After creating a user, credentials are stored in a Kubernetes Secret:

```bash
# Get access key
kubectl get secret <user-name> -n rook-ceph \
  -o jsonpath='{.data.AccessKey}' | base64 -d

# Get secret key
kubectl get secret <user-name> -n rook-ceph \
  -o jsonpath='{.data.SecretKey}' | base64 -d
```

### Bucket Credentials

After creating a bucket, credentials and endpoint information are stored:

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

kubectl get secret <bucket-name> -n rook-ceph \
  -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d
```

## Using S3 Clients

### AWS CLI

```bash
# Configure AWS CLI
export AWS_ACCESS_KEY_ID=$(kubectl get secret myapp-bucket -n rook-ceph -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)
export AWS_SECRET_ACCESS_KEY=$(kubectl get secret myapp-bucket -n rook-ceph -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
export BUCKET_NAME=$(kubectl get configmap myapp-bucket -n rook-ceph -o jsonpath='{.data.BUCKET_NAME}')
export BUCKET_HOST=$(kubectl get configmap myapp-bucket -n rook-ceph -o jsonpath='{.data.BUCKET_HOST}')

# List objects
aws s3 ls s3://$BUCKET_NAME --endpoint-url http://$BUCKET_HOST

# Upload file
aws s3 cp myfile.txt s3://$BUCKET_NAME/ --endpoint-url http://$BUCKET_HOST
```

### Python (boto3)

```python
import boto3
import base64
from kubernetes import client, config

# Load kubeconfig
config.load_kube_config()
v1 = client.CoreV1Api()

# Get credentials from secret
secret = v1.read_namespaced_secret("myapp-bucket", "rook-ceph")
access_key = base64.b64decode(secret.data['AWS_ACCESS_KEY_ID']).decode()
secret_key = base64.b64decode(secret.data['AWS_SECRET_ACCESS_KEY']).decode()

# Get bucket info from configmap
configmap = v1.read_namespaced_config_map("myapp-bucket", "rook-ceph")
bucket_name = configmap.data['BUCKET_NAME']
bucket_host = configmap.data['BUCKET_HOST']

# Create S3 client
s3 = boto3.client('s3',
    endpoint_url=f'http://{bucket_host}',
    aws_access_key_id=access_key,
    aws_secret_access_key=secret_key
)

# List objects
response = s3.list_objects_v2(Bucket=bucket_name)
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

# Check bucket binding
kubectl get objectbucket -n rook-ceph
```

## Upgrading

```bash
helm upgrade my-rgw-resources . -f values.yaml -n rook-ceph
```

## Uninstalling

```bash
helm uninstall my-rgw-resources -n rook-ceph
```

**Warning**: This will delete all users and buckets. Ensure you have backups of important data.

## Troubleshooting

### User Not Created

Check Rook operator logs:

```bash
kubectl logs -n rook-ceph deployment/rook-ceph-operator
```

Check user status:

```bash
kubectl describe cephobjectstoreuser <user-name> -n rook-ceph
```

### Bucket Not Provisioned

Check ObjectBucketClaim status:

```bash
kubectl describe objectbucketclaim <bucket-name> -n rook-ceph
```

Verify StorageClass exists:

```bash
kubectl get storageclass rook-ceph-bucket
```

### Cannot Access Bucket

Verify endpoint is accessible:

```bash
BUCKET_HOST=$(kubectl get configmap <bucket-name> -n rook-ceph -o jsonpath='{.data.BUCKET_HOST}')
curl -I http://$BUCKET_HOST
```

Check credentials are correct:

```bash
kubectl get secret <bucket-name> -n rook-ceph -o yaml
```

## Additional Documentation

- [Rook Ceph Documentation](https://rook.io/docs/rook/latest/)
- [Object Bucket Claims](https://rook.io/docs/rook/latest/Storage-Configuration/Object-Storage-RGW/ceph-object-bucket-claim/)
- [CephObjectStoreUser CRD](https://rook.io/docs/rook/latest/CRDs/Object-Storage/ceph-object-store-user-crd/)

## Chart Values Reference

For a complete list of all configurable parameters, see [values.yaml](./values.yaml).

## Version

- **Chart Version**: 0.1.0
- **Rook Version**: Compatible with Rook 1.10+

## Contributing

This chart is part of the dataproduct-starterkit project. Contributions are welcome!

## License

See the [LICENSE](../../LICENSE) file in the repository root.
