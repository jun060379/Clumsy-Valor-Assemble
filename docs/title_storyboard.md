# Title screen storyboard (scripts/title.gd, mode "title")

Persona-skin title: black left / pink diagonal right, the guild hall's front on the right with the members on its steps,
the logo block on the left. The title grows with the save ("자라는 타이틀"): what stands in front of the hall depends on it. Everything below runs on the title's real-time clock `t` (ms); nothing is linear — the logo and the slabs use the `--bk` overshoot
(`UIA.p(…, "bk")`), the hall, the people and their silhouettes are `UIA.Spring`s, the bars and lines use `mv` / `in` / `out`.
Secondary motion lags the primary (silhouette after person, pink copy after letter, cursor-bar after the word).

Composition (fractions of the viewport, from the concept mock at 1800×1000):
- pink field: polygon (0.44W,0)–(W,0)–(W,H)–(0.64W,H); black everywhere else
- the hall plate (`assets/title/hall.png`, 1920×1088, the painted cottage; its row 1000 is the ground, the grass lies
  under it): its right edge 0.06W past the screen's (the bracket lantern hugs the edge), the building (rows 90–1000)
  0.74H tall or the plate 0.76W wide, whichever is smaller (1000×460 goes by height, 900×500 by width). It keeps its
  own colours by day and is modulated toward a cool violet (0.5, 0.43, 0.72) by the night factor — no ink treatment.
  The sign board on the left bracket (px 56,616 120×150 with its chains) is cut out of the plate (the plate is drawn in
  three regions around it) and hung from (116, 600), swinging ±2° (2.3 s). Both boards stay blank.
