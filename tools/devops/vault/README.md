# HashiCorp Vault - Secrets Management

## Overview

HashiCorp Vault is a tool for securely managing secrets, encryption keys, and sensitive data. It provides a unified interface to access secrets while maintaining tight access control and recording a detailed audit log.

### Why Use Vault?

| Challenge | How Vault Solves It |
|-----------|-------------------|
| Secrets sprawl | Centralized secret storage with a single API |
| Static credentials | Dynamic secrets with automatic rotation and TTLs |
| Encryption complexity | Encryption as a Service (transit engine) |
| Access control | Identity-based policies and fine-grained ACLs |
| Audit requirements | Complete audit log of every secret access |
| Multi-cloud secrets | Unified interface across AWS, GCP, Azure |

---

## Installation and Setup

### Method 1: Binary Installation

```bash
# macOS
brew install vault

# Linux (Ubuntu/Debian)
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# Verify
vault --version
```

### Method 2: Docker

```bash
# Development mode (not for production)
docker run -d --name vault \
  -p 8200:8200 \
  -e 'VAULT_DEV_ROOT_TOKEN_ID=my-root-token' \
  hashicorp/vault:latest

# Production mode with config
docker run -d --name vault \
  -p 8200:8200 \
  -v /vault/config:/vault/config \
  -v /vault/data:/vault/data \
  --cap-add=IPC_LOCK \
  hashicorp/vault:latest server
```

### Method 3: Helm (Kubernetes)

```bash
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  -f vault-values.yaml
```

Example `vault-values.yaml`:

```yaml
server:
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
  dataStorage:
    enabled: true
    size: 10Gi
    storageClass: gp3
  ingress:
    enabled: true
    hosts:
      - host: vault.example.com
  auditStorage:
    enabled: true
    size: 5Gi

ui:
  enabled: true
```

### Initialization and Unsealing

```bash
# Initialize Vault (first time only)
vault operator init -key-shares=5 -key-threshold=3

# Unseal (requires threshold number of keys)
vault operator unseal <key-1>
vault operator unseal <key-2>
vault operator unseal <key-3>

# Check status
vault status

# Login with root token
export VAULT_ADDR='http://127.0.0.1:8200'
vault login <root-token>
```

---

## Secret Engines

### KV (Key-Value) Secrets Engine

The most common engine for storing static secrets.

```bash
# Enable KV v2
vault secrets enable -path=secret kv-v2

# Write a secret
vault kv put secret/myapp/config \
  db_host="db.example.com" \
  db_user="admin" \
  db_pass="s3cur3P@ss"

# Read a secret
vault kv get secret/myapp/config
vault kv get -field=db_pass secret/myapp/config

# Read a specific version
vault kv get -version=2 secret/myapp/config

# List secrets
vault kv list secret/myapp/

# Delete a secret
vault kv delete secret/myapp/config

# Undelete (soft-deleted)
vault kv undelete -versions=3 secret/myapp/config

# Permanently destroy a version
vault kv destroy -versions=1,2 secret/myapp/config
```

### Database Secrets Engine

Generates dynamic, short-lived database credentials.

```bash
# Enable the database engine
vault secrets enable database

# Configure PostgreSQL connection
vault write database/config/my-postgres \
  plugin_name=postgresql-database-plugin \
  connection_url="postgresql://{{username}}:{{password}}@db.example.com:5432/mydb?sslmode=require" \
  allowed_roles="readonly,readwrite" \
  username="vault_admin" \
  password="vault_admin_pass"

# Create a role for read-only access
vault write database/roles/readonly \
  db_name=my-postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl="1h" \
  max_ttl="24h"

# Generate dynamic credentials
vault read database/creds/readonly
# Returns: username=v-token-readonly-xxxxx, password=yyyyy, lease_duration=1h
```

### AWS Secrets Engine

Generate dynamic AWS IAM credentials.

