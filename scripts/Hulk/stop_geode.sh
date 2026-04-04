#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-11.0.25.0.9-2.el8.x86_64}"
PATH="$JAVA_HOME/bin:$PATH"
GEODE_HOME="${GEODE_HOME:-/home/alex/apache-geode-1.15.2}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATOR_NAME="${LOCATOR_NAME:-locator2}"
LOCATOR_BIND_ADDRESS="${LOCATOR_BIND_ADDRESS:-192.168.0.151}"
LOCATOR_PORT="${LOCATOR_PORT:-10334}"
SERVER_NAME="${SERVER_NAME:-server2}"
LOCATOR_CONNECTION="${LOCATOR_CONNECTION:-$LOCATOR_BIND_ADDRESS[$LOCATOR_PORT]}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "java not found or not executable under JAVA_HOME: $JAVA_HOME" >&2
  exit 1
fi

echo "=== Stopping Geode server on Hulk ==="
"$GFSH_BIN" -e "connect --locator=$LOCATOR_CONNECTION" \
  -e "stop server --name=$SERVER_NAME"

echo "=== Stopping Geode locator on Hulk ==="
exec "$GFSH_BIN" -e "connect --locator=$LOCATOR_CONNECTION" \
  -e "stop locator --name=$LOCATOR_NAME"
