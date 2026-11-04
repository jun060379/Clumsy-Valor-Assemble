extends Node
const ST := preload("res://scripts/status.gd")
## Character levels and the memory tree (prototype CHARACTER SCREEN v2 "memory path v3": TR / TREE / LVM / LVB / nodeNeed /
## treeValid / ptsLeft / BRKN / lvPreview / nodeOut / nodeIn / nodeEv / nMul, the runeTick / playerHit wraps, 성소 and 의족을 박고,
## memDecay). Lives on the runes node as `arena.runes.memory` (runes.gd creates it and calls its combat hooks).
##
## Per member: a level 1–12 bought with 기억석 (runes.mem), 돌파 at Lv3 / 6 / 9 with a dungeon material (runes.mats), one point a
## level spent on a 25-node tree (three branches of seven: tiers I · I · I · II · II · III · KEY, and four cross nodes X0–X3).
## The level multiplier (LVCURVE) scales base HP and attack (runes.stats) and the heals.
##
## Save hook (save_game.gd "memory"):
##   get_state() -> {"v": 1, "tree": {member: {"lv": int, "on": [node id...], "br": {"3": 1, ...}}}}
##   set_state(d)  restores it (unknown node ids are dropped, an invalid tree is cleared so its points come back)

const MD := preload("res://scripts/memory_data.gd")
const ROSTER := ["estelle", "aida", "luce", "kenin"]
## normal and charged attacks, by animation (prototype NORM / HEAVY)
const NORM := ["attack1", "attack2", "attack3", "attack_high", "air_combo", "air1", "air2", "air3", "lpunch"]
const HEAVY := ["cthrust", "cwave", "lfinisher", "kneel_attack", "gcharge", "lgather", "heavy"]

var runes                   # runes.gd
var tree := {}              # member -> {"lv": int, "on": Array, "br": Dictionary}
# combat state
var buf := {}               # timed node buffs: key -> {"o": the "on" entry, "t": ms left, "n": stacks}
var combo := 0              # 될 때까지 / 봉분 다지기 / 악당에게 정의를!: normal hits counted
var oath := {}              # 밀랍 날개: member -> the room it last fired in
var gp := {}                # 의족을 박고: member -> {"n": charges, "t": ms}
var sanc := {"cd": 0.0}     # 성소 (shared by the party)
var was_ult := false
var _fx_cache := {}
# 성소 drawing
var dome := {"st": "off", "t": 0.0, "shards": []}
var fx_node: Node2D


func _init() -> void:
	for c in ROSTER: tree[c] = {"lv": 1, "on": [], "br": {}}

func setup(r) -> void:
	runes = r
	name = "Memory"
	if r.arena != null:
		fx_node = Node2D.new()
		fx_node.z_index = 9
		fx_node.draw.connect(_draw_dome)
		r.arena.add_child(fx_node)

func reset() -> void:
	for c in ROSTER: tree[c] = {"lv": 1, "on": [], "br": {}}
	_fx_cache.clear()
	buf.clear()


# ---------- the tree ----------
func T(c: String) -> Dictionary:
	if not tree.has(c): tree[c] = {"lv": 1, "on": [], "br": {}}
	return tree[c]

func lv(c: String) -> int:
	return int(T(c)["lv"])

## LVM: the level multiplier
func lvm(c: String) -> float:
	return float(MD.LVCURVE[clampi(lv(c), 1, MD.MAXLV)])

static func lv_cost(l: int) -> int:
	return MD.LVCUM[l + 1] - MD.LVCUM[l] if l + 1 < MD.LVCUM.size() else 0

func pts_left(c: String) -> int:
	return (lv(c) - 1) - T(c)["on"].size()

func unlocked(c: String) -> bool:
	return lv(c) >= MD.MAXLV

static func node_ids() -> Array:
	var L: Array = []
	for b in "ABC":
		for i in 7: L.append(b + str(i))
	for i in 4: L.append("X" + str(i))
	return L

