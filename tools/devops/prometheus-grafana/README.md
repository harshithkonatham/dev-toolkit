# Prometheus & Grafana Setup Guide

## Overview

**Prometheus** is an open-source systems monitoring and alerting toolkit originally built at SoundCloud. It collects metrics from configured targets at given intervals, evaluates rule expressions, displays results, and can trigger alerts when specified conditions are observed.

**Grafana** is an open-source analytics and interactive visualization web application. It provides charts, graphs, and alerts when connected to supported data sources, with Prometheus being one of the most popular.

Together, they form the backbone of modern observability stacks.

---

## Why Use Prometheus + Grafana?

| Feature | Benefit |
|---|---|
| Pull-based metrics collection | Prometheus scrapes targets, simplifying service config |
| Powerful query language (PromQL) | Flexible, expressive querying of time-series data |
| Multi-dimensional data model | Labels allow slicing and dicing metrics freely |
| Built-in alerting | Alertmanager handles dedup, grouping, routing |
| Grafana dashboards | Rich, customizable visualizations for any audience |
| Extensive ecosystem | Thousands of exporters, integrations, and community dashboards |
| Cloud-native ready | First-class Kubernetes integration via service discovery |

---

## Architecture

```
                  +-----------------+
                  |   Alertmanager  |
                  +--------^--------+
                           |
+----------+      +--------+--------+      +-----------+
| Exporters| <--- |   Prometheus    | ---> |  Grafana   |
| (targets)|      | (scrape/store)  |      | (visualize)|
+----------+      +-----------------+      +-----------+
     ^                    |
     |                    v
+---------+        +-----------+
| Your App|        | TSDB      |
| /metrics|        | (storage) |
+---------+        +-----------+
```

Key components:
- **Prometheus Server**: Scrapes and stores time-series data
- **Client Libraries**: Instrument application code (Go, Java, Python, etc.)
- **Exporters**: Expose metrics from third-party systems (Node Exporter, MySQL Exporter, etc.)
- **Alertmanager**: Handles alerts sent by Prometheus
- **Pushgateway**: For short-lived jobs that cannot be scraped
- **Grafana**: Visualization and dashboarding layer

---

## Installation

### macOS

```bash
# Prometheus
brew install prometheus

# Grafana
brew install grafana

# Start services
brew services start prometheus
brew services start grafana
```

### Linux (Ubuntu/Debian)

```bash
# Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.53.0/prometheus-2.53.0.linux-amd64.tar.gz
tar xvfz prometheus-2.53.0.linux-amd64.tar.gz
sudo mv prometheus-2.53.0.linux-amd64/prometheus /usr/local/bin/
sudo mv prometheus-2.53.0.linux-amd64/promtool /usr/local/bin/

# Grafana
sudo apt-get install -y apt-transport-https software-properties-common
wget -q -O - https://apt.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update && sudo apt-get install grafana
sudo systemctl enable --now grafana-server
```

### Windows

Download binaries from official release pages:
- Prometheus: https://prometheus.io/download/
- Grafana: https://grafana.com/grafana/download?platform=windows

Or use `winget`:

```powershell
winget install Grafana.Grafana
```

---

## Docker Compose Setup (Recommended)

Create a `docker-compose.yml` for the full stack:

```yaml
version: "3.8"

services:
  prometheus:
    image: prom/prometheus:v2.53.0
    container_name: prometheus
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./prometheus/alert_rules.yml:/etc/prometheus/alert_rules.yml
      - prometheus_data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--storage.tsdb.retention.time=30d"
      - "--web.enable-lifecycle"
    ports:
      - "9090:9090"
    restart: unless-stopped

  grafana:
    image: grafana/grafana:11.1.0
    container_name: grafana
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=changeme
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "3000:3000"
    depends_on:
      - prometheus
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:v1.8.1
    container_name: node-exporter
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - "--path.procfs=/host/proc"
      - "--path.sysfs=/host/sys"
      - "--path.rootfs=/rootfs"
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"
    ports:
      - "9100:9100"
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:v0.27.0
    container_name: alertmanager
    volumes:
      - ./alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml
    ports:
      - "9093:9093"
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
```

---

## Prometheus Configuration

### prometheus.yml

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]

  # Kubernetes service discovery example
  - job_name: "kubernetes-pods"
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
```

### Service Discovery

Prometheus supports multiple service discovery mechanisms:

| Mechanism | Use Case |
|---|---|
| `static_configs` | Fixed list of targets |
| `kubernetes_sd_configs` | Auto-discover Kubernetes pods/services |
| `consul_sd_configs` | Consul service registry |
| `ec2_sd_configs` | AWS EC2 instances |
| `file_sd_configs` | JSON/YAML file-based discovery |
| `dns_sd_configs` | DNS SRV records |

---

## PromQL Essentials

```promql
# Instant vector - current CPU usage per mode
node_cpu_seconds_total

