extends Control
## Title (prototype #title) in the persona skin, as a transparent overlay on the live guild town; the hero select is
## gone (a fresh game is 에스텔 alone, the seniors join in play). docs/title_storyboard.md has the whole timeline.
## The title is music-driven: every move is a function of the title track's clock (beat.gd, `mt` seconds into
## assets/bgm/title.ogg, looping), never a one-shot timer, so it survives loops, tab switches and headless captures.
##
## The backdrop is the town itself, running (arena.title_mode — always the town, whatever scene the save woke in):
## its real clock and weather, Eilin on her day, every recruited member — the hero too — out in town as a townsperson
## for the title's duration, strolling at the pace their walk art plants its feet at, with passing greetings; the player
## node stands aside and the HUD is off. The title drives the camera (arena.cam_override): it opens on the hall's front
## with a short pull-in, then every so often picks someone who is walking and follows them at their pace, settles when
## they stop, and drifts back to the hall when nobody walks — never a cut, every move an eased pan.
## Over it: a soft ink gradient down the left, the brush logo on its blob, the motto, the flower and the menu — four
## ink slabs on a pink rail, the picked one pink on the brush stroke. The intro lands on the track's first hits: the
## logo on 0.42, the slabs on four consecutive 16ths from 1.07, the cursor on 1.72, the motto and the flower after.
## A slab counts on the release inside it; 시작 asks first (a card); the pick slams, the others drop, then the outro:
## the burst from the logo, the pink field grows over the screen and the sweep carries it into the game.
##
## Layers: this Control draws the gradient (and the gate, and the outro's pink field); `fg` draws the logo, the
## menu, the card, the bursts and the loop's wedge with linear filtering.