static func node_def(c: String, id: String) -> Variant:
	if id.length() < 2 or not MD.NODES.has(c) or not MD.NODES[c].has(id[0]): return null
	var L: Array = MD.NODES[c][id[0]]
	var i := int(id.substr(1))
	return L[i] if i >= 0 and i < L.size() else null

static func br_count(on: Array, b: String) -> int:
	var n := 0
	for x in on:
		if String(x)[0] == b: n += 1
	return n

## nodeNeed: "" when the node may be taken given `on`, else a short reason
func node_need(c: String, id: String, on: Array) -> String:
	var need_lv: int = MD.XLV if id[0] == "X" else MD.TIERLV[int(id.substr(1))]
	if lv(c) < need_lv: return "Lv %d에 열림" % need_lv
	if id[0] == "X":
		var r: Array = MD.XREQ[int(id.substr(1))]
		var need: Array = []
		for i in 3:
			if r[i] > 0 and br_count(on, "ABC"[i]) < r[i]: need.append("%s %d" % [MD.BR[c][i], r[i]])
		return " · ".join(need) + " 필요" if not need.is_empty() else ""
	var q: int = MD.TIERREQ[int(id.substr(1))]
	var have := br_count(on.filter(func(x): return x != id), id[0])
	return "%s에 %d포인트 필요 (지금 %d)" % [MD.BR[c]["ABC".find(id[0])], q, have] if have < q else ""

func tree_valid(c: String, on: Array) -> bool:
	for id in on:
		if node_need(c, id, on) != "": return false
	return true

func can_take(c: String, id: String) -> bool:
	var on: Array = T(c)["on"]
	return not on.has(id) and pts_left(c) > 0 and node_need(c, id, on + [id]) == ""

## turning the node off would leave another one standing on nothing
func held(c: String, id: String) -> bool:
	var on: Array = T(c)["on"]
	return on.has(id) and not tree_valid(c, on.filter(func(x): return x != id))

func take(c: String, id: String) -> bool:
	if not can_take(c, id): return false
	T(c)["on"].append(id)
	_changed()
	return true

func drop(c: String, id: String) -> bool:
	if not T(c)["on"].has(id) or held(c, id): return false
	T(c)["on"].erase(id)
	_changed()
	return true

func clear_nodes(c: String) -> bool:
	if T(c)["on"].is_empty(): return false
	T(c)["on"] = []
	_changed()
	return true

## the tier tag of a node ("검 · II", "혼합 · 검 2 + 방패 2")
func tier_name(c: String, id: String) -> String:
	if id[0] == "X":
		var r: Array = MD.XREQ[int(id.substr(1))]
		var p: Array = []
		for i in 3:
			if r[i] > 0: p.append("%s %d" % [MD.BR[c][i], r[i]])
		return "혼합 · " + " + ".join(p)
	return MD.BR[c]["ABC".find(id[0])] + " · " + MD.TIERN[int(id.substr(1))]


# ---------- levels and 돌파 ----------
## BRKN: the breakthrough due before the next level, or {}
func brk_need(c: String) -> Dictionary:
	var t: Dictionary = T(c)
	var B: Dictionary = MD.BRKC.get(c, MD.BRKC["estelle"])
	var l := int(t["lv"])
	if not B.has(l) or t["br"].has(str(l)): return {}
	return B[l]

static func mat_name(m: String) -> String:
	return MD.MATN[m]["n"] if MD.MATN.has(m) else m

static func mat_col(m: String) -> Color:
	return Color(MD.MATN[m]["c"]) if MD.MATN.has(m) else Color("#8a8a9a")

func mat_have(m: String) -> int:
	return int(runes.mats.get(m, 0)) if runes != null else 0

