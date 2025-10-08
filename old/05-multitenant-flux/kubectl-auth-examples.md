# kubectl auth can-i Examples for Multi-Tenant Flux

This document contains example commands to verify RBAC boundaries in the multi-tenant FluxCD setup.

## Team A Service Account

### Allowed Operations (within team-a namespace)

```bash
# Check if team-a can create deployments in their namespace
kubectl auth can-i create deployments \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-a
# Expected: yes

# Check if team-a can list pods in their namespace
kubectl auth can-i list pods \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-a
# Expected: yes

# Check if team-a can create secrets in their namespace
kubectl auth can-i create secrets \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-a
# Expected: yes

# Check if team-a can manage Kustomizations in their namespace
kubectl auth can-i get kustomizations.kustomize.toolkit.fluxcd.io \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-a
# Expected: yes
```

### Denied Operations (cross-namespace access)

```bash
# Check if team-a can create deployments in team-b namespace
kubectl auth can-i create deployments \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-b
# Expected: no

# Check if team-a can list pods in team-b namespace
kubectl auth can-i list pods \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-b
# Expected: no

# Check if team-a can read secrets in team-b namespace
kubectl auth can-i get secrets \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-b
# Expected: no
```

### Denied Operations (cluster-wide access)

```bash
# Check if team-a can list namespaces (cluster-wide)
kubectl auth can-i list namespaces \
  --as system:serviceaccount:team-a:flux-reconciler
# Expected: no

# Check if team-a can create ClusterRoles
kubectl auth can-i create clusterroles \
  --as system:serviceaccount:team-a:flux-reconciler
# Expected: no

# Check if team-a can create ClusterRoleBindings
kubectl auth can-i create clusterrolebindings \
  --as system:serviceaccount:team-a:flux-reconciler
# Expected: no

# Check if team-a can list nodes
kubectl auth can-i list nodes \
  --as system:serviceaccount:team-a:flux-reconciler
# Expected: no
```

## Team B Service Account

### Allowed Operations (within team-b namespace)

```bash
# Check if team-b can create deployments in their namespace
kubectl auth can-i create deployments \
  --as system:serviceaccount:team-b:flux-reconciler \
  -n team-b
# Expected: yes

# Check if team-b can list pods in their namespace
kubectl auth can-i list pods \
  --as system:serviceaccount:team-b:flux-reconciler \
  -n team-b
# Expected: yes

# Check if team-b can create configmaps in their namespace
kubectl auth can-i create configmaps \
  --as system:serviceaccount:team-b:flux-reconciler \
  -n team-b
# Expected: yes
```

### Denied Operations (cross-namespace access)

```bash
# Check if team-b can create deployments in team-a namespace
kubectl auth can-i create deployments \
  --as system:serviceaccount:team-b:flux-reconciler \
  -n team-a
# Expected: no

# Check if team-b can list pods in team-a namespace
kubectl auth can-i list pods \
  --as system:serviceaccount:team-b:flux-reconciler \
  -n team-a
# Expected: no
```

### Denied Operations (cluster-wide access)

```bash
# Check if team-b can list namespaces
kubectl auth can-i list namespaces \
  --as system:serviceaccount:team-b:flux-reconciler
# Expected: no

# Check if team-b can create PersistentVolumes (cluster-scoped)
kubectl auth can-i create persistentvolumes \
  --as system:serviceaccount:team-b:flux-reconciler
# Expected: no
```

## Verification Summary

Run the automated verification script to test all permissions at once:

```bash
chmod +x verify-rbac.sh
./verify-rbac.sh
```

## Key Takeaways

1. Each tenant's service account has **full permissions** within their own namespace
2. Each tenant's service account has **no permissions** in other tenants' namespaces
3. Each tenant's service account has **no cluster-wide permissions**
4. This enforces strong isolation boundaries between tenants

