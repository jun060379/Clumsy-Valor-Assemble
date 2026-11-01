extends Control
## 길드 수첩 and 모험 수첩 (fame_ui.js / fame_core.js fmQuest · fmFac · fmPeople · fmDun · abHome · abLv · abCh · abDay):
## the menu pages "gbk" and "abk". A colour band across the top (guild yellow / adventure blue), the title, tabs, the purse,
## the other book's bookmark, the big number panel (rank / level) with its info menu on the left, and the paper sheet
## the rows are written on. Click / tap the buttons; wheel or drag scrolls the sheet; ←/→ (Q/E, LB/RB) change tabs,
## Tab switches books, Esc / B closes.

const S := preload("res://scripts/fame_skin.gd")
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
var hover := Vector2(-999, -999)
var tex := {}
var cur_book := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visible = false

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
		cur_book = b
		t = 0.0
		tab_t = 0.0
		fame.poll(true)
	var dt := minf(delta * 1000.0, 250.0)
	t += dt
	tab_t += dt
	queue_redraw()


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if not visible or book() == "": return
	if menu.ui_root.sweep.active or fame.fx.blocking(): return
	if ev is InputEventMouseMotion:
		hover = ev.position
		if not drag.is_empty() and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var d: Vector2 = ev.position - drag["p"]
			if d.length() > 6.0: drag["moved"] = true
			if drag["moved"]:
				_scroll_by(-(d.x if cur_tab() == "lv" else d.y))
				drag["p"] = ev.position
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed: _scroll_by(48.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed: _scroll_by(-48.0)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				drag = {"p": ev.position, "moved": false, "in": paper_r.has_point(ev.position)}
			else:
				var moved: bool = drag.get("moved", false)
				drag = {}
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
		menu.close_page()
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
	tab[book()] = tb
	tab_t = 0.0
	arena.sfx("step", 0.3)
	S.play(self, S.noise_wav(0.16), 0.18)
	fame.poll(true)

func _switch_book() -> void:
	menu.page = "abk" if book() == "gbk" else "gbk"
	arena.sfx("ready", 0.3)

func _goto(b: String, tb: String) -> void:
	if b != book(): menu.page = b
	tab[b] = tb
	tab_t = 0.0
	arena.sfx("step", 0.3)

func _scroll_by(d: float) -> void:
	var tb := cur_tab()
	var mx := _scroll_max()
	scroll[tb] = clampf(float(scroll.get(tb, 0.0)) + d, 0.0, mx)

func _scroll_max() -> float:
	if cur_tab() == "lv":
		return maxf(0.0, (FD.AMAX - 1) * 128.0 - (paper_r.size.x - 60.0))
	return maxf(0.0, content_h - paper_r.size.y + 16.0)


# =====================================================================
func _draw() -> void:
	hits.clear()
	var b := book()
	if b == "": return
	var vs := get_viewport_rect().size
	var fa := col()
	var tb := cur_tab()
	# ground: ink, drifting dots, the colour band (breathing)
	draw_rect(Rect2(Vector2.ZERO, vs), Color("#0d0b10"))
	var dof := fmod(t / 7000.0, 1.0) * 12.0
	S.dots(self, Rect2(Vector2.ZERO, vs), 12.0, 1.6, Color(1, 1, 1, 0.06), Vector2(dof, dof))
	var br := 0.5 - 0.5 * cos(t / 7000.0 * TAU)
	var band := Rect2(-0.1 * vs.x, -30.0 + 2.0 * br, vs.x * 1.2, 120.0)
	draw_set_transform(band.get_center(), deg_to_rad(-4.0 + 0.6 * br))
	draw_rect(Rect2(-band.size / 2.0, band.size), fa)
	draw_set_transform(Vector2.ZERO)
	# title
	var en := "GUILD BOOK" if b == "gbk" else "ADVENTURE BOOK"
	var kr := "길드 수첩" if b == "gbk" else "모험 수첩"
	draw_set_transform(Vector2(18, 10), deg_to_rad(-4.0))
	draw_string(S.anton(false, 3), Vector2(0, 11), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	var tw := S.tw(S.bhs(), kr, 30)
	S.para(self, Rect2(-2, 15, tw + 26.0, 36), 7.0, Color.BLACK)
	draw_string(S.bhs(), Vector2(10, 44), kr, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	_draw_tabs(vs, fa)
	_draw_purse(vs, fa)
	_draw_bookmark(vs)
	# the pane
	var pane := Rect2(16, 106, vs.x - 32, vs.y - 118)
	var dock: String = HDOCK.get(tb, "L")
	var left_w := 0.0
	match tb:
		"quest", "fac", "home", "lv", "day": left_w = pane.size.x * (0.34 if tb == "fac" else (0.29 if tb == "lv" else 0.31))
		"dun": left_w = pane.size.x * 0.26
		"ch": left_w = pane.size.x * 0.30
	var e := S.ez(S.k(tab_t, 0.0, 420.0))
	var slide := 40.0 * (1.0 - e)
	paper_r = Rect2(pane.position.x + (left_w + 14.0 if left_w > 0.0 else 0.0) + slide, pane.position.y, pane.size.x - (left_w + 14.0 if left_w > 0.0 else 0.0), pane.size.y)
	_draw_paper(paper_r, e)
	var cr := Rect2(paper_r.position + Vector2(34, 12), paper_r.size - Vector2(48, 20))
	match tb:
		"quest": _p_quest(cr)
		"fac": _p_fac(cr)
		"people": _p_people(Rect2(paper_r.position + Vector2(18, 12), paper_r.size - Vector2(30, 20)))
		"dun": _p_dun(cr)
		"rune": _p_rune(cr)
		"home": _p_home(cr)
		"lv": _p_lv(cr)
		"ch": _p_ch(cr)
		"day": _p_day(cr)
	# the left column
	var lc := Rect2(pane.position.x - 30.0 * (1.0 - e), pane.position.y, left_w, pane.size.y)
	match tb:
		"quest", "fac":
			var y := _hero(lc, false)
			_info_menu(Rect2(lc.position.x, y + 8.0, lc.size.x, lc.end.y - y - 8.0), "rank", "등급 안내")
		"home", "lv":
			var y := _hero(lc, false)
			var n: int = fame.lv_can().size()
			if n and tb == "home":
				y = _goal(Rect2(lc.position.x, y + 6.0, lc.size.x - 8.0, 44.0), "받지 않은 레벨 보상 %d개" % n, "모험 레벨 탭에서 받기", Color("#7fd0ff"), func(): _go_tab("lv")) + 4.0
			_info_menu(Rect2(lc.position.x, y + 8.0, lc.size.x, lc.end.y - y - 8.0), "exp", "EXP 획득처")
		"day": _day_col(lc)
		"dun": _dun_list(lc)
		"ch": _ch_list(lc)
	if dock == "R": _hero(Rect2(vs.x - 196.0, vs.y - 92.0, 180.0, 80.0), true)
	_draw_close(vs, fa)


# ---------- chrome ----------
func _draw_tabs(vs: Vector2, fa: Color) -> void:
	var L: Array = TABS[book()]
	var x := maxf(190.0, vs.x * 0.22)
	var bf := S.bhs()
	var fs := 18 if vs.x > 1000.0 else 16
	for i in L.size():
		var on: bool = L[i][0] == cur_tab()
		var s: String = L[i][1]
		var w := S.tw(bf, s, fs) + 22.0
		var r := Rect2(x, 16.0, w, 30.0)
		var sc := 1.16 if on else 1.0
		draw_set_transform_matrix(Transform2D(0.0, Vector2(sc, sc), deg_to_rad(-8.0), r.get_center() + Vector2(0, -2 if on else 0)))
		var lr := Rect2(-w / 2.0, -15.0, w, 30.0)
		var hv := r.has_point(hover) and not on
		if on:
			draw_colored_polygon(S.clip(lr, [[3, 20], [97, 0], [100, 74], [7, 100]]), Color.WHITE)
			draw_string(S.anton(false, 2), Vector2(lr.position.x + 10.0, lr.position.y - 2.0), L[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.BLACK)
			draw_string(bf, Vector2(lr.position.x + 11.0, 7.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
		else:
			draw_string_outline(bf, Vector2(lr.position.x + 11.0, 7.0 - (2.0 if hv else 0.0)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
			draw_string(bf, Vector2(lr.position.x + 11.0, 7.0 - (2.0 if hv else 0.0)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 1.0 if hv else 0.85))
		var badge := _badge(L[i][0])
		if badge > 0:
			draw_circle(Vector2(lr.end.x - 2.0, lr.position.y + 2.0), 8.0, Color("#ff3d5a"))
			var bs := str(badge)
			draw_string(S.noto(), Vector2(lr.end.x - 2.0 - S.tw(S.noto(), bs, 10) / 2.0, lr.position.y + 6.0), bs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		var tb: String = L[i][0]
		_hit(r, func(): _go_tab(tb))
		x += w * sc + 4.0

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
		draw_set_transform(Vector2(x + w / 2.0, 70.0 + (6.0 if j == 1 else (2.0 if j == 2 else 0.0))), deg_to_rad(rots[j]))
		var r := Rect2(-w / 2.0, -12.0, w, 24.0)
		draw_colored_polygon(S.clip(Rect2(r.position + Vector2(3, 3), r.size), [[9, 0], [100, 0], [91, 100], [0, 100]]), Color.BLACK)
		draw_colored_polygon(S.clip(r, [[9, 0], [100, 0], [91, 100], [0, 100]]), Color.WHITE)
		draw_circle(r.position + Vector2(16, 12), 9.0, Color.BLACK)
		draw_string(S.noto(), r.position + Vector2(16 - S.tw(S.noto(), it[2], 10) / 2.0, 16), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fa)
		draw_string(S.noto(), r.position + Vector2(30, 15), it[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.75))
		draw_string(S.anton(), Vector2(r.end.x - 12.0 - S.tw(S.anton(), it[1], 15), r.position.y + 18.0), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)
		draw_set_transform(Vector2.ZERO)

## the other book's bookmark, hanging under the band on the right
func _draw_bookmark(vs: Vector2) -> void:
	var other := "abk" if book() == "gbk" else "gbk"
	var oc: Color = BOOKCOL[other]
	var en := "ADVENTURE" if other == "abk" else "GUILD"
	var kr := "모험 수첩" if other == "abk" else "길드 수첩"
	var w := S.tw(S.bhs(), kr, 14) + 24.0
	var r := Rect2(vs.x - 16.0 - w, 58.0, w, 52.0)
	var hv := r.has_point(hover)
	draw_set_transform(Vector2(r.get_center().x, r.position.y), deg_to_rad(-2.0 if hv else -5.0))
	var lr := Rect2(-w / 2.0, 4.0 if hv else 0.0, w, 52.0)
	draw_colored_polygon(S.clip(lr, [[0, 0], [100, 0], [100, 82], [50, 100], [0, 82]]), Color.BLACK)
	draw_rect(Rect2(lr.position, Vector2(w, 5)), oc)
	draw_string(S.anton(false, 2), Vector2(-S.tw(S.anton(false, 2), en, 9) / 2.0, lr.position.y + 19.0), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, oc)
	draw_string(S.bhs(), Vector2(-S.tw(S.bhs(), kr, 14) / 2.0, lr.position.y + 36.0), kr, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	_hit(r, func(): _switch_book())

func _draw_close(vs: Vector2, fa: Color) -> void:
	var c := Vector2(vs.x - 14.0 - 18.0, 10.0 + 18.0)
	draw_circle(c + Vector2(3, 3), 18.0, fa)
	draw_circle(c, 18.0, Color.BLACK)
	draw_arc(c, 17.0, 0, TAU, 32, Color.WHITE, 2.0, true)
	draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), Color.WHITE, 2.0, true)
	draw_line(c + Vector2(5, -5), c + Vector2(-5, 5), Color.WHITE, 2.0, true)
	_hit(Rect2(c - Vector2(20, 20), Vector2(40, 40)), func(): menu.close_page())

## the paper sheet: cream, a red margin line, faint rules, a hard black drop
func _draw_paper(r: Rect2, e: float) -> void:
	var rot := deg_to_rad(-0.6)
	draw_set_transform(r.get_center(), rot)
	var lr := Rect2(-r.size / 2.0, r.size)
	draw_rect(Rect2(lr.position + Vector2(7, 9), lr.size), Color(0, 0, 0, e))
	draw_rect(lr, Color(PAPER, 1.0))
	var y := lr.position.y + 27.0
	while y < lr.end.y:
		draw_rect(Rect2(lr.position.x, y, lr.size.x, 1.0), Color(0.24, 0.16, 0.08, 0.075))
		y += 28.0
	draw_rect(Rect2(lr.position.x + 30.0, lr.position.y, 1.0, lr.size.y), Color(0.78, 0.27, 0.27, 0.22))
	draw_rect(Rect2(lr.position, Vector2(10, lr.size.y)), Color(0, 0, 0, 0.08))
	draw_set_transform(Vector2.ZERO)


# ---------- the big number (hero) ----------
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
	draw_set_transform(p + Vector2(0, 4), deg_to_rad(-1.5 if not small else 7.0 * 0.0 - 3.0))
	var lr := Rect2(0, 0, w, h)
	draw_colored_polygon(S.clip(Rect2(lr.position + Vector2(5, 5), lr.size), [[0, 0], [100, 3], [97, 100], [2, 95]]), fa)
	draw_colored_polygon(S.clip(lr, [[0, 0], [100, 3], [97, 100], [2, 95]]), Color("#0d0b10"))
	var fi := S.anton(true)
	var nw := S.tw(fi, num, nfs)
	draw_string(fi, Vector2(16 + 4, nfs * 0.86 + 4), num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color.BLACK)
	draw_string(fi, Vector2(16, nfs * 0.86), num, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, fa)
	var tx := 16.0 + nw + 10.0
	draw_string(S.anton(false, 1), Vector2(tx, nfs * 0.5), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.73, 0.73, 0.73))
	var nmfs := S.fit_size(S.bhs(), nm, 18 if small else 22, w - tx - 10.0)
	draw_string(S.bhs(), Vector2(tx, nfs * 0.5 + nmfs + 2.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nmfs, Color.WHITE)
	if not small:
		var gy := nfs * 0.98 + 6.0
		var gr := Rect2(16, gy, w - 36.0, 12.0)
		S.para(self, gr, -3.0, Color("#2a2630"))
		var f := clampf(cur / maxf(1.0, need), 0.0, 1.0)
		if f > 0.0: S.para(self, Rect2(gr.position, Vector2(gr.size.x * f, gr.size.y)), -3.0, fa)
		draw_string(S.noto(), Vector2(16, gy + 30.0), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.87, 0.87, 0.87))
		draw_string(S.noto(), Vector2(w - 20.0 - S.tw(S.noto(), l2, 12), gy + 30.0), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.87, 0.87, 0.87))
	draw_set_transform(Vector2.ZERO)
	return p.y + h + 8.0

## a goal button (abHome .goal)
func _goal(r: Rect2, title: String, sub: String, gc: Color, cb: Callable, tag := "", on_paper := false) -> float:
	var hv := r.has_point(hover)
	var bg := Color(1, 1, 1, 0.6) if on_paper else Color("#16131b")
	draw_rect(r, bg if not hv else (Color(1, 1, 1, 0.85) if on_paper else Color("#221d29")))
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), gc)
	var x := r.position.x + 12.0
	var ink := INK if on_paper else Color.WHITE
	if tag != "":
		var tw := S.tw(S.noto(), tag, 10) + 12.0
		S.para(self, Rect2(x, r.position.y + 8.0, tw, 16.0), 3.0, gc)
		draw_string(S.noto(), Vector2(x + 6.0, r.position.y + 20.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
		x += tw + 6.0
	draw_string(S.bhs(), Vector2(x, r.position.y + 21.0), title, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - x - 24.0, 15, ink)
	draw_string(S.noto(), Vector2(r.position.x + 12.0, r.position.y + 38.0), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 40.0, 11, INK2 if on_paper else Color(0.79, 0.76, 0.82))
	draw_string(S.anton(), Vector2(r.end.x - 16.0, r.position.y + r.size.y / 2.0 + 6.0), "›", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, gc)
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
	draw_string(S.bhs(), r.position + Vector2(4, 14), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, fa)
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
			draw_set_transform_matrix(xf * Transform2D(deg_to_rad(2.0), Vector2(x - 6.0, y + 14.0)))
			draw_colored_polygon(S.clip(Rect2(0, 0, cw * 1.28 + 10.0, 30), [[0, 34], [100, 8], [94, 100], [5, 84]]), fa)
			draw_set_transform_matrix(xf * Transform2D(deg_to_rad(-3.0), Vector2(x - 2.0, y + 10.0)))
			draw_colored_polygon(S.clip(Rect2(0, 0, cw * 1.28, 30), [[3, 20], [97, 0], [100, 74], [7, 100]]), Color.WHITE)
		draw_set_transform_matrix(base)
		if on:
			draw_string(S.anton(false, 2), Vector2(2, 4), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, fa.darkened(0.2))
			draw_string(bf, Vector2(4, 22), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK)
		else:
			draw_string_outline(bf, Vector2(4, 22), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color.BLACK)
			draw_string(bf, Vector2(4, 22), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.82))
		draw_set_transform(Vector2.ZERO)
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
			draw_set_transform(pp, deg_to_rad(2.5))
			var pr := Rect2(0, 0, pw, ph)
			draw_colored_polygon(S.clip(pr, [[0, 6], [5, 6], [8, 0], [11, 6], [100, 8], [98.5, 100], [1, 96]]), Color.BLACK)
			draw_rect(Rect2(0, 6, 5, ph - 10.0), fa)
			draw_string(S.anton(false, 2), Vector2(14, 24), it[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, fa)
			draw_string(bf, Vector2(14, 42), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			var lk: bool = it.size() > 5 and it[5]
			draw_multiline_string(S.noto(), Vector2(14, 60), text, HORIZONTAL_ALIGNMENT_LEFT, pw - 26.0, 12, -1, Color(0.54, 0.52, 0.57) if lk else Color(0.87, 0.87, 0.87))
			if it[4] != null:
				var bl: String = it[4][0]
				var bw := S.tw(S.bhs(), bl, 12) + 26.0
				var brr := Rect2(14, ph - 30.0, bw, 22.0)
				draw_colored_polygon(S.clip(brr, [[7, 0], [100, 0], [93, 100], [0, 100]]), fa)
				draw_string(S.bhs(), brr.position + Vector2(13, 16), bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
				var sr := Rect2(pp + Vector2(14, ph - 30.0).rotated(deg_to_rad(2.5)), Vector2(bw, 22))
				_hit(sr.grow(4), it[4][1])
			draw_set_transform(Vector2.ZERO)
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
	draw_rect(Rect2(r.position + Vector2(0, 1), r.size), Color(0.24, 0.16, 0.08, 0.15 * a))
	draw_rect(r, Color(bg, bg.a * a))
	draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color(border, a))
	var x := r.position.x + 12.0
	var ink := Color(INK3 if dim else INK, a)
	if o.get("lock", false):
		S.lock(self, Vector2(x, r.position.y + 8.0), 13.0, Color(INK3, a))
		x += 18.0
	var tag: String = o.get("tag", "")
	if tag != "":
		var tw := S.tw(S.noto(), tag, 10) + 12.0
		S.para(self, Rect2(x, r.position.y + 8.0, tw, 16.0), 3.0, Color(o.get("tagc", Color("#3a2f26")), a))
		draw_string(S.noto(), Vector2(x + 6.0, r.position.y + 20.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, a))
		x += tw + 6.0
	var title: String = o.get("title", "")
	draw_string(S.bhs(), Vector2(x, r.position.y + 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	var fr: String = o.get("from", "")
	if fr != "":
		draw_string(S.noto(), Vector2(x + S.tw(S.bhs(), title, 15) + 6.0, r.position.y + 21.0), fr, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(INK3, a))
	var sub: String = o.get("sub", "")
	var sw := r.size.x - 120.0
	if sub != "":
		draw_multiline_string(S.noto(), Vector2(r.position.x + 12.0, r.position.y + 41.0), sub, HORIZONTAL_ALIGNMENT_LEFT, sw, 12, 3, Color(INK3 if dim else INK2, a))
	var bar: float = o.get("bar", -1.0)
	if bar >= 0.0:
		var by := r.end.y - 12.0
		draw_rect(Rect2(r.position.x + 12.0, by, sw, 4.0), Color(0, 0, 0, 0.12))
		draw_rect(Rect2(r.position.x + 12.0, by, sw * clampf(bar, 0.0, 1.0), 4.0), Color("#3a2f26"))
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
		if on: draw_colored_polygon(S.clip(Rect2(brr.position + Vector2(3, 3), brr.size), [[7, 0], [100, 0], [93, 100], [0, 100]]), Color(0, 0, 0, 0.8))
		draw_colored_polygon(S.clip(brr.grow(1.0 if hv else 0.0), [[7, 0], [100, 0], [93, 100], [0, 100]]), (Color("#ffd34d").lightened(0.15 * pulse) if on else Color("#555")))
		draw_string(S.bhs(), brr.position + Vector2(14, 17), bl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK if on else Color(0.73, 0.73, 0.73))
		if on: _hit(brr.grow(3), btn[1])
		ry = brr.end.y + 14.0
	var r1: String = o.get("r1", "")
	if r1 != "":
		var f := S.anton()
		draw_string(f, Vector2(rx - S.tw(f, r1, 14), ry), r1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, a))
		ry += 15.0
	var r2: String = o.get("r2", "")
	if r2 != "":
		var fs := 10
		draw_string(S.noto(), Vector2(rx - S.tw(S.noto(), r2, fs), ry), r2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Color("#a87400") if not o.get("acc", false) else Color("#2f6d94"), a))
	if o.get("envelope", false):
		var wob := sin(t / 1600.0 * TAU) * 0.14
		draw_set_transform(Vector2(rx - 16.0, r.position.y + r.size.y / 2.0), wob, Vector2.ONE * (1.0 + 0.1 * absf(sin(t / 800.0 * PI))))
		S.envelope(self, Rect2(-13, -9, 26, 18), Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	# the imprint of the stamp on rows that are done with
	var imp: String = o.get("imprint", "")
	if st == "got" and imp != "":
		var c := Vector2(rx - 34.0, r.position.y + r.size.y / 2.0)
		draw_set_transform(c, deg_to_rad(-12.0))
		var iw := S.tw(S.bhs(), imp, 16) + 16.0
		draw_rect(Rect2(-iw / 2.0, -14, iw, 28), Color(0.84, 0.16, 0.21, 0.7), false, 2.0)
		draw_string(S.bhs(), Vector2(-iw / 2.0 + 8.0, 6), imp, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.84, 0.16, 0.21, 0.75))
		draw_set_transform(Vector2.ZERO)
	var cb = o.get("click", null)
	if cb != null: _hit(r, cb)

func _sec(p: Vector2, s: String) -> float:
	var w := S.tw(S.bhs(), s, 13) + 20.0
	draw_set_transform(p, deg_to_rad(-1.5))
	S.para(self, Rect2(0, 0, w, 22), 4.0, Color("#2b2218"))
	draw_string(S.bhs(), Vector2(10, 16), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#efe6d1"))
	draw_set_transform(Vector2.ZERO)
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
		var ia := S.k(tab_t, idx * 30.0, 300.0)
		var dx := 26.0 * (1.0 - S.ez(ia))
		if y + h > cr.position.y - 4.0 and y < cr.end.y + 4.0:
			_block(B, Rect2(cr.position.x + dx, y, w, h - 6.0), cr)
		y += h
		total += h
		idx += 1
	content_h = total
	# fade the cut edges
	if total > cr.size.y:
		var sbh := cr.size.y * cr.size.y / total
		var sbp := cr.position.y + (cr.size.y - sbh) * clampf(sy / maxf(1.0, total - cr.size.y + 16.0), 0.0, 1.0)
		draw_rect(Rect2(cr.end.x + 6.0, sbp, 3.0, sbh), Color(0, 0, 0, 0.25))
	if sy > _scroll_max(): scroll[cur_tab()] = _scroll_max()

func _block(B: Array, r: Rect2, cr: Rect2) -> void:
	# only what fits wholly on the sheet is written (the sheet scrolls under its edges)
	if r.position.y < cr.position.y - 2.0 or r.end.y > cr.end.y + 6.0: return
	match String(B[0]):
		"row": _row(r, B[1])
		"sec": _sec(r.position, B[1])
		"note": draw_multiline_string(S.noto(), r.position + Vector2(0, 14), B[1], HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 12, -1, INK2)
		"log":
			draw_string(S.anton(), r.position + Vector2(0, 15), B[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK3)
			draw_string(S.noto(), r.position + Vector2(78, 15), B[2], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 80.0, 12, INK)
			draw_rect(Rect2(r.position.x, r.end.y + 1.0, r.size.x, 1.0), Color(0, 0, 0, 0.06))
		"goal": _goal(Rect2(r.position, Vector2(r.size.x, 42.0)), B[1], B[2], B[3], B[4], B[5], true)

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
	var cw := maxf(150.0, (cr.size.x - 10.0 * 4.0) / 5.0)
	var per := maxi(1, int((cr.size.x + 10.0) / (cw + 10.0)))
	cw = (cr.size.x - 10.0 * (per - 1)) / per
	var ch := 210.0
	var sy: float = scroll.get("people", 0.0)
	var rows := ceili(float(FD.FPEOPLE.size()) / per)
	content_h = rows * (ch + 10.0)
	for i in FD.FPEOPLE.size():
		var p: Dictionary = FD.FPEOPLE[i]
		var cx := cr.position.x + (i % per) * (cw + 10.0)
		var cy := cr.position.y + (i / per) * (ch + 10.0) - sy
		var u := S.k(tab_t, i * 55.0, 600.0)
		cy += 40.0 * (1.0 - S.bk(u))
		if cy + ch < cr.position.y - 4.0 or cy > cr.end.y: continue
		var in_g: bool = (fame.bran == 1) if p.get("b", false) else (p.has("c") and fame.rec.has(p["c"]))
		var r := Rect2(cx, cy, cw, ch)
		var clip_top := maxf(r.position.y, cr.position.y - 6.0)
		var clip_bot := minf(r.end.y, cr.end.y + 8.0)
		var vr := Rect2(r.position.x, clip_top, r.size.x, clip_bot - clip_top)
		draw_colored_polygon(S.clip(vr, [[3, 0], [100, 2], [97, 100], [0, 98]]), Color("#1a1620"))
		if p.has("por"):
			var tx: Texture2D = _tex(p["por"])
			var ih := ch * 0.96
			var iw := ih * tx.get_width() / tx.get_height()
			var ir := Rect2(cx + cw / 2.0 - iw / 2.0, cy + ch + 6.0 - ih, iw, ih)
			# crop to the card
			var src := Rect2(Vector2.ZERO, tx.get_size())
			var dst := ir
			var lo := maxf(ir.position.x, cx)
			var hi := minf(ir.end.x, cx + cw)
			var top := maxf(ir.position.y, clip_top)
			var bot := minf(ir.end.y, clip_bot)
			if hi > lo and bot > top:
				var sx := tx.get_width() / iw
				var syy := tx.get_height() / ih
				src = Rect2((lo - ir.position.x) * sx, (top - ir.position.y) * syy, (hi - lo) * sx, (bot - top) * syy)
				dst = Rect2(lo, top, hi - lo, bot - top)
				if in_g:
					draw_texture_rect_region(tx, Rect2(dst.position + Vector2(4, 0), dst.size), src, Color.BLACK)
					draw_texture_rect_region(tx, dst, src, Color.WHITE)
				else:
					draw_texture_rect_region(tx, dst, src, Color(0.02, 0.02, 0.03))
		else:
			# a silhouette: head and shoulders
			var c := Vector2(cx + cw / 2.0, cy + ch * 0.18)
			draw_circle(c + Vector2(0, ch * 0.18), cw * 0.17, Color.BLACK)
			draw_colored_polygon(PackedVector2Array([Vector2(cx + cw * 0.16, cy + ch), Vector2(cx + cw * 0.3, cy + ch * 0.62), Vector2(cx + cw * 0.7, cy + ch * 0.62), Vector2(cx + cw * 0.84, cy + ch)]), Color.BLACK)
			var stt := "%d등급" % p["r"]
			draw_set_transform(Vector2(cx + cw - 30.0, cy + 14.0), deg_to_rad(6.0))
			draw_rect(Rect2(-24, -9, S.tw(S.noto(), stt, 11) + 16.0, 18), Color.BLACK)
			draw_string(S.noto(), Vector2(-16, 4), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
			draw_set_transform(Vector2.ZERO)
		if in_g:
			var stt := "선배" if p.get("sr", false) else "길드원"
			draw_set_transform(Vector2(cx + cw - 30.0, cy + 14.0), deg_to_rad(6.0))
			draw_rect(Rect2(-24, -9, S.tw(S.noto(), stt, 11) + 16.0, 18), col())
			draw_string(S.noto(), Vector2(-16, 4), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
			draw_set_transform(Vector2.ZERO)
		# label
		var ly := cy + ch - 52.0
		if ly + 52.0 <= cr.end.y + 8.0 and ly >= cr.position.y - 10.0:
			for k in 6:
				draw_rect(Rect2(cx, ly + k * 3.0, cw, 3.0), Color(0, 0, 0, 0.92 * k / 6.0))
			draw_rect(Rect2(cx, ly + 18.0, cw, 34.0), Color(0, 0, 0, 0.92))
			var nm: String = p["n"] if (in_g or not (p.has("c") or p.get("b", false))) else "???"
			var role: String = p["role"] if in_g else ("첫 의뢰를 마치면 에일린이 소개해 준다" if (p.has("c") or p.get("b", false)) else "%s · %s" % [p["role"], p["hint"]])
			draw_string(S.bhs(), Vector2(cx + 10.0, ly + 24.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
			draw_multiline_string(S.noto(), Vector2(cx + 10.0, ly + 40.0), role, HORIZONTAL_ALIGNMENT_LEFT, cw - 16.0, 11, 2, Color(0.81, 0.78, 0.85))

func _dun_list(lc: Rect2) -> void:
	var y := lc.position.y + 4.0
	for i in FD.DUNGEONS.size():
		var d: Dictionary = FD.DUNGEONS[i]
		var on := i == dun_i
		var lk: bool = not d["ok"] or FD.DUNRANK.get(d["id"], 1) > fame.r
		var r := Rect2(lc.position.x + (6.0 if on else 0.0), y, lc.size.x - 8.0, 46.0)
		draw_colored_polygon(S.clip(r, [[2, 0], [100, 0], [98, 100], [0, 100]]), Color.WHITE if on else Color(0.086, 0.075, 0.106, 0.9))
		var nm: String = d["name"] if d["ok"] else "???"
		draw_string(S.bhs(), r.position + Vector2(12, 21), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK if on else Color.WHITE)
		if lk: S.lock(self, r.position + Vector2(16 + S.tw(S.bhs(), nm, 16), 8), 12.0, Color.BLACK if on else Color(0.7, 0.7, 0.7))
		var sub: String = ("%s · 권장 Lv %d–%d" % [d["lv"], d["rec"][0], d["rec"][1]]) if d["ok"] else "미정"
		draw_string(S.noto(), r.position + Vector2(12, 38), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.75) if on else Color(1, 1, 1, 0.72))
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
		draw_multiline_string(S.noto(), cr.position + Vector2(0, 20), "아직 아무것도 알려지지 않은 곳.\n이야기가 이어지면 길이 열린다.", HORIZONTAL_ALIGNMENT_LEFT, cr.size.x, 13, -1, INK2)
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
		draw_rect(Rect2(cr.position.x + dx, y, cr.size.x, h), Color(1, 1, 1, 0.5))
		draw_string(S.noto(), Vector2(cr.position.x + dx + 10.0, y + 17.0), R[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK3)
		var txt: String = R[1]
		if i == 3:
			# gems in their colours
			var x := cr.position.x + dx + 112.0
			for g in grades:
				draw_set_transform(Vector2(x + 5.0, y + 13.0), PI / 4.0)
				draw_rect(Rect2(-4, -4, 8, 8), FD.GRADE[g][1])
				draw_set_transform(Vector2.ZERO)
				draw_string(S.noto(), Vector2(x + 14.0, y + 17.0), FD.GRADE[g][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
				x += 20.0 + S.tw(S.noto(), FD.GRADE[g][0], 12)
			var rest := "· 보스 상자 대박 "
			draw_string(S.noto(), Vector2(x, y + 17.0), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
			x += S.tw(S.noto(), rest, 12)
			draw_set_transform(Vector2(x + 5.0, y + 13.0), PI / 4.0)
			draw_rect(Rect2(-4, -4, 8, 8), FD.GRADE[D["bonus"]][1])
			draw_set_transform(Vector2.ZERO)
			draw_string(S.noto(), Vector2(x + 14.0, y + 17.0), FD.GRADE[D["bonus"]][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)
		else:
			draw_multiline_string(S.noto(), Vector2(cr.position.x + dx + 112.0, y + 17.0), txt, HORIZONTAL_ALIGNMENT_LEFT, vw, 12, -1, INK)
		y += h + 4.0
	y += 8.0
	if ok:
		var lbl := "출격하러 가기" if arena.level_kind() == "town" else "출격 마차에서 출발"
		var bw := S.tw(S.bhs(), lbl, 15) + 40.0
		var br := Rect2(cr.position.x, y, bw, 32.0)
		draw_colored_polygon(S.clip(br, [[7, 0], [100, 0], [93, 100], [0, 100]]), col())
		draw_string(S.bhs(), br.position + Vector2(20, 22), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)
		_hit(br, func():
			menu.close_page()
			fame.notice("출격 마차로 · 마을 동쪽 끝", "던전", col()))   # PLACEHOLDER: the sortie (dungeon select) is agent C's
	else:
		S.lock(self, Vector2(cr.position.x, y + 4.0), 13.0, INK3)
		draw_string(S.noto(), Vector2(cr.position.x + 18.0, y + 16.0), "명성 %d등급이 되면 열린다." % rk, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK2)

func _p_rune(cr: Rect2) -> void:
	# PLACEHOLDER: the rune codex lives with the runes (agent B); this tab only says where it will be
	draw_string(S.bhs(), cr.position + Vector2(0, 24), "룬 도감", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	draw_multiline_string(S.noto(), cr.position + Vector2(0, 52), "룬이 길드에 들어오면 이 장이 채워진다.\n발견한 룬 %d종" % fame.seen.size(), HORIZONTAL_ALIGNMENT_LEFT, cr.size.x, 13, -1, INK2)


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
		draw_colored_polygon(S.clip(Rect2(br.position + Vector2(3, 3), br.size), [[7, 0], [100, 0], [93, 100], [0, 100]]), Color.BLACK)
		draw_colored_polygon(S.clip(br, [[7, 0], [100, 0], [93, 100], [0, 100]]), Color("#ffd34d").lightened(0.15 * (0.5 + 0.5 * sin(t / 240.0))))
		draw_string(S.bhs(), br.position + Vector2(14, 18), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
		_hit(br, func():
			for i in fame.lv_can(): fame.lv_claim(i)
			arena.sfx("heavy", 0.5))
	else:
		var nt := "끌어서 넘기기 · 휠로 넘기기"
		draw_string(S.noto(), Vector2(cr.end.x - S.tw(S.noto(), nt, 11), cr.position.y + 15.0), nt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, INK3)
	# the road: one card per level, scrolled sideways (wheel / drag); opens at the current level
	if not scroll.has("lv"): scroll["lv"] = clampf(maxi(0, L - 3) * 128.0, 0.0, maxf(0.0, (FD.AMAX - 1) * 128.0 - (paper_r.size.x - 60.0)))
	var sx: float = scroll["lv"]
	var y0 := cr.position.y + 40.0
	var hh := cr.size.y - 50.0
	var x := cr.position.x - sx
	for i in range(2, FD.AMAX + 1):
		var cw := 118.0
		if x >= cr.position.x - 2.0 and x + cw <= cr.end.x + 4.0:
			var R := FD.a_reward(i)
			var gotit: bool = fame.lvc.has(str(i))
			var can := i <= L and not gotit
			var nxt := i == L + 1
			var r := Rect2(x, y0 + (0.0 if i % 2 else 10.0), cw, hh - 14.0)
			var bg := Color(1, 1, 1, 0.65) if can else (Color(1, 1, 1, 0.35) if gotit else Color(0, 0, 0, 0.05))
			draw_colored_polygon(S.clip(r, [[0, 0], [100, 0], [96, 100], [3, 97]]), bg)
			if i == L: draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color("#7fd0ff"))
			if can: draw_rect(Rect2(r.position, Vector2(4, r.size.y)), Color("#7fd0ff"))
			var a := 0.5 if gotit else 1.0
			draw_string(S.anton(true), r.position + Vector2(10, 44), str(i), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(INK if (can or nxt or i == L) else INK3, a))
			var stt := "받음" if gotit else ("받을 수 있음" if can else ("다음 레벨" if nxt else ("지금" if i == L else "")))
			draw_string(S.noto(), r.position + Vector2(12, 62), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Color("#2f6d94"), a))
			var ry := r.position.y + 88.0
			for line in FD.rw_txt(R).split(" · "):
				draw_string(S.noto(), Vector2(r.position.x + 12.0, ry), line, HORIZONTAL_ALIGNMENT_LEFT, cw - 18.0, 12, Color(INK, a))
				ry += 18.0
			if gotit:
				draw_set_transform(r.get_center() + Vector2(0, 30), deg_to_rad(-12.0))
				draw_rect(Rect2(-26, -13, 52, 26), Color(0.84, 0.16, 0.21, 0.7), false, 2.0)
				draw_string(S.bhs(), Vector2(-17, 7), "수령", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.84, 0.16, 0.21, 0.75))
				draw_set_transform(Vector2.ZERO)
			if can:
				var br := Rect2(r.position.x + 12.0, r.end.y - 36.0, 62.0, 24.0)
				draw_colored_polygon(S.clip(br, [[7, 0], [100, 0], [93, 100], [0, 100]]), Color("#ffd34d"))
				draw_string(S.bhs(), br.position + Vector2(17, 17), "받기", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK)
				var ii := i
				_hit(br.grow(4), func():
					fame.lv_claim(ii)
					arena.sfx("heavy", 0.5))
		x += 128.0
	# the marker under the road
	var f := clampf(sx / maxf(1.0, (FD.AMAX - 1) * 128.0 - (paper_r.size.x - 60.0)), 0.0, 1.0)
	draw_rect(Rect2(cr.position.x, cr.end.y - 4.0, cr.size.x, 2.0), Color(0, 0, 0, 0.12))
	draw_rect(Rect2(cr.position.x + (cr.size.x - 60.0) * f, cr.end.y - 6.0, 60.0, 6.0), Color("#2f6d94"))

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
		draw_colored_polygon(S.clip(r, [[2, 0], [100, 0], [98, 100], [0, 100]]), Color.WHITE if on else Color(0.086, 0.075, 0.106, 0.88))
		var ink := Color.BLACK if on else Color.WHITE
		draw_string(S.noto(), r.position + Vector2(12, 17), "제%d장" % (j + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(ink, 0.7))
		var nm: String = X["n"]
		var nfs := S.fit_size(S.bhs(), nm, 15, r.size.x - 70.0)
		draw_string(S.bhs(), r.position + Vector2(12, 38), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, ink)
		if not op: S.lock(self, r.position + Vector2(16 + S.tw(S.bhs(), nm, nfs), 26), 11.0, Color(ink, 0.7))
		var pr := "%d/%d" % [nd, X["t"].size()]
		draw_string(S.anton(), Vector2(r.end.x - 12.0 - S.tw(S.anton(), pr, 14), r.position.y + 30.0), pr, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
		if dot: draw_circle(Vector2(r.end.x - 6.0, r.position.y + 6.0), 5.0, Color("#ff3d5a"))
		if fame.chc.has(X["id"]): draw_rect(Rect2(r.position.x, r.end.y - 3.0, r.size.x, 3.0), Color("#7fd0ff"))
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
	draw_string(S.noto(), cr.position + Vector2(0, 12), "제%d장" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#2f6d94"))
	draw_string(S.bhs(), cr.position + Vector2(0, 38), C["n"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	var sub: String = C["d"] + ("" if op else " · 앞 장을 마치면 열린다 (진행도는 미리 쌓인다)")
	draw_string(S.noto(), cr.position + Vector2(0, 58), sub, HORIZONTAL_ALIGNMENT_LEFT, cr.size.x, 12, INK2)

func _day_col(lc: Rect2) -> void:
	var y := _hero(lc, false)
	var D: Dictionary = fame.d_day()
	var lk: bool = fame.alv < FD.DAYLV
	var fa := Color("#7fd0ff")
	var pt := int(D["pt"])
	draw_string(S.anton(true), Vector2(lc.position.x + 6.0, y + 46.0), str(pt), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, fa)
	var nx := lc.position.x + 16.0 + S.tw(S.anton(true), str(pt), 48)
	draw_string(S.anton(false, 1), Vector2(nx, y + 22.0), "ACTIVITY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.73, 0.73, 0.73))
	draw_string(S.bhs(), Vector2(nx, y + 44.0), "오늘의 활동도", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	var gr := Rect2(lc.position.x + 6.0, y + 56.0, lc.size.x - 20.0, 10.0)
	S.para(self, gr, -3.0, Color("#2a2630"))
	S.para(self, Rect2(gr.position, Vector2(gr.size.x * minf(1.0, pt / 500.0), gr.size.y)), -3.0, fa)
	var bw := (lc.size.x - 14.0) / 5.0
	for i in FD.DMS.size():
		var M: Dictionary = FD.DMS[i]
		var gotit: bool = D["ms"].has(str(i))
		var can: bool = not lk and not gotit and pt >= M["p"]
		var r := Rect2(lc.position.x + 6.0 + i * bw, y + 74.0, bw - 4.0, 64.0)
		var wob := sin(t / 1300.0 * TAU * 2.0) * 0.06 if can else 0.0
		draw_set_transform(r.get_center(), wob)
		var lr := Rect2(-r.size / 2.0, r.size)
		draw_rect(lr, fa if can else (Color("#2a2630") if not gotit else Color("#1a1620")))
		var ink := Color.BLACK if can else Color.WHITE
		draw_string(S.anton(), lr.position + Vector2(5, 16), str(M["p"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
		var R: Dictionary = fame.d_ms_rw(i)
		var ry := lr.position.y + 32.0
		if gotit:
			draw_string(S.noto(), Vector2(lr.position.x + 5.0, ry), "받음", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.6))
		else:
			for line in FD.rw_txt(R).split(" · "):
				draw_string(S.noto(), Vector2(lr.position.x + 4.0, ry), line, HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 6.0, 9, Color(ink, 0.85))
				ry += 12.0
		draw_set_transform(Vector2.ZERO)
		if can:
			var ii := i
			_hit(r, func():
				fame.d_ms(ii)
				arena.sfx("heavy", 0.5))
	var note := "날짜가 바뀌면 새 과제가 붙는다." + ("\n로비 샹들리에 · 실링 +20%" if fame.fac_ok("chand") else "")
	draw_multiline_string(S.noto(), Vector2(lc.position.x + 6.0, y + 156.0), note, HORIZONTAL_ALIGNMENT_LEFT, lc.size.x - 10.0, 11, -1, Color(0.73, 0.73, 0.73))

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