## the small line under the level button
func lv_preview(c: String) -> String:
	var l := lv(c)
	var b: float = float(MD.LVCURVE[mini(l + 1, MD.MAXLV)])
	var up: bool = (l + 1) in [4, 7, 10]
	var B: Dictionary = MD.BRKC.get(c, MD.BRKC["estelle"])
	var nxt := -1
	var ks: Array = B.keys()
	ks.sort()
	for k in ks:
		if int(k) >= l and not T(c)["br"].has(str(k)):
			nxt = int(k)
			break
	var op: String = MD.LVOPEN.get(l + 1, "")
	var base_hp: float = runes.CH.STATS[c]["hp"] if runes != null else 70.0
	return "Lv%d%s · 체력 %d · 공격 ×%s%s%s" % [l + 1, " 점프" if up else "", roundi(base_hp * b), _num(b), (" · " + op) if op != "" else "",
		" · 곧 돌파" if brk_need(c).is_empty() and nxt >= 0 and nxt - l <= 1 else ""]

static func _num(v: float) -> String:
	return str(int(v)) if v == roundf(v) else str(snappedf(v, 0.01))

## the level button: "brk" (돌파 done) / "nomat" / "lv" (levelled) / "nomem" / "max"
func level_up(c: String) -> String:
	var t: Dictionary = T(c)
	if int(t["lv"]) >= MD.MAXLV: return "max"
	var nb := brk_need(c)
	if not nb.is_empty():
		if mat_have(nb["m"]) < int(nb["n"]): return "nomat"
		runes.mats[nb["m"]] = mat_have(nb["m"]) - int(nb["n"])
		t["br"][str(t["lv"])] = 1
		return "brk"
	var cost := lv_cost(int(t["lv"]))
	if runes.mem < cost: return "nomem"
	runes.mem -= cost
	t["lv"] = int(t["lv"]) + 1
	_changed()
	return "lv"

func any_break() -> bool:
	for c in ROSTER:
		if not T(c)["br"].is_empty(): return true
	return false

## memDecay: 기억석 from a dungeon well below the party thins out (−25% a level over its top, never under 10%)
func mem_decay(top := 6) -> float:
	var l := 1
	if runes != null and runes.arena != null:
		for c in runes.arena.player.party: l = maxi(l, lv(c))
	return 1.0 if l <= top else maxf(0.1, 1.0 - 0.25 * (l - top))


# ---------- effects ----------
func _changed() -> void:
	_fx_cache.clear()
	if runes != null: runes.changed()
	# a level can earn a costume (skin_data.gd "level"; Lv 12 = 메모리얼 해방)
	if runes != null and runes.arena != null and runes.arena.get("skins") != null: runes.arena.skins.sync()

## nfx: the effects of the nodes a member has on
func nfx(c: String) -> Array:
	var on: Array = T(c)["on"]
	var k := ",".join(on)
	if _fx_cache.has(c) and _fx_cache[c][0] == k: return _fx_cache[c][1]
	var v: Array = []
	for id in on:
		var d = node_def(c, id)
		if d != null: v.append(d["fx"])
	_fx_cache[c] = [k, v]
	return v

## plain stat nodes (최대 체력 / 회복량), added to the gear totals
func stat_add(c: String) -> Dictionary:
	var S := {}
	for f in nfx(c):
		if f.has("stat"):
			for k in f["stat"]: S[k] = float(S.get(k, 0.0)) + float(f["stat"][k])
	return S

## nMul: the product of a multiplier key (ult, qteT, swap, cd, rch)
func mul(c: String, key: String) -> float:
	var m := 1.0
	for f in nfx(c):
		if f.has(key): m *= float(f[key])
	return m

func val(c: String, key: String) -> float:
	for f in nfx(c):
		if f.has(key): return float(f[key])
	return 0.0

func _P():
	return runes.arena.player if runes != null and runes.arena != null else null

func low_hp() -> bool:
	var P = _P()
	return P != null and P.hp <= P.MAX_HP * 0.5

func _bn(k: String) -> int:
	return int(buf[k]["n"]) if buf.has(k) and buf[k]["t"] > 0.0 else 0

