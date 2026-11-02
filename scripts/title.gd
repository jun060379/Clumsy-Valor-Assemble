extends Control
## Title (prototype #title) in the persona skin; the hero select is gone (a fresh game is 에스텔 alone, the seniors join in play). docs/title_storyboard.md has the beats:
## a pink band wipes in, the painted guild hall springs in and the members drop onto its steps with white cut-outs
## trailing them, paint splats pop and the brush logo lands on its blob, then nothing ever holds still (drifting
## halftone, travelling guide lines, breathing people, candle windows, lanterns, chimney smoke, fog, the sign swinging,
## pointer parallax); 시작 bursts from the logo, the pink field grows over the screen and the sweep carries it into the town.
##
## The title grows with the save ("자라는 타이틀"): the hall sits in the pink sky (tinted by the world's clock,
## arena.tod_h), its lights come on one per restored facility (a 7-step ladder: windows, lanterns, the door's crack,
## chimney smoke), every member in fame.rec stands on the steps and the guild's rank fills the steps behind them with a
## crowd of nameless paper silhouettes, each rimmed in its own hue.
##
## Layers: this Control (nearest filtering) draws the ground: the fields, the specks and the guide lines; `bg` (linear)
## draws the hall plate with its lights and sign, the emblem watermark, the crowd and the back fog; `sil` (UI.solid_mat)
## draws the people's white / ink cut-outs; `fg` draws the logo, the people, the front fog, the menu and the burst.

