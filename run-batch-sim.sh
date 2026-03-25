#!/usr/bin/env bash
set -euo pipefail

: "${NETLOGO_HOME:=/opt/NetLogo 7.0.3}"
: "${MODEL_FILE:=/app/final_model_v2.nlogox}"
: "${OUTPUT_DIR:=/app/output}"
: "${OUTPUT_FILE:=${OUTPUT_DIR}/batch-results.csv}"
: "${RUNS:=50}"
: "${MEXICAN_CONCENTRATION:=100}"
: "${COS_FATIGUE:=100}"
: "${TIME_LIMIT_STEPS:=600}"
: "${NETLOGO_THREADS:=1}"
: "${NETLOGO_JAR:=${NETLOGO_HOME}/lib/app/netlogo-7.0.3.jar}"

mkdir -p "${OUTPUT_DIR}"

if [[ -n "${JAVA_HOME:-}" ]]; then
  java_bin="${JAVA_HOME}/bin/java"
else
  java_bin="java"
fi

exec "${java_bin}" \
  --class-path "${NETLOGO_JAR}:/app" \
  BatchRunner \
  "${MODEL_FILE}" \
  "${OUTPUT_FILE}" \
  "${RUNS}" \
  "${MEXICAN_CONCENTRATION}" \
  "${COS_FATIGUE}" \
  "${TIME_LIMIT_STEPS}"
