#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

: "${APP_HOME:=${REPO_ROOT}}"
: "${BUILD_DIR:=${APP_HOME}/build}"
: "${MODEL_SOURCE_FILE:=${APP_HOME}/models/san_jacinto_battle.nlogox}"
: "${HEADLESS_MODEL_FILE:=${BUILD_DIR}/san_jacinto_battle_headless.nlogox}"
: "${BATCH_RUNNER_SOURCE:=${APP_HOME}/src/BatchRunner.java}"
: "${BATCH_RUNNER_CLASS_DIR:=${BUILD_DIR}/classes}"
: "${OUTPUT_DIR:=${APP_HOME}/output}"
: "${NETLOGO_HOME:=/opt/NetLogo 7.0.3}"
: "${NETLOGO_JAR:=${NETLOGO_HOME}/lib/app/netlogo-7.0.3.jar}"

resolve_cpu_count() {
  local cpu_count

  cpu_count=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)
  if [[ ! "${cpu_count}" =~ ^[0-9]+$ ]] || (( cpu_count < 1 )); then
    cpu_count=4
  fi

  printf '%s\n' "${cpu_count}"
}

resolve_parallel_job_count() {
  local requested=${1:-} cpu_count

  if [[ -n "${requested}" ]]; then
    if [[ ! "${requested}" =~ ^[0-9]+$ ]] || (( requested < 1 )); then
      printf 'Parallel job count must be a positive integer. Got: %s\n' "${requested}" >&2
      exit 1
    fi

    printf '%s\n' "${requested}"
    return 0
  fi

  resolve_cpu_count
}

compute_gc_threads_per_job() {
  local cpu_count=$1 max_jobs=$2 gc_threads

  gc_threads=$(( cpu_count / max_jobs ))
  if (( gc_threads < 1 )); then
    gc_threads=1
  elif (( gc_threads > 4 )); then
    gc_threads=4
  fi

  printf '%s\n' "${gc_threads}"
}

wait_for_available_slot() {
  local max_jobs=$1 poll_interval=${2:-0.1} active_jobs

  while true; do
    active_jobs=$(jobs -pr | wc -l | tr -d ' ')
    if (( active_jobs < max_jobs )); then
      return 0
    fi

    sleep "${poll_interval}"
  done
}

validate_slider_value() {
  local name=$1 value=$2

  if [[ ! "${value}" =~ ^[0-9]+$ ]] || (( value < 0 || value > 100 )); then
    printf '%s must be an integer between 0 and 100. Got: %s\n' "${name}" "${value}" >&2
    exit 1
  fi
}

resolve_java_bin() {
  if [[ -n "${JAVA_HOME:-}" ]]; then
    printf '%s\n' "${JAVA_HOME}/bin/java"
    return 0
  fi

  command -v java
}

resolve_javac_bin() {
  if [[ -n "${JAVA_HOME:-}" ]]; then
    printf '%s\n' "${JAVA_HOME}/bin/javac"
    return 0
  fi

  command -v javac
}

ensure_batch_artifacts() {
  local javac_bin batch_runner_class

  mkdir -p "${OUTPUT_DIR}" "${BUILD_DIR}" "${BATCH_RUNNER_CLASS_DIR}"

  if [[ ! -f "${MODEL_SOURCE_FILE}" ]]; then
    printf 'Missing model source file: %s\n' "${MODEL_SOURCE_FILE}" >&2
    exit 1
  fi

  if [[ ! -f "${HEADLESS_MODEL_FILE}" || "${MODEL_SOURCE_FILE}" -nt "${HEADLESS_MODEL_FILE}" ]]; then
    sed '/<experiments>/,/<\/experiments>/d' "${MODEL_SOURCE_FILE}" > "${HEADLESS_MODEL_FILE}"
  fi

  if [[ ! -f "${BATCH_RUNNER_SOURCE}" ]]; then
    printf 'Missing batch runner source: %s\n' "${BATCH_RUNNER_SOURCE}" >&2
    exit 1
  fi

  batch_runner_class="${BATCH_RUNNER_CLASS_DIR}/BatchRunner.class"
  if [[ ! -f "${batch_runner_class}" || "${BATCH_RUNNER_SOURCE}" -nt "${batch_runner_class}" ]]; then
    if ! javac_bin=$(resolve_javac_bin); then
      printf 'javac not found. Install Java 17 or set JAVA_HOME.\n' >&2
      exit 1
    fi

    "${javac_bin}" \
      -cp "${NETLOGO_JAR}" \
      -d "${BATCH_RUNNER_CLASS_DIR}" \
      "${BATCH_RUNNER_SOURCE}"
  fi
}
