# Apache Geode Lab Guide

## Purpose

This document is the single source of truth for the Geode lab. It covers host topology, component versions, installation assumptions, startup scripts, WAN configuration, client usage, validation, troubleshooting, and optional expansion work.

## Current Versions

| Component | Version |
| --- | --- |
| Apache Geode | 1.15.2 |
| Java runtime used by Geode hosts | Java 11 |

## Host Inventory

| Host | IP | OS | Role | Status |
| --- | --- | --- | --- | --- |
| Ironman | 192.168.0.53 | Windows 11 | Primary VMware host and Windows-side Geode client workstation | Lab host |
| Antman | 192.168.0.150 | Rocky Linux 8 | Cluster A locator1 and server1 | Active |
| Hulk | 192.168.0.151 | RHEL 8 | Cluster A server2 and optional locator2 | Active for server2, optional for locator2 |
| BlackWidow | 192.168.0.153 | Ubuntu 24.04 | Monitoring hub for LGTM, scrapes Geode metrics | Active |
| Thor | 192.168.0.14 | Windows 11 | WSL2 host and `portproxy` entry point into Cluster B | Active |
| Vision | 172.22.79.100 | Ubuntu 24.04 | Cluster B locatorB, serverB1, GatewayReceiver | Active |
| Warmachine | 172.22.79.100 | RHEL 8 | Cluster B serverB2 | Active |

Notes:

- Vision is behind WSL2 NAT, so Cluster A reaches the GatewayReceiver through Thor.
- Warmachine and Vision share the same WSL2 virtual network adapter on Thor and both bind to `172.22.79.100`. They must use distinct ports for all Geode members.
- Warmachine runs no locator and no GatewayReceiver. It joins Cluster B by connecting to Vision's locatorB at `172.22.79.100[20334]`.

## Topology

### Cluster A

```text
                    +-------------------------------+
                    | locator1                      |
                    | Host: Antman                  |
                    | IP: 192.168.0.150            |
                    | Locator: 10334/tcp           |
                    | JMX Manager: 1099/tcp        |
                    | HTTP Service: 7070/tcp       |
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

### WAN Paths (Bidirectional)

```text
A → B:  Antman(senderA) -> Thor 192.168.0.14:5000 -> Vision 172.22.79.100:5000/5001 -> GatewayReceiver
B → A:  Vision/Warmachine(senderB) -> Antman 192.168.0.150:6000 -> GatewayReceiver
```

Note: B→A traffic goes directly from Vision to Antman (both on `192.168.0.x` subnet). No portproxy is needed for this direction.

### Cluster B

```text
                    +-------------------------------+
                    | locatorB                      |
                    | Host: Vision                  |
                    | IP: 172.22.79.100            |
                    | Locator: 20334/tcp           |
                    +---------------+---------------+
                                    |
               locators=172.22.79.100[20334]
                                    |
             +----------------------+----------------------+
             |                                             |
 +-----------v-----------+                     +-----------v-----------+
 | serverB1               |                    | serverB2              |
 | Host: Vision           |                    | Host: Warmachine      |
 | IP: 172.22.79.100      |                    | IP: 172.22.79.100     |
 | Cache Server: 40405/tcp|                    | Cache Server: 40406/tcp|
 | GatewayReceiver: 5001  |                    | GatewayReceiver: 5000 |
 | (A→B receiver)         |                    | (A→B receiver)        |
 +-----------------------+                     +-----------------------+
