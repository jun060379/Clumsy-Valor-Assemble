extends Control
## 설정 page (prototype #op2) and 조작 안내: a tilted list of slanted rows over the black band, the leader's standing
## art on the left. Toggles, the 12-step time slider, and the key list with inline rebinding (sortie.js ctrlGuide hook):
## press a slot, then the key; Esc cancels, Backspace clears; a key already in use leaves its old slot.

const UI := preload("res://scripts/ui_kit.gd")
const CFG := preload("res://scripts/settings.gd")
const SK := preload("res://scripts/skins.gd")       # member art through the worn costume

var arena
var menu
var mode := "opts"               # opts / help
var t := 0.0                     # since opened (row entrance)
var scroll := 0.0
var content_h := 0.0
var cap: Array = []              # [action, slot] while waiting for a key
var hits: Array = []             # [screen polygon, Callable]
var close_rect := Rect2()
var press_at := Vector2.INF
var dragged := false
var sil: Control
var art: Control
var fg: Control
var clock := 0.0
var sel := -1                    # keyboard / pad cursor: index into _rows() (-1 = none until a key is used)
var sel_j := 0                   # …and which button in that row (key slots, presets)
const LIVE := ["tog", "sld", "kb", "pre", "rmb"]
## the volume sliders (settings.gd "audio" keys and their labels), 11 steps = 0 … 100 % by tens
const VOLS := [["master", "전체 음량"], ["bgm", "배경음"], ["sfx", "효과음"], ["voice", "보이스"]]
const VOL_STEPS := 11


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sil = _layer(true)
	sil.draw.connect(_draw_sil)
	art = _layer(false)
	art.draw.connect(_draw_art)
	fg = _layer(false)
	fg.draw.connect(_draw_fg)

func _layer(solid: bool) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED    # only the halftone ground repeats
	if solid: c.material = UI.solid_mat()
	add_child(c)
	return c

func open(m: String) -> void:
	mode = m
	t = 0.0
	scroll = 0.0
	cap = []
	sel = -1
	sel_j = 0
	visible = true

func col() -> Color:
	return UI.col(arena.player.who)

func _process(delta: float) -> void:
	if not visible: return
	var dt := minf(delta * 1000.0, 250.0)   # real time, like the prototype's CSS / rAF clocks
	t += dt
	clock += dt
	queue_redraw()
	sil.queue_redraw()
	art.queue_redraw()
	fg.queue_redraw()


