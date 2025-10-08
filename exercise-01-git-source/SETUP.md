# Setup Instructions

## Prerequisites
1. A GitHub Personal Access Token with repository read access
2. Access to the Kubernetes cluster with flux-system namespace

## Steps to Deploy

### 1. Create the Git Secret
Replace `REPLACE_WITH_YOUR_GITHUB_TOKEN` in `git-secret.yaml` with your actual token, then apply:

```bash
kubectl apply -f exercise-01-git-source/git-secret.yaml
```

Alternatively, use the create-secret.sh script:
```bash
./create-secret.sh
```

### 2. Apply the GitRepository
```bash
kubectl apply -f exercise-01-git-source/gitrepository.yaml
```

### 3. Apply the Kustomization
```bash
kubectl apply -f exercise-01-git-source/kustomization.yaml
```

### 4. Verify the Setup
```bash
flux get sources git -A
flux get kustomizations -A
```

### 5. Force Reconciliation (Optional)
```bash
flux reconcile source git gitops-repo -n flux-system
flux reconcile kustomization gitops-apps -n flux-system
```

## Files Created
- `git-secret.yaml` - Secret for GitHub authentication
- `gitrepository.yaml` - GitRepository resource
- `kustomization.yaml` - Kustomization resource
- `apps/sample-configmap.yaml` - Sample application manifest
- `auth-method-note.md` - Authentication method justification

