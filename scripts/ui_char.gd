extends "res://scripts/ui_page.gd"
## 캐릭터 (prototype CHARACTER SCREEN v2, cx v2): tabs 상세 · 장비 · 스킬 · 기억 · 기록 along the top, the member's faces
## top right. 상세 = the numbers with gear on (+ what gear adds), the passive; 장비 = seven blades (WEAPON … ACC 3), the picked
## piece as a card (stats, its rune), 교체 = what in the bag fits, with a stat diff, and 해제.
## 스킬 · 기억 · 기록 belong to other systems and show a short note for now.

const ST := {"estelle": "res://assets/ui/st/estelle_base.webp", "aida": "res://assets/ui/st/aida_base.webp", "luce": "res://assets/ui/st/luce_base.webp"}
const GEAR_ART := {"estelle": "res://assets/ui/st/estelle_gear.webp", "aida": "res://assets/ui/st/aida_gear.webp", "luce": "res://assets/ui/st/luce_gear.webp"}
const FACE := {"estelle": preload("res://assets/ui/faces/estelle.png"), "aida": preload("res://assets/ui/faces/aida.png"), "luce": preload("res://assets/ui/faces/luce.png")}
const TABS := [["attr", "상세", "STATUS"], ["gear", "장비", "GEAR"], ["skill", "스킬", "SKILL"], ["match", "기억", "MEMORY"], ["rec", "기록", "RECORD"]]
const GSL := [["weapon", "WEAPON"], ["head", "HEAD"], ["body", "BODY"], ["shoe", "SHOES"], ["acc1", "ACC 1"], ["acc2", "ACC 2"], ["acc3", "ACC 3"]]
const SHEET := {"estelle": ["에스텔 벨라시타", "자칭 성기사 · 탱커", ["수호자", "받는 피해 25% 감소."]],
	"aida": ["스나가와 아이다", "삽 · 기습형", ["그림자 걸음", "적의 등 뒤에서 때리면 피해 2배 (뒷치기)."]],
	"luce": ["루체 루멘", "빛 · 원거리 지원", ["축복", "루체가 파티에 있으면 대기 중인 동료가 초당 체력 2씩 회복한다."]]}

var c := "estelle"
var tab := "attr"
var gi := 0
var picking := false
var slam_t := 0.0
var tab_t := 0.0


func _ready() -> void:
	super()
	keys = ["char"]

var want_c := ""                 # cxOpen(c): open on this member instead of the one in control

func _opened() -> void:
	c = want_c if want_c != "" else arena.player.who
	want_c = ""
	tab = "attr"
	gi = 0
	picking = false
	slam_t = 0.0
	tab_t = 0.0

func _tick(dt: float) -> void:
	slam_t += dt
	tab_t += dt

func _key(k: int) -> void:
	if k == KEY_ESCAPE:
		if picking: picking = false
		else: back()
	elif k in [KEY_LEFT, KEY_RIGHT, KEY_Q, KEY_E]:
		var i := 0
		for j in TABS.size(): if TABS[j][0] == tab: i = j
		_tab(TABS[(i + (TABS.size() - 1 if k in [KEY_LEFT, KEY_Q] else 1)) % TABS.size()][0])
	elif tab == "gear" and k in [KEY_UP, KEY_DOWN]:
		gi = clampi(gi + (-1 if k == KEY_UP else 1), 0, GSL.size() - 1)
		picking = false
	elif tab == "gear" and k in [KEY_ENTER, KEY_SPACE]:
		picking = not picking

func _tab(k: String) -> void:
	if k == tab: return
	tab = k
	tab_t = 0.0
	picking = false
	sfx("ready", 0.2)

func _member(cc: String) -> void:
	if cc == c: return
	c = cc
	slam_t = 0.0
	picking = false
	sfx("ready", 0.2)

func roster() -> Array:
	var L: Array = arena.player.party.duplicate()
	for cc in RN.ROSTER:
		if not L.has(cc): L.append(cc)
	return L