# ---------- rows ----------
func _rows() -> Array:
	var C = arena.cfg
	var R: Array = []
	if mode == "opts":
		R.append({"k": "tog", "lab": "캐릭터 도트화", "o": ["끄기", "도트", "도트+셰이딩"], "on": ["off", "dot", "shade"].find(arena.pix),
			"set": func(i):
				arena.pix = ["off", "dot", "shade"][i]
				arena.player.set_pix(arena.pix)})
		R.append({"k": "tog", "lab": "조작 기기", "o": ["자동", "키보드·마우스", "패드", "터치"], "on": ["auto", "kbm", "pad", "touch"].find(C.dev),
			"set": func(i): C.dev = ["auto", "kbm", "pad", "touch"][i]})
		R.append({"k": "tog", "lab": "이동 스틱", "o": ["따라오는 스틱", "고정 스틱"], "on": 0 if C.stick == "float" else 1,
			"set": func(i): C.stick = "float" if i == 0 else "fixed"})
		R.append({"k": "tog", "lab": "화면 효과 (빛 번짐·충격파·타격감)", "o": ["켜기", "끄기"], "on": 0 if arena.screen_fx else 1,
			"set": func(i): arena.screen_fx = i == 0})
		var hh := int(arena.tod_h)
		var mm := int(roundf((arena.tod_h - hh) * 60.0)) % 60
		R.append({"k": "sld", "lab": "시간 %02d:%02d" % [hh, mm], "n": 12, "on": roundi(arena.tod_h / 24.0 * 11.0),
			"set": func(k): arena.tod_h = minf(23.75, roundf(24.0 * k / 11.0 / 0.25) * 0.25)})
		R.append({"k": "tog", "lab": "시간 흐름", "o": ["켜기", "끄기"], "on": 0 if arena.tod_auto else 1,
			"set": func(i): arena.tod_auto = i == 0})
		R.append({"k": "tog", "lab": "날씨", "o": ["맑음", "비", "눈"], "on": ["clear", "rain", "snow"].find(arena.weather),
			"set": func(i): arena.weather = ["clear", "rain", "snow"][i]})
		R.append({"k": "tog", "lab": "환경음", "o": ["켜기", "끄기"], "on": 0 if arena.ambient else 1,
			"set": func(i): arena.ambient = i == 0})
		R.append({"k": "tog", "lab": "배경음 켜기/끄기", "o": ["켜기", "끄기"], "on": 0 if arena.music else 1,
			"set": func(i): arena.music = i == 0})
		# the volumes: 11 steps (0 … 100 %) onto the Master / BGM / SFX / Voice buses (settings.gd apply_audio); the
		# 효과음 slider answers with a click so the level can be heard, the music is already playing for 배경음
		for v in VOLS:
			var key: String = v[0]
			var pct := roundi(C.get_vol(key) * 100.0)
			R.append({"k": "sld", "lab": "%s %d%%" % [v[1], pct], "n": VOL_STEPS, "on": roundi(C.get_vol(key) * (VOL_STEPS - 1)), "vol": key,
				"set": func(i):
					C.set_vol(key, float(i) / (VOL_STEPS - 1))
					C.save()
					if key == "sfx": arena.sfx("ui_ok", 0.5)})
	# ctrlGuide
	var d: String = C.act_dev()
	var nm: String = {"kbm": "키보드 · 마우스", "pad": "패드", "touch": "터치"}[d]
	R.append({"k": "oh", "lab": "조작키 · " + nm + (" (자동)" if C.dev == "auto" else "")})
	if d == "pad":
		var on := Input.get_connected_joypads().size() > 0
		for r in [["패드", "연결됨" if on else "감지 안 됨 · 버튼을 한 번 눌러 주세요"], ["이동", "왼쪽 스틱 · 방향키"], ["계단 · 문", "위"], ["점프 · 결정", "A"], ["공격 · 상호작용", "X"],
				["가드", "Y · LT"], ["대시 · 뒤로", "B"], ["궁극기", "RT"], ["동료 전환", "LB · RB"], ["메뉴", "Start"], ["설정", "Back"]]:
			R.append({"k": "okb", "lab": r[0], "v": r[1]})
	elif d == "touch":
		for r in [["이동", "왼쪽 스틱"], ["점프 · 공격 · 가드", "오른쪽 버튼"], ["상호작용", "공격 버튼이 바뀜"], ["동료 전환", "초상화 누르기"]]:
			R.append({"k": "okb", "lab": r[0], "v": r[1]})
	else:
		R.append({"k": "pre", "lab": "프리셋"})
		for a in CFG.ACTS:
			R.append({"k": "kb", "lab": a[1], "a": a[0]})
		R.append({"k": "okb", "lab": "마우스 좌클릭", "v": "공격"})
		R.append({"k": "rmb", "lab": "마우스 우클릭"})
		R.append({"k": "tog", "lab": "마우스 조준", "o": ["끄기", "켜기"], "on": 1 if C.aim == "mouse" else 0,
			"set": func(i): C.aim = "mouse" if i == 1 else "off"})
		R.append({"k": "okb", "lab": "편성 슬롯으로 바로 교대", "v": "1 · 2 · 3"})
		R.append({"k": "okb", "lab": "전체화면 · 닫기", "v": "F · Esc"})
		R.append({"k": "hint", "lab": "칸을 누르고 키를 누르면 바뀐다 · Esc 취소 · Backspace 비우기"})
	return R


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if not visible or menu.ui_root.sweep.active:
		return
	# waiting for a key: it goes into the slot
	if cap.size() > 0 and ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = CFG.code_of(ev)
		var a: String = cap[0]
		var i: int = cap[1]
		cap = []
		if k != KEY_ESCAPE:
			arena.cfg.bind(a, i, 0 if k in [KEY_BACKSPACE, KEY_DELETE] else k)
		arena.sfx("ui_ok" if k != KEY_ESCAPE else "ui_back", 0.5)
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey:
		if ev.pressed and (ev.physical_keycode == KEY_ESCAPE or ev.keycode == KEY_ESCAPE):
			if not ev.echo: menu.close_page()
		elif ev.pressed:
			var k: int = ev.keycode
			if k in [KEY_DOWN, KEY_S]: _nav(1)
			elif k in [KEY_UP, KEY_W]: _nav(-1)
			elif k in [KEY_LEFT, KEY_A]: _side(-1)
			elif k in [KEY_RIGHT, KEY_D]: _side(1)
			elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and not ev.echo: _activate()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventJoypadButton:
		if ev.pressed:
			match ev.button_index:
				JOY_BUTTON_B: menu.close_page()
				JOY_BUTTON_DPAD_DOWN: _nav(1)
				JOY_BUTTON_DPAD_UP: _nav(-1)
				JOY_BUTTON_DPAD_LEFT: _side(-1)
				JOY_BUTTON_DPAD_RIGHT: _side(1)
				JOY_BUTTON_A: _activate()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			scroll += 40.0
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			scroll -= 40.0
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				press_at = ev.position
				dragged = false
			else:
				if press_at != Vector2.INF and not dragged:
					_click(ev.position)
				press_at = Vector2.INF
		_clamp_scroll()
	elif ev is InputEventMouseMotion and press_at != Vector2.INF:
		if ev.position.distance_to(press_at) > 8.0:
			dragged = true
		if dragged:
			scroll -= ev.relative.y
			_clamp_scroll()
		get_viewport().set_input_as_handled()
	elif ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		get_viewport().set_input_as_handled()

