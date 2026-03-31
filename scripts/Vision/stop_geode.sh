#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_NAME="${SERVER_NAME:-serverB1}"
LOCATOR_NAME="${LOCATOR_NAME:-locatorB}"
STOP_GATEWAY_RECEIVER="${STOP_GATEWAY_RECEIVER:-true}"
GATEWAY_RECEIVER_MEMBER="${GATEWAY_RECEIVER_MEMBER:-$SERVER_NAME}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

if [[ "$STOP_GATEWAY_RECEIVER" == "true" ]]; then
  echo "=== Stopping GatewayReceiver on Vision ==="
  if "$GFSH_BIN" -e "connect --locator=$LOCATORS" \
      -e "stop gateway-receiver --members=$GATEWAY_RECEIVER_MEMBER"; then
    :
  else
    echo "GatewayReceiver is not running or is not configured. Continuing shutdown." >&2
  fi
fi

echo "=== Stopping Cluster B server on Vision ==="
"$GFSH_BIN" -e "connect --locator=$LOCATORS" \
  -e "stop server --name=$SERVER_NAME"

echo "=== Stopping Cluster B locator on Vision ==="
"$GFSH_BIN" -e "connect --locator=$LOCATORS" \
  -e "stop locator --name=$LOCATOR_NAME"

echo "=== Vision Cluster B stopped ==="
