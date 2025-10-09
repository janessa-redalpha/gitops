# Exercise 03: Canary Deployment - Summary

## 📋 Submission Deliverables

### Required Files

1. **Canary YAML**: `clusters/dev/minikube/apps/canary/podinfo/canary.yaml`
2. **Deployment YAML**: `clusters/dev/minikube/apps/canary/podinfo/deployment.yaml`
3. **Service YAML**: `clusters/dev/minikube/apps/canary/podinfo/service.yaml`
4. **Ingress YAML**: `clusters/dev/minikube/apps/canary/podinfo/ingress.yaml`

### Verification Command Output

```bash
kubectl -n test get svc | grep podinfo
```

**Expected Output:**
```
NAME                TYPE        CLUSTER-IP       PORT(S)             AGE
podinfo             ClusterIP   10.96.50.123     80/TCP,9797/TCP     5m
podinfo-canary      ClusterIP   10.96.100.45     80/TCP,9797/TCP     5m
podinfo-primary     ClusterIP   10.96.200.78     80/TCP,9797/TCP     5m
```

### Traffic Shifting Explanation (2-3 sentences)

> Flagger orchestrates progressive canary deployments by automatically creating primary and canary services, then gradually shifting traffic from primary to canary in 10% increments (from 0% to 50% maxWeight) every 30 seconds. At each step, Flagger monitors two key metrics: request-success-rate (minimum 99%) and request-duration (P99 maximum 500ms). If metrics pass for 5 consecutive checks, the canary is promoted to primary; if any check fails, traffic is immediately rolled back to the stable version, ensuring zero-downtime deployments with automatic safety guarantees.

## 🎯 Key Configuration

### Canary Resource Highlights

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
spec:
  provider: nginx                    # NGINX Ingress for traffic shifting
  targetRef:
    name: podinfo                    # Target Deployment
  service:
    port: 80
    targetPort: 9898
  analysis:
    interval: 30s                    # Check metrics every 30s
    threshold: 5                     # Allow 5 failures before rollback
    maxWeight: 50                    # Max 50% traffic to canary
    stepWeight: 10                   # Increase by 10% each step
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99                    # Min 99% success rate
      - name: request-duration
        thresholdRange:
          max: 500                   # Max 500ms P99 latency
    webhooks:
      - name: acceptance-test        # Pre-rollout validation
        type: pre-rollout
      - name: load-test              # Generate traffic during rollout
        type: rollout
```

### Traffic Progression

| Step | Time | Primary | Canary | Check |
|------|------|---------|--------|-------|
| 0 | T+0s | 100% | 0% | Deploy new version |
| 1 | T+30s | 90% | 10% | Pre-rollout test + metrics |
| 2 | T+60s | 80% | 20% | Metrics check |
| 3 | T+90s | 70% | 30% | Metrics check |
| 4 | T+120s | 60% | 40% | Metrics check |
| 5 | T+150s | 50% | 50% | Metrics check (maxWeight) |
| 6 | T+180s | 0% | 100% | Promote canary → primary |

**Total Duration**: ~3 minutes for successful rollout

## 📁 Files Created

```
infrastructure/
├── sources/
│   ├── nginx-ingress-repo.yaml       # NGINX Ingress Helm repo
│   └── flagger-repo.yaml             # Flagger Helm repo
└── helm-releases/
    ├── nginx-ingress.yaml            # NGINX Ingress Controller
    ├── flagger.yaml                  # Flagger operator
    └── flagger-loadtester.yaml       # Load testing tool

clusters/dev/minikube/apps/canary/podinfo/
├── namespace.yaml                    # test namespace
├── deployment.yaml                   # podinfo app (v6.5.3)
├── service.yaml                      # ClusterIP service
├── ingress.yaml                      # NGINX Ingress route
├── canary.yaml                       # Flagger Canary CRD
└── kustomization.yaml                # Kustomize config
```

## 🚀 Quick Deploy

```bash
# Commit and push
git add -A
git commit -m "Add Exercise 03: Canary Deployment"
git push origin main

# Deploy infrastructure
flux reconcile source git flux-system
flux reconcile kustomization infrastructure-redis

# Wait for ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=180s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=flagger -n flagger-system --timeout=180s

# Deploy app
flux reconcile kustomization canary-podinfo

# Verify
kubectl get canary,svc,deploy -n test
```

## 🎬 Trigger Canary

```bash
# Update image version in deployment.yaml
sed -i 's/podinfo:6.5.3/podinfo:6.5.4/g' clusters/dev/minikube/apps/canary/podinfo/deployment.yaml

# Commit and push
git add clusters/dev/minikube/apps/canary/podinfo/deployment.yaml
git commit -m "Trigger canary: update to v6.5.4"
git push origin main

# Reconcile
flux reconcile kustomization canary-podinfo

# Watch rollout
kubectl get canary podinfo -n test -w
```

## 📊 Monitoring

```bash
# Watch canary status
watch kubectl get canary podinfo -n test

# View events
kubectl describe canary podinfo -n test

# Check services
kubectl get svc -n test | grep podinfo

# Follow Flagger logs
kubectl logs -n flagger-system deploy/flagger -f
```

## ✅ Success Indicators

- Canary status: `Succeeded`
- Weight: `0` (canary promoted)
- Primary deployment updated to new version
- Canary deployment scaled to 0

## ❌ Rollback Indicators

- Canary status: `Failed`
- Events show metric failures
- Traffic returned to 100% primary
- Old version still running

## 📚 Documentation

- **Complete Submission**: `EXERCISE_03_CANARY_SUBMISSION.md`
- **This Summary**: `EXERCISE_03_SUMMARY.md`

---

**Status**: ✅ Ready for submission (pending cluster DNS resolution for infrastructure deployment)


