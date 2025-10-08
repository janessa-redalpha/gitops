# Quick Start Guide - Multi-Tenant FluxCD Setup

This is a quick reference guide to get the multi-tenant FluxCD setup running.

## Directory Structure

```
05-multitenant-flux/
├── base/                              # Base manifests (optional)
├── tenants/
│   ├── team-a/
│   │   ├── namespace.yaml             # Namespace with tenant label
│   │   ├── rbac.yaml                  # ServiceAccount, Role, RoleBinding
│   │   ├── git-secret.yaml            # Git auth secret template
│   │   ├── gitrepository.yaml         # Git source configuration
│   │   └── kustomization.yaml         # Flux reconciler config
│   └── team-b/
│       ├── namespace.yaml
│       ├── rbac.yaml
│       ├── git-secret.yaml
│       ├── gitrepository.yaml
│       └── kustomization.yaml
├── README.md                          # Full documentation
├── SUBMISSION.md                      # Assignment submission details
├── kubectl-auth-examples.md           # RBAC verification examples
├── verify-rbac.sh                     # Automated RBAC testing
└── deploy-all.sh                      # Deployment automation
```

## Prerequisites

- ✅ Kubernetes cluster (v1.24+)
- ✅ FluxCD installed (`flux install`)
- ✅ kubectl with cluster-admin access
- ✅ Git repositories for teams (or monorepo paths)

## 5-Minute Setup

### 1. Update Git Repository URLs

Edit these files to point to your actual Git repositories:

```bash
# Update team-a Git URL
vim tenants/team-a/gitrepository.yaml

# Update team-b Git URL
vim tenants/team-b/gitrepository.yaml
```

Change the `spec.url` field to your repository:
```yaml
spec:
  url: https://github.com/YOUR-ORG/team-a-apps  # <- Update this
```

### 2. Create Git Authentication Secrets

For HTTPS with Personal Access Token:

```bash
# Create secret for team-a
kubectl create namespace team-a
kubectl create secret generic team-a-git-auth \
  --namespace=team-a \
  --from-literal=username=git \
  --from-literal=password=ghp_YOUR_GITHUB_TOKEN_HERE

# Create secret for team-b
kubectl create namespace team-b
kubectl create secret generic team-b-git-auth \
  --namespace=team-b \
  --from-literal=username=git \
  --from-literal=password=ghp_YOUR_GITHUB_TOKEN_HERE
```

For SSH (alternative):

```bash
# Create secret for team-a
kubectl create secret generic team-a-git-auth \
  --namespace=team-a \
  --from-file=identity=/path/to/team-a-private-key \
  --from-file=known_hosts=/path/to/known_hosts

# Create secret for team-b
kubectl create secret generic team-b-git-auth \
  --namespace=team-b \
  --from-file=identity=/path/to/team-b-private-key \
  --from-file=known_hosts=/path/to/known_hosts
```

### 3. Deploy All Resources

```bash
# Apply namespaces
kubectl apply -f tenants/team-a/namespace.yaml
kubectl apply -f tenants/team-b/namespace.yaml

# Apply RBAC
kubectl apply -f tenants/team-a/rbac.yaml
kubectl apply -f tenants/team-b/rbac.yaml

# Apply Git sources (secrets already created in step 2)
kubectl apply -f tenants/team-a/gitrepository.yaml
kubectl apply -f tenants/team-b/gitrepository.yaml

# Apply Kustomizations
kubectl apply -f tenants/team-a/kustomization.yaml
kubectl apply -f tenants/team-b/kustomization.yaml
```

Or use the automated script:

```bash
./deploy-all.sh
```

### 4. Verify Everything Works

```bash
# Check if GitRepositories are ready
flux get sources git -n team-a
flux get sources git -n team-b

# Check if Kustomizations are ready
flux get kustomizations -n team-a
flux get kustomizations -n team-b

# View all Flux resources
flux get all -n team-a
flux get all -n team-b

# Watch logs
flux logs -n team-a --follow
```

### 5. Verify RBAC Boundaries

Run the automated verification:

```bash
./verify-rbac.sh
```

Or test manually:

```bash
# Should return "yes" - team-a can manage their namespace
kubectl auth can-i create deployments \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-a

# Should return "no" - team-a cannot access team-b
kubectl auth can-i create deployments \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-b

# Should return "no" - team-a cannot list namespaces
kubectl auth can-i list namespaces \
  --as system:serviceaccount:team-a:flux-reconciler
```

## What Each Team's Git Repository Should Contain

Each team's Git repository (or monorepo path) should have Kubernetes manifests:

```
team-a-apps/                      # or /teams/team-a/ in monorepo
├── deployment.yaml
├── service.yaml
├── configmap.yaml
└── ingress.yaml
```

Example deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: team-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
```

## Common Commands

### Check Status

```bash
# Overall status
flux get all -n team-a
flux get all -n team-b

# Detailed status
kubectl describe gitrepository -n team-a team-a-apps
kubectl describe kustomization -n team-a team-a-apps
```

### Force Reconciliation

```bash
# Immediately sync from Git
flux reconcile source git team-a-apps -n team-a
flux reconcile kustomization team-a-apps -n team-a
```

### View Resources

```bash
# List all resources in tenant namespace
kubectl get all -n team-a
kubectl get all -n team-b

# List Flux resources
kubectl get gitrepositories,kustomizations -n team-a
```

### Suspend/Resume

```bash
# Pause reconciliation
flux suspend kustomization team-a-apps -n team-a

# Resume reconciliation
flux resume kustomization team-a-apps -n team-a
```

## Troubleshooting

### GitRepository Not Ready

```bash
# Check status
kubectl describe gitrepository -n team-a team-a-apps

# Common fixes:
# - Verify Git credentials are correct
# - Check Git URL is accessible
# - Ensure secret name matches in gitrepository.yaml
```

### Kustomization Failing

```bash
# Check logs
flux logs -n team-a --level=error

# Check status
kubectl describe kustomization -n team-a team-a-apps

# Common fixes:
# - Verify RBAC permissions
# - Check for invalid manifests in Git
# - Ensure targetNamespace is correct
```

### RBAC Errors

```bash
# Check if ServiceAccount exists
kubectl get sa -n team-a flux-reconciler

# Check Role permissions
kubectl describe role -n team-a flux-reconciler

# Check RoleBinding
kubectl describe rolebinding -n team-a flux-reconciler

# Test specific permission
kubectl auth can-i <verb> <resource> \
  --as system:serviceaccount:team-a:flux-reconciler \
  -n team-a
```

## Next Steps

1. ✅ Deploy applications from team Git repositories
2. ✅ Add more tenants by copying the pattern
3. ✅ Implement NetworkPolicies for network isolation
4. ✅ Add ResourceQuotas to limit resource usage
5. ✅ Configure monitoring and alerting per tenant
6. ✅ Set up CD pipelines with image automation

## Additional Resources

- Full documentation: `README.md`
- RBAC examples: `kubectl-auth-examples.md`
- Submission details: `SUBMISSION.md`
- [FluxCD Multi-Tenancy Docs](https://fluxcd.io/flux/installation/configuration/multitenancy/)

## Summary

This setup provides:
- ✅ Strong namespace isolation between tenants
- ✅ RBAC-enforced security boundaries
- ✅ Self-service GitOps for each team
- ✅ Separate Git sources per tenant
- ✅ Constrained reconcilers with limited permissions
- ✅ Easy to scale to additional tenants

Happy GitOps! 🚀

