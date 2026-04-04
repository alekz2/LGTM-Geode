# Apache Geode WAN Replication Lab Plan and Execution Runbook

**Environment:** Antman / Hulk / Vision / WarMachine
**Purpose:** Run Apache Geode WAN replication from Cluster A on Antman to Cluster B on Vision
**Current status:** WAN sender and receiver are persisted through Geode cluster configuration groups, the `Activity` regions are configured correctly, and end-to-end replication is validated

---

## 1. Lab topology

### 1.1 Physical layout

#### Cluster A - Source side
- **Antman** - Rocky Linux 8 - `192.168.0.150`
- **Hulk** - RHEL 8 - `192.168.0.151`

#### Cluster B - Target side
- **Vision** - Ubuntu 24.04 on WSL2 - internal IP `172.22.79.100`
- **WarMachine** - RHEL 8 in the same WSL2/NAT domain for future expansion

#### External forwarding host
- **Thor** - Windows 11 host - `192.168.0.14`
- **Role** - Windows `portproxy` entry point into the Vision WSL2 guest

### 1.2 Distributed system IDs
- **Cluster A** = `1`
- **Cluster B** = `2`

### 1.3 Active roles
- **Cluster A**
  - `locator1` on Antman
  - `server1` on Antman
  - `GatewaySender senderA` on Antman
- **Cluster B**
  - `locatorB` on Vision
  - `serverB1` on Vision
  - `GatewayReceiver` on Vision

### 1.4 Active ports

| Component | Host | Port | Purpose |
| --- | --- | ---: | --- |
| Cluster A locator | Antman | 10334 | Cluster A locator |
| Cluster A JMX manager | Antman | 1099 | Locator manager |
| Cluster A HTTP service | Antman | 7070 | Locator HTTP service |
| Cluster A server1 | Antman | 40404 | Cache server |
| Cluster A server1 HTTP | Antman | 7071 | REST/HTTP service |
| Cluster B locator internal | Vision | 20334 | Cluster B locator |
| Cluster B server1 | Vision | 40405 | Cache server |
| Cluster B receiver internal | Vision | 5000 | GatewayReceiver listen port |
| Cluster B receiver external | Thor | 5000 | Forwarded WAN receiver endpoint |

### 1.5 WAN traffic path

```text
Antman -> senderA -> Thor 192.168.0.14:5000 -> Vision 172.22.79.100:5000 -> GatewayReceiver
```

---

## 2. Current validated Geode state

### 2.1 Vision - Cluster B
- `locatorB` runs on `172.22.79.100:20334`
- `serverB1` runs on `172.22.79.100:40405`
- `GatewayReceiver` listens on `172.22.79.100:5000`
- `hostname-for-senders` advertises `192.168.0.14`

### 2.2 Antman - Cluster A
- `locator1` runs on `192.168.0.150:10334`
- `server1` runs on `192.168.0.150:40404`
- `senderA` targets remote distributed system `2`
- `senderA` is connected to receiver location `192.168.0.14:5000`

### 2.3 Region wiring
- **Cluster A** region `Activity`
  - `data-policy = REPLICATE`
  - `gateway-sender-id = senderA`
- **Cluster B** region `Activity`
  - `data-policy = PERSISTENT_REPLICATE`
  - no sender attached

---

## 3. Scripted workflow in repo

### 3.1 Vision scripts
- `scripts/Vision/start_geode.sh`
  - starts `locatorB`
  - starts `serverB1` with group `wan-receiver`
- `scripts/Vision/stop_geode.sh`
  - stops `serverB1`
  - stops `locatorB`
- `scripts/Vision/create_gateway_receiver.sh`
  - writes a persistent receiver config to Geode cluster configuration
  - targets group `wan-receiver`
  - uses port `5000`
  - binds to `172.22.79.100`
  - advertises `192.168.0.14` to senders

### 3.2 Antman scripts
- `scripts/Antman/start_geode.sh`
  - starts `locator1`
  - starts `server1` with group `wan-sender`
- `scripts/Antman/stop_geode.sh`
  - stops `server1`
  - stops `locator1`
- `scripts/Antman/create_gateway_sender.sh`
  - writes a persistent sender config to Geode cluster configuration
  - targets group `wan-sender`
  - targets remote distributed system `2`

### 3.3 Recommended execution order

#### Vision
```bash
./scripts/Vision/start_geode.sh
./scripts/Vision/create_gateway_receiver.sh
```

#### Antman
```bash
./scripts/Antman/start_geode.sh
./scripts/Antman/create_gateway_sender.sh
```

Notes:
- Run the create scripts once to persist the gateway configs in the locators.
- After that, rebooting and rerunning only the start scripts should bring the gateways back automatically because the servers rejoin with the same groups.

---

## 4. Commands executed in the validated lab state

