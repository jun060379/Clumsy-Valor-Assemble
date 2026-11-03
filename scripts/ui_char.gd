extends "res://scripts/ui_page.gd"
## 캐릭터 (prototype CHARACTER SCREEN v2, cx v2): tabs 상세 · 장비 · 스킬 · 기억 · 기록 · 의상 along the top, the member's faces
## top right. 상세 = the numbers with gear on (+ what gear adds), the passive; 장비 = seven blades (WEAPON … ACC 3), the picked
## piece as a card (stats, its rune), 교체 = what in the bag fits, with a stat diff, and 해제.
## 스킬 · 기억 · 기록 are drawn by ui_char_mem.gd (mx): the moves, the memory tree and levels (memory.gd), the record and memorial.
## 의상 is drawn by ui_char_wear.gd (wr): the member's costumes (skins.gd), quick switching. All member art goes through skins.gd.

const MEMUI := preload("res://scripts/ui_char_mem.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const SK := preload("res://scripts/skins.gd")       # every member picture comes through the worn costume (skins.gd)
const WEAR := preload("res://scripts/ui_char_wear.gd")
const TABS := [["attr", "상세", "STATUS"], ["gear", "장비", "GEAR"], ["skill", "스킬", "SKILL"], ["match", "기억", "MEMORY"], ["rec", "기록", "RECORD"], ["wear", "의상", "COSTUME"]]
const GSL := [["weapon", "WEAPON"], ["head", "HEAD"], ["body", "BODY"], ["shoe", "SHOES"], ["acc1", "ACC 1"], ["acc2", "ACC 2"], ["acc3", "ACC 3"]]
const SHEET := {"estelle": ["에스텔 벨라시타", "전사", ["수호자", "받는 피해 25% 감소."]],
	"aida": ["스나가와 아이다", "워락", ["그림자 걸음", "적의 등 뒤에서 때리면 피해 2배 (뒷치기)."]],
	"luce": ["루체 루멘", "사제", ["축복", "루체가 파티에 있으면 대기 중인 동료가 초당 체력 2씩 회복한다."]]}

var c := "estelle"
var tab := "attr"
var gi := 0
var picking := false
var slam_t := 0.0
var tab_t := 0.0
var mx                           # ui_char_mem.gd: the 스킬 · 기억 · 기록 tabs
var wr                           # ui_char_wear.gd: the 의상 tab
# ---- motion (status.js cx v2: .wipe, cx_mn / cx_cd, cx_slam, cx_drop, cx_flash, .menu / .cur transitions, .nm and the
# per-tab ground gliding .7s --mv, cx_xgear, cx_flb, cx_gdpop) ----
var trn := UIA.Tr.new()
var name_t := 0.0                # cx_drop clock (letters fall in on open and on a member change)
var flash_t := 1e9               # cx_flash: the white slash across on a tab change
var wipe_t := -1.0               # .wipe: black with a col2 edge; -1 = none
var wipe_kind := ""              # open: leaves from -8 % / member: comes in, the member changes under it, leaves
var pend_c := ""
var prev_tab := ""
var gi_t := 1e9                  # cx_flb on the picked blade
var gd_t := 1e9                  # cx_gdpop on the gear card
var open_t := 0.0
# ---- presence on 상세 (react / sblink / --px --py): a tap smiles (♪, hop), three quick taps surprise (!!, shake);
# the art blinks while it rests on its base face; the ground's dots follow the pointer
const HXY := {"estelle": Vector2(0.58, 0.20), "aida": Vector2(0.58, 0.21), "luce": Vector2(0.58, 0.24)}
var react := ""                  # "" / "smile" / "sup"
var react_t := 0.0               # ms left on that face
var taps: Array = []             # tap times (ms) in the last 1.3 s
var jolt := ""                   # "hop" / "shake"
var jolt_t := 1e9
var blk := 0.0                   # ms left of a blink (the cl face)
var blk_next := 2400.0
var blk2 := 0.0


func _ready() -> void:
	super()
	keys = ["char"]
	mx = MEMUI.new(self)
	wr = WEAR.new(self)

var want_c := ""                 # cxOpen(c): open on this member instead of the one in control
var stat_scroll := 0.0           # 상세: #cx .stats scrolls (overflow auto) down to the 패시브 and 상성 cards
var stat_max := 0.0
const EL := preload("res://scripts/elements.gd")

func _opened() -> void:
	stat_scroll = 0.0
	c = want_c if want_c != "" else arena.player.who
	want_c = ""
	tab = "attr"
	gi = 0
	picking = false
	slam_t = 0.0
	tab_t = 0.0
	open_t = 0.0
	name_t = 0.0
	flash_t = 1e9
	wipe_t = 0.0
	wipe_kind = "open"
	pend_c = ""
	prev_tab = ""
	gi_t = 1e9
	gd_t = 1e9
	react = ""
	react_t = 0.0
	taps.clear()
	jolt_t = 1e9
	trn.clear()
	mx.opened()
	wr.reset()

func _tick(dt: float) -> void:
	slam_t += dt
	tab_t += dt
	open_t += dt
	name_t += dt
	flash_t += dt
	gi_t += dt
	gd_t += dt
	jolt_t += dt
	if react_t > 0.0:
		react_t -= dt
		if react_t <= 0.0: react = ""
	_sblink(dt)
	trn.step(dt)
	if wipe_t >= 0.0:
		wipe_t += dt
		if wipe_kind == "member" and pend_c != "" and wipe_t >= 190.0:
			c = pend_c
			pend_c = ""
			slam_t = 0.0
			name_t = 0.0
			picking = false
			react = ""
			react_t = 0.0
			mx.member_changed()
			wr.reset()
		if wipe_t >= (540.0 if wipe_kind == "open" else 490.0): wipe_t = -1.0
	mx.tick(dt)
	wr.tick(dt)

func _key(k: int) -> void:
	if tab in ["skill", "match", "rec"] and mx.key(k): return
	if tab == "wear" and wr.key(k): return
	if k == KEY_ESCAPE:
		if picking: picking = false
		else: back()
	elif k in [KEY_LEFT, KEY_RIGHT, KEY_Q, KEY_E]:
		var i := 0
		for j in TABS.size(): if TABS[j][0] == tab: i = j
		_tab(TABS[(i + (TABS.size() - 1 if k in [KEY_LEFT, KEY_Q] else 1)) % TABS.size()][0])
	elif tab == "attr" and k in [KEY_UP, KEY_DOWN]:
		stat_scroll = clampf(stat_scroll + (-40.0 if k == KEY_UP else 40.0), 0.0, stat_max)
	elif tab == "gear" and k in [KEY_UP, KEY_DOWN]:
		_pick_gi(clampi(gi + (-1 if k == KEY_UP else 1), 0, GSL.size() - 1))
	elif tab == "gear" and k in [KEY_ENTER, KEY_SPACE]:
		picking = not picking
		gd_t = 0.0

## a blade picked: it flashes (cx_flb) and the card pops (cx_gdpop)
func _pick_gi(i: int) -> void:
	if i == gi and gi_t < 1e8: return
	gi = i
	picking = false
	gi_t = 0.0
	gd_t = 0.0

func _tab(k: String) -> void:
	stat_scroll = 0.0
	if k == tab: return
	prev_tab = tab
	tab = k
	tab_t = 0.0
	flash_t = 0.0
	picking = false
	react = ""
	react_t = 0.0
	mx.tab_changed()
	if k == "wear": wr.reset()
	sfx("ui_move", 0.5)

func _member(cc: String) -> void:
	stat_scroll = 0.0
	if cc == c or wipe_t >= 0.0: return
	# setChar: the wipe comes in (190 ms), the member changes under it, the wipe goes on out (300 ms)
	pend_c = cc
	wipe_t = 0.0
	wipe_kind = "member"
	sfx("ui_move", 0.5)

## ROSTER (cxOpen's .chars): the members who have joined, in the prototype's order
func roster() -> Array:
	return arena.player.roster()

func _paint(vs: Vector2) -> void:
	var col := UI.col(c)
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	if tab == "gear": _gear(vs, col)
	elif tab == "attr": _attr(vs, col)
	elif tab == "wear":
		wr.paint(vs, col)
		if prev_tab == "attr" and tab_t < 350.0: _attr_art(vs, tab_t)
	else:
		mx.paint(vs, col)
		if mx.clean: return          # 감상: only the memorial art and its ✕
		if prev_tab == "attr" and tab_t < 350.0: _attr_art(vs, tab_t)
	_tabs(vs, col)
	_faces(vs)
	close_x(vs, func():
		if picking: picking = false
		else: back())
	_flash(vs)
	_wipe(vs)

## .chars: the roster's faces top right (cx_cd on open; .on turns and grows .3s --bk)
func _faces(vs: Vector2) -> void:
	var L := roster()
	var fx := vs.x - 60.0 - L.size() * 50.0
	for i in L.size():
		var cc: String = L[i]
		var on: bool = cc == c
		var r := Rect2(fx, 12, 44, 44)
		var rot: float = trn.get_v("fr%d" % i, -8.0 if on else (5.0 if i == 1 else -6.0), 300.0, "bk")
		var sc: float = trn.get_v("fs%d" % i, 1.1 if on else 0.84, 300.0, "bk")
		var u := UIA.p(open_t, 300.0 + i * 60.0, 500.0, "bk")
		var a := clampf((open_t - 300.0 - i * 60.0) / 150.0, 0.0, 1.0)
		if a > 0.0:
			draw_set_transform_matrix(Transform2D(0.0, Vector2(0, -60.0 * (1.0 - u))) * Transform2D(deg_to_rad(rot + 30.0 * (1.0 - u)), Vector2(sc, sc), 0.0, r.get_center()))
			var lr := Rect2(-22, -22, 44, 44)
			if on: draw_rect(Rect2(lr.position + Vector2(5, 5), lr.size), Color(1, 1, 1, a))
			draw_rect(lr, Color(Color.BLACK if on else Color.WHITE, a))
			var g := 1.0 if on else 0.45
			draw_texture_rect(SK.face(cc), lr.grow(-3), false, Color(g, g, g, a))
			draw_set_transform(Vector2.ZERO)
		var c2: String = cc
		hit(r, func(): _member(c2))
		fx += 50.0

## cx_flash: a white slash sweeps across the screen as a tab opens
func _flash(vs: Vector2) -> void:
	if flash_t > 380.0: return
	var u := UIA.p(flash_t, 0.0, 380.0, "mv")
	var r := Rect2(-0.2 * vs.x, vs.y * 0.5, vs.x * 1.4, 26.0)
	var m := UIA.xf(r.get_center(), Vector2(lerpf(-1.2, 1.2, u) * r.size.x, 0), deg_to_rad(-12.0))
	draw_colored_polygon(m * UI.clip(r, [[0, 45], [100, 0], [100, 25], [0, 100]]), Color.WHITE)

## .wipe (inset -10% -30%): black with a col2 lightning edge; open: leaves from -8 % to -140 % (480 ms after 60);
## member: comes in from 130 % (190 ms), then leaves (300 ms)
func _wipe(vs: Vector2) -> void:
	if wipe_t < 0.0: return
	var x := 0.0
	if wipe_kind == "open":
		x = lerpf(-0.08, -1.4, UIA.p(wipe_t, 60.0, 480.0, [0.2, 0.7, 0.3, 1.0]))
	elif wipe_t < 190.0:
		x = lerpf(1.3, -0.08, UIA.p(wipe_t, 0.0, 190.0, [0.6, 0.0, 0.9, 0.5]))
	else:
		x = lerpf(-0.08, -1.4, UIA.p(wipe_t, 190.0, 300.0, [0.2, 0.7, 0.3, 1.0]))
	var r := Rect2(-0.3 * vs.x, -0.1 * vs.y, vs.x * 1.6, vs.y * 1.2)
	r.position.x += x * r.size.x
	draw_colored_polygon(UI.clip(r, [[18, 0], [100, 0], [100, 100], [0, 100], [10, 62], [4, 58]]), Color.BLACK)
	draw_colored_polygon(UI.clip(r, [[14, 0], [18, 0], [4, 58], [10, 62], [0, 100], [-4, 100], [6, 64], [0, 60]]), UI.col2(c))

## .menu: left 14, top 22, turned −3°; BHS 20 with a 5 px black stroke, the English line over it; the even ones sit lower and
## lean the other way; the chosen one is black and 1.3× on the white cursor, the colour cursor lagging under it (.36s --bk);
## on open each drops in (cx_mn, 55 ms apart after 200)
func _tabs(vs: Vector2, col: Color) -> void:
	var base := Transform2D(deg_to_rad(-3.0), Vector2(14, 22 + 40))
	var x := 0.0
	var fs := 20
	var R: Array = []
	for tb in TABS:
		var w := tw(UI.bhs(), tb[1], fs) + 10.0
		R.append([x, w])
		x += w + 14.0
	var oi := 0
	for i in TABS.size(): if TABS[i][0] == tab: oi = i
	var ob: Array = R[oi]
	var cw: float = ob[1] * 1.3 + 20.0
	for k in [["c2", col, 3.0, [[0, 30], [100, 10], [94, 100], [6, 86]], 50.0], ["c1", Color.WHITE, -4.0, [[4, 18], [96, 0], [100, 72], [8, 100]], 0.0]]:
		var cx: float = trn.get_v(k[0] + "x", ob[0] - ob[1] * 0.15 - 10.0, 360.0, "bk")
		var ww: float = trn.get_v(k[0] + "w", cw, 300.0, "ease")
		var ua := clampf((open_t - 200.0 - oi * 55.0) / 200.0, 0.0, 1.0)
		draw_set_transform_matrix(base * Transform2D(deg_to_rad(k[2]), Vector2(cx, -36.0)))
		draw_colored_polygon(UI.clip(Rect2(0, 0, ww, 40), k[3]), Color(k[1], ua))
	for i in TABS.size():
		var tb: Array = TABS[i]
		var on: bool = i == oi
		var w: float = R[i][1]
		var bx: float = R[i][0]
		var sc: float = trn.get_v("ts%d" % i, 1.3 if on else 1.0, 320.0, "bk")
		var rot: float = trn.get_v("tr%d" % i, -3.0 if on else (3.0 if i % 2 == 1 else 0.0), 320.0, "bk")
		var dy: float = trn.get_v("ty%d" % i, 0.0 if on else (5.0 if i % 2 == 1 else 0.0), 320.0, "bk")
		var ink: float = trn.get_v("tc%d" % i, 1.0 if on else 0.0, 200.0, "ease")
		var u := UIA.p(open_t, 200.0 + i * 55.0, 500.0, "bk")
		var a := clampf((open_t - 200.0 - i * 55.0) / 150.0, 0.0, 1.0)
		if a <= 0.0: continue
		var piv := Vector2(bx + w / 2.0, 0)
		var m := base * Transform2D(0.0, Vector2(0, -40.0 * (1.0 - u) + dy)) * UIA.xf(piv, Vector2.ZERO, deg_to_rad(rot - 20.0 * (1.0 - u)), Vector2(sc, sc))
		draw_set_transform_matrix(m)
		var en: String = tb[2]
		var ef := UI.spaced(UI.anton(), 2)
		draw_string(ef, Vector2(bx + w / 2.0 - tw(ef, en, 9) / 2.0, -fs - 2.0), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0, 0, 0, 0.6 * a).lerp(Color(col, a), ink))
		if ink < 1.0: draw_string_outline(UI.bhs(), Vector2(bx + 2, -2), tb[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, a * (1.0 - ink)))
		draw_string(UI.bhs(), Vector2(bx + 2, -2), tb[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0 - ink, 1.0 - ink, 1.0 - ink, a))
		var k2: String = tb[0]
		hit(PackedVector2Array([m * Vector2(bx - 4, -fs - 14), m * Vector2(bx + w + 4, -fs - 14), m * Vector2(bx + w + 4, 8), m * Vector2(bx - 4, 8)]), func(): _tab(k2))
	draw_set_transform(Vector2.ZERO)

