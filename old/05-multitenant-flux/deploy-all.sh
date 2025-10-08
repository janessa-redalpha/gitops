#!/bin/bash
# Script to deploy the multi-tenant FluxCD setup

set -e

echo "================================================"
echo "Deploying Multi-Tenant FluxCD Setup"
echo "================================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}WARNING:${NC} Before running this script, ensure you have:"
echo "  1. Updated Git repository URLs in gitrepository.yaml files"
echo "  2. Created Git authentication secrets with actual credentials"
echo ""
read -p "Have you completed these steps? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please complete the prerequisites first, then run this script again."
    exit 1
fi

echo ""
echo "=== Step 1: Creating Namespaces ==="
kubectl apply -f tenants/team-a/namespace.yaml
kubectl apply -f tenants/team-b/namespace.yaml
echo -e "${GREEN}✓${NC} Namespaces created"

echo ""
echo "=== Step 2: Applying RBAC Resources ==="
kubectl apply -f tenants/team-a/rbac.yaml
kubectl apply -f tenants/team-b/rbac.yaml
echo -e "${GREEN}✓${NC} RBAC resources created"

echo ""
echo "=== Step 3: Creating Git Authentication Secrets ==="
echo -e "${YELLOW}NOTE:${NC} You need to create these manually with actual credentials:"
echo "  kubectl create secret generic team-a-git-auth --namespace=team-a --from-literal=username=git --from-literal=password=<TOKEN>"
echo "  kubectl create secret generic team-b-git-auth --namespace=team-b --from-literal=username=git --from-literal=password=<TOKEN>"
echo ""
read -p "Press Enter once you've created the secrets..."

echo ""
echo "=== Step 4: Creating GitRepository Resources ==="
kubectl apply -f tenants/team-a/gitrepository.yaml
kubectl apply -f tenants/team-b/gitrepository.yaml
echo -e "${GREEN}✓${NC} GitRepository resources created"

echo ""
echo "Waiting for GitRepositories to be ready..."
kubectl wait --for=condition=ready --timeout=60s gitrepository/team-a-apps -n team-a || echo "team-a GitRepository not ready yet"
kubectl wait --for=condition=ready --timeout=60s gitrepository/team-b-apps -n team-b || echo "team-b GitRepository not ready yet"

echo ""
echo "=== Step 5: Creating Kustomization Resources ==="
kubectl apply -f tenants/team-a/kustomization.yaml
kubectl apply -f tenants/team-b/kustomization.yaml
echo -e "${GREEN}✓${NC} Kustomization resources created"

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Check status: flux get all -n team-a"
echo "  2. Check status: flux get all -n team-b"
echo "  3. Verify RBAC: ./verify-rbac.sh"
echo "  4. View logs: flux logs -n team-a --follow"
echo ""