const UI := preload("res://scripts/ui_kit.gd")
const DEV := preload("res://scripts/dev.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const BEAT := preload("res://scripts/beat.gd")
const PINK := Color("#ff3d7f")
const INK := Color("#0d0b10")
const CREAM := Color("#f3e9d2")
const ROSE := Color("#c48aa0")       # the captions: pink-grey
const LOGO := preload("res://assets/title/logo.png")      # Clumsy Valor / 어설픈 용맹 / Assemble, brush
const BLOB := preload("res://assets/title/blob.png")      # the plum blob the logo lands on
const BRUSH := preload("res://assets/title/brush.png")    # the menu cursor
const BURST := preload("res://assets/title/burst.png")    # the bursts and splats
const EMBLEM := preload("res://assets/title/emblem.png")  # the guild's flower
const GRAD_W := 0.46                 # the ink gradient's reach from the left edge (fraction of W)
const GRAD_A := 0.8                  # its strength at the edge
## the hall's front (the opening framing, and the camera's home): x from the hall's left edge, y from its terrace
## (town.gd HXB / TTOP) — the door a little right of centre, the terrace at ~0.82 H
const HOME := Vector2(330.0, -160.0)
const PULL_IN := 60.0                # the intro: the camera settles onto the hall's front from this much further left, by 3.23
## the follow camera: the subject held at 0.42 W walking right / 0.58 W walking left; a critically damped ease with
## this time constant (s), panning no faster than CAM_MAX px/s; a new subject every PICK_MIN..PICK_MAX s, one who has
## at least SUBJ_PATH px still to walk; after the subject stops the camera holds HOLD_MIN..HOLD_MAX s; with nobody
## walking for IDLE_HOME s it drifts back to the hall
const CAM_OFF := 0.08
const CAM_TAU := 1.6
const CAM_MAX := 140.0
const PICK_MIN := 10000.0
const PICK_MAX := 18000.0
const SUBJ_PATH := 280.0
const HOLD_MIN := 4000.0
const HOLD_MAX := 8000.0
const IDLE_HOME := 12000.0
## the menu column: slabs 0.30 W × 0.072 H leaning −8°, from (0.06 W, 0.56 H), 0.088 H apart
const MENU_X := 0.06
const MENU_Y := 0.56
const MENU_PITCH := 0.088
const SLAB_W := 0.30
const SLAB_H := 0.072
const SLAB_LEAN := 8.0               # degrees
const SLAB_SHIFT := 0.014            # the picked slab slides right this much (W)
const CAPTION := {"start": "START", "load": "LOAD", "opts": "CONFIG", "quit": "QUIT"}
const COMMIT_MS := 450.0             # the pick's feedback runs this long before the outro
const CARD_LINES := {"fresh": ["새로운 이야기를 시작합니다"], "wipe": ["저장된 진행이 있어요.", "지우고 처음부터 시작할까요?"]}
const CARD_BTNS := {"fresh": ["시작", "취소"], "wipe": ["새로 시작", "돌아가기"]}

## ---- the timeline (music seconds; beat.gd has the grid) ----
const T_FIELD := 0.09                # the gradient fades in (by 0.42); the camera's pull-in starts
const T_LOGO := 0.42                 # the logo and its blob slam down with a burst
const T_MENU := [BEAT.T0 + 3.0 * BEAT.BEAT, BEAT.T0 + 3.0 * BEAT.BEAT + BEAT.PULSE / 4.0, BEAT.T0 + 3.0 * BEAT.BEAT + BEAT.PULSE / 2.0, BEAT.T0 + 3.0 * BEAT.BEAT + 3.0 * BEAT.PULSE / 4.0]   # the slabs: four 16ths from 1.07
const T_CURSOR := BEAT.T0 + 3.0 * BEAT.BEAT + BEAT.PULSE     # 1.72: the brush slaps 시작
const T_MOTTO := 2.11
const T_EMBLEM := 2.76
const T_CAM := 3.23                  # the camera has settled onto the hall's front
const T_INTRO_END := 3.1             # a tap before this settles the intro at once; past it, taps are the menu's
const WEDGE := 0.26                  # s for the loop's wedge to uncover the screen after the wrap
const LOOP_WEDGE := 1.34             # s before the wrap the loop's wedge starts from the right

var arena
var ui_root
var active := true
var beat := BEAT.new()           # the music clock
var mt := 0.0                    # beat.music_t, cached each frame (s)
var sec := "A"                   # the section mt is in
var gate := false                # the quiet gate before the first tap (the web: audio needs the gesture)
var fs_want := false             # the gate was tapped: ask for fullscreen on the tap's release (web)
var skip := false                # a tap during the intro: its moves settle at once
var menu_in := false             # the menu rows have entered (they never leave, laps included)
var intro_done := false
var fired := {}                  # the intro's sounds already played (name -> true)
var outro := -1.0                # outro clock (ms), -1 = not running
var handed := false              # the sweep into the game has been started
var clock := 0.0                 # wall clock (ms): ambient motion, the menu's springs, the outro
var trn := UIA.Tr.new()
var fg_layer: Control
var sp_px := UIA.Spring.new(0.0, 0.9, 0.9)     # pointer parallax (the logo block)
var sp_py := UIA.Spring.new(0.0, 0.9, 0.9)
var sp_cur := UIA.Spring.new(0.0, 0.3, 0.8)    # the menu cursor's row (the brush slides between items)
var burst_t := -1.0                            # clock when 시작's burst popped (-1: none)
var wedge: Array = []            # the loop's ink wedge in flight: [leading edge x (fraction of W), dir]
## the camera
var cam_pos := Vector2.ZERO      # the camera centre the title asks for (town coordinates)
var cam_v := Vector2.ZERO        # its velocity (px/s)
var cam_home := Vector2.ZERO     # the hall's front, as last computed
var subject := ""                # who the camera follows: a member id, "eilin", or "" (home / holding)
var last_subject := ""           # the one before (never twice in a row if another qualifies)
var cam_phase := "home"          # "home" / "follow" / "hold"
var pick_t := 0.0                # ms until the next pick
var hold_t := 0.0                # ms left of the hold after a subject stopped
var hold_at := Vector2.ZERO      # where the camera glides to a stop for the hold
var idle_t := 0.0                # ms nobody has walked
var cam_lap := -1                # the lap the camera's pull-in was placed for
## the menu: 시작 · 불러오기 · 설정 · 끝내기 (no 끝내기 on the web, where a tab cannot close itself)
var items: Array = []            # [key, label]
var sel := 0
var sel_t := -1e9                # clock when the selection last moved (the underline sweep)
var item_rects: Array = []       # Rect2 per item, as last drawn (taps)
var press_k := -1                # the slab a press went down on (a tap counts on the release inside it)
var press_t := -1e9              # clock of that press (the squash)
var release_t := -1e9            # clock of its release (the spring back)
var release_k := -1
var commit_k := -1               # the slab that was picked: it slams, the others drop, then the outro
var commit_t := -1e9
var has_save := false
var confirm := false             # the 시작 card: "새로운 이야기" (no save) or "지우고 처음부터?" (over a save)
var confirm_kind := "fresh"      # "fresh" / "wipe"
var confirm_sel := 0
var confirm_rects: Array = []
var confirm_t := 0.0              # clock when the card opened
var press_c := -1                # the card button a press went down on
var fresh := false               # 시작 chosen over a save: the save goes and the scene reloads into a new game
var in_opts := false             # the settings page is open over the title
static var pending_fresh := false   # set across the reload: the new game starts without the title

## the title's clock is running (bgm.gd starts the track with it)
var live: bool:
	get: return beat.live


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	items = [["start", "시작"], ["load", "불러오기"], ["opts", "설정"]]
	if not OS.has_feature("web"): items.append(["quit", "끝내기"])
	gate = OS.has_feature("web")                  # the browser's audio waits for a gesture: so does the title
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED     # halftone tiles through polygon uvs
	fg_layer = Control.new()
	fg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fg_layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fg_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	fg_layer.draw.connect(_draw_fg)
	add_child(fg_layer)

## the title goes live: the timeline (and the track) start from 0
func go_live() -> void:
	gate = false
	skip = false
	menu_in = false
	intro_done = false
	fired = {}
	beat.start(0.0)
	_tick()
	cam_lap = -1
	_camera_reset()
	if arena != null and arena.bgm != null: arena.bgm.poke()

func _process(delta: float) -> void:
	if pending_fresh and arena != null and arena.world_started:
		# the reload after 시작: straight into the new game, no title
		pending_fresh = false
		active = false
		visible = false
		ui_root.start_game("estelle")
		return
	if in_opts:
		# the settings page over the title: the title waits (input off) until it closes
		if not ui_root.menu.is_open() and not ui_root.sweep.active:
			in_opts = false
			active = true
			visible = true
		return
	if not active:
		return
	if not has_save and arena != null and arena.save != null and FileAccess.file_exists(arena.save.path):
		has_save = true
	# the town under the title: once the world is up, it lives on as the backdrop
	if arena != null and arena.world_started and not arena.title_mode and outro < 0.0:
		arena.enter_title_mode()
	var dt := minf(delta * 1000.0, 250.0)   # real time, like the prototype's CSS / rAF clocks
	clock += dt
	trn.step(dt)
	if not gate and not beat.live and outro < 0.0:
		go_live()                            # the desktop: straight in
	# the music clock: the track's position while it really plays, else the wall clock
	var pos := -1.0
	if arena != null and arena.bgm != null: pos = arena.bgm.title_pos()
	beat.step(dt / 1000.0, pos)
	_tick()
	_cues()
	if commit_k >= 0 and outro < 0.0 and clock - commit_t >= COMMIT_MS:
		_begin()
	if outro >= 0.0:
		outro += dt
		# the field has swallowed the screen: the menu sweep carries the pink on into the town (no hero select —
		# a fresh game is 에스텔 alone, a saved one keeps its leader)
		if outro >= 650.0 and not handed:
			handed = true
			ui_root.sweep.run(func(): _go(), PINK)
	# parallax: the pointer (the last touch on a phone) as -1..1
	var vs := get_viewport_rect().size
	var mp := get_viewport().get_mouse_position()
	sp_px.to(clampf((mp.x / maxf(1.0, vs.x) - 0.5) * 2.0, -1.0, 1.0))
	sp_py.to(clampf((mp.y / maxf(1.0, vs.y) - 0.5) * 2.0, -1.0, 1.0))
	sp_px.step(dt)
	sp_py.step(dt)
	sp_cur.to(float(sel))
	sp_cur.step(dt)
	_camera(dt)
	queue_redraw()
	fg_layer.queue_redraw()

## everything the frame derives from the music clock: the section, the intro's state, the loop's wedge
func _tick() -> void:
	mt = beat.music_t
	sec = beat.section()
	if not intro_done and (skip or beat.lap >= 1 or (beat.live and mt >= T_INTRO_END)): intro_done = true
	if not menu_in and (skip or beat.lap >= 1 or (beat.live and mt >= T_INTRO_END)): menu_in = true
	# the loop's wedge: from the right at the end of the track, covering the screen exactly at the wrap and uncovering
	# the town over the first WEDGE s (the camera's pull-in replays behind it; the logo and the menu stay)
	wedge = []
	if beat.live:
		var tl := BEAT.LEN - LOOP_WEDGE
		if mt >= tl:
			wedge = [lerpf(1.3, -0.3, UIA.ez("in", (mt - tl) / LOOP_WEDGE)), -1]
		elif beat.lap >= 1 and mt < WEDGE:
			wedge = [lerpf(-0.3, -1.9, mt / WEDGE), -1]

## the intro's sounds, each once as its beat passes (the first lap only; a skipped intro plays none)
func _cues() -> void:
	if not beat.live or beat.lap >= 1 or skip or arena == null: return
	var cues: Array = [["slam", T_LOGO, "slam", 0.5]]
	for k in items.size():
		cues.append(["slab%d" % k, T_MENU[k] + 0.16, "ui_move", 0.5])
	cues.append(["cursor", T_CURSOR + 0.1, "ui_ok", 0.45])
	for c in cues:
		if fired.has(c[0]) or mt < c[1]: continue
		fired[c[0]] = true
		if mt < c[1] + 0.5: arena.sfx(c[2], c[3])

## progress (0..1, eased) of a music-timed move that starts at t0 (s) and lasts dur (s); the intro's moves are done at
## once after a tap skipped the intro, and stay done on later laps (only the camera's pull-in replays: _pull)
func mu(t0: float, dur: float, name = "bk") -> float:
	if (skip or beat.lap >= 1) and t0 <= T_CAM: return 1.0
	return UIA.ez(name, (mt - t0) / maxf(0.001, dur))

## the camera's pull-in onto the hall's front (0..1): from the first hit, settled by T_CAM, every lap
func _pull() -> float:
	if skip: return 1.0
	return UIA.ez("out", (mt - T_FIELD) / (T_CAM - T_FIELD))

## the current section for a time (tests)
func section_at(t: float) -> String:
	return BEAT.section_at(t)


# ---------- the camera ----------
## the town under the title (null elsewhere)
func _town():
	if arena == null or not arena.title_mode or arena.level == null or String(arena.level.kind) != "town": return null
	return arena.level

## the hall's front, the camera's home (town coordinates)
func _home() -> Vector2:
	var L = _town()
	if L == null: return cam_home
	return Vector2(L.HXB + HOME.x, L.TTOP + HOME.y)

## the camera's y for someone standing at world y: their feet at 0.82 H, as the hall's front has its terrace
func _cam_y(sy: float) -> float:
	return sy - 0.32 * get_viewport_rect().size.y

## the intro: the camera placed 60 px left of the hall's front, the pull-in to come (go_live, and each wrap)
func _camera_reset() -> void:
	subject = ""
	cam_phase = "home"
	cam_v = Vector2.ZERO
	hold_t = 0.0
	idle_t = 0.0
	pick_t = _rand(PICK_MIN, PICK_MAX)
	cam_home = _home()
	cam_pos = cam_home - Vector2(PULL_IN, 0)
	cam_lap = beat.lap

## a random number in [a, b] seeded by the clock (deterministic for a capture, different every time for a player)
func _rand(a: float, b: float) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(int(clock) + beat.lap * 7919)
	return r.randf_range(a, b)

## everyone walking in town right now: [[id, x, y, vx (px/ms), path left (px), rank (0 members, 1 Eilin)], …]
func walkers() -> Array:
	var out: Array = []
	var L = _town()
	if L == null: return out
	var F = arena.FOLK.of(arena)
	for c in F.folk():
		var n: Dictionary = F.npc(c)
		if not F.walking(n): continue
		var g: Array = F.title_gait(c)
		out.append([c, float(n["x"]), float(n["y"]), float(g[0]) * float(n["dir"]), F.path_left(n), 0])
	var E = arena.eil
	if E != null and E.map == "town" and E.walking() and E.wait <= 0.0 and not E.hide:
		out.append(["eilin", float(E.x), float(L.floor_at(E.x)) if L.has_method("floor_at") else float(E.y), E.spd() * float(E.face), E.leg_left(), 1])
	return out

## the one to follow next: walking with SUBJ_PATH px still to go, members before Eilin, not the last one again while
## someone else qualifies; "" when nobody does
func pick_subject() -> String:
	var cands: Array = walkers().filter(func(w): return w[4] >= SUBJ_PATH)
	if cands.is_empty(): return ""
	var best_rank: int = cands.map(func(w): return w[5]).min()
	var top: Array = cands.filter(func(w): return w[5] == best_rank)
	var fresh_ones: Array = top.filter(func(w): return w[0] != last_subject)
	if fresh_ones.is_empty():
		var others: Array = cands.filter(func(w): return w[0] != last_subject)
		if others.is_empty(): return top[0][0]
		fresh_ones = others
	var r := RandomNumberGenerator.new()
	r.seed = hash(int(clock) * 31 + fresh_ones.size())
	return fresh_ones[r.randi() % fresh_ones.size()][0]

## the subject's walker entry, or [] once it stopped / left
func _subject_entry() -> Array:
	for w in walkers():
		if w[0] == subject: return w
	return []

## where the title puts the camera this frame (arena.cam_override; the arena applies it under the title): the hall's
## front with the intro's pull-in (each lap), then the follow camera — a subject held at 0.42 / 0.58 W at their pace,
## a hold where they stopped, the hall again when nobody walks — every move a critically damped pan at ≤ CAM_MAX px/s
func _camera(dt: float) -> void:
	var L = _town()
	if L == null:
		if arena != null: arena.cam_override = null
		return
	cam_home = _home()
	if cam_lap != beat.lap: _camera_reset()          # the wrap: the pull-in replays behind the wedge
	var vs := get_viewport_rect().size
	var pull := beat.live and mt < T_CAM and not skip and subject == ""
	var target := cam_home
	var ff := Vector2.ZERO                           # the subject's velocity, fed forward so the pan has no lag at their pace
	# who walks (the idle clock) and the subject's state
	var ws := walkers()
	if ws.is_empty(): idle_t += dt
	else: idle_t = 0.0
	if subject != "":
		var w := _subject_entry()
		if w.is_empty():
			# stopped (or gone): glide to a stop just ahead and hold there, then look for the next one
			last_subject = subject
			subject = ""
			cam_phase = "hold"
			hold_t = _rand(HOLD_MIN, HOLD_MAX)
			hold_at = cam_pos + cam_v * CAM_TAU * 0.5
		else:
			cam_phase = "follow"
			var dir: float = signf(w[3]) if w[3] != 0.0 else 1.0
			target = Vector2(w[1] + dir * CAM_OFF * vs.x, _cam_y(w[2]))
			ff = Vector2(w[3] * 1000.0 * CAM_TAU, 0.0)
	if subject == "":
		match cam_phase:
			"hold":
				target = hold_at
				hold_t -= dt
				if hold_t <= 0.0:
					var s := pick_subject()
					if s != "": subject = s
					elif idle_t >= IDLE_HOME:
						cam_phase = "home"
						pick_t = _rand(PICK_MIN, PICK_MAX)
					else: hold_t = 1000.0
			_:
				cam_phase = "home"
				target = cam_home
				if not pull:
					pick_t -= dt
					if pick_t <= 0.0:
						var s := pick_subject()
						if s != "": subject = s
						else: pick_t = 1500.0
	# the town's bounds, as the normal camera
	target.x = clampf(target.x + ff.x, vs.x / 2.0, maxf(vs.x / 2.0, arena.world_w - vs.x / 2.0))
	if pull:
		# the intro: an exact pull-in onto the hall's front, settled by T_CAM
		cam_pos = cam_home - Vector2(PULL_IN * (1.0 - _pull()), 0.0)
		cam_v = Vector2.ZERO
	else:
		var out := _damp(cam_pos, target, cam_v, CAM_TAU, CAM_MAX, dt / 1000.0)
		cam_pos = out[0]
		cam_v = out[1]
	arena.cam_override = cam_pos

## a critically damped move of `cur` toward `target` (SmoothDamp): [position, velocity], the speed capped at `vmax`
static func _damp(cur: Vector2, target: Vector2, vel: Vector2, tau: float, vmax: float, dt: float) -> Array:
	if dt <= 0.0: return [cur, vel]
	var omega := 2.0 / maxf(0.0001, tau)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var maxc := vmax * tau
	if change.length() > maxc: change = change.normalized() * maxc
	var tgt := cur - change
	var temp := (vel + change * omega) * dt
	vel = (vel - temp * omega) * e
	var out := tgt + (change + temp) * e
	# no overshoot past the target
	if (target - cur).dot(out - target) > 0.0:
		out = target
		vel = Vector2.ZERO
	# the pan's speed cap
	var step := out - cur
	var lim := vmax * dt
	if step.length() > lim:
		out = cur + step.normalized() * lim
		vel = step.normalized() * vmax
	return [out, vel]


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if not active:
		return
	var down := Vector2.INF
	var up_at := Vector2.INF
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed: down = ev.position
		else: up_at = ev.position
	if fs_want and ((ev is InputEventMouseButton and not ev.pressed) or (ev is InputEventScreenTouch and not ev.pressed)):
		fs_want = false
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var key := -1
	if ev is InputEventKey and ev.pressed and not ev.echo:
		key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	var padb := -1
	if ev is InputEventJoypadButton and ev.pressed:
		padb = ev.button_index
	if ev is InputEventScreenTouch:
		get_viewport().set_input_as_handled()        # (the mouse events it emulates do the work)
		return
	if down == Vector2.INF and up_at == Vector2.INF and key < 0 and padb < 0:
		return
	get_viewport().set_input_as_handled()
	if outro >= 0.0 or commit_k >= 0:
		return
	if gate:
		if up_at != Vector2.INF: return
		# the gate's tap is the browser gesture that allows both audio and fullscreen. The audio can start on the press;
		# the fullscreen request has to wait for the RELEASE (a touch grants the browser's activation on touchend, not on
		# touchstart — the HUD's 전체화면 button works the same way). Phones that refuse (iOS Safari) just stay as they are.
		fs_want = OS.has_feature("web") and down != Vector2.INF and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
		if OS.has_feature("web") and key >= 0 and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)     # a key press carries the activation itself
		go_live()                # the gate's tap: the track and the timeline start
		return
	if not intro_done:
		if up_at != Vector2.INF: return
		_finish_intro()
		return             # the first press only settles the intro
	# a release: it counts on the slab (or card button) the press went down on, and only there
	if up_at != Vector2.INF:
		if press_c >= 0:
			var c := press_c
			press_c = -1
			if c < confirm_rects.size() and confirm_rects[c].has_point(up_at): _confirm_pick(c)
		elif press_k >= 0:
			var k := press_k
			press_k = -1
			release_k = k
			release_t = clock
			if k < item_rects.size() and item_rects[k].has_point(up_at): _activate(k)
		return
	var up := key in [KEY_UP, KEY_W] or padb == JOY_BUTTON_DPAD_UP
	var dn := key in [KEY_DOWN, KEY_S] or padb == JOY_BUTTON_DPAD_DOWN
	var left := key in [KEY_LEFT, KEY_A] or padb == JOY_BUTTON_DPAD_LEFT
	var right := key in [KEY_RIGHT, KEY_D] or padb == JOY_BUTTON_DPAD_RIGHT
	var ok := key in [KEY_ENTER, KEY_SPACE] or padb == JOY_BUTTON_A
	var back := key == KEY_ESCAPE or padb == JOY_BUTTON_B
	if confirm:
		if left or right or up or dn:
			confirm_sel = 1 - confirm_sel
			arena.sfx("ui_move", 0.5)
		elif ok: _confirm_pick(confirm_sel)
		elif back: _confirm_pick(1)
		elif down != Vector2.INF:
			press_c = -1
			for k in confirm_rects.size():
				if confirm_rects[k].has_point(down): press_c = k
		return
	if up or dn:
		sel = posmod(sel + (1 if dn else -1), items.size())
		sel_t = clock
		arena.sfx("ui_move", 0.5)
	elif ok:
		press_k = sel
		press_t = clock
		release_k = sel
		release_t = clock + 60.0
		press_k = -1
		_activate(sel)
	elif down != Vector2.INF:
		# a press on a slab: the squash, and the pick waits for the release inside it; elsewhere nothing
		press_k = -1
		for k in item_rects.size():
			if item_rects[k].has_point(down):
				press_k = k
				press_t = clock
				if sel != k:
					sel = k
					sel_t = clock
					arena.sfx("ui_move", 0.4)

