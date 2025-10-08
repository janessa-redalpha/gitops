# Git Workflow Design for GitOps Deployment Patterns

## Executive Summary

This document outlines a comprehensive Git workflow designed for GitOps deployment patterns that enables rapid iteration, secure promotion through environments, and maintains Git as the single source of truth for both application code and cluster state.

## 1. Branching Model: GitOps Flow

### Chosen Model: Single Main Branch with Environment-Based Overlays

**Rationale:**
- **Simplicity**: Single main branch reduces complexity and merge conflicts
- **Auditability**: All changes flow through main branch with clear history
- **GitOps Compliance**: Aligns with GitOps principle of Git as single source of truth
- **Environment Isolation**: Directory-based overlays (dev/staging/prod) provide clear separation
- **Promotion Safety**: Image tag updates via PRs ensure controlled promotions

### Branch Structure
```
main (protected)
├── app-repos/
│   ├── feature/myapp-feature-123
│   ├── feature/myapp-bugfix-456
│   └── main
└── config-repos/
    └── main (single branch with overlays)
        ├── apps/myapp/overlays/dev/
        ├── apps/myapp/overlays/staging/
        └── apps/myapp/overlays/prod/
```

## 2. Protected Branches, Code Owners, and Required Status Checks

### Protected Branches Configuration

#### Application Repositories
- **main**: Protected, requires PR review, status checks, up-to-date branches
- **feature/***: Unprotected, for development work

#### Configuration Repositories  
- **main**: Protected, requires PR review, CODEOWNERS approval, status checks

### CODEOWNERS File
```bash
# Global platform configuration
/                        @platform-team @senior-platform-engineers

# Application-specific configurations
/apps/frontend/          @frontend-team @platform-team
/apps/backend/           @backend-team @platform-team
/apps/database/          @database-team @platform-team @senior-platform-engineers

# Infrastructure components
/infrastructure/         @platform-team @senior-platform-engineers
/cluster-configs/        @platform-team @senior-platform-engineers

# Production environments (extra approval required)
/apps/*/overlays/prod/   @platform-team @senior-platform-engineers @app-team-leads
```

### Required Status Checks

#### For Application Repositories (main branch)
- **Build & Test**: `build-test-pipeline`
- **Security Scan**: `security-scan`
- **Code Quality**: `code-quality-check`
- **Docker Build**: `docker-build-push`

#### For Configuration Repositories (main branch)
- **Manifest Validation**: `kustomize-validate`
- **Security Policy Check**: `security-policy-check`
- **Resource Quota Validation**: `quota-validation`
- **Flux Sync Check**: `flux-sync-validation`

## 3. Promotion Flow: Dev → Staging → Prod

### Development Workflow

#### 1. Application Development
```bash
# Developer creates feature branch
git checkout -b feature/myapp-new-feature
# ... make changes ...
git commit -m "feat: add new feature"
git push origin feature/myapp-new-feature

# Create PR to main
gh pr create --title "feat: add new feature" --body "Description"
```

#### 2. CI Pipeline Triggers
- Builds application image with tag: `myapp-<commit-sha>-<timestamp>`
- Pushes to registry: `ghcr.io/org/myapp:sha-abc123def`
- Updates config repo with new image tag

#### 3. Auto-Deploy to Development
```bash
# CI automatically creates PR in config repo
gh pr create --repo org/config-repo \
  --title "deploy: myapp sha-abc123def to dev" \
  --body "Auto-deploy from app-repo PR #123" \
  --head auto-deploy/myapp-sha-abc123def
```

### Staging Promotion

#### 1. Manual Promotion via PR
```bash
# Platform engineer creates staging promotion PR
git checkout -b promote/myapp-to-staging
# Update staging overlay image tag
sed -i 's|ghcr.io/org/myapp:sha-abc123def|ghcr.io/org/myapp:sha-abc123def|g' \
  apps/myapp/overlays/staging/deployment-patch.yaml
git commit -m "promote: myapp sha-abc123def to staging"
git push origin promote/myapp-to-staging
```

#### 2. Required Approvals
- App team lead approval
- Platform team approval
- Staging environment testing

### Production Promotion

#### 1. Staged Production Deployment
```bash
# Create production promotion PR
git checkout -b promote/myapp-to-prod
# Update production overlay with tested image tag
sed -i 's|ghcr.io/org/myapp:v1.2.3|ghcr.io/org/myapp:sha-abc123def|g' \
  apps/myapp/overlays/prod/deployment-patch.yaml
