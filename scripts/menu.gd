extends Control
## Top-right buttons (prototype #topR: 전체화면, 길드 수첩, 모험 수첩, 파티, 캐릭터, 가방, 메뉴) and the Persona-style
## main menu (ph.js #phub) with its pages. Pages whose systems don't exist yet open a styled "준비 중" panel;
## 설정 and 조작 안내 are real (options.gd). Hub ↔ page changes go through the sweep (sortie.js txSweep2).

const UI := preload("res://scripts/ui_kit.gd")
const OPTIONS := preload("res://scripts/options.gd")
const ICON := {
	"fs": preload("res://assets/ui/icons/tb_fs.svg"), "gbk": preload("res://assets/ui/icons/tb_gbk.svg"), "abk": preload("res://assets/ui/icons/tb_abk.svg"),
	"pty": preload("res://assets/ui/icons/tb_pty.svg"), "cxb": preload("res://assets/ui/icons/tb_cxb.svg"), "bgb": preload("res://assets/ui/icons/tb_bgb.svg"),
	"mnu": preload("res://assets/ui/icons/tb_mnu.svg"),
}
## TBX + fs + mnu, left to right as laid out
const TB := [["fs", "전체화면"], ["gbk", "길드 수첩"], ["abk", "모험 수첩"], ["pty", "파티"], ["cxb", "캐릭터"], ["bgb", "가방"], ["mnu", "메뉴"]]
## PHM: key, name, English, line
const PHM := [["party", "파티", "PARTY", "함께 던전에 나설 동료."], ["char", "캐릭터", "CHARACTER", "능력치 · 장비 · 스킬 · 기억 · 기록."], ["bag", "가방", "INVENTORY", "던전에서 얻은 장비와 룬, 재화."], ["forge", "대장간", "FORGE", "브랜에게 강화 · 각인 · 합성 · 계승을 맡긴다."], ["best", "적 도감", "BESTIARY", "만난 적과 상성을 정리한 기록."], ["opts", "설정", "CONFIG", "소리 · 화면 · 조작 · 테스트."], ["help", "조작 안내", "HOW TO", "터치와 키보드 조작법."]]
## pages without their system yet: title (English small line, Korean big line) and icon
const PAGE := {
	"party": ["PARTY", "파티", "res://assets/ui/icons/ui_party.png"],
	"char": ["CHARACTER", "캐릭터", "res://assets/ui/icons/ui_character.png"],
	"bag": ["INVENTORY", "가방", "res://assets/ui/icons/ui_bag.png"],
	"forge": ["FORGE", "대장간", ""],
	"best": ["BESTIARY", "적 도감", "res://assets/ui/icons/ui_bestiary.png"],
	"gbk": ["GUILD BOOK", "길드 수첩", ""],          # PLACEHOLDER: English line invented (the prototype's page has its own layout)
	"abk": ["ADVENTURE BOOK", "모험 수첩", ""],      # PLACEHOLDER: English line invented
}
const ST := {"estelle": ["res://assets/ui/st/estelle_base.webp", "res://assets/ui/st/estelle_cl.webp"], "aida": ["res://assets/ui/st/aida_base.webp", "res://assets/ui/st/aida_cl.webp"], "luce": ["res://assets/ui/st/luce_base.webp", "res://assets/ui/st/luce_cl.webp"]}

var arena
var ui_root
var page := ""                  # "" / hub / opts / help / a PAGE key
var from_hub := false
var opts
var art_sil: Control
var art: Control
var fg: Control
var tex := {}

# top bar
var tb_rects := {}
var hover := Vector2(-999, -999)
var tb_press := ""
# hub
var ph_i := 0
var ph_c := "estelle"
var hub_t := 0.0               # since the hub (re)opened
var slam_t := 9999.0           # art slam clock
var info_t := 9999.0           # info card pop clock
var cur_from := Vector2.ZERO   # cursor (x, y) animation start
var cur_to := Vector2.ZERO
var cur_w0 := 0.0
var cur_w1 := 0.0
var cur_t := 9999.0
var blink := 2400.0
var item_rects: Array = []      # hit areas (screen) for menu items
var party_rects := {}
var close_rect := Rect2()
var clock := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	art_sil = _layer(true)
	art_sil.draw.connect(_draw_art_sil)
	art = _layer(false)
	art.draw.connect(_draw_art)
	fg = _layer(false)
	fg.draw.connect(_draw_fg)
	opts = Control.new()
	opts.set_script(OPTIONS)
	opts.arena = arena
	opts.menu = self
	add_child(opts)
	opts.visible = false

