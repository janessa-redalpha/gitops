#!/bin/bash
set -e

echo "==================================="
echo "Vault Secret Setup Script"
echo "==================================="
echo ""

# Wait for Vault to be ready
echo "1. Waiting for Vault pod to be ready..."
kubectl wait --for=condition=ready pod -l app=vault -n vault --timeout=120s
echo "✅ Vault is ready"
echo ""

# Port-forward to Vault
echo "2. Setting up port-forward to Vault..."
kubectl port-forward -n vault svc/vault 8200:8200 > /dev/null 2>&1 &
PF_PID=$!
echo "✅ Port-forward established (PID: $PF_PID)"
sleep 3
echo ""

# Set environment variables
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

echo "3. Configuring Vault environment..."
echo "   VAULT_ADDR: $VAULT_ADDR"
echo "   VAULT_TOKEN: $VAULT_TOKEN (dev mode)"
echo ""

# Create the secret in Vault
echo "4. Creating secret in Vault..."
if command -v vault &> /dev/null; then
    vault kv put secret/app/config MY_MESSAGE="Hello from Vault! This is a demo secret managed by ESO."
    echo "✅ Secret created using Vault CLI"
    echo ""
    
    echo "5. Verifying secret..."
    vault kv get secret/app/config
else
    echo "⚠️  Vault CLI not found, using curl instead..."
    curl -s -X POST \
        -H "X-Vault-Token: root" \
        -d '{"data": {"MY_MESSAGE": "Hello from Vault! This is a demo secret managed by ESO."}}' \
        http://127.0.0.1:8200/v1/secret/data/app/config
    echo "✅ Secret created using curl"
    echo ""
    
    echo "5. Verifying secret..."
    curl -s -H "X-Vault-Token: root" \
        http://127.0.0.1:8200/v1/secret/data/app/config | jq .
fi
echo ""

# Clean up
echo "6. Cleaning up port-forward..."
kill $PF_PID 2>/dev/null || true
echo "✅ Port-forward closed"
echo ""

echo "==================================="
echo "✅ Setup Complete!"
echo "==================================="
echo ""
echo "Next steps:"
echo "1. Wait for External Secrets Operator to sync (up to 1 minute)"
echo "2. Check ExternalSecret status: kubectl get externalsecret -n team-a"
echo "3. Verify secret created: kubectl get secret app-secret -n team-a"
echo "4. Check app logs: kubectl logs -n team-a deployment/secret-consumer"
echo ""

