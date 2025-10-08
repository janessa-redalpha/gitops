# Exercise 03: Tag-Based Release Management

## Goal
Implement a tag-based deployment strategy where FluxCD automatically deploys applications when new version tags are created.

## Overview

This exercise demonstrates how to use Git tags for immutable versioned releases with FluxCD. Tags represent specific points in history and are ideal for production releases.

## Implementation Strategies

### 1. Fixed Tag Strategy ✅
**Use Case**: Pin deployment to a specific version with manual promotion

**How It Works**:
- GitRepository points to a specific tag (e.g., `v1.0.0`)
- To promote, update the GitRepository to point to a new tag (e.g., `v1.2.0`)
- Provides complete control over which version is deployed
- Requires manual updates for version changes

**Best For**:
- Production environments
- Compliance requirements
- Controlled release processes
- Environments requiring approval gates

### 2. Semver Range Strategy
**Use Case**: Automatically track latest version within a semver range

**How It Works**:
- GitRepository uses semver constraint (e.g., `^1.0.0`)
- FluxCD automatically picks up new tags matching the range
- Follows semantic versioning rules
- Auto-updates within safe version ranges

**Best For**:
- Development/staging environments
- Patch/minor version auto-updates
- Rapid iteration cycles

## Directory Structure

```
exercise-03-tag-based-release-management/
├── gitrepository-fixed-tag.yaml    # Fixed tag strategy (v1.0.0 → v1.2.0)
├── gitrepository-semver.yaml       # Semver strategy (^1.0.0)
├── kustomization-fixed-tag.yaml    # Kustomization for fixed tag
├── kustomization-semver.yaml       # Kustomization for semver
├── flux-sources-before.txt         # State before tag update
├── flux-sources-after.txt          # State after tag update
├── README.md                       # This file
└── SUBMISSION.md                   # Submission documentation

apps/versioned-app/
└── base/
    ├── deployment.yaml
    ├── service.yaml
    └── kustomization.yaml
```

## Git Tags Created

| Tag | Commit | Description |
|-----|--------|-------------|
| v1.0.0 | 4955617 | Initial stable release |
| v1.1.0 | 65692c5 | Minor feature additions |
| v1.2.0 | b49abd4 | Resource optimization |

## Implementation Details

### Fixed Tag GitRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: versioned-app-fixed
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/janessa-redalpha/gitops
  ref:
    tag: v1.2.0  # Specific tag
  secretRef:
    name: gitops-repo-auth
```

**Key Features**:
- `interval: 5m` - Checks for updates every 5 minutes
- `ref.tag: v1.2.0` - Points to specific tag
- Requires manual update to change versions

### Semver GitRepository

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: versioned-app-semver
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/janessa-redalpha/gitops
  ref:
    semver: "^1.0.0"  # Automatically tracks latest 1.x
  secretRef:
    name: gitops-repo-auth
```

**Semver Patterns**:
- `^1.0.0` - Latest 1.x version (>=1.0.0 <2.0.0)
- `~1.2.0` - Latest 1.2.x version (>=1.2.0 <1.3.0)
- `>=1.0.0 <2.0.0` - Explicit range
- `*` - Latest tag (use with caution)

## Deployment Process

### Step 1: Create Initial Tags

```bash
# Create v1.0.0
git tag -a v1.0.0 -m "Release v1.0.0 - Initial stable release"
git push origin v1.0.0

# Create v1.1.0
git tag -a v1.1.0 -m "Release v1.1.0 - Minor feature additions"
git push origin v1.1.0

# Create v1.2.0
git tag -a v1.2.0 -m "Release v1.2.0 - Resource optimization"
git push origin v1.2.0
```

### Step 2: Apply GitRepository and Kustomization

```bash
# Create namespaces
kubectl create namespace version-fixed
kubectl create namespace version-semver

# Apply GitRepositories
kubectl apply -f gitrepository-fixed-tag.yaml
kubectl apply -f gitrepository-semver.yaml

# Apply Kustomizations
kubectl apply -f kustomization-fixed-tag.yaml
kubectl apply -f kustomization-semver.yaml
```

### Step 3: Verify Deployment

```bash
# Check GitRepository sources
flux get sources git -A

# Check Kustomizations
flux get kustomizations -A

# Check deployed pods
kubectl get pods -n version-fixed
kubectl get pods -n version-semver
```

### Step 4: Promote to New Version (Fixed Tag)

```bash
# Update GitRepository to point to new tag
# Edit gitrepository-fixed-tag.yaml: change tag from v1.0.0 to v1.2.0

# Apply the change
kubectl apply -f gitrepository-fixed-tag.yaml

# Force reconciliation (optional)
flux reconcile source git versioned-app-fixed -n flux-system

# Verify update
flux get sources git -A
```

## Verification Results

### Before Tag Update

```
NAMESPACE      NAME                    REVISION                READY  MESSAGE
flux-system    versioned-app-fixed     v1.0.0@sha1:4955617a   True   stored artifact for revision 'v1.0.0@sha1:4955617a'
```

