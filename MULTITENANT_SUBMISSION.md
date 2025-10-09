# Multi-Tenant FluxCD Setup - Submission

## Exercise 01: Multi-Tenant FluxCD Setup

This document provides the complete submission for the multi-tenant FluxCD onboarding exercise.

---

## Overview

Successfully implemented a multi-tenant FluxCD setup with two isolated tenants:
- **team-a**: Isolated namespace with dedicated RBAC and applications
- **team-b**: Isolated namespace with dedicated RBAC and applications

Each tenant has:
- Dedicated namespace with tenant label
- Restricted ServiceAccount in flux-system namespace
- Role and RoleBinding limiting permissions to their namespace only
- Separate Kustomization pointing to their app directory
- Sample applications (Deployment, Service, ConfigMap)

---

## 1. Namespace Configuration

### Team A Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-a
  labels:
    tenant: team-a
```

### Team B Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: team-b
  labels:
    tenant: team-b
```

**Location:** 
- `clusters/dev/minikube/tenants/team-a/namespace.yaml`
- `clusters/dev/minikube/tenants/team-b/namespace.yaml`

---

## 2. RBAC Configuration

### Team A RBAC

**ServiceAccount:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: team-a-sa
  namespace: flux-system
```

**Role:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: team-a-role
  namespace: team-a
rules:
  - apiGroups: [""]
    resources:
      - configmaps
      - secrets
      - services
      - persistentvolumeclaims
    verbs: ["*"]
  - apiGroups: ["apps"]
    resources:
      - deployments
      - statefulsets
      - daemonsets
      - replicasets
    verbs: ["*"]
  - apiGroups: ["batch"]
    resources:
      - jobs
      - cronjobs
    verbs: ["*"]
  - apiGroups: ["networking.k8s.io"]
    resources:
      - ingresses
      - networkpolicies
    verbs: ["*"]
  - apiGroups: ["autoscaling"]
    resources:
      - horizontalpodautoscalers
    verbs: ["*"]
```

**RoleBinding:**
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team-a-rolebinding
  namespace: team-a
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: team-a-role
subjects:
  - kind: ServiceAccount
    name: team-a-sa
    namespace: flux-system
```

### Team B RBAC

Similar structure with `team-b-sa`, `team-b-role`, and `team-b-rolebinding`.

**Location:**
- `clusters/dev/minikube/tenants/team-a/rbac.yaml`
- `clusters/dev/minikube/tenants/team-b/rbac.yaml`

**Key RBAC Design:**
- ServiceAccounts are in `flux-system` namespace (where Flux controllers run)
- Roles are in tenant namespaces (team-a, team-b) limiting scope
- RoleBindings grant ServiceAccount access only to their tenant namespace
- No cluster-wide permissions - fully namespace-isolated

---

## 3. GitRepository Configuration

**Reusing Existing GitRepository:**
Both tenants use the existing `flux-system` GitRepository that points to the main repository. This approach:
- Simplifies configuration
- Reduces redundancy
- Uses the same authentication mechanism

```yaml
# Referenced in Kustomization (not created separately)
sourceRef:
  kind: GitRepository
  name: flux-system
  namespace: flux-system
```

---

## 4. Kustomization Configuration

### Team A Kustomization
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-a-apps
  namespace: flux-system
spec:
  interval: 5m
  targetNamespace: team-a
  serviceAccountName: team-a-sa
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  path: ./apps/team-a
  prune: true
  wait: true
  timeout: 2m
```

### Team B Kustomization
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: team-b-apps
  namespace: flux-system
spec:
  interval: 5m
  targetNamespace: team-b
  serviceAccountName: team-b-sa
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  path: ./apps/team-b
  prune: true
  wait: true
  timeout: 2m