### 4.1 Start Cluster B on Vision

```bash
./scripts/Vision/create_gateway_receiver.sh
./scripts/Vision/start_geode.sh
```

Validation:

```bash
gfsh -e "connect --locator=172.22.79.100[20334]" -e "list gateways"
ss -ltnp | grep 5000
```

Validated result:
- `describe config --group=wan-receiver` shows the receiver config in cluster configuration
- `GatewayReceiver` present on `serverB1`
- receiver listening on port `5000`

### 4.2 Start Cluster A on Antman

```bash
./scripts/Antman/create_gateway_sender.sh
./scripts/Antman/start_geode.sh
```

Validation:

```bash
gfsh -e "connect --locator=192.168.0.150[10334]" -e "list gateways"
```

Validated result:
- `describe config --group=wan-sender` shows sender `senderA` in cluster configuration
- `senderA` present on `server1`
- sender status `Running and Connected`
- receiver location `192.168.0.14:5000`

### 4.3 Validate external receiver path from Antman

```bash
nc -zv 192.168.0.14 5000
```

Validated result:

```text
Ncat: Connected to 192.168.0.14:5000.
```

### 4.4 Validate and correct region wiring

Cluster A validation:

```bash
gfsh -e "connect --locator=192.168.0.150[10334]" -e "describe region --name=Activity"
```

Current validated state on Cluster A:

```text
gateway-sender-id | senderA
```

Cluster B validation:

```bash
gfsh -e "connect --locator=172.22.79.100[20334]" -e "describe region --name=Activity"
```

Current validated state on Cluster B:

```text
data-policy | PERSISTENT_REPLICATE
```

### 4.5 End-to-end WAN replication test

Executed on Antman:

```bash
gfsh -e "connect --locator=192.168.0.150[10334]" -e "put --region=Activity --key=E2E001 --value=wan_test_20260330"
```

Executed on Vision:

```bash
gfsh -e "connect --locator=172.22.79.100[20334]" -e "get --region=Activity --key=E2E001"
```

Validated result:
- Cluster B returned the value written on Cluster A
- `list gateways` on Antman still showed `senderA` as `Running and Connected`

---

## 5. Validation summary

| Check | Command | Expected / Observed Result | Status |
| --- | --- | --- | --- |
| Thor receiver path reachable | `nc -zv 192.168.0.14 5000` from Antman | connected | PASS |
| Cluster B locator up | `list members` on Vision | `locatorB` present | PASS |
| Cluster B server up | `list members` on Vision | `serverB1` present | PASS |
| Receiver active | `list gateways` on Vision | receiver on `5000` | PASS |
| Receiver persisted | `describe config --group=wan-receiver` on Vision | receiver config present | PASS |
| Receiver listening | `ss -ltnp | grep 5000` on Vision | listener on `172.22.79.100:5000` | PASS |
| Cluster A locator up | `list members` on Antman | `locator1` present | PASS |
| Cluster A server up | `list members` on Antman | `server1` present | PASS |
| Sender active | `list gateways` on Antman | `senderA Running and Connected` | PASS |
| Sender persisted | `describe config --group=wan-sender` on Antman | senderA config present | PASS |
| Sender receiver target | `list gateways` on Antman | receiver location `192.168.0.14:5000` | PASS |
| Cluster A region wiring | `describe region --name=Activity` on Antman | `gateway-sender-id = senderA` | PASS |
| Cluster B region data policy | `describe region --name=Activity` on Vision | `PERSISTENT_REPLICATE` | PASS |
| End-to-end replication | `put` on Antman + `get` on Vision | replicated value returned | PASS |

---

## 6. Important notes and caveats

### 6.1 Vision is behind WSL2 NAT
- `Vision` is not directly reachable from Antman on the LAN
- WAN traffic must enter through `Thor` at `192.168.0.14`
- the receiver advertises `192.168.0.14` to senders via `hostname-for-senders`

### 6.2 Gateway persistence model
- gateway configs are now written through Geode cluster configuration using groups
- `wan-receiver` is the Vision server group
- `wan-sender` is the Antman server group
- the create scripts should only be needed when bootstrapping or intentionally changing the gateway configuration
- after a normal reboot, rerunning the host start scripts should be sufficient

### 6.3 Region direction matters
- For this lab, Cluster A is the source and Cluster B is the target
- `Activity` on Cluster A must point to `senderA`
- `Activity` on Cluster B must not point to a sender

### 6.4 Hulk and WarMachine
- `Hulk` and `WarMachine` are not part of the currently validated end-to-end path
- they remain future scale-out members rather than part of the validated minimum WAN topology

---

## 7. Current one-line status

**Cluster A senderA and Cluster B GatewayReceiver are persisted via group-based cluster configuration, and end-to-end replication for region `Activity` is validated from Antman to Vision.**