# ---------- keyboard / pad cursor ----------
func _nav(d: int) -> void:
	var rows := _rows()
	var i := sel
	for n in rows.size():
		i = (i + d + rows.size()) % rows.size() if i >= 0 else (0 if d > 0 else rows.size() - 1)
		if LIVE.has(rows[i]["k"]): break
	if not LIVE.has(rows[i]["k"]): return
	sel = i
	sel_j = 0
	arena.sfx("ui_move", 0.5)
	# keep the row in the box
	var rh := 33.0 if get_viewport_rect().size.y <= 420.0 else 38.0
	var y := 0.0
	for k in sel: y += 30.0 if rows[k]["k"] == "oh" else rh + 4.0
	var bh := _box(get_viewport_rect().size).size.y
	if y < scroll: scroll = y
	elif y + rh + 4.0 > scroll + bh: scroll = y + rh + 4.0 - bh
	_clamp_scroll()

func _side(d: int) -> void:
	var rows := _rows()
	if sel < 0 or sel >= rows.size():
		_nav(1)
		return
	var R: Dictionary = rows[sel]
	match R["k"]:
		"tog":
			var n: int = R["o"].size()
			R["set"].call(clampi(int(R["on"]) + d, 0, n - 1))
			arena.cfg.save()
		"sld":
			R["set"].call(clampi(int(R["on"]) + d, 0, int(R["n"]) - 1))
		"kb", "pre":
			sel_j = clampi(sel_j + d, 0, 1)
		"rmb":
			_activate()
			return
	_row_snd(R, "ui_move")

