extends "res://scripts/ui_page.gd"
## 브랜의 대장간 — FORGE v2, four stations (prototype F2 / forge2.js): 강화 (a rune's ★ on the anvil), 각인 (one socket per
## piece, the old rune is destroyed), 합성 (three of a grade → one a grade up, odds by grade), 분해 (bag pieces → shilling).
## Tap the anvil to pick any equipped piece of the roster. Station changes wipe in the next station's colour; results stamp
## in (SUCCESS / MISS / ENGRAVED / FUSED / SALVAGED); a strike from ★6 up gets Bran's cut-in.
## Opened from the hub (back = sweep to the hub) or from Bran's choices (back = his choices again).

const ACTS := [["up", "강화", "ENHANCE"], ["eng", "각인", "ENGRAVE"], ["fuse", "합성", "FUSE"], ["dis", "분해", "SALVAGE"]]
const FBG := {"up": Color("#2b0f15"), "eng": Color("#1d1240"), "fuse": Color("#08283a"), "dis": Color("#202329")}
const POR := preload("res://assets/bran/por.png")
const HIT := preload("res://assets/bran/hit.webp")

var c := "estelle"
var slot := "weapon"
var p := "up"
var eng := 0
var fz := 0
var dis := {}
var ds := "plain"
var gs := "rune"
var picking := false
var pick_t := 0.0
var from_dlg := false
var busy := 0.0
var msg := ""
var msg_t := 0.0
var face := "r"
var wipe_t := -1.0
var wipe_to := ""
var stamps: Array = []
var strike_t := -1.0
var cut_t := -1.0
var jolt := 0.0
var sparks: Array = []
var list_off := 0.0
var pend: Callable


func _ready() -> void:
	super()
	keys = ["forge"]

func set_from_dlg(v: bool) -> void:
	from_dlg = v

func _opened() -> void:
	c = arena.player.who
	slot = "weapon"
	var G: Dictionary = R().gear[c]
	if G["weapon"] == null:
		for s in RN.SLOTS:
			if G[s[0]] != null:
				slot = s[0]
				break
	picking = false
	dis = {}
	busy = 0.0
	stamps.clear()
	wipe_t = -1.0
	say(["흐흐, 뭘 손봐 드릴까요?", "엄, 거기 올려 두십쇼. 어디 봅시다.", "룬 박으러 오셨지요? 화로는 달궈놨습니다.", "갑옷이 찌그러질 정도면, 맨몸이었으면 그냥 끝이었을 겁니다. 흐흐."][randi() % 4])
	if arena.level_kind() == "town" and arena.level.get("bran") != null:
		arena.level.bran.talk_t = 1500.0
		arena.level.bran.play("talk")

func cur():
	return R().gear[c][slot]

func say(s: String) -> void:
	msg = s
	msg_t = 0.0

func _tick(dt: float) -> void:
	msg_t += dt
	if busy > 0.0:
		busy -= dt
		if busy <= 0.0 and pend.is_valid():
			var f := pend
			pend = Callable()
			f.call()
	if wipe_t >= 0.0:
		wipe_t += dt
		if wipe_t >= 250.0 and p != wipe_to:
			p = wipe_to
			_station_in()
		if wipe_t >= 560.0: wipe_t = -1.0
	if strike_t >= 0.0:
		strike_t += dt
		if strike_t > 460.0: strike_t = -1.0
	if cut_t >= 0.0:
		cut_t += dt
		if cut_t > 900.0: cut_t = -1.0
	if picking: pick_t += dt
	jolt = maxf(0.0, jolt - dt)
	for s in stamps: s["t"] += dt
	stamps = stamps.filter(func(s): return s["t"] < 1300.0)
	for q in sparks:
		q["t"] += dt
		q["x"] += q["vx"] * dt
		q["y"] += q["vy"] * dt
		q["vy"] += 0.0012 * dt
	sparks = sparks.filter(func(q): return q["t"] < 700.0)

func go_station(np: String) -> void:
	if np == p or wipe_t >= 0.0 or busy > 0.0: return
	wipe_to = np
	wipe_t = 0.0
	list_off = 0.0
	sfx("ready", 0.25)

func _station_in() -> void:
	match p:
		"up": say(["쾅, 쾅. 이번엔 제대로 박아 보지요.", "흐흐, 뭘 손봐 드릴까요?", "엄, 거기 올려 두십쇼. 어디 봅시다."][randi() % 3] if cur() != null else "올릴 게 없군요. 모루를 눌러 골라 주십쇼.")
		"eng": say("룬 박으러 오셨지요? 화로는 달궈놨습니다." if cur() != null else "모루 쪽에서 장비부터 골라 주십쇼.")
		"fuse": say("셋을 녹이면 하나가 나옵니다. 운이 좋으면요. 흐흐.")
		"dis": say("부술 건 골라만 주십시오. 쇳물은 버리지 않습니다.")

func back() -> void:
	if busy > 0.0: return
	if picking:
		picking = false
		return
	menu.close_page()
	if from_dlg and not menu.from_hub:
		from_dlg = false
		menu.open_bran(true)

func _key(k: int) -> void:
	if k == KEY_ESCAPE: back()
	elif k in [KEY_Q, KEY_PAGEUP]: go_station(ACTS[(_pi() + 3) % 4][0])
	elif k in [KEY_E, KEY_PAGEDOWN, KEY_TAB]: go_station(ACTS[(_pi() + 1) % 4][0])
	elif k in [KEY_1, KEY_2, KEY_3, KEY_4]: go_station(ACTS[k - KEY_1][0])
	elif k in [KEY_UP, KEY_DOWN]:
		var d := -1 if k == KEY_UP else 1
		if p == "eng": eng = clampi(eng + d, 0, maxi(0, R().eng_list(c, slot).size() - 1))
		elif p == "fuse": fz = clampi(fz + d, 0, maxi(0, R().fuse_groups().size() - 1))
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		match p:
			"up": do_up()
			"eng": do_eng()
			"fuse": do_fuse()
			"dis": do_dis()

func _wheel(d: int, _pos: Vector2) -> void:
	list_off = maxf(0.0, list_off + d * 40.0)

func _pi() -> int:
	for i in 4:
		if ACTS[i][0] == p: return i
	return 0


# ---------- actions ----------
func stamp(s: String, fail: bool, sub := "", big := "") -> void:
	for o in stamps: o["t"] = maxf(o["t"], 850.0)
	stamps.append({"s": s, "fail": fail, "sub": sub, "big": big, "t": 0.0})

func burst(at: Vector2, n: int, col := Color("#ffd34d")) -> void:
	for i in n:
		var a := randf() * TAU
		var v := 0.15 + randf() * 0.35
		sparks.append({"x": at.x, "y": at.y, "vx": cos(a) * v, "vy": sin(a) * v - 0.1, "t": 0.0, "c": col})