func _layer(solid: bool) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	c.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED    # only the halftone ground repeats
	if solid: c.material = UI.solid_mat()
	add_child(c)
	return c

func _tex(p: String) -> Texture2D:
	if p == "": return null
	if not tex.has(p): tex[p] = load(p)
	return tex[p]

func is_open() -> bool:
	return page != ""

func capturing() -> bool:
	return opts.visible and opts.cap.size() > 0

func tcol() -> Color:
	return UI.col(arena.player.who)


# ---------- opening / closing ----------
## phOpen: the hub through the sweep
func open_hub() -> void:
	if page != "": return
	ph_c = arena.player.who
	_release_keys()
	arena.sfx("ready", 0.4)
	ui_root.sweep.run(func(): _show_hub(true), UI.col(ph_c))

func _show_hub(fresh: bool) -> void:
	page = "hub"
	from_hub = false
	opts.visible = false
	hub_t = 0.0
	slam_t = 0.0
	if fresh: ph_i = ph_i
	_sel(ph_i, true)

func close_hub() -> void:
	arena.sfx("ready", 0.25)
	ui_root.sweep.run(func(): page = "", UI.col(ph_c))

## phEnter
func enter(i: int) -> void:
	var k: String = PHM[i][0]
	ui_root.sweep.run(func(): _open_page(k, true), UI.col(ph_c))

## a page straight from the top bar (m2Open: no sweep)
func open_page(k: String) -> void:
	if page != "": return
	_release_keys()
	arena.sfx("ready", 0.4)
	_open_page(k, false)

func _open_page(k: String, via_hub: bool) -> void:
	page = k
	from_hub = via_hub
	hub_t = 0.0
	if k == "opts" or k == "help":
		opts.open(k)
	else:
		opts.visible = false

## m2Close: back to the hub through the sweep when it came from there
func close_page() -> void:
	arena.sfx("ready", 0.25)
	if from_hub:
		ui_root.sweep.run(func():
			opts.visible = false
			_show_hub(false), UI.col(ph_c))
	else:
		opts.visible = false
		page = ""

func _release_keys() -> void:
	for a in ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "ult", "swap"]:
		if InputMap.has_action(a): Input.action_release(a)
	ui_root.mouse_held.clear()


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if ui_root.title.active or ui_root.sweep.active:
		return
	if ev is InputEventMouseMotion:
		hover = ev.position if ev.device != InputEvent.DEVICE_ID_EMULATION else Vector2(-999, -999)
		return
	if page == "":
		_input_bar(ev)
		return
	if page == "opts" or page == "help":
		return                   # options.gd takes it
	var tap := _tap(ev)
	var key := _key(ev)
	if page == "hub":
		_input_hub(ev, tap, key)
	else:
		# a "준비 중" page: ✕, Esc or the pad's B close it
		if (tap != Vector2.INF and close_rect.grow(6).has_point(tap)) or key == KEY_ESCAPE or (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_B):
			close_page()
		if tap != Vector2.INF or key >= 0 or ev is InputEventJoypadButton:
			get_viewport().set_input_as_handled()

static func _tap(ev: InputEvent) -> Vector2:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		return ev.position
	return Vector2.INF

static func _key(ev: InputEvent) -> int:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		return ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	return -1

func _bar_visible() -> bool:
	return page == "" and not ui_root.title.active and not arena.dlg.active

