#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
PATH="$JAVA_HOME/bin:$PATH"

GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_GROUPS="${SERVER_GROUPS:-wan-receiver}"

GATEWAY_SENDER_ID="${GATEWAY_SENDER_ID:-senderB}"
REMOTE_DISTRIBUTED_SYSTEM_ID="${REMOTE_DISTRIBUTED_SYSTEM_ID:-1}"
GATEWAY_SENDER_PARALLEL="${GATEWAY_SENDER_PARALLEL:-false}"
GATEWAY_SENDER_MANUAL_START="${GATEWAY_SENDER_MANUAL_START:-false}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "java not found or not executable under JAVA_HOME: $JAVA_HOME" >&2
  exit 1
fi

echo "=== Checking existing GatewaySender on Vision ==="
if "$GFSH_BIN" -e "connect --locator=$LOCATORS" -e "list gateways" | grep -q "$GATEWAY_SENDER_ID"; then
  echo "GatewaySender $GATEWAY_SENDER_ID already exists in live cache. Skipping create."
else
  echo "=== Creating GatewaySender on Vision ==="
  "$GFSH_BIN" -e "connect --locator=$LOCATORS" \
    -e "create gateway-sender --id=$GATEWAY_SENDER_ID --remote-distributed-system-id=$REMOTE_DISTRIBUTED_SYSTEM_ID --groups=$SERVER_GROUPS --parallel=$GATEWAY_SENDER_PARALLEL --manual-start=$GATEWAY_SENDER_MANUAL_START"
fi

echo "=== GatewaySender status on Vision ==="
"$GFSH_BIN" -e "connect --locator=$LOCATORS" \
  -e "describe config --group=$SERVER_GROUPS" \
  -e "list gateways"

echo "=== GatewaySender create complete ==="
