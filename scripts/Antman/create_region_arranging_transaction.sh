#!/usr/bin/env bash
set -euo pipefail

GEODE_HOME=/home/alex/Work/apache-geode-1.15.2
GFSH_BIN="$GEODE_HOME/bin/gfsh"
LOCATOR_CONNECTION="192.168.0.150[10334]"
REGION_NAME="ArrangingTransaction"

"$GFSH_BIN" \
  -e "connect --locator=$LOCATOR_CONNECTION" \
  -e "create region --name=$REGION_NAME --type=REPLICATE_PERSISTENT"