const UI := preload("res://scripts/ui_kit.gd")
const DEV := preload("res://scripts/dev.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const CH := preload("res://scripts/chars.gd")
const SK := preload("res://scripts/skins.gd")
const PINK := Color("#ff3d7f")
const INK := Color("#0d0b10")
const LIT := preload("res://scripts/lit.gd")
const INTRO_END := 1500.0
const HALL := preload("res://assets/title/hall.png")      # the painted plate (1920×1088; the ground is its y 1000, the grass lies under it)
const LOGO := preload("res://assets/title/logo.png")      # Clumsy Valor / 어설픈 용맹 / Assemble, brush
const BLOB := preload("res://assets/title/blob.png")      # the pink blob the logo lands on
const BRUSH := preload("res://assets/title/brush.png")    # the menu cursor
const BURST := preload("res://assets/title/burst.png")    # 시작's burst, and the intro's small splats
const EMBLEM := preload("res://assets/title/emblem.png")  # the guild's flower
const GROUND := 0.86                 # the ground line (fraction of H): the hall's foot, the people's feet
const PERSON_H := 0.38               # one common height for every standing picture, framed knee-up (fraction of H)
const FULL_CROP := 0.72              # a full-body st_full is cut to its knees (this much of its height) to match the st_base framing
const KNEE_SINK := 0.1               # the knee line sits this far below the ground line (the fog and the screen's edge hide the cut)
const HALL_NIGHT := Color(0.5, 0.43, 0.72)      # the plate keeps its own colours by day and cools toward violet at night
## the sky (the pink field) by the hour: never grey — day pink, dusk magenta, night plum
const SKY_K := [[0.0, Color("#4a1740")], [4.5, Color("#4a1740")], [6.3, Color("#c8246c")], [8.0, Color("#ff3d7f")], [16.5, Color("#ff3d7f")], [18.5, Color("#c8246c")], [20.5, Color("#4a1740")], [24.0, Color("#4a1740")]]
## the plate's features (hall.png px)
const HALL_GROUND := 1000.0                      # the plate's row that stands on the ground line
const HALL_TOP := 90.0                           # the spire's tip (the building is HALL_GROUND - HALL_TOP tall)
const WIN_R := Rect2(1348, 660, 117, 122)        # the right wing's panes (Eilin's)
const WIN_L := Rect2(432, 660, 116, 122)         # the left wing's panes
const LANT_DOOR := Vector2(1103, 722)            # the lantern by the door (its glass)
const LANT_R := Vector2(1776, 715)               # the lantern on the right bracket
const DOOR_CRACK := Rect2(931, 652, 8, 210)      # the seam between the door's leaves
const CHIM_L := Vector2(340, 170)                # the chimney tops
const CHIM_R := Vector2(1510, 172)
const SIGN := Rect2(56, 616, 120, 150)           # the board hanging from the left bracket (with its chains)
const SIGN_PIV := Vector2(116, 600)              # where it hangs from
const DOOR_X := 935.0                            # the door's centre
const LIGHT_STEPS := 7                           # the light ladder: right window, left window, door lantern, bracket lantern, door crack, left smoke, right smoke
## where the members stand: [x offset from the door in W, feet above the ground in H, parallax weight], by their place in the row
const SPOTS := [[0.0, -0.01, 1.0], [-0.115, 0.03, 0.7], [0.12, 0.03, 0.7], [-0.23, 0.05, 0.55], [0.23, 0.05, 0.55], [-0.32, 0.06, 0.45], [0.32, 0.06, 0.45]]
## the intro's three paint splats behind the logo: [x, y] in logo-rect fractions, scale (of the logo width), rotation (deg), t0 (ms)
const SPLATS := [[0.18, 0.3, 0.3, 25.0, 420.0], [0.8, 0.22, 0.22, -70.0, 510.0], [0.55, 0.85, 0.26, 140.0, 600.0]]
const EMBLEM_WATERMARK := false                   # the flower: a faint large watermark behind the people (false: small by the menu)
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
var bg_layer: Control
var sil_layer: Control
var fg_layer: Control
var sp_cur := UIA.Spring.new(0.0, 0.3, 0.8)    # the menu cursor's row (the brush slides between items)
var burst_t := -1.0                            # clock when 시작's burst popped (-1: none)
var smoke_seed: Array = []                     # chimney puffs: [chimney 0/1, phase, drift, size]
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
	for i in 3:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		c.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		if i == 0:
			c.draw.connect(_draw_bg)
			bg_layer = c
		elif i == 1:
			c.material = UI.solid_mat()
			c.draw.connect(_draw_sil)
			sil_layer = c
		else:
			c.draw.connect(_draw_fg)
			fg_layer = c
		add_child(c)
	for i in 12:
		specks.append([randf(), randf(), 0.5 + randf() * 0.7, 2600.0 + randf() * 3000.0])
	for i in 10:
		smoke_seed.append([i % 2, float(i / 2) / 5.0, randf() * 2.0 - 1.0, 0.8 + randf() * 0.5])

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
	sp_cur.to(float(sel))
	sp_cur.step(dt)
	queue_redraw()
	bg_layer.queue_redraw()
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
	burst_t = clock
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

## lights on the facade: Eilin's window and one more step of the ladder per restored facility (LIGHT_STEPS at most)
func lit_windows() -> int:
	var F = _fame()
	var n := 1
	if F != null and "fac" in F: n += F.fac.size()
	return mini(n, LIGHT_STEPS)

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

## the hall plate's home rect: its right lantern a hair past the right edge, the ground row on the ground line, the
## building ~0.74 H tall or the plate ~0.76 W wide, whichever is smaller
func _hall_rect(vs: Vector2) -> Rect2:
	var sc := minf(0.74 * vs.y / (HALL_GROUND - HALL_TOP), 0.76 * vs.x / HALL.get_width())
	var w := HALL.get_width() * sc
	var h := HALL.get_height() * sc
	return Rect2(vs.x + 0.06 * vs.x - w, GROUND * vs.y - HALL_GROUND * sc, w, h)

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
	# (the first wipe frames put both edges past the right side: no polygon then, a clamped one while only the top is)
	var pts := PackedVector2Array([Vector2(minf(f[0], vs.x), 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(minf(f[1], vs.x), vs.y)])
	if minf(f[0], f[1]) < vs.x - 0.5:
		# the sky: the field in the hour's pink, eased to the plain pink as the outro grows it (the sweep's colour)
		draw_colored_polygon(pts, sky(hour()).lerp(PINK, UIA.p(outro, 150.0, 500.0, "ease") if outro >= 0.0 else 0.0))
		var k := 1.0 - UIA.p(outro, 150.0, 500.0, "ease") if outro >= 0.0 else 1.0
		_tiled(pts, UI.dot_tile(0.24), Vector2(-clock / 120.0, clock / 170.0) * k)
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
# ---------- draw: the plate, the lights, the crowd ----------
func _draw_bg() -> void:
	if not active or outro > 1050.0: return
	var vs := get_viewport_rect().size
	_hall(vs, night())
	if EMBLEM_WATERMARK: _emblem(bg_layer, vs)
	_crowd(vs)
	_fog(bg_layer, vs, 0)

## the hall plate sliding in on sp_art, its own colours by day and cooled toward violet at night, the sign board
## swinging on its chains, and the light ladder (lit_windows() steps): the right window, the left window, the lantern by
## the door, the bracket lantern, warm light through the door's crack, smoke from the left chimney, then the right
func _hall(vs: Vector2, nk: float) -> void:
	var ci := bg_layer
	var a := clampf((t - 120.0) / 150.0, 0.0, 1.0)
	if a <= 0.0: return
	var r := _hall_rect(vs)
	var sc := r.size.x / HALL.get_width()
	var m: Array = _art_motion(vs, sp_art.x, 1.0)
	var piv := Vector2(r.get_center().x, r.end.y)
	var base := UIA.xf(piv, m[0], m[1], Vector2(m[2], m[2]))
	ci.draw_set_transform_matrix(base)
	var tint := Color.WHITE.lerp(HALL_NIGHT, nk)
	var col := Color(tint, a)
	# the plate in three pieces around the sign's region (the sign comes separately, swinging)
	var W := float(HALL.get_width())
	var H := float(HALL.get_height())
	var sx := SIGN.end.x
	for reg in [Rect2(0, 0, sx, SIGN.position.y), Rect2(0, SIGN.end.y, sx, H - SIGN.end.y), Rect2(sx, 0, W - sx, H)]:
		ci.draw_texture_rect_region(HALL, Rect2(r.position + reg.position * sc, reg.size * sc), reg, col)
	var n := lit_windows()
	var warm := Color("#ffcf7a")
	var ts := clock / 1000.0
	var glow := UI.glow()
	# 1-2) the windows: a warm fill over the panes, a candle's flicker, a soft glow
	for i in mini(n, 2):
		var wr: Rect2 = WIN_R if i == 0 else WIN_L
		var pr := Rect2(r.position + wr.position * sc, wr.size * sc)
		var fl := 0.88 + 0.12 * LIT.fl(ts, i * 2.3)
		ci.draw_texture_rect(glow, pr.grow(pr.size.y * (0.7 + 0.5 * nk)), false, Color(warm, (0.16 + 0.24 * nk) * fl * a))
		ci.draw_rect(pr, Color(warm, (0.62 + 0.1 * fl) * a))
	# 3-4) the lanterns: a warm dot and a halo
	for i in [2, 3]:
		if n <= i: continue
		var c: Vector2 = r.position + (LANT_DOOR if i == 2 else LANT_R) * sc
		var fl := 0.85 + 0.15 * LIT.fl(ts, i * 1.9)
		var rad := 48.0 * sc
		ci.draw_texture_rect(glow, Rect2(c - Vector2(rad, rad) * (2.6 + 1.4 * nk), Vector2(rad, rad) * (5.2 + 2.8 * nk)), false, Color(warm, (0.18 + 0.22 * nk) * fl * a))
		ci.draw_texture_rect(glow, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, Color(1.0, 0.93, 0.75, 0.9 * fl * a))
	# 5) the door's crack: warm light leaking out
	if n > 4:
		var cr := Rect2(r.position + DOOR_CRACK.position * sc, DOOR_CRACK.size * sc)
		var fl := 0.85 + 0.15 * LIT.fl(ts, 7.0)
		ci.draw_texture_rect(glow, cr.grow_individual(cr.size.x * 4.0, cr.size.x * 2.0, cr.size.x * 4.0, cr.size.x * 2.0), false, Color(warm, (0.22 + 0.2 * nk) * fl * a))
		ci.draw_rect(cr, Color(1.0, 0.9, 0.7, 0.85 * fl * a))
	# the sign board on its chains, swinging ±2°
	var sw := deg_to_rad(2.0) * sin(clock / 2300.0 * TAU)
	ci.draw_set_transform_matrix(base * UIA.xf(r.position + SIGN_PIV * sc, Vector2.ZERO, sw))
	ci.draw_texture_rect_region(HALL, Rect2(r.position + SIGN.position * sc, SIGN.size * sc), SIGN, col)
	ci.draw_set_transform_matrix(base)
	# 6-7) chimney smoke: soft puffs rising, drifting with the breeze, fading as they grow
	var tx := LIT.soft_tex()
	for sm in smoke_seed:
		var ch: int = sm[0]
		if n < 6 + ch: continue
		var u: float = fposmod(ts / 4.2 + sm[1], 1.0)
		var top: Vector2 = r.position + (CHIM_L if ch == 0 else CHIM_R) * sc
		var rise := u * 0.26 * vs.y
		var px: float = top.x + (sin(ts * 0.4 + sm[1] * 9.0) * 0.5 + 0.5 + sm[2] * 0.3) * 0.03 * vs.x * u + sin(ts * 1.3 + sm[1] * 20.0) * 3.0
		var sz: float = (0.035 + 0.06 * u) * vs.y * sm[3]
		var al: float = (0.26 if u < 0.15 else 0.26 * (1.0 - (u - 0.15) / 0.85)) * (1.0 - 0.2 * nk)
		ci.draw_texture_rect(tx, Rect2(px - sz, top.y - rise - sz, sz * 2.0, sz * 2.0), false, Color(0.96, 0.92, 0.97, al * a))
	ci.draw_set_transform(Vector2.ZERO)

## the guild's flower as a faint watermark behind the people, over the hall's door, breathing with the hall
func _emblem(ci: CanvasItem, vs: Vector2) -> void:
	var a := clampf((t - 600.0) / 400.0, 0.0, 1.0) * 0.18
	if a <= 0.0: return
	var r := _hall_rect(vs)
	var m: Array = _art_motion(vs, sp_art.x, 1.2)
	var h := 0.62 * vs.y
	var w := h * EMBLEM.get_width() / EMBLEM.get_height()
	var c := Vector2(r.position.x + DOOR_X * r.size.x / HALL.get_width(), GROUND * vs.y - h * 0.48)
	ci.draw_set_transform_matrix(UIA.xf(c, m[0], m[1], Vector2(m[2], m[2])))
	ci.draw_texture_rect(EMBLEM, Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h)), false, Color(1, 1, 1, a))
	ci.draw_set_transform(Vector2.ZERO)

