extends "res://scripts/ui_page.gd"
## 가방 (prototype BAG v2 #bg2): categories on the left (장비 · 룬 · 재화), a sub-tab per category (장비 / 룬 각인 장비,
## 보유 룬 / 각인된 룬), the rows, and on the right the picked thing blown up over a burst: its numbers (gear ↔ rune face),
## who can wear it with a stat diff per slot (tap = 장착), 녹이기.

const FACE := {"estelle": preload("res://assets/ui/faces/estelle.png"), "aida": preload("res://assets/ui/faces/aida.png"), "luce": preload("res://assets/ui/faces/luce.png")}

var cat := "gear"
var gsub := "plain"
var rsub := "bag"
var sel := 0
var who := ""
var face := "g"
var pop_t := 0.0
var scroll := 0.0


func _ready() -> void:
	super()
	keys = ["bag"]

func _opened() -> void:
	sel = 0
	scroll = 0.0
	pop_t = 0.0

func _tick(dt: float) -> void:
	pop_t += dt

func _key(k: int) -> void:
	var L := rows()
	if k == KEY_ESCAPE: back()
	elif k in [KEY_UP, KEY_W]: _sel(maxi(0, sel - 1))
	elif k in [KEY_DOWN, KEY_S]: _sel(mini(L.size() - 1, sel + 1))
	elif k in [KEY_LEFT, KEY_RIGHT, KEY_TAB]:
		var cs := ["gear", "rune", "mat"]
		_cat(cs[(cs.find(cat) + (2 if k == KEY_LEFT else 1)) % 3])

func _wheel(d: int, _p: Vector2) -> void:
	scroll = maxf(0.0, scroll + d * 44.0)

func _sel(i: int) -> void:
	if i == sel or i < 0: return
	sel = i
	pop_t = 0.0
	sfx("ready", 0.15)

func _cat(k: String) -> void:
	cat = k
	sel = 0
	scroll = 0.0
	pop_t = 0.0
	sfx("ready", 0.2)

func worn() -> Array:
	var L: Array = []
	for c in arena.player.roster():
		for s in RN.SLOTS:
			var it = R().gear[c][s[0]]
			if R().has_rune_item(it): L.append({"it": it, "c": c, "s": s[0]})
	return L

## bgList
func rows() -> Array:
	var ord := RN.GORD
	var L: Array = []
	if cat == "gear" and gsub == "rune":
		for w in worn(): L.append({"kind": "gear", "v": w["it"], "c": w["c"], "s": w["s"], "grp": "on"})
		for it in R().gearbag:
			if R().has_rune_item(it): L.append({"kind": "gear", "v": it, "c": "", "s": it["slot"], "grp": "off"})
		L.sort_custom(func(a, b): return (a["grp"] == "on" and b["grp"] != "on") or (a["grp"] == b["grp"] and ord.find(a["v"]["g"]) < ord.find(b["v"]["g"])))
	elif cat == "gear":
		for it in R().gearbag:
			if not R().has_rune_item(it): L.append({"kind": "gear", "v": it, "c": "", "s": it["slot"]})
		L.sort_custom(func(a, b): return ord.find(a["v"]["g"]) < ord.find(b["v"]["g"]))
	elif cat == "rune" and rsub == "set":
		for w in worn(): L.append({"kind": "erune", "v": w["it"]["rune"], "it": w["it"], "c": w["c"], "s": w["s"], "grp": "on"})
		for it in R().gearbag:
			if R().has_rune_item(it): L.append({"kind": "erune", "v": it["rune"], "it": it, "c": "", "s": it["slot"], "grp": "off"})
	elif cat == "rune":
		var ks: Array = R().runebag.keys().filter(func(r): return int(R().runebag[r]) > 0 and RN.RUNE.has(r))
		ks.sort_custom(func(a, b): return ord.find(RN.RUNE[a]["g"]) < ord.find(RN.RUNE[b]["g"]))
		for r in ks: L.append({"kind": "rune", "v": r, "n": R().runebag[r]})
	else:
		L = [{"kind": "sh", "v": R().iron}, {"kind": "mem", "v": R().mem}]
	return L

func ocol(o: Dictionary) -> Color:
	match o["kind"]:
		"sh": return RN.SHC
		"mem": return RN.MEMC
		"rune", "erune": return RN.gcol(RN.RUNE[o["v"]]["g"])
	return RN.gcol(o["v"]["g"])

