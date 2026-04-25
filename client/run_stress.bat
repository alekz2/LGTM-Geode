@echo off
setlocal enabledelayedexpansion

:: ── Paths ──────────────────────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
set "OUT_DIR=%SCRIPT_DIR%out"

:: JMX settings — override by setting these env vars before calling this script
if not defined JMX_JAR     set "JMX_JAR=D:\Alex\Work\Installs\JMX-Exporter\jmx_prometheus_javaagent-1.5.0.jar"
if not defined JMX_CONFIG  set "JMX_CONFIG=%SCRIPT_DIR%jmx-stress-config.yml"
if not defined JMX_PORT    set "JMX_PORT=9406"

:: ── JVM tuning ─────────────────────────────────────────────────────────────
:: -Xmx768m gives the heap stressor enough headroom for HIGH intensity (512 MB target).
:: For `all` + `high` simultaneously, increase to -Xmx1g.
set "JVM_OPTS=-Xms64m -Xmx768m"

:: ── Default test parameters ────────────────────────────────────────────────
if not defined MODE       set "MODE=heap"
if not defined DURATION   set "DURATION=60"
if not defined INTENSITY  set "INTENSITY=medium"
if not defined INTERVAL   set "INTERVAL=5"

:: ── Validation ─────────────────────────────────────────────────────────────
if not exist "%JMX_JAR%" (
    echo ERROR: JMX exporter JAR not found: %JMX_JAR%
    echo        Set JMX_JAR=C:\path\to\jmx_prometheus_javaagent.jar
    exit /b 1
)

if not exist "%JMX_CONFIG%" (
    echo ERROR: JMX config not found: %JMX_CONFIG%
    exit /b 1
)

if not exist "%OUT_DIR%" (
    echo ERROR: Compiled output directory not found: %OUT_DIR%
    echo        Run: javac -d client\out client\src\main\java\lab\geode\client\StressTestApp.java
    exit /b 1
)

:: ── Build CLI args ──────────────────────────────────────────────────────────
set "STRESS_ARGS=--mode %MODE% --duration %DURATION% --intensity %INTENSITY% --interval %INTERVAL%"
if defined THREADS set "STRESS_ARGS=%STRESS_ARGS% --threads %THREADS%"

:: ── Launch info ─────────────────────────────────────────────────────────────
echo === StressTestApp ===
echo   JMX port   : %JMX_PORT%  (Prometheus metrics at http://localhost:%JMX_PORT%/metrics)
echo   Mode       : %MODE%
echo   Duration   : %DURATION%s
echo   Intensity  : %INTENSITY%
echo   Interval   : %INTERVAL%s
if defined THREADS echo   Threads    : %THREADS%
echo.

:: ── Launch ──────────────────────────────────────────────────────────────────
:: Note: paths with spaces in JMX_JAR or JMX_CONFIG must use 8.3 short names
:: or be relocated to a path without spaces (e.g. C:\opt\jmx-exporter\).
java %JVM_OPTS% ^
  -javaagent:%JMX_JAR%=%JMX_PORT%:%JMX_CONFIG% ^
  -cp "%OUT_DIR%" ^
  lab.geode.client.StressTestApp ^
  %STRESS_ARGS%