## the nameless members: paper cut-out silhouettes on the steps behind the people, flat ink, each with a thin rim in
## its own hue (same saturation and value: a crowd of colours), in three rows that drift a hair
func _crowd(vs: Vector2) -> void:
	if crowd_seed.is_empty(): return
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
		var h: float = (0.18 - 0.022 * row) * vs.y
		var bob := sin(clock / 2900.0 * TAU + cs[4]) * 1.2
		var drop := 1.0 - UIA.p(t, 700.0 + row * 90.0, 420.0, "bk")
		var xf := base * Transform2D(0.0, Vector2(x, fy + bob - 0.1 * vs.y * drop))
		var rim := Color.from_hsv(cs[3] / 360.0, 0.7, 0.95)
		_figure(xf, h, cs[2], Color(rim, a), 1.0 + 2.2 / h)
		_figure(xf, h, cs[2], Color(INK, a), 1.0)
	bg_layer.draw_set_transform(Vector2.ZERO)

## one paper figure (feet at the origin, `h` tall): kind 0 plain, 1 pointed hat, 2 hood, 3 a staff
func _figure(xf: Transform2D, h: float, kind: int, col: Color, grow: float) -> void:
	var ci := bg_layer
	ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(grow, grow), 0.0, Vector2.ZERO))
	var sw := h * 0.17
	var bh := h * 0.72
	var body := PackedVector2Array([Vector2(-sw, 0), Vector2(sw, 0), Vector2(sw * 0.95, -bh * 0.55), Vector2(sw * 1.25, -bh * 0.8),
		Vector2(sw * 0.55, -bh), Vector2(-sw * 0.55, -bh), Vector2(-sw * 1.25, -bh * 0.8), Vector2(-sw * 0.95, -bh * 0.55)])
	ci.draw_colored_polygon(body, col)
	var hr := h * 0.11
	var hc := Vector2(0, -bh - hr * 0.9)
	ci.draw_circle(hc, hr, col)
	match kind:
		1: ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-hr * 1.4, -hr * 0.3), hc + Vector2(hr * 1.4, -hr * 0.3), hc + Vector2(hr * 0.2, -hr * 3.2)]), col)
		2: ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-hr * 1.3, hr * 0.8), hc + Vector2(-hr * 1.1, -hr * 1.3), hc + Vector2(0, -hr * 1.6), hc + Vector2(hr * 1.1, -hr * 1.3), hc + Vector2(hr * 1.3, hr * 0.8)]), col)
		3: ci.draw_rect(Rect2(sw * 1.15, -h * 1.02, h * 0.025, h * 1.02), col)

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
	_logo(ci, vs)
	_people(ci, vs)
	_fog(ci, vs, 1)
	_prompt(ci, vs)
	_burst(ci, vs)
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