func _activate() -> void:
	var rows := _rows()
	if sel < 0 or sel >= rows.size():
		_nav(1)
		return
	var R: Dictionary = rows[sel]
	match R["k"]:
		"tog":
			var n: int = R["o"].size()
			R["set"].call((int(R["on"]) + 1) % n)
			arena.cfg.save()
		"sld":
			R["set"].call((int(R["on"]) + 1) % int(R["n"]))
		"kb":
			cap = [R["a"], sel_j]
		"pre":
			cap = []
			arena.cfg.use_preset(["arrow", "wasd"][sel_j])
		"rmb":
			arena.cfg.rmb = "guard" if arena.cfg.rmb == "dash" else "dash"
			arena.cfg.save()
	_row_snd(R, "ui_ok")

## a row's own answer: the 효과음 slider already clicks (its set plays ui_ok at the new level), every other row gets n
func _row_snd(R: Dictionary, n: String) -> void:
	if R.get("vol", "") == "sfx": return
	arena.sfx(n, 0.5)

func _click(p: Vector2) -> void:
	if close_rect.grow(6).has_point(p):
		cap = []
		menu.close_page()
		return
	for h in hits:
		if Geometry2D.is_point_in_polygon(p, h[0]):
			h[1].call()
			_row_snd(h[2] if h.size() > 2 else {}, "ui_ok")
			return
	cap = []

func _clamp_scroll() -> void:
	var box := _box(get_viewport_rect().size)
	scroll = clampf(scroll, 0.0, maxf(0.0, content_h - box.size.y))

func _box(vs: Vector2) -> Rect2:
	return Rect2(vs.x * 0.30, vs.y * 0.16, vs.x * 0.65, vs.y * 0.78)


# ---------- draw ----------
func _draw() -> void:
	var vs := get_viewport_rect().size
	var c := col()
	draw_rect(Rect2(Vector2.ZERO, vs), c)
	UI.burst(self, Vector2(vs.x * 0.1, vs.y * 0.8), maxf(vs.x, vs.y) * 1.6, 0.14, clock / 80000.0 * TAU)
	var sc := Vector2(-fmod(clock / 6000.0, 1.0) * 44.0, fmod(clock / 6000.0, 1.0) * 22.0)
	UI.dots(self, Rect2(Vector2.ZERO, vs), 0.26, 1.0, sc)
	var band := Rect2(0.3 * vs.x, -0.2 * vs.y, 0.9 * vs.x, 1.5 * vs.y)
	draw_colored_polygon(UI.rot(UI.clip(band, [[0, 0], [100, 0], [100, 100], [0, 100]]), band.get_center(), deg_to_rad(-12.0)), Color.BLACK)

func _art_rect(vs: Vector2) -> Rect2:
	var tex: Texture2D = menu._tex(SK.path(arena.player.who, "st_base"))
	var h := vs.y * 0.96
	var w := h * tex.get_width() / tex.get_height()
	return Rect2(-0.04 * vs.x, vs.y * 1.04 - h, w, h)

func _draw_sil() -> void:
	var vs := get_viewport_rect().size
	var r := _art_rect(vs)
	sil.draw_texture_rect(menu._tex(SK.path(arena.player.who, "st_base")), Rect2(r.position + Vector2(8, 0), r.size), false, Color.BLACK)

func _draw_art() -> void:
	var vs := get_viewport_rect().size
	art.draw_texture_rect(menu._tex(SK.path(arena.player.who, "st_base")), _art_rect(vs), false)

