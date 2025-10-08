# Exercise 03: Multiple Source Configuration Setup - Deliverables

## Submitted By: Janessa Yang (janessa.yang@redalphacyber.com)

## Overview

This deliverable demonstrates a **production-ready multi-source FluxCD configuration** with:
- ✅ 3 separate Git repositories (simulating team ownership)
- ✅ 1 Helm repository (Bitnami for shared infrastructure)
- ✅ Independent Kustomizations per application
- ✅ Dependency management (backend depends on Redis)
- ✅ Different reconciliation intervals per source
- ✅ Health checks and automatic remediation
- ✅ Complete setup and deployment guide

---

## Repository Structure

This deliverable contains **three independent Git repositories**:

### 1. `gitops-main/` - Central GitOps Repository
**Purpose**: Infrastructure configuration and Flux setup

```
gitops-main/
├── README.md                           # Repository documentation
├── clusters/production/
│   ├── flux-system/                    # Flux installation
│   │   ├── gotk-components.yaml        # Flux controllers (generate with flux install)
│   │   ├── gotk-sync.yaml              # GitRepository and Kustomization for flux-system
│   │   └── kustomization.yaml          # Kustomize config
│   ├── sources/                        # Source definitions
│   │   ├── frontend-repo.yaml          # GitRepository for frontend
│   │   ├── backend-repo.yaml           # GitRepository for backend
│   │   ├── helm-bitnami.yaml           # HelmRepository for Bitnami
│   │   └── kustomization.yaml
│   └── apps/                           # Application Kustomizations
│       ├── frontend-kustomization.yaml
│       ├── backend-kustomization.yaml
│       ├── infrastructure-redis-kustomization.yaml
│       └── kustomization.yaml
└── infrastructure/
    └── helm-releases/                  # Shared infrastructure
        ├── redis-release.yaml          # Redis HelmRelease
        └── kustomization.yaml
```

**Git commit**: `edacaa2` - "Initial commit: GitOps configuration with multi-source setup"

### 2. `frontend-app/` - Frontend Application Repository
**Purpose**: Frontend team's application manifests

```
frontend-app/
├── README.md              # App documentation
├── namespace.yaml         # apps namespace
├── deployment.yaml        # Frontend Deployment (nginx, 2 replicas)
├── service.yaml           # Frontend Service
└── kustomization.yaml     # Kustomize config
```

**Team**: frontend-team  
**Git commit**: `b242eb1` - "Initial commit: Frontend application manifests"

### 3. `backend-api/` - Backend API Repository
**Purpose**: Backend team's application manifests

```
backend-api/
├── README.md              # App documentation
├── deployment.yaml        # Backend Deployment (http-echo, 3 replicas)
├── service.yaml           # Backend Service
└── kustomization.yaml     # Kustomize config
```

**Team**: backend-team  
**Git commit**: `6ebb18c` - "Initial commit: Backend API manifests"

---

## Source Definitions

### GitRepository Sources

#### 1. flux-system (Main Repository)
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  url: https://github.com/YOUR-ORG/gitops-main.git
```
**Purpose**: Infrastructure, Flux config, and Redis HelmRelease  
**Interval**: 1 minute (fast reconciliation for cluster config)

#### 2. frontend-repo
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: frontend-repo
  namespace: flux-system
spec:
  interval: 2m0s
  ref:
    branch: main
  url: https://github.com/YOUR-ORG/frontend-app.git
```
**Purpose**: Frontend application manifests  
**Interval**: 2 minutes (frequent updates expected)  
**Owned by**: frontend-team

#### 3. backend-repo
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: backend-repo
  namespace: flux-system
spec:
  interval: 3m0s
  ref:
    branch: main
  url: https://github.com/YOUR-ORG/backend-api.git
```
**Purpose**: Backend API manifests  
**Interval**: 3 minutes (less frequent updates)  
**Owned by**: backend-team

### HelmRepository Source

#### bitnami
```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: bitnami
  namespace: flux-system
spec:
  interval: 10m0s
  url: https://charts.bitnami.com/bitnami
```
**Purpose**: Shared infrastructure components (Redis)  
**Interval**: 10 minutes (external stable charts)

---

## Kustomization Resources

### 1. frontend-app
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: frontend-app
  namespace: flux-system
spec:
  interval: 5m0s
  path: ./
  prune: true
  sourceRef:
    kind: GitRepository
    name: frontend-repo  # ← References separate frontend repo
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: frontend
    namespace: apps
  timeout: 2m
```

**Key Features**:
- Independent source (frontend-repo)
- Health check on Deployment
- No dependencies
- Auto-prune deleted resources

### 2. backend-app
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: backend-app
  namespace: flux-system
spec:
  interval: 5m0s
  path: ./
  prune: true
  sourceRef:
    kind: GitRepository
    name: backend-repo  # ← References separate backend repo
  dependsOn:
  - name: infrastructure-redis  # ← Waits for Redis
  healthChecks:
  - apiVersion: apps/v1
    kind: Deployment
    name: backend
    namespace: apps
  timeout: 2m
