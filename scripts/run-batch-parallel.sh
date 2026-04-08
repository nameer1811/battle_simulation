#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/common.sh"

: "${MODEL_FILE:=${HEADLESS_MODEL_FILE}}"
: "${RUNS:=500}"
: "${TIME_LIMIT_STEPS:=600}"
: "${CONFIG_FILE:=}"
: "${CONFIG_PAIRS:=}"
: "${MAX_JOBS:=${MAX_PARALLEL:-}}"

ensure_batch_artifacts

if ! java_bin=$(resolve_java_bin); then
  printf 'java not found. Install Java 17 or set JAVA_HOME.\n' >&2
  exit 1
fi

CPU_COUNT=$(resolve_cpu_count)
MAX_JOBS=$(resolve_parallel_job_count "${MAX_JOBS}")
GC_THREADS_PER_JOB=$(compute_gc_threads_per_job "${CPU_COUNT}" "${MAX_JOBS}")
CONC_GC_THREADS=1
if (( GC_THREADS_PER_JOB > 1 )); then
  CONC_GC_THREADS=$(( (GC_THREADS_PER_JOB + 1) / 2 ))
fi

# Keep per-process GC thread counts small so high job counts do not oversubscribe the machine.
JVM_OPTS=(
  "-XX:ParallelGCThreads=${GC_THREADS_PER_JOB}"
  "-XX:ConcGCThreads=${CONC_GC_THREADS}"
  "-XX:+UseParallelGC"
)

DEFAULT_CONFIGS=(
  "0 0"     # No concentration, rested Cos
  "0 50"    # No concentration, mid fatigue
  "0 100"   # No concentration, fatigued Cos (historic surprise baseline)
  "50 0"    # Mid concentration, rested Cos
  "50 50"   # Mid concentration, mid fatigue
  "50 100"  # Mid concentration, fatigued Cos
  "100 0"   # Full concentration, rested Cos
  "100 50"  # Full concentration, mid fatigue
  "100 100" # Full concentration, fatigued Cos
)
CONFIGS=()

append_config() {
  local source=$1 raw=$2 conc fatigue

  raw=${raw%%#*}
  raw=${raw//$'\r'/}
  if [[ -z "${raw//[[:space:]]/}" ]]; then
    return 0
  fi

  if [[ "${raw}" =~ ^[[:space:]]*([0-9]{1,3})[^0-9]+([0-9]{1,3})[[:space:]]*$ ]]; then
    conc=${BASH_REMATCH[1]}
    fatigue=${BASH_REMATCH[2]}
  else
    printf 'Invalid config pair in %s: %s\n' "${source}" "${raw}" >&2
    exit 1
  fi

  validate_slider_value "mexican_concentration" "${conc}"
  validate_slider_value "cos_fatigue" "${fatigue}"
  CONFIGS+=("${conc} ${fatigue}")
}

load_configs() {
  local line

  if [[ -n "${CONFIG_FILE}" && -n "${CONFIG_PAIRS}" ]]; then
    printf 'Set either CONFIG_FILE or CONFIG_PAIRS, not both.\n' >&2
    exit 1
  fi

  if [[ -n "${CONFIG_FILE}" ]]; then
    if [[ ! -f "${CONFIG_FILE}" ]]; then
      printf 'Config file not found: %s\n' "${CONFIG_FILE}" >&2
      exit 1
    fi

    while IFS= read -r line || [[ -n "${line}" ]]; do
      append_config "${CONFIG_FILE}" "${line}"
    done < "${CONFIG_FILE}"
  elif [[ -n "${CONFIG_PAIRS}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      append_config "CONFIG_PAIRS" "${line}"
    done < <(printf '%s\n' "${CONFIG_PAIRS}" | sed -E 's/[[:space:]]*[;,][[:space:]]*/\
/g')
  else
    CONFIGS=("${DEFAULT_CONFIGS[@]}")
  fi

  if [[ ${#CONFIGS[@]} -eq 0 ]]; then
    printf 'No batch configs were loaded.\n' >&2
    exit 1
  fi
}

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

load_configs

echo "Running ${#CONFIGS[@]} configs in parallel (max_jobs=${MAX_JOBS}, cpu_count=${CPU_COUNT}, gc_threads_per_job=${GC_THREADS_PER_JOB})"
pids=()
for cfg in "${CONFIGS[@]}"; do
  read -r conc fatigue <<< "$cfg"
  wait_for_available_slot "${MAX_JOBS}"
  run_config "$conc" "$fatigue" &
  pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid"; done

echo "All batch runs complete. Results in ${OUTPUT_DIR}/"
