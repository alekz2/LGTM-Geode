#!/usr/bin/env bash
set -euo pipefail

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-11-openjdk-11.0.25.0.9-2.el8.x86_64}"
PATH="$JAVA_HOME/bin:$PATH"

GEODE_HOME="${GEODE_HOME:-/home/alex/apache-geode-1.15.2}"
GFSH_BIN="${GFSH_BIN:-$GEODE_HOME/bin/gfsh}"
GEODE_CLUSTER_DIR="${GEODE_CLUSTER_DIR:-/home/alex/geode_cluster}"

LOCATOR_NAME="${LOCATOR_NAME:-locator2}"
LOCATOR_DIR="${LOCATOR_DIR:-$GEODE_CLUSTER_DIR/locator2}"
#LOCATOR_BIND_ADDRESS="${LOCATOR_BIND_ADDRESS:-192.168.0.151}"
LOCATOR_BIND_ADDRESS="${LOCATOR_BIND_ADDRESS:-Hulk}"
LOCATOR_HOSTNAME_FOR_CLIENTS="${LOCATOR_HOSTNAME_FOR_CLIENTS:-Hulk}"
LOCATOR_PORT="${LOCATOR_PORT:-10334}"
LOCATOR_JMX_PORT="${LOCATOR_JMX_PORT:-1099}"
LOCATOR_HTTP_PORT="${LOCATOR_HTTP_PORT:-7070}"
LOCATOR_JMX_EXPORTER_PORT="${LOCATOR_JMX_EXPORTER_PORT:-9405}"
LOCATOR_PROPERTIES="${LOCATOR_PROPERTIES:-$GEODE_CLUSTER_DIR/gemfire-wan-a.properties}"
LOCATOR_CONNECTION="${LOCATOR_CONNECTION:-$LOCATOR_BIND_ADDRESS[$LOCATOR_PORT]}"

SERVER_DIR="${SERVER_DIR:-$GEODE_CLUSTER_DIR/server2}"
SERVER_NAME="${SERVER_NAME:-server2}"
LOCATORS="${LOCATORS:-Antman[10334],Hulk[10334]}"
HOSTNAME_FOR_CLIENTS="${HOSTNAME_FOR_CLIENTS:-Hulk}"
SERVER_PORT="${SERVER_PORT:-40405}"
HTTP_SERVICE_PORT="${HTTP_SERVICE_PORT:-7071}"
JMX_EXPORTER_PORT="${JMX_EXPORTER_PORT:-9404}"
JMX_EXPORTER_JAR="${JMX_EXPORTER_JAR:-/opt/jmx-exporter/jmx_prometheus_javaagent.jar}"
JMX_EXPORTER_CONFIG="${JMX_EXPORTER_CONFIG:-/opt/jmx-exporter/geode-jmx.yml}"
GEMFIRE_PROPERTIES="${GEMFIRE_PROPERTIES:-$SERVER_DIR/gemfire.properties}"
MEMBERSHIP_PORT_RANGE="${MEMBERSHIP_PORT_RANGE:-41000-41020}"

if [[ ! -x "$GFSH_BIN" ]]; then
  echo "gfsh not found or not executable: $GFSH_BIN" >&2
  exit 1
fi

if [[ ! -x "$JAVA_HOME/bin/java" ]]; then
  echo "java not found or not executable under JAVA_HOME: $JAVA_HOME" >&2
  exit 1
fi

if [[ ! -r "$LOCATOR_PROPERTIES" ]]; then
  echo "locator properties file not readable: $LOCATOR_PROPERTIES" >&2
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

echo "=== Starting Geode locator on Hulk ==="
"$GFSH_BIN" -e "start locator \
  --name=$LOCATOR_NAME \
  --dir=$LOCATOR_DIR \
  --bind-address=$LOCATOR_BIND_ADDRESS \
  --hostname-for-clients=$LOCATOR_HOSTNAME_FOR_CLIENTS \
  --port=$LOCATOR_PORT \
  --locators=$LOCATORS \
  --properties-file=$LOCATOR_PROPERTIES \
  --J=-Dgemfire.jmx-manager-port=$LOCATOR_JMX_PORT \
  --J=-Dgemfire.http-service-port=$LOCATOR_HTTP_PORT \
  --J=-javaagent:$JMX_EXPORTER_JAR=$LOCATOR_JMX_EXPORTER_PORT:$JMX_EXPORTER_CONFIG"

sleep 5

echo "=== Starting Geode server on Hulk ==="
exec "$GFSH_BIN" -e "connect --locator=$LOCATOR_CONNECTION" -e "start server \
  --name=$SERVER_NAME \
  --dir=$SERVER_DIR \
  --server-port=$SERVER_PORT \
  --locators=$LOCATORS \
  --hostname-for-clients=$HOSTNAME_FOR_CLIENTS \
  --properties-file=$GEMFIRE_PROPERTIES \
  --J=-Dgemfire.use-cluster-configuration=true \
  --J=-Dgemfire.start-dev-rest-api=true \
  --J=-Dgemfire.http-service-port=$HTTP_SERVICE_PORT \
  --J=-Dgemfire.membership-port-range=$MEMBERSHIP_PORT_RANGE \
  --J=-javaagent:$JMX_EXPORTER_JAR=$JMX_EXPORTER_PORT:$JMX_EXPORTER_CONFIG"
