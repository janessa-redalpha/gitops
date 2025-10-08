# Quick Command Reference

## Setup Commands

### 1. Push Branches to Remote

```bash
cd /home/jnssa/GitOps

# Push all branches to remote
git push origin dev
git push origin staging
git push origin prod
```

### 2. Apply GitRepository Resources

```bash
# Apply all GitRepository resources
kubectl apply -f exercise-02-branch-based-environment-management/gitrepository-dev.yaml
kubectl apply -f exercise-02-branch-based-environment-management/gitrepository-staging.yaml
kubectl apply -f exercise-02-branch-based-environment-management/gitrepository-prod.yaml
```

### 3. Apply Kustomization Resources

```bash
# Apply all Kustomization resources
kubectl apply -f exercise-02-branch-based-environment-management/kustomization-dev.yaml
kubectl apply -f exercise-02-branch-based-environment-management/kustomization-staging.yaml
kubectl apply -f exercise-02-branch-based-environment-management/kustomization-prod.yaml
```

## Verification Commands

### Check FluxCD Sources

```bash
# View all GitRepository sources
flux get sources git -A

# View specific source details
flux describe source git gitops-repo-dev -n flux-system
flux describe source git gitops-repo-staging -n flux-system
flux describe source git gitops-repo-prod -n flux-system
```

### Check FluxCD Kustomizations

```bash
# View all Kustomizations
flux get kustomizations -A

# View specific Kustomization details
flux describe kustomization myapp-dev -n flux-system
flux describe kustomization myapp-staging -n flux-system
flux describe kustomization myapp-prod -n flux-system

# Watch Kustomizations in real-time
flux get kustomizations -A --watch
```

### Check Kubernetes Resources

```bash
# Check namespaces
kubectl get namespaces dev staging prod

# Check deployments
kubectl get deployments -n dev
kubectl get deployments -n staging
kubectl get deployments -n prod

# Check pods
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n prod

# Check services
kubectl get services -n dev
kubectl get services -n staging
kubectl get services -n prod

# Check all resources in each namespace
kubectl get all -n dev
kubectl get all -n staging
kubectl get all -n prod
```

### Check Logs

```bash
# Application logs
kubectl logs -n dev -l app=myapp
kubectl logs -n staging -l app=myapp
kubectl logs -n prod -l app=myapp

# FluxCD logs
kubectl logs -n flux-system deploy/source-controller
kubectl logs -n flux-system deploy/kustomize-controller
```

### Check Events

```bash
kubectl get events -n dev --sort-by='.lastTimestamp'
kubectl get events -n staging --sort-by='.lastTimestamp'
kubectl get events -n prod --sort-by='.lastTimestamp'
```

## Promotion Commands

### Promote Dev to Staging

```bash
# Option 1: Using GitHub CLI
gh pr create --base staging --head dev \
  --title "Promote to staging" \
  --body "Promoting validated changes from dev to staging"

# Option 2: Manual merge (after testing)
git checkout staging
git pull origin staging
git merge dev
git push origin staging
```

### Promote Staging to Prod

```bash
# Option 1: Using GitHub CLI
gh pr create --base prod --head staging \
  --title "Promote to prod" \
  --body "Promoting validated changes from staging to production"

# Option 2: Manual merge (after testing)
git checkout prod
git pull origin prod
git merge staging
git push origin prod
```

## Force Reconciliation

```bash
# Force reconcile GitRepository
flux reconcile source git gitops-repo-dev -n flux-system
flux reconcile source git gitops-repo-staging -n flux-system
flux reconcile source git gitops-repo-prod -n flux-system

# Force reconcile Kustomization
flux reconcile kustomization myapp-dev -n flux-system
flux reconcile kustomization myapp-staging -n flux-system
flux reconcile kustomization myapp-prod -n flux-system
```

## Troubleshooting Commands

### Test Kustomize Build

```bash
# Test kustomize build locally before deploying
flux build kustomization myapp-dev \
  --path ./apps/myapp/kustomize/overlays/dev

flux build kustomization myapp-staging \
  --path ./apps/myapp/kustomize/overlays/staging

flux build kustomization myapp-prod \
  --path ./apps/myapp/kustomize/overlays/prod
```

### Suspend/Resume

```bash
# Suspend a Kustomization (stop reconciliation)
flux suspend kustomization myapp-prod -n flux-system

# Resume a Kustomization
flux resume kustomization myapp-prod -n flux-system
```

### Debug Failed Reconciliation

```bash
# Check Kustomization status
flux get kustomization myapp-dev -n flux-system

# View detailed logs
flux logs --level=debug

# Check controller logs
kubectl logs -n flux-system deploy/kustomize-controller -f
kubectl logs -n flux-system deploy/source-controller -f
```

## Rollback Commands

### Emergency Rollback

```bash
# Revert last commit on prod branch
git checkout prod
git revert HEAD
git push origin prod

# Monitor rollback
flux get kustomizations -A --watch
kubectl get pods -n prod -w
```

### Planned Rollback

```bash
# Create revert branch
git checkout -b revert-feature prod
git revert <commit-hash>
git push origin revert-feature

# Create PR and follow normal promotion process
gh pr create --base prod --head revert-feature \
  --title "Rollback: <description>" \
  --body "Rolling back changes due to <reason>"
```

## Cleanup Commands

```bash
# Delete Kustomizations
kubectl delete -f exercise-02-branch-based-environment-management/kustomization-prod.yaml
kubectl delete -f exercise-02-branch-based-environment-management/kustomization-staging.yaml
kubectl delete -f exercise-02-branch-based-environment-management/kustomization-dev.yaml

# Delete GitRepositories
kubectl delete -f exercise-02-branch-based-environment-management/gitrepository-prod.yaml
kubectl delete -f exercise-02-branch-based-environment-management/gitrepository-staging.yaml
kubectl delete -f exercise-02-branch-based-environment-management/gitrepository-dev.yaml

# Delete namespaces (this will delete all resources in them)
kubectl delete namespace dev
kubectl delete namespace staging
kubectl delete namespace prod
```

## Submission Output Commands

```bash
# Get the outputs required for submission
flux get sources git -A > flux-sources-output.txt
flux get kustomizations -A > flux-kustomizations-output.txt

# View the outputs
cat flux-sources-output.txt
cat flux-kustomizations-output.txt
```

## Useful Aliases

Add these to your `.bashrc` or `.zshrc`:

```bash
# Flux aliases
alias fgs='flux get sources git -A'
alias fgk='flux get kustomizations -A'
alias fgkw='flux get kustomizations -A --watch'
alias frs='flux reconcile source git'
alias frk='flux reconcile kustomization'

# Kubectl aliases
alias kgd='kubectl get deployments'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kga='kubectl get all'

# Combined checks
alias check-envs='kubectl get all -n dev && kubectl get all -n staging && kubectl get all -n prod'
```

