# Title screen storyboard (scripts/title.gd, mode "title")

Persona-skin title: black left / pink diagonal right, the painted guild hall on the right with the members on its steps,
the brush logo on the left. The title grows with the save ("자라는 타이틀"): what stands in front of the hall depends on
it. The title is **music-driven**: every move below is a function of the title track's clock (`scripts/beat.gd`,
`music_t` seconds into `assets/bgm/title.ogg`), never a one-shot timer, so it survives loops, tab switches and headless
captures. Nothing is linear — the logo and the slabs use the `--bk` overshoot (`UIA.ez("bk")`), the bars and lines use
`mv` / `in` / `out`. Secondary motion lags the primary (cut-out 80 ms after the person, the blob with the logo).

## The track (beat.gd)

184.6 BPM taken as 92 BPM half-time: pulse 0.650 s, bar 1.3005 s, 8-bar phrase 10.40 s, the first downbeat at 0.09 s,
164.44 s long, looping straight back onto the hit at 0.09. Bar n starts at 0.09 + n·1.3005.
Sections: **A** bars 0–35 (0 → 45.6 s), **B** 35–65 (→ 84.6), **C** 65–91 (→ 118.4), **D** 91–115 (→ 149.6),
**outro** 115 → 164.44, then the loop. `beat.gd` exposes `music_t`, `bar()`, `bar_phase()`, `pulse_phase()`,
`beat_phase()`, `phrase()`, `section()`, `lap`, and `bump(phase)` (a short hop peaking on the beat).

The clock reads the stream's position (+ time since the last mix − output latency) while the stream is really moving;
otherwise (headless tests, 배경음 off, a dummy driver whose position sits at 0, the desktop before audio) a wall clock
started when the title went live carries the same timeline. `set_time` / `hold` jump and freeze it (captures, tests).

`bgm.gd` plays title.ogg on its own player while the title is up (the settings page over it included); on `_go` the
title track and the town cross-fade over 1.2 s and the town starts from 0. Both files sit at −14 LUFS, the BGM bus at
−1 dB. On the web the track can only start after the first tap: the gate.

## Composition (fractions of the viewport)

- pink field: polygon (0.44W,0)–(W,0)–(W,H)–(0.64W,H); black everywhere else. Section C: a thin band (0.70W / 0.88W)
  and the black tinted 30 % toward the sky colour
- the sky: the field takes its colour from the world clock (`arena.tod_h`, `SKY_K`): day #ff3d7f, dusk #c8246c
  (6:18 / 18:30), night #4a1740 — always in the pink family. The outro eases it back to the plain pink for the sweep.
- the hall plate (`assets/title/hall.png`, 1920×1088, the painted cottage; its row 1000 is the ground, the grass lies
  under it): A — its right edge 0.06W past the screen's (the bracket lantern hugs the edge), the building (rows
  90–1000) 0.74H tall or the plate 0.76W wide, whichever is smaller (1000×460 goes by height, 900×500 by width);
  C — 0.55 of that, centred on 0.68W, the ground at 0.80H. It keeps its own colours by day and is modulated toward a
  cool violet (0.5, 0.43, 0.72) by the night factor. The sign board on the left bracket (px 56,616 120×150 with its
  chains) is cut out of the plate (drawn in three regions around it) and hung from (116, 600), swinging ±2° (2.3 s).
