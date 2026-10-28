# ELK Stack (Elasticsearch, Logstash, Kibana) Setup Guide

## Overview

The **ELK Stack** is a collection of three open-source products maintained by Elastic:

- **Elasticsearch**: A distributed, RESTful search and analytics engine built on Apache Lucene
- **Logstash**: A server-side data processing pipeline that ingests, transforms, and sends data
- **Kibana**: A visualization layer that provides a UI for querying and dashboarding Elasticsearch data

Together with **Beats** (lightweight data shippers), the stack is often called the **Elastic Stack**.

---

## Why Use the ELK Stack?

| Feature | Benefit |
|---|---|
| Centralized logging | Aggregate logs from all services into one place |
| Full-text search | Fast, powerful search across billions of log lines |
| Real-time analysis | Near-instant indexing and querying |
| Rich visualizations | Kibana dashboards, maps, ML anomaly detection |
| Scalable | Horizontally scales to petabytes of data |
| Ecosystem | Beats, APM, SIEM, Observability all built-in |

---

## Architecture

```
+----------+     +----------+     +---------------+     +--------+
| Filebeat | --> | Logstash | --> | Elasticsearch | <-- | Kibana |
+----------+     +----------+     +---------------+     +--------+
| Metricbeat|         |                  |
+-----------+    (filter,             (index,
| Heartbeat |    transform)           search)
+-----------+
       |
  +-----------+
  | Elastic   |
  | Agent     |  (unified agent replacing individual Beats)
  +-----------+
```

---

## Installation

### macOS

```bash
# Using Homebrew
brew tap elastic/tap
brew install elastic/tap/elasticsearch-full
brew install elastic/tap/logstash-full
brew install elastic/tap/kibana-full
brew install elastic/tap/filebeat-full

# Start services
brew services start elastic/tap/elasticsearch-full
brew services start elastic/tap/kibana-full
```

### Linux (Ubuntu/Debian)

```bash
# Import Elastic GPG key
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic-keyring.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/elastic-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list

sudo apt-get update
sudo apt-get install elasticsearch logstash kibana filebeat metricbeat

# Enable and start
sudo systemctl enable --now elasticsearch
sudo systemctl enable --now kibana
```

### Windows

Download MSI installers or ZIP archives from https://www.elastic.co/downloads/.

---

## Docker Compose Setup (Recommended)

```yaml
version: "3.8"

services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.14.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=true
      - ELASTIC_PASSWORD=changeme
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
    volumes:
      - es_data:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "curl -s -u elastic:changeme http://localhost:9200/_cluster/health | grep -q '\"status\":\"green\"\\|\"status\":\"yellow\"'"]
      interval: 30s
      timeout: 10s
      retries: 5

  logstash:
    image: docker.elastic.co/logstash/logstash:8.14.0
    container_name: logstash
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline
      - ./logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml
    ports:
      - "5044:5044"   # Beats input
      - "5000:5000"   # TCP input
      - "9600:9600"   # Monitoring API
    environment:
      - "LS_JAVA_OPTS=-Xms512m -Xmx512m"
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped

  kibana:
    image: docker.elastic.co/kibana/kibana:8.14.0
    container_name: kibana
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
      - ELASTICSEARCH_USERNAME=kibana_system
      - ELASTICSEARCH_PASSWORD=changeme
    ports:
      - "5601:5601"
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped

  filebeat:
    image: docker.elastic.co/beats/filebeat:8.14.0
    container_name: filebeat
    user: root
    volumes:
      - ./filebeat/filebeat.yml:/usr/share/filebeat/filebeat.yml:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/log:/var/log:ro
    depends_on:
      elasticsearch:
        condition: service_healthy
    restart: unless-stopped

volumes:
  es_data:
```

---

## Log Ingestion Pipelines

### Logstash Pipeline Configuration

