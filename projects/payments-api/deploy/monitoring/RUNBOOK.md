# Payments API runbook

What to do when an alert fires. Each alert in [`alerts.yml`](alerts.yml) links
to its section here.

**Severity:** `page` means act now (customers can't pay). `ticket` means look
at it during working hours.

**First five minutes, for any alert**

1. Open the **Payments API** dashboard in Grafana and note when the change started.
2. Check what changed around then: deploys (`kubectl -n payments rollout history deployment/payments-api`), config, dependencies.
3. Search the logs by `request_id`. Every response carries an `X-Request-ID`
   header, and every JSON log line includes it.
4. If a deploy lines up with the start, roll back first and investigate after:
   `kubectl -n payments rollout undo deployment/payments-api`.

## PaymentsApiDown

Prometheus can't scrape the API for 2 minutes.

- `kubectl -n payments get pods`: look for `CrashLoopBackOff` or `Pending`.
- `kubectl -n payments logs deploy/payments-api --previous`. A `ConfigError`
  at startup means a missing or short secret; the app refuses to start without one.
- Readiness fails if the database is unreachable (`/readyz` returns 503).
- If the pods are healthy, check the NetworkPolicy still allows the scrape.

## PaymentsHighErrorRate

More than 2% of requests return 5xx for 5 minutes (needs at least 0.1 req/s,
so one error at night doesn't page).

- Dashboard: **Requests by status**. Is it one route or all of them?
- Logs: `"level": "ERROR"` lines. Unhandled errors are logged with a stack
  trace, and the client only gets `internal server error`.
- `database is locked` errors mean write contention. Check for a stuck process
  holding the database.
- Recent deploy? Roll back.

## PaymentsSlowCreate

p95 for `POST /v1/transactions` is above 500 ms for 10 minutes.

- **Latency by route**: if every route is slow, suspect the host (CPU
  throttling: `kubectl top pods`). If only creation is slow, suspect the
  database write path.
- Check whether the outbox is backing up (many `event publish failed` logs).
  The relay shares the database.

## PaymentsDeclineSpike

More than 25% of payments declined over 15 minutes.

- This is usually a business signal, not an outage: a merchant sending
  unusually large amounts, or a change to the risk limits.
- **Payments by currency and outcome**: is it one currency?
- Check whether `SINGLE_PAYMENT_LIMIT` in `main.py` changed in a recent deploy.
- Tell the payments operations owner. Don't change limits without them.

## PaymentsAuthFailures

More than 1 request per second getting 401/403 for 10 minutes. Category: **security**.

- Many different tokens from a few sources suggests credential stuffing or
  token guessing. Rate-limit or block at the ingress and inform security.
- One client with an expired or wrongly scoped token suggests a broken
  integration. Contact the client owner.
- Tokens are never logged. Use `request_id` and client IP from the ingress
  logs to correlate.
- Record what you found in the incident log; PCI DSS 10.7 expects security
  monitoring failures and responses to be documented.

---

## Incident review template

Use this for every `page` incident, and for any `ticket` that had customer impact.
Blameless: describe what the system allowed to happen, not who did it.

```markdown
### <date> – <one-line summary>

**Impact:** who was affected, how, for how long
**Detection:** which alert or report, and the time from start to detection
**Timeline (UTC):** start → detected → mitigated → resolved
**Root cause:** the underlying condition, not just the trigger ("5 whys")
**What went well / what didn't**
**Actions:** each with an owner and a date; prefer changes that stop it from recurring
```

### Example: 2026-10-28 – Prometheus crashed on start in the local monitoring stack

Found while building this stack. It shows how the template is used.

**Impact:** Local only. No metrics or alerts for the first run of the stack.
**Detection:** Manual. Grafana loaded, but the queries returned nothing.
**Timeline:** compose up → Grafana empty after ~2 min → `docker compose ps`
showed Prometheus `Exited (2)` → fixed and verified in ~5 min.
**Root cause:**
1. Why no data? Prometheus wasn't running.
2. Why? It panicked: `Unable to create mmap-ed active query log`.
3. Why? It couldn't write to `/prometheus`.
4. Why? Hardening made the container read-only, with a `tmpfs` at
   `/prometheus`. The tmpfs was owned by root, but the image runs as `nobody` (65534).
5. Why wasn't it caught? Config validation (`promtool check config`) doesn't
   start the server, so permissions aren't tested.

**Fix:** mount the tmpfs with `uid=65534,gid=65534` and set `--storage.tsdb.path`
explicitly ([`compose.yaml`](compose.yaml)).
**Actions:** when hardening a third-party image, check which user it runs as
(`docker inspect --format '{{.Config.User}}'`) before mounting writable paths.
