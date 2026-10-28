# PCI DSS v4.0 control mapping

This maps PCI DSS v4.0 requirements to the controls in this project, with
evidence an assessor (or reviewer) can check: a file, a test or a CI job.

> **Scope.** This is a reference project, not a PCI-assessed system. It shows
> how requirements turn into code and pipeline checks. A real assessment would
> also cover the hosting environment, people and processes, which are out of
> scope here.

## Cardholder data flow

```text
client ──TLS──► ingress ──► payments-api ──► SQLite / outbox   (last 4 + HMAC fingerprint only)
                               │
                               └─► RabbitMQ (amqps) ──► risk-monitor   (no PAN in events)
```

The full card number (PAN) exists only in memory during one request. It is
never written to the database, events or logs. That keeps most storage
requirements (3.5) out of scope by design.

## Requirements

### 1 – Network security controls

| Req. | Control | Evidence |
|---|---|---|
| 1.2, 1.3 | Default-deny Kubernetes NetworkPolicy for ingress and egress. Only inbound HTTP on port 8000 is allowed, and the API makes no outbound calls. (Switching on `EVENT_BROKER=rabbitmq` in the cluster needs an egress rule to the broker and DNS.) | [`deploy/k8s/networkpolicy.yaml`](../deploy/k8s/networkpolicy.yaml) |
| 1.4 | Local stacks bind to `127.0.0.1` only | [`compose.yaml`](../compose.yaml), [`deploy/monitoring/compose.yaml`](../deploy/monitoring/compose.yaml) |

### 2 – Secure configurations

| Req. | Control | Evidence |
|---|---|---|
| 2.2.2 | No default credentials: the service refuses to start without its secrets, and they must be 32+ characters | [`config.py`](../src/payments_api/config.py), `tests/unit/test_config.py` |
| 2.2.4, 2.2.5 | Only needed services are enabled: API docs off by default, no service-account token mounted, minimal image | [`main.py`](../src/payments_api/main.py), [`deploy/k8s/deployment.yaml`](../deploy/k8s/deployment.yaml), [`Dockerfile`](../Dockerfile) |
| 2.2.6 | Hardened runtime: non-root UID 10001, read-only root filesystem, all capabilities dropped, seccomp `RuntimeDefault` | [`deploy/k8s/deployment.yaml`](../deploy/k8s/deployment.yaml); CI runs the container the same way |

### 3 – Protect stored account data

