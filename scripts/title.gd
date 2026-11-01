extends Control
## Title and hero select (prototype #title / #select). The sword is drawn up, the banner slams in, the letters tumble
## down; a tap / Enter rips it all away into CHOOSE YOUR HERO; 출격 drops the chosen leader into the guild town.

const UI := preload("res://scripts/ui_kit.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const CH := preload("res://scripts/chars.gd")
const T_SWORD := preload("res://assets/ui/title/logo_sword.png")
const T_BANNER := preload("res://assets/ui/title/logo_banner.png")
const T_LETTERS := preload("res://assets/ui/title/logo_letters.png")
## LOGO: positions inside the 1216 x 832 logo canvas
const LW := 1216.0
const LH := 832.0
const SWORD := Vector2(545, 20)
const BANNER := Vector2(19, 304)
const LETTERS := Vector2(78, 214)
const PIECES := [[297, 218, 139, 70], [453, 218, 74, 70], [529, 248, 47, 40], [577, 242, 145, 62], [737, 218, 97, 70], [837, 218, 97, 70]]
const GOLD := Color("#d6b46e")
## select cards (prototype #cards)
const CARDS := [
	{"c": "estelle", "col": Color("#ff6fb0"), "nm": "에스텔 벨라시타", "rl": "검과 방패의 기사", "kit": ["· 3단 베기 / 상단·하단", "· 패링(무효) · 가드(반감)", "· 차징 찌르기"]},
	{"c": "aida", "col": Color("#c9a6ff"), "nm": "스나가와 아이다", "rl": "삽 든 암살자", "kit": ["· 등 뒤 순간이동 · 뒷치기", "· 균열: 문양 조준 텔포", "· 어두운 참격 (차징)"]},
	{"c": "luce", "col": Color("#ffd36b"), "nm": "루체 루멘", "rl": "성녀 후보", "kit": ["· 대상 지정 유도 빛탄", "· 빛기둥 · 벼락 (차징)", "· 힐"]},
]

var arena
var ui_root
var active := true
var mode := "title"              # title / select
var t := 0.0                     # intro clock (ms)
var intro_done := false
var outro := -1.0                # outro clock, -1 = not running
var outro_seed: Array = []
var sel := 0
var sel_t := 0.0
var card_rects: Array = []
var go_rect := Rect2()
var clock := 0.0
var trn := UIA.Tr.new()          # .card transition: transform .3s --bk, background .15s


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED     # halftone dots on the select screen
	for p in PIECES:
		outro_seed.append({"d": randf() * 160.0, "vx": (randf() - 0.5) * 0.5, "rot": (randf() - 0.5) * 0.004})

func _process(delta: float) -> void:
	if not active:
		return
	var dt := minf(delta * 1000.0, 250.0)   # real time, like the prototype's CSS / rAF clocks
	clock += dt
	trn.step(dt)
	t += dt
	if not intro_done and t > 820.0 + PIECES.size() * 70.0 + 620.0:
		intro_done = true
	if outro >= 0.0:
		outro += dt
		if outro > 1350.0:
			outro = -1.0
			mode = "select"
			sel_t = 0.0
	sel_t += dt
	queue_redraw()


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
	if mode == "title":
		if outro >= 0.0:
			return
		var ok := tap != Vector2.INF or key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or padb in [JOY_BUTTON_A, JOY_BUTTON_START]
		if not ok:
			return
		if not intro_done:
			intro_done = true
			t = 99999.0
			return
		outro = 0.0
		arena.sfx("parry", 1.0)
		return
	# select
	if key in [KEY_LEFT, KEY_A] or padb == JOY_BUTTON_DPAD_LEFT:
		_set_sel(sel - 1)
	elif key in [KEY_RIGHT, KEY_D] or padb == JOY_BUTTON_DPAD_RIGHT:
		_set_sel(sel + 1)
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or padb in [JOY_BUTTON_A, JOY_BUTTON_START]:
		_go()
	elif tap != Vector2.INF:
		if go_rect.has_point(tap):
			_go()
			return
		for i in card_rects.size():
			if card_rects[i].has_point(tap):
				if i == sel: _go()
				else: _set_sel(i)
				return

func _set_sel(i: int) -> void:
	sel = posmod(i, CARDS.size())
	arena.sfx("step", 0.4)

func _go() -> void:
	active = false
	visible = false
	ui_root.start_game(CARDS[sel]["c"])


# ---------- draw ----------
func _draw() -> void:
	var vs := get_viewport_rect().size
	if mode == "select" or outro > 1050.0:
		_draw_select(vs)
	if mode == "title":
		var a := 1.0
		if outro > 1050.0: a = maxf(0.0, 1.0 - (outro - 1050.0) / 300.0)
		_draw_title(vs, a)

func _draw_title(vs: Vector2, a: float) -> void:
	# backdrop: deep blue-black, a cold glow up top, faint scanlines and pillars, drifting motes, a vignette
	var steps := 24
	for i in steps:
		var u := float(i) / steps
		var c := Color("#171a26").lerp(Color("#0f111a"), clampf(u / 0.6, 0, 1)) if u < 0.6 else Color("#0f111a").lerp(Color("#090a0f"), (u - 0.6) / 0.4)
		draw_rect(Rect2(0, vs.y * u, vs.x, vs.y / steps + 1.0), Color(c, a))
	draw_texture_rect(UI.glow(), Rect2(vs.x * 0.5 - vs.x * 0.55, vs.y * 0.3 - vs.y * 0.55, vs.x * 1.1, vs.y * 1.1), false, Color(90 / 255.0, 120 / 255.0, 190 / 255.0, 0.28 * a))
	var y := 0.0
	while y < vs.y:
		draw_rect(Rect2(0, y, vs.x, 1), Color(1, 1, 1, 0.025 * a))
		y += 7.0
	var x := 0.0
	while x < vs.x:
		draw_rect(Rect2(x, 0, 1, vs.y), Color(0, 0, 0, 0.18 * a))
		x += 90.0
	var dr := clock / 60000.0
	for L in [[Vector2(170, 130), Vector2(20, 30), Vector2(60, -120), Color(1, 0.84, 0.55, 0.9)], [Vector2(260, 210), Vector2(90, 70), Vector2(160, -180), Color(1, 0.94, 0.78, 0.6)]]:
		var g: Vector2 = L[0]
		var o: Vector2 = L[1] + L[2] * fmod(dr, 1.0)
		var px := fposmod(o.x, g.x) - g.x
		while px < vs.x:
			var py := fposmod(o.y, g.y) - g.y
			while py < vs.y:
				draw_rect(Rect2(px, py, 2, 2), Color(L[3], L[3].a * 0.28 * a))
				py += g.y
			px += g.x
	_vignette(vs, a)
	# banners top and bottom
	var bx := 0.0
	while bx < vs.x:
		draw_rect(Rect2(bx, 0, 18, 6), Color(GOLD, 0.35 * a))
		draw_rect(Rect2(bx, vs.y - 6, 18, 6), Color(GOLD, 0.35 * a))
		bx += 26.0
	# layout: crest, rule, logo, -ASSEMBLE-, rule, motto, press
	var lw := minf(vs.x * 0.78, 600.0)
	var lh := lw * LH / LW
	if lh > vs.y - 172.0:
		lh = maxf(180.0, vs.y - 172.0)
		lw = lh * LW / LH
	var total := 16.0 + 20.0 + lh + 26.0 + 18.0 + 18.0 + 34.0
	var y0 := (vs.y - total) / 2.0
	var cx := vs.x / 2.0
	# frame with corner brackets
	var fr := Rect2(cx - lw / 2.0 - 44.0, y0 - 18.0, lw + 88.0, total + 38.0)
	draw_rect(fr, Color(0.06, 0.07, 0.11, 0.55 * a))
	draw_rect(fr, Color(GOLD, 0.55 * a), false, 1.0)
	draw_rect(fr.grow(6), Color(GOLD, 0.2 * a), false, 1.0)
	for cr in [[fr.position, Vector2(1, 1)], [Vector2(fr.end.x, fr.position.y), Vector2(-1, 1)], [Vector2(fr.position.x, fr.end.y), Vector2(1, -1)], [fr.end, Vector2(-1, -1)]]:
		var p: Vector2 = cr[0] - cr[1] * 6.0
		draw_line(p, p + Vector2(cr[1].x * 16, 0), Color(GOLD, a), 2.0)
		draw_line(p, p + Vector2(0, cr[1].y * 16), Color(GOLD, a), 2.0)
	var fb := UI.noto()
	var crest := "ADVENTURERS' GUILD"
	var cf := UI.spaced(fb, 5)
	draw_string(cf, Vector2(cx - UI.text_w(cf, crest, 11) / 2.0, y0 + 12.0), crest, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(GOLD, 0.85 * a))
	_rule(Vector2(cx, y0 + 26.0), 1, a)
	var ly := y0 + 36.0
	var lr := Rect2(cx - lw / 2.0, ly, lw, lh)
	if intro_done and outro < 0.0:
		lr.position.y += sin(clock / 900.0) * -4.0
	_draw_logo(lr, a)
	# -ASSEMBLE- tag
	var ay := ly + lh - 6.0
	var at: float = clampf((t - 300.0) / 700.0, 0.0, 1.0) if not intro_done else 1.0
	if t > 300.0 or intro_done:
		var af := UI.anton(true, 7)
		var s := "-ASSEMBLE-"
		var fs := int(clampf(vs.y * 0.042, 16.0, 26.0))
		var tw := UI.text_w(af, s, fs) + 44.0
		var sc := 1.0 + 1.2 * (1.0 - UI.bk(at))
		draw_set_transform(Vector2(cx, ay + 14.0), deg_to_rad(-3.0 - 9.0 * (1.0 - UI.bk(at))), Vector2(sc, sc))
		var h := fs + 8.0
		UI.para(self, -tw / 2.0 + 10.0, -h / 2.0 + 10.0, tw, h, h * 0.2, Color(1, 1, 1, 0.85 * a * at))
		UI.para(self, -tw / 2.0 + 5.0, -h / 2.0 + 5.0, tw, h, h * 0.2, Color(Color("#ff3d7f"), a * at))
		UI.para(self, -tw / 2.0, -h / 2.0, tw, h, h * 0.2, Color(0, 0, 0, a * at))
		draw_string(af, Vector2(-tw / 2.0 + 24.0, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a * at))
		draw_set_transform(Vector2.ZERO)
	# rule, motto, press (fade in once the intro has settled)
	var ra := (1.0 if intro_done else 0.0) * a
	_rule(Vector2(cx, ay + 40.0), 3, ra)
	var motto := "서툴지만, 물러서지 않는다 — 길드 훈련장"
	draw_string(fb, Vector2(cx - UI.text_w(fb, motto, 13) / 2.0, ay + 62.0), motto, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Color("#cfc3a6"), 0.9 * ra))
	if intro_done and int(clock / 700.0) % 2 == 0:
		var pf := UI.spaced(fb, 3)
		var ps := "탭하여 입장"
		var pw := UI.text_w(pf, ps, 15)
		var py := ay + 90.0
		UI.shadow_text(self, pf, Vector2(cx - pw / 2.0, py), ps, 15, Color(Color("#f3e3b6"), a))
		UI.star4(self, Vector2(cx - pw / 2.0 - 16.0, py - 5.0), 7.0, Color(Color("#f3e3b6"), a), true)
		UI.star4(self, Vector2(cx + pw / 2.0 + 14.0, py - 5.0), 7.0, Color(Color("#f3e3b6"), a), true)
	var ver: String = arena._stamp()
	draw_string(UI.spaced(fb, 1), Vector2(vs.x - 12.0 - UI.text_w(UI.spaced(fb, 1), ver, 11), vs.y - 12.0), ver, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(GOLD, 0.45 * a))

