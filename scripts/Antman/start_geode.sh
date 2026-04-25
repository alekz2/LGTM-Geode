#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME="${GEODE_HOME:-/home/alex/Work/apache-geode-1.15.2}"
CLUSTER_DIR="${CLUSTER_DIR:-/home/alex/geode_cluster}"

LOCATOR_NAME="${LOCATOR_NAME:-locator1}"
LOCATOR_DIR="${LOCATOR_DIR:-$CLUSTER_DIR/locator1}"
LOCATOR_HOST="${LOCATOR_HOST:-192.168.0.150}"
LOCATOR_PORT="${LOCATOR_PORT:-10334}"
JMX_PORT="${JMX_PORT:-1099}"
LOCATOR_HTTP_PORT="${LOCATOR_HTTP_PORT:-7070}"
WAN_PROPERTIES="${WAN_PROPERTIES:-$CLUSTER_DIR/gemfire-wan-a.properties}"

SERVER_NAME="${SERVER_NAME:-server1}"
SERVER_DIR="${SERVER_DIR:-$CLUSTER_DIR/server1}"
SERVER_PORT="${SERVER_PORT:-40404}"
SERVER_HTTP_PORT="${SERVER_HTTP_PORT:-7071}"
LOCATOR_CONNECTION="${LOCATOR_CONNECTION:-$LOCATOR_HOST[$LOCATOR_PORT]}"
SERVER_GROUPS="${SERVER_GROUPS:-wan-sender}"

LOCATOR_JMX_EXPORTER_PORT="${LOCATOR_JMX_EXPORTER_PORT:-9405}"
JMX_EXPORTER_PORT="${JMX_EXPORTER_PORT:-9404}"
JMX_EXPORTER_JAR="${JMX_EXPORTER_JAR:-/opt/jmx-exporter/jmx_prometheus_javaagent.jar}"
JMX_EXPORTER_CONFIG="${JMX_EXPORTER_CONFIG:-/opt/jmx-exporter/geode-jmx.yml}"

export PATH="$GEODE_HOME/bin:$PATH"

if [[ ! -x "$GEODE_HOME/bin/gfsh" ]]; then
  echo "gfsh not found: $GEODE_HOME/bin/gfsh" >&2
  exit 1
fi

if [[ ! -r "$WAN_PROPERTIES" ]]; then
  echo "WAN properties file not readable: $WAN_PROPERTIES" >&2
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

echo "=== Starting WAN locator on Antman ==="
gfsh -e "start locator \
  --name=$LOCATOR_NAME \
  --dir=$LOCATOR_DIR \
  --port=$LOCATOR_PORT \
  --hostname-for-clients=$LOCATOR_HOST \
  --properties-file=$WAN_PROPERTIES \
  --J=-Dgemfire.jmx-manager-port=$JMX_PORT \
  --J=-Dgemfire.http-service-port=$LOCATOR_HTTP_PORT \
  --J=-javaagent:$JMX_EXPORTER_JAR=$LOCATOR_JMX_EXPORTER_PORT:$JMX_EXPORTER_CONFIG"

sleep 5

echo "=== Starting WAN server on Antman ==="
gfsh -e "connect --locator=$LOCATOR_CONNECTION" \
     -e "start server \
         --name=$SERVER_NAME \
         --dir=$SERVER_DIR \
         --server-port=$SERVER_PORT \
         --hostname-for-clients=$LOCATOR_HOST \
         --http-service-port=$SERVER_HTTP_PORT \
         --groups=$SERVER_GROUPS \
         --properties-file=$WAN_PROPERTIES \
         --J=-Dgemfire.start-dev-rest-api=true \
         --J=-javaagent:$JMX_EXPORTER_JAR=$JMX_EXPORTER_PORT:$JMX_EXPORTER_CONFIG"

echo "=== Antman WAN startup complete ==="
