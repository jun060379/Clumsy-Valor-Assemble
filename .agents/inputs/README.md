# 2dimg2motion inputs

- `estelle_idle.png`: Estelle's idle frame, one game cell (448x352, transparent, facing screen-right, feet at (203,340)).
  Output frames must keep this canvas, this facing and this character scale so they drop into the sheet as-is.

Skill: `.agents/skills/2dimg2motion` (MIT, https://github.com/WU-HAOTIAN34/2dimg2motion; `examples/` left out).
Put generated frames under `.agents/outputs/<motion>/`; the main session aligns, tones and packs them.
