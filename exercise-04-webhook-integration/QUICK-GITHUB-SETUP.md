# Quick GitHub Webhook Setup (No Domain Required!)

## Your Webhook Information

**Webhook Token:** `AhkhAD0H2oQdYRXU3qJnBynWOk7hH9sX1Tcsq0jHhEo`

**Webhook Paths:**
- Dev: `/hook/f6ccf0cba14dea90063998dcf8f3fff41bfd1ebb51bb49f7ceaa396d75225a9e`
- Staging: `/hook/1da5231aa2c00a9725c1331407f4fd94b744de0073765b1a438f552024c2df44`
- Production: `/hook/926effdf37d687d3571ed701e190c583f59901c7c0a0ee2313865da342779c2c`

---

## Step-by-Step: Test with GitHub Using ngrok

### Step 1: Port-forward is Already Running ✅

The notification-controller is now accessible on `localhost:9292`

### Step 2: Start ngrok

Open a **NEW terminal** and run:

```bash
ngrok http 9292
```

You'll see output like:
```
ngrok                                                                                                                                                                                         
                                                                                                                                                                                              
Session Status                online                                                                                                                                                          
Account                       Free                                                                                                                                                            
Version                       3.x.x                                                                                                                                                           
Region                        United States (us)                                                                                                                                              
Forwarding                    https://abc123xyz.ngrok.io -> http://localhost:9292                                                                                                            
```

**COPY THE HTTPS URL** (e.g., `https://abc123xyz.ngrok.io`)

### Step 3: Configure GitHub Webhook

1. Go to your repository: https://github.com/janessa-redalpha/gitops/settings/hooks

2. Click **"Add webhook"**

3. Fill in the form:

   - **Payload URL**: `https://abc123xyz.ngrok.io/hook/f6ccf0cba14dea90063998dcf8f3fff41bfd1ebb51bb49f7ceaa396d75225a9e`
     *(Replace `abc123xyz.ngrok.io` with YOUR ngrok URL from step 2)*
     *(Using dev environment path - change if needed)*

   - **Content type**: Select `application/json`

   - **Secret**: Paste this token:
     ```
     AhkhAD0H2oQdYRXU3qJnBynWOk7hH9sX1Tcsq0jHhEo
     ```

   - **Which events would you like to trigger this webhook?**
     - Select: **"Just the push event"**

   - **Active**: Check the box ✅

4. Click **"Add webhook"**

### Step 4: Test It!

GitHub will automatically send a "ping" event. You should see:
- Green checkmark (✓) in GitHub webhook deliveries
- Look at "Recent Deliveries" - should show successful response

### Step 5: Test with a Real Push

Make a change to your repository:

```bash
cd /path/to/your/local/gitops/repo
echo "Testing webhook" >> test-webhook.txt
git add test-webhook.txt
git commit -m "Test webhook trigger"
git push origin dev  # or staging/prod depending on which receiver you configured
```

### Step 6: Monitor the Results

Watch for immediate reconciliation:

```bash
# In another terminal
flux events -A --watch

# Or check GitRepository status
kubectl -n flux-system get gitrepository -w
```

You should see reconciliation happen within **2-5 seconds** instead of waiting for the polling interval!

---

## Alternative: Using serveo (No Installation Required)

If you don't want to install ngrok, use serveo:

```bash
ssh -R 80:localhost:9292 serveo.net
```

This will give you a URL like: `https://randomname.serveo.net`

Use that URL in GitHub webhook settings instead.

---

## Troubleshooting

### ngrok Not Working?

If ngrok connection drops or shows errors:

1. Check if port-forward is still running:
   ```bash
   ps aux | grep port-forward
   ```

2. Restart port-forward if needed:
   ```bash
   kubectl -n flux-system port-forward svc/notification-controller 9292:80
   ```

3. Make sure ngrok is pointing to port 9292

### GitHub Shows Connection Error?

- Make sure ngrok is running
- Make sure port-forward is running
- Check the ngrok URL matches what you put in GitHub

### Webhook Returns 401?

- Double-check the token matches exactly (no extra spaces)

### Webhook Returns 404?

- Make sure you included the full webhook path in the URL
- The path starts with `/hook/...`

---

## For Submission

After testing, take screenshots of:

1. ✅ GitHub webhook configuration page
2. ✅ GitHub "Recent Deliveries" showing green checkmark
3. ✅ Terminal showing `flux events` with webhook-triggered reconciliation
4. ✅ Time comparison (before: 1-5 minutes, after: 2-5 seconds)

These screenshots go in `SUBMISSION.md`

---

## When You're Done Testing

1. Stop ngrok (Ctrl+C in ngrok terminal)
2. Stop port-forward (run: `killall kubectl` or close the terminal)
3. The webhook will stop working (which is fine for testing)

**Note:** For production, you'd use a real Ingress with a domain instead of ngrok!

