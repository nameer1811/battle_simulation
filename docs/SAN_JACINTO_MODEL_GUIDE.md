# San Jacinto Model Guide

This guide explains the `models/san_jacinto_battle.nlogox` simulation in plain language.

## What this model is trying to answer

The model tests two hypotheses:

1. If the Mexican force had been in a more defensive, concentrated posture (instead of dispersed camp posture) when the Texians attacked, would the battle outcome have changed?
2. If General Cos' 500 reinforcements had arrived earlier and been less fatigued, would the additional effective manpower have changed the battle?

The `mexican-concentration` and `cos-fatigue` sliders are the test variables.

## Main agents in the simulation

### 1) Texian soldiers (`texians`)
- Start on the left side of the map.
- Push forward aggressively, especially in the opening surprise phase.
- Can be in different condition states (`fighting`, `shaken`).
- Have health and morale values that change during combat.

### 2) Mexican soldiers (`mexicans`)
- Split into two subpopulations:
  - **Main body** (750 troops): Sesma, Castrillon, and other units already encamped.
  - **Cos' reinforcements** (500 troops): General Cos' column that arrived after a forced march. Visually distinguished by lighter violet color.
- Start near camp/defensive areas on the right side.
- Placement depends on `mexican-concentration`:
  - higher concentration = more tight formation,
  - lower concentration = more dispersed camp layout.
- Cos' troops are placed on the Mexican right / northern rear of camp, not on the southern cavalry-contact flank.
- At high fatigue they remain less integrated into the main camp positions, so more of them still begin dispersed.
- Have command delay (activation delay), morale, and state (`fighting`, `shaken`, `routing`).
- Can be captured during rout/collapse dynamics.

### 3) Texian cannons (`texian-cannons`)
- Periodically fire at nearby active Mexican combatants.
- Apply both damage and morale suppression.

### 4) Mexican cannon (`mexican-cannons`)
- Modeled as usually one-shot behavior, but probabilistic.
- At low readiness, it often fails to deliver an effective shot.
- At higher readiness, chance of effective fire is somewhat better.

## Environment and terrain

The map includes terrain zones that affect movement and survivability:

- `open`: normal movement.
- `marsh`: slower movement and slight cover effects.
- `barricade`: defensive line that blocks movement until degraded.
- `lake`: impassable terrain.

Important: world wrapping is disabled, so agents do not teleport from one edge to the opposite edge.

## Battle phases

The battle uses a phase system:

1. `surprise`
   - Opening shock period.
   - Texians have stronger early effectiveness.
   - Mexican response is reduced by activation delay and morale pressure.

2. `contested`
   - Main firefight/melee phase.
   - Both sides still actively engage.

3. `collapse`
   - Mexican side is losing cohesion.
   - Morale and routing become dominant.

4. `rout`
   - Organized fighting breaks down.
   - Capture outcomes become much more common.

5. `ended`
   - Simulation stop state.

### Exact battle phase transition numbers

- `surprise` lasts for `34 - round(mexican-concentration / 6)` ticks, with a floor of `12`.
- That means surprise lasts `34` ticks at concentration `0`, `25` ticks at concentration `50`, and `17` ticks at concentration `100`.
- Once `ticks >= surprise-ticks`, the model shifts from `surprise` to `contested`.
- The model also starts the real combat clock only when Texians cross the ridgeline. Before that breach, Mexican movement/fire/morale degradation are largely paused even if the phase label is already `surprise`.
- `contested` shifts to `collapse` when either:
- Mexican side morale falls below `42 - (mexican-readiness * 12)`, where `mexican-readiness = mexican-concentration / 100`.
- Or the Mexican routing share rises above `0.14 + (mexican-readiness * 0.16)`.
- In concrete terms, the collapse morale threshold is `42` at concentration `0`, `36` at concentration `50`, and `30` at concentration `100`.
- The collapse routing-share threshold is `0.14` at concentration `0`, `0.22` at concentration `50`, and `0.30` at concentration `100`.
- `collapse` shifts to `rout` when Mexican troops still in `fighting` or `shaken` fall below `250 + ((1 - mexican-readiness) * 80)`.
- That means rout begins below `330` active Mexican troops at concentration `0`, below `290` at concentration `50`, and below `250` at concentration `100`.
- The battle ends with a Texian win if phase is `rout` and fewer than `50` Mexicans remain alive.
- The battle ends with a Mexican win if readiness is at least `0.70`, Texian side morale falls below `48`, Texian casualties exceed `350`, and more than `300` Mexicans are still present.
- The battle also ends with a Mexican win if fewer than `100` Texians remain while more than `400` Mexicans are still present.
- Independent stop conditions also end the battle if either side is wiped out, or once ticks exceed `650`.

## Core rules (human summary)

### Movement
- Texians generally move toward Mexican active units.
- Mexicans move based on state:
  - active units engage,
  - routing units try to break away.

### Combat
- Combat is asymmetric (not mirror-image rules).
- Hit chance and damage depend on:
  - phase,
  - morale/state,
  - terrain cover,
  - readiness effects.

### Morale and state changes
- Nearby enemies, nearby allies, suppression, and phase context affect morale.
- Lower morale shifts units from `fighting` to `shaken`, then `routing`.

### Exact individual state transition numbers