| Req. | Control | Evidence |
|---|---|---|
| 3.2.1 | No PAN retention: only the last 4 digits and a keyed HMAC-SHA256 fingerprint are stored | [`cards.py`](../src/payments_api/cards.py), [`db.py`](../src/payments_api/db.py) |
| 3.3.1 | No sensitive authentication data (CVV, PIN, track data) is accepted: unknown fields are rejected | [`models.py`](../src/payments_api/models.py) (`extra="forbid"`) |
| 3.4.1 | PAN masked wherever shown: API responses carry `card_last4`, and logs use `mask()` | [`cards.py`](../src/payments_api/cards.py), `tests/integration/test_security.py::test_card_number_never_reaches_the_logs` |
| 3.6, 3.7 | Keys in a managed store (Secrets Manager, encrypted with a customer-managed KMS key rotated yearly). Rotation procedure is documented per key. | [`deploy/terraform/secrets.tf`](../deploy/terraform/secrets.tf), [`kms.tf`](../deploy/terraform/kms.tf), [Terraform README](../deploy/terraform/README.md#secret-rotation) |

### 4 – Protect data in transit

| Req. | Control | Evidence |
|---|---|---|
| 4.2.1 | HSTS on every response; TLS ends at the ingress | [`observability.py`](../src/payments_api/observability.py) |
| 4.2.1 | Broker connections must use `amqps://`. Plaintext needs an explicit local-only opt-in. | [`config.py`](../src/payments_api/config.py), `tests/unit/test_config.py::test_rabbitmq_requires_tls_by_default` |
| 4.2.2 | PAN is never sent in events: the consumer rejects any event containing a `card_number` field | [`consumer.py`](../src/payments_api/consumer.py), `tests/unit/test_consumer.py` |

### 6 – Secure systems and software

| Req. | Control | Evidence |
|---|---|---|
| 6.2.1, 6.2.3 | All changes go through pull requests with CI gates | [workflow](../../../.github/workflows/payments-api.yml) |
| 6.2.4 | Injection and common attacks: parameterised SQL, strict input schemas, body size limit, Semgrep OWASP Top 10, CodeQL `security-extended`, Bandit | [`db.py`](../src/payments_api/db.py), [`models.py`](../src/payments_api/models.py), CI `sast` and `codeql` jobs |
| 6.3.1 | Vulnerabilities found: pip-audit (dependencies), Grype (image), weekly scheduled re-scan | CI `dependencies` and `image` jobs, `schedule:` trigger |
| 6.3.2 | Software inventory: a CycloneDX SBOM for every image build | CI `image` job artifact |
| 6.3.3 | Patching: Dependabot for Python packages, actions and base image, with a 7-day cooldown | [`.github/dependabot.yml`](../../../.github/dependabot.yml) |
| 6.4.1, 6.4.2 | Public-facing API protections: auth on every data route, strict CSP, `nosniff`, `DENY` framing, validation errors that don't echo input | [`observability.py`](../src/payments_api/observability.py), [`main.py`](../src/payments_api/main.py) |
| 6.5.1 | Change control: Actions pinned to commit SHAs, base images pinned by digest, deploys only after every gate passes | [workflow](../../../.github/workflows/payments-api.yml) (`deploy` `needs:`) |

### 7 – Restrict access by need to know

| Req. | Control | Evidence |
|---|---|---|
| 7.2.1 | Scoped tokens: `transactions:read` and `transactions:write` | [`auth.py`](../src/payments_api/auth.py) |
| 7.2.2 | Object-level authorisation: every query is scoped to the caller, and another user's ID returns 404 | [`db.py`](../src/payments_api/db.py), `tests/integration/test_security.py` |
| 7.2.5 | Least-privilege CI identity: the GitHub OIDC role can push only to one ECR repository, only from `main` | [`deploy/terraform/github_oidc.tf`](../deploy/terraform/github_oidc.tf) |

### 8 – Identify users and authenticate access

| Req. | Control | Evidence |
|---|---|---|
| 8.3.1 | JWT with pinned HS256; `exp`, `iat`, `sub`, `iss` and `aud` required; `alg: none` rejected | [`auth.py`](../src/payments_api/auth.py), `tests/unit/test_auth.py::test_unsigned_alg_none_token_is_rejected` |
| 8.2.8 | Short-lived credentials: 15-minute access tokens, 1-hour CI sessions, no long-lived AWS keys | [`auth.py`](../src/payments_api/auth.py), [`github_oidc.tf`](../deploy/terraform/github_oidc.tf) |
| 8.6.2 | No secrets in code: Gitleaks scans the full git history on every push | CI `secrets` job |

### 10 – Log and monitor all access

| Req. | Control | Evidence |
|---|---|---|
| 10.2 | Structured JSON log for every request (method, route, status, duration, request ID), plus a log line with the caller for every payment created | [`observability.py`](../src/payments_api/observability.py) |
| 10.3.1 | Logs can't leak card data: anything that looks like a PAN is masked by the log formatter | [`observability.py`](../src/payments_api/observability.py) (`redact`), `tests/unit/test_observability.py` |
| 10.5.1 | Logs kept at least 12 months, KMS-encrypted (the retention variable can't be set lower) | [`deploy/terraform/logs.tf`](../deploy/terraform/logs.tf), [`variables.tf`](../deploy/terraform/variables.tf) |
| 10.4.1, 10.7 | Automated review: alerts for outages, errors, latency, declines and sustained auth failures, each unit-tested and linked to a runbook | [`deploy/monitoring/alerts.yml`](../deploy/monitoring/alerts.yml), [`alerts.test.yml`](../deploy/monitoring/alerts.test.yml) |

### 11 – Test security regularly

| Req. | Control | Evidence |
|---|---|---|
| 11.3.1 | Vulnerability scans on every change and weekly | CI `dependencies`, `image`, `schedule:` |
| 11.6 | IaC scanned for misconfiguration (Checkov on the Dockerfile, Kubernetes and Terraform; Hadolint) | CI `iac` job |

### 12 – Incident response

| Req. | Control | Evidence |
|---|---|---|
| 12.10.1 | Runbook per alert, first-response checklist, and a blameless incident review template with a worked example | [`deploy/monitoring/RUNBOOK.md`](../deploy/monitoring/RUNBOOK.md) |

## Known gaps

Recorded so they aren't mistaken for coverage:

- **Requirement 5 (anti-malware)** isn't addressed beyond image CVE scanning.
- **Penetration testing (11.4)** and **ASV scans (11.3.2)** need an external party.
- **Audit-log immutability:** CloudWatch retention is set, but write-once storage
  (S3 Object Lock) is not configured yet.
- **Key rotation** for the PAN HMAC key needs a re-fingerprinting job that isn't built yet.