## a slab picked (a release inside it, Enter, the pad's A)
func _activate(k: int) -> void:
	match String(items[k][0]):
		"start":
			# never straight in: the card asks (a fresh story, or the save going)
			confirm = true
			confirm_kind = "wipe" if has_save else "fresh"
			confirm_sel = 1 if has_save else 0
			confirm_t = clock
			press_c = -1
			arena.sfx("ui_ok", 0.5)
		"load":
			if has_save: _commit(k)
			else: arena.sfx("step", 0.2)
		"opts":
			in_opts = true
			active = false
			visible = false          # the settings page is drawn under this layer: step aside until it closes
			ui_root.menu.open_page("opts")      # (its own ui_ok)
		"quit":
			get_tree().quit()

## the card's answer: 0 = go (시작 / 새로 시작), 1 = back
func _confirm_pick(k: int) -> void:
	confirm = false
	press_c = -1
	if k == 0:
		fresh = has_save and confirm_kind == "wipe"
		_commit(0)
	else: arena.sfx("ui_back", 0.5)

## the pick's feedback before the outro: the chosen slab slams, a burst pops on it, the others drop out of frame
## 60 ms apart; the outro begins COMMIT_MS later (_process)
func _commit(k: int) -> void:
	commit_k = k
	commit_t = clock
	press_k = -1
	if arena != null: arena.sfx("ui_ok", 0.6)

