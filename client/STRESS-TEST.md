# JVM Stress Test App

## Purpose

This document describes `StressTestApp`, a standalone Java application for generating controlled JVM load so that performance metrics — heap, GC, threads, CPU — can be observed end-to-end in the LGTM stack (Mimir and Grafana). It complements the Geode cluster metrics by providing a dedicated, controllable signal source for validating dashboards, alert thresholds, and Alloy scrape configuration.

## Host

| Property | Value |
| --- | --- |
| Host | Ironman |
| IP | 192.168.0.53 |
| OS | Windows 11 |
| Repo root | `D:\Alex\Work\Installs\LGTM-Geode` |

All commands in this document are run from the repo root on Ironman unless stated otherwise.

## Files

| File | Purpose |
| --- | --- |
| `client\src\main\java\lab\geode\client\StressTestApp.java` | Application source (pure Java, no external dependencies) |
| `client\jmx-stress-config.yml` | JMX Exporter catch-all config for Prometheus scraping |
| `client\run_stress.bat` | Windows CMD launch script that wires in the JMX Exporter agent |
| `client\out\lab\geode\client\StressTestApp*.class` | Compiled output, shared with ActivityClientApp |

## Prerequisites

- Java 11 or later (`java` and `javac` on PATH)
- `jmx_prometheus_javaagent.jar` present on Ironman — set the path via the `JMX_JAR` environment variable before running the script
- Network path open from BlackWidow (192.168.0.153) to Ironman (192.168.0.53) on port `9406`

No Maven, Gradle, or third-party JARs are required. The app uses only standard JDK classes.

## Port

| Port | Purpose |
| --- | --- |
| 9406 | JMX Exporter Prometheus endpoint |

Port 9406 is chosen to avoid collisions with existing Geode endpoints: 9404 (Geode server JMX) and 9405 (Geode locator JMX).

## Compilation

Run from `D:\Alex\Work\Installs\LGTM-Geode`:

```cmd
javac -d client\out client\src\main\java\lab\geode\client\StressTestApp.java
```

