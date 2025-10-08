# Exercise 02: Branch-Based Environment Management

## Goal
Set up FluxCD to deploy different Git branches to different environments (dev, staging, prod) with appropriate synchronization policies and safe promotion flows.

## Architecture Overview

This exercise implements a branch-based GitOps workflow where:
- Each environment (dev, staging, prod) has its own Git branch
- Each environment has dedicated GitRepository and Kustomization resources
- Environments are isolated in separate Kubernetes namespaces
- Dependencies ensure proper promotion order (dev → staging → prod)

## Directory Structure

```
exercise-02-branch-based-environment-management/
├── gitrepository-dev.yaml          # GitRepository for dev environment
├── gitrepository-staging.yaml      # GitRepository for staging environment
├── gitrepository-prod.yaml         # GitRepository for prod environment
├── kustomization-dev.yaml          # Kustomization for dev environment
├── kustomization-staging.yaml      # Kustomization for staging environment (depends on dev)
├── kustomization-prod.yaml         # Kustomization for prod environment (depends on staging)
├── PROMOTION_WORKFLOW.md           # Detailed promotion workflow documentation
├── README.md                       # This file
└── SUBMISSION.md                   # Submission documentation with outputs

apps/myapp/kustomize/
├── base/
│   ├── deployment.yaml             # Base deployment manifest
│   ├── service.yaml                # Base service manifest
│   └── kustomization.yaml          # Base kustomization
└── overlays/
    ├── dev/
    │   └── kustomization.yaml      # Dev-specific overrides (1 replica, minimal resources)
    ├── staging/
    │   └── kustomization.yaml      # Staging overrides (2 replicas, medium resources)
    └── prod/
        └── kustomization.yaml      # Production overrides (3 replicas, high resources)
```

## Implementation Details

### 1. Git Branches

Three branches have been created:
- `dev` - Development environment
- `staging` - Staging environment
- `prod` - Production environment

### 2. GitRepository Resources

Each environment has its own GitRepository resource pointing to the same repository but different branches:

**Dev**: 1-minute sync interval for rapid iteration
**Staging**: 1-minute sync interval for validation
**Prod**: 5-minute sync interval for stability

### 3. Kustomization Resources

Each environment has its own Kustomization resource with:
- Environment-specific namespace (`dev`, `staging`, `prod`)
- Path to environment-specific overlay
- Dependencies to ensure proper order:
  - `staging` depends on `dev`
  - `prod` depends on `staging`

### 4. Kustomize Overlays

Each environment has customized configurations:

| Environment | Replicas | Memory Request | CPU Request | Sync Interval |
|-------------|----------|----------------|-------------|---------------|
| Dev         | 1        | 64Mi           | 100m        | 1m            |
| Staging     | 2        | 128Mi          | 200m        | 2m            |
| Prod        | 3        | 256Mi          | 500m        | 5m            |

## Deployment Instructions

### Prerequisites

1. FluxCD installed on your Kubernetes cluster
2. Git repository authentication configured (PAT or SSH)
3. Kubernetes cluster with necessary permissions

### Step 1: Push Branches to Remote

```bash
# Push the three environment branches to remote
git push origin dev
git push origin staging
git push origin prod
```

### Step 2: Apply GitRepository Resources

```bash
# Apply all three GitRepository resources
kubectl apply -f exercise-02-branch-based-environment-management/gitrepository-dev.yaml
kubectl apply -f exercise-02-branch-based-environment-management/gitrepository-staging.yaml
kubectl apply -f exercise-02-branch-based-environment-management/gitrepository-prod.yaml

# Verify GitRepository resources are created
flux get sources git -A
```

### Step 3: Create Namespaces (Optional)

FluxCD can auto-create namespaces, but you can create them manually:

```bash
kubectl create namespace dev
kubectl create namespace staging
kubectl create namespace prod
```

### Step 4: Apply Kustomization Resources

