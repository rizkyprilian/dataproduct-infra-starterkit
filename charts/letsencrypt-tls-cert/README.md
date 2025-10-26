# Let's Encrypt TLS Certificate Helm Chart

This Helm chart deploys Let's Encrypt TLS certificates using cert-manager with optional issuer creation.

## Features

- Deploy multiple TLS certificates from a single chart
- Support for both `Issuer` and `ClusterIssuer` resources
- Optional issuer creation or use existing issuers in the cluster
- Flexible ACME challenge solver configuration (HTTP-01, DNS-01)
- Support for multiple DNS names/domains per certificate
- Configurable certificate duration and renewal settings

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- cert-manager 1.0+ installed in the cluster

## Installing the Chart

To install the chart with the release name `my-certs`:

```bash
helm install my-certs ./letsencrypt-tls-cert
```

## Uninstalling the Chart

To uninstall/delete the `my-certs` deployment:

```bash
helm delete my-certs
```

## Configuration

### Global Issuer Configuration

You can optionally create a global issuer that can be used by all certificates:

```yaml
globalIssuer:
  create: true
  kind: ClusterIssuer  # or Issuer
  server: https://acme-v02.api.letsencrypt.org/directory
  email: admin@example.com
  privateKeySecretName: letsencrypt-account-key
  solvers:
    - http01:
        ingress:
          class: nginx
```

### Certificate Configuration

The main configuration is done through the `certificates` array. Each certificate can have its own issuer configuration.

#### Example 1: Using an Existing ClusterIssuer

```yaml
certificates:
  - name: example-com-cert
    dnsNames:
      - example.com
      - www.example.com
    secretName: example-com-tls
    issuer:
      name: letsencrypt-prod
      kind: ClusterIssuer
```

#### Example 2: Creating a New Issuer with HTTP-01 Challenge

```yaml
certificates:
  - name: app-cert
    dnsNames:
      - app.example.com
    secretName: app-tls
    issuer:
      name: letsencrypt-http
      kind: Issuer
      create: true
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: admin@example.com
        privateKeySecretName: letsencrypt-http-key
        solvers:
          - http01:
              ingress:
                class: nginx
```

#### Example 3: Creating a ClusterIssuer with DNS-01 Challenge (Cloudflare)

```yaml
certificates:
  - name: wildcard-cert
    dnsNames:
      - "*.example.com"
      - example.com
    secretName: wildcard-tls
    issuer:
      name: letsencrypt-dns
      kind: ClusterIssuer
      create: true
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: admin@example.com
        privateKeySecretName: letsencrypt-dns-key
        solvers:
          - dns01:
              cloudflare:
                email: admin@example.com
                apiTokenSecretRef:
                  name: cloudflare-api-token
                  key: api-token
```

#### Example 4: Multiple Certificates with Different Configurations

```yaml
certificates:
  # Certificate using existing ClusterIssuer
  - name: web-cert
    dnsNames:
      - web.example.com
    secretName: web-tls
    issuer:
      name: letsencrypt-prod
      kind: ClusterIssuer
    duration: 2160h  # 90 days
    renewBefore: 720h  # 30 days
    usages:
      - digital signature
      - key encipherment
  
  # Certificate with its own Issuer
  - name: api-cert
    dnsNames:
      - api.example.com
      - api-v2.example.com
    secretName: api-tls
    commonName: api.example.com
    issuer:
      name: api-issuer
      kind: Issuer
      create: true
      acme:
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        email: devops@example.com
        privateKeySecretName: api-issuer-key
        solvers:
          - http01:
              ingress:
                class: nginx
                ingressTemplate:
                  metadata:
                    annotations:
                      nginx.ingress.kubernetes.io/ssl-redirect: "false"
```

### Configuration Parameters

#### Global Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `nameOverride` | Override the chart name | `""` |
| `fullnameOverride` | Override the full name | `""` |

#### Global Issuer Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `globalIssuer.create` | Create a global issuer | `false` |
| `globalIssuer.kind` | Issuer kind (Issuer or ClusterIssuer) | `ClusterIssuer` |
| `globalIssuer.server` | ACME server URL | `https://acme-v02.api.letsencrypt.org/directory` |
| `globalIssuer.email` | Email for ACME account | `""` (required if create=true) |
| `globalIssuer.privateKeySecretName` | Secret name for ACME account key | `letsencrypt-account-key` |
| `globalIssuer.solvers` | ACME challenge solvers | `[]` |

