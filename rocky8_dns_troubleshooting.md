Here is a clean, structured **Markdown document** you can copy or save as `rocky8_dns_troubleshooting.md`.

---

````markdown
# Rocky Linux 8 DNS & Network Troubleshooting (VMware)

## Overview

This document summarizes the issues encountered, root causes identified, and step-by-step resolutions applied to fix DNS and network connectivity problems on a Rocky Linux 8 VM running in VMware Workstation.

---

# 🧩 Initial Problem

```bash
ping www.yahoo.com
ping: www.yahoo.com: Name or service not known
````

### Symptoms:

* DNS resolution failed
* Internet access unavailable
* System unable to resolve hostnames

---

# 🔍 Troubleshooting Journey

## 1. Checked Network Interface

```bash
ip addr
```

### Finding:

* `ens160` interface existed but had **no IP address**

### Root Cause:

* No DHCP lease → no network connectivity

---

## 2. Verified Routing

```bash
ip route
```

### Finding:

```bash
192.168.122.0/24 dev virbr0 ... linkdown
```

### Issues:

* ❌ No default route
* ❌ Only `virbr0` present (irrelevant virtual bridge)

---

## 3. Checked NetworkManager Status

```bash
nmcli device status
```

### Finding:

```bash
ens160  ethernet  disconnected  --
```

### Root Cause:

* No active connection profile bound to `ens160`

---

# 🛠️ Resolution Steps

## Step 1 — Create Network Connection

```bash
nmcli connection add type ethernet ifname ens160 con-name ens160 autoconnect yes
```

---

## Step 2 — Remove Duplicate Connection

```bash
nmcli connection show
nmcli connection delete uuid <duplicate-uuid>
```

---

## Step 3 — Configure DHCP

```bash
nmcli connection modify uuid <active-uuid> ipv4.method auto
```

---

## Step 4 — Enable Auto-connect

```bash
nmcli connection modify uuid <active-uuid> connection.autoconnect yes
```

---

## Step 5 — Bring Interface Up

```bash
nmcli connection up uuid <active-uuid>
```

---

## Step 6 — Verify Network

```bash
ip addr show ens160
ip route
```

### Expected:

```bash
inet 192.168.x.x
default via 192.168.x.x
```

---

## Step 7 — Test Connectivity

```bash
ping 8.8.8.8
```

### Result:

* ✅ Network connectivity restored

---

# 🌐 DNS Issue

## Problem After Network Fix

```bash
ping www.yahoo.com
Name or service not known
```

---

## Step 8 — Check DNS Configuration

```bash
cat /etc/resolv.conf
```

### Finding:

```bash
nameserver 192.168.33.2
```

### Root Cause:

* Invalid or unreachable DNS server from DHCP

---

## Step 9 — Override DNS

```bash
nmcli connection modify ens160 ipv4.dns "8.8.8.8 1.1.1.1"
nmcli connection modify ens160 ipv4.ignore-auto-dns yes
nmcli connection up ens160
```

---

## Step 10 — Verify DNS

```bash
cat /etc/resolv.conf
```

### Expected:

```bash
nameserver 8.8.8.8
nameserver 1.1.1.1
```

---

## Step 11 — Final Test

```bash
ping www.yahoo.com
```

### Result:

* ✅ DNS resolution working
* ✅ Internet access restored

---

# 🔁 Persistence Issue

## Problem:

* Network worked temporarily but failed after reboot

## Root Cause:

* Connection profile not properly configured or duplicated

## Fix:

* Cleaned duplicate profiles
* Ensured:

  * `ipv4.method auto`
  * `connection.autoconnect yes`

---

# 🧠 Key Learnings

## Network Debugging Layers

| Layer       | Issue              | Resolution                 |
| ----------- | ------------------ | -------------------------- |
| Interface   | No IP              | Create/activate connection |
| Routing     | No default route   | DHCP config                |
| DNS         | Invalid nameserver | Override DNS               |
| Persistence | Lost after reboot  | Fix connection profile     |

---

## Important Concepts

### 1. NetworkManager (RHEL/Rocky 8)

* Replaces traditional `dhclient`
* Uses **connection profiles**

### 2. Interface vs Connection

| Component  | Meaning                       |
| ---------- | ----------------------------- |
| `ens160`   | Physical interface            |
| Connection | Configuration (IP, DNS, DHCP) |

---

## Common VMware Issues

* DHCP not assigning DNS correctly
* NAT DNS proxy misconfigured
* Duplicate connection profiles
* Interface not auto-connecting

---

# ✅ Final State

System now has:

* ✔ Valid IP address
* ✔ Default gateway
* ✔ Working DNS
* ✔ Persistent configuration
* ✔ Internet connectivity after reboot

---

# 🚀 Recommended Best Practices

* Always verify:

  ```bash
  ip addr
  ip route
  nmcli device status
  ```

* Use static DNS for lab environments:

  ```bash
  8.8.8.8 / 1.1.1.1
  ```

* Avoid duplicate NetworkManager profiles

---

# 🎯 Conclusion

The issue was **not just DNS**, but a layered network failure involving:

1. Missing connection profile
2. No IP / routing
3. Invalid DNS from DHCP
4. Non-persistent configuration

Systematic debugging resolved all layers successfully.

---

````

---

