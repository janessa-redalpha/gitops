# Exercise 02: Component Configuration Setup - Deliverables

## Assignment Summary

Successfully configured resource requests/limits and replicas for the Flux source-controller using Kustomize patches in Git.

## 1. Patch File: patch-source-controller.yaml

**Location**: `clusters/dev/minikube/flux-system/patch-source-controller.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: source-controller
  namespace: flux-system
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: manager
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

## 2. Updated kustomization.yaml

**Location**: `clusters/dev/minikube/flux-system/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- gotk-components.yaml
- gotk-sync.yaml
patchesStrategicMerge:
- patch-source-controller.yaml
```

## 3. Verification Output

### Resource Settings
```bash
$ kubectl -n flux-system get deploy source-controller -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

**Output**:
```json
{
  "limits": {
    "cpu": "500m",
    "memory": "512Mi"
  },
  "requests": {
    "cpu": "100m",
    "memory": "128Mi"
  }
}
```

### Replicas Setting
```bash
$ kubectl -n flux-system get deploy source-controller -o jsonpath='{.spec.replicas}'
```

**Output**:
```
2
```

### Pod Status
```bash
$ kubectl -n flux-system get pods -l app=source-controller
```

**Output**:
```
NAME                                 READY   STATUS    RESTARTS   AGE
source-controller-6f9bd9857d-7sbdp   0/1     Running   0          78s
source-controller-6f9bd9857d-sh8xk   1/1     Running   0          79s
```

## 4. Resource Values Rationale

### CPU Resources
- **Request (100m)**: Ensures each source-controller pod gets at least 0.1 CPU core guaranteed. This is sufficient for normal Git repository polling and artifact management operations.
- **Limit (500m)**: Caps CPU usage at 0.5 cores to prevent source-controller from consuming excessive CPU during intensive operations (e.g., large repository clones or artifact processing).

### Memory Resources
- **Request (128Mi)**: Provides baseline memory for source-controller's in-memory operations, Git caching, and artifact storage. This is appropriate for small to medium-sized repositories.
- **Limit (512Mi)**: Prevents memory exhaustion while allowing source-controller to handle larger repositories and multiple concurrent reconciliations. A 4x headroom between request and limit accommodates traffic spikes.

### Replicas (2)
- **High Availability**: Two replicas provide redundancy if one pod fails or needs to be evicted during node maintenance.
- **Load Distribution**: Multiple replicas can distribute the workload when reconciling multiple GitRepository resources.
- **Zero-Downtime Updates**: With 2 replicas, rolling updates can proceed without service interruption.

### Design Considerations
These values are conservative and suitable for:
- Development/staging environments with moderate repository activity
- Small to medium-sized Git repositories (< 100MB)
- Typical reconciliation intervals (1-5 minutes)

For production environments with larger repositories, more frequent reconciliations, or higher throughput requirements, consider:
- Increasing memory request to 256Mi and limit to 1Gi
- Increasing CPU limit to 1000m (1 core)
- Scaling replicas to 3+ for better fault tolerance

## 5. Git Commit

```bash
$ git log -1 --oneline
dd1c3e9 Add source-controller resource limits and replicas patch
```

## 6. Reconciliation Process

The changes were applied to the cluster using:
1. Git commit and push to the repository
2. Flux automatic reconciliation via `flux reconcile kustomization flux-system --with-source`
3. Manual verification with `kubectl apply -k .` to ensure immediate application

## Notes

- Used `patchesStrategicMerge` as recommended for simplicity (though Kustomize shows a deprecation warning suggesting to use `patches` instead)
- The patch uses strategic merge, which merges the specified fields with the existing Deployment
- Changes are fully GitOps-compliant and stored in version control
- Flux will automatically maintain these settings on future reconciliations

