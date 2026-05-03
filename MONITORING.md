# LGTM Monitoring Guide

## Purpose

This document is the single source of truth for the LGTM deployment used to monitor the Geode lab. It covers the monitoring topology, component versions, host roles, ports, Alloy scrape design, dashboard workflow, and validation steps.

## Current Versions

| Component | Version |
| --- | --- |
| Docker on BlackWidow | 29.3.0 |
| Grafana | 12.4.1 |
| Loki | 3.6.7 |
| Alloy | 1.14.1 |
| Mimir | 3.0.4 |
| Tempo | 2.10.0 |
| JMX Exporter | 1.5.0 |
| Geode monitored by this stack | 1.15.2 |

Note: Alloy, Grafana, Loki, and Mimir run on `:latest` in docker-compose.yml and will upgrade on the next `docker compose pull`. Tempo is the only service pinned to a specific version (`2.10.0`). To pin a service, replace `:latest` with the version tag in `/home/alex/observability-lgtm/docker-compose.yml` and run `docker compose up -d`.

## Monitoring Scope

The current monitoring design is centered on BlackWidow as the observability hub. Both Antman and Hulk are active and validated Geode scrape targets.

Current implementation status:

- Phase 1 baseline panels (up, heap, GC, file descriptors) are live and validated in Grafana.
- Phase 2 Geode-specific panels (gets/puts rates, request latency, region entry count, region hit ratio, gateway sender health, member CPU) are live and validated in Grafana as of 2026-04-27.
- Geode log ingestion is live on Antman and Hulk via Alloy → Loki, validated in Grafana Explore as of 2026-04-27.
- ActivityClientApp tracing is live via OTel Java agent → Tempo, validated in Grafana as of 2026-04-27. Instrumented spans: `geode.connect`, `geode.subscribe`, `geode.put`.
- Phase 3 Cluster B monitoring (Vision + Warmachine metrics and logs) — in progress. JMX Exporter and Alloy agent installation on both hosts required before start scripts are run.

## Host Inventory

| Host | IP | OS | Role | Status |
| --- | --- | --- | --- | --- |
| BlackWidow | 192.168.0.153 | Ubuntu 24.04 | Monitoring hub for Grafana, Loki, Tempo, Mimir, Alloy | Active |
| Antman | 192.168.0.150 | Rocky Linux 8 | Cluster A locator1 and server1, both expose JMX Exporter for Geode metrics | Active |
| Hulk | 192.168.0.151 | RHEL 8 | Cluster A locator2 and server2, both expose JMX Exporter for Geode metrics | Active |
| Vision | 172.22.79.100 (WSL2) | Ubuntu 24.04 | Cluster B locatorB, serverB1, GatewayReceiver; JMX Exporter + Alloy agent | Planned |
| Warmachine | 172.22.79.100 (WSL2) | RHEL 8 | Cluster B serverB2; JMX Exporter + Alloy agent | Planned |

## Port Map

### BlackWidow

| Port | Service | Purpose |
| --- | --- | --- |
| 3000 | Grafana | Dashboards, Explore, alerting UI |
| 3100 | Loki | Log ingestion and query API |
| 3200 | Tempo | Trace storage and query API |
| 4317 | OTLP gRPC | Trace ingestion |
| 4318 | OTLP HTTP | Trace ingestion |
| 9009 | Mimir | Metrics ingestion and query backend |
| 12345 | Alloy | Alloy HTTP or API endpoint if enabled |

### Antman

| Port | Service | Purpose |
| --- | --- | --- |
| 9404 | JMX Exporter | Prometheus-format JVM and Geode metrics |
| 9405 | Locator JMX Exporter | Prometheus-format JVM and Geode metrics for locator1 |
| 9100 | Node Exporter | Optional host-level system metrics |

### Hulk

| Port | Service | Purpose |
| --- | --- | --- |
| 9404 | JMX Exporter | Prometheus-format JVM and Geode metrics |
| 9405 | Locator JMX Exporter | Prometheus-format JVM and Geode metrics for locator2 |
| 9100 | Node Exporter | Optional host-level system metrics |

### Vision

| Port | Service | Purpose |
| --- | --- | --- |
| 9404 | serverB1 JMX Exporter | Scraped by local Alloy agent only — not exposed externally |
| 9405 | locatorB JMX Exporter | Scraped by local Alloy agent only — not exposed externally |
| 9100 | Node Exporter | Optional host-level system metrics |

### Warmachine

| Port | Service | Purpose |
| --- | --- | --- |
| 9404 | serverB2 JMX Exporter | Scraped by local Alloy agent only — not exposed externally |
| 9100 | Node Exporter | Optional host-level system metrics |

Required network access:

- Allow BlackWidow to reach `192.168.0.150:9404` and `192.168.0.150:9405`.
- Allow BlackWidow to reach `192.168.0.151:9404` and `192.168.0.151:9405`.
- Allow BlackWidow to reach `:9100` on any host where Node Exporter is scraped.

## Architecture

