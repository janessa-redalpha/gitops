# GitOps Fundamentals - Introduction

## 1. Core Principles

**Principle 1:** Git as the Single Source of Truth
- All infrastructure and application configurations are stored in Git repositories, making Git the authoritative source for the desired state of the system.

**Principle 2:** Declarative Configuration
- The entire system state is described declaratively using configuration files (manifests, Helm charts, etc.) rather than imperative commands or scripts.

**Principle 3:** Continuous Pull-Based Reconciliation
- Automated controllers continuously monitor Git repositories and pull changes to reconcile the actual cluster state with the desired state defined in Git.

## 2. Traditional vs GitOps Comparison

| Topic | Traditional CI/CD (Push) | GitOps (Pull) |
|-------|-------------------------|---------------|
| Who initiates deploys? | [x] CI pipeline pushes to cluster | [ ] Controller pulls from Git |
| Source of truth | [ ] CI job config | [x] Git repo (manifests/config) |
| How changes land | [ ] Manual apply/scripts | [x] PR merged → reconcile |
| Drift handling | [ ] Manual detection | [x] Auto-detect and correct |

## 3. Git as Truth

The desired state lives in Git repositories containing declarative configuration files (Kubernetes manifests, Helm charts, Terraform files, etc.). Updates occur through Git operations, such as when developers create pull requests with configuration changes, which are reviewed and merged into the main branch, triggering automatic reconciliation.

## 4. Deployment Model

The pull-based model uses automated controllers (like ArgoCD, Flux, or Jenkins X) that continuously watch Git repositories for changes. These controllers pull the latest configuration from Git and apply it to the target environment, ensuring the actual state matches the desired state without requiring external push mechanisms.

## 5. Workflow Pattern

Basic promotion flow using PRs:

• **Development**: Developers create feature branches and PRs with configuration changes for the dev environment

• **Staging Promotion**: After dev testing, create a PR to promote the same configuration to staging environment

• **Production Promotion**: Following staging validation, create a final PR to promote configuration to production

• **Automated Deployment**: Each PR merge triggers the GitOps controller to automatically deploy changes to the respective environment

## 6. Security Benefits

**Benefit 1:** Enhanced Audit Trail and Compliance
- All changes are tracked through Git history with commit messages, author information, and PR reviews, providing complete audit trails for compliance requirements.

**Benefit 2:** Reduced Attack Surface and Principle of Least Privilege
- GitOps eliminates the need for CI/CD systems to have direct cluster access, reducing the attack surface. Controllers only need read access to Git repositories and appropriate cluster permissions, following the principle of least privilege.
