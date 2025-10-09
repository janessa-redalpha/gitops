# External Secrets Operator - Quick Start Guide

## 🚀 Quick Setup

### Prerequisites
- Kubernetes cluster running (Minikube/Kind/etc.)
- FluxCD installed and syncing
- `kubectl` configured
- `vault` CLI (optional but recommended)

### 1. Deploy All Resources

```bash
# Commit and push all files to Git
git add -A
git commit -m "Add External Secrets Operator setup"
git push origin main

# Reconcile Flux immediately
flux reconcile source git flux-system
flux reconcile kustomization infrastructure
flux reconcile kustomization team-a-apps
```

### 2. Wait for Infrastructure

```bash
# Wait for ESO to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets -n external-secrets --timeout=120s

# Wait for Vault to be ready
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=120s
```

### 3. Initialize Vault Secret

```bash
# Run the setup script
chmod +x scripts/setup-vault-secret.sh
./scripts/setup-vault-secret.sh
```

Or manually:

```bash
# Port-forward to Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

# Set environment
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Create secret
vault kv put secret/app/config MY_MESSAGE="Hello from Vault!"

# Stop port-forward
pkill -f "port-forward.*vault"
```

### 4. Verify Everything

```bash
# Check all resources in team-a
kubectl get externalsecret,secret,pod -n team-a

# Check ExternalSecret status
kubectl describe externalsecret app-config -n team-a

# View secret value
kubectl get secret app-secret -n team-a -o jsonpath='{.data.MY_MESSAGE}' | base64 -d

# Check app logs
kubectl logs -n team-a deployment/secret-consumer --tail=20
```

## 📊 Expected Output

### Resources
```
$ kubectl get externalsecret,secret,pod -n team-a
NAME                                             STORE            REFRESH INTERVAL   STATUS         READY
externalsecret.external-secrets.io/app-config   vault-backend    1m                 SecretSynced   True

NAME                         TYPE                                  DATA   AGE
secret/app-secret            Opaque                                1      5m
secret/vault-token           Opaque                                1      5m

NAME                                   READY   STATUS    RESTARTS   AGE
pod/secret-consumer-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
```

### Application Output
```
$ kubectl logs -n team-a deployment/secret-consumer
Secret Consumer App Started
====================
Reading secret from environment variable:
MY_MESSAGE: Hello from Vault!
====================
App will sleep indefinitely. Use 'kubectl logs' to see the output.
Thu Oct  9 12:00:00 UTC 2025: Secret value is: Hello from Vault!
```

## 🔄 Testing Secret Updates

### Update Secret in Vault

```bash
# Port-forward
kubectl port-forward -n vault svc/vault 8200:8200 &
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Update the secret
vault kv put secret/app/config MY_MESSAGE="Updated secret value!"

# Wait up to 1 minute for ESO to sync
sleep 60

# Verify update
kubectl get secret app-secret -n team-a -o jsonpath='{.data.MY_MESSAGE}' | base64 -d

# Restart pod to see new value
kubectl rollout restart deployment secret-consumer -n team-a

# Check logs
kubectl logs -n team-a deployment/secret-consumer --tail=5
```

## 🔧 Common Commands

### Check ESO Status
```bash
kubectl get pods -n external-secrets
kubectl logs -n external-secrets deployment/external-secrets -f
```

### Check Vault Status
```bash
kubectl get pods -n vault
kubectl logs -n vault deployment/vault
```

### Debug ExternalSecret
```bash
kubectl describe externalsecret app-config -n team-a
kubectl get secretstore vault-backend -n team-a -o yaml
kubectl get externalsecret app-config -n team-a -o yaml
```

### Manual Vault Access
```bash
# Port-forward
kubectl port-forward -n vault svc/vault 8200:8200

# In another terminal
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# List secrets
vault kv list secret/

# Get secret
vault kv get secret/app/config

# Put secret
vault kv put secret/app/config MY_MESSAGE="New value"

# Delete secret
vault kv delete secret/app/config
```

## 🧹 Cleanup

To remove External Secrets setup:

```bash
# Remove from kustomization
git checkout HEAD -- apps/team-a/kustomization.yaml

# Remove files
git rm apps/team-a/secret-store.yaml
git rm apps/team-a/external-secret.yaml
git rm apps/team-a/secret-consumer-app.yaml
git rm infrastructure/sources/external-secrets-repo.yaml
git rm infrastructure/helm-releases/external-secrets-operator.yaml
git rm infrastructure/helm-releases/vault-dev.yaml

# Commit and push
git commit -m "Remove External Secrets setup"
git push origin main

# Reconcile Flux
flux reconcile kustomization team-a-apps
flux reconcile kustomization infrastructure

# Delete namespaces
kubectl delete namespace external-secrets
kubectl delete namespace vault
```

## 📚 More Information

See `EXTERNAL_SECRETS_SUBMISSION.md` for:
- Complete architecture diagram
- Detailed explanations
- Security considerations
- Production recommendations
- Full YAML manifests
- Troubleshooting guide

## 🆘 Troubleshooting

### ExternalSecret shows "SecretSyncedError"
- Check SecretStore configuration: `kubectl describe secretstore vault-backend -n team-a`
- Verify Vault token: `kubectl get secret vault-token -n team-a -o yaml`
- Check Vault connectivity: `kubectl run test --rm -it --image=curlimages/curl -- curl http://vault.vault.svc.cluster.local:8200/v1/sys/health`

### Secret not appearing
- Check ExternalSecret events: `kubectl describe externalsecret app-config -n team-a`
- Check ESO logs: `kubectl logs -n external-secrets deployment/external-secrets`
- Verify secret exists in Vault (see "Manual Vault Access" above)

### App pod not starting
- Check secret exists: `kubectl get secret app-secret -n team-a`
- Check pod events: `kubectl describe pod -l app=secret-consumer -n team-a`
- Check pod logs: `kubectl logs -l app=secret-consumer -n team-a`

---

**Quick Setup Time**: ~5-10 minutes (depending on image pulls)

