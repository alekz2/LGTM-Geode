#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-amd64}"
PATH="$JAVA_HOME/bin:$PATH"

GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
CLUSTER_DIR="${CLUSTER_DIR:-/home/alex/geode_cluster_b}"

LOCATOR_NAME="${LOCATOR_NAME:-locatorB}"
LOCATOR_DIR="${LOCATOR_DIR:-$CLUSTER_DIR/locatorB}"
LOCATOR_BIND_ADDRESS="${LOCATOR_BIND_ADDRESS:-172.22.79.100}"
LOCATOR_HOSTNAME_FOR_CLIENTS="${LOCATOR_HOSTNAME_FOR_CLIENTS:-192.168.0.14}"
LOCATOR_PORT="${LOCATOR_PORT:-20334}"
DISTRIBUTED_SYSTEM_ID="${DISTRIBUTED_SYSTEM_ID:-2}"

SERVER_NAME="${SERVER_NAME:-serverB1}"
SERVER_DIR="${SERVER_DIR:-$CLUSTER_DIR/serverB1}"
SERVER_PORT="${SERVER_PORT:-40405}"
SERVER_BIND_ADDRESS="${SERVER_BIND_ADDRESS:-172.22.79.100}"
SERVER_HOSTNAME_FOR_CLIENTS="${SERVER_HOSTNAME_FOR_CLIENTS:-192.168.0.14}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_GROUPS="${SERVER_GROUPS:-wan-receiver}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "java not found or not executable under JAVA_HOME: $JAVA_HOME" >&2
  exit 1
fi

mkdir -p "$LOCATOR_DIR" "$SERVER_DIR"

echo "=== Starting Cluster B locator on Vision ==="
"$GFSH_BIN" -e "start locator \
  --name=$LOCATOR_NAME \
  --dir=$LOCATOR_DIR \
  --bind-address=$LOCATOR_BIND_ADDRESS \
  --hostname-for-clients=$LOCATOR_HOSTNAME_FOR_CLIENTS \
  --port=$LOCATOR_PORT \
  --J=-Dgemfire.distributed-system-id=$DISTRIBUTED_SYSTEM_ID"

sleep 5

echo "=== Starting Cluster B server on Vision ==="
"$GFSH_BIN" -e "connect --locator=$LOCATORS" \
  -e "start server \
    --name=$SERVER_NAME \
    --dir=$SERVER_DIR \
    --server-port=$SERVER_PORT \
    --bind-address=$SERVER_BIND_ADDRESS \
    --hostname-for-clients=$SERVER_HOSTNAME_FOR_CLIENTS \
    --groups=$SERVER_GROUPS"

echo "=== Vision Cluster B startup complete ==="
