#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
PATH="$JAVA_HOME/bin:$PATH"
GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_NAME="${SERVER_NAME:-serverB1}"
LOCATOR_NAME="${LOCATOR_NAME:-locatorB}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

echo "=== Stopping Cluster B server on Vision ==="
"$GFSH_BIN" -e "connect --locator=$LOCATORS" \
  -e "stop server --name=$SERVER_NAME"

echo "=== Stopping Cluster B locator on Vision ==="
"$GFSH_BIN" -e "connect --locator=$LOCATORS" \
  -e "stop locator --name=$LOCATOR_NAME"

echo "=== Vision Cluster B stopped ==="
