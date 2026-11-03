extends "res://scripts/ui_page.gd"
## 가방 — the prototype's BAG v2 (#bg2, openBag2 / bgRows / bgSpot), laid out as its DOM is:
##   the page in her colour with the burst (76 % / 52 %, 80 s a turn), the drifting dots and the black band (-10°);
##   .ttl 가방 (-6°), .cats 장비 · 룬 · 재화 (-10°, the picked one ×1.35 with ▶), .bsub (-4°) the two sub tabs,
##   .rows (18 % / 15 %, 40 % wide, clipped): content-wide rows, the picked one white, -4°, ×1.06, 26 px right;
##   .spot (right 2 %, top 10 %, 44 % × 86 %): the striped disc, the big gem, and .nm (-5°): h2, the info p and
##   .bwho (faces, slots with the stat diff = 장착, 녹이기); .cash chips bottom left; the ✕.
## Motion as the CSS: .st stagger in (50 px, 6°, .5 s --bk, 40 ms apart) on every bgRows; a picked row turns over
## .5 s --bk; .spot.pop: disc w_pop, gem w_popd, name w_stamp (.45 s --bk, the name 80 ms late); the gem bobs (2.6 s);
## the disc, whose w_spin replaces its centring translate, only drifts from centred to half a disc right-down in 14 s.

const SK := preload("res://scripts/skins.gd")       # member art through the worn costume
const AE := preload("res://scripts/ui_anim.gd")

var cat := "gear"
var gsub := "plain"
var rsub := "bag"
var sel := 0
var who := ""
var rvm := {}                  # RVM: the effect box face per context ("bag" -> g, "rune" -> r)
var pop_t := 0.0               # since the last bgSpot (.spot.pop)
var rows_t := 0.0              # since the last bgRows (stIn)
var sel_t := -9999.0           # since the last row pick (row transition)
var prev_sel := -1
var cat_t := 9999.0
var prev_cat := ""
var flip_t := 9999.0          # rvbox flip nudge
var who_t := 9999.0
var prev_who := ""
var scroll := 0.0
var rows_ctl: Control
var front_ctl: Control
var h_back: Array = []
var h_rows: Array = []
var h_front: Array = []
var L: Array = []              # bgList, refreshed by bgRows
var st_idx: Array = []         # per row: its .st index (--i) counting the group heads


func _ready() -> void:
	super()
	keys = ["bag"]
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rows_ctl = Control.new()
	rows_ctl.clip_contents = true
	rows_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows_ctl)
	rows_ctl.draw.connect(_draw_rows)
	front_ctl = Control.new()
	front_ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front_ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(front_ctl)
	front_ctl.draw.connect(_draw_front)

func _opened() -> void:
	sel = 0
	scroll = 0.0
	sel_t = 9999.0
	prev_sel = -1
	cat_t = 9999.0
	bg_rows()

## bgRows: rebuild the list, the rows enter again (stIn), the spot pops
func bg_rows() -> void:
	L = rows()
	if sel >= L.size(): sel = 0
	st_idx.clear()
	var j := 0
	var last := ""
	for o in L:
		if o.has("grp") and o["grp"] != last:
			last = o["grp"]
			j += 1
		st_idx.append(j)
		j += 1
	rows_t = 0.0
	sel_t = 9999.0
	prev_sel = -1
	pop_t = 0.0

func _tick(dt: float) -> void:
	pop_t += dt
	rows_t += dt
	sel_t += dt
	cat_t += dt
	flip_t += dt
	who_t += dt
	var vs := get_viewport_rect().size
	rows_ctl.position = Vector2(vs.x * 0.18, vs.y * 0.15)
	rows_ctl.size = Vector2(vs.x * 0.4, vs.y * 0.79)
	rows_ctl.queue_redraw()
	front_ctl.queue_redraw()

func _draw() -> void:
	h_back.clear()
	_paint(get_viewport_rect().size)

## taps: the ✕ and the front layer over the rows over the spot
func _input(ev: InputEvent) -> void:
	hits = h_back + h_rows + h_front
	super(ev)

func _key(k: int) -> void:
	if k == KEY_ESCAPE: back()
	elif k in [KEY_UP, KEY_W]: _pick(maxi(0, sel - 1))
	elif k in [KEY_DOWN, KEY_S]: _pick(mini(L.size() - 1, sel + 1))
	elif k in [KEY_LEFT, KEY_RIGHT, KEY_TAB]:
		var cs := ["gear", "rune", "mat"]
		_cat(cs[(cs.find(cat) + (2 if k == KEY_LEFT else 1)) % 3])

func _wheel(d: int, _p: Vector2) -> void:
	scroll = clampf(scroll + d * 44.0, 0.0, maxf(0.0, _list_h() - rows_ctl.size.y))

func _pick(i: int) -> void:
	if i == sel or i < 0 or i >= L.size(): return
	prev_sel = sel
	sel = i
	sel_t = 0.0
	pop_t = 0.0

func _cat(k: String) -> void:
	if k == cat: return
	prev_cat = cat
	cat = k
	cat_t = 0.0
	sel = 0
	scroll = 0.0
	sfx("ui_move", 0.5)
	bg_rows()

func _sub(k: String) -> void:
	if cat == "gear": gsub = k
	else: rsub = k
	sel = 0
	scroll = 0.0
	sfx("ui_move", 0.5)
	bg_rows()

