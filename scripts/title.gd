extends Control
## Title (prototype #title) in the persona skin, as a transparent overlay on the live guild town; the hero select is
## gone (a fresh game is 에스텔 alone, the seniors join in play). docs/title_storyboard.md has the whole timeline.
## The title is music-driven: every move is a function of the title track's clock (beat.gd, `mt` seconds into
## assets/bgm/title.ogg, looping), never a one-shot timer, so it survives loops, tab switches and headless captures.
##
## The backdrop is the town itself, running (arena.title_mode): its real clock and weather, Eilin on her day, every
## recruited member out in town as a townsperson (the party too, for the title's duration), passing greetings; the
## player stands aside and the HUD is off. The title drives the camera (arena.cam_override) through three framings —
## F1 본관 정면, F2 언덕 길, F3 거리 — switching behind the ink wedge at the section bars, drifting a little inside each.
## Over it: a soft ink gradient down the left, the brush logo on its blob, the motto, the menu with its brush cursor and
## the flower. Section A's intro beats stay (the splats, the logo landing, the menu rows, the cursor's slap); at 3.23
## the camera settles into F1 from a slightly wider start. 시작 bursts from the logo, the pink field grows over the
## screen and the sweep carries it into the game.
##
## Layers: this Control draws the gradient (and the gate, and the outro's pink field); `fg` draws the logo, the
## menu, the bursts and the wedge with linear filtering.