## the name in loose stamped letters, and the role under it
func _name(at0: Vector2) -> void:
	# .nm glides to its place for the tab (.75s --mv); the letters drop in (cx_drop, 35 ms apart)
	var at: Vector2 = trn.get_v("nm", at0, 750.0, "mv")
	var nm: String = SHEET[c][0]
	var seed := 0
	for ch in c: seed += ch.unicode_at(0)
	var rs := seed
	var rnd := func() -> float:
		rs = (rs * 16807) % 2147483647
		return float(rs) / 2147483647.0
	var styles := [[Color.BLACK, Color.WHITE], [Color.WHITE, Color.BLACK], [UI.col(c), Color.BLACK], [Color.BLACK, UI.col(c)]]
	var x := at.x
	for i in nm.length():
		var ch := nm.substr(i, 1)
		if ch == " ":
			x += 10.0
			continue
		var s: Array = styles[int(rnd.call() * 4.0)]
		var r: float = rnd.call() * 16.0 - 8.0
		var sz := 20 + int(rnd.call() * 8.0)
		var dy: float = rnd.call() * 8.0 - 4.0
		var w := tw(UI.bhs(), ch, sz) + 8.0
		var u := UIA.p(name_t, i * 35.0, 500.0, "bk")
		var la := clampf((name_t - i * 35.0) / 150.0, 0.0, 1.0)
		if la > 0.0:
			var pc := Vector2(x + w / 2.0, at.y + dy - sz / 2.0)
			draw_set_transform_matrix(UIA.xf(pc, Vector2(0, -40.0 * (1.0 - u)), deg_to_rad(lerpf(-3.0 * r, r, u)), Vector2.ONE * lerpf(1.6, 1.0, u)) * Transform2D(0.0, Vector2(x, at.y + dy)))
			draw_rect(Rect2(3, -sz + 3, w, sz + 6.0), Color(0, 0, 0, la))
			draw_rect(Rect2(0, -sz, w, sz + 6.0), Color(s[0], la))
			draw_string(UI.bhs(), Vector2(4, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(s[1], la))
			draw_set_transform(Vector2.ZERO)
		x += w + 3.0
	var role: String = SHEET[c][1] + (" · 조작 중" if c == arena.player.who else (" · 파티" if arena.player.party.has(c) else " · 마을"))
	draw_set_transform(at + Vector2(0, 30), deg_to_rad(-4.0))
	UI.para(self, 0, -14, tw(UI.noto_k(), role, 12) + 20.0, 22, 4.0, Color.BLACK)
	draw_string(UI.noto_k(), Vector2(10, 2), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_set_transform(Vector2.ZERO)

## the standing art: cx_slam on open and on a member change (from 40 % right, turned −14°, 1.15×, black until 45 %, lit by
## 60 %, .62s --bk), then breathing (cx_breath 4.2 s); xgear on the gear tab (from (8 %, 45 %), 14°, 1.15×, black to 40 %,
## 1.6× bright at 55 %, .7s --bk, settling at 3°)
func _art(vs: Vector2, p: String, r: Rect2, kind := "slam", out := 0.0) -> void:
	var tt := tx(p)
	var T := minf(slam_t, tab_t) if kind == "gear" else slam_t
	var br := 0.5 - 0.5 * cos(t / (4600.0 if kind == "gear" else 4200.0) * TAU)
	var tr := Vector2.ZERO
	var rot := 0.0
	var sc := 1.0 + 0.006 * br
	var lit := 1.0
	var a := 1.0
	if kind == "gear":
		var u := UIA.p(T, 0.0, 700.0, "bk")
		tr = Vector2(0.08 * r.size.x, 0.45 * r.size.y) * (1.0 - u)
		rot = lerpf(14.0, 3.0, u)
		sc *= lerpf(1.15, 1.0, u)
		lit = UIA.kf(T, [[0.0, 0.0], [0.4, 0.0], [0.55, 1.6], [1.0, 1.0]], 700.0)
	else:
		var u := UIA.p(T, 0.0, 620.0, "bk")
		tr = Vector2(0.4 * r.size.x, 0) * (1.0 - u)
		rot = -14.0 * (1.0 - u)
		sc *= lerpf(1.15, 1.0, u)
		lit = UIA.kf(T, [[0.0, 0.0], [0.45, 0.0], [0.6, 1.0], [1.0, 1.0]], 620.0)
		a = clampf(T / 620.0 / 0.3, 0.0, 1.0)
	if out > 0.0:
		# leaving 상세: opacity .2s, translateX(−30 %) rotate(−10°) scale(.95) .35s --mv
		var v := UIA.p(out, 0.0, 350.0, "mv")
		tr = Vector2(-0.3 * r.size.x * v, 0)
		rot = -10.0 * v
		sc = lerpf(1.0, 0.95, v)
		a = 1.0 - clampf(out / 200.0, 0.0, 1.0)
		lit = 1.0
	tr.y -= 6.0 * br
	if kind == "slam" and out <= 0.0:
		var J := _jolt()
		tr += J[0]
		rot += J[1]
	draw_set_transform(Vector2(r.get_center().x, r.end.y) + tr, deg_to_rad(rot), Vector2(sc, sc))
	var lr := Rect2(-r.size.x / 2.0, -r.size.y, r.size.x, r.size.y)
	var k := minf(lit, 1.0)
	draw_texture_rect(tt, lr, false, Color(k, k, k, a))
	if lit > 1.0:
		draw_texture_rect(tt, lr, false, Color(1, 1, 1, a * (lit - 1.0) * 0.6))
	draw_set_transform(Vector2.ZERO)

func _attr(vs: Vector2, col: Color) -> void:
	# the attr ground (#cx[data-tab=attr]: the black shard on the left, its col2 edge, the slash, ESTELLE low right)
	mx.ground(vs, col, "attr")
	_attr_art(vs, 0.0)
	_name(Vector2(vs.x * 0.54, vs.y * 0.2))
	# the rows
	var S: Dictionary = R().stats(c)
	var T: Dictionary = R().gear_tot(c)
	var P = arena.player
	var hp: float = P.hp if c == P.who else P.hpm.get(c, S["hp"])
	var rows: Array = [["체력", str(int(S["hp"])), S["hp"] - S["base_hp"], ""], ["공격력", str(roundi(10.0 * S["atk"])), roundi(10.0 * S["atk"]) - roundi(10.0 * S["base_atk"]), ""],
		["방어", RN.fmt(T["def"]), T["def"], ""], ["치명", RN.fmt(T["crit"]) + "%", T["crit"], "%"], ["이동 속도", str(roundi(S["ms"] * 100.0)) + "%", roundi(S["ms"] * 100.0) - roundi(S["base_ms"] * 100.0), "%"],
		["공격 속도", str(roundi(S["as"] * 100.0)) + "%", 0, "%"]]
	if c == "luce" or T["heal"] > 0.0: rows.append(["회복량", RN.fmt(100.0 + T["heal"]) + "%", T["heal"], "%"])
	if T["ult"] > 0.0: rows.append(["기력 획득", RN.fmt(100.0 + T["ult"]) + "%", T["ult"], "%"])
	# .zone (53 %, 37 %) 396 × 310: .stats scrolls (overflow auto), -3°; under the rows the 패시브 card and the 상성 card
	var top := vs.y * 0.37
	var y := vs.y * 0.38 - stat_scroll
	var rh := 30.0
	var i := 0
	for row in [["현재 체력", str(roundi(hp)), 0, "", hp / maxf(1.0, S["hp"])]] + rows:
		var e := UI.bk(clampf((tab_t - i * 40.0) / 500.0, 0.0, 1.0))
		var x := vs.x * 0.53 + (i % 2) * 14.0 + 60.0 * (1.0 - e) - i * 4.0
		var bw := vs.x * 0.42
		if y >= top - 2.0:
			draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + bw, y - 4.0), Vector2(x + bw - 6.0, y + rh - 4.0), Vector2(x - 4.0, y + rh)]), Color(0, 0, 0, 0.92 * e))
			draw_string(UI.noto_k(), Vector2(x + 12, y + rh * 0.68), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, e))
			if row.size() > 4:
				draw_rect(Rect2(x + 90, y + rh * 0.42, bw * 0.38, 4), Color(1, 1, 1, 0.2 * e))
				draw_rect(Rect2(x + 90, y + rh * 0.42, bw * 0.38 * clampf(row[4], 0.0, 1.0), 4), Color(col.lightened(0.3), e))
			draw_string(UI.anton(true), Vector2(x + bw * 0.62, y + rh * 0.78), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(rh * 0.72), Color(1, 1, 1, e))
			var d: float = row[2]
			var ds: String = ("/ %d" % roundi(S["hp"])) if i == 0 else (("+" if d > 0 else "−") + RN.fmt(absf(d)) + row[3] if d != 0.0 else "")
			draw_string(UI.anton(true), Vector2(x + bw * 0.86, y + rh * 0.55), ds, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col.lightened(0.2), e))
		y += rh + 2.0
		i += 1
	# .card.it (패시브): 150 wide, black, the tag white on black, its text black (as the prototype's cascade leaves it);
	# .card.aff.it (상성): black, the tags in her colour, the lines #ddd at 11.5 px
	var pv: Array = SHEET[c][2]
	var cx0 := vs.x * 0.53 + 2.0
	var cw := 150.0
	var f := UI.noto()
	var cards: Array = [["패시브 · " + pv[0], [[pv[1]]], Color.BLACK, Color.WHITE, Color.BLACK, 12], ["상성", match_text(c), Color.BLACK, col, Color(0.867, 0.867, 0.867), 11]]
	for ci in cards.size():
		var cd: Array = cards[ci]
		var e := UI.bk(clampf((tab_t - i * 40.0) / 500.0, 0.0, 1.0))
		var tagw := tw(f, cd[0], 12) + 12.0
		var lines: Array = []
		var inner := cw - 32.0
		var lh := 16.7 if ci == 1 else 18.75
		var hh := 8.0
		if ci == 0:
			hh += 19.0
			for ln in flow([[pv[1], f, 12, Color.BLACK]], inner): lines.append([ln, false])
		else:
			hh += 19.0
			for ln in cd[1]:
				var fl: Array = flow([[ln[0], f, 11, Color.BLACK], [ln[1], f, 11, Color(0.867, 0.867, 0.867)]], inner)
				for k in fl.size(): lines.append([fl[k], k == 0])
		hh += lines.size() * lh + 10.0
		y += 8.0
		if y + hh >= top and y < vs.y:
			var m := xf(Vector2(cx0 + 60.0 * (1.0 - e), y), Vector2(cw / 2.0, hh / 2.0), -3.0)
			draw_colored_polygon(poly(Rect2(0, 0, cw, hh), [[7, 0], [100, 0], [93, 100], [0, 100]], m), Color(0, 0, 0, e))
			draw_set_transform_matrix(m)
			var tx := 16.0 + (37.0 if ci == 1 else 0.0)
			draw_rect(Rect2(tx, 8, tagw, 19), Color(cd[3] if ci == 1 else Color.BLACK, e))
			txt(self, f, tx + 6, 8, cd[0], 12, Color(Color.BLACK if ci == 1 else Color.WHITE, e), 19.0)
			var ly := 8.0 + 19.0
			for ln in lines:
				if ln[1]:
					# the element tag: her colour behind the first run
					var seg: Array = ln[0][0]
					var r0: Array = seg[1]
					draw_rect(Rect2(20, ly, tw(f, String(seg[2]).rstrip(" "), 11) + 8.0, lh), Color(col, e))
				for seg2 in ln[0]:
					var rr: Array = seg2[1]
					var cc2: Color = rr[3]
					txt(self, rr[1], 20 + (4.0 if ci == 1 and ln[1] else 0.0) + seg2[0] + (8.0 if ci == 1 and ln[1] and seg2 != ln[0][0] else 0.0), ly, seg2[2], rr[2], Color(cc2, e), lh)
				ly += lh
			draw_set_transform(Vector2.ZERO)
		y += hh + 4.0
		i += 1
	stat_max = maxf(0.0, y + stat_scroll - vs.y + 6.0)

