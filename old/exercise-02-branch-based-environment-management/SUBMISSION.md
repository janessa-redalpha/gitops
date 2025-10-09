# Exercise 02 Submission: Branch-Based Environment Management

## Overview

This submission demonstrates a complete branch-based environment management setup using FluxCD to deploy applications across dev, staging, and prod environments.

## Part 1: YAML Resources

### GitRepository Resources

#### 1. GitRepository for Dev Environment

**File**: `gitrepository-dev.yaml`

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: gitops-repo-dev
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/jnssa/GitOps
  ref:
    branch: dev
  secretRef:
    name: gitops-repo-auth
```

#### 2. GitRepository for Staging Environment

**File**: `gitrepository-staging.yaml`

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: gitops-repo-staging
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/jnssa/GitOps
  ref:
    branch: staging
  secretRef:
    name: gitops-repo-auth
```

#### 3. GitRepository for Prod Environment

**File**: `gitrepository-prod.yaml`

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: gitops-repo-prod
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/jnssa/GitOps
  ref:
    branch: prod
  secretRef:
    name: gitops-repo-auth
```

### Kustomization Resources

#### 1. Kustomization for Dev Environment

**File**: `kustomization-dev.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp-dev
  namespace: flux-system
spec:
  interval: 2m
  sourceRef:
    kind: GitRepository
    name: gitops-repo-dev
  path: ./apps/myapp/kustomize/overlays/dev
  prune: true
  targetNamespace: dev
  wait: true
  timeout: 3m
```

#### 2. Kustomization for Staging Environment

**File**: `kustomization-staging.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp-staging
  namespace: flux-system
spec:
  interval: 2m
  sourceRef:
    kind: GitRepository
    name: gitops-repo-staging
  path: ./apps/myapp/kustomize/overlays/staging
  prune: true
  targetNamespace: staging
  wait: true
  timeout: 3m
  dependsOn:
    - name: myapp-dev
```

**Note**: Staging depends on dev being ready.

#### 3. Kustomization for Prod Environment

**File**: `kustomization-prod.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: myapp-prod
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: gitops-repo-prod
  path: ./apps/myapp/kustomize/overlays/prod
  prune: true
  targetNamespace: prod
  wait: true
  timeout: 3m
  dependsOn:
    - name: myapp-staging
```

**Note**: Prod depends on staging being ready.

## Part 2: Expected Command Outputs

### Output of `flux get sources git -A`

```
NAMESPACE     NAME                  REVISION                                        SUSPENDED  READY  MESSAGE
flux-system   gitops-repo-dev       dev@sha1:abc123def456                          False      True   stored artifact for revision 'dev@sha1:abc123def456'
flux-system   gitops-repo-staging   staging@sha1:def456abc789                      False      True   stored artifact for revision 'staging@sha1:def456abc789'
flux-system   gitops-repo-prod      prod@sha1:789abc123def                         False      True   stored artifact for revision 'prod@sha1:789abc123def'
```

**Key Points**:
- All three GitRepository resources are in the `flux-system` namespace
- Each points to a different branch (dev, staging, prod)
- All are in READY state
- Each has its own revision hash
- None are suspended

### Output of `flux get kustomizations -A`

```
NAMESPACE     NAME            REVISION                                        SUSPENDED  READY  MESSAGE
flux-system   myapp-dev       dev@sha1:abc123def456                          False      True   Applied revision: dev@sha1:abc123def456
flux-system   myapp-staging   staging@sha1:def456abc789                      False      True   Applied revision: staging@sha1:def456abc789
flux-system   myapp-prod      prod@sha1:789abc123def                         False      True   Applied revision: prod@sha1:789abc123def
```

**Key Points**:
- All three Kustomization resources are in the `flux-system` namespace
- Each references its respective GitRepository source
- All are in READY state
- Dependencies are working correctly (staging waits for dev, prod waits for staging)
- Each has successfully applied its revision

### Additional Verification Outputs

#### Namespace Status

```bash
$ kubectl get namespaces dev staging prod
NAME      STATUS   AGE
dev       Active   5m
staging   Active   4m
prod      Active   3m
```

#### Deployment Status

```bash
$ kubectl get deployments -n dev
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
dev-myapp    1/1     1            1           5m

$ kubectl get deployments -n staging
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
staging-myapp    2/2     2            2           4m

$ kubectl get deployments -n prod
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
prod-myapp   3/3     3            3           3m
```

#### Pod Status

```bash
$ kubectl get pods -n dev
NAME                        READY   STATUS    RESTARTS   AGE
dev-myapp-7d4b8f9c6-x7k2m   1/1     Running   0          5m

$ kubectl get pods -n staging
NAME                            READY   STATUS    RESTARTS   AGE
staging-myapp-5f8c7d9b4-m9n3p   1/1     Running   0          4m
staging-myapp-5f8c7d9b4-q2r8t   1/1     Running   0          4m

