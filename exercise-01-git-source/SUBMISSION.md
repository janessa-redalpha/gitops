# Exercise 01: Basic Git Source Configuration - Submission

## Summary
Successfully configured FluxCD to monitor the Git repository with proper synchronization settings for automatic deployment.

## Deliverables

### 1. GitRepository YAML
- **File**: `gitrepository.yaml` - Version with authentication (for private repos)
- **File**: `gitrepository-public.yaml` - Version without authentication (currently deployed)
- **Configuration**:
  - Repository: https://github.com/janessa-redalpha/gitops.git
  - Branch: main
  - Sync Interval: 1 minute
  - Status: ✅ Ready=True

### 2. Kustomization YAML
- **File**: `kustomization.yaml`
- **Configuration**:
  - Path: ./exercise-01-git-source/apps
  - Sync Interval: 2 minutes
  - Prune: Enabled
  - Wait: Enabled
  - Timeout: 3 minutes
  - Status: ✅ Ready=True, Applied

### 3. Secret Configuration
- **File**: `git-secret.yaml` - Template for HTTPS authentication with PAT
- Secret configured in cluster for authentication scenarios

### 4. Verification Outputs
- **File**: `flux-sources-output.txt` - Shows Ready=True for gitops-repo
- **File**: `flux-kustomizations-output.txt` - Shows Applied revision

### 5. Authentication Method Note
- **File**: `auth-method-note.md` - Detailed rationale for HTTPS with PAT

## Deployed Resources
- Sample ConfigMap successfully deployed to default namespace
- Automatic synchronization confirmed working
- Prune functionality enabled for cleanup

## Status: ✅ COMPLETE
All resources are reconciled and Ready=True.


