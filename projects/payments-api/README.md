# Payments API

[![payments-api](https://github.com/harshithkonatham/dev-toolkit/actions/workflows/payments-api.yml/badge.svg)](https://github.com/harshithkonatham/dev-toolkit/actions/workflows/payments-api.yml)

A small card-transactions service built to show a secure software lifecycle end
to end: validated input, token auth, card data that never touches storage or
logs, tests at three levels, and a CI/CD pipeline where security checks gate
the deploy.

It's deliberately small. Most of the work is in how it is built, tested,
scanned and shipped.

## API

| Method | Path | Scope | Notes |
|---|---|---|---|
| `POST` | `/v1/transactions` | `transactions:write` | Create a payment. Optional `Idempotency-Key` header. |
| `GET` | `/v1/transactions/{id}` | `transactions:read` | Only the caller's own transactions. |
| `GET` | `/v1/transactions?limit=20` | `transactions:read` | Newest first, `limit` 1–100. |
| `GET` | `/healthz`, `/readyz` | none | Liveness and readiness (checks the database). |
| `GET` | `/metrics` | none | Prometheus metrics. Keep internal (see NetworkPolicy). |

```bash
curl -X POST localhost:8000/v1/transactions \
  -H "Authorization: Bearer $TOKEN" -H "Idempotency-Key: order-1001" \
  -H "Content-Type: application/json" \
  -d '{"card_number":"4111111111111111","amount":"25.50","currency":"GBP","merchant_id":"coffee-shop"}'
```

```json
{"id":"6f17…","card_last4":"1111","amount":"25.50","currency":"GBP",
 "merchant_id":"coffee-shop","description":null,"status":"approved",
 "created_at":"2026-10-28T21:41:10Z"}
```

## Run it

Needs [uv](https://docs.astral.sh/uv/). Docker is optional.

```bash
make install                  # locked dependencies
make check                    # lint, types, tests, security scans
make run                      # API on http://localhost:8000 with throwaway secrets
make token                    # in another shell: print a 15-minute access token
```

With Docker: `make docker-build docker-run`.

## Security controls

| Risk | Control | Where |
|---|---|---|
| Card data exposure (PCI DSS req. 3) | The card number is never stored or logged. We keep the last 4 digits plus a keyed HMAC fingerprint. Validation errors don't echo input. Logs mask anything that looks like a card number. | [`cards.py`](src/payments_api/cards.py), [`main.py`](src/payments_api/main.py), [`observability.py`](src/payments_api/observability.py) |
| Broken authentication | JWT with pinned HS256, required `exp`/`iat`/`sub`/`iss`/`aud`, 15-minute tokens. `alg: none` and other algorithms are rejected. | [`auth.py`](src/payments_api/auth.py) |
| Broken object-level authorization (OWASP API1) | Every query is scoped to the caller. Another user's ID returns 404, so IDs can't be probed. | [`db.py`](src/payments_api/db.py) |
| Injection | Strict schemas (unknown fields rejected, currency allowlist, Luhn check, bounded amounts and lengths). All SQL is parameterised. | [`models.py`](src/payments_api/models.py), [`db.py`](src/payments_api/db.py) |
| Double charging | `Idempotency-Key`: a retry returns the original result, and reusing a key with a different body gets 409. | [`db.py`](src/payments_api/db.py) |
| Money rounding errors | Amounts are `Decimal` in the API and integer minor units in storage, and JSON carries them as strings. | [`db.py`](src/payments_api/db.py) |
| Lost or phantom events | Transactional outbox: the payment and its event commit together, then a relay publishes them at least once. | [`db.py`](src/payments_api/db.py), [`events.py`](src/payments_api/events.py) |
| Secret leakage | No default secrets: the app won't start without them. They're read from mounted files in Kubernetes, and `repr()` redacts them. Gitleaks scans the full git history. | [`config.py`](src/payments_api/config.py) |
| Resource abuse | 16 KB body limit enforced before parsing (including chunked bodies), plus bounded page sizes. | [`observability.py`](src/payments_api/observability.py) |
| Browser-side attacks | `no-store`, a strict CSP, HSTS, `nosniff` and `DENY` framing on every response. API docs are off by default. | [`observability.py`](src/payments_api/observability.py) |
| Supply chain | `uv.lock` with hashes and a wheels-only install. Base images pinned by digest, Actions pinned by commit SHA. SBOM generated on every build. Dependabot proposes updates only after a release is 7 days old. | [`pyproject.toml`](pyproject.toml), [`Dockerfile`](Dockerfile), [workflow](../../.github/workflows/payments-api.yml) |
| Container and cluster | Non-root user (UID 10001), read-only root filesystem, all capabilities dropped, seccomp `RuntimeDefault`, no service-account token, restricted Pod Security Standard, default-deny NetworkPolicy. | [`deploy/k8s`](deploy/k8s) |

## Monitoring

[`deploy/monitoring`](deploy/monitoring) has Prometheus alert rules, a Grafana
dashboard and a [runbook](deploy/monitoring/RUNBOOK.md) with a section for each alert.

| Alert | Fires when | Severity |
|---|---|---|
| `PaymentsApiDown` | Scrape target down for 2 min | page |
| `PaymentsHighErrorRate` | 5xx above 2% for 5 min (with real traffic) | page |
| `PaymentsSlowCreate` | p95 for creating a payment above 500 ms for 10 min | ticket |
| `PaymentsDeclineSpike` | More than 25% declined over 15 min | ticket |
| `PaymentsAuthFailures` | Sustained 401/403 above 1/s for 10 min | ticket (security) |

Every alert has a promtool unit test ([`alerts.test.yml`](deploy/monitoring/alerts.test.yml)),
covering both "fires when it should" and "stays quiet at low traffic". CI runs
them, and the deploy job waits for them.

```bash
make run              # API on :8000
make monitoring-up    # Grafana on http://localhost:3000 (Payments folder), Prometheus on :9090
make test-alerts      # alert unit tests
```

## Pipeline

[`.github/workflows/payments-api.yml`](../../.github/workflows/payments-api.yml)
runs on every push and PR that touches this project, plus a weekly re-scan for
newly published CVEs.

```text
 test     ruff · mypy --strict · pytest (unit + integration, ≥90% coverage)  ─┐
 sast     Bandit · Semgrep (Python, OWASP Top 10, secrets) → Security tab     │
 codeql   CodeQL security-extended → Security tab                             │
 secrets  Gitleaks over full git history                                      │
 deps     pip-audit against uv.lock                                           │
 iac      Hadolint · Checkov (Dockerfile + Kubernetes)                         │
                                                                              ▼
 image    build → Grype CVE scan (fail on fixable high/critical) → SBOM
          → run hardened container → e2e tests
                                                                              ▼
 deploy   kind cluster → apply manifests with generated secrets
          → rollout → e2e tests through the Service
```

Each job gets only the permissions it needs (`contents: read` by default).
Secrets used in CI are random values generated per run, so the repo stores none.

## Tests

| Level | What | Where |
|---|---|---|
| Unit | Luhn check, masking, JWT edge cases, schema validation, config, log redaction | [`tests/unit`](tests/unit) |
| Integration | Full HTTP API against a real SQLite DB: auth, authorization, idempotency, outbox, security headers, PAN leakage, SQL injection, size limits, failure modes | [`tests/integration`](tests/integration) |
| End-to-end | The same journey against a running container and a Kubernetes deployment | [`tests/e2e`](tests/e2e) |

## Design notes and limits

- **SQLite** keeps the demo self-contained. It's single-writer, so the
  Deployment runs one replica with `Recreate`. Production would use a managed
  database such as Postgres behind the same `Repository` interface.
- **The event publisher** logs events. A Kafka, SQS or RabbitMQ publisher would
  implement the one-method `Publisher` protocol in [`events.py`](src/payments_api/events.py).
- **HS256 tokens** keep local testing simple. With an external identity
  provider you'd verify RS256/ES256 tokens against its JWKS endpoint instead.
- **The approve/decline rule** is a placeholder per-currency limit.
- **Data is in an `emptyDir`**, so it's lost when the pod restarts.

## Compliance

[`docs/pci-dss.md`](docs/pci-dss.md) maps PCI DSS v4.0 requirements (1–4, 6–8,
10–12) to the controls above, with a file, test or CI job as evidence for each,
and lists the known gaps.