func _input_bar(ev: InputEvent) -> void:
	if not _bar_visible():
		return
	if ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_START:
		open_hub()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_BACK:
		_open_page("opts", false)
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		for id in tb_rects:
			if tb_rects[id].has_point(ev.position):
				get_viewport().set_input_as_handled()
				if ev.pressed:
					tb_press = id
				elif tb_press == id:
					tb_press = ""
					_bar_click(id)
				return
		if not ev.pressed: tb_press = ""
	elif ev is InputEventScreenTouch:
		for id in tb_rects:
			if tb_rects[id].has_point(ev.position):
				get_viewport().set_input_as_handled()      # keep the touch stick / buttons off it
				return

func _bar_click(id: String) -> void:
	match id:
		"fs": ui_root.toggle_fullscreen()
		"mnu": open_hub()
		"gbk", "abk": open_page(id)
		"pty": open_page("party")
		"cxb": open_page("char")
		"bgb": open_page("bag")

func _input_hub(ev: InputEvent, tap: Vector2, key: int) -> void:
	var handled := tap != Vector2.INF or key >= 0 or ev is InputEventJoypadButton
	var pad: int = ev.button_index if ev is InputEventJoypadButton and ev.pressed else -1
	if key in [KEY_DOWN, KEY_S] or pad == JOY_BUTTON_DPAD_DOWN:
		_sel((ph_i + 1) % PHM.size())
	elif key in [KEY_UP, KEY_W] or pad == JOY_BUTTON_DPAD_UP:
		_sel((ph_i + PHM.size() - 1) % PHM.size())
	elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or pad == JOY_BUTTON_A:
		enter(ph_i)
	elif key == KEY_ESCAPE or pad in [JOY_BUTTON_B, JOY_BUTTON_START]:
		close_hub()
	elif tap != Vector2.INF:
		if close_rect.grow(6).has_point(tap):
			close_hub()
		else:
			for c in party_rects:
				if party_rects[c].has_point(tap):
					if c != ph_c:
						ui_root.sweep.run(func():
							ph_c = c
							slam_t = 0.0
							_sel(ph_i, true), UI.col(c))
					return
			for i in item_rects.size():
				if _in_poly(item_rects[i], tap):
					if i == ph_i: enter(i)
					else: _sel(i)
					break
	if handled:
		get_viewport().set_input_as_handled()

static func _in_poly(poly: PackedVector2Array, p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)

## phSel
func _sel(i: int, quiet := false) -> void:
	var vs := get_viewport_rect().size
	var old := _cur_target(ph_i, vs)
	ph_i = i
	var nw := _cur_target(i, vs)
	cur_from = Vector2(old[0], old[1])
	cur_w0 = old[2]
	cur_to = Vector2(nw[0], nw[1])
	cur_w1 = nw[2]
	cur_t = 0.0 if not quiet else 9999.0
	if not quiet:
		info_t = 0.0
		arena.sfx("ready", 0.18)
	else:
		info_t = 9999.0


# ---------- per frame ----------
func _process(delta: float) -> void:
	var dt := minf(delta * 1000.0, 250.0)   # real time, like the prototype's CSS / rAF clocks
	clock += dt
	hub_t += dt
	slam_t += dt
	info_t += dt
	cur_t += dt
	blink -= dt
	if blink < -130.0: blink = 2400.0 + randf() * 2600.0
	queue_redraw()
	art_sil.queue_redraw()
	art.queue_redraw()
	fg.queue_redraw()


# ---------- top bar ----------
func _draw() -> void:
	var vs := get_viewport_rect().size
	tb_rects.clear()
	if _bar_visible():
		_draw_bar(vs)
	if page == "hub":
		_draw_hub_bg(vs)
	elif PAGE.has(page):
		_draw_page(vs)