- the light ladder (`lit_windows()` = min(7, restored facilities + 1), `LIGHT_STEPS`), in order: (1) the right wing's
  window — Eilin's, always; (2) the left window; (3) the lantern by the door; (4) the lantern on the right bracket;
  (5) warm light through the door's crack; (6) smoke from the left chimney; (7) smoke from the right. Windows are a warm
  fill (#ffcf7a) over the measured panes (`WIN_R`, `WIN_L`) with the candle flicker (`LIT.fl`) and a `UI.glow` halo;
  lanterns a warm dot with a wide halo; the crack a warm line with a halo; smoke five soft puffs per chimney rising
  0.26H over 4.2 s, drifting with a breeze, growing and fading
- the logo (`assets/title/logo.png`, the brush "Clumsy Valor / 어설픈 용맹 / Assemble"): the left column, 0.4W wide
  from (0.04W, 0.1H) (capped at 0.54H tall), on its pink blob (`blob.png`, 1.15× the logo, rolling ±1° over 6.4 s).
  The motto sits small above it at 0.082H. The old slabs, letters, bars and the -ASSEMBLE- tag are gone
- the menu: four slabs under the logo as before; the picked row has no slab — it rides the brush stroke (`brush.png`,
  1.3× the slab width, 2.3× its height) that slides between rows on `sp_cur` (resp .3 damp .8), its label white with an
  ink shadow, centred on the stroke's thick middle. The guild's flower (`emblem.png`) stands small (0.16H) at the top
  right of the menu column (the watermark behind the people was tried and read as a stain on the house)
- the sky: the pink field takes its colour from the world clock (`arena.tod_h`, `SKY_K`): day #ff3d7f, dusk #c8246c
  (6:18 / 18:30), night #4a1740 — always in the pink family. The outro eases it back to the plain pink for the sweep.
- the people: every member in `fame.rec` (에스텔 first, `people()`), `st_full` (cut to its knees, `FULL_CROP`) or
  `st_base`, one common knee-up height 0.38H, the knee line 0.1H under the ground line (the fog and the screen's edge
  hide the cut). Spots (`SPOTS`, from the door's centre): 에스텔 centre-front, then left-back / right-back ±0.11W,
  ±0.23W, ±0.32W. White cut-out offset (+0.022W, +0.014H), thin ink copy (−0.004W, +0.004H). Each breathes (3.4 s + i·0.3,
  sy ±0.007, y −2.5 px) and follows the pointer (front ±11 px, back ×0.7, cut-outs ×1.6; the hall ±4 px, the crowd ×1.4)
- the crowd: (rank − 1) × 3 nameless members, at most 18 (`crowd_n()`), paper cut-out figures (`_figure`: plain /
  pointed hat / hood / staff) in flat ink with a 2 px rim in its own hue (47° apart, s .7 v .95), three rows on the steps
  behind the people (0.18H / 0.158H / 0.136H tall), bobbing 1.2 px on their own phases
- fog: two soft bands behind the people (0.84H, 0.93H) and one in front (0.9H), the sky's pink whitened, drifting at
  7 / 11 / 5 px/s; at full strength while the steps are empty (one person), half once the seniors stand there
- the menu column from x = 0.089W: four slabs 0.19W × 0.052H ending at 0.96H, the motto at 0.082H

## Beats (ms)

1. **0–380** — **Pink band wipes in.** The field's two edge x's come from off the right with bez(.3,.6,.3,1); the dark halftone rides on it (uv-scrolled polygon). The black side already has its faint white halftone drifting.
2. **0–1200** — **Guide lines race.** Three thin white lines cross the black from the left; their first lap is the intro lap (fast, `mv`), afterwards each one travels, *stops on the logo* (line 1 across the logo's top, line 2 under it, line 3 above the motto) for ~900 ms and leaves with `in`.
3. **120–900** — **The hall springs in** from +0.5W right, rotated −3°, 1.06× (Spring resp .55 damp .72 → overshoots a little past its place and settles); its windows and sign ride on it. The crowd drops onto the steps from 700 (rows 90 ms apart, `bk`).
4. **900–** — **The people drop in** one by one 120 ms apart after the hall settles (Spring resp .5 damp .7 from 0.3H above, rotated −2°), each black (unlit) until 45 %, lit by 60 % (`kf`, like cx_slam); each one's **white cut-out follows** 80 ms late on a softer spring (resp .7 damp .55), swinging past and settling into its (+0.022W, +0.014H) offset. The thin ink copy is glued to the picture.
5. **420 / 510 / 600** — **Three paint splats pop** behind the logo's place (`burst.png` at 0.3 / 0.22 / 0.26 of the logo width, their own rotations, `bk` 260 ms each).
6. **650–1070** — **The logo lands** on its blob: both scale 1.25 → 1 with `bk` (a short overshoot), alpha in over the first 100 ms; the blob is 1.02× the logo's scale so it peeks out all round.
7. **1050** — the landing jolt (±3 px, 160 ms, `_logo_xf`) and the `slam` sfx.
10. **1250–1650** — **The motto fades** up; the **brush cursor and the menu slabs** slide in from the left (`bk`, 70 ms apart); the emblem fades in at 1300. `intro_done` at 1500 (a tap before that finishes the intro only, as before).
11. **settle** — **Never static, even on a first run (one person, one window):** halftone drifts (both fields, different speeds/directions); the field edge breathes ±6 px (7 s); the logo block breathes 1.0 ↔ 1.006 (4.2 s, cx_breath); the hall breathes 1.0 ↔ 1.004 (5.2 s), its sign swings ±2°, its windows and lanterns flicker like candles, its chimneys smoke; the blob rolls ±1° under the logo; the brush cursor pulses 1.0 ↔ 1.04; the people breathe on their own phases and follow the pointer/touch (parallax: front people ±11 px, cut-outs ×1.6, back ×0.7, crowd ×1.4, hall ±4 px, field ±4 px, on springs); fog bands drift across the steps; a few white specks drift up the pink; guide lines keep travelling and stopping; the menu's picked slab pulses.
12. **outro 0–480** — **시작.** The burst (`burst.png`) pops from the logo's centre, 0.2× → 2.4× over 350 ms (`out`), spinning −20°, fading from 60 %; the logo and its blob leave left (`in`, 280 ms), the menu drops, the hall (with its crowd) leaves right on its kicked spring, the people hop and leave right 40 ms apart (`in`, 480 ms) with their white cut-outs trailing (sp_sil kicked at 80 ms).
13. **outro 150–650** — **The pink field grows** — both edges sweep left with bez(.6,0,.9,.4) until it covers the screen (the dot drift eases to the select screen's fixed phase).
14. **outro 650–1050** — **The select screen's black shard** comes in from the left (`out` ease) and lands exactly on its select-mode place at 1050, when `_draw_select` takes over.
15. **1050–1600** — **Cards slide up** (bk, 70 ms stagger), CHOOSE YOUR HERO drops from above, 출격 rises, the hint fades. From 1600 on the select screen is pixel-identical to before.

Everything is draw calls and a handful of springs per frame: no per-pixel work, no textures beyond the two 11 px dot tiles
and the six title sprites in `assets/title/` (the hall at full size, the logo sprites halved from their sources).
