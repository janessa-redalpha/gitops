# GitHub Webhook Configuration

This guide shows how to configure GitHub webhooks to trigger immediate Flux reconciliation.

## Prerequisites

- Receivers deployed in your cluster
- Notification controller accessible via Ingress or public URL
- Webhook secret token generated

## Get Required Information

1. Get the webhook token:

```bash
kubectl -n flux-system get secret webhook-token -o jsonpath='{.data.token}' | base64 -d
```

Save this token for use in GitHub.

2. Get the receiver webhook path:

```bash
# For dev environment
kubectl -n flux-system get receiver gitops-receiver-dev -o jsonpath='{.status.webhookPath}'

# Output example: /hook/1234567890abcdef
```

3. Determine your webhook URL:
   - If using Ingress: `https://flux-webhook.your-domain.com/hook/1234567890abcdef`
   - If using port-forward (for testing): `http://your-public-ip:9292/hook/1234567890abcdef`
   - If using ngrok/tunnel: `https://your-ngrok-url.ngrok.io/hook/1234567890abcdef`

## Configure GitHub Webhook

### Step 1: Navigate to Repository Settings

1. Go to your GitHub repository: `https://github.com/janessa-redalpha/gitops`
2. Click on **Settings** tab
3. In the left sidebar, click **Webhooks**
4. Click **Add webhook** button

### Step 2: Configure Webhook Settings

Fill in the webhook form:

- **Payload URL**: Enter your full webhook URL
  ```
  https://flux-webhook.your-domain.com/hook/1234567890abcdef
  ```

- **Content type**: Select `application/json`

- **Secret**: Paste the webhook token you retrieved earlier

- **SSL verification**: 
  - Select "Enable SSL verification" if using valid TLS certificate
  - Select "Disable SSL verification" only for testing (not recommended for production)

- **Which events would you like to trigger this webhook?**
  - Select "Just the push event" (this is what Flux receivers listen for)
  - Alternatively, select "Let me select individual events" and choose:
    - ✓ Pushes
    - ✓ Ping (optional, for testing)

- **Active**: Check this box

### Step 3: Save Webhook

Click **Add webhook** to save the configuration.

### Step 4: Test the Webhook

1. GitHub will automatically send a ping event. Check the webhook delivery:
   - Click on your newly created webhook
   - Scroll down to **Recent Deliveries**
   - Click on the ping event
   - You should see a green checkmark (✓) indicating success

2. Make a test commit and push:

```bash
cd /path/to/your/repo
echo "# Testing webhook" >> README.md
git add README.md
git commit -m "Test webhook integration"
git push origin dev  # or your target branch
```

3. Verify in your cluster:

```bash
# Watch for immediate reconciliation
flux events -A --for gitrepository/gitops-repo-dev

# Check notification controller logs
kubectl -n flux-system logs deploy/notification-controller --tail=20
```

## Multiple Environment Setup

For branch-based environments (dev, staging, prod), create separate receivers:

1. **Dev Environment** (branch: `dev`):
   - Receiver: `gitops-receiver-dev`
   - Webhook URL: `https://flux-webhook.your-domain.com/hook/<dev-path>`

2. **Staging Environment** (branch: `staging`):
   - Receiver: `gitops-receiver-staging`
   - Webhook URL: `https://flux-webhook.your-domain.com/hook/<staging-path>`

3. **Production Environment** (branch: `prod`):
   - Receiver: `gitops-receiver-prod`
   - Webhook URL: `https://flux-webhook.your-domain.com/hook/<prod-path>`

You'll need to create separate webhooks in GitHub for each receiver, or use a single receiver that triggers all GitRepository resources.

## Alternative: Single Receiver for All Environments

You can also create a single receiver that triggers multiple GitRepositories:

```yaml
apiVersion: notification.toolkit.fluxcd.io/v1
kind: Receiver
metadata:
  name: gitops-receiver-all
  namespace: flux-system
spec:
  type: github
  events:
    - "ping"
    - "push"
  secretRef:
    name: webhook-token
  resources:
    - apiVersion: source.toolkit.fluxcd.io/v1
      kind: GitRepository
      name: gitops-repo-dev
    - apiVersion: source.toolkit.fluxcd.io/v1
      kind: GitRepository
      name: gitops-repo-staging
    - apiVersion: source.toolkit.fluxcd.io/v1
      kind: GitRepository
      name: gitops-repo-prod
```

This way, any push to any branch will trigger reconciliation for all environments.

## Verification

### Check Webhook Deliveries in GitHub

1. Go to Settings → Webhooks → Your webhook
2. Click on Recent Deliveries
3. Verify status codes (200 = success)
4. Check request/response details

### Check Flux Events

```bash
# Watch all events
flux events -A --watch

# Check specific GitRepository
kubectl -n flux-system describe gitrepository gitops-repo-dev
```

### Monitor Reconciliation Time

Compare reconciliation times:

**Before webhooks** (polling):
- Interval: 1m-5m
- Max delay: Up to full interval

**After webhooks** (event-driven):
- Delay: < 5 seconds typically
- Triggered immediately on push

## Troubleshooting

### Webhook Shows Error in GitHub

Check these common issues:

1. **Connection timeout**: Ensure your Ingress/service is accessible from the internet
2. **401 Unauthorized**: Token mismatch - verify secret matches
3. **404 Not Found**: Check receiver webhook path is correct
4. **SSL certificate error**: Use valid TLS certificate or disable verification for testing

### No Reconciliation Triggered

```bash
# Check receiver status
kubectl -n flux-system get receiver

# Check notification-controller logs
kubectl -n flux-system logs deploy/notification-controller

# Verify GitRepository exists
kubectl -n flux-system get gitrepository
```

## Security Best Practices

1. **Always use HTTPS** in production with valid TLS certificates
2. **Use strong webhook secrets** (at least 32 random characters)
3. **Limit receiver to specific GitRepository resources** (principle of least privilege)
4. **Enable SSL verification** in GitHub webhook settings
5. **Monitor webhook deliveries** regularly for suspicious activity
6. **Rotate webhook secrets** periodically

## Testing with ngrok (Development Only)

If you don't have a public domain, you can use ngrok for testing:

```bash
# Port-forward notification-controller
kubectl -n flux-system port-forward svc/notification-controller 9292:80 &

# Start ngrok
ngrok http 9292

# Use the ngrok URL in GitHub webhook settings
# Example: https://abc123.ngrok.io/hook/1234567890abcdef
```

**Note**: ngrok URLs change on restart. This is for testing only, not production use.