```bash
# Enable AWS engine
vault secrets enable aws

# Configure root credentials
vault write aws/config/root \
  access_key=AKIAIOSFODNN7EXAMPLE \
  secret_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  region=us-east-1

# Create a role
vault write aws/roles/s3-reader \
  credential_type=iam_user \
  policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": "*"
    }
  ]
}
EOF

# Generate credentials
vault read aws/creds/s3-reader
```

### PKI Secrets Engine

Manage TLS certificates as a Certificate Authority.

```bash
# Enable PKI engine
vault secrets enable pki

# Configure max TTL
vault secrets tune -max-lease-ttl=87600h pki

# Generate root CA
vault write pki/root/generate/internal \
  common_name="example.com" \
  ttl=87600h

# Create a role
vault write pki/roles/web-certs \
  allowed_domains="example.com" \
  allow_subdomains=true \
  max_ttl="720h"

# Issue a certificate
vault write pki/issue/web-certs \
  common_name="app.example.com" \
  ttl="24h"
```

### Transit Secrets Engine (Encryption as a Service)

```bash
# Enable transit engine
vault secrets enable transit

# Create an encryption key
vault write -f transit/keys/my-app-key

# Encrypt data
vault write transit/encrypt/my-app-key \
  plaintext=$(echo "secret data" | base64)

# Decrypt data
vault write transit/decrypt/my-app-key \
  ciphertext="vault:v1:xxxxx"

# Rotate the encryption key
vault write -f transit/keys/my-app-key/rotate
```

---

## Authentication Methods

### Token Auth (default)

```bash
# Create a token with a policy
vault token create -policy=my-policy -ttl=1h

# Create an orphan token (no parent)
vault token create -orphan -policy=my-policy

# Look up a token
vault token lookup <token>

# Revoke a token
vault token revoke <token>
```

### AppRole Auth (for machines/applications)

```bash
# Enable AppRole
vault auth enable approle

# Create a role
vault write auth/approle/role/my-app \
  token_policies="my-app-policy" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=10m \
  secret_id_num_uses=1

# Get role ID
vault read auth/approle/role/my-app/role-id

# Generate secret ID
vault write -f auth/approle/role/my-app/secret-id

# Login with AppRole
vault write auth/approle/login \
  role_id=<role-id> \
  secret_id=<secret-id>
```

### Kubernetes Auth

```bash
# Enable Kubernetes auth
vault auth enable kubernetes

# Configure with the cluster's API
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443" \
  token_reviewer_jwt="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# Create a role bound to a service account
vault write auth/kubernetes/role/my-app \
  bound_service_account_names=my-app-sa \
  bound_service_account_namespaces=my-namespace \
  policies=my-app-policy \
  ttl=1h
```

### OIDC Auth

```bash
vault auth enable oidc

vault write auth/oidc/config \
  oidc_discovery_url="https://accounts.google.com" \
  oidc_client_id="xxxxx.apps.googleusercontent.com" \
  oidc_client_secret="xxxxx" \
  default_role="reader"

vault write auth/oidc/role/reader \
  bound_audiences="xxxxx.apps.googleusercontent.com" \
  allowed_redirect_uris="http://localhost:8250/oidc/callback" \
  user_claim="sub" \
  policies="reader"
```

---

## Policies and Access Control

Policies are written in HCL (HashiCorp Configuration Language) and define what paths a token can access.

### Policy Syntax

```hcl
# my-app-policy.hcl

# Read-only access to app secrets
path "secret/data/myapp/*" {
  capabilities = ["read", "list"]
}

# Full access to own namespace
path "secret/data/myapp/config" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Deny access to admin secrets
path "secret/data/admin/*" {
  capabilities = ["deny"]
}

# Generate database credentials
path "database/creds/readonly" {
  capabilities = ["read"]
}

# Allow encryption/decryption via transit
path "transit/encrypt/my-app-key" {
  capabilities = ["update"]
}
path "transit/decrypt/my-app-key" {
  capabilities = ["update"]
}
```

### Managing Policies

```bash
# Write a policy
vault policy write my-app-policy my-app-policy.hcl

# List policies
vault policy list

# Read a policy
vault policy read my-app-policy

# Delete a policy
vault policy delete my-app-policy
```