## the outro: the burst, the logo leaves, the pink field grows, the sweep carries on into the game
func _begin() -> void:
	outro = 0.0
	burst_t = clock
	if arena != null: arena.sfx("parry", 1.0)

## the intro's moves settle at once (a tap during the intro); the music plays on
func _finish_intro() -> void:
	skip = true
	intro_done = true
	menu_in = true
	for k in items.size(): fired["slab%d" % k] = true
	fired["cursor"] = true
	fired["slam"] = true
	_tick()

func _go() -> void:
	active = false
	visible = false
	beat.stop()                  # bgm.gd cross-fades to the town from here
	if arena != null: arena.leave_title_mode(not fresh)
	if fresh:
		# 시작 over a saved game: the save goes, the scene reloads and starts the new game under the sweep
		if arena.save != null and FileAccess.file_exists(arena.save.path):
			DirAccess.remove_absolute(arena.save.path)
		if get_tree().current_scene != null:
			pending_fresh = true
			get_tree().reload_current_scene()
			return
	var c: String = arena.player.who if arena.save != null and arena.save.loaded else "estelle"
	ui_root.start_game(c)


# ---------- layout ----------
## the outro's pink field: off the right edge until 시작, then both edges sweep left over the screen
func _field(vs: Vector2) -> Array:
	var sh := 0.7 * vs.x
	if outro >= 0.0:
		sh -= (0.64 * vs.x + 0.12 * vs.x + 0.7 * vs.x) * UI.bez(0.6, 0.0, 0.9, 0.4, (outro - 150.0) / 500.0)
	return [0.44 * vs.x + sh, 0.64 * vs.x + sh]

