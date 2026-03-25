#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/common.sh"

: "${MODEL_FILE:=${HEADLESS_MODEL_FILE}}"
: "${RUNS:=50}"
: "${TIME_LIMIT_STEPS:=600}"

# Use all available CPUs for parallel runs
MAX_JOBS=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

ensure_batch_artifacts

if ! java_bin=$(resolve_java_bin); then
  printf 'java not found. Install Java 17 or set JAVA_HOME.\n' >&2
  exit 1
fi

# JVM flags for max parallelism
JVM_OPTS=(
  "-XX:ParallelGCThreads=${MAX_JOBS}"
  "-XX:ConcGCThreads=${MAX_JOBS}"
  "-XX:+UseParallelGC"
)

# Benchmark configs: (mexican_concentration cos_fatigue) — historic baseline and sweeps
CONFIGS=(
  "0 100"    # Surprise rout baseline (historic)
  "50 100"   # Mid concentration
  "100 100"  # Max concentration, fatigued Cos
  "100 0"    # Max concentration, rested Cos (Mexican advantage)
)

run_config() {
  local conc=$1 fatigue=$2
  local outfile="${OUTPUT_DIR}/batch-${conc}-${fatigue}.csv"
  echo "[${conc}/${fatigue}] Starting -> ${outfile}"
  "${java_bin}" "${JVM_OPTS[@]}" \
    --class-path "${NETLOGO_JAR}:${BATCH_RUNNER_CLASS_DIR}" \
    BatchRunner \
    "${MODEL_FILE}" \
    "${outfile}" \
    "${RUNS}" \
    "${conc}" \
    "${fatigue}" \
    "${TIME_LIMIT_STEPS}"
  echo "[${conc}/${fatigue}] Done"
}

echo "Running ${#CONFIGS[@]} configs in parallel (max ${MAX_JOBS} jobs)"
pids=()
for cfg in "${CONFIGS[@]}"; do
  read -r conc fatigue <<< "$cfg"
  run_config "$conc" "$fatigue" &
  pids+=($!)
  while [[ $(jobs -pr | wc -l | tr -d ' ') -ge ${MAX_JOBS} ]] 2>/dev/null; do
    wait -n 2>/dev/null
  done
done
for pid in "${pids[@]}"; do wait "$pid"; done

echo "All batch runs complete. Results in ${OUTPUT_DIR}/"
