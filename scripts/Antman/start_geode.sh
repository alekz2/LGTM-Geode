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
START_GATEWAY_SENDER="${START_GATEWAY_SENDER:-true}"
GATEWAY_SENDER_ID="${GATEWAY_SENDER_ID:-senderA}"
GATEWAY_SENDER_MEMBERS="${GATEWAY_SENDER_MEMBERS:-$SERVER_NAME}"

JMX_EXPORTER_PORT=9404

export PATH="$GEODE_HOME/bin:$PATH"

if [[ ! -x "$GEODE_HOME/bin/gfsh" ]]; then
  echo "gfsh not found: $GEODE_HOME/bin/gfsh" >&2
  exit 1
fi

if [[ ! -r "$WAN_PROPERTIES" ]]; then
  echo "WAN properties file not readable: $WAN_PROPERTIES" >&2
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
  --J=-Dgemfire.http-service-port=$LOCATOR_HTTP_PORT"

sleep 5

echo "=== Starting WAN server on Antman ==="
gfsh -e "connect --locator=$LOCATOR_CONNECTION" \
     -e "start server \
         --name=$SERVER_NAME \
         --dir=$SERVER_DIR \
         --server-port=$SERVER_PORT \
         --hostname-for-clients=$LOCATOR_HOST \
         --http-service-port=$SERVER_HTTP_PORT \
         --J=-Dgemfire.start-dev-rest-api=true \
	 --J=-javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent.jar=${JMX_EXPORTER_PORT}:/opt/jmx-exporter/geode-jmx.yml"

if [[ "$START_GATEWAY_SENDER" == "true" ]]; then
  echo "=== Starting GatewaySender on Antman ==="
  if gfsh -e "connect --locator=$LOCATOR_CONNECTION" \
      -e "start gateway-sender --id=$GATEWAY_SENDER_ID --members=$GATEWAY_SENDER_MEMBERS"; then
    :
  else
    echo "GatewaySender $GATEWAY_SENDER_ID is not configured yet. Run scripts/Antman/create_gateway_sender.sh first." >&2
  fi
fi

echo "=== Antman WAN startup complete ==="
