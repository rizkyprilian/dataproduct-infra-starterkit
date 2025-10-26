# Changelog

All notable changes to the cnpg-database Helm chart will be documented in this file.

## [0.3.0] - 2024-10-26

### Added
- **Declarative Database Management**: Added support for creating and managing multiple databases declaratively using CloudNativePG's Database CRD
  - Create multiple databases beyond the bootstrap database
  - Manage PostgreSQL extensions per database with version control
  - Manage schemas within databases with ownership control
  - Support for `ensure: present/absent` lifecycle management
  - Automatic reconciliation and status tracking by CloudNativePG operator
  - New `databases.yaml` template for rendering Database resources
  - Comprehensive documentation in README.md with examples
  - Follows official CloudNativePG declarative database management specification

### Changed
- Updated chart description to include declarative database management support
- Bumped chart version from 0.2.0 to 0.3.0 (minor version bump for new feature)
- Enhanced README.md with dedicated section on declarative database management
- Added inline documentation in `values.yaml` with detailed examples

### Technical Details
- Database resources are created with proper labels and cluster references
- Supports all CloudNativePG Database CRD features:
  - Required fields: `name`, `owner`, `cluster.name`
  - Optional fields: `ensure`, `extensions`, `schemas`
  - Extension properties: `name`, `ensure`, `version`, `schema`
  - Schema properties: `name`, `owner`, `ensure`
- Reserved database names (`postgres`, `template0`, `template1`) are documented as restricted
- Database objects are reconciled independently from the cluster bootstrap process

## [0.2.0] - 2024-10-22

### Added
- **pg_basebackup Support**: Added ability to clone PostgreSQL clusters from live instances
  - Clone from running CloudNativePG clusters
  - Clone from external PostgreSQL servers
  - Support for password authentication
  - Support for TLS certificate authentication
  - Application database configuration after cloning
  - Comprehensive documentation in `PG_BASEBACKUP.md`
  - Example values file (`values-pg-basebackup-example.yaml`)

- **Recovery Support**: Added ability to bootstrap PostgreSQL clusters from backups
  - Support for recovery from Backup objects
  - Support for recovery from external clusters (object stores)
  - Point-in-Time Recovery (PITR) support with multiple target options:
    - `targetTime`: Recover to a specific timestamp
    - `targetXID`: Recover to a specific transaction ID
    - `targetName`: Recover to a named restore point
    - `targetLSN`: Recover to a specific Log Sequence Number
    - `targetImmediate`: Recover to the earliest consistent point
  - Comprehensive documentation in `RECOVERY.md`
  - Example values file for recovery scenarios (`values-recovery-example.yaml`)

- **External Clusters Support**: Full rendering of externalClusters configuration
  - Support for plugin-based configuration (Barman Cloud Plugin)
  - Support for direct barmanObjectStore configuration
  - Support for connectionParameters (for pg_basebackup)
  - Password and TLS certificate authentication methods

- Enhanced inline documentation in `values.yaml` with examples for all bootstrap methods

### Changed
- Updated `cnpg_cluster.yaml` template to support three bootstrap methods: `pg_basebackup`, `recovery`, and `initdb`
- Added `externalClusters` rendering to cluster template
- Chart description updated to reflect backup, recovery, and cloning capabilities
- Bumped chart version from 0.1.9 to 0.2.0 (minor version bump for new features)

### Technical Details
- Bootstrap method priority: `pg_basebackup` > `recovery` > `initdb` (first defined wins)
- When `bootstrapDB.pg_basebackup` is defined, the chart clones from a live cluster
- When `bootstrapDB.recovery` is defined, the chart restores from a backup
- When neither is defined, the chart creates a new cluster with `initdb`
- All bootstrap methods are mutually exclusive
- Supports CloudNativePG's native bootstrap features as documented in their official documentation

## [0.1.9] - Previous Version
- Initial chart configuration with initdb bootstrap support
- Backup configuration for S3, GCS, and volume snapshots
- TLS/SSL certificate support
- Custom pg_hba configuration
- Managed roles support
