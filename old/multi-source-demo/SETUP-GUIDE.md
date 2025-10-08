# Multi-Source GitOps Setup Guide

## Exercise 03: Multiple Source Configuration Setup - Complete Guide

This guide walks you through setting up a production-ready multi-source FluxCD configuration.

## Overview

This setup demonstrates:
- ✅ Multiple Git repositories (3 separate repos)
- ✅ Multiple Helm repositories (Bitnami)
- ✅ Independent reconciliation per application
- ✅ Dependency management (backend → Redis)
- ✅ Team ownership and isolation

## Prerequisites

- Kubernetes cluster (Minikube, kind, or production cluster)
- FluxCD CLI installed (`flux --version`)
- GitHub account or GitLab account
- kubectl configured

## Step 1: Create GitHub Repositories

You need to create three repositories:

### Option A: Using GitHub CLI
```bash
gh auth login
gh repo create YOUR-USERNAME/gitops-main --public
gh repo create YOUR-USERNAME/frontend-app --public
gh repo create YOUR-USERNAME/backend-api --public
```

### Option B: Using GitHub Web UI
1. Go to https://github.com/new
2. Create these three repositories:
   - `gitops-main`
   - `frontend-app`
   - `backend-api`
3. Keep them public for this demo (or configure SSH keys for private)

## Step 2: Update Repository URLs

Replace `YOUR-ORG` with your GitHub username in these files:

### In `gitops-main/clusters/production/sources/frontend-repo.yaml`:
```yaml
url: https://github.com/YOUR-USERNAME/frontend-app.git
```

### In `gitops-main/clusters/production/sources/backend-repo.yaml`:
```yaml
url: https://github.com/YOUR-USERNAME/backend-api.git
```

### In `gitops-main/clusters/production/flux-system/gotk-sync.yaml`:
```yaml
url: https://github.com/YOUR-USERNAME/gitops-main.git
```

## Step 3: Push Repositories

```bash
cd multi-source-demo

# Frontend App
cd frontend-app
git add .
git commit -m "Initial commit: Frontend application manifests"
git remote add origin https://github.com/YOUR-USERNAME/frontend-app.git
git push -u origin main

# Backend API
cd ../backend-api
git add .
git commit -m "Initial commit: Backend API manifests"
git remote add origin https://github.com/YOUR-USERNAME/backend-api.git
git push -u origin main

# GitOps Main (generate gotk-components.yaml first!)
cd ../gitops-main
flux install --export > clusters/production/flux-system/gotk-components.yaml
git add .
git commit -m "Initial commit: GitOps configuration"
git remote add origin https://github.com/YOUR-USERNAME/gitops-main.git
git push -u origin main
```

## Step 4: Bootstrap Flux

### For Public Repositories (Easier)
```bash
flux bootstrap github \
  --owner=YOUR-USERNAME \
  --repository=gitops-main \
  --branch=main \
  --path=clusters/production/flux-system \
  --personal
```

### For Private Repositories
```bash
# Generate a GitHub Personal Access Token with repo permissions
# Go to: https://github.com/settings/tokens/new

export GITHUB_TOKEN=your-personal-access-token

flux bootstrap github \
  --owner=YOUR-USERNAME \
  --repository=gitops-main \
  --branch=main \
  --path=clusters/production/flux-system \
  --personal \
  --token-auth
```

## Step 5: Verify Deployment

Wait 2-3 minutes for everything to reconcile, then check:

```bash
# Check all sources
flux get sources all -A

# Expected output:
# NAMESPACE     NAME                       REVISION         READY
# flux-system   gitrepository/flux-system  main@sha1:...   True
# flux-system   gitrepository/frontend-repo main@sha1:...  True
# flux-system   gitrepository/backend-repo main@sha1:...   True
# flux-system   helmrepository/bitnami     sha256:...      True

# Check Kustomizations
flux get kustomizations -A

# Expected output:
# NAMESPACE     NAME                   READY
# flux-system   flux-system           True
# flux-system   frontend-app          True
# flux-system   backend-app           True
# flux-system   infrastructure-redis  True

# Check HelmReleases
flux get helmreleases -A

# Expected output:
# NAMESPACE   NAME   REVISION  READY
# apps        redis  19.6.4    True

# Check application pods
kubectl -n apps get pods

# Expected output:
# NAME                        READY   STATUS
# frontend-xxxxxx-xxx         1/1     Running
# frontend-xxxxxx-xxx         1/1     Running
# backend-xxxxxx-xxx          1/1     Running
# backend-xxxxxx-xxx          1/1     Running
# backend-xxxxxx-xxx          1/1     Running
# redis-master-0              1/1     Running
```

