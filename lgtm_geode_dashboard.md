# LGTM Dashboard Implementation Runbook for Apache Geode

## Purpose

This document turns the Geode dashboard idea into an implementation sequence you can execute interactively.

The critical constraint is that the current environment has confirmed metric ingestion through Alloy and Mimir, but this file cannot assume that Geode-specific metric names such as `geode_gets_total` or `geode_region_entries` already exist. The first task is to discover the real exported metric names and labels from `Antman`.

Reference architecture: `Blackwidow` (`192.168.0.153`) hosts Grafana, Alloy, Mimir, Loki, and Tempo. `Antman` (`192.168.0.150`) exposes the JMX Exporter on `:9404`.

## Review Findings

### 1. Variable queries assume labels that may not exist

The draft uses variables such as `cluster`, `member`, and `region` directly from `up{...}` queries. That only works if Alloy or the exporter already attaches those labels to the scraped series. Today, the architecture document only proves labels such as `instance`, `job`, `app`, and `member` in the Alloy target example.

Impact:

- Variable drop-downs may render empty
- Panel queries that depend on `$cluster` or `$region` may return no data

### 2. Several Geode metric names are placeholders, not validated metrics

The draft references series such as:

- `geode_cache_operations_total`
- `geode_gets_total`
- `geode_puts_total`
- `geode_get_latency_seconds_bucket`
- `geode_errors_total`
- `geode_region_entries`
- `geode_region_hits_total`
- `geode_region_misses_total`
- `geode_offheap_used_bytes`
- `geode_offheap_max_bytes`

These are reasonable target metrics, but they are not yet verified against the exporter output.

Impact:

- Most dashboard panels may fail on first import
- Alert rules tied to these names would be invalid

### 3. The heap and alert queries are too broad

The heap percentage and `up == 0` alert expressions are written without enough label scoping.

Impact:

- Multi-target environments will mix unrelated series
- Alert conditions may trigger for the wrong job or instance

### 4. Loki log labels may not match the actual ingestion labels

The draft uses `{app="apache_geode"}` for log queries. The Alloy scrape example in the architecture doc uses `app = "apache-geode"` for metrics, not logs. The log pipeline labels still need verification in Grafana Explore.

Impact:

- Log panels may return nothing

## Dashboard Strategy

Build the dashboard in two phases:

1. Foundation dashboard using metrics that are already very likely present from JMX Exporter and Node Exporter
2. Geode-specific expansion after the real metric names are discovered and mapped

## Phase 1: Prerequisites

Before opening Grafana, confirm these are true:

- `curl http://192.168.0.150:9404/metrics` returns data from `Blackwidow`
- Grafana can query the Mimir data source
- `up{job="geode"}` returns `1`
- Node Exporter metrics are available if infrastructure panels are required

If any of those fail, stop here and fix ingestion first.

## Phase 2: Interactive Implementation Session

Use this as a live operator checklist. Execute one step at a time and do not move to the next section until the current one works.

### Step 1. Verify the base metrics in Grafana Explore

Open Grafana on `Blackwidow`:

```text
http://192.168.0.153:3000
```

In Explore, select the Mimir data source and run:

```promql
up
```

Expected result:

- You see at least one `up` series for the Geode scrape target

Now run:

```promql
up{job="geode"}
```

Expected result:

- Value is `1`
- You can see the real label set for the target

Write down the labels that actually exist. You need to confirm whether these labels are present:

- `job`
- `instance`
- `member`
- `app`
- `cluster`
- `region`
- `env`

Decision:

- If `cluster`, `region`, or `env` are missing, do not use them as dashboard variables yet

### Step 2. Discover the actual JVM and Geode metric names

Stay in Explore and search for JVM metrics first:

```promql
{__name__=~"jvm_.*"}
```

Then search for Node Exporter metrics:

```promql
{__name__=~"node_.*"}
```

Then search for possible Geode metrics:

```promql
{__name__=~".*geode.*"}
```

If that returns too little, inspect the raw exporter output from `Antman` and search for likely prefixes:

```bash
curl http://192.168.0.150:9404/metrics
```

Capture the real names for:

- JVM heap metrics
- GC metrics
- file descriptor or process metrics
- Geode cache operation counters
- region entry metrics
- hit and miss counters
- off-heap metrics
- latency histogram or summary metrics

Decision:

- If you do not find Geode-specific metrics, build only the JVM plus infrastructure dashboard first

### Step 3. Create the dashboard shell

In Grafana:

1. Go to Dashboards
2. Click New
3. Click New dashboard
4. Add a new visualization
5. Select the Mimir data source
6. Save the dashboard as `Geode / Production Overview`

### Step 4. Create only proven variables first

Create these variables only if the labels exist in Step 1:

`job`

```promql
label_values(up{job=~".*geode.*"}, job)
```

`instance`

```promql
label_values(up{job=~"$job"}, instance)
```

`member`

```promql
label_values(up{job=~"$job"}, member)
```

Conditional variables:

- Add `cluster` only if `cluster` exists on `up`
- Add `region` only after you verify a region label exists on real region metrics
- Add `env` only if Alloy injects it

Do not create fake variables. Empty variables make the dashboard harder to debug.

### Step 5. Build the minimum working panel set

Create these panels first because they rely on metrics that are very likely available now.

#### Panel: Members Up

Type: Stat

```promql
sum(up{job=~"$job"})
```

#### Panel: Member Status

Type: State timeline or Stat

```promql
up{job=~"$job", instance=~"$instance"}
```

#### Panel: Heap Usage %

Type: Time series

Use this query only after confirming the label set on the JVM metrics:

```promql
100 *
sum by (instance) (jvm_memory_used_bytes{area="heap", job=~"$job"})
/
sum by (instance) (jvm_memory_max_bytes{area="heap", job=~"$job"})
```

#### Panel: GC Pause Rate

Type: Time series

```promql
sum by (instance) (rate(jvm_gc_pause_seconds_sum{job=~"$job"}[$__rate_interval]))
```

#### Panel: Process Open FDs

Type: Time series

```promql
process_open_fds{job=~"$job"}
```

#### Panel: CPU %

Type: Time series

Use this only if Node Exporter is being scraped:

```promql
100 - (
  avg by (instance) (
    rate(node_cpu_seconds_total{mode="idle"}[$__rate_interval])
  ) * 100
)
```

#### Panel: Memory %

Type: Time series

```promql
100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

### Step 6. Validate every panel before adding the next one

For each panel:

1. Paste the query into Explore first
2. Confirm it returns data
3. Confirm the label set matches the intended variable filtering
4. Only then save it into the dashboard

If a panel fails:

- Check whether the metric exists
- Check whether the labels in the query exist
- Remove unsupported label filters before assuming ingestion is broken

### Step 7. Add Geode-specific panels only after metric discovery

After Step 2, replace the placeholder metrics below with the real exported names.

Candidate panel categories:

- cache gets and puts per second
- operation error rate
- off-heap usage
- region entry count
- region hit ratio
- request latency percentiles

Template examples:

Gets/sec:

```promql
sum(rate(<verified_geode_get_counter>{job=~"$job"}[$__rate_interval]))
```

Puts/sec:

```promql
sum(rate(<verified_geode_put_counter>{job=~"$job"}[$__rate_interval]))
```

Region entries:

```promql
sum by (region) (<verified_region_entries_metric>{job=~"$job"})
```

Hit ratio:

```promql
100 *
sum(rate(<verified_region_hit_counter>{job=~"$job"}[$__rate_interval]))
/
(
  sum(rate(<verified_region_hit_counter>{job=~"$job"}[$__rate_interval])) +
  sum(rate(<verified_region_miss_counter>{job=~"$job"}[$__rate_interval]))
)
```

P95 latency:

```promql
histogram_quantile(
  0.95,
  sum by (le) (
    rate(<verified_latency_bucket_metric>{job=~"$job"}[$__rate_interval])
  )
)
```

### Step 8. Validate Loki labels before adding log panels

Open Explore and switch to the Loki data source.

Start broad:

```logql
{}
```

Then inspect the labels attached to Geode-related logs.

Do not assume the label is `app="apache_geode"`. Confirm whether it is one of these instead:

- `app="apache-geode"`
- `job="geode"`
- `instance="antman"`
- another label set created by Alloy

After you verify the labels, add panels such as:

```logql
{job="geode"} |= "ERROR"
```

```logql
{job="geode"} |~ "LowMemoryException|membership|rebalance"
```

### Step 9. Add thresholds

Suggested starting thresholds:

- Heap warning `70`, critical `85`
- Off-heap warning `70`, critical `80`
- CPU warning `70`, critical `85`
- Disk warning `75`, critical `90`

Only apply thresholds to panels that already return correct data.

### Step 10. Add alerts last

Do not create alerts until the panel queries are proven.

Use scoped expressions, for example:

Member down:

```promql
up{job="geode"} == 0
```

Heap critical:

```promql
100 *
sum by (instance) (jvm_memory_used_bytes{area="heap", job="geode"})
/
sum by (instance) (jvm_memory_max_bytes{area="heap", job="geode"})
> 85
```

For Geode-specific alerts, use the verified metric names from Step 2.

## Suggested Build Order

Build the dashboard in this exact order:

1. `Members Up`
2. `Member Status`
3. `Heap Usage %`
4. `GC Pause Rate`
5. `Process Open FDs`
6. `CPU %`
7. `Memory %`
8. Log panels
9. Geode-specific traffic panels
10. Geode-specific region panels
11. Alerts

## What You Should Capture During the Session

As you execute the steps, keep a scratch list of:

- actual metric names exported for Geode
- actual labels on `up`
- actual labels on log streams
- any missing Node Exporter metrics
- any labels you want Alloy to inject later, such as `cluster` or `env`

## Next Action

Start with Grafana Explore and complete only Steps 1 and 2 first. Once you have the real metric names and labels, the rest of the dashboard build becomes straightforward and low risk.