## nodeOut: outgoing damage of the member in play against e
func out_mul(c: String, e) -> float:
	var L := nfx(c)
	var P = _P()
	var me: bool = P != null and c == P.who
	var an: String = P.anim if me else ""
	var nor: bool = NORM.has(an)
	var hv := false
	for h in HEAVY:
		if an.begins_with(h): hv = true
	var m := 1.0
	for f in L:
		if f.has("out"): m *= 1.0 + f["out"]
		if f.has("outN") and nor: m *= 1.0 + f["outN"]
		if f.has("outH") and hv: m *= 1.0 + f["outH"]
		if f.has("outLow") and me and low_hp(): m *= 1.0 + f["outLow"]
		if f.has("outExposed") and e != null and ST.exposed(e): m *= 1.0 + f["outExposed"]      # 무방비 (경직 · 빙결 · 띄움 · 그로기)
		if f.has("outExec") and e != null and e.get("max_hp") != null and e.max_hp > 0.0 and e.hp > 0.0 and e.hp / e.max_hp <= 0.3: m *= 1.0 + f["outExec"]
		if f.has("outDark") and e != null and e.has_meta("dark_t") and Time.get_ticks_msec() < int(e.get_meta("dark_t")): m *= 1.0 + f["outDark"]
		if f.has("outBack") and me and e != null and e.get("dir") != null and signf(e.position.x - P.position.x) == signf(e.dir): m *= 1.0 + f["outBack"]
		if f.has("combo3") and me and nor and e != null:
			combo += 1
			if combo % 3 == 0: m *= 1.5
	var bh := 0.0
	var bnn := 0.0
	if me:
		for k in buf:
			var n := _bn(k)
			if n == 0: continue
			var o: Dictionary = buf[k]["o"]
			if o.has("out"): m *= 1.0 + o["out"] * n
			if o.has("outH") and hv: bh += o["outH"]
			if o.has("outN") and nor: bnn += o["outN"]
	return m * (1.0 + bh) * (1.0 + bnn)

## nodeIn: incoming damage for the member in play
func in_mul() -> float:
	var P = _P()
	if P == null: return 1.0
	var m := 1.0
	for f in nfx(P.who):
		if f.has("inAll"): m *= f["inAll"]
		if f.has("inGuard") and (P.anim == "guard" or P.anim == "parry"): m *= f["inGuard"]
		if f.has("inLow") and low_hp(): m *= f["inLow"]
	for k in buf:
		if _bn(k) > 0 and buf[k]["o"].has("inn"): m *= buf[k]["o"]["inn"]
	return m

## move speed from timed buffs (밤 순찰, 선사고 후보고, 그늘진 문)
func spd() -> float:
	var s := 1.0
	for k in buf:
		if _bn(k) > 0 and buf[k]["o"].has("spd"): s *= buf[k]["o"]["spd"]
	return s

## nodeEv: dash / heavy / parry / pparry / block / tag / skill / heal / kill / pdodge / ult
func ev(e: String) -> void:
	var P = _P()
	if P == null: return
	var c: String = P.who
	var L := nfx(c)
	for i in L.size():
		var f: Dictionary = L[i]
		if not f.has("on"): continue
		for j in f["on"].size():
			var o: Dictionary = f["on"][j]
			if o["ev"] != e: continue
			if o.has("ms"):
				var k := "n_%s%d_%d" % [c, i, j]
				if not buf.has(k): buf[k] = {"o": o, "t": 0.0, "n": 0}
				buf[k]["o"] = o
				buf[k]["t"] = float(o["ms"])
				buf[k]["n"] = mini(int(o.get("max", 1)), int(buf[k]["n"]) + 1)
			var U = runes.arena.get("ult")
			if o.has("ult") and U != null and U.state == "":
				U.v[c] = minf(U.ULTMAX[c], U.v[c] + float(o["ult"]))
			if o.has("dash") and P.charges < 2: P.charges = mini(2, P.charges + int(o["dash"]))
			if o.has("heal") and P.hp > 0.0 and P.hp < P.MAX_HP:
				var hv := roundi(float(o["heal"]) * lvm(c))
				P.hp = minf(P.MAX_HP, P.hp + hv)
				runes.arena.text(P.position + Vector2(0, -130.0 * P.CSCALE), "+%d" % hv, Color("#9fe3a0"))
			if o.has("cdReset"):
				P.tp_cd = 0.0
				P.heal_cd = 0.0
				runes.shield_cd = 0.0
				runes.arena.text(P.position + Vector2(0, -150.0 * P.CSCALE), "재사용 대기 초기화", Color("#bfe8ff"))

