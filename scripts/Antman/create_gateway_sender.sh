#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME="${GEODE_HOME:-/home/alex/Work/apache-geode-1.15.2}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATOR_HOST="${LOCATOR_HOST:-192.168.0.150}"
LOCATOR_PORT="${LOCATOR_PORT:-10334}"
LOCATOR_CONNECTION="${LOCATOR_CONNECTION:-$LOCATOR_HOST[$LOCATOR_PORT]}"
SERVER_GROUPS="${SERVER_GROUPS:-wan-sender}"

GATEWAY_SENDER_ID="${GATEWAY_SENDER_ID:-senderA}"
REMOTE_DISTRIBUTED_SYSTEM_ID="${REMOTE_DISTRIBUTED_SYSTEM_ID:-2}"
GATEWAY_SENDER_PARALLEL="${GATEWAY_SENDER_PARALLEL:-false}"
GATEWAY_SENDER_MANUAL_START="${GATEWAY_SENDER_MANUAL_START:-false}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

echo "=== Checking existing GatewaySender on Antman ==="
if "$GFSH_BIN" -e "connect --locator=$LOCATOR_CONNECTION" -e "describe config --group=$SERVER_GROUPS" | grep -q "$GATEWAY_SENDER_ID"; then
  echo "GatewaySender $GATEWAY_SENDER_ID already exists. Skipping create."
else
  echo "=== Creating GatewaySender on Antman ==="
  "$GFSH_BIN" -e "connect --locator=$LOCATOR_CONNECTION" \
    -e "create gateway-sender \
      --id=$GATEWAY_SENDER_ID \
      --remote-distributed-system-id=$REMOTE_DISTRIBUTED_SYSTEM_ID \
      --groups=$SERVER_GROUPS \
      --parallel=$GATEWAY_SENDER_PARALLEL \
      --manual-start=$GATEWAY_SENDER_MANUAL_START"
fi

echo "=== GatewaySender status on Antman ==="
"$GFSH_BIN" -e "connect --locator=$LOCATOR_CONNECTION" \
  -e "describe config --group=$SERVER_GROUPS" \
  -e "list gateways"

echo "=== GatewaySender create complete ==="