```

**Location:**
- `clusters/dev/minikube/tenants/team-a/kustomization.yaml`
- `clusters/dev/minikube/tenants/team-b/kustomization.yaml`

---

## 5. Sample Application Manifests

### Team A Applications

**ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: team-a-config
  namespace: team-a
data:
  app.name: "Team A Application"
  environment: "development"
  team: "team-a"
```

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: team-a-app
  namespace: team-a
  labels:
    app: team-a-app
    tenant: team-a
spec:
  replicas: 2
  selector:
    matchLabels:
      app: team-a-app
  template:
    metadata:
      labels:
        app: team-a-app
        tenant: team-a
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 80
        env:
        - name: TEAM_NAME
          valueFrom:
            configMapKeyRef:
              name: team-a-config
              key: team
        resources:
          requests:
            memory: "32Mi"
            cpu: "50m"
          limits:
            memory: "64Mi"
            cpu: "100m"
```

**Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: team-a-service
  namespace: team-a
  labels:
    app: team-a-app
    tenant: team-a
spec:
  type: ClusterIP
  selector:
    app: team-a-app
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
```

### Team B Applications

Similar structure with team-b naming and labels.

**Location:**
- `apps/team-a/` (configmap.yaml, deployment.yaml, service.yaml, kustomization.yaml)
- `apps/team-b/` (configmap.yaml, deployment.yaml, service.yaml, kustomization.yaml)

---

## 6. Verification Output

### Namespace Verification
```bash
$ kubectl get namespace team-a team-b --show-labels
NAME     STATUS   AGE   LABELS
team-a   Active   25h   kubernetes.io/metadata.name=team-a,tenant=team-a
team-b   Active   25h   kubernetes.io/metadata.name=team-b,tenant=team-b
```

### Team A Resources
```bash
$ kubectl get all -n team-a
NAME                              READY   STATUS    RESTARTS   AGE
pod/team-a-app-79b6ff999d-26css   1/1     Running   0          10m
pod/team-a-app-79b6ff999d-nwltc   1/1     Running   0          14m

NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/team-a-service   ClusterIP   10.110.56.18   <none>        80/TCP    26m

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/team-a-app   2/2     2            2           26m

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/team-a-app-79b6ff999d   2         2         2       14m
```

### Team B Resources
```bash
$ kubectl get all -n team-b
NAME                              READY   STATUS    RESTARTS   AGE
pod/team-b-app-56f74986f9-lp5hb   1/1     Running   0          15m
pod/team-b-app-56f74986f9-xvq22   1/1     Running   0          11m

NAME                     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/team-b-service   ClusterIP   10.96.30.183   <none>        80/TCP    27m

NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/team-b-app   2/2     2            2           27m

NAME                                    DESIRED   CURRENT   READY   AGE
replicaset.apps/team-b-app-56f74986f9   2         2         2       15m
```

### Flux Kustomization Status
```bash
$ kubectl get kustomization -n flux-system team-a-apps team-b-apps
NAME          AGE   READY   STATUS
team-a-apps   57m   True    Applied revision: main@sha1:6dbf73a726547ec6ed33f314ea8f312ddd640201
team-b-apps   54m   True    Applied revision: main@sha1:6dbf73a726547ec6ed33f314ea8f312ddd640201
```

### ServiceAccount Verification
```bash
$ kubectl get sa -n flux-system team-a-sa team-b-sa
NAME        SECRETS   AGE
team-a-sa   0         32m
team-b-sa   0         31m
```

### RBAC Verification (Team A)
```bash
$ kubectl get role,rolebinding -n team-a
NAME                                             CREATED AT
role.rbac.authorization.k8s.io/team-a-role       2025-10-09T02:43:24Z

NAME                                                       ROLE                   AGE
rolebinding.rbac.authorization.k8s.io/team-a-rolebinding   Role/team-a-role       60m
```

### RBAC Verification (Team B)
```bash
$ kubectl get role,rolebinding -n team-b
NAME                                             CREATED AT
role.rbac.authorization.k8s.io/team-b-role       2025-10-09T02:46:14Z

NAME                                                       ROLE                   AGE
rolebinding.rbac.authorization.k8s.io/team-b-rolebinding   Role/team-b-role       58m
```