func _vignette(vs: Vector2, a: float) -> void:
	# edges darken: soft bands
	for i in 12:
		var w := 6.0 + i * 6.0
		var al := 0.06 * a
		draw_rect(Rect2(0, 0, w, vs.y), Color(0, 0, 0, al))
		draw_rect(Rect2(vs.x - w, 0, w, vs.y), Color(0, 0, 0, al))
		draw_rect(Rect2(0, 0, vs.x, w * 0.6), Color(0, 0, 0, al))
		draw_rect(Rect2(0, vs.y - w * 0.6, vs.x, w * 0.6), Color(0, 0, 0, al))

func _rule(c: Vector2, n: int, a: float) -> void:
	if a <= 0.0: return
	var half := (n - 1) * 9.0
	for i in n:
		UI.star4(self, c + Vector2(-half + i * 18.0, 0), 5.0, Color(GOLD, 0.8 * a))
	for s in [-1, 1]:
		var x0: float = c.x + s * (half + 12.0)
		for j in 18:
			var k := float(j) / 18.0
			draw_rect(Rect2(x0 + s * k * 90.0 - (5.0 if s < 0 else 0.0), c.y, 5, 1), Color(GOLD, 0.8 * a * (1.0 - k)))

## the logo canvas: intro (sword up, flash, banner slam, letters bounce) / settled / outro (rip away)
func _draw_logo(r: Rect2, a: float) -> void:
	var k := r.size.x / LW
	var o := r.position
	var tt := t if not intro_done else 99999.0
	if outro >= 0.0:
		var to := outro
		var sy := -pow(maxf(0.0, to / 460.0), 2) * 1400.0
		_img(T_SWORD, o, k, SWORD + Vector2(0, sy), 0.0, a)
		if to < 520.0:
			var f := 1.0 - to / 520.0
			draw_rect(Rect2(o + Vector2(590, maxf(-200.0, SWORD.y + sy + 40.0)) * k, Vector2(44, 760) * k), Color(1, 1, 1, 0.85 * f * a))
			draw_texture_rect(UI.glow(), Rect2(o + (Vector2(612, 300) - Vector2(420, 420)) * k, Vector2(840, 840) * k), false, Color(1, 1, 1, 0.8 * f * a))
		var kb := maxf(0.0, to - 380.0) / 1000.0
		var bc := BANNER + Vector2(T_BANNER.get_width(), T_BANNER.get_height()) / 2.0
		_img(T_BANNER, o, k, bc + Vector2(0, kb * kb * 2200.0), kb * 0.22, a, true)
		for i in PIECES.size():
			var p: Array = PIECES[i]
			var sd: Dictionary = outro_seed[i]
			var kk := maxf(0.0, to - 200.0 - sd["d"])
			var yo: float = kk * kk * 0.0022 + kk * 0.04
			var xo: float = sd["vx"] * kk
			_piece(o, k, p, Vector2(xo, yo), sd["rot"] * kk, a)
		return
	# 1) sword drawn upward out of the dark, overshoot and settle
	var ts := clampf(tt / 520.0, 0.0, 1.0)
	var sy2 := (1.0 - (1.0 - pow(1.0 - ts, 3))) * 700.0 - (sin((ts - 0.8) / 0.2 * PI) * 14.0 if ts > 0.8 else 0.0)
	_img(T_SWORD, o, k, SWORD + Vector2(0, sy2), 0.0, a * clampf(tt / 120.0, 0.0, 1.0))
	# "chang": flash and a light streak up the blade
	if tt > 500.0 and tt < 780.0:
		var q := (tt - 500.0) / 280.0
		var rr := 320.0 * (0.4 + q)
		draw_texture_rect(UI.glow(), Rect2(o + (Vector2(612, 230) - Vector2(rr, rr)) * k, Vector2(rr, rr) * 2.0 * k), false, Color(1, 1, 1, 0.95 * (1.0 - q) * a))
		var yy := 780.0 - q * 760.0
		draw_rect(Rect2(o + Vector2(580, yy - 40.0) * k, Vector2(56, 80) * k), Color(1, 1, 1, 0.9 * (1.0 - q) * a))
	# 2) banner slams in
	if tt > 600.0:
		var kb2 := clampf((tt - 600.0) / 220.0, 0.0, 1.0)
		var sc := 1.35 - 0.35 * (1.0 - pow(1.0 - kb2, 3))
		var bsz := Vector2(T_BANNER.get_width(), T_BANNER.get_height())
		var bc2 := BANNER + bsz / 2.0
		draw_set_transform(o + bc2 * k, 0.0, Vector2(k * sc, k * sc))
		draw_texture_rect(T_BANNER, Rect2(-bsz / 2.0, bsz), false, Color(1, 1, 1, clampf(kb2 * 2.0, 0.0, 1.0) * a))
		draw_set_transform(Vector2.ZERO)
		if kb2 >= 1.0 and tt < 1000.0:
			var q2 := (tt - 820.0) / 180.0
			draw_rect(Rect2(o + (BANNER - Vector2(8.0 + q2 * 30.0, 8.0 + q2 * 20.0)) * k, (bsz + Vector2(16.0 + q2 * 60.0, 16.0 + q2 * 40.0)) * k), Color(1, 0.9, 0.63, 0.9 * (1.0 - q2) * a), false, maxf(1.0, (6.0 * (1.0 - q2) + 1.0) * k))
	# 3) letters tumble down left to right, bounce once
	for i in PIECES.size():
		var st := 820.0 + i * 70.0
		if tt < st: continue
		var kk := clampf((tt - st) / 620.0, 0.0, 1.0)
		var yo2 := -(1.0 - _bounce(kk)) * 420.0
		var rt := (1.0 - kk) * (1.0 if i % 2 else -1.0) * 0.35
		var p2: Array = PIECES[i]
		_piece(o, k, p2, Vector2(0, yo2), rt, a)
		if kk > 0.33 and kk < 0.45:
			draw_rect(Rect2(o + Vector2(p2[0] - 6.0, p2[1] + p2[3] - 2.0) * k, Vector2(p2[2] + 12.0, 4.0) * k), Color(1, 0.94, 0.78, 0.8 * (0.45 - kk) / 0.12 * a))