const UI := preload("res://scripts/ui_kit.gd")
const DEV := preload("res://scripts/dev.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const BEAT := preload("res://scripts/beat.gd")
const PINK := Color("#ff3d7f")
const INK := Color("#0d0b10")
const CREAM := Color("#f3e9d2")
const LOGO := preload("res://assets/title/logo.png")      # Clumsy Valor / 어설픈 용맹 / Assemble, brush
const BLOB := preload("res://assets/title/blob.png")      # the plum blob the logo lands on
const BRUSH := preload("res://assets/title/brush.png")    # the menu cursor
const BURST := preload("res://assets/title/burst.png")    # 시작's burst, the wedges' and the intro's splats
const EMBLEM := preload("res://assets/title/emblem.png")  # the guild's flower
const GRAD_W := 0.42                 # the ink gradient's reach from the left edge (fraction of W)
const GRAD_A := 0.8                  # its strength at the edge
## the camera framings (town.gd coordinates, from its layout): [name, x, y, drift (px)]; x/y are added to the town's
## HXB / TTOP / LOWF in _framing(). F1 본관 정면 — the hall's door a little right of centre, its terrace at ~0.82 H;
## F2 언덕 길 — the lamp-lit slope up to the hall with the hall's left half in frame; F3 거리 — the lower plaza under
## the hill (the fountain, the benches, the light strings) where the townsfolk gather
const FRAMINGS := {"F1": [330.0, -160.0, 40.0], "F2": [230.0, -100.0, 40.0], "F3": [-40.0, -190.0, 40.0]}
## which framing each section rides: switches behind the wedges at bars 35, 65, 91 and 115
const SEC_FRAME := {"A": "F1", "B": "F2", "C": "F3", "D": "F2", "out": "F1"}
const PULL_IN := 60.0                # the intro: the camera settles into F1 from this much further left, by 3.23

## ---- the timeline (music seconds; beat.gd has the grid) ----
const T_FIELD := 0.09                # the gradient fades in (by 0.42)
const T_SPLAT := [0.42, 0.75, 1.07]  # the three paint splats behind the logo's spot, one per beat
const T_LOGO := 1.39                 # the logo and its blob land (bar 2) with the slam
const T_CAM := 3.23                  # the camera has settled into F1
const T_MENU := [6.43, 7.08, 7.08, 7.41]   # the menu rows, one per beat; the 2nd one beat late (and it takes two stamps)
const T_CURSOR := 9.22               # the brush slaps 시작, the emblem pops
const WEDGE := 0.26                  # s for the ink wedge's leading edge to cross the screen (the composition switches then)
const LOOP_WEDGE := 1.34             # s before the wrap the loop's wedge starts from the right

var arena
var ui_root
var active := true
var beat := BEAT.new()           # the music clock
var mt := 0.0                    # beat.music_t, cached each frame (s)
var sec := "A"                   # the section mt is in
var gate := false                # the quiet gate before the first tap (the web: audio needs the gesture)
var fs_want := false             # the gate was tapped: ask for fullscreen on the tap's release (web)
var skip := false                # a tap during the intro: its moves settle at once (until the next lap)
var menu_in := false             # the menu rows have entered (they never leave, laps included)
var slam_lap := -1               # the lap the logo's slam was played on
var intro_done := false
var outro := -1.0                # outro clock (ms), -1 = not running
var handed := false              # the sweep into the game has been started
var clock := 0.0                 # wall clock (ms): ambient motion, the menu's springs, the outro
var trn := UIA.Tr.new()
var fg_layer: Control
var sp_px := UIA.Spring.new(0.0, 0.9, 0.9)     # pointer parallax (the logo block)
var sp_py := UIA.Spring.new(0.0, 0.9, 0.9)
var sp_cur := UIA.Spring.new(0.0, 0.3, 0.8)    # the menu cursor's row (the brush slides between items)
var burst_t := -1.0                            # clock when 시작's burst popped (-1: none)
var wedge: Array = []            # the ink wedge in flight: [leading edge x (fraction of W), dir, u, biggest]
var framing := "F1"              # the camera framing being drawn
var cam_pos := Vector2.ZERO      # the camera centre the title asks for (town coordinates)
## the menu: 시작 · 불러오기 · 설정 · 끝내기 (no 끝내기 on the web, where a tab cannot close itself)
var items: Array = []            # [key, label]
var sel := 0
var item_rects: Array = []       # Rect2 per item, as last drawn (taps)
var has_save := false
var confirm := false             # 시작 over a saved game: "지우고 새로 시작할까요?" row
var confirm_sel := 1             # 0 = 새로 시작, 1 = 돌아가기
var confirm_rects: Array = []
var confirm_t := 0.0              # clock when the confirm card opened
var fresh := false               # 시작 chosen: the save goes and the scene reloads into a new game
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
	beat.start(0.0)
	_tick()
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
	if beat.wrapped:
		skip = false                         # the loop replays the intro
	_tick()
	if outro < 0.0 and beat.live and slam_lap != beat.lap and mt >= T_LOGO and mt < T_LOGO + 1.0:
		slam_lap = beat.lap
		if arena != null: arena.sfx("slam", 0.5)
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
	_camera()
	queue_redraw()
	fg_layer.queue_redraw()

## everything the frame derives from the music clock: the section, the framing, the wedge
func _tick() -> void:
	mt = beat.music_t
	sec = beat.section()
	if not intro_done and (skip or beat.lap >= 1 or (beat.live and mt >= T_CURSOR)): intro_done = true
	if not menu_in and (skip or beat.lap >= 1 or (beat.live and mt >= T_MENU[3] + 0.45)): menu_in = true
	# the framing: a section's framing takes over once its wedge has covered the screen
	framing = "F1"
	if beat.live:
		for name in ["B", "C", "D", "out"]:
			if mt >= BEAT.sec_t(name) + WEDGE: framing = SEC_FRAME[name]
	# the wedge: at each section's start (left → right), and the loop's (from the right)
	wedge = []
	if beat.live:
		var tD := BEAT.sec_t("D")
		for tb in _wedge_times():
			var u: float = (mt - float(tb)) / WEDGE
			if u >= 0.0 and u < 2.0:
				wedge = [lerpf(-0.3, 1.3, UIA.ez("mv", u)) if u < 1.0 else lerpf(1.3, 2.9, UIA.ez("mv", u - 1.0)), 1, u, is_equal_approx(float(tb), tD)]
				break
		var tl := BEAT.LEN - LOOP_WEDGE
		if mt >= tl:
			wedge = [lerpf(1.3, -0.3, UIA.ez("in", (mt - tl) / LOOP_WEDGE)), -1, 0.0, false]
		elif beat.lap >= 1 and mt < WEDGE:
			wedge = [lerpf(-0.3, -1.9, mt / WEDGE), -1, 1.0, false]

## the wedges' start times: the sections B, C, D and the outro
func _wedge_times() -> Array:
	return [BEAT.sec_t("B"), BEAT.sec_t("C"), BEAT.sec_t("D"), BEAT.sec_t("out")]

## progress (0..1, eased) of a music-timed move that starts at t0 (s) and lasts dur (s); the intro's moves are done at
## once after a tap skipped the intro
func mu(t0: float, dur: float, name = "bk") -> float:
	if skip and t0 <= T_CURSOR: return 1.0
	return UIA.ez(name, (mt - t0) / maxf(0.001, dur))

## the current section for a time (tests)
func section_at(t: float) -> String:
	return BEAT.section_at(t)


# ---------- the camera ----------
## a framing's centre in the town (null when the world is not the town)
func _framing(name: String) -> Variant:
	if arena == null or arena.level == null or String(arena.level.kind) != "town": return null
	var L = arena.level
	var f: Array = FRAMINGS[name]
	match name:
		"F1": return Vector2(L.HXB + f[0], L.TTOP + f[1])
		"F2": return Vector2(L.SX1 + f[0], L.TTOP + f[1])
	return Vector2(L.HDOOR + f[0], L.LOWF + f[1])

## the framing's span in music seconds (for the drift): the section's
func _frame_span() -> Array:
	var names := ["A", "B", "C", "D", "out"]
	var i := names.find(sec)
	var t0 := BEAT.sec_t(sec)
	var t1 := BEAT.sec_t(names[i + 1]) if i + 1 < names.size() else BEAT.LEN
	return [t0, t1]

## where the title puts the camera this frame: the framing, a slow sine drift of ~40 px across the framing's span,
## and the intro's pull-in into F1 (arena.cam_override; the arena applies it under the title)
func _camera() -> void:
	if arena == null or not arena.title_mode: return
	var c = _framing(framing)
	if c == null:
		arena.cam_override = null
		return
	var span := _frame_span()
	var u := clampf((mt - span[0]) / maxf(1.0, span[1] - span[0]), 0.0, 1.0)
	var d: float = FRAMINGS[framing][2]
	var p: Vector2 = c + Vector2(d * sin(PI * u), 6.0 * sin(TAU * u))
	if framing == "F1" and (sec == "A" or sec == "out") and beat.live:
		p.x -= PULL_IN * (1.0 - mu(T_CAM - 0.6, 0.6, "out")) if sec == "A" else 0.0
	cam_pos = p
	arena.cam_override = p


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if not active:
		return
	var tap := Vector2.INF
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		tap = ev.position
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
	if tap == Vector2.INF and key < 0 and padb < 0:
		return
	get_viewport().set_input_as_handled()
	if outro >= 0.0:
		return
	if gate:
		# the gate's tap is the browser gesture that allows both audio and fullscreen. The audio can start on the press;
		# the fullscreen request has to wait for the RELEASE (a touch grants the browser's activation on touchend, not on
		# touchstart — the HUD's 전체화면 button works the same way). Phones that refuse (iOS Safari) just stay as they are.
		fs_want = OS.has_feature("web") and tap != Vector2.INF and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
		if OS.has_feature("web") and key >= 0 and DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)     # a key press carries the activation itself
		go_live()                # the gate's tap: the track and the timeline start
		return
	if not intro_done:
		_finish_intro()
		return             # the first press only settles the logo
	var up := key in [KEY_UP, KEY_W] or padb == JOY_BUTTON_DPAD_UP
	var down := key in [KEY_DOWN, KEY_S] or padb == JOY_BUTTON_DPAD_DOWN
	var left := key in [KEY_LEFT, KEY_A] or padb == JOY_BUTTON_DPAD_LEFT
	var right := key in [KEY_RIGHT, KEY_D] or padb == JOY_BUTTON_DPAD_RIGHT
	var ok := key in [KEY_ENTER, KEY_SPACE] or padb == JOY_BUTTON_A
	var back := key == KEY_ESCAPE or padb == JOY_BUTTON_B
	if confirm:
		if left or right or up or down:
			confirm_sel = 1 - confirm_sel
			arena.sfx("ui_move", 0.5)
		elif ok: _confirm_pick(confirm_sel)
		elif back: _confirm_pick(1)
		elif tap != Vector2.INF:
			for k in confirm_rects.size():
				if confirm_rects[k].has_point(tap): _confirm_pick(k)
		return
	if up or down:
		sel = posmod(sel + (1 if down else -1), items.size())
		arena.sfx("ui_move", 0.5)
	elif ok:
		_pick(sel)
	elif tap != Vector2.INF:
		for k in item_rects.size():
			if item_rects[k].has_point(tap):
				sel = k
				_pick(k)