func _gear(vs: Vector2, col: Color) -> void:
	# the gear ground (#cx[data-tab=gear]: her colour on the left, the black shard on the right), the gear art (cx_xgear)
	mx.ground(vs, col, "gear")
	if prev_tab == "attr" and tab_t < 350.0: _attr_art(vs, tab_t)
	var art := tx(SK.path(c, "st_gear"))
	var h := vs.y * 1.05
	var w := h * art.get_width() / art.get_height()
	_art(vs, SK.path(c, "st_gear"), Rect2(vs.x * 0.98 - w, vs.y * 1.02 - h, w, h), "gear")
	_name(Vector2(vs.x * 0.05, vs.y * 0.83))
	var G: Dictionary = R().gear[c]
	var y := vs.y * 0.21
	for i in GSL.size():
		var s: String = GSL[i][0]
		var it = G[s]
		var on := i == gi
		var e := UI.bk(clampf((tab_t - i * 40.0) / 500.0, 0.0, 1.0))
		var x := vs.x * 0.06 + (i % 2) * -10.0 + (12.0 if on else 0.0) + 60.0 * (1.0 - e)
		var fb := 0.0
		if on and gi_t < 450.0:
			# cx_flb: from brightness(3), turned (k − 3)·2.2°, 40 px right, 1.12×
			var fu := UIA.p(gi_t, 0.0, 450.0, "bk")
			x += 40.0 * (1.0 - fu)
			fb = 1.0 - fu
		var bw := vs.x * 0.27
		var bh := 30.0
		var g: Color = RN.gcol(it["g"]) if it != null else Color(0.33, 0.33, 0.33)
		var poly := PackedVector2Array([Vector2(x, y), Vector2(x + bw, y - 3.0), Vector2(x + bw - 8.0, y + bh - 3.0), Vector2(x - 6.0, y + bh)])
		if on: draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(4, 4), poly[1] + Vector2(4, 4), poly[2] + Vector2(4, 4), poly[3] + Vector2(4, 4)]), Color.BLACK)
		draw_colored_polygon(poly, Color(1, 1, 1, e) if on else Color(0, 0, 0, 0.92 * e))
		if fb > 0.0: draw_colored_polygon(poly, Color(1, 1, 1, 0.8 * fb))
		draw_rect(Rect2(x - 2, y, 5, bh - 2), Color(g, e))
		draw_string(UI.spaced(UI.anton(), 1), Vector2(x + 12, y + 20), GSL[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(g.darkened(0.3) if on else g, e))
		var nm: String = it["n"] if it != null else "— 비어 있음"
		draw_string(UI.noto_k(), Vector2(x + 72, y + 20), nm, HORIZONTAL_ALIGNMENT_LEFT, bw - 130.0, 13, Color(0, 0, 0, e) if on else Color(1, 1, 1, e))
		if it != null:
			var lv := "Lv %d" % int(it.get("lv", 0))
			draw_string(UI.anton(true), Vector2(x + bw - 44, y + 21), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, e) if on else Color(col, e))
		var ii := i
		hit(poly, func():
			if gi != ii:
				_pick_gi(ii)
				sfx("ui_move", 0.5))
		y += bh + 7.0
	_gear_card(vs, col)

