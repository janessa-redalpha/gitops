# Exercise 03 Submission: Tag-Based Release Management

## Overview

This submission demonstrates a complete tag-based deployment strategy using FluxCD, where Git tags represent immutable application versions that can be deployed to Kubernetes clusters.

## Strategy Chosen: Fixed Tag with Manual Promotion

I implemented the **Fixed Tag Strategy** because it provides:
- ✅ Complete control over version promotion
- ✅ Clear audit trail of what's deployed
- ✅ Predictable deployment behavior
- ✅ Compliance with change management processes
- ✅ Easy rollback to any previous version

## Part 1: YAML Manifests

### GitRepository for Fixed Tag

**File**: `gitrepository-fixed-tag.yaml`

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: versioned-app-fixed
  namespace: flux-system
spec:
  interval: 5m
  url: https://github.com/janessa-redalpha/gitops
  ref:
    tag: v1.2.0
  secretRef:
    name: gitops-repo-auth
```

**Key Configuration**:
- `interval: 5m` - Check for updates every 5 minutes
- `ref.tag: v1.2.0` - Points to specific tag (updated from v1.0.0)
- Uses authentication via secret reference
- Immutable: Tag doesn't change unless manually updated

### Kustomization for Fixed Tag

**File**: `kustomization-fixed-tag.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: versioned-app-fixed
  namespace: flux-system
spec:
  interval: 5m
  sourceRef:
    kind: GitRepository
    name: versioned-app-fixed
  path: ./apps/versioned-app/base
  prune: true
  targetNamespace: version-fixed
  wait: true
  timeout: 3m
```

**Key Configuration**:
- References `versioned-app-fixed` GitRepository
- Deploys to `version-fixed` namespace
- `prune: true` - Automatically removes deleted resources
- `wait: true` - Waits for resources to be ready

### GitRepository for Semver (Bonus)

**File**: `gitrepository-semver.yaml`

```yaml
---
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: versioned-app-semver
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/janessa-redalpha/gitops
  ref:
    semver: "^1.0.0"  # Automatically tracks latest 1.x version
  secretRef:
    name: gitops-repo-auth
```

**Key Configuration**:
- `ref.semver: "^1.0.0"` - Automatically picks latest 1.x tag
- Faster interval (1m) for quick updates
- Follows semantic versioning rules

### Kustomization for Semver (Bonus)

**File**: `kustomization-semver.yaml`

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: versioned-app-semver
  namespace: flux-system
spec:
  interval: 2m
  sourceRef:
    kind: GitRepository
    name: versioned-app-semver
  path: ./apps/versioned-app/base
  prune: true
  targetNamespace: version-semver
  wait: true
  timeout: 3m
```

## Part 2: Git Tags Created

### Tag Timeline

| Tag    | Commit SHA | Date | Description |
|--------|------------|------|-------------|
| v1.0.0 | 4955617a   | Initial | Initial stable release with 2 replicas |
| v1.1.0 | 65692c55   | +5min  | Minor feature additions, updated version label |
| v1.2.0 | b49abd4e   | +10min | Resource optimization, reduced to 1 replica |

### Tag Creation Commands

```bash
# Created v1.0.0
git tag -a v1.0.0 -m "Release v1.0.0 - Initial stable release"
git push origin v1.0.0

# Created v1.1.0
git tag -a v1.1.0 -m "Release v1.1.0 - Minor feature additions"
git push origin v1.1.0

# Created v1.2.0
git tag -a v1.2.0 -m "Release v1.2.0 - Resource optimization"
git push origin v1.2.0
```

### Verify Tags Exist

```bash
$ git tag -l "v1.*"
v1.0.0
v1.1.0
v1.2.0

$ git show v1.2.0 --no-patch
tag v1.2.0
Tagger: ...
Date:   Wed Oct 8 16:30:00 2025

Release v1.2.0 - Resource optimization

commit b49abd4e...
```

## Part 3: Output Before and After Creating New Tag

### BEFORE: Initial Deployment with v1.0.0

**Command**: `flux get sources git -A`

```
NAMESPACE      NAME                    REVISION                SUSPENDED  READY  MESSAGE
flux-system    flux-system             main@sha1:65692c55     False      True   stored artifact for revision 'main@sha1:65692c55'
flux-system    gitops-repo             main@sha1:65692c55     False      True   stored artifact for revision 'main@sha1:65692c55'
flux-system    gitops-repo-dev         dev@sha1:ab6b79be      False      True   stored artifact for revision 'dev@sha1:ab6b79be'
flux-system    gitops-repo-prod        prod@sha1:ab6b79be     False      True   stored artifact for revision 'prod@sha1:ab6b79be'
flux-system    gitops-repo-staging     staging@sha1:ab6b79be  False      True   stored artifact for revision 'staging@sha1:ab6b79be'
flux-system    versioned-app-fixed     v1.0.0@sha1:4955617a   False      True   stored artifact for revision 'v1.0.0@sha1:4955617a'
```

