extends Control
## Title (prototype #title) in the persona skin; the hero select is gone (a fresh game is 에스텔 alone, the seniors join in play). docs/title_storyboard.md has the beats:
## a pink band wipes in, the guild hall's front springs in and the members drop onto its steps with white cut-outs
## trailing them, the logo slabs slam and the letters of 어설픈 용맹 drop one by one, then nothing ever holds still
## (drifting halftone, travelling guide lines, a sheen over the letters, breathing people, candle windows, fog, the sign
## swinging, pointer parallax); a tap grows the pink field over the screen and the menu sweep carries it on into the town.
##
## The title grows with the save ("자라는 타이틀"): the hall is a dark cut-out over the pink sky (tinted by the world's
## clock, arena.tod_h), one window is lit per restored facility (+ Eilin's), every member in fame.rec stands on the steps
## and the guild's rank fills the steps behind them with a crowd of nameless paper silhouettes, each rimmed in its own hue.
##
## Layers: this Control (nearest filtering) draws the ground: the fields, the hall plate, its windows and sign, the crowd
## and the back fog; `sil` (UI.solid_mat) draws the people's white / ink cut-outs; `fg` draws the logo, the people,
## the front fog and the prompt with linear filtering.

const UI := preload("res://scripts/ui_kit.gd")
const DEV := preload("res://scripts/dev.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const CH := preload("res://scripts/chars.gd")
const SK := preload("res://scripts/skins.gd")
const PINK := Color("#ff3d7f")
const INK := Color("#0d0b10")
const LIT := preload("res://scripts/lit.gd")
const INTRO_END := 1500.0
const HALL := preload("res://assets/town/g_hall.png")
const HALL_WIN := preload("res://assets/town/g_hall_win.png")
const GROUND := 0.86                 # the ground line (fraction of H): the hall's foot, the people's feet
const PERSON_H := 0.46               # one common height for every standing picture, framed knee-up (fraction of H)
const FULL_CROP := 0.72              # a full-body st_full is cut to its knees (this much of its height) to match the st_base framing
const KNEE_SINK := 0.1               # the knee line sits this far below the ground line (the fog and the screen's edge hide the cut)
const HALL_TINT := Color(0.35, 0.3, 0.4)        # the hall sits behind the pink's mood: an ink cut-out with faint detail
const HALL_TINT_NIGHT := Color(0.2, 0.17, 0.27)
## the sky (the pink field) by the hour: never grey — day pink, dusk magenta, night plum
const SKY_K := [[0.0, Color("#4a1740")], [4.5, Color("#4a1740")], [6.3, Color("#c8246c")], [8.0, Color("#ff3d7f")], [16.5, Color("#ff3d7f")], [18.5, Color("#c8246c")], [20.5, Color("#4a1740")], [24.0, Color("#4a1740")]]
## the facade's windows (g_hall_win px rects) in lighting order: Eilin's first (the right wing's upper window), then one
## per restored facility
const WINS := [[548, 274, 22, 24], [474, 274, 22, 24], [152, 274, 22, 24], [78, 274, 22, 24], [386, 228, 22, 24], [238, 228, 22, 24], [314, 230, 22, 24],
	[314, 126, 22, 24], [548, 342, 22, 24], [78, 342, 22, 24], [474, 342, 22, 24], [152, 342, 22, 24], [386, 342, 22, 24], [238, 342, 22, 24]]
const SIGN := Rect2(253, 275, 142, 30)          # the CLUMSY VALOR board on the facade (g_hall px), hung from its top centre
const DOOR_X := 322.0                            # the door's centre (g_hall px)
## where the members stand: [x offset from the door in W, feet above the ground in H, parallax weight], by their place in the row
const SPOTS := [[0.015, -0.01, 1.0], [-0.105, 0.03, 0.7], [0.135, 0.03, 0.7], [-0.23, 0.05, 0.55], [0.23, 0.05, 0.55], [-0.32, 0.06, 0.45], [0.32, 0.06, 0.45]]
## guide lines: [y, length] in fractions of the viewport, period (ms), phase (ms), where the right end stops (fraction of W)
const LINES := [[0.15, 0.23, 5200.0, 0.0, 0.40], [0.47, 0.10, 6800.0, 1700.0, 0.44], [0.06, 0.17, 4400.0, 900.0, 0.30]]

var arena
var ui_root
var active := true
var t := 0.0                     # intro clock (ms)
var intro_done := false
var outro := -1.0                # outro clock, -1 = not running
var handed := false              # the sweep into the game has been started
var clock := 0.0
var trn := UIA.Tr.new()          # .card transition: transform .3s --bk, background .15s
var sil_layer: Control
var fg_layer: Control
## the picture and its white cut-out: 1 = off to the right, 0 = home (the cut-out follows a softer spring, 100 ms late)
var sp_art := UIA.Spring.new(1.0, 0.55, 0.72)
var sp_sil := UIA.Spring.new(1.0, 0.75, 0.6)
var sp_px := UIA.Spring.new(0.0, 0.9, 0.9)     # pointer parallax
var sp_py := UIA.Spring.new(0.0, 0.9, 0.9)
var sil_out := false
var slammed := false
var specks: Array = []
var drops: Array = []            # per person: [Spring drop (1 = above, 0 = home), Spring cut-out lag]
var crowd_seed: Array = []       # per crowd figure: [u (0..1 along the steps), row 0..2, kind, hue, phase]
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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	items = [["start", "시작"], ["load", "불러오기"], ["opts", "설정"]]
	if not OS.has_feature("web"): items.append(["quit", "끝내기"])
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED     # halftone tiles through polygon uvs
	for i in 2:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		c.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		if i == 0:
			c.material = UI.solid_mat()
			c.draw.connect(_draw_sil)
			sil_layer = c
		else:
			c.draw.connect(_draw_fg)
			fg_layer = c
		add_child(c)
	for i in 12:
		specks.append([randf(), randf(), 0.5 + randf() * 0.7, 2600.0 + randf() * 3000.0])

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
	var dt := minf(delta * 1000.0, 250.0)   # real time, like the prototype's CSS / rAF clocks
	clock += dt
	trn.step(dt)
	t += dt
	if not intro_done and t > INTRO_END:
		intro_done = true
	if outro < 0.0:
		if t >= 120.0: sp_art.to(0.0)
		if t >= 220.0: sp_sil.to(0.0)
	_sync_drops()
	for i in drops.size():
		if outro < 0.0 and t >= 900.0 + i * 120.0: drops[i][0].to(0.0)
		if outro < 0.0 and t >= 980.0 + i * 120.0: drops[i][1].to(0.0)
		drops[i][0].step(dt)
		drops[i][1].step(dt)
	if not slammed and t >= 1050.0 and t < 90000.0:
		slammed = true
		if arena != null: arena.sfx("slam", 0.5)
	if outro >= 0.0:
		outro += dt
		if outro >= 80.0 and not sil_out:
			sil_out = true
			sp_sil.to(1.5, 2.0)
		# the field has swallowed the screen: the menu sweep carries the pink on into the town (no hero select —
		# a fresh game is 에스텔 alone, a saved one keeps its leader)
		if outro >= 650.0 and not handed:
			handed = true
			ui_root.sweep.run(func(): _go(), PINK)
	sp_art.step(dt)
	sp_sil.step(dt)
	# parallax: the pointer (the last touch on a phone) as -1..1
	var vs := get_viewport_rect().size
	var mp := get_viewport().get_mouse_position()
	sp_px.to(clampf((mp.x / maxf(1.0, vs.x) - 0.5) * 2.0, -1.0, 1.0))
	sp_py.to(clampf((mp.y / maxf(1.0, vs.y) - 0.5) * 2.0, -1.0, 1.0))
	sp_px.step(dt)
	sp_py.step(dt)
	queue_redraw()
	sil_layer.queue_redraw()
	fg_layer.queue_redraw()


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if not active:
		return
	var tap := Vector2.INF
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		tap = ev.position
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
			arena.sfx("step", 0.4)
		elif ok: _confirm_pick(confirm_sel)
		elif back: _confirm_pick(1)
		elif tap != Vector2.INF:
			for k in confirm_rects.size():
				if confirm_rects[k].has_point(tap): _confirm_pick(k)
		return
	if up or down:
		sel = posmod(sel + (1 if down else -1), items.size())
		arena.sfx("step", 0.4)
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
				arena.sfx("ready", 0.4)
			else: _begin()
		"load":
			if has_save: _begin()
			else: arena.sfx("step", 0.2)
		"opts":
			in_opts = true
			active = false
			visible = false          # the settings page is drawn under this layer: step aside until it closes
			arena.sfx("ready", 0.4)
			ui_root.menu.open_page("opts")
		"quit":
			get_tree().quit()

func _confirm_pick(k: int) -> void:
	confirm = false
	if k == 0:
		fresh = true
		_begin()
	else: arena.sfx("step", 0.3)

## the outro: the logo leaves, the field grows, the sweep carries on into the game
func _begin() -> void:
	outro = 0.0
	sp_art.to(1.5, 1.5)
	for d in drops: d[0].to(0.0, 0.6)           # the people hop as they leave right
	arena.sfx("parry", 1.0)

## the logo settles at once (a tap during the intro)
func _finish_intro() -> void:
	intro_done = true
	t = 99999.0
	slammed = true
	sp_art.snap(0.0)
	sp_sil.snap(0.0)
	_sync_drops()
	for d in drops:
		d[0].snap(0.0)
		d[1].snap(0.0)

func _go() -> void:
	active = false
	visible = false
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
## the pink field's edge x at the top and the bottom (home: 44 % / 64 % of the width), with the intro wipe, the breathing
## and the outro growth
func _field(vs: Vector2) -> Array:
	var sh := 0.0
	if outro >= 0.0:
		sh = -(0.64 * vs.x + 0.12 * vs.x) * UI.bez(0.6, 0.0, 0.9, 0.4, (outro - 150.0) / 500.0)
	else:
		sh = (0.7 * vs.x) * (1.0 - UI.bez(0.3, 0.6, 0.3, 1.0, t / 380.0))
	sh += sin(clock / 7000.0 * TAU) * 6.0 + sp_px.x * 4.0
	return [0.44 * vs.x + sh, 0.64 * vs.x + sh]

# ---------- what the save shows ----------
func _fame():
	return arena.fame if arena != null and "fame" in arena else null

## the members on the steps: everyone in fame.rec, 에스텔 first (a fresh game: her alone)
func people() -> Array:
	var F = _fame()
	var out: Array = ["estelle"]
	if F != null and "rec" in F:
		for c in F.rec:
			if not out.has(c): out.append(c)
	return out

## windows lit on the facade: Eilin's and one per restored facility
func lit_windows() -> int:
	var F = _fame()
	var n := 1
	if F != null and "fac" in F: n += F.fac.size()
	return mini(n, WINS.size())

## the nameless crowd behind them: three per rank above the first, at most 18
func crowd_n() -> int:
	var F = _fame()
	var r: int = F.rank() if F != null and F.has_method("rank") else 1
	return mini(18, maxi(0, r - 1) * 3)

## the hour the sky is painted for
func hour() -> float:
	return fposmod(arena.tod_h, 24.0) if arena != null and "tod_h" in arena else 12.0

## the sky colour by the hour (SKY_K, piecewise)
func sky(h: float) -> Color:
	for i in SKY_K.size() - 1:
		if h <= SKY_K[i + 1][0]:
			var u: float = (h - SKY_K[i][0]) / (SKY_K[i + 1][0] - SKY_K[i][0])
			return (SKY_K[i][1] as Color).lerp(SKY_K[i + 1][1], UIA.ez("ease-in-out", clampf(u, 0.0, 1.0)))
	return PINK

## how deep the night is (0 day .. 1 night): the hall darker, the windows brighter
func night() -> float:
	var h := hour()
	return clampf((h - 17.0) / 3.5, 0.0, 1.0) if h >= 12.0 else clampf(1.0 - (h - 4.5) / 3.0, 0.0, 1.0)

func _sync_drops() -> void:
	var n := people().size()
	while drops.size() < n: drops.append([UIA.Spring.new(1.0, 0.5, 0.7), UIA.Spring.new(1.0, 0.7, 0.55)])
	while drops.size() > n: drops.pop_back()
	var m := crowd_n()
	while crowd_seed.size() < m:
		var i := crowd_seed.size()
		var rs := RandomNumberGenerator.new()
		rs.seed = 7919 * (i + 1)
		crowd_seed.append([rs.randf(), i % 3, rs.randi_range(0, 3), fposmod(i * 47.0 + 20.0, 360.0), rs.randf() * TAU])
	while crowd_seed.size() > m: crowd_seed.pop_back()

## the hall plate's home rect: right-aligned, its foot on the ground line, ~0.78 H tall (narrower screens: ~0.6 W wide)
func _hall_rect(vs: Vector2) -> Rect2:
	var sc := minf(0.78 * vs.y / HALL.get_height(), 0.6 * vs.x / HALL.get_width())
	var w := HALL.get_width() * sc
	var h := HALL.get_height() * sc
	return Rect2(vs.x - 0.015 * vs.x - w, GROUND * vs.y - h, w, h)

## member i's standing picture, its rect and the source region: one common knee-up height, the knee line just under the ground line
func _person(vs: Vector2, i: int, c: String) -> Array:
	var tex := SK.tex(c, "st_full")
	var src := Rect2()
	if tex != null: src = Rect2(0, 0, tex.get_width(), tex.get_height() * FULL_CROP)
	else:
		tex = SK.tex(c, "st_base")
		if tex == null: return [null, Rect2(), Rect2()]
		src = Rect2(0, 0, tex.get_width(), tex.get_height())
	var sp: Array = SPOTS[mini(i, SPOTS.size() - 1)]
	var hr := _hall_rect(vs)
	var h := PERSON_H * vs.y
	var w := h * src.size.x / src.size.y
	var cx: float = hr.position.x + DOOR_X * (hr.size.x / HALL.get_width()) + sp[0] * vs.x
	var fy: float = (GROUND - sp[1] + KNEE_SINK) * vs.y
	return [tex, Rect2(cx - w / 2.0, fy - h, w, h), src]

## member i's motion: [translation, rotation, scale] from its drop spring value (1 = above), the breathing, the parallax
## and the outro exit; `par` scales the parallax, `lag` is the cut-out's extra share of the drop
func _person_motion(vs: Vector2, i: int, s: float, par: float) -> Array:
	var sp: Array = SPOTS[mini(i, SPOTS.size() - 1)]
	var ph := i * 1.7
	var br := 0.5 - 0.5 * cos(clock / (3400.0 + i * 310.0) * TAU + ph)
	var tr: Vector2 = Vector2(0, -0.3 * vs.y * s) + Vector2(sp_px.x, sp_py.x) * Vector2(11.0, 5.0) * float(sp[2]) * par
	tr.y -= 2.5 * br
	if outro >= 0.0: tr.x += 0.7 * vs.x * UIA.p(outro, 40.0 + i * 40.0, 480.0, "in")
	return [tr, deg_to_rad(-2.0 * s), Vector2(1.0 - 0.004 * br, 1.0 + 0.007 * br)]

## the hall's motion: [translation, rotation (rad), scale] for a spring value (1 = off right) and a parallax weight;
## at home it breathes a hair (1.0 ↔ 1.004) and follows the pointer less than the people
func _art_motion(vs: Vector2, s: float, par: float) -> Array:
	var tr := Vector2(0.5 * vs.x * s, 0) + Vector2(sp_px.x, sp_py.x) * Vector2(4.0, 2.0) * par
	var br := 0.004 * (0.5 - 0.5 * cos(clock / 5200.0 * TAU))
	return [tr, deg_to_rad(-3.0 * s), 1.0 + 0.06 * s + br]

## the logo block's breathing and the slam jolt
func _logo_xf(vs: Vector2) -> Transform2D:
	var br := 1.0 + 0.006 * (0.5 - 0.5 * cos(clock / 4200.0 * TAU))
	var j := Vector2.ZERO
	if t >= 1050.0 and t < 1210.0:
		var k: Array = UIA.kf(t - 1050.0, [[0.0, [0.0, 0.0]], [0.3, [-3.0, -1.5]], [0.65, [2.0, 0.0]], [1.0, [0.0, 0.0]]], 160.0)
		j = Vector2(k[0], k[1])
	var piv := Vector2(0.25 * vs.x, 0.5 * vs.y)
	return UIA.xf(piv, j, 0.0, Vector2(br, br))

## how far a logo piece has left in the outro (0..1), i = its place in the stagger
func _out(i: int) -> float:
	if outro < 0.0: return 0.0
	return UIA.p(outro, i * 40.0, 280.0, "in")


# ---------- draw: ground ----------
func _draw() -> void:
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), INK)
	# faint white halftone over the black, drifting
	var scr := Vector2(clock / 90.0, clock / 140.0)
	_tiled(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]), UI.dot_tile(0.07, Color.WHITE), scr)
	# the pink field with its dark halftone (the drift eases out in the outro so the select screen's fixed dots take over)
	var f := _field(vs)
	var nk := night()
	# (the first wipe frames put both edges past the right side: no polygon then, a clamped one while only the top is)
	var pts := PackedVector2Array([Vector2(minf(f[0], vs.x), 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(minf(f[1], vs.x), vs.y)])
	if minf(f[0], f[1]) < vs.x - 0.5:
		# the sky: the field in the hour's pink, eased to the plain pink as the outro grows it (the sweep's colour)
		draw_colored_polygon(pts, sky(hour()).lerp(PINK, UIA.p(outro, 150.0, 500.0, "ease") if outro >= 0.0 else 0.0))
		var k := 1.0 - UIA.p(outro, 150.0, 500.0, "ease") if outro >= 0.0 else 1.0
		_tiled(pts, UI.dot_tile(0.24), Vector2(-clock / 120.0, clock / 170.0) * k)
	_hall(vs, nk)
	_crowd(vs)
	_fog(self, vs, 0)
	# white specks rising through the pink
	for s in specks:
		var y: float = fposmod(s[1] - clock / s[3], 1.0) * vs.y
		var x: float = vs.x * (0.42 + 0.6 * s[0]) + sin(clock / 1900.0 + s[1] * 7.0) * 6.0
		var edge: float = lerpf(f[0], f[1], y / vs.y)
		if x > edge + 12.0 and x < vs.x - 4.0:
			var r: float = 1.5 + 1.5 * s[2]
			draw_rect(Rect2(x - r, y - r, r * 2.0, r * 2.0), Color(1, 1, 1, 0.5 * s[2]))
	# guide lines: travel in, stop on the logo, leave
	var ox := vs.x * UIA.p(outro, 0.0, 400.0, "in") if outro >= 0.0 else 0.0
	for L in LINES:
		var ln: float = L[1] * vs.x
		var ph: float = fmod(clock + L[3], L[2]) / L[2]
		var stop: float = L[4] * vs.x - ln
		var x: float
		if ph < 0.42: x = lerpf(-ln - 20.0, stop, UIA.ez("mv", ph / 0.42))
		elif ph < 0.62: x = stop
		else: x = lerpf(stop, vs.x + 20.0, UIA.ez("in", (ph - 0.62) / 0.38))
		draw_rect(Rect2(x + ox, L[0] * vs.y, ln, 2.0), Color(1, 1, 1, 0.6))
## the hall plate: the facade as an ink cut-out (HALL_TINT, deeper at night) sliding in on sp_art, the sign swinging on
## its bracket, and the lit windows (candle flicker, a soft glow behind each)
func _hall(vs: Vector2, nk: float) -> void:
	if outro > 1050.0: return
	var a := clampf((t - 120.0) / 150.0, 0.0, 1.0)
	if a <= 0.0: return
	var r := _hall_rect(vs)
	var sc := r.size.x / HALL.get_width()
	var m: Array = _art_motion(vs, sp_art.x, 1.0)
	var piv := Vector2(r.get_center().x, r.end.y)
	var base := UIA.xf(piv, m[0], m[1], Vector2(m[2], m[2]))
	draw_set_transform_matrix(base)
	var tint := HALL_TINT.lerp(HALL_TINT_NIGHT, nk)
	draw_texture_rect(HALL, r, false, Color(tint, a))
	# the sign, hung from its top centre, swinging ±2°
	var sw := deg_to_rad(2.0) * sin(clock / 2300.0 * TAU)
	var sp := Vector2(r.position.x + (SIGN.position.x + SIGN.size.x / 2.0) * sc, r.position.y + SIGN.position.y * sc)
	draw_set_transform_matrix(base * UIA.xf(sp, Vector2.ZERO, sw, Vector2(1.06, 1.06)))
	draw_texture_rect_region(HALL, Rect2(r.position + SIGN.position * sc, SIGN.size * sc), SIGN, Color(tint, a))
	draw_set_transform_matrix(base)
	# the windows: one per restored facility and Eilin's, warm, each a candle
	var n := lit_windows()
	var warm := Color(1.0, 0.86, 0.6)
	var ts := clock / 1000.0
	for i in n:
		var w: Array = WINS[i]
		var wr := Rect2(r.position + Vector2(w[0], w[1]) * sc, Vector2(w[2], w[3]) * sc)
		var fl := 0.9 + 0.1 * LIT.fl(ts, i * 2.3)
		var g := wr.grow(wr.size.y * (0.9 + 0.6 * nk))
		draw_texture_rect(UI.glow(), g, false, Color(warm, (0.14 + 0.22 * nk) * fl * a))
		draw_texture_rect_region(HALL_WIN, wr, Rect2(w[0], w[1], w[2], w[3]), Color(warm * (0.85 + 0.15 * fl), a))
	draw_set_transform(Vector2.ZERO)

## the nameless members: paper cut-out silhouettes on the steps behind the people, flat ink, each with a thin rim in
## its own hue (same saturation and value: a crowd of colours), in three rows that drift a hair
func _crowd(vs: Vector2) -> void:
	if outro > 1050.0 or crowd_seed.is_empty(): return
	var a := clampf((t - 700.0) / 300.0, 0.0, 1.0)
	if a <= 0.0: return
	var hr := _hall_rect(vs)
	var m: Array = _art_motion(vs, sp_art.x, 1.4)
	var piv := Vector2(hr.get_center().x, hr.end.y)
	var base := UIA.xf(piv, m[0], m[1], Vector2(m[2], m[2]))
	var order := crowd_seed.duplicate()
	order.sort_custom(func(p, q): return p[1] > q[1])       # back rows first
	for cs in order:
		var row: int = cs[1]
		var x: float = hr.position.x + hr.size.x * (-0.02 + 1.04 * cs[0])
		var fy: float = GROUND * vs.y - (0.02 + 0.03 * row) * vs.y
		var h: float = (0.21 - 0.025 * row) * vs.y
		var bob := sin(clock / 2900.0 * TAU + cs[4]) * 1.2
		var drop := 1.0 - UIA.p(t, 700.0 + row * 90.0, 420.0, "bk")
		var xf := base * Transform2D(0.0, Vector2(x, fy + bob - 0.1 * vs.y * drop))
		var rim := Color.from_hsv(cs[3] / 360.0, 0.7, 0.95)
		_figure(xf, h, cs[2], Color(rim, a), 1.0 + 2.2 / h)
		_figure(xf, h, cs[2], Color(INK, a), 1.0)
	draw_set_transform(Vector2.ZERO)

## one paper figure (feet at the origin, `h` tall): kind 0 plain, 1 pointed hat, 2 hood, 3 a staff
func _figure(xf: Transform2D, h: float, kind: int, col: Color, grow: float) -> void:
	draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(grow, grow), 0.0, Vector2.ZERO))
	var sw := h * 0.17
	var bh := h * 0.72
	var body := PackedVector2Array([Vector2(-sw, 0), Vector2(sw, 0), Vector2(sw * 0.95, -bh * 0.55), Vector2(sw * 1.25, -bh * 0.8),
		Vector2(sw * 0.55, -bh), Vector2(-sw * 0.55, -bh), Vector2(-sw * 1.25, -bh * 0.8), Vector2(-sw * 0.95, -bh * 0.55)])
	draw_colored_polygon(body, col)
	var hr := h * 0.11
	var hc := Vector2(0, -bh - hr * 0.9)
	draw_circle(hc, hr, col)
	match kind:
		1: draw_colored_polygon(PackedVector2Array([hc + Vector2(-hr * 1.4, -hr * 0.3), hc + Vector2(hr * 1.4, -hr * 0.3), hc + Vector2(hr * 0.2, -hr * 3.2)]), col)
		2: draw_colored_polygon(PackedVector2Array([hc + Vector2(-hr * 1.3, hr * 0.8), hc + Vector2(-hr * 1.1, -hr * 1.3), hc + Vector2(0, -hr * 1.6), hc + Vector2(hr * 1.1, -hr * 1.3), hc + Vector2(hr * 1.3, hr * 0.8)]), col)
		3: draw_rect(Rect2(sw * 1.15, -h * 1.02, h * 0.025, h * 1.02), col)

