# Exercise 04: A/B Testing with Session Affinity - Submission

## Overview

This submission demonstrates A/B testing with Flagger using NGINX Ingress with session affinity (sticky sessions). The configuration routes only selected users (by header/cookie) to the canary while maintaining session persistence.

## Directory Structure

```
clusters/dev/minikube/apps/ab/podinfo/
├── namespace.yaml          # Test namespace
├── deployment.yaml         # Podinfo deployment
├── service.yaml           # Podinfo service
├── ingress.yaml           # Ingress with session affinity
├── canary.yaml            # Flagger Canary with A/B testing
└── kustomization.yaml     # Kustomization manifest
```

## 1. Ingress Manifest with Session Affinity Annotations

**File: `clusters/dev/minikube/apps/ab/podinfo/ingress.yaml`**

Key session affinity annotations:
- `nginx.ingress.kubernetes.io/affinity: "cookie"` - Enable cookie-based affinity
- `nginx.ingress.kubernetes.io/session-cookie-name: "abtest"` - Cookie name
- `nginx.ingress.kubernetes.io/session-cookie-hash: "sha1"` - Hash algorithm
- `nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"` - Cookie expiry (1 hour)
- `nginx.ingress.kubernetes.io/session-cookie-path: "/"` - Cookie path

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: podinfo
  namespace: test
  labels:
    app: podinfo
  annotations:
    kubernetes.io/ingress.class: nginx
    # Enable cookie-based session affinity for sticky sessions
    nginx.ingress.kubernetes.io/affinity: "cookie"
    nginx.ingress.kubernetes.io/session-cookie-name: "abtest"
    nginx.ingress.kubernetes.io/session-cookie-hash: "sha1"
    # Optional: configure cookie expiry and path
    nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"
    nginx.ingress.kubernetes.io/session-cookie-path: "/"
spec:
  rules:
  - host: app.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: podinfo
            port:
              number: 80
```

## 2. Flagger Canary YAML with A/B Testing

**File: `clusters/dev/minikube/apps/ab/podinfo/canary.yaml`**

Key A/B testing configuration:
- `provider: nginx` - Required for NGINX Ingress integration
- `analysis.match` - Defines traffic matching rules for A/B testing
  - Header match: `X-Canary: insider` (exact match)
  - Cookie match: `canary=always` (regex pattern)

```yaml
---
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: podinfo
  namespace: test
spec:
  # Provider must be nginx for A/B testing with NGINX Ingress
  provider: nginx
  # Deployment reference
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: podinfo
  progressDeadlineSeconds: 60
  # Reference to the ingress for A/B testing
  ingressRef:
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    name: podinfo
  service:
    port: 80
    targetPort: 9898
  analysis:
    interval: 30s
    threshold: 5
    iterations: 10
    # A/B testing match conditions
    # Traffic matching these conditions will be routed to canary
    # Weight settings are ignored during A/B testing
    match:
      # Match requests with X-Canary header set to "insider"
      - headers:
          x-canary:
            exact: "insider"
      # Match requests with cookie containing canary=always
      - headers:
          cookie:
            regex: "^(.*?;)?(canary=always)(;.*)?$"
    # Metrics for canary analysis
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
      interval: 1m
    - name: request-duration
      thresholdRange:
        max: 500
      interval: 30s
```

## 3. Verification Commands

### Check Ingress Annotations

```bash
kubectl describe ingress podinfo -n test
```

**Output showing session affinity annotations:**

```
Annotations:       kubernetes.io/ingress.class: nginx
                   nginx.ingress.kubernetes.io/affinity: cookie
                   nginx.ingress.kubernetes.io/session-cookie-hash: sha1
                   nginx.ingress.kubernetes.io/session-cookie-max-age: 3600
                   nginx.ingress.kubernetes.io/session-cookie-name: abtest
                   nginx.ingress.kubernetes.io/session-cookie-path: /
```

### Check Canary A/B Testing Configuration

```bash
kubectl get canary podinfo -n test -o jsonpath='{.spec.analysis.match}' | jq .
```

**Output showing A/B match conditions:**

```json
[
  {
    "headers": {
      "x-canary": {
        "exact": "insider"
      }
    }
  },
  {
    "headers": {
      "cookie": {
        "regex": "^(.*?;)?(canary=always)(;.*)?$"
      }
    }
  }
]
```

### Check Canary Status

```bash
kubectl get canary podinfo -n test
```

**Output:**

```
NAME      STATUS         WEIGHT   LASTTRANSITIONTIME
podinfo   Initializing   0        2025-10-09T08:35:32Z
```

### Check Services Created by Flagger

```bash
kubectl get svc -n test
```

**Output showing primary, canary, and main services:**

```
NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)           AGE
podinfo               ClusterIP   10.98.99.173     <none>        80/TCP,9797/TCP   58m
podinfo-canary        ClusterIP   10.99.211.28     <none>        80/TCP            58m
podinfo-primary       ClusterIP   10.102.242.164   <none>        80/TCP            58m
```

## 4. Testing Procedure

### Test 1: Unmatched Request (Should hit Primary)

```bash
# Request without header or cookie - routes to primary
curl -v -H "Host: app.example.com" http://<ingress-address>/