func _paint(vs: Vector2) -> void:
	var col := UI.col(c)
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	if tab == "gear": _gear(vs, col)
	elif tab == "attr": _attr(vs, col)
	else: _soon(vs, col)
	_tabs(vs, col)
	# faces, top right
	var fx := vs.x - 64.0 - roster().size() * 48.0
	for cc in roster():
		var on: bool = cc == c
		var r := Rect2(fx, 14, 40, 40)
		draw_set_transform(r.get_center(), deg_to_rad(-6.0), Vector2.ONE * (1.08 if on else 0.86))
		var lr := Rect2(-20, -20, 40, 40)
		if on: draw_rect(Rect2(lr.position + Vector2(4, 4), lr.size), UI.col(cc))
		draw_rect(lr.grow(2), Color.WHITE)
		draw_texture_rect(FACE[cc], lr, false, Color.WHITE if on else Color(0.45, 0.45, 0.45))
		draw_set_transform(Vector2.ZERO)
		var c2: String = cc
		hit(r, func(): _member(c2))
		fx += 48.0
	close_x(vs, func():
		if picking: picking = false
		else: back())

func _tabs(vs: Vector2, col: Color) -> void:
	var x := 22.0
	for tb in TABS:
		var on: bool = tb[0] == tab
		var fs := 26 if on else 20
		var w := tw(UI.bhs(), tb[1], fs) + 16.0
		draw_set_transform(Vector2(x, 40), deg_to_rad(-5.0))
		draw_string(UI.spaced(UI.anton(), 2), Vector2(2, -16), tb[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(col, 0.9) if on else Color(1, 1, 1, 0.3))
		if on:
			UI.para(self, -4, -fs + 2, w, fs + 8, 4.0, Color.WHITE)
		draw_string(UI.bhs(), Vector2(4, 4), tb[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.BLACK if on else Color.WHITE)
		draw_set_transform(Vector2.ZERO)
		var k: String = tb[0]
		hit(Rect2(x - 4, 10, w + 4, 40), func(): _tab(k))
		x += w + 8.0

## the name in loose stamped letters, and the role under it
func _name(at: Vector2) -> void:
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
		draw_set_transform(Vector2(x, at.y + dy), deg_to_rad(r))
		draw_rect(Rect2(0, -sz, w, sz + 6.0), s[0])
		draw_string(UI.bhs(), Vector2(4, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, s[1])
		draw_set_transform(Vector2.ZERO)
		x += w + 3.0
	var role: String = SHEET[c][1] + (" · 조작 중" if c == arena.player.who else (" · 파티" if arena.player.party.has(c) else " · 마을"))
	draw_set_transform(at + Vector2(0, 30), deg_to_rad(-4.0))
	UI.para(self, 0, -14, tw(UI.noto_k(), role, 12) + 20.0, 22, 4.0, Color.BLACK)
	draw_string(UI.noto_k(), Vector2(10, 2), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_set_transform(Vector2.ZERO)

func _art(vs: Vector2, p: String, r: Rect2) -> void:
	var tt := tx(p)
	var e := UI.bk(clampf(slam_t / 600.0, 0.0, 1.0))
	draw_set_transform(Vector2(r.get_center().x + 0.2 * r.size.x * (1.0 - e), r.end.y), deg_to_rad(8.0 * (1.0 - e)), Vector2.ONE * (1.0 + 0.08 * (1.0 - e)))
	var lr := Rect2(-r.size.x / 2.0, -r.size.y, r.size.x, r.size.y)
	draw_texture_rect(tt, lr, false, Color(1, 1, 1, clampf(e, 0.0, 1.0)))
	draw_set_transform(Vector2.ZERO)

func _attr(vs: Vector2, col: Color) -> void:
	# her art on the left over black; her colour on the right with rays
	var right := PackedVector2Array([Vector2(vs.x * 0.53, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x * 0.44, vs.y)])
	draw_colored_polygon(right, col)
	UI.burst(self, Vector2(vs.x * 0.75, vs.y * 0.35), vs.x, 0.12, t / 90000.0 * TAU)
	UI.dots(self, Rect2(vs.x * 0.45, 0, vs.x * 0.55, vs.y), 0.25, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(vs.x * 0.45, vs.y * 0.47), Vector2(vs.x, vs.y * 0.22), Vector2(vs.x, vs.y * 0.25), Vector2(vs.x * 0.47, vs.y * 0.49)]), Color.WHITE)
	var t0 := tx(ST[c])
	var h := vs.y * 1.02
	var w := h * t0.get_width() / t0.get_height()
	_art(vs, ST[c], Rect2(vs.x * 0.02, vs.y * 1.03 - h, w, h))
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
	var y := vs.y * 0.38
	var rh := minf(30.0, (vs.y - y - 10.0) / (rows.size() + 1.0))
	var i := 0
	for row in [["현재 체력", str(roundi(hp)), 0, "", hp / maxf(1.0, S["hp"])]] + rows:
		var e := UI.bk(clampf((tab_t - i * 40.0) / 320.0, 0.0, 1.0))
		var x := vs.x * 0.53 + (i % 2) * 14.0 + 40.0 * (1.0 - e) - i * 4.0
		var bw := vs.x * 0.42
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
	# passive
	var pv: Array = SHEET[c][2]
	var pw := vs.x * 0.3
	var py := vs.y * 0.62
	if y < vs.y * 0.9:
		pass
	draw_set_transform(Vector2(vs.x * 0.04, vs.y * 0.86), deg_to_rad(-3.0))
	var ps: Array = [["패시브 · " + pv[0], 12, col], [pv[1], 11, Color.WHITE]]
	var ph := paras_h(pw - 20.0, ps) + 12.0
	draw_rect(Rect2(0, -ph, pw, ph), Color(0, 0, 0, 0.85))
	paras(self, 10, -ph + 6.0, pw - 20.0, ps)
	draw_set_transform(Vector2.ZERO)

func _gear(vs: Vector2, col: Color) -> void:
	# her colour on the left, the gear art on black to the right
	var left := PackedVector2Array([Vector2(0, 0), Vector2(vs.x * 0.56, 0), Vector2(vs.x * 0.47, vs.y), Vector2(0, vs.y)])
	draw_colored_polygon(left, col)
	UI.dots(self, Rect2(0, 0, vs.x * 0.56, vs.y), 0.25, 1.0)
	draw_set_transform(Vector2(vs.x * 0.02, vs.y * 0.38), deg_to_rad(-8.0))
	draw_string_outline(UI.anton(), Vector2.ZERO, UI.EN[c], HORIZONTAL_ALIGNMENT_LEFT, -1, int(vs.y * 0.3), 2, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO)
	var art := tx(GEAR_ART[c])
	var h := vs.y * 1.05
	var w := h * art.get_width() / art.get_height()
	_art(vs, GEAR_ART[c], Rect2(vs.x * 0.98 - w, vs.y * 1.02 - h, w, h))
	draw_colored_polygon(PackedVector2Array([Vector2(vs.x * 0.05, vs.y * 0.82), Vector2(vs.x * 0.5, vs.y * 0.74), Vector2(vs.x * 0.5, vs.y * 0.755), Vector2(vs.x * 0.05, vs.y * 0.835)]), Color.WHITE)
	_name(Vector2(vs.x * 0.05, vs.y * 0.83))
	var G: Dictionary = R().gear[c]
	var y := vs.y * 0.21
	for i in GSL.size():
		var s: String = GSL[i][0]
		var it = G[s]
		var on := i == gi
		var e := UI.bk(clampf((tab_t - i * 40.0) / 320.0, 0.0, 1.0))
		var x := vs.x * 0.06 + (i % 2) * -10.0 + (12.0 if on else 0.0) - 40.0 * (1.0 - e)
		var bw := vs.x * 0.27
		var bh := 30.0
		var g: Color = RN.gcol(it["g"]) if it != null else Color(0.33, 0.33, 0.33)
		var poly := PackedVector2Array([Vector2(x, y), Vector2(x + bw, y - 3.0), Vector2(x + bw - 8.0, y + bh - 3.0), Vector2(x - 6.0, y + bh)])
		if on: draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(4, 4), poly[1] + Vector2(4, 4), poly[2] + Vector2(4, 4), poly[3] + Vector2(4, 4)]), Color.BLACK)
		draw_colored_polygon(poly, Color(1, 1, 1, e) if on else Color(0, 0, 0, 0.92 * e))
		draw_rect(Rect2(x - 2, y, 5, bh - 2), Color(g, e))
		draw_string(UI.spaced(UI.anton(), 1), Vector2(x + 12, y + 20), GSL[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(g.darkened(0.3) if on else g, e))
		var nm: String = it["n"] if it != null else "— 비어 있음"
		draw_string(UI.noto_k(), Vector2(x + 72, y + 20), nm, HORIZONTAL_ALIGNMENT_LEFT, bw - 130.0, 13, Color(0, 0, 0, e) if on else Color(1, 1, 1, e))
		if it != null:
			var lv := "Lv %d" % int(it.get("lv", 0))
			draw_string(UI.anton(true), Vector2(x + bw - 44, y + 21), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, e) if on else Color(col, e))
			if R().has_rune_item(it): gem(self, Vector2(x + bw - 56, y + 14), 5.0, RN.gcol(RN.RUNE[it["rune"]]["g"]))
		var ii := i
		hit(poly, func():
			if gi != ii:
				gi = ii
				picking = false
				sfx("ready", 0.15))
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
				sfx("ready", 0.4)
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
					sfx("ready", 0.5)
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
		ps.append([desc, 12, Color(0.15, 0.15, 0.15)])
		if R().has_rune_item(it):
			ps.append(["룬 · " + RN.RUNE[it["rune"]]["n"] + " ★%d" % int(it.get("rs", 1)), 12, Color(0.15, 0.15, 0.15)])
			ps.append([RN.rune_scaled(it["rune"], int(it.get("rs", 1))), 11, Color(0.35, 0.35, 0.35)])
	else:
		ps.append([RN.SLOTN[s] + " 칸이 비어 있습니다.", 12, Color(0.3, 0.3, 0.3)])
	var h2 := 66.0 + paras_h(w - 24.0, ps) + 44.0
	var e := UI.bk(clampf(tab_t / 360.0, 0.0, 1.0))
	draw_set_transform(Vector2(x + 30.0 * (1.0 - e), y), deg_to_rad(-3.0))
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
		sfx("ready", 0.3))

