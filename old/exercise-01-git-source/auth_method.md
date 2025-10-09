# Authentication Method Selection

## Chosen Method: HTTPS with Personal Access Token (PAT)

### Rationale

I chose HTTPS authentication with a Personal Access Token for the following reasons:

1. **Simplicity**: HTTPS with PAT is easier to set up and manage compared to SSH keys. It requires only a username and token, without the need to manage SSH key pairs or known_hosts files.

2. **Compatibility**: HTTPS works seamlessly across different network environments, including corporate firewalls and proxies that might block SSH port 22.

3. **Token Rotation**: Personal Access Tokens can be easily rotated or revoked from the Git hosting platform (GitHub/GitLab) without regenerating SSH keys and updating multiple locations.

4. **Fine-grained Permissions**: Modern Git platforms like GitHub allow fine-grained PATs with specific repository access and limited permissions, enhancing security.

5. **Common Practice**: HTTPS with PAT is the most commonly used authentication method in modern CI/CD and GitOps workflows, making it easier to find documentation and community support.

### Security Considerations

- The PAT is stored as a Kubernetes Secret in the `flux-system` namespace
- Access to the secret is restricted by Kubernetes RBAC
- The token should have minimal required permissions (read-only access to the repository)
- Regular token rotation should be implemented as part of security best practices

### Configuration Details

- **Sync Interval**: Set to 1 minute for quick detection of changes
- **Kustomization Interval**: Set to 2 minutes with prune enabled for automatic cleanup
- **Secret Reference**: Uses `gitops-repo-auth` secret in the flux-system namespace

