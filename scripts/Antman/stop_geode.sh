#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME="${GEODE_HOME:-/home/alex/Work/apache-geode-1.15.2}"
LOCATOR_HOST="${LOCATOR_HOST:-192.168.0.150}"
LOCATOR_PORT="${LOCATOR_PORT:-10334}"
LOCATOR_NAME="${LOCATOR_NAME:-locator1}"
SERVER_NAME="${SERVER_NAME:-server1}"
LOCATOR_CONNECTION="${LOCATOR_CONNECTION:-$LOCATOR_HOST[$LOCATOR_PORT]}"

export PATH="$GEODE_HOME/bin:$PATH"

if [[ ! -x "$GEODE_HOME/bin/gfsh" ]]; then
  echo "gfsh not found: $GEODE_HOME/bin/gfsh" >&2
  exit 1
fi

echo "=== Stopping Geode Server ==="

gfsh -e "connect --locator=$LOCATOR_CONNECTION" \
     -e "stop server --name=$SERVER_NAME"

echo "=== Stopping Geode Locator ==="

gfsh -e "connect --locator=$LOCATOR_CONNECTION" \
     -e "stop locator --name=$LOCATOR_NAME"

echo "=== Geode Stopped ==="

