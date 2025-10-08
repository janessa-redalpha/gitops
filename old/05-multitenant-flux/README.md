# Multi-Tenant FluxCD Setup

This repository contains a complete multi-tenant FluxCD implementation where different teams manage their own GitOps workflows independently while sharing the same Kubernetes cluster.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Tenancy Model](#tenancy-model)
- [Directory Structure](#directory-structure)
- [Setup Instructions](#setup-instructions)
- [Verification](#verification)
- [Security Considerations](#security-considerations)

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │           flux-system Namespace (Admin)                │   │
│  │  - FluxCD Controllers (source, kustomize, helm, etc.)  │   │
│  │  - Cluster-level reconciliation                        │   │
│  └────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            │ Manages                            │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  team-a Namespace                       │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  ServiceAccount: flux-reconciler                 │  │  │
│  │  │  Role: Limited to team-a namespace only          │  │  │
│  │  │  RoleBinding: Binds SA to Role                   │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  GitRepository: team-a-apps                      │  │  │
│  │  │    - URL: github.com/team-a/apps                 │  │  │
│  │  │    - Auth: team-a-git-auth Secret                │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Kustomization: team-a-apps                      │  │  │
│  │  │    - Uses: flux-reconciler SA                    │  │  │
│  │  │    - Target: team-a namespace only               │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Application Resources                           │  │  │
│  │  │  (Deployments, Services, ConfigMaps, etc.)       │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  team-b Namespace                       │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  ServiceAccount: flux-reconciler                 │  │  │
│  │  │  Role: Limited to team-b namespace only          │  │  │
│  │  │  RoleBinding: Binds SA to Role                   │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  GitRepository: team-b-apps                      │  │  │
│  │  │    - URL: github.com/team-b/apps                 │  │  │
│  │  │    - Auth: team-b-git-auth Secret                │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Kustomization: team-b-apps                      │  │  │
│  │  │    - Uses: flux-reconciler SA                    │  │  │
│  │  │    - Target: team-b namespace only               │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Application Resources                           │  │  │
│  │  │  (Deployments, Services, ConfigMaps, etc.)       │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

     ▲                                        ▲
     │                                        │
     │ Git Sync                               │ Git Sync
     │                                        │
┌────┴────────┐                      ┌───────┴─────┐
│  Team A     │                      │  Team B     │
│  Git Repo   │                      │  Git Repo   │
└─────────────┘                      └─────────────┘
```

## Tenancy Model

### Core Principles

1. **Namespace Isolation**: Each tenant operates in their own namespace(s)
2. **RBAC Boundaries**: Service accounts have Role-based permissions (not ClusterRole)
3. **Separate Git Sources**: Each tenant has their own GitRepository resource
4. **Constrained Reconcilers**: Kustomizations use tenant-specific ServiceAccounts
5. **No Cluster-Wide Access**: Tenants cannot access cluster-scoped resources

### Key Components Per Tenant

1. **Namespace** with `tenant: <name>` label
2. **ServiceAccount** (`flux-reconciler`) - identity for Flux operations
3. **Role** - defines allowed operations (limited to namespace)
4. **RoleBinding** - binds the ServiceAccount to the Role
5. **Secret** - Git authentication credentials
6. **GitRepository** - points to team's application repository
7. **Kustomization** - reconciles manifests using the ServiceAccount

### Security Boundaries

```
┌─────────────────────────────────────────────────────────┐
│  Team A Boundary                                        │
│  ┌───────────────────────────────────────────────────┐ │
│  │ ✓ Can manage resources in team-a namespace       │ │
│  │ ✓ Can create Deployments, Services, ConfigMaps   │ │
│  │ ✓ Can manage Flux resources in team-a            │ │
│  │ ✗ Cannot access team-b namespace                 │ │
│  │ ✗ Cannot create ClusterRoles or ClusterRBs       │ │
│  │ ✗ Cannot list nodes or namespaces                │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Team B Boundary                                        │
│  ┌───────────────────────────────────────────────────┐ │
│  │ ✓ Can manage resources in team-b namespace       │ │
│  │ ✓ Can create Deployments, Services, ConfigMaps   │ │
│  │ ✓ Can manage Flux resources in team-b            │ │
│  │ ✗ Cannot access team-a namespace                 │ │
│  │ ✗ Cannot create ClusterRoles or ClusterRBs       │ │
│  │ ✗ Cannot list nodes or namespaces                │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Directory Structure

```
05-multitenant-flux/
├── README.md                          # This file
├── kubectl-auth-examples.md           # RBAC verification examples
├── verify-rbac.sh                     # Automated RBAC verification script
├── base/                              # Base manifests (optional)
└── tenants/
    ├── team-a/
    │   ├── namespace.yaml             # Namespace definition
    │   ├── rbac.yaml                  # ServiceAccount, Role, RoleBinding
    │   ├── git-secret.yaml            # Git authentication secret
    │   ├── gitrepository.yaml         # GitRepository source
    │   └── kustomization.yaml         # Kustomization reconciler
    └── team-b/
        ├── namespace.yaml             # Namespace definition
        ├── rbac.yaml                  # ServiceAccount, Role, RoleBinding
        ├── git-secret.yaml            # Git authentication secret
        ├── gitrepository.yaml         # GitRepository source
        └── kustomization.yaml         # Kustomization reconciler
```

## Setup Instructions

### Prerequisites

- Kubernetes cluster (v1.24+)
- FluxCD installed in the `flux-system` namespace
- kubectl configured with cluster-admin access
- Git repositories for each team (or paths in a monorepo)

### Step 1: Apply Tenant Namespaces

```bash
# Apply team-a namespace
kubectl apply -f tenants/team-a/namespace.yaml

# Apply team-b namespace
kubectl apply -f tenants/team-b/namespace.yaml

# Verify namespaces
kubectl get namespaces -l toolkit.fluxcd.io/tenant
```

### Step 2: Apply RBAC Resources

```bash
# Apply RBAC for team-a
kubectl apply -f tenants/team-a/rbac.yaml

# Apply RBAC for team-b
kubectl apply -f tenants/team-b/rbac.yaml

# Verify ServiceAccounts
kubectl get serviceaccounts -n team-a
kubectl get serviceaccounts -n team-b

# Verify Roles
kubectl get roles -n team-a
kubectl get roles -n team-b
```

### Step 3: Configure Git Authentication

**Important**: Update the secrets with actual credentials before applying!

For HTTPS with Personal Access Token:
```bash
kubectl create secret generic team-a-git-auth \
  --namespace=team-a \
  --from-literal=username=git \
  --from-literal=password=<GITHUB_TOKEN>

kubectl create secret generic team-b-git-auth \
  --namespace=team-b \
  --from-literal=username=git \
  --from-literal=password=<GITHUB_TOKEN>
```

For SSH authentication:
```bash
kubectl create secret generic team-a-git-auth \
  --namespace=team-a \
  --from-file=identity=/path/to/team-a-private-key \
  --from-file=known_hosts=/path/to/known_hosts

kubectl create secret generic team-b-git-auth \
  --namespace=team-b \
  --from-file=identity=/path/to/team-b-private-key \
  --from-file=known_hosts=/path/to/known_hosts
```

### Step 4: Apply GitRepository Resources

**Important**: Update the Git URLs in the YAML files to point to actual repositories!

```bash
# Apply GitRepository for team-a
kubectl apply -f tenants/team-a/gitrepository.yaml

# Apply GitRepository for team-b
kubectl apply -f tenants/team-b/gitrepository.yaml

# Verify GitRepositories
kubectl get gitrepositories -n team-a
kubectl get gitrepositories -n team-b

# Check status
flux get sources git -n team-a
flux get sources git -n team-b
```

### Step 5: Apply Kustomization Resources

```bash
# Apply Kustomization for team-a
kubectl apply -f tenants/team-a/kustomization.yaml

# Apply Kustomization for team-b
kubectl apply -f tenants/team-b/kustomization.yaml

# Verify Kustomizations
kubectl get kustomizations -n team-a
kubectl get kustomizations -n team-b

# Check status
flux get kustomizations -n team-a
flux get kustomizations -n team-b
```

### Step 6: Monitor Reconciliation

```bash
# Watch team-a reconciliation
flux logs -n team-a --follow

# Watch team-b reconciliation
flux logs -n team-b --follow

# Check overall status
flux get all -n team-a
flux get all -n team-b
```

## Verification

### Automated Verification

Run the automated RBAC verification script:

```bash
./verify-rbac.sh
```

This script tests:
- ✓ Tenant can manage resources in their own namespace
- ✗ Tenant cannot access other tenants' namespaces
- ✗ Tenant cannot access cluster-scoped resources

### Manual Verification

See `kubectl-auth-examples.md` for detailed manual verification commands.

#### Quick Verification Examples

```bash
# Test team-a can create deployments in their namespace (should succeed)
kubectl auth can-i create deployments \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-a

# Test team-a cannot create deployments in team-b (should fail)
kubectl auth can-i create deployments \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-b

# Test team-a cannot list cluster-scoped resources (should fail)
kubectl auth can-i list namespaces \
  --as system:serviceaccount:team-a:flux-reconciler
```

### Check Deployed Resources

```bash
# List all resources in team-a namespace
kubectl get all -n team-a

# List all resources in team-b namespace
kubectl get all -n team-b

# Check if resources have correct labels
kubectl get all -n team-a --show-labels
kubectl get all -n team-b --show-labels
```

## Security Considerations

### What This Model Provides

✅ **Namespace Isolation**: Tenants cannot access each other's namespaces  
✅ **Resource Isolation**: Each tenant can only manage resources in their namespace  
✅ **Git Source Isolation**: Each tenant uses their own Git repository  
✅ **RBAC Enforcement**: Role-based permissions prevent privilege escalation  
✅ **Audit Trail**: All changes are tracked via Git commits  

### What This Model Does NOT Provide

❌ **Network Isolation**: Use NetworkPolicies for pod-to-pod traffic control  
❌ **Resource Quotas**: Apply ResourceQuotas to limit tenant resource usage  
❌ **Pod Security**: Use PodSecurityStandards or admission controllers  
❌ **Node Isolation**: Consider node pools or taints/tolerations for workload placement  

### Recommended Additional Security Measures

1. **NetworkPolicies**: Restrict network traffic between tenant namespaces
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: deny-cross-namespace
     namespace: team-a
   spec:
     podSelector: {}
     policyTypes:
       - Ingress
     ingress:
       - from:
           - namespaceSelector:
               matchLabels:
                 tenant: team-a
   ```

2. **ResourceQuotas**: Limit CPU, memory, and object counts per tenant
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: team-a-quota
     namespace: team-a
   spec:
     hard:
       requests.cpu: "10"
       requests.memory: 20Gi
       limits.cpu: "20"
       limits.memory: 40Gi
       persistentvolumeclaims: "10"
   ```

3. **LimitRanges**: Set default and maximum resource limits
   ```yaml
   apiVersion: v1
   kind: LimitRange
   metadata:
     name: team-a-limits
     namespace: team-a
   spec:
     limits:
       - max:
           cpu: "2"
           memory: 4Gi
         min:
           cpu: 100m
           memory: 128Mi
         type: Container
   ```

4. **PodSecurityStandards**: Enforce security policies
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: team-a
     labels:
       tenant: team-a
       pod-security.kubernetes.io/enforce: restricted
       pod-security.kubernetes.io/audit: restricted
       pod-security.kubernetes.io/warn: restricted
   ```

## Onboarding New Tenants

To onboard a new tenant (e.g., `team-c`):

1. Create a new directory: `tenants/team-c/`
2. Copy files from `tenants/team-a/` as templates
3. Update all occurrences of `team-a` to `team-c`
4. Update Git repository URL in `gitrepository.yaml`
5. Create Git authentication secret with actual credentials
6. Apply all manifests in order (namespace → RBAC → secrets → sources → kustomizations)
7. Verify RBAC boundaries using the verification script

## Troubleshooting

### GitRepository Not Ready

```bash
# Check GitRepository status
kubectl describe gitrepository -n team-a team-a-apps

# Common issues:
# - Invalid Git credentials
# - Wrong repository URL
# - Network connectivity issues
```

### Kustomization Reconciliation Fails

```bash
# Check Kustomization status
kubectl describe kustomization -n team-a team-a-apps

# Check logs
flux logs -n team-a --level=error

# Common issues:
# - Invalid manifests in Git repository
# - RBAC permissions insufficient
# - ServiceAccount not properly configured
```

### RBAC Permission Denied

```bash
# Verify Role permissions
kubectl describe role -n team-a flux-reconciler

# Verify RoleBinding
kubectl describe rolebinding -n team-a flux-reconciler

# Test specific permissions
kubectl auth can-i <verb> <resource> \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-a
```

## References

- [FluxCD Multi-Tenancy Documentation](https://fluxcd.io/flux/installation/configuration/multitenancy/)
- [Kubernetes RBAC Documentation](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [FluxCD Security Best Practices](https://fluxcd.io/flux/security/)

## Contributing

When modifying this setup:
1. Test changes in a development cluster first
2. Verify RBAC boundaries after any RBAC changes
3. Update documentation to reflect changes
4. Run the verification script to ensure isolation is maintained

## License

This is an educational example for learning multi-tenant FluxCD patterns.