## a menu item chosen
func _pick(k: int) -> void:
	match String(items[k][0]):
		"start":
			if has_save:
				confirm = true
				confirm_sel = 1
				confirm_t = clock
				arena.sfx("ui_ok", 0.5)
			else: _begin()
		"load":
			if has_save: _begin()
			else: arena.sfx("step", 0.2)
		"opts":
			in_opts = true
			active = false
			visible = false          # the settings page is drawn under this layer: step aside until it closes
			ui_root.menu.open_page("opts")      # (its own ui_ok)
		"quit":
			get_tree().quit()

func _confirm_pick(k: int) -> void:
	confirm = false
	if k == 0:
		fresh = true
		_begin()
	else: arena.sfx("ui_back", 0.5)

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
	slam_lap = beat.lap
	_tick()

func _go() -> void:
	active = false
	visible = false
	beat.stop()                  # bgm.gd cross-fades to the town from here
	if arena != null: arena.leave_title_mode()
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
	if beat.live and not skip and mt >= T_LOGO and mt < T_LOGO + 0.16:
		var k: Array = UIA.kf((mt - T_LOGO) * 1000.0, [[0.0, [0.0, 0.0]], [0.3, [-3.0, -1.5]], [0.65, [2.0, 0.0]], [1.0, [0.0, 0.0]]], 160.0)
		j += Vector2(k[0], k[1])
	var piv := Vector2(0.25 * vs.x, 0.5 * vs.y)
	return UIA.xf(piv, j, 0.0, Vector2(br, br))