func _img(tex: Texture2D, o: Vector2, k: float, at: Vector2, rot: float, a: float, centred := false) -> void:
	var sz := Vector2(tex.get_width(), tex.get_height())
	if centred:
		draw_set_transform(o + at * k, rot, Vector2(k, k))
		draw_texture_rect(tex, Rect2(-sz / 2.0, sz), false, Color(1, 1, 1, a))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_texture_rect(tex, Rect2(o + at * k, sz * k), false, Color(1, 1, 1, a))

func _piece(o: Vector2, k: float, p: Array, off: Vector2, rot: float, a: float) -> void:
	var w: float = p[2]
	var h: float = p[3]
	var c := Vector2(p[0] + w / 2.0, p[1] + h / 2.0) + off
	draw_set_transform(o + c * k, rot, Vector2(k, k))
	draw_texture_rect_region(T_LETTERS, Rect2(-w / 2.0, -h / 2.0, w, h), Rect2(p[0] - LETTERS.x, p[1] - LETTERS.y, w, h), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)

static func _bounce(u: float) -> float:
	if u < 1.0 / 2.75: return 7.5625 * u * u
	if u < 2.0 / 2.75:
		u -= 1.5 / 2.75
		return 7.5625 * u * u + 0.75
	if u < 2.5 / 2.75:
		u -= 2.25 / 2.75
		return 7.5625 * u * u + 0.9375
	u -= 2.625 / 2.75
	return 7.5625 * u * u + 0.984375