**Key Observation**: 
- `versioned-app-fixed` is tracking tag **v1.0.0**
- Revision SHA: `4955617a`
- Status: READY

### AFTER: Updated to v1.2.0 After Creating New Tag

**Step 1**: Created new tag v1.2.0
```bash
git tag -a v1.2.0 -m "Release v1.2.0 - Resource optimization"
git push origin v1.2.0
```

**Step 2**: Updated GitRepository manifest to point to v1.2.0
```bash
# Changed ref.tag from v1.0.0 to v1.2.0
kubectl apply -f gitrepository-fixed-tag.yaml
```

**Step 3**: FluxCD automatically detected the change

**Command**: `flux get sources git -A`

```
NAMESPACE      NAME                    REVISION                SUSPENDED  READY  MESSAGE
flux-system    flux-system             main@sha1:65692c55     False      True   stored artifact for revision 'main@sha1:65692c55'
flux-system    gitops-repo             main@sha1:b49abd4e     False      True   stored artifact for revision 'main@sha1:b49abd4e'
flux-system    gitops-repo-dev         dev@sha1:ab6b79be      False      True   stored artifact for revision 'dev@sha1:ab6b79be'
flux-system    gitops-repo-prod        prod@sha1:ab6b79be     False      True   stored artifact for revision 'prod@sha1:ab6b79be'
flux-system    gitops-repo-staging     staging@sha1:ab6b79be  False      True   stored artifact for revision 'staging@sha1:ab6b79be'
flux-system    versioned-app-fixed     v1.2.0@sha1:b49abd4e   False      True   stored artifact for revision 'v1.2.0@sha1:b49abd4e'
```

**Key Changes**: 
- ✅ `versioned-app-fixed` updated from **v1.0.0** to **v1.2.0**
- ✅ Revision SHA changed from `4955617a` to `b49abd4e`
- ✅ Status remains READY
- ✅ Automatic deployment to cluster triggered

### Comparison

| Aspect | BEFORE (v1.0.0) | AFTER (v1.2.0) | Changed |
|--------|-----------------|----------------|---------|
| Tag | v1.0.0 | v1.2.0 | ✅ Yes |
| Commit SHA | 4955617a | b49abd4e | ✅ Yes |
| Ready Status | True | True | No |
| Deployment | 2 replicas | 1 replica | ✅ Yes |

## Part 4: Deployment Verification

### Kustomization Status

```bash
$ flux get kustomizations -A | grep versioned
flux-system  versioned-app-fixed   v1.2.0@sha1:b49abd4e  False  True  Applied revision: v1.2.0@sha1:b49abd4e
```

**Result**: ✅ Kustomization successfully applied the new version

### Pod Deployment

```bash
$ kubectl get pods -n version-fixed
NAME                             READY   STATUS    RESTARTS   AGE
versioned-app-85864bbf94-xrwbr   1/1     Running   0          2m
```

**Verification**:
```bash
$ kubectl get pod -n version-fixed -o jsonpath='{.items[0].spec.containers[0].env[?(@.name=="APP_VERSION")].value}'
1.1.0
```

## Tag-Based Deployment Process

### Process Flow

```
1. Developer commits code
   ↓
2. CI/CD tests pass
   ↓
3. Create annotated Git tag
   git tag -a v1.x.x -m "Release description"
   ↓
4. Push tag to remote
   git push origin v1.x.x
   ↓
5. Update GitRepository manifest (fixed tag)
   Change ref.tag to new version
   ↓
6. Apply GitRepository
   kubectl apply -f gitrepository-fixed-tag.yaml
   ↓
7. FluxCD detects change
   Fetches new tag artifact
   ↓
8. Kustomization reconciles
   Applies new manifests to cluster
   ↓
9. Kubernetes updates pods
   Rolling update to new version
   ↓
10. Verification
    Check pod status and app version
```

### Promotion Strategy

#### Development → Staging → Production

1. **Development**: Use semver range (`^1.0.0`) for automatic updates
2. **Staging**: Use semver range (`~1.2.0`) for patch updates
3. **Production**: Use fixed tags for manual, controlled promotion

#### Promotion Example

```bash
# After testing in staging, promote to production
# 1. Update production GitRepository
sed -i 's/tag: v1.1.0/tag: v1.2.0/' gitrepository-prod.yaml

# 2. Apply the change
kubectl apply -f gitrepository-prod.yaml

# 3. Monitor the rollout
kubectl rollout status deployment/versioned-app -n production

# 4. Verify version
flux get sources git versioned-app-prod -n flux-system
```

## Advantages of Tag-Based Strategy

### ✅ Benefits Demonstrated

1. **Immutability**: Tags don't change, ensuring consistent deployments
   - v1.0.0 always refers to commit `4955617a`
   - No "tag moved" surprises

2. **Version Control**: Clear versioning with semantic versioning
   - v1.0.0 → v1.1.0 → v1.2.0
   - Follows industry standards

3. **Easy Rollback**: Simply point to previous tag
   ```bash
   # Rollback from v1.2.0 to v1.0.0
   kubectl patch gitrepository versioned-app-fixed -n flux-system \
     --type=json -p='[{"op": "replace", "path": "/spec/ref/tag", "value":"v1.0.0"}]'
   ```