The compiled classes land in `client\out\lab\geode\client\`, the same directory used by `ActivityClientApp`.

## Running

All commands below are run from `D:\Alex\Work\Installs\LGTM-Geode` on Ironman.

### Without JMX agent (quick test)

```cmd
java -cp client\out lab.geode.client.StressTestApp --mode baseline --duration 30 --interval 5
```

### With JMX metrics (normal usage)

Set environment variables and call the batch script:

```cmd
set JMX_JAR=C:\opt\jmx-exporter\jmx_prometheus_javaagent.jar
set MODE=heap
set DURATION=120
set INTENSITY=high
client\run_stress.bat
```

All parameters are controlled by environment variables set before calling the script:

| Variable | Default | Description |
| --- | --- | --- |
| `JMX_JAR` | `C:\opt\jmx-exporter\jmx_prometheus_javaagent.jar` | Path to JMX Exporter agent JAR |
| `JMX_PORT` | `9406` | Port to expose Prometheus metrics on |
| `MODE` | `heap` | Stress mode |
| `DURATION` | `60` | Run duration in seconds |
| `INTENSITY` | `medium` | Load intensity |
| `THREADS` | _(from intensity)_ | Override thread count |
| `INTERVAL` | `5` | Stats print interval in seconds |

> **Note:** The JMX agent does not support paths with spaces in the `-javaagent` argument on Windows. Place `jmx_prometheus_javaagent.jar` and `jmx-stress-config.yml` in a path with no spaces (e.g. `C:\opt\jmx-exporter\`).

## CLI Reference

| Parameter | Values | Default | Notes |
| --- | --- | --- | --- |
| `--mode` | `heap` `threads` `cpu` `baseline` `all` | required | See modes below |
| `--duration` | integer seconds | `60` | How long the test runs |
| `--intensity` | `low` `medium` `high` | `medium` | Controls thread count and heap target |
| `--threads` | integer | from intensity | Overrides thread count for `threads` and `cpu` modes; ignored for `baseline` |
| `--interval` | integer seconds | `5` | How often `[STATS]` lines are printed |

### Intensity Defaults

| Level | Thread count | Heap target | Chunk size |
| --- | --- | --- | --- |
| `low` | 10 | 32 MB | 1 MB |
| `medium` | 50 | 128 MB | 4 MB |
| `high` | 200 | 512 MB | 16 MB |

### JVM Heap Sizing

| Scenario | Recommended `-Xmx` |
| --- | --- |
| `heap` or `all` at `low` | default (no flag needed) |
| `heap` or `all` at `medium` | `-Xmx512m` |
| `heap` at `high` | `-Xmx768m` (set in `run_stress.bat`) |
| `all` at `high` | `-Xmx1g` (edit `JVM_OPTS` in `run_stress.bat`) |

## Stress Modes

### `heap`

Continuously allocates and releases `byte[]` arrays to generate heap pressure and GC cycles. The stressor fills live objects up to the intensity target, pauses briefly so GC can observe the full heap, then releases half the live data to trigger collection. This cycle repeats until the duration expires.

Observable signals: heap used (MB), GC collection count, GC collection time (ms).

### `threads`

Spawns N daemon threads, each alternating between a short sleep and a small array sort. The purpose is to show a sustained elevated thread count and demonstrate the impact of thread pool sizing on JVM thread metrics.

Observable signals: live thread count, peak thread count, daemon thread count.

### `cpu`

Spawns N threads each running a tight Sieve of Eratosthenes loop. Drives CPU utilization without allocating significant heap.

Observable signals: process CPU load percentage, live thread count.

### `baseline`

No artificial load. The JVM runs idle, exposing only its natural memory and thread overhead. Use this to establish a healthy baseline before running stress modes.

Observable signals: all metrics at rest values.

### `all`

Runs `heap`, `threads`, and `cpu` stressors simultaneously. Use this to observe combined resource pressure and potential interaction effects (e.g., GC pauses while threads are running, CPU contention from GC and compute threads together).

## Output Format

Every line written to stdout has a `[TAG]` prefix so Alloy log scraping (Loki) can filter by tag if a log-scrape job is configured later.

```
[START] mode=heap duration=120s intensity=high threads=200 interval=5s
[HEAP]  Starting. Target=512MB chunk=16MB
[STATS] heap=347/768MB nonheap=42MB threads=9/9/8d gc=12/88ms cpu=3.2%
[STATS] heap=512/768MB nonheap=42MB threads=9/9/8d gc=18/134ms cpu=5.7%
[HEAP]  Stopped.
[DONE]  Stress test complete.
```

`[STATS]` field reference:

| Field | Description |
| --- | --- |
| `heap=used/maxMB` | JVM heap — used and configured maximum |
| `nonheap=usedMB` | Non-heap (metaspace, code cache) |
| `threads=live/peak/daemoncount` | Live, peak, and daemon thread counts |
| `gc=count/timeMs` | Cumulative GC collection count and wall time across all collectors |
| `cpu=pct` | Process CPU load from `com.sun.management.OperatingSystemMXBean`; `N/A` on first sample |

## LGTM Integration

### Alloy scrape stanza

Add the following block to the Alloy configuration on BlackWidow (192.168.0.153) to pull Ironman's JVM metrics into Mimir:

```alloy
prometheus.scrape "stress_test_ironman" {
  targets = [
    {
      __address__ = "192.168.0.53:9406",
      instance    = "ironman",
      job         = "stress-test",
      app         = "jvm-stress",
    },
  ]
  scrape_interval = "10s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

### Key Prometheus metrics

These metrics are produced automatically by the JMX Exporter from standard JVM MBeans. No custom instrumentation is needed in the app.

| Metric | Source MBean | Description |
| --- | --- | --- |
| `jvm_memory_bytes_used{area="heap"}` | `java.lang:type=Memory` | Heap in use |
| `jvm_memory_bytes_max{area="heap"}` | `java.lang:type=Memory` | Heap maximum |
| `jvm_gc_collection_seconds_sum` | `java.lang:type=GarbageCollector` | Cumulative GC time |
| `jvm_gc_collection_seconds_count` | `java.lang:type=GarbageCollector` | Cumulative GC runs |
| `jvm_threads_current` | `java.lang:type=Threading` | Live thread count |
| `jvm_threads_peak` | `java.lang:type=Threading` | Peak thread count |
| `jvm_threads_daemon` | `java.lang:type=Threading` | Daemon thread count |
| `process_cpu_seconds_total` | `java.lang:type=OperatingSystem` | Process CPU time |

### Grafana query examples

Heap usage over time:
```promql
jvm_memory_bytes_used{job="stress-test", area="heap"}
```

GC rate (collections per second):
```promql
rate(jvm_gc_collection_seconds_count{job="stress-test"}[1m])
```

GC pause time ratio (fraction of time spent in GC):
```promql
rate(jvm_gc_collection_seconds_sum{job="stress-test"}[1m])
```

Thread count:
```promql
jvm_threads_current{job="stress-test"}
```

## Verification Checklist

All steps run from `D:\Alex\Work\Installs\LGTM-Geode` on Ironman.

1. Compile cleanly with no errors:
   ```cmd
   javac -d client\out client\src\main\java\lab\geode\client\StressTestApp.java
   ```

2. Run baseline smoke test and confirm `[STATS]` lines appear every 5 seconds:
   ```cmd
   java -cp client\out lab.geode.client.StressTestApp --mode baseline --duration 30 --interval 5
   ```

3. Run heap mode and confirm heap values fluctuate and GC count increments:
   ```cmd
   java -cp client\out lab.geode.client.StressTestApp --mode heap --intensity low --duration 30
   ```

4. Run threads mode and confirm live thread count rises by ~10 (low intensity):
   ```cmd
   java -cp client\out lab.geode.client.StressTestApp --mode threads --intensity low --duration 15
   ```

5. Run with JMX agent via the batch script and confirm the Prometheus endpoint is reachable:
   ```cmd
   set JMX_JAR=C:\opt\jmx-exporter\jmx_prometheus_javaagent.jar
   set MODE=baseline
   set DURATION=60
   client\run_stress.bat
   ```
   Then in a second CMD window:
   ```cmd
   curl http://localhost:9406/metrics
   ```
   Confirm the response contains lines beginning with `jvm_memory`.

6. Add the Alloy scrape stanza on BlackWidow and confirm the series appears in Grafana Explore:
   ```promql
   jvm_memory_bytes_used{job="stress-test", instance="ironman"}
   ```

## Design Notes

- The app is intentionally single-file with no build system, consistent with `ActivityClientApp.java` in the same package.
- All stressor worker threads are daemon threads; only the coordinator threads are non-daemon, which keeps the JVM alive for exactly the configured duration and allows clean shutdown via `running.set(false)`.
- `byte[]` chunks in `HeapStressor` are filled with `Arrays.fill` to prevent the JIT from eliminating the allocations as dead code.
- The Sieve of Eratosthenes loop in `CpuStressor` reads `running.get()` (an `AtomicBoolean` with volatile semantics) on every iteration, preventing JIT loop hoisting.
- `getProcessCpuLoad()` returns `-1.0` on the first measurement interval; the stats reporter prints `N/A` in that case rather than a negative percentage.
- The shutdown hook and the duration timer both call `running.set(false)`. This is safe — setting an `AtomicBoolean` to `false` twice is idempotent.
