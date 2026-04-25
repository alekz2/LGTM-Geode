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
| Thor | 192.168.0.14 | Windows 11 | WSL2 host and `portproxy` entry point into Vision | Active |
| Vision | 172.22.79.100 | Ubuntu 24.04 | Cluster B locatorB, serverB1, GatewayReceiver | Active |
| Warmachine | 172.22.79.100 | RHEL 8 | Future Cluster B member in the same WSL2 or NAT domain | Planned |

Notes:

- Vision is behind WSL2 NAT, so Cluster A reaches the GatewayReceiver through Thor.
- Warmachine is not part of the currently validated WAN data path.

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

### WAN Path from Cluster A to Cluster B

```text
Antman -> senderA -> Thor 192.168.0.14:5000 -> Vision 172.22.79.100:5000 -> GatewayReceiver
```

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
                    +---------------v---------------+
                    | serverB1                      |
                    | Host: Vision                  |
                    | IP: 172.22.79.100            |
                    | Cache Server: 40405/tcp      |
                    | GatewayReceiver: 5000/tcp    |
                    +-------------------------------+
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
| Vision | 5000 | GatewayReceiver | WAN receiver internal listen port |
| Thor | 5000 | portproxy | External entry point forwarded to Vision |
| Thor | 20334 | portproxy | Cluster B locator forwarded to Vision |
| Thor | 40405 | portproxy | Cluster B cache server forwarded to Vision |
| BlackWidow | 3000 | Grafana | Monitoring UI |
| BlackWidow | 3100 | Loki | Logs |
| BlackWidow | 3200 | Tempo | Traces |
| BlackWidow | 9009 | Mimir | Metrics backend |

## Installation Baseline

### Geode hosts

Apply this baseline on Antman, Hulk, and Vision:

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

Thor forwards specific ports from its physical Wi-Fi IP (`192.168.0.14`) to Vision's WSL2 IP (`172.22.79.100`). These rules must be present for Cluster A to reach Cluster B.

| External (Thor) | Internal (Vision) | Purpose |
| --- | --- | --- |
| 192.168.0.14:5000 | 172.22.79.100:5000 | GatewayReceiver |
| 192.168.0.14:20334 | 172.22.79.100:20334 | Cluster B locator |
| 192.168.0.14:40405 | 172.22.79.100:40405 | Cluster B cache server |

Verify rules on Thor:

```powershell
netsh interface portproxy show all
```

Add a missing rule (run elevated on Thor):

```powershell
netsh interface portproxy add v4tov4 listenaddress=192.168.0.14 listenport=5000 connectaddress=172.22.79.100 connectport=5000
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
- server group `wan-receiver`

### Stop Vision

`scripts/Vision/stop_geode.sh` stops:

1. `serverB1`
2. `locatorB`

## Gateway Configuration

### Cluster A sender

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

### Cluster B receiver

`scripts/Vision/create_gateway_receiver.sh` creates:

- group: `wan-receiver`
- start port: `5000`
- end port: `5000`
- bind address: `172.22.79.100`
- hostname-for-senders: `192.168.0.14`
- `manual-start=false`
- `if-not-exists=true`

Both start and end port are fixed at `5000` so the receiver always binds to the same port. This matches the Thor portproxy rule and avoids the need to update portproxy rules after each restart.

This makes the receiver reachable externally through Thor while the actual listener stays on Vision.

## Region Wiring

Current validated region design:

- Cluster A region `Activity`
  - `data-policy = REPLICATE`
  - `gateway-sender-id = senderA`
- Cluster B region `Activity`
  - `data-policy = REPLICATE_PERSISTENT` (gfsh type: `REPLICATE_PERSISTENT`)
  - no sender attached

Direction rule:

- Cluster A is the source side.
- Cluster B is the target side.

Create command for Cluster B if the region is missing:

```bash
gfsh -e "connect --locator=172.22.79.100[20334]" \
  -e "create region --name=Activity --type=REPLICATE_PERSISTENT --group=wan-receiver"
```

## Recommended Execution Order

### Initial bootstrap

1. Start Cluster B on Vision.
2. Create the GatewayReceiver on Vision.
3. Create the `Activity` region on Cluster B.
4. Start Cluster A on Antman.
5. Create the GatewaySender on Antman.
6. Validate members, gateways, and region wiring.
7. Run an end-to-end put on Cluster A and get on Cluster B.

### Commands

Vision:

```bash
./scripts/Vision/start_geode.sh
./scripts/Vision/create_gateway_receiver.sh
gfsh -e "connect --locator=172.22.79.100[20334]" \
  -e "create region --name=Activity --type=REPLICATE_PERSISTENT --group=wan-receiver"
```

Antman:

```bash
./scripts/Antman/start_geode.sh
./scripts/Antman/create_gateway_sender.sh
```

Notes:

- Always run the create scripts after clearing the cluster configuration disk store — gateway and region configs are not automatically restored on restart.
- On normal restarts where the disk store is intact, start scripts alone are sufficient.

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

### End-to-end replication test

On Antman:

```bash
gfsh -e "connect --locator=192.168.0.150[10334]" -e "put --region=Activity --key=E2E001 --value=wan_test"
```

On Vision:

```bash
gfsh -e "connect --locator=172.22.79.100[20334]" -e "get --region=Activity --key=E2E001"
```

Expected result:

- Cluster B returns the value written on Cluster A.
- `senderA` remains `Running and Connected`.

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

Root cause:

- The persisted cluster configuration disk store (`ConfigDiskDir_locatorB`) contains a gateway-receiver XML element that Geode 1.15.2 considers invalid. A bug in `removeInvalidGatewayReceivers` causes an NPE when attempting to remove it, crashing the locator before startup completes.
- No dedicated JIRA fix exists for this NPE in the 1.15.x line. The original cleanup logic was introduced in GEODE-5502 (fixed in 1.7.0).

Recovery steps:

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

Expected result: `GatewayReceiver` shows status active on `serverB1` with `Sender Count = 0` until Cluster A connects.

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
