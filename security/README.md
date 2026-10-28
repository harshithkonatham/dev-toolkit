# Security & Compliance

A reference guide for security practices, secret management, and compliance standards.

---

## Table of Contents

1. [GitHub Security Setup](#1-github-security-setup)
2. [SSH Keys](#2-ssh-keys)
3. [Secret Management](#3-secret-management)
4. [Branch Protection](#4-branch-protection)
5. [DevSecOps Tooling](#5-devsecops-tooling)
6. [Pre-commit Security Hooks](#6-pre-commit-security-hooks)
7. [Compliance Checklist](#7-compliance-checklist)

---

## 1. GitHub Security Setup

### Two-Factor Authentication (2FA)
1. GitHub → Settings → Security → Enable 2FA
2. Use an authenticator app (1Password, Authy, or hardware key)
3. Save backup codes securely

### Dependabot Alerts
1. Repository → Settings → Security & analysis
2. Enable Dependabot alerts
3. Enable Dependabot security updates
4. Enable secret scanning

---

## 2. SSH Keys

```bash
# Generate key (Ed25519 is preferred over RSA)
ssh-keygen -t ed25519 -C "you@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
pbcopy < ~/.ssh/id_ed25519.pub

# Test connection
ssh -T git@github.com
```

Add the public key in GitHub → Settings → SSH and GPG keys.

---

## 3. Secret Management

### .env files — never commit

```bash
# .gitignore must include:
.env
.env.local
.env.*.local
*.pem
*.key
credentials.json
```

### GitHub Secrets (CI/CD)
```
Repository → Settings → Secrets and variables → Actions
→ New repository secret
```

Reference in workflow:
```yaml
env:
  API_KEY: ${{ secrets.API_KEY }}
```

### HashiCorp Vault (production secrets)

```bash
# Install
brew tap hashicorp/tap && brew install hashicorp/tap/vault

# Start dev server
vault server -dev

# Set env
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Store a secret
vault kv put secret/myapp API_KEY=xxx DB_PASSWORD=yyy

# Retrieve
vault kv get secret/myapp
vault kv get -field=API_KEY secret/myapp
```

### Doppler (SaaS secret management)

```bash
brew install dopplerhq/cli/doppler
doppler login
doppler setup
doppler run -- node server.js   # injects secrets as env vars
```

---

## 4. Branch Protection

Recommended settings for `main` branch:

1. Repository → Settings → Branches → Add rule
2. Apply to: `main`
3. Enable:
   - Require pull request reviews before merging (1 reviewer min)
   - Require status checks to pass before merging
   - Require branches to be up to date before merging
   - Restrict who can push to matching branches
   - Do not allow bypassing the above settings

---

## 5. DevSecOps Tooling

### Code Analysis

| Tool | Purpose | Setup |
|---|---|---|
| SonarQube | Code quality + security scan | `docker run -p 9000:9000 sonarqube` |
| Semgrep | Static analysis, SAST | `pip install semgrep && semgrep --config auto .` |
| CodeQL | GitHub-native deep analysis | Enabled via GitHub Advanced Security |
| Bandit | Python security linter | `pip install bandit && bandit -r .` |
| ESLint security | JS/TS security rules | `npm install eslint-plugin-security` |

### Dependency Scanning

```bash
# Node.js
npm audit
npm audit fix

# Python
pip install safety
safety check

# Docker images
docker scout cves my-image:latest
trivy image my-image:latest
```

### Secret Scanning

```bash
# gitleaks — scan git history for secrets
brew install gitleaks
gitleaks detect --source=. --verbose

# git-secrets — prevent committing secrets
brew install git-secrets
git secrets --install
git secrets --register-aws

# trufflehog — deep secret scanning
pip install trufflehog
trufflehog git file://. --only-verified
```

### Container Security

```bash
# Trivy — comprehensive vulnerability scanner
brew install trivy
trivy image python:3.12-slim
trivy fs .
trivy config .   # IaC scanning (Dockerfile, k8s, Terraform)

# Hadolint — Dockerfile linter
brew install hadolint
hadolint Dockerfile
```

---

## 6. Pre-commit Security Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.21.2
    hooks:
      - id: gitleaks

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: detect-private-key
      - id: check-added-large-files
      - id: check-merge-conflict
      - id: no-commit-to-branch
        args: [--branch, main]

  - repo: https://github.com/hadolint/hadolint
    rev: v2.12.0
    hooks:
      - id: hadolint

  - repo: https://github.com/PyCQA/bandit
    rev: 1.8.0
    hooks:
      - id: bandit
        args: ["-c", "pyproject.toml"]
```

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

---

## 7. Compliance Checklist

### Per Repository

- [ ] `.gitignore` covers `.env`, secrets, OS files
- [ ] Branch protection enabled on `main`
- [ ] Dependabot alerts enabled
- [ ] Secret scanning enabled (GitHub Advanced Security)
- [ ] `pre-commit` hooks installed with secret scanning
- [ ] No secrets in git history (check with `gitleaks`)
- [ ] All contributors using 2FA
- [ ] Third-party dependencies audited (`npm audit` / `safety check`)
- [ ] Docker images scanned (`trivy`)

### For Production Apps

- [ ] Secrets stored in vault (Vault / Doppler / AWS Secrets Manager)
- [ ] Environment variables injected at runtime, not baked into images
- [ ] Least-privilege IAM roles for cloud resources
- [ ] TLS/HTTPS enforced everywhere
- [ ] Rate limiting on all public APIs
- [ ] Input validation + parameterized queries (prevent SQLi/XSS)
- [ ] Audit logging enabled
- [ ] Incident response runbook documented