### Capabilities Reference

| Capability | HTTP Verb | Description |
|------------|-----------|-------------|
| `create` | POST/PUT | Create new data |
| `read` | GET | Read data |
| `update` | POST/PUT | Modify existing data |
| `delete` | DELETE | Delete data |
| `list` | LIST | List keys at a path |
| `deny` | - | Explicit deny (overrides all) |
| `sudo` | - | Access root-protected paths |

---

## Dynamic Secrets

Dynamic secrets are generated on-demand and automatically revoked after their TTL expires.

### Workflow

```
Application --> Vault --> Generate Credentials --> Database
                  |
                  +--> TTL expires --> Revoke Credentials
```

### Lease Management

```bash
# List active leases
vault list sys/leases/lookup/database/creds/readonly

# Renew a lease
vault lease renew <lease-id>
vault lease renew -increment=2h <lease-id>

# Revoke a specific lease
vault lease revoke <lease-id>

# Revoke all leases under a prefix
vault lease revoke -prefix database/creds/readonly
```

---

## Integration with Kubernetes

### Vault Agent Injector

The Vault Agent Injector uses a mutating webhook to inject Vault Agent containers into pods.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "my-app"
        vault.hashicorp.com/agent-inject-secret-config.txt: "secret/data/myapp/config"
        vault.hashicorp.com/agent-inject-template-config.txt: |
          {{- with secret "secret/data/myapp/config" -}}
          DB_HOST={{ .Data.data.db_host }}
          DB_USER={{ .Data.data.db_user }}
          DB_PASS={{ .Data.data.db_pass }}
          {{- end }}
    spec:
      serviceAccountName: my-app-sa
      containers:
        - name: my-app
          image: my-app:latest
          volumeMounts:
            - name: vault-secrets
              mountPath: /vault/secrets
              readOnly: true
```

### External Secrets Operator with Vault

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "my-app"
          serviceAccountRef:
            name: my-app-sa
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: my-app-secrets
  data:
    - secretKey: db-password
      remoteRef:
        key: myapp/config
        property: db_pass
```

---

## Best Practices

1. **Never use the root token in production** - Create specific tokens with minimal policies for each use case. Revoke the root token after initial setup.

2. **Enable audit logging** - Always enable at least one audit device:
   ```bash
   vault audit enable file file_path=/vault/logs/audit.log
   ```

3. **Use dynamic secrets wherever possible** - Short-lived, automatically rotated credentials reduce the blast radius of a compromise.

4. **Implement least-privilege policies** - Grant only the minimum capabilities needed. Use `deny` explicitly for sensitive paths.

5. **Use namespaces for multi-tenancy** (Enterprise) - Isolate teams and environments with Vault namespaces.

6. **Automate unsealing** - Use auto-unseal with a cloud KMS (AWS KMS, GCP CKMS, Azure Key Vault) to avoid manual unsealing.
   ```bash
   # In vault config
   seal "awskms" {
     region     = "us-east-1"
     kms_key_id = "alias/vault-unseal-key"
   }
   ```

7. **Run Vault in HA mode** - Use Raft or Consul as the storage backend with multiple replicas.

8. **Rotate encryption keys regularly** - Use `vault operator rotate` for the master key and rotate transit keys on a schedule.

9. **Use response wrapping** - Wrap sensitive responses so they can only be unwrapped once:
   ```bash
   vault kv get -wrap-ttl=5m secret/myapp/config
   ```

10. **Back up Vault data** - Use Raft snapshots for backup:
    ```bash
    vault operator raft snapshot save backup.snap
    ```

---

## Resources

- [Vault Documentation](https://developer.hashicorp.com/vault/docs)
- [Vault Tutorials](https://developer.hashicorp.com/vault/tutorials)
- [Vault GitHub Repository](https://github.com/hashicorp/vault)
- [Vault Helm Chart](https://github.com/hashicorp/vault-helm)
- [Vault Agent Injector Guide](https://developer.hashicorp.com/vault/docs/platform/k8s/injector)
