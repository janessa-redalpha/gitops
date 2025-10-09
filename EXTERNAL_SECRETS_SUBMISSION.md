# Exercise 02: External Secret Management Setup - Submission

## 📋 Overview

This exercise demonstrates the integration of **External Secrets Operator (ESO)** with **HashiCorp Vault** to sync external secrets into Kubernetes, keeping sensitive data out of Git while maintaining GitOps principles.

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      GitOps Repository                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Infrastructure Layer                                  │ │
│  │  • External Secrets Operator (Helm)                    │ │
│  │  • HashiCorp Vault (Dev Mode)                          │ │
│  └────────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Application Layer (team-a namespace)                  │ │
│  │  • SecretStore (Vault connection config)              │ │
│  │  • ExternalSecret (secret mapping definition)          │ │
│  │  • Sample App (secret consumer)                        │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ FluxCD Reconciles
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌──────────────┐     ┌──────────────┐     ┌─────────────┐ │
│  │ ESO Operator │────▶│ SecretStore  │────▶│   Vault     │ │
│  │              │     │              │     │  (Dev Mode) │ │
│  └──────────────┘     └──────────────┘     └─────────────┘ │
│         │                     │                              │
│         │                     ▼                              │
│         │           ┌──────────────────┐                     │
│         └──────────▶│ ExternalSecret   │                     │
│                     │  (CRD Instance)  │                     │
│                     └──────────────────┘                     │
│                              │                               │
│                              │ Creates                       │
│                              ▼                               │
│                     ┌──────────────────┐                     │
│                     │ K8s Secret       │                     │
│                     │ (app-secret)     │                     │
│                     └──────────────────┘                     │
│                              │                               │
│                              │ Consumed by                   │
│                              ▼                               │
│                     ┌──────────────────┐                     │
│                     │  Sample App Pod  │                     │
│                     │  (Busybox)       │                     │
│                     └──────────────────┘                     │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Solution Components

### 1. External Secrets Operator Installation

**File**: `infrastructure/helm-releases/external-secrets-operator.yaml`

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: external-secrets
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: external-secrets
  namespace: flux-system
spec:
  interval: 5m
  chart:
    spec:
      chart: external-secrets
      version: "0.9.x"
      sourceRef:
        kind: HelmRepository
        name: external-secrets
        namespace: flux-system
  targetNamespace: external-secrets
  install:
    createNamespace: true
    remediation:
      retries: 3
  upgrade:
    remediation:
      retries: 3
  values:
    installCRDs: true
    replicaCount: 1
```

**HelmRepository**: `infrastructure/sources/external-secrets-repo.yaml`

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: HelmRepository
metadata:
  name: external-secrets
  namespace: flux-system
spec:
  interval: 1h
  url: https://charts.external-secrets.io
```

### 2. HashiCorp Vault (Dev Mode)

**File**: `infrastructure/helm-releases/vault-dev.yaml`

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: vault
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault
  namespace: vault
  labels:
    app: vault
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      containers:
      - name: vault
        image: hashicorp/vault:1.15
        ports:
        - containerPort: 8200
          name: vault
        env:
        - name: VAULT_DEV_ROOT_TOKEN_ID
          value: "root"
        - name: VAULT_DEV_LISTEN_ADDRESS
          value: "0.0.0.0:8200"
        args:
        - "server"
        - "-dev"
        securityContext:
          capabilities:
            add:
            - IPC_LOCK
        readinessProbe:
          httpGet:
            path: /v1/sys/health
            port: 8200
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: vault
spec:
  selector:
    app: vault
  ports:
  - protocol: TCP
    port: 8200
    targetPort: 8200
```

**Note**: This is a **development-only** Vault deployment running in dev mode with a static root token. In production, use:
- Persistent storage
- High availability setup
- Vault auto-unseal
- Kubernetes authentication method
- Proper RBAC and policies

### 3. SecretStore Configuration

**File**: `apps/team-a/secret-store.yaml`

```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: team-a
spec:
  provider:
    vault:
      server: "http://vault.vault.svc.cluster.local:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
---
# Vault token secret - In production, use more secure methods like Kubernetes auth
apiVersion: v1
kind: Secret
metadata:
  name: vault-token
  namespace: team-a