## drifting fog bands across the lower screen (layer 0 behind the people, 1 in front): soft blobs stretched wide,
## in the sky's whitened pink, thicker when the steps are still empty
func _fog(ci: CanvasItem, vs: Vector2, layer: int) -> void:
	if outro > 1050.0: return
	var a := clampf((t - 400.0) / 600.0, 0.0, 1.0) * (1.0 if people().size() <= 1 else 0.5)
	if a <= 0.0: return
	var tx := LIT.soft_tex()
	var col := sky(hour()).lerp(Color.WHITE, 0.75)
	var ts := clock / 1000.0
	var bands: Array = [[0.84, 0.2, 7.0, 0.0], [0.93, 0.16, 11.0, 300.0]] if layer == 0 else [[0.9, 0.1, 5.0, 150.0]]
	for b in bands:
		var bw := 0.72 * vs.x
		var off := fmod(ts * b[2] + b[3], bw)
		var x := -bw + off
		var cy: float = b[0] * vs.y + sin(ts * 0.3 + b[3]) * 4.0
		while x < vs.x + bw:
			ci.draw_texture_rect(tx, Rect2(x - bw * 0.5, cy - 0.11 * vs.y, bw, 0.22 * vs.y), false, Color(col, b[1] * a))
			x += bw * 0.5
	ci.draw_set_transform(Vector2.ZERO)

