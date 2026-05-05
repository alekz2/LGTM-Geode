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
REMOTE_LOCATORS="${REMOTE_LOCATORS:-192.168.0.150[10334],192.168.0.151[10334]}"

SERVER_NAME="${SERVER_NAME:-serverB1}"
SERVER_DIR="${SERVER_DIR:-$CLUSTER_DIR/serverB1}"
SERVER_PORT="${SERVER_PORT:-40405}"
SERVER_BIND_ADDRESS="${SERVER_BIND_ADDRESS:-172.22.79.100}"
SERVER_HOSTNAME_FOR_CLIENTS="${SERVER_HOSTNAME_FOR_CLIENTS:-192.168.0.14}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_GROUPS="${SERVER_GROUPS:-wan-receiver}"

LOCATOR_JMX_EXPORTER_PORT="${LOCATOR_JMX_EXPORTER_PORT:-9405}"
JMX_EXPORTER_PORT="${JMX_EXPORTER_PORT:-9404}"
JMX_EXPORTER_JAR="${JMX_EXPORTER_JAR:-/opt/jmx-exporter/jmx_prometheus_javaagent.jar}"
JMX_EXPORTER_CONFIG="${JMX_EXPORTER_CONFIG:-/opt/jmx-exporter/geode-jmx.yml}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "java not found or not executable under JAVA_HOME: $JAVA_HOME" >&2
  exit 1
fi

if [[ ! -r "$JMX_EXPORTER_JAR" ]]; then
  echo "JMX exporter jar not readable: $JMX_EXPORTER_JAR" >&2
  exit 1
fi

if [[ ! -r "$JMX_EXPORTER_CONFIG" ]]; then
  echo "JMX exporter config not readable: $JMX_EXPORTER_CONFIG" >&2
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
  --J=-Dgemfire.distributed-system-id=$DISTRIBUTED_SYSTEM_ID \
  --J=-Dgemfire.remote-locators=$REMOTE_LOCATORS \
  --J=-javaagent:$JMX_EXPORTER_JAR=$LOCATOR_JMX_EXPORTER_PORT:$JMX_EXPORTER_CONFIG"

sleep 5

echo "=== Starting Cluster B server on Vision ==="
"$GFSH_BIN" -e "connect --locator=$LOCATORS" \
  -e "start server \
    --name=$SERVER_NAME \
    --dir=$SERVER_DIR \
    --server-port=$SERVER_PORT \
    --bind-address=$SERVER_BIND_ADDRESS \
    --hostname-for-clients=$SERVER_HOSTNAME_FOR_CLIENTS \
    --groups=$SERVER_GROUPS \
    --J=-javaagent:$JMX_EXPORTER_JAR=$JMX_EXPORTER_PORT:$JMX_EXPORTER_CONFIG"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Creating/restoring GatewayReceiver on Cluster B ==="
"$SCRIPT_DIR/create_gateway_receiver.sh"

echo "=== Creating/restoring GatewaySender on Cluster B ==="
"$SCRIPT_DIR/create_gateway_sender.sh"

echo "=== Vision Cluster B startup complete ==="
