# DevOps Complete Setup - 2026 Roadmap

This module is the enhanced setup collection for DevOps engineers. It consolidates profiles, decisions, and the latest toolchain details.

## Objectives
- Capture full setup workflows (install, configure, verify).
- Provide tool comparisons and suitability guidance.
- Build a carrier for per-tool deep-dive documents.

## Tool coverage
1. Ansible
2. Argo CD
3. AWS CLI + Cloud infrastructure
4. Docker + Podman
5. ELK Stack
6. Jenkins + GitHub Actions alternatives
7. Kafka
8. Kubernetes + K3s + EKS/GKE/AKS
9. Prometheus + Grafana + Loki
10. Terraform + Terragrunt
11. Vault

## How to use
- Each tool has a subfolder in the parent directory.
- Use `*_overview.md` in this folder to consolidate cross-tool patterns.
- Use `TODO-update-<tool>.md` as living notes for updates.

## 2026 updates
- Recommend Terraform 1.9+ with `provider_installation` and performance tuning.
- Recommend Ansible 2.14+ and automation with `ansible-navigator` and `ansible-core`.
- Recommend Kubernetes 1.30+ and `kubeadm` / cluster API patterns.
- Add GitOps with Argo CD + Flux for environment drift detection.
- Add policy as code using OPA (Open Policy Agent) and GitHub repo enforcement.

## Getting started checklist
- [ ] Validate each tool README exist and has install steps.
- [ ] Run `./scripts/check-env.sh` evaluating local dependencies (bash script optional).
- [ ] Add `setup-guides/` for cloud-specific quickstarts (GCP/AWS/Azure).  

## Cross-tool best practices
- Single source of truth: infrastructure as code in `terraform/`, config in `ansible/`.
- Immutable infrastructure + ephemeral containers in `docker/` + `kubernetes/`.
- Observability pivot: metric + trace + logs using `prometheus-grafana` and `elk-stack`.
- Secrets lifecycle: `vault/` for backend, integrate with CI and container secrets manager.
- Security: `kubernetes` RBAC, `OSPP` sysctl, and OPA integration.

## Add-ons (future)
- `k9s` for terminal Kubernetes UX.
- `stern` and `kubectl-trace` for debugging.
- `argocd-image-updater` and `fluxcd` for GitOps drift control.
- `grype` and `trivy` for container scanning.