```text
                         +----------------------------------+
                         | BlackWidow / 192.168.0.153      |
                         |----------------------------------|
                         | Grafana                          |
                         | Loki                             |
                         | Tempo                            |
                         | Mimir                            |
                         | Alloy (scrapes Cluster A only)   |
                         +-------+----------+--------------+
                                 ^          ^
                       scrape    |          | push (remote_write / logs)
                                 |          |
          +----------------------+    +-----+----------------------------------------------+
          |                           |                                                      |
  +-------+--------------------+      |  Thor / 192.168.0.14 (WSL2 NAT host)                |
  | Cluster A                  |      |  +---------------------------+  +------------------+|
  |                            |      |  | Vision / 172.22.79.100    |  | Warmachine        ||
  | Antman / 192.168.0.150     |      |  |---------------------------|  | 172.22.79.100     ||
  | locator1 + server1         |      |  | locatorB + serverB1       |  | serverB2          ||
  | JMX :9405, :9404           |      |  | JMX :9405, :9404          |  | JMX :9404         ||
  | Alloy (systemd)            |      |  | Alloy (systemd) -------+  |  | Alloy (systemd) --||
  |                            |      |  +------------------------+--+  +----------------+--+|
  | Hulk / 192.168.0.151       |      |                           |                      |   |
  | locator2 + server2         |      |                           +----------+-----------+   |
  | JMX :9405, :9404           |      |                           push via WSL2 NAT          |
  | Alloy (systemd)            |      +------------------------------------------------------+
  +----------------------------+

Cluster A metrics: JMX Exporter -> BlackWidow Alloy (pull/scrape) -> Mimir
Cluster B metrics: JMX Exporter -> Vision/Warmachine Alloy (local scrape + push) -> Mimir
Logs:              Geode log files -> Alloy (on each host) -> Loki
Traces:            ActivityClientApp (Ironman) -> OTLP HTTP -> Tempo

Note: BlackWidow cannot initiate connections to 172.22.79.100 (WSL2 private network).
      Vision and Warmachine Alloy agents push outbound through Thor's WSL2 NAT to BlackWidow.
```

## Configuration File Reference

All config files confirmed from live host inspection on 2026-04-27.

### BlackWidow — Docker stack

Stack root: `/home/alex/observability-lgtm/`

Docker Compose file: `/home/alex/observability-lgtm/docker-compose.yml`

#### Alloy

| Item | Path |
| --- | --- |
| Config (host) | `/home/alex/observability-lgtm/alloy/config.alloy` |
| Config (container) | `/etc/alloy/config.alloy` (bind-mounted read-only) |
| Data volume | `observability-lgtm_alloy-data` → `/var/lib/alloy/data` |
| Docker socket | `/var/run/docker.sock` → `/var/run/docker.sock` (read-only) |
| Previous config backup | `/home/alex/observability-lgtm/alloy/config.alloy.260404` |

#### Grafana

| Item | Path |
| --- | --- |
| Provisioning dir (host) | `/home/alex/observability-lgtm/grafana/provisioning` |
| Provisioning dir (container) | `/etc/grafana/provisioning` (bind-mounted) |
| Data source definitions | `/home/alex/observability-lgtm/grafana/provisioning/datasources/datasources.yaml` |
| Data volume | `observability-lgtm_grafana-storage` → `/var/lib/grafana` |

#### Loki

| Item | Path |
| --- | --- |
| Config | Uses container default — no config file bind-mounted |
| Data volume | `observability-lgtm_loki-data` → `/loki` |

#### Mimir

| Item | Path |
| --- | --- |
| Config (host) | `/home/alex/observability-lgtm/mimir/mimir.yaml` |
| Config (container) | `/etc/mimir.yaml` (bind-mounted read-only) |
| Data volume | `observability-lgtm_mimir-data` → `/data` |

#### Tempo

| Item | Path |
| --- | --- |
| Config (host) | `/home/alex/observability-lgtm/tempo/tempo.yaml` |
| Config (container) | `/etc/tempo.yaml` (bind-mounted read-only) |
| Data volume | `observability-lgtm_tempo-data` → `/var/tempo` |

### Antman — Alloy agent (systemd, not Docker)

| Item | Path |
| --- | --- |
| Alloy config | `/etc/alloy/config.alloy` |
| Geode locator1 logs | `/home/alex/geode_cluster/locator1/locator1.log` |
| Geode locator1 pulse log | `/home/alex/geode_cluster/locator1/pulse.log` |
| Geode server1 logs | `/home/alex/geode_cluster/server1/server1.log` |
| JMX Exporter JAR | `/opt/jmx-exporter/jmx_prometheus_javaagent.jar` |
| JMX Exporter config | `/opt/jmx-exporter/geode-jmx.yml` |

### Hulk — Alloy agent (systemd, not Docker)

| Item | Path |
| --- | --- |
| Alloy config | `/etc/alloy/config.alloy` |
| Geode locator2 logs | `/home/alex/geode_cluster/locator2/locator2.log` |
| Geode locator2 pulse log | `/home/alex/geode_cluster/locator2/pulse.log` |
| Geode server2 logs | `/home/alex/geode_cluster/server2/server2.log` |
| JMX Exporter JAR | `/opt/jmx-exporter/jmx_prometheus_javaagent.jar` |
| JMX Exporter config | `/opt/jmx-exporter/geode-jmx.yml` |

### Vision — Alloy agent (systemd, not Docker)

| Item | Path |
| --- | --- |
| Alloy config | `/etc/alloy/config.alloy` |
| Geode locatorB logs | `/home/alex/geode_cluster_b/locatorB/locatorB.log` |
| Geode serverB1 logs | `/home/alex/geode_cluster_b/serverB1/serverB1.log` |
| JMX Exporter JAR | `/opt/jmx-exporter/jmx_prometheus_javaagent.jar` |
| JMX Exporter config | `/opt/jmx-exporter/geode-jmx.yml` |

