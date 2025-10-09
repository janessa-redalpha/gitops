# Exercise 02: External Secret Management Setup - Submission


### Provider: HashiCorp Vault

**Why Vault?**
- Industry-standard secrets management solution
- Excellent Kubernetes integration
- Strong audit logging and access control
- Dynamic secrets support (future enhancement)
- Easy to set up in dev mode for demonstrations

**Authentication Method**:
- **Demo**: Static token authentication with root token
- **Production**: Should use Vault Kubernetes authentication method with ServiceAccount tokens

### Secret Consumption Method

The sample application consumes the secret using **environment variables** via `secretKeyRef`:

```yaml
env:
- name: MY_MESSAGE
  valueFrom:
    secretKeyRef:
      name: app-secret
      key: MY_MESSAGE
```

**Benefits of this approach**:
- Simple and widely supported
- No special volume mounts required
- Works with any container runtime

**Alternative approaches**:
- **`envFrom`**: Load all keys from a secret as environment variables
- **Volume mounts**: Mount secrets as files (better for large secrets or certificates)
- **CSI driver**: Use Secrets Store CSI Driver for more advanced scenarios
