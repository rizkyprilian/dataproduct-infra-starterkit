# database-tls-cert

A Helm chart for managing TLS certificates for PostgreSQL databases using cert-manager and HashiCorp Vault.

## Overview

This chart automates the generation and management of TLS certificates for database connections using certificate-based authentication. It integrates with cert-manager and HashiCorp Vault to provide secure, automated certificate lifecycle management.

## Features

- **Automated Certificate Generation**: Creates TLS certificates via cert-manager
- **Vault Integration**: Retrieves certificates from HashiCorp Vault PKI backend
- **Multiple Certificates**: Support for multiple database certificates in a single deployment
- **Service Account Management**: Automatic creation of service accounts for Vault authentication
- **RBAC Configuration**: Proper role bindings for cert-manager integration
- **Certificate Concatenation**: Optional controller to concatenate CA certificates
- **Auto-Reload**: Certificates labeled for automatic reload by CloudNativePG

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- [cert-manager](https://cert-manager.io/docs/installation/) installed in your cluster
- HashiCorp Vault with PKI secrets engine configured
- Vault Kubernetes auth backend configured for your cluster
- Proper Vault policies and roles set up

## Installation

### From GitHub Container Registry (OCI)

The charts are automatically published to GitHub Container Registry on every push to the main branch.

#### 1. Pull the chart

```bash
helm pull oci://ghcr.io/rprilian/database-tls-cert --version 0.1.9
```

#### 2. Extract and customize

```bash
tar -xzf database-tls-cert-0.1.9.tgz
cd database-tls-cert
cp values.yaml my-values.yaml
# Edit my-values.yaml with your configuration
```

#### 3. Install the chart

```bash
helm install db-tls-cert . -f my-values.yaml -n database-namespace --create-namespace
```

### From Git Repository

#### 1. Clone the repository

```bash
git clone https://github.com/rprilian/dataproduct-starterkit.git
cd dataproduct-starterkit/charts/database-tls-cert
```

#### 2. Customize values

```bash
cp values.yaml my-values.yaml
# Edit my-values.yaml with your configuration
```

#### 3. Install the chart

```bash
helm install db-tls-cert . -f my-values.yaml -n database-namespace --create-namespace
```

### As a Subchart (Recommended for ArgoCD)

Add to your `Chart.yaml`:

```yaml
apiVersion: v2
name: my-application
description: My application with database TLS certificates
type: application
version: 0.1.0

dependencies:
  - name: database-tls-cert
    version: 0.1.9
    repository: oci://ghcr.io/rprilian
```

Then in your `values.yaml`:

```yaml
database-tls-cert:
  clusterCertManager:
    serviceAccountName: cert-manager
    namespace: cert-manager
  
  dbServerTLSCertIssuers:
    - certName: my-app-db-cert
      serviceAccountName: my-app-sa
      vault:
        path: pki_int_dev_db/sign/my-app-role
        role: k8s-dev-cluster-my-app
        mount: /v1/auth/k8s-dev-cluster
        server: https://vault-private.example.com
      commonName: my-app-db-user
      dnsNames:
        - my-app-db.example.com
```

## Configuration

The following table lists the configurable parameters of the Database TLS Certificate chart and their default values.

| Parameter | Required | Description | Default |
| --------- | ----------- | ----------- | ------- |
| `name_override` | No | Custom name that will override chart release name | `` |
| `fullname_override` | No | Create a default fully qualified app name. If release name contains chart name it will be used as a full name. | `` |
| `clusterCertManager.serviceAccountName` | Yes | Name of the Cert Manager Service Account according to the target cluster | `cert-manager` |
| `clusterCertManager.namespace` | Yes | Namespace of the Cert Manager according to the target cluster | `cert-manager` |
| `dbServerTLSCertIssuers.*` | Yes | List of Issuer and Certificate to be Generated | List of Objects  |
| `dbServerTLSCertIssuers.*.certName` | Yes | Name of the Certificate to be generated | `` |
| `dbServerTLSCertIssuers.*.serviceAccountName` | Yes | This chart will generate one service account that was allowed in the Vault auth backend role | `` |
| `dbServerTLSCertIssuers.*.vault.path` | Yes | Path where PKI secret is mounted | `` |
| `dbServerTLSCertIssuers.*.vault.role` | Yes | Name of the Auth Backend Role | `` |
| `dbServerTLSCertIssuers.*.vault.mount` | Yes | Auth Mount Endpoint. Specific for each Kubernetes Cluster | `` |
| `dbServerTLSCertIssuers.*.vault.server` | Yes | URI of the Vault Server | `https://vault.jdsdata.id` |
| `dbServerTLSCertIssuers.*.usages` | No | List of usages that will be added to the certificate | `["client auth"]` |
| `dbServerTLSCertIssuers.*.commonName` | No | Common Name for the Certificate. This would be your intended role in the target database | `` |
| `dbServerTLSCertIssuers.*.dnsNames` | No | List of valid DNS Names to be appended to Certificate. These values usually used for server certificate | `JDS` |
| `dbServerTLSCertIssuers.*.ipAddresses` | No | List of valid IPv4 or IPv6 to be added to Certificate (Make sure allowed ip sans configured on the CA). These values usually used for server certificate | `[]` |
| `dbServerTLSCertIssuers.*.additionalOutputFormats` | No | Option to produce additional output format into the secret | List of string with option of `CombinedPEM` or `DER` |
| `rootCA.secretName` | No | Name of the root CA secret to concatenate | `` |
| `rootCA.key` | No | Key name in the root CA secret | `root-ca.pem` |
| `rootConcatController.imageName` | No | Image for the CA concatenation controller | `bitnami/kubectl:latest` |
| `rootConcatController.replicas` | No | Number of controller replicas | `1` |
| `rootConcatController.resources` | No | Resource requests and limits for controller | See values.yaml |

## Usage Examples

### Example 1: Single Database Certificate

```yaml
clusterCertManager:
  serviceAccountName: cert-manager
  namespace: cert-manager

dbServerTLSCertIssuers:
  - certName: myapp-db-cert
    serviceAccountName: myapp-sa
    vault:
      path: pki_int_dev_db/sign/myapp-role
      role: k8s-dev-cluster-myapp
      mount: /v1/auth/k8s-dev-cluster
      server: https://vault-private.example.com
    usages:
      - client auth
    commonName: myapp_user
```

### Example 2: Multiple Certificates for Different Databases

```yaml
clusterCertManager:
  serviceAccountName: cert-manager
  namespace: cert-manager

dbServerTLSCertIssuers:
  # Production database certificate
  - certName: prod-db-cert
    serviceAccountName: prod-app-sa
    vault:
      path: pki_int_prod_db/sign/prod-app-role
      role: k8s-prod-cluster-app
      mount: /v1/auth/k8s-prod-cluster
      server: https://vault-private.example.com
    usages:
      - client auth
    commonName: prod_app_user
  
  # Staging database certificate
  - certName: staging-db-cert
    serviceAccountName: staging-app-sa
    vault:
      path: pki_int_dev_db/sign/staging-app-role
      role: k8s-dev-cluster-app
      mount: /v1/auth/k8s-dev-cluster
      server: https://vault-private.example.com
    usages:
      - client auth
    commonName: staging_app_user
```

### Example 3: Server Certificate with DNS Names

```yaml
clusterCertManager:
  serviceAccountName: cert-manager
  namespace: cert-manager

dbServerTLSCertIssuers:
  - certName: postgres-server-cert
    serviceAccountName: postgres-sa
    vault:
      path: pki_int_prod_db/sign/postgres-server-role
      role: k8s-prod-cluster-postgres
      mount: /v1/auth/k8s-prod-cluster
      server: https://vault-private.example.com
    usages:
      - server auth
      - client auth
    commonName: postgres.example.com
    dnsNames:
      - postgres.example.com
      - postgres-rw.production.svc.cluster.local
      - postgres-ro.production.svc.cluster.local
    additionalOutputFormats:
      - CombinedPEM
```

### Example 4: With Root CA Concatenation

```yaml
clusterCertManager:
  serviceAccountName: cert-manager
  namespace: cert-manager

rootCA:
  secretName: root-ca-secret
  key: root-ca.pem

rootConcatController:
  imageName: bitnami/kubectl:latest
  replicas: 1
  resources:
    requests:
      memory: "64Mi"
      cpu: "50m"
    limits:
      memory: "256Mi"
      cpu: "200m"

dbServerTLSCertIssuers:
  - certName: app-db-cert
    serviceAccountName: app-sa
    vault:
      path: pki_int_dev_db/sign/app-role
      role: k8s-dev-cluster-app
      mount: /v1/auth/k8s-dev-cluster
      server: https://vault-private.example.com
    commonName: app_user
```

## How It Works

1. **Service Account Creation**: The chart creates a Kubernetes service account for each certificate issuer
2. **RBAC Setup**: Role bindings are created to allow cert-manager to access the service account tokens
3. **Vault Issuer**: A cert-manager Issuer is created for each certificate, configured to use Vault
4. **Certificate Request**: cert-manager creates a Certificate resource that requests a certificate from Vault
5. **Secret Creation**: The certificate and private key are stored in a Kubernetes secret
6. **Auto-Reload**: Secrets are labeled with `cnpg.io/reload: "true"` for CloudNativePG integration
7. **CA Concatenation** (optional): A controller watches for certificate changes and concatenates CA certificates

## Integration with CloudNativePG

The generated certificates can be used with CloudNativePG for secure database connections:

```yaml
# In your cnpg-database values.yaml
serverCerts:
  enabled: true
  # Reference the certificate created by this chart
  # The chart creates secrets named after certName

replicationClientCerts:
  enabled: true
  # Reference the replication certificate
```

CloudNativePG will automatically reload certificates when they are renewed, thanks to the `cnpg.io/reload` label.

## Verifying Certificates

### Check Certificate Status

```bash
# List certificates
kubectl get certificates -n database-namespace

# Describe a certificate
kubectl describe certificate myapp-db-cert -n database-namespace

# Check certificate secret
kubectl get secret myapp-db-cert -n database-namespace
```

### View Certificate Details

```bash
# Extract and view certificate
kubectl get secret myapp-db-cert -n database-namespace \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout
```

### Check Issuer Status

```bash
# List issuers
kubectl get issuers -n database-namespace

# Describe an issuer
kubectl describe issuer myapp-db-cert-issuer -n database-namespace
```

## Troubleshooting

### Certificate Not Being Issued

**Check cert-manager logs:**
```bash
kubectl logs -n cert-manager deployment/cert-manager
```

**Check issuer status:**
```bash
kubectl describe issuer <issuer-name> -n database-namespace
```

**Common issues:**
- Vault server unreachable
- Incorrect Vault path or role
- Service account not authorized in Vault
- Kubernetes auth backend not configured

### Vault Authentication Failures

**Verify service account exists:**
```bash
kubectl get sa -n database-namespace
```

**Check Vault auth configuration:**
- Ensure the Kubernetes auth backend is enabled
- Verify the role exists in Vault
- Check the role's bound service accounts
- Confirm the PKI path is correct

### Certificate Renewal Issues

**Check certificate renewal status:**
```bash
kubectl get certificate myapp-db-cert -n database-namespace -o yaml
```

**Force certificate renewal:**
```bash
kubectl delete certificaterequest <request-name> -n database-namespace
```

### CA Concatenation Controller Not Working

**Check controller logs:**
```bash
kubectl logs deployment/<release-name>-concat-ca-controller -n database-namespace
```

**Verify root CA secret exists:**
```bash
kubectl get secret <rootCA.secretName> -n database-namespace
```

## Upgrading

```bash
helm upgrade db-tls-cert oci://ghcr.io/rprilian/database-tls-cert \
  --version 0.1.9 \
  -f my-values.yaml \
  -n database-namespace
```

## Uninstalling

```bash
helm uninstall db-tls-cert -n database-namespace
```

**Note**: This will delete all certificates and secrets created by the chart.

## Security Considerations

1. **Vault Access**: Ensure proper Vault policies are in place to restrict certificate issuance
2. **RBAC**: The chart creates minimal RBAC permissions required for cert-manager
3. **Secret Access**: Limit access to the namespace containing certificate secrets
4. **Certificate Rotation**: Certificates are automatically renewed by cert-manager before expiration
5. **Service Account Tokens**: Use bound service account tokens for Vault authentication

## Additional Resources

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Vault PKI Secrets Engine](https://www.vaultproject.io/docs/secrets/pki)
- [Vault Kubernetes Auth](https://www.vaultproject.io/docs/auth/kubernetes)
- [CloudNativePG TLS Documentation](https://cloudnative-pg.io/documentation/current/certificates/)

## Contributing

This chart is part of the dataproduct-starterkit project. Contributions are welcome!

## License

See the [LICENSE](../../LICENSE) file in the repository root.

## Version

- **Chart Version**: 0.1.9
- **cert-manager**: Compatible with v1.0+
- **Vault**: Compatible with Vault 1.10+