## the logo's home rect: the left column, ~0.4 W wide (capped at 0.54 H tall), above the menu
func _logo_rect(vs: Vector2) -> Rect2:
	var w := 0.4 * vs.x
	var h := w * LOGO.get_height() / LOGO.get_width()
	if h > 0.54 * vs.y:
		h = 0.54 * vs.y
		w = h * LOGO.get_width() / LOGO.get_height()
	return Rect2(0.04 * vs.x, 0.1 * vs.y, w, h)

## the brush logo on its pink blob: three paint splats pop behind it 90 ms apart, then it lands from 1.25× with a short
## overshoot (`bk`); the blob breathes a slow ±1° roll under it; the block leaves left in the outro
func _logo(ci: CanvasItem, vs: Vector2) -> void:
	var r := _logo_rect(vs)
	var base := _logo_xf(vs)
	var o := _out(0)
	if o >= 1.0: return
	var c := r.get_center()
	var leave := Vector2(-0.7 * vs.x * o, 0)
	# the splats
	for sp in SPLATS:
		var u := UIA.p(t, sp[4], 260.0, "bk")
		if u <= 0.0: continue
		var sz: float = r.size.x * sp[2] * u
		var at := r.position + Vector2(sp[0], sp[1]) * r.size + leave
		ci.draw_set_transform_matrix(base * UIA.xf(at, Vector2.ZERO, deg_to_rad(sp[3]) + deg_to_rad(-4.0 * o)))
		ci.draw_texture_rect(BURST, Rect2(at - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, 0.9))
	# the blob and the logo land together
	var u := UIA.p(t, 650.0, 420.0, "bk")
	if u <= 0.0:
		ci.draw_set_transform(Vector2.ZERO)
		return
	var al := clampf((t - 650.0) / 100.0, 0.0, 1.0)
	var sc := 1.0 + 0.25 * (1.0 - u)
	var roll := deg_to_rad(1.0) * sin(clock / 6400.0 * TAU)
	var bw := r.size.x * 1.15
	var bh := bw * BLOB.get_height() / BLOB.get_width()
	ci.draw_set_transform_matrix(base * UIA.xf(c, leave, roll - deg_to_rad(6.0 * o), Vector2(sc * 1.02, sc * 1.02)))
	ci.draw_texture_rect(BLOB, Rect2(c - Vector2(bw, bh) / 2.0, Vector2(bw, bh)), false, Color(1, 1, 1, al))
	ci.draw_set_transform_matrix(base * UIA.xf(c, leave, deg_to_rad(-6.0 * o), Vector2(sc, sc)))
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