```

**Key Features**:
- Independent source (backend-repo)
- **Depends on infrastructure-redis** (ordered deployment)
- Health check on Deployment
- Auto-prune deleted resources

### 3. infrastructure-redis
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure-redis
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./infrastructure/helm-releases
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system  # ← Uses main GitOps repo
  timeout: 5m
```

**Key Features**:
- Slower reconciliation (10m)
- Longer timeout for Helm installs
- Infrastructure-grade reliability

---

## HelmRelease Definition

### Redis (Shared Infrastructure)
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: redis
  namespace: apps
spec:
  interval: 5m
  chart:
    spec:
      chart: redis
      version: 19.6.4  # ← Pinned version
      sourceRef:
        kind: HelmRepository
        name: bitnami
        namespace: flux-system
      interval: 10m
  install:
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    architecture: standalone
    auth:
      enabled: false
    master:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 200m
          memory: 128Mi
```

**Why Pin Version?**
- Prevents unexpected breaking changes
- Ensures reproducible deployments
- Controlled upgrade process

---

## Reconciliation Intervals & Dependencies

### Interval Strategy

| Component | Interval | Rationale |
|-----------|----------|-----------|
| flux-system GitRepo | 1m | Fast cluster config changes |
| frontend-repo GitRepo | 2m | Frequent frontend updates |
| backend-repo GitRepo | 3m | Less frequent backend updates |
| bitnami HelmRepo | 10m | Stable external charts |
| frontend-app Kustomization | 5m | Regular app reconciliation |
| backend-app Kustomization | 5m | Regular app reconciliation |
| infrastructure Kustomization | 10m | Slower infra changes |
| Redis HelmRelease | 5m | Monitor for updates |

### Dependency Graph

```
┌─────────────────────────┐
│  infrastructure-redis   │
│  (from flux-system)     │
└───────────┬─────────────┘
            │
            │ dependsOn
            ↓
┌─────────────────────────┐     ┌─────────────────────────┐
│      backend-app        │     │     frontend-app        │
│  (from backend-repo)    │     │  (from frontend-repo)   │
└─────────────────────────┘     └─────────────────────────┘
          ↓                                   ↓
    backend pods                        frontend pods
```

**Benefits**:
1. Redis deploys first (infrastructure layer)
2. Backend waits for Redis to be ready
3. Frontend deploys independently (no dependency)
4. Automatic retries if dependency not ready

---

## Application Isolation Strategy

### 1. Repository Isolation
- **Separate Git Repositories**: Each team owns their repo
  - Frontend: `YOUR-ORG/frontend-app`
  - Backend: `YOUR-ORG/backend-api`
  - Platform: `YOUR-ORG/gitops-main`
- **Independent Access Control**: Per-repo permissions
- **Separate Reconciliation**: Teams update at their own pace

### 2. Source Isolation
- **Different Intervals**: frontend (2m), backend (3m), infra (10m)
- **Independent Credentials**: Each repo can have separate SSH keys
- **Selective Updates**: Changes in one repo don't trigger others

### 3. Kustomization Isolation
- **Separate Kustomization per App**: frontend-app, backend-app, infrastructure-redis
- **Independent Health Checks**: Each validates its own deployment
- **Isolated Failures**: One app's failure doesn't block others
- **Explicit Dependencies**: Only backend depends on Redis

### 4. Team Ownership
```yaml
# Frontend labels
labels:
  app: frontend
  team: frontend-team

# Backend labels
labels:
  app: backend
  team: backend-team

# Infrastructure labels
labels:
  toolkit.fluxcd.io/tenant: platform-team
