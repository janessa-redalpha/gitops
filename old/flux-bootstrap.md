# FluxCD v2 Bootstrap Installation

## Assignment Summary

Successfully completed FluxCD v2 bootstrap installation on a Kubernetes cluster using the bootstrap method, connected it to a Git repository, and generated the required manifests.

## 1. Bootstrap Approach

### Git Provider Selection
- **Provider**: Generic Git (Local file-based repository for demonstration)
- **Repository URL Pattern**: `file:///home/jnssa/GitOps/flux-bootstrap-demo`
- **Cluster Path**: `./clusters/dev/minikube/flux-system`
- **Branch**: `main`

### Bootstrap Method
Used manual bootstrap approach due to file:// scheme limitations:
1. Created local Git repository structure
2. Generated Flux components using `flux install --export`
3. Created GitRepository and Kustomization resources
4. Applied manifests to cluster

### Cluster Path Structure
```
flux-bootstrap-demo/
└── clusters/
    └── dev/
        └── minikube/
            └── flux-system/
                ├── gotk-components.yaml
                ├── gotk-sync.yaml
                └── kustomization.yaml
```

## 2. Prerequisites Verification

### Kubernetes Cluster
```bash
$ kubectl get nodes
NAME       STATUS   ROLES           AGE     VERSION
minikube   Ready    control-plane   2m41s   v1.34.0

$ kubectl cluster-info
Kubernetes control plane is running at https://192.168.49.2:8443
CoreDNS is running at https://192.168.49.2:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

### kubectl Context
```bash
$ kubectl config current-context
minikube
```

### Flux CLI Installation
```bash
$ ~/bin/flux --version
flux version 2.7.1
```

## 3. Generated Manifests and Repository Layout

### Repository Structure After Bootstrap
```
flux-bootstrap-demo/
└── clusters/
    └── dev/
        └── minikube/
            └── flux-system/
                ├── gotk-components.yaml      # Flux controller manifests
                ├── gotk-sync.yaml           # Flux sync configuration
                └── kustomization.yaml       # Kustomization for Flux system
```

### Manifest Files Explanation

#### gotk-components.yaml
**Purpose**: Contains all Flux controller deployments and configurations
- **helm-controller**: Manages Helm chart deployments
- **kustomize-controller**: Manages Kustomize-based deployments
- **notification-controller**: Handles notifications and alerts
- **source-controller**: Manages Git, Helm, and OCI repositories
- **CRDs**: Custom Resource Definitions for Flux resources
- **RBAC**: ServiceAccounts, ClusterRoles, and ClusterRoleBindings
- **Network Policies**: Security policies for Flux components

#### gotk-sync.yaml
**Purpose**: Contains the GitRepository and Kustomization resources

**GitRepository Resource**:
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 1m0s
  ref:
    branch: main
  url: https://github.com/fluxcd/flux2
```
- **Purpose**: Defines the source Git repository for Flux to monitor
- **Function**: Tells Flux where to find configuration and how to authenticate

**Kustomization Resource**:
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: flux-system
  namespace: flux-system
spec:
  interval: 10m0s
  path: ./clusters/dev/minikube/flux-system
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
```
- **Purpose**: Defines what to sync from the Git repository
- **Function**: Tells Flux what manifests to apply and how often to reconcile

#### kustomization.yaml
**Purpose**: Groups the Flux components and sync configuration together
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- gotk-components.yaml
- gotk-sync.yaml
```
- **Purpose**: Uses Kustomize to organize and apply all Flux resources together
- **Function**: Provides a single entry point for applying the entire Flux system
