#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
PATH="$JAVA_HOME/bin:$PATH"

GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_GROUPS="${SERVER_GROUPS:-wan-receiver}"

GATEWAY_RECEIVER_START_PORT="${GATEWAY_RECEIVER_START_PORT:-5000}"
GATEWAY_RECEIVER_END_PORT="${GATEWAY_RECEIVER_END_PORT:-5000}"
GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS="${GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS:-192.168.0.14}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

# --bind-address is intentionally omitted so the receiver binds to all local interfaces.
# Persisting a specific WSL2 IP (172.22.79.100) in the cluster config XML triggers a
# NullPointerException in Geode 1.15.2's removeInvalidGatewayReceivers on the next
# locator restart. External access is controlled by Thor's portproxy, so binding all
# interfaces is safe. --hostname-for-senders still routes Cluster A senders through Thor.
CREATE_CMD="create gateway-receiver --groups=${SERVER_GROUPS} --start-port=${GATEWAY_RECEIVER_START_PORT} --end-port=${GATEWAY_RECEIVER_END_PORT} --hostname-for-senders=${GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS} --manual-start=false --if-not-exists=true"

echo "=== Creating GatewayReceiver on Vision ==="
"$GFSH_BIN" \
  -e "connect --locator=$LOCATORS" \
  -e "$CREATE_CMD" \
  -e "describe config --group=$SERVER_GROUPS" \
  -e "list gateways"

echo "=== GatewayReceiver create complete ==="