### Warmachine — Alloy agent (systemd, not Docker)

| Item | Path |
| --- | --- |
| Alloy config | `/etc/alloy/config.alloy` |
| Geode serverB2 logs | `/home/alex/geode_cluster_b/serverB2/serverB2.log` |
| JMX Exporter JAR | `/opt/jmx-exporter/jmx_prometheus_javaagent.jar` |
| JMX Exporter config | `/opt/jmx-exporter/geode-jmx.yml` |

### WSL2 Network Constraint

Vision and Warmachine are WSL2 guests on Thor sharing IP `172.22.79.100`. BlackWidow (`192.168.0.153`) cannot initiate connections into that address. The data flow is therefore push-based:

- Vision and Warmachine Alloy agents scrape their own JMX Exporter on `127.0.0.1`.
- Both Alloy agents push metrics and logs outbound to `192.168.0.153` through Thor's WSL2 NAT — standard outbound WSL2 routing works without any portproxy rules.
- This differs from Antman and Hulk, where BlackWidow's Alloy container pulls from their LAN IPs.

Repo-side config files: `scripts/Vision/config.alloy` and `scripts/Warmachine/config.alloy`. Deploy to `/etc/alloy/config.alloy` on each host.

### Ironman — ActivityClientApp (Windows)

| Item | Path |
| --- | --- |
| Project root | `d:\Alex\Work\Installs\LGTM-Geode\client\` |
| Maven build file | `d:\Alex\Work\Installs\LGTM-Geode\client\pom.xml` |
| Application source | `d:\Alex\Work\Installs\LGTM-Geode\client\src\main\java\lab\geode\client\ActivityClientApp.java` |
| OTel Java agent | `d:\Alex\Work\Installs\LGTM-Geode\client\opentelemetry-javaagent.jar` |
| Run command | `mvn compile exec:exec` from the `client\` directory |

## Stack Management

### BlackWidow — Docker Compose

All five LGTM services are managed by Docker Compose. The compose file is at `/home/alex/observability-lgtm/docker-compose.yml`.

```bash
cd /home/alex/observability-lgtm

# Start all services detached
docker compose up -d

# Stop all services (containers removed, volumes retained)
docker compose down

# Restart all services
docker compose restart

# Restart a single service after a config change
docker compose restart alloy

# Pull latest images and recreate all containers
docker compose pull && docker compose up -d

# View logs
docker compose logs -f              # all services
docker compose logs -f alloy        # single service
docker compose logs --tail=100 tempo

# Check running status and ports
docker compose ps
```

After editing `alloy/config.alloy` on BlackWidow, restart the Alloy container:

```bash
docker compose restart alloy
```

Alloy validates its config at startup and will not come up if the config has syntax errors. Check `docker compose logs alloy` if the container exits immediately after restart.

### Vision — Alloy systemd (Ubuntu 24.04)

Install Alloy from the Grafana APT repository:

```bash
sudo apt-get install -y gpg
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | \
  sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update && sudo apt-get install -y alloy
```

### Warmachine — Alloy systemd (RHEL 8)

Install Alloy from the Grafana RPM repository:

```bash
cat <<'EOF' | sudo tee /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF
sudo dnf install -y alloy
```

### Deploy config and start Alloy (Vision and Warmachine)

```bash
# Deploy repo config to system path
sudo cp ~/path/to/config.alloy /etc/alloy/config.alloy

# Validate syntax before starting
alloy fmt --write=false /etc/alloy/config.alloy

# Enable and start
sudo systemctl enable --now alloy
sudo systemctl status alloy

# Follow logs
sudo journalctl -u alloy -f
```

### JMX Exporter prerequisites (Vision and Warmachine)

Before running the updated start scripts, install the JMX Exporter JAR and config on each Cluster B host:

```bash
sudo mkdir -p /opt/jmx-exporter
# Copy jmx_prometheus_javaagent.jar from the repo or download the same version used on Antman/Hulk
# Copy geode-jmx.yml (minimal catch-all config — see Geode Metric Exposure section)
sudo chmod 644 /opt/jmx-exporter/jmx_prometheus_javaagent.jar /opt/jmx-exporter/geode-jmx.yml
```

Verify outbound connectivity from Vision/Warmachine to BlackWidow before starting Alloy:

```bash
curl http://192.168.0.153:9009/ready    # Mimir
curl http://192.168.0.153:3100/ready    # Loki
```

Expected: HTTP 200 response from each endpoint.

### Antman / Hulk — Alloy systemd

Alloy on Antman and Hulk runs as a systemd service, not a Docker container.

```bash
# Check service status
sudo systemctl status alloy

# Restart after a config change
sudo systemctl restart alloy

# Follow live logs
sudo journalctl -u alloy -f

