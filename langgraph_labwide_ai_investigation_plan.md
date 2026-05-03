# LangGraph Lab-Wide AI Investigation Automation Plan

**Primary objective:** Fully utilize LangGraph as an AI automation tool to investigate issues across the lab-wide observability, Geode, Kafka, MQ, Splunk, WSL, and network stack.

**Target environment:** Alex's lab with Blackwidow LGTM stack, Antman Geode/MQ, Hulk Kafka/forwarder, Vision and WarMachine WSL2 nodes, Hawkeye Splunk, and IRONMAN/Thor Windows hosts.

---

## 1. Executive Recommendation

LangGraph should be used as the **AI investigation orchestration layer**, not as the observability backend itself.

Recommended layered model:

```text
Layer 1: Telemetry Collection
  Grafana Alloy, OpenTelemetry, exporters, logs, system probes

Layer 2: Observability Storage and Query
  Loki for logs
  Mimir for metrics
  Tempo for traces
  Splunk as optional comparison/search source

Layer 3: Dashboards, Alerts, and Runbooks
  Grafana dashboards
  Alert rules
  Manual diagnostic runbooks

Layer 4: LangGraph AI Automation
  Evidence collection
  Hypothesis generation
  Multi-step investigation
  Human-approved diagnostics/remediation
  RCA generation
```

LangGraph becomes the lab-wide investigation brain. LGTM remains the source of truth.

---

## 2. Why LangGraph Is Appropriate

LangGraph is appropriate because lab-wide troubleshooting is not a single prompt problem. It is a workflow problem.

Typical investigation requires:

- Classifying the incident domain.
- Querying logs, metrics, traces, and host status.
- Comparing evidence across systems.
- Looping when evidence is insufficient.
- Asking for human approval before risky commands.
- Persisting state for long investigations.
- Generating structured RCA output.

LangGraph supports these requirements through:

- Graph-based workflows.
- Shared state between nodes.
- Conditional routing.
- Tool-calling nodes.
- Durable execution through checkpointing.
- Human-in-the-loop interruptions.
- Multi-agent or multi-role workflow design.

---

## 3. What LangGraph Should and Should Not Do

### LangGraph should do

- Coordinate investigation steps.
- Query Loki, Mimir, Tempo, Splunk, and local diagnostic scripts.
- Track evidence collected so far.
- Decide what to query next.
- Rank possible root causes.
- Ask for approval before dangerous operations.
- Produce final RCA summaries.
- Convert manual runbooks into repeatable automated graphs.

### LangGraph should not do

- Replace Grafana dashboards.
- Replace Loki/Mimir/Tempo/Splunk.
- Be the only alerting mechanism.
- Run unrestricted shell commands.
- Automatically restart services without approval.
- Guess from incomplete telemetry.
- Store secrets directly in graph state.

---

## 4. Lab-Wide Scope

The investigation assistant should understand the following systems.

| Host | Role | Important Signals |
|---|---|---|
| Blackwidow | LGTM stack | Grafana, Loki, Mimir, Tempo, Alloy health |
| Antman | Geode Cluster-A, IBM MQ | Geode locator/server, REST API, JMX exporter, MQ listener |
| Hulk | Kafka, Splunk UF, Alloy | Kafka broker, topic health, OS logs, forwarder status |
| Vision | WSL2 Geode Cluster-B | Locator/server, gateway receiver, WSL networking |
| WarMachine | WSL2 planned Geode/network node | SSH, Geode/network checks |
| Hawkeye | Splunk Enterprise | Indexing, searching, forwarder intake |
| Thor | Windows/WSL host | WSL networking, port proxies, firewall, mirrored/NAT mode |
| IRONMAN | Main workstation | VMware, orchestration, local AI development |

---

## 5. Target Use Cases

### Use Case 1: Geode Cluster Investigation

Example request:

```text
Investigate why Geode Cluster-A is not receiving replicated activity events.
```

Workflow:

1. Check Antman locator and server process state.
2. Query Geode logs from Loki.
3. Query Geode JMX metrics from Mimir.
4. Check REST endpoint availability.
5. Check gateway sender/receiver status.
6. Check Vision/WarMachine reachability.
7. Compare timestamps across logs and metrics.
8. Produce hypothesis and recommended next action.

