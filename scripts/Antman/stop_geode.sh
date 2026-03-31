#!/bin/bash

GEODE_HOME=/home/alex/Work/apache-geode-1.15.2
export PATH=$GEODE_HOME/bin:$PATH

echo "=== Stopping Geode Server ==="

gfsh -e "connect --locator=192.168.0.150[10334]" \
     -e "stop server --name=server1"

echo "=== Stopping Geode Locator ==="

gfsh -e "connect --locator=192.168.0.150[10334]" \
     -e "stop locator --name=locator1"

echo "=== Geode Stopped ==="

