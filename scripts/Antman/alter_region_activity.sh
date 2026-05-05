#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME="${GEODE_HOME:-/home/alex/Work/apache-geode-1.15.2}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATOR_HOST="${LOCATOR_HOST:-192.168.0.150}"
LOCATOR_PORT="${LOCATOR_PORT:-10334}"
LOCATOR_CONNECTION="${LOCATOR_CONNECTION:-$LOCATOR_HOST[$LOCATOR_PORT]}"
REGION_NAME="${REGION_NAME:-/Activity}"
GATEWAY_SENDER_ID="${GATEWAY_SENDER_ID:-senderA}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

echo "=== Altering region $REGION_NAME on Cluster A to attach $GATEWAY_SENDER_ID ==="
"$GFSH_BIN" \
  -e "connect --locator=$LOCATOR_CONNECTION" \
  -e "alter region --name=$REGION_NAME --gateway-sender-id=$GATEWAY_SENDER_ID"

echo "=== Confirming region configuration ==="
"$GFSH_BIN" \
  -e "connect --locator=$LOCATOR_CONNECTION" \
  -e "describe region --name=$REGION_NAME"

echo "=== Region alter complete ==="