```ruby
# logstash/pipeline/main.conf

input {
  beats {
    port => 5044
  }

  tcp {
    port => 5000
    codec => json_lines
  }
}

filter {
  # Parse JSON logs
  if [message] =~ /^\{/ {
    json {
      source => "message"
    }
  }

  # Parse Apache/Nginx access logs
  if [fileset][name] == "access" {
    grok {
      match => {
        "message" => '%{IPORHOST:remote_ip} - %{DATA:user_name} \[%{HTTPDATE:access_time}\] "%{WORD:http_method} %{DATA:url} HTTP/%{NUMBER:http_version}" %{NUMBER:response_code} %{NUMBER:body_sent_bytes} "%{DATA:referrer}" "%{DATA:agent}"'
      }
    }
    date {
      match => ["access_time", "dd/MMM/yyyy:HH:mm:ss Z"]
      target => "@timestamp"
    }
    mutate {
      convert => {
        "response_code" => "integer"
        "body_sent_bytes" => "integer"
      }
    }
  }

  # Parse application logs with timestamp
  if [type] == "application" {
    grok {
      match => {
        "message" => "%{TIMESTAMP_ISO8601:log_timestamp} %{LOGLEVEL:log_level} %{GREEDYDATA:log_message}"
      }
    }
    date {
      match => ["log_timestamp", "ISO8601"]
      target => "@timestamp"
    }
  }

  # GeoIP enrichment
  if [remote_ip] {
    geoip {
      source => "remote_ip"
      target => "geoip"
    }
  }

  # Remove unnecessary fields
  mutate {
    remove_field => ["host", "agent", "ecs"]
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    user => "elastic"
    password => "changeme"
    index => "%{[@metadata][beat]}-%{+YYYY.MM.dd}"
  }

  # Debug output (disable in production)
  # stdout { codec => rubydebug }
}
```

### Logstash Configuration

```yaml
# logstash/config/logstash.yml
http.host: "0.0.0.0"
xpack.monitoring.elasticsearch.hosts: ["http://elasticsearch:9200"]
xpack.monitoring.elasticsearch.username: "logstash_system"
xpack.monitoring.elasticsearch.password: "changeme"
pipeline.workers: 2
pipeline.batch.size: 125
```

---

## Filebeat Configuration

```yaml
# filebeat/filebeat.yml
filebeat.inputs:
  - type: log
    enabled: true
    paths:
      - /var/log/*.log
      - /var/log/syslog
    fields:
      type: syslog

  - type: container
    paths:
      - /var/lib/docker/containers/*/*.log
    processors:
      - add_docker_metadata:
          host: "unix:///var/run/docker.sock"

filebeat.modules:
  - module: nginx
    access:
      enabled: true
    error:
      enabled: true

  - module: system
    syslog:
      enabled: true
    auth:
      enabled: true

output.logstash:
  hosts: ["logstash:5044"]

# Or send directly to Elasticsearch (skip Logstash)
# output.elasticsearch:
#   hosts: ["elasticsearch:9200"]
#   username: "elastic"
#   password: "changeme"

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
```

---

## Metricbeat Configuration

```yaml
# metricbeat.yml
metricbeat.modules:
  - module: system
    metricsets: ["cpu", "memory", "network", "diskio", "filesystem", "process"]
    period: 10s
    processes: [".*"]

  - module: docker
    metricsets: ["container", "cpu", "diskio", "memory", "network"]
    hosts: ["unix:///var/run/docker.sock"]
    period: 10s

  - module: elasticsearch
    metricsets: ["node", "node_stats", "cluster_stats"]
    hosts: ["http://elasticsearch:9200"]
    period: 10s

output.elasticsearch:
  hosts: ["elasticsearch:9200"]
  username: "elastic"
  password: "changeme"

setup.kibana:
  host: "kibana:5601"
```

---

## Kibana Dashboards and Visualizations

### Setting Up Index Patterns

1. Navigate to **Management > Stack Management > Kibana > Data Views**
2. Create a data view matching your index pattern (e.g., `filebeat-*`)
3. Select `@timestamp` as the time field

### Common Visualizations

| Type | Use Case |
|---|---|
| Line chart | Request rates over time |
| Bar chart | Error codes distribution |
| Pie chart | Traffic by geographic region |
| Data table | Top error messages |
| Metric | Current request count |
| Map | Geographic request distribution |
| TSVB | Advanced time-series analysis |
| Lens | Drag-and-drop visualization builder |

### Useful KQL (Kibana Query Language) Examples

```
# Filter by log level
log_level: "ERROR"

# Filter by status code range
response_code >= 500

# Full-text search
message: "connection refused"

# Wildcard
kubernetes.pod.name: api-server-*

# Combined filters
log_level: "ERROR" and service.name: "payment-service" and not message: "timeout"
```

---

## Index Lifecycle Management (ILM)

ILM automates index rollover, shrink, and deletion based on policies.

### Create an ILM Policy

