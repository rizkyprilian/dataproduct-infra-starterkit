# GitLab to GitHub Migration Guide

## Overview
This document outlines the migration from GitLab CI to GitHub Actions for the dataproduct-starterkit project.

## Changes Made

### CI/CD Pipeline
- **GitLab CI**: `.gitlab-ci.yml` (2 stages)
- **GitHub Actions**: `.github/workflows/ci.yml` (2 jobs)

### Key Differences

#### 1. Build Helm Image Job
**GitLab CI:**
- Used Kaniko executor for building Docker images
- Triggered only on changes to `helm-image/Dockerfile`
- Required manual Docker auth configuration

**GitHub Actions:**
- Uses Docker Buildx action (standard GitHub approach)
- Path filtering via `if` condition checking commit changes
- Simplified authentication via `docker/login-action`

#### 2. Build and Deploy Charts Job
**GitLab CI:**
- Uploaded charts to GitLab Package Registry
- Used `CI_JOB_TOKEN` for authentication
- Uploaded via curl to GitLab API

**GitHub Actions:**
- Uploads charts as GitHub artifacts (for download/review)
- Pushes charts to GitHub Container Registry (ghcr.io) as OCI artifacts
- Uses `GITHUB_TOKEN` for authentication
- Helm 3 native OCI registry support

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository:

1. **DOCKER_USERNAME**: Your Docker Hub username (currently: `rprilian`)
2. **DOCKER_PASSWORD**: Your Docker Hub password or access token

### How to Add Secrets:
1. Go to your GitHub repository
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret with its corresponding value

## Workflow Triggers

The GitHub Actions workflow runs when:
- Code is pushed to the `main` branch
- Changes are made to files in `charts/**` or `helm-image/Dockerfile`
- Pull requests are opened against the `main` branch

## Chart Distribution

### GitLab (Previous)
Charts were uploaded to GitLab Package Registry at:
```
https://gitlab.com/api/v4/projects/{PROJECT_ID}/packages/helm/api/stable/charts
```

### GitHub (Current)
Charts are distributed via two methods:

1. **GitHub Artifacts**: Available for download from workflow runs
   - Retention: 30 days
   - Access: Actions → Workflow run → Artifacts section

2. **GitHub Container Registry (OCI)**: Permanent storage
   - Location: `ghcr.io/{owner}/{chart-name}`
   - Pull charts using: `helm pull oci://ghcr.io/{owner}/{chart-name} --version {version}`

## Testing the Workflow

1. Make a change to any chart in the `charts/` directory
2. Commit and push to the `main` branch
3. Check the **Actions** tab in your GitHub repository
4. Monitor the workflow execution

## Accessing Published Charts

### From GitHub Container Registry:
```bash
# Login to GitHub Container Registry
echo $GITHUB_TOKEN | helm registry login ghcr.io -u USERNAME --password-stdin

# Pull a chart
helm pull oci://ghcr.io/{owner}/{chart-name} --version {version}

# Install directly
helm install my-release oci://ghcr.io/{owner}/{chart-name} --version {version}
```

### From Workflow Artifacts:
1. Go to **Actions** → Select workflow run
2. Scroll to **Artifacts** section
3. Download `helm-charts` artifact

## Notes

- The `GITHUB_TOKEN` is automatically provided by GitHub Actions (no manual configuration needed)
- GitHub Container Registry (ghcr.io) is free for public repositories
- You may need to make your packages public in GitHub Package settings
- The workflow uses `ubuntu-latest` runners (GitHub-hosted)

## Cleanup

After confirming the GitHub Actions workflow works correctly, you can:
- Delete `.gitlab-ci.yml` file
- Archive or delete the GitLab repository
- Update documentation references from GitLab to GitHub
