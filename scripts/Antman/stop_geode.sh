#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME="${GEODE_HOME:-/home/alex/Work/apache-geode-1.15.2}"
LOCATOR_HOST="${LOCATOR_HOST:-192.168.0.150}"
LOCATOR_PORT="${LOCATOR_PORT:-10334}"
LOCATOR_NAME="${LOCATOR_NAME:-locator1}"
SERVER_NAME="${SERVER_NAME:-server1}"
LOCATOR_CONNECTION="${LOCATOR_CONNECTION:-$LOCATOR_HOST[$LOCATOR_PORT]}"
STOP_GATEWAY_SENDER="${STOP_GATEWAY_SENDER:-true}"
GATEWAY_SENDER_ID="${GATEWAY_SENDER_ID:-senderA}"
GATEWAY_SENDER_MEMBERS="${GATEWAY_SENDER_MEMBERS:-$SERVER_NAME}"

export PATH="$GEODE_HOME/bin:$PATH"

if [[ ! -x "$GEODE_HOME/bin/gfsh" ]]; then
  echo "gfsh not found: $GEODE_HOME/bin/gfsh" >&2
  exit 1
fi

if [[ "$STOP_GATEWAY_SENDER" == "true" ]]; then
  echo "=== Stopping GatewaySender on Antman ==="
  if gfsh -e "connect --locator=$LOCATOR_CONNECTION" \
      -e "stop gateway-sender --id=$GATEWAY_SENDER_ID --members=$GATEWAY_SENDER_MEMBERS"; then
    :
  else
    echo "GatewaySender $GATEWAY_SENDER_ID is not running or is not configured. Continuing shutdown." >&2
  fi
fi

echo "=== Stopping Geode Server ==="

gfsh -e "connect --locator=$LOCATOR_CONNECTION" \
     -e "stop server --name=$SERVER_NAME"

echo "=== Stopping Geode Locator ==="

gfsh -e "connect --locator=$LOCATOR_CONNECTION" \
     -e "stop locator --name=$LOCATOR_NAME"

echo "=== Geode Stopped ==="

