#!/bin/bash

# Flux Webhook Testing Script
# This script simulates a GitHub webhook call to test the receiver

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
RECEIVER_NAME="gitops-receiver-dev"
PORT="9292"
HOST="localhost"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--receiver)
            RECEIVER_NAME="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -h|--host)
            HOST="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -r, --receiver NAME    Receiver name (default: gitops-receiver-dev)"
            echo "  -p, --port PORT        Port number (default: 9292)"
            echo "  -h, --host HOST        Host (default: localhost)"
            echo "  --help                 Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Test dev receiver on localhost:9292"
            echo "  $0 -r gitops-receiver-staging        # Test staging receiver"
            echo "  $0 -h flux-webhook.example.com -p 443 # Test via Ingress"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "========================================"
echo "Flux Webhook Test"
echo "========================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if curl is available
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed or not in PATH${NC}"
    exit 1
fi

# Check if openssl is available
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: openssl is not installed or not in PATH${NC}"
    exit 1
fi

echo "Configuration:"
echo -e "  Receiver: ${BLUE}$RECEIVER_NAME${NC}"
echo -e "  Host: ${BLUE}$HOST${NC}"
echo -e "  Port: ${BLUE}$PORT${NC}"
echo ""

# Get webhook token
echo "Retrieving webhook token..."
TOKEN=$(kubectl -n flux-system get secret webhook-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d)

if [ -z "$TOKEN" ]; then
    echo -e "${RED}Error: Could not retrieve webhook token${NC}"
    echo "Make sure the webhook-token secret exists in flux-system namespace"
    exit 1
fi

echo -e "${GREEN}✓${NC} Token retrieved"
echo ""

# Get webhook path
echo "Retrieving webhook path..."
WEBHOOK_PATH=$(kubectl -n flux-system get receiver $RECEIVER_NAME -o jsonpath='{.status.webhookPath}' 2>/dev/null)

if [ -z "$WEBHOOK_PATH" ]; then
    echo -e "${RED}Error: Could not retrieve webhook path for receiver $RECEIVER_NAME${NC}"
    echo "Make sure the receiver exists and is ready"
    exit 1
fi

echo -e "${GREEN}✓${NC} Webhook path: $WEBHOOK_PATH"
echo ""

# Construct URL
if [ "$PORT" == "443" ]; then
    PROTOCOL="https"
else
    PROTOCOL="http"
fi

URL="${PROTOCOL}://${HOST}:${PORT}${WEBHOOK_PATH}"

echo "Target URL: ${BLUE}$URL${NC}"
echo ""

# Create test payload
PAYLOAD='{"ref":"refs/heads/dev","repository":{"full_name":"janessa-redalpha/gitops"},"pusher":{"name":"test"}}'

echo "Creating HMAC signature..."

# Calculate HMAC signature
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$TOKEN" | cut -d' ' -f2)

echo -e "${GREEN}✓${NC} Signature created"
echo ""

# Send webhook request
echo "Sending webhook request..."
echo ""

RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "$URL" \
    -H "Content-Type: application/json" \
    -H "X-GitHub-Event: push" \
    -H "X-Hub-Signature-256: sha256=$SIGNATURE" \
    -d "$PAYLOAD" 2>&1)

# Extract status code
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_STATUS_CODE:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | grep -v "HTTP_STATUS_CODE:")

echo "Response:"
echo "  Status code: $HTTP_CODE"
if [ ! -z "$RESPONSE_BODY" ]; then
    echo "  Body: $RESPONSE_BODY"
fi
echo ""

# Evaluate response
if [ "$HTTP_CODE" == "200" ] || [ "$HTTP_CODE" == "202" ]; then
    echo -e "${GREEN}✓ Success! Webhook accepted${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Check Flux events: flux events --for receiver/$RECEIVER_NAME -n flux-system"
    echo "2. Check GitRepository: kubectl -n flux-system get gitrepository"
    echo "3. View logs: kubectl -n flux-system logs deploy/notification-controller --tail=20"
    exit 0
elif [ "$HTTP_CODE" == "401" ]; then
    echo -e "${RED}✗ Authentication failed (401)${NC}"
    echo "The webhook token may be incorrect"
    exit 1
elif [ "$HTTP_CODE" == "404" ]; then
    echo -e "${RED}✗ Not found (404)${NC}"
    echo "The webhook path or receiver may not exist"
    exit 1
elif [ "$HTTP_CODE" == "000" ] || [ -z "$HTTP_CODE" ]; then
    echo -e "${RED}✗ Connection failed${NC}"
    echo "Could not connect to $URL"
    echo ""
    echo "If testing locally, make sure port-forward is running:"
    echo "  kubectl -n flux-system port-forward svc/notification-controller 9292:80"
    exit 1
else
    echo -e "${YELLOW}! Unexpected status code: $HTTP_CODE${NC}"
    exit 1
fi

