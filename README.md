# San Jacinto Battle Model

🗺️ A NetLogo simulation of the Battle of San Jacinto focused on one counterfactual question:

What changes if the Mexican camp is more concentrated and if General Cos' reinforcements arrive less exhausted?

This repo is built around a single canonical model file: `models/san_jacinto_battle.nlogox`.

## Why this model is interesting

This is not a generic red-vs-blue skirmish. The model tries to recreate the shape of the historical fight:

- the Texian approach begins as a fast-moving surprise attack,
- the Mexican side starts from an encamped posture rather than an ideal battle line,
- General Cos' 500 reinforcements may exist on paper but still be militarily degraded by fatigue,
- terrain matters because the breastwork, marsh, river edge, and ridgeline channel how the battle unfolds,
- the ending is not just "who got more kills" but also whether the Mexican force collapses into rout and capture.

## Core dynamics

### 1. Readiness vs fatigue

The two sliders drive nearly everything:

- `mexican-concentration` controls how tightly the Mexican camp is organized at setup.
- `cos-fatigue` controls how badly Cos' reinforcements suffer from forced-march exhaustion.

Higher `mexican-concentration` means:

- more troops begin in tighter forward and reserve clusters,
- higher starting morale,
- shorter activation delays,
- stronger early resistance,
- lower chance of rapid collapse.

Higher `cos-fatigue` means Cos' 500 men:

- start with lower morale,
- react more slowly,
- move more slowly,
- shoot worse,
- hit less effectively in melee,
- break sooner and rally less easily,
- are less integrated into concentrated positions even when overall readiness is high.

Deployment note:

- Cos' men are staged on the Mexican right / northern rear of camp, not hard-wired into the southern flank that Lamar's cavalry sweeps first.

### 2. The map is doing real work

🌾 The battlefield is not flat open space.

The model includes:

- Buffalo Bayou and the San Jacinto River,
- Peggy Lake and marshy connectors,
- a north-south ridgeline,
- a long breastwork line in front of the Mexican camp,
- Texian and Mexican camp footprints.

Terrain changes movement and cover:

- `open` is normal ground,
- `marsh` slows units and adds a little cover,
- `lake` is impassable,
- `barricade` blocks movement until the Texians batter through it,
- `ridgeline` helps structure the opening approach and the moment combat really begins.

### 3. Combat does not fully start at tick 0

⚠️ One of the most important model choices: the Mexican side is largely inert until the Texians cross the ridgeline.

Before the ridgeline is breached:

- Mexican movement is halted,
- cannon fire is halted,
- firefights are halted,
- Mexican morale stays stable.

Once Texians cross that line:

- `ridgeline-breached?` flips to true,
- the combat clock starts,
- Mexican units begin moving and fighting,
- the battle shifts from approach into actual contact.

That means the model distinguishes between approach time and real battle duration.

### 4. Phase changes matter

The battle moves through:

- `surprise`
- `contested`
- `collapse`
- `rout`
- `ended`

The surprise window lasts:

`34 - round(mexican-concentration / 6)` ticks, with a floor of `12`.

So concentrated Mexican deployments shorten the vulnerable surprise window.

Collapse and rout are driven by morale and the share of Mexican troops already routing, not by one arbitrary timer. A high-readiness Mexican defense can also win outright if Texian morale breaks badly enough and the Mexican force remains intact.

### 5. Firefight, melee, cannon, and capture are asymmetric

⚔️ The model does not mirror Texian and Mexican combat rules.

Texians:

- have stronger early surprise effectiveness,
- generally shoot farther and harder in the opening,
- accelerate during collapse and rout,
- use cavalry as a southern flanking force rather than just another infantry blob.

Mexicans:

- depend heavily on readiness and activation delay,
- are heavily penalized in the surprise phase,
- can still become much more dangerous if concentration is high and fatigue is low,
- are more likely to break into rout/capture cascades once morale fails.

Captures are intentionally constrained:

- no capture logic runs until Texians are actually past the breastwork,
- rout, chasers, and terrain traps near marsh or water all increase late-battle capture pressure.

That helps the model produce a more historically plausible endgame than a pure KIA-only resolution.

## What to watch in a run

Useful outputs:

