# Environment-Specific Configuration Management Strategy

## Executive Summary

This document outlines a comprehensive Helm-based configuration management strategy for Kubernetes applications using GitOps principles. The strategy provides clean separation between base templates and environment-specific values, ensuring reproducibility and minimal drift between environments.

## 1. Helm Chart Structure

### Chart Tree
```
scaffold/helm/myapp/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default values
├── values-dev.yaml              # Development environment values
├── values-staging.yaml          # Staging environment values
├── values-prod.yaml             # Production environment values
├── templates/
│   ├── _helpers.tpl             # Template helpers
│   ├── deployment.yaml          # Generic deployment template
│   ├── service.yaml             # Generic service template
│   ├── configmap.yaml           # Generic configmap template
│   ├── hpa.yaml                 # Generic HPA template
│   └── serviceaccount.yaml      # Generic service account template
└── flux-helmreleases/
    ├── helmrelease-dev.yaml     # Flux HelmRelease for dev
    ├── helmrelease-staging.yaml # Flux HelmRelease for staging
    └── helmrelease-prod.yaml    # Flux HelmRelease for production
```

### Key Design Principles

1. **Generic Templates**: All templates are environment-agnostic and use values-driven configuration
2. **Environment Separation**: Each environment has dedicated values files
3. **GitOps Compliance**: Flux HelmRelease resources manage deployments
4. **Secret Management**: Integration with external-secrets or SOPS for secure secret handling
5. **Reproducibility**: Deterministic deployments across all environments

## 2. Environment-Specific Values Files

### Development Environment (values-dev.yaml)
```yaml
replicaCount: 1
image:
  repository: nginx
  tag: "1.27-alpine"
  pullPolicy: Always

config:
  appMode: "development"
  greeting: "Hello from Development!"
  debug: true

resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false

healthCheck:
  enabled: true
  path: /health
  initialDelaySeconds: 10
  periodSeconds: 5
```

### Staging Environment (values-staging.yaml)
```yaml
replicaCount: 2
image:
  repository: ghcr.io/org/myapp
  tag: "staging-latest"
  pullPolicy: IfNotPresent

config:
  appMode: "staging"
  greeting: "Hello from Staging Environment!"
  debug: false

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 5
  targetCPUUtilizationPercentage: 70

secrets:
  enabled: true
```

### Production Environment (values-prod.yaml)
```yaml
replicaCount: 3
image:
  repository: ghcr.io/org/myapp
  tag: "v1.2.3"
  pullPolicy: IfNotPresent

config:
  appMode: "production"
  greeting: "Welcome to MyApp Production!"
  debug: false

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 60

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: myapp.company.com
      paths:
        - path: /
          pathType: Prefix

secrets:
  enabled: true

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - myapp
        topologyKey: kubernetes.io/hostname
```

## 3. Flux HelmRelease Configuration

### GitRepository Source
```yaml
apiVersion: source.toolkit.fluxcd.io/v1beta2
kind: GitRepository
metadata:
  name: config-repo
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/config-repo
  ref:
    branch: main
  secretRef:
    name: config-repo-secret
```

### Development HelmRelease
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: myapp-dev
  namespace: flux-system
spec:
  interval: 1m
  chart:
    spec:
      chart: ./scaffold/helm/myapp
      sourceRef:
        kind: GitRepository
        name: config-repo
      version: ">=0.1.0"
  values:
    # Inline values for development
    replicaCount: 1
    image:
      repository: nginx
      tag: "1.27-alpine"
  targetNamespace: myapp-dev
  install:
    createNamespace: true
```

### Staging HelmRelease (with ConfigMap values)
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: myapp-staging
  namespace: flux-system
spec:
  interval: 2m
  chart:
    spec:
      chart: ./scaffold/helm/myapp
      sourceRef:
        kind: GitRepository
        name: config-repo
      version: ">=0.1.0"
  valuesFrom:
    - kind: ConfigMap
      name: myapp-staging-values
      valuesKey: values.yaml
  targetNamespace: myapp-staging
  test:
    enable: true
```

### Production HelmRelease (with ConfigMap + Secret values)
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: myapp-prod
  namespace: flux-system
spec:
  interval: 5m
  chart:
    spec:
      chart: ./scaffold/helm/myapp
      sourceRef:
        kind: GitRepository
        name: config-repo
      version: ">=0.1.0"
  valuesFrom:
    - kind: ConfigMap
      name: myapp-prod-values
      valuesKey: values.yaml
    - kind: Secret
      name: myapp-prod-secrets
      valuesKey: secrets.yaml
      targetPath: "secrets"
  targetNamespace: myapp-prod
  install:
    remediation:
      retries: 5
  test:
    enable: true
    timeout: 10m
```

## 4. Local Validation Commands

### Prerequisites
```bash
# Install Helm if not already installed
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify Helm installation
helm version
```

### Render and Validate Development Environment
```bash
# Navigate to chart directory
cd /home/jnssa/GitOps/scaffold/helm/myapp

# Render development manifests
helm template myapp-dev . -f values-dev.yaml --debug

# Validate with kubectl (dry-run)
helm template myapp-dev . -f values-dev.yaml | kubectl apply -f - --dry-run=client

