#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-11.0.25.0.9-2.el8.x86_64}"
PATH="$JAVA_HOME/bin:$PATH"

GEODE_HOME="${GEODE_HOME:-/home/alex/geode}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
CLUSTER_DIR="${CLUSTER_DIR:-/home/alex/geode_cluster_b}"

SERVER_NAME="${SERVER_NAME:-serverB2}"
SERVER_DIR="${SERVER_DIR:-$CLUSTER_DIR/serverB2}"
SERVER_PORT="${SERVER_PORT:-40406}"
SERVER_BIND_ADDRESS="${SERVER_BIND_ADDRESS:-172.22.79.100}"
SERVER_HOSTNAME_FOR_CLIENTS="${SERVER_HOSTNAME_FOR_CLIENTS:-192.168.0.14}"
LOCATORS="${LOCATORS:-172.22.79.100[20334]}"
SERVER_GROUPS="${SERVER_GROUPS:-wan-receiver}"
GEMFIRE_PROPERTIES="${GEMFIRE_PROPERTIES:-$SERVER_DIR/gemfire.properties}"

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

if [[ ! -r "$GEMFIRE_PROPERTIES" ]]; then
  echo "gemfire.properties not readable: $GEMFIRE_PROPERTIES" >&2
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

mkdir -p "$SERVER_DIR"

echo "=== Starting Cluster B serverB2 on Warmachine ==="
"$GFSH_BIN" \
  -e "connect --locator=$LOCATORS" \
  -e "start server \
    --name=$SERVER_NAME \
    --dir=$SERVER_DIR \
    --server-port=$SERVER_PORT \
    --bind-address=$SERVER_BIND_ADDRESS \
    --hostname-for-clients=$SERVER_HOSTNAME_FOR_CLIENTS \
    --locators=$LOCATORS \
    --groups=$SERVER_GROUPS \
    --properties-file=$GEMFIRE_PROPERTIES \
    --J=-Dgemfire.use-cluster-configuration=true \
    --J=-javaagent:$JMX_EXPORTER_JAR=$JMX_EXPORTER_PORT:$JMX_EXPORTER_CONFIG"

echo "=== Warmachine serverB2 startup complete ==="
