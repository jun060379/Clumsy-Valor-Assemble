extends Control
## 길드 수첩 and 모험 수첩 (fame_ui.js / fame_core.js fmQuest · fmFac · fmPeople · fmDun · abHome · abLv · abCh · abDay):
## the menu pages "gbk" and "abk". A colour band across the top (guild yellow / adventure blue), the title, tabs, the purse,
## the other book's bookmark, the big number panel (rank / level) with its info menu on the left, and the paper sheet
## the rows are written on. Click / tap the buttons; wheel or drag scrolls the sheet; ←/→ (Q/E, LB/RB) change tabs,
## Tab switches books, Esc / B closes.

const S := preload("res://scripts/fame_skin.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const FD := preload("res://scripts/fame_data.gd")
const BOOKCOL := {"gbk": Color("#ffd34d"), "abk": Color("#7fd0ff")}
const TABS := {"gbk": [["quest", "명성", "FAME"], ["fac", "시설", "FACILITY"], ["people", "동료", "MEMBERS"], ["dun", "던전", "DUNGEON"], ["rune", "룬 도감", "RUNES"]],
	"abk": [["home", "개요", "OVERVIEW"], ["lv", "모험 레벨", "LEVEL"], ["ch", "모험 일지", "LOG"], ["day", "일일 훈련", "DAILY"]]}
## where the big number panel sits: L = top of the left column, R = shrunk into the bottom-right corner
const HDOCK := {"quest": "L", "fac": "L", "home": "L", "lv": "L", "day": "L", "people": "R", "dun": "R", "rune": "R", "ch": "R"}
const ORD := {"letter": 0, "done": 1, "run": 2, "wait": 2.5, "got": 3, "lock": 4}
const INK := Color("#2b2218")
const INK2 := Color("#5a4e42")
const INK3 := Color("#8a7a66")
const PAPER := Color("#efe6d1")
const RED := Color("#ff5a5a")

var menu
var arena
var fame
var tab := {"gbk": "quest", "abk": "home"}
var im := {"rank": 0, "exp": 0}
var dun_i := 0
var chi := -1
var scroll := {}                # tab -> y (or x for the level road)
var t := 0.0                    # since the page opened (entrance)
var tab_t := 0.0                # since the tab changed
var hits: Array = []            # [Rect2, Callable]
var paper_r := Rect2()
var content_h := 0.0
var drag := {}
# the level road (roadInit): drag with rubber-banding at the ends, a flick carries on and snaps to a card, the wheel and
# the keys step a card, it glides in on open and to a card that is claimed
const ROAD_STEP := 178.0          # .lv: 168 px cards, 10 apart
var road_sp = null               # UIA.Spring on scroll["lv"] while it glides
var road_w := 600.0              # the road's view width (cr) as last drawn
var hover := Vector2(-999, -999)
var tex := {}
var cur_book := ""
# ---- motion (fame_ui.js openFx / headerFx / pageSlide / fmClose / wipe / tabInd / heroSync) ----
var _ci                         # what the page draws through: a UIA.Pen on this canvas item (group transform + opacity)
var pen
var trn := UIA.Tr.new()         # CSS transitions (the background layers per tab, the tabs' scale)
var hdr_t := 0.0                # header clock (headerFx), hdr_d its delay
var hdr_d := 300.0
var hdr_hide := false           # under the wiper
var closing := -1.0             # fmClose clock (ms), -1 = not closing
var slide_t := 1e9              # pageSlide clock
var slide_dir := 1
var slide_n := 0
var slide_old := Rect2()        # where the old sheet lay
var slide_tab := ""             # the tab that was on it (its rows ride on the old sheet)
var rowsig := {}                # tab -> {row key -> signature}: per-row identity for the in-place morphs
var row_fx := {}                # row key -> [kind (swap / new), ms]
var claim_r := Rect2()          # the last 받기 / 복구 button drawn (test hook)
var claims: Array = []          # deferred claims: [Callable, ms left] (claimFx applies when the first chip lands)
var lead_t := 1e9               # .bgl.lead (the slash leads a tab change)
var bump_t := 1e9               # .wal.bump / .bm.bump
var wipe_t := -1.0              # book switch fan, -1 = none
var wipe_to := ""
var wipe_from := Color.WHITE
var wipe_mid := false
var ind_l := UIA.Spring.new(0.0, 0.38, 0.82)
var ind_w := UIA.Spring.new(0.0, 0.42, 0.9)
var ind2_l := UIA.Spring.new(0.0, 0.62, 0.7)
var ind2_w := UIA.Spring.new(0.0, 0.6, 0.9)
var ind_init := false
var hero_dock := ""
var hero_off := Vector2.ZERO    # hero spring offset (it glides between docks)
var hero_sp := [UIA.Spring.new(0.0, 0.62, 0.8), UIA.Spring.new(0.0, 0.62, 0.8), UIA.Spring.new(0.0, 0.75, 0.55), UIA.Spring.new(1.0, 0.7, 0.8)]
var hero_last := Rect2()
var stamps: Array = []          # stampFx: {p, text, t, dk}
var flies: Array = []           # moveEl: reward labels flying to the purse / the hero {from, to, text, t, d}
var jolt_t := 1e9               # the paper's jolt under the stamp
var purse_at: Array = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var hot_t: Array = [1e9, 1e9, 1e9]   # fm_hit on a purse token when a chip lands
const EZ := [0.2, 0.9, 0.25, 1.0]
const BK := [0.2, 1.5, 0.4, 1.0]
const FMIN := [0.16, 1.0, 0.3, 1.0]
const SLOUT := [0.55, 0.0, 0.85, 0.4]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visible = false
	pen = UIA.Pen.new(self)
	_ci = pen
	if OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(func(a: Array): _js(str(a[0]) if a.size() > 0 else ""))
		JavaScriptBridge.get_interface("window").cvaBook = _js_cb

## web test hook (screenshots): window.cvaBook("tab dun" | "switch" | "close")
var _js_cb
func _js(cmd: String) -> void:
	var w := cmd.split(" ")
	match w[0]:
		"tab": _go_tab(w[1])
		"switch": _switch_book()
		"close": close_fx()
		"claim": if claim_r.size.x > 0.0: _click(claim_r.get_center())

func book() -> String:
	return menu.page if menu.page in ["gbk", "abk"] else ""

func cur_tab() -> String:
	return tab[book()] if book() != "" else ""

func col() -> Color:
	return BOOKCOL.get(book(), BOOKCOL["gbk"])

func _tex(p: String) -> Texture2D:
	if not tex.has(p): tex[p] = load(p)
	return tex[p]

## fameOpen / advOpen
func set_tab(b: String, tb: String) -> void:
	for x in TABS[b]:
		if x[0] == tb: tab[b] = tb

func _process(delta: float) -> void:
	var b := book()
	visible = b != ""
	if not visible:
		cur_book = ""
		return
	if b != cur_book:
		if cur_book == "" or wipe_t < 0.0:
			_open_fx()
		cur_book = b
		fame.poll(true)
	var dt := minf(delta * 1000.0, 250.0)
	t += dt
	tab_t += dt
	hdr_t += dt
	slide_t += dt
	jolt_t += dt
	for k in row_fx.keys():
		row_fx[k][1] += dt
		if row_fx[k][1] > 900.0: row_fx.erase(k)
	if not claims.is_empty():
		var due: Array = []
		for cl in claims:
			cl[1] -= dt
			if cl[1] <= 0.0: due.append(cl)
		for cl in due:
			claims.erase(cl)
			cl[0].call()
			fame.poll(true)
	if road_sp != null:
		scroll["lv"] = road_sp.step(dt)
		if absf(road_sp.x - road_sp.t) < 0.4 and absf(road_sp.v) < 6.0:
			scroll["lv"] = road_sp.t
			road_sp = null
	for i in 3: hot_t[i] += dt
	for st in stamps: st["t"] += dt
	stamps = stamps.filter(func(st): return st["t"] < 1200.0)
	for f in flies:
		f["t"] += dt
		if f["t"] - f["d"] >= 520.0 and not f.get("hit", false):
			f["hit"] = true
			if f["k"] >= 0: hot_t[f["k"]] = 0.0
	flies = flies.filter(func(f): return f["t"] - f["d"] < 520.0)
	lead_t += dt
	bump_t += dt
	trn.step(dt)
	for sp in [ind_l, ind_w, ind2_l, ind2_w]: sp.step(dt)
	for sp in hero_sp: sp.step(dt)
	if closing >= 0.0:
		closing += dt
		if closing >= 440.0:
			closing = -1.0
			menu.close_page()
	if wipe_t >= 0.0:
		wipe_t += dt
		if not wipe_mid and wipe_t >= 1140.0 * 0.35:
			wipe_mid = true
			hdr_hide = true
			menu.page = wipe_to
			cur_book = wipe_to
			tab_t = 0.0
			slide_t = 1e9
			fame.poll(true)
			S.play(self, S.noise_wav(0.16), 0.2)
		if wipe_t >= 1140.0:
			wipe_t = -1.0
			hdr_hide = false
			hdr_t = 0.0
			hdr_d = 0.0
	queue_redraw()

## openFx: everything files in (t = 0); the rows start at 380 ms
func _open_fx() -> void:
	t = 0.0
	tab_t = -380.0
	hdr_t = 0.0
	hdr_d = 300.0
	closing = -1.0
	slide_t = 1e9
	lead_t = 1e9
	bump_t = 1e9
	ind_init = false
	hero_dock = ""
	trn.clear()
	S.play(self, S.noise_wav(0.16), 0.26)

## fmClose: the sheet drops, the band leaves, the header lifts away; the page goes after 440 ms
func close_fx() -> void:
	if closing >= 0.0 or wipe_t >= 0.0: return
	closing = 0.0
	S.play(self, S.noise_wav(0.16), 0.18)

func busy() -> bool:
	return closing >= 0.0 or wipe_t >= 0.0


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if not visible or book() == "": return
	if menu.ui_root.sweep.active or fame.fx.blocking(): return
	if busy():
		if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton or ev is InputEventScreenTouch:
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseMotion:
		hover = ev.position
		if not drag.is_empty() and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var d: Vector2 = ev.position - drag["p"]
			if d.length() > 6.0: drag["moved"] = true
			if drag["moved"] and cur_tab() == "lv" and drag.has("x0"):
				road_sp = null
				scroll["lv"] = road_rb(float(drag["sx0"]) - (ev.position.x - float(drag["x0"])))
				var hs: Array = drag["hist"]
				hs.append([float(t), ev.position.x])
				if hs.size() > 7: hs.pop_front()
			elif drag["moved"]:
				_scroll_by(-(d.x if cur_tab() == "lv" else d.y))
				drag["p"] = ev.position
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed: _scroll_by(48.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed: _scroll_by(-48.0)
		elif ev.button_index in [MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_LEFT] and ev.pressed: _scroll_by(48.0 if ev.button_index == MOUSE_BUTTON_WHEEL_RIGHT else -48.0)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				drag = {"p": ev.position, "moved": false, "in": paper_r.has_point(ev.position)}
				if cur_tab() == "lv":
					drag["x0"] = ev.position.x
					drag["sx0"] = float(scroll.get("lv", 0.0))
					drag["hist"] = [[float(t), ev.position.x]]
					road_sp = null
			else:
				var moved: bool = drag.get("moved", false)
				var dr := drag
				drag = {}
				if moved and cur_tab() == "lv" and dr.has("hist"): road_fling(dr["hist"])
				if not moved: _click(ev.position)
		return
	if ev is InputEventScreenTouch or ev is InputEventScreenDrag:
		get_viewport().set_input_as_handled()
		return
	var k := -1
	if ev is InputEventKey and ev.pressed:
		k = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	var pad := -1
	if ev is InputEventJoypadButton and ev.pressed: pad = ev.button_index
	if k >= KEY_F1 and k <= KEY_F12: return     # test keys pass through
	if k < 0 and pad < 0:
		if ev is InputEventKey or ev is InputEventJoypadButton: get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if k == KEY_ESCAPE or pad == JOY_BUTTON_B or pad == JOY_BUTTON_START:
		close_fx()
	elif k in [KEY_RIGHT, KEY_E, KEY_D] or pad == JOY_BUTTON_RIGHT_SHOULDER:
		_tab_step(1)
	elif k in [KEY_LEFT, KEY_Q, KEY_A] or pad == JOY_BUTTON_LEFT_SHOULDER:
		_tab_step(-1)
	elif k == KEY_TAB or pad == JOY_BUTTON_BACK:
		_switch_book()
	elif k in [KEY_DOWN, KEY_S] or pad == JOY_BUTTON_DPAD_DOWN:
		_scroll_by(60.0)
	elif k in [KEY_UP, KEY_W] or pad == JOY_BUTTON_DPAD_UP:
		_scroll_by(-60.0)

func _click(p: Vector2) -> void:
	for i in range(hits.size() - 1, -1, -1):
		var h: Array = hits[i]
		if h[0].has_point(p):
			h[1].call()
			return

func _hit(r: Rect2, cb: Callable) -> void:
	hits.append([r, cb])

func _tab_step(d: int) -> void:
	var L: Array = TABS[book()]
	var i := 0
	for j in L.size():
		if L[j][0] == cur_tab(): i = j
	_go_tab(L[(i + d + L.size()) % L.size()][0])

func _go_tab(tb: String) -> void:
	if tb == cur_tab(): return
	if book() == "gbk" and tb == "rune":
		# the 룬 도감 tab is a door: the rune codex book opens over the town (prototype fmEl click → cdxOpen('rune'))
		menu.page = ""
		menu.open_codex("rune")
		return
	var L: Array = TABS[book()]
	var ti := 0
	var tj := 0
	for j in L.size():
		if L[j][0] == tb: ti = j
		if L[j][0] == cur_tab(): tj = j
	_page_slide(1 if ti >= tj else -1, absi(ti - tj))
	tab[book()] = tb
	arena.sfx("step", 0.3)
	S.play(self, S.noise_wav(0.16), 0.18)
	fame.poll(true)

func _switch_book() -> void:
	_wipe("abk" if book() == "gbk" else "gbk")

func _wipe(to: String) -> void:
	if wipe_t >= 0.0 or closing >= 0.0 or to == book(): return
	wipe_to = to
	wipe_from = col()
	wipe_t = 0.0
	wipe_mid = false
	arena.sfx("ready", 0.3)

## pageSlide: a new sheet (and n - 1 blank ones) slides over the old one going right, the old one slides off going left
func _page_slide(dir: int, steps: int) -> void:
	slide_t = 0.0
	slide_dir = dir
	slide_n = mini(3, maxi(0, steps - 1))
	slide_old = paper_r
	slide_tab = cur_tab()
	lead_t = 0.0
	bump_t = 0.0
	tab_t = -float(slide_n * 90 + 120) if dir > 0 else 0.0

func _goto(b: String, tb: String) -> void:
	if b != book():
		tab[b] = tb
		_wipe(b)
		return
	elif tb != cur_tab():
		_go_tab(tb)
		return
	tab[b] = tb
	tab_t = 0.0
	arena.sfx("step", 0.3)

func _scroll_by(d: float) -> void:
	var tb := cur_tab()
	if tb == "lv":
		# a wheel notch or a key: one card along (it springs there)
		var from: float = road_sp.t if road_sp != null else float(scroll.get("lv", 0.0))
		road_go(roundf((from + signf(d) * ROAD_STEP) / ROAD_STEP) * ROAD_STEP, 0.0, 0.42, 1.0)
		return
	var mx := _scroll_max()
	scroll[tb] = clampf(float(scroll.get(tb, 0.0)) + d, 0.0, mx)

## the road's rubber band: past an end it gives way less and less (overshoot^0.72)
func road_rb(sx: float) -> float:
	var mx := _road_max()
	if sx < 0.0: return -pow(-sx, 0.72)
	if sx > mx: return mx + pow(sx - mx, 0.72)
	return sx

func _road_max() -> float:
	return maxf(0.0, (FD.AMAX - 1) * ROAD_STEP - (paper_r.size.x - 60.0))

## spring to a place on the road (clamped to its ends), with a starting speed (px/s along the scroll)
func road_go(target: float, v: float, resp: float, damp: float) -> void:
	var x: float = float(scroll.get("lv", 0.0))
	road_sp = UIA.Spring.new(x, resp, damp)
	road_sp.v = v
	road_sp.t = clampf(target, 0.0, _road_max())

## a release after a drag: the flick's speed over the last few moves carries it on (decay .998), then it snaps to a card
func road_fling(h: Array) -> void:
	if h.size() < 1: return
	var dtm := maxf(16.0, float(h[h.size() - 1][0]) - float(h[0][0]))
	var v: float = (float(h[h.size() - 1][1]) - float(h[0][1])) / dtm * 1000.0     # px/s, the road's way (left = negative)
	var sx: float = float(scroll.get("lv", 0.0))
	var proj := sx - (v / 1000.0) * 0.998 / (1.0 - 0.998) * 0.35
	road_go(roundf(proj / ROAD_STEP) * ROAD_STEP, -v * 0.9, 0.6, 0.86)

## where the road sits with level lv's card in the middle
func road_center(lv: int) -> float:
	return (lv - 2) * ROAD_STEP + 84.0 - road_w / 2.0

func road_to(lv: int, resp := 0.5) -> void:
	road_go(roundf(road_center(lv) / ROAD_STEP) * ROAD_STEP, 0.0, resp, 0.85)

func _scroll_max() -> float:
	if cur_tab() == "lv":
		return maxf(0.0, (FD.AMAX - 1) * ROAD_STEP - (paper_r.size.x - 60.0))
	return maxf(0.0, content_h - paper_r.size.y + 16.0)


# =====================================================================
func _draw() -> void:
	hits.clear()
	var b := book()
	if b == "": return
	var vs := get_viewport_rect().size
	var fa := col()
	var tb := cur_tab()
	pen.reset()
	var cl := closing
	# ground: ink, drifting dots (fmdots)
	_ci.draw_rect(Rect2(Vector2.ZERO, vs), Color("#0d0b10"))
	var dof := fmod(t / 7000.0, 1.0) * 12.0
	S.dots(_ci, Rect2(Vector2.ZERO, vs), 12.0, 1.6, Color(1, 1, 1, 0.06), Vector2(dof, dof))
	_draw_bgl(vs, fa, tb)
	_draw_speed(vs)
	# the colour band (fm_breath), sliding in from the upper left (openFx) and back out (fmClose)
	var br := 0.5 - 0.5 * cos(t / 7000.0 * TAU)
	var band := Rect2(-0.1 * vs.x, -30.0 + 2.0 * br, vs.x * 1.2, 120.0)
	var bk := UIA.p(t, 170.0, 460.0, EZ)
	if cl >= 0.0: bk = 1.0 - UIA.p(cl, 60.0, 380.0, SLOUT)
	pen.group(UIA.xf(band.get_center(), Vector2(-0.7 * band.size.x, -0.6 * band.size.y) * (1.0 - bk)))
	_ci.draw_set_transform(band.get_center(), deg_to_rad(-4.0 + 0.6 * br))
	_ci.draw_rect(Rect2(-band.size / 2.0, band.size), fa)
	pen.reset()
	# the pane
	var pane := Rect2(16, 106, vs.x - 32, vs.y - 118)
	var dock: String = HDOCK.get(tb, "L")
	var left_w := 0.0
	match tb:
		"quest", "fac", "home", "lv", "day": left_w = pane.size.x * (0.34 if tb == "fac" else (0.29 if tb == "lv" else 0.31))
		"dun": left_w = pane.size.x * 0.26
		"ch": left_w = pane.size.x * 0.30
	paper_r = Rect2(pane.position.x + (left_w + 14.0 if left_w > 0.0 else 0.0), pane.position.y, pane.size.x - (left_w + 14.0 if left_w > 0.0 else 0.0), pane.size.y)
	# the sheets: the old one (blank) under or over the new one while a tab turns
	var ps := _paper_xf(paper_r)
	var going_out := slide_t < 600.0 + slide_n * 90.0 and slide_dir < 0
	if slide_t < 520.0 + slide_n * 90.0 and slide_dir > 0:
		var oa: float = 1.0 - UIA.kf(slide_t, [[0.0, 0.0], [0.6, 0.0], [1.0, 1.0]], 520.0, slide_n * 90.0)
		pen.group(Transform2D.IDENTITY, oa)
		_old_sheet()
		for i in slide_n:
			pen.group(_sl_in(slide_old, slide_t, i * 90.0, 360.0), 1.0)
			_draw_paper(slide_old, 1.0)
	var jo: Vector2 = UIA.kf(jolt_t, [[0.0, Vector2.ZERO], [0.33, Vector2(0, 3)], [0.66, Vector2(-1, -2)], [1.0, Vector2.ZERO]], 200.0)
	pen.group(Transform2D(0.0, jo) * ps[0], ps[1])
	_draw_paper(paper_r, 1.0)
	_content(tb, paper_r)
	if going_out:
		# the old sheet slides off to the lower right first, then the blank ones in between
		for i in range(slide_n - 1, -1, -1):
			pen.group(_sl_out(slide_old, slide_t, 140.0 + i * 90.0, 340.0), 1.0)
			_draw_paper(slide_old, 1.0)
		pen.group(_sl_out(slide_old, slide_t, 0.0, 380.0), 1.0)
		_old_sheet()
	# the left column: files in from the side (fm_in), leaves left on close
	var lc := Rect2(pane.position.x, pane.position.y, left_w, pane.size.y)
	var lu := UIA.p(tab_t, 0.0, 500.0, FMIN)
	var ldx := (-26.0 if (slide_dir > 0 or slide_t > 5000.0) else 26.0) * (1.0 - lu)
	var la := clampf(tab_t / 500.0 * 2.0, 0.0, 1.0)
	if cl >= 0.0:
		ldx = -40.0 * UIA.lin(cl, 0.0, 260.0)
		la = 1.0 - UIA.lin(cl, 0.0, 260.0)
	pen.group(Transform2D(0.0, Vector2(ldx, 0)), la)
	match tb:
		"quest", "fac":
			var y := _hero_l(lc)
			_info_menu(Rect2(lc.position.x, y + 8.0, lc.size.x, lc.end.y - y - 8.0), "rank", "등급 안내")
		"home", "lv":
			var y := _hero_l(lc)
			var n: int = fame.lv_can().size()
			if n and tb == "home":
				y = _goal(Rect2(lc.position.x, y + 6.0, lc.size.x - 8.0, 44.0), "받지 않은 레벨 보상 %d개" % n, "모험 레벨 탭에서 받기", Color("#7fd0ff"), func(): _go_tab("lv")) + 4.0
			_info_menu(Rect2(lc.position.x, y + 8.0, lc.size.x, lc.end.y - y - 8.0), "exp", "EXP 획득처")
		"day": _day_col(lc)
		"dun": _dun_list(lc)
		"ch": _ch_list(lc)
	pen.reset()
	if dock == "R": _hero_at(Rect2(vs.x - 196.0, vs.y - 92.0, 180.0, 80.0), true)
	# the header on the band (headerFx), hidden under the wiper
	if not hdr_hide:
		_draw_title(vs, b)
		_draw_tabs(vs, fa)
		_draw_purse(vs, fa)
		_draw_bookmark(vs)
		_draw_close(vs, fa)
	pen.reset()
	_draw_claims()
	_draw_wipe(vs)


## what is written on a sheet for tab tb
func _content(tb: String, pr: Rect2) -> void:
	var cr := Rect2(pr.position + Vector2(34, 12), pr.size - Vector2(48, 20))
	match tb:
		"quest": _p_quest(cr)
		"fac": _p_fac(cr)
		"people": _p_people(Rect2(pr.position + Vector2(18, 12), pr.size - Vector2(30, 20)))
		"dun": _p_dun(cr)
		"rune": _p_rune(cr)
		"home": _p_home(cr)
		"lv": _p_lv(cr)
		"ch": _p_ch(cr)
		"day": _p_day(cr)

## the old sheet with its rows still on it (pageSlide keeps the old page until it is covered or has slid away);
## nothing on it can be clicked
func _old_sheet() -> void:
	_draw_paper(slide_old, 1.0)
	if slide_tab == "" or slide_tab == cur_tab(): return
	var b := book()
	var keep_tab: String = tab[b]
	var keep_t := tab_t
	var keep_h := content_h
	var keep_s := slide_t
	var nh := hits.size()
	tab[b] = slide_tab
	tab_t = 1e6
	slide_t = 1e6
	_content(slide_tab, slide_old)
	tab[b] = keep_tab
	tab_t = keep_t
	slide_t = keep_s
	content_h = keep_h
	hits.resize(nh)

# ---------- claim choreography (stampFx · moveEl) ----------
## the stamp slams onto the row (the paper jolts at 160 ms), then the row's reward labels fly to the purse
func _claim_fx(r: Rect2, rw: Array, text: String, rx: float) -> int:
	stamps.append({"p": Vector2(r.position.x + r.size.x * (0.8 if r.size.x > 300.0 else 0.5), r.get_center().y), "text": text, "t": 0.0})
	jolt_t = -160.0
	var k := 0
	for lab in rw:
		var L := String(lab)
		if L == "": continue
		var ti := 0 if L.contains("실링") else (1 if L.contains("기억석") else (2 if L.contains("룬") else -1))
		var to: Vector2 = purse_at[ti] if ti >= 0 else hero_last.position + Vector2(60, 40)
		flies.append({"from": Vector2(rx - S.tw(S.anton(), L, 14) / 2.0, r.position.y + 50.0 + k * 15.0), "to": to, "text": L, "t": -160.0, "d": 120.0 + k * 80.0, "k": ti})
		k += 1
	return k

func _draw_claims() -> void:
	for st in stamps:
		var tt: float = st["t"]
		var sc: float = UIA.kf(tt, [[0.0, 3.0, [0.7, 0.0, 1.0, 0.6]], [0.62, 1.0, "ease-out"], [0.78, 1.06], [1.0, 1.0]], 260.0)
		var rot: float = UIA.kf(tt, [[0.0, -24.0, [0.7, 0.0, 1.0, 0.6]], [0.62, -12.0, "ease-out"], [0.78, -11.0], [1.0, -12.0]], 260.0)
		var a: float = UIA.kf(tt, [[0.0, 0.0, [0.7, 0.0, 1.0, 0.6]], [0.62, 1.0]], 260.0)
		var dy := 0.0
		if tt > 880.0:
			var u := UIA.p(tt, 880.0, 320.0, "ease-out")
			a = 1.0 - u
			sc *= 1.0 + 0.1 * u
			dy = -10.0 * u
		var s: String = st["text"]
		var w := S.tw(S.bhs(), s, 26) + 28.0
		pen.group(UIA.xf(st["p"], Vector2(0, dy), deg_to_rad(rot), Vector2(sc, sc)), a)
		var rr := Rect2(st["p"] - Vector2(w / 2.0, 19.0), Vector2(w, 38.0))
		var red := Color("#c8232c")
		_ci.draw_rect(rr, Color(red, 0.85), false, 4.0)
		_ci.draw_string(S.bhs(), rr.position + Vector2(14, 30), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(red, 0.9))
	for f in flies:
		var tt: float = f["t"] - f["d"]
		if tt < 0.0: continue
		var a0: Vector2 = f["from"]
		var b0: Vector2 = f["to"]
		var x1 := b0.x - a0.x
		var y1 := b0.y - a0.y
		var lift := -18.0 if y1 > 40.0 else -50.0 - absf(x1) * 0.06
		var k: Array = UIA.kf(tt, [[0.0, [0.0, 0.0, 1.0]], [0.2, [x1 * 0.1, -10.0 if y1 > 40.0 else -22.0, 1.35]], [0.55, [x1 * 0.55, y1 * 0.35 if y1 > 40.0 else minf(0.0, y1) + lift, 1.2]], [1.0, [x1, y1, 0.45]]], 520.0, 0.0, [0.4, 0.0, 0.2, 1.0])
		pen.group(UIA.xf(a0, Vector2(k[0], k[1]), 0.0, Vector2(k[2], k[2])), 1.0 if tt < 500.0 else 0.9)
		var s2: String = f["text"]
		var w2 := S.tw(S.anton(), s2, 14) + 20.0
		var r2 := Rect2(a0 - Vector2(w2 / 2.0, 12.0), Vector2(w2, 24.0))
		_ci.draw_colored_polygon(S.clip(Rect2(r2.position + Vector2(3, 3), r2.size), [[6, 0], [100, 0], [94, 100], [0, 100]]), col())
		_ci.draw_colored_polygon(S.clip(r2, [[6, 0], [100, 0], [94, 100], [0, 100]]), Color.BLACK)
		_ci.draw_rect(Rect2(r2.position, Vector2(4, r2.size.y)), col())
		_ci.draw_string(S.anton(), r2.position + Vector2(12, 18), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	pen.reset()


# ---------- motion helpers ----------
## header element k's entrance: [progress 0..1 with the overshoot, opacity]; on close, [1, fading]
func _hdr(delay: float, dur: float, ez = BK) -> Array:
	if closing >= 0.0: return [1.0, 1.0]
	return [UIA.p(hdr_t, hdr_d + delay, dur, ez), clampf((hdr_t - hdr_d - delay) / (dur * 0.5), 0.0, 1.0)]

## fmClose for header items i (tabs, tokens, bookmark, ✕): up 30 px and out, 20 ms apart
func _hdr_out(i: int) -> Array:
	if closing < 0.0: return [0.0, 1.0]
	var u := UIA.lin(closing, i * 20.0, 240.0)
	return [-30.0 * u, 1.0 - u]

## the sheet's group transform: openFx rise, pageSlide slide-in (new sheet over the old), fmClose drop
func _paper_xf(r: Rect2) -> Array:
	var c := r.get_center()
	if closing >= 0.0:
		var u := UIA.p(closing, 0.0, 360.0, SLOUT)
		return [UIA.xf(c, Vector2(0, r.size.y * 0.8 * u), deg_to_rad(4.0 * u)), 1.0 - u]
	if t < 640.0 and tab_t < 0.0 and slide_t > 5000.0:
		var y: float = UIA.kf(t, [[0.0, 0.78], [0.72, -0.014], [1.0, 0.0]], 640.0, 0.0, EZ)
		var rr: float = UIA.kf(t, [[0.0, 3.0], [0.72, -0.5], [1.0, 0.0]], 640.0, 0.0, EZ)
		return [UIA.xf(c, Vector2(0, r.size.y * y), deg_to_rad(rr)), clampf(t / (640.0 * 0.08), 0.0, 1.0)]
	if slide_dir > 0 and slide_t < 520.0 + slide_n * 90.0:
		return [_sl_in(r, slide_t, slide_n * 90.0, 520.0), clampf((slide_t - slide_n * 90.0) / 42.0, 0.0, 1.0)]
	return [Transform2D.IDENTITY, 1.0]

## SL_IN: from translate(72%,14%) rotate(9deg) to a little past home and back
func _sl_in(r: Rect2, tt: float, delay: float, dur: float) -> Transform2D:
	var k: Array = UIA.kf(tt, [[0.0, [0.72, 0.14, 9.0]], [0.72, [-0.014, -0.006, -0.9]], [1.0, [0.0, 0.0, 0.0]]], dur, delay, EZ)
	return UIA.xf(r.get_center(), Vector2(r.size.x * k[0], r.size.y * k[1]), deg_to_rad(k[2]))

## SL_OUT: to translate(78%,16%) rotate(10deg)
func _sl_out(r: Rect2, tt: float, delay: float, dur: float) -> Transform2D:
	var u := UIA.p(tt, delay, dur, SLOUT)
	return UIA.xf(r.get_center(), Vector2(r.size.x * 0.78, r.size.y * 0.16) * u, deg_to_rad(10.0 * u))

## the title on the band (headerFx .ttl: in from the left)
func _draw_title(vs: Vector2, b: String) -> void:
	var h := _hdr(0.0, 420.0, EZ)
	var x: float = -70.0 * (1.0 - h[0])
	var a: float = h[1]
	if closing >= 0.0:
		var u := UIA.lin(closing, 0.0, 260.0)
		x = -60.0 * u
		a = 1.0 - u
	var en := "GUILD BOOK" if b == "gbk" else "ADVENTURE BOOK"
	var kr := "길드 수첩" if b == "gbk" else "모험 수첩"
	pen.group(Transform2D(0.0, Vector2(x, 0).rotated(deg_to_rad(-4.0))), a)
	_ci.draw_set_transform(Vector2(18, 10), deg_to_rad(-4.0))
	_ci.draw_string(S.anton(false, 3), Vector2(0, 11), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	var tw := S.tw(S.bhs(), kr, 30)
	S.para(_ci, Rect2(-2, 15, tw + 26.0, 36), 7.0, Color.BLACK)
	_ci.draw_string(S.bhs(), Vector2(10, 44), kr, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	pen.reset()

## .bgl: the slow burst, the dark shard with its colour edge, the white slash and the hollow GUILD / ADVENTURE,
## each moving to its place for the tab (.75s --mv), sliding in on open and leading a tab change (fm_lead)
const BGL := {
	"": {"bx": 0.22, "by": 0.70, "sh": [-0.10, 0.46, -9.0], "ed": [0.30, -9.0], "sl": [0.01, 0.34, 0.30, -7.0, 16.0], "bg": [-0.04, 0.64, -8.0]},
	"fac": {"by": 0.40, "sh": [-0.10, 0.46, -4.0], "ed": [0.30, -4.0], "sl": [0.01, 0.58, 0.30, -4.0, 16.0]},
	"home": {"sl": [0.01, 0.40, 0.28, -7.0, 16.0]},
	"lv": {"bx": 0.60, "by": 0.60, "sl": [0.01, 0.70, 0.30, -2.0, 16.0], "bg": [0.36, 0.14, -4.0]},
	"day": {"sl": [0.01, 0.52, 0.30, -5.0, 16.0], "bg": [-0.04, 0.74, -8.0]},
	"ch": {"sh": [-0.10, 0.40, -5.0], "ed": [0.27, -5.0], "sl": [0.01, 0.72, 0.26, -5.0, 16.0], "bg": [-0.06, 0.82, -8.0]},
	"dun": {"sh": [-0.10, 0.40, -5.0], "ed": [0.27, -5.0], "sl": [0.01, 0.72, 0.26, -5.0, 16.0], "bg": [-0.06, 0.82, -8.0]},
	"rune": {"sh": [-0.10, 0.62, -3.0], "ed": [0.50, -3.0], "sl": [0.01, 0.84, 0.48, -3.0, 16.0], "bg": [0.20, 0.70, -8.0]},
	"people": {"bx": 0.80, "by": 0.30, "sh": [0.52, 0.60, 8.0], "ed": [0.50, 8.0], "sl": [0.34, 0.125, 0.44, -3.0, 6.0], "bg": [0.40, 0.70, -8.0]},
}
func _bgl(tb: String, k: String):
	var d: Dictionary = BGL.get(tb, {})
	return d.get(k, BGL[""][k])

func _draw_bgl(vs: Vector2, fa: Color, tb: String) -> void:
	var MV := "mv"
	var bx: float = trn.get_v("bx", _bgl(tb, "bx"), 800.0, MV)
	var by: float = trn.get_v("by", _bgl(tb, "by"), 800.0, MV)
	var sh: Array = trn.get_v("sh", _bgl(tb, "sh"), 750.0, MV)
	var ed: Array = trn.get_v("ed", _bgl(tb, "ed"), 750.0, MV)
	var sl: Array = trn.get_v("sl", _bgl(tb, "sl"), 750.0, MV)
	var bg: Array = trn.get_v("bg", _bgl(tb, "bg"), 750.0, MV)
	var cl := closing
	# burst: white rays 5° of every 13°, 80 s a turn
	var bc := Vector2(vs.x * bx, vs.y * by)
	var rr := maxf(vs.x, vs.y) * 2.6
	var step := deg_to_rad(13.0)
	var spin := t / 80000.0 * TAU
	for i in int(TAU / step) + 1:
		var a0 := spin + i * step
		_ci.draw_colored_polygon(PackedVector2Array([bc, bc + Vector2(cos(a0), sin(a0)) * rr, bc + Vector2(cos(a0 + deg_to_rad(5.0)), sin(a0 + deg_to_rad(5.0))) * rr]), Color(1, 1, 1, 0.035))
	# shard
	var shr := Rect2(vs.x * sh[0], -0.04 * vs.y, vs.x * sh[1], vs.y * 1.3)
	var su := UIA.p(t, 60.0, 620.0, EZ)
	pen.group(UIA.xf(shr.get_center(), Vector2(-0.45 * shr.size.x * (1.0 - su), 0).rotated(deg_to_rad(sh[2])), deg_to_rad(sh[2])))
	_ci.draw_colored_polygon(S.clip(shr, [[0, 0], [86, 0], [100, 30], [82, 48], [94, 100], [0, 100]]), Color("#17131d"))
	# edge
	var lt := lead_t
	var e2: float = UIA.kf(lt, [[0.0, 0.0], [0.4, 36.0], [1.0, 0.0]], 950.0, 0.0, "mv")
	var er := Rect2(vs.x * ed[0], -0.12 * vs.y, vs.x * 0.022, vs.y * 1.34)
	var eu := UIA.p(t, 120.0, 560.0, EZ)
	pen.group(UIA.xf(er.get_center(), Vector2(e2, 0) + Vector2(0, -1.1 * er.size.y * (1.0 - eu)).rotated(deg_to_rad(ed[1])), deg_to_rad(ed[1])))
	_ci.draw_rect(er, Color(fa, 0.9))
	# slash
	var slr := Rect2(vs.x * sl[0], vs.y * sl[1], vs.x * sl[2], sl[4])
	var slu := UIA.p(t, 160.0, 640.0, EZ)
	var sla := clampf((t - 160.0) / (640.0 * 0.3), 0.0, 1.0)
	var lead: Array = UIA.kf(lt, [[0.0, [0.0, 0.0, 1.0]], [0.38, [220.0, -16.0, 1.25]], [1.0, [0.0, 0.0, 1.0]]], 950.0, 0.0, "mv")
	var sx := -1.2 * slr.size.x * (1.0 - slu)
	if cl >= 0.0:
		var cu := UIA.lin(cl, 0.0, 320.0)
		sx = 1.2 * slr.size.x * cu
		sla = 1.0 - cu
	pen.group(Transform2D(0.0, Vector2(lead[0], lead[1])) * UIA.xf(slr.get_center(), Vector2(sx, 0).rotated(deg_to_rad(sl[3])), deg_to_rad(sl[3]), Vector2(lead[2], 1.0)), sla)
	_ci.draw_colored_polygon(S.clip(slr, [[0, 40], [100, 0], [100, 30], [3, 100]]), Color.WHITE)
	# the hollow word
	var word := "ADVENTURE" if book() == "abk" else "GUILD"
	var fs := int(vs.y * 0.34)
	var bu := UIA.p(t, 300.0, 700.0, EZ)
	var ba := clampf((t - 300.0) / 700.0, 0.0, 1.0)
	if cl >= 0.0: ba = 1.0 - UIA.lin(cl, 0.0, 300.0)
	var ww := S.tw(S.anton(), word, fs)
	var l3: float = UIA.kf(lt, [[0.0, 0.0], [0.45, -60.0], [1.0, 0.0]], 950.0, 0.0, "mv")
	var bp := Vector2(vs.x * bg[0], vs.y * bg[1])
	pen.group(UIA.xf(bp + Vector2(ww / 2.0, fs * 0.4), Vector2(l3 - 0.12 * ww * (1.0 - bu), 0), deg_to_rad(bg[2])), ba)
	_ci.draw_string_outline(S.anton(), bp + Vector2(0, fs * 0.8), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(1, 1, 1, 0.09))
	pen.reset()

## speedFx: streaks sweep across as a tab turns
func _draw_speed(vs: Vector2) -> void:
	if slide_t > 560.0: return
	var u := UIA.p(slide_t, 0.0, 560.0, "ease-out")
	var a := 0.9 * (1.0 - u)
	var off := vs.x * 1.8 * 0.3 * (1.0 - 2.0 * u) * (1.0 if slide_dir > 0 else -1.0)
	var tk := tan(deg_to_rad(14.0))
	var x := -0.4 * vs.x
	while x < vs.x * 1.4:
		var xx := x + off
		var m := clampf(xx / vs.x, 0.0, 1.0)
		var mk := clampf(m / 0.3, 0.0, 1.0) * clampf((1.0 - m) / 0.4, 0.0, 1.0)
		if mk > 0.0:
			_ci.draw_colored_polygon(PackedVector2Array([Vector2(xx, -10), Vector2(xx + 2.0, -10), Vector2(xx + 2.0 + vs.y * tk, vs.y + 10), Vector2(xx + vs.y * tk, vs.y + 10)]), Color(1, 1, 1, 0.7 * a * mk))
		x += 60.0

## the book switch wiper: one fan of the new colour around the band's left end, rising from under the page
func _draw_wipe(vs: Vector2) -> void:
	if wipe_t < 0.0: return
	var deg := -4.0
	var th := deg_to_rad(deg)
	var W := vs.x
	var mx := W / 2.0 - 60.0 * sin(th)
	var my := 30.0 + 60.0 * cos(th)
	var py := my + (0.0 - mx) * tan(th)
	var D := 1140.0
	var rot: float = UIA.kf(wipe_t, [[0.0, 270.0, [0.55, 0.0, 0.8, 0.4]], [0.36, 176.0, [0.35, 0.0, 0.65, 1.0]], [0.64, 86.0, [0.2, 0.7, 0.25, 1.0]], [0.9, deg - 4.5, "ease-out"], [1.0, deg]], D)
	var H := 3200.0
	var r := Rect2(-3.2 * W, py - H, 6.4 * W, H)
	var piv := Vector2(0.0, py)
	var to: Color = BOOKCOL.get(wipe_to, Color.WHITE)
	_ci.draw_colored_polygon(UIA.xf(piv, Vector2.ZERO, deg_to_rad(rot)) * PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), to)


# ---------- chrome ----------
func _draw_tabs(vs: Vector2, fa: Color) -> void:
	var L: Array = TABS[book()]
	var x := maxf(190.0, vs.x * 0.22)
	var bf := S.bhs()
	var fs := 18 if vs.x > 1000.0 else 16
	# layout first (the cursor plates need the chosen tab's place)
	var R: Array = []
	var on_i := 0
	for i in L.size():
		var on: bool = L[i][0] == cur_tab()
		if on: on_i = i
		var w := S.tw(bf, L[i][1], fs) + 22.0
		R.append(Rect2(x, 16.0, w, 30.0))
		x += w * (1.16 if on else 1.0) + 4.0
	var tr: Rect2 = R[on_i]
	var tw2 := tr.size.x * 1.16
	var tl := tr.position.x - (tw2 - tr.size.x) / 2.0
	if not ind_init:
		ind_init = true
		for sp in [ind_l, ind2_l]: sp.snap(tl)
		for sp in [ind_w, ind2_w]: sp.snap(tw2)
	ind_l.to(tl)
	ind2_l.to(tl)
	ind_w.to(tw2)
	ind2_w.to(tw2)
	# the cursor: a black plate lagging behind a white one (tabInd springs)
	var hi := _hdr(40.0 + on_i * 45.0, 420.0)
	var ho := _hdr_out(on_i)
	var iy: float = -40.0 * (1.0 - hi[0]) + ho[0]
	pen.group(Transform2D(0.0, Vector2(0, iy)), hi[1] * ho[1] * 0.9)
	_ci.draw_colored_polygon(S.clip(Rect2(ind2_l.x, 14.0 + 2.0, ind2_w.x, 32.0), [[0, 34], [100, 8], [94, 100], [5, 84]]), Color.BLACK)
	pen.group(Transform2D(0.0, Vector2(0, iy)), hi[1] * ho[1])
	_ci.draw_colored_polygon(S.clip(Rect2(ind_l.x, 14.0, ind_w.x, 32.0), [[3, 20], [97, 0], [100, 74], [7, 100]]), Color.WHITE)
	for i in L.size():
		var on: bool = L[i][0] == cur_tab()
		var s: String = L[i][1]
		var r: Rect2 = R[i]
		var w := r.size.x
		var hv := r.has_point(hover) and not on
		var sc: float = trn.get_v("tab%d" % i, 1.16 if on else 1.0, 350.0, BK)
		var lift: float = trn.get_v("tabl%d" % i, -2.0 if (on or hv) else 0.0, 350.0, BK)
		var ink: float = trn.get_v("tabc%d" % i, 1.0 if on else 0.0, 250.0, "ease")
		var h := _hdr(40.0 + i * 45.0, 420.0)
		var o := _hdr_out(i)
		pen.group(Transform2D(0.0, Vector2(0, -34.0 * (1.0 - h[0]) + o[0])), h[1] * o[1] * (1.0 if on or hv else 0.85))
		_ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(sc, sc), deg_to_rad(-8.0), r.get_center() + Vector2(0, lift)))
		var lr := Rect2(-w / 2.0, -15.0, w, 30.0)
		_ci.draw_string(S.anton(false, 2), Vector2(lr.position.x + 10.0, lr.position.y - 2.0 + 4.0 * (1.0 - ink)), L[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, ink))
		if ink < 1.0:
			_ci.draw_string_outline(bf, Vector2(lr.position.x + 11.0, 7.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 1.0 - ink))
		_ci.draw_string(bf, Vector2(lr.position.x + 11.0, 7.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0 - ink, 1.0 - ink, 1.0 - ink, 1.0))
		var badge := _badge(L[i][0])
		if badge > 0:
			_ci.draw_circle(Vector2(lr.end.x - 2.0, lr.position.y + 2.0), 8.0, Color("#ff3d5a"))
			var bs := str(badge)
			_ci.draw_string(S.noto(), Vector2(lr.end.x - 2.0 - S.tw(S.noto(), bs, 10) / 2.0, lr.position.y + 6.0), bs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		_ci.draw_set_transform(Vector2.ZERO)
		var tb: String = L[i][0]
		_hit(r, func(): _go_tab(tb))
	pen.reset()

## tabBadges
func _badge(tb: String) -> int:
	match tb:
		"quest": return fame.ready_n() + (1 if fame.f_letter() else 0)
		"lv": return fame.lv_can().size()
		"ch": return fame.ch_badges()
		"day": return fame.d_ready()
	return 0

func _draw_purse(vs: Vector2, fa: Color) -> void:
	var items := [["실링", str(arena.shilling), "●"], ["기억석", str(fame.mem_now()), "◆"], ["룬", str(fame.runes_now()), "★"]]
	var x := vs.x - 122.0
	var rots := [-5.0, 2.0, -2.0]
	for j in range(items.size() - 1, -1, -1):
		var it: Array = items[j]
		var w := 30.0 + S.tw(S.noto(), it[0], 9) + 6.0 + maxf(24.0, S.tw(S.anton(), it[1], 15)) + 10.0
		x -= w - 7.0
		var h := _hdr(160.0 + j * 60.0, 460.0)
		var o := _hdr_out(5 + j)
		var bump: float = UIA.kf(bump_t, [[0.0, 0.0], [0.3, -8.0], [1.0, 0.0]], 550.0, 0.0, BK)
		purse_at[j] = Vector2(x + w / 2.0, 70.0)
		var hs: float = UIA.kf(hot_t[j], [[0.0, 1.35], [1.0, 1.0]], 500.0, 0.0, [0.2, 1.6, 0.4, 1.0])
		pen.group(Transform2D(0.0, Vector2(0, -46.0 * (1.0 - h[0]) + o[0] + bump)), h[1] * o[1])
		_ci.draw_set_transform(Vector2(x + w / 2.0, 70.0 + (6.0 if j == 1 else (2.0 if j == 2 else 0.0))), deg_to_rad(rots[j]), Vector2(hs, hs))
		var r := Rect2(-w / 2.0, -12.0, w, 24.0)
		_ci.draw_colored_polygon(S.clip(Rect2(r.position + Vector2(3, 3), r.size), [[9, 0], [100, 0], [91, 100], [0, 100]]), Color.BLACK)
		_ci.draw_colored_polygon(S.clip(r, [[9, 0], [100, 0], [91, 100], [0, 100]]), Color.WHITE)
		_ci.draw_circle(r.position + Vector2(16, 12), 9.0, Color.BLACK)
		_ci.draw_string(S.noto(), r.position + Vector2(16 - S.tw(S.noto(), it[2], 10) / 2.0, 16), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fa)
		_ci.draw_string(S.noto(), r.position + Vector2(30, 15), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.75))
		_ci.draw_string(S.anton(), Vector2(r.end.x - 12.0 - S.tw(S.anton(), it[1], 15), r.position.y + 18.0), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)
		_ci.draw_set_transform(Vector2.ZERO)
	pen.reset()

## the other book's bookmark, hanging under the band on the right
func _draw_bookmark(vs: Vector2) -> void:
	var other := "abk" if book() == "gbk" else "gbk"
	var oc: Color = BOOKCOL[other]
	var en := "ADVENTURE" if other == "abk" else "GUILD"
	var kr := "모험 수첩" if other == "abk" else "길드 수첩"
	var w := S.tw(S.bhs(), kr, 14) + 24.0
	var r := Rect2(vs.x - 16.0 - w, 58.0, w, 52.0)
	var hv := r.has_point(hover)
	var h := _hdr(220.0, 560.0)
	var o := _hdr_out(8)
	var rot: float = trn.get_v("bmr", -2.0 if hv else -5.0, 300.0, BK)
	var dy: float = trn.get_v("bmy", 4.0 if hv else 0.0, 300.0, BK)
	if closing < 0.0 and h[0] < 1.0: rot = lerpf(-60.0, -5.0, h[0])
	var sw: Array = UIA.kf(bump_t, [[0.0, [0.0, 0.0]], [0.3, [-9.0, 4.0]], [1.0, [0.0, 0.0]]], 700.0, 0.0, BK)
	pen.group(Transform2D(0.0, Vector2(0, o[0])), h[1] * o[1])
	_ci.draw_set_transform(Vector2(r.get_center().x, r.position.y), deg_to_rad(rot + sw[0]))
	var lr := Rect2(-w / 2.0, dy + sw[1], w, 52.0)
	_ci.draw_colored_polygon(S.clip(lr, [[0, 0], [100, 0], [100, 82], [50, 100], [0, 82]]), Color.BLACK)
	_ci.draw_rect(Rect2(lr.position, Vector2(w, 5)), oc)
	_ci.draw_string(S.anton(false, 2), Vector2(-S.tw(S.anton(false, 2), en, 9) / 2.0, lr.position.y + 19.0), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, oc)
	_ci.draw_string(S.bhs(), Vector2(-S.tw(S.bhs(), kr, 14) / 2.0, lr.position.y + 36.0), kr, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	pen.reset()
	_hit(r, func(): _switch_book())

func _draw_close(vs: Vector2, fa: Color) -> void:
	var c := Vector2(vs.x - 14.0 - 18.0, 10.0 + 18.0)
	var h := _hdr(260.0, 380.0)
	var o := _hdr_out(9)
	pen.group(UIA.xf(c, Vector2(0, o[0]), deg_to_rad(-90.0) * (1.0 - h[0]), Vector2.ONE * maxf(0.001, h[0])), o[1])
	_ci.draw_circle(c, 18.0, Color.BLACK)
	_ci.draw_arc(c, 17.0, 0, TAU, 32, Color.WHITE, 2.0, true)
	_ci.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), Color.WHITE, 2.0, true)
	_ci.draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), Color.WHITE, 2.0, true)
	pen.reset()
	_hit(Rect2(c - Vector2(20, 20), Vector2(40, 40)), func(): close_fx())

