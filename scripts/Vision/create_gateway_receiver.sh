#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
PATH="$JAVA_HOME/bin:$PATH"

GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_NAME="${SERVER_NAME:-serverB1}"

GATEWAY_RECEIVER_START_PORT="${GATEWAY_RECEIVER_START_PORT:-5000}"
GATEWAY_RECEIVER_END_PORT="${GATEWAY_RECEIVER_END_PORT:-5000}"
GATEWAY_RECEIVER_BIND_ADDRESS="${GATEWAY_RECEIVER_BIND_ADDRESS:-172.22.79.100}"
GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS="${GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS:-192.168.0.14}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

echo "=== Creating GatewayReceiver on Vision ==="
"$GFSH_BIN" -e "connect --locator=$LOCATORS" \
  -e "create gateway-receiver \
    --members=$SERVER_NAME \
    --start-port=$GATEWAY_RECEIVER_START_PORT \
    --end-port=$GATEWAY_RECEIVER_END_PORT \
    --bind-address=$GATEWAY_RECEIVER_BIND_ADDRESS \
    --hostname-for-senders=$GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS \
    --manual-start=false \
    --if-not-exists=true" \
  -e "list gateways"

echo "=== GatewayReceiver create complete ==="
