# Exercise 04: FluxCD CLI Mastery - Deliverables



## 1. FluxCD CLI Cheat Sheet

### Installation & Environment Checks
```bash
# Check prerequisites (Kubernetes version, etc.)
flux check --pre

# Check Flux installation status and controllers
flux check

# Show Flux version
flux --version
```

**When to use:** Before installation or when troubleshooting controller issues.

---

### Listing & Inspecting Resources

```bash
# List all Flux resources
flux get all -A

# List Git sources across all namespaces
flux get sources git -A

# List Helm repositories
flux get sources helm -A

# List all Kustomizations
flux get kustomizations -A

# List HelmReleases
flux get helmreleases -A

# Show detailed info about a specific resource
flux get kustomization <name> -n <namespace>
```

**When to use:** Daily operations to check status of GitOps resources.

---

### Visualizing Relationships

```bash
# Show resource tree (what a Kustomization manages)
flux tree kustomization <name> -n <namespace>

# Example output shows hierarchy of all managed resources
flux tree kustomization flux-system -n flux-system
```

**When to use:** Understanding what resources are managed by a Kustomization and their dependencies.

---

### Reconciliation (Sync)

```bash
# Force reconcile a Kustomization (sync from Git)
flux reconcile kustomization <name> -n <namespace>

# Reconcile with source refresh (fetch latest from Git first)
flux reconcile kustomization <name> -n <namespace> --with-source

# Reconcile a Git source
flux reconcile source git <name> -n <namespace>

# Reconcile a HelmRelease
flux reconcile helmrelease <name> -n <namespace>
```

**When to use:** When you've pushed changes to Git and want immediate sync instead of waiting for the interval.

---

### Events & Logs

```bash
# View events for all resources
flux events -A

# View events for a specific resource
flux events -A --for Kustomization/<name>

# View controller logs
flux logs --kind Kustomization --name <name> -n <namespace>

# Tail logs in real-time
flux logs --kind Kustomization --name <name> -n <namespace> --follow

# Get logs with time range
flux logs --kind Kustomization --name <name> -n <namespace> --since=1h
```

**When to use:** Debugging reconciliation failures or understanding what Flux is doing.

---

### Suspend & Resume

```bash
# Suspend a Kustomization (stop reconciliation)
flux suspend kustomization <name> -n <namespace>

# Resume a suspended Kustomization
flux resume kustomization <name> -n <namespace>

# Suspend a HelmRelease
flux suspend helmrelease <name> -n <namespace>

# Resume a HelmRelease
flux resume helmrelease <name> -n <namespace>
```

**When to use:** Making manual changes without Flux overwriting them, or pausing problematic workloads.

---

### Exporting Declarative YAML

```bash
# Export a GitRepository definition
flux create source git <name> \
  --url=<git-url> \
  --branch=<branch> \
  --interval=<interval> \
  --export

# Export a Kustomization definition
flux create kustomization <name> \
  --source=GitRepository/<source-name> \
  --path="<path>" \
  --prune=true \
  --interval=<interval> \
  --export

# Export a HelmRepository definition
flux create source helm <name> \
  --url=<helm-url> \
  --interval=<interval> \
  --export

# Export existing resources
flux export source git --all > sources.yaml
flux export kustomization --all > kustomizations.yaml
```

**When to use:** Creating new resources without writing YAML from scratch, or backing up existing configurations.

---

### Advanced Commands

```bash
# Diff what would be applied (requires kustomize-controller v0.21+)
flux diff kustomization <name> -n <namespace>

# Trace a Kustomization to its source
flux trace <resource-name> --kind <Kind> --api-version <api-version> --namespace <namespace>

# Uninstall Flux
flux uninstall --namespace=flux-system --silent

# Bootstrap Flux on a cluster
flux bootstrap github \
  --owner=<github-user> \
  --repository=<repo-name> \
  --branch=<branch> \
  --path=<path> \
  --personal
```

**When to use:** Advanced scenarios, migrations, or cluster setup.

---

## 2. Example Outputs

### flux check --pre
```
► checking prerequisites
✔ Kubernetes 1.34.0 >=1.32.0-0
✔ prerequisites checks passed
```

### flux check
```
► checking prerequisites
✔ Kubernetes 1.34.0 >=1.32.0-0
► checking version in cluster
✔ distribution: flux-v2.7.1
✔ bootstrapped: true
► checking controllers
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
```

### flux get all -A
```
NAMESPACE    NAME                      REVISION           SUSPENDED  READY  MESSAGE                                           
flux-system  gitrepository/flux-system main@sha1:ccd5b136 False      True   stored artifact for revision 'main@sha1:ccd5b136'

NAMESPACE    NAME                   REVISION        SUSPENDED  READY  MESSAGE                                     
flux-system  helmrepository/bitnami sha256:df03891e False      True   stored artifact: revision 'sha256:df03891e'

NAMESPACE    NAME                               REVISION           SUSPENDED  READY  MESSAGE                              
flux-system  kustomization/backend-app          main@sha1:ccd5b136 False      True   Applied revision: main@sha1:ccd5b136
flux-system  kustomization/flux-system          main@sha1:ccd5b136 False      True   Applied revision: main@sha1:ccd5b136
flux-system  kustomization/frontend-app         main@sha1:ccd5b136 False      True   Applied revision: main@sha1:ccd5b136
flux-system  kustomization/infrastructure-redis main@sha1:ccd5b136 False      True   Applied revision: main@sha1:ccd5b136
```