```json
PUT _ilm/policy/logs-policy
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "rollover": {
            "max_primary_shard_size": "50gb",
            "max_age": "1d"
          },
          "set_priority": {
            "priority": 100
          }
        }
      },
      "warm": {
        "min_age": "7d",
        "actions": {
          "shrink": {
            "number_of_shards": 1
          },
          "forcemerge": {
            "max_num_segments": 1
          },
          "set_priority": {
            "priority": 50
          }
        }
      },
      "cold": {
        "min_age": "30d",
        "actions": {
          "set_priority": {
            "priority": 0
          }
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
```

### Apply ILM Policy to Index Template

```json
PUT _index_template/logs-template
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "index.lifecycle.name": "logs-policy",
      "index.lifecycle.rollover_alias": "logs",
      "number_of_shards": 3,
      "number_of_replicas": 1
    }
  }
}
```

---

## Elastic Agent and Fleet (Latest)

Elastic Agent is a unified agent that replaces individual Beats. Fleet provides centralized management.

### Key Benefits

- **Single agent** to deploy instead of multiple Beats
- **Centralized management** via Fleet in Kibana
- **Pre-built integrations** for hundreds of data sources
- **Agent policies** for consistent configuration across hosts

### Setting Up Fleet

1. Navigate to **Kibana > Management > Fleet**
2. Add a Fleet Server (self-managed or Elastic Cloud)
3. Create an Agent Policy with desired integrations
4. Install Elastic Agent on target hosts:

```bash
# Download and install
curl -L -O https://artifacts.elastic.co/downloads/beats/elastic-agent/elastic-agent-8.14.0-linux-x86_64.tar.gz
tar xzvf elastic-agent-8.14.0-linux-x86_64.tar.gz
cd elastic-agent-8.14.0-linux-x86_64

# Enroll with Fleet
sudo ./elastic-agent install \
  --url=https://fleet-server:8220 \
  --enrollment-token=YOUR_ENROLLMENT_TOKEN
```

---

## Key Commands

```bash
# Check Elasticsearch cluster health
curl -u elastic:changeme http://localhost:9200/_cluster/health?pretty

# List indices
curl -u elastic:changeme http://localhost:9200/_cat/indices?v

# Check index size and document count
curl -u elastic:changeme http://localhost:9200/_cat/indices/filebeat-*?v&s=index

# Check node stats
curl -u elastic:changeme http://localhost:9200/_nodes/stats?pretty

# Delete old indices
curl -X DELETE -u elastic:changeme http://localhost:9200/filebeat-2024.01.*

# Test Logstash config
/usr/share/logstash/bin/logstash --config.test_and_exit -f /path/to/config

# Check Filebeat status
filebeat test config
filebeat test output

# Filebeat setup (load dashboards and index patterns)
filebeat setup -e

# Metricbeat setup
metricbeat setup -e
```

---

## Best Practices

1. **Sizing**: Plan shard count based on data volume. Aim for 20-40 GB per shard. Avoid thousands of tiny shards.
2. **Memory**: Give Elasticsearch no more than 50% of RAM for the JVM heap (max 31 GB). Leave the rest for OS file cache.
3. **Index Naming**: Use date-based indices (e.g., `logs-2024.04.03`) for easy lifecycle management.
4. **Mapping**: Define explicit mappings for important fields. Avoid dynamic mapping in production for predictability.
5. **Security**: Always enable X-Pack security. Use TLS between nodes and for client connections. Create dedicated roles and users.
6. **Monitoring**: Monitor the Elastic Stack itself using Metricbeat's Elasticsearch module or the Stack Monitoring feature in Kibana.
7. **Backups**: Use the Snapshot and Restore API to back up indices to S3, GCS, or Azure Blob Storage.
8. **Avoid Expensive Queries**: Limit wildcard queries on large indices. Use filters (cached) over queries where possible.
9. **ILM**: Always configure ILM policies to manage index lifecycle and prevent unbounded disk usage.
10. **Migration Path**: For new deployments, prefer Elastic Agent with Fleet over individual Beats for simplified management.

---

## Resources

- [Elastic Documentation](https://www.elastic.co/guide/index.html)
- [Elasticsearch Reference](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [Logstash Filter Plugins](https://www.elastic.co/guide/en/logstash/current/filter-plugins.html)
- [Kibana Guide](https://www.elastic.co/guide/en/kibana/current/index.html)
- [Filebeat Modules](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-modules.html)
- [Fleet and Elastic Agent](https://www.elastic.co/guide/en/fleet/current/index.html)
- [Elastic Community](https://discuss.elastic.co/)
