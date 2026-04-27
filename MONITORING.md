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
| JMX Exporter | 1.5.0 |
| Geode monitored by this stack | 1.15.2 |

## Monitoring Scope

The current monitoring design is centered on BlackWidow as the observability hub. Both Antman and Hulk are active and validated Geode scrape targets.

Current implementation status:

- Phase 1 baseline panels (up, heap, GC, file descriptors) are live and validated in Grafana.
- Phase 2 Geode-specific panels (gets/puts rates, request latency, region entry count, region hit ratio, gateway sender health, member CPU) are live and validated in Grafana as of 2026-04-27.
- Logs exist for the broader LGTM environment, but Geode-specific log labeling still needs validation in Grafana Explore.
- Tempo endpoints are part of the platform design, but Geode-adjacent tracing is not yet implemented.

## Host Inventory

| Host | IP | OS | Role | Status |
| --- | --- | --- | --- | --- |
| BlackWidow | 192.168.0.153 | Ubuntu 24.04 | Monitoring hub for Grafana, Loki, Tempo, Mimir, Alloy | Active |
| Antman | 192.168.0.150 | Rocky Linux 8 | Cluster A locator1 and server1, both expose JMX Exporter for Geode metrics | Active |
| Hulk | 192.168.0.151 | RHEL 8 | Cluster A locator2 and server2, both expose JMX Exporter for Geode metrics | Active |

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
                         | Alloy                            |
                         +----------------+-----------------+
                                          ^
                                          |
                              scrape      | remote_write / push
                                          |
+-----------------------------------------+--------------------------------+
|                                                                            |
|  +-------------------------------+       +-------------------------------+  |
|  | Antman / 192.168.0.150        |       | Hulk / 192.168.0.151         |  |
|  |-------------------------------|       |-------------------------------|  |
|  | Geode locator1 + server1      |       | Geode locator2 + server2     |  |
|  | JMX Exporter :9405, :9404     |       | JMX Exporter :9405, :9404    |  |
|  | Node Exporter :9100 optional  |       | Node Exporter :9100 optional |  |
|  +-------------------------------+       +-------------------------------+  |
+----------------------------------------------------------------------------+

Metrics: Geode JVM -> JMX Exporter -> Alloy -> Mimir -> Grafana
Logs:    Host or container logs -> Alloy -> Loki -> Grafana
Traces:  Instrumented apps -> OTLP -> Tempo -> Grafana
```

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

Recommended follow-up:

- Add separate scrape jobs for Node Exporter on `:9100`.
- Standardize labels across all Geode members before building more dashboards.
- Add relabeling only after the current label set is validated in Grafana Explore.

## Grafana Data Sources

Grafana should be configured with these data sources:

- Mimir for metrics
- Loki for logs
- Tempo for traces

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
- `count(up{job="geode"} == 1)` returns `4` when both locators and both servers are scraped
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

Before creating log panels, inspect the real labels in Loki:

```logql
{}
```

Then narrow to the actual labels observed for Geode-related logs. Do not assume `app="apache_geode"` or any other label until it is confirmed.

## Deployment Sequence

### Monitoring node

1. Ensure Grafana, Loki, Tempo, Mimir, and Alloy are running on BlackWidow.
2. Add or update Alloy scrape jobs for Antman and Hulk.
3. Reload or restart Alloy.
4. Verify targets are up in Grafana or Alloy.
5. Validate queries in Grafana Explore before building dashboards.

### Geode nodes

1. Install the JMX Exporter JAR and config on each host.
2. Add the Java agent argument to the Geode startup command.
3. Restart the Geode member.
4. Confirm the metrics endpoint responds on `:9404` for servers and `:9405` for locators.

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

- Geode-specific log labeling is not yet documented end-to-end.
- Trace instrumentation for Geode-adjacent workloads is not implemented.
- TLS, authentication, and secret management are not documented here.
- Retention, storage sizing, and backup for Loki, Tempo, and Mimir are not covered.
- Full LGTM bootstrap commands are not part of this repo.

## Expansion Plan

### Add Geode logs

1. Identify the Geode log locations on Antman and Hulk.
2. Add Alloy file or journal ingestion.
3. Attach host and member labels.
4. Verify the final Loki label set before creating dashboard panels.

### Add tracing

1. Instrument client applications or services that call Geode.
2. Send OTLP data to BlackWidow on `4317` or `4318`.
3. Correlate traces with logs and metrics in Grafana.


## dummy line
