#!/bin/bash

# Flux Webhook Verification Script
# This script helps verify that webhook integration is working correctly

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================"
echo "Flux Webhook Verification"
echo "========================================"
echo ""

# Function to check command
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is not installed"
        return 1
    fi
}

# Check prerequisites
echo "Checking prerequisites..."
check_command kubectl
check_command flux || echo -e "${YELLOW}  Warning: flux CLI not found (optional)${NC}"
echo ""

# Check if webhook secret exists
echo "Checking webhook secret..."
if kubectl get secret webhook-token -n flux-system &> /dev/null; then
    echo -e "${GREEN}✓${NC} webhook-token secret exists"
    TOKEN=$(kubectl -n flux-system get secret webhook-token -o jsonpath='{.data.token}' | base64 -d)
    echo -e "  Token length: ${#TOKEN} characters"
else
    echo -e "${RED}✗${NC} webhook-token secret not found"
    echo "  Run ./setup.sh to create it"
    exit 1
fi
echo ""

# Check receivers
echo "Checking receivers..."
RECEIVERS=("gitops-receiver-dev" "gitops-receiver-staging" "gitops-receiver-prod")

for RECEIVER in "${RECEIVERS[@]}"; do
    if kubectl get receiver $RECEIVER -n flux-system &> /dev/null; then
        READY=$(kubectl get receiver $RECEIVER -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        WEBHOOK_PATH=$(kubectl get receiver $RECEIVER -n flux-system -o jsonpath='{.status.webhookPath}')
        
        if [ "$READY" == "True" ]; then
            echo -e "${GREEN}✓${NC} $RECEIVER is ready"
            echo -e "  Webhook path: ${BLUE}$WEBHOOK_PATH${NC}"
        else
            echo -e "${YELLOW}!${NC} $RECEIVER exists but not ready"
            REASON=$(kubectl get receiver $RECEIVER -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].message}')
            echo -e "  Reason: $REASON"
        fi
    else
        echo -e "${RED}✗${NC} $RECEIVER not found"
    fi
done
echo ""

# Check notification controller
echo "Checking notification-controller..."
if kubectl get deployment notification-controller -n flux-system &> /dev/null; then
    READY=$(kubectl get deployment notification-controller -n flux-system -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(kubectl get deployment notification-controller -n flux-system -o jsonpath='{.status.replicas}')
    
    if [ "$READY" == "$DESIRED" ]; then
        echo -e "${GREEN}✓${NC} notification-controller is running ($READY/$DESIRED replicas)"
    else
        echo -e "${YELLOW}!${NC} notification-controller: $READY/$DESIRED replicas ready"
    fi
else
    echo -e "${RED}✗${NC} notification-controller not found"
fi
echo ""

# Check GitRepositories
echo "Checking GitRepository resources..."
GITREPOS=("gitops-repo-dev" "gitops-repo-staging" "gitops-repo-prod")

for GITREPO in "${GITREPOS[@]}"; do
    if kubectl get gitrepository $GITREPO -n flux-system &> /dev/null; then
        READY=$(kubectl get gitrepository $GITREPO -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [ "$READY" == "True" ]; then
            echo -e "${GREEN}✓${NC} $GITREPO is ready"
        else
            echo -e "${YELLOW}!${NC} $GITREPO exists but not ready"
        fi
    else
        echo -e "${YELLOW}!${NC} $GITREPO not found"
    fi
done
echo ""

# Check Ingress (optional)
echo "Checking Ingress (optional)..."
if kubectl get ingress notification-controller -n flux-system &> /dev/null; then
    HOST=$(kubectl get ingress notification-controller -n flux-system -o jsonpath='{.spec.rules[0].host}')
    echo -e "${GREEN}✓${NC} Ingress exists"
    echo -e "  Host: ${BLUE}$HOST${NC}"
    
    # Try to get ingress IP/hostname
    ADDRESS=$(kubectl get ingress notification-controller -n flux-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -z "$ADDRESS" ]; then
        ADDRESS=$(kubectl get ingress notification-controller -n flux-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    fi
    
    if [ ! -z "$ADDRESS" ]; then
        echo -e "  Address: ${BLUE}$ADDRESS${NC}"
    else
        echo -e "  ${YELLOW}Warning: No LoadBalancer address assigned yet${NC}"
    fi
else
    echo -e "${YELLOW}!${NC} Ingress not configured (using port-forward for testing?)"
fi
echo ""

# Summary and next steps
echo "========================================"
echo "Summary"
echo "========================================"
echo ""

# Check if everything is ready
ALL_READY=true

# Count ready receivers
READY_COUNT=0
for RECEIVER in "${RECEIVERS[@]}"; do
    if kubectl get receiver $RECEIVER -n flux-system &> /dev/null; then
        READY=$(kubectl get receiver $RECEIVER -n flux-system -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        if [ "$READY" == "True" ]; then
            ((READY_COUNT++))
        fi
    fi
done

if [ $READY_COUNT -eq ${#RECEIVERS[@]} ]; then
    echo -e "${GREEN}✓ All receivers are ready ($READY_COUNT/${#RECEIVERS[@]})${NC}"
else
    echo -e "${YELLOW}! Some receivers not ready ($READY_COUNT/${#RECEIVERS[@]})${NC}"
    ALL_READY=false
fi

if [ "$ALL_READY" = true ]; then
    echo ""
    echo "Next steps:"
    echo "1. Configure GitHub webhooks with the information above"
    echo "2. Test by pushing a change to your repository"
    echo "3. Monitor with: flux events -A --watch"
    echo ""
    echo "For detailed instructions, see:"
    echo "  - github-webhook-configuration.md"
    echo "  - port-forward-testing.md"
else
    echo ""
    echo "Fix the issues above before proceeding."
    echo "Check logs: kubectl -n flux-system logs deploy/notification-controller"
fi

echo ""

exit 0

