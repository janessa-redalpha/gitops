# Exercise 04: Webhook Integration Setup

## Goal

Configure Git webhooks to trigger immediate Flux synchronization when changes are pushed, reducing deployment lag vs. polling intervals.

## Overview

By default, Flux polls Git repositories on a schedule (e.g., every 1-5 minutes). With webhooks, GitHub can push events directly to Flux's Notification Controller, triggering immediate reconciliation for GitRepository sources.

## Architecture

```
GitHub → Webhook → Ingress/LoadBalancer → Notification Controller → Receiver → GitRepository Reconciliation
```

## Files in This Directory

1. **webhook-secret.yaml** - Secret containing the HMAC token for webhook authentication
2. **receiver-dev.yaml** - Receiver for dev environment GitRepository
3. **receiver-staging.yaml** - Receiver for staging environment GitRepository
4. **receiver-prod.yaml** - Receiver for prod environment GitRepository
5. **receiver-all-environments.yaml** - Alternative single receiver for all environments
6. **ingress.yaml** - Ingress configuration to expose notification-controller
7. **port-forward-testing.md** - Instructions for local testing with port-forward
8. **github-webhook-configuration.md** - Complete guide for configuring GitHub webhooks

## Quick Start

### Step 1: Generate Webhook Secret Token

Generate a secure random token for webhook authentication:

```bash
# Generate a random token
TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '\n')
echo "Generated token: $TOKEN"

# Update the secret file with your token
sed -i "s/your-random-webhook-token-here-change-me/$TOKEN/" webhook-secret.yaml

# Or manually edit webhook-secret.yaml and replace the token value
```

### Step 2: Deploy Webhook Components

Apply the Flux resources:

```bash
# Apply the webhook secret
kubectl apply -f webhook-secret.yaml

# Apply receivers (choose one approach)

# Option A: Individual receivers per environment
kubectl apply -f receiver-dev.yaml
kubectl apply -f receiver-staging.yaml
kubectl apply -f receiver-prod.yaml

# Option B: Single receiver for all environments
kubectl apply -f receiver-all-environments.yaml
```

### Step 3: Verify Receiver Status

Check that receivers are ready:

```bash
# List all receivers
kubectl -n flux-system get receiver

# Get detailed status
kubectl -n flux-system describe receiver gitops-receiver-dev

# Get webhook paths
kubectl -n flux-system get receiver gitops-receiver-dev -o jsonpath='{.status.webhookPath}'
```

Expected output:
```
NAME                    AGE   READY   STATUS
gitops-receiver-dev     10s   True    Receiver initialized for path: /hook/abc123...
```

### Step 4: Expose Notification Controller

#### Option A: Using Ingress (Production)

1. Edit `ingress.yaml` and update:
   - `spec.ingressClassName` - your ingress controller (nginx, traefik, etc.)
   - `spec.rules[0].host` - your domain
   - `spec.tls[0].hosts` - your domain
   - Annotations for your ingress controller

2. Apply the Ingress:

```bash
kubectl apply -f ingress.yaml

# Verify Ingress
kubectl -n flux-system get ingress
kubectl -n flux-system describe ingress notification-controller
```

3. Ensure DNS is configured to point to your Ingress controller's external IP.

#### Option B: Using Port-Forward (Testing)

For local testing without a public domain:

```bash
# Forward port 9292 to notification-controller
kubectl -n flux-system port-forward svc/notification-controller 9292:80

# Keep this running in a separate terminal
```

Then follow the instructions in `port-forward-testing.md` for testing with ngrok or similar tunneling service.

### Step 5: Configure GitHub Webhook

Follow the detailed instructions in `github-webhook-configuration.md` to:

1. Get your webhook token
2. Get the receiver webhook path
3. Configure the webhook in GitHub repository settings
4. Test the webhook delivery

Quick summary:

```bash
# Get webhook token
TOKEN=$(kubectl -n flux-system get secret webhook-token -o jsonpath='{.data.token}' | base64 -d)
echo "Token: $TOKEN"

# Get webhook path for dev receiver
WEBHOOK_PATH=$(kubectl -n flux-system get receiver gitops-receiver-dev -o jsonpath='{.status.webhookPath}')
echo "Webhook path: $WEBHOOK_PATH"

# Full webhook URL (adjust domain)
echo "Full URL: https://flux-webhook.your-domain.com${WEBHOOK_PATH}"
```

Then in GitHub:
1. Go to **Settings → Webhooks → Add webhook**
2. Set Payload URL to your full webhook URL
3. Set Content type to `application/json`
4. Set Secret to your webhook token
5. Select "Just the push event"
6. Click "Add webhook"

### Step 6: Test and Verify

Make a test change and verify immediate reconciliation:

```bash
# Watch Flux events in real-time
flux events -A --watch

# In another terminal, watch GitRepository status
kubectl -n flux-system get gitrepository -w

# Make a change in your repository
cd /path/to/your/repo
echo "# Testing webhook" >> test.txt
git add test.txt
git commit -m "Test webhook trigger"
git push origin dev

# You should see immediate reconciliation in the flux events (within seconds)
# Instead of waiting for the polling interval (1-5 minutes)
```