git commit -m "promote: myapp sha-abc123def to production"
git push origin promote/myapp-to-prod
```

#### 2. Production Approval Process
- **Required Approvers**: Senior platform engineers, app team leads
- **Additional Checks**: Production readiness checklist, rollback plan
- **Deployment Window**: Scheduled during maintenance windows

## 4. CI Image Tagging Strategy

### Image Tagging Convention

#### Development Images
```
Format: <app-name>-<commit-sha>-<timestamp>
Example: myapp-abc123def-20241201-143022
```

#### Staging Images
```
Format: <app-name>-staging-<commit-sha>
Example: myapp-staging-abc123def
```

#### Production Images
```
Format: <app-name>-v<semantic-version>
Example: myapp-v1.2.3
```

### Config Repository Tag References

#### Base Configuration (apps/myapp/base/kustomization.yaml)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- deployment.yaml
- service.yaml
- configmap.yaml

images:
- name: myapp
  newTag: "{{ .Values.imageTag }}"
```

#### Environment-Specific Overlays

**Dev Overlay** (apps/myapp/overlays/dev/kustomization.yaml)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
- deployment-patch.yaml
- configmap-patch.yaml

images:
- name: myapp
  newTag: "sha-abc123def"  # Auto-updated by CI
```

**Staging Overlay** (apps/myapp/overlays/staging/kustomization.yaml)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
- deployment-patch.yaml
- hpa-patch.yaml

images:
- name: myapp
  newTag: "staging-abc123def"  # Manually updated via PR
```

**Production Overlay** (apps/myapp/overlays/prod/kustomization.yaml)
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- ../../base
- deployment-patch.yaml
- hpa-patch.yaml

images:
- name: myapp
  newTag: "v1.2.3"  # Manually updated via PR
```

## 5. Flux Controller Example

### Flux GitRepository Configuration

```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: config-repo
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/config-repo
  ref:
    branch: main
  secretRef:
    name: config-repo-secret
```

### Environment-Specific Kustomization

#### Development Environment
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: myapp-dev
  namespace: flux-system
spec:
  interval: 1m
  sourceRef:
    kind: GitRepository
    name: config-repo
  path: "./apps/myapp/overlays/dev"
  prune: true
  wait: true
  targetNamespace: app-dev
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: myapp
    namespace: app-dev
```

#### Staging Environment
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: myapp-staging
  namespace: flux-system
spec:
  interval: 2m
  sourceRef:
    kind: GitRepository
    name: config-repo
  path: "./apps/myapp/overlays/staging"
  prune: true
  wait: true
  targetNamespace: app-staging
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: myapp
    namespace: app-staging
```

#### Production Environment
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: myapp-prod
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: config-repo
  path: "./apps/myapp/overlays/prod"
  prune: true
  wait: true
  targetNamespace: app-prod
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: myapp
    namespace: app-prod
  # Additional production-specific configurations
  timeout: 10m
  retryInterval: 2m
```

## 6. Workflow Summary & Git Commands

### Quick Reference: Git Commands

#### Application Development
```bash
# Start new feature
git checkout -b feature/myapp-feature-123
git add .
git commit -m "feat: implement new feature"
git push origin feature/myapp-feature-123

# Create PR
gh pr create --title "feat: new feature" --body "Description"
```

#### Configuration Promotion
```bash
# Promote to staging
git checkout -b promote/myapp-to-staging
# Edit apps/myapp/overlays/staging/deployment-patch.yaml
git add .
git commit -m "promote: myapp v1.2.3 to staging"
git push origin promote/myapp-to-staging
gh pr create --title "Promote myapp v1.2.3 to staging"

# Promote to production
git checkout -b promote/myapp-to-prod
# Edit apps/myapp/overlays/prod/deployment-patch.yaml
git add .
git commit -m "promote: myapp v1.2.3 to production"
git push origin promote/myapp-to-prod
gh pr create --title "Promote myapp v1.2.3 to production"
```

### Workflow Benefits

1. **Rapid Iteration**: Feature branches enable fast development cycles
2. **Controlled Promotions**: PR-based promotions ensure review and approval
3. **Auditability**: All changes tracked through Git history
4. **Environment Isolation**: Clear separation via directory overlays
5. **Automated Deployments**: Flux handles cluster synchronization
6. **Security**: CODEOWNERS and protected branches enforce approval gates

### Key Principles

- **Git as Source of Truth**: All configuration and deployment state in Git
- **Declarative Configuration**: Kustomize overlays for environment differences
- **Automated Sync**: Flux continuously syncs desired state
- **Human-in-the-Loop**: Manual approvals for production promotions
- **Immutable Infrastructure**: Image tags ensure consistent deployments

---

*This workflow design provides a robust foundation for GitOps deployment patterns while maintaining security, auditability, and operational efficiency.*