### After Tag Update (v1.0.0 → v1.2.0)

```
NAMESPACE      NAME                    REVISION                READY  MESSAGE
flux-system    versioned-app-fixed     v1.2.0@sha1:b49abd4e   True   stored artifact for revision 'v1.2.0@sha1:b49abd4e'
```

**Result**: ✅ FluxCD successfully detected the tag change and updated the deployment from v1.0.0 to v1.2.0

## Release Workflow

### Creating a New Release

1. **Develop and Test**
   ```bash
   # Make changes to your app
   git add .
   git commit -m "Add new feature"
   ```

2. **Tag the Release**
   ```bash
   # Follow semantic versioning
   git tag -a v1.3.0 -m "Release v1.3.0 - New feature"
   git push origin v1.3.0
   ```

3. **Promote (Fixed Tag)**
   ```bash
   # Update GitRepository manifest
   sed -i 's/tag: v1.2.0/tag: v1.3.0/' gitrepository-fixed-tag.yaml
   kubectl apply -f gitrepository-fixed-tag.yaml
   ```

4. **Verify**
   ```bash
   flux get sources git versioned-app-fixed -n flux-system
   kubectl get pods -n version-fixed -w
   ```

## Advantages of Tag-Based Deployment

### ✅ Benefits

1. **Immutability**: Tags don't change, ensuring consistent deployments
2. **Traceability**: Clear history of what was deployed when
3. **Rollback**: Easy to revert to previous tag
4. **Semantic Versioning**: Follows industry standards
5. **Audit Trail**: Git history provides complete audit log
6. **Multiple Environments**: Different envs can run different tags

### ⚠️ Considerations

1. **Manual Promotion**: Fixed tags require manual updates
2. **Tag Management**: Need discipline to maintain clean tag history
3. **Coordination**: Teams must agree on tagging strategy
4. **Testing**: Tags should only be created for tested code

## Troubleshooting

### GitRepository Not Updating

```bash
# Force reconciliation
flux reconcile source git versioned-app-fixed -n flux-system

# Check logs
kubectl logs -n flux-system deploy/source-controller
```

### Wrong Tag Deployed

```bash
# Verify tag in manifest
kubectl get gitrepository versioned-app-fixed -n flux-system -o yaml | grep tag

# Update to correct tag
kubectl edit gitrepository versioned-app-fixed -n flux-system
```

### Pod Not Starting

```bash
# Check pod status
kubectl describe pod -n version-fixed <pod-name>

# Check kustomization
flux get kustomizations versioned-app-fixed -n flux-system
```

## Best Practices

1. **Use Semantic Versioning**
   - MAJOR.MINOR.PATCH (e.g., v1.2.3)
   - Increment MAJOR for breaking changes
   - Increment MINOR for new features
   - Increment PATCH for bug fixes

2. **Tag Naming Convention**
   - Prefix with 'v' (e.g., v1.0.0)
   - Use annotated tags (`git tag -a`)
   - Include meaningful messages

3. **Environment Strategy**
   - Dev: Use branch or semver range
   - Staging: Use semver range for automated testing
   - Prod: Use fixed tags with manual promotion

4. **Release Process**
   - Test thoroughly before tagging
   - Tag only from main/release branches
   - Document releases in CHANGELOG
   - Use GitHub/GitLab releases for notes

5. **Rollback Plan**
   - Keep previous tags accessible
   - Document rollback procedure
   - Test rollback in non-prod first

## Comparison: Branches vs Tags

| Aspect | Branches | Tags |
|--------|----------|------|
| Mutability | Mutable (commits added) | Immutable |
| Use Case | Active development | Stable releases |
| Promotion | Merge between branches | Update tag reference |
| Rollback | Revert commits | Point to previous tag |
| Best For | Continuous deployment | Versioned releases |

## Example Scenarios

### Scenario 1: Hotfix Release

```bash
# Create hotfix from prod tag
git checkout -b hotfix/1.2.1 v1.2.0
# Apply fix
git commit -m "Fix critical bug"
git tag -a v1.2.1 -m "Hotfix: Critical bug fix"
git push origin v1.2.1

# Promote to production
kubectl patch gitrepository versioned-app-fixed -n flux-system \
  --type=json -p='[{"op": "replace", "path": "/spec/ref/tag", "value":"v1.2.1"}]'
```

### Scenario 2: Staged Rollout

```bash
# Stage 1: Deploy to canary with new tag
# Use separate GitRepository with v1.3.0

# Stage 2: After validation, promote to prod
kubectl patch gitrepository versioned-app-fixed -n flux-system \
  --type=json -p='[{"op": "replace", "path": "/spec/ref/tag", "value":"v1.3.0"}]'
```

## Conclusion

Tag-based deployment provides a robust, auditable, and industry-standard approach to managing application releases. It works best when combined with:

- Semantic versioning
- Automated testing
- Clear release process
- Strong Git practices

For production environments, fixed tags offer the control and predictability needed for stable operations, while semver ranges can accelerate development cycles in lower environments.

