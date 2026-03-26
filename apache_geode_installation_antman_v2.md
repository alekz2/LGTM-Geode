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