## the tagline and the 탭하여 입장 slab (pulsing once the intro has settled)
func _prompt(ci: CanvasItem, vs: Vector2) -> void:
	var W := vs.x
	var H := vs.y
	var lx := 0.089 * W
	var o := UIA.p(outro, 0.0, 280.0, "in") if outro >= 0.0 else 0.0
	# the motto, small above the logo, under the travelling guide line
	var ua := UIA.p(t, 1250.0, 400.0, "ease") * (1.0 - o)
	if ua > 0.0:
		var fn := UI.noto()
		var motto := "서툴지만, 물러서지 않는다"
		var fs := int(0.026 * H)
		ci.draw_string(fn, Vector2(lx + 0.02 * W * (1.0 - ua), 0.082 * H), motto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.78, 0.78, 0.82, ua))
	if not EMBLEM_WATERMARK:
		# the guild's flower, small at the menu column's top right
		var ea := UIA.p(t, 1300.0, 400.0, "ease") * (1.0 - o)
		if ea > 0.0:
			var eh := 0.16 * H
			var ew := eh * EMBLEM.get_width() / EMBLEM.get_height()
			ci.draw_texture_rect(EMBLEM, Rect2(lx + 0.19 * W + 0.012 * W, 0.96 * H - items.size() * 0.064 * H - eh * 0.1, ew, eh), false, Color(1, 1, 1, ea))
	# the menu: four slabs, each sliding in 70 ms after the one above; the picked one is pink, pushed right and a touch bigger
	item_rects.clear()
	confirm_rects.clear()
	var fb := UI.bhs()
	var fs2 := int(0.03 * H)
	var ih := 0.052 * H
	var gap := 0.012 * H
	var y0 := 0.96 * H - items.size() * (ih + gap) + gap
	var pulse := UIA.pulse(clock, 1400.0) if intro_done else 0.0
	# the cursor: the brush stroke is the picked row's slab, sliding between rows on its spring
	var ucur := UIA.p(t, 1250.0, 400.0, "bk")
	if ucur > 0.0 and o < 1.0 and not confirm:
		var sw0 := 0.19 * W
		var bw := sw0 * 1.3
		var bh := ih * 2.3
		var cy := y0 + sp_cur.x * (ih + gap) + ih * 0.5
		var cc := Vector2(lx + 0.014 * W + sw0 * 0.5, cy)
		var psc := 1.0 + 0.04 * pulse
		ci.draw_set_transform_matrix(UIA.xf(cc, Vector2(-0.3 * W * (1.0 - ucur), 0.25 * H * o), 0.0, Vector2(psc, psc)))
		ci.draw_texture_rect(BRUSH, Rect2(cc - Vector2(bw, bh) / 2.0, Vector2(bw, bh)), false, Color(1, 1, 1, ucur))
		ci.draw_set_transform(Vector2.ZERO)
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
		if not on:
			# a white slab; the picked row rides the brush stroke instead, its label white with an ink shadow
			UI.para(ci, r.position.x, r.position.y, sw, ih, -ih * 0.3, Color(1, 1, 1, 0.35) if dim else Color.WHITE)
		var tc := Color.WHITE if on else INK
		if dim: tc = Color(0.1, 0.1, 0.12, 0.5)
		var tp := Vector2(r.position.x + 0.022 * W, r.position.y + ih * 0.5 + fs2 * 0.36)
		if on: tp.x = r.position.x + sw * 0.5 - UI.text_w(fb, lab, fs2) * 0.5 + 0.01 * W    # on the stroke's thick middle
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
