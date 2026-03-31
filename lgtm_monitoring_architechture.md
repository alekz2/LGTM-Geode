# Apache Geode + LGTM Monitoring Architecture

## 1. Purpose

This document defines the monitoring architecture for an Apache Geode environment using the LGTM stack:

- Loki for logs
- Grafana for visualization and alerting
- Tempo for traces
- Mimir for metrics storage
- Grafana Alloy for collection, scraping, and forwarding

The current implementation is centered on one active Geode node (`Antman`) and one monitoring node (`Blackwidow`), with a second Geode node (`Hulk`) planned for expansion.

## 2. Goals

- Centralize metrics, logs, and traces in the LGTM stack
- Expose JVM and Geode runtime metrics through JMX Exporter
- Scrape and forward metrics with Alloy instead of standalone Prometheus
- Make Grafana the single UI for observability
- Keep the design easy to extend to additional Geode members

## 3. Scope and Assumptions

### In Scope

- Geode JVM metrics exposed through JMX Exporter
- Remote scraping from the monitoring node
- Metrics storage in Mimir
- Log ingestion through Alloy into Loki
- Trace ingestion readiness through Tempo
- Initial Grafana dashboards and validation queries

### Out of Scope

- Geode application tracing instrumentation
- Alert rule design
- Long-term retention tuning
- TLS, authentication, and secret-management hardening

### Key Assumptions

- `Blackwidow` hosts the LGTM platform components
- `Antman` runs an Apache Geode locator and server process
- `Hulk` will later be configured using the same pattern as `Antman`
- Alloy is the only collector and scrape engine in this design
- Geode metrics are exposed on port `9404` by the JMX Exporter Java agent

## 4. Infrastructure Layout

| Hostname | IP Address | Role | OS | Key Components | Status |
|----------|------------|------|----|----------------|--------|
| `Blackwidow` | `192.168.0.153` | Monitoring node | Ubuntu 24.04 | Grafana, Loki, Tempo, Mimir, Alloy | Active |
| `Antman` | `192.168.0.150` | Geode node | Rocky Linux 8 | Geode Locator, Geode Server, JMX Exporter, Node Exporter | Active |
| `Hulk` | `192.168.0.151` | Geode node | RHEL 8 | Geode, JMX Exporter, Node Exporter | Planned |

## 5. Network and Port Map

### `Antman` (`192.168.0.150`, Rocky Linux 8)

| Port | Service | Purpose |
|------|---------|---------|
| `10334` | Geode Locator | Cluster membership and discovery |
| `40404` | Geode Server | Cache server traffic |
| `7071` | Geode REST API | Development REST access |
| `1099` | JMX Manager | JMX management endpoint |
| `9404` | JMX Exporter | Prometheus-format JVM and Geode metrics |
| `9100` | Node Exporter | Host-level system metrics |

Required firewall access:

- Allow `9404/tcp` from `Blackwidow` to `Antman`
- Allow `9100/tcp` from `Blackwidow` to `Antman` if host metrics are scraped

### `Blackwidow` (`192.168.0.153`, Ubuntu 24.04)

| Port | Service | Purpose |
|------|---------|---------|
| `3000` | Grafana | Dashboards, explore, alerting UI |
| `3100` | Loki | Log ingestion and query API |
| `3200` | Tempo | Trace storage and query API |
| `4317` | OTLP gRPC | Trace ingestion |
| `4318` | OTLP HTTP | Trace ingestion |
| `9009` | Mimir | Metrics ingestion and query backend |
| `12345` | Alloy | Alloy HTTP/API endpoint if enabled |

## 6. Architecture Diagram

```text
                         +----------------------------------+
                         | Blackwidow / 192.168.0.153       |
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
|  | Geode Locator + Server        |       | Geode Locator/Server          |  |
|  | JMX Exporter :9404            |       | JMX Exporter :9404            |  |
|  | Node Exporter :9100           |       | Node Exporter :9100           |  |
|  +-------------------------------+       +-------------------------------+  |
|                                                                            |
+----------------------------------------------------------------------------+

Metrics: Geode JVM -> JMX Exporter -> Alloy -> Mimir -> Grafana
Logs:    Host/app logs -> Alloy -> Loki -> Grafana
Traces:  Instrumented apps -> OTLP -> Tempo -> Grafana
```

## 7. Data Flows

### Metrics Flow

1. Apache Geode runs inside the JVM on `Antman`.
2. JMX Exporter is attached as a Java agent and exposes Prometheus-format metrics on `:9404`.
3. Alloy on `Blackwidow` scrapes that endpoint on a fixed interval.
4. Alloy forwards the metrics to Mimir using `prometheus.remote_write`.
5. Grafana queries Mimir for dashboards, exploration, and alerts.

### Logs Flow

1. Docker or host logs are collected by Alloy.
2. Alloy forwards log streams to Loki.
3. Grafana queries Loki for log exploration and correlation.

### Trace Flow

1. Instrumented applications send OTLP data to `Blackwidow`.
2. Tempo stores and indexes trace data.
3. Grafana visualizes traces and correlates them with logs and metrics.

Current state:

- Metrics are implemented
- Logs exist for the broader LGTM environment
- Tracing endpoints are ready but Geode-related application traces are not yet in use

## 8. Component Configuration

### 8.1 Geode Node Configuration on `Antman`