---

### Use Case 2: LGTM Stack Health Investigation

Example request:

```text
Investigate why logs stopped appearing in Grafana.
```

Workflow:

1. Check Alloy health.
2. Query Loki ingestion metrics.
3. Verify target host log files are readable.
4. Check network connectivity to Loki.
5. Query recent log volume by host.
6. Identify first timestamp where ingestion dropped.
7. Produce likely cause.

---

### Use Case 3: Network Path Investigation

Example request:

```text
Investigate why Thor cannot connect to Vision port 5000.
```

Workflow:

1. Identify source and destination hosts.
2. Check known IP inventory.
3. Run safe reachability checks.
4. Check listener state on destination.
5. Check Windows firewall or WSL networking mode.
6. Check whether NAT/mirrored WSL mode changed.
7. Produce diagnosis.

---

### Use Case 4: Kafka Pipeline Investigation

Example request:

```text
Investigate why activity-events messages are not being consumed.
```

Workflow:

1. Check Kafka broker health on Hulk.
2. Query Kafka logs.
3. Check topic existence and partition status.
4. Check consumer group lag.
5. Check producers and consumers.
6. Correlate with Geode or REST errors.
7. Produce RCA summary.

---

### Use Case 5: Splunk vs LGTM Cross-Validation

Example request:

```text
Compare whether Hulk logs are visible in Splunk and Loki.
```

Workflow:

1. Query Loki by host and time window.
2. Query Splunk by host and time window.
3. Compare message counts.
4. Identify gaps.
5. Check forwarder and Alloy status.
6. Produce recommendation.

---

## 6. LangGraph Architecture

### 6.1 Main Graph

```text
START
  ↓
Normalize Incident Request
  ↓
Classify Domain
  ↓
Load Lab Inventory
  ↓
Select Investigation Playbook
  ↓
Collect Evidence
  ↓
Analyze Evidence
  ↓
Need More Evidence?
  ├── yes → Collect More Evidence
  └── no  → Risk Assessment
              ↓
          Need Human Approval?
              ├── yes → Human Approval Gate
              └── no  → Final RCA
```

---

### 6.2 Recommended Nodes

| Node | Purpose |
|---|---|
| `normalize_request` | Extract issue, time window, hosts, symptoms |
| `classify_domain` | Route to Geode, Kafka, LGTM, network, Splunk, OS |
| `load_inventory` | Load hostnames, IPs, ports, services, known topology |
| `select_playbook` | Choose investigation workflow |
| `query_loki` | Query logs from Loki |
| `query_mimir` | Query metrics from Mimir/PromQL |
| `query_tempo` | Query traces when available |
| `query_splunk` | Optional comparison query |
| `run_safe_probe` | Execute read-only diagnostics |
| `correlate_timeline` | Align evidence by time |
| `hypothesis_engine` | Generate ranked root-cause hypotheses |
| `gap_detector` | Decide what evidence is missing |
| `human_approval_gate` | Pause before risky action |
| `rca_writer` | Generate final report |

---

## 7. Investigation State Design

Use a typed state object.

Example conceptual state:

```python
class InvestigationState(TypedDict):
    incident_id: str
    user_request: str
    time_window: dict
    domain: str
    affected_hosts: list[str]
    affected_services: list[str]
    inventory: dict
    evidence: list[dict]
    hypotheses: list[dict]
    confidence: float
    missing_evidence: list[str]
    approved_actions: list[str]
    rejected_actions: list[str]
    final_rca: str
```

Important rule:

```text
State stores investigation facts, not secrets.
```

---

## 8. Tool Layer Design

LangGraph should call tools through controlled wrappers.

### 8.1 Loki Tool

Purpose:

- Query logs by host, service, severity, and time range.

Example capabilities:

```text
query_loki(host="Antman", service="geode", pattern="ERROR", last="30m")
query_loki_count_by_host(last="1h")
query_loki_first_error_after(timestamp)
```

---

### 8.2 Mimir Tool

Purpose:

- Query PromQL-compatible metrics.

Example capabilities:

```text
query_mimir("up{job='geode'}")
query_mimir("rate({metric}[5m])")
query_mimir("node_filesystem_avail_bytes")
```

---

### 8.3 Tempo Tool

Purpose:

- Query traces when application tracing exists.

Initial state:

```text
Optional. Add after logs and metrics are stable.
```

---

### 8.4 Host Probe Tool

Purpose:

- Run read-only checks.

Allowed examples:

```bash
hostname
ip addr
ss -ltnp
systemctl status <known-service>
curl -s http://host:port/health
nc -vz host port
```

Blocked examples unless manually approved:

```bash
systemctl restart
kill
rm
firewall-cmd --remove
iptables changes
configuration edits
```

---

### 8.5 Inventory Tool

Store inventory in a simple YAML or JSON file.

Example:

```yaml
hosts:
  antman:
    ip: 192.168.0.150
    os: Rocky 8.10
    services:
      geode_locator:
        port: 10334
      geode_http:
        port: 7071
      mq_listener:
        port: 1414
  blackwidow:
    ip: 192.168.0.153
    services:
      grafana:
        port: 3000
      loki:
        port: 3100
      mimir:
        port: 9009
      tempo:
        port: 3200
```

---

## 9. Human Approval Policy

### Read-only actions

Allowed automatically:

- Query Loki.
- Query Mimir.
- Query Grafana APIs.
- Read inventory.
- Run `curl` health checks.
- Run `nc -vz` port checks.
- Run `ss -ltnp`.
- Run `systemctl status`.

### Approval-required actions

Require human approval:

- Restart services.
- Change firewall rules.
- Modify config files.
- Start or stop Geode/Kafka/MQ/Splunk services.
- Delete or rotate logs.
- Change WSL networking settings.
- Apply permanent Windows netsh changes.

### Forbidden by default

- Running arbitrary shell commands generated by the LLM.
- Deleting files.
- Uploading logs to external services.
- Storing passwords in state.
- Executing remediation without approval.

---

## 10. Investigation Playbooks

### 10.1 Geode Playbook

Checks:

1. Locator process status.
2. Server process status.
3. REST endpoint status.
4. JMX exporter status.
5. Region existence.
6. Gateway sender/receiver status.
7. Log errors around incident time.
8. Network connectivity between clusters.

Expected evidence:

```text
service_status
recent_errors
port_listeners
REST response
JMX metrics
network reachability
```

---

### 10.2 LGTM Playbook

Checks:

1. Grafana reachable.
2. Loki reachable.
3. Mimir reachable.
4. Tempo reachable.
5. Alloy targets healthy.
6. Log volume by host.
7. Metric scrape success.
8. Disk/memory pressure.

---

### 10.3 Kafka Playbook

Checks:

1. Broker listener status.
2. Topic list.
3. Partition status.
4. Consumer group lag.
5. Producer/consumer logs.
6. Network access from clients.

---

### 10.4 Splunk Playbook

Checks:

1. Splunk Enterprise service status on Hawkeye.
2. Receiver port 9997.
3. Hulk Universal Forwarder status.
4. Active forward-server status.
5. Search index visibility.
6. Compare with Loki ingestion.

---

### 10.5 WSL/Network Playbook

Checks:

1. WSL mode: NAT or mirrored.
2. Distro IP address.
3. Windows host IP.
4. Listener binding.
5. Firewall status.
6. Portproxy status.
7. Cross-host reachability.

---

## 11. Required Project Structure

Recommended folder:

```text
langgraph-lab-investigator/
  README.md
  pyproject.toml
  .env.example
  config/
    lab_inventory.yaml
    safe_commands.yaml
    playbooks.yaml
  app/
    main.py
    graph.py
    state.py
    nodes/
      classify.py
      inventory.py
      evidence.py
      analysis.py
      approval.py
      rca.py
    tools/
      loki.py
      mimir.py
      tempo.py
      splunk.py
      ssh_probe.py
      geode.py
      kafka.py
      network.py
    prompts/
      classifier.md
      hypothesis.md
      rca.md
  outputs/
    rca_reports/
    evidence_bundles/
  tests/
    test_inventory.py
    test_loki_tool.py
    test_graph_routing.py
```