## per frame (runeTick wraps): buffs run down, 궁극기 edge, 밀랍 날개, 의족을 박고 charges, 성소 cooldown
func tick(dt: float) -> void:
	for k in buf:
		if buf[k]["t"] > 0.0:
			buf[k]["t"] -= dt
			if buf[k]["t"] <= 0.0: buf[k]["n"] = 0
	var P = _P()
	if P == null: return
	var A = runes.arena
	var U = A.get("ult")
	var u: bool = U != null and U.state != ""
	if u and not was_ult: ev("ult")
	was_ult = u
	# 밀랍 날개: once per room, dropping under 30% fills the gauge
	if val(P.who, "bloodOath") > 0.0 and A.level_kind() == "dungeon":
		var rk := "%s|%s" % [A.level_kind(), str(A.level.get("cur"))]
		if P.hp > 0.0 and P.hp < P.MAX_HP * 0.3 and oath.get(P.who, "") != rk:
			oath[P.who] = rk
			if U != null: U.v[P.who] = U.ULTMAX[P.who]
			A.text(P.position + Vector2(0, -170.0 * P.CSCALE), "피의 서약", Color("#ff5a7a"))
			A.flash = maxf(A.flash, 0.12)
	# 의족을 박고: two charges, one back every 8 s
	var g := val(P.who, "guardParry")
	if g > 0.0:
		if not gp.has(P.who): gp[P.who] = {"n": 2, "t": 0.0}
		var G: Dictionary = gp[P.who]
		if G["n"] < 2:
			G["t"] += dt
			if G["t"] >= g:
				G["t"] = 0.0
				G["n"] += 1
		runes.rb["n_gp"] = {"t": 1e9 if G["n"] > 0 else 0.0, "n": G["n"]}
	elif runes.rb.has("n_gp"): runes.rb["n_gp"]["t"] = 0.0
	# 성소
	var ls := sanc_v()
	if ls > 0.0:
		if sanc["cd"] > 0.0: sanc["cd"] -= dt
		runes.rb["n_ls"] = {"t": 0.0 if sanc["cd"] > 0.0 else 1e9, "n": 1}
	elif runes.rb.has("n_ls"): runes.rb["n_ls"]["t"] = 0.0
	_step_dome(dt)
	if fx_node != null: fx_node.queue_redraw()

## 성소 covers the whole party while Luce (with the node) is in it and standing
func sanc_v() -> float:
	var P = _P()
	if P == null: return 0.0
	var v := val(P.who, "lightShield")
	if v > 0.0: return v
	if P.party.has("luce") and not (P.hpm.get("luce", 1.0) <= 0.0 and P.who != "luce"): return val("luce", "lightShield")
	return 0.0

## playerHit wrap, before the blow lands: "miss" when 성소 takes it, "gp" when 의족을 박고 turns the guard into a parry, else ""
func guard_hit(m, facing: bool) -> String:
	var P = _P()
	var free: bool = not (P.inv > 0.0) and P.hp > 0.0 and P.anim != "death"
	var ls := sanc_v()
	if ls > 0.0 and free and not (sanc["cd"] > 0.0) and not P.anim in ["dash", "airdash", "dig_in", "tp_in"]:
		sanc["cd"] = ls
		P.inv = maxf(P.inv, 500.0)
		var A = runes.arena
		A.sfx("guard", 0.8)
		_dome_break(m)
		A.text(P.position + Vector2(0, -140.0 * P.CSCALE), "성소", Color("#fff1b0"))
		A.post_wave(P.position + Vector2(0, -70.0 * P.CSCALE), 0.8, 380.0, 0.18)
		return "miss"
	var g := val(P.who, "guardParry")
	if g > 0.0 and free and gp.has(P.who) and gp[P.who]["n"] > 0 and P.anim == "guard" and facing:
		gp[P.who]["n"] -= 1
		return "gp"
	return ""