Attach JMX Exporter to the Geode JVM:

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/geode-jmx.yml
```

Minimal exporter configuration:

```yaml
startDelaySeconds: 0
lowercaseOutputName: true
lowercaseOutputLabelNames: true
rules:
  - pattern: ".*"
```

Notes:

- This broad catch-all rule is acceptable for initial validation.
- For production use, narrow the ruleset to reduce cardinality and irrelevant JVM/JMX noise.
- Keep the exporter YAML on disk before starting Geode, or the JVM will fail to launch with the configured agent argument.

### 8.2 Alloy Configuration on `Blackwidow`

Example Geode scrape job:

```alloy
prometheus.scrape "geode_antman_server1" {
  targets = [
    {
      __address__ = "192.168.0.150:9404",
      instance    = "antman",
      job         = "geode",
      app         = "apache-geode",
      member      = "server1",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

Recommended follow-up additions:

- Add a separate scrape job for Node Exporter on `:9100`
- Standardize labels across all Geode members
- Add relabeling if hostnames or cluster labels need normalization

### 8.3 Grafana Data Sources

Grafana should be configured with these data sources:

- Mimir for metrics
- Loki for logs
- Tempo for traces

Minimum expectation:

- Grafana Explore can query `up{job="geode"}`
- Dashboards can filter by `instance`, `job`, and `member`

## 9. Deployment Sequence

### Geode Node

1. Install the JMX Exporter JAR on `Antman`
2. Create `/opt/jmx-exporter/geode-jmx.yml`
3. Add the Java agent option to the Geode startup command
4. Restart the Geode member
5. Verify `curl http://<antman-ip>:9404/metrics` returns Prometheus text output

### Monitoring Node

1. Ensure Alloy is running on `Blackwidow`
2. Add the Geode scrape configuration
3. Reload or restart Alloy
4. Confirm metrics are arriving in Mimir
5. Build or import Grafana dashboards

## 10. Validation Checklist

### Network Validation

Run from `Blackwidow`:

```bash
curl http://192.168.0.150:9404/metrics
```

Expected result:

- HTTP connectivity succeeds
- Prometheus-format metrics are returned

Optional host metrics validation:

```bash
curl http://192.168.0.150:9100/metrics
```

### Alloy Validation

Validate in Alloy or Grafana that the scrape target is healthy.

Expected result:

- Target status is `up`
- The scrape interval is stable
- Labels are attached as expected

### Grafana / Mimir Validation

Use these PromQL queries:

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

- `up{job="geode"}` returns `1`
- The `instance="antman"` label is present
- JVM process metrics appear consistently across scrapes

## 11. Dashboard Recommendations

### Initial Validation Dashboard

Use these first panels:

- `up{job="geode"}`
- `process_open_fds{job="geode"}`
- `process_resident_memory_bytes{job="geode"}`
- `scrape_duration_seconds{job="geode"}`

### Next Dashboard Iteration

Build panels for:

- JVM heap usage
- GC activity and pause behavior
- Thread counts
- CPU and file descriptor usage
- Geode-specific cache and region metrics, once confirmed in the exporter output

## 12. Known Issues and Resolutions

| Issue | Cause | Resolution |
|------|-------|------------|
| JMX Exporter JAR downloaded as HTML | Incorrect download URL | Use the Maven artifact URL or another verified binary source |
| Geode process failed to start | Missing exporter YAML referenced by the Java agent | Create `geode-jmx.yml` before startup |
| Metrics endpoint unreachable | Firewall blocked port `9404` | Open `9404/tcp` from `Blackwidow` |
| Metrics absent in Grafana | Wrong target IP address | Correct Alloy target to `192.168.0.150:9404` |
| Compose command failed | Executed from the wrong directory | Run from the LGTM deployment directory |
| Architecture confusion about Prometheus | No standalone Prometheus server was deployed | Use Alloy as the scraper and forwarder |

## 13. Risks and Gaps

- The catch-all JMX Exporter rule can create noisy or high-cardinality metrics.
- No alerting strategy is documented yet.
- No TLS or authentication model is documented for Grafana, Alloy, or scrape endpoints.
- Log collection for Geode-specific logs is not described yet.
- Trace readiness exists, but no Geode-adjacent application instrumentation is defined.
- Retention, storage sizing, and backup strategy for Loki, Tempo, and Mimir are not covered.

## 14. Expansion Plan

### Add `Hulk`

1. Install JMX Exporter
2. Reuse the same exporter YAML pattern
3. Add a new Alloy scrape target
4. Apply consistent labels such as `instance="hulk"` and the correct `member`

### Add Geode Logs

1. Identify Geode log file locations
2. Configure Alloy file or journal scraping
3. Attach labels for cluster, host, and member identity
4. Forward to Loki

### Add Tracing

1. Instrument client applications or services that talk to Geode
2. Export traces via OTLP to `Blackwidow`
3. Correlate traces with logs and metrics in Grafana

## 15. Summary

This architecture establishes a practical observability baseline for Apache Geode using Alloy and the LGTM stack.

Implemented today:

- Centralized Geode metrics scraping through Alloy
- Metrics storage in Mimir
- Visualization in Grafana
- Platform readiness for logs and traces

Recommended next actions:

- Add Node Exporter scraping for host-level visibility
- Narrow the JMX Exporter rules for production use
- Define alerting and security controls
- Extend the same pattern to `Hulk`
