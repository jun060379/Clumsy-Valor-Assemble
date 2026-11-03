# Title screen storyboard (scripts/title.gd, mode "title")

Persona-skin title as a **transparent overlay on the live guild town**: the brush logo top-left, four ink slabs on a
pink rail under it, and behind them the town itself, running. The title is **music-driven**: every move below is a
function of the title track's clock (`scripts/beat.gd`, `music_t` seconds into `assets/bgm/title.ogg`), never a
one-shot timer, so it survives loops, tab switches and headless captures. Nothing is linear — the logo and the slabs
use the `--bk` overshoot (`UIA.ez("bk")`), the wedge uses `in`.

## The track (beat.gd)

184.6 BPM taken as 92 BPM half-time: pulse 0.650 s, bar 1.3005 s, 8-bar phrase 10.40 s, the first downbeat at 0.09 s,
164.44 s long, looping straight back onto the hit at 0.09. Bar n starts at 0.09 + n·1.3005. A 16th of the pulse is
0.1625 s. Sections (A 0–35 bars, B 35–65, C 65–91, D 91–115, outro 115 → end) no longer move the camera; D still
pulses the logo on the bar and pops a burst behind it on its phrase downbeats.

The clock reads the stream's position (+ time since the last mix − output latency) while the stream is really moving;
otherwise (headless tests, 배경음 off, a dummy driver, the desktop before audio) a wall clock started when the title went
live carries the same timeline. `set_time` / `hold` jump and freeze it (captures, tests).

`bgm.gd` plays title.ogg on its own player while the title is up (the settings page over it included); on `_go` the
title track and the town cross-fade over 1.2 s and the town starts from 0. On the web the track can only start after
the first tap: the gate.

## The town under the title (arena.title_mode)

The world wakes from the autosave under the title as it always did (or on the village street). While the title is up
(`arena.enter_title_mode`, left again on the hand-off): **the title always shows the town** — a save that woke in the
hall or on the training ground switches to the town for the backdrop (nothing is saved on the way: `_autosave` is a
no-op under the title; the scene is noted in `title_back`). On the hand-off the title leaves title mode without that
restore and loads the file the player picked (`ui_root.start_game(c, file)` → `arena.load_file`): the save comes back
whole — its scene (the hall, its floor, the spot she stood on; the training ground), party, clock, day — whichever of
the autosave or the three slots it is. A new game (no save anywhere) starts on the town as it stands.
The arena keeps stepping the world's clock (`tod_h`), Eilin's day, and the town's life (weather, lamps and lit windows
by the real hour, the horse, the cat, the townsfolk) — but not the player: her node is hidden and parked off-world, the
HUD and touch controls are off. **Every recruited member — the hero too — lives in town as a townsperson** for the
duration (`townsfolk.gd` title_mode: `folk()` is the whole roster; the hero's player node stands aside while a
townsfolk entry with her skin walks; on the hand-off `join_party` gives the party back), leaning toward the hall's
front and the bench / street / lamp spots (`TITLE_FAV`); their word chats and solo lines rest. A first run is 에스텔
and Eilin's town. Input goes to the menu only.