## the logo block's breathing and the slam jolt (on the landing)
func _logo_xf(vs: Vector2) -> Transform2D:
	var br := 1.0 + 0.006 * (0.5 - 0.5 * cos(clock / 4200.0 * TAU))
	var j := Vector2(sp_px.x, sp_py.x) * Vector2(4.0, 2.0)
	if beat.live and not skip and beat.lap == 0 and mt >= T_LOGO and mt < T_LOGO + 0.16:
		var k: Array = UIA.kf((mt - T_LOGO) * 1000.0, [[0.0, [0.0, 0.0]], [0.3, [-3.0, -1.5]], [0.65, [2.0, 0.0]], [1.0, [0.0, 0.0]]], 160.0)
		j += Vector2(k[0], k[1])
	var piv := Vector2(0.25 * vs.x, 0.5 * vs.y)
	return UIA.xf(piv, j, 0.0, Vector2(br, br))

## the logo's home rect: the left column, 0.36 W wide (capped at 0.44 H tall), from (0.04 W, 0.08 H), above the menu
func _logo_rect(vs: Vector2) -> Rect2:
	var w := 0.36 * vs.x
	var h := w * LOGO.get_height() / LOGO.get_width()
	if h > 0.44 * vs.y:
		h = 0.44 * vs.y
		w = h * LOGO.get_width() / LOGO.get_height()
	return Rect2(0.04 * vs.x, 0.08 * vs.y, w, h)

## slab k's rect (its bottom-left at the column's x; the lean's shift at the top comes on top)
func slab_rect(vs: Vector2, k: int) -> Rect2:
	return Rect2(MENU_X * vs.x, (MENU_Y + k * MENU_PITCH) * vs.y, SLAB_W * vs.x, SLAB_H * vs.y)

## the lean's horizontal shift of a slab's top edge
func _lean(vs: Vector2) -> float:
	return SLAB_H * vs.y * tan(deg_to_rad(SLAB_LEAN))

## how far the logo has left in the outro (0..1)
func _out(i: int) -> float:
	if outro < 0.0: return 0.0
	return UIA.p(outro, i * 40.0, 280.0, "in")


# ---------- draw: ground ----------
func _draw() -> void:
	var vs := get_viewport_rect().size
	if gate:
		_gate(vs)
		return
	# the soft ink gradient down the left: cream and pink read on a bright day sky; the paper halftone rides it
	var ga := GRAD_A * (mu(T_FIELD, 0.33, "ease") if beat.live else 0.0) * (1.0 - UIA.p(outro, 0.0, 400.0, "in") if outro >= 0.0 else 1.0)
	if ga > 0.0:
		var gw := GRAD_W * vs.x
		var pts := PackedVector2Array([Vector2.ZERO, Vector2(gw, 0), Vector2(gw, vs.y), Vector2(0, vs.y)])
		var cols := PackedColorArray([Color(INK, ga), Color(INK, 0.0), Color(INK, 0.0), Color(INK, ga)])
		draw_polygon(pts, cols)
		var uvs := PackedVector2Array()
		var scr := Vector2(clock / 90.0, clock / 140.0)
		for v in pts: uvs.append((v + scr) / 11.0)
		var dc := PackedColorArray([Color(1, 1, 1, ga), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, ga)])
		draw_polygon(pts, dc, uvs, UI.dot_tile(0.07, Color.WHITE))
	# the outro: the pink field grows over the screen (the sweep's colour), its dark halftone on it
	if outro >= 0.0:
		var f := _field(vs)
		if minf(f[0], f[1]) < vs.x - 0.5:
			var pts2 := PackedVector2Array([Vector2(minf(f[0], vs.x), 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(minf(f[1], vs.x), vs.y)])
			draw_colored_polygon(pts2, PINK)
			var uvs2 := PackedVector2Array()
			for v in pts2: uvs2.append(v / 11.0)
			draw_colored_polygon(pts2, Color.WHITE, uvs2, UI.dot_tile(0.24))

## the quiet gate (the web, before the first tap): ink and paper, the flower pulsing, 터치하여 시작
func _gate(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), INK)
	var pts := PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)])
	var uvs := PackedVector2Array()
	for v in pts: uvs.append((v + Vector2(clock / 90.0, clock / 140.0)) / 11.0)
	draw_colored_polygon(pts, Color.WHITE, uvs, UI.dot_tile(0.07, Color.WHITE))
	var pu := 1.0 + 0.04 * UIA.pulse(clock, 1300.0)
	var eh := 0.22 * vs.y
	var ew := eh * EMBLEM.get_width() / EMBLEM.get_height()
	var c := Vector2(vs.x * 0.5, vs.y * 0.44)
	draw_set_transform_matrix(UIA.xf(c, Vector2.ZERO, 0.0, Vector2(pu, pu)))
	draw_texture_rect(EMBLEM, Rect2(c - Vector2(ew, eh) / 2.0, Vector2(ew, eh)), false)
	draw_set_transform(Vector2.ZERO)
	var fn := UI.noto()
	var s := "터치하여 시작 · 전체 화면"
	var fs := int(0.03 * vs.y)
	draw_string(fn, Vector2(vs.x * 0.5 - UI.text_w(fn, s, fs) / 2.0, vs.y * 0.44 + eh * 0.62 + fs), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CREAM, 0.7 + 0.3 * UIA.pulse(clock, 1300.0)))


