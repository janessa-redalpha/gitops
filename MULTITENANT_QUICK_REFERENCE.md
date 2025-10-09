# Multi-Tenant FluxCD Setup - Quick Reference

## ✅ What Was Created

### Directory Structure
```
apps/
├── team-a/                    # Team A application manifests
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── team-b/                    # Team B application manifests
    ├── configmap.yaml
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml

clusters/dev/minikube/tenants/
├── team-a/                    # Team A onboarding manifests
│   ├── namespace.yaml         # Namespace with tenant=team-a label
│   ├── rbac.yaml             # ServiceAccount, Role, RoleBinding
│   └── kustomization.yaml    # FluxCD Kustomization
└── team-b/                    # Team B onboarding manifests
    ├── namespace.yaml         # Namespace with tenant=team-b label
    ├── rbac.yaml             # ServiceAccount, Role, RoleBinding
    └── kustomization.yaml    # FluxCD Kustomization
```

## 🔑 Key Components

### Namespaces
- **team-a**: Labeled with `tenant: team-a`
- **team-b**: Labeled with `tenant: team-b`

### RBAC (per tenant)
- **ServiceAccount**: `team-a-sa` / `team-b-sa` (in flux-system namespace)
- **Role**: `team-a-role` / `team-b-role` (in tenant namespace)
- **RoleBinding**: `team-a-rolebinding` / `team-b-rolebinding` (in tenant namespace)

### FluxCD Resources
- **GitRepository**: Reuses existing `flux-system` GitRepository
- **Kustomization**: `team-a-apps` / `team-b-apps` (in flux-system namespace)

### Sample Applications (per tenant)
- **ConfigMap**: Configuration data
- **Deployment**: 2 replicas of nginx:1.27-alpine
- **Service**: ClusterIP service on port 80

## 📊 Current Status

```bash
# Both kustomizations are healthy
team-a-apps: ✅ Ready - Applied revision: main@sha1:6dbf73a726547ec6ed33f314ea8f312ddd640201
team-b-apps: ✅ Ready - Applied revision: main@sha1:6dbf73a726547ec6ed33f314ea8f312ddd640201

# Team A: 2/2 pods running
# Team B: 2/2 pods running
```

## 🔧 Useful Commands

### View Tenant Resources
```bash
# View all resources for team-a
kubectl get all -n team-a

# View all resources for team-b
kubectl get all -n team-b

# View ConfigMaps
kubectl get configmap -n team-a
kubectl get configmap -n team-b
```

### Check Flux Status
```bash
# Check kustomization status
flux get kustomizations team-a-apps
flux get kustomizations team-b-apps

# Force reconciliation
flux reconcile kustomization team-a-apps --with-source
flux reconcile kustomization team-b-apps --with-source
```

### Verify RBAC
```bash
# Check ServiceAccounts
kubectl get sa -n flux-system team-a-sa team-b-sa

# Check Roles and RoleBindings
kubectl get role,rolebinding -n team-a
kubectl get role,rolebinding -n team-b

# Describe Role permissions
kubectl describe role team-a-role -n team-a
kubectl describe role team-b-role -n team-b
```

### Verify Isolation
```bash
# Check namespace labels
kubectl get namespace team-a team-b --show-labels

# Verify resources are in correct namespaces
kubectl get pods --all-namespaces -l tenant=team-a
kubectl get pods --all-namespaces -l tenant=team-b
```

## 🎯 Isolation Features

### ✅ Namespace Isolation
- Each tenant has dedicated namespace
- Resources cannot cross namespace boundaries

### ✅ RBAC Isolation
- ServiceAccounts in flux-system (where Flux runs)
- Roles scoped to tenant namespace only
- No cluster-level permissions
- Cannot access other tenant's resources

### ✅ Application Isolation
- Separate directories in Git
- Independent reconciliation
- Isolated configuration and secrets

### ✅ GitOps Isolation
- Changes tracked separately
- Independent deployment cycles
- Can use different branches/repos if needed

## 🚀 Adding a New Tenant (e.g., team-c)

1. **Create namespace manifest:**
   ```bash
   mkdir -p clusters/dev/minikube/tenants/team-c
   # Create namespace.yaml with tenant: team-c label
   ```

2. **Create RBAC manifest:**
   ```bash
   # Create rbac.yaml with team-c-sa, team-c-role, team-c-rolebinding
   ```

3. **Create Kustomization manifest:**
   ```bash
   # Create kustomization.yaml pointing to ./apps/team-c
   ```

4. **Create application directory:**
   ```bash
   mkdir -p apps/team-c
   # Add your manifests and kustomization.yaml
   ```

5. **Apply and commit:**
   ```bash
   kubectl apply -f clusters/dev/minikube/tenants/team-c/
   git add .
   git commit -m "Add team-c tenant"
   git push
   flux reconcile kustomization flux-system
   ```

## 📝 Files for Submission

1. **Namespace, ServiceAccount, Role, RoleBinding YAML:**
   - `clusters/dev/minikube/tenants/team-a/namespace.yaml`
   - `clusters/dev/minikube/tenants/team-a/rbac.yaml`
   - `clusters/dev/minikube/tenants/team-b/namespace.yaml`
   - `clusters/dev/minikube/tenants/team-b/rbac.yaml`

2. **GitRepository and Kustomization YAML:**
   - Uses existing `flux-system` GitRepository
   - `clusters/dev/minikube/tenants/team-a/kustomization.yaml`
   - `clusters/dev/minikube/tenants/team-b/kustomization.yaml`

3. **Output commands:**
   ```bash
   kubectl get all -n team-a
   kubectl get all -n team-b
   kubectl get configmap -n team-a
   kubectl get configmap -n team-b
   kubectl get kustomization -n flux-system team-a-apps team-b-apps
   ```

4. **Complete documentation:**
   - `MULTITENANT_SUBMISSION.md` (comprehensive submission doc)
   - `MULTITENANT_QUICK_REFERENCE.md` (this file)

## 🎓 Key Learnings

1. **ServiceAccounts must be in flux-system** where Flux controllers run
2. **Roles are namespace-scoped** to limit permissions
3. **RoleBindings connect ServiceAccount to Role** across namespaces
4. **targetNamespace in Kustomization** directs where resources are applied
5. **Reusing GitRepository** reduces complexity and authentication overhead
6. **Resource requests matter** for scheduling in resource-constrained clusters
7. **Namespace labels** help with filtering and organization

## 🔒 Security Best Practices Implemented

✅ Principle of Least Privilege (minimal necessary permissions)  
✅ Namespace-scoped RBAC (no cluster-wide access)  
✅ Separate ServiceAccounts per tenant  
✅ GitOps-based access control  
✅ Audit trail via Git history  
✅ Explicit resource permissions (no wildcards on apiGroups)  

---

**Status**: ✅ Production-ready multi-tenant FluxCD setup complete!