## the logo's home rect: the left column, ~0.4 W wide (capped at 0.54 H tall), above the menu
func _logo_rect(vs: Vector2) -> Rect2:
	var w := 0.4 * vs.x
	var h := w * LOGO.get_height() / LOGO.get_width()
	if h > 0.54 * vs.y:
		h = 0.54 * vs.y
		w = h * LOGO.get_width() / LOGO.get_height()
	return Rect2(0.04 * vs.x, 0.1 * vs.y, w, h)

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
	_prompt(ci, vs)
	_burst(ci, vs)
	# the white slash as the logo lands (cx_flash)
	if beat.live and not skip and mt >= T_LOGO and mt < T_LOGO + 0.38:
		var u := UIA.ez("mv", (mt - T_LOGO) / 0.38)
		var fr := Rect2(-0.2 * vs.x, vs.y * 0.5, vs.x * 1.4, 0.05 * vs.y)
		var fm := UIA.xf(fr.get_center(), Vector2(lerpf(-1.2, 1.2, u) * fr.size.x, 0), deg_to_rad(-12.0))
		ci.draw_colored_polygon(fm * UI.clip(fr, [[0, 45], [100, 0], [100, 25], [0, 100]]), Color.WHITE)
	_wedge(ci, vs)
	if not DEV.on or arena == null: return   # the build stamp: debug builds only (dev.gd)
	var ver: String = arena._stamp()
	var sf := UI.spaced(UI.noto(), 1)
	ci.draw_string(sf, Vector2(vs.x - 12.0 - UI.text_w(sf, ver, 11), vs.y - 12.0), ver, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

## the brush logo on its blob: three paint splats pop behind it one per beat, then it lands from 1.25× with a short
## overshoot, 2° over-rotated and settling in 150 ms; the blob rolls ±1° under it; it pulses 1.0 ↔ 1.02 on the bar
## in section D (first to stop in the outro); it follows the pointer a hair and leaves left in the outro
func _logo(ci: CanvasItem, vs: Vector2) -> void:
	if not beat.live: return
	var r := _logo_rect(vs)
	var base := _logo_xf(vs)
	var o := _out(0)
	if o >= 1.0: return
	var c := r.get_center()
	var leave := Vector2(-0.7 * vs.x * o, 0)
	# the splats (a fresh set each lap), and section D's phrase bursts
	var bursts: Array = []
	for i in T_SPLAT.size():
		bursts.append([T_SPLAT[i], 0.26, [0.18, 0.3, 0.22][i], [0.3, 0.22, 0.26][i], [25.0, -70.0, 140.0][i], 0.9, false])
	if sec == "D" or sec == "out":
		for b in [91, 99, 107]:
			bursts.append([BEAT.bar_t(b), 0.4, 0.5, 1.6, -15.0 * b, 1.0, true])
	for sp in bursts:
		var u := mu(sp[0], sp[1], "bk" if not sp[6] else "out")
		if u <= 0.0 or (sp[6] and u >= 1.0): continue
		var sz: float = r.size.x * (sp[3] * u if not sp[6] else lerpf(0.3, sp[3], u))
		var at := r.position + Vector2(sp[2], 0.3 if not sp[6] else 0.5) * r.size + leave if not sp[6] else c + leave
		var al: float = sp[5] * (1.0 if not sp[6] or u < 0.5 else 1.0 - (u - 0.5) / 0.5)
		ci.draw_set_transform_matrix(base * UIA.xf(at, Vector2.ZERO, deg_to_rad(sp[4]) + deg_to_rad(-4.0 * o)))
		ci.draw_texture_rect(BURST, Rect2(at - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, al))
	# the blob and the logo land together
	var u := mu(T_LOGO - 0.39, 0.39, "bk")
	if u <= 0.0:
		ci.draw_set_transform(Vector2.ZERO)
		return
	var al := mu(T_LOGO - 0.39, 0.1, "linear")
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

## the ink wedge: a slanted band crossing the screen with a burst on its leading edge; left → right at each section's
## start (the camera's framing switches once it covers the screen), from the right at the end of the track (it covers
## the screen exactly at the wrap and uncovers the intro)
func _wedge(ci: CanvasItem, vs: Vector2) -> void:
	if wedge.is_empty(): return
	var xl: float = wedge[0] * vs.x
	var dir: int = wedge[1]
	var bw := 1.6 * vs.x
	var sl := 0.2 * vs.x
	var pts: PackedVector2Array
	if dir > 0: pts = PackedVector2Array([Vector2(xl, 0), Vector2(xl - bw, 0), Vector2(xl - bw + sl, vs.y), Vector2(xl + sl, vs.y)])
	else: pts = PackedVector2Array([Vector2(xl, 0), Vector2(xl + bw, 0), Vector2(xl + bw + sl, vs.y), Vector2(xl + sl, vs.y)])
	ci.draw_colored_polygon(pts, INK)
	var uvs := PackedVector2Array()
	for v in pts: uvs.append((v + Vector2(clock / 90.0, clock / 140.0)) / 11.0)
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, UI.dot_tile(0.07, Color.WHITE))
	if dir > 0:
		var u: float = wedge[2]
		var big: bool = wedge[3]
		var sz := (0.9 if big else 0.5) * vs.y * (1.0 if u < 1.0 else 1.0 + 0.6 * (u - 1.0))
		var al := 1.0 if u < 1.0 else 1.0 - (u - 1.0)
		var c := Vector2(xl + 0.5 * sl, 0.5 * vs.y)
		ci.draw_set_transform_matrix(UIA.xf(c, Vector2.ZERO, deg_to_rad(30.0 * u)))
		ci.draw_texture_rect(BURST, Rect2(c - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO)

## the motto above the logo, the emblem by the menu, the menu rows (one per beat), the brush cursor and the confirm card
func _prompt(ci: CanvasItem, vs: Vector2) -> void:
	var W := vs.x
	var H := vs.y
	var lx := 0.089 * W
	var o := UIA.p(outro, 0.0, 280.0, "in") if outro >= 0.0 else 0.0
	# the motto, small above the logo
	var ua := mu(T_LOGO, 1.3, "ease") * (1.0 - o) if beat.live else 0.0
	if ua > 0.0:
		var fn := UI.noto()
		var motto := "서툴지만, 물러서지 않는다"
		var fs := int(0.026 * H)
		ci.draw_string(fn, Vector2(lx + 0.02 * W * (1.0 - ua), 0.082 * H), motto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.86, 0.86, 0.9, ua))
	var fb := UI.bhs()
	var fs2 := int(0.03 * H)
	var ih := 0.052 * H
	var gap := 0.012 * H
	var y0 := 0.96 * H - items.size() * (ih + gap) + gap
	var sw0 := 0.19 * W
	# the guild's flower, small at the menu column's top right, popping with the cursor
	var ucur := 1.0 if menu_in else (mu(T_CURSOR, 0.25, "bk") if beat.live else 0.0)
	if ucur > 0.0 and o < 1.0:
		var eh := 0.16 * H
		var ew := eh * EMBLEM.get_width() / EMBLEM.get_height()
		var er := Rect2(lx + sw0 + 0.012 * W, y0 - eh * 0.1, ew, eh)
		ci.draw_set_transform_matrix(UIA.xf(er.get_center(), Vector2(0, 0.25 * H * o), 0.0, Vector2(ucur, ucur)))
		ci.draw_texture_rect(EMBLEM, er, false, Color(1, 1, 1, minf(1.0, ucur)))
		ci.draw_set_transform(Vector2.ZERO)
	item_rects.clear()
	confirm_rects.clear()
	var pulse := BEAT.bump(beat.pulse_phase(), 0.45) if intro_done else 0.0
	# the cursor: the brush stroke is the picked row's slab, sliding between rows on its spring; it slaps onto 시작
	# from 1.3× and pulses ±2 % on the pulse
	if ucur > 0.0 and o < 1.0 and not confirm:
		var bw := sw0 * 1.3
		var bh := ih * 2.3
		var cy := y0 + sp_cur.x * (ih + gap) + ih * 0.5
		var cc := Vector2(lx + 0.014 * W + sw0 * 0.5, cy)
		var psc := (1.0 + 0.02 * pulse) * (1.0 + 0.3 * (1.0 - minf(1.0, ucur)))
		ci.draw_set_transform_matrix(UIA.xf(cc, Vector2(0, 0.25 * H * o), 0.0, Vector2(psc, psc)))
		ci.draw_texture_rect(BRUSH, Rect2(cc - Vector2(bw, bh) / 2.0, Vector2(bw, bh)), false, Color(1, 1, 1, minf(1.0, ucur)))
		ci.draw_set_transform(Vector2.ZERO)
	for k in items.size():
		var u := 1.0 if menu_in else (mu(T_MENU[k], 0.4, "bk") if beat.live else 0.0)
		if u <= 0.0 or o >= 1.0:
			item_rects.append(Rect2())
			continue
		var on := k == sel and not confirm and ucur > 0.0     # until the brush slaps it, the picked row is a slab too
		var dim: bool = items[k][0] == "load" and not has_save
		var lab: String = items[k][1]
		var r := Rect2(lx + (0.014 * W if on else 0.0), y0 + k * (ih + gap), sw0, ih)
		var sc := 1.0 + (0.02 * pulse if on else 0.0)
		# the second row takes two stamps: a 0.01 W push on the beat after it lands
		var push := 0.0
		if k == 1 and not menu_in: push = 0.01 * W * sin(PI * mu(T_MENU[1] + BEAT.BEAT, 0.25, "linear"))
		ci.draw_set_transform_matrix(UIA.xf(r.get_center(), Vector2(-0.3 * W * (1.0 - u) + push, 0.25 * H * o), deg_to_rad(-3.0 * (1.0 - u)), Vector2(sc, sc)))
		if not on:
			# a white slab; the picked row rides the brush stroke instead, its label white with an ink shadow
			UI.para(ci, r.position.x, r.position.y, sw0, ih, -ih * 0.3, Color(1, 1, 1, 0.35) if dim else Color.WHITE)
		var tc := Color.WHITE if on else INK
		if dim: tc = Color(0.1, 0.1, 0.12, 0.5)
		var tp := Vector2(r.position.x + 0.022 * W, r.position.y + ih * 0.5 + fs2 * 0.36)
		if on: tp.x = r.position.x + sw0 * 0.5 - UI.text_w(fb, lab, fs2) * 0.5 + 0.01 * W    # on the stroke's thick middle
		if on: ci.draw_string(fb, tp + Vector2(1.5, 1.5), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(INK, 0.8))
		ci.draw_string(fb, tp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tc)
		ci.draw_set_transform(Vector2.ZERO)
		item_rects.append(Rect2(r.position + Vector2(-0.012 * W, 0), r.size + Vector2(0.024 * W, gap)))
	if not confirm: return
	# 시작 over a save: a black card beside the menu asks before the save goes
	var cw := 0.36 * W
	var chh := 0.2 * H
	var cr := Rect2(lx + 0.24 * W, 0.96 * H - chh, cw, chh)
	var cu := UIA.p(clock - confirm_t, 0.0, 260.0, "bk")
	ci.draw_set_transform_matrix(UIA.xf(cr.get_center(), Vector2(0, 0.08 * H * (1.0 - cu)), deg_to_rad(-2.0), Vector2(cu, cu)))
	ci.draw_colored_polygon(UI.clip(cr, [[0, 4], [100, 0], [99, 100], [1, 96]]), INK)
	ci.draw_colored_polygon(UI.clip(Rect2(cr.position.x, cr.position.y, 0.006 * W, chh), [[0, 0], [100, 0], [100, 100], [0, 100]]), PINK)
	var fn2 := UI.noto()
	var fsq := int(0.03 * H)
	ci.draw_string(fn2, Vector2(cr.position.x + 0.03 * W, cr.position.y + 0.06 * H), "저장된 진행이 있어요.", HORIZONTAL_ALIGNMENT_LEFT, -1, fsq, Color.WHITE)
	ci.draw_string(fn2, Vector2(cr.position.x + 0.03 * W, cr.position.y + 0.1 * H), "지우고 처음부터 시작할까요?", HORIZONTAL_ALIGNMENT_LEFT, -1, fsq, Color(0.8, 0.8, 0.85))
	var labs := ["새로 시작", "돌아가기"]
	for k in 2:
		var bw := 0.13 * W
		var br := Rect2(cr.position.x + 0.03 * W + k * (bw + 0.02 * W), cr.end.y - 0.07 * H, bw, 0.05 * H)
		var bon := k == confirm_sel
		UI.para(ci, br.position.x, br.position.y, bw, br.size.y, -br.size.y * 0.3, PINK if bon else Color.WHITE)
		ci.draw_string(fb, Vector2(br.position.x + 0.02 * W, br.position.y + br.size.y * 0.5 + fs2 * 0.36), labs[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color.WHITE if bon else INK)
		confirm_rects.append(br.grow(6.0))
	ci.draw_set_transform(Vector2.ZERO)