#### Certificate Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `certificates[].name` | Certificate name | Yes |
| `certificates[].dnsNames` | Array of DNS names/domains | Yes |
| `certificates[].secretName` | Secret name to store certificate | No (defaults to name) |
| `certificates[].issuer.name` | Issuer name | Yes |
| `certificates[].issuer.kind` | Issuer kind (Issuer/ClusterIssuer) | No (default: ClusterIssuer) |
| `certificates[].issuer.create` | Create the issuer | No (default: false) |
| `certificates[].issuer.acme.server` | ACME server URL | No (if create=true) |
| `certificates[].issuer.acme.email` | Email for ACME account | Yes (if create=true) |
| `certificates[].issuer.acme.privateKeySecretName` | ACME account key secret | No |
| `certificates[].issuer.acme.solvers` | ACME challenge solvers | No |
| `certificates[].duration` | Certificate duration | No (default: 2160h) |
| `certificates[].renewBefore` | Renew before expiry | No (default: 720h) |
| `certificates[].commonName` | Common name | No |
| `certificates[].ipAddresses` | Array of IP addresses | No |
| `certificates[].uris` | Array of URIs | No |
| `certificates[].usages` | Certificate usages | No |
| `certificates[].isCA` | Is CA certificate | No (default: false) |
| `certificates[].additionalOutputFormats` | Additional output formats | No |

## ACME Challenge Solvers

### HTTP-01 Challenge

```yaml
solvers:
  - http01:
      ingress:
        class: nginx
```

### DNS-01 Challenge Examples

#### Cloudflare

```yaml
solvers:
  - dns01:
      cloudflare:
        email: user@example.com
        apiTokenSecretRef:
          name: cloudflare-api-token
          key: api-token
```

#### Route53 (AWS)

```yaml
solvers:
  - dns01:
      route53:
        region: us-east-1
        accessKeyID: AKIAIOSFODNN7EXAMPLE
        secretAccessKeySecretRef:
          name: route53-credentials
          key: secret-access-key
```

#### Google Cloud DNS

```yaml
solvers:
  - dns01:
      cloudDNS:
        project: my-project
        serviceAccountSecretRef:
          name: clouddns-service-account
          key: key.json
```

## Common Use Cases

### 1. Single Domain Certificate

```yaml
certificates:
  - name: single-domain
    dnsNames:
      - example.com
    issuer:
      name: letsencrypt-prod
      kind: ClusterIssuer
```

### 2. Multi-Domain Certificate (SAN)

```yaml
certificates:
  - name: multi-domain
    dnsNames:
      - example.com
      - www.example.com
      - api.example.com
    issuer:
      name: letsencrypt-prod
      kind: ClusterIssuer
```

### 3. Wildcard Certificate

```yaml
certificates:
  - name: wildcard
    dnsNames:
      - "*.example.com"
      - example.com
    issuer:
      name: letsencrypt-dns
      kind: ClusterIssuer
      create: true
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: admin@example.com
        solvers:
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: cloudflare-token
                  key: token
```

### 4. Staging Environment (Let's Encrypt Staging)

```yaml
certificates:
  - name: staging-cert
    dnsNames:
      - staging.example.com
    issuer:
      name: letsencrypt-staging
      kind: ClusterIssuer
      create: true
      acme:
        server: https://acme-staging-v02.api.letsencrypt.org/directory
        email: admin@example.com
        solvers:
          - http01:
              ingress:
                class: nginx
```

## Troubleshooting

### Check Certificate Status

```bash
kubectl get certificate -n <namespace>
kubectl describe certificate <certificate-name> -n <namespace>
```

### Check Issuer Status

```bash
kubectl get issuer -n <namespace>
kubectl get clusterissuer
kubectl describe issuer <issuer-name> -n <namespace>
```

### Check Certificate Request

```bash
kubectl get certificaterequest -n <namespace>
kubectl describe certificaterequest <request-name> -n <namespace>
```

### Check Challenge Status

```bash
kubectl get challenge -n <namespace>
kubectl describe challenge <challenge-name> -n <namespace>
```

## Notes

- For wildcard certificates, you must use DNS-01 challenge
- HTTP-01 challenge requires the domain to be publicly accessible
- Let's Encrypt has rate limits - use staging environment for testing
- Certificate secrets are automatically created by cert-manager

## License

This chart is provided as-is.
