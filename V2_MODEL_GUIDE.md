# San Jacinto V2 Model Guide

This guide explains the `final_model_v2.nlogox` simulation in plain language.

## What this model is trying to answer

The core hypothesis is:

If the Mexican force had been in a more defensive, concentrated posture (instead of dispersed camp posture) when the Texians attacked, would the battle outcome have changed?

The `mexican-concentration` slider is the main test variable.

## Main agents in the simulation

### 1) Texian soldiers (`texians`)
- Start on the left side of the map.
- Push forward aggressively, especially in the opening surprise phase.
- Can be in different condition states (`fighting`, `shaken`).
- Have health and morale values that change during combat.

### 2) Mexican soldiers (`mexicans`)
- Start near camp/defensive areas on the right side.
- Placement depends on `mexican-concentration`:
  - higher concentration = more tight formation,
  - lower concentration = more dispersed camp layout.
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

### Capture logic
- During collapse/rout, Mexican units near Texians and with low morale are increasingly likely to surrender/be captured.
- This is intentional so late battle outcomes are not only KIA-based.

## How the slider works

`mexican-concentration` (0 to 100) acts as defensive readiness:

- **Low values**: dispersed setup, longer command delays, weaker early resistance, faster morale collapse.
- **High values**: tighter defensive posture, faster reaction, stronger morale retention, more resistance to opening shock.

## Outputs to watch

Interface monitors include:

- `Texian Casualties`
- `Mexican KIA`
- `Mexican Captured`
- `Mex Morale`
- `Tex Morale`
- `Battle Duration`
- `Battle Phase`

For your hypothesis, compare distributions (many runs), not one run.

## Suggested experiment workflow

1. Pick slider values (for example: 0, 20, 40, 60, 80, 100).
2. Run many repetitions per value (for example: 50 to 200).
3. Record medians and spread for:
   - Texian casualties,
   - Mexican KIA,
   - Mexican captured,
   - battle duration.
4. Compare how outcomes shift with concentration.

From the Command Center, you can run batch trials with:

`run-experiment 50`

## Known limitations

- This is still a simplified agent-based model, not a full historical reconstruction.
- Units are individual agents, not formal companies/battalions with historical chain-of-command detail.
- Terrain is stylized rather than exact geospatial reconstruction.
- Casualty and capture rates need ongoing calibration to match specific historical targets.

## Bottom line

Use this model as an experimental sandbox:

- It is best for testing directional effects of readiness/defensive concentration.
- It is not yet a definitive quantitative reconstruction of San Jacinto.