4. **Audit Trail**: Complete history in Git
   ```bash
   git log --tags --oneline
   ```

5. **Multiple Environments**: Different environments run different tags
   - Dev: latest/main branch
   - Staging: v1.2.0
   - Prod: v1.1.0 (tested version)

6. **Release Management**: Aligns with traditional release processes
   - Tag represents a release
   - Can create GitHub/GitLab releases
   - Integrates with CI/CD pipelines

## Comparison: Fixed Tag vs Semver

### Fixed Tag (Implemented)

**Pros**:
- ✅ Complete control over versions
- ✅ Predictable deployments
- ✅ Compliance friendly
- ✅ Clear approval gates

**Cons**:
- ⚠️ Requires manual updates
- ⚠️ Slower to receive updates
- ⚠️ More operational overhead

### Semver Range

**Pros**:
- ✅ Automatic updates
- ✅ Less manual work
- ✅ Faster patch deployment
- ✅ Good for non-prod

**Cons**:
- ⚠️ Less control
- ⚠️ Potential for surprises
- ⚠️ Requires good tagging discipline
- ⚠️ May not meet compliance requirements

## Best Practices Implemented

1. ✅ **Semantic Versioning**: Used v1.0.0, v1.1.0, v1.2.0 format
2. ✅ **Annotated Tags**: Used `git tag -a` with messages
3. ✅ **Meaningful Messages**: Clear descriptions for each tag
4. ✅ **Tag Prefix**: Consistent 'v' prefix
5. ✅ **Namespace Isolation**: Separate namespace per strategy
6. ✅ **Authentication**: Secure access with secret reference
7. ✅ **Prune Enabled**: Automatic cleanup of deleted resources
8. ✅ **Health Checks**: Wait and timeout configured

## Troubleshooting Notes

### Issue Encountered: Resource Constraints

**Problem**: Initial deployment had 2 replicas, causing pods to remain in Pending state due to insufficient CPU on minikube.

**Solution**: 
1. Reduced replicas from 2 to 1
2. Created new tag v1.2.0 with the fix
3. Promoted to v1.2.0

**Learning**: Tag-based deployment allows quick fixes through new version tags.

## Rollback Procedure

### Quick Rollback

```bash
# 1. Identify previous working tag
git tag -l | sort -V

# 2. Update GitRepository to previous tag
kubectl patch gitrepository versioned-app-fixed -n flux-system \
  --type=json -p='[{"op": "replace", "path": "/spec/ref/tag", "value":"v1.0.0"}]'

# 3. Wait for FluxCD to reconcile
flux reconcile source git versioned-app-fixed -n flux-system

# 4. Verify rollback
flux get sources git versioned-app-fixed -n flux-system
kubectl get pods -n version-fixed -w
```

## Files Delivered

### Configuration Files
- ✅ `gitrepository-fixed-tag.yaml` - Fixed tag GitRepository
- ✅ `gitrepository-semver.yaml` - Semver GitRepository (bonus)
- ✅ `kustomization-fixed-tag.yaml` - Fixed tag Kustomization
- ✅ `kustomization-semver.yaml` - Semver Kustomization (bonus)

### Application Files
- ✅ `apps/versioned-app/base/deployment.yaml` - Application deployment
- ✅ `apps/versioned-app/base/service.yaml` - Application service
- ✅ `apps/versioned-app/base/kustomization.yaml` - Base kustomization

### Verification Outputs
- ✅ `flux-sources-before.txt` - State before tag update (v1.0.0)
- ✅ `flux-sources-after.txt` - State after tag update (v1.2.0)

### Documentation
- ✅ `README.md` - Complete exercise documentation
- ✅ `SUBMISSION.md` - This submission document

## Conclusion

This implementation successfully demonstrates tag-based release management with FluxCD:

### ✅ Achievements

1. **Created Multiple Tags**: v1.0.0, v1.1.0, v1.2.0 with semantic versioning
2. **Implemented Fixed Tag Strategy**: Manual promotion with full control
3. **Demonstrated Tag Promotion**: Successfully updated from v1.0.0 to v1.2.0
4. **Captured Before/After State**: Documented the transition
5. **Bonus: Semver Implementation**: Included automatic semver tracking
6. **Production-Ready**: Follows industry best practices
7. **Complete Documentation**: Comprehensive guides and procedures

### Key Learnings

1. Tags provide immutable reference points for releases
2. Fixed tags give maximum control for production environments
3. Semver ranges enable automation for development environments
4. Tag-based deployment aligns well with traditional release management
5. GitOps + Tags = Powerful version control for Kubernetes

### Repository Information

- **Repository**: https://github.com/janessa-redalpha/gitops
- **Tags**: v1.0.0, v1.1.0, v1.2.0
- **Strategy**: Fixed Tag with Manual Promotion
- **Status**: ✅ All Systems Operational

**Status: READY FOR SUBMISSION** 🎉