---

## 12. Python Environment

Recommended on IRONMAN or a Linux VM:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install langgraph langchain langchain-openai httpx pydantic pyyaml rich typer
```

Optional packages:

```bash
pip install paramiko prometheus-api-client python-dotenv
```

For local LLM usage, later evaluate:

```text
Ollama
LM Studio
vLLM
llama.cpp server
```

---

## 13. Minimum Viable Product

### MVP Goal

Build a read-only investigation agent that can answer:

```text
What is unhealthy in my lab right now?
```

### MVP Capabilities

- Load inventory.
- Query Loki for recent errors.
- Query Mimir for `up` metrics.
- Check known service ports.
- Rank unhealthy systems.
- Generate a markdown RCA-style summary.

### MVP Exclusions

- No automatic remediation.
- No arbitrary shell commands.
- No Tempo integration yet.
- No Splunk integration unless needed.
- No long-term memory beyond checkpoints.

---

## 14. Build Phases

### Phase 0 — Inventory and Safety Baseline

Deliverables:

- `lab_inventory.yaml`
- `safe_commands.yaml`
- list of approved read-only diagnostics
- list of approval-required actions

Success criteria:

```text
The agent knows hosts, services, ports, and allowed checks.
```

---

### Phase 1 — Read-Only Evidence Collection

Deliverables:

- Loki query tool
- Mimir query tool
- network port probe tool
- service health probe tool

Success criteria:

```text
The agent can collect evidence without changing systems.
```

---

### Phase 2 — LangGraph Workflow

Deliverables:

- Investigation state schema
- Request classifier
- Domain router
- Evidence collector
- Hypothesis generator
- Final RCA writer

Success criteria:

```text
The graph completes one investigation from request to RCA.
```

---

### Phase 3 — Playbook Expansion

Deliverables:

- Geode playbook
- LGTM playbook
- Kafka playbook
- Network playbook
- Splunk comparison playbook

Success criteria:

```text
The graph chooses the correct playbook for common lab problems.
```

---

### Phase 4 — Human-in-the-Loop Approval

Deliverables:

- approval gate node
- remediation proposal format
- audit log of approved/rejected actions

Success criteria:

```text
The agent pauses before any risky action.
```

---

### Phase 5 — RCA and Knowledge Base

Deliverables:

- RCA markdown output
- evidence bundle
- known-issue database
- runbook suggestions

Success criteria:

```text
Every investigation produces reusable documentation.
```

---

### Phase 6 — Advanced Automation

Deliverables:

- recurring health scan
- anomaly detection integration
- incident similarity search
- optional local LLM backend
- optional Grafana dashboard links

Success criteria:

```text
The system helps detect and investigate recurring lab-wide issues.
```

---

## 15. Example Graph Logic

```python
from langgraph.graph import StateGraph, END

builder = StateGraph(InvestigationState)

builder.add_node("normalize_request", normalize_request)
builder.add_node("classify_domain", classify_domain)
builder.add_node("load_inventory", load_inventory)
builder.add_node("collect_evidence", collect_evidence)
builder.add_node("analyze_evidence", analyze_evidence)
builder.add_node("human_approval_gate", human_approval_gate)
builder.add_node("write_rca", write_rca)

builder.set_entry_point("normalize_request")
builder.add_edge("normalize_request", "classify_domain")
builder.add_edge("classify_domain", "load_inventory")
builder.add_edge("load_inventory", "collect_evidence")
builder.add_edge("collect_evidence", "analyze_evidence")

builder.add_conditional_edges(
    "analyze_evidence",
    route_after_analysis,
    {
        "need_more_evidence": "collect_evidence",
        "need_approval": "human_approval_gate",
        "complete": "write_rca",
    },
)

builder.add_edge("human_approval_gate", "write_rca")
builder.add_edge("write_rca", END)

app = builder.compile(checkpointer=checkpointer)
```

---

## 16. Example User Interactions

### General lab health

```text
Investigate current lab-wide health for the last 30 minutes.
```

Expected output:

```text
Summary:
- Blackwidow Loki is healthy.
- Antman Geode server has recent ERROR messages.
- Vision gateway receiver port is reachable from Thor but not from Antman.