# Expect: Response from podinfo-primary pods
# The Set-Cookie header will include the abtest session cookie
```

**Expected behavior:**
- Request routed to `podinfo-primary` service
- Response from a primary pod (e.g., `podinfo-primary-xxxxxxx`)
- `Set-Cookie` header with `abtest` cookie for session persistence

### Test 2: Matched Request with Header (Should hit Canary)

```bash
# Request with X-Canary: insider header - routes to canary
curl -v -H "Host: app.example.com" -H "X-Canary: insider" http://<ingress-address>/

# Expect: Response from podinfo-canary pods
```

**Expected behavior:**
- Request routed to `podinfo-canary` service
- Response from a canary pod (e.g., `podinfo-xxxxxxx`)
- Session cookie ensures subsequent requests go to the same backend

### Test 3: Matched Request with Cookie (Should hit Canary with Sticky Session)

```bash
# Request with canary=always cookie - routes to canary
curl -v -b 'canary=always' -H 'Host: app.example.com' http://<ingress-address>/

# Repeat multiple times to verify sticky sessions
for i in {1..5}; do
  curl -s -b 'canary=always' -H 'Host: app.example.com' http://<ingress-address>/ | grep hostname
done

# Expect: All responses from the SAME canary pod due to session affinity
```

**Expected behavior:**
- Request routed to `podinfo-canary` service
- Session cookie ensures all requests hit the same backend pod
- The `hostname` field in the response should be consistent across all requests

### Test 4: Verify Session Cookie Persistence

```bash
# Make initial request without cookie, capture the session cookie
curl -v -c cookies.txt -H "Host: app.example.com" http://<ingress-address>/

# Make subsequent requests with the saved cookie
curl -v -b cookies.txt -H "Host: app.example.com" http://<ingress-address>/

# Expect: Both requests hit the same backend pod
```

## 5. How A/B Testing Works

1. **Traffic Splitting by Match Conditions:**
   - Flagger configures NGINX Ingress to route traffic based on `analysis.match` rules
   - Requests with `X-Canary: insider` header → routed to canary
   - Requests with `canary=always` cookie → routed to canary
   - All other requests → routed to primary

2. **Session Affinity (Sticky Sessions):**
   - NGINX Ingress annotations enable cookie-based session affinity
   - Once a user hits a backend (primary or canary), the `abtest` cookie is set
   - Subsequent requests with this cookie are routed to the same backend pod
   - This ensures a consistent experience during the A/B test

3. **Weight Ignored in A/B Testing:**
   - Unlike progressive canary deployments, `stepWeight` and `maxWeight` are ignored
   - Traffic routing is purely based on match conditions
   - This allows for precise control over which users see which version

## 6. Key Configuration Points

### NGINX Ingress Annotations for Session Affinity

These annotations work independently of Flagger and apply to all traffic:

```yaml
nginx.ingress.kubernetes.io/affinity: "cookie"
nginx.ingress.kubernetes.io/session-cookie-name: "abtest"
nginx.ingress.kubernetes.io/session-cookie-hash: "sha1"
nginx.ingress.kubernetes.io/session-cookie-max-age: "3600"
nginx.ingress.kubernetes.io/session-cookie-path: "/"
```

### Flagger Canary Match Conditions

These define which traffic goes to the canary:

```yaml
analysis:
  match:
    - headers:
        x-canary:
          exact: "insider"
    - headers:
        cookie:
          regex: "^(.*?;)?(canary=always)(;.*)?$"
```

## 7. Deployment Steps

1. **Commit and push changes:**
   ```bash
   git add clusters/dev/minikube/apps/ab/
   git add clusters/dev/minikube/apps/ab-podinfo-kustomization.yaml
   git add clusters/dev/minikube/apps/kustomization.yaml
   git commit -m "Add A/B testing setup with session affinity"
   git push
   ```

2. **Reconcile Flux:**
   ```bash
   flux reconcile kustomization flux-system --with-source
   ```

3. **Monitor deployment:**
   ```bash
   kubectl get canary -n test -w
   ```

## 8. Troubleshooting

### Issue: NGINX Ingress Admission Webhook Error

If you see: `failed calling webhook "validate.nginx.ingress.kubernetes.io"`

**Solution:**
```bash
# Remove the webhook if NGINX controller is not running
kubectl delete validatingwebhookconfiguration ingress-nginx-ingress-nginx-admission
```

### Issue: Pods in Pending State

Check resource constraints:
```bash
kubectl describe pod <pod-name> -n test
```

Adjust resource requests in `deployment.yaml` if needed.

### Issue: Canary Stuck in Initializing

Check Flagger controller logs:
```bash
kubectl logs -n flagger-system deploy/flagger -f
```

## Summary

This implementation demonstrates:
✅ NGINX Ingress with cookie-based session affinity annotations
✅ Flagger Canary with A/B testing match conditions (header + cookie)
✅ Proper provider configuration (`provider: nginx`)
✅ Cookie regex pattern for flexible matching
✅ Session persistence across matched requests
✅ GitOps workflow with Flux for deployment

The configuration ensures that:
- Users without the header/cookie hit the primary version
- Users with the header/cookie hit the canary version
- All users maintain session affinity to their assigned backend
- The A/B test can be controlled by selectively setting headers/cookies

