#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_NAME="${SERVER_NAME:-serverB2}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

echo "=== Stopping Cluster B serverB2 on Warmachine ==="
"$GFSH_BIN" \
  -e "connect --locator=$LOCATORS" \
  -e "stop server --name=$SERVER_NAME"

echo "=== Warmachine serverB2 stopped ==="
