# Exercise 01: Basic Git Source Configuration

## ✅ Exercise Complete

This exercise demonstrates FluxCD Git source configuration with HTTPS authentication and automatic synchronization.

## 📁 Files Location

All files are in: `/home/jnssa/GitOps/exercise-01-git-source/`

### Required YAML Files

1. **gitrepository.yaml** - GitRepository with authentication reference
   - Interval: 1 minute
   - Includes secretRef for authentication
   
2. **gitrepository-public.yaml** - GitRepository without authentication (currently deployed)
   - Interval: 1 minute
   - Used for public repositories
   
3. **kustomization.yaml** - Kustomization resource
   - Path: ./exercise-01-git-source/apps
   - Interval: 2 minutes
   - Prune: enabled
   - Wait: enabled

4. **git-secret.yaml** - Secret template for HTTPS authentication
   - Username: git
   - Password: PAT placeholder

### Application Files

- **apps/sample-configmap.yaml** - Sample application deployed by Flux

### Verification Outputs

- **flux-sources-output.txt** - Shows `Ready=True` for gitops-repo
- **flux-kustomizations-output.txt** - Shows applied revision

### Documentation

- **auth-method-note.md** - Detailed rationale for choosing HTTPS with PAT authentication

## 🎯 Current Status

```
GitRepository: gitops-repo
├─ Status: Ready=True
├─ Revision: main@sha1:8ab4bd47
└─ Message: stored artifact for revision

Kustomization: gitops-apps
├─ Status: Ready=True
├─ Revision: main@sha1:8ab4bd47
└─ Message: Applied revision

Deployed Resources:
└─ ConfigMap: sample-app-config (namespace: default)
```

## 🔐 Authentication Method

**Selected: HTTPS with Personal Access Token (PAT)**

Key reasons:
- Simplicity and ease of setup
- Better compatibility across network environments
- Easy token rotation and revocation
- Fine-grained permissions support
- Industry standard for GitOps workflows

See `auth-method-note.md` for detailed rationale.

## ✨ Features Demonstrated

- ✅ Git source configuration with 1-minute sync interval
- ✅ Kustomization with prune enabled
- ✅ Automatic resource deployment
- ✅ Secret-based authentication (HTTPS PAT)
- ✅ Proper namespace configuration (flux-system)
- ✅ Resource verification and reconciliation