# Check specific resources
helm template myapp-dev . -f values-dev.yaml | grep -A 20 "kind: Deployment"
```

**Expected Output (Development):**
```yaml
# Source: myapp/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-dev-myapp
  labels:
    app.kubernetes.io/instance: myapp-dev
    app.kubernetes.io/name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/instance: myapp-dev
      app.kubernetes.io/name: myapp
  template:
    spec:
      containers:
      - name: myapp
        image: "nginx:1.27-alpine"
        env:
        - name: APP_MODE
          value: "development"
        - name: GREETING
          value: "Hello from Development!"
        - name: DEBUG
          value: "true"
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 128Mi
```

### Render and Validate Staging Environment
```bash
# Render staging manifests
helm template myapp-staging . -f values-staging.yaml --debug

# Validate with kubectl (dry-run)
helm template myapp-staging . -f values-staging.yaml | kubectl apply -f - --dry-run=client

# Check HPA configuration
helm template myapp-staging . -f values-staging.yaml | grep -A 15 "kind: HorizontalPodAutoscaler"
```

**Expected Output (Staging):**
```yaml
# Source: myapp/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-staging-myapp
spec:
  replicas: 2
  template:
    spec:
      containers:
      - name: myapp
        image: "ghcr.io/org/myapp:staging-latest"
        env:
        - name: APP_MODE
          value: "staging"
        - name: GREETING
          value: "Hello from Staging Environment!"
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 250m
            memory: 256Mi

---
# Source: myapp/templates/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: myapp-staging-myapp
spec:
  minReplicas: 2
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Render and Validate Production Environment
```bash
# Render production manifests
helm template myapp-prod . -f values-prod.yaml --debug

# Validate with kubectl (dry-run)
helm template myapp-prod . -f values-prod.yaml | kubectl apply -f - --dry-run=client

# Check ingress configuration
helm template myapp-prod . -f values-prod.yaml | grep -A 20 "kind: Ingress"

# Check anti-affinity configuration
helm template myapp-prod . -f values-prod.yaml | grep -A 30 "podAntiAffinity"
```

**Expected Output (Production):**
```yaml
# Source: myapp/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-prod-myapp
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: myapp
        image: "ghcr.io/org/myapp:v1.2.3"
        env:
        - name: APP_MODE
          value: "production"
        - name: GREETING
          value: "Welcome to MyApp Production!"
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 500m
            memory: 512Mi
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app.kubernetes.io/name
                  operator: In
                  values:
                  - myapp
              topologyKey: kubernetes.io/hostname

---
# Source: myapp/templates/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-prod-myapp
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  rules:
  - host: myapp.company.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-prod-myapp
            port:
              number: 80
```

### Comprehensive Validation Script
```bash
#!/bin/bash
# validate-helm-charts.sh

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
```

## 5. Secrets Management Strategy

### SOPS Integration

#### Encrypted Secrets File (secrets-prod.yaml.enc)
```yaml
# This file is encrypted with SOPS
apiVersion: v1
kind: Secret
metadata:
  name: myapp-prod-secrets
  namespace: myapp-prod
type: Opaque
data:
  apiKey: <encrypted-base64-value>
  databaseUrl: <encrypted-base64-value>
```

#### SOPS Configuration (.sops.yaml)
```yaml
creation_rules:
  - path_regex: .*prod.*\.yaml$
    kms: "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
    pgp: |
      -----BEGIN PGP PUBLIC KEY BLOCK-----
      mQENBF7Bl8sBCAD...
      -----END PGP PUBLIC KEY BLOCK-----
  - path_regex: .*staging.*\.yaml$
    kms: "arn:aws:kms:us-west-2:123456789012:key/87654321-4321-4321-4321-210987654321"
```

#### Encryption/Decryption Commands
```bash
# Encrypt secrets
sops -e -i secrets-prod.yaml

# Decrypt for editing
sops -d secrets-prod.yaml > secrets-prod-decrypted.yaml
sops -e -i secrets-prod.yaml

# Verify encryption
sops -d secrets-prod.yaml | kubectl apply -f - --dry-run=client
```

### External Secrets Operator Integration

#### SecretStore Configuration
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: myapp-prod
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        secretRef:
          accessKeyID:
            name: aws-credentials
            key: access-key-id
          secretAccessKey:
            name: aws-credentials
            key: secret-access-key
```

#### ExternalSecret Configuration
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-prod-secrets
  namespace: myapp-prod
spec:
  refreshInterval: 15s
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: myapp-prod-secrets
    creationPolicy: Owner
  data:
  - secretKey: apiKey
    remoteRef:
      key: myapp/prod/api-key
      property: value
  - secretKey: databaseUrl
    remoteRef:
      key: myapp/prod/database-url
      property: value
```

## 6. GitOps Integration Benefits

### Key Advantages

1. **Declarative Configuration**: All environment differences defined in Git
2. **Auditability**: Complete change history and approval workflow
3. **Reproducibility**: Identical deployment process across environments
4. **Security**: Secrets managed externally, never stored in plaintext
5. **Scalability**: Easy to add new environments or applications
6. **Compliance**: Meets enterprise security and governance requirements

### Deployment Flow

1. **Development**: Auto-deploy on merge to main branch
2. **Staging**: Manual promotion via PR with app team approval
3. **Production**: Manual promotion via PR with platform team approval
4. **Rollback**: Git-based rollback using Flux rollback capabilities

### Monitoring and Observability

- Flux provides real-time sync status
- Helm test hooks enable post-deployment validation
- Resource health checks ensure deployment success
- Prometheus metrics integration for monitoring

---

*This configuration management strategy provides a robust, scalable, and secure approach to managing Kubernetes applications across multiple environments using Helm and GitOps principles.*