func worn() -> Array:
	var out: Array = []
	for c in arena.player.roster():
		for s in RN.SLOTS:
			var it = R().gear[c][s[0]]
			if R().has_rune_item(it): out.append({"it": it, "c": c, "s": s[0]})
	return out

func engraved() -> Array:
	var out: Array = []
	for w in worn(): out.append({"kind": "erune", "v": w["it"]["rune"], "it": w["it"], "c": w["c"], "s": w["s"], "grp": "on"})
	for it in R().gearbag:
		if R().has_rune_item(it): out.append({"kind": "erune", "v": it["rune"], "it": it, "c": "", "s": it["slot"], "grp": "off"})
	return out

## Array.sort as JS: stable
static func ssort(a: Array, less: Callable) -> Array:
	var d: Array = []
	for i in a.size(): d.append([a[i], i])
	d.sort_custom(func(x, y): return less.call(x[0], y[0]) or (not less.call(y[0], x[0]) and x[1] < y[1]))
	return d.map(func(x): return x[0])

## bgList
func rows() -> Array:
	var ord := RN.GORD
	var out: Array = []
	var go := func(a, b): return (0 if a["grp"] == "on" else 1) - (0 if b["grp"] == "on" else 1)
	if cat == "gear" and gsub == "rune":
		for w in worn(): out.append({"kind": "gear", "v": w["it"], "c": w["c"], "s": w["s"], "grp": "on"})
		for it in R().gearbag:
			if R().has_rune_item(it): out.append({"kind": "gear", "v": it, "c": "", "s": it["slot"], "grp": "off"})
		return ssort(out, func(a, b):
			var g: int = go.call(a, b)
			return g < 0 or (g == 0 and ord.find(a["v"]["g"]) < ord.find(b["v"]["g"])))
	if cat == "gear":
		for it in R().gearbag:
			if not R().has_rune_item(it): out.append({"kind": "gear", "v": it, "c": "", "s": it["slot"]})
		return ssort(out, func(a, b): return ord.find(a["v"]["g"]) < ord.find(b["v"]["g"]))
	if cat == "rune" and rsub == "set":
		return ssort(engraved(), func(a, b):
			var g: int = go.call(a, b)
			if g != 0: return g < 0
			var ga := ord.find(RN.RUNE[a["v"]]["g"])
			var gb := ord.find(RN.RUNE[b["v"]]["g"])
			if ga != gb: return ga < gb
			return int(b["it"].get("rs", 1)) < int(a["it"].get("rs", 1)))
	if cat == "rune":
		var ks: Array = R().runebag.keys().filter(func(r): return int(R().runebag[r]) > 0 and RN.RUNE.has(r))
		ks = ssort(ks, func(a, b): return ord.find(RN.RUNE[a]["g"]) < ord.find(RN.RUNE[b]["g"]))
		for r in ks: out.append({"kind": "rune", "v": r, "n": int(R().runebag[r])})
		return out
	return [{"kind": "sh", "v": R().iron}, {"kind": "mem", "v": R().mem}]

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

static func bg_slot(s: String) -> String:
	return "장신구" if s == "acc" else RN.SLOTN.get(s, s)