## a polygon filled with a repeating 11 px tile (uv = position / 11, scrolled)
func _tiled(pts: PackedVector2Array, tex: Texture2D, scroll: Vector2) -> void:
	var uvs := PackedVector2Array()
	for v in pts: uvs.append((v + scroll) / 11.0)
	draw_colored_polygon(pts, Color.WHITE, uvs, tex)


# ---------- draw: silhouettes ----------
func _draw_sil() -> void:
	if not active or outro > 1050.0: return
	var ci := sil_layer
	var vs := get_viewport_rect().size
	var P := people()
	for i in P.size():
		if i >= drops.size(): break
		var pr: Array = _person(vs, i, P[i])
		var tex: Texture2D = pr[0]
		if tex == null: continue
		var r: Rect2 = pr[1]
		var a := clampf((t - 980.0 - i * 120.0) / 150.0, 0.0, 1.0)
		if a <= 0.0: continue
		var piv := Vector2(r.get_center().x, r.end.y)
		# the white cut-out, on its own lagging spring (and the outro's trailing sp_sil)
		var m: Array = _person_motion(vs, i, drops[i][1].x, 1.6)
		var tr: Vector2 = m[0] + Vector2(0.022 * vs.x, 0.014 * vs.y) + Vector2(0.4 * vs.x * sp_sil.x if sil_out else 0.0, 0)
		ci.draw_set_transform_matrix(UIA.xf(piv, tr, m[1], m[2]))
		ci.draw_texture_rect_region(tex, r, pr[2], Color(1, 1, 1, a))
		# the thin ink copy, glued to the picture
		var m2: Array = _person_motion(vs, i, drops[i][0].x, 1.0)
		ci.draw_set_transform_matrix(UIA.xf(piv, m2[0] + Vector2(-0.004 * vs.x, 0.004 * vs.y), m2[1], m2[2]))
		ci.draw_texture_rect_region(tex, r, pr[2], Color(INK, a))
	ci.draw_set_transform(Vector2.ZERO)


