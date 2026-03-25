# Agent Guide

This repo contains a NetLogo battle simulation plus headless batch-run tooling.

## Files That Matter

- `san_jacinto_battle.nlogox`: canonical NetLogo model.
- `BatchRunner.java`: headless Java runner that opens the model, runs `setup`/`go`, and writes CSV output.
- `run-batch-sim.sh`: runs one batch configuration.
- `run-batch-parallel.sh`: runs several benchmark configurations in parallel.
- `Dockerfile`: reproducible way to build the headless runner environment.
- `output/*.csv`: batch results written by the scripts.

## Preferred Test Path

Use Docker unless the user explicitly wants a host-native run. The Docker image:

- installs NetLogo 7.0.3,
- compiles `BatchRunner.java`,
- generates `san_jacinto_battle_headless.nlogox` by stripping the `<experiments>` block,
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

That runs these configurations from `run-batch-parallel.sh`:

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
  --entrypoint /app/run-batch-sim.sh \
  -e MODEL_FILE=/app/san_jacinto_battle_headless.nlogox \
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

1. Generate the headless-safe model file:

```bash
sed '/<experiments>/,/<\/experiments>/d' san_jacinto_battle.nlogox > san_jacinto_battle_headless.nlogox
```

2. Compile the runner:

```bash
javac -cp "/path/to/NetLogo 7.0.3/lib/app/netlogo-7.0.3.jar" BatchRunner.java
```

3. Run one batch:

```bash
NETLOGO_HOME="/path/to/NetLogo 7.0.3" \
MODEL_FILE="$PWD/san_jacinto_battle_headless.nlogox" \
OUTPUT_DIR="$PWD/output" \
OUTPUT_FILE="$PWD/output/batch-results.csv" \
RUNS=50 \
MEXICAN_CONCENTRATION=100 \
COS_FATIGUE=100 \
TIME_LIMIT_STEPS=600 \
./run-batch-sim.sh
```

`run-batch-parallel.sh` expects the compiled `BatchRunner.class` to be present and uses the same NetLogo jar.

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
- If you change `BatchRunner.java`, `run-batch-sim.sh`, `run-batch-parallel.sh`, or `Dockerfile`, re-read all four files before editing because they are tightly coupled.

## Approval Policy

For script and Docker-based batch testing in this repo, agents should treat these command families as safe and preferred:

- `docker build` for building the reproducible NetLogo batch-run image from the repo `Dockerfile`.
- `docker run` for executing `run-batch-sim.sh`, `run-batch-parallel.sh`, or other one-off containerized batch tests against that image.
- `./run-batch-sim.sh` and `./run-batch-parallel.sh` for host-native runs when Java 17 and NetLogo 7.0.3 are already installed.

When approval systems exist, prefer granting persistent approval for `docker build` and `docker run` in this repository so both Codex-style and Claude-style agents can execute the documented batch-testing workflow without repeated prompts.
