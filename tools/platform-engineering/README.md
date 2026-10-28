# Platform Engineering

> Build Internal Developer Platforms (IDPs) that give developers golden paths to production.

## What is Platform Engineering?

Platform Engineering is the practice of building self-service infrastructure and tooling that enables developers to ship faster without needing to become DevOps experts. The platform team acts as a product team whose customers are internal developers.

**Core principle:** Reduce cognitive load on developers. They shouldn't need to know Kubernetes internals, Terraform syntax, or CI/CD pipelines — just `git push`.

## Key Concepts

```
Developer Experience
        │
        ▼
┌───────────────────────────────────────────┐
│         Internal Developer Portal         │
│    (Backstage / Port / Cortex / Roadie)   │
├───────────────────────────────────────────┤
│              Golden Paths                 │
│  Templates for: APIs, Workers, ML models  │
├───────────────────────────────────────────┤
│          Self-Service Primitives          │
│  Deploy  │  Scale  │  Observe  │  Secure  │
├───────────────────────────────────────────┤
│         Abstraction Layer                 │
│  Kubernetes + Terraform + CI/CD + Secrets │
└───────────────────────────────────────────┘
```

## Modules

| Module | Tool | Purpose |
|--------|------|---------|
| `backstage/` | Backstage | Service catalog + developer portal |
| `port/` | Port | Modern IDP with scorecards |
| `golden-paths/` | Cookiecutter/Copier | Service templates |
| `idp/` | Custom | Platform APIs and self-service |
| `scorecard/` | Custom | Service maturity scoring |

## Quick Start: Backstage

```bash
# Install Backstage
npx @backstage/create-app@latest --name my-platform

cd my-platform
yarn dev  # Opens at http://localhost:3000

# Add GitHub integration
# Edit app-config.yaml:
integrations:
  github:
    - host: github.com
      token: ${GITHUB_TOKEN}

# Register a service component
# Create catalog-info.yaml in any repo (see backstage/catalog-info.yaml)
```

### Backstage Key Features

```bash
# Software Catalog — Discover all services/APIs/libraries
# TechDocs — Auto-generate docs from markdown
# Templates — Scaffold new services with one click
# Search — Find anything across the org

# Install TechDocs
yarn add --cwd packages/backend @backstage/plugin-techdocs-backend

# Add Kubernetes plugin for live service status
yarn add @backstage/plugin-kubernetes
yarn add --cwd packages/backend @backstage/plugin-kubernetes-backend
```

## Quick Start: Port (Modern IDP)

```bash
# Port is SaaS-based, no infrastructure needed
# Sign up at app.getport.io

# Install Port CLI
npm install -g @port-labs/port-cli

# Sync your catalog
port entities upsert --blueprint Service --identifier my-service \
  --property name="My Service" \
  --property language="Python" \
  --property tier="Tier 1"

# Create a self-service action
port actions create --config configs/port_deploy_action.yaml
```

## Service Scorecards

Scorecards enforce standards across all services automatically:

```yaml
# scorecard.yaml — Define what "production-ready" means
name: Production Readiness
rules:
  - name: Has README
    rule: hasReadme
    weight: 1

  - name: Has CI/CD
    rule: hasCICD
    weight: 2

  - name: Has Monitoring
    rule: hasMonitoring
    weight: 3

  - name: Has On-Call
    rule: hasOnCallRotation
    weight: 3

  - name: Has SLO Defined
    rule: hasSLO
    weight: 2

  - name: No Critical Vulnerabilities
    rule: noHighVulns
    weight: 5

levels:
  - name: Bronze
    minimum_score: 3
  - name: Silver
    minimum_score: 7
  - name: Gold
    minimum_score: 14
```

## Golden Path: New Microservice

A "golden path" is an opinionated, pre-approved template for common scenarios.

```bash
# Create new service from golden path template
cookiecutter gh:your-org/service-template

# Prompts:
# service_name: payment-processor
# language: python
# database: postgres
# cache: redis
# deploy_target: kubernetes

# Result: A fully configured service with:
# ✓ Dockerfile + docker-compose.yaml
# ✓ GitHub Actions CI/CD
# ✓ Terraform module for infra
# ✓ OpenTelemetry instrumentation
# ✓ Health check endpoints
# ✓ Prometheus metrics
# ✓ Structured logging
# ✓ README + runbook template
# ✓ On-call rotation template
```

## Platform Metrics (DORA Metrics)

Track platform success with DORA metrics:

```python
# scripts/dora_metrics.py collects:
# - Deployment Frequency: How often you deploy to prod
# - Lead Time for Changes: Commit → production
# - Change Failure Rate: % of deployments that cause incidents
# - Mean Time to Restore: How long to recover from failures

# Industry benchmarks:
# Elite:  Deploy multiple times/day, <1hr lead time, <5% failure, <1hr restore
# High:   Deploy daily-weekly, <1wk lead time, <15% failure, <24hr restore
# Medium: Deploy weekly-monthly, 1wk-1mo lead time
# Low:    Deploy monthly or less
```

## Real-World Use Cases

1. **Self-service database provisioning** — Dev fills a form, gets a Postgres DB in 5 minutes
2. **One-click staging environments** — Spin up a full copy of prod for each PR
3. **Automated cost tagging** — All cloud resources auto-tagged with team/service/env
4. **Compliance guardrails** — Security policies enforced at platform level, not per-service
5. **Developer onboarding** — New hire can ship their first PR in <2 hours

## Further Reading

- [Team Topologies](https://teamtopologies.com/) — Platform teams as enabling teams
- [Humanitec Platform Maturity Model](https://humanitec.com/platform-maturity-model)
- [CNCF Platform Engineering Whitepaper](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