func do_up() -> void:
	var it = cur()
	if busy > 0.0 or it == null: return
	if not R().has_rune_item(it):
		say("각인된 룬이 없습니다. 강화는 룬에 하는 겁니다.")
		return
	var lv := int(it.get("rs", 1))
	if lv >= RN.RMAX:
		say("★%d입니다. 더 올릴 데가 없지요. 흐흐." % RN.RMAX)
		return
	if R().iron < RN.rs_cost(lv):
		say("실링이 모자랍니다. 던전에서 좀 벌어 오십쇼.")
		sfx("guard", 0.4)
		return
	var rn: String = RN.RUNE[it["rune"]]["n"]
	busy = 700.0 if lv >= 6 else 360.0
	if lv >= 6: cut_t = 0.0
	strike_t = 0.0
	pend = func():
		var res: String = R().star_up(c, slot)
		var ok := res == "ok"
		var st := int(it.get("rs", 1))
		jolt = 300.0
		sfx("heavy", 0.7)
		stamp("SUCCESS" if ok else "MISS", not ok, ("[%s] ★%d" % [rn, st]) if ok else "룬이 안 받는다… (★ 유지)", ("★%d" % st) if ok else "")
		burst(_anvil_c(), 22)
		say((("★%d. 흐흐, 이건 좀 자랑해도 되겠는데요." % st) if st >= 6 else ("쾅, 쾅. ★%d 됐습니다." % st)) if ok else ["…룬이 안 받는군요. 다시 새겨 보지요.", "흠. 이번 건 망치가 비껴 맞았습니다.", "허, 금이 갈 뻔했습니다. 별은 그대로입니다."][randi() % 3])

func do_eng() -> void:
	var it = cur()
	var L: Array = R().eng_list(c, slot)
	if busy > 0.0 or it == null or L.is_empty(): return
	var r: String = L[mini(eng, L.size() - 1)]
	var cost := RN.engrave_cost(RN.RUNE[r]["g"])
	if R().iron < cost:
		say("실링이 모자랍니다.")
		return
	busy = 380.0
	pend = func():
		if R().engrave(c, slot, r):
			jolt = 300.0
			sfx("heavy", 0.6)
			burst(_anvil_c(), 16, RN.gcol(RN.RUNE[r]["g"]))
			stamp("ENGRAVED", false, "[%s] 각인 완료" % RN.RUNE[r]["n"])
			say("%s, 단단히 박아 뒀습니다. 흐흐, 이 정도면 변명이 좀 되겠지요?" % RN.RUNE[r]["n"])
			eng = mini(eng, maxi(0, R().eng_list(c, slot).size() - 1))

func do_fuse() -> void:
	var G: Array = R().fuse_groups()
	if busy > 0.0 or G.is_empty(): return
	var x: Dictionary = G[mini(fz, G.size() - 1)]
	var up := RN.up_grade(x["g"])
	if x["c"] < 3:
		say("셋은 있어야 녹이지요. 지금은 %d개뿐입니다." % x["c"])
		return
	if R().iron < RN.FUSE_COST:
		say("실링이 모자랍니다.")
		return
	busy = 420.0
	pend = func():
		var res: Dictionary = R().fuse(x["g"])
		if res.is_empty(): return
		jolt = 300.0
		if res["ok"]:
			sfx("heavy", 0.6)
			burst(_fuse_c(), 22, RN.gcol(up))
			stamp("FUSED", false, "%s [%s]" % [RN.gname(up), RN.RUNE[res["got"]]["n"]])
			say("나왔습니다. [%s]. %s급이군요. 흐흐." % [RN.RUNE[res["got"]]["n"], RN.gname(up)])
		else:
			sfx("guard", 0.6)
			stamp("MISS", true, "[%s] 하나만 남았다" % RN.RUNE[res["got"]]["n"])
			say(["…셋이 하나로 안 붙는군요. 하나는 건졌습니다.", "흠. 이번엔 녹기만 했습니다. 하나는 돌려드리지요."][randi() % 2])
		var L: Array = R().fuse_groups()
		fz = 0
		for i in L.size():
			if L[i]["g"] == x["g"]: fz = i

func do_dis() -> void:
	if busy > 0.0: return
	if dis.is_empty():
		say("뭘 부술지는 정해 주셔야지요.")
		return
	busy = 420.0
	pend = func():
		var sil: int = R().salvage(dis.keys())
		dis = {}
		jolt = 300.0
		sfx("heavy", 0.5)
		stamp("SALVAGED", false, "실링 +%d" % sil, "+%d" % sil)
		say("실링 %d. 장부에 달아 두지요." % sil)


# ---------- drawing ----------
func _anvil_c() -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(vs.x * 0.395, vs.y * 0.5)

func _fuse_c() -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(vs.x * 0.42, vs.y * 0.55)