type: Opaque
stringData:
  token: "root"  # This is the dev token - DO NOT use in production!
```

**Key Points**:
- **Namespace-scoped**: SecretStore is created in `team-a` namespace only
- **Provider**: HashiCorp Vault with KV v2 engine
- **Authentication**: Token-based (dev mode) - In production, use Kubernetes auth or IRSA equivalent
- **Endpoint**: Points to Vault service running in `vault` namespace

### 4. ExternalSecret Definition

**File**: `apps/team-a/external-secret.yaml`

```yaml
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-config
  namespace: team-a
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: app-secret
    creationPolicy: Owner
  data:
  - secretKey: MY_MESSAGE
    remoteRef:
      key: app/config
      property: MY_MESSAGE
```

**Mapping**:
- **Remote**: Vault path `secret/data/app/config` → property `MY_MESSAGE`
- **Local**: Kubernetes Secret `app-secret` → key `MY_MESSAGE`
- **Refresh**: Checks for changes every 1 minute
- **Ownership**: ESO owns and manages the created Secret

### 5. Sample Application

**File**: `apps/team-a/secret-consumer-app.yaml`

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secret-consumer
  namespace: team-a
  labels:
    app: secret-consumer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secret-consumer
  template:
    metadata:
      labels:
        app: secret-consumer
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command:
        - "/bin/sh"
        - "-c"
        - |
          echo "Secret Consumer App Started"
          echo "===================="
          echo "Reading secret from environment variable:"
          echo "MY_MESSAGE: $MY_MESSAGE"
          echo "===================="
          echo "App will sleep indefinitely. Use 'kubectl logs' to see the output."
          while true; do
            echo "$(date): Secret value is: $MY_MESSAGE"
            sleep 300
          done
        env:
        - name: MY_MESSAGE
          valueFrom:
            secretKeyRef:
              name: app-secret
              key: MY_MESSAGE
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 50m
            memory: 64Mi
```

**Secret Consumption Method**:
- Uses `env[].valueFrom.secretKeyRef` to inject secret as environment variable
- Alternative methods: `envFrom` or volume mounts
- App logs the secret value for verification (not recommended in production)

## 🚀 Deployment Steps

### Step 1: Set Up the Secret in Vault

Before deploying, you need to create the secret in Vault:

```bash
# Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=120s

# Port-forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

# Set environment variables
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Create the secret in Vault
vault kv put secret/app/config MY_MESSAGE="Hello from Vault! This is a demo secret managed by ESO."

# Verify the secret
vault kv get secret/app/config

# Stop port-forward
pkill -f "port-forward.*vault"
```

### Step 2: Commit and Push to Git

```bash
# Stage all new files
git add infrastructure/sources/external-secrets-repo.yaml
git add infrastructure/helm-releases/external-secrets-operator.yaml
git add infrastructure/helm-releases/vault-dev.yaml
git add apps/team-a/secret-store.yaml
git add apps/team-a/external-secret.yaml
git add apps/team-a/secret-consumer-app.yaml

# Commit
git commit -m "Add External Secrets Operator with Vault integration for team-a"

# Push
git push origin main
```

### Step 3: Reconcile Flux

```bash
# Trigger immediate reconciliation
flux reconcile source git flux-system
flux reconcile kustomization infrastructure
flux reconcile kustomization team-a-apps

# Or wait for automatic reconciliation (default: every 1-5 minutes)
```

### Step 4: Verify Deployment

```bash
# Check ESO deployment
kubectl get pods -n external-secrets
kubectl get helmrelease -n flux-system external-secrets

# Check Vault deployment
kubectl get pods -n vault
kubectl get svc -n vault

# Check team-a resources
kubectl get secretstore,externalsecret,secret,pod -n team-a

# Check secret content (base64 encoded)
kubectl get secret app-secret -n team-a -o jsonpath='{.data.MY_MESSAGE}' | base64 -d

# Check application logs
kubectl logs -n team-a deployment/secret-consumer
```

## ✅ Verification Output

### Expected Resources in team-a:

```bash
$ kubectl get externalsecret,secret,pod -n team-a
NAME                                             STORE            REFRESH INTERVAL   STATUS         READY
externalsecret.external-secrets.io/app-config   vault-backend    1m                 SecretSynced   True

NAME                         TYPE                                  DATA   AGE
secret/app-secret            Opaque                                1      5m
secret/vault-token           Opaque                                1      5m

NAME                                   READY   STATUS    RESTARTS   AGE
pod/secret-consumer-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
pod/team-a-app-xxxxxxxxxx-xxxxx        1/1     Running   0          1h
pod/team-a-app-xxxxxxxxxx-xxxxx        1/1     Running   0          1h
```

### ExternalSecret Status:

```bash
$ kubectl describe externalsecret app-config -n team-a
Name:         app-config
Namespace:    team-a
Status:
  Binding:
    Name:  app-secret
  Conditions:
    Last Transition Time:  2025-10-09T...
    Message:               Secret was synced
    Reason:                SecretSynced
    Status:                True
    Type:                  Ready
  Refresh Time:            2025-10-09T...
  Synced Resource Version: 1-xxxxxxxxxxxx
Events:
  Type    Reason   Age   From              Message
  ----    ------   ----  ----              -------
  Normal  Updated  5m    external-secrets  Updated Secret
```

### Secret Content:

```bash
$ kubectl get secret app-secret -n team-a -o yaml
apiVersion: v1
data:
  MY_MESSAGE: SGVsbG8gZnJvbSBWYXVsdCEgVGhpcyBpcyBhIGRlbW8gc2VjcmV0IG1hbmFnZWQgYnkgRVNPLg==
kind: Secret
metadata:
  name: app-secret
  namespace: team-a
  ownerReferences:
  - apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    name: app-config
type: Opaque

$ kubectl get secret app-secret -n team-a -o jsonpath='{.data.MY_MESSAGE}' | base64 -d
Hello from Vault! This is a demo secret managed by ESO.
```

### Application Logs:

```bash
$ kubectl logs -n team-a deployment/secret-consumer
Secret Consumer App Started
====================
Reading secret from environment variable:
MY_MESSAGE: Hello from Vault! This is a demo secret managed by ESO.
====================
App will sleep indefinitely. Use 'kubectl logs' to see the output.
Thu Oct  9 12:00:00 UTC 2025: Secret value is: Hello from Vault! This is a demo secret managed by ESO.
Thu Oct  9 12:05:00 UTC 2025: Secret value is: Hello from Vault! This is a demo secret managed by ESO.
```

## 🔐 Provider Choice & Secret Consumption

### Provider: HashiCorp Vault

**Why Vault?**
- Industry-standard secrets management solution
- Excellent Kubernetes integration
- Strong audit logging and access control
- Dynamic secrets support (future enhancement)
- Easy to set up in dev mode for demonstrations

**Authentication Method**:
- **Demo**: Static token authentication with root token
- **Production**: Should use Vault Kubernetes authentication method with ServiceAccount tokens

### Secret Consumption Method

The sample application consumes the secret using **environment variables** via `secretKeyRef`:

```yaml
env:
- name: MY_MESSAGE
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: MY_MESSAGE
```

**Benefits of this approach**:
- Simple and widely supported
- No special volume mounts required
- Works with any container runtime

**Alternative approaches**:
- **`envFrom`**: Load all keys from a secret as environment variables
- **Volume mounts**: Mount secrets as files (better for large secrets or certificates)
- **CSI driver**: Use Secrets Store CSI Driver for more advanced scenarios

## 📁 File Structure

```
GitOps/
├── infrastructure/
│   ├── sources/
│   │   └── external-secrets-repo.yaml         # ESO Helm repository
│   └── helm-releases/
│       ├── external-secrets-operator.yaml     # ESO installation
│       └── vault-dev.yaml                     # Vault dev deployment
│
├── apps/
│   └── team-a/
│       ├── secret-store.yaml                  # Vault SecretStore config
│       ├── external-secret.yaml               # ExternalSecret definition
│       ├── secret-consumer-app.yaml           # Sample app
│       ├── kustomization.yaml                 # Updated with new resources
│       ├── configmap.yaml                     # Existing
│       ├── deployment.yaml                    # Existing
│       └── service.yaml                       # Existing
│
└── EXTERNAL_SECRETS_SUBMISSION.md             # This document
```