Likely issue:
- Network path or listener binding issue between Antman and Vision.

Recommended next step:
- Verify gateway receiver bind address on Vision.
```

---

### Geode issue

```text
Investigate why Activity region data is missing in Geode Cluster-B.
```

Expected output:

```text
Evidence:
- Cluster-A server is running.
- Cluster-B receiver is listening on 5000.
- Sender logs show connection refused at 10:42.
- Vision IP changed after WSL restart.

Likely cause:
- WSL IP drift or stale gateway sender configuration.
```

---

## 17. Data and Security Model

### Secrets

Do not store secrets in:

- graph state
- logs
- RCA files
- prompt text
- inventory files

Use environment variables or a local secrets manager.

Example `.env`:

```bash
LOKI_URL=http://192.168.0.153:3100
MIMIR_URL=http://192.168.0.153:9009
GRAFANA_URL=http://192.168.0.153:3000
SPLUNK_URL=https://192.168.0.154:8089
```

---

## 18. Output Format

Each investigation should generate:

```text
Incident ID
User request
Time window
Affected systems
Evidence table
Timeline
Ranked hypotheses
Confidence level
Recommended next actions
Approval-required actions
Final RCA
Follow-up monitoring suggestions
```

---

## 19. Success Metrics

Track these metrics:

| Metric | Target |
|---|---|
| Time to first useful hypothesis | < 2 minutes |
| False remediation suggestions | 0 without approval |
| Evidence coverage | Logs + metrics + probe for each investigation |
| RCA generated | 100% of completed investigations |
| Repeat issue recognition | improves over time |

---

## 20. Implementation Priority

Recommended order:

1. Inventory YAML.
2. Loki query tool.
3. Mimir query tool.
4. Safe network probe tool.
5. LangGraph state and graph skeleton.
6. LGTM health playbook.
7. Geode playbook.
8. RCA writer.
9. Human approval gate.
10. Kafka, Splunk, and WSL/network playbooks.

---

## 21. Practical First Build

Start with this first command goal:

```bash
python app/main.py investigate "Check lab-wide health for the last 30 minutes"
```

Expected first MVP output:

```text
Lab Health Investigation

Healthy:
- Grafana reachable
- Loki reachable
- Mimir reachable

Warnings:
- No recent logs from Vision in Loki
- Geode JMX exporter unavailable on Antman

Next checks:
- Verify Alloy target for Vision
- Check Antman JMX exporter process
```

---

## 22. Final Target State

The final system should behave like this:

```text
User: Investigate why Geode replication failed after I restarted Vision.

LangGraph agent:
1. Reads inventory.
2. Detects Geode/network domain.
3. Queries Loki logs on Antman and Vision.
4. Queries Mimir metrics for Geode and node health.
5. Checks known ports.
6. Identifies WSL IP drift as likely cause.
7. Shows evidence.
8. Recommends config verification.
9. Asks before changing anything.
10. Writes RCA report.
```

---

## 23. References

- LangGraph overview: https://docs.langchain.com/oss/python/langgraph/overview
- LangGraph durable execution: https://docs.langchain.com/oss/python/langgraph/durable-execution
- LangGraph persistence/checkpointing: https://docs.langchain.com/oss/python/langgraph/persistence
- LangGraph human-in-the-loop: https://docs.langchain.com/oss/python/langchain/human-in-the-loop
- Grafana Mimir query documentation: https://grafana.com/docs/mimir/latest/query/
- Grafana Mimir HTTP API: https://grafana.com/docs/mimir/latest/references/http-api/
- Prometheus HTTP API: https://prometheus.io/docs/prometheus/latest/querying/api/
- Grafana HTTP API: https://grafana.com/docs/grafana/latest/developer-resources/api-reference/http-api/

---

## 24. Bottom Line

LangGraph is the right tool for AI-driven lab-wide investigation **after** the observability foundation is reliable.

The correct build order is:

```text
Inventory → Telemetry Queries → Safe Probes → LangGraph Workflow → Playbooks → RCA → Approval Gates → Advanced Automation
```

Do not start with autonomous remediation. Start with read-only investigation and evidence-backed RCA.
