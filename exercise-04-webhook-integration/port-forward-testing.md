# Port-Forward Testing Instructions

This document provides instructions for testing webhooks locally using port-forwarding.

## Setup Port-Forward

1. Forward the notification-controller service to your local machine:

```bash
kubectl -n flux-system port-forward svc/notification-controller 9292:80
```

Keep this running in a separate terminal.

## Get Receiver URLs

2. Check the receiver status to get the webhook path:

```bash
# For dev environment
kubectl -n flux-system get receiver gitops-receiver-dev -o jsonpath='{.status.webhookPath}'

# For staging environment
kubectl -n flux-system get receiver gitops-receiver-staging -o jsonpath='{.status.webhookPath}'

# For prod environment
kubectl -n flux-system get receiver gitops-receiver-prod -o jsonpath='{.status.webhookPath}'
```

The output will be something like: `/hook/12345abcdef`

## Test Webhook Locally

3. Test the webhook with curl:

```bash
# Get the webhook token
TOKEN=$(kubectl -n flux-system get secret webhook-token -o jsonpath='{.data.token}' | base64 -d)

# Get the webhook path (replace with your receiver name)
WEBHOOK_PATH=$(kubectl -n flux-system get receiver gitops-receiver-dev -o jsonpath='{.status.webhookPath}')

# Send a test ping event
curl -X POST http://localhost:9292${WEBHOOK_PATH} \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: ping" \
  -H "X-Hub-Signature-256: sha256=$(echo -n '{"zen":"Testing"}' | openssl dgst -sha256 -hmac "$TOKEN" | cut -d' ' -f2)" \
  -d '{"zen":"Testing"}'
```

## Monitor Events

4. Watch for reconciliation events:

```bash
# Watch Flux events
flux events -A --watch

# Watch notification-controller logs
kubectl -n flux-system logs deploy/notification-controller -f

# Check GitRepository status
kubectl -n flux-system get gitrepository -w
```

## Verify Immediate Reconciliation

5. Make a change to your repository and push it:

```bash
# In your git repository
echo "# Test webhook" >> test-webhook.txt
git add test-webhook.txt
git commit -m "Test webhook trigger"
git push
```

6. Observe that Flux reconciles immediately instead of waiting for the polling interval.

## Expected Results

- You should see webhook delivery in the notification-controller logs
- GitRepository should reconcile within seconds instead of waiting for the interval
- `flux events` should show reconciliation triggered by webhook

## Troubleshooting

If webhooks aren't working:

1. Check receiver status:
```bash
kubectl -n flux-system get receiver -o wide
```

2. Verify the secret exists:
```bash
kubectl -n flux-system get secret webhook-token
```

3. Check notification-controller logs for errors:
```bash
kubectl -n flux-system logs deploy/notification-controller --tail=50
```

4. Ensure the GitRepository resource exists:
```bash
kubectl -n flux-system get gitrepository
```