func oname(o: Dictionary) -> String:
	match o["kind"]:
		"sh": return "실링"
		"mem": return "기억석"
		"rune", "erune": return RN.RUNE[o["v"]]["n"]
	return o["v"]["n"]

func _paint(vs: Vector2) -> void:
	var col := tcol()
	draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	# the right: her colour, dots, a slanted edge
	var right := PackedVector2Array([Vector2(vs.x * 0.47, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x * 0.55, vs.y)])
	draw_colored_polygon(right, col)
	# .burst (left 76 %, top 52 %, 80 s a turn) and the drifting dots (w_dotf 6 s)
	UI.burst(self, Vector2(vs.x * 0.76, vs.y * 0.52), maxf(vs.x, vs.y) * 1.6, 0.14, t / 80000.0 * TAU)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x * 0.47, 0), Vector2(vs.x * 0.55, vs.y), Vector2(0, vs.y)]), Color.BLACK)
	var dsc := fmod(t / 6000.0, 1.0)
	UI.dots(self, Rect2(vs.x * 0.47, 0, vs.x * 0.53, vs.y), 0.3, 1.0, Vector2(-44.0 * dsc, 22.0 * dsc))
	# title and categories
	draw_set_transform(Vector2(44, 52), deg_to_rad(-4.0))
	draw_string(UI.bhs(), Vector2.ZERO, "가방", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	var cy := vs.y * 0.27
	for k in [["gear", "장비"], ["rune", "룬"], ["mat", "재화"]]:
		var on: bool = cat == k[0]
		var fs := 28 if on else 20
		var x := 40.0 + (18.0 if on else 0.0)
		draw_set_transform(Vector2(x, cy), deg_to_rad(-6.0))
		if on: draw_colored_polygon(PackedVector2Array([Vector2(-16, -16), Vector2(-4, -10), Vector2(-16, -4)]), col)
		draw_string(UI.bhs(), Vector2.ZERO, k[1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE if on else Color(0.55, 0.55, 0.55))
		draw_set_transform(Vector2.ZERO)
		var kk: String = k[0]
		hit(Rect2(20, cy - fs, 120, fs + 8.0), func(): _cat(kk))
		cy += fs + 6.0
	# money
	draw_set_transform(Vector2(40, vs.y - 22.0), deg_to_rad(-3.0))
	draw_string(UI.noto_k(), Vector2.ZERO, "실링", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(UI.anton(true), Vector2(36, 1), str(R().iron), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	draw_string(UI.noto_k(), Vector2(120, 0), "기억석", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(UI.anton(true), Vector2(168, 1), str(R().mem), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
	draw_set_transform(Vector2.ZERO)
	# sub tabs
	var L := rows()
	if sel >= L.size(): sel = 0
	var sx := vs.x * 0.225
	var sy := vs.y * 0.08
	if cat == "gear":
		var nr := 0
		for it in R().gearbag: if R().has_rune_item(it): nr += 1
		sx += tab_btn(Vector2(sx, sy), "장비", R().gearbag.size() - nr, gsub == "plain", func(): gsub = "plain"; sel = 0; sfx("ready", 0.2))
		tab_btn(Vector2(sx, sy), "룬 각인 장비", nr + worn().size(), gsub == "rune", func(): gsub = "rune"; sel = 0; sfx("ready", 0.2))
	elif cat == "rune":
		var ne := worn().size()
		for it in R().gearbag: if R().has_rune_item(it): ne += 1
		sx += tab_btn(Vector2(sx, sy), "보유 룬", R().rune_count(), rsub == "bag", func(): rsub = "bag"; sel = 0; sfx("ready", 0.2))
		tab_btn(Vector2(sx, sy), "각인된 룬", ne, rsub == "set", func(): rsub = "set"; sel = 0; sfx("ready", 0.2))
	# rows
	var y := vs.y * 0.17 - scroll
	var x0 := vs.x * 0.2
	if L.is_empty():
		draw_string(UI.noto_k(), Vector2(x0, y + 40.0), "비어 있어요. 던전에서 구해 오세요.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
	var last_grp := ""
	for i in L.size():
		var o: Dictionary = L[i]
		if o.has("grp") and o["grp"] != last_grp:
			last_grp = o["grp"]
			var n := L.filter(func(q): return q.get("grp", "") == last_grp).size()
			draw_string(UI.noto_k(), Vector2(x0 + 4, y + 16), ("착용 중" if last_grp == "on" else "가방") + "  " + str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			y += 24.0
		var on := i == sel
		var two: bool = o["kind"] == "erune" or (o["kind"] == "gear" and o.get("c", "") != "")
		var h := 44.0 if two else 34.0
		# .sbody .it: in from 60 px right, .5s --bk, 60 ms apart (opacity .3s)
		var e0 := clampf((t - i * 60.0) / 500.0, 0.0, 1.0)
		var x := x0 + 60.0 * (1.0 - UI.bk(e0))
		var e := clampf((t - i * 60.0) / 300.0, 0.0, 1.0)
		var nm := oname(o)
		var small := ""
		var rtxt := ""
		match o["kind"]:
			"gear":
				small = ((RN.pname(o["c"]) + " · ") if o.get("c", "") != "" else "") + RN.SLOTN.get(o["s"], o["s"])
				rtxt = (("★%d " % int(o["v"].get("rs", 1))) if R().has_rune_item(o["v"]) else "") + "Lv %d" % int(o["v"].get("lv", 0))
			"erune":
				small = (RN.pname(o["c"]) if o.get("c", "") != "" else "가방") + " · " + RN.SLOTN.get(o["s"], o["s"]) + " · " + o["it"]["n"]
				rtxt = "★%d" % int(o["it"].get("rs", 1))
			"rune": rtxt = ("×%d" % o["n"]) if o["n"] > 1 else ""
			_: rtxt = str(o["v"])
		var w := tw(UI.noto_k(), nm, 15 if on else 14) + tw(UI.noto(), small, 10) + tw(UI.anton(true), rtxt, 17) + 86.0
		if y > vs.y * 0.12 and y < vs.y - 50.0:
			var poly := PackedVector2Array([Vector2(x, y), Vector2(x + w + 8.0, y), Vector2(x + w, y + h), Vector2(x, y + h)])
			if on: draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(4, 4), poly[1] + Vector2(4, 4), poly[2] + Vector2(4, 4), poly[3] + Vector2(4, 4)]), col)
			draw_colored_polygon(poly, Color(1, 1, 1, e) if on else Color(0.1, 0.1, 0.11, 0.95 * e))
			gem(self, Vector2(x + 18, y + h / 2.0), 7.0, ocol(o))
			var fc := Color(0, 0, 0, e) if on else Color(1, 1, 1, e)
			if two:
				draw_string(UI.noto_k(), Vector2(x + 36, y + 20), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if on else 14, fc)
				draw_string(UI.noto(), Vector2(x + 36, y + 36), small, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(fc, 0.62 * e))
			else:
				var xx := x + 36.0
				if small != "":
					draw_string(UI.noto(), Vector2(xx, y + 22), small, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(fc, 0.62 * e))
					xx += tw(UI.noto(), small, 10) + 7.0
				draw_string(UI.noto_k(), Vector2(xx, y + 23), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if on else 14, fc)
			draw_string(UI.anton(true), Vector2(x + w - tw(UI.anton(true), rtxt, 17) - 8.0, y + h / 2.0 + 7.0), rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(col, e) if not on else Color(0, 0, 0, e))
			var ii := i
			hit(poly, func(): _sel(ii))
		y += h + 6.0
	if not L.is_empty(): _spot(vs, L[sel], col)
	close_x(vs, back)

## bgSpot: the picked thing, large
func _spot(vs: Vector2, o: Dictionary, col: Color) -> void:
	var g := ocol(o)
	# .spot.pop: the disc spins in from a fifth of its size (w_pop), the gem drops from 2.4x (w_popd) and bobs (w_bob),
	# the name stamps down (w_stamp); all .45s --bk
	var k := UI.bk(clampf(pop_t / 450.0, 0.0, 1.0))
	var cc := Vector2(vs.x * 0.765, vs.y * 0.34)
	var rad := vs.y * 0.27 * lerpf(0.2, 1.0, k)
	var spin := deg_to_rad(-90.0) * (1.0 - k)
	draw_circle(cc, rad + 6.0, g)
	draw_circle(cc, rad, Color(0.05, 0.05, 0.07))
	for i in 30:
		var a0 := float(i) / 30.0 * TAU + t / 14000.0 * TAU + spin
		var a1 := a0 + TAU / 60.0
		draw_colored_polygon(PackedVector2Array([cc, cc + Vector2(cos(a0), sin(a0)) * rad, cc + Vector2(cos(a1), sin(a1)) * rad]), Color(g, 0.85))
	draw_circle(cc, rad * 0.3, Color(0.05, 0.05, 0.07))
	var kd := clampf(pop_t / 450.0, 0.0, 1.0)
	var dr := vs.y * 0.27 * 0.48 * lerpf(2.4, 1.0, k)
	var bob := -0.08 * dr * 1.4 * (0.5 - 0.5 * cos(t / 2600.0 * TAU))
	var gc := cc + Vector2(0, bob)
	var ga := clampf(kd * 2.0, 0.0, 1.0)
	draw_colored_polygon(rrect(Rect2(gc - Vector2(dr, dr) * 0.7, Vector2(dr, dr) * 1.4), 45.0), Color(1, 1, 1, ga))
	gem(self, gc, dr * 0.8, Color(g, ga), false)
	# name plate
	var nm := oname(o)
	if o["kind"] == "gear": nm += " +%d" % int(o["v"].get("lv", 0))
	elif o["kind"] == "erune": nm += " ★%d" % int(o["it"].get("rs", 1))
	var np := Vector2(vs.x * 0.55, vs.y * 0.6)
	var ks := UI.bk(clampf((pop_t - 80.0) / 450.0, 0.0, 1.0))
	var nw := tw(UI.bhs(), nm, 28) + 30.0
	draw_set_transform_matrix(Transform2D(deg_to_rad(-6.0 - 12.0 * (1.0 - ks)), Vector2.ONE * lerpf(2.2, 1.0, ks), 0.0, np + Vector2(nw / 2.0, -13.0)) * Transform2D(0.0, Vector2(-nw / 2.0, 13.0)))
	UI.para(self, 0, -34, nw, 42, 6.0, Color.BLACK)
	draw_string(UI.bhs(), Vector2(14, 0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	# info box
	var ix := vs.x * 0.56
	var iw := vs.x * 0.4
	var ps: Array = []
	var gk := ""
	match o["kind"]:
		"gear":
			var it: Dictionary = o["v"]
			var kind := RN.slot_kind(o["s"])
			gk = RN.gname(it["g"])
			if o.get("c", "") != "":
				ps.append([gk + " · " + RN.pname(o["c"]) + " · " + RN.SLOTN.get(o["s"], "") + " 착용 중", 12, g])
			else:
				ps.append([gk + " · " + ((it.get("cls", "") + " 무기") if it["slot"] == "weapon" else ((it.get("wt", "") + " " + RN.SLOTN[it["slot"]]) if it.has("wt") else "장신구")), 12, g])
			if R().has_rune_item(it) and face == "r":
				ps.append([rune_head(it["rune"], int(it.get("rs", 1))), 11, RN.gcol(RN.RUNE[it["rune"]]["g"])])
				ps.append([RN.rune_scaled(it["rune"], int(it.get("rs", 1))), 12, Color.WHITE])
			else:
				ps.append([gear_line(it, kind), 12, Color.WHITE])
			if o.get("c", "") != "": ps.append(["바꾸거나 빼려면 캐릭터 창 장비 탭에서.", 10, Color(1, 1, 1, 0.6)])
		"erune":
			var Rd: Dictionary = RN.RUNE[o["v"]]
			var it2: Dictionary = o["it"]
			ps.append([RN.gname(Rd["g"]) + " · " + ((RN.pname(o["c"]) + " · " + RN.SLOTN.get(o["s"], "")) if o.get("c", "") != "" else "가방 속 장비") + "에 각인", 12, g])
			ps.append([rune_head(o["v"], int(it2.get("rs", 1))), 11, g])
			ps.append([RN.rune_scaled(o["v"], int(it2.get("rs", 1))), 12, Color.WHITE])
			ps.append(["성급은 대장간 강화에서 올려요.", 10, Color(1, 1, 1, 0.6)])
		"rune":
			var Rd2: Dictionary = RN.RUNE[o["v"]]
			ps.append([RN.gname(Rd2["g"]) + " · " + rune_kind(o["v"]), 12, g])
			ps.append([Rd2["d"], 12, Color.WHITE])
			ps.append(["대장간에서 각인할 수 있어요.", 10, Color(1, 1, 1, 0.6)])
		"sh": ps.append(["길드에서 쓰는 화폐. 대장간 강화·각인·계승에 쓴다.", 12, Color.WHITE])
		"mem": ps.append(["던전의 기억이 굳은 돌. 마을의 세계수에 넣어 캐릭터를 성장시킨다.", 12, Color.WHITE])
	var has_tabs: bool = o["kind"] == "gear" and R().has_rune_item(o["v"])
	var h := paras_h(iw - 24.0, ps) + 16.0 + (24.0 if has_tabs else 0.0)
	var iy := vs.y * 0.63
	draw_set_transform(Vector2(ix, iy), deg_to_rad(-3.0))
	draw_rect(Rect2(0, 0, iw, h), Color(0, 0, 0, 0.92))
	var yy := 8.0
	if has_tabs:
		var x := 12.0
		for tb in [["g", "장비 효과"], ["r", "룬 효과 ★%d" % int(o["v"].get("rs", 1))]]:
			var on: bool = face == tb[0]
			var bw := tw(UI.noto(), tb[1], 11) + 20.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + 3, yy), Vector2(x + bw + 3, yy), Vector2(x + bw, yy + 18), Vector2(x, yy + 18)]), Color.WHITE if on else Color(0.16, 0.16, 0.16))
			draw_string(UI.noto(), Vector2(x + 10, yy + 13), tb[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK if on else Color(0.6, 0.6, 0.6))
			x += bw + 6.0
		yy += 24.0
	paras(self, 12, yy, iw - 24.0, ps)
	draw_set_transform(Vector2.ZERO)
	if has_tabs: hit(rrect(Rect2(ix, iy, iw, h), -3.0), func(): face = "g" if face == "r" else "r"; sfx("ready", 0.15))
	# who can wear a bag piece, the slots with their stat diff, melt
	if o["kind"] == "gear" and o.get("c", "") == "":
		var it3: Dictionary = o["v"]
		var W: Array = arena.player.roster().filter(func(c): return it3["slot"] != "weapon" or it3.get("cls", "") == RN.CLS[c])
		if not W.has(who): who = arena.player.who if W.has(arena.player.who) else (W[0] if not W.is_empty() else "")
		var fy := iy + h + 4.0
		var fx := ix + 4.0
		for c in W:
			var on2: bool = c == who
			var r := Rect2(fx, fy, 30, 30)
			if on2: draw_rect(r.grow(3), UI.col(c))
			draw_texture_rect(FACE[c], r, false, Color.WHITE if on2 else Color(0.5, 0.5, 0.5))
			var cc2: String = c
			hit(r, func(): who = cc2; sfx("ready", 0.15))
			fx += 38.0
		if who != "":
			var bx := fx + 6.0
			for sl in RN.slots_for(it3):
				var curi = R().gear[who][sl]
				var lab: String = RN.SLOTN[sl] + " · " + ((curi["n"] + " +%d" % int(curi.get("lv", 0))) if curi != null else "비어 있음")
				var diff := ""
				for d in R().gear_cmp(it3, who, sl):
					diff += "%s %s%s%s  " % [d[0], "+" if d[1] > 0 else "−", RN.fmt(absf(d[1])), d[2]]
				if diff == "": diff = "변화 없음"
				var bw2 := maxf(tw(UI.noto(), lab, 10), tw(UI.noto(), diff, 9)) + 18.0
				var br := Rect2(bx, fy - 4.0, bw2, 38)
				if br.end.x > vs.x - 6.0: break
				draw_rect(br, Color(0, 0, 0, 0.9))
				draw_rect(Rect2(bx, fy - 4.0, 3, 38), UI.col(who))
				draw_string(UI.noto(), Vector2(bx + 9, fy + 10), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
				draw_string(UI.noto(), Vector2(bx + 9, fy + 26), diff, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#9fe3a0") if diff.find("+") >= 0 else Color("#ff9d9d"))
				var s3: String = sl
				var w3: String = who
				hit(br, func():
					if R().gear_on(w3, s3, R().gearbag.find(it3)):
						arena.text(arena.player.position + Vector2(0, -170), RN.pname(w3) + " · " + it3["n"] + " 장착", Color("#ffe9a8"))
						sfx("ready", 0.5)
						sel = 0)
				bx += bw2 + 6.0
		var ml := "녹이기 · 실링 +%d%s" % [RN.melt_val(it3), " · 룬은 가방으로" if R().has_rune_item(it3) else ""]
		var mr := Rect2(ix + 4.0, fy + 40.0, tw(UI.noto_k(), ml, 12) + 24.0, 24)
		if mr.end.y < vs.y:
			UI.para(self, mr.position.x, mr.position.y, mr.size.x, 24, 4.0, Color(0.1, 0.1, 0.1))
			draw_string(UI.noto_k(), mr.position + Vector2(12, 17), ml, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
			hit(mr, func():
				R().melt(R().gearbag.find(it3))
				sfx("heavy", 0.5)
				pop_t = 0.0)
