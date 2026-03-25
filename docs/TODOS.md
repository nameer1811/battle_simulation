# TODOs

- Add Mexican cavalry as a distinct agent group with its own deployment zone, movement rules, morale profile, and flanking behavior.
- Split Mexican infantry into named subcommands or battalion-scale groupings so collapse can happen unevenly across the line instead of uniformly.
- Add a separate arrival-timing variable for Cos so the model can test "late but rested" versus "early and integrated" instead of treating fatigue as the only proxy.
- Revisit Mexican victory calibration at high concentration values and compare the output distribution against the historical casualty/capture shape.
- Add a scripted sweep under `scripts/` that writes scenario summaries for a wider grid of `mexican-concentration` and `cos-fatigue` values.
- Decide whether generated CSVs should remain versioned in `output/` or move to ignored artifacts with a smaller checked-in sample set.