## the paper sheet: cream, a red margin line, faint rules, a hard black drop
func _draw_paper(r: Rect2, e: float) -> void:
	var rot := deg_to_rad(-0.6)
	_ci.draw_set_transform(r.get_center(), rot)
	var lr := Rect2(-r.size / 2.0, r.size)
	_ci.draw_rect(Rect2(lr.position + Vector2(7, 9), lr.size), Color(0, 0, 0, e))
	_ci.draw_rect(lr, Color(PAPER, 1.0))
	var y := lr.position.y + 27.0
	while y < lr.end.y:
		_ci.draw_rect(Rect2(lr.position.x, y, lr.size.x, 1.0), Color(0.24, 0.16, 0.08, 0.075))
		y += 28.0
	_ci.draw_rect(Rect2(lr.position.x + 30.0, lr.position.y, 1.0, lr.size.y), Color(0.78, 0.27, 0.27, 0.22))
	_ci.draw_rect(Rect2(lr.position, Vector2(10, lr.size.y)), Color(0, 0, 0, 0.08))
	_ci.draw_set_transform(Vector2.ZERO)


# ---------- the big number (hero) ----------
func _hero_l(lc: Rect2) -> float:
	return _hero_at(lc, false)

## the hero floats over the pages: it glides between its docks on springs (heroSync), slides in late on open,
## and drifts off left on close
func _hero_at(r: Rect2, small: bool) -> float:
	var dk := "R" if small else "L"
	var keep_xf: Transform2D = pen.xf
	var keep_a: float = pen.a
	if hero_dock == "":
		hero_dock = dk
		hero_last = r
		hero_sp[0].snap(-120.0)
		hero_sp[1].snap(0.0)
		hero_sp[2].snap(-8.0)
		hero_sp[3].snap(1.0)
	elif dk != hero_dock and closing < 0.0:
		var far := (r.position - hero_last.position).length() > 120.0
		hero_sp[0].snap(hero_sp[0].x + hero_last.position.x - r.position.x)
		hero_sp[1].snap(hero_sp[1].x + hero_last.position.y - r.position.y)
		hero_sp[3].snap(hero_last.size.x / maxf(1.0, r.size.x) * hero_sp[3].x)
		hero_sp[2].v += (-60.0 if r.position.x > hero_last.position.x else 60.0) if far else 0.0
		hero_dock = dk
	hero_last = r
	var a := 1.0
	if t < 260.0:
		hero_sp[0].snap(-120.0)
		hero_sp[2].snap(-8.0)
		a = 0.0
	else:
		a = clampf((t - 260.0) / 400.0, 0.0, 1.0)
	for i in 4: hero_sp[i].to(1.0 if i == 3 else 0.0)
	var off := Vector2(hero_sp[0].x, hero_sp[1].x)
	if closing >= 0.0:
		var u := UIA.lin(closing, 0.0, 300.0)
		off.x -= 80.0 * u
		a *= 1.0 - u
	pen.group(UIA.xf(r.position, off, deg_to_rad(hero_sp[2].x), Vector2.ONE * hero_sp[3].x), a * (keep_a if not small else 1.0))
	var y := _hero(r, small)
	pen.group(keep_xf, keep_a)
	return y