# ---------- draw: logo, menu, wedge ----------
func _draw_fg() -> void:
	if not active or gate or outro > 1050.0: return
	var ci := fg_layer
	var vs := get_viewport_rect().size
	_logo(ci, vs)
	_menu(ci, vs)
	_card(ci, vs)
	_burst(ci, vs)
	# the white slash as the logo lands (cx_flash)
	if beat.live and not skip and beat.lap == 0 and mt >= T_LOGO and mt < T_LOGO + 0.38:
		var u := UIA.ez("mv", (mt - T_LOGO) / 0.38)
		var fr := Rect2(-0.2 * vs.x, vs.y * 0.5, vs.x * 1.4, 0.05 * vs.y)
		var fm := UIA.xf(fr.get_center(), Vector2(lerpf(-1.2, 1.2, u) * fr.size.x, 0), deg_to_rad(-12.0))
		ci.draw_colored_polygon(fm * UI.clip(fr, [[0, 45], [100, 0], [100, 25], [0, 100]]), Color.WHITE)
	_wedge(ci, vs)
	if not DEV.on or arena == null: return   # the build stamp: debug builds only (dev.gd)
	var ver: String = arena._stamp()
	var sf := UI.spaced(UI.noto(), 1)
	ci.draw_string(sf, Vector2(vs.x - 12.0 - UI.text_w(sf, ver, 11), vs.y - 12.0), ver, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

## the brush logo on its blob: it slams down on 0.42 from 1.25× with a short overshoot, 2° over-rotated and settling
## in 150 ms, a burst popping behind it; the blob rolls ±1° under it; it pulses 1.0 ↔ 1.02 on the bar in section D
## (stopping in the outro); it follows the pointer a hair and leaves left in the outro
func _logo(ci: CanvasItem, vs: Vector2) -> void:
	if not beat.live: return
	var r := _logo_rect(vs)
	var base := _logo_xf(vs)
	var o := _out(0)
	if o >= 1.0: return
	var c := r.get_center()
	var leave := Vector2(-0.7 * vs.x * o, 0)
	# the landing's burst behind the logo, and section D's phrase bursts
	var bursts: Array = [[T_LOGO, 0.4, 1.5, 1.0]]
	if sec == "D" or sec == "out":
		for b in [91, 99, 107]:
			bursts.append([BEAT.bar_t(b), 0.4, 1.6, 1.0])
	for sp in bursts:
		var u := mu(sp[0], sp[1], "out")
		if u <= 0.0 or u >= 1.0: continue
		var sz: float = r.size.x * lerpf(0.3, sp[2], u)
		var al: float = sp[3] * (1.0 if u < 0.5 else 1.0 - (u - 0.5) / 0.5)
		ci.draw_set_transform_matrix(base * UIA.xf(c + leave, Vector2.ZERO, deg_to_rad(-15.0 * u)))
		ci.draw_texture_rect(BURST, Rect2(c + leave - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, al))
	# the blob and the logo land together
	var u := mu(T_LOGO - 0.33, 0.33, "bk")
	if u <= 0.0:
		ci.draw_set_transform(Vector2.ZERO)
		return
	var al := mu(T_LOGO - 0.33, 0.08, "linear")
	var sc := 1.0 + 0.25 * (1.0 - u)
	var over := deg_to_rad(-2.0) * (1.0 - mu(T_LOGO, 0.15, "ease"))
	var pk := 0.0
	if sec == "D": pk = 1.0
	elif sec == "out": pk = 1.0 - mu(BEAT.bar_t(115), 0.3, "linear")
	sc *= 1.0 + 0.02 * BEAT.bump(beat.bar_phase(), 0.4) * pk
	var roll := deg_to_rad(1.0) * sin(clock / 6400.0 * TAU)
	var bw := r.size.x * 1.15
	var bh := bw * BLOB.get_height() / BLOB.get_width()
	ci.draw_set_transform_matrix(base * UIA.xf(c, leave, roll + over - deg_to_rad(6.0 * o), Vector2(sc * 1.02, sc * 1.02)))
	ci.draw_texture_rect(BLOB, Rect2(c - Vector2(bw, bh) / 2.0, Vector2(bw, bh)), false, Color(1, 1, 1, al))
	ci.draw_set_transform_matrix(base * UIA.xf(c, leave, over - deg_to_rad(6.0 * o), Vector2(sc, sc)))
	ci.draw_texture_rect(LOGO, r, false, Color(1, 1, 1, al))
	ci.draw_set_transform(Vector2.ZERO)

## 시작's burst: the splash pops from the logo's centre, 0.2× → 2.4× over 350 ms, fading out at the end
func _burst(ci: CanvasItem, vs: Vector2) -> void:
	if burst_t < 0.0: return
	var u := UIA.p(clock - burst_t, 0.0, 350.0, "out")
	if u >= 1.0: return
	var c := _logo_rect(vs).get_center()
	var sz: float = _logo_rect(vs).size.x * lerpf(0.2, 2.4, u)
	var al := 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
	ci.draw_set_transform_matrix(UIA.xf(c, Vector2.ZERO, deg_to_rad(-20.0 * u)))
	ci.draw_texture_rect(BURST, Rect2(c - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, al))
	ci.draw_set_transform(Vector2.ZERO)

## the loop's ink wedge: a slanted band from the right at the end of the track, covering the screen exactly at the
## wrap and uncovering the town over the first WEDGE s of the next lap
func _wedge(ci: CanvasItem, vs: Vector2) -> void:
	if wedge.is_empty(): return
	var xl: float = wedge[0] * vs.x
	var bw := 1.6 * vs.x
	var sl := 0.2 * vs.x
	var pts := PackedVector2Array([Vector2(xl, 0), Vector2(xl + bw, 0), Vector2(xl + bw + sl, vs.y), Vector2(xl + sl, vs.y)])
	ci.draw_colored_polygon(pts, INK)
	var uvs := PackedVector2Array()
	for v in pts: uvs.append((v + Vector2(clock / 90.0, clock / 140.0)) / 11.0)
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, UI.dot_tile(0.07, Color.WHITE))

## a slab's scale from the press / release / commit feedback: the squash to 0.96 on a press (80 ms), the spring back
## (`bk`) on the release, the pick's slam
func _slab_scale(k: int) -> float:
	var s := 1.0
	if commit_k == k:
		var t := clock - commit_t
		s = UIA.kf(t, [[0.0, 1.0], [0.2, 0.9], [0.55, 1.07], [1.0, 1.0]], 300.0, 0.0, "ease-out")
	elif press_k == k:
		s = 1.0 - 0.04 * UIA.p(clock - press_t, 0.0, 40.0, "ease-out")
	elif release_k == k and clock - release_t < 260.0:
		s = 0.96 + 0.04 * UIA.p(clock - release_t, 0.0, 240.0, "bk")
	return s