# ---------- draw: picture, logo, prompt ----------
func _draw_fg() -> void:
	if not active or outro > 1050.0: return
	var ci := fg_layer
	var vs := get_viewport_rect().size
	_logo(ci, vs)          # under the people: the bars sweep in from behind them
	_people(ci, vs)
	_fog(ci, vs, 1)
	_tag(ci, vs)           # the -ASSEMBLE- stamp lands over whoever stands at the hall's left
	_prompt(ci, vs)
	# the white slash as the tag stamps (cx_flash)
	if t >= 1050.0 and t < 1430.0:
		var u := UIA.p(t, 1050.0, 380.0, "mv")
		var fr := Rect2(-0.2 * vs.x, vs.y * 0.5, vs.x * 1.4, 0.05 * vs.y)
		var fm := UIA.xf(fr.get_center(), Vector2(lerpf(-1.2, 1.2, u) * fr.size.x, 0), deg_to_rad(-12.0))
		ci.draw_colored_polygon(fm * UI.clip(fr, [[0, 45], [100, 0], [100, 25], [0, 100]]), Color.WHITE)
	if not DEV.on or arena == null: return   # the build stamp: debug builds only (dev.gd)
	var ver: String = arena._stamp()
	var sf := UI.spaced(UI.noto(), 1)
	ci.draw_string(sf, Vector2(vs.x - 12.0 - UI.text_w(sf, ver, 11), vs.y - 12.0), ver, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

## the members on the steps: each drops in on its spring (120 ms apart after the hall settles), dark until it lands,
## then breathes and follows the pointer (front more than back)
func _people(ci: CanvasItem, vs: Vector2) -> void:
	if outro > 1050.0: return
	var P := people()
	var order := range(P.size())
	order.reverse()                                  # the back of the row first, 에스텔 (0) on top
	for i in order:
		if i >= drops.size(): break
		var pr: Array = _person(vs, i, P[i])
		var tex: Texture2D = pr[0]
		if tex == null: continue
		var r: Rect2 = pr[1]
		var t0: float = 900.0 + i * 120.0
		var a := clampf((t - t0) / 150.0, 0.0, 1.0)
		if a <= 0.0: continue
		var lit: float = UIA.kf(t, [[0.0, 0.0], [0.45, 0.0], [0.6, 1.0], [1.0, 1.0]], 600.0, t0)
		var m: Array = _person_motion(vs, i, drops[i][0].x, 1.0)
		ci.draw_set_transform_matrix(UIA.xf(Vector2(r.get_center().x, r.end.y), m[0], m[1], m[2]))
		ci.draw_texture_rect_region(tex, r, pr[2], Color(lit, lit, lit, a))
	ci.draw_set_transform(Vector2.ZERO)

## CLUMSY VALOR slab, 어설픈 / 용맹 with their bars, the -ASSEMBLE- tag
func _logo(ci: CanvasItem, vs: Vector2) -> void:
	var W := vs.x
	var H := vs.y
	var lx := 0.067 * W
	var base := _logo_xf(vs)
	# 1) CLUMSY VALOR: black Anton on a white slab, sliding in from the left
	var u1 := UIA.p(t, 380.0, 420.0, "bk")
	var o1 := _out(0)
	if u1 > 0.0 and o1 < 1.0:
		var af := UI.anton(true, 1)
		var s := "CLUMSY VALOR"
		var fs := int(0.078 * H)
		var sh := 0.092 * H
		var tw := UI.text_w(af, s, fs)
		var sw := tw + 0.05 * W
		var c := Vector2(lx + sw / 2.0, 0.13 * H + sh / 2.0)
		var sc := 1.0 + 0.15 * (1.0 - u1)
		ci.draw_set_transform_matrix(base * UIA.xf(c, Vector2(-0.4 * W * (1.0 - u1) - 0.7 * W * o1, 0), deg_to_rad(-2.0 - 7.0 * (1.0 - u1) - 6.0 * o1), Vector2(sc, sc)))
		UI.para(ci, c.x - sw / 2.0, c.y - sh / 2.0, sw, sh, sh * 0.16, Color.WHITE)
		ci.draw_string(af, Vector2(c.x - tw / 2.0 + sh * 0.08, c.y + fs * 0.38), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK)
	# 2) 어설픈: white with a pink copy behind, a back-leaning pink bar through its lower third
	var by := 0.23 * H
	var fs1 := int(0.23 * H)
	var o2 := _out(1)
	_bar(ci, base, Rect2(lx - 0.017 * W, by + 0.118 * H, 0.36 * W, 0.054 * H), PINK, UIA.p(t, 700.0, 350.0, "mv"), -1.0, _out(2))
	_word(ci, base, "어설픈", fs1, Vector2(lx - 0.7 * W * o2, by + fs1 * 0.86), Color.WHITE, PINK, 520.0, 0, o2)
	# 3) 용맹: pink with a black copy, a white bar
	var by2 := 0.48 * H
	var fs2 := int(0.25 * H)
	var o3 := _out(3)
	_bar(ci, base, Rect2(lx + 0.067 * W, by2 + 0.12 * H, 0.32 * W, 0.056 * H), Color.WHITE, UIA.p(t, 940.0, 350.0, "mv"), 1.0, _out(4))
	_word(ci, base, "용맹", fs2, Vector2(lx + 0.078 * W - 0.7 * W * o3, by2 + fs2 * 0.86), PINK, INK, 760.0, 3, o3)
	ci.draw_set_transform(Vector2.ZERO)

## the -ASSEMBLE- tag stamps in (over the people)
func _tag(ci: CanvasItem, vs: Vector2) -> void:
	if outro > 1050.0: return
	var W := vs.x
	var H := vs.y
	var base := _logo_xf(vs)
	var u4 := UIA.p(t, 1050.0, 380.0, "bk")
	var o4 := _out(5)
	if u4 > 0.0 and o4 < 1.0:
		var af2 := UI.anton(true, 7)
		var s2 := "-ASSEMBLE-"
		var fs4 := int(0.046 * H)
		var th := 0.062 * H
		var tw2 := UI.text_w(af2, s2, fs4)
		var tww := tw2 + 0.04 * W
		var c2 := Vector2(0.378 * W + tww / 2.0, 0.68 * H + th / 2.0)
		var sc2 := 1.0 + 1.4 * (1.0 - u4)
		var ta := clampf((t - 1050.0) / 60.0, 0.0, 1.0)
		ci.draw_set_transform_matrix(base * UIA.xf(c2, Vector2(-0.7 * W * o4, 0), deg_to_rad(-2.0 - 12.0 * (1.0 - u4) - 5.0 * o4), Vector2(sc2, sc2)))
		UI.para(ci, c2.x - tww / 2.0 + 5.0, c2.y - th / 2.0 + 5.0, tww, th, th * 0.3, Color(1, 1, 1, 0.9 * ta))
		UI.para(ci, c2.x - tww / 2.0, c2.y - th / 2.0, tww, th, th * 0.3, Color(PINK, ta))
		ci.draw_string(af2, Vector2(c2.x - tw2 / 2.0 + th * 0.12, c2.y + fs4 * 0.37), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs4, Color(1, 1, 1, ta))
	ci.draw_set_transform(Vector2.ZERO)

## a back-leaning bar behind a word, sweeping in from side `d` (-1 left / 1 right)
func _bar(ci: CanvasItem, base: Transform2D, r: Rect2, col: Color, u: float, d: float, o: float) -> void:
	if u <= 0.0 or o >= 1.0: return
	var c := r.get_center()
	ci.draw_set_transform_matrix(base * UIA.xf(c, Vector2(d * 0.5 * get_viewport_rect().size.x * (1.0 - u) - 0.7 * get_viewport_rect().size.x * o, 0), deg_to_rad(-2.3)))
	UI.para(ci, r.position.x, r.position.y, r.size.x, r.size.y, -r.size.y * 0.35, col)

## a word in Black Han Sans, slanted, each glyph dropping in with squash (step 90 ms) and an offset copy behind that
## lags it; `si` is the glyph's place in the sheen that runs across both words every 3.6 s
func _word(ci: CanvasItem, base: Transform2D, s: String, fs: int, at: Vector2, col: Color, back: Color, t0: float, si: int, o: float) -> void:
	if o >= 1.0: return
	var f := UI.bhs()
	var rot := deg_to_rad(-2.5)
	var dir := Vector2(cos(rot), sin(rot))
	var bo := Vector2(0.052, 0.044) * fs
	var sh := fmod(clock, 3600.0) / 3600.0
	var sg := lerpf(-1.5, 6.5, sh / 0.45) if sh < 0.45 else -9.0
	var x := 0.0
	for i in s.length():
		var ch := s.substr(i, 1)
		var gw := UI.text_w(f, ch, fs)
		var tt := t - t0 - i * 90.0
		var la := clampf(tt / 120.0, 0.0, 1.0)
		if la > 0.0:
			var u := UIA.ez("bk", tt / 520.0)
			var sx: float = UIA.kf(tt, [[0.0, 0.8], [0.55, 1.08], [1.0, 1.0]], 520.0)
			var sy: float = UIA.kf(tt, [[0.0, 1.3], [0.55, 0.94], [1.0, 1.0]], 520.0)
			var dy := -0.16 * get_viewport_rect().size.y * (1.0 - u) + 0.1 * fs * o
			var piv := at + dir * (x + gw / 2.0) + Vector2(0, dy)
			ci.draw_set_transform_matrix(base * Transform2D(rot, piv) * Transform2D(Vector2(sx, 0), Vector2(-0.12 * sx, sy), Vector2.ZERO))
			var lag := Vector2(0.06 * fs * (1.0 - u), 0.03 * fs * (1.0 - u))
			ci.draw_string(f, Vector2(-gw / 2.0, 0) + bo + lag, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(back, la))
			ci.draw_string(f, Vector2(-gw / 2.0, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, la))
			var gl := maxf(0.0, 1.0 - absf(float(si + i) - sg)) * 0.7
			if gl > 0.0 and tt > 520.0:
				ci.draw_string(f, Vector2(-gw / 2.0, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, gl))
		x += gw
	ci.draw_set_transform(Vector2.ZERO)

## the tagline and the 탭하여 입장 slab (pulsing once the intro has settled)
func _prompt(ci: CanvasItem, vs: Vector2) -> void:
	var W := vs.x
	var H := vs.y
	var lx := 0.089 * W
	var o := UIA.p(outro, 0.0, 280.0, "in") if outro >= 0.0 else 0.0
	# the motto, top left, under the travelling guide line
	var ua := UIA.p(t, 1250.0, 400.0, "ease") * (1.0 - o)
	if ua > 0.0:
		var fn := UI.noto()
		var motto := "서툴지만, 물러서지 않는다"
		var fs := int(0.026 * H)
		ci.draw_string(fn, Vector2(lx + 0.02 * W * (1.0 - ua), 0.085 * H), motto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.78, 0.78, 0.82, ua))
	# the menu: four slabs, each sliding in 70 ms after the one above; the picked one is pink, pushed right and a touch bigger
	item_rects.clear()
	confirm_rects.clear()
	var fb := UI.bhs()
	var fs2 := int(0.03 * H)
	var ih := 0.052 * H
	var gap := 0.012 * H
	var y0 := 0.96 * H - items.size() * (ih + gap) + gap
	var pulse := UIA.pulse(clock, 1400.0) if intro_done else 0.0
	for k in items.size():
		var u := UIA.p(t, 1250.0 + k * 70.0, 400.0, "bk")
		if u <= 0.0 or o >= 1.0:
			item_rects.append(Rect2())
			continue
		var on := k == sel and not confirm
		var dim: bool = items[k][0] == "load" and not has_save
		var lab: String = items[k][1]
		var sw := 0.19 * W
		var r := Rect2(lx + (0.014 * W if on else 0.0), y0 + k * (ih + gap), sw, ih)
		var sc := 1.0 + (0.04 * pulse if on else 0.0)
		ci.draw_set_transform_matrix(UIA.xf(r.get_center(), Vector2(-0.3 * W * (1.0 - u), 0.25 * H * o), deg_to_rad(-3.0 * (1.0 - u)), Vector2(sc, sc)))
		var bg := PINK.lerp(Color("#ff7aa8"), pulse) if on else Color.WHITE
		if dim: bg = Color(1, 1, 1, 0.35)
		UI.para(ci, r.position.x, r.position.y, sw, ih, -ih * 0.3, bg)
		if on:
			# a black tick on the left, the persona "you are here"
			UI.para(ci, r.position.x - 0.012 * W, r.position.y + ih * 0.2, 0.006 * W, ih * 0.6, -ih * 0.18, INK)
		var tc := Color.WHITE if on else INK
		if dim: tc = Color(0.1, 0.1, 0.12, 0.5)
		ci.draw_string(fb, Vector2(r.position.x + 0.022 * W, r.position.y + ih * 0.5 + fs2 * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tc)
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