- `Texian Casualties`
- `Mexican KIA`
- `Mexican Captured`
- `Cos Remaining`
- `Mex Morale`
- `Tex Morale`
- `Battle Duration`
- `Battle Phase`
- `Casualty Ratio`

If you are evaluating a hypothesis, compare many runs. Single runs are too noisy to mean much.

## Running the model

### Interactive NetLogo run

Open `models/san_jacinto_battle.nlogox` in NetLogo 7.x and use the UI:

- set `mexican-concentration`,
- set `cos-fatigue`,
- click `setup`,
- click `go`.

### Headless batch runs with Docker

🧪 This is the preferred scripted test path.

Build:

```bash
docker build -t battle-sim .
```

Run the default parallel benchmark sweep:

```bash
docker run --rm \
  -v "$PWD/output:/app/output" \
  battle-sim
```

That executes the configurations baked into `scripts/run-batch-parallel.sh`:

- `0 100`
- `50 100`
- `100 100`
- `100 0`

Run a single configuration:

```bash
docker run --rm \
  -v "$PWD/output:/app/output" \
  --entrypoint /app/scripts/run-batch-sim.sh \
  -e MODEL_FILE=/app/build/san_jacinto_battle_headless.nlogox \
  -e OUTPUT_FILE=/app/output/batch-results.csv \
  -e RUNS=10 \
  -e MEXICAN_CONCENTRATION=100 \
  -e COS_FATIGUE=100 \
  -e TIME_LIMIT_STEPS=600 \
  battle-sim
```

### Grid sweep for analytics (500 runs per config)

Run all combinations of `mexican-concentration` and `cos-fatigue` at a configurable step interval:

```bash
docker run --rm \
  -v "$PWD/output:/app/output" \
  --entrypoint /app/scripts/run-grid-sweep.sh \
  -e RUNS=500 \
  -e GRID_STEP=10 \
  battle-sim
```

`GRID_STEP=10` produces an 11×11 = 121-configuration grid. With `RUNS=500`, that is 60,500 total simulations. Each config writes its own CSV to `output/grid/`.

For a faster first pass use `GRID_STEP=20` (36 configs × 500 = 18,000 runs).

After the sweep finishes, analyze and plot the results:

```bash
pip install pandas matplotlib seaborn
python scripts/analyze_results.py --output-dir output/grid --plots-dir output/plots
```

This writes `output/grid/summary.csv` (one aggregated row per config) and heatmap PNGs in `output/plots/`.

Key environment variables for the grid sweep:

| Variable | Default | Meaning |
|----------|---------|---------|
| `RUNS` | `500` | Repetitions per config |
| `GRID_STEP` | `10` | Step between parameter values (0, step, 2×step, … 100) |
| `MAX_PARALLEL` | `nproc` | Concurrent JVM processes |
| `OUTPUT_DIR` | `output/grid` | Where per-config CSVs are written |
| `TIME_LIMIT_STEPS` | `600` | Hard step cap per simulation run |

The batch scripts keep generated artifacts in `build/`:

- `build/san_jacinto_battle_headless.nlogox`: headless-safe model file
- `build/classes/BatchRunner.class`: compiled Java runner classes

## Output schema

The batch runner writes CSV rows with:

- `run`
- `mexican_concentration`
- `cos_fatigue`
- `texian_casualties`
- `mexican_casualties`
- `mexican_captured`
- `cos_remaining`
- `battle_duration`
- `texian_side_morale`
- `mexican_side_morale`
- `texian_win`

## Repo layout

- `models/`: canonical NetLogo model source
- `src/`: Java headless runner source
- `scripts/`: batch scripts and shared bootstrap logic
- `docs/`: longer model notes and backlog items
- `Dockerfile`: reproducible headless runtime
- `build/`: generated headless model and compiled classes (ignored by Git)
- `docs/SAN_JACINTO_MODEL_GUIDE.md`: longer plain-language guide
- `AGENTS.md`: repo-specific agent instructions

## Caveats

📌 This is an experimental historical simulation, not a definitive reconstruction.

It is best used for directional questions:

- Does concentration materially blunt surprise?
- How much does Cos' fatigue matter on its own?
- Is there a threshold where higher readiness flips the battle from collapse to sustained resistance?

Those are the kinds of questions this model is built to answer well.