```

### 5. Benefits

| Benefit | Description |
|---------|-------------|
| **Team Autonomy** | Each team controls their deployment pipeline |
| **Blast Radius** | Failures contained to single app |
| **Independent Scaling** | Teams choose reconciliation frequency |
| **Clear Ownership** | Labels identify responsible team |
| **Audit Trail** | Git history shows who changed what |
| **Security** | Repository-level access control |

---

## Setup Instructions

### Quick Start

1. **Create GitHub Repositories**:
   ```bash
   gh repo create YOUR-ORG/gitops-main --public
   gh repo create YOUR-ORG/frontend-app --public
   gh repo create YOUR-ORG/backend-api --public
   ```

2. **Update URLs** in:
   - `gitops-main/clusters/production/sources/*.yaml`
   - `gitops-main/clusters/production/flux-system/gotk-sync.yaml`

3. **Push Repositories**:
   ```bash
   cd gitops-main && git push origin main
   cd ../frontend-app && git push origin main
   cd ../backend-api && git push origin main
   ```

4. **Bootstrap Flux**:
   ```bash
   flux bootstrap github \
     --owner=YOUR-ORG \
     --repository=gitops-main \
     --branch=main \
     --path=clusters/production/flux-system \
     --personal
   ```

5. **Verify**:
   ```bash
   flux get sources all -A
   flux get kustomizations -A
   kubectl -n apps get pods
   ```

See `SETUP-GUIDE.md` for detailed instructions.

---

## Verification Commands & Expected Output

### 1. Check Sources
```bash
$ flux get sources all -A
```
**Expected**:
```
NAMESPACE     NAME                       REVISION         READY MESSAGE
flux-system   gitrepository/flux-system  main@sha1:...   True  stored artifact
flux-system   gitrepository/frontend-repo main@sha1:...  True  stored artifact
flux-system   gitrepository/backend-repo main@sha1:...   True  stored artifact
flux-system   helmrepository/bitnami     sha256:...      True  stored artifact
flux-system   helmchart/apps-redis       19.6.4          True  pulled 'redis' chart
```

### 2. Check Kustomizations
```bash
$ flux get kustomizations -A
```
**Expected**:
```
NAMESPACE     NAME                   REVISION         READY MESSAGE
flux-system   flux-system           main@sha1:...    True  Applied revision
flux-system   frontend-app          main@sha1:...    True  Applied revision
flux-system   backend-app           main@sha1:...    True  Applied revision
flux-system   infrastructure-redis  main@sha1:...    True  Applied revision
```

### 3. Check HelmReleases
```bash
$ flux get helmreleases -A
```
**Expected**:
```
NAMESPACE   NAME   REVISION  READY MESSAGE
apps        redis  19.6.4    True  Helm install succeeded
```

### 4. Check Application Pods
```bash
$ kubectl -n apps get deployments,pods,services
```
**Expected**:
```
NAME                       READY   UP-TO-DATE   AVAILABLE
deployment.apps/frontend   2/2     2            2
deployment.apps/backend    3/3     3            3

NAME                            READY   STATUS
pod/frontend-xxx-xxx            1/1     Running
pod/frontend-xxx-xxx            1/1     Running
pod/backend-xxx-xxx             1/1     Running
pod/backend-xxx-xxx             1/1     Running
pod/backend-xxx-xxx             1/1     Running
pod/redis-master-0              1/1     Running

NAME                     TYPE        CLUSTER-IP      PORT(S)
service/frontend         ClusterIP   10.x.x.x        80/TCP
service/backend          ClusterIP   10.x.x.x        8080/TCP
service/redis-master     ClusterIP   10.x.x.x        6379/TCP
```

---

## Resource Values Rationale

### Frontend (Nginx)
- **Replicas**: 2 (HA without over-provisioning)
- **CPU Request**: 50m (lightweight web server)
- **Memory Request**: 64Mi (minimal for nginx)
- **CPU Limit**: 200m (4x headroom for bursts)
- **Memory Limit**: 128Mi (2x headroom)

### Backend (API)
- **Replicas**: 3 (higher availability for API tier)
- **CPU Request**: 100m (more processing than frontend)
- **Memory Request**: 128Mi (API caching and processing)
- **CPU Limit**: 500m (5x headroom for computation)
- **Memory Limit**: 256Mi (2x headroom)

### Redis (Cache)
- **Architecture**: Standalone (demo simplicity)
- **CPU Request**: 50m (I/O bound workload)
- **Memory Request**: 64Mi (small cache size)
- **CPU Limit**: 200m (handle request spikes)
- **Memory Limit**: 128Mi (prevent OOM)

---

## Files Included

```
multi-source-demo/
├── DELIVERABLES.md           # This file
├── SETUP-GUIDE.md            # Step-by-step deployment guide
├── frontend-app/             # Frontend repository
│   ├── README.md
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
├── backend-api/              # Backend repository
│   ├── README.md
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── gitops-main/              # Main GitOps repository
    ├── README.md
    ├── clusters/production/
    │   ├── flux-system/
    │   ├── sources/
    │   └── apps/
    └── infrastructure/
        └── helm-releases/
```

---

## Summary

### What Was Demonstrated

✅ **Multiple Git Sources**: 3 independent repositories  
✅ **Multiple Helm Sources**: Bitnami public repository  
✅ **Independent Kustomizations**: Separate reconciliation per app  
✅ **Dependency Management**: Backend waits for Redis  
✅ **Different Intervals**: 1m, 2m, 3m, 5m, 10m intervals  
✅ **Health Checks**: Per-deployment validation  
✅ **Helm Chart Pinning**: Version 19.6.4 locked  
✅ **Team Ownership**: Labels for frontend-team, backend-team, platform-team  
✅ **Isolated Failures**: Apps fail independently  
✅ **Production Patterns**: SSH keys, retries, remediation

### Key Learnings

1. **Multi-source enables team autonomy** while maintaining central control
2. **Dependencies ensure correct ordering** without tight coupling
3. **Different intervals optimize** reconciliation efficiency
4. **Pinned versions prevent** unexpected breaking changes
5. **Health checks provide** automatic validation
6. **Repository isolation creates** clear ownership boundaries

---

## Submission Checklist

- [x] Multiple Git repositories (frontend, backend, gitops-main)
- [x] Helm repository (Bitnami)
- [x] GitRepository YAML files for each source
- [x] HelmRepository YAML file
- [x] Kustomization YAML files for each app
- [x] HelmRelease YAML with pinned version
- [x] Application manifests (deployments, services)
- [x] Documentation explaining intervals and dependencies
- [x] Explanation of application isolation strategy
- [x] Setup guide for deployment
- [x] Verification commands and expected outputs
- [x] Resource value rationale

---

**End of Deliverables Document**