# ---------- 성소: Luce's dome (pixel hex shell, a scan racing up, shatters on a hit, re-weaves bottom-up) ----------
var _hex: Array = []

func _hexes() -> Array:
	if _hex.is_empty():
		var r := 0.115
		var w := sqrt(3.0) * r
		for row in range(-12, 2):
			for col in range(-12, 13):
				var x := col * w + (w / 2.0 if row & 1 else 0.0)
				var y := row * r * 1.5
				if Vector2(x, y).length() < 1.05 and y < 0.08: _hex.append(Vector2(x, y))
	return _hex

static func _warp(p: Vector2) -> Vector2:
	var d := p.length()
	if d < 1e-6: return Vector2.ZERO
	var m := minf(d, 1.0)
	return p * (sin(m * PI / 2.0) / m)

func _dome_break(m) -> void:
	var P = _P()
	dome["st"] = "break"
	dome["t"] = 0.0
	var sh: Array = []
	var H := _hexes()
	var side: float = signf(m.position.x - P.position.x) * 0.7 if m != null else 0.0
	for i in range(0, H.size(), 2):
		var h: Vector2 = H[i]
		var u := _warp(h)
		var dv := Vector2(h.x - side, h.y + 0.4)
		var d := dv.length() + 0.2
		sh.append({"p": P.position + Vector2(u.x * 112.0 * P.CSCALE, u.y * 104.0 * P.CSCALE), "v": Vector2(u.x * 0.22 + dv.x / d * 0.16 + (randf() - 0.5) * 0.12, -0.08 - randf() * 0.2 + dv.y / d * 0.1),
			"rot": 0.0, "vr": (randf() - 0.5) * 0.02, "delay": d * 120.0})
	dome["shards"] = sh

func _step_dome(dt: float) -> void:
	var ls := sanc_v()
	var A = runes.arena
	if ls <= 0.0 or A.level_kind() == "town":
		dome["st"] = "off"
		return
	var ready: bool = not (sanc["cd"] > 0.0)
	dome["t"] += dt
	if dome["st"] == "off": dome["st"] = "up" if ready else "down"
	if dome["st"] == "down" and ready:
		dome["st"] = "regen"
		dome["t"] = 0.0
	if dome["st"] == "regen" and dome["t"] > 900.0: dome["st"] = "up"
	if dome["st"] == "break" and dome["t"] > 1100.0: dome["st"] = "down"
	if dome["st"] == "up" and not ready: dome["st"] = "down"
	if dome["st"] == "break":
		for s in dome["shards"]:
			if dome["t"] - s["delay"] <= 0.0: continue
			s["p"] += s["v"] * dt
			s["v"].y += 0.0006 * dt
			s["rot"] += s["vr"] * dt

