# eso-secrets

A Helm chart for managing Kubernetes secrets using External Secrets Operator (ESO) with HashiCorp Vault backend.

## Overview

This chart simplifies the deployment of External Secrets Operator resources to synchronize secrets from HashiCorp Vault into Kubernetes. It creates SecretStore and ExternalSecret resources that automatically fetch and sync secrets from Vault's KV secrets engine.

## Features

- **Automated Secret Synchronization**: Automatically sync secrets from Vault to Kubernetes
- **Multiple Secret Support**: Deploy multiple ExternalSecret resources in a single chart
- **Vault KV v2 Support**: Works with Vault's KV version 2 secrets engine
- **Service Account Management**: Optional service account creation for Vault authentication
- **Flexible Configuration**: Support for various conversion and decoding strategies
- **Metadata Control**: Configurable metadata policies for secret management

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- [External Secrets Operator](https://external-secrets.io/latest/introduction/getting-started/) installed in your cluster
- HashiCorp Vault with KV v2 secrets engine
- Vault Kubernetes auth backend configured
- Secrets stored in Vault KV store

## Installation

### From GitHub Container Registry (OCI)

The charts are automatically published to GitHub Container Registry on every push to the main branch.

#### 1. Pull the chart

```bash
helm pull oci://ghcr.io/rizkyprilian/eso-secrets --version 0.1.0
```

#### 2. Extract and customize

```bash
tar -xzf eso-secrets-0.1.0.tgz
cd eso-secrets
cp values.yaml my-values.yaml
# Edit my-values.yaml with your configuration
```

#### 3. Install the chart

```bash
helm install my-secrets . -f my-values.yaml -n application-namespace --create-namespace
```

### From Git Repository

#### 1. Clone the repository

```bash
git clone https://github.com/rizkyprilian/dataproduct-starterkit.git
cd dataproduct-starterkit/charts/eso-secrets
```

#### 2. Customize values

```bash
cp values.yaml my-values.yaml
# Edit my-values.yaml with your configuration
```

#### 3. Install the chart

```bash
helm install my-secrets . -f my-values.yaml -n application-namespace --create-namespace
```

### As a Subchart (Recommended for ArgoCD)

Add to your `Chart.yaml`:

```yaml
apiVersion: v2
name: my-application
description: My application with external secrets
type: application
version: 0.1.0

dependencies:
  - name: eso-secrets
    version: 0.1.0
    repository: oci://ghcr.io/rizkyprilian
```

Then in your `values.yaml`:

```yaml
eso-secrets:
  serviceAccount:
    create: true
    name: my-app-sa
  
  externalSecretOperator:
    vaultSecretStore:
      enabled: true
      server: "https://vault-private.example.com"
      path: "kv-myapp"
      version: "v2"
      mountPath: "myapp-k8s-dev"
      role: "myapp-dev"
    
    deploySecrets:
      - name: database-credentials
        data:
          - secretKey: username
            remoteKey: dev/database
            remoteProperty: username
          - secretKey: password
            remoteKey: dev/database
            remoteProperty: password
```

## Configuration

### Basic Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `serviceAccount.create` | Create a service account | `true` |
| `serviceAccount.automount` | Automount service account token | `true` |
| `serviceAccount.annotations` | Annotations for service account | `{}` |
| `serviceAccount.name` | Service account name | Generated from release name |

### Vault SecretStore Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `externalSecretOperator.vaultSecretStore.enabled` | Enable Vault SecretStore | Yes |
| `externalSecretOperator.vaultSecretStore.server` | Vault server URL | Yes |
| `externalSecretOperator.vaultSecretStore.path` | Vault KV path | Yes |
| `externalSecretOperator.vaultSecretStore.version` | KV version (v1 or v2) | Yes |
| `externalSecretOperator.vaultSecretStore.mountPath` | Kubernetes auth mount path | Yes |
| `externalSecretOperator.vaultSecretStore.role` | Vault role for authentication | Yes |

### ExternalSecret Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `externalSecretOperator.deploySecrets[].name` | Name of the Kubernetes secret | Yes |
| `externalSecretOperator.deploySecrets[].data[].secretKey` | Key name in Kubernetes secret | Yes |
| `externalSecretOperator.deploySecrets[].data[].remoteKey` | Path to secret in Vault | Yes |
| `externalSecretOperator.deploySecrets[].data[].remoteProperty` | Property name in Vault secret | Yes |
| `externalSecretOperator.deploySecrets[].data[].conversionStrategy` | Conversion strategy | No |
| `externalSecretOperator.deploySecrets[].data[].decodingStrategy` | Decoding strategy | No |
| `externalSecretOperator.deploySecrets[].data[].metadataPolicy` | Metadata policy | No |

## Usage Examples

### Example 1: Simple Database Credentials

```yaml
serviceAccount:
  create: true
  name: myapp-sa

externalSecretOperator:
  vaultSecretStore:
    enabled: true
    server: "https://vault-private.example.com"
    path: "kv-myapp"
    version: "v2"
    mountPath: "myapp-k8s-dev"
    role: "myapp-dev"
  
  deploySecrets:
    - name: database-credentials
      data:
        - secretKey: DB_HOST
          remoteKey: dev/database
          remoteProperty: host
        - secretKey: DB_PORT
          remoteKey: dev/database
          remoteProperty: port
        - secretKey: DB_USERNAME
          remoteKey: dev/database
          remoteProperty: username
        - secretKey: DB_PASSWORD
          remoteKey: dev/database
          remoteProperty: password
```

### Example 2: Multiple Secrets from Different Paths

```yaml
serviceAccount:
  create: true
  name: myapp-sa

externalSecretOperator:
  vaultSecretStore:
    enabled: true
    server: "https://vault-private.example.com"
    path: "kv-myapp"
    version: "v2"
    mountPath: "myapp-k8s-prod"
    role: "myapp-prod"
  
  deploySecrets:
    # Database credentials
    - name: postgres-credentials
      data:
        - secretKey: username
          remoteKey: prod/postgres
          remoteProperty: username
        - secretKey: password
          remoteKey: prod/postgres
          remoteProperty: password
    
    # API keys
    - name: api-keys
      data:
        - secretKey: stripe-key
          remoteKey: prod/api-keys
          remoteProperty: stripe
        - secretKey: sendgrid-key
          remoteKey: prod/api-keys
          remoteProperty: sendgrid
    
    # OAuth credentials
    - name: oauth-config
      data:
        - secretKey: client-id
          remoteKey: prod/oauth
          remoteProperty: client_id
        - secretKey: client-secret
          remoteKey: prod/oauth
          remoteProperty: client_secret
```

### Example 3: With Conversion and Decoding Strategies

```yaml
serviceAccount:
  create: true
  name: myapp-sa

externalSecretOperator:
  vaultSecretStore:
    enabled: true
    server: "https://vault-private.example.com"
    path: "kv-myapp"
    version: "v2"
    mountPath: "myapp-k8s-dev"
    role: "myapp-dev"
  
  deploySecrets:
    - name: app-config
      data:
        # Plain text secret
        - secretKey: api-key
          remoteKey: dev/config
          remoteProperty: api_key
          conversionStrategy: "Default"
          decodingStrategy: "None"
        
        # Base64 encoded secret
        - secretKey: certificate
          remoteKey: dev/config
          remoteProperty: cert
          conversionStrategy: "Default"
          decodingStrategy: "Base64"
        
        # JSON secret
        - secretKey: config-json
          remoteKey: dev/config
          remoteProperty: json_config
          conversionStrategy: "Default"
          decodingStrategy: "None"
          metadataPolicy: "None"
```

### Example 4: Production Setup with Annotations

```yaml
serviceAccount:
  create: true
  name: production-app-sa
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/production-app

externalSecretOperator:
  vaultSecretStore:
    enabled: true
    server: "https://vault-private.example.com"
    path: "kv-production"
    version: "v2"
    mountPath: "production-k8s-cluster"
    role: "production-app-role"
  
  deploySecrets:
    - name: production-secrets
      data:
        - secretKey: DATABASE_URL
          remoteKey: production/app/database
          remoteProperty: connection_string
        - secretKey: REDIS_URL
          remoteKey: production/app/redis
          remoteProperty: connection_string
        - secretKey: S3_ACCESS_KEY
          remoteKey: production/app/aws
          remoteProperty: access_key_id
        - secretKey: S3_SECRET_KEY
          remoteKey: production/app/aws
          remoteProperty: secret_access_key
```

## How It Works

1. **Service Account**: The chart creates a Kubernetes service account (if enabled)
2. **SecretStore**: A SecretStore resource is created, configured to authenticate with Vault using Kubernetes auth
3. **ExternalSecrets**: For each secret in `deploySecrets`, an ExternalSecret resource is created
4. **Synchronization**: ESO watches the ExternalSecret resources and fetches data from Vault
5. **Secret Creation**: ESO creates/updates Kubernetes secrets with the data from Vault
6. **Auto-Refresh**: Secrets are automatically refreshed when values change in Vault

## Vault Setup

### 1. Enable KV v2 Secrets Engine

```bash
vault secrets enable -path=kv-myapp kv-v2
```

### 2. Store Secrets in Vault

```bash
# Store database credentials
vault kv put kv-myapp/dev/database \
  host=postgres.example.com \
  port=5432 \
  username=myapp \
  password=secret123

# Store API keys
vault kv put kv-myapp/dev/api-keys \
  stripe=sk_test_123 \
  sendgrid=SG.123
```

### 3. Create Vault Policy

```hcl
# Policy: myapp-dev-policy
path "kv-myapp/data/dev/*" {
  capabilities = ["read", "list"]
}
```

### 4. Configure Kubernetes Auth

```bash
# Enable Kubernetes auth
vault auth enable -path=myapp-k8s-dev kubernetes

# Configure Kubernetes auth
vault write auth/myapp-k8s-dev/config \
  kubernetes_host="https://kubernetes.default.svc" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create role
vault write auth/myapp-k8s-dev/role/myapp-dev \
  bound_service_account_names=myapp-sa \
  bound_service_account_namespaces=application-namespace \
  policies=myapp-dev-policy \
  ttl=24h
```

## Verifying Secrets

### Check SecretStore Status

```bash
# List SecretStores
kubectl get secretstores -n application-namespace

# Describe SecretStore
kubectl describe secretstore <release-name>-vault-secret-store -n application-namespace
```

### Check ExternalSecret Status

```bash
# List ExternalSecrets
kubectl get externalsecrets -n application-namespace

# Describe an ExternalSecret
kubectl describe externalsecret <secret-name> -n application-namespace

# Check sync status
kubectl get externalsecret <secret-name> -n application-namespace -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

### Verify Kubernetes Secret

```bash
# List secrets
kubectl get secrets -n application-namespace

# View secret data
kubectl get secret <secret-name> -n application-namespace -o yaml

# Decode secret value
kubectl get secret <secret-name> -n application-namespace \
  -o jsonpath='{.data.password}' | base64 -d
```

## Troubleshooting

### ExternalSecret Not Syncing

**Check ESO logs:**
```bash
kubectl logs -n external-secrets-system deployment/external-secrets
```

**Check ExternalSecret status:**
```bash
kubectl describe externalsecret <secret-name> -n application-namespace
```

**Common issues:**
- Vault server unreachable
- Incorrect Vault path or role
- Service account not authorized in Vault
- Secret doesn't exist in Vault
- Incorrect remoteKey or remoteProperty

### Vault Authentication Failures

**Verify service account exists:**
```bash
kubectl get sa -n application-namespace
```

**Check Vault auth configuration:**
- Ensure Kubernetes auth backend is enabled at the correct path
- Verify the role exists and has correct bound service accounts
- Check Vault policies allow reading the secrets

**Test Vault authentication manually:**
```bash
# Get service account token
SA_TOKEN=$(kubectl get secret -n application-namespace \
  $(kubectl get sa myapp-sa -n application-namespace -o jsonpath='{.secrets[0].name}') \
  -o jsonpath='{.data.token}' | base64 -d)

# Test login
vault write auth/myapp-k8s-dev/login \
  role=myapp-dev \
  jwt=$SA_TOKEN
```

### Secret Not Found in Vault

**Verify secret exists:**
```bash
vault kv get kv-myapp/dev/database
```

**Check path format:**
- For KV v2, the data path is automatically prefixed with `/data/`
- Ensure `remoteKey` matches the actual path in Vault
- Verify `remoteProperty` matches the key in the secret

### Permission Denied Errors

**Check Vault policy:**
```bash
vault policy read myapp-dev-policy
```

**Verify role policies:**
```bash
vault read auth/myapp-k8s-dev/role/myapp-dev
```

## Conversion and Decoding Strategies

### Conversion Strategies

- **Default**: No conversion applied
- **Unicode**: Convert to Unicode
- **ToString**: Convert to string representation

### Decoding Strategies

- **None**: No decoding (default)
- **Base64**: Decode from Base64
- **Base64URL**: Decode from Base64 URL-safe encoding
- **Auto**: Automatically detect encoding

### Metadata Policy

- **None**: No metadata (default)
- **Fetch**: Include metadata from Vault

## Upgrading

```bash
helm upgrade my-secrets oci://ghcr.io/rizkyprilian/eso-secrets \
  --version 0.1.0 \
  -f my-values.yaml \
  -n application-namespace
```

## Uninstalling

```bash
helm uninstall my-secrets -n application-namespace
```

**Note**: This will delete the SecretStore and ExternalSecret resources. The synced Kubernetes secrets will also be deleted.

## Security Considerations

1. **Least Privilege**: Grant minimal Vault permissions required
2. **Namespace Isolation**: Use separate Vault roles per namespace
3. **Secret Rotation**: Regularly rotate secrets in Vault
4. **Audit Logging**: Enable Vault audit logging
5. **Network Policies**: Restrict network access to Vault
6. **Service Account Tokens**: Use bound service account tokens

## Integration with Applications

### Using Secrets as Environment Variables

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        envFrom:
        - secretRef:
            name: database-credentials
```

### Using Secrets as Volume Mounts

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        volumeMounts:
        - name: secrets
          mountPath: /etc/secrets
          readOnly: true
      volumes:
      - name: secrets
        secret:
          secretName: database-credentials
```

## Additional Resources

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Vault KV Secrets Engine](https://www.vaultproject.io/docs/secrets/kv)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)
- [ESO Vault Provider](https://external-secrets.io/latest/provider/hashicorp-vault/)

## Contributing

This chart is part of the dataproduct-starterkit project. Contributions are welcome!

## License

See the [LICENSE](../../LICENSE) file in the repository root.

## Version

- **Chart Version**: 0.1.0
- **External Secrets Operator**: Compatible with v0.9.0+
- **Vault**: Compatible with Vault 1.10+
