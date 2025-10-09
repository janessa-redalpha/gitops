#!/bin/bash

# Flux Webhook Setup Script
# This script helps you set up webhook integration for Flux

set -e

echo "========================================"
echo "Flux Webhook Integration Setup"
echo "========================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if flux is available
if ! command -v flux &> /dev/null; then
    echo -e "${YELLOW}Warning: flux CLI is not installed. Some features may not work.${NC}"
fi

echo "Step 1: Generating webhook token..."
TOKEN=$(head -c 32 /dev/urandom | base64 | tr -d '\n' | tr -d '=')
echo -e "${GREEN}✓ Token generated${NC}"
echo ""

echo "Step 2: Creating webhook secret..."
kubectl create secret generic webhook-token \
    --namespace=flux-system \
    --from-literal=token="$TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✓ Secret created${NC}"
echo ""

echo "Step 3: Applying receivers..."
kubectl apply -f receiver-dev.yaml
kubectl apply -f receiver-staging.yaml
kubectl apply -f receiver-prod.yaml
echo -e "${GREEN}✓ Receivers applied${NC}"
echo ""

echo "Step 4: Waiting for receivers to be ready..."
sleep 3
kubectl wait --for=condition=ready receiver/gitops-receiver-dev -n flux-system --timeout=60s || true
kubectl wait --for=condition=ready receiver/gitops-receiver-staging -n flux-system --timeout=60s || true
kubectl wait --for=condition=ready receiver/gitops-receiver-prod -n flux-system --timeout=60s || true
echo ""

echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""

echo "Webhook Token:"
echo -e "${YELLOW}$TOKEN${NC}"
echo ""

echo "Receiver Status:"
kubectl get receiver -n flux-system
echo ""

echo "Webhook Paths:"
echo ""
echo "Dev environment:"
DEV_PATH=$(kubectl -n flux-system get receiver gitops-receiver-dev -o jsonpath='{.status.webhookPath}' 2>/dev/null || echo "Not ready yet")
echo -e "  Path: ${GREEN}$DEV_PATH${NC}"
echo ""

echo "Staging environment:"
STAGING_PATH=$(kubectl -n flux-system get receiver gitops-receiver-staging -o jsonpath='{.status.webhookPath}' 2>/dev/null || echo "Not ready yet")
echo -e "  Path: ${GREEN}$STAGING_PATH${NC}"
echo ""

echo "Production environment:"
PROD_PATH=$(kubectl -n flux-system get receiver gitops-receiver-prod -o jsonpath='{.status.webhookPath}' 2>/dev/null || echo "Not ready yet")
echo -e "  Path: ${GREEN}$PROD_PATH${NC}"
echo ""

echo "========================================"
echo "Next Steps:"
echo "========================================"
echo ""
echo "1. Configure GitHub webhooks using the token and paths above"
echo "   See: github-webhook-configuration.md"
echo ""
echo "2. For testing with port-forward:"
echo "   kubectl -n flux-system port-forward svc/notification-controller 9292:80"
echo "   See: port-forward-testing.md"
echo ""
echo "3. For production, apply the Ingress:"
echo "   Edit ingress.yaml with your domain"
echo "   kubectl apply -f ingress.yaml"
echo ""
echo "4. Monitor webhook deliveries:"
echo "   kubectl -n flux-system logs deploy/notification-controller -f"
echo ""

exit 0