func _paint(vs: Vector2) -> void:
	var col := UI.col(c)
	var sh := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * (jolt / 300.0)
	draw_set_transform(sh)
	var bg: Color = FBG[p]
	draw_rect(Rect2(Vector2.ZERO - Vector2(10, 10), vs + Vector2(20, 20)), bg)
	# the forge fire low on the left
	var gl := UI.glow()
	draw_texture_rect(gl, Rect2(vs.x * 0.1 - vs.y * 0.9, vs.y * 1.0 - vs.y * 0.9, vs.y * 1.8, vs.y * 1.8), false, Color(1.0, 0.45, 0.15, 0.32))
	UI.dots(self, Rect2(Vector2.ZERO, vs), 0.4, 1.0, Vector2(t / 300.0, 0))
	# the station's word, huge and hollow
	var bf := UI.anton(true)
	var word: String = (ACTS[_pi()][2] + " · ").repeat(4)
	draw_set_transform(sh + Vector2(-vs.x * 0.1, vs.y * 0.98), deg_to_rad(-8.0))
	draw_string_outline(UI.bhs(), Vector2.ZERO, word, HORIZONTAL_ALIGNMENT_LEFT, -1, int(vs.y * 0.42), 2, Color(1, 1, 1, 0.09))
	draw_set_transform(sh)
	if p == "fuse":
		draw_colored_polygon(PackedVector2Array([Vector2(vs.x * 0.44, vs.y * 0.06), Vector2(vs.x * 0.86, vs.y * 1.0), Vector2(vs.x * 0.02, vs.y * 1.0)]), Color(0, 0, 0, 0.45))
	# the slab on the right in her colour
	var slab := PackedVector2Array([Vector2(vs.x * 0.71, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x * 0.62, vs.y)])
	if p == "eng" or p == "fuse" or p == "dis":
		slab = PackedVector2Array([Vector2(vs.x * 0.79, 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(vs.x * 0.75, vs.y)])
	draw_colored_polygon(slab, col)
	UI.dots(self, Rect2(vs.x * 0.6, 0, vs.x * 0.4, vs.y), 0.18, 1.0)
	# station body
	match p:
		"up": _up(vs, col)
		"eng": _eng(vs, col)
		"fuse": _fuse(vs, col)
		"dis": _dis(vs, col)
	_title(vs)
	_rail(vs, col)
	_bubble(vs)
	for q in sparks:
		draw_rect(Rect2(q["x"] - 2, q["y"] - 2, 4, 4), Color(q["c"], 1.0 - q["t"] / 700.0))
	draw_set_transform(Vector2.ZERO)
	if picking: _pick(vs, col)
	_stamps(vs, col)
	if cut_t >= 0.0: _cut(vs, col)
	if wipe_t >= 0.0:
		# the next station's colour sweeps across, turning about the bottom-left corner
		var u := clampf(wipe_t / 500.0, 0.0, 1.0)
		var e := UI.bez(0.6, 0.02, 0.3, 1.0, u)
		var a := deg_to_rad(-91.0 + 91.0 * e) if wipe_t < 250.0 else deg_to_rad(91.0 * (e - 0.5) * 2.0)
		var piv := Vector2(0, vs.y)
		var L := vs.length() * 1.3
		var pts := PackedVector2Array([piv, piv + Vector2(L, 0).rotated(a), piv + Vector2(L, -L).rotated(a), piv + Vector2(0, -L).rotated(a)])
		draw_colored_polygon(pts, FBG[wipe_to])
		draw_polyline(PackedVector2Array([piv + Vector2(L, 0).rotated(a), piv]), col, 6.0)
	close_x(vs, back)

func _title(vs: Vector2) -> void:
	draw_set_transform(Vector2(26, 14), deg_to_rad(-6.0))
	draw_string(UI.spaced(UI.noto_k(), 3), Vector2(4, 12), "BRAN'S FORGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e8b25a"))
	var w := tw(UI.bhs(), "대장간", 34) + 26.0
	UI.para(self, 0, 16, w, 42, 6.0, Color.BLACK)
	draw_string(UI.bhs(), Vector2(12, 50), "대장간", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	var cs := "실링 "
	UI.para(self, 4, 60, tw(UI.noto_k(), cs, 12) + tw(UI.anton(true), str(R().iron), 15) + 22.0, 22, 4.0, Color.BLACK)
	draw_string(UI.noto_k(), Vector2(12, 76), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	draw_string(UI.anton(true), Vector2(12 + tw(UI.noto_k(), cs, 12), 77), str(R().iron), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffd34d"))
	draw_set_transform(Vector2.ZERO)

func _rail(vs: Vector2, col: Color) -> void:
	for i in 4:
		var on: bool = ACTS[i][0] == p
		var bw := vs.x * 0.16
		var bh := vs.y * 0.088
		var x := vs.x * 0.785 - i * 7.0 + (-0.03 * vs.x if on else 0.0)
		var y := vs.y * 0.31 + i * (bh + 9.0)
		var poly := PackedVector2Array([Vector2(x + 10, y), Vector2(x + bw + 10, y), Vector2(x + bw, y + bh), Vector2(x, y + bh)])
		if on: draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(5, 5), poly[1] + Vector2(5, 5), poly[2] + Vector2(5, 5), poly[3] + Vector2(5, 5)]), Color.BLACK)
		draw_colored_polygon(poly, Color.WHITE if on else Color.BLACK)
		draw_string(UI.anton(true), Vector2(x + 14, y + bh * 0.78), "0%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(bh * 0.62), Color.BLACK if on else col)
		draw_string(UI.spaced(UI.noto_k(), 2), Vector2(x + bw * 0.42, y + bh * 0.3), ACTS[i][2], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.6) if on else Color(1, 1, 1, 0.6))
		draw_string(UI.bhs(), Vector2(x + bw * 0.32, y + bh * 0.84), ACTS[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(bh * 0.5), Color.BLACK if on else Color.WHITE)
		var np: String = ACTS[i][0]
		hit(poly, func(): go_station(np))

func _bubble(vs: Vector2) -> void:
	var n := mini(msg.length(), int(msg_t / 28.0))
	var s := msg.substr(0, n)
	var f := UI.noto_k()
	var maxw := vs.x * 0.26
	var pos := Vector2(vs.x * 0.25, vs.y * 0.13) if p == "up" else Vector2(vs.x * 0.6, vs.y * 0.05)
	var fs := 12
	var h := paras_h(maxw, [[msg, fs, Color.BLACK, f]]) + 14.0
	var w := minf(maxw, tw(f, msg, fs)) + 24.0 + (34.0 if p != "up" else 0.0)
	var k := clampf(msg_t / 160.0, 0.0, 1.0)
	draw_set_transform(pos + Vector2(w / 2.0, h / 2.0), deg_to_rad(-6.0 + 6.0 * (1.0 - UI.bk(k))), Vector2.ONE * (0.6 + 0.4 * UI.bk(k)))
	var r := Rect2(-w / 2.0, -h / 2.0, w, h)
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(18, h - 1), r.position + Vector2(8, h + 10), r.position + Vector2(34, h - 1)]), Color.WHITE)
	draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.5))
	draw_rect(r, Color.WHITE)
	var tx0 := r.position.x + 12.0
	if p != "up":
		draw_circle(r.position + Vector2(20, h / 2.0), 15.0, Color.BLACK)
		draw_texture_rect_region(POR, Rect2(r.position + Vector2(7, h / 2.0 - 13.0), Vector2(26, 26)), Rect2(130, 40, 160, 160))
		tx0 += 32.0
	paras(self, tx0, r.position.y + 7.0, maxw, [[s, fs, Color.BLACK, f]])
	draw_set_transform(Vector2.ZERO)