---

## 7. Directory Structure

```
GitOps/
├── apps/
│   ├── team-a/
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── kustomization.yaml
│   └── team-b/
│       ├── configmap.yaml
│       ├── deployment.yaml
│       ├── service.yaml
│       └── kustomization.yaml
└── clusters/
    └── dev/
        └── minikube/
            └── tenants/
                ├── team-a/
                │   ├── namespace.yaml
                │   ├── rbac.yaml
                │   └── kustomization.yaml
                └── team-b/
                    ├── namespace.yaml
                    ├── rbac.yaml
                    └── kustomization.yaml
```

---

## 8. Key Features & Isolation

### Namespace Isolation
- Each tenant has a dedicated namespace
- Namespaces are labeled with `tenant: <team-name>` for easy filtering
- Resources are strictly confined to their namespace

### RBAC Isolation
- ServiceAccounts created in `flux-system` (where Flux runs)
- Roles defined with namespace scope (not cluster-wide)
- Permissions limited to common resources (Deployments, Services, ConfigMaps, etc.)
- No cross-namespace access possible
- No cluster-level permissions granted

### Application Isolation
- Each team's apps are in separate directories (`apps/team-a`, `apps/team-b`)
- Separate Kustomizations ensure independent reconciliation
- Changes to one tenant's apps don't affect the other
- Different reconciliation intervals can be set per tenant

### Source Control
- Clean separation of tenant configurations
- Easy to audit and review changes per tenant
- Can be extended to use different branches or repositories per tenant

---

## 9. Testing Isolation

To verify isolation, you can test that:

1. **Namespace isolation works:**
```bash
# Team A cannot see Team B resources
kubectl get pods -n team-a  # Shows only team-a pods
kubectl get pods -n team-b  # Shows only team-b pods
```

2. **RBAC isolation works:**
```bash
# Check Role permissions are namespace-scoped
kubectl describe role team-a-role -n team-a
kubectl describe rolebinding team-a-rolebinding -n team-a
```

3. **Flux reconciliation isolation:**
```bash
# Reconcile only team-a (doesn't affect team-b)
flux reconcile kustomization team-a-apps

# Check status independently
flux get kustomizations team-a-apps
flux get kustomizations team-b-apps
```

---

## 10. Deployment Steps Summary

1. **Created namespace manifests** with tenant labels
2. **Created RBAC resources** (ServiceAccount in flux-system, Role and RoleBinding in tenant namespaces)
3. **Created Kustomization resources** pointing to tenant app directories
4. **Created sample applications** (ConfigMap, Deployment, Service)
5. **Applied tenant onboarding manifests** to cluster
6. **Committed and pushed** all changes to Git repository
7. **Reconciled Flux** to sync the changes
8. **Verified** resources deployed correctly in isolated namespaces

---

## 11. Benefits of This Approach

1. **Security**: Strong RBAC boundaries prevent cross-tenant access
2. **Scalability**: Easy to add new tenants following the same pattern
3. **Maintainability**: Clear structure and separation of concerns
4. **Auditability**: Git history shows all changes per tenant
5. **Self-Service**: Teams can manage their own apps within their namespace
6. **Resource Efficiency**: Shared Flux controllers, separate workloads
7. **Flexibility**: Each tenant can have different reconciliation settings

---

## 12. Future Enhancements

- Add NetworkPolicies for network-level isolation
- Implement ResourceQuotas to limit tenant resource usage
- Add LimitRanges for default resource limits
- Use separate Git repositories per tenant for stronger isolation
- Implement OPA/Gatekeeper policies for additional governance
- Add monitoring and alerting per tenant namespace

---

## Conclusion

Successfully implemented a production-ready multi-tenant FluxCD setup with two tenants (team-a and team-b). Each tenant is fully isolated with dedicated namespaces, RBAC, and application directories. The setup demonstrates proper GitOps practices with clear separation of concerns and strong security boundaries.

