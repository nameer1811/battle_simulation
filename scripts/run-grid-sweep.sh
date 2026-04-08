#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "${SCRIPT_DIR}/common.sh"

: "${MODEL_FILE:=${HEADLESS_MODEL_FILE}}"
: "${RUNS:=500}"
: "${TIME_LIMIT_STEPS:=600}"
: "${GRID_STEP:=10}"
# Write directly to OUTPUT_DIR root (subdirs may not mount properly on cloud drives)
GRID_OUTPUT_DIR="${OUTPUT_DIR}"
: "${MAX_PARALLEL:=${MAX_JOBS:-}}"

ensure_batch_artifacts

if ! java_bin=$(resolve_java_bin); then
  printf 'java not found. Install Java 17 or set JAVA_HOME.\n' >&2
  exit 1
fi

CPU_COUNT=$(resolve_cpu_count)
MAX_PARALLEL=$(resolve_parallel_job_count "${MAX_PARALLEL}")
GC_THREADS_PER_JOB=$(compute_gc_threads_per_job "${CPU_COUNT}" "${MAX_PARALLEL}")
CONC_GC_THREADS=1
if (( GC_THREADS_PER_JOB > 1 )); then
  CONC_GC_THREADS=$(( (GC_THREADS_PER_JOB + 1) / 2 ))
fi

JVM_OPTS=(
  "-XX:ParallelGCThreads=${GC_THREADS_PER_JOB}"
  "-XX:ConcGCThreads=${CONC_GC_THREADS}"
  "-XX:+UseParallelGC"
)

mkdir -p "${GRID_OUTPUT_DIR}"

run_config() {
  local conc=$1 fatigue=$2
  local outfile="${GRID_OUTPUT_DIR}/batch-${conc}-${fatigue}.csv"
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

# Build the full grid of (concentration, fatigue) pairs
CONFIGS=()
for conc in $(seq 0 "${GRID_STEP}" 100); do
  for fatigue in $(seq 0 "${GRID_STEP}" 100); do
    CONFIGS+=("${conc} ${fatigue}")
  done
done

total=${#CONFIGS[@]}
echo "Grid sweep: ${total} configs, ${RUNS} runs each (step=${GRID_STEP}, max_parallel=${MAX_PARALLEL}, cpu_count=${CPU_COUNT}, gc_threads_per_job=${GC_THREADS_PER_JOB})"
echo "Output directory: ${GRID_OUTPUT_DIR}"

pids=()
for cfg in "${CONFIGS[@]}"; do
  read -r conc fatigue <<< "$cfg"
  wait_for_available_slot "${MAX_PARALLEL}"
  run_config "$conc" "$fatigue" &
  pids+=($!)
done
for pid in "${pids[@]}"; do wait "$pid"; done

echo "Grid sweep complete: ${total} configs x ${RUNS} runs = $((total * RUNS)) total simulations. Results in ${GRID_OUTPUT_DIR}/"