```

## Port Matrix

| Host | Port | Service | Purpose |
| --- | ---: | --- | --- |
| Antman | 10334 | locator1 | Cluster A locator |
| Antman | 1099 | locator1 JMX manager | Locator management |
| Antman | 7070 | locator1 HTTP service | Locator HTTP service |
| Antman | 9405 | locator1 JMX Exporter | Locator metrics endpoint |
| Antman | 40404 | server1 | Cache server |
| Antman | 7071 | server1 REST | Dev REST API |
| Antman | 9404 | server1 JMX Exporter | Metrics endpoint |
| Hulk | 10334 | locator2 | Optional Cluster A locator |
| Hulk | 1099 | locator2 JMX manager | Optional locator management |
| Hulk | 7070 | locator2 HTTP service | Optional locator HTTP service |
| Hulk | 9405 | locator2 JMX Exporter | Locator metrics endpoint |
| Hulk | 40405 | server2 | Cache server |
| Hulk | 7071 | server2 REST | Dev REST API |
| Hulk | 9404 | server2 JMX Exporter | Metrics endpoint |
| Vision | 20334 | locatorB | Cluster B locator |
| Vision | 40405 | serverB1 | Cache server |
| Vision | 5001 | serverB1 GatewayReceiver | WAN A→B receiver (dynamic from range 5000-5001) |
| Vision | 9405 | locatorB JMX Exporter | Metrics endpoint (localhost only, scraped by local Alloy agent) |
| Vision | 9404 | serverB1 JMX Exporter | Metrics endpoint (localhost only, scraped by local Alloy agent) |
| Warmachine | 40406 | serverB2 | Cache server (distinct port — shares 172.22.79.100 with Vision) |
| Warmachine | 5000 | serverB2 GatewayReceiver | WAN A→B receiver (dynamic from range 5000-5001) |
| Warmachine | 9406 | serverB2 JMX Exporter | Metrics endpoint — must use 9406 (9404 conflicts with serverB1) |
| Antman | 6000 | server1 GatewayReceiver | WAN B→A receiver — requires `firewall-cmd --add-port=6000/tcp` on Antman |
| Thor | 5000 | portproxy | A→B GatewayReceiver forwarded to Vision (port range 5000-5001) |
| Thor | 20334 | portproxy | Cluster B locator forwarded to Vision |
| Thor | 40405 | portproxy | serverB1 forwarded to Vision |
| Thor | 40406 | portproxy | serverB2 forwarded to Warmachine |
| BlackWidow | 3000 | Grafana | Monitoring UI |
| BlackWidow | 3100 | Loki | Logs |
| BlackWidow | 3200 | Tempo | Traces |
| BlackWidow | 9009 | Mimir | Metrics backend |

## Installation Baseline

### Geode hosts

Apply this baseline on Antman, Hulk, Vision, and Warmachine:

- Java 11 is required.
- Apache Geode 1.15.2 must be installed locally.
- `gfsh` must be available from the configured `GEODE_HOME`.

### Antman

Expected defaults in `scripts/Antman/start_geode.sh`:

- `GEODE_HOME=/home/alex/Work/apache-geode-1.15.2`
- `CLUSTER_DIR=/home/alex/geode_cluster`
- WAN properties file: `/home/alex/geode_cluster/gemfire-wan-a.properties`

### Hulk

Expected defaults in `scripts/Hulk/start_geode.sh`:

- `GEODE_HOME=/home/alex/apache-geode-1.15.2`
- `GEODE_CLUSTER_DIR=/home/alex/geode_cluster`
- Locator properties file: `/home/alex/geode_cluster/gemfire-wan-a.properties`
- Server properties file: `/home/alex/geode_cluster/server2/gemfire.properties`

### Vision

Expected defaults in `scripts/Vision/start_geode.sh`:

- `JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64`
- `GEODE_HOME=/home/alex/geode`
- `CLUSTER_DIR=/home/alex/geode_cluster_b`

### Warmachine

Warmachine is RHEL 8, the same OS family as Hulk. Install Java 11 with `dnf`:

```bash
sudo dnf install -y java-11-openjdk-devel
```

Verify the installed path and set `JAVA_HOME` to match:

```bash
ls /usr/lib/jvm/ | grep java-11-openjdk
```

Expected output example (exact version string varies by RHEL 8 minor release):

```
java-11-openjdk-11.0.25.0.9-2.el8.x86_64
```

Expected defaults for `scripts/Warmachine/start_geode.sh`:

- `JAVA_HOME=/usr/lib/jvm/java-11-openjdk-11.0.25.0.9-2.el8.x86_64`
- `GEODE_HOME=/home/alex/geode`
- `CLUSTER_DIR=/home/alex/geode_cluster_b`

Note: Warmachine and Vision share the WSL2 virtual network adapter on Thor and both resolve to `172.22.79.100`. Warmachine's server (`serverB2`) must use a different port than Vision's `serverB1` (port `40405`). Use port `40406` for `serverB2`.

### Client workstation on Ironman

The Java client only needs the Geode product libraries and a Java 11 JDK. It does not need to host a local Geode server.

### Host mapping

For Linux lab hosts, keep hostname resolution explicit:

```bash
echo "192.168.0.150 Antman" | sudo tee -a /etc/hosts
echo "192.168.0.151 Hulk"   | sudo tee -a /etc/hosts
```

## Runtime Directories

Validated member directories:

| Host | Member | Directory |
| --- | --- | --- |
| Antman | locator1 | /home/alex/geode_cluster/locator1 |
| Antman | server1 | /home/alex/geode_cluster/server1 |
| Hulk | locator2 | /home/alex/geode_cluster/locator2 |
| Hulk | server2 | /home/alex/geode_cluster/server2 |
| Vision | locatorB | /home/alex/geode_cluster_b/locatorB |
| Vision | serverB1 | /home/alex/geode_cluster_b/serverB1 |
| Warmachine | serverB2 | /home/alex/geode_cluster_b/serverB2 |

Important rule:

- Use explicit `--dir` values for members so logs and runtime files stay under the intended directories.

## Firewall and Networking

### Cluster A peer traffic

Between Antman and Hulk, allow both `TCP` and `UDP` peer traffic. Fixed service ports alone are not enough for Geode membership.

Why:

- Geode uses additional runtime sockets beyond locator and cache-server ports.
- Join failures were observed when `UDP` was blocked even though `TCP` was open.

Example rule pattern:

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.151" port port="1-65535" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.151" port port="1-65535" protocol="udp" accept'
sudo firewall-cmd --reload
```

Apply the reciprocal rule on Hulk for Antman traffic.

### Thor portproxy rules

Thor forwards specific ports from its physical Wi-Fi IP (`192.168.0.14`) into the WSL2 network (`172.22.79.100`). Vision and Warmachine share that IP but use distinct ports. These rules must be present for Cluster A and external clients to reach Cluster B.

| External (Thor) | Internal (WSL2) | Purpose |
| --- | --- | --- |
| 192.168.0.14:5000 | 172.22.79.100:5000 | GatewayReceiver (Warmachine/serverB2) |
| 192.168.0.14:5001 | 172.22.79.100:5001 | GatewayReceiver (Vision/serverB1) |
| 192.168.0.14:20334 | 172.22.79.100:20334 | Cluster B locator (Vision/locatorB) |
| 192.168.0.14:40405 | 172.22.79.100:40405 | serverB1 (Vision) |
| 192.168.0.14:40406 | 172.22.79.100:40406 | serverB2 (Warmachine) |

Verify rules on Thor:

```powershell
netsh interface portproxy show all
```

Add a missing rule (run elevated on Thor):

```powershell
netsh interface portproxy add v4tov4 listenaddress=192.168.0.14 listenport=5000 connectaddress=172.22.79.100 connectport=5000
netsh interface portproxy add v4tov4 listenaddress=192.168.0.14 listenport=5001 connectaddress=172.22.79.100 connectport=5001
netsh interface portproxy add v4tov4 listenaddress=192.168.0.14 listenport=40406 connectaddress=172.22.79.100 connectport=40406
```