# ---------- hero select ----------
func _draw_select(vs: Vector2) -> void:
	var tc := UI.col("estelle")
	draw_rect(Rect2(Vector2.ZERO, vs), tc)
	UI.dots(self, Rect2(Vector2.ZERO, vs), 0.24)
	var sr := Rect2(-0.1 * vs.x, -0.2 * vs.y, 0.58 * vs.x, 1.5 * vs.y)
	draw_colored_polygon(UI.rot(UI.clip(sr, [[0, 0], [100, 0], [100, 100], [0, 100]]), sr.get_center(), deg_to_rad(-10.0)), Color.BLACK)
	var cw := 150.0
	var ch := 236.0
	var gap := 14.0
	var top := (vs.y - (44.0 + 12.0 + ch + 16.0 + 44.0 + 12.0 + 18.0)) / 2.0
	var cx := vs.x / 2.0
	# CHOOSE YOUR HERO
	var hf := UI.anton(true, 2)
	var hs := "CHOOSE YOUR HERO"
	var hw := UI.text_w(hf, hs, 26) + 36.0
	draw_set_transform(Vector2(cx, top + 18.0), deg_to_rad(-3.0))
	UI.para(self, -hw / 2.0 + 5.0, -18.0 + 5.0, hw, 38, -6.7, Color.WHITE)
	UI.para(self, -hw / 2.0, -18.0, hw, 38, -6.7, Color.BLACK)
	draw_string(hf, Vector2(-hw / 2.0 + 16.0, 11.0), hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	# cards
	card_rects.clear()
	var cy := top + 56.0
	var x0 := cx - (cw * 3.0 + gap * 2.0) / 2.0
	var fb := UI.bhs()
	var fn := UI.noto()
	for i in CARDS.size():
		var C: Dictionary = CARDS[i]
		var on := i == sel
		var r := Rect2(x0 + i * (cw + gap), cy, cw, ch)
		card_rects.append(r)
		var sc: float = trn.get_v("s%d" % i, 1.06 if on else 1.0, 300.0, "bk")
		var lift: float = trn.get_v("y%d" % i, -8.0 if on else 0.0, 300.0, "bk")
		var wk: float = trn.get_v("w%d" % i, 1.0 if on else 0.0, 150.0, "ease")
		var c0 := r.get_center() + Vector2(0, lift)
		draw_set_transform(c0, 0.0, Vector2(sc, sc))
		var lr := Rect2(-cw / 2.0, -ch / 2.0, cw, ch)
		draw_colored_polygon(UI.clip(lr, [[7, 0], [100, 0], [93, 100], [0, 100]]), Color.BLACK.lerp(Color.WHITE, wk))
		var tcol := Color.WHITE.lerp(Color.BLACK, wk)
		var pr := Rect2(-60, lr.position.y + 8.0, 120, 120)
		draw_rect(pr, Color(0, 0, 0, 0.25))
		_preview(C["c"], pr)
		var nw := UI.text_w(fb, C["nm"], 17)
		draw_string(fb, Vector2(-nw / 2.0, pr.end.y + 22.0), C["nm"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tcol)
		var rw := UI.text_w(UI.noto_k(), C["rl"], 13)
		draw_string(UI.noto_k(), Vector2(-rw / 2.0, pr.end.y + 41.0), C["rl"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK if on else C["col"])
		var ky := pr.end.y + 62.0
		for line in C["kit"]:
			draw_string(fn, Vector2(lr.position.x + 16.0, ky), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(tcol, 0.85))
			ky += 16.0
		draw_set_transform(Vector2.ZERO)
	# 출격
	var gy := cy + ch + 16.0
	var gs := "출격"
	var gw := UI.text_w(fb, gs, 22) + 80.0
	go_rect = Rect2(cx - gw / 2.0, gy, gw, 42)
	draw_set_transform(Vector2(cx, gy + 21.0), deg_to_rad(-2.0))
	UI.para(self, -gw / 2.0 + 6.0, -21.0 + 6.0, gw, 42, 9.0, Color.BLACK)
	UI.para(self, -gw / 2.0, -21.0, gw, 42, 9.0, Color.WHITE)
	draw_string(fb, Vector2(-UI.text_w(fb, gs, 22) / 2.0 + 4.0, 8.0), gs, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.BLACK)
	draw_set_transform(Vector2.ZERO)
	var hint := "← → 선택 · Enter/탭 출격 · 게임 중 Tab으로 교체"
	UI.shadow_text(self, fn, Vector2(cx - UI.text_w(fn, hint, 13) / 2.0, gy + 70.0), hint, 13, Color(1, 1, 1, 0.8))

## idle loop of the member's sheet (row 0), cropped like the prototype's card canvas
func _preview(c: String, r: Rect2) -> void:
	var P = arena.player
	if P == null or not P.sheets.has(c): return
	var tim: Array = CH.TABLE[c]["idle"][1]
	var tot := 0.0
	for v in tim: tot += v
	var tm := fmod(clock, tot)
	var f := 0
	while tm > tim[f]:
		tm -= tim[f]
		f += 1
	var sheet: Texture2D = P.sheets[c][0]
	draw_texture_rect_region(sheet, Rect2(r.position, Vector2(120, 131)).intersection(r), Rect2(f * CH.CELL_W + 114, 105, 220, 240 * 120.0 / 131.0), Color.WHITE)