# Validate config syntax before restarting
alloy fmt --write=false /etc/alloy/config.alloy
```

Alloy does not support hot reload via SIGHUP in all versions — use `restart` rather than `reload` to be safe.

## Design Rules

- Alloy is the only scraper and collector in this design.
- There is no standalone Prometheus server in the current deployment.
- Grafana is the single UI for dashboards, metric exploration, logs, and traces.
- Geode metrics are exposed through the JMX Exporter Java agent — servers on port `9404`, locators on port `9405`.
- Monitoring configuration should use stable labels such as `job`, `instance`, `app`, and `member`.

## Installation Baseline

The repo documents the LGTM integration and runtime design, not a full platform bootstrap script. The expected installed state on BlackWidow is:

- Grafana running and reachable on port `3000`
- Loki running and reachable on port `3100`
- Tempo running and reachable on port `3200`
- Mimir running and reachable on port `9009`
- Alloy running with scrape and forwarding config

The repo-side Geode prerequisites for monitoring are:

- JMX Exporter JAR installed on each monitored Geode host
- JMX Exporter config file present before the Geode JVM starts
- Geode startup commands include the Java agent argument
- Firewall allows BlackWidow to reach the scrape endpoints

## Geode Metric Exposure

### Antman

The Antman start script launches `locator1` on port 9405 and `server1` on port 9404:

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9405:/opt/jmx-exporter/geode-jmx.yml
```

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/geode-jmx.yml
```

### Hulk

The Hulk start script launches `locator2` on port 9405 and `server2` on port 9404:

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9405:/opt/jmx-exporter/geode-jmx.yml
```

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/geode-jmx.yml
```

### Vision

The Vision start script launches `locatorB` on port 9405 and `serverB1` on port 9404:

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9405:/opt/jmx-exporter/geode-jmx.yml
```

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/geode-jmx.yml
```

### Warmachine

The Warmachine start script launches `serverB2` on port 9404:

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/geode-jmx.yml
```

Note: Vision and Warmachine share `172.22.79.100` but the JMX Exporter ports are bound to `127.0.0.1` and scraped locally by each host's Alloy agent. There is no external port conflict.

Minimal exporter config:

```yaml
startDelaySeconds: 0
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
  - pattern: ".*"
```

Notes:

- The catch-all rule is acceptable for initial validation.
- Narrow the rules later to reduce noise and metric cardinality.

## Alloy Configuration

### Antman Geode scrapes