- Texians only use two morale-based states: `fighting` and `shaken`.
- A Texian becomes `shaken` once morale falls below `22`.
- A shaken Texian rallies back to `fighting` once morale rises above `38`, but only if the battle is not already in `collapse` or `rout`.
- Mexicans do not suffer morale decay before the ridgeline is breached; that is a hard gating rule in the model.
- Mexican morale thresholds depend on `fatigue-modifier`, which is `cos-fatigue / 100` for Cos' troops and `0` for the main Mexican body.
- Mexican `shaken` threshold is `20 + (fatigue-modifier * 6)`.
- That means the main body shakes below `20`, while fully fatigued Cos troops shake below `26`.
- Mexican `routing` threshold is `12 + (fatigue-modifier * 5)`.
- That means the main body routes below `12`, while fully fatigued Cos troops route below `17`.
- Mexican rally threshold is `32 + (fatigue-modifier * 5)`, and rally only happens from `shaken` back to `fighting` during `contested`.
- That means the main body rallies above `32`, while fully fatigued Cos troops need morale above `37`.
- Once a Mexican unit reaches `routing`, the model does not use a morale threshold to restore it to `fighting`; routing is effectively terminal unless the unit is later removed by death or capture.

### Capture logic
- During collapse/rout, Mexican units near Texians and with low morale are increasingly likely to surrender/be captured.
- This is intentional so late battle outcomes are not only KIA-based.

## How the sliders work

### `mexican-concentration` (0 to 100)

Acts as defensive readiness for the entire force:

- **Low values**: dispersed setup, longer command delays, weaker early resistance, faster morale collapse.
- **High values**: tighter defensive posture, faster reaction, stronger morale retention, more resistance to opening shock.

### `cos-fatigue` (0 to 100)

Models the exhaustion level of General Cos' 500 reinforcement troops:

- **100 (historical)**: Cos' troops just completed a forced march and arrived hours before battle. They suffer maximum penalties across all systems.
- **50**: Cos arrived the previous evening. Troops had partial rest and some integration into camp positions.
- **0**: Cos arrived days earlier. Troops are fully rested and integrated, fighting at full effectiveness alongside the main body.

Fatigue affects Cos' troops in six ways (all scaling linearly with the slider):

| System | At fatigue 0 | At fatigue 100 |
|--------|-------------|----------------|
| Starting morale | Same as main body | -30 penalty |
| Morale decay rate | Normal | +0.25/tick additional decay |
| Activation delay | Readiness-based only | +12-14 extra ticks |
| Firefight hit probability | Normal | -40% penalty |
| Melee damage | Normal | -30% penalty |
| Movement speed | Normal | -20% penalty |
| Shaken threshold | morale < 28 | morale < 36 (breaks sooner) |
| Routing threshold | morale < 18 | morale < 24 (routes sooner) |
| Rally threshold | morale > 42 | morale > 50 (harder to rally) |

At high fatigue, Cos' troops also have fewer agents in concentrated positions (fatigue reduces concentration integration by up to 50%), meaning more of them start dispersed even when `mexican-concentration` is high.

## Outputs to watch

Interface monitors include:

- `Texian Casualties`
- `Mexican KIA`
- `Mexican Captured`
- `Cos Remaining` — how many of Cos' 500 troops are still alive/uncaptured
- `Mex Morale`
- `Tex Morale`
- `Battle Duration`
- `Battle Phase`

In batch CSV output, `battle_duration_minutes` is exported in minutes rather than raw ticks. The underlying model timing still uses ticks internally, with `1 tick = 6 seconds`.

For your hypothesis, compare distributions (many runs), not one run.

## Suggested experiment workflow

### Baseline sweep (concentration only)
1. Set `cos-fatigue` to 100 (historical).
2. Sweep `mexican-concentration` from 0 to 100 in increments of 10.
3. Run 50-200 repetitions per value.
4. Record medians and spread for Texian casualties, Mexican KIA, Mexican captured, battle duration.

### Cos fatigue sweep (isolating fatigue effect)
1. Fix `mexican-concentration` at a chosen value (e.g., 30 for historical-ish posture).
2. Sweep `cos-fatigue` from 0 to 100 in increments of 10.
3. Record the same metrics plus `Cos Remaining` at battle end.

### 2D interaction sweep
1. Sweep both sliders simultaneously (e.g., each at 0, 25, 50, 75, 100).
2. Look for nonlinear interaction effects — does rested Cos + high concentration create a qualitatively different outcome?
3. For a hand-picked matrix of interesting cases, use `scripts/run-batch-parallel.sh` with `CONFIG_PAIRS` or `CONFIG_FILE` rather than editing the script.

Example custom pair file:

```text
20 50
70 - 40
85,15
100:0
```

Then run:

```bash
CONFIG_FILE="$PWD/configs/custom-pairs.example.txt" \
MAX_JOBS=8 \
RUNS=200 \
./scripts/run-batch-parallel.sh
```

From the Command Center, you can run batch trials with:

`run-experiment 50`

The experiment log now includes `cos-fatigue` and `cos-remaining` values.

## Known limitations

- This is still a simplified agent-based model, not a full historical reconstruction.
- Units are individual agents, not formal companies/battalions with historical chain-of-command detail.
- Terrain is stylized rather than exact geospatial reconstruction.
- Casualty and capture rates need ongoing calibration to match specific historical targets.

## Bottom line

Use this model as an experimental sandbox:

- It is best for testing directional effects of readiness/defensive concentration and Cos' reinforcement fatigue.
- The two-slider design allows isolating each factor and testing their interaction.
- It is not yet a definitive quantitative reconstruction of San Jacinto.
