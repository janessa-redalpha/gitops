# Team-A Applications

## 📦 Deployed Applications

### 1. Team-A Main Application (Nginx)
- **Deployment**: `deployment.yaml`
- **Service**: `service.yaml`
- **ConfigMap**: `configmap.yaml`
- **Status**: ✅ Active (from previous exercise)

### 2. Secret Consumer Application
- **Deployment**: `secret-consumer-app.yaml`
- **Purpose**: Demonstrates External Secrets Operator integration
- **Secret Source**: HashiCorp Vault via ESO
- **Status**: ✅ NEW (Exercise 02)

## 🔐 External Secrets Configuration

### SecretStore
- **File**: `secret-store.yaml`
- **Type**: Namespace-scoped
- **Provider**: HashiCorp Vault (KV v2)
- **Auth Method**: Token (dev mode)

### ExternalSecret
- **File**: `external-secret.yaml`
- **Name**: `app-config`
- **Target Secret**: `app-secret`
- **Synced Key**: `MY_MESSAGE` from Vault path `secret/app/config`

## 🚀 Quick Commands

### View All Resources
```bash
kubectl get all,externalsecret,secretstore,secret -n team-a
```

### Check Secret Consumer
```bash
# View logs
kubectl logs -n team-a deployment/secret-consumer --tail=20

# Check secret value
kubectl get secret app-secret -n team-a -o jsonpath='{.data.MY_MESSAGE}' | base64 -d
```

### Check ExternalSecret Status
```bash
kubectl describe externalsecret app-config -n team-a
```

## 📚 Related Documentation

- **Exercise Submission**: `../../EXTERNAL_SECRETS_SUBMISSION.md`
- **Quick Start Guide**: `../../EXTERNAL_SECRETS_QUICKSTART.md`
- **Summary**: `../../EXERCISE_02_SUMMARY.md`
- **Setup Script**: `../../scripts/setup-vault-secret.sh`

## 🏗️ Resource Ownership

All resources in this namespace are managed by:
- **FluxCD Kustomization**: `team-a-apps`
- **ServiceAccount**: `team-a-sa`
- **Git Path**: `./apps/team-a`
- **Reconciliation**: Automatic via Flux

## 🔄 How to Update

1. Edit files in this directory
2. Commit and push to Git
3. Flux will automatically reconcile (or run `flux reconcile kustomization team-a-apps`)

For secrets, update in Vault - ESO will sync automatically within 1 minute.

