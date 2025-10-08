# Promotion and Rollback Strategies

## Promotion Strategy (Dev → Staging → Prod)

### 1. Git-Based Promotion

#### Manual Promotion Process:
```bash
# 1. Update image tag in dev overlay
cd apps/myapp/overlays/dev/
# Update kustomization.yaml with new image tag
kustomize edit set image myapp:v1.2.4-dev

# 2. Commit and push to dev branch
git add .
git commit -m "feat: promote myapp v1.2.4 to dev"
git push origin dev

# 3. After dev validation, promote to staging
cd ../staging/
kustomize edit set image myapp:v1.2.4-staging
git add .
git commit -m "feat: promote myapp v1.2.4 to staging"
git push origin main

# 4. After staging validation, promote to prod
cd ../prod/
kustomize edit set image myapp:v1.2.4
git add .
git commit -m "feat: promote myapp v1.2.4 to production"
git push origin main
```

#### Automated Promotion with Flux Image Automation:
```yaml
---
# ImageUpdateAutomation for automated promotions
apiVersion: image.toolkit.fluxcd.io/v1beta1
kind: ImageUpdateAutomation
metadata:
  name: myapp-promotion
  namespace: flux-system
spec:
  interval: 1h
  sourceRef:
    kind: GitRepository
    name: flux-system
  git:
    checkout:
      ref:
        branch: main
    commit:
      author:
        name: fluxcdbot
        email: fluxcdbot@users.noreply.github.com
      messageTemplate: |
        chore: promote myapp {{range .Images}}{{.Name}}:{{.NewTag}}{{end}}
        
        Automated promotion from {{.Image.Repository}}:{{.LastImage.Tag}} to {{.Image.Repository}}:{{.NewTag}}
        
        Co-authored-by: fluxcdbot <fluxcdbot@users.noreply.github.com>
    push:
      branch: main
  update:
    path: "./apps/myapp/overlays"
    strategy: Setters
```

### 2. Promotion Gates and Validation

#### Pre-Promotion Validation:
```yaml
---
# Policy for promotion validation
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: myapp-promotion-validation
  namespace: flux-system
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: validate-image-tag
    match:
      any:
      - resources:
          kinds:
          - Kustomization
          names:
          - "myapp-*"
    validate:
      message: "Image tag must follow semantic versioning"
      pattern:
        spec:
          kustomize:
            images:
            - name: "myapp"
              newTag: "v[0-9]+\\.[0-9]+\\.[0-9]+(-.*)?"
```

#### Health Check Validation:
```yaml
---
# Health check policy
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: myapp-health-validation
  namespace: flux-system
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: validate-health-checks
    match:
      any:
      - resources:
          kinds:
          - Deployment
          names:
          - "myapp*"
    validate:
      message: "Health checks are required for production deployments"
      pattern:
        spec:
          template:
            spec:
              containers:
              - name: "myapp"
                livenessProbe:
                  httpGet:
                    path: "/health"
                    port: "8080"
                readinessProbe:
                  httpGet:
                    path: "/ready"
                    port: "8080"
```

### 3. Cross-Cluster Promotion

#### Regional Promotion Strategy:
```bash
# Promote to all dev clusters
for region in us-west-2 us-east-1 eu-west-1; do
  kubectl --context=dev-$region patch kustomization myapp \
    -n flux-system --type='merge' \
    -p='{"spec":{"kustomize":{"images":[{"name":"myapp","newTag":"v1.2.4-dev"}]}}}'
done

# Promote to staging clusters after dev validation
for region in us-west-2 us-east-1 eu-west-1; do
  kubectl --context=staging-$region patch kustomization myapp \
    -n flux-system --type='merge' \
    -p='{"spec":{"kustomize":{"images":[{"name":"myapp","newTag":"v1.2.4-staging"}]}}}'
done

# Promote to production clusters after staging validation
for region in us-west-2 us-east-1 eu-west-1; do
  kubectl --context=prod-$region patch kustomization myapp \
    -n flux-system --type='merge' \
    -p='{"spec":{"kustomize":{"images":[{"name":"myapp","newTag":"v1.2.4"}]}}}'
done
```

## Rollback Strategy

### 1. Git-Based Rollback

#### Quick Rollback Process:
```bash
# 1. Identify the last known good commit
git log --oneline -10

# 2. Revert to the previous version
git revert HEAD~1

# 3. Force push to trigger immediate rollback
git push origin main --force-with-lease

# 4. Verify rollback across clusters
for context in dev-us-west-2 staging-us-east-1 prod-us-west-2; do
  kubectl --context=$context get pods -l app=myapp -o wide
done
```

#### Targeted Rollback:
```bash
# Rollback specific environment
kubectl --context=prod-us-west-2 patch kustomization myapp \
  -n flux-system --type='merge' \
  -p='{"spec":{"kustomize":{"images":[{"name":"myapp","newTag":"v1.2.3"}]}}}'

# Verify rollback
kubectl --context=prod-us-west-2 rollout status deployment/myapp
```

