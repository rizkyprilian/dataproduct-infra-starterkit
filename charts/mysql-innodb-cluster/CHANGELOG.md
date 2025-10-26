# Changelog

All notable changes to the mysql-innodb-cluster Helm chart will be documented in this file.

## [0.2.0] - 2024-10-26

### Added

- **Vault TLS Certificate Support**: Integration with HashiCorp Vault for automated TLS certificate management
  - Uses cert-manager with Vault issuer for certificate generation
  - Automatic certificate rotation
  - Compatible with the same Vault PKI setup as PostgreSQL (cnpg-database chart)
  - Configurable DNS SANs for certificate
  - Service account and RBAC setup for Vault authentication
  - New `serverCerts` configuration section in values.yaml
  - New `server-certs.yaml` template for certificate resources

### Changed

- Updated `innodbcluster.yaml` template to support three TLS modes:
  - Vault-issued certificates (when `serverCerts.enabled=true`)
  - Self-signed certificates (default, when `tls.useSelfSigned=true`)
  - Custom certificates (when providing `tls.tlsSecret`)
- Enhanced TLS configuration documentation in README
- Updated chart description to include Vault TLS support
- Bumped chart version from 0.1.0 to 0.2.0

### Technical Details

- Certificate format uses standard X.509 PEM encoding
- Compatible with PostgreSQL TLS certificates (same format)
- Requires cert-manager for Vault integration
- Uses Kubernetes service account token for Vault authentication
- Supports both server auth and client auth certificate usages

## [0.1.0] - 2024-10-26

### Added

- **Initial Release**: MySQL InnoDB Cluster Helm chart based on MySQL Operator for Kubernetes
- **High Availability Clustering**:
  - Configurable number of MySQL instances (default: 3)
  - MySQL Router for intelligent connection routing
  - Group Replication for data consistency
  - Automatic failover capabilities
  - Configurable base server IDs

- **Backup Support**:
  - PersistentVolumeClaim backup storage
  - OCI Object Storage backup support
  - S3-compatible storage backup (MySQL Operator 9.1.0+)
  - Reusable backup profiles
  - Scheduled backups using Kubernetes CronJobs
  - Configurable backup options and exclusions

- **Flexible Initialization**:
  - Bootstrap from scratch (default)
  - Clone from existing MySQL instances
  - Restore from dumps (OCI, S3, or PVC)

- **Security Features**:
  - TLS/SSL encryption support
  - Self-signed certificate generation
  - Custom certificate support
  - Secure credential management via Kubernetes Secrets

- **Kubernetes Native Features**:
  - Pod anti-affinity configuration (preferred or required)
  - Resource limits and requests
  - Custom storage classes
  - Service configuration options
  - Pod Disruption Budget support
  - Node selectors and tolerations
  - Custom labels and annotations

- **Configuration Options**:
  - Custom my.cnf configuration
  - Configurable MySQL and Router versions
  - Storage size and class configuration
  - Service type and annotations
  - Image pull secrets support

- **Documentation**:
  - Comprehensive README with examples
  - Production HA example values file
  - Development example values file
  - Clone from existing cluster example
  - Installation and upgrade guides
  - Troubleshooting section

### Technical Details

- Chart API version: v2
- Default MySQL version: 9.1.0
- Default MySQL Router version: 9.1.0
- Requires MySQL Operator for Kubernetes v2.0.0+
- Supports Kubernetes 1.19+
- Uses InnoDBCluster CRD from mysql.oracle.com/v2 API

### Dependencies

- MySQL Operator for Kubernetes must be installed separately
- Requires appropriate storage class for persistent volumes
- Optional: S3 or OCI credentials for backup storage