static func loc(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ---------- the page ----------
func _paint(vs: Vector2) -> void:
	var col := tcol()
	draw_rect(Rect2(Vector2.ZERO, vs), col)
	# .burst: 260vmax conic, 5° dark of 13°, from the top, 80 s a turn
	UI.burst(self, Vector2(vs.x * 0.76, vs.y * 0.52), maxf(vs.x, vs.y) * 1.84, 0.14, -PI / 2.0 + t / 80000.0 * TAU)
	# .dots: 11 px, w_dotf 6 s to -44 px 22 px
	var u := fmod(t / 6000.0, 1.0)
	var off := Vector2(-44.0 * u, 22.0 * u)
	draw_texture_rect(UI.dot_tile(0.26), Rect2(Vector2(fposmod(off.x, 11.0), fposmod(off.y, 11.0)) - Vector2(11, 11), vs + Vector2(22, 22)), true)
	# .band: left -10 %, top -20 %, 62 % × 150 %, -10° about its centre
	var band := Rect2(-vs.x * 0.1, -vs.y * 0.2, vs.x * 0.62, vs.y * 1.5)
	draw_colored_polygon(poly(Rect2(Vector2.ZERO, band.size), SQ, xf(band.position, band.size / 2.0, -10.0)), Color.BLACK)
	if sel < L.size(): _spot(vs, L[sel], col)

## .spot
func _spot(vs: Vector2, o: Dictionary, col: Color) -> void:
	var g := ocol(o)
	var sp := Rect2(vs.x - vs.x * 0.02 - vs.x * 0.44, vs.y * 0.1, vs.x * 0.44, vs.y * 0.86)
	var anc := Vector2(sp.position.x + sp.size.x * 0.5, sp.position.y + sp.size.y * 0.26)
	var kp := UI.bk(clampf(pop_t / 450.0, 0.0, 1.0))
	# .disc: 62 % wide; w_spin swaps its translate(-50%,-50%) for rotate(360deg) = a drift with no turn (14 s)
	var D := sp.size.x * 0.62
	var dr := fmod(t, 14000.0) / 14000.0
	var drift := Vector2(D / 2.0, D / 2.0) * dr
	var sc := lerpf(0.2, 1.0, kp)
	var rot := deg_to_rad(-90.0) * (1.0 - kp)
	var dc := anc + drift * kp
	var R0 := D / 2.0 * sc
	draw_circle(dc, R0 + 12.0 * sc, g)
	draw_circle(dc, R0 + 8.0 * sc, Color.BLACK)
	var n := 23
	for i in n:
		var a0 := -PI / 2.0 + rot + i * deg_to_rad(16.0)
		var a1 := a0 + deg_to_rad(8.0)
		var pts := PackedVector2Array([dc])
		for k in 5: pts.append(dc + Vector2.from_angle(lerpf(a0, a1, k / 4.0)) * R0)
		draw_colored_polygon(pts, g)
	# .big: 26 % wide, rotate 45°, white 6 px border, 10 px shadow; w_bob 2.6 s (-50 % → -58 %); w_popd from ×2.4, clear
	var B := sp.size.x * 0.26
	var bt := fmod(t, 2600.0) / 2600.0
	var bob := -0.08 * B * (AE.ez("ease-in-out", bt * 2.0) if bt < 0.5 else 1.0 - AE.ez("ease-in-out", (bt - 0.5) * 2.0))
	var bsc := lerpf(2.4, 1.0, kp)
	var ba := clampf(lerpf(0.0, 1.0, kp), 0.0, 1.0)
	var bc := anc + Vector2(0, bob * kp)
	var bm := Transform2D(PI / 4.0, Vector2(bsc, bsc), 0.0, bc)
	var sq := func(r: float, sh := Vector2.ZERO) -> PackedVector2Array:
		return PackedVector2Array([bm * (Vector2(-r, -r) + sh), bm * (Vector2(r, -r) + sh), bm * (Vector2(r, r) + sh), bm * (Vector2(-r, r) + sh)])
	draw_colored_polygon(sq.call(B / 2.0, Vector2(10, 10)), Color(0, 0, 0, ba))
	draw_colored_polygon(sq.call(B / 2.0), Color(1, 1, 1, ba))
	draw_colored_polygon(sq.call(B / 2.0 - 6.0), Color(g, ba))
	_nm(vs, sp, o, g)

## the info p's runs and the who row's needs, per kind
func _info(o: Dictionary) -> Dictionary:
	var f := UI.noto()
	var W := Color.WHITE
	var d := {"runs": [], "box": null, "small": "", "who": false}
	match o["kind"]:
		"gear":
			var it: Dictionary = o["v"]
			d["runs"].append([RN.gname(it["g"]), f, 12, RN.gcol(it["g"])])
			if o.get("c", "") != "":
				d["runs"].append([" · " + RN.pname(o["c"]) + " · " + bg_slot(o["s"]) + " 착용 중", f, 12, W])
				d["box"] = _box(it, RN.slot_kind(o["s"]), "bag")
				d["small"] = "바꾸거나 빼려면 캐릭터 창 장비 탭에서."
			else:
				d["runs"].append([" · " + ((it.get("cls", "") + " 무기") if it["slot"] == "weapon" else ((it["wt"] + " " + RN.SLOTN[it["slot"]]) if it.has("wt") else "장신구")), f, 12, W])
				d["box"] = _box(it, it["slot"], "bag")
				d["who"] = true
		"erune":
			var Rd: Dictionary = RN.RUNE[o["v"]]
			var it2: Dictionary = o["it"]
			d["runs"].append([RN.gname(Rd["g"]), f, 12, RN.gcol(Rd["g"])])
			d["runs"].append([" · " + ((RN.pname(o["c"]) + " · " + RN.SLOTN.get(o["s"], o["s"])) if o.get("c", "") != "" else "가방 속 장비") + "에 각인", f, 12, W])
			d["box"] = _box(it2, RN.slot_kind(o["s"]), "rune")
			d["small"] = "성급은 대장간 강화에서 올려요."
		"rune":
			var Rd2: Dictionary = RN.RUNE[o["v"]]
			d["runs"].append([RN.gname(Rd2["g"]), f, 12, RN.gcol(Rd2["g"])])
			d["runs"].append([" · " + rune_kind(o["v"]) + "\n" + Rd2["d"] + "\n", f, 12, W])
			d["runs"].append(["대장간에서 각인할 수 있어요.", f, 10, W])
		"sh": d["runs"].append(["길드에서 쓰는 화폐. 대장간 강화·각인·계승에 쓴다.", f, 12, W])
		"mem": d["runs"].append(["던전의 기억이 굳은 돌. 마을의 세계수에 넣어 캐릭터를 성장시킨다.", f, 12, W])
	return d

## effBox(it, kind, ctx): the faces as runs; tabs only when a rune is set
func _box(it: Dictionary, kind: String, ctx: String) -> Dictionary:
	var f := UI.noto()
	var b := {"ctx": ctx, "tabs": R().has_rune_item(it), "g": [[R().gear_text(it, kind), f, 12, Color.WHITE]], "r": []}
	if b["tabs"]:
		var r: String = it["rune"]
		var st := int(it.get("rs", 1))
		var Rd: Dictionary = RN.RUNE[r]
		b["r"] = [["[" + Rd["n"] + "]", f, 12, RN.gcol(Rd["g"])], [" " + RN.gname(Rd["g"]) + " · ★%d ×%s" % [st, RN.fmt(RN.RSM[st])], f, 11, Color(1, 1, 1, 0.72)], ["\n" + RN.rune_scaled(r, st), f, 12, Color.WHITE]]
		b["lab"] = "룬 효과 ★%d" % st
	return b

func _face(b: Dictionary) -> String:
	if not b["tabs"]: return "g"
	return rvm.get(b["ctx"], "g" if b["ctx"] == "bag" else "r")

## .nm: h2 and p inline (one line when both fit), then .bwho; -5° about its own centre; w_stamp .45 s --bk, 80 ms late
func _nm(vs: Vector2, sp: Rect2, o: Dictionary, g: Color) -> void:
	var nw := sp.size.x
	var bf := UI.bhs()
	var nm := oname(o)
	if o["kind"] == "gear": nm += " +%d" % int(o["v"].get("lv", 0))
	elif o["kind"] == "erune": nm += " ★%d" % int(o["it"].get("rs", 1))
	var h2w := tw(bf, nm, 26) + 24.0
	var h2h := 33.0
	var d := _info(o)
	var f := UI.noto()
	# the p: padding 4 10, line-height 1.5, max-width 100 %
	var maxw := nw - 20.0
	var l1: Array = flow(d["runs"], maxw)
	var box = d["box"]
	var fc := "g"
	var bl: Array = []
	var tabs_w := 0.0
	if box != null:
		fc = _face(box)
		bl = flow(box[fc], maxw)
		if box["tabs"]: tabs_w = tw(f, "장비 효과", 11) + 20.0 + 5.0 + tw(f, box["lab"], 11) + 20.0
	var sl: Array = flow([[d["small"], f, 10, Color.WHITE]], maxw) if d["small"] != "" else []
	var cw := maxf(flow_w(l1), maxf(flow_w(bl), maxf(tabs_w, flow_w(sl))))
	if box != null and fc == "r": cw = maxf(cw, flow_w(flow(box["g"], maxw)))
	var pw := minf(nw, cw + 20.0)
	var ph := 4.0 + l1.size() * 18.0 + (5.0 + (26.0 if box["tabs"] else 0.0) + bl.size() * 18.0 if box != null else 0.0) + sl.size() * 18.0 + 4.0
	var same := h2w + pw <= nw
	var py := 0.0 if same else h2h + 4.0
	var h2y := 0.0
	if same:
		# inline-blocks on one line sit on the baseline of their last line
		var h2b := 1.0 + 28.6
		var pb := 4.0 + 4.0 + 18.0 * (l1.size() + bl.size() + sl.size()) - 4.5
		var base := maxf(h2b, pb)
		h2y = base - h2b
		py = base - pb + 4.0
	var pbottom := py + ph
	var who_h := 0.0
	var W: Array = []
	if d["who"]:
		var it3: Dictionary = o["v"]
		W = arena.player.roster().filter(func(c): return it3["slot"] != "weapon" or it3.get("cls", "") == RN.CLS[c])
		if not W.has(who): who = arena.player.who if W.has(arena.player.who) else (W[0] if not W.is_empty() else "")
	var bw2: Array = _bw2(o, W) if d["who"] else []
	if d["who"]:
		who_h = 38.0 + 5.0
		var x := 0.0
		var rowh := 0.0
		for b in bw2:
			if x > 0.0 and x + b["w"] > nw:
				who_h += rowh + 5.0
				x = 0.0
			x += b["w"] + 5.0
			rowh = maxf(rowh, b["h"])
		who_h += rowh + 5.0 + 19.0
	var nh := maxf(h2y + h2h, pbottom) + (6.0 + who_h if d["who"] else 0.0)
	var top := sp.position.y + sp.size.y * 0.47
	var ks := UI.bk(clampf((pop_t - 80.0) / 450.0, 0.0, 1.0))
	var a := clampf((pop_t - 80.0) / 450.0, 0.0, 1.0)
	a = clampf(ks, 0.0, 1.0)
	var m := xf(Vector2(sp.position.x, top), Vector2(nw / 2.0, nh / 2.0), lerpf(-12.0, -5.0, ks), lerpf(2.2, 1.0, ks))
	# h2: padding 1 12 3, skewX(-10°)
	var hm := m * xf(Vector2(0, h2y), Vector2(h2w / 2.0, h2h / 2.0), 0.0, 1.0, -10.0)
	draw_colored_polygon(poly(Rect2(0, 0, h2w, h2h), SQ, hm), Color(0, 0, 0, a))
	draw_set_transform_matrix(hm)
	txt(self, bf, 12, 1, nm, 26, Color(1, 1, 1, a), 28.6)
	# p
	var pm := m * Transform2D(0.0, Vector2(h2w if same else 0.0, py))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(poly(Rect2(0, 0, pw, ph), SQ, pm), Color(0, 0, 0, a))
	draw_set_transform_matrix(pm)
	var y := 4.0
	draw_flow(self, l1, 10, y, 18.0, a)
	y += l1.size() * 18.0
	if box != null:
		y += 5.0
		var fl := clampf(flip_t / 180.0, 0.0, 1.0)
		var fx := 6.0 * (1.0 - UI.bez(0.2, 1.2, 0.4, 1.0, fl))
		var fa := lerpf(0.4, 1.0, UI.bez(0.2, 1.2, 0.4, 1.0, fl)) * a
		var by := y
		if box["tabs"]:
			var x := 10.0 + fx
			for tb in [["g", "장비 효과"], ["r", box["lab"]]]:
				var on: bool = fc == tb[0]
				var w := tw(f, tb[1], 11) + 20.0
				var tr := Rect2(x, y, w, 20.5)
				draw_set_transform(Vector2.ZERO)
				draw_colored_polygon(poly(tr, SQ, xf(Vector2.ZERO, tr.position + tr.size / 2.0, 0, 1, -10.0)), Color(1, 1, 1, fa) if on else Color(0.165, 0.165, 0.165, fa))
				txt(self, f, x + 10, y + 2, tb[1], 11, Color(0, 0, 0, fa) if on else Color(0.6, 0.6, 0.6, fa), 16.5)
				x += w + 5.0
			y += 26.0
		draw_set_transform_matrix(pm * Transform2D(0.0, Vector2(fx, 0)))
		draw_flow(self, bl, 10, y, 18.0, fa)
		draw_set_transform_matrix(pm)
		y += bl.size() * 18.0
		if box["tabs"]:
			var bx: Dictionary = box
			var gp := pm * Vector2(0, by)
			var gp2 := pm * Vector2(pw, y)
			h_back.append([poly(Rect2(0, by, pw, y - by), SQ, pm), func():
				rvm[bx["ctx"]] = "r" if _face(bx) == "g" else "g"
				flip_t = 0.0
				sfx("ui_ok", 0.5), "flip"])
	if not sl.is_empty():
		draw_flow(self, sl, 10, y, 18.0, a)
	draw_set_transform(Vector2.ZERO)
	if d["who"]: _bwho(m, maxf(h2y + h2h, pbottom) + 6.0, nw, o, W, bw2, a)

## .bw2 buttons: [slot, label, diffs] with their size
func _bw2(o: Dictionary, W: Array) -> Array:
	var it: Dictionary = o["v"]
	var out: Array = []
	if who == "": return out
	var f := UI.noto()
	for sl in RN.slots_for(it):
		var cur = R().gear[who][sl]
		var lab: String = (cur["n"] + " +%d" % int(cur.get("lv", 0))) if cur != null else "비어 있음"
		var diffs: Array = []
		for dd in R().gear_cmp(it, who, sl):
			diffs.append(["%s %s%s%s" % [dd[0], "+" if dd[1] > 0 else "−", RN.fmt(absf(dd[1])), dd[2]], Color("#7fe08a") if dd[1] > 0 else Color("#ff7a7a")])
		if diffs.is_empty(): diffs.append(["변화 없음", Color("#bbbbbb")])
		var dw := 0.0
		for q in diffs: dw += tw(f, q[0], 10) + 6.0
		var w := maxf(maxf(tw(UI.anton(false, 2), RN.SLOTN[sl], 9), tw(f, lab, 11)), dw - 6.0) + 24.0
		out.append({"sl": sl, "lab": lab, "diffs": diffs, "w": w, "h": 51.0})
	return out

## .bwho: faces (38 px, -3 px when picked), the slot buttons (tap = 장착), 녹이기
func _bwho(m: Transform2D, y0: float, nw: float, o: Dictionary, W: Array, bw2: Array, a: float) -> void:
	var it: Dictionary = o["v"]
	var f := UI.noto()
	var x := 0.0
	for c in W:
		var on: bool = c == who
		var k := UI.bez(0.2, 1.5, 0.4, 1.0, clampf(who_t / 250.0, 0.0, 1.0))
		var lift := (-3.0 * (k if (on and c == who) else (1.0 - k) if c == prev_who else (1.0 if on else 0.0))) if who_t < 250.0 else (-3.0 if on else 0.0)
		var op := (1.0 if on else 0.45) * a
		var r := Rect2(x, y0 + lift, 38, 38)
		var pts := poly(r, [[10, 0], [100, 0], [90, 100], [0, 100]], m)
		var tex: Texture2D = SK.face(c)
		var ts := tex.get_size()
		var s := maxf(38.0 / ts.x, 38.0 / ts.y)
		var uw := 38.0 / s / ts.x
		var uh := 38.0 / s / ts.y
		var uvs := PackedVector2Array()
		for q in [[0.1, 0], [1, 0], [0.9, 1], [0, 1]]: uvs.append(Vector2(0.5 - uw / 2.0 + uw * q[0], 0.5 - uh / 2.0 + uh * q[1]))
		draw_colored_polygon(pts, Color(0, 0, 0, op))
		draw_colored_polygon(pts, Color(1, 1, 1, op), uvs, tex)
		draw_colored_polygon(poly(Rect2(x, y0 + lift + 34, 38, 4), [[1, 0], [91, 0], [90, 100], [0, 100]], m), Color(UI.col(c), op))
		var cc: String = c
		h_back.append([pts, func():
			if who == cc: return
			prev_who = who
			who = cc
			who_t = 0.0
			pop_t = 0.0, "who%d" % W.find(cc)])
		x += 43.0
	var y := y0 + 38.0 + 5.0
	x = 0.0
	var rowh := 0.0
	for b in bw2:
		if x > 0.0 and x + b["w"] > nw:
			y += rowh + 5.0
			x = 0.0
		var r := Rect2(x, y, b["w"], b["h"])
		var pts := poly(r, [[4, 0], [100, 0], [96, 100], [0, 100]], m)
		draw_colored_polygon(pts, Color(0, 0, 0, a))
		draw_set_transform_matrix(m)
		txt(self, UI.anton(false, 2), x + 12, y + 4, RN.SLOTN[b["sl"]], 9, Color(ocol(o), a), 12.15)
		txt(self, f, x + 12, y + 4 + 12.15, b["lab"], 11, Color(1, 1, 1, a), 15.5)
		var dx := x + 12.0
		for q in b["diffs"]:
			dx += txt(self, f, dx, y + 4 + 12.15 + 15.5, q[0], 10, Color(q[1], a), 13.5) + 6.0
		draw_set_transform(Vector2.ZERO)
		var sl: String = b["sl"]
		var w3 := who
		h_back.append([pts, func():
			if R().gear_on(w3, sl, R().gearbag.find(it)):
				arena.text(arena.player.position + Vector2(0, -170), RN.pname(w3) + " · " + it["n"] + " 장착", Color("#ffe9a8"))
				sfx("ui_ok", 0.5)
				bg_rows(), "eq"])
		x += b["w"] + 5.0
		rowh = maxf(rowh, b["h"])
	y += rowh + 5.0
	# .bmelt: padding 2 10, rgba(0,0,0,.55), 10.5 px, skewX(-10°)
	var ml := "녹이기 · 실링 +%d%s" % [RN.melt_val(it), " · 룬은 가방으로" if R().has_rune_item(it) else ""]
	var mw := tw(f, ml, 10) + 20.0
	var mr := Rect2(0, y, mw, 19)
	var mm := m * xf(Vector2.ZERO, mr.position + mr.size / 2.0, 0, 1, -10.0)
	var mp := poly(mr, SQ, mm)
	draw_colored_polygon(mp, Color(0, 0, 0, 0.55 * a))
	draw_set_transform_matrix(mm)
	txt(self, f, 10, y + 2, ml, 10, Color(0.867, 0.867, 0.867, a), 15.0)
	draw_set_transform(Vector2.ZERO)
	h_back.append([mp, func():
		var i: int = R().gearbag.find(it)
		if i < 0: return
		R().melt(i)
		sfx("heavy", 0.5)
		bg_rows(), "melt"])


# ---------- .rows (clipped) ----------
func _list_h() -> float:
	var y := 0.0
	var last := ""
	for o in L:
		if o.has("grp") and o["grp"] != last:
			y += (8.0 if last != "" else 0.0) + 18.0 + 5.0 - (5.0 if last != "" else 0.0)
			last = o["grp"]
		y += (44.0 if o["kind"] == "erune" else 36.0) + 5.0
	return y

func _row_runs(o: Dictionary) -> Dictionary:
	var sub := ""
	var u := ""
	match o["kind"]:
		"gear":
			sub = ((RN.pname(o["c"]) + " · ") if o.get("c", "") != "" else "") + bg_slot(o["s"])
			u = (("★%d " % int(o["v"].get("rs", 1))) if R().has_rune_item(o["v"]) else "") + "Lv %d" % int(o["v"].get("lv", 0))
		"erune":
			sub = (RN.pname(o["c"]) if o.get("c", "") != "" else "가방") + " · " + bg_slot(o["s"]) + " · " + o["it"]["n"]
			u = "★%d" % int(o["it"].get("rs", 1))
		"rune": u = ("×%d" % o["n"]) if o["n"] > 1 else ""
		_: u = loc(int(o["v"]))
	return {"sub": sub, "u": u}

func _draw_rows() -> void:
	h_rows.clear()
	if not live(): return
	var ci := rows_ctl
	var org := rows_ctl.position
	var col := tcol()
	var f := UI.noto()
	var fa := UI.anton(true)
	var y := -scroll
	var el := rows_t
	if L.is_empty():
		# .bnone.st: padding 14, 13 px #aaa
		var e := _st(0)
		var s := "비어 있어요. 던전에서 구해 오세요."
		var bw := tw(f, s, 13) + 28.0
		ci.draw_set_transform_matrix(xf(Vector2(e["x"], 0), Vector2(bw / 2.0, 23.0), e["r"]))
		txt(ci, f, 14, 14, s, 13, Color(0.667, 0.667, 0.667, e["a"]), 19.0)
		ci.draw_set_transform(Vector2.ZERO)
		return
	var last := ""
	for i in L.size():
		var o: Dictionary = L[i]
		if o.has("grp") and o["grp"] != last:
			if last != "": y += 3.0
			last = o["grp"]
			var gl := "착용 중" if last == "on" else "가방"
			var gn := 0
			for q in L: if q.get("grp", "") == last: gn += 1
			var e := _st(st_idx[i] - 1)
			ci.draw_set_transform_matrix(xf(Vector2(4.0 + e["x"], y), Vector2(-4, 9), -4.0 + e["r"]))
			var hw := txt(ci, UI.spaced(UI.bhs(), 1), 0, 0, gl, 13, Color(col, e["a"]), 18.0)
			txt(ci, UI.bhs(), hw + 4.0, 0, str(gn), 13, Color(0.533, 0.533, 0.533, e["a"]), 18.0)
			ci.draw_set_transform(Vector2.ZERO)
			y += 18.0 + 5.0
		var two: bool = o["kind"] == "erune"
		var h := 44.0 if two else 36.0
		var rr := _row_runs(o)
		var nm := oname(o)
		var on := i == sel
		var bw := 0.0
		if two: bw = maxf(tw(f, nm, 13), tw(f, rr["sub"], 10))
		else: bw = (tw(f, rr["sub"], 10) + 7.0 if rr["sub"] != "" else 0.0) + tw(f, nm, 13)
		var uw := tw(fa, rr["u"], 16) if rr["u"] != "" else 0.0
		var w := 14.0 + 14.0 + 10.0 + bw + (10.0 + uw if rr["u"] != "" else 0.0) + 14.0
		if y + h > -60.0 and y < rows_ctl.size.y + 60.0:
			var j: int = st_idx[i]
			var k := _on_amt(i, j)
			var e := _st(j)
			var tx: float = lerpf(0.0, j * -6.0 + 26.0, k) + e["x"]
			var m := xf(Vector2(tx, y), Vector2(0, h / 2.0), -4.0 * k + e["r"], lerpf(1.0, 1.06, k))
			var white := on
			var pts := poly(Rect2(0, 0, w, h), [[2, 0], [100, 0], [98, 100], [0, 100]], m)
			ci.draw_colored_polygon(pts, Color(1, 1, 1, e["a"]) if white else Color(0.082, 0.082, 0.082, e["a"]))
			var gc := ocol(o)
			var gm := m * Transform2D(PI / 4.0, Vector2(21, h / 2.0))
			for gl2 in [[11.0, 0.12], [9.0, 0.22]]:
				ci.draw_colored_polygon(PackedVector2Array([gm * Vector2(-gl2[0], -gl2[0]), gm * Vector2(gl2[0], -gl2[0]), gm * Vector2(gl2[0], gl2[0]), gm * Vector2(-gl2[0], gl2[0])]), Color(gc, gl2[1] * e["a"]))
			ci.draw_colored_polygon(PackedVector2Array([gm * Vector2(-7, -7), gm * Vector2(7, -7), gm * Vector2(7, 7), gm * Vector2(-7, 7)]), Color(gc, e["a"]))
			var inr := PackedVector2Array([gm * Vector2(-5, -5), gm * Vector2(5, -5), gm * Vector2(5, 5), gm * Vector2(-5, 5), gm * Vector2(-5, -5)])
			ci.draw_polyline(inr, Color(1, 1, 1, 0.35 * e["a"]), 2.0)
			var fc := Color(0, 0, 0, e["a"]) if white else Color(1, 1, 1, e["a"])
			ci.draw_set_transform_matrix(m)
			if two:
				var ty := (h - (15.5 + 1.0 + 12.0)) / 2.0
				txt(ci, f, 38, ty, nm, 13, fc, 15.5)
				txt(ci, f, 38, ty + 16.5, rr["sub"], 10, Color(fc, 0.62 * e["a"]), 12.0)
			else:
				var xx := 38.0
				if rr["sub"] != "": xx += txt(ci, f, xx, (h - 18.0) / 2.0 + 1.0, rr["sub"], 10, Color(fc, 0.62 * e["a"]), 18.0) + 7.0
				txt(ci, f, xx, (h - 18.0) / 2.0, nm, 13, fc, 18.0)
			if rr["u"] != "":
				txt(ci, fa, w - 14.0 - uw, (h - 18.0) / 2.0, rr["u"], 16, Color(0, 0, 0, e["a"]) if white else Color(col, e["a"]), 18.0)
			ci.draw_set_transform(Vector2.ZERO)
			var ii := i
			var gp := PackedVector2Array()
			for q in pts: gp.append(q + org)
			h_rows.append([gp, func():
				if ii == sel: return
				_pick(ii)])
		y += h + 5.0

## .st entering: x / rotation offsets and opacity for stagger index j (from 50 px, 6°; .5 s --bk, opacity .3 s ease)
func _st(j: int) -> Dictionary:
	var e := rows_t - j * 40.0
	var k := UI.bk(clampf(e / 500.0, 0.0, 1.0))
	return {"x": 50.0 * (1.0 - k), "r": 6.0 * (1.0 - k), "a": AE.ez("ease", clampf(e / 300.0, 0.0, 1.0))}

## how far a row is into its .on transform (transition .5 s --bk after its own 40 ms × index delay)
func _on_amt(i: int, j: int) -> float:
	var k := UI.bk(clampf((sel_t - j * 40.0) / 500.0, 0.0, 1.0))
	if i == sel: return k if prev_sel >= 0 else 1.0
	if i == prev_sel: return 1.0 - k
	return 0.0


# ---------- the layer over the rows: title, cats, sub tabs, cash, ✕ ----------
func _draw_front() -> void:
	h_front.clear()
	if not live(): return
	var ci := front_ctl
	var vs := get_viewport_rect().size
	var col := tcol()
	var bf := UI.bhs()
	# .ttl (20, 14) -6° about its corner; b: padding 2 14 4 10, 34 px/1.05, skewX(-12°) (black on the band)
	var tm := xf(Vector2(20, 14), Vector2.ZERO, -6.0)
	var tw0 := tw(bf, "가방", 34) + 24.0
	var bm := tm * xf(Vector2(0, 12), Vector2(tw0 / 2.0, 21.0), 0, 1, -12.0)
	ci.draw_colored_polygon(poly(Rect2(0, 0, tw0, 42), SQ, bm), Color.BLACK)
	ci.draw_set_transform_matrix(bm)
	txt(ci, bf, 10, 2, "가방", 34, Color.WHITE, 35.7)
	# .cats (18, 24 %) -10° about its corner; buttons 22 px/1.15 #777, .on white ×1.35 + 8 px (.3 s --bk, colour .2 s)
	var cm := xf(Vector2(18, vs.y * 0.24), Vector2.ZERO, -10.0)
	var cw := 0.0
	for k in [["gear", "장비"], ["rune", "룬"], ["mat", "재화"]]:
		cw = maxf(cw, tw(bf, k[1], 22) + (tw(UI.noto(), "▶", 12) + 4.0 if cat == k[0] else 0.0))
	var cy := 0.0
	for k in [["gear", "장비"], ["rune", "룬"], ["mat", "재화"]]:
		var on: bool = cat == k[0]
		var kk := UI.bk(clampf(cat_t / 300.0, 0.0, 1.0))
		var kc := clampf(cat_t / 200.0, 0.0, 1.0)
		var amt := (kk if on else (1.0 - kk if k[0] == prev_cat else 0.0))
		var ca := (kc if on else (1.0 - kc if k[0] == prev_cat else 0.0))
		var m := cm * xf(Vector2(0, cy), Vector2(cw / 2.0, 12.65), 0.0, lerpf(1.0, 1.35, amt)) * Transform2D(0.0, Vector2(8.0 * amt, 0))
		ci.draw_set_transform_matrix(m)
		var x := 0.0
		if on:
			x += txt(ci, UI.noto(), 0, 1, "▶", 12, col, 25.3) + 4.0
		txt(ci, bf, x, 0, k[1], 22, Color(0.467, 0.467, 0.467).lerp(Color.WHITE, ca), 25.3)
		var key: String = k[0]
		h_front.append([poly(Rect2(0, 0, cw, 25.3), SQ, m), func(): _cat(key)])
		cy += 25.3
	ci.draw_set_transform(Vector2.ZERO)
	# .bsub (18 % + 30, 15 % - 40) -4° about its centre: .fsub buttons
	if cat == "gear" or cat == "rune":
		var A: Array
		if cat == "gear":
			var nr := 0
			for it in R().gearbag: if R().has_rune_item(it): nr += 1
			A = [["plain", "장비", R().gearbag.size() - nr], ["rune", "룬 각인 장비", nr + worn().size()]]
		else:
			A = [["bag", "보유 룬", R().rune_count()], ["set", "각인된 룬", engraved().size()]]
		var cur := gsub if cat == "gear" else rsub
		var f := UI.noto()
		var ws: Array = []
		var tot := 0.0
		for a in A:
			var w: float = tw(f, a[1], 13) + 5.0 + tw(f, str(a[2]), 13) + 28.0
			ws.append(w)
			tot += w + 6.0
		tot -= 6.0
		var nm := xf(Vector2(vs.x * 0.18 + 30.0, vs.y * 0.15 - 40.0), Vector2(tot / 2.0, 14.0), -4.0)
		var x := 0.0
		for i in A.size():
			var a: Array = A[i]
			var on: bool = a[0] == cur
			var w: float = ws[i]
			var m := nm * xf(Vector2(x, 0), Vector2(w / 2.0, 14.0), 0, 1, -12.0)
			if on: ci.draw_colored_polygon(poly(Rect2(3, 3, w, 28), SQ, m), col)
			var pts := poly(Rect2(0, 0, w, 28), SQ, m)
			ci.draw_colored_polygon(pts, Color.WHITE)
			if not on: ci.draw_colored_polygon(poly(Rect2(2, 2, w - 4, 24), SQ, m), Color.BLACK)
			ci.draw_set_transform_matrix(m)
			var tx0 := txt(ci, f, 14, 5, a[1], 13, Color.BLACK if on else Color(0.667, 0.667, 0.667), 18.2)
			txt(ci, f, 14 + tx0 + 5.0, 5, str(a[2]), 13, Color(0, 0, 0, 0.55) if on else Color(0.667, 0.667, 0.667, 0.55), 18.2)
			ci.draw_set_transform(Vector2.ZERO)
			var key: String = a[0]
			h_front.append([pts, func(): _sub(key)])
			x += w + 6.0
	# .cash (18, bottom 10) -4°: chips 14 px BHS, padding 2 10, skewX(-10°), the number in her colour
	var chips := [["실링 ", loc(R().iron)], ["기억석 ", str(R().mem)]]
	var cws: Array = []
	var ctot := 0.0
	for c2 in chips:
		var w2: float = tw(bf, c2[0], 14) + tw(bf, c2[1], 14) + 20.0
		cws.append(w2)
		ctot += w2 + 6.0
	ctot -= 6.0
	var km := xf(Vector2(18, vs.y - 10.0 - 22.0), Vector2(ctot / 2.0, 11.0), -4.0)
	var x2 := 0.0
	for i in chips.size():
		var m2 := km * xf(Vector2(x2, 0), Vector2(cws[i] / 2.0, 11.0), 0, 1, -10.0)
		ci.draw_colored_polygon(poly(Rect2(0, 0, cws[i], 22), SQ, m2), Color.BLACK)
		ci.draw_set_transform_matrix(m2)
		var a0 := txt(ci, bf, 10, 2, chips[i][0], 14, Color.WHITE, 18.0)
		txt(ci, bf, 10 + a0, 2, chips[i][1], 14, col, 18.0)
		ci.draw_set_transform(Vector2.ZERO)
		x2 += cws[i] + 6.0
	# ✕: right 14, top 12, 36 px
	var c := Vector2(vs.x - 14.0 - 18.0, 12.0 + 18.0)
	ci.draw_circle(c + Vector2(3, 3), 18.0, col)
	ci.draw_circle(c, 18.0, Color.WHITE)
	ci.draw_circle(c, 16.0, Color.BLACK)
	UI.cross(ci, c, 4.5, Color.WHITE, 2.0)
	h_front.append([Rect2(c - Vector2(18, 18), Vector2(36, 36)), back])


## script hook (capture / tests): tap the first hit area drawn with this tag
func tap(tag: String) -> bool:
	for h in h_back + h_rows + h_front:
		if h.size() > 2 and h[2] == tag:
			h[1].call()
			return true
	return false