- the light ladder (`lit_windows()` = min(7, restored facilities + 1)), in order: (1) the right wing's window —
  Eilin's, always; (2) the left window; (3) the lantern by the door; (4) the lantern on the right bracket; (5) warm
  light through the door's crack; (6) smoke from the left chimney; (7) smoke from the right. Windows are a warm fill
  (#ffcf7a) over the measured panes with a candle flicker (`LIT.fl` plus a hop on the 8ths) and a `UI.glow` halo;
  lanterns a warm dot with a wide halo; the crack a warm line with a halo; smoke five soft puffs per chimney
- the logo (`assets/title/logo.png`): the left column, 0.4W wide from (0.04W, 0.1H) (capped at 0.54H tall), on its
  plum blob (`blob.png`, 1.15× the logo, rolling ±1° over 6.4 s); the motto small above it at 0.082H. Section B docks
  it at 0.6× top-left (0.03W, 0.04H), motto hidden
- the menu: four slabs 0.19W × 0.052H ending at 0.96H from x = 0.089W; the picked row has no slab — it rides the brush
  stroke (`brush.png`, 1.3× the slab width, 2.3× its height) that slides between rows on `sp_cur` (resp .3 damp .8),
  its label white with an ink shadow on the stroke's thick middle. The guild's flower (`emblem.png`) stands small
  (0.16H) at the top right of the menu column
- the people: every member in `fame.rec` (에스텔 first, `people()`), `st_full` (cut to its knees, `FULL_CROP`) or
  `st_base`, one common knee-up height 0.38H (× the framing's scale), the knee line 0.1H under the ground line. Spots
  (`SPOTS`, from the door's centre): 에스텔 centre-front, then left-back / right-back ±0.12W, ±0.23W, ±0.32W. White
  cut-out offset (+0.022W, +0.014H), thin ink copy (−0.004W, +0.004H). Parallax: front ±11 px, back ×0.7, cut-outs
  ×1.6, crowd ×1.4, hall ±4 px, field ±4 px
- the crowd: (rank − 1) × 3 nameless members, at most 18 (`crowd_n()`), paper cut-out figures (`_figure`: plain /
  pointed hat / hood / staff) in flat ink with a 2 px rim in its own hue (47° apart, s .7 v .95), three rows on the
  steps behind the people (0.18H / 0.158H / 0.136H tall), bobbing 1.2 px on their own phases
- fog: two soft bands behind the people (0.84H, 0.93H) and one in front (0.9H), the sky's pink whitened, drifting at
  7 / 11 / 5 px/s; at full strength while the steps are empty (one person), half once the seniors stand there

## Gate (the web only, before the track has started)

Ink-black with the paper halftone, the flower small in the centre pulsing 1.0 ↔ 1.04 on a 1.3 s cycle, "터치하여 시작"
in small cream letters under it. The first tap/key starts title.ogg from 0 and the timeline. On the desktop the title
goes live at once. The loop never returns to the gate.

## Section A — "모인다" (music seconds)

1. **0.09 → 0.42** — **The pink field slashes in** from the right (bez(.3,.6,.3,1)); the halftone and the specks start drifting.
2. **0.42 / 0.75 / 1.07** — **Three paint splats pop** behind the logo's spot, one per beat (`burst.png` at 0.3 / 0.22 / 0.26 of the logo width, own rotations, `bk` 260 ms each).
3. **1.00 → 1.39** — **The logo and its blob land** (bar 2) from 1.25× with `bk`; they land 2° over-rotated and settle in 150 ms (the clumsy touch); the slam jolt (±3 px, 160 ms) and the `slam` sfx on 1.39; a white slash crosses the screen. The motto fades in by bar 3 (2.69).
4. **2.69 → 3.23** — **The hall springs in** from +0.5W right, rotated −3°, 1.06× (`bk`), landing on 3.23.
5. **4.11 / 4.76 / 5.41 …** — **The members drop in**, 에스텔 first, then one per pulse: each from 0.3H above over the beat before its landing (`bk`), black until 45 %, lit by 60 %; the white cut-out follows 80 ms late with a bouncier curve (`bk6`). The second member lands 0.03W short of her spot and shuffles the rest of the way in two small hops on the next two beats ("어설프게").
6. **6.43 / 7.08 / 7.08 / 7.41** — **The menu rows slide in** one per beat (`bk` 400 ms); 불러오기 arrives one beat late and gets a second 0.01W push on the beat after (the tag that takes two stamps). The picked row is a plain slab until the brush arrives. Once in, the menu never leaves — laps included.
7. **9.22** — **The brush cursor slaps onto 시작** (1.3× → 1, `bk` 250 ms), the flower pops at the menu corner, and from here **one light of the ladder comes on per bar** until the save's count is reached. `intro_done` (a tap before it settles everything of the intro at once; the music plays on).
8. **17.09 (bar 13)** — **The crowd arrives** P4G-style: for each silhouette a thin vertical line in its rim hue sprints in from the right edge along the ground (120 ms, `mv`), one per beat, stops at its spot and the figure unfolds from the line (scale x 0.05 → 1 in 120 ms, `bk`). Rank 1: no crowd — a single faint pale-pink line sprints to 아이다's empty spot, holds and fades (the first-run hint).
9. **17.1 → 45.6 — steady A.** The field's halftone breathes on the bar; the cursor pulses ±2 % on the pulse; the windows flicker on the 8ths; each person bobs 2 px on the pulse but on a different beat of the bar (deliberately out of step); fog, sign, smoke, hall breath (1.0 ↔ 1.004) and the blob's roll as always. Nothing ever stops.

## Section B (bar 35, 45.6 s) — the cut-ins

- **The wedge**: an ink band slanted at the field's angle (1.6W wide) sweeps left → right, its leading edge crossing the screen in 260 ms (`mv`) with a burst (0.5H) riding on it; the composition switches when it covers the screen (45.87), and the band's trailing edge uncovers the new frame over the next 260 ms. Behind it the hall and its people slide out right, the logo shrinks to 0.6× and docks top-left (motto hidden), the menu stays put.
- **The panel**: a slanted pink parallelogram over the right ~62 % (left edge 0.28W top → 0.48W bottom) with a 0.02W ink shadow; odd slots are ink with a pink rim. The current member's `st_full` (fallback `st_base`) 0.95H tall (0.72H for a knee-up picture), bottom at 1.02H, centred on 0.70W, in from the right on the switch (`bk` 450 ms, dark until it lands) with the white cut-out trailing 80 ms; the flower as a large watermark (alpha 0.14, ink on pink / pink on ink) behind the figure; the halftone drifting over the panel, the specks in front. The figure breathes sy ±0.007 on the pulse.
- **The name slab** (ink, cream `UI.bhs` name and a `UI.noto` role line, from ui_char.gd's SHEET) stamps at the panel's top-left in two hits: 0.85× at 90 % on the beat after the switch, 1.0× on the next (`bk` 120 ms each).
- **Every 8 bars** (45.6 / 56.0 / 66.4 / 76.8) the next slot: the wedge sweeps again, the panel colour alternates. Slots show 에스텔, then the rest of `rec`; after them, while there is room on the steps, the empty chair on every other slot (the members again in between). With 3 members: 에스텔 / 아이다 / 루체 / the empty chair. Empty save: 에스텔 / chair / 에스텔 / chair.
- **The empty chair**: a dashed cream outline of someone standing at the figure's height, a big brush "?" (cream over a pink copy), and a slab reading "아직 오지 않은 동료" (placeholder copy).

## Section C (bar 65, 84.6 s) — the village, wide

- The wedge again; the panel leaves; the hall comes back **small** (0.55 of A, the ground at 0.80H, centred on 0.68W), the pink field recedes to a thin band and the black takes the sky's tint; stars (the specks) twinkle over the whole sky at night; fog low; smoke if lit. The people and the crowd stand at the same proportional scale, all breathing. The logo returns to its A place at full size, the motto with it.
- **The crowd grows**: from the switch, one more silhouette sprints in per bar until the rank's count.
- **Bar 80** (104.1 s): two tiny ink figures walk along the ground from the far right to the door over 6 s, 0.45 s apart, and go in; the door lantern brightens as each passes (visual only, nothing saved). The quiet section: big slow moves only.

## Section D (bar 91, 118.4 s) — ASSEMBLE

- The wedge with **the biggest burst** (0.9H on its leading edge); back to the A framing but louder: on every phrase downbeat (bars 91, 99, 107) a burst pops behind the logo (0.3 → 1.6 of its width over 400 ms, fading); the people hop **in unison** on the bar, 4 px; the crowd's rims brighten, thicken and pulse on the bar; the pink field's halftone drift doubles; the logo pulses 1.0 ↔ 1.02 on the bar; the lit windows flare on the bar. Hall and sign as in A.

## Outro (bar 115, 149.6 s → 164.44)

- Everything settles: the pulses stop one by one over the first bars (the logo at 115, the crowd at 116, the people at 117 — back out of step), the fog rises 0.03H over six seconds, the cursor keeps breathing, the sky does not change.
- **163.1 →** an ink wedge sweeps in from the right (`in`, 1.34 s) and covers the screen exactly at the wrap.

## Loop (164.44 → 0.09)

- Behind the wedge the A composition resets; the band keeps moving left and uncovers the intro over the first 260 ms. Bars 1–13 replay, shortened: the hall is already there and just lands with a 1.03 bump on 3.23; the splats and the logo land again; the people re-drop; the crowd re-sprints at 17.09; the lights stay on; the menu rows do not re-enter (the menu never leaves). No gate on the loop. A tap's skip is cleared at the wrap so the replay runs.

## 시작 and the outro (wall clock, any section)

- **outro 0–480** — the burst (`burst.png`) pops from the logo's centre, 0.2× → 2.4× over 350 ms (`out`), spinning −20°, fading from 60 %; the logo and its blob leave left (`in`, 280 ms), the menu drops, the hall (with its crowd) or the cut-in panel leaves right, the people hop and leave right 40 ms apart (`in`, 480 ms) with their white cut-outs trailing (sp_sil kicked at 80 ms).
- **outro 150–650** — the pink field grows: both edges sweep left with bez(.6,0,.9,.4) until it covers the screen.
- **650** — the menu sweep carries the pink on into the town; `_go` stops the music clock and bgm.gd cross-fades title → town (the town from 0).
- The menu, the confirm card and the settings page work in every section; the scene keeps running under the confirm card.

Everything is draw calls and a few springs per frame (parallax, the cursor, the outro's cut-outs): no per-pixel work,
no textures beyond the two 11 px dot tiles and the six title sprites in `assets/title/` (the hall at full size, the
logo sprites halved from their sources).
