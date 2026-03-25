#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/common.sh"

: "${MODEL_FILE:=${HEADLESS_MODEL_FILE}}"
: "${OUTPUT_FILE:=${OUTPUT_DIR}/batch-results.csv}"
: "${RUNS:=50}"
: "${MEXICAN_CONCENTRATION:=100}"
: "${COS_FATIGUE:=100}"
: "${TIME_LIMIT_STEPS:=600}"
: "${NETLOGO_THREADS:=1}"

ensure_batch_artifacts

if ! java_bin=$(resolve_java_bin); then
  printf 'java not found. Install Java 17 or set JAVA_HOME.\n' >&2
  exit 1
fi

exec "${java_bin}" \
  --class-path "${NETLOGO_JAR}:${BATCH_RUNNER_CLASS_DIR}" \
  BatchRunner \
  "${MODEL_FILE}" \
  "${OUTPUT_FILE}" \
  "${RUNS}" \
  "${MEXICAN_CONCENTRATION}" \
  "${COS_FATIGUE}" \
  "${TIME_LIMIT_STEPS}"
