#!/usr/bin/env bash
set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${OUT_DIR:-$SCRIPT_DIR/out}"
JMX_JAR="${JMX_JAR:-/opt/jmx-exporter/jmx_prometheus_javaagent.jar}"
JMX_CONFIG="${JMX_CONFIG:-$SCRIPT_DIR/jmx-stress-config.yml}"
JMX_PORT="${JMX_PORT:-9406}"

# ── JVM tuning ─────────────────────────────────────────────────────────────
# -Xmx768m gives the heap stressor enough headroom for HIGH intensity (512 MB target).
# For `all` + `high` simultaneously, increase to -Xmx1g.
JVM_OPTS="-Xms64m -Xmx768m"

# ── Default test parameters (override via env or positional args) ──────────
MODE="${MODE:-heap}"
DURATION="${DURATION:-60}"
INTENSITY="${INTENSITY:-medium}"
THREADS="${THREADS:-}"       # empty = use intensity default
INTERVAL="${INTERVAL:-5}"

# ── Validation ─────────────────────────────────────────────────────────────
if [[ ! -r "$JMX_JAR" ]]; then
  echo "ERROR: JMX exporter JAR not found or not readable: $JMX_JAR" >&2
  echo "       Set JMX_JAR=/path/to/jmx_prometheus_javaagent.jar" >&2
  exit 1
fi

if [[ ! -r "$JMX_CONFIG" ]]; then
  echo "ERROR: JMX config not found: $JMX_CONFIG" >&2
  exit 1
fi

if [[ ! -d "$OUT_DIR" ]]; then
  echo "ERROR: Compiled output directory not found: $OUT_DIR" >&2
  echo "       Run: javac -d client/out client/src/main/java/lab/geode/client/StressTestApp.java" >&2
  exit 1
fi

# ── Build CLI args ──────────────────────────────────────────────────────────
STRESS_ARGS=(--mode "$MODE" --duration "$DURATION" --intensity "$INTENSITY" --interval "$INTERVAL")
if [[ -n "$THREADS" ]]; then
  STRESS_ARGS+=(--threads "$THREADS")
fi

# ── Launch ──────────────────────────────────────────────────────────────────
echo "=== StressTestApp ==="
echo "  JMX port   : $JMX_PORT  (Prometheus metrics at http://localhost:$JMX_PORT/metrics)"
echo "  Mode       : $MODE"
echo "  Duration   : ${DURATION}s"
echo "  Intensity  : $INTENSITY"
echo "  Interval   : ${INTERVAL}s"
[[ -n "$THREADS" ]] && echo "  Threads    : $THREADS"
echo ""

# exec replaces the shell process with the JVM so SIGTERM/Ctrl-C goes
# directly to Java and the shutdown hook fires correctly.
exec java \
  $JVM_OPTS \
  -javaagent:"$JMX_JAR"="$JMX_PORT":"$JMX_CONFIG" \
  -cp "$OUT_DIR" \
  lab.geode.client.StressTestApp \
  "${STRESS_ARGS[@]}"