```alloy
prometheus.scrape "geode_antman_locator1" {
  targets = [
    {
      __address__ = "192.168.0.150:9405",
      instance    = "antman",
      job         = "geode",
      app         = "apache-geode",
      member      = "locator1",
      role        = "locator",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

```alloy
prometheus.scrape "geode_antman_server1" {
  targets = [
    {
      __address__ = "192.168.0.150:9404",
      instance    = "antman",
      job         = "geode",
      app         = "apache-geode",
      member      = "server1",
      role        = "server",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

### Hulk Geode scrapes

```alloy
prometheus.scrape "geode_hulk_locator2" {
  targets = [
    {
      __address__ = "192.168.0.151:9405",
      instance    = "hulk",
      job         = "geode",
      app         = "apache-geode",
      member      = "locator2",
      role        = "locator",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

```alloy
prometheus.scrape "geode_hulk_server2" {
  targets = [
    {
      __address__ = "192.168.0.151:9404",
      instance    = "hulk",
      job         = "geode",
      app         = "apache-geode",
      member      = "server2",
      role        = "server",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

Node Exporter scraping is active on Antman and Hulk via the Alloy agents installed on those hosts. No additional scrape jobs are needed.

### Vision and Warmachine Geode scrapes (push-based)

Because BlackWidow cannot reach `172.22.79.100` directly, Vision and Warmachine each run their own Alloy agent that scrapes JMX locally and pushes to Mimir. The scrape blocks live in `scripts/Vision/config.alloy` and `scripts/Warmachine/config.alloy`.

Vision — locatorB:

```alloy
prometheus.scrape "geode_vision_locatorb" {
  targets = [
    {
      __address__ = "127.0.0.1:9405",
      instance    = "vision",
      job         = "geode",
      app         = "apache-geode",
      member      = "locatorB",
      role        = "locator",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

Vision — serverB1:

```alloy
prometheus.scrape "geode_vision_serverb1" {
  targets = [
    {
      __address__ = "127.0.0.1:9404",
      instance    = "vision",
      job         = "geode",
      app         = "apache-geode",
      member      = "serverB1",
      role        = "server",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

Warmachine — serverB2:

```alloy
prometheus.scrape "geode_warmachine_serverb2" {
  targets = [
    {
      __address__ = "127.0.0.1:9404",
      instance    = "warmachine",
      job         = "geode",
      app         = "apache-geode",
      member      = "serverB2",
      role        = "server",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

## Mimir Configuration

Mimir config file: `/home/alex/observability-lgtm/mimir/mimir.yaml` (bind-mounted read-only into the container as `/etc/mimir.yaml`). Content as of 2026-04-27:

```yaml
multitenancy_enabled: false

server:
  http_listen_port: 9009

common:
  storage:
    backend: filesystem
    filesystem:
      dir: /data/blocks

blocks_storage:
  backend: filesystem
  filesystem:
    dir: /data/blocks

compactor:
  data_dir: /data/compactor

distributor:
  ring:
    kvstore:
      store: inmemory

ingester:
  ring:
    kvstore:
      store: inmemory
    replication_factor: 1

ruler_storage:
  backend: filesystem
  filesystem:
    dir: /data/ruler

store_gateway:
  sharding_ring:
    replication_factor: 1
```

Key notes:
- Single-node deployment (`replication_factor: 1`, `inmemory` kvstore). Not suitable for multi-replica setups.
- All storage uses the local filesystem under `/data` (mapped to the `mimir-data` Docker volume).
- Multitenancy is disabled — all metrics go to the default anonymous tenant. Alloy's `remote_write` URL requires no `X-Scope-OrgID` header.
- The Prometheus query path Grafana uses is `http://mimir:9009/prometheus` — the `/prometheus` suffix is required.

## Grafana Data Sources

Grafana data sources are provisioned automatically from `/home/alex/observability-lgtm/grafana/provisioning/datasources/datasources.yaml`. The file content as of 2026-04-27:

```yaml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: false

  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo:3200
    isDefault: false

  - name: Mimir
    type: prometheus
    access: proxy
    url: http://mimir:9009/prometheus
    isDefault: true
```

Note: The URLs use Docker Compose service names (`loki`, `tempo`, `mimir`), not IP addresses. These resolve only within the Docker network on BlackWidow. Grafana queries from the browser always go through Grafana's proxy — the service names are never exposed to the client.

Minimum expected behavior:

- Explore can query `up{job="geode"}`
- Dashboards can filter on labels that actually exist
- Loki queries are validated against real log labels instead of assumed labels

## Dashboard Implementation

Build dashboards in two phases.

### Phase 1: Proven baseline panels

Start with metrics that are already likely to exist:

- `up{job="geode"}`
- `process_open_fds{job="geode"}`
- `process_resident_memory_bytes{job="geode"}`
- `scrape_duration_seconds{job="geode"}`
- `jvm_memory_used_bytes`
- `jvm_memory_max_bytes`
- `jvm_gc_collection_seconds_sum`

Note: JMX Exporter 1.x uses the OpenMetrics naming convention for memory metrics. The GC metric `jvm_gc_collection_seconds_sum` retains its original name as it is derived directly from JMX MBeans, not the Prometheus Java client library.

Validated panel set (all live in Grafana):

**Members Up** — stat panel
```promql
count(up{job="geode"} == 1)
```

**Member Status** — stat panel, shows per-member up/down state (1 = up, 0 = down)
```promql
up{job="geode", instance=~"$instance", member=~"$member"}
```

**Heap Usage % (per instance)**
```promql
100 *
sum by (instance) (jvm_memory_used_bytes{area="heap", job=~"$job"})
/
sum by (instance) (jvm_memory_max_bytes{area="heap", job=~"$job"} > 0)
```

**Memory Utilization % (per member)**
```promql
100 *
sum by (instance, member) (
  jvm_memory_used_bytes{job="geode", area="heap", instance=~"$instance", member=~"$member"}
)
/
sum by (instance, member) (
  jvm_memory_max_bytes{job="geode", area="heap", instance=~"$instance", member=~"$member"} > 0
)
```

**GC Pause Rate** — time series, unit: seconds/sec, legend: `{{member}} {{gc}}`
```promql
rate(jvm_gc_collection_seconds_sum{job="geode", instance=~"$instance", member=~"$member"}[$__rate_interval])
```

**Process Open File Descriptors** — time series, legend: `{{member}}`
```promql
process_open_fds{job="geode", instance=~"$instance", member=~"$member"}
```

CPU % and Memory % panels require Node Exporter on `:9100` — not yet enabled.

### Phase 2: Geode-specific panels

Metric names confirmed from live JMX exporter endpoints on 2026-04-26. All `gemfire_*` metrics carry at minimum the `member` label from the MBean object name. Alloy adds `job`, `instance`, `app`, and `role` at scrape time. Region metrics also carry `name` (region path, e.g. `/Activity`) and `type="Member"`. Gateway sender metrics carry `gatewaysender` (sender ID) and `type="Member"`.

#### Additional dashboard variable

Add a `$region` variable before building the region panels:

- Query: `label_values(gemfire_region_entrycount{job="geode"}, name)`
- Label: `Region`
- Default: `.*` (all)

#### Gets and Puts Per Second

**Member GET Rate** — time series, unit: ops/sec, legend: `{{member}}`
```promql
gemfire_member_getsrate{job="geode", instance=~"$instance", member=~"$member"}
```

**Member PUT Rate** — time series, unit: ops/sec, legend: `{{member}}`
```promql
gemfire_member_putsrate{job="geode", instance=~"$instance", member=~"$member"}
```

**Cache Server GET Request Rate** — time series, unit: req/sec, legend: `{{member}}`
```promql
gemfire_cacheserver_getrequestrate{job="geode", instance=~"$instance", member=~"$member"}
```

**Cache Server PUT Request Rate** — time series, unit: req/sec, legend: `{{member}}`
```promql
gemfire_cacheserver_putrequestrate{job="geode", instance=~"$instance", member=~"$member"}
```

#### Request Latency

Geode reports these as average latency in nanoseconds.

**GET Request Avg Latency** — time series, unit: ns, legend: `{{member}}`
```promql
gemfire_cacheserver_getrequestavglatency{job="geode", instance=~"$instance", member=~"$member"}
```

**PUT Request Avg Latency** — time series, unit: ns, legend: `{{member}}`
```promql
gemfire_cacheserver_putrequestavglatency{job="geode", instance=~"$instance", member=~"$member"}
```

**Member GET Avg Latency** — time series, unit: ns, legend: `{{member}}`
```promql
gemfire_member_getsavglatency{job="geode", instance=~"$instance", member=~"$member"}
```

**Member PUT Avg Latency** — time series, unit: ns, legend: `{{member}}`
```promql
gemfire_member_putsavglatency{job="geode", instance=~"$instance", member=~"$member"}
```

#### Region Entry Count

**Region Entry Count** — time series, legend: `{{member}} {{name}}`
```promql
gemfire_region_entrycount{job="geode", instance=~"$instance", member=~"$member", name=~"$region"}
```

Note: The `name` label contains the full region path including the leading `/` (e.g. `/Activity`).

#### Region Hit Ratio

**Region Hit Ratio** — time series, unit: ratio (0–1), legend: `{{member}} {{name}}`
```promql
gemfire_region_hitratio{job="geode", instance=~"$instance", member=~"$member", name=~"$region"} >= 0
```

The metric returns `-1.0` when no get operations have occurred yet. The `>= 0` guard suppresses uninitialised values so the panel stays blank rather than showing -1.

#### Off-Heap Usage

Off-heap memory is not configured in this lab, so these metrics currently show `0`. The panels remain useful as a baseline and become meaningful if off-heap is enabled later.

**Off-Heap Used Bytes** — time series, unit: bytes, legend: `{{member}}`
```promql
gemfire_member_offheapusedmemory{job="geode", instance=~"$instance", member=~"$member"}
```

**Off-Heap Used %** — gauge, unit: %, legend: `{{member}}`
```promql
100 *
gemfire_member_offheapusedmemory{job="geode", instance=~"$instance", member=~"$member"}
/
(gemfire_member_offheapmaxmemory{job="geode", instance=~"$instance", member=~"$member"} > 0)
```

#### Gateway Sender Health

**Sender Connected** — stat panel, 1 = connected / 0 = disconnected, legend: `{{member}} {{gatewaysender}}`
```promql
gemfire_gatewaysender_connected{job="geode", instance=~"$instance", member=~"$member"}
```

**Sender Event Queue Depth** — time series, unit: events, legend: `{{member}} {{gatewaysender}}`
```promql
gemfire_gatewaysender_eventqueuesize{job="geode", instance=~"$instance", member=~"$member"}
```

**Sender Batches Dispatched Rate** — time series, unit: batches/sec, legend: `{{member}} {{gatewaysender}}`
```promql
gemfire_gatewaysender_batchesdispatchedrate{job="geode", instance=~"$instance", member=~"$member"}
```

#### Member CPU Usage

**CPU Usage % (per member)** — time series, unit: %, legend: `{{member}}`
```promql
gemfire_member_cpuusage{job="geode", instance=~"$instance", member=~"$member"}
```

This is Geode's own per-member CPU measurement. For host-level CPU, Node Exporter on `:9100` is still required and not yet enabled.

#### Gateway Receiver Health

These panels become populated once Vision and Warmachine are added to the monitoring stack. Use `{__name__=~"gemfire_gatewayreceiver.*"}` in Grafana Explore to confirm the exact metric names after the first scrape.

**Receiver Running** — stat panel, 1 = running, legend: `{{member}}`
```promql
gemfire_gatewayreceiver_running{job="geode", instance=~"$instance", member=~"$member"}
```

**Receiver Connections** — time series, unit: connections, legend: `{{member}}`
```promql
gemfire_gatewayreceiver_connectionsload{job="geode", instance=~"$instance", member=~"$member"}
```

**Receiver Events Received Rate** — time series, unit: events/sec, legend: `{{member}}`
```promql
gemfire_gatewayreceiver_eventsreceivedrate{job="geode", instance=~"$instance", member=~"$member"}
```

**Receiver Avg Batch Processing Time** — time series, unit: ms, legend: `{{member}}`
```promql
gemfire_gatewayreceiver_avgbatchprocessingtime{job="geode", instance=~"$instance", member=~"$member"}
```

Note: Exact metric names are confirmed from a live JMX endpoint. If any panel shows no data after Vision/Warmachine Alloy is running, run `{__name__=~"gemfire_gatewayreceiver.*"}` in Mimir Explore to discover the real names and update accordingly.

## Validation Workflow

### Network validation from BlackWidow

```bash
curl http://192.168.0.150:9404/metrics
curl http://192.168.0.150:9405/metrics
curl http://192.168.0.151:9404/metrics
curl http://192.168.0.151:9405/metrics
```

Optional host metric validation:

```bash
curl http://192.168.0.150:9100/metrics
curl http://192.168.0.151:9100/metrics
```

Expected result:

- HTTP connectivity succeeds
- Prometheus-format metrics are returned

### Network validation for Cluster B (from Vision or Warmachine directly)

Cluster B JMX Exporters are localhost-only and cannot be validated from BlackWidow. Validate from within each WSL2 host:

```bash
# On Vision
curl http://127.0.0.1:9405/metrics    # locatorB
curl http://127.0.0.1:9404/metrics    # serverB1

# On Warmachine
curl http://127.0.0.1:9404/metrics    # serverB2
```

Verify that Vision and Warmachine Alloy agents can reach BlackWidow:

```bash
curl http://192.168.0.153:9009/ready    # Mimir
curl http://192.168.0.153:3100/ready    # Loki
```

After Alloy is running, confirm metrics arrived in Grafana Explore (Mimir data source):

```promql
up{job="geode", instance="vision"}
up{job="geode", instance="warmachine"}
```

### Grafana and Mimir validation

Run these PromQL queries in Grafana Explore against Mimir:

```promql
up{job="geode"}
```

```promql
process_open_fds{job="geode"}
```

```promql
scrape_duration_seconds{job="geode"}
```

Expected result:

- `up{job="geode"}` returns `1` for healthy targets
- `count(up{job="geode"} == 1)` returns `4` for Cluster A only (locator1, server1, locator2, server2); returns `7` when all Cluster B members are also scraped (+ locatorB, serverB1, serverB2)
- Series carry the expected labels such as `instance`, `job`, `app`, `member`, and `role`

### Metric discovery

Use Explore to find the real metric set before building Geode-specific dashboards:

```promql
{__name__=~"jvm_.*"}
```

```promql
{__name__=~"node_.*"}
```

```promql
{__name__=~".*geode.*"}
```

### Loki validation

Confirmed Geode log label set as of 2026-04-27 (from live Loki `/loki/api/v1/labels`):

| Label | Values |
| --- | --- |
| `job` | `geode` |
| `app` | `apache-geode` |
| `cluster` | `production` |
| `instance` | `antman`, `hulk`, `vision` (planned), `warmachine` (planned) |
| `host` | `antman`, `hulk`, `vision` (planned), `warmachine` (planned) |
| `member` | `locator1`, `server1`, `locator2`, `server2`, `locatorB` (planned), `serverB1` (planned), `serverB2` (planned) |
| `log_type` | `locator`, `server` |
| `filename` | full path to the log file, added automatically by Alloy |

Validated LogQL queries:

```logql
{job="geode"}
```

```logql
{job="geode", instance="antman"}
```

```logql
{job="geode", member="server1"}
```

```logql
{job="geode", log_type="locator"}
```

Note: Geode members that are idle for more than one hour will not appear in the default Loki label window. Set the Grafana Explore time range to **Last 6 hours** or wider when querying a cluster that has been quiet. The data is present in Loki — it is a query window issue, not a pipeline failure.

## TraceQL Reference

Tempo uses TraceQL for trace search. Always use the **TraceQL** tab in Grafana Explore — the Search tab does not support attribute filtering.

### Syntax rules

| Scope | Prefix | Example |
| --- | --- | --- |
| Resource attributes | `resource.` | `resource.service.name` |
| Span attributes | `span.` | `span.geode.region` |
| Intrinsic fields | none | `name`, `duration`, `status` |

### Query patterns

**All traces from ActivityClientApp**
```
{resource.service.name="activity-client"}
```

**Filter by span name**
```
{resource.service.name="activity-client" && name="geode.put"}
```

**Slow operations (over 100 ms)**
```
{resource.service.name="activity-client" && duration > 100ms}
```

**Filter by Geode region**
```
{span.geode.region="/Activity"}
```

**Show specific attributes in results**
```
{resource.service.name="activity-client"} | select(span.geode.key, span.geode.region, duration)
```

**Find errored spans**
```
{resource.service.name="activity-client" && status=error}
```

**Slowest spans across all services**
```
{duration > 1s}
```

Note: `resource.service.name` is the correct TraceQL syntax. The shorthand `service.name` (without prefix) produces a parse error in Tempo 2.x.

Note: Tempo's ingester requires approximately 15 seconds after container start before search queries succeed. If `/ready` at `http://192.168.0.153:3200/ready` returns `Ingester not ready`, wait and retry.

## Correlation Workflow

The three signals (metrics, logs, traces) share the `member` label and timestamp, enabling time- and label-based correlation. Geode's internal log files do not include OTel trace IDs, so trace-to-log linking is time-based rather than ID-based.

### Metrics → Logs

1. In Grafana Explore (Mimir data source), identify a spike on a specific member, e.g. `server1`.
2. Note the exact time window.
3. Click the split-pane icon (top right of Explore) to open a second panel.
4. Select the **Loki** data source and set the same time range.
5. Query logs for that member:
   ```logql
   {job="geode", member="server1"}
   ```
6. Look for `WARN` or `ERROR` lines in the same window as the metric anomaly.

### Traces → Logs

1. Open a trace in Grafana Explore (Tempo data source).
2. Note the root span start time and duration.
3. Open a split pane with the **Loki** data source and set the same time range.
4. Query by instance to narrow the log scope:
   ```logql
   {job="geode", instance="antman"}
   ```
5. Correlate Geode connection events or warnings with the span timeline.

### Logs → Metrics

1. Find a warning or error line in Loki Explore and note its timestamp.
2. Open a split pane with the **Mimir** data source.
3. Set the same time window and check the relevant Geode metric for that member:
   ```promql
   gemfire_member_getsrate{job="geode", member="server1"}
   ```

### Future: trace ID linking

Grafana's **Derived Fields** feature can create clickable links from Loki log lines directly to a trace in Tempo, but only if the application writes trace IDs into its log output. Geode's internal logs do not include trace IDs. If a future instrumented service writes structured logs with an `traceID` field, add a Derived Field in the Loki data source configuration pointing to `http://192.168.0.153:3200/explore?traceId=${__value.raw}`.

## Deployment Sequence

### Monitoring node

1. Ensure Grafana, Loki, Tempo, Mimir, and Alloy are running on BlackWidow.
2. Add or update Alloy scrape jobs for Antman and Hulk.
3. Reload or restart Alloy.
4. Verify targets are up in Grafana or Alloy.
5. Validate queries in Grafana Explore before building dashboards.

### Geode nodes (Cluster A — Antman and Hulk)

1. Install the JMX Exporter JAR and config on each host.
2. Add the Java agent argument to the Geode startup command.
3. Restart the Geode member.
4. Confirm the metrics endpoint responds on `:9404` for servers and `:9405` for locators.

### Geode nodes (Cluster B — Vision and Warmachine)

1. Install the JMX Exporter JAR and config at `/opt/jmx-exporter/` on Vision and Warmachine.
2. Install Alloy via package manager (APT on Vision, DNF on Warmachine).
3. Deploy `scripts/Vision/config.alloy` and `scripts/Warmachine/config.alloy` to `/etc/alloy/config.alloy` on each host.
4. Enable and start Alloy: `sudo systemctl enable --now alloy`.
5. Verify outbound connectivity: `curl http://192.168.0.153:9009/ready` from each host.
6. Start Cluster B using the updated start scripts (JMX Exporter args are now included).
7. Confirm JMX endpoints respond locally: `curl http://127.0.0.1:9404/metrics` and `curl http://127.0.0.1:9405/metrics` (Vision only for 9405).
8. Validate in Grafana Explore: `up{job="geode", instance="vision"}` and `up{job="geode", instance="warmachine"}` return `1`.

## Known Issues

| Issue | Cause | Resolution |
| --- | --- | --- |
| JMX Exporter JAR downloaded as HTML | Wrong download URL | Use a verified binary artifact source |
| Geode process fails to start after adding the agent | Exporter config path missing | Create the YAML file before startup |
| Metrics endpoint unreachable | Firewall block on `9404` or `9405` | Open access from BlackWidow to the Geode host |
| Metrics missing in Grafana | Wrong scrape target or labels | Correct the Alloy target and validate labels in Explore |
| Confusion about Prometheus | No standalone Prometheus is deployed | Use Alloy as the scraper and forwarder |
| Empty Grafana variables | Queries assume labels that do not exist | Build variables only from validated labels |

## Current Gaps

- TLS, authentication, and secret management are not documented here.
- Retention, storage sizing, and backup for Loki, Tempo, and Mimir are not covered.
- Full LGTM bootstrap commands are not part of this repo.

## Expansion Plan

### Add Geode logs — complete

Alloy agents on Antman and Hulk tail the following log files and forward to Loki on BlackWidow:

| Host | Member | Log path |
| --- | --- | --- |
| Antman | locator1 | `/home/alex/geode_cluster/locator1/locator1.log` |
| Antman | locator1 | `/home/alex/geode_cluster/locator1/pulse.log` |
| Antman | server1 | `/home/alex/geode_cluster/server1/server1.log` |
| Hulk | locator2 | `/home/alex/geode_cluster/locator2/locator2.log` |
| Hulk | locator2 | `/home/alex/geode_cluster/locator2/pulse.log` |
| Hulk | server2 | `/home/alex/geode_cluster/server2/server2.log` |

Config location on each host: `/etc/alloy/config.alloy` under the `loki.source.file "geode"` component.

### Add Cluster B logs — planned

Alloy agents on Vision and Warmachine will tail the following log files and forward to Loki on BlackWidow:

| Host | Member | Log path |
| --- | --- | --- |
| Vision | locatorB | `/home/alex/geode_cluster_b/locatorB/locatorB.log` |
| Vision | serverB1 | `/home/alex/geode_cluster_b/serverB1/serverB1.log` |
| Warmachine | serverB2 | `/home/alex/geode_cluster_b/serverB2/serverB2.log` |

Config location on each host: `/etc/alloy/config.alloy` under the `loki.source.file "geode"` component. See `scripts/Vision/config.alloy` and `scripts/Warmachine/config.alloy`.

### Add tracing — complete

ActivityClientApp on Ironman is instrumented with the OpenTelemetry Java agent and sends traces directly to Tempo on BlackWidow via OTLP HTTP. Validated in Grafana as of 2026-04-27.

#### Setup

| Item | Detail |
| --- | --- |
| OTel Java agent | `opentelemetry-javaagent.jar` (v2.27.0) at `d:\Alex\Work\Installs\LGTM-Geode\client\` |
| Transport | OTLP HTTP → `http://192.168.0.153:4318` (direct to Tempo, no Alloy in path) |
| Build | `d:\Alex\Work\Installs\LGTM-Geode\client\pom.xml` — `geode-core 1.15.1` + `opentelemetry-api 1.38.0` |
| Run | `mvn compile exec:exec` from the `client\` directory |

#### Instrumented spans

| Span name | Operation | Key attributes |
| --- | --- | --- |
| `geode.connect` | ClientCache creation and locator handshake | `geode.locator.host`, `geode.locator.port` |
| `geode.subscribe` | Region interest registration | `geode.region` |
| `geode.put` | Each region.put call | `geode.region`, `geode.key` |

#### Validated TraceQL queries

```
{resource.service.name="activity-client"}
```

```
{resource.service.name="activity-client"} | select(span.geode.region)
```

Note: TraceQL uses `resource.service.name`, not `service.name`. Grafana's Tempo data source passes the query directly — use the TraceQL tab in Explore, not the Search tab, for attribute-based filtering.

Note: Tempo's ingester requires ~15 seconds after container start before it accepts search queries. If `/ready` returns `Ingester not ready`, wait and retry.
