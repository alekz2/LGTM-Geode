#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
PATH="$JAVA_HOME/bin:$PATH"

GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
REGION_NAME="${REGION_NAME:-/Activity}"
GATEWAY_SENDER_ID="${GATEWAY_SENDER_ID:-senderB}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "java not found or not executable under JAVA_HOME: $JAVA_HOME" >&2
  exit 1
fi

echo "=== Altering region $REGION_NAME on Cluster B to attach $GATEWAY_SENDER_ID ==="
"$GFSH_BIN" \
  -e "connect --locator=$LOCATORS" \
  -e "alter region --name=$REGION_NAME --gateway-sender-id=$GATEWAY_SENDER_ID"

echo "=== Confirming region configuration ==="
"$GFSH_BIN" \
  -e "connect --locator=$LOCATORS" \
  -e "describe region --name=$REGION_NAME"

echo "=== Region alter complete ==="
