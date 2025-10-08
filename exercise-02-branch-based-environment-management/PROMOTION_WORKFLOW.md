# Branch-Based Promotion Workflow

## Overview
This document describes the promotion workflow for deploying applications across dev, staging, and prod environments using FluxCD and Git branches.

## Environment Hierarchy

```
dev → staging → prod
```

Each environment has:
- Its own Git branch (`dev`, `staging`, `prod`)
- Its own GitRepository resource
- Its own Kustomization resource
- Its own Kubernetes namespace
- Environment-specific configuration overlays

## Promotion Process

### 1. Development (dev branch)

**Purpose**: Rapid iteration and testing of new features

**Process**:
1. Developers make changes directly to the `dev` branch or merge feature branches into `dev`
2. FluxCD detects changes in the `dev` branch (checks every 1 minute)
3. The `myapp-dev` Kustomization automatically deploys to the `dev` namespace
4. Test and validate changes in the dev environment

**Configuration**:
- 1 replica
- Minimal resources (64Mi memory, 100m CPU)
- Fast sync interval (1 minute)

### 2. Staging (staging branch)

**Purpose**: Pre-production testing with production-like settings

**Process**:
1. Once changes are validated in dev, create a Pull Request from `dev` → `staging`
2. Review the PR to ensure:
   - All tests pass
   - Code review is complete
   - Changes are ready for staging validation
3. Merge the PR to the `staging` branch
4. FluxCD detects changes in the `staging` branch (checks every 1 minute)
5. The `myapp-staging` Kustomization waits for `myapp-dev` to be ready (due to `dependsOn`)
6. After validation, deploys to the `staging` namespace
7. Conduct thorough testing including:
   - Integration tests
   - Performance tests
   - Security scans
   - User acceptance testing

**Configuration**:
- 2 replicas
- Medium resources (128Mi memory, 200m CPU)
- Depends on dev being healthy

### 3. Production (prod branch)

**Purpose**: Serving live traffic to end users

**Process**:
1. Once changes are validated in staging, create a Pull Request from `staging` → `prod`
2. Review the PR with extra scrutiny:
   - All staging tests passed
   - Stakeholder approval obtained
   - Rollback plan documented
   - Change window scheduled (if applicable)
3. Merge the PR to the `prod` branch
4. FluxCD detects changes in the `prod` branch (checks every 5 minutes)
5. The `myapp-prod` Kustomization waits for `myapp-staging` to be ready (due to `dependsOn`)
6. After validation, deploys to the `prod` namespace
7. Monitor deployment closely:
   - Check application logs
   - Monitor metrics and alerts
   - Verify user traffic is healthy
   - Be ready to rollback if issues arise

**Configuration**:
- 3 replicas for high availability
- High resources (256Mi memory, 500m CPU)
- Slower sync interval (5 minutes) for stability
- Depends on staging being healthy

## Safety Mechanisms

### 1. Git-Based Approval
- All promotions require Pull Requests with reviews
- PR merge is the single gate for promotion
- Full audit trail in Git history

### 2. FluxCD Dependencies
- `staging` depends on `dev` being healthy
- `prod` depends on `staging` being healthy
- Prevents cascading failures

### 3. Environment Isolation
- Each environment has its own namespace
- Resource quotas can be applied per namespace
- Network policies can isolate environments

### 4. Rollback Strategy
- **Dev**: Simply revert commits and push to `dev`
- **Staging**: Create revert PR from staging history
- **Production**: 
  - Emergency: Revert the merge commit in `prod` branch
  - Planned: Create revert PR and follow normal promotion process

## Best Practices

### 1. Always Test in Lower Environments First
Never skip environments. Always follow: dev → staging → prod

### 2. Keep Branches in Sync
After promoting to prod, ensure all branches are aligned:
```bash
git checkout dev
git merge prod
git push origin dev

git checkout staging
git merge prod
git push origin staging
```

### 3. Use Meaningful Commit Messages
- Clear descriptions help with troubleshooting
- Link to ticket/issue numbers
- Describe what changed and why

### 4. Monitor FluxCD Status
Regularly check:
```bash
flux get sources git -A
flux get kustomizations -A
kubectl get all -n dev
kubectl get all -n staging
kubectl get all -n prod
```

### 5. Hotfix Process
For urgent production fixes:
1. Create hotfix branch from `prod`
2. Apply fix and test
3. Merge directly to `prod` (with approval)
4. Backport to `staging` and `dev` branches

## Example Promotion Commands

### Create PR for dev → staging:
```bash
git checkout staging
git pull origin staging
gh pr create --base staging --head dev --title "Promote to staging" --body "Promoting validated changes from dev"
```

### Create PR for staging → prod:
```bash
git checkout prod
git pull origin prod
gh pr create --base prod --head staging --title "Promote to prod" --body "Promoting validated changes from staging"
```

### Check deployment status:
```bash
# Watch FluxCD reconciliation
flux get kustomizations -A --watch

# Check application status
kubectl get pods -n dev
kubectl get pods -n staging
kubectl get pods -n prod
```

## Reconciliation Intervals Summary

| Environment | Sync Interval | Timeout | Purpose |
|-------------|---------------|---------|---------|
| Dev         | 1 minute      | 3 minutes | Fast iteration |
| Staging     | 2 minutes     | 3 minutes | Quick validation |
| Prod        | 5 minutes     | 3 minutes | Controlled rollout |

