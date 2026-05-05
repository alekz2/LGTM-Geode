#!/usr/bin/env bash
set -euo pipefail

# ── Cluster B (Vision side) ─────────────────────────────────────────────────
JAVA_HOME_B="${JAVA_HOME_B:-/usr/lib/jvm/java-11-openjdk-amd64}"
GEODE_HOME_B="${GEODE_HOME_B:-/home/alex/geode}"
GFSH_B="${GFSH_B:-$GEODE_HOME_B/bin/gfsh}"
LOCATORS_B="${LOCATORS_B:-172.22.79.100[20334]}"

# ── Cluster A (Antman side) ─────────────────────────────────────────────────
# Override GFSH_A if Cluster A's gfsh is not accessible from this host.
GEODE_HOME_A="${GEODE_HOME_A:-/home/alex/Work/apache-geode-1.15.2}"
GFSH_A="${GFSH_A:-$GEODE_HOME_A/bin/gfsh}"
LOCATORS_A="${LOCATORS_A:-192.168.0.150[10334]}"

REGION_NAME="${REGION_NAME:-/Activity}"

PATH="$JAVA_HOME_B/bin:$PATH"

if [[ ! -x "$GFSH_B" ]]; then
  echo "Cluster B gfsh not found or not executable: $GFSH_B" >&2
  exit 1
fi

if [[ ! -x "$GFSH_A" ]]; then
  echo "Cluster A gfsh not found or not executable: $GFSH_A" >&2
  echo "Override GFSH_A to point to a reachable Geode installation, or run destroy on Antman separately." >&2
  exit 1
fi

# Destroy on Cluster B first — stops new WAN events before touching Cluster A
echo "=== Destroying $REGION_NAME on Cluster B ==="
if "$GFSH_B" \
    -e "connect --locator=$LOCATORS_B" \
    -e "destroy region --name=$REGION_NAME"; then
  echo "Region $REGION_NAME destroyed on Cluster B."
else
  echo "WARNING: destroy region on Cluster B exited non-zero. Region may not have existed. Continuing." >&2
fi

echo "=== Destroying $REGION_NAME on Cluster A ==="
if "$GFSH_A" \
    -e "connect --locator=$LOCATORS_A" \
    -e "destroy region --name=$REGION_NAME"; then
  echo "Region $REGION_NAME destroyed on Cluster A."
else
  echo "WARNING: destroy region on Cluster A exited non-zero. Region may not have existed or cluster unreachable." >&2
fi

echo "=== Coordinated region destroy complete ==="