## Step 6: Test Application Updates

### Update Frontend
```bash
cd frontend-app
# Edit deployment.yaml, change replicas from 2 to 3
sed -i 's/replicas: 2/replicas: 3/' deployment.yaml
git add deployment.yaml
git commit -m "Scale frontend to 3 replicas"
git push

# Watch Flux reconcile
flux reconcile kustomization frontend-app --with-source
kubectl -n apps get pods -l app=frontend -w
```

### Update Backend
```bash
cd ../backend-api
# Edit deployment.yaml, update the message
sed -i 's/Backend API v1.0/Backend API v2.0/' deployment.yaml
git add deployment.yaml
git commit -m "Update backend API message to v2.0"
git push

# Watch Flux reconcile
flux reconcile kustomization backend-app --with-source
kubectl -n apps get pods -l app=backend -w
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                   flux-system namespace               │  │
│  │                                                        │  │
│  │  GitRepository: flux-system                           │  │
│  │    └─> https://github.com/YOU/gitops-main            │  │
│  │                                                        │  │
│  │  GitRepository: frontend-repo                         │  │
│  │    └─> https://github.com/YOU/frontend-app           │  │
│  │                                                        │  │
│  │  GitRepository: backend-repo                          │  │
│  │    └─> https://github.com/YOU/backend-api            │  │
│  │                                                        │  │
│  │  HelmRepository: bitnami                              │  │
│  │    └─> https://charts.bitnami.com/bitnami            │  │
│  │                                                        │  │
│  │  Kustomizations:                                      │  │
│  │    ├─ frontend-app → frontend-repo                    │  │
│  │    ├─ backend-app → backend-repo (depends on Redis)   │  │
│  │    └─ infrastructure-redis → flux-system              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                    apps namespace                     │  │
│  │                                                        │  │
│  │  Deployments:                                         │  │
│  │    ├─ frontend (2 replicas) - nginx                  │  │
│  │    ├─ backend (3 replicas) - http-echo               │  │
│  │    └─ redis (1 replica) - from Helm chart            │  │
│  │                                                        │  │
│  │  Services:                                            │  │
│  │    ├─ frontend:80                                     │  │
│  │    ├─ backend:8080                                    │  │
│  │    └─ redis-master:6379                               │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Sources Not Ready

```bash
# Check specific source
flux get sources git frontend-repo -n flux-system

# Check logs
flux logs --kind=GitRepository --name=frontend-repo
```

### Kustomization Failing

```bash
# Check specific Kustomization
flux get kustomizations frontend-app -n flux-system

# Check events
kubectl -n flux-system describe kustomization frontend-app

# Force reconciliation
flux reconcile kustomization frontend-app --with-source
```

### Authentication Issues (Private Repos)

```bash
# Create SSH key
ssh-keygen -t ed25519 -C "flux-frontend" -f ./frontend-deploy-key

# Add public key to GitHub repo deploy keys
# Settings → Deploy keys → Add deploy key

# Create Flux secret
flux create secret git frontend-git-auth \
  --url=ssh://git@github.com/YOUR-USERNAME/frontend-app \
  --private-key-file=./frontend-deploy-key

# Update source to use secret (uncomment secretRef in YAML)
```

## Cleanup

```bash
# Uninstall Flux
flux uninstall --namespace=flux-system --silent

# Delete application resources
kubectl delete namespace apps

# Delete GitHub repositories (if needed)
gh repo delete YOUR-USERNAME/gitops-main --yes
gh repo delete YOUR-USERNAME/frontend-app --yes
gh repo delete YOUR-USERNAME/backend-api --yes
```

## Benefits of This Setup

1. **Team Autonomy**: Each team owns their repository and can update independently
2. **Clear Boundaries**: Frontend and backend are completely isolated
3. **Dependency Management**: Backend waits for infrastructure to be ready
4. **Different Reconciliation**: Teams can choose their own update frequency
5. **Security**: Each repo can have different access controls
6. **Scalability**: Easy to add more apps/teams by adding new repos

## Next Steps

- Add more applications by creating new repositories
- Implement RBAC for team-specific access
- Add Kustomize overlays for multiple environments (dev/staging/prod)
- Set up notifications via Slack/Discord
- Implement image automation for automatic deployments
- Add PodDisruptionBudgets and NetworkPolicies

