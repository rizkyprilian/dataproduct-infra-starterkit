# Changelog

All notable changes to the ceph-rgw-resources Helm chart will be documented in this file.

## [0.1.0] - 2024-10-26

### Added

- **Initial Release**: Simple Helm chart for declarative Ceph RGW resource management
- **User Management**:
  - Create CephObjectStoreUser resources
  - Configure user quotas (maxBuckets, maxSize, maxObjects)
  - Set user capabilities (permissions)
  - Automatic credential generation in Kubernetes Secrets
  - Support for multiple users

- **Bucket Management**:
  - Create ObjectBucketClaim resources
  - Support for specific bucket names or generated names
  - Configure bucket quotas and policies
  - Set S3 bucket policies (JSON format)
  - Configure lifecycle rules (JSON format)
  - Assign buckets to specific users
  - Automatic credential generation per bucket
  - Support for multiple buckets

- **Configuration Options**:
  - Configurable storage class
  - Configurable object store name
  - Global labels and annotations
  - Clean YAML-based configuration

- **Documentation**:
  - Comprehensive README with examples
  - Usage examples for AWS CLI and Python
  - Credential access instructions
  - Troubleshooting guide
  - Example values file with multiple scenarios

### Technical Details

- Chart API version: v2
- Uses Rook CRDs: CephObjectStoreUser and ObjectBucketClaim
- Compatible with Rook 1.10+
- Supports Kubernetes 1.19+
- Automatic secret and configmap creation by Rook operator

### Dependencies

- Rook Ceph Operator must be installed
- CephObjectStore resource must exist
- StorageClass for object storage must be configured
