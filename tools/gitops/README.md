# GitOps — Git as the Single Source of Truth

> Everything is code. Changes go through Git. Systems self-reconcile to match Git state.

## GitOps Principles

1. **Declarative** — Describe desired state, not imperative steps
2. **Versioned** — All state stored in Git with full history
3. **Automatic** — Software agents automatically apply changes
4. **Continuous** — Constantly reconcile actual vs desired state

## Stack Overview

```
Developer
    │ git push
    ▼
GitHub Repo (Source of Truth)
    │
    ├── .github/workflows/    ← CI: Build, Test, Security Scan
    │         │
    │         └── Push image → Container Registry
    │
    └── k8s/manifests/        ← CD: Desired Kubernetes state
              │
              ▼
          ArgoCD (GitOps Agent)
              │ watches + reconciles
              ▼
          Kubernetes Cluster
```

## Modules

| Module | Purpose |
|--------|---------|
| `github-actions/` | Reusable CI/CD workflow templates |
| `argocd/` | ArgoCD ApplicationSet configs |
| `flux/` | FluxCD alternatives |
| `scripts/` | GitOps automation helpers |

## GitHub Actions Workflows

### Complete CI/CD Pipeline

```bash
# Trigger: Push to main, or PR opened
# Pipeline stages:
# 1. Code Quality (lint, type-check, format)
# 2. Unit Tests + Coverage
# 3. Security Scan (Trivy, Semgrep, Gitleaks)
# 4. Build Docker image
# 5. Push to registry (GHCR / ECR / GCR)
# 6. Deploy to staging (auto)
# 7. Smoke tests
# 8. Deploy to production (manual gate)
```

See `github-actions/ci-cd.yml` for complete implementation.

### Reusable Workflows

```yaml
# Call a reusable workflow from any repo
jobs:
  deploy:
    uses: your-org/platform-workflows/.github/workflows/deploy.yml@main
    with:
      service: payment-service
      environment: production
      image-tag: ${{ needs.build.outputs.image-tag }}
    secrets: inherit
```

## ArgoCD Setup

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Install ArgoCD CLI
brew install argocd

# Login
argocd login localhost:8080 --username admin --password <password>

# Register cluster
argocd cluster add my-cluster --name production

# Create application
argocd app create payment-service \
  --repo https://github.com/your-org/k8s-config \
  --path apps/payment-service/production \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace payment-service \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

## Progressive Delivery with Argo Rollouts

```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts \
  -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
brew install argoproj/tap/kubectl-argo-rollouts
```

```yaml
# Canary deployment — gradually shift traffic
apiVersion: argoproj.io/v1alpha1
kind: Rollout
spec:
  strategy:
    canary:
      steps:
      - setWeight: 5    # 5% traffic to new version
      - pause: {duration: 5m}
      - analysis:       # Auto-promote if error rate < 1%
          templates:
          - templateName: success-rate
      - setWeight: 50
      - pause: {duration: 10m}
      - setWeight: 100  # Full rollout
```

## Environment Promotion Flow

```
feature-branch  →  PR  →  merge to main
                              │
                    ┌─────────▼──────────┐
                    │   dev (auto-sync)   │
                    └─────────┬──────────┘
                              │ promote (script)
                    ┌─────────▼──────────┐
                    │  staging (auto)     │
                    └─────────┬──────────┘
                              │ manual approval
                    ┌─────────▼──────────┐
                    │  production        │
                    └────────────────────┘
```

```bash
# Promote image from staging to production
./scripts/promote.sh --service payment-service --from staging --to production
```

## Image Tag Strategy

```bash
# Immutable tags — NEVER use :latest in production
# Pattern: {service}-{git-sha}-{date}
IMAGE_TAG="${SERVICE}-${GITHUB_SHA::8}-$(date +%Y%m%d)"

# Or use semantic versioning for releases
# Pattern: v1.2.3
git tag v1.2.3
git push origin v1.2.3
```

## GitOps Security

```bash
# Seal secrets with Sealed Secrets (never store raw secrets in Git)
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Or use External Secrets Operator to fetch from AWS Secrets Manager
kubectl apply -f external-secrets/payment-service-secrets.yaml
```

## Drift Detection

```bash
# ArgoCD detects and alerts on config drift
argocd app diff payment-service

# Force sync to Git state (rolls back manual changes)
argocd app sync payment-service --force

# Get sync status of all apps
argocd app list
```
