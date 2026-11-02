# Title screen storyboard (scripts/title.gd, mode "title")

Persona-skin title: black left / pink diagonal right, the guild hall's front on the right with the members on its steps,
the logo block on the left. The title grows with the save ("자라는 타이틀"): what stands in front of the hall depends on it. Everything below runs on the title's real-time clock `t` (ms); nothing is linear — slabs use the `--bk` overshoot
(`UIA.p(…, "bk")`), the hall, the people and their silhouettes are `UIA.Spring`s, the bars and lines use `mv` / `in` / `out`.
Secondary motion lags the primary (silhouette after person, pink copy after letter, cursor-bar after the word).

Composition (fractions of the viewport, from the concept mock at 1800×1000):
- pink field: polygon (0.44W,0)–(W,0)–(W,H)–(0.64W,H); black everywhere else
- the hall plate (`assets/town/g_hall.png`, a stand-in until the painted plate comes): right-aligned at 0.985W, its foot
  on the ground line 0.86H, 0.78H tall (or 0.6W wide, whichever is smaller — 1000×460 goes by height, 900×500 by width);
  drawn with modulate `HALL_TINT` (0.35, 0.3, 0.4), darker at night (0.2, 0.17, 0.27): an ink cut-out with faint detail
  behind the pink. The sign (sprite px 253,275 142×30) is redrawn on top at 1.06× hung from its top centre, swinging ±2°
  (2.3 s). The windows (`g_hall_win`, 22×24 px rects, `WINS`) are lit one per restored facility (`fame.fac`) plus
  Eilin's (the right wing's upper window, always), in a fixed order, each a candle (`LIT.fl` flicker) with a soft glow
- the sky: the pink field takes its colour from the world clock (`arena.tod_h`, `SKY_K`): day #ff3d7f, dusk #c8246c
  (6:18 / 18:30), night #4a1740 — always in the pink family. The outro eases it back to the plain pink for the sweep.