# Range vector - CPU over last 5 minutes
node_cpu_seconds_total[5m]

# Rate of HTTP requests per second
rate(http_requests_total[5m])

# 95th percentile request duration
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Total memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Top 5 containers by CPU usage
topk(5, rate(container_cpu_usage_seconds_total[5m]))

# Aggregate: average request rate across all instances
avg(rate(http_requests_total[5m])) by (service)

# Predict disk full in 4 hours
predict_linear(node_filesystem_avail_bytes[1h], 4 * 3600) < 0
```

---

## Alerting Rules

### alert_rules.yml

```yaml
groups:
  - name: infrastructure
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes (current: {{ $value }}%)."

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"

      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15
        for: 10m
        labels:
          severity: critical
        annotations:
          summary: "Disk space below 15% on {{ $labels.instance }}"

      - alert: InstanceDown
        expr: up == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} is down"

  - name: application
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High 5xx error rate on {{ $labels.job }}"

      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High p95 latency on {{ $labels.job }}"
```

### Alertmanager Configuration

```yaml
# alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m

route:
  group_by: ["alertname", "severity"]
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: "slack-notifications"
  routes:
    - match:
        severity: critical
      receiver: "pagerduty-critical"

receivers:
  - name: "slack-notifications"
    slack_configs:
      - api_url: "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
        channel: "#alerts"
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

  - name: "pagerduty-critical"
    pagerduty_configs:
      - service_key: "YOUR_PAGERDUTY_KEY"
```

---

## Grafana Configuration

### Adding Prometheus as a Data Source

Provisioning file at `grafana/provisioning/datasources/prometheus.yml`:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
```

### Dashboard Provisioning

```yaml
# grafana/provisioning/dashboards/dashboards.yml
apiVersion: 1
providers:
  - name: "default"
    orgId: 1
    folder: ""
    type: file
    options:
      path: /etc/grafana/provisioning/dashboards/json
```

### Recommended Community Dashboards

Import these by ID in Grafana (Dashboards > Import):

| Dashboard | ID | Purpose |
|---|---|---|
| Node Exporter Full | 1860 | Host-level metrics |
| Docker and System Monitoring | 893 | Container monitoring |
| Kubernetes Cluster | 6417 | K8s cluster overview |
| NGINX | 9614 | NGINX metrics |
| PostgreSQL | 9628 | PostgreSQL monitoring |

---

## Key Metrics to Monitor

### Infrastructure (The Four Golden Signals)

1. **Latency**: Time to service a request
2. **Traffic**: Volume of requests (requests/sec)
3. **Errors**: Rate of failed requests
4. **Saturation**: How full is the system (CPU, memory, disk)

### Application Metrics (RED Method)

- **Rate**: Requests per second
- **Errors**: Failed requests per second
- **Duration**: Distribution of request latencies

### System Metrics (USE Method)

- **Utilization**: Percentage of resource busy
- **Saturation**: Queue depth / work backlog
- **Errors**: Count of error events

---

## Key Commands

```bash
# Validate Prometheus config
promtool check config prometheus.yml

# Validate alerting rules
promtool check rules alert_rules.yml

# Test PromQL queries
promtool query instant http://localhost:9090 'up'

# Reload Prometheus config (requires --web.enable-lifecycle)
curl -X POST http://localhost:9090/-/reload

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Backup Grafana dashboards via API
curl -s http://admin:changeme@localhost:3000/api/dashboards/uid/DASHBOARD_UID | jq . > backup.json

# Create Prometheus TSDB snapshot
curl -X POST http://localhost:9090/api/v1/admin/tsdb/snapshot
```

---

## Best Practices for Production

1. **Retention and Storage**: Set `--storage.tsdb.retention.time` based on needs; use remote storage (Thanos, Cortex, Mimir) for long-term retention.
2. **High Availability**: Run at least two Prometheus replicas scraping the same targets. Use Thanos or Cortex for deduplication and global view.
3. **Cardinality Management**: Avoid labels with unbounded values (user IDs, request IDs). High cardinality kills performance.
4. **Recording Rules**: Pre-compute expensive queries as recording rules to speed up dashboards.
5. **Federation**: Use federation to aggregate metrics from multiple Prometheus servers in large environments.
6. **Security**: Enable TLS and authentication on Prometheus and Grafana. Use Grafana RBAC for dashboard access control.
7. **Alerting Hygiene**: Every alert should be actionable. Avoid alert fatigue by tuning thresholds and using inhibition rules.
8. **Dashboard Standards**: Use variables/templates in Grafana dashboards. Standardize naming conventions across teams.

---

## Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [Awesome Prometheus Alerts](https://awesome-prometheus-alerts.grep.to/)
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)
- [Google SRE Book - Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Thanos (Long-term Storage)](https://thanos.io/)
- [Grafana Mimir](https://grafana.com/oss/mimir/)