## returns the bottom y
func _hero(r: Rect2, small: bool) -> float:
	var adv := book() == "abk"
	var fa := col()
	var num := str(fame.alv) if adv else str(fame.r)
	var en := "ADVENTURER LV" if adv else "GUILD RANK"
	var nm := "모험가 레벨" if adv else String(FD.FRANK[fame.r - 1]["n"])
	var cur := 0.0
	var need := 1.0
	var l1 := ""
	var l2 := ""
	if adv:
		cur = fame.aexp
		need = FD.a_need(fame.alv)
		l1 = "EXP %d" % fame.aexp
		l2 = "다음 %d" % FD.a_need(fame.alv) if fame.alv < FD.AMAX else "MAX"
	else:
		var nx: Variant = fame.fame_next()
		var lo: int = FD.FRANK[fame.r - 1]["need"]
		cur = fame.pts - lo
		need = (nx["need"] - lo) if nx != null else 1.0
		l1 = "명성 %d" % fame.pts
		l2 = "다음 %d" % nx["need"] if nx != null else "MAX"
	var h := 80.0 if small else 128.0
	var w := r.size.x if not small else r.size.x
	var p := r.position
	var nfs := 54 if small else 76
	_ci.draw_set_transform(p + Vector2(0, 4), deg_to_rad(-1.5 if not small else 7.0 * 0.0 - 3.0))
	var lr := Rect2(0, 0, w, h)
	_ci.draw_colored_polygon(S.clip(Rect2(lr.position + Vector2(5, 5), lr.size), [[0, 0], [100, 3], [97, 100], [2, 95]]), fa)
	_ci.draw_colored_polygon(S.clip(lr, [[0, 0], [100, 3], [97, 100], [2, 95]]), Color("#0d0b10"))
	var fi := S.anton(true)
	var nw := S.tw(fi, num, nfs)
	_ci.draw_string(fi, Vector2(16 + 4, nfs * 0.86 + 4), num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color.BLACK)
	_ci.draw_string(fi, Vector2(16, nfs * 0.86), num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, fa)
	var tx := 16.0 + nw + 10.0
	_ci.draw_string(S.anton(false, 1), Vector2(tx, nfs * 0.5), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.73, 0.73, 0.73))
	var nmfs := S.fit_size(S.bhs(), nm, 18 if small else 22, w - tx - 10.0)
	_ci.draw_string(S.bhs(), Vector2(tx, nfs * 0.5 + nmfs + 2.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nmfs, Color.WHITE)
	if not small:
		var gy := nfs * 0.98 + 6.0
		var gr := Rect2(16, gy, w - 36.0, 12.0)
		S.para(_ci, gr, -3.0, Color("#2a2630"))
		var f := clampf(cur / maxf(1.0, need), 0.0, 1.0)
		if f > 0.0: S.para(_ci, Rect2(gr.position, Vector2(gr.size.x * f, gr.size.y)), -3.0, fa)
		_ci.draw_string(S.noto(), Vector2(16, gy + 30.0), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.87, 0.87, 0.87))
		_ci.draw_string(S.noto(), Vector2(w - 20.0 - S.tw(S.noto(), l2, 12), gy + 30.0), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.87, 0.87, 0.87))
	_ci.draw_set_transform(Vector2.ZERO)
	return p.y + h + 8.0