## card: a black panel with a title, paragraphs, a cost line and a pink button
func card(r: Rect2, title: String, body: Array, cost: String, btn: String, disabled: bool, act: Callable, extra := Callable()) -> void:
	var col := UI.col(c)
	var y0 := r.position.y
	var inner_w := r.size.x - 36.0
	var bh := paras_h(inner_w, body)
	var eh := 0.0
	if extra.is_valid(): eh = extra.call(Vector2(-9999, -9999), inner_w, true)
	var h := 48.0 + bh + eh + (22.0 if cost != "" else 0.0) + (52.0 if btn != "" else 8.0)
	var rr := Rect2(r.position.x, y0, r.size.x, h)
	draw_set_transform(rr.get_center(), deg_to_rad(-2.0))
	var lr := Rect2(-rr.size / 2.0, rr.size)
	draw_rect(Rect2(lr.position + Vector2(6, 6), lr.size), Color(col, 0.9))
	draw_rect(lr, Color(0.03, 0.03, 0.04, 0.96))
	var x := lr.position.x + 18.0
	var y := lr.position.y + 34.0
	draw_string(UI.bhs(), Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 30.0, 20, Color.WHITE)
	y += 12.0
	y += paras(self, x, y, inner_w, body)
	if extra.is_valid(): y += extra.call(Vector2(x, y), inner_w, false)
	if cost != "":
		draw_string(UI.noto_k(), Vector2(x, y + 14.0), cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffb070"))
		y += 22.0
	if btn != "":
		var bw := tw(UI.bhs(), btn, 22) + 44.0
		var b := Rect2(x, y + 6.0, bw, 36.0)
		var poly := PackedVector2Array([b.position + Vector2(6, 0), b.position + Vector2(bw + 6, 0), b.position + Vector2(bw, 36), b.position + Vector2(0, 36)])
		var a := 0.4 if disabled else 1.0
		draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(4, 4), poly[1] + Vector2(4, 4), poly[2] + Vector2(4, 4), poly[3] + Vector2(4, 4)]), Color(1, 1, 1, a))
		draw_colored_polygon(poly, Color(col, a))
		draw_string(UI.bhs(), b.position + Vector2(22, 28), btn, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0, 0, 0, a))
		var xf := Transform2D(deg_to_rad(-2.0), rr.get_center())
		var wp := PackedVector2Array()
		for q in poly: wp.append(xf * q)
		if not disabled: hit(wp, act)
		else: hit(wp, act)
	draw_set_transform(Vector2.ZERO)

