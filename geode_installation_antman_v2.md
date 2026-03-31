# Apache Geode Installation & Troubleshooting (Rocky Linux 8 - Antman VM)

## 📌 Overview
This document provides a **complete, production-style guide** for installing, configuring, and troubleshooting Apache Geode on Rocky Linux 8 running on VMware.

It includes:
- Installation steps
- Cluster setup
- REST API enablement
- OQL querying
- Issues encountered and resolutions
- Architecture overview

---

# 🏗️ Architecture

```
            +----------------------+
            |    locator1          |
            | Host: Antman         |
            | IP: 192.168.0.150    |
            | Locator:10334        |
            | JMX:1099             |
            | HTTP:7070            |
            +----------+-----------+
                       |
                       |
            +----------v-----------+
            |     server1          |
            | Host: Antman         |
            | IP: 192.168.0.150    |
            | Server:40404         |
            | REST API:7071        |
            | JMX Exporter:9404    |
            +----------------------+
```

---

# ⚙️ 1. Environment

| Component | Value |
|----------|------|
| OS | Rocky Linux 8 |
| Platform | VMware Workstation |
| Interface | ens160 |
| Java | OpenJDK 11 |
| Geode | 1.15.2 |

---

# 📦 2. Install Java

```bash
sudo dnf install -y java-11-openjdk java-11-openjdk-devel
java --version
```

---

# 📥 3. Download Geode

```bash
wget https://downloads.apache.org/geode/1.15.2/apache-geode-1.15.2.tgz
tar -xvzf apache-geode-1.15.2.tgz
cd apache-geode-1.15.2
```

---

# 🌐 4. Environment Setup

```bash
export GEODE_HOME=$(pwd)
export PATH=$GEODE_HOME/bin:$PATH
gfsh version
```

---

# 🚀 5. Start Cluster

```bash
gfsh
start locator --name=locator1
start server --name=server1
```

---

# 📊 6. Create Region

```bash
create region --name=Activity --type=REPLICATE
```

---

# ⚠️ 7. Issue: Data Stored as String

```bash
put --region=Activity --key=1 --value="{'reference':'REF1','symbol':'AAPL','unit':100}"
```

### Problem:
- Stored as string
- OQL cannot access fields

---

# 🌐 8. Enable REST API

## ❌ Issue
```
Failed to bind to port 7070
```

## 🔍 Root Cause
- Locator already using port 7070

## ✅ Fix

```bash
stop server --name=server1

start server   --name=server1   --http-service-port=7071   --J=-Dgemfire.start-dev-rest-api=true
```

---

# 🔎 9. Verify REST API

```bash
curl http://Antman:7071/geode/v1/ping
# or
curl http://192.168.0.150:7071/geode/v1/ping
```

Expected:
```
HTTP/1.1 200 OK
```

Note:
- `http://localhost:7071/geode/v1/ping` also works when run on `Antman`
- `http://localhost:7071/v1/ping` returns `404 Not Found` because the REST app is mounted under `/geode`

---

# 📥 10. Insert Structured Data

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"reference":"REF2","symbol":"MSFT","unit":200}' \
  http://Antman:7071/geode/v1/Activity?key=2