## a goal button (abHome .goal)
func _goal(r: Rect2, title: String, sub: String, gc: Color, cb: Callable, tag := "", on_paper := false) -> float:
	var hv := r.has_point(hover)
	var bg := Color(1, 1, 1, 0.6) if on_paper else Color("#16131b")
	_ci.draw_rect(r, bg if not hv else (Color(1, 1, 1, 0.85) if on_paper else Color("#221d29")))
	_ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), gc)
	var x := r.position.x + 12.0
	var ink := INK if on_paper else Color.WHITE
	if tag != "":
		var tw := S.tw(S.noto(), tag, 10) + 12.0
		S.para(_ci, Rect2(x, r.position.y + 8.0, tw, 16.0), 3.0, gc)
		_ci.draw_string(S.noto(), Vector2(x + 6.0, r.position.y + 20.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
		x += tw + 6.0
	_ci.draw_string(S.bhs(), Vector2(x, r.position.y + 21.0), title, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x - 24.0, 15, ink)
	_ci.draw_string(S.noto(), Vector2(r.position.x + 12.0, r.position.y + 38.0), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0, 11, INK2 if on_paper else Color(0.79, 0.76, 0.82))
	_ci.draw_string(S.anton(), Vector2(r.end.x - 16.0, r.position.y + r.size.y / 2.0 + 6.0), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gc)
	_hit(r, cb)
	return r.end.y

## IMD: stacked hub-style labels; the chosen one swells onto a white cursor and a black tip panel opens under it
func _imd(key: String) -> Array:
	if key == "exp":
		var D: Dictionary = fame.d_day()
		return [["obs", "몬스터 관찰", "OBSERVE", "적을 알아갈수록 EXP가 들어온다.\n만남 · 첫 처치 · 숙련 · 완료, 네 단계.", null],
			["dun", "던전 클리어", "DUNGEON", "던전을 처음 깨면 150.\n그 뒤로는 피로도 40을 써서 보스 보물상자를 열면 60.", ["던전 보기 ›", func(): _goto("gbk", "dun")]],
			["log", "모험 일지", "LOG", "장마다 적힌 과제를 끝내면 EXP, 장을 덮으면 장 보상.", ["일지 펼치기 ›", func(): _goto("abk", "ch")]],
			["day", "일일 훈련", "DAILY", "활동도가 쌓일 때마다 단계 보상으로 EXP.\n오늘 활동도 %d / 500" % int(D["pt"]), ["훈련 보기 ›", func(): _goto("abk", "day")]]]
	var r: int = fame.r
	var nx: Variant = fame.fame_next()
	var L := [["now", "열린 것", "UNLOCKED", "지금 %d등급에서 할 수 있는 일.\n" % r + " · ".join(FD.FUNLOCK[r - 1]), null]]
	if nx != null:
		L.append(["next", "%d등급에서" % (r + 1), "NEXT RANK", "「%s」에 오르면.\n" % nx["n"] + " · ".join(FD.FUNLOCK[r]), null, true])
	L.append(["how", "오르는 법", "PROMOTION", "의뢰 보고 · 시설 복구 · 동료 합류 · 몬스터 관찰 완료로 명성이 쌓인다. 전부 할 필요는 없다.\n명성이 다 차면 길드 관리국에서 심사 서신이 온다. 에일린에게 받아 길드원 모두가 심사 과제를 해내면 승급.", null])
	return L

func _info_menu(r: Rect2, key: String, title: String) -> void:
	var items := _imd(key)
	var sel := mini(int(im.get(key, 0)), items.size() - 1)
	var fa := col()
	_ci.draw_string(S.bhs(), r.position + Vector2(4, 14), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, fa)
	var xf := Transform2D(deg_to_rad(-4.0), r.position + Vector2(8, 26))
	var y := 0.0
	var bf := S.bhs()
	for i in items.size():
		var it: Array = items[i]
		var on := i == sel
		var x := i * 7.0 + (10.0 if on else 0.0)
		var sc := 1.28 if on else 1.0
		var fs := 19
		var lw := S.tw(bf, it[1], fs)
		var rot := deg_to_rad(1.2 if i % 2 else -1.2)
		var base := xf * Transform2D(rot, Vector2(sc, sc), 0.0, Vector2(x, y + (8.0 if on else 0.0)))
		if on:
			var cw := lw * 1.0 + 26.0
			_ci.draw_set_transform_matrix(xf * Transform2D(deg_to_rad(2.0), Vector2(x - 6.0, y + 14.0)))
			_ci.draw_colored_polygon(S.clip(Rect2(0, 0, cw * 1.28 + 10.0, 30), [[0, 34], [100, 8], [94, 100], [5, 84]]), fa)
			_ci.draw_set_transform_matrix(xf * Transform2D(deg_to_rad(-3.0), Vector2(x - 2.0, y + 10.0)))
			_ci.draw_colored_polygon(S.clip(Rect2(0, 0, cw * 1.28, 30), [[3, 20], [97, 0], [100, 74], [7, 100]]), Color.WHITE)
		_ci.draw_set_transform_matrix(base)
		if on:
			_ci.draw_string(S.anton(false, 2), Vector2(2, 4), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, fa.darkened(0.2))
			_ci.draw_string(bf, Vector2(4, 22), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
		else:
			_ci.draw_string_outline(bf, Vector2(4, 22), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
			_ci.draw_string(bf, Vector2(4, 22), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.82))
		_ci.draw_set_transform(Vector2.ZERO)
		var hr := Rect2(xf * Vector2(x, y + 2.0), Vector2(lw * sc + 12.0, 26.0 * sc))
		var kk: String = key
		var ii := i
		_hit(hr, func():
			im[kk] = ii
			arena.sfx("step", 0.2))
		y += 26.0 * sc + (10.0 if on else 0.0)
		if on:
			# the tip panel
			var pw := r.size.x - 22.0
			var lines: Array = []
			for part in String(it[3]).split("\n"):
				lines.append(part)
			var text := "\n".join(lines)
			var th := S.noto().get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, pw - 26.0, 12).y
			var ph := 50.0 + th + (30.0 if it[4] != null else 0.0)
			var pp := xf * Vector2(0, y)
			_ci.draw_set_transform(pp, deg_to_rad(2.5))
			var pr := Rect2(0, 0, pw, ph)
			_ci.draw_colored_polygon(S.clip(pr, [[0, 6], [5, 6], [8, 0], [11, 6], [100, 8], [98.5, 100], [1, 96]]), Color.BLACK)
			_ci.draw_rect(Rect2(0, 6, 5, ph - 10.0), fa)
			_ci.draw_string(S.anton(false, 2), Vector2(14, 24), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fa)
			_ci.draw_string(bf, Vector2(14, 42), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			var lk: bool = it.size() > 5 and it[5]
			_ci.draw_multiline_string(S.noto(), Vector2(14, 60), text, HORIZONTAL_ALIGNMENT_LEFT, pw - 26.0, 12, -1, Color(0.54, 0.52, 0.57) if lk else Color(0.87, 0.87, 0.87))
			if it[4] != null:
				var bl: String = it[4][0]
				var bw := S.tw(S.bhs(), bl, 12) + 26.0
				var brr := Rect2(14, ph - 30.0, bw, 22.0)
				_ci.draw_colored_polygon(S.clip(brr, [[7, 0], [100, 0], [93, 100], [0, 100]]), fa)
				_ci.draw_string(S.bhs(), brr.position + Vector2(13, 16), bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
				var sr := Rect2(pp + Vector2(14, ph - 30.0).rotated(deg_to_rad(2.5)), Vector2(bw, 22))
				_hit(sr.grow(4), it[4][1])
			_ci.draw_set_transform(Vector2.ZERO)
			y += ph * 1.02 + 8.0


# ---------- rows on the paper ----------
## o: {k, st, tag, tagc, title, from, sub, bar (-1 = none), r1, r2, btn [label, cb, on], acc, imprint}
func _row_h(o: Dictionary, w: float) -> float:
	var sub: String = o.get("sub", "")
	var sw := w - 120.0
	var lines := 0
	if sub != "":
		lines = mini(3, int(ceil(S.tw(S.noto(), sub, 12) / maxf(60.0, sw))))
	return 30.0 + lines * 17.0 + (8.0 if o.get("bar", -1.0) >= 0.0 else 0.0) + 8.0

func _row(r: Rect2, o: Dictionary) -> void:
	var st: String = o.get("st", "run")
	var fa := col()
	var accent: Color = Color("#7fd0ff") if o.get("acc", false) else fa
	var dim := st == "lock" or st == "wait"
	var a := 0.5 if st == "got" else 1.0
	var bg := Color(1, 1, 1, 0.55)
	var border := Color("#3a2f26")
	if st == "done":
		border = accent.darkened(0.1)
		bg = Color(accent.lerp(Color.WHITE, 0.55), 0.85)
	if o.get("trial", false):
		border = RED
		if st != "done": bg = Color(1.0, 0.9, 0.88, 0.7)
	if dim:
		bg = Color(0, 0, 0, 0.05)
		border = Color(0, 0, 0, 0.18)
	_ci.draw_rect(Rect2(r.position + Vector2(0, 1), r.size), Color(0.24, 0.16, 0.08, 0.15 * a))
	_ci.draw_rect(r, Color(bg, bg.a * a))
	_ci.draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color(border, a))
	var x := r.position.x + 12.0
	var ink := Color(INK3 if dim else INK, a)
	if o.get("lock", false):
		S.lock(_ci, Vector2(x, r.position.y + 8.0), 13.0, Color(INK3, a))
		x += 18.0
	var tag: String = o.get("tag", "")
	if tag != "":
		var tw := S.tw(S.noto(), tag, 10) + 12.0
		S.para(_ci, Rect2(x, r.position.y + 8.0, tw, 16.0), 3.0, Color(o.get("tagc", Color("#3a2f26")), a))
		_ci.draw_string(S.noto(), Vector2(x + 6.0, r.position.y + 20.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, a))
		x += tw + 6.0
	var title: String = o.get("title", "")
	_ci.draw_string(S.bhs(), Vector2(x, r.position.y + 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	var fr: String = o.get("from", "")
	if fr != "":
		_ci.draw_string(S.noto(), Vector2(x + S.tw(S.bhs(), title, 15) + 6.0, r.position.y + 21.0), fr, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(INK3, a))
	var sub: String = o.get("sub", "")
	var sw := r.size.x - 120.0
	if sub != "":
		_ci.draw_multiline_string(S.noto(), Vector2(r.position.x + 12.0, r.position.y + 41.0), sub, HORIZONTAL_ALIGNMENT_LEFT, sw, 12, 3, Color(INK3 if dim else INK2, a))
	var bar: float = o.get("bar", -1.0)
	if bar >= 0.0:
		var by := r.end.y - 12.0
		_ci.draw_rect(Rect2(r.position.x + 12.0, by, sw, 4.0), Color(0, 0, 0, 0.12))
		_ci.draw_rect(Rect2(r.position.x + 12.0, by, sw * clampf(bar, 0.0, 1.0), 4.0), Color("#3a2f26"))
	# the right column
	var rx := r.end.x - 10.0
	var btn = o.get("btn", null)
	var ry := r.position.y + 22.0
	if btn != null:
		var bl: String = btn[0]
		var on: bool = btn[2]
		var bw := S.tw(S.bhs(), bl, 13) + 28.0
		var brr := Rect2(rx - bw, r.position.y + 8.0, bw, 24.0)
		var hv := brr.has_point(hover) and on
		var pulse := 0.5 + 0.5 * sin(t / 240.0) if on else 0.0
		if on: _ci.draw_colored_polygon(S.clip(Rect2(brr.position + Vector2(3, 3), brr.size), [[7, 0], [100, 0], [93, 100], [0, 100]]), Color(0, 0, 0, 0.8))
		_ci.draw_colored_polygon(S.clip(brr.grow(1.0 if hv else 0.0), [[7, 0], [100, 0], [93, 100], [0, 100]]), (Color("#ffd34d").lightened(0.15 * pulse) if on else Color("#555")))
		_ci.draw_string(S.bhs(), brr.position + Vector2(14, 17), bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK if on else Color(0.73, 0.73, 0.73))
		if on:
			var cb: Callable = btn[1]
			var rr := r
			var rw: Array = [o.get("r1", ""), o.get("r2", "")]
			var stp := "복구" if bl.begins_with("복구") else "완료"
			claim_r = brr
			_hit(brr.grow(3), func():
				if claims.size() > 0: return
				# the claim applies when the first chip lands (or 260 ms after the stamp if nothing flies)
				var n := _claim_fx(rr, rw, stp, rx)
				claims.append([cb, 160.0 + (120.0 + 520.0 if n > 0 else 260.0)]))
		ry = brr.end.y + 14.0
	var r1: String = o.get("r1", "")
	if r1 != "":
		var f := S.anton()
		_ci.draw_string(f, Vector2(rx - S.tw(f, r1, 14), ry), r1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, a))
		ry += 15.0
	var r2: String = o.get("r2", "")
	if r2 != "":
		var fs := 10
		_ci.draw_string(S.noto(), Vector2(rx - S.tw(S.noto(), r2, fs), ry), r2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color("#a87400") if not o.get("acc", false) else Color("#2f6d94"), a))
	if o.get("envelope", false):
		var wob := sin(t / 1600.0 * TAU) * 0.14
		_ci.draw_set_transform(Vector2(rx - 16.0, r.position.y + r.size.y / 2.0), wob, Vector2.ONE * (1.0 + 0.1 * absf(sin(t / 800.0 * PI))))
		S.envelope(_ci, Rect2(-13, -9, 26, 18), Color.WHITE)
		_ci.draw_set_transform(Vector2.ZERO)
	# the imprint of the stamp on rows that are done with
	var imp: String = o.get("imprint", "")
	if st == "got" and imp != "":
		var c := Vector2(rx - 34.0, r.position.y + r.size.y / 2.0)
		_ci.draw_set_transform(c, deg_to_rad(-12.0))
		var iw := S.tw(S.bhs(), imp, 16) + 16.0
		_ci.draw_rect(Rect2(-iw / 2.0, -14, iw, 28), Color(0.84, 0.16, 0.21, 0.7), false, 2.0)
		_ci.draw_string(S.bhs(), Vector2(-iw / 2.0 + 8.0, 6), imp, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.84, 0.16, 0.21, 0.75))
		_ci.draw_set_transform(Vector2.ZERO)
	var cb = o.get("click", null)
	if cb != null: _hit(r, cb)

func _sec(p: Vector2, s: String) -> float:
	var w := S.tw(S.bhs(), s, 13) + 20.0
	_ci.draw_set_transform(p, deg_to_rad(-1.5))
	S.para(_ci, Rect2(0, 0, w, 22), 4.0, Color("#2b2218"))
	_ci.draw_string(S.bhs(), Vector2(10, 16), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#efe6d1"))
	_ci.draw_set_transform(Vector2.ZERO)
	return 30.0

## a scrolling list of blocks inside the content rect: ["row", o] / ["sec", s] / ["note", s] / ["log", time, s] / ["goal", ...]
func _flow(cr: Rect2, blocks: Array) -> void:
	var sy: float = scroll.get(cur_tab(), 0.0)
	var y := cr.position.y - sy
	var w := cr.size.x
	var total := 0.0
	var idx := 0
	for B in blocks:
		var kind: String = B[0]
		var h := 0.0
		match kind:
			"row": h = _row_h(B[1], w)
			"sec": h = 30.0
			"note": h = S.noto().get_multiline_string_size(B[1], HORIZONTAL_ALIGNMENT_LEFT, w, 12).y + 10.0
			"log": h = 24.0
			"goal": h = 48.0
			"gap": h = B[1]
		# entrance: rows slide in one after another
		var ia := S.k(tab_t, idx * 30.0, 500.0)
		var dx := 26.0 * (1.0 if slide_dir > 0 or slide_t > 5000.0 else -1.0) * -1.0 * (1.0 - UIA.ez(FMIN, ia))
		if y + h > cr.position.y - 4.0 and y < cr.end.y + 4.0:
			var ka: float = pen.a
			pen.a = ka * clampf(ia * 2.5, 0.0, 1.0)
			_block(B, Rect2(cr.position.x + dx, y, w, h - 6.0), cr)
			pen.a = ka
		y += h
		total += h
		idx += 1
	content_h = total
	# fade the cut edges
	if total > cr.size.y:
		var sbh := cr.size.y * cr.size.y / total
		var sbp := cr.position.y + (cr.size.y - sbh) * clampf(sy / maxf(1.0, total - cr.size.y + 16.0), 0.0, 1.0)
		_ci.draw_rect(Rect2(cr.end.x + 6.0, sbp, 3.0, sbh), Color(0, 0, 0, 0.25))
	if sy > _scroll_max(): scroll[cur_tab()] = _scroll_max()

func _block(B: Array, r: Rect2, cr: Rect2) -> void:
	# only what fits wholly on the sheet is written (the sheet scrolls under its edges)
	if r.position.y < cr.position.y - 2.0 or r.end.y > cr.end.y + 6.0: return
	match String(B[0]):
		"row": _row_morph(r, B[1])
		"sec": _sec(r.position, B[1])
		"note": _ci.draw_multiline_string(S.noto(), r.position + Vector2(0, 14), B[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 12, -1, INK2)
		"log":
			_ci.draw_string(S.anton(), r.position + Vector2(0, 15), B[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK3)
			_ci.draw_string(S.noto(), r.position + Vector2(78, 15), B[2], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80.0, 12, INK)
			_ci.draw_rect(Rect2(r.position.x, r.end.y + 1.0, r.size.x, 1.0), Color(0, 0, 0, 0.06))
		"goal": _goal(Rect2(r.position, Vector2(r.size.x, 42.0)), B[1], B[2], B[3], B[4], B[5], true)

## per-row identity: a row whose state changed in place flashes (fm_swap: from .94×, brightness 1.6 → 1.15 at 60 % → none,
## .5s); a row that was not there before drops in (fm_new: from 14 px up, .96×, transparent, .55s); both --bk-ish (.2,1.5,.4,1)
func _row_morph(r: Rect2, o: Dictionary) -> void:
	var tb := cur_tab()
	var key := String(o.get("k", "")) + "|" + String(o.get("title", ""))
	var sig := "%s|%s|%s|%s|%s" % [o.get("st", ""), o.get("r1", ""), o.get("r2", ""), o.get("tag", ""), str(o.get("bar", -1.0)).left(5)]
	if not rowsig.has(tb): rowsig[tb] = {}
	var D: Dictionary = rowsig[tb]
	var settled := tab_t > 700.0 and slide_t > 2000.0 and t > 1200.0
	if D.has(key):
		if D[key] != sig and settled: row_fx[key] = ["swap", 0.0]
	elif settled and D.has("_init"):
		row_fx[key] = ["new", 0.0]
	D[key] = sig
	D["_init"] = true
	if not row_fx.has(key):
		_row(r, o)
		return
	var fx: Array = row_fx[key]
	var keep: Transform2D = pen.xf
	var ka: float = pen.a
	var c := r.get_center()
	var EZM := [0.2, 1.5, 0.4, 1.0]
	if fx[0] == "swap":
		var u := UIA.p(fx[1], 0.0, 500.0, EZM)
		pen.group(keep * UIA.xf(c, Vector2.ZERO, 0.0, Vector2.ONE * lerpf(0.94, 1.0, u)), ka)
		_row(r, o)
		var lit: float = UIA.kf(fx[1], [[0.0, 1.6], [0.6, 1.15], [1.0, 1.0]], 500.0, 0.0, EZM)
		if lit > 1.0: _ci.draw_rect(r, Color(1, 1, 1, (lit - 1.0) * 0.9))
	else:
		var u2 := UIA.p(fx[1], 0.0, 550.0, EZM)
		pen.group(keep * UIA.xf(c, Vector2(0, -14.0 * (1.0 - u2)), 0.0, Vector2.ONE * lerpf(0.96, 1.0, u2)), ka * clampf(fx[1] / 250.0, 0.0, 1.0))
		_row(r, o)
	pen.group(keep, ka)

# =========================== 길드 수첩 ===========================
func _p_quest(cr: Rect2) -> void:
	var r: int = fame.r
	var L := []
	for q in FD.FQ:
		if q["r"] == r: L.append([q, fame.f_state(q)])
	L.sort_custom(func(a, b):
		var oa: float = ORD[a[1]]
		var ob: float = ORD[b[1]]
		if oa != ob: return oa < ob
		return int(a[0].get("t", "") == "trial") < int(b[0].get("t", "") == "trial"))
	var B := []
	if L.is_empty():
		B.append(["row", {"st": "lock", "title": "다음 장 · 향후 추가 예정", "sub": ("%d등급 「%s」으로 가는 의뢰와 등급 보상은 새 이야기와 함께 추가된다." % [r + 1, FD.FRANK[r]["n"]]) if r + 1 <= 7 and r < FD.FRANK.size() else "새 이야기가 열리면 의뢰가 붙는다."}])
	for e in L:
		var q: Dictionary = e[0]
		var st: String = e[1]
		var trial: bool = q.get("t", "") == "trial"
		var v := clampi(fame.q_val(q), 0, q["g"])
		if st == "wait":
			B.append(["row", {"st": "wait", "trial": true, "tag": "심사", "tagc": RED, "title": "등급 심사 · ???", "sub": "명성을 %d 더 모으면 길드 관리국에서 심사 서신이 온다." % (FD.FRANK[r]["need"] - fame.pts)}])
			continue
		if st == "letter":
			B.append(["row", {"st": "letter", "trial": true, "tag": "서신", "tagc": RED, "title": "길드 관리국에서 서신 도착", "sub": "접수대의 에일린에게 받으면 등급 심사 의뢰가 붙는다.", "envelope": true}])
			continue
		var o := {"st": st, "trial": trial, "tag": "심사" if trial else "의뢰", "tagc": RED if trial else Color("#3a2f26"), "title": q["n"], "from": q["from"], "sub": q["d"],
			"imprint": "통과" if trial else "보고함"}
		if st == "run":
			o["bar"] = float(v) / q["g"]
			o["r1"] = "%d / %d" % [v, q["g"]]
			if q["f"]: o["r2"] = "명성 +%d" % q["f"]
		elif st == "done":
			o["r1"] = "완료"
			o["r2"] = "에일린에게 보고"
		B.append(["row", o])
	var n := 0
	for x in FD.FQ:
		if x["r"] == r + 1 and x.get("t", "") != "trial" and n < 3:
			n += 1
			B.append(["row", {"st": "lock", "lock": true, "title": "???", "sub": "%d등급 「%s」에서 열리는 의뢰 · %s" % [r + 1, FD.FRANK[r]["n"], x["from"]]}])
	_flow(cr, B)

func _p_fac(cr: Rect2) -> void:
	var B := []
	for grp in [["길드 본관", false], ["마을", true]]:
		B.append(["sec", grp[0]])
		for F in FD.FAC:
			if F.get("town", false) != grp[1]: continue
			var ok: bool = fame.fac_ok(F["id"])
			var lk: String = fame.fac_lock(F)
			var can: bool = not ok and lk == "" and arena.shilling >= F["cost"]
			var id: String = F["id"]
			var o := {"st": "got" if ok else ("lock" if lk != "" else ("done" if can else "run")), "tag": "복구됨" if ok else (lk if lk != "" else "시설"),
				"tagc": Color("#555") if ok or lk != "" else Color("#8a6a2a"), "title": F["n"], "from": F["where"], "sub": F["eff"], "imprint": "복구"}
			if not ok and lk != "":
				o["r1"] = ""
				o["r2"] = "브랜 합류 후" if lk == "브랜 합류" else "명성 " + lk
				o["lock"] = true
			elif not ok:
				o["btn"] = ["복구 · %d" % F["cost"], func(): fame.fac_restore(id), can]
				o["r2"] = "명성 +%d" % F["f"]
			B.append(["row", o])
	B.append(["note", "보유 실링 %d" % arena.shilling])
	_flow(cr, B)

func _p_people(cr: Rect2) -> void:
	# .paper .people: a grid of polaroids (auto-fill, ≥150 px, 10 apart, padding 10 6): each card 210 tall, a 5 px white
	# frame and a soft drop, turned -1.6° (odd) / 1.4° (even), a strip of tape over the top edge; members show their
	# portrait, the not-yet-met a black cut-out; the rank stamp only on the silhouettes. fm_up: 40 px up, 3°, .6 s, 55 ms apart
	var ink := Color(0.169, 0.133, 0.094)
	var x0 := cr.position.x + 6.0
	var w := cr.size.x - 12.0
	var per := maxi(1, int((w + 10.0) / 160.0))
	var cw := (w - 10.0 * (per - 1)) / per
	var ch := 210.0
	var sy: float = scroll.get("people", 0.0)
	var rows := ceili(float(FD.FPEOPLE.size()) / per)
	content_h = 10.0 + rows * (ch + 10.0)
	for i in FD.FPEOPLE.size():
		var p: Dictionary = FD.FPEOPLE[i]
		var cx := x0 + (i % per) * (cw + 10.0)
		var cy := cr.position.y + 10.0 + (i / per) * (ch + 10.0) - sy
		var u := S.k(tab_t, i * 55.0, 600.0)
		var e := S.bk(u)
		var a := clampf(u * 2.0, 0.0, 1.0)
		if cy + ch < cr.position.y - 20.0 or cy > cr.end.y + 20.0: continue
		var in_g: bool = (fame.bran == 1) if p.get("b", false) else (p.has("c") and fame.rec.has(p["c"]))
		var known: bool = p.has("c") or p.get("b", false)
		var rot := (-1.6 if i % 2 == 0 else 1.4) + 3.0 * (1.0 - e)
		var cc := Vector2(cx + cw / 2.0, cy + ch / 2.0 + 40.0 * (1.0 - e))
		var m := Transform2D(deg_to_rad(rot), cc) * Transform2D(0.0, -Vector2(cw, ch) / 2.0)
		var box := func(r: Rect2) -> PackedVector2Array: return PackedVector2Array([m * r.position, m * Vector2(r.end.x, r.position.y), m * r.end, m * Vector2(r.position.x, r.end.y)])
		# the drop (0 6 12 rgba(0,0,0,.35)) and the white frame (0 0 0 5px #fff)
		for k in 3:
			var g := 6.0 - k * 2.0
			_ci.draw_colored_polygon(box.call(Rect2(-5.0 - g, 6.0 - 5.0 - g, cw + 10.0 + g * 2.0, ch + 10.0 + g * 2.0)), Color(0, 0, 0, 0.1 * a))
		_ci.draw_colored_polygon(box.call(Rect2(-5, -5, cw + 10.0, ch + 10.0)), Color(1, 1, 1, a))
		_ci.draw_colored_polygon(box.call(Rect2(0, 0, cw, ch)), Color(0.102, 0.086, 0.125, a))
		_ci.draw_set_transform_matrix(m)
		if p.has("por"):
			var tx: Texture2D = _tex(p["por"])
			var ih := ch * 0.96
			var iw := ih * tx.get_width() / tx.get_height()
			var ir := Rect2(cw / 2.0 - iw / 2.0, ch + 6.0 - ih, iw, ih)
			var lo := maxf(ir.position.x, 0.0)
			var hi := minf(ir.end.x, cw)
			var bot := minf(ir.end.y, ch)
			if hi > lo:
				var sx := tx.get_width() / iw
				var syy := tx.get_height() / ih
				var src := Rect2((lo - ir.position.x) * sx, 0, (hi - lo) * sx, (bot - ir.position.y) * syy)
				var dst := Rect2(lo, ir.position.y, hi - lo, bot - ir.position.y)
				if in_g:
					_ci.draw_texture_rect_region(tx, Rect2(dst.position + Vector2(4, 0), Vector2(minf(dst.size.x, cw - 4.0 - dst.position.x), dst.size.y)), Rect2(src.position, Vector2(src.size.x * minf(1.0, (cw - 4.0 - dst.position.x) / dst.size.x), src.size.y)), Color(0, 0, 0, a))
					_ci.draw_texture_rect_region(tx, dst, src, Color(1, 1, 1, a))
				else:
					_ci.draw_texture_rect_region(tx, dst, src, Color(0, 0, 0, a))
		else:
			# .ph: a head and shoulders cut out in black (inset 18 % 26 % 0)
			var pr := Rect2(cw * 0.26, ch * 0.18, cw * 0.48, ch * 0.82)
			_ci.draw_circle(Vector2(pr.get_center().x, pr.position.y + pr.size.y * 0.22), pr.size.x * 0.22 * 1.2, Color(0, 0, 0, a))
			var sh := PackedVector2Array()
			for k in 17:
				var an := PI + PI * k / 16.0
				sh.append(Vector2(pr.get_center().x + cos(an) * pr.size.x * 0.55, pr.end.y + sin(an) * pr.size.y * 0.55 * 0.62))
			_ci.draw_colored_polygon(sh, Color(0, 0, 0, a))
			var stt := "%d등급" % p["r"]
			var sw := S.tw(S.noto(), stt, 11) + 16.0
			_ci.draw_set_transform_matrix(m * Transform2D(deg_to_rad(6.0), Vector2(cw - 6.0 - sw / 2.0, 6.0 + 9.0)))
			_ci.draw_rect(Rect2(-sw / 2.0, -9, sw, 18), Color(0, 0, 0, a))
			_ci.draw_string(S.noto(), Vector2(-sw / 2.0 + 8.0, 4), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(ink, a))
			_ci.draw_set_transform_matrix(m)
		# .pl: the gradient foot, the name (Black Han Sans 18, in the book's ink) and the line under it
		var nm: String = p["n"] if (in_g or not known) else "???"
		var role: String = p["role"] if in_g else ("첫 의뢰를 마치면 에일린이 소개해 준다" if known else "%s · %s" % [p["role"], p["hint"]])
		var rl := S.noto().get_multiline_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, cw - 20.0, 11).y
		var lh := 6.0 + 24.0 + rl + 8.0
		var ly := ch - lh
		for k in 8:
			var f := float(k) / 8.0
			_ci.draw_rect(Rect2(0, ly + lh * 0.35 * f, cw, lh * 0.35 / 8.0 + 0.5), Color(0, 0, 0, 0.92 * f * a))
		_ci.draw_rect(Rect2(0, ly + lh * 0.35, cw, lh * 0.65), Color(0, 0, 0, 0.92 * a))
		_ci.draw_string(S.bhs(), Vector2(10.0, ly + 6.0 + 19.0), nm, HORIZONTAL_ALIGNMENT_LEFT, cw - 20.0, 18, Color(ink, a))
		_ci.draw_multiline_string(S.noto(), Vector2(10.0, ly + 30.0 + 11.0), role, HORIZONTAL_ALIGNMENT_LEFT, cw - 20.0, 11, -1, Color(0.81, 0.78, 0.85, a))
		# the tape: 54 × 16, rgba(255,236,160,.75), -3°, 9 px over the top edge (the card clips it)
		_ci.draw_set_transform_matrix(m * Transform2D(deg_to_rad(-3.0), Vector2(cw / 2.0, -1.0)))
		_ci.draw_rect(Rect2(-27, 0, 54, 7), Color(1.0, 0.925, 0.627, 0.75 * a))
		_ci.draw_set_transform(Vector2.ZERO)

func _dun_list(lc: Rect2) -> void:
	var y := lc.position.y + 4.0
	for i in FD.DUNGEONS.size():
		var d: Dictionary = FD.DUNGEONS[i]
		var on := i == dun_i
		var lk: bool = not d["ok"] or FD.DUNRANK.get(d["id"], 1) > fame.r
		var r := Rect2(lc.position.x + (6.0 if on else 0.0), y, lc.size.x - 8.0, 46.0)
		_ci.draw_colored_polygon(S.clip(r, [[2, 0], [100, 0], [98, 100], [0, 100]]), Color.WHITE if on else Color(0.086, 0.075, 0.106, 0.9))
		var nm: String = d["name"] if d["ok"] else "???"
		_ci.draw_string(S.bhs(), r.position + Vector2(12, 21), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK if on else Color.WHITE)
		if lk: S.lock(_ci, r.position + Vector2(16 + S.tw(S.bhs(), nm, 16), 8), 12.0, Color.BLACK if on else Color(0.7, 0.7, 0.7))
		var sub: String = ("%s · 권장 Lv %d–%d" % [d["lv"], d["rec"][0], d["rec"][1]]) if d["ok"] else "미정"
		_ci.draw_string(S.noto(), r.position + Vector2(12, 38), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.75) if on else Color(1, 1, 1, 0.72))
		var ii := i
		_hit(r, func():
			dun_i = ii
			tab_t = 200.0
			arena.sfx("step", 0.25))
		y += 52.0

func _gem_line(grades: Array) -> String:
	var L: Array[String] = []
	for g in grades: L.append("◆" + FD.GRADE[g][0])
	return " ".join(L)

func _p_dun(cr: Rect2) -> void:
	var D: Dictionary = FD.DUNGEONS[dun_i]
	var rk: int = FD.DUNRANK.get(D["id"], 1)
	var ok: bool = D["ok"] and rk <= fame.r
	if not D["ok"]:
		_ci.draw_multiline_string(S.noto(), cr.position + Vector2(0, 20), "아직 아무것도 알려지지 않은 곳.\n이야기가 이어지면 길이 열린다.", HORIZONTAL_ALIGNMENT_LEFT, cr.size.x, 13, -1, INK2)
		return
	var grades := []
	for g in FD.GORD.duplicate():
		if g != "unique" and FD.GORD.find(g) >= FD.GORD.find(D["cap"]): grades.append(g)
	grades.reverse()
	var fx := []
	for F in FD.FAC:
		if fame.fac_ok(F["id"]) and F["id"] in ["hearth", "store", "barn", "bath", "yard"]: fx.append(F["n"])
	var mobs: Array[String] = []
	for k in D["mobs"]: mobs.append(FD.MOBN[k])
	var rows := [["입장 조건", ("✓ " if rk <= fame.r else "") + "명성 %d등급 「%s」" % [rk, FD.FRANK[rk - 1]["n"]]],
		["권장 레벨", "Lv %d–%d · 넘으면 기억석 레벨당 −25%%" % [D["rec"][0], D["rec"][1]]],
		["장비", "Lv %d–%d · 최고 %s" % [D["glv"][0], D["glv"][1], FD.GRADE[D["cap"]][0]]],
		["룬", _gem_line(grades) + " · 보스 상자 대박 ◆" + FD.GRADE[D["bonus"]][0]],
		["보상량", "×%s" % str(D["mul"]) + (" · 한 판 평균 실링 47 · 기억석 10 · 룬 6 · 장비 2.5" if D["id"] == "cave" else "")],
		["돌파 재료", FD.LAMP["n"] + " · " + FD.LAMP["src"]],
		["시설 효과", " · ".join(fx) if fx.size() else "복구된 시설이 없다 · 시설 탭"],
		["명성", "첫 클리어와 보스는 의뢰로 · 반복 클리어는 명성 없음"],
		["출몰", " · ".join(mobs) + " · 보스 감독관 해골"],
		["관찰", "EXP는 처음 만나고 · 처음 쓰러뜨리고 · 익숙해질 때 들어온다"]]   # PLACEHOLDER: the prototype's 룬 count line needs the rune list (agent B)
	var y := cr.position.y
	for i in rows.size():
		var u := S.k(tab_t, i * 30.0, 300.0)
		var dx := 26.0 * (1.0 - S.ez(u))
		var R: Array = rows[i]
		var h := 26.0
		var vw := cr.size.x - 112.0
		var th := S.noto().get_multiline_string_size(R[1], HORIZONTAL_ALIGNMENT_LEFT, vw, 12).y
		h = maxf(26.0, th + 10.0)
		_ci.draw_rect(Rect2(cr.position.x + dx, y, cr.size.x, h), Color(1, 1, 1, 0.5))
		_ci.draw_string(S.noto(), Vector2(cr.position.x + dx + 10.0, y + 17.0), R[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK3)
		var txt: String = R[1]
		if i == 3:
			# gems in their colours
			var x := cr.position.x + dx + 112.0
			for g in grades:
				_ci.draw_set_transform(Vector2(x + 5.0, y + 13.0), PI / 4.0)
				_ci.draw_rect(Rect2(-4, -4, 8, 8), FD.GRADE[g][1])
				_ci.draw_set_transform(Vector2.ZERO)
				_ci.draw_string(S.noto(), Vector2(x + 14.0, y + 17.0), FD.GRADE[g][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
				x += 20.0 + S.tw(S.noto(), FD.GRADE[g][0], 12)
			var rest := "· 보스 상자 대박 "
			_ci.draw_string(S.noto(), Vector2(x, y + 17.0), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
			x += S.tw(S.noto(), rest, 12)
			_ci.draw_set_transform(Vector2(x + 5.0, y + 13.0), PI / 4.0)
			_ci.draw_rect(Rect2(-4, -4, 8, 8), FD.GRADE[D["bonus"]][1])
			_ci.draw_set_transform(Vector2.ZERO)
			_ci.draw_string(S.noto(), Vector2(x + 14.0, y + 17.0), FD.GRADE[D["bonus"]][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
		else:
			_ci.draw_multiline_string(S.noto(), Vector2(cr.position.x + dx + 112.0, y + 17.0), txt, HORIZONTAL_ALIGNMENT_LEFT, vw, 12, -1, INK)
		y += h + 4.0
	y += 8.0
	if ok:
		var lbl := "출격하러 가기" if arena.level_kind() == "town" else "출격 마차에서 출발"
		var bw := S.tw(S.bhs(), lbl, 15) + 40.0
		var br := Rect2(cr.position.x, y, bw, 32.0)
		_ci.draw_colored_polygon(S.clip(br, [[7, 0], [100, 0], [93, 100], [0, 100]]), col())
		_ci.draw_string(S.bhs(), br.position + Vector2(20, 22), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)
		_hit(br, func():
			menu.close_page()
			fame.notice("출격 마차로 · 마을 동쪽 끝", "던전", col()))   # PLACEHOLDER: the sortie (dungeon select) is agent C's
	else:
		S.lock(_ci, Vector2(cr.position.x, y + 4.0), 13.0, INK3)
		_ci.draw_string(S.noto(), Vector2(cr.position.x + 18.0, y + 16.0), "명성 %d등급이 되면 열린다." % rk, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK2)

func _p_rune(cr: Rect2) -> void:
	# PLACEHOLDER: the rune codex lives with the runes (agent B); this tab only says where it will be
	_ci.draw_string(S.bhs(), cr.position + Vector2(0, 24), "룬 도감", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	_ci.draw_multiline_string(S.noto(), cr.position + Vector2(0, 52), "룬이 길드에 들어오면 이 장이 채워진다.\n발견한 룬 %d종" % fame.seen.size(), HORIZONTAL_ALIGNMENT_LEFT, cr.size.x, 13, -1, INK2)


# =========================== 모험 수첩 ===========================
func _p_home(cr: Rect2) -> void:
	var B := [["sec", "앞으로의 목표"]]
	var L: int = fame.alv
	var blue := Color("#7fd0ff")
	if L < FD.AMAX:
		B.append(["goal", "Lv %d까지 EXP %d" % [L + 1, FD.a_need(L) - fame.aexp], "보상 · " + FD.rw_txt(FD.a_reward(L + 1)), blue, func(): _go_tab("lv"), "레벨"])
	var ci: int = fame.ch_cur()
	if ci >= 0:
		var C: Dictionary = FD.FCH[ci]
		var nd := 0
		var nt = null
		for x in C["t"]:
			if fame.tgot.has(x["id"]): nd += 1
			elif nt == null: nt = x
		var cii := ci
		B.append(["goal", "제%d장 「%s」 %d / %d" % [ci + 1, C["n"], nd, C["t"].size()], (nt["n"] + " · " + nt["d"]) if nt != null else "모든 과제 완료 · 장 보상 받기", blue, func():
			chi = cii
			_go_tab("ch"), "일지"])
	if L >= FD.DAYLV:
		var D: Dictionary = fame.d_day()
		var left := 0
		for x in fame.d_tasks():
			if not D["got"].has(x["id"]): left += 1
		B.append(["goal", "오늘의 활동도 %d / 500" % int(D["pt"]), "%d개 남음 · 날이 바뀌면 새 과제" % left, blue, func(): _go_tab("day"), "훈련"])
	else:
		B.append(["goal", "일일 훈련 · Lv %d에 열림" % FD.DAYLV, "매일 다섯 가지 과제와 활동도 보상", Color("#9a8e7c"), func(): _go_tab("day"), "훈련"])
	var o: String = fame.fame_obj()
	var rq = null
	for q in FD.FQ:
		if q["r"] == fame.r and fame.f_state(q) == "run" and rq == null: rq = q
	var gt := o if o != "" else ("%s %d / %d" % [rq["n"], maxi(0, fame.q_val(rq)), rq["g"]] if rq != null else "길드 명성 %d" % fame.pts)
	var gs: String = (rq["n"] if o != "" and rq != null else (rq["d"] if rq != null else "시설을 복구하거나 다음 의뢰를 기다린다"))
	B.append(["goal", gt, gs, Color("#ffd34d"), func(): _goto("gbk", "quest"), "길드"])
	for F in FD.FAC:
		if not fame.fac_ok(F["id"]) and fame.fac_lock(F) == "":
			B.append(["goal", "%s 복구 · 실링 %d" % [F["n"], F["cost"]], F["eff"], Color("#ffd34d"), func(): _goto("gbk", "fac"), "시설"])
			break
	var best := ""
	for k in fame.bseen:
		if fame.obs_stage(k) < 4 and FD.MOBN.has(k) and (best == "" or fame.obs_stage(k) > fame.obs_stage(best)): best = k
	if best != "":
		var st: int = fame.obs_stage(best)
		B.append(["goal", "%s 관찰 %s → %s" % [FD.MOBN[best], ["", "Ⅰ", "Ⅱ", "Ⅲ"][st], ["", "Ⅱ", "Ⅲ", "Ⅳ"][st]], "다음: %s · 처치 %d" % [fame.b_next(best), int(fame.bkill.get(best, 0))], Color("#d9283e"), func(): pass, "도감"])
	B.append(["gap", 6.0])
	B.append(["sec", "지나온 길"])
	var lg: Array = fame.flog.duplicate()
	lg.reverse()
	if lg.is_empty(): B.append(["note", "아직 기록이 없다. 첫 걸음을 떼면 여기에 남는다."])
	for i in mini(30, lg.size()):
		var e: Dictionary = lg[i]
		var d := Time.get_datetime_dict_from_unix_time(int(e["t"] / 1000.0) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
		B.append(["log", "%d/%d %02d:%02d" % [d["month"], d["day"], d["hour"], d["minute"]], e["s"]])
	_flow(cr, B)

func _p_lv(cr: Rect2) -> void:
	var L: int = fame.alv
	var n: int = fame.lv_can().size()
	_sec(cr.position, "레벨 보상 · Lv 2 – %d" % FD.AMAX)
	if n:
		var lbl := "모두 받기 (%d)" % n
		var bw := S.tw(S.bhs(), lbl, 13) + 28.0
		var br := Rect2(cr.end.x - bw, cr.position.y - 2.0, bw, 26.0)
		_ci.draw_colored_polygon(S.clip(Rect2(br.position + Vector2(3, 3), br.size), [[7, 0], [100, 0], [93, 100], [0, 100]]), Color.BLACK)
		_ci.draw_colored_polygon(S.clip(br, [[7, 0], [100, 0], [93, 100], [0, 100]]), Color("#ffd34d").lightened(0.15 * (0.5 + 0.5 * sin(t / 240.0))))
		_ci.draw_string(S.bhs(), br.position + Vector2(14, 18), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
		_hit(br, func():
			for i in fame.lv_can(): fame.lv_claim(i)
			arena.sfx("heavy", 0.5))
	else:
		var nt := "끌어서 넘기기 · 휠로 넘기기"
		_ci.draw_string(S.noto(), Vector2(cr.end.x - S.tw(S.noto(), nt, 11), cr.position.y + 15.0), nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK3)
	# the road: one card per level, scrolled sideways (wheel / drag); opens at the current level
	road_w = cr.size.x
	if not scroll.has("lv"):
		# it opens 260 px short of the first level to claim (or the current one) and glides there
		var first: int = fame.lv_can()[0] if fame.lv_can().size() else L
		var to := clampf(roundf(road_center(first) / ROAD_STEP) * ROAD_STEP, 0.0, _road_max())
		scroll["lv"] = to - 260.0
		road_go(to, 0.0, 0.7, 0.8)
	var sx: float = scroll["lv"]
	var y0 := cr.position.y + 40.0
	var hh := cr.size.y - 50.0
	var x := cr.position.x - sx
	for i in range(2, FD.AMAX + 1):
		# .lv: 168 × 184, white (lock: rgba(255,255,255,.55)), the number in Anton 34 with its state beside it,
		# the reward lines; .cur / .next / .can rims, .got at .55 with the red 수령 stamp
		var cw := 168.0
		var vis := clampf((minf(x + cw, cr.end.x + 4.0) - maxf(x, cr.position.x - 2.0)) / cw, 0.0, 1.0)
		if vis > 0.02:
			var R := FD.a_reward(i)
			var gotit: bool = fame.lvc.has(str(i))
			var can := i <= L and not gotit
			var nxt := i == L + 1
			var lock := i > L
			var r := Rect2(x, y0, cw, minf(184.0, hh - 14.0))
			var bg := Color("#dff1ff") if can else (Color(1, 1, 1, 0.55) if lock else Color.WHITE)
			var ga := 0.55 if gotit else 1.0
			bg.a *= vis * ga
			var shp := S.clip(r, [[0, 0], [100, 0], [96, 100], [3, 97]])
			_ci.draw_colored_polygon(shp, bg)
			var rim := Color("#7fd0ff") if can else (Color("#9fc4d8") if nxt else (Color("#2f6d94") if i == L else Color(0, 0, 0, 0)))
			if rim.a > 0.0:
				var rl := shp.duplicate()
				rl.append(shp[0])
				_ci.draw_polyline(rl, Color(rim, vis * ga), 2.0)
			var a := ga * vis
			var num := str(i)
			var nc := Color("#b8ac94") if lock else Color("#2f6d94")
			_ci.draw_string(S.anton(true), r.position + Vector2(12, 10 + 31), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(nc, a))
			var stt := "받음" if gotit else ("받을 수 있음" if can else ("다음 레벨" if nxt else ""))
			if stt != "": _ci.draw_string(S.noto(), r.position + Vector2(12 + S.tw(S.anton(true), num, 34) + 4.0, 10 + 31), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(INK3, a))
			if i == L: _ci.draw_string(S.anton(), Vector2(r.end.x - 10.0 - S.tw(S.anton(), "NOW", 11), r.position.y + 10.0 + 9.0), "NOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#2f6d94", a))
			var ry := r.position.y + 10.0 + 34.0 + 4.0
			_ci.draw_multiline_string(S.noto(), Vector2(r.position.x + 12.0, ry + 13.0), FD.rw_txt(R).replace(" · ", "   "), HORIZONTAL_ALIGNMENT_LEFT, cw - 24.0, 12, -1, Color(Color("#9a8e7c") if lock else Color("#4a3e32"), a))
			if gotit and vis > 0.9:
				_ci.draw_set_transform(Vector2(r.end.x - 10.0 - 26.0, r.end.y - 12.0 - 13.0), deg_to_rad(-12.0))
				_ci.draw_rect(Rect2(-26, -13, 52, 26), Color(0.784, 0.137, 0.173, 0.72), false, 2.5)
				_ci.draw_string(S.bhs(), Vector2(-17, 7), "수령", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.784, 0.137, 0.173, 0.75))
				_ci.draw_set_transform(Vector2.ZERO)
			if can and vis > 0.9:
				var br := Rect2(r.position.x + 12.0, r.end.y - 36.0, 62.0, 24.0)
				_ci.draw_colored_polygon(S.clip(br, [[7, 0], [100, 0], [93, 100], [0, 100]]), Color("#ffd34d"))
				_ci.draw_string(S.bhs(), br.position + Vector2(17, 17), "받기", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
				var ii := i
				_hit(br.grow(4), func():
					road_to(ii)
					fame.lv_claim(ii)
					arena.sfx("heavy", 0.5))
		x += ROAD_STEP
	# the marker under the road
	var f := clampf(sx / maxf(1.0, (FD.AMAX - 1) * ROAD_STEP - (paper_r.size.x - 60.0)), 0.0, 1.0)
	_ci.draw_rect(Rect2(cr.position.x, cr.end.y - 4.0, cr.size.x, 2.0), Color(0, 0, 0, 0.12))
	_ci.draw_rect(Rect2(cr.position.x + (cr.size.x - 60.0) * f, cr.end.y - 6.0, 60.0, 6.0), Color("#2f6d94"))

func _ch_list(lc: Rect2) -> void:
	var ci: int = fame.ch_cur()
	if chi < 0 or chi >= FD.FCH.size(): chi = ci if ci >= 0 else FD.FCH.size() - 1
	var y := lc.position.y + 2.0
	for j in FD.FCH.size():
		var X: Dictionary = FD.FCH[j]
		var on := j == chi
		var op: bool = fame.ch_open(j)
		var nd := 0
		for x in X["t"]:
			if fame.tgot.has(x["id"]): nd += 1
		var dot := false
		if op:
			for x in X["t"]:
				if fame.t_can(x, j): dot = true
			if not fame.chc.has(X["id"]) and fame.ch_done(X): dot = true
		var r := Rect2(lc.position.x + (6.0 if on else 0.0), y, lc.size.x - 8.0, 50.0)
		_ci.draw_colored_polygon(S.clip(r, [[2, 0], [100, 0], [98, 100], [0, 100]]), Color.WHITE if on else Color(0.086, 0.075, 0.106, 0.88))
		var ink := Color.BLACK if on else Color.WHITE
		_ci.draw_string(S.noto(), r.position + Vector2(12, 17), "제%d장" % (j + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ink, 0.7))
		var nm: String = X["n"]
		var nfs := S.fit_size(S.bhs(), nm, 15, r.size.x - 70.0)
		_ci.draw_string(S.bhs(), r.position + Vector2(12, 38), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, ink)
		if not op: S.lock(_ci, r.position + Vector2(16 + S.tw(S.bhs(), nm, nfs), 26), 11.0, Color(ink, 0.7))
		var pr := "%d/%d" % [nd, X["t"].size()]
		_ci.draw_string(S.anton(), Vector2(r.end.x - 12.0 - S.tw(S.anton(), pr, 14), r.position.y + 30.0), pr, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
		if dot: _ci.draw_circle(Vector2(r.end.x - 6.0, r.position.y + 6.0), 5.0, Color("#ff3d5a"))
		if fame.chc.has(X["id"]): _ci.draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), Color("#7fd0ff"))
		var jj := j
		_hit(r, func():
			chi = jj
			tab_t = 200.0
			arena.sfx("step", 0.25))
		y += 56.0

func _p_ch(cr: Rect2) -> void:
	var ci: int = fame.ch_cur()
	if chi < 0 or chi >= FD.FCH.size(): chi = ci if ci >= 0 else FD.FCH.size() - 1
	var i := chi
	var C: Dictionary = FD.FCH[i]
	var op: bool = fame.ch_open(i)
	var TL := []
	for x in C["t"]:
		TL.append([x, "got" if fame.tgot.has(x["id"]) else ("done" if fame.t_can(x, i) else "run")])
	TL.sort_custom(func(a, b): return ORD[a[1]] < ORD[b[1]])
	var B := []
	for e in TL:
		var x: Dictionary = e[0]
		var st: String = e[1]
		var v := clampi(fame.t_val(x), 0, x["g"])
		var id: String = x["id"]
		var o := {"st": st, "acc": true, "title": x["n"], "sub": x["d"], "imprint": "완료", "r2": FD.rw_txt(x["rw"])}
		if st == "run":
			o["bar"] = float(v) / x["g"]
			o["r1"] = "%d / %d" % [v, x["g"]]
		elif st == "done":
			o["btn"] = ["받기", func():
				fame.t_claim(id)
				arena.sfx("heavy", 0.5), true]
		B.append(["row", o])
	# the chapter's own reward
	var dn: bool = fame.ch_done(C)
	var cg: bool = fame.chc.has(C["id"])
	var nx := " · 다음 장 「%s」" % FD.FCH[i + 1]["n"] if i + 1 < FD.FCH.size() else ""
	var co := {"st": "got" if cg else ("done" if dn and op else "run"), "acc": true, "tag": "장 보상", "tagc": Color("#2f6d94"), "title": "장 보상", "sub": FD.rw_txt(C["rw"]) + nx, "imprint": "완독"}
	var cid: String = C["id"]
	if not cg:
		if dn and op: co["btn"] = ["받기", func():
			fame.ch_claim(cid)
			arena.sfx("heavy", 0.6), true]
		else: co["r2"] = "과제를 모두 받으면"
	B.append(["row", co])
	_flow(Rect2(cr.position + Vector2(0, 70), cr.size - Vector2(0, 70)), B)
	_ci.draw_string(S.noto(), cr.position + Vector2(0, 12), "제%d장" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#2f6d94"))
	_ci.draw_string(S.bhs(), cr.position + Vector2(0, 38), C["n"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	var sub: String = C["d"] + ("" if op else " · 앞 장을 마치면 열린다 (진행도는 미리 쌓인다)")
	_ci.draw_string(S.noto(), cr.position + Vector2(0, 58), sub, HORIZONTAL_ALIGNMENT_LEFT, cr.size.x, 12, INK2)

func _day_col(lc: Rect2) -> void:
	var y := _hero(lc, false)
	var D: Dictionary = fame.d_day()
	var lk: bool = fame.alv < FD.DAYLV
	var fa := Color("#7fd0ff")
	var pt := int(D["pt"])
	_ci.draw_string(S.anton(true), Vector2(lc.position.x + 6.0, y + 46.0), str(pt), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, fa)
	var nx := lc.position.x + 16.0 + S.tw(S.anton(true), str(pt), 48)
	_ci.draw_string(S.anton(false, 1), Vector2(nx, y + 22.0), "ACTIVITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.73, 0.73, 0.73))
	_ci.draw_string(S.bhs(), Vector2(nx, y + 44.0), "오늘의 활동도", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var gr := Rect2(lc.position.x + 6.0, y + 56.0, lc.size.x - 20.0, 10.0)
	S.para(_ci, gr, -3.0, Color("#2a2630"))
	S.para(_ci, Rect2(gr.position, Vector2(gr.size.x * minf(1.0, pt / 500.0), gr.size.y)), -3.0, fa)
	var bw := (lc.size.x - 14.0) / 5.0
	for i in FD.DMS.size():
		var M: Dictionary = FD.DMS[i]
		var gotit: bool = D["ms"].has(str(i))
		var can: bool = not lk and not gotit and pt >= M["p"]
		var r := Rect2(lc.position.x + 6.0 + i * bw, y + 74.0, bw - 4.0, 64.0)
		var wob := sin(t / 1300.0 * TAU * 2.0) * 0.06 if can else 0.0
		_ci.draw_set_transform(r.get_center(), wob)
		var lr := Rect2(-r.size / 2.0, r.size)
		_ci.draw_rect(lr, fa if can else (Color("#2a2630") if not gotit else Color("#1a1620")))
		var ink := Color.BLACK if can else Color.WHITE
		_ci.draw_string(S.anton(), lr.position + Vector2(5, 16), str(M["p"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		var R: Dictionary = fame.d_ms_rw(i)
		var ry := lr.position.y + 32.0
		if gotit:
			_ci.draw_string(S.noto(), Vector2(lr.position.x + 5.0, ry), "받음", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.6))
		else:
			for line in FD.rw_txt(R).split(" · "):
				_ci.draw_string(S.noto(), Vector2(lr.position.x + 4.0, ry), line, HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 6.0, 9, Color(ink, 0.85))
				ry += 12.0
		_ci.draw_set_transform(Vector2.ZERO)
		if can:
			var ii := i
			_hit(r, func():
				fame.d_ms(ii)
				arena.sfx("heavy", 0.5))
	var note := "날짜가 바뀌면 새 과제가 붙는다." + ("\n로비 샹들리에 · 실링 +20%" if fame.fac_ok("chand") else "")
	_ci.draw_multiline_string(S.noto(), Vector2(lc.position.x + 6.0, y + 156.0), note, HORIZONTAL_ALIGNMENT_LEFT, lc.size.x - 10.0, 11, -1, Color(0.73, 0.73, 0.73))

func _p_day(cr: Rect2) -> void:
	var D: Dictionary = fame.d_day()
	var lk: bool = fame.alv < FD.DAYLV
	var B := []
	if lk: B.append(["row", {"st": "lock", "lock": true, "title": "모험가 Lv %d에 열린다" % FD.DAYLV, "sub": "매일 다섯 가지 작은 과제. 받은 활동도로 보상 상자를 연다."}])
	var TL := []
	for x in fame.d_tasks():
		TL.append([x, "got" if D["got"].has(x["id"]) else ("done" if fame.d_can(x) else ("lock" if lk else "run"))])
	TL.sort_custom(func(a, b): return ORD[a[1]] < ORD[b[1]])
	for e in TL:
		var x: Dictionary = e[0]
		var st: String = e[1]
		var v := mini(x["g"], fame.d_val(x))
		var id: String = x["id"]
		var o := {"st": st, "acc": true, "tag": "일일", "tagc": Color("#2f6d94"), "title": x["n"], "sub": x["d"], "imprint": "완료", "r2": "활동도 +%d" % x["p"]}
		if st == "run" or st == "lock":
			o["bar"] = float(v) / x["g"]
			o["r1"] = "%d / %d" % [v, x["g"]]
		elif st == "done":
			o["btn"] = ["받기", func():
				fame.d_claim(id)
				arena.sfx("heavy", 0.4), true]
		B.append(["row", o])
	_flow(cr, B)
