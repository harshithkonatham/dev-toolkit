# Observability — Logs, Metrics, Traces

> You can't fix what you can't see. Observability is the foundation of reliable systems.

## The Three Pillars

```
┌──────────────┬───────────────────┬─────────────────┐
│    LOGS      │     METRICS       │    TRACES       │
│              │                   │                 │
│ What happened│ How is it behaving│ Why is it slow? │
│ at a point   │ over time?        │ Where is the    │
│ in time?     │ (counters, gauges │ bottleneck?     │
│              │  histograms)      │                 │
│ Tools:       │ Tools:            │ Tools:          │
│ ELK, Loki,   │ Prometheus,       │ Jaeger, Zipkin, │
│ CloudWatch   │ Datadog, InfluxDB │ Tempo, OTEL     │
└──────────────┴───────────────────┴─────────────────┘
                          │
                          ▼
              OpenTelemetry (OTEL)
         Standard instrumentation for all three
```

## OpenTelemetry — The Standard

OpenTelemetry (OTEL) is the CNCF standard for instrumentation. Write once, ship to any backend (Datadog, Jaeger, Grafana, etc.).

### Quick Start

```bash
# Python
pip install opentelemetry-sdk opentelemetry-exporter-otlp \
  opentelemetry-instrumentation-fastapi \
  opentelemetry-instrumentation-sqlalchemy \
  opentelemetry-instrumentation-requests

# Node.js
npm install @opentelemetry/sdk-node @opentelemetry/auto-instrumentations-node \
  @opentelemetry/exporter-trace-otlp-http

# Go
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp
```

### Python FastAPI Auto-Instrumentation

```python
# otel_setup.py — Add to your app startup
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.resources import Resource

def setup_telemetry(service_name: str):
    resource = Resource(attributes={"service.name": service_name, "service.version": "1.0.0"})
    provider = TracerProvider(resource=resource)
    processor = BatchSpanProcessor(OTLPSpanExporter(endpoint="http://otel-collector:4317"))
    provider.add_span_processor(processor)
    trace.set_tracer_provider(provider)

    # Auto-instrument libraries
    FastAPIInstrumentor.instrument()
    SQLAlchemyInstrumentor().instrument()
    RequestsInstrumentor().instrument()

# In your FastAPI app
from fastapi import FastAPI
setup_telemetry("payment-service")
app = FastAPI()
```

## Grafana Observability Stack (LGTM)

The modern open-source observability stack:

```
LGTM = Loki (logs) + Grafana (UI) + Tempo (traces) + Mimir (metrics)
```

```bash
# Deploy full stack with Docker Compose
git clone https://github.com/grafana/docker-otel-lgtm
cd docker-otel-lgtm
docker compose up

# OTEL endpoint: http://localhost:4317 (gRPC) / http://localhost:4318 (HTTP)
# Grafana UI: http://localhost:3000 (admin/admin)
```

## Prometheus + Grafana

```bash
# Quick start with Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager + node-exporter)
helm install kube-prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=your-password

# Port forward Grafana
kubectl port-forward -n monitoring svc/kube-prom-grafana 3000:80

# Port forward Prometheus
kubectl port-forward -n monitoring svc/kube-prom-kube-prometheus-prometheus 9090:9090

# Port forward Alertmanager
kubectl port-forward -n monitoring svc/kube-prom-kube-prometheus-alertmanager 9093:9093
```

### Key PromQL Queries

```promql
# Request rate (per service, per 5 min)
rate(http_requests_total{service="payment"}[5m])

# Error rate (% of requests that are 5xx)
sum(rate(http_requests_total{status=~"5.."}[5m]))
/ sum(rate(http_requests_total[5m])) * 100

# P99 latency
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))

# Pod CPU usage
sum(rate(container_cpu_usage_seconds_total{namespace="production"}[5m])) by (pod)

# SLO: % of requests under 500ms
sum(rate(http_request_duration_seconds_bucket{le="0.5"}[1h]))
/ sum(rate(http_request_duration_seconds_count[1h])) * 100
```

## Alertmanager Rules

```yaml
# alerts/production.yaml
groups:
  - name: service.rules
    rules:
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
          / sum(rate(http_requests_total[5m])) by (service) > 0.01
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on {{ $labels.service }}"
          description: "Error rate is {{ $value | humanizePercentage }}"
          runbook: "https://runbooks.internal/{{ $labels.service }}/high-error-rate"

      - alert: P99LatencyHigh
        expr: |
          histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m])) > 2.0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P99 latency high: {{ $labels.service }}"

      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical

      - alert: SLOBudgetBurning
        expr: |
          (
            1 - (
              sum(rate(http_requests_total{status!~"5.."}[1h])) by (service)
              / sum(rate(http_requests_total[1h])) by (service)
            )
          ) > 0.001  # 30-day budget burning faster than 1h window
        annotations:
          summary: "SLO budget burning fast for {{ $labels.service }}"
```

## Structured Logging

```python
# Always use structured (JSON) logs in production
import structlog
import logging

structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),  # Output as JSON
    ],
    logger_factory=structlog.stdlib.LoggerFactory(),
)

log = structlog.get_logger()

# Add context that propagates through the call stack
log = log.bind(service="payment-service", request_id="req-123", user_id="user-456")

log.info("payment_processed", amount=99.99, currency="USD", payment_method="card")
# Output: {"event": "payment_processed", "amount": 99.99, "currency": "USD", "service": "payment-service", ...}

log.error("payment_failed", error="insufficient_funds", retry_count=3)
```

## Distributed Tracing with Jaeger

```bash
# Run Jaeger all-in-one (development)
docker run -d --name jaeger \
  -e COLLECTOR_OTLP_ENABLED=true \
  -p 16686:16686 \  # UI
  -p 4317:4317 \    # OTLP gRPC
  -p 4318:4318 \    # OTLP HTTP
  jaegertracing/all-in-one:latest

# View traces at http://localhost:16686
```

## SLO/SLA Management

```python
# Define SLOs as code
slos = {
    "payment-service": {
        "availability": {
            "target": 0.999,     # 99.9% = 43.8 min downtime/month
            "window": "30d",
            "metric": "http_requests_total",
            "good_filter": 'status!~"5.."',
        },
        "latency": {
            "target": 0.95,      # 95% of requests under threshold
            "threshold_ms": 500,
            "window": "30d",
        },
    }
}
```

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/setup_otel_collector.sh` | Deploy OpenTelemetry Collector |
| `scripts/trace_analyzer.py` | Analyze traces for latency hotspots |
| `scripts/alert_manager_setup.sh` | Configure Alertmanager routing |
| `configs/otel-collector.yaml` | OTEL Collector config |
| `configs/grafana-dashboards/` | Pre-built Grafana dashboards |