func _draw_bar(vs: Vector2) -> void:
	var x := vs.x - 8.0
	var y := 6.0
	var h := 34.0
	var tc := tcol()
	for j in range(TB.size() - 1, -1, -1):
		var id: String = TB[j][0]
		var w := 46.0 if id == "mnu" else 40.0
		x -= w
		var r := Rect2(x, y, w, h)
		tb_rects[id] = r
		var tbx := id != "fs" and id != "mnu"
		var c := r.get_center()
		var d := hover.distance_to(c)
		var k := maxf(0.0, 1.0 - d / 90.0)
		var a := maxf(0.36, k) if tbx else 1.0
		var off := Vector2.ZERO
		if tbx and d > 0.0 and d < 90.0:
			off = Vector2((hover.x - c.x) / d * 4.0 * k, (hover.y - c.y) / d * 3.0 * k)
		var down := tb_press == id
		var poly := UI.clip(Rect2(r.position + off, r.size), [[16, 0], [100, 0], [84, 100], [0, 100]])
		draw_colored_polygon(poly, Color(1, 1, 1, a) if down else Color(0, 0, 0, 0.45 * a))
		var rim := poly.duplicate()
		rim.append(poly[0])
		draw_polyline(rim, Color(1, 1, 1, 0.55 * a), 1.5)
		if id == "mnu":
			draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(1, 1), poly[0] + Vector2(5, 1), poly[3] + Vector2(5, -1), poly[3] + Vector2(1, -1)]), tc)
		var ic: Texture2D = ICON[id]
		draw_texture_rect(ic, Rect2(c + off - Vector2(9, 9), Vector2(18, 18)), false, Color(0, 0, 0, a) if down else Color(1, 1, 1, a))
		x -= 3.0


