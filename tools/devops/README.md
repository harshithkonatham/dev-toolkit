# DevOps Tools Central Index

This folder contains curated DevOps tooling guidance, installation instructions, and best practices for a modern infrastructure and automation stack.

## Goal
- Centralize setup and configuration across every tool.
- Include latest recommended versions, security and usability patterns.
- Provide a high-level map for teams to choose the right tool for each workflow.

## Contents
- `ansible/` - Infrastructure as code for provisioning and configuration management.
- `argocd/` - GitOps continuous delivery for Kubernetes.
- `aws/` - AWS CLI and cloud service provisioning guidance.
- `docker/` - Containerization, BuildKit, compose, and advanced Dockerfile practices.
- `elk-stack/` - ElasticSearch, Logstash, and Kibana logging pipeline.
- `jenkins/` - CI/CD server setup and pipeline scripting.
- `kafka/` - Streaming data platform and event-driven integration.
- `kubernetes/` - Kubernetes cluster deployment, security, and operations.
- `prometheus-grafana/` - Monitoring, observability, and dashboarding.
- `terraform/` - Immutable infrastructure as code for multi-cloud.
- `vault/` - Secrets management and encryption as a service.

## Quick-start commands
```bash
# Clone repo
git clone https://github.com/<your-org>/ak-dev-toolkit.git
cd ak-dev-toolkit/tools/devops

# Read the master guide
less README.md

# Open the recommended deep dive
less complete-setup/devops-tool-analysis.md
```

## Next actions
1. Visit specific tool subfolder and follow README instructions.
2. Add new tool support in this index (e.g., `argo-workflows`, `buildkite`, `pulumi`).
3. Keep this README in sync with tool versions and link back to architecture decisions. 