func _draw_fg() -> void:
	var vs := get_viewport_rect().size
	var c := col()
	var ci := fg
	# title
	var en := "CONFIG" if mode == "opts" else "HOW TO"
	var kr := "설정" if mode == "opts" else "조작 안내"
	var tf := 32 if vs.y <= 420.0 else 34
	ci.draw_set_transform(Vector2(20, 14), deg_to_rad(-6.0))
	ci.draw_string(UI.anton(false, 3), Vector2(0, 11), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	var tw := UI.text_w(UI.bhs(), kr, tf)
	UI.para(ci, 0, 15, tw + 24.0, tf + 4.0, 8.0, Color.BLACK)
	ci.draw_string(UI.bhs(), Vector2(12, 15.0 + tf * 0.98), kr, HORIZONTAL_ALIGNMENT_LEFT, -1, tf, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO)
	close_rect = menu._draw_close(ci, vs, c)
	# the list
	hits.clear()
	var box := _box(vs)
	var rows := _rows()
	var rh := 33.0 if vs.y <= 420.0 else 38.0
	var y := -scroll
	var pivot := box.get_center()
	var xf := Transform2D(deg_to_rad(-3.0), pivot) * Transform2D(0.0, box.position - pivot)
	var total := 0.0
	for i in rows.size():
		var R: Dictionary = rows[i]
		var h := 30.0 if R["k"] == "oh" else rh + 4.0
		total += h
		var ry := y
		y += h
		if ry + h < -4.0 or ry > box.size.y + 2.0:
			continue
		# entrance: rows swing in from the right one after another
		var e := UI.bk(clampf((t - i * 40.0) / 500.0, 0.0, 1.0))
		var a := clampf((t - i * 40.0) / 300.0, 0.0, 1.0)
		var edge := clampf(minf(ry + h, box.size.y - ry) / 12.0, 0.0, 1.0)
		a *= edge
		if a <= 0.0: continue
		var rx := xf * Transform2D(deg_to_rad(6.0) * (1.0 - e), Vector2(50.0 * (1.0 - e), ry))
		ci.draw_set_transform_matrix(rx)
		_row(ci, rx, R, box.size.x, rh, a, c)
		if i == sel:
			# the keyboard / pad cursor: a theme-colour rim round the row, a mark on the chosen slot
			var rim := UI.clip(Rect2(0, 0, box.size.x, rh), [[1, 0], [100, 0], [99, 100], [0, 100]])
			rim.append(rim[0])
			ci.draw_polyline(rim, Color(c, a), 2.0)
			if R["k"] in ["kb", "pre"]:
				ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, rh / 2.0 - 6.0), Vector2(-2, rh / 2.0), Vector2(-10, rh / 2.0 + 6.0)]), Color(c, a))
				var lab: String = ["첫째 칸", "둘째 칸"][sel_j] if R["k"] == "kb" else String(CFG.PRE[["arrow", "wasd"][sel_j]]["n"])   # PLACEHOLDER: cursor slot label
				ci.draw_string(UI.noto(), Vector2(box.size.x * 0.32, rh / 2.0 + 4.0), "◀ " + lab + " ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(c, a))
	ci.draw_set_transform(Vector2.ZERO)
	content_h = total + 10.0

func _row(ci: CanvasItem, xf: Transform2D, R: Dictionary, w: float, rh: float, a: float, c: Color) -> void:
	var fb := UI.noto()
	var bh := UI.bhs()
	if R["k"] == "oh":
		ci.draw_string(UI.anton(false, 4), Vector2(0, 24), R["lab"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(c, a))
		return
	ci.draw_colored_polygon(UI.clip(Rect2(0, 0, w, rh), [[1, 0], [100, 0], [99, 100], [0, 100]]), Color(0.082, 0.082, 0.082, a))
	var my := rh / 2.0
	if R["k"] == "hint":
		ci.draw_string(UI.noto(), Vector2(12, my + 4.0), R["lab"], HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 11, Color(1, 1, 1, 0.6 * a))
		return
	ci.draw_string(fb, Vector2(12, my + 5.0), R["lab"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))
	var right := w - 14.0
	match R["k"]:
		"tog":
			var labs: Array = R["o"]
			var ws: Array = []
			var tot := 0.0
			for s in labs:
				var ww := UI.text_w(bh, s, 15) + 20.0
				ws.append(ww)
				tot += ww + 4.0
			var x := right - tot + 4.0
			for j in labs.size():
				var on: bool = j == R["on"]
				var bw: float = ws[j]
				var bc := Vector2(x + bw / 2.0, my)
				var sc := 1.15 if on else 1.0
				var bx := Transform2D(deg_to_rad(-4.0) if on else 0.0, bc) * Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO)
				var poly := _para_pts(-bw / 2.0, -11.0, bw, 22.0, 4.7)
				ci.draw_set_transform_matrix(xf * bx)
				if on:
					ci.draw_colored_polygon(_shift(poly, Vector2(3, 3)), Color(1, 1, 1, a))
					ci.draw_colored_polygon(poly, Color(c, a))
				ci.draw_string(bh, Vector2(-bw / 2.0 + 10.0, 6.0), labs[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, a) if on else Color(0.4, 0.4, 0.4, a))
				ci.draw_set_transform_matrix(xf)
				var set_fn: Callable = R["set"]
				hits.append([_xf_poly(xf * bx, poly), func():
					set_fn.call(j)
					arena.cfg.save(), R])
				x += bw + 4.0
		"sld":
			var n: int = R["n"]
			var x0 := right - n * 15.0 + 3.0
			for k in n:
				var cell := _para_pts(x0 + k * 15.0, my - 9.0, 12.0, 18.0, 4.5)
				ci.draw_colored_polygon(cell, Color(c, a) if k <= R["on"] else Color(0.2, 0.2, 0.2, a))
				var set_fn2: Callable = R["set"]
				hits.append([_xf_poly(xf, _para_pts(x0 + k * 15.0 - 1.5, my - 12.0, 15.0, 24.0, 4.5)), func(): set_fn2.call(k), R])
		"okb":
			var v: String = R["v"]
			ci.draw_string(fb, Vector2(right - UI.text_w(fb, v, 12), my + 5.0), v, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85 * a))
		"kb":
			var act: String = R["a"]
			var x2 := right - 74.0 * 2.0 - 6.0
			for s in 2:
				var capd: bool = cap.size() > 0 and cap[0] == act and cap[1] == s
				var label: String = "키 입력…" if capd else CFG.key_name(int(arena.cfg.kb[act][s]))
				_kbtn(ci, xf, Rect2(x2, my - 12.0, 74, 24), label, capd, a, c, UI.anton(), func(): cap = [act, s])
				x2 += 80.0
		"pre":
			var x3 := right
			var keys := ["wasd", "arrow"]
			for pk in keys:
				var nm: String = CFG.PRE[pk]["n"]
				var bw2 := UI.text_w(bh, nm, 13) + 20.0
				x3 -= bw2
				_kbtn(ci, xf, Rect2(x3, my - 12.0, bw2, 24), nm, false, a, c, bh, func():
					cap = []
					arena.cfg.use_preset(pk))
				x3 -= 6.0
		"rmb":
			var lab2 := "대시" if arena.cfg.rmb == "dash" else "스킬"
			_kbtn(ci, xf, Rect2(right - 74.0, my - 12.0, 74, 24), lab2, false, a, c, UI.anton(), func():
				arena.cfg.rmb = "guard" if arena.cfg.rmb == "dash" else "dash"
				arena.cfg.save())

## white key slot; blinks in the theme colour while waiting for a key
func _kbtn(ci: CanvasItem, xf: Transform2D, r: Rect2, label: String, capd: bool, a: float, c: Color, f: Font, cb: Callable) -> void:
	var poly := UI.clip(r, [[6, 0], [100, 0], [94, 100], [0, 100]])
	var blink := 0.5 if capd and int(clock / 300.0) % 2 == 1 else 1.0
	ci.draw_colored_polygon(poly, Color(c, a * blink) if capd else Color(1, 1, 1, a))
	var tw := UI.text_w(f, label, 13)
	ci.draw_string(f, Vector2(r.get_center().x - tw / 2.0, r.position.y + 17.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a * blink) if capd else Color(0, 0, 0, a))
	hits.append([_xf_poly(xf, poly), cb])

static func _para_pts(x: float, y: float, w: float, h: float, sk: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x + sk, y), Vector2(x + w + sk, y), Vector2(x + w, y + h), Vector2(x, y + h)])

static func _shift(p: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p: out.append(v + o)
	return out

static func _xf_poly(xf: Transform2D, p: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p: out.append(xf * v)
	return out