# ---------- hub ----------
func _draw_hub_bg(vs: Vector2) -> void:
	var c1 := UI.col(ph_c)
	var c2 := UI.col2(ph_c)
	draw_rect(Rect2(Vector2.ZERO, vs), c1)
	UI.burst(self, Vector2(vs.x * 0.68, vs.y * 0.6), maxf(vs.x, vs.y) * 1.6, 0.14, clock / 80000.0 * TAU)
	UI.dots(self, Rect2(Vector2.ZERO, vs), 0.28, 0.42)
	var sh := Rect2(-0.14 * vs.x, -0.2 * vs.y, 0.6 * vs.x, 1.5 * vs.y)
	draw_colored_polygon(UI.rot(UI.clip(sh, [[0, 0], [86, 0], [100, 30], [82, 48], [94, 100], [0, 100]]), sh.get_center(), deg_to_rad(-12.0)), Color.BLACK)
	var ed := Rect2(0.42 * vs.x, -0.2 * vs.y, 0.035 * vs.x, 1.5 * vs.y)
	draw_colored_polygon(UI.rot(UI.clip(ed, [[0, 0], [100, 0], [100, 100], [0, 100]]), ed.get_center(), deg_to_rad(-12.0)), c2)
	var sl := Rect2(0.3 * vs.x, 0.84 * vs.y, 0.8 * vs.x, 18.0)
	draw_colored_polygon(UI.rot(UI.clip(sl, [[0, 40], [100, 0], [100, 30], [3, 100]]), sl.get_center(), deg_to_rad(-8.0)), Color.WHITE)
	# the member's name, huge and hollow
	var bf := UI.anton()
	var fs := int(vs.y * 0.36)
	var s: String = UI.EN[ph_c]
	var w := UI.text_w(bf, s, fs)
	draw_set_transform(Vector2(vs.x * 1.03 - w / 2.0, -0.08 * vs.y + fs * 0.4), deg_to_rad(-8.0))
	draw_string_outline(bf, Vector2(-w / 2.0, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO)

## art geometry: right 4%, bottom -2%, full height; breathing; the slam on open
func _art_xf(vs: Vector2) -> Dictionary:
	var t0: Texture2D = _tex(ST[ph_c][0])
	var h := vs.y
	var w := h * t0.get_width() / t0.get_height()
	var r := Rect2(vs.x * 0.96 - w, vs.y * 1.02 - h, w, h)
	var br := sin(clock / 4200.0 * TAU) * 0.5 + 0.5
	var u := clampf(slam_t / 650.0, 0.0, 1.0)
	var e := UI.bk(u)
	var dark := 1.0 if u < 0.45 else clampf(1.0 - (u - 0.45) / 0.15, 0.0, 1.0)
	return {"r": r, "tx": 0.3 * w * (1.0 - e), "rot": deg_to_rad(10.0) * (1.0 - e), "sc": (1.0 + 0.1 * (1.0 - e)) * (1.0 + 0.006 * br), "ty": -6.0 * br, "a": clampf(e, 0.0, 1.0), "dark": dark}

func _art_begin(ci: CanvasItem, X: Dictionary) -> Rect2:
	var r: Rect2 = X["r"]
	var pivot := Vector2(r.get_center().x, r.end.y)
	ci.draw_set_transform(pivot + Vector2(X["tx"], X["ty"]), X["rot"], Vector2(X["sc"], X["sc"]))
	return Rect2(r.position - pivot, r.size)

## a page's standing art (op2 .ochar): the leader at the left edge, a solid black drop to the right
func _ochar(vs: Vector2) -> Array:
	var t0: Texture2D = _tex(ST[arena.player.who][0])
	var h := vs.y * 0.96
	return [t0, Rect2(-0.04 * vs.x, vs.y * 1.04 - h, h * t0.get_width() / t0.get_height(), h)]

func _draw_art_sil() -> void:
	if PAGE.has(page):
		var O := _ochar(get_viewport_rect().size)
		var r: Rect2 = O[1]
		art_sil.draw_texture_rect(O[0], Rect2(r.position + Vector2(8, 0), r.size), false, Color.BLACK)
		return
	if page != "hub": return
	var X := _art_xf(get_viewport_rect().size)
	var lr := _art_begin(art_sil, X)
	var t0: Texture2D = _tex(ST[ph_c][0])
	var a: float = X["a"]
	art_sil.draw_texture_rect(t0, Rect2(lr.position + Vector2(16, 8), lr.size), false, Color(0, 0, 0, a))
	for o in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		art_sil.draw_texture_rect(t0, Rect2(lr.position + o, lr.size), false, Color(1, 1, 1, a))
	if X["dark"] > 0.0:
		art_sil.draw_texture_rect(t0, lr, false, Color(0, 0, 0, a))
	art_sil.draw_set_transform(Vector2.ZERO)

func _draw_art() -> void:
	if PAGE.has(page):
		var O := _ochar(get_viewport_rect().size)
		art.draw_texture_rect(O[0], O[1], false)
		return
	if page != "hub": return
	var X := _art_xf(get_viewport_rect().size)
	if X["dark"] >= 1.0: return
	var lr := _art_begin(art, X)
	var im: Texture2D = _tex(ST[ph_c][1] if blink < 0.0 else ST[ph_c][0])
	art.draw_texture_rect(im, lr, false, Color(1, 1, 1, X["a"] * (1.0 - X["dark"])))
	art.draw_set_transform(Vector2.ZERO)

func _items_layout(vs: Vector2) -> Dictionary:
	var fs := 26 if vs.y <= 420.0 else 30
	var lh := fs * 1.12
	return {"o": Vector2(maxf(26.0, 26.0), vs.y * 0.22), "fs": fs, "step": lh + 7.0, "rot": deg_to_rad(-9.0)}

## the cursor plates' target (x, y, width) for item i, in the menu's rotated frame
func _cur_target(i: int, vs: Vector2) -> Array:
	var L := _items_layout(vs)
	var fs: int = L["fs"]
	var w := UI.text_w(UI.bhs(), PHM[i][1], fs) * 1.38 + 30.0
	var y: float = i * L["step"] + L["step"] - 48.0
	return [float(i * 10 + 2), y, w]

func _draw_fg() -> void:
	if PAGE.has(page):
		_draw_page_fg(fg, get_viewport_rect().size)
		return
	if page != "hub": return
	var vs := get_viewport_rect().size
	var col := UI.col(ph_c)
	var ci := fg
	# logo, top left
	ci.draw_set_transform(Vector2(18, 22), deg_to_rad(-6.0))
	ci.draw_string(UI.anton(false, 4), Vector2(0, 11), "THE CLUMSY VALOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	var lw := UI.text_w(UI.bhs(), "어설픈 용맹", 15) + 16.0
	ci.draw_rect(Rect2(0, 15, lw, 20), Color.WHITE)
	ci.draw_string(UI.bhs(), Vector2(8, 31), "어설픈 용맹", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)
	ci.draw_string(UI.anton(true, 4), Vector2(0, 52), "-ASSEMBLE-", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))
	ci.draw_set_transform(Vector2.ZERO)
	# the menu: tilted list, the chosen one blown up black on a white plate over a colour plate
	var L := _items_layout(vs)
	var o: Vector2 = L["o"]
	var R: float = L["rot"]
	var fs: int = L["fs"]
	var step: float = L["step"]
	var bf := UI.bhs()
	var xf := Transform2D(R, o)
	# cursor
	var u := UI.bk(clampf(cur_t / 320.0, 0.0, 1.0))
	var cp := cur_from.lerp(cur_to, u)
	var cw := lerpf(cur_w0, cur_w1, clampf(cur_t / 250.0, 0.0, 1.0))
	var u2 := UI.bk(clampf((cur_t - 50.0) / 320.0, 0.0, 1.0))
	var cp2 := cur_from.lerp(cur_to, u2)
	var oa := clampf(hub_t / 300.0, 0.0, 1.0)
	_poly_xf(ci, xf * Transform2D(deg_to_rad(2.0), cp2 + Vector2(-8, 4)), Rect2(0, 0, cw + 12.0, 44), [[0, 34], [100, 8], [94, 100], [5, 84]], Color(col, oa))
	_poly_xf(ci, xf * Transform2D(deg_to_rad(-3.0), cp), Rect2(0, 0, cw, 44), [[3, 20], [97, 0], [100, 74], [7, 100]], Color(1, 1, 1, oa))
	item_rects.clear()
	var sf := UI.anton(false, 2)
	for i in PHM.size():
		var on := i == ph_i
		var base := Vector2(i * 10 + (14 if on else 0), i * step)
		var sc := 1.38 if on else 1.0
		# entrance: each item swings in from the upper left
		var e := UI.bk(clampf((hub_t - 100.0 - i * 45.0) / 450.0, 0.0, 1.0))
		var ia := clampf((hub_t - 100.0 - i * 45.0) / 200.0, 0.0, 1.0)
		var ex := Vector2(-60, -20) * (1.0 - e)
		var er := deg_to_rad(-30.0) * (1.0 - e)
		var rr := deg_to_rad(2.0 if i % 2 else -2.0) + er
		var lab: String = PHM[i][1]
		var tw := UI.text_w(bf, lab, fs)
		var pivot := base + ex + Vector2(0, step * 0.6)
		var it := xf * Transform2D(rr, pivot) * Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(0, -step * 0.6))
		item_rects.append(PackedVector2Array([it * Vector2(-4, 0), it * Vector2(tw + 8, 0), it * Vector2(tw + 8, step), it * Vector2(-4, step)]))
		ci.draw_set_transform_matrix(it)
		var a := ia * (1.0 if on else 0.85)
		ci.draw_string(sf, Vector2(0, 9), PHM[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col, a) if on else Color(0, 0, 0, 0.6 * a))
		var by := 6.0 + fs * 0.98
		if on:
			ci.draw_string(bf, Vector2(0, by), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a))
		else:
			ci.draw_string_outline(bf, Vector2(0, by), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, a))
			ci.draw_string(bf, Vector2(0, by), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
	ci.draw_set_transform(Vector2.ZERO)
	# party faces, top right, and the close button
	party_rects.clear()
	var P = arena.player
	var px: float = vs.x - 62.0 - P.party.size() * 48.0 + 6.0
	for c in P.party:
		var r := Rect2(px, 12, 42, 42)
		party_rects[c] = r
		var on2: bool = c == ph_c
		var s2 := 1.08 if on2 else 0.85
		ci.draw_set_transform(r.get_center(), deg_to_rad(-8.0 if on2 else -6.0), Vector2(s2, s2))
		var lr := Rect2(-21, -21, 42, 42)
		if on2: ci.draw_rect(Rect2(lr.position + Vector2(4, 4), lr.size), Color.WHITE)
		ci.draw_rect(lr, Color.BLACK if on2 else Color.WHITE)
		var st: Texture2D = _tex(ST[c][0])
		var k := 109.0 / st.get_width()
		var ih := st.get_height() * k
		var src := Rect2((109.0 - 36.0) * 0.58 / k, (ih - 36.0) * 0.06 / k, 36.0 / k, 36.0 / k)
		ci.draw_rect(lr.grow(-3), Color.BLACK)
		ci.draw_texture_rect_region(st, lr.grow(-3), src, Color.WHITE if on2 else Color(0.5, 0.48, 0.5))
		ci.draw_set_transform(Vector2.ZERO)
		px += 48.0
	close_rect = _draw_close(ci, vs, col)
	# the info card
	var m: Array = PHM[ph_i]
	var iw := minf(vs.x * 0.36, 300.0)
	var extra := _info(m[0])
	var ih2 := 92.0 if extra == "" else 110.0
	var pop := UI.bk(clampf(info_t / 350.0, 0.0, 1.0))
	var open_k := UI.bk(clampf((hub_t - 350.0) / 400.0, 0.0, 1.0))
	var pk := minf(pop, open_k)
	var ic := Vector2(vs.x - 22.0 - iw / 2.0 + 30.0 * (1.0 - pk), vs.y * 0.88 - ih2 / 2.0)
	ci.draw_set_transform(ic, deg_to_rad(-4.0 - 8.0 * (1.0 - pk)), Vector2.ONE * (0.85 + 0.15 * pk))
	var ir := Rect2(-iw / 2.0, -ih2 / 2.0, iw, ih2)
	var ia2 := clampf(pk * 1.5, 0.0, 1.0)
	ci.draw_colored_polygon(UI.clip(ir, [[0, 0], [100, 6], [97, 100], [2, 94]]), Color(0, 0, 0, ia2))
	ci.draw_colored_polygon(UI.clip(Rect2(ir.position, Vector2(6, ih2)), [[0, 0], [100, 0], [100, 94], [0, 94]]), Color(col, ia2))
	var tx := ir.position.x + 18.0
	ci.draw_string(UI.anton(false, 2), Vector2(tx, ir.position.y + 22.0), m[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, ia2))
	ci.draw_string(bf, Vector2(tx, ir.position.y + 46.0), m[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, ia2))
	ci.draw_string(UI.noto(), Vector2(tx, ir.position.y + 68.0), m[3], HORIZONTAL_ALIGNMENT_LEFT, iw - 30.0, 12, Color(0.87, 0.87, 0.87, ia2))
	if extra != "":
		ci.draw_string(UI.noto(), Vector2(tx, ir.position.y + 86.0), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col, ia2))
	ci.draw_set_transform(Vector2.ZERO)
	# money, bottom left
	ci.draw_set_transform(Vector2(22, vs.y - 22.0), deg_to_rad(-3.0))
	var cx := 0.0
	for pair in [["실링 ", str(arena.shilling)], ["기억석 ", "0"]]:     # 기억석: PLACEHOLDER (no memory stones yet)
		var w0 := UI.text_w(bf, pair[0], 14)
		var w1 := UI.text_w(bf, pair[1], 14)
		UI.para(ci, cx, -10, w0 + w1 + 20.0, 22, 3.9, Color.BLACK)
		ci.draw_string(bf, Vector2(cx + 10.0, 6), pair[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		ci.draw_string(bf, Vector2(cx + 10.0 + w0, 6), pair[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)
		cx += w0 + w1 + 28.0
	ci.draw_set_transform(Vector2.ZERO)

## phInfo: the extra line under an entry
func _info(k: String) -> String:
	if k == "party": return "%d / 3 편성" % arena.player.party.size()
	if k == "forge": return "실링 %d" % arena.shilling
	return ""

func _poly_xf(ci: CanvasItem, xf: Transform2D, r: Rect2, pct: Array, c: Color) -> void:
	var pts := UI.clip(r, pct)
	var out := PackedVector2Array()
	for p in pts: out.append(xf * p)
	ci.draw_colored_polygon(out, c)

## the round ✕ (black, white rim, colour drop)
func _draw_close(ci: CanvasItem, vs: Vector2, col: Color) -> Rect2:
	var c := Vector2(vs.x - 14.0 - 18.0, 14.0 + 18.0)
	ci.draw_circle(c + Vector2(3, 3), 18.0, col)
	ci.draw_circle(c, 18.0, Color.BLACK)
	ci.draw_arc(c, 17.0, 0, TAU, 32, Color.WHITE, 2.0, true)
	UI.cross(ci, c, 5.0, Color.WHITE, 2.0)
	return Rect2(c - Vector2(18, 18), Vector2(36, 36))


# ---------- a page whose system isn't here yet ----------
func _draw_page(vs: Vector2) -> void:
	var col := tcol()
	draw_rect(Rect2(Vector2.ZERO, vs), col)
	# the 설정 page's ground (op2): burst low left, drifting dots, the black band from 30 % to the right
	UI.burst(self, Vector2(vs.x * 0.1, vs.y * 0.8), maxf(vs.x, vs.y) * 1.6, 0.14, clock / 80000.0 * TAU)
	var sc := Vector2(-fmod(clock / 6000.0, 1.0) * 44.0, fmod(clock / 6000.0, 1.0) * 22.0)
	UI.dots(self, Rect2(Vector2.ZERO, vs), 0.26, 1.0, sc)
	var band := Rect2(0.3 * vs.x, -0.2 * vs.y, 0.9 * vs.x, 1.5 * vs.y)
	draw_colored_polygon(UI.rot(UI.clip(band, [[0, 0], [100, 0], [100, 100], [0, 100]]), band.get_center(), deg_to_rad(-12.0)), Color.BLACK)

## over the art: the title, the "준비 중" slab, the entry's line, ✕
func _draw_page_fg(ci: CanvasItem, vs: Vector2) -> void:
	var P: Array = PAGE[page]
	var col := tcol()
	# title, top left
	ci.draw_set_transform(Vector2(20, 14), deg_to_rad(-6.0))
	ci.draw_string(UI.anton(false, 3), Vector2(0, 11), P[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	var tw := UI.text_w(UI.bhs(), P[1], 34)
	UI.para(ci, 0, 15, tw + 24.0, 38, 8.0, Color.BLACK)
	ci.draw_string(UI.bhs(), Vector2(12, 46), P[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO)
	# the notice: a slab that stamps in
	var u := clampf(hub_t / 500.0, 0.0, 1.0)
	var e := UI.bk(u)
	var c := Vector2(vs.x * 0.62, vs.y * 0.5)
	ci.draw_set_transform(c, deg_to_rad(-4.0 - 8.0 * (1.0 - e)), Vector2.ONE * (1.0 + 1.2 * (1.0 - e)))
	var ns := "준비 중"                     # PLACEHOLDER: the page's real content comes with its system
	var fs := 56
	var nw := UI.text_w(UI.bhs(), ns, fs) + 70.0
	var a := clampf(u * 2.0, 0.0, 1.0)
	UI.para(ci, -nw / 2.0 + 8.0, -40.0 + 8.0, nw, 80, 16.0, Color(col, a))
	UI.para(ci, -nw / 2.0, -40.0, nw, 80, 16.0, Color(1, 1, 1, a))
	var ic: Texture2D = _tex(P[2])
	var tx := -nw / 2.0 + 35.0
	if ic != null:
		ci.draw_texture_rect(ic, Rect2(tx - 6.0, -26.0, 52, 52), false, Color(0, 0, 0, a))
		tx += 52.0
	ci.draw_string(UI.bhs(), Vector2(tx, 20.0), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a))
	ci.draw_set_transform(Vector2.ZERO)
	var line := ""
	for m in PHM:
		if m[0] == page: line = m[3]
	if line != "":
		var lw := UI.text_w(UI.noto(), line, 13)
		UI.para(ci, c.x - lw / 2.0 - 14.0, c.y + 62.0, lw + 28.0, 24, 4.0, Color(0, 0, 0, a))
		ci.draw_string(UI.noto(), Vector2(c.x - lw / 2.0, c.y + 79.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a))
	close_rect = _draw_close(ci, vs, col)
