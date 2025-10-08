# Multi-Cluster GitOps Architecture

This repository contains a comprehensive GitOps strategy for managing deployments across multiple Kubernetes clusters spanning environments (dev, staging, prod) and regions using Flux v2.

## 📁 Repository Structure

```
├── 05multiclustergitopsarchitecture_setup.md  # Main architecture document
├── flux-manifests/                            # Flux controller manifests
│   ├── gitrepository.yaml
│   ├── platform-kustomization.yaml
│   ├── apps-kustomization.yaml
│   └── flux-system-kustomization.yaml
├── cluster-config/                            # Cluster configuration
│   ├── cluster-labels.yaml
│   └── rbac-policies.yaml
├── apps/                                      # Application configurations
│   └── myapp/
│       ├── base/
│       │   ├── deployment.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           ├── staging/
│           └── prod/
├── security/                                  # Security configurations
│   ├── identity-rbac-secrets.yaml
│   ├── secrets-management.yaml
│   └── tenancy-boundaries.yaml
└── promotion-rollback/                        # Promotion strategies
    └── promotion-strategy.md
```

## 🏗️ Architecture Overview

### Multi-Cluster Strategy
- **Environment Separation**: dev, staging, prod
- **Regional Distribution**: us-west-2, us-east-1, eu-west-1
- **Flux Fan-Out**: One GitRepository + Multiple Kustomizations per cluster

### Key Components
1. **GitRepository**: Central repository configuration
2. **Platform Kustomization**: Manages platform components
3. **Apps Kustomization**: Manages application deployments
4. **Cluster Labels**: Standardized labeling for cluster selection
5. **RBAC Policies**: Role-based access control
6. **Secrets Management**: SOPS, External Secrets, Sealed Secrets

## 🚀 Quick Start

### 1. Bootstrap Flux on Management Cluster
```bash
# Install Flux CLI
curl -s https://fluxcd.io/install.sh | sudo bash

# Bootstrap Flux
flux bootstrap github \
  --owner=your-org \
  --repository=gitops-cluster-config \
  --branch=main \
  --path=./clusters/dev/us-west-2/flux-system
```

### 2. Register Workload Clusters
```bash
# For each cluster, run:
flux create cluster \
  --context=dev-us-west-2 \
  --kubeconfig=./clusters/dev/us-west-2/kubeconfig \
  --namespace=flux-system \
  --export > ./clusters/dev/us-west-2/cluster.yaml
```

### 3. Deploy Platform Components
```bash
# Apply platform kustomization
kubectl apply -f flux-manifests/platform-kustomization.yaml
```

### 4. Deploy Applications
```bash
# Apply apps kustomization
kubectl apply -f flux-manifests/apps-kustomization.yaml
```

## 🔧 Configuration

### Cluster Labels
Each cluster is labeled with:
- `environment`: dev, staging, prod
- `region`: us-west-2, us-east-1, eu-west-1
- `cluster-type`: workload, management
- `team`: platform, backend, frontend
- `cost-center`: engineering

### Application Deployment
Applications are deployed using:
- **Base Configuration**: Common manifests in `apps/{app}/base/`
- **Environment Overlays**: Environment-specific configs in `overlays/{env}/`
- **Cluster-Specific Kustomizations**: Each cluster points to appropriate overlay

## 🔐 Security Features

### Identity & Access Management
- **SSO Integration**: OIDC/OAuth2 with corporate identity provider
- **RBAC**: Fine-grained permissions per role and namespace
- **Multi-tenancy**: Namespace-based isolation with ResourceQuotas

### Secrets Management
- **SOPS**: Encrypt secrets in Git using age encryption
- **External Secrets**: Sync secrets from external stores (AWS Secrets Manager, HashiCorp Vault)
- **Sealed Secrets**: Kubernetes-native secret encryption

### Network Security
- **Network Policies**: Secure pod-to-pod communication
- **Pod Security Policies**: Enforce security standards
- **Resource Quotas**: Limit resource consumption per namespace

## 📈 Promotion & Rollback

### Promotion Strategy
1. **Development**: Deploy to all dev clusters across regions
2. **Staging**: Promote to staging clusters after dev validation
3. **Production**: Promote to prod clusters after staging validation

### Rollback Strategy
1. **Git Revert**: Revert commits in the GitOps repository
2. **Image Rollback**: Update image tags to previous versions
3. **Kustomization Rollback**: Update Kustomization manifests

## 📊 Monitoring & Observability

### Key Metrics
- Deployment success/failure rates
- Promotion pipeline health
- Rollback frequency and success
- Resource utilization per cluster
- Security policy compliance

### Alerting
- Prometheus alerts for failed deployments
- Slack/Teams notifications for critical events
- Grafana dashboards for cluster health

## 🔄 Best Practices

### Development
- Always validate in dev before promoting to staging
- Use automated testing in CI/CD pipeline
- Implement canary deployments for production
- Monitor key metrics during promotion

### Security
- Use signed container images
- Implement image scanning in promotion pipeline
- Secure promotion credentials and access
- Audit promotion and rollback activities

### Operations
- Keep rollback procedures documented and tested
- Use automated rollback for critical failures
- Monitor rollback success and recovery time
- Learn from rollback incidents to improve processes

## 📚 Documentation

- [Main Architecture Document](./05multiclustergitopsarchitecture_setup.md)
- [Promotion Strategy](./promotion-rollback/promotion-strategy.md)
- [Flux Manifests](./flux-manifests/)
- [Security Configurations](./security/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in this repository
- Contact the platform team
- Check the documentation

---

**Note**: This is a reference implementation. Adapt the configurations to match your specific requirements and security policies.