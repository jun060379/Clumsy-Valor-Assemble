# Title screen storyboard (scripts/title.gd, mode "title")

Persona-skin title as a **transparent overlay on the live guild town**: the brush logo on the left, the menu under it,
and behind them the town itself, running. The title is **music-driven**: every move below is a function of the title
track's clock (`scripts/beat.gd`, `music_t` seconds into `assets/bgm/title.ogg`), never a one-shot timer, so it
survives loops, tab switches and headless captures. Nothing is linear — the logo and the slabs use the `--bk`
overshoot (`UIA.ez("bk")`), the wedges use `mv` / `in`.

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

## The town under the title (arena.title_mode)

The world starts under the title as it always did (the saved scene, or the village street). While the title is up
(`arena.enter_title_mode`, left again on the hand-off): the arena keeps stepping the world's clock (`tod_h`), Eilin's
day, and the level (the town's life: weather, lamps and lit windows by the real hour, the horse, the cat, the
townsfolk) — but not the player: she is hidden, parked off-world, and the HUD and touch controls are off. Every
recruited member except the hero lives in town as a townsperson for the duration (`townsfolk.gd` title_mode: the party
too, leaning toward the hall's front and the bench / street / lamp spots; their word chats and solo lines rest). A
first run is Eilin's town alone. Input goes to the menu only.

**Passing greetings** (`townsfolk._greets`): when two walkers — a member and a member, or a member and Eilin on her
way through town — come within 60 px on the same route and neither is busy, and their pair has rested 20 s, both stop
for 1.2 s, turn to face each other and show an emote bubble ("…", "♪", "!" — symbols only; the townsfolk's cream
bubble, Eilin's own dark one). Members go on along their path afterwards; Eilin's `wait` holds her for the moment.

**The camera** (`arena.cam_override`, applied by the arena under the title; `snap_camera` on the hand-off): three
framings measured from town.gd's layout —
- **F1 본관 정면**: centre (HXB + 330, TTOP − 160): the hall's door a little right of centre, its terrace at ~0.82 H,
  the roof cropped at the top at 900×500, whole at 1087×500.
- **F2 언덕 길**: centre (SX1 + 230, TTOP − 100): the lamp-lit slope up to the terrace with the hall's left half (and
  its sign) in frame. (No zoom: the background parallax and the lighting are screen-space, so the camera just sits
  further left instead.)
- **F3 거리**: centre (HDOOR − 40, LOWF − 190): the lower plaza under the hill — the fountain, the benches, the
  planters, the light strings — where the townsfolk gather.
Inside a framing the camera drifts 40 px (one slow sine across the section) with a 6 px vertical sway. Section A rides
F1, B F2, C F3, D F2, the outro F1 again; the framing switches once each section's wedge has covered the screen.

## Composition (fractions of the viewport)

- a soft ink gradient (alpha 0.8 at the left edge → 0 at 0.42W, the paper halftone riding it) so cream and pink read on
  a bright day sky; no pink field, no hard diagonal
- the logo (`assets/title/logo.png`): the left column, 0.4W wide from (0.04W, 0.1H) (capped at 0.54H tall), on its
  plum blob (`blob.png`, 1.15× the logo, rolling ±1° over 6.4 s); the motto small above it at 0.082H; a 4 px pointer
  parallax on the block
- the menu: four slabs 0.19W × 0.052H ending at 0.96H from x = 0.089W; the picked row has no slab — it rides the brush
  stroke (`brush.png`, 1.3× the slab width, 2.3× its height) that slides between rows on `sp_cur` (resp .3 damp .8),
  its label white with an ink shadow on the stroke's thick middle. The guild's flower (`emblem.png`) stands small
  (0.16H) at the top right of the menu column
- the title's beat pulses stay only on the cursor (±2 % on the pulse) and the logo (1.0 ↔ 1.02 on the bar in section D)

## Gate (the web only, before the track has started)

Ink-black with the paper halftone, the flower small in the centre pulsing 1.0 ↔ 1.04 on a 1.3 s cycle, "터치하여 시작"
in small cream letters under it. The first tap/key starts title.ogg from 0 and the timeline. On the desktop the title
goes live at once. The loop never returns to the gate.

## Section A — "모인다" (music seconds)

1. **0.09 → 0.42** — **The ink gradient fades in** on the left; the camera waits 60 px left of F1.
2. **0.42 / 0.75 / 1.07** — **Three paint splats pop** behind the logo's spot, one per beat (`burst.png` at 0.3 / 0.22 / 0.26 of the logo width, own rotations, `bk` 260 ms each).
3. **1.00 → 1.39** — **The logo and its blob land** (bar 2) from 1.25× with `bk`; they land 2° over-rotated and settle in 150 ms (the clumsy touch); the slam jolt (±3 px, 160 ms) and the `slam` sfx on 1.39; a white slash crosses the screen. The motto fades in by bar 3 (2.69).
4. **2.63 → 3.23** — **The camera settles into F1** from 60 px further left (`out`, 600 ms).
5. **6.43 / 7.08 / 7.08 / 7.41** — **The menu rows slide in** one per beat (`bk` 400 ms); 불러오기 arrives one beat late and gets a second 0.01W push on the beat after (the tag that takes two stamps). The picked row is a plain slab until the brush arrives. Once in, the menu never leaves — laps included.
6. **9.22** — **The brush cursor slaps onto 시작** (1.3× → 1, `bk` 250 ms), the flower pops at the menu corner. `intro_done` (a tap before it settles everything of the intro at once; the music plays on).
7. **9.2 → 45.6 — steady A.** The town lives: the day turns, the townsfolk stroll and greet, the cursor pulses on the pulse, the blob rolls, the camera drifts.

## Sections B, C, D (bars 35, 65, 91) — the wedges

- **The wedge**: an ink band slanted like the old field (1.6W wide) sweeps left → right, its leading edge crossing the screen in 260 ms (`mv`) with a burst (0.5H; 0.9H at bar 91, the biggest) riding on it; the camera's framing switches when it covers the screen, and the band's trailing edge uncovers the new view over the next 260 ms. The wedge is the only transition.
- **B (45.6 s)** → F2 언덕 길. **C (84.6 s)** → F3 거리. **D (118.4 s)** → F2 again, with a burst behind the logo on every phrase downbeat (bars 91, 99, 107) and the logo pulsing 1.0 ↔ 1.02 on the bar.

## Outro (bar 115, 149.6 s → 164.44)

- The wedge once more, **back to F1**; the logo's pulse stops; the cursor keeps breathing; the sky is whatever the hour makes it.
- **163.1 →** an ink wedge sweeps in from the right (`in`, 1.34 s) and covers the screen exactly at the wrap.

## Loop (164.44 → 0.09)

- Behind the wedge section A resets; the band keeps moving left and uncovers the town over the first 260 ms. The splats, the logo landing and the camera's pull-in replay; the menu rows do not re-enter (the menu never leaves). No gate on the loop. A tap's skip is cleared at the wrap so the replay runs.

## 시작 and the outro (wall clock, any section)

- **outro 0–480** — the burst (`burst.png`) pops from the logo's centre, 0.2× → 2.4× over 350 ms (`out`), spinning −20°, fading from 60 %; the logo and its blob leave left (`in`, 280 ms), the menu drops, the gradient fades.
- **outro 150–650** — the pink field grows: both edges sweep in from the right with bez(.6,0,.9,.4) until it covers the screen.
- **650** — the menu sweep carries the pink on into the town; `_go` stops the music clock, leaves title mode (the hero back where she stood, her party hers, the camera snapped to her) and bgm.gd cross-fades title → town (the town from 0).
- The menu, the confirm card and the settings page work in every section; the town keeps living under the confirm card and the settings page.

Everything is draw calls and a few springs per frame (parallax, the cursor): no per-pixel work, no textures beyond the
two 11 px dot tiles and the five logo sprites in `assets/title/` (halved from their sources; the painted hall plate
stays in the folder, unused).
