# DevSecOps — Security Shifted Left

> Integrate security at every stage of the development lifecycle, not just at the end.

## DevSecOps Maturity Model

```
Level 1: Reactive        → Fix vulns when discovered in production
Level 2: Preventive      → Scan in CI, block on critical issues
Level 3: Proactive       → Threat modeling, SAST/DAST, SCA
Level 4: Continuous      → Real-time monitoring, automated remediation
Level 5: Predictive      → AI-driven threat detection, zero-trust
```

## Pipeline Security Gates

```
Code Push
    │
    ▼
Pre-commit Hooks
├── git-secrets (no credentials)
├── gitleaks (secret scanning)
└── semgrep --pre-commit

PR Created
    │
    ▼
CI Security Checks
├── SAST: Semgrep, CodeQL, Bandit
├── SCA: Snyk, OSV Scanner, npm audit
├── Secret scan: Gitleaks, TruffleHog
└── IaC scan: Checkov, tfsec

Image Build
    │
    ▼
Container Security
├── Dockerfile lint: Hadolint
├── Image scan: Trivy, Grype, Snyk
├── SBOM generation: Syft
└── Image signing: Cosign (Sigstore)

Deploy to K8s
    │
    ▼
Runtime Security
├── Policy: OPA/Gatekeeper, Kyverno
├── Runtime: Falco
├── Network: Cilium Network Policies
└── Secrets: External Secrets Operator

Production
    │
    ▼
Continuous Monitoring
├── DAST: OWASP ZAP, Nuclei
├── Dependency updates: Renovate
└── Compliance: OpenSCAP, Cloud Security Posture
```

## Supply Chain Security (SLSA)

SLSA (Supply chain Levels for Software Artifacts) is a framework for securing the software supply chain.

```bash
# Generate SBOM (Software Bill of Materials) with Syft
brew install syft

# Generate SBOM for local directory
syft . -o spdx-json=sbom.spdx.json
syft . -o cyclonedx-json=sbom.cyclonedx.json

# Generate SBOM for Docker image
syft your-image:tag -o spdx-json=image-sbom.spdx.json

# Scan SBOM for vulnerabilities with Grype
brew install grype
grype sbom:sbom.spdx.json
grype your-image:tag --fail-on high
```

### Sign Images with Cosign (Sigstore)

```bash
# Install cosign
brew install cosign

# Generate key pair
cosign generate-key-pair

# Sign an image (keyless with OIDC in CI)
cosign sign --yes ghcr.io/your-org/your-image:latest

# Verify signature
cosign verify --certificate-identity-regexp="https://github.com/your-org" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/your-org/your-image:latest

# Sign with in-toto attestation (includes SBOM)
cosign attest --predicate sbom.spdx.json \
  --type spdxjson \
  ghcr.io/your-org/your-image:latest
```

## Container Security

```bash
# Trivy — comprehensive vulnerability scanner
brew install trivy

# Scan image
trivy image --severity HIGH,CRITICAL your-image:latest

# Scan local filesystem
trivy fs --severity HIGH,CRITICAL .

# Scan IaC (Terraform, Kubernetes YAML)
trivy config ./terraform/
trivy config ./k8s/

# Scan in CI (fail on critical)
trivy image --exit-code 1 --severity CRITICAL your-image:latest

# Generate SARIF for GitHub Security tab
trivy image --format sarif --output trivy-results.sarif your-image:latest
```

### Hadolint — Dockerfile Best Practices

```bash
# Install
brew install hadolint

# Lint Dockerfile
hadolint Dockerfile

# In CI
docker run --rm -i hadolint/hadolint < Dockerfile

# Common issues it catches:
# DL3007: Using :latest tag — use specific version
# DL3008: Pin apt-get versions
# DL3013: Pin pip versions
# DL3025: Use JSON notation for CMD/ENTRYPOINT
# DL3045: COPY to absolute destination
```

## SAST — Static Analysis

```bash
# Semgrep — fast, OSS SAST
pip install semgrep

# Run security audit rules
semgrep --config p/security-audit .
semgrep --config p/owasp-top-ten .
semgrep --config p/python .
semgrep --config p/javascript .
semgrep --config p/secrets .

# Custom rules
semgrep --config semgrep-rules/ .

# Output as SARIF for GitHub
semgrep --config p/security-audit --sarif > semgrep.sarif
```

```bash
# Bandit — Python-specific SAST
pip install bandit

# Scan Python code
bandit -r . -f json -o bandit-report.json
bandit -r . -ll  # Only high severity

# Key checks:
# B101: assert statements in production code
# B102: exec usage
# B105/B106: hardcoded passwords
# B201: Flask debug mode
# B301: pickle deserialization
# B601/B602: shell injection
```

## Secret Scanning

```bash
# Gitleaks — scan for secrets in git history
brew install gitleaks

# Scan entire repo (including history)
gitleaks detect --source . --verbose

# Scan staged changes (pre-commit hook)
gitleaks protect --staged

# Scan specific branch
gitleaks detect --source . --log-opts "main..HEAD"

# Custom config for allowlists
gitleaks detect --config .gitleaks.toml

# TruffleHog — more comprehensive, checks entropy
pip install trufflesecurity
trufflehog git file://. --only-verified
trufflehog github --org=your-org --only-verified
```

## Kubernetes Security

```bash
# Kyverno — Kubernetes-native policy engine
helm repo add kyverno https://kyverno.github.io/kyverno/
helm install kyverno kyverno/kyverno -n kyverno --create-namespace

# Apply policies
kubectl apply -f policies/require-non-root.yaml
kubectl apply -f policies/disallow-latest-tag.yaml
kubectl apply -f policies/require-resource-limits.yaml

# OPA/Gatekeeper
helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --create-namespace

# Falco — runtime security (detects container breakouts, privilege escalation)
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm install falco falcosecurity/falco --namespace falco --create-namespace \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true
```

### Pod Security Policy (example)

```yaml
# policies/require-non-root.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-non-root
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-runAsNonRoot
      match:
        any:
        - resources:
            kinds: [Pod]
      validate:
        message: "Containers must not run as root"
        pattern:
          spec:
            containers:
              - securityContext:
                  runAsNonRoot: true
                  allowPrivilegeEscalation: false
                  readOnlyRootFilesystem: true
```

## IaC Security

```bash
# Checkov — scan Terraform, CloudFormation, Kubernetes YAML
pip install checkov

# Scan Terraform
checkov -d ./terraform/ --framework terraform

# Scan Kubernetes manifests
checkov -d ./k8s/ --framework kubernetes

# Scan Docker Compose
checkov -f docker-compose.yaml --framework compose

# Output for GitHub Actions
checkov -d . --output-format sarif --output-file-path . 

# tfsec — Terraform-specific
brew install tfsec
tfsec . --format sarif > tfsec-results.sarif
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/security_pipeline.sh` | Full security scan pipeline |
| `scripts/sbom_generate.sh` | Generate and sign SBOM |
| `scripts/vuln_report.py` | Aggregate vulnerability report |
| `scripts/secrets_audit.sh` | Scan for secrets across repos |
| `policies/` | Kyverno/OPA policy library |
