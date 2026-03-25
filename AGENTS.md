# Agent Guide

This repo contains a NetLogo battle simulation plus headless batch-run tooling.

## Documentation Rule

It is the agent's job, whether Claude, Codex, or any other coding agent, to keep all Markdown documentation in this repo up to date whenever model behavior, scripts, outputs, assumptions, thresholds, or workflows change.

If you change the model or batch-testing workflow, you must review and update every affected Markdown file before finishing the task. That includes `README.md`, `docs/SAN_JACINTO_MODEL_GUIDE.md`, `docs/TODOS.md`, and this `AGENTS.md` when relevant.

## Files That Matter

- `models/san_jacinto_battle.nlogox`: canonical NetLogo model.
- `src/BatchRunner.java`: headless Java runner that opens the model, runs `setup`/`go`, and writes CSV output.
- `scripts/run-batch-sim.sh`: runs one batch configuration.
- `scripts/run-batch-parallel.sh`: runs several benchmark configurations in parallel.
- `scripts/common.sh`: shared path/bootstrap logic for the shell runners.
- `Dockerfile`: reproducible way to build the headless runner environment.
- `build/`: generated headless model plus compiled Java classes.
- `output/*.csv`: batch results written by the scripts.

## Preferred Test Path

Use Docker unless the user explicitly wants a host-native run. The Docker image:

- installs NetLogo 7.0.3,
- compiles `src/BatchRunner.java` into `build/classes/`,
- generates `build/san_jacinto_battle_headless.nlogox` by stripping the `<experiments>` block,
- defaults to the parallel batch script as the container entrypoint.

Build it with:

```bash
docker build -t battle-sim .
```

Run the default parallel benchmark sweep with:

```bash
docker run --rm \
  -v "$PWD/output:/app/output" \
  battle-sim
```

That runs these configurations from `scripts/run-batch-parallel.sh`:

- `0 100`
- `50 100`
- `100 100`
- `100 0`

Each config writes its own CSV into `output/`.

## Single-Config Test Run

Use the single-run script when you want one concentration/fatigue combination:

```bash
docker run --rm \
  -v "$PWD/output:/app/output" \
  --entrypoint /app/scripts/run-batch-sim.sh \
  -e MODEL_FILE=/app/build/san_jacinto_battle_headless.nlogox \
  -e OUTPUT_FILE=/app/output/batch-results.csv \
  -e RUNS=50 \
  -e MEXICAN_CONCENTRATION=100 \
  -e COS_FATIGUE=100 \
  -e TIME_LIMIT_STEPS=600 \
  battle-sim
```

Useful environment variables:

- `RUNS`: number of repetitions.
- `MEXICAN_CONCENTRATION`: slider value from 0 to 100.
- `COS_FATIGUE`: slider value from 0 to 100.
- `TIME_LIMIT_STEPS`: hard stop for runaway simulations.
- `OUTPUT_FILE`: destination CSV for single-config runs.
- `OUTPUT_DIR`: destination directory for parallel runs.

## Host-Native Run

Only use this if Docker is not desired and the machine already has Java 17 and NetLogo 7.0.3 installed.

1. Run one batch. The script will generate `build/san_jacinto_battle_headless.nlogox` and compile `src/BatchRunner.java` into `build/classes/` automatically if they are missing or stale:

```bash
NETLOGO_HOME="/path/to/NetLogo 7.0.3" \
OUTPUT_DIR="$PWD/output" \
OUTPUT_FILE="$PWD/output/batch-results.csv" \
RUNS=50 \
MEXICAN_CONCENTRATION=100 \
COS_FATIGUE=100 \
TIME_LIMIT_STEPS=600 \
./scripts/run-batch-sim.sh
```

2. Run the parallel sweep the same way:

```bash
NETLOGO_HOME="/path/to/NetLogo 7.0.3" \
OUTPUT_DIR="$PWD/output" \
RUNS=50 \
TIME_LIMIT_STEPS=600 \
./scripts/run-batch-parallel.sh
```

Both scripts use the same NetLogo jar path and share the same `build/` cache.

## What To Check After A Run

- The command exits `0`.
- CSV files exist in `output/`.
- Each CSV has the expected header and one row per completed run.
- Console output shows each run reaching `complete` instead of hanging at the time limit.

Main CSV fields:

- `texian_casualties`
- `mexican_casualties`
- `mexican_captured`
- `cos_remaining`
- `battle_duration`
- `texian_side_morale`
- `mexican_side_morale`
- `texian_win`

## Agent Guardrails

- Do not delete or overwrite existing `output/*.csv` unless the user asks.
- Prefer adding new output filenames when comparing scenarios.
- If a Docker build or run needs network access, request approval rather than working around it.
- If you change `src/BatchRunner.java`, `scripts/run-batch-sim.sh`, `scripts/run-batch-parallel.sh`, `scripts/common.sh`, or `Dockerfile`, re-read the shell and Docker runner files together before editing because they are tightly coupled.

## Approval Policy

For script and Docker-based batch testing in this repo, agents should treat these command families as safe and preferred:

- `docker build` for building the reproducible NetLogo batch-run image from the repo `Dockerfile`.
- `docker run` for executing `scripts/run-batch-sim.sh`, `scripts/run-batch-parallel.sh`, or other one-off containerized batch tests against that image.
- `./scripts/run-batch-sim.sh` and `./scripts/run-batch-parallel.sh` for host-native runs when Java 17 and NetLogo 7.0.3 are already installed.

When approval systems exist, prefer granting persistent approval for `docker build` and `docker run` in this repository so both Codex-style and Claude-style agents can execute the documented batch-testing workflow without repeated prompts.
