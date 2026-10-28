# ArgoCD - GitOps Continuous Delivery for Kubernetes

## Overview

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of applications by synchronizing the desired state defined in Git repositories with the actual state running in Kubernetes clusters.

### What is GitOps?

GitOps is an operational framework that uses Git as the single source of truth for declarative infrastructure and application configuration. Core principles:

| Principle | Description |
|-----------|-------------|
| **Declarative** | The entire system is described declaratively |
| **Versioned** | The desired state is stored in Git, providing a full audit trail |
| **Automated** | Approved changes are automatically applied to the system |
| **Self-healing** | Agents ensure the actual state matches the desired state |

### Why Use ArgoCD?

- **Automated deployment** - Changes in Git trigger automatic deployments
- **Drift detection** - Detects when cluster state diverges from Git
- **Rollback** - Revert to any previous state by reverting a Git commit
- **Multi-cluster** - Manage deployments across multiple clusters from one place
- **SSO integration** - OIDC, LDAP, SAML, GitHub, GitLab, and more
- **RBAC** - Fine-grained access control for teams and projects
- **Web UI and CLI** - Rich interfaces for managing applications

---

## Installation

### Prerequisites

- A running Kubernetes cluster (v1.24+)
- `kubectl` configured with cluster access
- `helm` (for Helm-based installation)

### Method 1: Kubernetes Manifests

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Verify pods are running
kubectl get pods -n argocd

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Method 2: Helm Chart

```bash
# Add the ArgoCD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install with default values
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace

# Install with custom values
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f values.yaml
```

Example `values.yaml`:

```yaml
server:
  replicas: 2
  ingress:
    enabled: true
    hosts:
      - argocd.example.com
    tls:
      - secretName: argocd-tls
        hosts:
          - argocd.example.com

controller:
  replicas: 1

redis:
  enabled: true

configs:
  params:
    server.insecure: false
```

### Install the ArgoCD CLI

```bash
# macOS
brew install argocd

# Linux
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
argocd login argocd.example.com --username admin --password <password>
```

---

## Application CRDs

ArgoCD uses Custom Resource Definitions (CRDs) to define applications and their desired state.

### Application Resource

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/org/my-app.git
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### ApplicationSet Resource

ApplicationSets generate Application resources from templates, useful for multi-cluster or multi-tenant deployments.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app-set
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            env: production
  template:
    metadata:
      name: '{{name}}-my-app'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/my-app.git
        targetRevision: main
        path: k8s/overlays/{{metadata.labels.env}}
      destination:
        server: '{{server}}'
        namespace: my-app
```

### AppProject Resource

Projects provide logical grouping and access control for applications.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: "Team Alpha project"
  sourceRepos:
    - 'https://github.com/org/team-alpha-*'
  destinations:
    - namespace: 'team-alpha-*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
  roles:
    - name: developer
      description: Developer access
      policies:
        - p, proj:team-alpha:developer, applications, get, team-alpha/*, allow
        - p, proj:team-alpha:developer, applications, sync, team-alpha/*, allow
```

---

## Sync Strategies

### Automatic Sync

ArgoCD automatically applies changes when it detects drift between Git and the cluster.

```yaml
syncPolicy:
  automated:
    prune: true        # Delete resources removed from Git
    selfHeal: true     # Revert manual changes in the cluster
    allowEmpty: false   # Do not allow deleting all resources
```

### Manual Sync

Requires explicit user action to deploy changes.

```bash
# Sync via CLI
argocd app sync my-app

# Sync specific resources
argocd app sync my-app --resource ':Deployment:my-app'

# Sync with dry run
argocd app sync my-app --dry-run

# Preview diff before syncing
argocd app diff my-app
```

### Sync Waves and Hooks

Control the order of resource deployment using annotations.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
        - name: migrate
          image: my-app:latest
          command: ["./migrate.sh"]
      restartPolicy: Never
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

| Hook | When It Runs |
|------|-------------|
| `PreSync` | Before the sync operation |
| `Sync` | During the sync, after PreSync |
| `PostSync` | After all Sync hooks completed successfully |
| `SyncFail` | When the sync operation fails |
| `Skip` | Skips the resource during sync |

---

## Multi-Cluster Management

### Register External Clusters

```bash
# List current contexts
kubectl config get-contexts

# Add a cluster to ArgoCD
argocd cluster add my-staging-context --name staging

# List registered clusters
argocd cluster list
```

### Declarative Cluster Registration

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: staging-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: staging
  server: https://staging-api.example.com
  config: |
    {
      "bearerToken": "<token>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<base64-ca-cert>"
      }
    }
```

### ApplicationSet for Multi-Cluster

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-cluster-app
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - clusters:
              selector:
                matchLabels:
                  env: production
          - git:
              repoURL: https://github.com/org/config.git
              revision: main
              files:
                - path: "envs/{{name}}/config.json"
  template:
    metadata:
      name: '{{name}}-app'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/my-app.git
        targetRevision: main
        path: k8s
        helm:
          valueFiles:
            - values-{{values.env}}.yaml
      destination:
        server: '{{server}}'
        namespace: my-app
```

---

## SSO Integration

### OIDC (e.g., Keycloak, Okta)

Edit the `argocd-cm` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Okta
    issuer: https://org.okta.com/oauth2/default
    clientID: xxxxxxxxx
    clientSecret: $oidc.okta.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
      - groups
```

### RBAC Configuration

Edit `argocd-rbac-cm` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    g, dev-team, role:developer
    g, ops-team, role:admin
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, create, */*, deny
    p, role:developer, applications, delete, */*, deny
```

---

## Key CLI Commands

```bash
# Application management
argocd app create my-app --repo <url> --path <path> --dest-server <server> --dest-namespace <ns>
argocd app list
argocd app get my-app
argocd app sync my-app
argocd app delete my-app
argocd app history my-app
argocd app rollback my-app <history-id>

# Repository management
argocd repo add https://github.com/org/repo.git --username git --password <token>
argocd repo list

# Project management
argocd proj create team-alpha
argocd proj list

# Cluster management
argocd cluster add <context-name>
argocd cluster list
```

---

## Best Practices

1. **Use App of Apps pattern** - Manage ArgoCD applications themselves via Git using a root Application that points to a directory of Application manifests.

2. **Separate config from source code** - Keep Kubernetes manifests in a dedicated config repo, not alongside application source code.

3. **Use ApplicationSets over manual Application creation** - Reduce duplication and ensure consistency across environments.

4. **Enable automated sync with self-heal** - Let ArgoCD correct drift automatically in production-like environments.

5. **Use sync waves for dependencies** - Ensure databases and config are deployed before application pods.

6. **Implement RBAC from day one** - Restrict who can sync, create, or delete applications per project.

7. **Use Sealed Secrets or External Secrets** - Never store plain secrets in Git. Use tools like Sealed Secrets, External Secrets Operator, or Vault.

8. **Monitor sync status** - Set up alerts for applications that are OutOfSync or in a degraded state.

9. **Pin targetRevision in production** - Use tags or specific commit SHAs instead of branch names for production deployments.

10. **Use resource hooks for migrations** - Run database migrations as PreSync hooks to ensure they complete before new code deploys.

---

## Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD GitHub Repository](https://github.com/argoproj/argo-cd)
- [ApplicationSet Controller Docs](https://argocd-applicationset.readthedocs.io/)
- [GitOps Working Group](https://opengitops.dev/)
- [ArgoCD Autopilot](https://argocd-autopilot.readthedocs.io/)