static func _xr(xf: Transform2D, r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y), xf * r.end, xf * Vector2(r.position.x, r.end.y)])

func _soon(vs: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(vs.x * 0.5, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x * 0.4, vs.y)]), col)
	UI.dots(self, Rect2(vs.x * 0.4, 0, vs.x * 0.6, vs.y), 0.25, 1.0)
	var t0 := tx(ST[c])
	var h := vs.y * 1.02
	_art(vs, ST[c], Rect2(vs.x * 0.02, vs.y * 1.03 - h, h * t0.get_width() / t0.get_height(), h))
	_name(Vector2(vs.x * 0.54, vs.y * 0.2))
	var s := "준비 중"                 # PLACEHOLDER: 스킬 · 기억 · 기록 tabs come with their systems
	var c0 := Vector2(vs.x * 0.7, vs.y * 0.55)
	draw_set_transform(c0, deg_to_rad(-4.0))
	var w := tw(UI.bhs(), s, 44) + 50.0
	UI.para(self, -w / 2.0 + 6.0, -34.0, w, 64, 12.0, Color.BLACK)
	UI.para(self, -w / 2.0, -40.0, w, 64, 12.0, Color.WHITE)
	draw_string(UI.bhs(), Vector2(-w / 2.0 + 25.0, 8.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.BLACK)
	draw_set_transform(Vector2.ZERO)
