# Tenancy Model Diagram and Explanation

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │           flux-system Namespace (Admin)                │   │
│  │  - FluxCD Controllers (source, kustomize, helm, etc.)  │   │
│  │  - Cluster-level reconciliation                        │   │
│  └────────────────────────────────────────────────────────┘   │
│                            │                                    │
│                            │ Manages                            │
│                            ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  team-a Namespace                       │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  ServiceAccount: flux-reconciler                 │  │  │
│  │  │  Role: Limited to team-a namespace only          │  │  │
│  │  │  RoleBinding: Binds SA to Role                   │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  GitRepository: team-a-apps                      │  │  │
│  │  │    - URL: github.com/team-a/apps                 │  │  │
│  │  │    - Auth: team-a-git-auth Secret                │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Kustomization: team-a-apps                      │  │  │
│  │  │    - Uses: flux-reconciler SA                    │  │  │
│  │  │    - Target: team-a namespace only               │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Application Resources                           │  │  │
│  │  │  (Deployments, Services, ConfigMaps, etc.)       │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                  team-b Namespace                       │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  ServiceAccount: flux-reconciler                 │  │  │
│  │  │  Role: Limited to team-b namespace only          │  │  │
│  │  │  RoleBinding: Binds SA to Role                   │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  GitRepository: team-b-apps                      │  │  │
│  │  │    - URL: github.com/team-b/apps                 │  │  │
│  │  │    - Auth: team-b-git-auth Secret                │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Kustomization: team-b-apps                      │  │  │
│  │  │    - Uses: flux-reconciler SA                    │  │  │
│  │  │    - Target: team-b namespace only               │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │  Application Resources                           │  │  │
│  │  │  (Deployments, Services, ConfigMaps, etc.)       │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

     ▲                                        ▲
     │                                        │
     │ Git Sync                               │ Git Sync
     │                                        │
┌────┴────────┐                      ┌───────┴─────┐
│  Team A     │                      │  Team B     │
│  Git Repo   │                      │  Git Repo   │
└─────────────┘                      └─────────────┘
```

### Tenancy Model Explanation

#### Core Design Principles

1. **Strong Namespace Boundaries**
   - Each tenant operates exclusively within their own namespace
   - Namespace labeled with `tenant: <name>` for easy identification
   - All tenant resources (RBAC, sources, kustomizations) co-located in tenant namespace

2. **Least Privilege RBAC**
   - Each tenant has a dedicated ServiceAccount (`flux-reconciler`)
   - Role (not ClusterRole) grants only namespace-scoped permissions
   - RoleBinding restricts the ServiceAccount to the tenant namespace
   - No cluster-wide permissions granted to any tenant

3. **Isolated Git Sources**
   - Each tenant has their own GitRepository resource
   - Separate Git authentication secrets per tenant
   - Option for dedicated repos OR monorepo with path isolation
   - Git credentials managed independently per tenant

4. **Constrained Reconcilers**
   - Kustomization resources use `serviceAccountName` to bind to tenant SA
   - `targetNamespace` explicitly set to tenant namespace
   - Flux controllers enforce RBAC during reconciliation
   - Resources deployed by Flux inherit the SA's limited permissions

5. **Defense in Depth**
   - RBAC prevents cross-namespace resource access
   - Flux reconcilers cannot escalate privileges
   - Each tenant operates in their own security boundary
   - Audit trail maintained through Git commits

#### Security Boundaries

```
┌─────────────────────────────────────────────────────────┐
│  Team A Boundary                                        │
│  ┌───────────────────────────────────────────────────┐ │
│  │ ✓ Can manage resources in team-a namespace       │ │
│  │ ✓ Can create Deployments, Services, ConfigMaps   │ │
│  │ ✓ Can manage Flux resources in team-a            │ │
│  │ ✗ Cannot access team-b namespace                 │ │
│  │ ✗ Cannot create ClusterRoles or ClusterRBs       │ │
│  │ ✗ Cannot list nodes or namespaces                │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Team B Boundary                                        │
│  ┌───────────────────────────────────────────────────┐ │
│  │ ✓ Can manage resources in team-b namespace       │ │
│  │ ✓ Can create Deployments, Services, ConfigMaps   │ │
│  │ ✓ Can manage Flux resources in team-b            │ │
│  │ ✗ Cannot access team-a namespace                 │ │
│  │ ✗ Cannot create ClusterRoles or ClusterRBs       │ │
│  │ ✗ Cannot list nodes or namespaces                │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```