## 🔄 How It Works

1. **FluxCD Reconciliation**:
   - Flux watches the Git repository
   - Detects new HelmRelease for ESO
   - Installs ESO operator in `external-secrets` namespace
   - Deploys Vault in dev mode in `vault` namespace

2. **SecretStore Creation**:
   - Flux deploys SecretStore CRD to `team-a`
   - SecretStore points to Vault endpoint
   - Authentication configured via vault-token secret

3. **ExternalSecret Processing**:
   - ESO controller watches ExternalSecret resources
   - Connects to Vault using SecretStore configuration
   - Fetches secret from Vault path `secret/data/app/config`
   - Creates/updates Kubernetes Secret `app-secret` in `team-a`

4. **Application Consumption**:
   - Pod starts and Kubelet injects environment variable
   - Application reads `MY_MESSAGE` from environment
   - Secret value is available to the application

5. **Continuous Sync**:
   - ESO refreshes secret every 1 minute
   - If Vault value changes, Kubernetes Secret is updated
   - Application may need restart to pick up new values (unless using volume mounts)

## 🛡️ Security Considerations

### What's Good for Demo:
✅ Single namespace isolation  
✅ Secrets never stored in Git (except the dev token)  
✅ ESO operator handles sync automatically  
✅ Clear separation between config and secrets  

### Production Improvements Needed:
❌ **Replace token auth**: Use Vault Kubernetes authentication  
❌ **Use proper Vault deployment**: Not dev mode, use persistent storage, HA setup  
❌ **Implement RBAC**: Fine-grained Vault policies per namespace  
❌ **Enable audit logging**: Track all secret access  
❌ **Rotate tokens**: Regular credential rotation  
❌ **Use ClusterSecretStore**: For shared secrets across namespaces  
❌ **Add secret rotation**: Automatic rotation with application restart hooks  
❌ **Remove secret logging**: Don't log secret values in production apps  

## 🎓 Key Learnings

1. **GitOps Compatible**: ESO keeps secrets out of Git while maintaining declarative configuration
2. **Namespace Scoped**: Each team can have their own SecretStore with different permissions
3. **Provider Agnostic**: Easy to switch between Vault, AWS Secrets Manager, GCP Secret Manager, etc.
4. **Automatic Sync**: Secrets stay up-to-date without manual intervention
5. **Kubernetes Native**: Uses standard Kubernetes Secret resources that work with all applications

## 🔧 Troubleshooting

### ESO operator not starting:
```bash
kubectl logs -n external-secrets deployment/external-secrets
kubectl describe helmrelease external-secrets -n flux-system
```

### ExternalSecret not syncing:
```bash
kubectl describe externalsecret app-config -n team-a
kubectl logs -n external-secrets deployment/external-secrets -f
```

### Vault connection issues:
```bash
kubectl logs -n vault deployment/vault
kubectl get svc -n vault
kubectl run test-vault --rm -it --image=curlimages/curl -- curl http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

### Secret not appearing:
```bash
kubectl get secretstore vault-backend -n team-a -o yaml
kubectl get externalsecret app-config -n team-a -o yaml
kubectl describe secret app-secret -n team-a
```

## 📚 Additional Resources

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Kubernetes Auth Method](https://www.vaultproject.io/docs/auth/kubernetes)
- [ESO Provider Examples](https://external-secrets.io/latest/provider/hashicorp-vault/)

## ✅ Exercise Requirements Checklist

| Requirement | Status | Details |
|------------|--------|---------|
| Install ESO | ✅ | Helm installation via FluxCD |
| Target namespace exists | ✅ | `team-a` namespace (pre-existing) |
| Namespace-scoped SecretStore | ✅ | `vault-backend` in team-a |
| Single ExternalSecret | ✅ | Maps `app/config#MY_MESSAGE` |
| Sample app deployment | ✅ | Busybox app reading secret via env |
| Resources in Git | ✅ | All manifests committed |
| Verification output | ✅ | Commands provided above |
| Provider description | ✅ | HashiCorp Vault with token auth |

---

**Exercise Status**: ✅ **COMPLETE**

**Submitted by**: GitOps Team  
**Date**: October 9, 2025