## the pick's drop of the other slabs (0..1): the j-th other slab leaves the frame downwards 60 ms after the one before
func _slab_drop(k: int) -> float:
	if commit_k < 0 or k == commit_k: return 0.0
	var j := 0
	for i in items.size():
		if i == commit_k: continue
		if i == k: break
		j += 1
	return UIA.p(clock - commit_t, 70.0 + j * 60.0, 300.0, "in")

## the menu: the pink rail, four ink slabs leaning −8° with a pink rim and a hard pink shadow, their index, label and
## caption; the picked one slides right, turns pink on the brush stroke and gets a cream underline sweep; a disabled
## 불러오기 sits at 45 % with NO SAVE. The slabs slam in from the left one per 16th on the first lap, the second
## overshooting 0.01 W and settling; in the outro they drop downwards
func _menu(ci: CanvasItem, vs: Vector2) -> void:
	var W := vs.x
	var H := vs.y
	var o := UIA.p(outro, 0.0, 280.0, "in") if outro >= 0.0 else 0.0
	item_rects.clear()
	if not beat.live:
		for k in items.size(): item_rects.append(Rect2())
		return
	var lean := _lean(vs)
	var fb := UI.bhs()
	var fi := UI.anton(false, 0)
	var fcap := UI.anton(false, 2)
	var fs_lab := int(0.038 * H)
	var fs_idx := int(0.022 * H)
	var fs_cap := int(0.018 * H)
	var pulse := BEAT.bump(beat.pulse_phase(), 0.45) if intro_done else 0.0
	# the motto, small above the logo
	var ua := mu(T_MOTTO, 0.5, "ease") * (1.0 - o)
	if ua > 0.0:
		var fn := UI.noto()
		var motto := "서툴지만, 물러서지 않는다"
		var fsm := int(0.026 * H)
		ci.draw_string(fn, Vector2(0.089 * W + 0.02 * W * (1.0 - ua), 0.065 * H), motto, HORIZONTAL_ALIGNMENT_LEFT, -1, fsm, Color(0.86, 0.86, 0.9, ua))
	# the rail: a thin pink line down the slabs' left edges, from the logo's bottom-left to under the last slab
	var r0 := slab_rect(vs, 0)
	var rl := slab_rect(vs, items.size() - 1)
	var ur := 1.0 if menu_in else mu(T_MENU[0] - 0.1, 0.35, "ease")
	if ur > 0.0 and o < 1.0:
		var lr := _logo_rect(vs)
		var y_top := lr.end.y - 0.02 * H
		var y_bot := rl.end.y + 0.035 * H
		var y1 := lerpf(y_top, y_bot, ur)
		var slope := -tan(deg_to_rad(SLAB_LEAN))        # x per y, leaning like the slabs
		var xb := r0.position.x + 0.004 * W
		var x_at := func(y: float) -> float: return xb + (y - r0.end.y) * slope
		ci.draw_line(Vector2(x_at.call(y_top), y_top + 0.25 * H * o), Vector2(x_at.call(y1), y1 + 0.25 * H * o), Color(PINK, 0.85 * (1.0 - o)), 2.0)
	# the flower, small to the right of the first slab, popping on its beat
	var ue := 1.0 if menu_in else mu(T_EMBLEM, 0.3, "bk")
	if ue > 0.0 and o < 1.0:
		var eh := 0.15 * H
		var ew := eh * EMBLEM.get_width() / EMBLEM.get_height()
		var er := Rect2(r0.end.x + lean + 0.055 * W, r0.position.y - eh * 0.3, ew, eh)
		ci.draw_set_transform_matrix(UIA.xf(er.get_center(), Vector2(0, 0.25 * H * o), 0.0, Vector2(ue, ue)))
		ci.draw_texture_rect(EMBLEM, er, false, Color(1, 1, 1, minf(1.0, ue) * (1.0 - o)))
		ci.draw_set_transform(Vector2.ZERO)
	# the brush stroke behind the picked slab, sliding between rows on its spring; it slaps onto 시작 from 1.3× and
	# pulses on the pulse
	var ucur := 1.0 if menu_in else mu(T_CURSOR, 0.22, "bk")
	var on_k := sel if not confirm else -1
	if commit_k >= 0: on_k = commit_k
	if ucur > 0.0 and o < 1.0 and on_k >= 0:
		var rs := slab_rect(vs, int(round(sp_cur.x)) if commit_k < 0 else commit_k)
		var cy := slab_rect(vs, 0).get_center().y + sp_cur.x * MENU_PITCH * H if commit_k < 0 else rs.get_center().y
		var bw := rs.size.x * 1.25
		var bh := rs.size.y * 2.6
		var cc := Vector2(rs.position.x + SLAB_SHIFT * W + rs.size.x * 0.5 + lean * 0.5, cy)
		var psc := (1.0 + 0.02 * pulse) * (1.0 + 0.3 * (1.0 - minf(1.0, ucur))) * _slab_scale(on_k)
		ci.draw_set_transform_matrix(UIA.xf(cc, Vector2(0, 0.25 * H * o + _slab_drop(on_k) * 0.6 * H), 0.0, Vector2(psc, psc)))
		ci.draw_texture_rect(BRUSH, Rect2(cc - Vector2(bw, bh) / 2.0, Vector2(bw, bh)), false, Color(1, 1, 1, minf(1.0, ucur) * (1.0 - o)))
		ci.draw_set_transform(Vector2.ZERO)
	# the slabs
	for k in items.size():
		var u := 1.0 if menu_in else mu(T_MENU[k], 0.2, "bk")
		if u <= 0.0 or o >= 1.0:
			item_rects.append(Rect2())
			continue
		var key := String(items[k][0])
		var on := k == on_k and ucur > 0.0
		var dim: bool = key == "load" and not has_save
		var lab: String = items[k][1]
		var r := slab_rect(vs, k)
		var shift := SLAB_SHIFT * W * (1.0 if on else 0.0)
		# the second slab takes two stamps: a 0.01 W overshoot on the 16th after it lands, settling back
		var push := 0.0
		if k == 1 and not menu_in: push = 0.01 * W * sin(PI * mu(T_MENU[1] + 0.1, 0.22, "linear"))
		var sc := _slab_scale(k)
		var drop := _slab_drop(k)
		var alpha := (1.0 if on else 0.8) * (1.0 - o)
		if dim: alpha = 0.45 * (1.0 - o)
		var fill := PINK if on else INK
		var tc := INK if on else CREAM
		var ic := INK if on else PINK
		var cap: String = "NO SAVE" if dim else CAPTION[key]
		var cc := r.get_center() + Vector2(shift + lean * 0.5, 0)
		ci.draw_set_transform_matrix(UIA.xf(cc, Vector2(-0.3 * W * (1.0 - u) + push, 0.25 * H * o + drop * 0.6 * H), deg_to_rad(-6.0 * (1.0 - u)), Vector2(sc, sc)))
		var x := r.position.x + shift
		var y := r.position.y
		var w := r.size.x
		var h := r.size.y
		# the hard pink shadow, the ink body, the rim on the left edge
		UI.para(ci, x + 4.0, y + 4.0, w, h, lean, Color(PINK if not on else INK, alpha))
		UI.para(ci, x, y, w, h, lean, Color(fill, alpha))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x + lean, y), Vector2(x + lean + 3.0, y), Vector2(x + 3.0, y + h), Vector2(x, y + h)]), Color(INK if on else PINK, alpha))
		# the index, the label, the caption
		var base_y := y + h * 0.5
		ci.draw_string(fi, Vector2(x + lean * 0.6 + 0.014 * W, base_y + fs_idx * 0.36), "%02d" % (k + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_idx, Color(ic, alpha))
		var lx := x + lean * 0.5 + 0.055 * W
		ci.draw_string(fb, Vector2(lx, base_y + fs_lab * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_lab, Color(tc, alpha))
		var cw := UI.text_w(fcap, cap, fs_cap)
		ci.draw_string(fcap, Vector2(x + w + lean * 0.4 - 0.022 * W - cw, base_y + fs_cap * 0.36), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_cap, Color(INK if on else ROSE, alpha * (0.9 if on else 1.0)))
		# the cream underline sweeping across the label on selection
		if on and commit_k < 0:
			var us := UIA.p(clock - sel_t, 0.0, 180.0, "ease-out")
			if us > 0.0:
				var lw := UI.text_w(fb, lab, fs_lab)
				ci.draw_rect(Rect2(lx, base_y + fs_lab * 0.5 + 2.0, lw * us, 2.0), Color(CREAM, alpha))
		ci.draw_set_transform(Vector2.ZERO)
		item_rects.append(Rect2(x - 6.0, y - 4.0, w + lean + 12.0, h + 12.0))
		# the tiny ink splat as the slab lands (the first lap)
		if not menu_in and beat.lap == 0 and not skip:
			var us2 := mu(T_MENU[k] + 0.12, 0.22, "out")
			if us2 > 0.0 and us2 < 1.0:
				var sz := w * 0.22 * (0.4 + 0.6 * us2)
				var at := Vector2(x + lean * 0.5 + 0.01 * W, y + h * 0.5)
				ci.draw_set_transform_matrix(UIA.xf(at, Vector2.ZERO, deg_to_rad(40.0 * k + 90.0 * us2)))
				ci.draw_texture_rect(BURST, Rect2(at - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(INK, 0.9 * (1.0 - us2)))
				ci.draw_set_transform(Vector2.ZERO)
	# the pick's burst on the chosen slab
	if commit_k >= 0:
		var tb := clock - commit_t
		if tb < 380.0:
			var ub := UIA.ez("out", tb / 380.0)
			var rr := slab_rect(vs, commit_k)
			var c := rr.get_center() + Vector2(SLAB_SHIFT * W + lean * 0.5, 0)
			var sz := rr.size.x * lerpf(0.25, 1.5, ub)
			var al := 1.0 if tb < 200.0 else 1.0 - (tb - 200.0) / 180.0
			ci.draw_set_transform_matrix(UIA.xf(c, Vector2.ZERO, deg_to_rad(-25.0 * ub)))
			ci.draw_texture_rect(BURST, Rect2(c - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, al))
			ci.draw_set_transform(Vector2.ZERO)

## the 시작 card beside the menu: a fresh story ("새로운 이야기를 시작합니다" · 시작 / 취소), or over a save the warning
## ("저장된 진행이 있어요 / 지우고 처음부터?" · 새로 시작 / 돌아가기); a button counts on the release inside it
func _card(ci: CanvasItem, vs: Vector2) -> void:
	confirm_rects.clear()
	if not confirm: return
	var W := vs.x
	var H := vs.y
	var fb := UI.bhs()
	var fs2 := int(0.03 * H)
	var lines: Array = CARD_LINES[confirm_kind]
	var labs: Array = CARD_BTNS[confirm_kind]
	var cw := 0.36 * W
	var chh := (0.2 if lines.size() > 1 else 0.17) * H
	var cr := Rect2(MENU_X * W + SLAB_W * W + 0.06 * W, 0.96 * H - chh, cw, chh)
	var cu := UIA.p(clock - confirm_t, 0.0, 260.0, "bk")
	ci.draw_set_transform_matrix(UIA.xf(cr.get_center(), Vector2(0, 0.08 * H * (1.0 - cu)), deg_to_rad(-2.0), Vector2(cu, cu)))
	ci.draw_colored_polygon(UI.clip(cr.grow(3.0), [[0, 4], [100, 0], [99, 100], [1, 96]]), Color(PINK, 0.9))
	ci.draw_colored_polygon(UI.clip(cr, [[0, 4], [100, 0], [99, 100], [1, 96]]), INK)
	ci.draw_colored_polygon(UI.clip(Rect2(cr.position.x, cr.position.y, 0.006 * W, chh), [[0, 0], [100, 0], [100, 100], [0, 100]]), PINK)
	var fn2 := UI.noto()
	var fsq := int(0.03 * H)
	for i in lines.size():
		ci.draw_string(fn2, Vector2(cr.position.x + 0.03 * W, cr.position.y + (0.06 + 0.04 * i) * H), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fsq, Color.WHITE if i == 0 else Color(0.8, 0.8, 0.85))
	for k in 2:
		var bw := 0.13 * W
		var br := Rect2(cr.position.x + 0.03 * W + k * (bw + 0.02 * W), cr.end.y - 0.07 * H, bw, 0.05 * H)
		var bon := k == confirm_sel
		var sc := 0.96 if press_c == k else 1.0
		ci.draw_set_transform_matrix(UIA.xf(cr.get_center(), Vector2(0, 0.08 * H * (1.0 - cu)), deg_to_rad(-2.0), Vector2(cu, cu)) * UIA.xf(br.get_center(), Vector2.ZERO, 0.0, Vector2(sc, sc)))
		UI.para(ci, br.position.x, br.position.y, bw, br.size.y, -br.size.y * 0.3, PINK if bon else Color.WHITE)
		ci.draw_string(fb, Vector2(br.position.x + 0.02 * W, br.position.y + br.size.y * 0.5 + fs2 * 0.36), labs[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color.WHITE if bon else INK)
		confirm_rects.append(br.grow(6.0))
	ci.draw_set_transform(Vector2.ZERO)
