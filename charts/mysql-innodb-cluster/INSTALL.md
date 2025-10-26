# Quick Installation Guide

## Prerequisites

1. **Install MySQL Operator for Kubernetes**

```bash
# Install CRDs
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-crds.yaml

# Install Operator
kubectl apply -f https://raw.githubusercontent.com/mysql/mysql-operator/trunk/deploy/deploy-operator.yaml

# Verify installation
kubectl get deployment -n mysql-operator mysql-operator
```

## Installation Steps

### 1. Create Namespace

```bash
kubectl create namespace mysql-cluster
```

### 2. Create Root User Secret

```bash
kubectl create secret generic mysql-root-secret \
  --from-literal=rootUser=root \
  --from-literal=rootHost=% \
  --from-literal=rootPassword=MySecurePassword123! \
  -n mysql-cluster
```

### 3. (Optional) Create Backup Storage

For PVC-based backups:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-backup-pvc
  namespace: mysql-cluster
spec:
  storageClassName: standard
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 100Gi
EOF
```

For S3-based backups:

```bash
kubectl create secret generic s3-backup-credentials \
  --from-literal=accessKey=YOUR_ACCESS_KEY \
  --from-literal=secretKey=YOUR_SECRET_KEY \
  -n mysql-cluster
```

### 4. Install the Chart

**Development Setup:**

```bash
helm install my-mysql-cluster . \
  -f values-development.yaml \
  -n mysql-cluster
```

**Production HA Setup:**

```bash
helm install my-mysql-cluster . \
  -f values-production-ha.yaml \
  -n mysql-cluster
```

**Custom Configuration:**

```bash
# Copy and customize values
cp values.yaml my-values.yaml
# Edit my-values.yaml with your settings

# Install
helm install my-mysql-cluster . \
  -f my-values.yaml \
  -n mysql-cluster
```

## Verification

### Check Cluster Status

```bash
# Get cluster status
kubectl get innodbcluster -n mysql-cluster

# Check pods
kubectl get pods -n mysql-cluster

# Describe cluster
kubectl describe innodbcluster my-mysql-cluster -n mysql-cluster
```

### Connect to MySQL

```bash
# Port-forward
kubectl port-forward svc/my-mysql-cluster 3306:3306 -n mysql-cluster

# In another terminal, connect
mysql -h 127.0.0.1 -P 3306 -u root -p
```

## Post-Installation

### Create Application Database

```sql
CREATE DATABASE myapp;
CREATE USER 'appuser'@'%' IDENTIFIED BY 'apppassword';
GRANT ALL PRIVILEGES ON myapp.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
```

### Verify Cluster Status

```sql
-- Check cluster status
SELECT * FROM performance_schema.replication_group_members;

-- Check router status
SHOW STATUS LIKE 'group_replication%';
```

## Troubleshooting

If pods are not starting:

```bash
# Check operator logs
kubectl logs -n mysql-operator deployment/mysql-operator

# Check pod events
kubectl describe pod my-mysql-cluster-0 -n mysql-cluster

# Check pod logs
kubectl logs my-mysql-cluster-0 -n mysql-cluster -c mysql
```

## Uninstallation

```bash
# Uninstall chart
helm uninstall my-mysql-cluster -n mysql-cluster

# Delete PVCs (if needed)
kubectl delete pvc -l app.kubernetes.io/instance=my-mysql-cluster -n mysql-cluster

# Delete namespace (if needed)
kubectl delete namespace mysql-cluster
```
