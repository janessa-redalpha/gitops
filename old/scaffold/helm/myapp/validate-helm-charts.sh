#!/bin/bash
# validate-helm-charts.sh
# Comprehensive validation script for Helm chart environments

set -e

CHART_PATH="/home/jnssa/GitOps/scaffold/helm/myapp"
RELEASE_NAME="myapp"

echo "🔍 Validating Helm Chart Structure..."
helm lint $CHART_PATH

echo "🧪 Testing Development Environment..."
helm template $RELEASE_NAME-dev $CHART_PATH -f $CHART_PATH/values-dev.yaml > /tmp/dev-manifests.yaml
kubectl apply -f /tmp/dev-manifests.yaml --dry-run=client
echo "✅ Development validation passed"

echo "🧪 Testing Staging Environment..."
helm template $RELEASE_NAME-staging $CHART_PATH -f $CHART_PATH/values-staging.yaml > /tmp/staging-manifests.yaml
kubectl apply -f /tmp/staging-manifests.yaml --dry-run=client
echo "✅ Staging validation passed"

echo "🧪 Testing Production Environment..."
helm template $RELEASE_NAME-prod $CHART_PATH -f $CHART_PATH/values-prod.yaml > /tmp/prod-manifests.yaml
kubectl apply -f /tmp/prod-manifests.yaml --dry-run=client
echo "✅ Production validation passed"

echo "📊 Resource Comparison..."
echo "Development replicas: $(grep -A 5 'replicas:' /tmp/dev-manifests.yaml | head -1 | awk '{print $2}')"
echo "Staging replicas: $(grep -A 5 'replicas:' /tmp/staging-manifests.yaml | head -1 | awk '{print $2}')"
echo "Production replicas: $(grep -A 5 'replicas:' /tmp/prod-manifests.yaml | head -1 | awk '{print $2}')"

echo "🎉 All validations completed successfully!"
