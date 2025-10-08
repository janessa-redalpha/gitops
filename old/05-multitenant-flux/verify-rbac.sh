#!/bin/bash
# Script to verify RBAC boundaries for multi-tenant Flux setup

set -e

echo "================================================"
echo "Multi-Tenant FluxCD RBAC Verification"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

test_permission() {
    local sa=$1
    local namespace=$2
    local verb=$3
    local resource=$4
    local target_ns=$5
    
    if [ -z "$target_ns" ]; then
        target_ns=$namespace
    fi
    
    if kubectl auth can-i "$verb" "$resource" \
        --as "system:serviceaccount:${namespace}:${sa}" \
        -n "$target_ns" &>/dev/null; then
        echo -e "${GREEN}✓${NC} SA ${sa} CAN ${verb} ${resource} in ${target_ns}"
        return 0
    else
        echo -e "${RED}✗${NC} SA ${sa} CANNOT ${verb} ${resource} in ${target_ns}"
        return 1
    fi
}

echo "=== Testing Team A Service Account Permissions ==="
echo ""

echo "Testing permissions in team-a namespace (SHOULD SUCCEED):"
test_permission "flux-reconciler" "team-a" "create" "deployments"
test_permission "flux-reconciler" "team-a" "get" "deployments"
test_permission "flux-reconciler" "team-a" "list" "pods"
test_permission "flux-reconciler" "team-a" "create" "secrets"
test_permission "flux-reconciler" "team-a" "create" "configmaps"
test_permission "flux-reconciler" "team-a" "create" "services"
test_permission "flux-reconciler" "team-a" "get" "kustomizations"

echo ""
echo "Testing cross-namespace access from team-a to team-b (SHOULD FAIL):"
test_permission "flux-reconciler" "team-a" "create" "deployments" "team-b" || true
test_permission "flux-reconciler" "team-a" "get" "deployments" "team-b" || true
test_permission "flux-reconciler" "team-a" "list" "pods" "team-b" || true
test_permission "flux-reconciler" "team-a" "create" "secrets" "team-b" || true

echo ""
echo "Testing cluster-wide access from team-a (SHOULD FAIL):"
test_permission "flux-reconciler" "team-a" "list" "namespaces" "" || true
test_permission "flux-reconciler" "team-a" "create" "clusterroles" "" || true
test_permission "flux-reconciler" "team-a" "create" "clusterrolebindings" "" || true

echo ""
echo "=== Testing Team B Service Account Permissions ==="
echo ""

echo "Testing permissions in team-b namespace (SHOULD SUCCEED):"
test_permission "flux-reconciler" "team-b" "create" "deployments"
test_permission "flux-reconciler" "team-b" "get" "deployments"
test_permission "flux-reconciler" "team-b" "list" "pods"
test_permission "flux-reconciler" "team-b" "create" "secrets"
test_permission "flux-reconciler" "team-b" "create" "configmaps"
test_permission "flux-reconciler" "team-b" "create" "services"
test_permission "flux-reconciler" "team-b" "get" "kustomizations"

echo ""
echo "Testing cross-namespace access from team-b to team-a (SHOULD FAIL):"
test_permission "flux-reconciler" "team-b" "create" "deployments" "team-a" || true
test_permission "flux-reconciler" "team-b" "get" "deployments" "team-a" || true
test_permission "flux-reconciler" "team-b" "list" "pods" "team-a" || true
test_permission "flux-reconciler" "team-b" "create" "secrets" "team-a" || true

echo ""
echo "Testing cluster-wide access from team-b (SHOULD FAIL):"
test_permission "flux-reconciler" "team-b" "list" "namespaces" "" || true
test_permission "flux-reconciler" "team-b" "create" "clusterroles" "" || true
test_permission "flux-reconciler" "team-b" "create" "clusterrolebindings" "" || true

echo ""
echo "================================================"
echo "Verification Complete!"
echo "================================================"

