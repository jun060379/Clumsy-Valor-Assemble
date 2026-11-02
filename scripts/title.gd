extends Control
## Title (prototype #title) in the persona skin; the hero select is gone (a fresh game is 에스텔 alone, the seniors join in play). docs/title_storyboard.md has the beats:
## a pink band wipes in, Estelle's gear picture springs in with a white cut-out trailing it, the logo slabs slam and the
## letters of 어설픈 용맹 drop one by one, then nothing ever holds still (drifting halftone, travelling guide lines, a sheen
## over the letters, the picture's parallax); a tap grows the pink field over the screen and the menu sweep carries it
## on into the guild town.
##
## Layers: this Control draws the ground; `sil` (UI.solid_mat) draws the picture's silhouettes;
## `fg` draws the picture, the logo and the prompt with linear filtering.

const UI := preload("res://scripts/ui_kit.gd")
const DEV := preload("res://scripts/dev.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const CH := preload("res://scripts/chars.gd")
const SK := preload("res://scripts/skins.gd")
const PINK := Color("#ff3d7f")
const INK := Color("#0d0b10")
const INTRO_END := 1500.0
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


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	if not active:
		return
	var dt := minf(delta * 1000.0, 250.0)   # real time, like the prototype's CSS / rAF clocks
	clock += dt
	trn.step(dt)
	t += dt
	if not intro_done and t > INTRO_END:
		intro_done = true
	if outro < 0.0:
		if t >= 120.0: sp_art.to(0.0)
		if t >= 220.0: sp_sil.to(0.0)
	if not slammed and t >= 1050.0 and t < 90000.0:
		slammed = true
		arena.sfx("slam", 0.5)
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
	# Enter / Space (the pad's A sends Enter; Start is the in-game menu button and does nothing here)
	var kb_ok := key in [KEY_ENTER, KEY_SPACE] or padb == JOY_BUTTON_A
	if tap == Vector2.INF and not kb_ok:
		return
	if not intro_done:
		_finish_intro()
		if tap != Vector2.INF:
			return         # a click only finishes the logo; a key finishes it and starts at once (two keydown listeners)
	outro = 0.0
	sp_art.to(1.5, 1.5)
	arena.sfx("parry", 1.0)

## the logo settles at once (a tap during the intro)
func _finish_intro() -> void:
	intro_done = true
	t = 99999.0
	slammed = true
	sp_art.snap(0.0)
	sp_sil.snap(0.0)

func _go() -> void:
	active = false
	visible = false
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

## the picture's home rect: 1.12 H tall, cut by the right and bottom edges
func _art_rect(vs: Vector2, tex: Texture2D) -> Rect2:
	var h := 1.12 * vs.y
	var w := h * tex.get_width() / tex.get_height()
	return Rect2(vs.x - 0.78 * w, vs.y - 0.98 * h, w, h)

## the picture's motion: [translation, rotation (rad), scale] for a spring value (1 = off right) and a parallax weight
func _art_motion(vs: Vector2, s: float, par: float) -> Array:
	var sway := Vector2(sin(clock / 5200.0 * TAU) * 0.25, cos(clock / 6100.0 * TAU) * 0.2)
	var tr := Vector2(0.5 * vs.x * s, 0) + (Vector2(sp_px.x, sp_py.x) + sway) * Vector2(8.0, 5.0) * par
	tr.y -= 4.0 * (0.5 - 0.5 * cos(clock / 4200.0 * TAU))
	return [tr, deg_to_rad(-8.0 * s), 1.0 + 0.12 * s]

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
	var pts := PackedVector2Array([Vector2(f[0], 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(f[1], vs.y)])
	draw_colored_polygon(pts, PINK)
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
	var tex := SK.tex("estelle", "st_gear")
	if tex == null: return
	var r := _art_rect(vs, tex)
	var a := clampf((t - 220.0) / 150.0, 0.0, 1.0)
	if a <= 0.0: return
	var piv := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.75)
	# the white cut-out, on its own lagging spring
	var m: Array = _art_motion(vs, sp_sil.x, 1.7)
	ci.draw_set_transform_matrix(UIA.xf(piv, m[0] + Vector2(0.034 * vs.x, 0.022 * vs.y), m[1], Vector2(m[2], m[2])))
	ci.draw_texture_rect(tex, r, false, Color(1, 1, 1, a))
	# the thin black copy, glued to the picture
	var m2: Array = _art_motion(vs, sp_art.x, 1.0)
	ci.draw_set_transform_matrix(UIA.xf(piv, m2[0] + Vector2(-0.0055 * vs.x, 0.006 * vs.y), m2[1], Vector2(m2[2], m2[2])))
	ci.draw_texture_rect(tex, r, false, Color(0, 0, 0, a))
	ci.draw_set_transform(Vector2.ZERO)


# ---------- draw: picture, logo, prompt ----------
func _draw_fg() -> void:
	if not active or outro > 1050.0: return
	var ci := fg_layer
	var vs := get_viewport_rect().size
	_logo(ci, vs)          # under the picture: the bars sweep in from behind her
	var tex := SK.tex("estelle", "st_gear")
	if tex != null:
		var r := _art_rect(vs, tex)
		var a := clampf((t - 120.0) / 150.0, 0.0, 1.0)
		var m: Array = _art_motion(vs, sp_art.x, 1.0)
		var piv := Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y * 0.75)
		var lit: float = UIA.kf(t, [[0.0, 0.0], [0.45, 0.0], [0.6, 1.0], [1.0, 1.0]], 700.0, 120.0)
		ci.draw_set_transform_matrix(UIA.xf(piv, m[0], m[1], Vector2(m[2], m[2])))
		ci.draw_texture_rect(tex, r, false, Color(lit, lit, lit, a))
		ci.draw_set_transform(Vector2.ZERO)
	_prompt(ci, vs)
	# the white slash as the tag stamps (cx_flash)
	if t >= 1050.0 and t < 1430.0:
		var u := UIA.p(t, 1050.0, 380.0, "mv")
		var fr := Rect2(-0.2 * vs.x, vs.y * 0.5, vs.x * 1.4, 0.05 * vs.y)
		var fm := UIA.xf(fr.get_center(), Vector2(lerpf(-1.2, 1.2, u) * fr.size.x, 0), deg_to_rad(-12.0))
		ci.draw_colored_polygon(fm * UI.clip(fr, [[0, 45], [100, 0], [100, 25], [0, 100]]), Color.WHITE)
	if not DEV.on: return                  # the build stamp: debug builds only (dev.gd)
	var ver: String = arena._stamp()
	var sf := UI.spaced(UI.noto(), 1)
	ci.draw_string(sf, Vector2(vs.x - 12.0 - UI.text_w(sf, ver, 11), vs.y - 12.0), ver, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

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
	# 4) -ASSEMBLE- stamps in
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
	var ua := UIA.p(t, 1250.0, 400.0, "ease") * (1.0 - o)
	if ua > 0.0:
		var fn := UI.noto()
		var motto := "서툴지만, 물러서지 않는다"
		var fs := int(0.03 * H)
		ci.draw_string(fn, Vector2(lx + 0.02 * W * (1.0 - ua), 0.85 * H + fs * 0.4), motto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.78, 0.78, 0.82, ua))
	var u := UIA.p(t, 1300.0, 400.0, "bk")
	if u <= 0.0 or o >= 1.0: return
	var fb := UI.bhs()
	var ps := "탭하여 입장"
	var fs2 := int(0.036 * H)
	var sw := UI.text_w(fb, ps, fs2) + 0.044 * W
	var sh := 0.05 * H
	var r := Rect2(lx, 0.905 * H, sw, sh)
	var pulse := UIA.pulse(clock, 1200.0) if intro_done else 0.0
	var sc := 1.0 + 0.05 * pulse
	ci.draw_set_transform_matrix(UIA.xf(r.get_center(), Vector2(-0.3 * W * (1.0 - u), 0.2 * H * o), deg_to_rad(-3.0 * (1.0 - u)), Vector2(sc, sc)))
	UI.para(ci, r.position.x, r.position.y, sw, sh, -sh * 0.3, Color.WHITE.lerp(Color("#ffe0ea"), pulse))
	ci.draw_string(fb, Vector2(r.position.x + 0.022 * W, r.position.y + sh * 0.5 + fs2 * 0.36), ps, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, INK)
	ci.draw_set_transform(Vector2.ZERO)


# ---------- hero select ----------