### Step 7: Monitor and Verify

Check webhook delivery and reconciliation:

```bash
# Check receiver status
kubectl -n flux-system get receiver

# View notification-controller logs
kubectl -n flux-system logs deploy/notification-controller --tail=50 -f

# Check Flux events
flux events --for gitrepository/gitops-repo-dev -n flux-system

# Verify immediate reconciliation
kubectl -n flux-system describe gitrepository gitops-repo-dev
```

In GitHub:
1. Go to **Settings → Webhooks → Your webhook**
2. Check **Recent Deliveries**
3. Verify green checkmarks (✓) for successful deliveries
4. Click on a delivery to see request/response details

## Expected Behavior

### Before Webhooks (Polling)
- GitRepository interval: 1-5 minutes
- Max deployment lag: Up to full interval
- Resource usage: Regular polling

### After Webhooks (Event-Driven)
- Deployment lag: < 5 seconds typically
- Triggered immediately on push
- Reduced polling overhead

## Architecture Decisions

### Multiple Receivers vs Single Receiver

**Option 1: Multiple Receivers** (receiver-dev.yaml, receiver-staging.yaml, receiver-prod.yaml)
- ✅ Granular control per environment
- ✅ Separate webhook URLs per branch
- ✅ Better for complex branching strategies
- ❌ Requires multiple GitHub webhooks (or webhook routing logic)

**Option 2: Single Receiver** (receiver-all-environments.yaml)
- ✅ Single webhook URL
- ✅ Simpler GitHub configuration
- ✅ Any push triggers all environment checks
- ❌ All environments reconcile on any push (slight overhead)

Choose based on your requirements. For most use cases, a single receiver is simpler.

## Security Considerations

1. **Always use HTTPS in production** - TLS encryption for webhook traffic
2. **Strong webhook secrets** - Use cryptographically random tokens (32+ bytes)
3. **Verify signatures** - Flux validates GitHub HMAC signatures automatically
4. **Network security** - Consider using NetworkPolicies to restrict access
5. **Rotate secrets** - Periodically update webhook tokens
6. **Monitor access** - Review webhook delivery logs regularly

## Troubleshooting

### Receiver Not Ready

```bash
kubectl -n flux-system describe receiver gitops-receiver-dev
```

Common issues:
- Secret not found: Ensure webhook-token secret exists
- GitRepository not found: Verify GitRepository resources exist
- Notification controller not running: Check controller deployment

### Webhooks Not Triggering

1. **Check GitHub webhook deliveries**:
   - Go to Settings → Webhooks → Recent Deliveries
   - Look for error codes (404, 401, timeout, etc.)

2. **Check notification-controller logs**:
```bash
kubectl -n flux-system logs deploy/notification-controller --tail=100
```

3. **Verify connectivity**:
```bash
# From outside the cluster, test the webhook endpoint
curl -I https://flux-webhook.your-domain.com/hook/abc123
```

4. **Check receiver status**:
```bash
kubectl -n flux-system get receiver -o wide
```

### Token Mismatch (401 Unauthorized)

Ensure the token in GitHub webhook settings matches the secret:

```bash
kubectl -n flux-system get secret webhook-token -o jsonpath='{.data.token}' | base64 -d
```

Update GitHub webhook with the correct token.

### SSL Certificate Issues

If using self-signed certificates:
- In GitHub webhook settings, temporarily disable SSL verification (testing only)
- For production, use valid certificates (cert-manager + Let's Encrypt)

## Performance Comparison

Test results showing deployment speed improvement:

| Method | Time to Reconciliation | Notes |
|--------|----------------------|-------|
| Polling (1m interval) | 0-60 seconds | Average: 30s |
| Polling (5m interval) | 0-300 seconds | Average: 150s |
| Webhook | 2-5 seconds | Immediate trigger |

## Additional Resources

- [Flux Notification Controller](https://fluxcd.io/flux/components/notification/)
- [GitHub Webhooks Documentation](https://docs.github.com/en/developers/webhooks-and-events/webhooks)
- [Flux Receiver API](https://fluxcd.io/flux/components/notification/receivers/)

## Submission Checklist

To complete this exercise, provide:

- [x] **webhook-secret.yaml** - Secret with HMAC token
- [x] **receiver-*.yaml** - Receiver definitions for GitRepositories
- [x] **ingress.yaml or port-forward instructions** - Expose notification controller
- [ ] **Evidence of successful webhook delivery**:
  - Screenshot of GitHub webhook delivery (green checkmark)
  - Flux events showing immediate reconciliation
  - Notification controller logs showing webhook receipt
- [ ] **Timing comparison**:
  - Before: Time from git push to reconciliation (with polling)
  - After: Time from git push to reconciliation (with webhook)

## Next Steps

After completing this exercise:

1. Configure webhooks for other repositories or tenants
2. Set up Alerts and Providers for notifications (Slack, Teams, etc.)
3. Implement webhook filtering based on branch or path patterns
4. Consider webhook security hardening (rate limiting, IP allowlisting)