**The walkers' footing** (`townsfolk.gd` STRIDE / `title_gait`): the walk art decides the ground speed, not the other
way round. Each walker plays its own walk sheet (에스텔 초심's walk, 아이다 / 루체 their "walk", Eilin walkL), and each
sheet's natural speed is the planted sole's travel along the feet line (cell rows 334–340) per frame while it is down,
× 0.5 × the member's draw scale, at the entry's native frame time — measured on the sheets: 초심's 10-frame walk
(row 36) moves its sole ~9 cell px a 105 ms frame = **0.058 px/ms** (61 px a 1050 ms cycle), a short calm stride; the
original art's "walk" is its run row played slow, with two flight frames in eight: 에스텔 row 2 ≈ 0.19, **아이다 row 1
≈ 0.145** (~33 cell px a frame), **루체 row 1 ≈ 0.20** (~49) px/ms at 145 / 140 ms a frame. (The old figures — 0.067,
0.14, 0.13 — were off; 루체's by half, so she skated.) Under the title a walker moves at k × natural with its frames
played at k × their native rate, k = clamp(0.09 / natural, TITLE_PACE 0.62, 1.0): speed ÷ rate is always the sheet's
own stride speed, so the soles stay planted — 에스텔 strolls at her art's own 58 px/s and cadence, 아이다 at 90 px/s and
루체 at 124 px/s with their frames at 0.62. Eilin plays walkL at 0.7 of EIL_SPD (52 px/s) with its frames at 0.7, and
under the title never breaks into her trot (`hurry()` is false). A walker flips only when its way turns (no idle
about-face on arrival under the title). In play the street pace WALKSP still applies.

**Passing greetings** (`townsfolk._greets`): two walkers within 60 px on the same route, neither busy, their pair
rested 20 s — both stop 1.2 s, face each other and show an emote ("…", "♪", "!"); Eilin on her way through town too.

## The camera (arena.cam_override, applied by the arena under the title; `snap_camera` on the hand-off)

- **Home** — the hall's front: centre (HXB + 330, TTOP − 160): the door a little right of centre, the terrace at
  ~0.82 H, the roof cropped at the top at 900×500, whole at 1087×500.
- **The pull-in** — the camera waits 60 px left of home and eases onto it from the first hit (0.09, `out`), settled by
  3.23. It replays on every lap, behind the loop's wedge; nothing else of the intro does.
- **The follow** — after 10–18 s at home (`PICK_MIN..MAX`, the random seeded by the clock) the title picks a subject:
  someone walking with ≥ 280 px still to go, members before Eilin, never the one just followed while another
  qualifies. The camera eases toward them (a critically damped `_damp`, τ = 1.6 s, the subject's velocity fed forward
  so the pan runs at their pace without lag) and holds them at **0.42 W walking right / 0.58 W walking left**, their
  feet at 0.82 H (`_cam_y`: the terrace at home's height, the street and the lower plaza lower). When they stop the
  camera glides to a halt just ahead (`hold_at`) and holds 4–8 s, then picks the next one; with nobody walking for
  12 s it drifts back home over 3 s (a timed smoothstep, `RET_MS`; when home is further than 3 s allows at 140 px/s
  — the smoothstep's peak is 1.5× its mean — the drift takes 1.5·d / 140 s instead). Every move is an eased pan at **≤ 140 px/s** (`CAM_MAX`), clamped to the town's bounds as
  the normal camera is. Never a cut.
- **The wedge** stays only for the music's loop wrap (no framing change on it).

## Saves (save_game.gd)

The autosave `user://save.json` (every scene change, every 30 s, when the app is hidden) and three manual slots
`user://save_1.json` … `save_3.json` share one format; `save(p)` / `read(p)` take the file, `header(p)` reads a file's
summary (place, day, time, adventurer level, party, timestamp) without touching the world, `newest()` the most recent
file. The snapshot carries `where` (the place where it was really made: a cave save still loads at the sortie wagon,
but its header says 동굴 · the room) and `day` (`arena.day_n`, +1 each time the world clock passes midnight).
**In game, the hub's 저장** (menu.gd, between 적 도감 and 설정) opens the same card over the hub: 슬롯 1·2·3 with their
headers; an empty slot is written at once, a filled one asks "슬롯 N에 덮어쓸까요?" (덮어쓰기 / 취소, 취소 picked);
writing plays `ui_ok`, closes the card and shows "슬롯 N에 저장했어요" (placeholder line). Allowed in the town, the hall and
the training ground; in a dungeon the entry is greyed, its info line and a tap say "던전에서는 저장할 수 없어요"
(placeholder). Test runs use `save_test.json` and `save_test_N.json`.

## Composition (fractions of the viewport)

- a soft ink gradient (alpha 0.8 at the left edge → 0 at 0.46 W, the paper halftone riding it) so cream and pink read
  on a bright day sky
- the logo (`assets/title/logo.png`): 0.36 W wide from (0.04 W, 0.08 H), capped at 0.44 H tall (the cap bites at
  1087×500), on its plum blob (`blob.png`, 1.15× the logo, rolling ±1° over 6.4 s); the motto small above it at
  0.065 H; a 4 px pointer parallax on the block
- **the menu**: a column at x = 0.06 W, the first slab's top at 0.56 H, four rows 0.088 H apart. Each slab an ink
  parallelogram 0.30 W × 0.072 H leaning −8° (the top edge shifted right by h·tan 8°), a 3 px pink rim on its left
  edge, a hard pink drop shadow at (4, 4) px; a small Anton index "01"–"04" in pink at the left, the Korean label
  (시작 / 불러오기 / 설정 / 끝내기) in `UI.bhs` at 0.038 H cream, an Anton caption (START / LOAD / CONFIG / QUIT) at
  0.018 H in pink-grey, letter-spaced, at the right. A 2 px pink rail runs down the slabs' left edges at the same lean,
  from the logo's bottom-left to under the last slab. **Picked**: the slab slides right 0.014 W, its fill flips to pink
  with ink text, the brush stroke (`brush.png`, 1.25× the slab's width) sits behind it pulsing ±2 % on the pulse, a
  cream underline sweeps across the label over 180 ms; the others sit at 80 % alpha. **Press**: the slab squashes to
  0.96 over 40 ms and springs back (`bk`) on the release. **Disabled** (불러오기 with no save): ink at 45 %, caption
  NO SAVE, a tap gives the soft "step". The guild's flower (`emblem.png`, 0.15 H) stands to the right of the first slab,
  clear of the brush's overhang.
- the beat pulses stay only on the cursor (±2 % on the pulse) and the logo (1.0 ↔ 1.02 on the bar in section D)

## Gate (the web only, before the track has started)

Ink-black with the paper halftone, the flower small in the centre pulsing 1.0 ↔ 1.04 on a 1.3 s cycle, "터치하여 시작 ·
전체 화면" in small cream letters under it. The first tap/key starts title.ogg from 0 and the timeline (the release of
that tap asks the browser for fullscreen). On the desktop the title goes live at once. The loop never returns to the gate.

## The intro — "따다닥" (music seconds)

1. **0.09 → 0.42** — **The ink gradient fades in**; the camera's pull-in starts.
2. **0.42** — **The logo and its blob slam down** (from 1.25× with `bk` over the 0.33 s before, alpha in over 80 ms),
   2° over-rotated and settling in 150 ms (the clumsy touch), a burst popping behind them (0.3 → 1.5 of the logo's
   width over 400 ms, fading), the slam jolt (±3 px, 160 ms), the `slam` sfx, a white slash across the screen.
3. **1.07 / 1.23 / 1.39 / 1.55** — four consecutive 16ths (T0 + 3 beats + k·0.1625): **the four slabs slam in** from
   the left (−0.3 W, `bk` over the 140 ms before, rotating in from −6°) and land exactly on their 16th, a `ui_move`
   click and a tiny ink splat at each landing; the second slab overshoots 0.01 W over the next 16th and settles (the
   tag that takes two stamps).
4. **1.72** — **the brush cursor slaps onto 시작** (1.3× → 1, `bk` over the 120 ms before, landing on 1.72 with
   `ui_ok`). The picked slab is a plain ink slab until the brush arrives.
5. **2.11** — the motto fades in. **2.76** — the flower pops (`bk`). **3.23** — the pull-in has settled.
   `intro_done` at 3.1: a tap anywhere before it settles everything at once (the sounds not played); past it, taps
   are the menu's. Nothing else waits.
6. **steady** — the town lives; the camera starts following its walkers after 10–18 s; the cursor pulses; the blob rolls.

## Loop (164.44 → 0.09)

- **163.1 →** an ink wedge sweeps in from the right (`in`, 1.34 s) and covers the screen exactly at the wrap; it
  uncovers the town over the first 0.26 s of the next lap. Behind it the camera is back 60 px left of the hall and the
  pull-in replays; the logo and the menu stay (the menu never re-enters). No gate on the loop. A tap's skip is cleared
  at the wrap so the pull-in runs.

## Input, the cards, the pick (wall clock)

- **A tap counts on the release inside the same slab it was pressed on.** A press on a slab squashes it and moves the
  selection to it; a release elsewhere cancels; taps outside the slabs do nothing (once the intro is in — during it a
  tap only finishes it). The pad / the keyboard: ↑↓ move the selection (`ui_move`), Enter / A pick (the same
  squash-and-spring), Esc / B close a card.
- **시작 = continue.** With the autosave it goes straight to the pick's feedback and loads it on the hand-off (no card);
  without one but with a slot it continues the newest slot (`save_game.newest`); with no save at all it opens a card
  beside the menu: "새로운 이야기를 시작합니다" (시작 / 취소, 시작 picked) — 시작 there starts a new game. Nothing ever
  warns about a save being wiped any more (a new game is only offered when there is none).
- **불러오기** opens the slot card (`slot_card.gd`, shared with the hub's 저장): 자동 저장 and 슬롯 1·2·3, each row the
  file's header — the place (마을 / 본관 N층 / 훈련장 / 동굴 · the room), the in-game day and time ("3일째 17:30"), the
  adventurer level (LV), the party's names and the real timestamp; an empty row is greyed "비어 있음" and passed over
  (↑↓ skip it, a tap on it does nothing); 닫기 / Esc close it. A row counts on the release inside it; picking one
  closes the card and runs the pick's feedback on 불러오기, then that file is loaded. With nothing to load the slab sits
  at 45 % with NO SAVE and a tap gives the soft "step". **설정** opens the settings page; **끝내기** quits.
- **The pick's feedback** (`_commit`, 450 ms before the outro): the chosen slab slams (0.9 → 1.07 → 1 over 300 ms), a
  burst pops on it, `ui_ok` plays, the other slabs drop out of frame downwards 60 ms apart (from 70 ms, `in`, 300 ms);
  input is ignored meanwhile. The keyboard / pad get the same squash-and-spring and feedback.
- **The outro** (`_begin`, from 450 ms): the burst (`burst.png`) pops from the logo's centre, 0.2× → 2.4× over 350 ms
  (`out`), spinning −20°, fading from 60 %; the logo and its blob leave left (`in`, 280 ms), the picked slab drops,
  the gradient fades; **150–650** the pink field grows over the screen from the right (bez(.6,0,.9,.4)); **650** the
  menu sweep carries the pink on into the town; `_go` stops the music clock, leaves title mode (the hero's townsfolk entry hands her back to her node, her party
  hers), loads the file picked (`ui_root.start_game(c, file)` → `arena.load_file`: its scene, where she stood, the camera
  snapped to her) or starts the new game, and bgm.gd cross-fades title → town.
- The settings page over the title keeps the town living and the title track playing.

Everything is draw calls and a few springs per frame (parallax, the cursor, the camera's damp): no per-pixel work, no
textures beyond the two 11 px dot tiles and the five logo sprites in `assets/title/` (halved from their sources; the
painted hall plate stays in the folder, unused).
