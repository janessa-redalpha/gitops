# Exercise 03 - Quick Reference Guide

## What's Included

**File**: `exercise03-multi-source-deliverables.zip` (22KB)

This zip contains a **production-ready multi-source FluxCD setup** with:
- ✅ 3 separate Git repositories
- ✅ 1 Helm repository (Bitnami)
- ✅ Complete documentation
- ✅ Step-by-step setup guide

## Repository Structure

### Three Independent Repositories:

1. **`gitops-main/`** - Central GitOps repository
   - Flux installation config
   - Source definitions (GitRepository, HelmRepository)
   - Application Kustomizations
   - Infrastructure HelmReleases

2. **`frontend-app/`** - Frontend application
   - Nginx deployment (2 replicas)
   - Owned by: frontend-team
   - Reconciles every 2 minutes

3. **`backend-api/`** - Backend API
   - HTTP Echo API (3 replicas)
   - Owned by: backend-team
   - Reconciles every 3 minutes
   - Depends on Redis infrastructure

## Quick Setup Steps

1. **Extract the zip file**:
   ```bash
   unzip exercise03-multi-source-deliverables.zip
   cd multi-source-demo
   ```

2. **Read the documentation**:
   - `DELIVERABLES.md` - Complete submission document
   - `SETUP-GUIDE.md` - Step-by-step deployment instructions
   - `gitops-main/README.md` - Repository-specific guide

3. **Create GitHub repositories**:
   ```bash
   gh repo create YOUR-ORG/gitops-main --public
   gh repo create YOUR-ORG/frontend-app --public
   gh repo create YOUR-ORG/backend-api --public
   ```

4. **Update URLs** (replace `YOUR-ORG` with your GitHub username):
   - `gitops-main/clusters/production/sources/frontend-repo.yaml`
   - `gitops-main/clusters/production/sources/backend-repo.yaml`
   - `gitops-main/clusters/production/flux-system/gotk-sync.yaml`

5. **Generate Flux components**:
   ```bash
   cd gitops-main
   flux install --export > clusters/production/flux-system/gotk-components.yaml
   ```

6. **Push all repositories**:
   ```bash
   # From each repo directory:
   git remote add origin https://github.com/YOUR-ORG/<repo-name>.git
   git push -u origin main
   ```

7. **Bootstrap Flux**:
   ```bash
   flux bootstrap github \
     --owner=YOUR-ORG \
     --repository=gitops-main \
     --branch=main \
     --path=clusters/production/flux-system \
     --personal
   ```

8. **Verify deployment**:
   ```bash
   flux get sources all -A
   flux get kustomizations -A
   kubectl -n apps get pods
   ```

## Key Features

### Multi-Source Configuration
- **3 Git sources**: gitops-main, frontend-app, backend-api
- **1 Helm source**: Bitnami charts
- **Different intervals**: 1m, 2m, 3m, 5m, 10m

### Independent Reconciliation
- **Frontend**: No dependencies, updates every 2m
- **Backend**: Depends on Redis, updates every 3m
- **Infrastructure**: Redis from Helm, updates every 10m

### Team Ownership
- **frontend-team**: Owns frontend-app repo
- **backend-team**: Owns backend-api repo
- **platform-team**: Owns gitops-main and infrastructure

### Application Isolation
- Separate Git repositories per team
- Independent Kustomizations
- Health checks per application
- Isolated failure domains

## Documentation Files

| File | Purpose |
|------|---------|
| `DELIVERABLES.md` | Complete submission document with all details |
| `SETUP-GUIDE.md` | Step-by-step deployment guide with troubleshooting |
| `gitops-main/README.md` | GitOps repository documentation |
| `frontend-app/README.md` | Frontend application details |
| `backend-api/README.md` | Backend API details |

## Expected Results

After successful deployment:

- ✅ 2 frontend pods running (nginx)
- ✅ 3 backend pods running (http-echo)
- ✅ 1 Redis pod running (from Helm)
- ✅ All sources reporting "Ready"
- ✅ All Kustomizations reporting "Ready"
- ✅ Backend deployment waiting for Redis (dependency)

## Verification Commands

```bash
# Check all sources
flux get sources all -A

# Check all Kustomizations
flux get kustomizations -A

# Check HelmReleases
flux get helmreleases -A

# Check application status
kubectl -n apps get deployments,pods,services
```

## Support

For detailed instructions, see:
- `SETUP-GUIDE.md` for step-by-step deployment
- `DELIVERABLES.md` for architecture and rationale
- Each repository's `README.md` for specific details

## Submission Contents

✅ **Source YAMLs**: GitRepository and HelmRepository definitions  
✅ **Kustomization YAMLs**: Application reconciliation configs  
✅ **HelmRelease YAML**: Redis with pinned version (19.6.4)  
✅ **Application Manifests**: Deployments and Services  
✅ **Documentation**: Complete setup and architecture guide  
✅ **Isolation Explanation**: Team ownership and boundaries  

---

**Ready for Submission**: `exercise03-multi-source-deliverables.zip`