## the picked piece (gearCard), or the swap list
func _gear_card(vs: Vector2, col: Color) -> void:
	var s: String = GSL[gi][0]
	var k: String = GSL[gi][1]
	var it = R().gear[c][s]
	var kind := RN.slot_kind(s)
	var x := vs.x * 0.33
	var y := vs.y * 0.27 + gi * 6.0
	var w := vs.x * 0.27
	if picking:
		var cands: Array = []
		for i in R().gearbag.size():
			if RN.gear_fits(R().gearbag[i], c, s): cands.append(i)
		var rows_h := 40.0 + maxf(1, cands.size()) * 44.0 + 40.0
		var h := minf(rows_h, vs.y - y - 10.0)
		draw_set_transform(Vector2(x, y), deg_to_rad(-3.0))
		draw_rect(Rect2(6, 6, w, h), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(0, 0, w, h), Color.WHITE)
		draw_string(UI.spaced(UI.anton(), 1), Vector2(12, 20), k + " · 교체", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col.darkened(0.2))
		draw_set_transform(Vector2.ZERO)
		var xf := Transform2D(deg_to_rad(-3.0), Vector2(x, y))
		if it != null:
			var off := Rect2(w - 56, 6, 48, 22)
			draw_set_transform_matrix(xf)
			draw_rect(off, Color.BLACK)
			draw_string(UI.noto_k(), off.position + Vector2(12, 16), "해제", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			draw_set_transform(Vector2.ZERO)
			hit(_xr(xf, off), func():
				R().gear_off(c, s)
				sfx("ui_ok", 0.5)
				picking = false)
		var yy := 34.0
		if cands.is_empty():
			draw_set_transform_matrix(xf)
			draw_string(UI.noto(), Vector2(12, yy + 20), "가방에 이 칸에 맞는 장비가 없습니다.", HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 12, Color(0, 0, 0, 0.7))
			draw_set_transform(Vector2.ZERO)
			yy += 44.0
		for bi in cands:
			if yy + 44.0 > h - 30.0: break
			var g: Dictionary = R().gearbag[bi]
			var diff := ""
			for d in R().gear_cmp(g, c, s): diff += "%s %s%s%s  " % [d[0], "+" if d[1] > 0 else "−", RN.fmt(absf(d[1])), d[2]]
			var rr := Rect2(8, yy, w - 16, 40)
			draw_set_transform_matrix(xf)
			draw_rect(rr, Color(0.08, 0.08, 0.09))
			draw_rect(Rect2(rr.position, Vector2(4, 40)), RN.gcol(g["g"]))
			draw_string(UI.noto_k(), rr.position + Vector2(12, 17), "%s  Lv %d" % [g["n"], int(g.get("lv", 0))], HORIZONTAL_ALIGNMENT_LEFT, w - 40.0, 12, RN.gcol(g["g"]).lightened(0.3))
			draw_string(UI.noto(), rr.position + Vector2(12, 33), diff if diff != "" else "변화 없음", HORIZONTAL_ALIGNMENT_LEFT, w - 40.0, 10, Color("#9fe3a0") if diff.find("+") >= 0 else Color("#ff9d9d"))
			draw_set_transform(Vector2.ZERO)
			var b2: int = bi
			hit(_xr(xf, rr), func():
				if R().gear_on(c, s, b2):
					sfx("ui_ok", 0.5)
					arena.text(arena.player.position + Vector2(0, -170), RN.pname(c) + " · " + R().gear[c][s]["n"] + " 장착", Color("#ffe9a8"))
				picking = false)
			yy += 44.0
		var bk := Rect2(12, h - 30, 80, 22)
		draw_set_transform_matrix(xf)
		draw_string(UI.noto_k(), bk.position + Vector2(0, 16), "돌아가기", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.7))
		draw_set_transform(Vector2.ZERO)
		hit(_xr(xf, bk), func(): picking = false)
		return
	var ps: Array = []
	var title := "비어 있음"
	if it != null:
		title = it["n"]
		var desc: String = RN.gname(it["g"]) + " · " + (RN.CLS[c] + " 전용 · " if s == "weapon" else ((it["wt"] + " · ") if it.has("wt") else "")) + gear_line(it, kind)
		# the card's p: grade · class / weight · stats, then "<br>룬 · name" when a rune is set (no star, no text)
		ps.append([desc, 12, Color(0.15, 0.15, 0.15)])
		if R().has_rune_item(it):
			ps.append(["룬 · " + RN.RUNE[it["rune"]]["n"], 12, Color(0.15, 0.15, 0.15)])
	else:
		ps.append([RN.SLOTN[s] + " 칸이 비어 있습니다.", 12, Color(0.3, 0.3, 0.3)])
	var h2 := 66.0 + paras_h(w - 24.0, ps) + 44.0
	# cx_gdpop: from opacity 0, rotate(12°) scale(.6) translateX(−30 px), .42s --bk (with the pane's entrance)
	var gc0 := Vector2(x + w / 2.0, y + 60.0)
	if gd_t < tab_t:
		var e := UIA.p(gd_t, 0.0, 420.0, "bk")
		draw_set_transform_matrix(UIA.xf(gc0, Vector2(-30.0 * (1.0 - e), 0), deg_to_rad(12.0 * (1.0 - e)), Vector2.ONE * lerpf(0.6, 1.0, e)) * Transform2D(deg_to_rad(-3.0), Vector2(x, y)))
	else:
		# as the pane's eighth .it: from 60 px right, turned 6°, after the seven blades
		var e2 := UIA.p(tab_t, 7 * 40.0, 500.0, "bk")
		if tab_t < 7 * 40.0: return
		draw_set_transform_matrix(UIA.xf(gc0, Vector2(60.0 * (1.0 - e2), 0), deg_to_rad(6.0 * (1.0 - e2))) * Transform2D(deg_to_rad(-3.0), Vector2(x, y)))
	draw_rect(Rect2(6, 6, w, h2), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(0, 0, w, h2), Color.WHITE)
	var g2: Color = RN.gcol(it["g"]) if it != null else Color(0.5, 0.5, 0.5)
	UI.para(self, 12, 6, tw(UI.anton(), k, 11) + 18.0, 16, 3.0, g2)
	draw_string(UI.spaced(UI.anton(), 1), Vector2(20, 19), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
	draw_string(UI.bhs(), Vector2(12, 48), title, HORIZONTAL_ALIGNMENT_LEFT, w - 90.0, 21, Color.BLACK)
	if it != null:
		var lv := "Lv %d" % int(it.get("lv", 0))
		draw_string(UI.anton(true), Vector2(w - tw(UI.anton(true), lv, 30) - 10.0, 46), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col.darkened(0.1))
	paras(self, 12, 58, w - 24.0, ps)
	var btn := Rect2(12, h2 - 36, 64, 26)
	UI.para(self, btn.position.x, btn.position.y, btn.size.x, 26, 4.0, Color.BLACK)
	draw_string(UI.noto_k(), btn.position + Vector2(16, 19), "교체", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	hit(_xr(Transform2D(deg_to_rad(-3.0), Vector2(x, y)), btn), func():
		picking = true
		sfx("ui_ok", 0.5))

## the 상세 art (left 4 %, top 4 %, full height); out > 0 = leaving the tab
func _attr_art(vs: Vector2, out: float) -> void:
	var t0 := tx(SK.path(c, "st_base"))
	var h := vs.y
	var w := h * t0.get_width() / t0.get_height()
	var r := Rect2(vs.x * 0.04, vs.y * 0.04, w, h)
	_art(vs, face_path(), r, "slam", out)
	if out > 0.0: return
	# .art: aspect 2/3 box at left 4 %, top 4 %, full height (the picture sits at its foot, centred)
	var ab := Rect2(r.get_center().x - h / 3.0, r.position.y, h * 2.0 / 3.0, h)
	hit(Rect2(ab.position.x + ab.size.x * 0.15, ab.position.y, ab.size.x * 0.7, ab.size.y), func(): react_tap())
	_emo(ab)

## the face on show (face / artSrc): a reaction, else a blink (sblink: the cl picture), else base; a face the worn
## costume lacks resolves to its own base picture (skins.gd "alt")
func face_path() -> String:
	if react != "": return SK.path(c, "st_" + react)
	if blk > 0.0: return SK.path(c, "st_cl")
	return SK.path(c, "st_base")

## react(): a tap smiles for 1.7 s with a hop and ♪; the third tap within 1.3 s is a surprise (sup, 1.5 s, shake, !!)
func react_tap() -> void:
	var now := t
	taps = taps.filter(func(x): return now - x < 1300.0)
	taps.append(now)
	var sup := taps.size() >= 3
	if sup: taps.clear()
	react = "sup" if sup else "smile"
	react_t = 1500.0 if sup else 1700.0
	jolt = "shake" if sup else "hop"
	jolt_t = 0.0

## sblink: every 2.4–5.2 s while she rests on her base face (no reaction), 130 ms, one time in five a second one
func _sblink(dt: float) -> void:
	if blk > 0.0: blk -= dt
	if blk2 > 0.0:
		blk2 -= dt
		if blk2 <= 0.0: blk = 110.0
	blk_next -= dt
	if blk_next <= 0.0:
		blk_next = 2400.0 + randf() * 2800.0
		# no blink picture in the worn costume: no blink (the reactions keep their hop and ♪ on its base face)
		if tab == "attr" and react == "" and SK.has_face(c, "st_cl"):
			blk = 130.0
			if randf() < 0.2: blk2 = 280.0

## the pointer over the page, −1…1 on each axis (--px / --py); 0 until it has moved
func ptr(vs: Vector2) -> Vector2:
	if hover.x < -900.0: return Vector2.ZERO
	return Vector2(clampf(hover.x / vs.x * 2.0 - 1.0, -1.0, 1.0), clampf(hover.y / vs.y * 2.0 - 1.0, -1.0, 1.0))

## cx_hop / cx_shake on .artj: [offset, degrees]
func _jolt() -> Array:
	if jolt == "hop" and jolt_t < 550.0:
		var k: Array = UIA.kf(jolt_t, [[0.0, [0.0, 0.0]], [0.3, [-16.0, -1.5]], [0.65, [3.0, 0.0]], [1.0, [0.0, 0.0]]], 550.0, 0.0, "bk")
		return [Vector2(0, k[0]), k[1]]
	if jolt == "shake" and jolt_t < 420.0:
		var k2: Array = UIA.kf(jolt_t, [[0.0, [0.0, 0.0]], [0.2, [-9.0, -2.0]], [0.4, [8.0, 2.0]], [0.6, [-5.0, 0.0]], [0.8, [3.0, 0.0]], [1.0, [0.0, 0.0]]], 420.0)
		return [Vector2(k2[0], 0), k2[1]]
	return [Vector2.ZERO, 0.0]

## cx_emo: the white star with ♪ (!! after three quick taps) at --hx / --hy of the art (1.2 s --bk)
func _emo(ab: Rect2) -> void:
	if jolt_t >= 1200.0: return
	var hp: Vector2 = HXY.get(c, Vector2(0.58, 0.2))
	var at := ab.position + ab.size * hp + Vector2(-10.0, -30.0)
	var ek: Array = UIA.kf(jolt_t, [[0.0, [0.0, 10.0, 10.0, 0.2, -30.0]], [0.22, [1.0, 40.0, -40.0, 1.15, 10.0]], [0.75, [1.0, 44.0, -46.0, 1.0, 4.0]], [1.0, [0.0, 46.0, -56.0, 0.9, 0.0]]], 1200.0, 0.0, "bk")
	var ec := at + Vector2(36, 30)
	draw_set_transform_matrix(UIA.xf(ec, Vector2(ek[1], ek[2]), deg_to_rad(ek[4]), Vector2.ONE * ek[3]))
	var a := clampf(ek[0], 0.0, 1.0)
	var er := Rect2(at, Vector2(72, 60))
	draw_colored_polygon(UI.clip(er, [[50, 0], [62, 26], [96, 12], [76, 42], [100, 60], [70, 66], [74, 100], [50, 76], [24, 98], [28, 66], [0, 58], [24, 42], [6, 12], [38, 26]]), Color(1, 1, 1, a))
	var es := "!!" if jolt == "shake" else "♪"
	var ef: Font = UI.bhs()
	draw_string(ef, ec + Vector2(-tw(ef, es, 30) / 2.0, 11), es, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, a))
	draw_set_transform(Vector2.ZERO)

static func _xr(xf: Transform2D, r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y), xf * r.end, xf * Vector2(r.position.x, r.end.y)])