$ kubectl get pods -n prod
NAME                         READY   STATUS    RESTARTS   AGE
prod-myapp-6c9d8e7a3-k5l6m   1/1     Running   0          3m
prod-myapp-6c9d8e7a3-p8q9r   1/1     Running   0          3m
prod-myapp-6c9d8e7a3-v2w3x   1/1     Running   0          3m
```

## Part 3: Promotion Workflow Description

### Overview

Our promotion workflow follows a strict hierarchical model with Git-based promotion gates:

```
dev → staging → prod
```

### Promotion Process

#### Stage 1: Development to Staging

1. **Development Phase**
   - Developers commit changes to the `dev` branch
   - FluxCD detects changes within 1 minute
   - Changes are automatically deployed to the `dev` namespace
   - Team tests and validates in dev environment

2. **Promotion Gate**
   - Create Pull Request: `dev` → `staging`
   - Required approvals: 1+ reviewers
   - Automated checks: tests, linting, security scans
   - Review criteria:
     - All tests passing
     - Code review completed
     - Documentation updated

3. **Staging Deployment**
   - Merge PR to `staging` branch
   - FluxCD detects changes within 1 minute
   - Kustomization waits for `myapp-dev` to be healthy (dependsOn)
   - Changes deployed to `staging` namespace
   - Integration and performance testing conducted

#### Stage 2: Staging to Production

1. **Staging Validation**
   - Full regression testing in staging
   - Load testing and performance validation
   - Security scanning and compliance checks
   - User acceptance testing (UAT)
   - Stakeholder sign-off

2. **Promotion Gate**
   - Create Pull Request: `staging` → `prod`
   - Required approvals: 2+ senior reviewers
   - Additional checks:
     - All staging tests passed
     - Change management approval
     - Rollback plan documented
     - Monitoring alerts configured

3. **Production Deployment**
   - Merge PR to `prod` branch during approved change window
   - FluxCD detects changes within 5 minutes
   - Kustomization waits for `myapp-staging` to be healthy (dependsOn)
   - Changes deployed to `prod` namespace
   - Monitoring and validation:
     - Watch application metrics
     - Monitor error rates
     - Check user traffic
     - Verify business metrics

### Safety Mechanisms

1. **Git-Based Approval**
   - All promotions require Pull Requests
   - PRs provide full audit trail
   - Protected branches enforce review requirements

2. **FluxCD Dependencies**
   - `myapp-staging` depends on `myapp-dev` being Ready
   - `myapp-prod` depends on `myapp-staging` being Ready
   - Prevents promotion if lower environment is unhealthy

3. **Environment-Specific Configuration**
   - Dev: 1 replica, minimal resources (fast iteration)
   - Staging: 2 replicas, medium resources (realistic testing)
   - Prod: 3 replicas, high resources (high availability)

4. **Automated Reconciliation**
   - Dev: 1-minute sync for rapid feedback
   - Staging: 2-minute sync for validation
   - Prod: 5-minute sync for stability

5. **Namespace Isolation**
   - Each environment in separate namespace
   - Resource quotas can be applied
   - Network policies for additional isolation

### Rollback Strategy

#### Emergency Rollback (Production)

```bash
# Revert the merge commit
git checkout prod
git revert HEAD
git push origin prod

# FluxCD will automatically deploy the revert within 5 minutes
# Monitor the rollback
flux get kustomizations -A --watch
kubectl get pods -n prod -w
```

#### Planned Rollback

```bash
# Create revert PR
git checkout -b revert-feature
git revert <commit-hash>
git push origin revert-feature

# Create PR: revert-feature → prod
# Follow normal promotion process with review
```

### Best Practices

1. **Never Skip Environments**: Always follow dev → staging → prod
2. **Keep Branches Synchronized**: Regularly merge prod back to lower environments
3. **Automated Testing**: Run tests in CI/CD before allowing promotion
4. **Meaningful Commits**: Clear commit messages with ticket references
5. **Monitor FluxCD**: Regularly check `flux get kustomizations -A`
6. **Test Rollbacks**: Practice rollback procedures regularly

### Promotion Frequency

- **Dev**: Continuous (multiple times per day)
- **Staging**: Daily or as needed (after dev validation)
- **Prod**: Scheduled releases (weekly, bi-weekly, or as per release calendar)

### Communication

- Announce staging promotions in team channel
- Announce production promotions with change management ticket
- Post-deployment: Share metrics and validation results
- Incident: Follow incident management process for rollbacks

## Implementation Notes

### Branch Structure

All three branches (`dev`, `staging`, `prod`) have been created with the same application structure:

```
apps/myapp/kustomize/
├── base/                   # Common base manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── overlays/
    ├── dev/
    ├── staging/
    └── prod/
```

### Environment Differences

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| Branch | dev | staging | prod |
| Namespace | dev | staging | prod |
| Replicas | 1 | 2 | 3 |
| Memory Request | 64Mi | 128Mi | 256Mi |
| CPU Request | 100m | 200m | 500m |
| Sync Interval | 1m | 2m | 5m |
| Dependencies | None | Depends on dev | Depends on staging |

### Key Design Decisions

1. **Branch-per-environment**: Provides clear separation and promotion path
2. **Kustomize overlays**: Allows environment-specific configuration without duplication
3. **FluxCD dependencies**: Ensures safe promotion order
4. **Progressive resources**: Scales resources with environment criticality
5. **Different sync intervals**: Balances speed (dev) with stability (prod)

## Conclusion

This implementation provides a robust, GitOps-native approach to multi-environment deployment with:
- Clear promotion workflow through Git PRs
- Automated deployment via FluxCD
- Safety through dependencies and reviews
- Full audit trail in Git history
- Easy rollback capabilities
- Environment-specific configurations

The setup follows GitOps best practices and provides a solid foundation for production-grade deployments.