### flux tree kustomization flux-system -n flux-system
```
Kustomization/flux-system/flux-system
├── CustomResourceDefinition/alerts.notification.toolkit.fluxcd.io
├── CustomResourceDefinition/gitrepositories.source.toolkit.fluxcd.io
├── CustomResourceDefinition/helmcharts.source.toolkit.fluxcd.io
├── CustomResourceDefinition/helmreleases.helm.toolkit.fluxcd.io
├── CustomResourceDefinition/helmrepositories.source.toolkit.fluxcd.io
├── CustomResourceDefinition/kustomizations.kustomize.toolkit.fluxcd.io
├── Namespace/flux-system
├── ServiceAccount/flux-system/helm-controller
├── ServiceAccount/flux-system/kustomize-controller
├── ServiceAccount/flux-system/notification-controller
├── ServiceAccount/flux-system/source-controller
├── Service/flux-system/notification-controller
├── Service/flux-system/source-controller
├── Deployment/flux-system/helm-controller
├── Deployment/flux-system/kustomize-controller
├── Deployment/flux-system/notification-controller
├── Deployment/flux-system/source-controller
├── Kustomization/flux-system/backend-app
│   ├── Service/apps/backend
│   └── Deployment/apps/backend
├── Kustomization/flux-system/frontend-app
│   ├── Namespace/apps
│   ├── Service/apps/frontend
│   └── Deployment/apps/frontend
├── Kustomization/flux-system/infrastructure-redis
│   ├── Service/apps/redis-master
│   └── Deployment/apps/redis
├── GitRepository/flux-system/flux-system
└── HelmRepository/flux-system/bitnami
```

**Analysis:** This shows the complete hierarchy managed by flux-system, including:
- CRDs for Flux resources
- Flux controller deployments
- Child Kustomizations (backend-app, frontend-app, infrastructure-redis)
- All resources managed by each child Kustomization

### flux tree kustomization frontend-app -n flux-system
```
Kustomization/flux-system/frontend-app
├── Namespace/apps
├── Service/apps/frontend
└── Deployment/apps/frontend
```

**Analysis:** Frontend manages 3 resources: namespace, service, and deployment.

### flux reconcile kustomization frontend-app -n flux-system --with-source
```
► annotating GitRepository flux-system in flux-system namespace
✔ GitRepository annotated
◎ waiting for GitRepository reconciliation
✔ fetched revision main@sha1:ccd5b136b48e88cf54f19e7dd4a3b0d62a12acd3
► annotating Kustomization frontend-app in flux-system namespace
✔ Kustomization annotated
◎ waiting for Kustomization reconciliation
✔ applied revision main@sha1:ccd5b136b48e88cf54f19e7dd4a3b0d62a12acd3
```

**Analysis:** Shows the two-step process:
1. Refresh the Git source
2. Apply the Kustomization from the refreshed source

### flux events -A --for Kustomization/frontend-app (excerpt)
```
NAMESPACE    LAST SEEN  TYPE    REASON                      OBJECT                      MESSAGE
flux-system  36m        Normal  Progressing                 Kustomization/frontend-app  Namespace/apps configured
                                                                                        Service/apps/frontend configured
                                                                                        Deployment/apps/frontend configured
flux-system  36m        Normal  Progressing                 Kustomization/frontend-app  Health check passed in 538ms
flux-system  36m        Normal  ReconciliationSucceeded     Kustomization/frontend-app  Reconciliation finished in 9.04s, next run in 5m0s
```

**Analysis:** Events show:
- What resources were applied
- Health check status
- Reconciliation success and timing

### flux logs --kind Kustomization --name frontend-app -n flux-system
```
2025-10-07T09:17:32.707Z info Kustomization/frontend-app.flux-system - server-side apply completed
2025-10-07T09:17:35.393Z info Kustomization/frontend-app.flux-system - Reconciliation finished in 8.97s, next run in 5m0s
```

**Analysis:** Logs show successful server-side apply and timing information.

### flux suspend / resume
```bash
# Suspend
$ flux suspend kustomization frontend-app -n flux-system
► suspending kustomization frontend-app in flux-system namespace
✔ kustomization suspended

# Check status
$ flux get kustomizations -A | grep frontend
flux-system  frontend-app  main@sha1:ccd5b136  True   True   Applied revision: main@sha1:ccd5b136

# Resume
$ flux resume kustomization frontend-app -n flux-system
► resuming kustomization frontend-app in flux-system namespace
✔ kustomization resumed
◎ waiting for Kustomization reconciliation
✔ Kustomization frontend-app reconciliation completed
✔ applied revision main@sha1:ccd5b136b48e88cf54f19e7dd4a3b0d62a12acd3
```