## the two-faced effect box (gear stats ↔ engraved rune); tap to flip
func eff_box(it: Dictionary, kind: String, rune_ps: Array, label: String) -> Callable:
	return func(at: Vector2, w: float, measure: bool) -> float:
		var has_r: bool = not rune_ps.is_empty()
		var gps: Array = [[gear_line(it, kind), 12, Color(0.85, 0.85, 0.85)]]
		var ps: Array = rune_ps if has_r and face == "r" else gps
		var h := (26.0 if has_r else 4.0) + paras_h(w, ps)
		if measure: return h
		var y := at.y
		if has_r:
			var x := at.x
			for tb in [["g", "장비 효과"], ["r", label]]:
				var on: bool = face == tb[0]
				var bw := tw(UI.noto(), tb[1], 11) + 20.0
				var poly := PackedVector2Array([Vector2(x + 3, y), Vector2(x + bw + 3, y), Vector2(x + bw, y + 18), Vector2(x, y + 18)])
				draw_colored_polygon(poly, Color.WHITE if on else Color(0.16, 0.16, 0.16))
				draw_string(UI.noto(), Vector2(x + 10, y + 13), tb[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK if on else Color(0.6, 0.6, 0.6))
				x += bw + 6.0
			y += 26.0
		paras(self, at.x, y, w, ps)
		return h

## the box's hit: anywhere on the card flips it (registered by the caller as a rect)
func _flip() -> void:
	face = "g" if face == "r" else "r"
	sfx("ready", 0.15)

func rune_ps(r: String, st: int, nx := 0) -> Array:
	var ps: Array = [[rune_head(r, st, nx), 11, RN.gcol(RN.RUNE[r]["g"])], [RN.rune_scaled(r, st), 12, Color.WHITE]]
	if nx > 0: ps.append(["▶ " + RN.rune_scaled(r, nx), 12, Color("#ffd34d")])
	return ps

func _up(vs: Vector2, col: Color) -> void:
	var it = cur()
	# Bran: the portrait, or the hammer pose on a strike
	var ph := vs.y * 0.92
	if strike_t >= 0.0 and strike_t < 380.0:
		var hw := ph * 1.05 * HIT.get_width() / HIT.get_height()
		var k := 1.0 + 0.04 * (1.0 - strike_t / 380.0)
		draw_texture_rect(HIT, Rect2(Vector2(-vs.x * 0.04, vs.y - ph * 1.05 * k), Vector2(hw, ph * 1.05) * k), false, Color(1, 1, 1) if strike_t > 90.0 else Color(4, 4, 4))
	else:
		var pw := ph * POR.get_width() / POR.get_height()
		draw_texture_rect(POR, Rect2(vs.x * 0.01, vs.y - ph + 18.0, pw, ph), false)
	# the anvil card
	var ac := _anvil_c()
	var g: Color = col
	var stt := "—"
	var nm := "장비 없음"
	if it != null:
		var has_r: bool = R().has_rune_item(it)
		g = RN.gcol(RN.RUNE[it["rune"]]["g"] if has_r else it["g"])
		stt = ("★%d" % int(it.get("rs", 1))) if has_r else "—"
		nm = RN.RUNE[it["rune"]]["n"] if has_r else it["n"] + " · 룬 없음"
	var cw := vs.y * 0.27
	var cr := Rect2(ac - Vector2(cw, cw) / 2.0, Vector2(cw, cw))
	var poly := rrect(cr, -8.0)
	draw_colored_polygon(rrect(Rect2(cr.position - Vector2(10, 6), cr.size + Vector2(20, 22)), -12.0), col)
	draw_colored_polygon(rrect(Rect2(cr.position - Vector2(6, 6), cr.size + Vector2(12, 12)), -8.0), Color.WHITE)
	draw_colored_polygon(poly, Color.BLACK)
	gem(self, ac, cw * 0.3, g)
	draw_string_outline(UI.anton(true), ac + Vector2(-cw * 0.32, -cw * 0.52), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 6, Color.BLACK)
	draw_string(UI.anton(true), ac + Vector2(-cw * 0.32, -cw * 0.52), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color.WHITE)
	var nw := tw(UI.noto_k(), nm, 13) + 46.0
	draw_set_transform(ac + Vector2(-cw * 0.62, cw * 0.62), deg_to_rad(-4.0))
	UI.para(self, 0, 0, nw, 24, 4.0, Color.BLACK)
	draw_string(UI.noto_k(), Vector2(10, 17), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_string(UI.anton(), Vector2(nw - 28, 17), "TAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))
	draw_set_transform(Vector2.ZERO)
	hit(rrect(Rect2(cr.position - Vector2(10, 40), cr.size + Vector2(20, 80)), -8.0), func():
		if busy <= 0.0:
			picking = true
			pick_t = 0.0
			gs = "rune"
			sfx("ready", 0.3))
	# the card
	var r := Rect2(vs.x * 0.445, vs.y * 0.38, vs.x * 0.315, 0)
	if it == null:
		card(r, "빈 칸", [[RN.SLOTN[slot] + " 칸이 비어 있습니다.", 12, Color(0.85, 0.85, 0.85)], ["모루를 눌러 장비를 고르세요.", 12, Color(0.85, 0.85, 0.85)]], "", "", true, func(): pass)
		return
	if not R().has_rune_item(it):
		card(r, it["n"], [["각인된 룬이 없습니다.", 12, Color(0.85, 0.85, 0.85)], ["강화는 룬에 합니다. 각인부터 해 주십쇼.", 12, Color(0.85, 0.85, 0.85)]], "", "각인으로", false, func(): go_station("eng"), eff_box(it, RN.slot_kind(slot), [], ""))
		return
	var st := int(it.get("rs", 1))
	var mx := st >= RN.RMAX
	var cost := RN.rs_cost(st)
	var head := ("★%d · 최대 성급" % RN.RMAX) if mx else ("★%d → ★%d · 성공 확률 %d%%" % [st, st + 1, RN.rs_rate(st)])
	var lbl := ("룬 ★%d" % st) + ("" if mx else " → ★%d" % (st + 1))
	var body: Array = [[head, 12, Color(0.85, 0.85, 0.85)]]
	var tail: Array = [[RN.pname(c) + " · " + RN.SLOTN[slot] + ("" if mx else " · 실패해도 성급은 그대로"), 11, Color(0.6, 0.6, 0.6)]]
	var box := eff_box(it, RN.slot_kind(slot), rune_ps(it["rune"], st, 0 if mx else st + 1), lbl)
	var ex := func(at: Vector2, w: float, measure: bool) -> float:
		var h0: float = box.call(at, w, measure)
		if measure: return h0 + paras_h(w, tail)
		hit(Rect2(at, Vector2(w, h0)), _flip)
		return h0 + paras(self, at.x, at.y + h0, w, tail)
	card(r, RN.RUNE[it["rune"]]["n"], body, "" if mx else ("실링 %d%s" % [cost, " · 모자랍니다" if R().iron < cost else ""]), "MAX" if mx else "때린다!", mx or R().iron < cost, do_up, ex)

## rows of runes / groups on the left (rlist)
func rlist(vs: Vector2, rows: Array, sel: int, on_pick: Callable) -> void:
	var x0 := vs.x * 0.08
	var y := vs.y * 0.19 - list_off
	var w := vs.x * 0.26
	if rows.is_empty():
		draw_string(UI.noto_k(), Vector2(x0, y + 30.0), "맞는 룬이 없습니다.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
		return
	for i in rows.size():
		var o: Dictionary = rows[i]
		var on := i == sel
		var h := 50.0
		var x := x0 + (i % 4) * 4.0 + (-8.0 if on else 0.0)
		if y > -h and y < vs.y:
			var poly := PackedVector2Array([Vector2(x, y), Vector2(x + w + 10.0, y), Vector2(x + w, y + h), Vector2(x, y + h)])
			draw_colored_polygon(poly, Color.WHITE if on else Color(0.04, 0.04, 0.05, 0.92))
			draw_rect(Rect2(x, y, 4, h), o["col"])
			if o.get("dim", false) and not on: draw_colored_polygon(poly, Color(0, 0, 0, 0.45))
			gem(self, Vector2(x + 22, y + 16), 8.0, o["col"])
			var fc := Color.BLACK if on else Color.WHITE
			draw_string(UI.noto_k(), Vector2(x + 42, y + 21), o["n"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fc)
			draw_string(UI.noto(), Vector2(x + 48 + tw(UI.noto_k(), o["n"], 14), y + 20), o["gn"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, o["col"].darkened(0.2) if on else o["col"])
			if o["cnt"] != "": draw_string(UI.anton(true), Vector2(x + w - 34, y + 24), o["cnt"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, fc)
			draw_string(UI.noto(), Vector2(x + 42, y + 39), o["e"], HORIZONTAL_ALIGNMENT_LEFT, w - 50.0, 10, Color(0, 0, 0, 0.7) if on else Color(1, 1, 1, 0.65))
			var ii := i
			hit(poly, func(): on_pick.call(ii))
		y += h + 8.0

func _eng(vs: Vector2, col: Color) -> void:
	var it = cur()
	var L: Array = R().eng_list(c, slot)
	if eng >= L.size(): eng = 0
	var rows: Array = []
	for r in L:
		var Rd: Dictionary = RN.RUNE[r]
		rows.append({"n": Rd["n"], "gn": RN.gname(Rd["g"]), "col": RN.gcol(Rd["g"]), "cnt": "×%d" % R().runebag[r], "e": Rd["d"]})
	rlist(vs, rows, eng, func(i): eng = i; sfx("ready", 0.15))
	# the socket circle
	var cc := Vector2(vs.x * 0.44, vs.y * 0.56)
	var rad := vs.y * 0.2
	for i in 36:
		var a := float(i) / 36.0 * TAU + t / 4000.0
		draw_line(cc + Vector2(cos(a), sin(a)) * rad, cc + Vector2(cos(a), sin(a)) * (rad + 8.0), Color(1, 1, 1, 0.5), 2.0)
	var ir := Rect2(cc - Vector2(rad, rad) * 0.62, Vector2(rad, rad) * 1.24)
	draw_colored_polygon(rrect(Rect2(ir.position - Vector2(8, 4), ir.size + Vector2(16, 16)), -12.0), col)
	draw_colored_polygon(rrect(ir.grow(5), -8.0), Color.WHITE)
	draw_colored_polygon(rrect(ir, -8.0), Color.BLACK)
	gem(self, cc, rad * 0.3, RN.gcol(it["g"]) if it != null else Color(0.4, 0.4, 0.4))
	var sk := cc + Vector2(-rad * 0.1, -rad * 1.05)
	if it != null and R().has_rune_item(it): gem(self, sk, 16.0, RN.gcol(RN.RUNE[it["rune"]]["g"]))
	else:
		draw_arc(sk, 16.0, 0, TAU, 24, Color(1, 1, 1, 0.5 + 0.3 * sin(t / 200.0)), 2.0)
	var nm: String = ("%s Lv %d" % [it["n"], int(it.get("lv", 0))]) if it != null else "장비 없음"
	draw_set_transform(cc + Vector2(-rad * 0.9, rad * 0.9), deg_to_rad(-4.0))
	UI.para(self, 0, 0, tw(UI.noto_k(), nm, 13) + 24.0, 24, 4.0, Color.BLACK)
	draw_string(UI.noto_k(), Vector2(10, 17), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	hit(Rect2(cc - Vector2(rad, rad), Vector2(rad, rad) * 2.0), func():
		if busy <= 0.0:
			picking = true
			pick_t = 0.0
			gs = "rune" if it != null and R().has_rune_item(it) else "plain")
	var r := Rect2(vs.x * 0.44, vs.y * 0.34, vs.x * 0.33, 0)
	if it == null:
		card(r, "빈 칸", [["각인할 장비가 없습니다.", 12, Color(0.85, 0.85, 0.85)]], "", "", true, func(): pass)
		return
	if L.is_empty():
		card(r, "룬 없음", [["이 칸에 맞는 룬이 가방에 없습니다.", 12, Color(0.85, 0.85, 0.85)]], "", "", true, func(): pass, eff_box(it, RN.slot_kind(slot), [], ""))
		return
	var rn: String = L[eng]
	var Rd: Dictionary = RN.RUNE[rn]
	var cost := RN.engrave_cost(Rd["g"])
	var has_old: bool = R().has_rune_item(it)
	var cmp: Array = [["지금 · " + (rune_head(it["rune"], int(it.get("rs", 1))) if has_old else "빈 홈"), 11, Color(0.75, 0.75, 0.75)]]
	if has_old: cmp.append([RN.rune_scaled(it["rune"], int(it.get("rs", 1))), 12, Color(0.85, 0.85, 0.85)])
	cmp.append(["새로 · " + rune_head(rn, 1), 11, Color("#ffd34d")])
	cmp.append([RN.rune_scaled(rn, 1), 12, Color.WHITE])
	if has_old: cmp.append(["기존 룬 [%s]%s 파괴됩니다" % [RN.RUNE[it["rune"]]["n"], ("] ★%d은(는) 성급째" % int(it["rs"])).substr(1) if int(it.get("rs", 1)) > 1 else "은(는)"], 11, Color("#ff6a6a")])
	var box := eff_box(it, RN.slot_kind(slot), cmp, "룬 비교")
	var ex := func(at: Vector2, w: float, measure: bool) -> float:
		var h0: float = box.call(at, w, measure)
		if not measure: hit(Rect2(at, Vector2(w, h0)), _flip)
		return h0
	card(r, "[%s]" % Rd["n"], [], "실링 %d%s" % [cost, " · 모자랍니다" if R().iron < cost else ""], "새긴다!", R().iron < cost, do_eng, ex)

func _fuse(vs: Vector2, col: Color) -> void:
	var G: Array = R().fuse_groups()
	if fz >= G.size(): fz = 0
	var rows: Array = []
	for x in G:
		var up := RN.up_grade(x["g"])
		rows.append({"n": RN.gname(x["g"]) + " 룬", "gn": RN.gname(x["g"]), "col": RN.gcol(x["g"]), "cnt": "×%d" % x["c"], "e": "3개 → %s 룬 1개 · 성공 %d%%" % [RN.gname(up), RN.FZRATE[up]], "dim": x["c"] < 3})
	rlist(vs, rows, fz, func(i): fz = i; sfx("ready", 0.15))
	var x0 = G[fz] if not G.is_empty() else null
	var gc: Color = RN.gcol(x0["g"]) if x0 != null else Color(0.4, 0.4, 0.4)
	var top := Vector2(vs.x * 0.42, vs.y * 0.34)
	var bl := Vector2(vs.x * 0.34, vs.y * 0.74)
	var br := Vector2(vs.x * 0.50, vs.y * 0.74)
	var mid := _fuse_c()
	for q in [top, bl, br]: draw_line(q, mid, Color(1, 1, 1, 0.35), 2.0)
	var k := 0
	for q in [top, bl, br]:
		var hexp := PackedVector2Array()
		for i in 6: hexp.append(q + Vector2(cos(i * PI / 3.0), sin(i * PI / 3.0)) * 30.0)
		draw_colored_polygon(hexp, Color.BLACK)
		hexp.append(hexp[0])
		draw_polyline(hexp, Color.WHITE, 2.0)
		var have: bool = x0 != null and k < x0["c"]
		if have: gem(self, q, 14.0 * (1.0 if busy <= 0.0 else maxf(0.2, busy / 420.0)), gc)
		k += 1
	var sr := Rect2(mid - Vector2(40, 40), Vector2(80, 80))
	draw_colored_polygon(rrect(sr.grow(14), 12.0), Color(1, 1, 1, 0.92))
	draw_colored_polygon(rrect(sr.grow(6), -6.0), col)
	draw_colored_polygon(rrect(sr, -6.0), Color(0.06, 0.06, 0.08))
	for i in 8:
		draw_line(sr.position + Vector2(i * 10, 0), sr.position + Vector2(0, i * 10), Color(1, 1, 1, 0.08), 2.0)
	if x0 != null:
		var lab := RN.gname(RN.up_grade(x0["g"])) + " ?"
		draw_set_transform(top + Vector2(-34, 38), deg_to_rad(-4.0))
		UI.para(self, 0, 0, tw(UI.noto_k(), lab, 12) + 20.0, 20, 3.0, Color.BLACK)
		draw_string(UI.noto_k(), Vector2(8, 15), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	var r := Rect2(vs.x * 0.55, vs.y * 0.56, vs.x * 0.23, 0)
	if x0 == null:
		card(r, "룬 없음", [["합성할 룬이 없습니다.", 12, Color(0.85, 0.85, 0.85)], ["고유·전설 룬은 합성할 수 없습니다.", 12, Color(0.85, 0.85, 0.85)]], "", "", true, func(): pass)
		return
	var up2 := RN.up_grade(x0["g"])
	card(r, "%s 룬 ×3" % RN.gname(x0["g"]), [["%s 3개 → %s 1개 (무작위)" % [RN.gname(x0["g"]), RN.gname(up2)], 12, Color(0.85, 0.85, 0.85)], ["성공 %d%% · 실패 시 1개 반환" % RN.FZRATE[up2], 12, Color(0.85, 0.85, 0.85)], ["보유 %d개" % x0["c"], 12, Color(0.85, 0.85, 0.85)]],
		"실링 %d%s" % [RN.FUSE_COST, " · 모자랍니다" if R().iron < RN.FUSE_COST else ""], "녹인다!", x0["c"] < 3 or R().iron < RN.FUSE_COST, do_fuse)

func _dis(vs: Vector2, col: Color) -> void:
	var bag: Array = R().gearbag
	var panel := PackedVector2Array([Vector2(vs.x * 0.02, vs.y * 0.2), Vector2(vs.x * 0.58, vs.y * 0.12), Vector2(vs.x * 0.58, vs.y * 0.9), Vector2(vs.x * 0.02, vs.y * 0.9)])
	draw_colored_polygon(panel, Color(0.05, 0.05, 0.06, 0.85))
	var n_r := 0
	for d in bag: if R().has_rune_item(d): n_r += 1
	var x := vs.x * 0.04
	x += tab_btn(Vector2(x, vs.y * 0.22), "장비", bag.size() - n_r, ds == "plain", func(): ds = "plain"; sfx("ready", 0.2))
	tab_btn(Vector2(x, vs.y * 0.22), "룬 각인 장비", n_r, ds == "rune", func(): ds = "rune"; sfx("ready", 0.2))
	var V: Array = []
	for i in bag.size():
		if (ds == "rune") == R().has_rune_item(bag[i]): V.append(i)
	var tw0 := vs.x * 0.14
	var th := vs.y * 0.2
	if V.is_empty():
		var msg2 := ("룬을 박은 장비가 가방에 없습니다." if ds == "rune" else "룬 없는 장비가 가방에 없습니다.") if not bag.is_empty() else "가방에 분해할 장비가 없습니다."
		draw_string(UI.noto_k(), Vector2(vs.x * 0.06, vs.y * 0.4), msg2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
		if bag.is_empty(): draw_string(UI.noto(), Vector2(vs.x * 0.06, vs.y * 0.45), "던전에서 얻은 장비가 여기 쌓입니다.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.5))
	for k in V.size():
		var i: int = V[k]
		var d: Dictionary = bag[i]
		var sel := dis.has(i)
		var gx := vs.x * 0.035 + (k % 3) * (tw0 + 10.0)
		var gy := vs.y * 0.31 + int(k / 3) * (th + 10.0) - list_off
		if gy > vs.y * 0.9 or gy < vs.y * 0.2: continue
		var rr := Rect2(gx, gy, tw0, th)
		var poly := rrect(rr, 1.5 if k % 2 else -2.0)
		if sel: draw_colored_polygon(rrect(rr.grow(4), 1.5 if k % 2 else -2.0), col)
		draw_colored_polygon(poly, Color(0.1, 0.1, 0.12) if not sel else Color(0.2, 0.08, 0.12))
		draw_rect(Rect2(gx, gy, tw0, 4), RN.gcol(d["g"]))
		gem(self, Vector2(gx + 26, gy + 34), 11.0, RN.gcol(d["g"]))
		var lvs := ("★%d" % int(d.get("rs", 1))) if R().has_rune_item(d) else ("Lv %d" % int(d.get("lv", 0)))
		draw_string(UI.anton(true), Vector2(gx + tw0 - 8 - tw(UI.anton(true), lvs, 18), gy + 30), lvs, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.9))
		draw_string(UI.noto_k(), Vector2(gx + 12, gy + th - 30), d["n"], HORIZONTAL_ALIGNMENT_LEFT, tw0 - 16.0, 13, Color.WHITE)
		var sub2: String = ("[%s]" % RN.RUNE[d["rune"]]["n"]) if R().has_rune_item(d) else (RN.gname(d["g"]) + " · " + RN.SLOTN.get(d.get("slot", ""), "").replace(" 1", ""))
		draw_string(UI.noto(), Vector2(gx + 12, gy + th - 12), sub2, HORIZONTAL_ALIGNMENT_LEFT, tw0 - 16.0, 10, Color(1, 1, 1, 0.55))
		var ii := i
		hit(poly, func():
			if dis.has(ii): dis.erase(ii)
			else: dis[ii] = 1
			sfx("ready", 0.15))
	var S: Array = []
	var sil := 0
	for i in dis.keys():
		if i < bag.size():
			S.append(bag[i])
			sil += RN.melt_val(bag[i])
	var r := Rect2(vs.x * 0.55, vs.y * 0.6, vs.x * 0.22, 0)
	if S.is_empty():
		card(r, "분해", [["부술 장비를 골라 주세요.", 12, Color(0.85, 0.85, 0.85)], ["등급과 강화 수치가 높을수록 많이 나옵니다.", 12, Color(0.85, 0.85, 0.85)]], "", "부순다!", true, do_dis)
	else:
		var b: Array = [["획득: 실링 +%d" % sil, 12, Color(0.85, 0.85, 0.85)]]
		if S.any(func(d): return R().has_rune_item(d)): b.append(["박힌 룬은 가방으로 돌아갑니다 (성급은 초기화)", 11, Color(0.75, 0.75, 0.75)])
		card(r, "%d개 선택" % S.size(), b, "", "부순다!", false, do_dis, eff_box(S[0], S[0].get("slot", "weapon"), [], "") if S.size() == 1 else Callable())

## tap the anvil: every equipped piece across the roster
func _pick(vs: Vector2, col: Color) -> void:
	var e := UI.bez(0.16, 1.0, 0.3, 1.0, clampf(pick_t / 340.0, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.35 * e))
	hit(Rect2(Vector2.ZERO, vs), func(): picking = false)
	var off := -vs.x * 0.5 * (1.0 - e)
	draw_colored_polygon(PackedVector2Array([Vector2(off, 0), Vector2(off + vs.x * 0.49, 0), Vector2(off + vs.x * 0.41, vs.y), Vector2(off, vs.y)]), col)
	var panel := PackedVector2Array([Vector2(off, 0), Vector2(off + vs.x * 0.46, 0), Vector2(off + vs.x * 0.38, vs.y), Vector2(off, vs.y)])
	draw_colored_polygon(panel, Color(0.02, 0.02, 0.03, 0.97))
	hit(panel, func(): pass)
	draw_string(UI.spaced(UI.noto_k(), 3), Vector2(off + 20, 28), "SELECT GEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e8b25a"))
	draw_string(UI.noto_k(), Vector2(off + 20, 62), "모루에 올릴 장비", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	var L: Array = []
	for cc in RN.ROSTER:
		for s in RN.SLOTS:
			var it = R().gear[cc][s[0]]
			if it != null: L.append([cc, s[0], it])
	var nr := L.filter(func(x): return R().has_rune_item(x[2])).size()
	var x := off + 20.0
	x += tab_btn(Vector2(x, 76), "룬 각인", nr, gs == "rune", func(): gs = "rune"; sfx("ready", 0.2))
	tab_btn(Vector2(x, 76), "룬 없음", L.size() - nr, gs == "plain", func(): gs = "plain"; sfx("ready", 0.2))
	var V := L.filter(func(q): return (gs == "rune") == R().has_rune_item(q[2]))
	var y := 112.0
	if V.is_empty():
		draw_string(UI.noto_k(), Vector2(off + 24, y + 24), "룬을 박은 장비가 없습니다." if gs == "rune" else "모든 장비에 룬이 박혀 있습니다.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6))
	for i in V.size():
		var q: Array = V[i]
		var it: Dictionary = q[2]
		var on: bool = q[0] == c and q[1] == slot
		var w := vs.x * 0.37 - i * 0.0
		var h := 42.0
		var xx := off + 20.0 + (16.0 if on else 0.0)
		var ee := UI.bk(clampf((pick_t - 120.0 - mini(i, 8) * 35.0) / 380.0, 0.0, 1.0))
		xx -= 60.0 * (1.0 - ee)
		var poly := PackedVector2Array([Vector2(xx, y), Vector2(xx + w + 8.0, y), Vector2(xx + w, y + h), Vector2(xx, y + h)])
		var hr: bool = R().has_rune_item(it)
		var gc := RN.gcol(RN.RUNE[it["rune"]]["g"] if hr else it["g"])
		draw_colored_polygon(poly, Color(1, 1, 1, ee) if on else Color(0.12, 0.12, 0.14, ee))
		draw_rect(Rect2(xx, y, 4, h), Color(gc, ee))
		gem(self, Vector2(xx + 22, y + 15), 8.0, RN.gcol(it["g"]))
		var fc := Color(0, 0, 0, ee) if on else Color(1, 1, 1, ee)
		draw_string(UI.noto_k(), Vector2(xx + 46, y + 19), it["n"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fc)
		draw_string(UI.noto(), Vector2(xx + 52 + tw(UI.noto_k(), it["n"], 14), y + 18), RN.gname(it["g"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RN.gcol(it["g"]))
		var rs := ("★%d" % int(it.get("rs", 1))) if hr else ("Lv %d" % int(it.get("lv", 0)))
		draw_string(UI.anton(true), Vector2(xx + w - 40, y + 26), rs, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, fc)
		var sub2: String = RN.pname(q[0]) + " · " + RN.SLOTN[q[1]] + ((" · [%s]" % RN.RUNE[it["rune"]]["n"]) if hr else (" · Lv %d" % int(it.get("lv", 0))))
		draw_string(UI.noto(), Vector2(xx + 46, y + 35), sub2, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.6 * ee) if on else Color(1, 1, 1, 0.6 * ee))
		var cc2: String = q[0]
		var s2: String = q[1]
		hit(poly, func():
			picking = false
			if cc2 == c and s2 == slot: return
			c = cc2
			slot = s2
			eng = 0
			jolt = 200.0
			sfx("heavy", 0.3)
			say("[%s]이요? 좋지요. 올려 보지요." % R().gear[c][slot]["n"]))
		y += h + 6.0

func _stamps(vs: Vector2, col: Color) -> void:
	for o in stamps:
		var k: float = o["t"]
		var out := clampf((k - 850.0) / 300.0, 0.0, 1.0)
		var inn := UI.bez(0.16, 1.0, 0.3, 1.0, clampf(k / 220.0, 0.0, 1.0))
		var c0 := Vector2(vs.x * 0.5, vs.y * 0.46)
		draw_set_transform(c0, deg_to_rad(-8.0))
		var bw := vs.x * 1.3
		var x1 := -bw / 2.0 + (1.0 - inn) * -bw + out * bw
		var x2 := -bw / 2.0 + (1.0 - inn) * bw - out * bw
		draw_rect(Rect2(x1, -58, bw, 116), Color(0, 0, 0, 0.88))
		draw_rect(Rect2(x2, -44, bw, 88), col if not o["fail"] else Color(0.35, 0.35, 0.4))
		var s: String = o["s"]
		var fs := 76
		var f := UI.anton(true)
		var w := tw(f, s, fs)
		var x := -w / 2.0
		for i in s.length():
			var ch := s.substr(i, 1)
			var d := k - 110.0 - i * 34.0
			var a := clampf(d / 200.0, 0.0, 1.0) * (1.0 - out)
			if a > 0.0:
				var sc := 1.0 + 1.8 * (1.0 - UI.bk(clampf(d / 200.0, 0.0, 1.0))) if not o["fail"] else 1.0
				var yy := (-0.6 * fs * (1.0 - clampf(d / 260.0, 0.0, 1.0))) if o["fail"] else 0.0
				draw_set_transform(c0 + Vector2(x + tw(f, ch, fs) / 2.0, 24.0 + yy).rotated(deg_to_rad(-8.0)), deg_to_rad(-8.0), Vector2(sc, sc))
				draw_string_outline(f, Vector2(-tw(f, ch, fs) / 2.0, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(0, 0, 0, a))
				draw_string(f, Vector2(-tw(f, ch, fs) / 2.0, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
			x += tw(f, ch, fs)
		draw_set_transform(c0, deg_to_rad(-8.0))
		var sa := clampf((k - 360.0) / 300.0, 0.0, 1.0) * (1.0 - out)
		if o["sub"] != "" and sa > 0.0:
			var sw := tw(UI.noto_k(), o["sub"], 15) + 24.0
			UI.para(self, -sw / 2.0, 52, sw, 26, 4.0, Color(0, 0, 0, sa))
			draw_string(UI.noto_k(), Vector2(-sw / 2.0 + 12, 71), o["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, sa))
		if o["big"] != "":
			var ba := clampf((k - 60.0) / 380.0, 0.0, 1.0) * (1.0 - out)
			draw_string(UI.anton(true), Vector2(-w / 2.0, -70), o["big"], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color("#ffd34d", ba))
		draw_set_transform(Vector2.ZERO)
	if not stamps.is_empty() and stamps[-1]["t"] < 240.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, 0.7 * (1.0 - stamps[-1]["t"] / 240.0)))

## Bran's cut-in (★6 and up): three bands slide in, his hammer pose slams over them
func _cut(vs: Vector2, col: Color) -> void:
	var k := cut_t
	var e := UI.bez(0.2, 0.8, 0.3, 1.0, clampf(k / 340.0, 0.0, 1.0))
	var a := 1.0 - clampf((k - 660.0) / 220.0, 0.0, 1.0)
	var c0 := Vector2(vs.x * 0.5, vs.y * 0.5)
	draw_set_transform(c0 + Vector2(vs.x * 0.3 * (1.0 - e), 0), deg_to_rad(-8.0))
	draw_rect(Rect2(-vs.x, -vs.y * 0.3, vs.x * 2.0, vs.y * 0.6), Color(0, 0, 0, 0.92 * a))
	draw_rect(Rect2(-vs.x, -vs.y * 0.3, vs.x * 2.0, 8), Color(col, a))
	draw_rect(Rect2(-vs.x, vs.y * 0.3 - 8.0, vs.x * 2.0, 8), Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
	var ih := vs.y * 1.1
	var iw := ih * HIT.get_width() / HIT.get_height()
	var br := 6.0 if k > 330.0 and k < 400.0 else 1.0
	draw_texture_rect(HIT, Rect2(Vector2(vs.x * 0.5 - iw * 0.5 + vs.x * 0.1 * (1.0 - e), vs.y * 0.56 - ih * 0.44), Vector2(iw, ih)), false, Color(br, br, br, a * e))