```

---

# 🔍 11. Query Data

```bash
query --query="SELECT * FROM /Activity"
```

---

# 📈 12. Field Query

```bash
SELECT reference, symbol FROM /Activity
```

---

# 🔎 13. Filter Query

```bash
SELECT * FROM /Activity WHERE symbol='MSFT'
```

---

# ⚠️ 14. Empty String Handling

```bash
SELECT * FROM /Activity WHERE symbol=''
```

---

# 🧠 15. Key Issues & Resolutions

## Issue 1: No Network
- Cause: Missing connection profile
- Fix: nmcli connection setup

## Issue 2: DNS Failure
- Cause: Bad DHCP DNS
- Fix: Set 8.8.8.8 / 1.1.1.1

## Issue 3: REST API Not Starting
- Cause: Port conflict (7070)
- Fix: Use 7071

## Issue 5: REST API Ping Returns 404 From Antman
- Cause: Wrong path used (`/v1/ping` instead of `/geode/v1/ping`)
- Fix: Include the `/geode` context path

## Issue 4: OQL Not Working
- Cause: String storage
- Fix: Use REST JSON

---

# 🧪 16. Validation Checklist

| Check | Command |
|------|--------|
| Locator running | list members |
| Server running | list members |
| REST alive | curl /geode/v1/ping |
| Query works | SELECT * |
| Filter works | WHERE |

---

# 🏁 17. Final State

- Cluster operational
- REST API enabled
- Structured data stored
- OQL fully functional
- Hostname: `Antman`
- Primary IP: `192.168.0.150`
- Locator ports: `10334`, `1099`, `7070`
- Server ports: `40404`, `7071`, `9404`

---

# 💡 18. Best Practices

- Use REST or client APIs for structured data
- Avoid port conflicts
- Always check logs
- Separate locator/server ports
- Use static DNS in labs

---

# 🚀 Next Steps

- Connect Python client (Devious tool)
- Enable security/auth
- Add persistence regions
- Scale to multi-node cluster

---

# 📌 Conclusion

The deployment was successful after resolving:

- Network issues
- DNS misconfiguration
- Port conflicts
- Data modeling problems

System is now production-ready for further experimentation.

---

# Current Two-Host Cluster Configuration

This section replaces the earlier expansion plan. It documents the current validated layout that is used on both `Antman` and `Hulk`.

## Validated Topology

```text
                    +-------------------------------+
                    | locator1                      |
                    | Host: Antman                  |
                    | IP: 192.168.0.150             |
                    | Locator: 10334/tcp            |
                    | JMX Manager: 1099/tcp         |
                    | HTTP Service: 7070/tcp        |
                    +---------------+---------------+
                                    |
                locators=192.168.0.150[10334]
                                    |
             +----------------------+----------------------+
             |                                             |
 +-----------v-----------+                     +-----------v-----------+
 | server1               |                     | server2               |
 | Host: Antman          |                     | Host: Hulk            |
 | IP: 192.168.0.150     |                     | IP: 192.168.0.151     |
 | Cache Server: 40404   |                     | Cache Server: 40405   |
 | REST API: 7071        |                     | REST API: 7071        |
 | JMX Exporter: 9404    |                     | JMX Exporter: 9404    |
 +-----------------------+                     +-----------------------+
```

Current role assignment:

| Host | Active members | Notes |
|------|----------------|-------|
| `Antman` | `locator1`, `server1` | Cluster bootstrap node |
| `Hulk` | `server2` | Additional cache member |

Current non-goal:

- `locator2` on `Hulk` is not part of the validated setup.
- Do not assume `server2` is normalized unless you start it with the validated Hulk launcher shown below.

## Required Host Setup

Apply on both `Antman` and `Hulk`:

```bash
sudo dnf install -y java-11-openjdk java-11-openjdk-devel
java -version
```

Validated runtime:

- Java: OpenJDK 11
- Geode: `1.15.2`
- Working directory root: `/home/alex/geode_cluster`

Recommended host mapping:

```bash
echo "192.168.0.150 Antman" | sudo tee -a /etc/hosts
echo "192.168.0.151 Hulk"   | sudo tee -a /etc/hosts
```

## Runtime Directories

Geode member directories must be created under `~/geode_cluster` and members must be started from that location or with `--dir`.

Validated directories:

| Host | Member | Directory |
|------|--------|-----------|
| `Antman` | `locator1` | `/home/alex/geode_cluster/locator1` |
| `Antman` | `server1` | `/home/alex/geode_cluster/server1` |
| `Hulk` | `server2` | `/home/alex/geode_cluster/server2` |

Important startup rule:

- `gfsh` uses the current working directory for member state if `--dir` is not provided.
- If you start members manually from another directory, logs and runtime files will be created there instead of `~/geode_cluster`.
- For `server2`, always use `--dir=/home/alex/geode_cluster/server2`.

## Antman Startup Layout

The validated Antman script model is:

```bash
GEODE_HOME="${GEODE_HOME:-/home/alex/Work/apache-geode-1.15.2}"
WORKDIR="${WORKDIR:-$HOME/geode_cluster}"
GFSH="$GEODE_HOME/bin/gfsh"