**Analysis:** Suspend immediately stops reconciliation. Resume triggers an immediate reconciliation.

### flux create source git --export
```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: demo-repo
  namespace: flux-system
spec:
  interval: 5m0s
  ref:
    branch: main
  url: https://github.com/example/repo
```

### flux create kustomization --export
```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: demo-app
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./deploy
  prune: true
  sourceRef:
    kind: GitRepository
    name: demo-repo
```

---

## 3. Debugging Workflow

### My Typical Debugging Process

When something goes wrong with Flux, I follow this systematic approach:

#### Step 1: Check High-Level Status
```bash
# Quick overview of all Flux resources
flux get all -A
```

**Look for:** `READY` column showing `False` or `Unknown`

#### Step 2: Identify the Failing Resource
```bash
# Get detailed status
flux get kustomizations -A
flux get sources git -A
flux get helmreleases -A
```

**Look for:** Error messages in the `MESSAGE` column

#### Step 3: Check Recent Events
```bash
# See what Flux has been doing
flux events -A --for Kustomization/<failing-name>
```

**Look for:** 
- `Warning` events
- Error messages
- Path not found errors
- Authentication failures

#### Step 4: Review Controller Logs
```bash
# Get detailed logs from the controller
flux logs --kind Kustomization --name <failing-name> -n flux-system --tail 50
```

**Look for:**
- Stack traces
- Timeout errors
- Network issues
- YAML parsing errors

#### Step 5: Visualize Dependencies
```bash
# See what the Kustomization manages
flux tree kustomization <name> -n flux-system
```

**Look for:**
- Missing resources
- Circular dependencies
- Resources in wrong namespace

#### Step 6: Force Reconciliation
```bash
# Try to refresh and see if it resolves
flux reconcile kustomization <name> -n flux-system --with-source
```

**Look for:** Whether error persists or if it was a transient issue

#### Step 7: Suspend, Fix, Resume
```bash
# Suspend the resource
flux suspend kustomization <name> -n flux-system

# Fix the issue (edit Git repo, fix syntax, etc.)

# Resume and watch
flux resume kustomization <name> -n flux-system
flux logs --kind Kustomization --name <name> -n flux-system --follow
```

---

### Common Issues & Solutions

| Issue | Command to Diagnose | Common Cause |
|-------|---------------------|--------------|
| **Path not found** | `flux events -A` | Wrong `path` in Kustomization spec |
| **Source not ready** | `flux get sources git -A` | Git URL unreachable or auth failure |
| **Reconciliation timeout** | `flux logs --kind Kustomization ...` | Large manifests or slow cluster |
| **Dependency not ready** | `flux tree kustomization ...` | Check `dependsOn` field |
| **Health check failing** | `flux events -A` | Pod not starting or wrong health check |
| **Authentication errors** | `flux logs --kind GitRepository ...` | Missing/incorrect credentials |

---

### Debugging Checklist

- [ ] Run `flux check` to ensure controllers are healthy
- [ ] Check `flux get all -A` for overall status
- [ ] Review `flux events` for recent errors
- [ ] Check `flux logs` for detailed error messages
- [ ] Verify Git repository is accessible
- [ ] Confirm paths in Kustomization specs are correct
- [ ] Check dependencies with `flux tree`
- [ ] Validate YAML syntax in Git repo
- [ ] Ensure Kubernetes resources are valid
- [ ] Check namespace permissions and quotas

---

### Pro Tips

1. **Use --with-source flag**: Always reconcile with `--with-source` to fetch latest from Git
2. **Events are your friend**: `flux events` shows what Flux is doing in plain English
3. **Suspend for manual fixes**: Suspend Kustomizations when you need to make manual changes
4. **Export before creating**: Use `--export` to generate YAML templates
5. **Tree for understanding**: `flux tree` is invaluable for understanding what's managed
6. **Logs for deep debugging**: When events aren't enough, logs show the full story
7. **Check the source first**: If a Kustomization fails, check if its source is ready
8. **Reconcile is safe**: Force reconciliation won't break anything, it just syncs from Git

---

## 4. Quick Reference Card

### Daily Operations
```bash
flux get all -A                              # Check everything
flux reconcile kustomization <name> --with-source  # Force sync
flux events -A                               # See recent activity
```

### Troubleshooting
```bash
flux check                                   # Health check
flux events -A --for <Type>/<name>          # Debug specific resource
flux logs --kind <Kind> --name <name>       # Detailed logs
flux tree kustomization <name>              # See what's managed
```

### Safe Editing
```bash
flux suspend kustomization <name>            # Pause reconciliation
# Make changes...
flux resume kustomization <name>             # Resume and sync
```

### Creating Resources
```bash
flux create source git <name> ... --export   # Generate Git source YAML
flux create kustomization <name> ... --export  # Generate Kustomization YAML
```