- the people: every member in `fame.rec` (에스텔 first, `people()`), `st_full` (cut to its knees, `FULL_CROP`) or
  `st_base`, one common knee-up height 0.46H, the knee line 0.1H under the ground line (the fog and the screen's edge
  hide the cut). Spots (`SPOTS`, from the door's centre): 에스텔 centre-front, then left-back / right-back ±0.11W,
  ±0.23W, ±0.32W. White cut-out offset (+0.022W, +0.014H), thin ink copy (−0.004W, +0.004H). Each breathes (3.4 s + i·0.3,
  sy ±0.007, y −2.5 px) and follows the pointer (front ±11 px, back ×0.7, cut-outs ×1.6; the hall ±4 px, the crowd ×1.4)
- the crowd: (rank − 1) × 3 nameless members, at most 18 (`crowd_n()`), paper cut-out figures (`_figure`: plain /
  pointed hat / hood / staff) in flat ink with a 2 px rim in its own hue (47° apart, s .7 v .95), three rows on the steps
  behind the people (0.21H / 0.185H / 0.16H tall), bobbing 1.2 px on their own phases
- fog: two soft bands behind the people (0.84H, 0.93H) and one in front (0.9H), the sky's pink whitened, drifting at
  7 / 11 / 5 px/s; at full strength while the steps are empty (one person), half once the seniors stand there
- logo block from x = 0.067W: CLUMSY VALOR slab at y 0.13H (h 0.092H), 어설픈 at y 0.23H (BHS 0.23H), 용맹 at
  y 0.48H indented to 0.145W (BHS 0.25H), -ASSEMBLE- tag at (0.378W, 0.68H), tagline at 0.85H, 탭하여 입장 slab at 0.905H

## Beats (ms)

1. **0–380** — **Pink band wipes in.** The field's two edge x's come from off the right with bez(.3,.6,.3,1); the dark halftone rides on it (uv-scrolled polygon). The black side already has its faint white halftone drifting.
2. **0–1200** — **Guide lines race.** Three thin white lines cross the black from the left; their first lap is the intro lap (fast, `mv`), afterwards each one travels, *stops on the logo* (line 1 under the CLUMSY VALOR slab, line 2 along the 용맹 bar, line 3 above the tagline) for ~900 ms and leaves with `in`.
3. **120–900** — **The hall springs in** from +0.5W right, rotated −3°, 1.06× (Spring resp .55 damp .72 → overshoots a little past its place and settles); its windows and sign ride on it. The crowd drops onto the steps from 700 (rows 90 ms apart, `bk`).
4. **900–** — **The people drop in** one by one 120 ms apart after the hall settles (Spring resp .5 damp .7 from 0.3H above, rotated −2°), each black (unlit) until 45 %, lit by 60 % (`kf`, like cx_slam); each one's **white cut-out follows** 80 ms late on a softer spring (resp .7 damp .55), swinging past and settling into its (+0.022W, +0.014H) offset. The thin ink copy is glued to the picture.
5. **380–800** — **CLUMSY VALOR slab slides in** from −0.4W with `bk`, rotation −9° → −2°, scale 1.15 → 1.
6. **520–1000** — **어설픈 drops letter by letter** (90 ms apart, 520 ms each, `bk`): from −0.16H, squash kf (sx .8/sy 1.3 → 1.08/.94 → 1). The pink offset copy lags: offset = rest + 0.06H·(1−u).
7. **700–1050** — **Pink bar** sweeps in from the left under 어설픈's lower third (`mv`), 60 ms behind the last letter.
8. **760–1240** — **용맹 drops** the same way, bigger; **white bar** from the right at 940.
9. **1050–1430** — **-ASSEMBLE- stamps**: scale 2.4 → 1, rotation −14° → −2°, `bk` 380 ms; a white slash (ui_char `_flash` idiom) crosses the screen at the stamp, the logo block jolts (±3 px, 160 ms), `slam` sfx.
10. **1250–1650** — **Tagline fades** up; **탭하여 입장 slab** slides in from the left (`bk`). `intro_done` at 1500 (a tap before that finishes the intro only, as before).
11. **settle** — **Never static, even on a first run (one person, one window):** halftone drifts (both fields, different speeds/directions); the field edge breathes ±6 px (7 s); the logo block breathes 1.0 ↔ 1.006 (4.2 s, cx_breath); a highlight runs across the letters glyph by glyph every 3.6 s; the hall breathes 1.0 ↔ 1.004 (5.2 s), its sign swings ±2°, its windows flicker like candles; the people breathe on their own phases and follow the pointer/touch (parallax: front people ±11 px, cut-outs ×1.6, back ×0.7, crowd ×1.4, hall ±4 px, field ±4 px, on springs); fog bands drift across the steps; a few white specks drift up the pink; guide lines keep travelling and stopping; the menu's picked slab pulses.
12. **outro 0–480** — **Tap.** Logo slabs leave left (`in`, 40 ms stagger: CLUMSY VALOR, 어설픈, bar, 용맹, bar, tag), the menu drops, the hall (with its crowd) leaves right on its kicked spring, the people hop and leave right 40 ms apart (`in`, 480 ms) with their white cut-outs trailing (sp_sil kicked at 80 ms).
13. **outro 150–650** — **The pink field grows** — both edges sweep left with bez(.6,0,.9,.4) until it covers the screen (the dot drift eases to the select screen's fixed phase).
14. **outro 650–1050** — **The select screen's black shard** comes in from the left (`out` ease) and lands exactly on its select-mode place at 1050, when `_draw_select` takes over.
15. **1050–1600** — **Cards slide up** (bk, 70 ms stagger), CHOOSE YOUR HERO drops from above, 출격 rises, the hint fades. From 1600 on the select screen is pixel-identical to before.

Everything is draw calls and a handful of springs per frame: no per-pixel work, no new textures beyond the two 11 px dot tiles
and the hall sprites. The painted hall plate, when it comes, replaces `HALL` / `HALL_WIN` and the px constants (`WINS`, `SIGN`, `DOOR_X`).