```bash
# Apply all three Kustomization resources
kubectl apply -f exercise-02-branch-based-environment-management/kustomization-dev.yaml
kubectl apply -f exercise-02-branch-based-environment-management/kustomization-staging.yaml
kubectl apply -f exercise-02-branch-based-environment-management/kustomization-prod.yaml

# Verify Kustomization resources are created
flux get kustomizations -A
```

### Step 5: Verify Deployments

```bash
# Watch the reconciliation process
flux get kustomizations -A --watch

# Check pods in each namespace
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n prod

# Check all resources
kubectl get all -n dev
kubectl get all -n staging
kubectl get all -n prod
```

## Promotion Workflow

See [PROMOTION_WORKFLOW.md](PROMOTION_WORKFLOW.md) for detailed promotion procedures.

**Quick Summary**:
1. Make changes in `dev` branch
2. Test and validate in dev environment
3. Create PR: `dev` → `staging`
4. Review, merge, and validate in staging
5. Create PR: `staging` → `prod`
6. Review, merge, and deploy to production

## Verification Commands

```bash
# Check FluxCD sources
flux get sources git -A

# Check FluxCD kustomizations
flux get kustomizations -A

# Check specific kustomization status
flux get kustomization myapp-dev -n flux-system
flux get kustomization myapp-staging -n flux-system
flux get kustomization myapp-prod -n flux-system

# View detailed status
flux describe kustomization myapp-dev -n flux-system

# Check events
kubectl get events -n dev --sort-by='.lastTimestamp'
kubectl get events -n staging --sort-by='.lastTimestamp'
kubectl get events -n prod --sort-by='.lastTimestamp'

# Check application logs
kubectl logs -n dev -l app=myapp
kubectl logs -n staging -l app=myapp
kubectl logs -n prod -l app=myapp
```

## Troubleshooting

### GitRepository not syncing

```bash
# Check GitRepository status
flux describe source git gitops-repo-dev -n flux-system

# Force reconciliation
flux reconcile source git gitops-repo-dev -n flux-system
```

### Kustomization failing

```bash
# Check Kustomization status
flux describe kustomization myapp-dev -n flux-system

# View build output
flux build kustomization myapp-dev --path ./apps/myapp/kustomize/overlays/dev

# Force reconciliation
flux reconcile kustomization myapp-dev -n flux-system
```

### Dependencies not working

```bash
# Ensure the dependent kustomization is ready
flux get kustomizations -A

# The status should show:
# - myapp-dev: Ready
# - myapp-staging: Ready (after dev is ready)
# - myapp-prod: Ready (after staging is ready)
```

## Rollback Procedure

### Emergency Rollback

```bash
# Revert the last commit on the affected branch
git checkout prod
git revert HEAD
git push origin prod

# FluxCD will automatically sync the revert
```

### Planned Rollback

```bash
# Create a PR to revert specific changes
git checkout -b revert-feature
git revert <commit-hash>
git push origin revert-feature

# Create PR and follow normal promotion process
```

## Key Features

1. **Environment Isolation**: Each environment runs in its own namespace
2. **Branch-Based Promotion**: Clear promotion path through Git PRs
3. **Dependency Management**: Ensures lower environments are healthy before promoting
4. **Configuration Drift Prevention**: FluxCD continuously reconciles desired state
5. **Audit Trail**: All changes tracked in Git history
6. **Automated Reconciliation**: No manual kubectl apply needed

## Best Practices Implemented

- ✅ Separate Git branches per environment
- ✅ Environment-specific configurations via Kustomize overlays
- ✅ Progressive resource allocation (dev < staging < prod)
- ✅ Dependency ordering with `dependsOn`
- ✅ Automatic namespace creation
- ✅ Prune enabled for cleanup
- ✅ Wait and timeout settings for safe deployments
- ✅ Different sync intervals based on environment criticality

## References

- [FluxCD Documentation](https://fluxcd.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Principles](https://opengitops.dev/)