See the [Thor Portproxy Maintenance](#thor-portproxy-maintenance) section if rules exist but connections are still refused.

## Cluster A Scripts

### Start Antman

`scripts/Antman/start_geode.sh` starts:

1. `locator1` on `192.168.0.150:10334`
2. `server1` on `192.168.0.150:40404`

It also enables:

- locator JMX manager on `1099`
- locator HTTP service on `7070`
- locator JMX Exporter on `9405`
- server REST API on `7071`
- JMX Exporter on `9404`
- server group `wan-sender`
- WAN properties file on both locator and server (required for `remote-locators`)

### Stop Antman

`scripts/Antman/stop_geode.sh` stops:

1. `server1`
2. `locator1`

### Start Hulk

`scripts/Hulk/start_geode.sh` starts:

1. `locator2` on `192.168.0.151:10334`
2. `server2` on `192.168.0.151:40405`

It also enables:

- locator JMX manager on `1099`
- locator HTTP service on `7070`
- locator JMX Exporter on `9405`
- server REST API on `7071`
- JMX Exporter on `9404`
- membership port range `41000-41020`
- dual locator list `Antman[10334],Hulk[10334]`

### Stop Hulk

`scripts/Hulk/stop_geode.sh` stops:

1. `server2`
2. `locator2`

## Cluster B Scripts

### Start Vision

`scripts/Vision/start_geode.sh` starts:

1. `locatorB` on `172.22.79.100:20334`
2. `serverB1` on `172.22.79.100:40405`

It also sets:

- distributed system ID `2`
- locator advertised hostname-for-clients `192.168.0.14`
- `remote-locators=192.168.0.150[10334],192.168.0.151[10334]` — required for `senderB` to discover Cluster A's gateway receiver
- server group `wan-receiver`

**Key note — bind address and hostname resolution**: The locator starts with `--bind-address=172.22.79.100`. This works correctly only because Vision's `/etc/hosts` maps `Vision` → `172.22.79.100`, which causes `InetAddress.getLocalHost()` to return `172.22.79.100` at JVM startup. Without that `/etc/hosts` entry, Geode's `SocketCreator.getLocalHost()` scans network interfaces, finds WSL2's `10.255.255.254` NAT loopback proxy on the `lo` interface (which is not in the 127.0.0.0/8 range so `isLoopbackAddress()` returns false), and caches it as the locator's member address before any config is applied. Members then try to contact the locator at `10.255.255.254:20334`, which is refused. See [senderB Running, not Connected](#senderb-running-not-connected--locator-advertises-10255255254) for the full root cause and the one-time `/etc/hosts` setup required on Vision.

### Stop Vision

`scripts/Vision/stop_geode.sh` stops:

1. `serverB1`
2. `locatorB`

### Start Warmachine

`scripts/Warmachine/start_geode.sh` starts:

1. `serverB2` on `172.22.79.100:40406`

It connects to Vision's `locatorB` at `172.22.79.100[20334]` before starting the server. It requires Vision's Cluster B to already be running. It also sets:

- server group `wan-receiver`
- hostname-for-clients `192.168.0.14`
- properties file `~/geode_cluster_b/serverB2/gemfire.properties`

### Stop Warmachine

`scripts/Warmachine/stop_geode.sh` stops:

1. `serverB2`

## Gateway Configuration

### Cluster A sender (A→B)

`scripts/Antman/create_gateway_sender.sh` creates or reuses:

- GatewaySender ID: `senderA`
- group: `wan-sender`
- remote distributed system ID: `2`
- `parallel=false`
- `manual-start=false`

The script is idempotent. It checks `list gateways` against the live cache before creating the sender, so it is safe to run on every startup.

#### WAN properties requirement

Both the locator and server on Antman must load `gemfire-wan-a.properties`. This file supplies `remote-locators=192.168.0.14[20334]`, which tells the sender where to find Cluster B's locator. If only the locator receives the properties file, the server starts with `remote-locators=` empty and `senderA` will report `Running, not Connected`.

`gemfire-wan-a.properties` on Antman:

```properties
mcast-port=0
distributed-system-id=1
remote-locators=192.168.0.14[20334]
```

### Cluster A receiver (B→A)

`scripts/Antman/create_gateway_receiver.sh` creates:

- group: `wan-sender`
- start port: `6000`
- end port: `6000`
- hostname-for-senders: `192.168.0.150`
- `manual-start=false`
- `if-not-exists=true`

Only `server1` on Antman is in the `wan-sender` group, so only one receiver is created (port `6000`). Vision's `senderB` connects directly to `192.168.0.150:6000` — no portproxy is needed for this direction.

`--bind-address` is intentionally omitted for the same reason as the Cluster B receiver (Geode 1.15.2 NPE in `removeInvalidGatewayReceivers`).

**Firewall prerequisite on Antman (Rocky Linux 8 — one-time)**:

```bash
sudo firewall-cmd --permanent --add-port=6000/tcp
sudo firewall-cmd --reload
```

### Cluster B receiver (A→B)

`scripts/Vision/create_gateway_receiver.sh` creates:

- group: `wan-receiver`
- start port: `5000`
- end port: `5001`
- hostname-for-senders: `192.168.0.14`
- `manual-start=false`
- `if-not-exists=true`

The port **range** `5000-5001` is required because both `serverB1` (Vision) and `serverB2` (Warmachine) are in the `wan-receiver` group and share IP `172.22.79.100`. Each server picks a distinct port from the range: `serverB1` binds to `5001`, `serverB2` binds to `5000`. The Thor portproxy rule forwards `192.168.0.14:5000` to `172.22.79.100:5000`; a second rule forwards `192.168.0.14:5001` to `172.22.79.100:5001`.

`--bind-address` is intentionally omitted. When a specific WSL2 IP such as `172.22.79.100` is persisted into the cluster configuration XML, Geode 1.15.2 considers that element invalid on the next locator restart and crashes with a `NullPointerException` in `removeInvalidGatewayReceivers` before startup completes. Omitting `--bind-address` causes the receiver to bind to all local interfaces, which is safe because external access is gated by Thor's portproxy. `--hostname-for-senders` still ensures Cluster A senders connect through Thor.

**Auto-restore note**: Geode 1.15.2 restores GatewaySenders from cluster config automatically on server restart, but GatewayReceivers are always absent after a locator restart. The root cause is confirmed in the locatorB log: the cluster config service calls `removeInvalidGatewayReceivers` during its own startup sequence, before any server members have rejoined. At that instant there are no running members backing the receiver, so every persisted gateway receiver element is considered "invalid" and deleted from the cluster config. By the time servers rejoin seconds later, the receiver config is already gone. GatewaySenders have no equivalent cleanup pass and survive restarts unaffected. Both `scripts/Vision/start_geode.sh` and `scripts/Antman/start_geode.sh` call their respective `create_gateway_receiver.sh` at the end of startup to recreate the receiver after this deletion.

### Cluster B sender (B→A)

`scripts/Vision/create_gateway_sender.sh` creates or reuses:

- GatewaySender ID: `senderB`
- group: `wan-receiver`
- remote distributed system ID: `1`
- `parallel=false`
- `manual-start=false`

The `wan-receiver` group is used (not `wan-sender`) because both serverB1 and serverB2 are `wan-receiver` members and must carry the sender for the `/Activity` region that they host.

The script is idempotent. It checks `list gateways | grep senderB` before creating.

### Wiring senderA to /Activity on Cluster A (A→B)

`scripts/Antman/alter_region_activity.sh` runs:

```bash
alter region --name=/Activity --gateway-sender-id=senderA
```

**Prerequisite**: The `/Activity` region must be registered in the Cluster A cluster configuration XML (i.e., it was created via gfsh `create region`, not just recovered from a disk persistence store). If `alter region` fails with "does not exist in group cluster", destroy and recreate the region via gfsh — see [Region not in cluster config](#region-not-in-cluster-config).

### Wiring senderB to /Activity on Cluster B (B→A)

`scripts/Vision/alter_region_activity.sh` runs:

```bash
alter region --name=/Activity --gateway-sender-id=senderB
```

Same prerequisite as above: region must be in the cluster config XML on Cluster B.

### Coordinated region destroy

`scripts/shared/destroy_region_activity.sh` destroys `/Activity` on both clusters in order:

1. Cluster B first — stops new WAN events before touching Cluster A.
2. Cluster A second.

The script uses separate `gfsh` sessions for each cluster. Each destroy is non-fatal (the script continues with a warning if the region did not exist). Both `GFSH_A` and `GFSH_B` paths are configurable; override if the binary for one cluster is not accessible from the host running the script.

**Note**: WAN replication only propagates entry-level events (`put`, `destroy`, `invalidate`). A `destroy region` command is a cluster-level operation and is NOT forwarded over WAN. Always use this coordinated script (or manual gfsh commands on both clusters) when removing a replicated region.

## Region Wiring

Current validated region design (bidirectional):

- Cluster A region `/Activity`
  - `data-policy = REPLICATE`
  - `gateway-sender-id = senderA` (sends A→B)
- Cluster B region `/Activity`
  - `data-policy = REPLICATE_PERSISTENT` (gfsh type: `REPLICATE_PERSISTENT`)
  - `gateway-sender-id = senderB` (sends B→A)

WAN loop prevention: Geode's built-in DS ID filtering prevents infinite loops. An event originating from DS ID 1 arriving at Cluster B is not re-forwarded by `senderB` back to DS ID 1, and vice versa. No additional configuration is required.

**Important**: `alter region --gateway-sender-id` only works when the region is registered in the cluster configuration XML (i.e., created via gfsh `create region`, not recovered from a disk persistence store). If the region was auto-recovered from disk on startup, `alter region` will fail with "does not exist in group cluster". The fix is to destroy and recreate the region via gfsh — see [Region not in cluster config](#region-not-in-cluster-config).

Create commands if either region is missing:

```bash
# Cluster A
gfsh -e "connect --locator=192.168.0.150[10334]" \
  -e "create region --name=/Activity --type=REPLICATE --gateway-sender-id=senderA"

# Cluster B
gfsh -e "connect --locator=172.22.79.100[20334]" \
  -e "create region --name=/Activity --type=REPLICATE_PERSISTENT --gateway-sender-id=senderB"
```

## Recommended Execution Order

### Full bidirectional bootstrap (one-time setup)

This sequence is required on initial setup or after a full cluster wipe. A full restart is needed because `remote-locators` on Vision's locator is a JVM startup property.

```
1.  ANTMAN:      sudo firewall-cmd --permanent --add-port=6000/tcp && sudo firewall-cmd --reload
2.  WARMACHINE:  ./scripts/Warmachine/stop_geode.sh
3.  VISION:      ./scripts/Vision/stop_geode.sh
4.  HULK:        ./scripts/Hulk/stop_geode.sh         (if locator2 is running)
5.  ANTMAN:      ./scripts/Antman/stop_geode.sh
6.  LOCAL:       Verify scripts/Vision/start_geode.sh has REMOTE_LOCATORS and --bind-address=172.22.79.100 on locator
7.  VISION:      ./scripts/Vision/start_geode.sh
8.  WARMACHINE:  ./scripts/Warmachine/start_geode.sh
9.  VISION:      ./scripts/Vision/create_gateway_receiver.sh
10. VISION:      ./scripts/Vision/create_gateway_sender.sh
11. ANTMAN:      ./scripts/Antman/start_geode.sh
12. HULK:        ./scripts/Hulk/start_geode.sh         (if locator2 is needed)
13. ANTMAN:      ./scripts/Antman/create_gateway_receiver.sh
14. ANTMAN:      ./scripts/Antman/create_gateway_sender.sh
15. ANTMAN:      ./scripts/Antman/alter_region_activity.sh
16. VISION:      ./scripts/Vision/alter_region_activity.sh
```

Steps 15 and 16 (`alter region`) only succeed if the `/Activity` region is already registered in each cluster's config XML. If the region needs to be created first:

```bash
# Cluster A (Antman)
gfsh -e "connect --locator=192.168.0.150[10334]" \
  -e "create region --name=/Activity --type=REPLICATE --gateway-sender-id=senderA"

# Cluster B (Vision)
gfsh -e "connect --locator=172.22.79.100[20334]" \
  -e "create region --name=/Activity --type=REPLICATE_PERSISTENT --gateway-sender-id=senderB"
```

In that case, skip steps 15 and 16 — the sender is wired at `create region` time.

### Normal restart (cluster config intact)

On normal restarts where both clusters have their configuration disk stores intact:

```
1. ANTMAN:      ./scripts/Antman/stop_geode.sh
2. VISION:      ./scripts/Vision/stop_geode.sh
3. WARMACHINE:  ./scripts/Warmachine/stop_geode.sh
4. VISION:      ./scripts/Vision/start_geode.sh
5. WARMACHINE:  ./scripts/Warmachine/start_geode.sh
6. ANTMAN:      ./scripts/Antman/start_geode.sh
7. HULK:        ./scripts/Hulk/start_geode.sh                 (if locator2 is needed)
```

`start_geode.sh` on Vision automatically calls `create_gateway_receiver.sh` and `create_gateway_sender.sh` at the end of startup. No manual gateway steps are needed on normal restarts.

### Shutdown order

Stop Cluster A before Cluster B so the sender drains and disconnects cleanly before the receiver goes away.

```bash
# Cluster A
./scripts/Hulk/stop_geode.sh      # if server2/locator2 is running
./scripts/Antman/stop_geode.sh

# Cluster B
./scripts/Warmachine/stop_geode.sh
./scripts/Vision/stop_geode.sh
```

## Validation Commands

### Cluster A

```bash
gfsh -e "connect --locator=192.168.0.150[10334]" -e "list members"
gfsh -e "connect --locator=192.168.0.150[10334]" -e "list gateways"
gfsh -e "connect --locator=192.168.0.150[10334]" -e "describe region --name=Activity"
```

### Cluster B

```bash
gfsh -e "connect --locator=172.22.79.100[20334]" -e "list members"
gfsh -e "connect --locator=172.22.79.100[20334]" -e "list gateways"
gfsh -e "connect --locator=172.22.79.100[20334]" -e "describe region --name=Activity"
```

### WAN connectivity check from Antman

```bash
nc -zv 192.168.0.14 5000
```

Expected: `Connected to 192.168.0.14:5000`

If this fails, see [Thor Portproxy Maintenance](#thor-portproxy-maintenance).

### End-to-end replication test (A→B)

On Antman:

```bash
gfsh -e "connect --locator=192.168.0.150[10334]" -e "put --region=/Activity --key=E2E-A-001 --value=from_cluster_a"
```

On Vision:

```bash
gfsh -e "connect --locator=172.22.79.100[20334]" -e "get --region=/Activity --key=E2E-A-001"
```

Expected: Cluster B returns `from_cluster_a`. `senderA` shows `Running and Connected`.

### End-to-end replication test (B→A)

On Vision:

```bash
gfsh -e "connect --locator=172.22.79.100[20334]" -e "put --region=/Activity --key=E2E-B-001 --value=from_cluster_b"
```

On Antman:

```bash
gfsh -e "connect --locator=192.168.0.150[10334]" -e "get --region=/Activity --key=E2E-B-001"
```

Expected: Cluster A returns `from_cluster_b`. `senderB` shows `Running and Connected`.

### Confirm both senders are connected

```bash
# Cluster A — senderA should be "Running and Connected"
gfsh -e "connect --locator=192.168.0.150[10334]" -e "list gateways"

# Cluster B — senderB should be "Running and Connected"
gfsh -e "connect --locator=172.22.79.100[20334]" -e "list gateways"
```

If a sender shows `Running, not Connected`:
- **senderA**: check Thor portproxy (port 5000/5001) and Vision's GatewayReceiver status
- **senderB**: check Antman firewall (port 6000) and that Vision's locator started with `--bind-address=172.22.79.100`

## REST and Query Notes

### REST endpoint on Antman

The Geode REST app is mounted under `/geode`.

Health check:

```bash
curl http://192.168.0.150:7071/geode/v1/ping
```

Wrong path example:

- `http://192.168.0.150:7071/v1/ping` returns `404`

### Structured data example

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"reference":"REF2","symbol":"MSFT","unit":200}' \
  http://192.168.0.150:7071/geode/v1/Activity?key=2
```

OQL examples:

```bash
query --query="SELECT * FROM /Activity"
query --query="SELECT reference, symbol FROM /Activity"
query --query="SELECT * FROM /Activity WHERE symbol='MSFT'"
```

## Activity Java Client

Source:

- `client/src/main/java/lab/geode/client/ActivityClientApp.java`

Default client settings:

- locator host: `192.168.0.150`
- locator port: `10334`
- region: `Activity`

### Prerequisites on Ironman

- Java 11 JDK with `javac` and `java`
- `GEODE_HOME` pointing to a local Apache Geode 1.15.2 installation

Example in `cmd.exe`:

```cmd
set JAVA_HOME=D:\Alex\Tools\Java\temurin-11
set PATH=%JAVA_HOME%\bin;%PATH%
set GEODE_HOME=D:\Alex\Work\Installs\apache-geode-1.15.2
```

### Compile

```cmd
cd D:\Alex\Work\Installs\LGTM-Geode\client
if not exist out mkdir out
javac -cp "%GEODE_HOME%\lib\*" -d out src\main\java\lab\geode\client\ActivityClientApp.java
```

### Run

Subscriber:

```cmd
java -cp "out;%GEODE_HOME%\lib\*" lab.geode.client.ActivityClientApp subscribe
```

Publisher:

```cmd
java -cp "out;%GEODE_HOME%\lib\*" lab.geode.client.ActivityClientApp publish order-1001 created
```

Interactive mode:

```cmd
java -cp "out;%GEODE_HOME%\lib\*" lab.geode.client.ActivityClientApp interactive
```

Override defaults:

```cmd
java -cp "out;%GEODE_HOME%\lib\*" lab.geode.client.ActivityClientApp --locator-host Antman --locator-port 10334 --region Activity subscribe
```

Validation flow:

1. Run `subscribe` in one terminal.
2. Run `publish demo-1 hello` in another terminal.
3. Confirm the subscriber prints the event for key `demo-1`.

## Thor Portproxy Maintenance

Thor forwards ports from its physical Wi-Fi adapter (`192.168.0.14`) into Vision's WSL2 network (`172.22.79.100`) using Windows `netsh portproxy`. The Windows IP Helper service (`iphlpsvc`) must be running for these rules to be active.

### Check portproxy rules

```powershell
netsh interface portproxy show all
```

### Verify a rule is actively listening

```powershell
netstat -ano | findstr ":5000"
Test-NetConnection -ComputerName 192.168.0.14 -Port 5000
```

If `Test-NetConnection` reports `TcpTestSucceeded: False` but the rule appears in `portproxy show all`, the IP Helper service is stale.

### Restart IP Helper (run elevated)

```powershell
Restart-Service iphlpsvc -Force
```

Retest after restart:

```powershell
Test-NetConnection -ComputerName 192.168.0.14 -Port 5000
```

Expected: `TcpTestSucceeded: True`

### Known behaviour

- Portproxy rules persist across reboots but the IP Helper service may not rebind them correctly until restarted.
- Adding a new portproxy rule while the service is running also sometimes requires a restart before the new rule becomes active.
- Always verify with `Test-NetConnection` from Thor before assuming the WAN path is open.

## Troubleshooting

### Rocky Linux network and DNS on Antman

Symptoms:

- `ens160` exists but has no IP address
- no default route
- DNS resolution fails even after basic connectivity returns

Typical fixes:

```bash
nmcli connection add type ethernet ifname ens160 con-name ens160 autoconnect yes
nmcli connection modify ens160 ipv4.dns "8.8.8.8 1.1.1.1"
nmcli connection modify ens160 ipv4.ignore-auto-dns yes
nmcli connection up ens160
```

Useful checks:

```bash
ip addr
ip route
nmcli device status
cat /etc/resolv.conf
```

### REST API port conflict

Symptom:

- `Failed to bind to port 7070`

Cause:

- The locator already uses `7070`.

Fix:

- Keep the locator on `7070`.
- Run the server REST API on `7071`.

### String data prevents useful OQL field access

Cause:

- Values inserted as raw strings are not query-friendly.

Fix:

- Use REST or a client API to write structured payloads.

### `server2` waits for a join response

Check:

- Hulk is using Java 11.
- `server2` starts with `--dir=/home/alex/geode_cluster/server2`.
- `/home/alex/geode_cluster/server2/gemfire.properties` exists.
- Antman and Hulk allow both `TCP` and `UDP`.

### Persistent store conflict

Observed failure:

- `ConflictingPersistentDataException` on `/Activity`

Root cause:

- Cluster configuration used an absolute disk-store path that matched Antman but not Hulk.

Validated recovery pattern:

1. Export cluster configuration from `locator1`.
2. Change the disk-store path to a relative `data` path.
3. Import the corrected cluster configuration.
4. Move conflicting data directories aside on both hosts.
5. Restart the affected members.
6. Verify `show missing-disk-stores` reports none.

### locatorB NullPointerException in removeInvalidGatewayReceivers

Observed failure:

- `Exception in thread "main" java.lang.NullPointerException at org.apache.geode.distributed.internal.InternalConfigurationPersistenceService.removeInvalidGatewayReceivers`
- The locator crashes before `Cluster configuration service is up and running` is logged.

#### Root cause

`create gateway-receiver` was originally run with `--bind-address=172.22.79.100`, which persisted the specific WSL2 IP into the cluster configuration XML inside `ConfigDiskDir_locatorB`:

```xml
<gateway-receiver bind-address="172.22.79.100" start-port="5000" end-port="5000"
  hostname-for-senders="192.168.0.14" manual-start="false"/>
```

On the next locator restart, Geode's `InternalConfigurationPersistenceService` calls `removeInvalidGatewayReceivers` during startup. This method iterates over all cluster configuration groups, reads each gateway receiver XML element, and attempts to validate the `bind-address` against the local network interfaces. When it determines the address is invalid (or its internal lookup returns null), it tries to remove the element by calling into the group's `CacheConfig` object. In Geode 1.15.2 that `CacheConfig` reference is null for the group being processed, causing the NPE before startup completes.

Key distinction between the two address flags:

- `--bind-address` — the local interface the receiver JVM listens on. This value is written into the cluster config XML and is what `removeInvalidGatewayReceivers` validates.
- `--hostname-for-senders` — the address advertised to WAN senders for connecting. This value is also persisted but is not validated by `removeInvalidGatewayReceivers`.

Only `--bind-address` triggers the bug. `--hostname-for-senders` is safe to persist.

No dedicated JIRA fix exists for this NPE in the 1.15.x line. The original cleanup logic was introduced in GEODE-5502 (fixed in 1.7.0).

#### Investigation path

1. Searched `locatorB.log` for `NullPointer`, `removeInvalid`, `GatewayReceiver`, and `bind-address` patterns via the Query Service API.
2. Identified two distinct locator startup sequences in the log: the first used `--bind-address=0.0.0.0` (clean start, no crash); the second used `--bind-address=172.22.79.100` (crash on next restart).
3. Confirmed the gateway receiver was created with `--bind-address=172.22.79.100` between those two starts, persisting the WSL2 IP into the cluster config XML.
4. Confirmed that removing `--bind-address` from `create gateway-receiver` and restarting locatorB produced a clean startup with `Cluster configuration service is up and running` and no NPE.

#### Fix applied

`scripts/Vision/create_gateway_receiver.sh` was updated to omit `--bind-address`. The receiver now binds to all local interfaces. External access remains controlled by Thor's portproxy, so this is safe. `--hostname-for-senders=192.168.0.14` is retained so Cluster A senders connect through Thor.

Fix validated by:

1. Wiping all persisted data in Cluster B (`ConfigDiskDir_locatorB`, serverB1 disk store).
2. Starting Cluster B and running `create_gateway_receiver.sh` without `--bind-address`.
3. Stopping Cluster B, then restarting it — locatorB reached `Cluster configuration service is up and running` without the NPE.
4. Confirming end-to-end replication: `put` on Cluster A, `get` on Cluster B returned the expected value.

#### Recovery (if already in a broken state)

1. Back up and clear the cluster configuration disk store on Vision:
   ```bash
   cp -r /home/alex/geode_cluster_b/locatorB/ConfigDiskDir_locatorB \
         /home/alex/geode_cluster_b/locatorB/ConfigDiskDir_locatorB.bak
   rm -f /home/alex/geode_cluster_b/locatorB/ConfigDiskDir_locatorB/*
   ```
2. Start Cluster B normally:
   ```bash
   ./scripts/Vision/start_geode.sh
   ```
3. Recreate the GatewayReceiver and Activity region — both are lost when the disk store is cleared:
   ```bash
   ./scripts/Vision/create_gateway_receiver.sh
   gfsh -e "connect --locator=172.22.79.100[20334]" \
     -e "create region --name=Activity --type=REPLICATE_PERSISTENT --group=wan-receiver"
   ```
4. Validate the receiver is active:
   ```bash
   gfsh -e "connect --locator=172.22.79.100[20334]" -e "list gateways"
   ```

Expected result: `GatewayReceiver` shows status active on `serverB1` with `Sender Count = 0` until Cluster A connects. On subsequent restarts locatorB must reach `Cluster configuration service is up and running` without exception.

### senderA Running, not Connected — remote-locators empty

Observed failure:

- `list gateways` on Antman shows `senderA` status `Running, not Connected`
- Server log contains: `Remote locator host port information for remote site 2 is not available`

Root cause:

- `gemfire-wan-a.properties` was passed to the locator but not to server1. The server started with `remote-locators=` empty and cannot discover Cluster B's locator.

Fix:

- Ensure `scripts/Antman/start_geode.sh` passes `--properties-file=$WAN_PROPERTIES` to the server start command, not just the locator start command.
- Restart server1 after correcting the script.

Verify the property is loaded by checking the server log at startup:

```bash
grep "remote-locators" /home/alex/geode_cluster/server1/server1.log | head -5
```

Expected: `remote-locators=192.168.0.14[20334]`

### Thor portproxy not accepting connections

Observed failure:

- `nc -zv 192.168.0.14 5000` returns `Connection refused` from Antman
- `netsh interface portproxy show all` on Thor shows the rule exists
- Windows Firewall rule for port 5000 is enabled

Root cause:

- The IP Helper service (`iphlpsvc`) is stale. The portproxy rule is registered but the service has not bound it to the network interface.

Fix (run elevated on Thor):

```powershell
Restart-Service iphlpsvc -Force
Test-NetConnection -ComputerName 192.168.0.14 -Port 5000
```

Expected after restart: `TcpTestSucceeded: True`

Then retest from Antman:

```bash
nc -zv 192.168.0.14 5000
```

### senderB Running, not Connected — locator advertises 10.255.255.254

Observed failure:

- `list gateways` on Vision shows `senderB` status `Running, not Connected`
- `serverB1.log`: `GatewaySender senderB is not able to connect to local locator 10.255.255.254:172.22.79.100[20334] : java.net.ConnectException: Connection refused`
- `serverB1.log`: `GatewaySender senderB could not get remote locator information for remote site 1.`

Root cause:

WSL2 assigns `10.255.255.254/32` as a NAT loopback proxy alias on Vision's `lo` interface. Java's `InetAddress.isLoopbackAddress()` returns **false** for this address (it is not in the 127.0.0.0/8 range), so Geode's `SocketCreator.getLocalHost()` picks `10.255.255.254` as Vision's local host during locatorB initialization — before the JVM's bind-address configuration is applied. This address is persisted into `DistributionLocatorId.host`, which is what cluster members (including `senderB`) use to contact the locator. The locator itself listens on `172.22.79.100:20334` (gfsh always resolves to `eth0`), so a connection attempt to `10.255.255.254:20334` is refused.

Removing `--bind-address` from the gfsh command does not fix this: gfsh silently sets `bind-address=172.22.79.100` via its API regardless, and `10.255.255.254` is still picked during early JVM initialization.

Additional confirmed dead-ends (tried, do not retry):

- Removing `--bind-address` from the gfsh locator command → gfsh silently sets `bind-address=172.22.79.100` via its API regardless; no change.
- Adding `--bind-address=172.22.79.100` to the gfsh locator command → gfsh does NOT translate `--bind-address` into a `-Dgemfire.bind-address` JVM property for the locator JVM; `SocketCreator` still runs before any config is read.
- Adding `--J=-Dgemfire.bind-address=172.22.79.100` to the server start → verified in JVM args, yet the server member address is still `10.255.255.254`. Confirmed that `gemfire.bind-address` system property does NOT affect `SocketCreator.getLocalHost()` in Geode 1.15.2.

Fix:

Change Vision's hostname to resolve to `172.22.79.100` in `/etc/hosts`. When `InetAddress.getLocalHost()` returns a non-loopback address, Geode uses it immediately without scanning interfaces. This eliminates the race where `10.255.255.254` is found first.

**One-time setup on Vision** (run once, persists across Geode restarts):

```bash
# Prevent WSL2 from regenerating /etc/hosts on next distro start
echo -e "[network]\ngenerateHosts = false" | sudo tee -a /etc/wsl.conf

# Replace Vision's loopback hostname entry with the eth0 IP
sudo sed -i '/\bVision\b/d' /etc/hosts
echo "172.22.79.100 Vision" | sudo tee -a /etc/hosts

# Verify
getent hosts Vision   # must return: 172.22.79.100  Vision
```

Then restart Cluster B:

```bash
./scripts/Warmachine/stop_geode.sh
./scripts/Vision/stop_geode.sh
./scripts/Vision/start_geode.sh
./scripts/Warmachine/start_geode.sh
```

Startup confirms the fix is active if the locator reports `172.22.79.100[20334]` and JMX Manager shows `host=172.22.79.100`, and the server JVM arg shows `-Dgemfire.default.locators=172.22.79.100[20334]` (no `10.255.255.254` prefix).

After restart, `senderB` will show `Running and Connected` once it dispatches its first event to Cluster A. If the queue is empty at startup, the sender is idle until the first `put` to `/Activity` on Cluster B triggers the connection.

### GatewayReceiver absent after cluster restart

Observed failure:

- After restarting a cluster, `list gateways` shows the GatewayReceiver section absent
- The remote cluster's sender drops to `Running, not Connected`

Root cause — confirmed from `locatorB.log`:

On every locator restart, the cluster configuration service calls `removeInvalidGatewayReceivers` during its own startup sequence. This runs before any server members have rejoined. With no running members at that moment, every persisted gateway receiver element is considered "invalid" and is deleted from the cluster config disk store. The locator log records this explicitly:

```
Removed invalid cluster configuration gateway-receiver element=
  <gateway-receiver end-port="5001" hostname-for-senders="192.168.0.14"
   manual-start="false" start-port="5000" .../>
Cluster configuration service start up completed successfully and is now running ....
```

The removal line appears 18 ms before the "startup completed" line — the deletion is baked into the startup path. When servers rejoin shortly after, the receiver element is already gone from the cluster config, so they join with no gateway receiver.

GatewaySenders have no equivalent `removeInvalid` pass and survive restarts cleanly from cluster config.

This is a Geode 1.15.2 behavior in `removeInvalidGatewayReceivers` (originally introduced in GEODE-5502). The same method also triggered the NPE crash when `--bind-address` was persisted; that crash is resolved by omitting `--bind-address`, but the deletion of the gateway receiver element from the cluster config still occurs on every restart regardless.

Fix:

Both `scripts/Vision/start_geode.sh` and `scripts/Antman/start_geode.sh` call their respective `create_gateway_receiver.sh` at the end of startup, so receivers are always recreated on start. If a receiver is still missing after a normal start (e.g., the create script failed silently), re-run manually:

```bash
# Cluster B
./scripts/Vision/create_gateway_receiver.sh

# Cluster A
./scripts/Antman/create_gateway_receiver.sh
```

The remote sender should reconnect automatically within a few seconds.

### Region not in cluster config

Observed failure:

- `alter region --name=/Activity --gateway-sender-id=senderX` fails with:
  `Region named '/Activity' does not exist in group 'cluster'`
- This happens even though `list regions` shows `/Activity` is present

Root cause:

The `/Activity` region was auto-recovered from a disk persistence store on startup. Disk-recovered regions are not registered in the cluster configuration XML. The `alter region` command only operates on regions that are registered in the cluster config service.

Fix:

Destroy and recreate the region via gfsh so it gets registered in the cluster config:

```bash
# On Cluster B (Vision)
gfsh -e "connect --locator=172.22.79.100[20334]" \
  -e "destroy region --name=/Activity" \
  -e "create region --name=/Activity --type=REPLICATE_PERSISTENT --gateway-sender-id=senderB"

# On Cluster A (Antman)
gfsh -e "connect --locator=192.168.0.150[10334]" \
  -e "destroy region --name=/Activity" \
  -e "create region --name=/Activity --type=REPLICATE --gateway-sender-id=senderA"
```

**Warning**: `destroy region` removes all in-memory and disk-persisted data for that region. Export or back up data first if needed.

## Optional Expansion: Hulk locator2

The repo includes `scripts/Hulk/start_geode.sh` and `scripts/Hulk/stop_geode.sh` for a dual-locator Cluster A layout.

After cutover, Cluster A can run:

- `locator1` on Antman
- `locator2` on Hulk
- `server1` on Antman
- `server2` on Hulk

Target locator list:

```text
Antman[10334],Hulk[10334]
```

Use this expansion only after the single-locator baseline is stable and validated.
