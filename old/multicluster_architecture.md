# Multi-Cluster GitOps Architecture Setup

## Overview

This document outlines a comprehensive GitOps strategy for managing deployments across multiple Kubernetes clusters spanning environments (dev, staging, prod) and regions using Flux v2.

## Architecture Design

### 1. Repository Structure

```
gitops-cluster-config/
├── clusters/
│   ├── dev/
│   │   ├── us-west-2/
│   │   │   ├── flux-system/
│   │   │   │   ├── gotk-components.yaml
│   │   │   │   ├── gotk-sync.yaml
│   │   │   │   └── kustomization.yaml
│   │   │   ├── platform/
│   │   │   │   ├── ingress-nginx/
│   │   │   │   ├── monitoring/
│   │   │   │   └── cert-manager/
│   │   │   └── apps/
│   │   │       └── kustomization.yaml
│   │   ├── us-east-1/
│   │   │   └── [similar structure]
│   │   └── eu-west-1/
│   │       └── [similar structure]
│   ├── staging/
│   │   ├── us-west-2/
│   │   ├── us-east-1/
│   │   └── eu-west-1/
│   └── prod/
│       ├── us-west-2/
│       ├── us-east-1/
│       └── eu-west-1/
├── apps/
│   ├── myapp/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   ├── overlays/
│   │   │   ├── dev/
│   │   │   ├── staging/
│   │   │   └── prod/
│   │   └── README.md
│   └── [other-apps]/
└── platform/
    ├── ingress-nginx/
    ├── monitoring/
    ├── cert-manager/
    └── external-secrets/
```

### 2. Flux Fan-Out Mechanism

We use **one GitRepository + multiple Kustomization objects per cluster** pattern:

- **Single GitRepository**: Points to the gitops-cluster-config repository
- **Multiple Kustomizations**: Each cluster has separate Kustomization resources for different components
  - `platform-kustomization`: Manages platform components (ingress, monitoring, etc.)
  - `apps-kustomization`: Manages application deployments
  - `flux-system`: Manages Flux itself

### 3. Cluster Labels and Selection Rules

#### Cluster Labels Structure:
```yaml
metadata:
  labels:
    environment: dev|staging|prod
    region: us-west-2|us-east-1|eu-west-1
    cluster-type: workload|management
    team: platform|backend|frontend
    cost-center: engineering
```

#### Selection Rules:
```yaml
# Example Kustomization with cluster selection
spec:
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: "./apps/myapp/overlays/dev"
  prune: true
  interval: 1m
  targetNamespace: myapp
  kustomize:
    images:
      - name: myapp
        newTag: v1.2.3
  postBuild:
    substitute:
      ENVIRONMENT: "dev"
      REGION: "us-west-2"
```

### 4. Application Declaration Strategy

The `myapp` is declared once and deployed to selected clusters through:

1. **Base Configuration**: Common application manifests in `apps/myapp/base/`
2. **Environment Overlays**: Environment-specific configurations in `overlays/{env}/`
3. **Cluster-Specific Kustomizations**: Each cluster has a Kustomization pointing to the appropriate overlay

### 5. Promotion Strategy (Dev → Staging → Prod)

#### Promotion Process:
1. **Development**: Deploy to all dev clusters across regions
2. **Staging**: Promote to staging clusters after dev validation
3. **Production**: Promote to prod clusters after staging validation

#### Promotion Methods:
- **Git-based**: Update image tags in overlay kustomizations
- **Flux Image Automation**: Automated image updates with approval gates
- **Manual**: Update Kustomization manifests with new versions

#### Rollback Strategy:
1. **Git Revert**: Revert commits in the GitOps repository
2. **Image Rollback**: Update image tags to previous versions
3. **Kustomization Rollback**: Update Kustomization manifests

### 6. Security and Identity Management

#### RBAC Strategy:
- **Cluster-scoped ServiceAccounts**: Each cluster has dedicated ServiceAccounts
- **GitOps Namespace**: All GitOps resources in dedicated namespace
- **Least Privilege**: Minimal permissions for each component

#### Secrets Management:
- **SOPS**: Encrypt secrets in Git using age encryption
- **External Secrets Operator**: Sync secrets from external stores (AWS Secrets Manager, HashiCorp Vault)
- **Sealed Secrets**: Kubernetes-native secret encryption

#### Identity and Access:
- **SSO Integration**: OIDC/OAuth2 with corporate identity provider
- **Multi-tenancy**: Namespace-based isolation with ResourceQuotas
- **Network Policies**: Secure pod-to-pod communication

## Implementation Details

### Controller Manifests

#### GitRepository (Cluster-scoped)
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/gitops-cluster-config
  ref:
    branch: main
  secretRef:
    name: flux-system
```

#### Platform Kustomization (Per Cluster)
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: platform
  namespace: flux-system
spec:
  interval: 5m
  path: "./platform"
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  targetNamespace: platform
  postBuild:
    substitute:
      CLUSTER_NAME: "dev-us-west-2"
      ENVIRONMENT: "dev"
      REGION: "us-west-2"
```

#### Apps Kustomization (Per Cluster)
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 1m
  path: "./clusters/dev/us-west-2/apps"
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  targetNamespace: default
  dependsOn:
    - name: platform
      namespace: flux-system
```

### Promotion and Rollback Steps

#### Promotion Process:
1. **Update Image Tags**: Modify image references in overlay kustomizations
2. **Commit Changes**: Push changes to GitOps repository
3. **Monitor Deployment**: Watch Flux reconciliation across clusters
4. **Validate**: Ensure applications are healthy in target environment

#### Rollback Process:
1. **Identify Previous Version**: Find the last known good commit/image tag
2. **Revert Changes**: Update kustomizations to previous versions
3. **Commit Rollback**: Push rollback changes to GitOps repository
4. **Monitor Recovery**: Verify applications return to healthy state

### Security Boundaries

#### Multi-tenancy:
- **Namespace Isolation**: Each team gets dedicated namespaces
- **Resource Quotas**: Limit resource consumption per namespace
- **Network Policies**: Control pod-to-pod communication
- **RBAC**: Fine-grained permissions per namespace

#### Secrets Management:
- **SOPS Encryption**: Encrypt sensitive data in Git
- **External Secrets**: Sync from external secret stores
- **Secret Rotation**: Automated secret rotation policies

#### Compliance:
- **Audit Logging**: Comprehensive audit trails
- **Policy Enforcement**: OPA Gatekeeper policies
- **Security Scanning**: Container image vulnerability scanning