### 2. Automated Rollback with Flux

#### Rollback Policy:
```yaml
---
# Rollback policy for failed deployments
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: myapp-rollback-policy
  namespace: flux-system
spec:
  validationFailureAction: enforce
  background: true
  rules:
  - name: auto-rollback-on-failure
    match:
      any:
      - resources:
          kinds:
          - Deployment
          names:
          - "myapp*"
    preconditions:
      any:
      - key: "{{.status.conditions[?(@.type=='Progressing')].status}}"
        operator: Equals
        value: "False"
      - key: "{{.status.conditions[?(@.type=='Available')].status}}"
        operator: Equals
        value: "False"
    validate:
      message: "Deployment failed, triggering automatic rollback"
      deny:
        conditions:
          all:
          - key: "{{.status.conditions[?(@.type=='Progressing')].status}}"
            operator: Equals
            value: "False"
```

### 3. Blue-Green Rollback

#### Blue-Green Deployment Strategy:
```yaml
---
# Blue-Green deployment configuration
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp
  namespace: myapp-prod
spec:
  replicas: 3
  strategy:
    blueGreen:
      activeService: myapp-active
      previewService: myapp-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
        - templateName: myapp-health-check
        args:
        - name: service-name
          value: myapp-preview
      postPromotionAnalysis:
        templates:
        - templateName: myapp-performance-check
        args:
        - name: service-name
          value: myapp-active
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:v1.2.4
        ports:
        - containerPort: 8080
```

### 4. Canary Rollback

#### Canary Deployment with Automatic Rollback:
```yaml
---
# Canary deployment with rollback
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: myapp-canary
  namespace: myapp-prod
spec:
  replicas: 5
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {duration: 10m}
      - setWeight: 40
      - pause: {duration: 10m}
      - setWeight: 60
      - pause: {duration: 10m}
      - setWeight: 80
      - pause: {duration: 10m}
      analysis:
        templates:
        - templateName: myapp-success-rate
        args:
        - name: service-name
          value: myapp
        startingStep: 2
        successfulRunHistoryLimit: 5
        unsuccessfulRunHistoryLimit: 3
        metrics:
        - name: success-rate
          interval: 30s
          successCondition: result[0] >= 0.95
          failureCondition: result[0] < 0.90
          failureLimit: 3
```

## Monitoring and Alerting

### 1. Promotion Monitoring

#### Prometheus Alerts:
```yaml
---
# Prometheus alert rules for promotions
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-promotion-alerts
  namespace: monitoring
spec:
  groups:
  - name: myapp.promotion
    rules:
    - alert: MyAppPromotionFailed
      expr: kube_deployment_status_replicas_unavailable{deployment="myapp"} > 0
      for: 5m
      labels:
        severity: critical
        team: backend
      annotations:
        summary: "MyApp deployment failed after promotion"
        description: "MyApp deployment {{ $labels.deployment }} has {{ $value }} unavailable replicas"
        
    - alert: MyAppPromotionSlow
      expr: kube_deployment_status_replicas_ready{deployment="myapp"} < kube_deployment_spec_replicas{deployment="myapp"}
      for: 10m
      labels:
        severity: warning
        team: backend
      annotations:
        summary: "MyApp promotion is taking longer than expected"
        description: "MyApp deployment {{ $labels.deployment }} is not fully ready after 10 minutes"
```

### 2. Rollback Monitoring

#### Rollback Success Metrics:
```yaml
---
# Rollback success metrics
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: myapp-rollback-alerts
  namespace: monitoring
spec:
  groups:
  - name: myapp.rollback
    rules:
    - alert: MyAppRollbackFailed
      expr: kube_deployment_status_replicas_unavailable{deployment="myapp"} > 0
      for: 5m
      labels:
        severity: critical
        team: backend
      annotations:
        summary: "MyApp rollback failed"
        description: "MyApp deployment {{ $labels.deployment }} rollback failed with {{ $value }} unavailable replicas"
        
    - alert: MyAppRollbackSuccess
      expr: kube_deployment_status_replicas_ready{deployment="myapp"} == kube_deployment_spec_replicas{deployment="myapp"}
      for: 0m
      labels:
        severity: info
        team: backend
      annotations:
        summary: "MyApp rollback successful"
        description: "MyApp deployment {{ $labels.deployment }} rollback completed successfully"
```

## Best Practices

### 1. Promotion Best Practices
- Always validate in dev before promoting to staging
- Use automated testing in CI/CD pipeline
- Implement canary deployments for production
- Monitor key metrics during promotion
- Have rollback plan ready before promotion

### 2. Rollback Best Practices
- Keep rollback procedures documented and tested
- Use automated rollback for critical failures
- Monitor rollback success and recovery time
- Communicate rollback status to stakeholders
- Learn from rollback incidents to improve processes

### 3. Security Considerations
- Use signed container images
- Implement image scanning in promotion pipeline
- Secure promotion credentials and access
- Audit promotion and rollback activities
- Use least privilege for promotion automation
