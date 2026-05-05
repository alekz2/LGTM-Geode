#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME="${GEODE_HOME:-/home/alex/Work/apache-geode-1.15.2}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATOR_HOST="${LOCATOR_HOST:-192.168.0.150}"
LOCATOR_PORT="${LOCATOR_PORT:-10334}"
LOCATOR_CONNECTION="${LOCATOR_CONNECTION:-$LOCATOR_HOST[$LOCATOR_PORT]}"
SERVER_GROUPS="${SERVER_GROUPS:-wan-sender}"

GATEWAY_RECEIVER_START_PORT="${GATEWAY_RECEIVER_START_PORT:-6000}"
GATEWAY_RECEIVER_END_PORT="${GATEWAY_RECEIVER_END_PORT:-6000}"
GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS="${GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS:-192.168.0.150}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

# --bind-address intentionally omitted — persisting a specific IP in cluster config XML
# triggers Geode 1.15.2 NPE in removeInvalidGatewayReceivers on next locator restart.
# Vision connects directly to Antman's physical IP; no NAT/portproxy needed for B→A.
CREATE_CMD="create gateway-receiver --groups=${SERVER_GROUPS} --start-port=${GATEWAY_RECEIVER_START_PORT} --end-port=${GATEWAY_RECEIVER_END_PORT} --hostname-for-senders=${GATEWAY_RECEIVER_HOSTNAME_FOR_SENDERS} --manual-start=false --if-not-exists=true"

echo "=== Creating GatewayReceiver on Antman ==="
"$GFSH_BIN" \
  -e "connect --locator=$LOCATOR_CONNECTION" \
  -e "$CREATE_CMD" \
  -e "describe config --group=$SERVER_GROUPS" \
  -e "list gateways"

echo "=== GatewayReceiver create complete ==="