func _drag(rel: Vector2, _p: Vector2) -> void:
	if tab == "attr":
		stat_scroll = clampf(stat_scroll - rel.y, 0.0, stat_max)

func _wheel(d: int, _p: Vector2) -> void:
	if tab == "attr":
		stat_scroll = clampf(stat_scroll + d * 40.0, 0.0, stat_max)
		return
	mx.wheel(d)

## matchText(c): per attack element what it beats / is weak to, then what this member takes more / less from
static func match_text(cc: String) -> Array:
	var out: Array = []
	for e in EL.ATKEL.get(cc, ["phys"]):
		if e == "holy":
			out.append([EL.ELN["holy"], " 공격: 어둠을 가진 대상에 1.75배(다른 상성 무시), 그 외 모든 대상에 0.25배"])
			continue
		var g: Array = []
		var b: Array = []
		for k in EL.EFF[e]:
			if EL.EFF[e][k] > 1.0: g.append(EL.ELN[k])
			elif EL.EFF[e][k] < 1.0: b.append(EL.ELN[k])
		out.append([EL.ELN[e], " 공격: " + (("유리 " + "·".join(g)) if not g.is_empty() else "유리 없음") + " / " + (("불리 " + "·".join(b)) if not b.is_empty() else "불리 없음")])
	var weak: Array = []
	var res: Array = []
	for a in EL.ELN:
		var m: float = (1.75 if EL.DEFEL[cc].has("dark") else 0.25) if a == "holy" else EL.eff_mul(a, EL.DEFEL[cc])
		var ms := ("%s×%s" % [EL.ELN[a], str(m) if m != int(m) else str(int(m))])
		if m > 1.0: weak.append(ms)
		elif m < 1.0: res.append(ms)
	out.append(["받는 피해", ": " + (("약점 " + " ".join(weak)) if not weak.is_empty() else "약점 없음") + " / " + (("저항 " + " ".join(res)) if not res.is_empty() else "저항 없음")])
	return out

func back() -> void:
	mx.hush()
	super()
