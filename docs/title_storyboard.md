# Title screen storyboard (scripts/title.gd, mode "title")

Persona-skin title: black left / pink diagonal right, Estelle's `st_gear` cut-out on the right third, the logo block on the
left. Everything below runs on the title's real-time clock `t` (ms); nothing is linear — slabs use the `--bk` overshoot
(`UIA.p(…, "bk")`), the picture and its silhouette are `UIA.Spring`s, the bars and lines use `mv` / `in` / `out`.
Secondary motion lags the primary (silhouette after picture, pink copy after letter, cursor-bar after the word).

Composition (fractions of the viewport, from the concept mock at 1800×1000):
- pink field: polygon (0.44W,0)–(W,0)–(W,H)–(0.64W,H); black everywhere else
- picture: 1.12H tall, left edge at W − 0.78·w, top at H − 0.98·h (cut by the right and bottom edges);
  white silhouette offset (+0.034W, +0.022H), thin black silhouette offset (−0.0055W, +0.006H)
- logo block from x = 0.067W: CLUMSY VALOR slab at y 0.13H (h 0.092H), 어설픈 at y 0.23H (BHS 0.23H), 용맹 at
  y 0.48H indented to 0.145W (BHS 0.25H), -ASSEMBLE- tag at (0.378W, 0.68H), tagline at 0.85H, 탭하여 입장 slab at 0.905H

## Beats (ms)

1. **0–380** — **Pink band wipes in.** The field's two edge x's come from off the right with bez(.3,.6,.3,1); the dark halftone rides on it (uv-scrolled polygon). The black side already has its faint white halftone drifting.
2. **0–1200** — **Guide lines race.** Three thin white lines cross the black from the left; their first lap is the intro lap (fast, `mv`), afterwards each one travels, *stops on the logo* (line 1 under the CLUMSY VALOR slab, line 2 along the 용맹 bar, line 3 above the tagline) for ~900 ms and leaves with `in`.
3. **120–900** — **Picture springs in** from +0.5W right, rotated −8°, 1.12× (Spring resp .55 damp .72 → overshoots ~6 % past its place and settles). It is black (unlit) until 45 %, lit by 60 % (`kf`, like cx_slam).
4. **220–1100** — **White cut-out follows.** The silhouette spring targets the same place 100 ms late with a softer spring (resp .75 damp .6), so it swings past the picture and settles into its (+34,+22) offset. The thin black copy is glued to the picture.
5. **380–800** — **CLUMSY VALOR slab slides in** from −0.4W with `bk`, rotation −9° → −2°, scale 1.15 → 1.
6. **520–1000** — **어설픈 drops letter by letter** (90 ms apart, 520 ms each, `bk`): from −0.16H, squash kf (sx .8/sy 1.3 → 1.08/.94 → 1). The pink offset copy lags: offset = rest + 0.06H·(1−u).
7. **700–1050** — **Pink bar** sweeps in from the left under 어설픈's lower third (`mv`), 60 ms behind the last letter.
8. **760–1240** — **용맹 drops** the same way, bigger; **white bar** from the right at 940.
9. **1050–1430** — **-ASSEMBLE- stamps**: scale 2.4 → 1, rotation −14° → −2°, `bk` 380 ms; a white slash (ui_char `_flash` idiom) crosses the screen at the stamp, the logo block jolts (±3 px, 160 ms), `slam` sfx.
10. **1250–1650** — **Tagline fades** up; **탭하여 입장 slab** slides in from the left (`bk`). `intro_done` at 1500 (a tap before that finishes the intro only, as before).
11. **settle** — **Never static:** halftone drifts (both fields, different speeds/directions); the field edge breathes ±6 px (7 s); the logo block breathes 1.0 ↔ 1.006 (4.2 s, cx_breath); a highlight runs across the letters glyph by glyph every 3.6 s; the picture sways and follows the pointer/touch (parallax: picture ±8 px, white cut-out ±14 px, field ±4 px, each on its own spring); a few white specks drift up the pink; guide lines keep travelling and stopping; the tap slab pulses 1.0 ↔ 1.05 (1.2 s ease-in-out).
12. **outro 0–320** — **Tap.** Logo slabs leave left (`in`, 40 ms stagger: CLUMSY VALOR, 어설픈, bar, 용맹, bar, tag), the tap slab drops, the picture leaves right with its silhouette trailing (springs kicked).
13. **outro 150–650** — **The pink field grows** — both edges sweep left with bez(.6,0,.9,.4) until it covers the screen (the dot drift eases to the select screen's fixed phase).
14. **outro 650–1050** — **The select screen's black shard** comes in from the left (`out` ease) and lands exactly on its select-mode place at 1050, when `_draw_select` takes over.
15. **1050–1600** — **Cards slide up** (bk, 70 ms stagger), CHOOSE YOUR HERO drops from above, 출격 rises, the hint fades. From 1600 on the select screen is pixel-identical to before.

Everything is draw calls and a handful of springs per frame: no per-pixel work, no new textures beyond the two 11 px dot tiles.