mkdir -p "$WORKDIR"
cd "$WORKDIR"
```

That `cd "$WORKDIR"` step is required so `locator1` and `server1` are created under `~/geode_cluster`.

## Hulk `server2` Member Configuration

`server2` must have its own member directory and local `gemfire.properties`.

Create:

```bash
mkdir -p /home/alex/geode_cluster/server2

cat > /home/alex/geode_cluster/server2/gemfire.properties <<'EOF'
locators=192.168.0.150[10334]
membership-port-range=41000-41020
EOF
```

Why this is required:

- `locators=192.168.0.150[10334]` makes `server2` join the Antman locator directly.
- `membership-port-range=41000-41020` constrains Hulk membership sockets to a known range.
- The file must be loaded from the `server2` member directory, which only happens when `gfsh` is started with `--dir=/home/alex/geode_cluster/server2`.

## Hulk JMX Exporter And Normalized Launcher

Validated Hulk JMX exporter installation:

```bash
sudo mkdir -p /opt/jmx-exporter
sudo cp jmx_prometheus_javaagent.jar /opt/jmx-exporter/
sudo cp geode-jmx.yml /opt/jmx-exporter/
sudo chown root:root /opt/jmx-exporter/*
sudo chmod 644 /opt/jmx-exporter/*
```

Validated Hulk launcher:

```bash
cat > /home/alex/geode_cluster/start-hulk-server2.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-11.0.25.0.9-2.el8.x86_64}"
PATH="$JAVA_HOME/bin:$PATH"

GEODE_HOME="${GEODE_HOME:-/home/alex/apache-geode-1.15.2}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
GEODE_CLUSTER_DIR="${GEODE_CLUSTER_DIR:-/home/alex/geode_cluster}"
SERVER_DIR="${SERVER_DIR:-$GEODE_CLUSTER_DIR/server2}"
SERVER_NAME="${SERVER_NAME:-server2}"
LOCATORS="${LOCATORS:-Antman[10334]}"
HOSTNAME_FOR_CLIENTS="${HOSTNAME_FOR_CLIENTS:-Hulk}"
SERVER_PORT="${SERVER_PORT:-40405}"
HTTP_SERVICE_PORT="${HTTP_SERVICE_PORT:-7071}"
JMX_EXPORTER_PORT="${JMX_EXPORTER_PORT:-9404}"
JMX_EXPORTER_JAR="${JMX_EXPORTER_JAR:-/opt/jmx-exporter/jmx_prometheus_javaagent.jar}"
JMX_EXPORTER_CONFIG="${JMX_EXPORTER_CONFIG:-/opt/jmx-exporter/geode-jmx.yml}"
GEMFIRE_PROPERTIES="${GEMFIRE_PROPERTIES:-$SERVER_DIR/gemfire.properties}"
MEMBERSHIP_PORT_RANGE="${MEMBERSHIP_PORT_RANGE:-41000-41020}"

mkdir -p "$SERVER_DIR"

exec "$GFSH_BIN" -e "start server \
  --name=$SERVER_NAME \
  --dir=$SERVER_DIR \
  --server-port=$SERVER_PORT \
  --locators=$LOCATORS \
  --hostname-for-clients=$HOSTNAME_FOR_CLIENTS \
  --properties-file=$GEMFIRE_PROPERTIES \
  --J=-Dgemfire.use-cluster-configuration=true \
  --J=-Dgemfire.start-dev-rest-api=true \
  --J=-Dgemfire.http-service-port=$HTTP_SERVICE_PORT \
  --J=-Dgemfire.membership-port-range=$MEMBERSHIP_PORT_RANGE \
  --J=-javaagent:$JMX_EXPORTER_JAR=$JMX_EXPORTER_PORT:$JMX_EXPORTER_CONFIG"
EOF

chmod +x /home/alex/geode_cluster/start-hulk-server2.sh
```

Why this launcher is now required:

- Forces Java 11 on Hulk instead of the host default Java 17
- Uses the real Hulk Geode install path: `/home/alex/apache-geode-1.15.2`
- Enables `server2` REST on `7071`
- Enables the Hulk JMX exporter on `9404`
- Keeps the corrected `server2` member directory under `/home/alex/geode_cluster/server2`

## Fixed Service Ports

These are the fixed ports you should treat as part of the stable deployment.

| Host | Member | Purpose | Port | Protocol |
|------|--------|---------|------|----------|
| `Antman` | `locator1` | Locator | `10334` | `tcp` |
| `Antman` | `locator1` | JMX Manager | `1099` | `tcp` |
| `Antman` | `locator1` | HTTP Service | `7070` | `tcp` |
| `Antman` | `server1` | Cache Server | `40404` | `tcp` |
| `Antman` | `server1` | REST API | `7071` | `tcp` |
| `Antman` | `server1` | JMX Exporter | `9404` | `tcp` |
| `Hulk` | `server2` | Cache Server | `40405` | `tcp` |
| `Hulk` | `server2` | REST API | `7071` | `tcp` |
| `Hulk` | `server2` | JMX Exporter | `9404` | `tcp` |

## Dynamic Geode Membership Traffic

Do not treat `41000` and `41001` in Geode logs as the only network ports that need to be opened.

Observed behavior in the validated lab:

- Geode uses additional live sockets beyond the fixed cache-server and locator ports.
- Geode membership join traffic uses both `TCP` and `UDP`.
- A `TCP`-only firewall policy is not sufficient.
- Hulk `server2` join failures were traced to missing `UDP` allow rules even when `TCP` was already open.

Operational recommendation:

- Keep the fixed service ports documented above.
- For Antman-to-Hulk and Hulk-to-Antman peer membership traffic, allow all `TCP` and all `UDP` between the two host IPs.

## Firewall Rules

### Antman

Allow all `TCP` and `UDP` from Hulk:

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.151" port port="1-65535" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.151" port port="1-65535" protocol="udp" accept'
sudo firewall-cmd --reload
```

### Hulk

Allow all `TCP` and `UDP` from Antman:

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.150" port port="1-65535" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.150" port port="1-65535" protocol="udp" accept'
sudo firewall-cmd --reload
```

Why broad peer rules are used:

- Geode opens additional runtime sockets that are not well represented by only `10334`, `40404`, `40405`, and the logical membership IDs.
- Join traffic was observed sending datagrams to `192.168.0.150:41000`, so `UDP` between the peers is required.

Verification:

```bash
sudo firewall-cmd --list-rich-rules
```

## Validated Startup Sequence

### 1. Start `locator1` on `Antman`

Run from `/home/alex/geode_cluster`:

```bash
gfsh
start locator --name=locator1 --port=10334
```

### 2. Start `server1` on `Antman`

Use the same working directory root:

```bash
connect --locator=localhost[10334]

start server \
  --name=server1 \
  --server-port=40404 \
  --http-service-port=7071 \
  --J=-Dgemfire.start-dev-rest-api=true
```

If JMX exporter is in use, append:

```bash
--J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=9404:/opt/jmx-exporter/geode-jmx.yml
```

### 3. Start `server2` on `Hulk`

Run the normalized launcher:

```bash
/home/alex/geode_cluster/start-hulk-server2.sh
```

Important notes:

- The script pins Hulk to Java 11.
- The script keeps `server2` under `/home/alex/geode_cluster/server2`.
- `server2` inherits `locators` and `membership-port-range` from `/home/alex/geode_cluster/server2/gemfire.properties`.
- The script enables both REST on `7071` and the JMX exporter on `9404`.

## Validation Commands

From `gfsh` on either host:

```bash
list members
list regions
describe member --name=locator1
describe member --name=server1
describe member --name=server2
```

Expected state:

- `locator1`, `server1`, and `server2` all appear
- `server2` shows `Hulk` as its host
- `server2` listens on `40405`
- `server2` joins the distributed system instead of timing out with `MemberStartupException`

Host-level checks:

```bash
ss -ltnp | grep java
tail -n 80 /home/alex/geode_cluster/locator1/locator1.log
tail -n 80 /home/alex/geode_cluster/server1/server1.log
tail -n 80 /home/alex/geode_cluster/server2/server2.log
```

## Region Guidance

For initial two-node validation:

```bash
create region --name=Activity --type=REPLICATE
```

Why:

- Easier to validate than `PARTITION`
- Both `server1` and `server2` should see the same data during bring-up
- Fewer moving parts while stabilizing inter-host membership

## Monitoring Notes

Current scrape targets:

- `Antman:9404` for `server1`
- `Hulk:9404` for `server2`

Example Hulk scrape target:

```alloy
prometheus.scrape "geode_hulk_server2" {
  targets = [
    {
      __address__ = "192.168.0.151:9404",
      instance    = "hulk",
      job         = "geode",
      app         = "apache-geode",
      member      = "server2",
    },
  ]

  scrape_interval = "15s"
  forward_to      = [prometheus.remote_write.mimir.receiver]
}
```

## Known Failure Modes and Fixes

### 2026-03-27 startup failure after `server2` joined from Hulk

Symptoms:

- `server1` on `Antman` exited during startup with `ConflictingPersistentDataException`
- the failure referenced region `/Activity`
- the remote member in the exception was `Hulk(server2)`
- `server2` logs showed `/Activity` being created under `/home/alex/geode_cluster/server1/data`

Root cause:

- The live Geode cluster configuration stored `ActivityStore` with the absolute disk path `/home/alex/geode_cluster/server1/data`
- That path was valid for `server1` on `Antman` but incorrect for `server2` on `Hulk`
- When `server2` started, it created a fresh persistent store using the wrong path identity
- `server1` still had older `ActivityStore` data in its local `data` directory, so the two members no longer belonged to the same persistent history

Validated recovery sequence:

1. Export the live cluster configuration from `locator1`
2. Change `ActivityStore` from `/home/alex/geode_cluster/server1/data` to relative `data`
3. Import the corrected cluster configuration back into the locator
4. Stop `server2`
5. Move the conflicting `ActivityStore` data aside on both hosts
6. Start `server2` first and verify it creates `/home/alex/geode_cluster/server2/data`
7. Start `server1` and verify it initializes `/Activity` from `server2`
8. Verify `list members` shows `locator1`, `server1`, and `server2`
9. Verify `show missing-disk-stores` reports none

Preserved backup paths used during the fix:

- Cluster config backup: `/home/alex/geode_cluster/cluster-config-backup-20260327-091903`
- Antman moved data: `/home/alex/geode_cluster/server1/data.pre-fix-20260327-092019`
- Hulk moved data: `/home/alex/geode_cluster/server1/data.pre-fix-20260327-092020`

### `server2` loops on `waiting for a join-response`

Check:

- `JAVA_HOME` on Hulk is Java 11
- `server2` was started with `--dir=/home/alex/geode_cluster/server2`
- `/home/alex/geode_cluster/server2/gemfire.properties` exists
- both hosts allow peer `TCP` and `UDP` traffic

### `server2` starts from the wrong directory

Symptom:

- logs appear under a different path such as a scripts directory

Fix:

- start it again with the explicit `--dir`
- or `cd /home/alex/geode_cluster` before starting members

### REST API port conflict

Symptom:

- `Failed to bind to port 7070` or another HTTP service conflict

Fix:

- keep `7070` for `locator1`
- keep `7071` for `server1`
- keep `7071` for `server2` on `Hulk`

## Recommended Operating Model

1. Keep `locator1` and `server1` on `Antman` under `~/geode_cluster`.
2. Keep `server2` on `Hulk` under `~/geode_cluster/server2`.
3. Use Java 11 on both hosts.
4. Use explicit `--dir` for `server2`.
5. Keep fixed service ports stable.
6. Allow all peer-to-peer `TCP` and `UDP` between `192.168.0.150` and `192.168.0.151`.

## Future Upgrade Path

After the current layout is stable, optional next steps are:

- add `locator2` on `Hulk` for locator redundancy
- enable persistence for region durability
- add cluster security and authentication
- add startup automation through `systemd` for `locator1`, `server1`, and `server2`