func _hex_pts(c: Vector2, r: float, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 7:
		var a := PI / 6.0 + i * PI / 3.0 + rot
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw_dome() -> void:
	var st: String = dome["st"]
	if st == "off" or st == "down" or runes == null: return
	var P = _P()
	if P == null or (runes.arena.ui_root != null and runes.arena.ui_root.holds()): return
	var ci := fx_node
	var rx: float = 112.0 * P.CSCALE
	var ry: float = 104.0 * P.CSCALE
	var px := 2.5
	var o: Vector2 = P.position
	var snap := func(v: Vector2) -> Vector2: return Vector2(roundf(v.x / px) * px, roundf(v.y / px) * px)
	var H := _hexes()
	if st == "break":
		var k: float = dome["t"]
		if k < 200.0:
			for h: Vector2 in H:
				ci.draw_polyline(_hex_pts(snap.call(o + _warp(h) * Vector2(rx, ry)), 0.115 * rx * 0.9), Color(1.0, 0.94, 0.75, 1.0 - k / 200.0), 1.1)
		var hr := 0.115 * rx * 0.65
		for s in dome["shards"]:
			var tt: float = k - s["delay"]
			if tt <= 0.0: continue
			var a := 1.0 - tt / 700.0
			if a <= 0.0: continue
			ci.draw_polyline(_hex_pts(snap.call(s["p"]), hr, roundf(s["rot"] * 4.0) / 4.0), Color(1.0, 0.9, 0.63, 1.0 if a > 0.6 else (0.6 if a > 0.3 else 0.3)), 1.5)
		return
	var rv: float = dome["t"] / 900.0 if st == "regen" else 1.0
	var ph := fmod(Time.get_ticks_msec() / 1000.0, 3.4) / 0.55
	for h: Vector2 in H:
		var hy := -h.y                                    # 0 at the rim … 1 at the top
		if rv < 1.0 and hy > rv * 1.1: continue          # re-weaving: bottom-up
		var rim := pow(minf(1.0, h.length()), 2.2)
		var c: Vector2 = snap.call(o + _warp(h) * Vector2(rx, ry))
		var lit := 0.0
		if ph > hy and ph < hy + 2.2:
			var kk := pow(1.0 - (ph - hy) / 2.2, 2.0)
			lit = 1.0 if kk > 0.6 else (0.55 if kk > 0.3 else (0.25 if kk > 0.1 else 0.0))
		var base_a := minf(1.0, 0.3 + 0.25 * rim)
		var col := Color(1.0, 0.84, 0.47, base_a * 0.75).lerp(Color(1.0, 0.94, 0.75, 1.0), lit)
		if lit > 0.0 and (hy > 0.55 or rim > 0.6): ci.draw_colored_polygon(_hex_pts(c, 0.115 * rx * 0.9), Color(1.0, 0.89, 0.59, 0.28 * lit))
		ci.draw_polyline(_hex_pts(c, 0.115 * rx * 0.9), col, 1.0)
	# the rim arc and the floor ring
	var arc := PackedVector2Array()
	for i in 33:
		var a := PI + PI * i / 32.0
		arc.append(snap.call(o + Vector2(cos(a) * rx, sin(a) * ry)))
	ci.draw_polyline(arc, Color(1.0, 0.88, 0.59, 0.85 * minf(1.0, rv)), 1.6)
	var ring := PackedVector2Array()                    # the flat ring on the floor (rx × 0.16 rx)
	for i in 41:
		var a := TAU * i / 40.0
		ring.append(snap.call(o + Vector2(cos(a) * rx, sin(a) * rx * 0.16)))
	ci.draw_polyline(ring, Color(1.0, 0.83, 0.42, 0.55 * minf(1.0, rv)), 1.2)


# ---------- save ----------
func get_state() -> Dictionary:
	var o := {}
	for c in ROSTER:
		var t := T(c)
		o[c] = {"lv": int(t["lv"]), "on": t["on"].duplicate(), "br": t["br"].duplicate()}
	return {"v": 1, "tree": o}

func set_state(d: Dictionary) -> void:
	var tr: Dictionary = d.get("tree", {}) if d.get("tree") is Dictionary else {}
	var ids := node_ids()
	for c in ROSTER:
		if not tr.has(c) or not tr[c] is Dictionary: continue
		var s: Dictionary = tr[c]
		var t := {"lv": clampi(int(s.get("lv", 1)), 1, MD.MAXLV), "on": [], "br": {}}
		if s.get("on") is Array:
			for id in s["on"]:
				if ids.has(String(id)) and not t["on"].has(String(id)): t["on"].append(String(id))
		if s.get("br") is Dictionary:
			for k in s["br"]: t["br"][str(int(float(k)))] = 1
		tree[c] = t
		if t["on"].size() > t["lv"] - 1 or not tree_valid(c, t["on"]): t["on"] = []
	_changed()
