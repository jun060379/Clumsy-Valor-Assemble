extends RefCounted
## 케닌 클로 (도적 · 원거리 · 트릭스터): the pistol, the sticky bombs, the QTE covering shot and the chain detonation.
## Lives on the arena as `arena.kenin`; player.gd calls fire / throw / assist, the detonator (charged attack) and ult.gd call chain_detonate.
## The loop the owner set (2026-11-03): from the bench his QTE shoots a foe's head without swapping (a mark, the swap
## cooldown reset); out front he empties the cylinder and the bombs at high power, then he is weak until he reloads —
## and he reloads fast only off the field, so he goes back into the party to rearm.
##   ammo   AMMO shots out front; empty = no shot at all (the trigger clicks, he looks at the pistol: anim "kdry").
##          On the field an empty pistol reloads after RELOAD_FIELD ms; on the bench one round every RELOAD_BENCH ms.
##   bombs  BOMBS charges; spent ones all come back BOMB_FIELD ms after the last throw (BOMB_BENCH on the bench). A thrown bomb sticks to
##          the first foe it touches (or rests on the floor) and blows after FUSE ms; a bullet hitting a foe that wears
##          one sets it off at once ×BOMB_HEAD.
##   marks  stamps on a foe's body: every bullet that lands one, every bomb blast one on each foe it catches, the QTE
##          headshot MARK_QTE, every ult shot one; at most MARK_MAX a foe (the ult has no cap). His charged attack (the detonator, chain_detonate) sets off every stamp and
##          every bomb one after another, nearest first, faster and faster — 파바바방 — and the ult ends on the same chain.
## Every number here is a PLACEHOLDER until the owner tunes it.

const CH := preload("res://scripts/chars.gd")
const PFX := preload("res://scripts/pfx.gd")
const UI := preload("res://scripts/ui_kit.gd")

const AMMO := 18                # owner 2026-11-04: ×3, every trigger pull is a 3-round burst (타다당)
const BURST := 3
const BOMBS := 3
const RELOAD_FIELD := 15000.0      # owner 2026-11-04: long on purpose
const RELOAD_BENCH := 1000.0       # the bench refills faster (6 s for the cylinder)
const BOMB_BENCH := 10000.0
const BOMB_FIELD := 25000.0        # owner 2026-11-04
const FUSE := 2500.0
const BOMB_DMG := 3.0
const BOMB_R := 120.0
const BOMB_HEAD := 1.5
const HEAD_DMG := 4.0
const MARK_DMG := 1.6           # one stamp popping
const MARK_QTE := 3
const MARK_MAX := 8
const VULN_MS := 8000
const CHAIN_GAP0 := 110.0       # the chain: the first gap, then each gap ×CHAIN_ACC down to CHAIN_GAP_MIN
const CHAIN_ACC := 0.86
const CHAIN_GAP_MIN := 38.0
const SHOT_V := 2.4             # px / ms
const SHOT_LIFE := 520.0
## the QTE assist: the headshot row's frame times (chars.gd A_KENIN "headshot"); the pistol fires on frame 5
const AS_FIRE := 5

var arena
var ammo := AMMO
var bombs := BOMBS
var reload_t := 0.0             # field: time since the cylinder ran dry; bench: time toward the next round
var bomb_t := 0.0
var shots: Array = []           # {x, y, vx, vy, dmg, dry, t, tr}
var bomb_fx: Array = []         # {x, y, vx, vy, m (stuck foe or null), ox, oy, on_floor, t, fuse}
var booms: Array = []           # {x, y, t, life, big}
var marks := {}                 # instance id -> {m, pts: [{ox, oy, t}]} (stamp offsets from the foe's feet, age)
var chain: Array = []           # the detonation queue: {at, kind: "mark" / "bomb", m, ox, oy, b, i}
var chain_t := 0.0
var chain_n := 0                # pops so far in this chain
var chain_tot := 0              # how many the chain holds
var in_chain := false           # a bomb going off inside the chain stamps nothing (it would be left over)
var assists: Array = []         # {x, y, dir, tg, t, fired}


func _init(a) -> void:
	arena = a

func reset() -> void:
	ammo = amax()
	bombs = bmax()
	reload_t = 0.0
	bomb_t = 0.0
	shots.clear()
	bomb_fx.clear()
	booms.clear()
	marks.clear()
	assists.clear()
	chain.clear()

# ---------- memory nodes (memory_data.gd NODES.kenin: the k* keys) ----------
var spare_t := 0.0              # 비상 탄창: time until it can fire again
var was_field := false

func _mem():
	var R = arena.get("runes")
	return R.memory if R != null and R.get("memory") != null else null

## a node value (additive keys: kAmmo, kBombs, kHeavyShot …; 0 when not taken)
func nv(key: String) -> float:
	var M = _mem()
	return M.val("kenin", key) if M != null else 0.0

## a node multiplier (kReload, kBench, kFuse, kBombR; 1 when not taken)
func nm(key: String) -> float:
	var M = _mem()
	return M.mul("kenin", key) if M != null else 1.0

func amax() -> int:
	return AMMO + int(nv("kAmmo"))

func bmax() -> int:
	return BOMBS + int(nv("kBombs"))

func reload_need() -> float:
	return RELOAD_FIELD * nm("kReload")

func bomb_need(field: bool) -> float:
	return (BOMB_FIELD if field else BOMB_BENCH * nm("kBench"))

## the cylinder just ran dry (out front): 비상 탄창, 빈 탄창 털기 (kdry event), 탄피 폭탄
func _ran_dry() -> void:
	var P = _P()
	var M = _mem()
	if M != null: M.ev("kdry")
	if nv("kDryBlast") > 0.0: dud_blast(P.position + Vector2(0, -20.0))
	if nv("kSpare") > 0.0 and spare_t <= 0.0:
		spare_t = nv("kSpare")
		ammo = amax()
		reload_t = 0.0
		arena.sfx("ui_ok", 0.7, {"st": 4.0})
		arena.big_word("비상 탄창!", Color("#e8ffb0"), 600.0, Vector2.ZERO, P.position + Vector2(0, -170.0 * P.CSCALE))

## no screen shake while his ult plays (owner 2026-11-04: the ult read better still)
func _shake(amt: float, d: int) -> void:
	if arena.ult != null and arena.ult.state == "act" and arena.ult.who == "kenin": return
	arena.shake(amt, d)

func _P():
	return arena.player

## his attack multiplier, whoever is in control (the bench assist uses his own)
func _mul() -> float:
	var R = arena.get("runes")
	return CH.STATS["kenin"]["atk"] * (R.atk_k("kenin") if R != null else 1.0)

func on_field() -> bool:
	return _P() != null and _P().who == "kenin"

func in_party() -> bool:
	return _P() != null and _P().party.has("kenin")

func dry() -> bool:
	return ammo <= 0

## the rest of the world: reload, bombs back, bullets, bombs, booms, the bench assist
func step(dt: float) -> void:
	var P = _P()
	if P == null: return
	var field := on_field()
	if spare_t > 0.0: spare_t -= dt
	if field and not was_field and nv("kTagReload") > 0.0 and ammo < amax():
		ammo = amax()                                       # 교대 장전
		reload_t = 0.0
		arena.text(P.position + Vector2(0, -150.0 * P.CSCALE), "교대 장전", Color("#e2f5b8"))
	was_field = field
	if field:
		if ammo <= 0:
			reload_t += dt
			if reload_t >= reload_need():
				ammo = amax()
				reload_t = 0.0
				arena.sfx("ui_ok", 0.5)
				arena.text(P.position + Vector2(0, -150.0 * P.CSCALE), "재장전 완료", Color("#e2f5b8"))
		else:
			reload_t = 0.0
	elif ammo < amax():
		reload_t += dt
		var rb := RELOAD_BENCH / BURST * nm("kBench")       # the bench refills a burst's worth as fast as one round was
		while reload_t >= rb and ammo < amax():
			reload_t -= rb
			ammo += 1
	if bombs < bmax():
		bomb_t += dt
		if bomb_t >= bomb_need(field):
			bomb_t = 0.0
			bombs = bmax()
			if field:
				arena.sfx("ui_ok", 0.5, {"st": -3.0})
				arena.text(P.position + Vector2(0, -150.0 * P.CSCALE), "폭탄 보충", Color("#e2f5b8"))
	else:
		bomb_t = 0.0
	_step_shots(dt)
	_step_bombs(dt)
	_step_assists(dt)
	for b in booms: b["t"] += dt
	booms = booms.filter(func(b): return b["t"] < b["life"])
	for k in marks.keys():
		var e = marks[k]["m"]
		if e == null or not is_instance_valid(e) or not e.alive(): marks.erase(k)
		else:
			for q in marks[k]["pts"]: q["t"] += dt
	var mf := nv("kMarkFuse")
	if mf > 0.0 and chain.is_empty():
		_mark_fuses(mf)
	_step_chain(dt)


# ---------- the pistol ----------
## one round from the muzzle (o) along d (a unit vector), a third of a pull's damage; player.gd replays the fire frame for
## each round of the BURST (first = the burst's opening round: only it stamps a mark). Empty = nothing comes out, the
## trigger clicks on the opening round (returns false; the burst stops).
func fire(o: Vector2, d: Vector2, dmg: float, first := true, big := false) -> bool:
	if ammo <= 0:
		if first:
			arena.sfx("ui_move", 0.7, {"st": -4.0})
			arena.text(_P().position + Vector2(0, -150.0 * _P().CSCALE), "찰칵… 탄창 비었음", Color("#b9bfa8"))
		return false
	ammo -= 1
	var dd := d.rotated(randf_range(-0.05, 0.05))
	if big: dd = d
	shots.append({"x": o.x, "y": o.y, "vx": dd.x * SHOT_V * (1.25 if big else 1.0), "vy": dd.y * SHOT_V * (1.25 if big else 1.0), "dmg": dmg / BURST, "dry": false, "t": 0.0, "mul": _mul(), "mk": first or big, "big": big})
	# PLACEHOLDER sound: there is no gunshot in the packs yet (the stab, pitched up); each round its own crack, the big one a boom
	if big:
		arena.sfx("thrust", 0.9, {"st": 1.0})
		arena.sfx("heavy", 0.7, {"st": 2.0})
		arena.pfx.hit(o.x, o.y, int(signf(d.x)) if d.x != 0.0 else 1, 1.5)
		arena.post_wave(o, 0.6, 360.0, 0.15)
	else:
		arena.sfx("thrust", 0.6, {"st": 5.0 + randf() * 1.2})
		arena.pfx.hit(o.x, o.y, int(signf(d.x)) if d.x != 0.0 else 1, 0.7)
	_shake(1.0, -int(signf(d.x)) if d.x != 0.0 else 1)
	if ammo <= 0 and on_field(): _ran_dry()
	return true

func _step_shots(dt: float) -> void:
	for s in shots:
		s["t"] += dt
		var x0: float = s["x"]
		s["x"] += s["vx"] * dt
		s["y"] += s["vy"] * dt
		if s.get("fake", false): continue          # the ult's tracers: the damage was dealt when it fired
		# swept along this frame's path: a fast ball must not skip through a thin goblin
		var lo := minf(x0, s["x"]) - 22.0
		var hi := maxf(x0, s["x"]) + 22.0
		for m in arena.foes():
			if m.position.x > lo and m.position.x < hi and s["y"] > m.position.y - 112.0 and s["y"] < m.position.y + 10.0:
				_land_shot(s, m)
				s["t"] = SHOT_LIFE + 1.0
				break
		if s["y"] > _floor(s["x"]) + 4.0 or s["x"] < -40.0 or s["x"] > arena.world_w + 40.0:
			s["t"] = SHOT_LIFE + 1.0
	shots = shots.filter(func(s): return s["t"] < SHOT_LIFE)

func _land_shot(s: Dictionary, m) -> void:
	arena.hit_by = "kenin"
	if nv("kMarked") > 0.0 and marks.has(m.get_instance_id()): s["dmg"] *= 1.0 + nv("kMarked")    # 명사수
	var big: bool = s.get("big", false)
	m.hit(s["dmg"], signf(s["vx"]) * (9.0 if big else (1.5 if s["dry"] else 3.0)), s["mul"])
	arena.hit_by = ""
	arena.spark(Vector2(s["x"], s["y"]), 12 if big else (4 if s["dry"] else 7))
	arena.sfx("hit3" if big else "hit1", 0.9 if big else (0.4 if s["dry"] else 0.6))
	if big:
		arena.hitstop = maxf(arena.hitstop, 60.0)
		arena.pfx.hit(s["x"], s["y"], int(signf(s["vx"])), 1.3)
		_shake(4.0, int(signf(s["vx"])))
	if not s["dry"]:
		arena.ult_gain(2.0 / BURST)
		if s.get("mk", true): add_marks(m, 1)
		var b = _bomb_on(m)
		if b != null:
			_explode(b, BOMB_HEAD, true)

func _floor(x: float) -> float:
	var L = arena.level
	if L != null and L.has_method("floor_at"): return L.floor_at(x)
	return arena.ground_y


# ---------- sticky bombs ----------
func can_throw() -> bool:
	return bombs > 0

## a lob; with a foe ahead (tx) it is thrown to reach it (the arc comes back to hand height in ~290 ms)
func throw_bomb(o: Vector2, d: int, tx := NAN) -> void:
	if bombs <= 0: return
	bombs -= 1
	bomb_t = 0.0                # the refill clock starts over from the last throw
	var v := 0.5
	if not is_nan(tx) and (tx - o.x) * d > 0.0: v = clampf(absf(tx - o.x) / 290.0, 0.3, 1.1)
	bomb_fx.append({"x": o.x, "y": o.y, "vx": d * v, "vy": -0.3, "m": null, "ox": 0.0, "oy": 0.0, "on_floor": false, "t": 0.0, "fuse": FUSE * nm("kFuse"), "done": false})
	arena.sfx("swing", 0.5)

func _bomb_on(m):
	for b in bomb_fx:
		if not b["done"] and b["m"] == m: return b
	return null

func _step_bombs(dt: float) -> void:
	for b in bomb_fx:
		if b["done"]: continue
		b["t"] += dt
		var m = b["m"]
		if m != null:
			if not is_instance_valid(m) or not m.alive():
				b["m"] = null
				b["vx"] = 0.0
				b["vy"] = 0.0
			else:
				b["x"] = m.position.x + b["ox"]
				b["y"] = m.position.y + b["oy"]
		elif not b["on_floor"]:
			b["vy"] += 0.0024 * dt
			b["x"] += b["vx"] * dt
			b["y"] += b["vy"] * dt
			for e in arena.foes():
				if absf(e.position.x - b["x"]) < 34.0 and b["y"] > e.position.y - 112.0 and b["y"] < e.position.y + 10.0:
					b["m"] = e
					b["ox"] = clampf(b["x"] - e.position.x, -14.0, 14.0)
					b["oy"] = clampf(b["y"] - e.position.y, -80.0, -30.0)
					arena.sfx("ui_move", 0.6, {"st": -7.0})        # the squelch of the glue (PLACEHOLDER)
					if nv("kInstant") > 0.0: b["fuse"] = 0.0        # 접촉 신관
					break
			var fy := _floor(b["x"])
			if b["m"] == null and b["y"] >= fy:
				b["y"] = fy - 6.0
				b["on_floor"] = true
				b["vx"] = 0.0
				b["vy"] = 0.0
			b["x"] = clampf(b["x"], 20.0, arena.world_w - 20.0)
		b["fuse"] -= dt
		if b["fuse"] <= 0.0:
			_explode(b, 1.0, false)
	bomb_fx = bomb_fx.filter(func(b): return not b["done"])

func _explode(b: Dictionary, k: float, head: bool) -> void:
	if b["done"]: return
	b["done"] = true
	var c := Vector2(b["x"], b["y"])
	var R := BOMB_R * (1.15 if k > 1.0 else 1.0) * nm("kBombR")
	arena.hit_by = "kenin"
	for e in arena.foes():
		var ec: Vector2 = Vector2(e.position.x, e.position.y - 50.0)
		if ec.distance_to(c) < R + 30.0:
			var dd := signf(e.position.x - c.x) if e.position.x != c.x else 1.0
			e.hit(BOMB_DMG * k * (1.0 + nv("kBombDmg")), dd * 9.0, _mul())
			if not in_chain: add_marks(e, 1 + int(nv("kBombMark")))
	arena.hit_by = ""
	booms.append({"x": c.x, "y": c.y, "t": 0.0, "life": 420.0, "big": k > 1.0, "r": R})
	arena.sfx("heavy", 1.0)
	arena.sfx("slam", 0.5)          # PLACEHOLDER: no explosion in the packs yet
	_shake(7.0 if k > 1.0 else 5.0, 1)
	arena.hitstop = maxf(arena.hitstop, 45.0)
	arena.post_wave(c, 1.0 * k, 520.0, 0.25)
	arena.dust(Vector2(c.x, _floor(c.x)), 0, true)
	arena.spark_ring(c, 12)
	if head: arena.text(c + Vector2(0, -60.0), "명중 기폭!", Color("#ffe08a"))


# ---------- the QTE: covering fire from the bench ----------
func _as_ms() -> Array:
	return CH.A_KENIN["headshot"][1]

## owner 2026-11-04: he rolls in slowly (데구르르), uncurls where he can be seen, then fires one heavy shot
const AS_ROLL := 720.0
const AS_UNCURL := 260.0

func assist_lead() -> float:
	return AS_ROLL + AS_UNCURL

func assist_total() -> float:
	var s := assist_lead()
	for v in _as_ms(): s += v
	return s

## what to draw for an assist: [anim, frame, x]
func assist_pose(a: Dictionary) -> Array:
	var t: float = a["t"]
	if t < AS_ROLL:
		var u := 1.0 - pow(1.0 - t / AS_ROLL, 2.2)                       # rolls in, slowing down
		return ["dash", 1 + int(t / 70.0) % 6, lerpf(a["x0"], a["x"], u)]
	if t < AS_ROLL + AS_UNCURL:
		return ["dash", 7 if t < AS_ROLL + AS_UNCURL * 0.5 else 8, a["x"]]
	return ["headshot", _as_frame(t - assist_lead()), a["x"]]

func _as_frame(t: float) -> int:
	var acc := 0.0
	var ms: Array = _as_ms()
	for i in ms.size():
		acc += ms[i]
		if t < acc: return i
	return ms.size() - 1

## he appears at the foe's side, shoots its head and is gone; no swap (player.gd party_input / counter_swap)
func assist(tg) -> void:
	var P = _P()
	if tg == null or not is_instance_valid(tg) or not tg.alive(): tg = P.target(900.0)
	var side: int = P.dir
	var x: float = P.position.x + P.dir * 160.0
	var y: float = P.position.y
	var view: Rect2 = arena.view_rect().grow(-70.0)
	if tg != null:
		# a spot in plain view, clear of the foe and the one in control: past the foe if that is on screen, else on our side
		var away := -1 if tg.position.x < P.position.x else 1
		x = tg.position.x + away * 190.0
		if x < view.position.x or x > view.end.x or absf(x - P.position.x) < 90.0:
			x = tg.position.x - away * 190.0
			if absf(x - P.position.x) < 90.0: x = P.position.x - away * 110.0
		side = 1 if tg.position.x >= x else -1
		var fly: bool = tg.get("M") != null and tg.M.has("fly")
		y = _floor(x) if fly else tg.position.y
	x = clampf(x, 30.0, arena.world_w - 30.0)
	var x0 := clampf(x - side * 340.0, 20.0, arena.world_w - 20.0)                   # rolls in from out there
	assists.append({"x0": x0, "x": x, "y": y, "dir": side, "tg": tg, "t": 0.0, "fired": false, "dust": 0.0})
	arena.sfx("dash", 0.7)

func _step_assists(dt: float) -> void:
	var tot := assist_total()
	for a in assists:
		a["t"] += dt
		if a["t"] < AS_ROLL:
			a["dust"] += dt
			if a["dust"] > 110.0:
				a["dust"] = 0.0
				arena.dust(Vector2(assist_pose(a)[2], a["y"]), -a["dir"], false)
				arena.sfx("foot", 0.35)
			continue
		if not a.get("planted", false):
			a["planted"] = true                                   # the uncurl: feet down, a skid
			arena.dust(Vector2(a["x"], a["y"]), -a["dir"], true)
			arena.sfx("skid", 0.6)
		var ht: float = a["t"] - assist_lead()
		if ht < 0.0: continue
		if not a.get("aimed", false) and _as_frame(ht) >= 3:
			a["aimed"] = true                                   # the aim settles: a click of the hammer
			arena.sfx("ui_move", 0.8, {"st": -9.0})
		if not a["fired"] and _as_frame(ht) >= AS_FIRE:
			a["fired"] = true
			_headshot(a)
	assists = assists.filter(func(a): return a["t"] < tot)

func _headshot(a: Dictionary) -> void:
	var tg = a["tg"]
	var mz := Vector2(a["x"] + a["dir"] * 30.0 * CH.SCALE["kenin"], a["y"] - 50.0 * CH.SCALE["kenin"])
	arena.sfx("thrust", 1.0, {"st": 3.0})          # PLACEHOLDER gunshot
	arena.pfx.hit(mz.x, mz.y, a["dir"], 1.0)
	if tg == null or not is_instance_valid(tg) or not tg.alive():
		return
	var hp: Vector2 = Vector2(tg.position.x, tg.position.y - 70.0)
	# weight (owner 2026-11-04): a long freeze, a hard knock, the screen kicks, the recoil throws dust at his feet
	arena.post_wave(hp, 1.3, 620.0, 0.35)
	arena.post_ca(0.02)
	arena.dust(Vector2(a["x"], a["y"]), -a["dir"], true)
	arena.sfx("slam", 0.8)
	arena.hit_by = "kenin"
	tg.hit(HEAD_DMG * (1.0 + nv("kAssistDmg")), a["dir"] * 12.0, _mul())
	arena.hit_by = ""
	add_marks(tg, MARK_QTE + int(nv("kQteMark")))
	if nv("kQteVuln") > 0.0:
		# 약점 표시: it takes more damage for 8 s (mob.gd reads the meta)
		tg.set_meta("kvuln_t", Time.get_ticks_msec() + VULN_MS)
		tg.set_meta("kvuln", 1.0 + nv("kQteVuln"))
		arena.text(Vector2(tg.position.x, tg.position.y - 150.0), "약점 노출", Color("#ff8a6a"))
	if nv("kQteBomb") > 0.0 and _bomb_on(tg) == null:
		bomb_fx.append({"x": tg.position.x, "y": tg.position.y - 50.0, "vx": 0.0, "vy": 0.0, "m": tg, "ox": randf_range(-10.0, 10.0), "oy": -60.0, "on_floor": false, "t": 0.0, "fuse": FUSE * nm("kFuse"), "done": false})
	arena.spark_ring(hp, 10)
	arena.sfx("heavy", 0.9)
	arena.hitstop = maxf(arena.hitstop, 200.0)        # the headshot holds a long beat so it lands heavy
	arena.flash = maxf(arena.flash, 0.28)
	arena.shake(10, a["dir"])
	arena.big_word("HEADSHOT!", Color("#e8ffb0"), 800.0, Vector2.ZERO, hp + Vector2(0, -70.0))
	var b = _bomb_on(tg)
	if b != null: _explode(b, BOMB_HEAD, true)


# ---------- marks and the chain detonation ----------
## n stamps on a foe's body, each one stamped in with its own pop (the pitch climbs with how many it wears)
func add_marks(m, n: int, cap := MARK_MAX) -> void:
	if m == null or not is_instance_valid(m) or not m.alive(): return
	var id: int = m.get_instance_id()
	if not marks.has(id): marks[id] = {"m": m, "pts": []}
	var pts: Array = marks[id]["pts"]
	var fly: bool = m.get("M") != null and m.M.has("fly")
	for i in n:
		if pts.size() >= cap: break
		var k := pts.size()
		# spread over the body: alternate sides, climbing
		var ox := (-1.0 if k % 2 == 0 else 1.0) * (6.0 + randf() * 12.0)
		var oy := -(20.0 + fmod(k * 23.0 + randf() * 14.0, 70.0)) if not fly else -(randf() * 30.0)
		pts.append({"ox": ox, "oy": oy, "t": -i * 45.0})        # stamped one after another, 45 ms apart
		arena.sfx("ui_ok", 0.45, {"st": minf(14.0, 2.0 * k), "delay_ms": i * 45.0})

## 시한 표식: a stamp older than `ms` pops on its own (one small blast, the stamp gone)
func _mark_fuses(ms: float) -> void:
	for k in marks.keys():
		var e = marks[k]["m"]
		if e == null or not is_instance_valid(e) or not e.alive(): continue
		var pts: Array = marks[k]["pts"]
		for q in pts.duplicate():
			if q["t"] < ms: continue
			pts.erase(q)
			var c := Vector2(e.position.x + q["ox"], e.position.y + q["oy"])
			arena.hit_by = "kenin"
			e.hit(MARK_DMG, 0.0, _mul())
			arena.hit_by = ""
			booms.append({"x": c.x, "y": c.y, "t": 0.0, "life": 280.0, "big": false, "r": 42.0})
			arena.spark(c, 5)
			arena.sfx("hit2", 0.6, {"st": 3.0})
			if not is_instance_valid(e) or not e.alive(): break
		if pts.is_empty(): marks.erase(k)

func marked_count() -> int:
	var n := 0
	for k in marks: n += (marks[k]["pts"] as Array).size()
	return n

## the detonator: every stamp and every bomb into the queue, nearest to `o` first, the gaps shrinking; returns how many
func chain_detonate(o: Vector2) -> int:
	var items: Array = []
	for k in marks:
		var e = marks[k]["m"]
		if e == null or not is_instance_valid(e) or not e.alive(): continue
		for q in marks[k]["pts"]:
			items.append({"kind": "mark", "m": e, "ox": q["ox"], "oy": q["oy"], "d": Vector2(e.position.x + q["ox"], e.position.y + q["oy"]).distance_to(o)})
	for b in bomb_fx:
		if not b["done"]:
			items.append({"kind": "bomb", "b": b, "d": Vector2(b["x"], b["y"]).distance_to(o)})
	marks.clear()
	items.sort_custom(func(x, y): return x["d"] < y["d"])
	var at := 60.0
	var fast := nv("kChainSplash") > 0.0
	var gap := CHAIN_GAP0 * (0.75 if fast else 1.0)
	for i in items.size():
		items[i]["at"] = at
		items[i]["i"] = i
		at += gap
		gap = maxf(CHAIN_GAP_MIN * (0.8 if fast else 1.0), gap * CHAIN_ACC)
	chain = items
	chain_t = 0.0
	chain_n = 0
	chain_tot = items.size()
	return items.size()

func chaining() -> bool:
	return not chain.is_empty()

func _step_chain(dt: float) -> void:
	if chain.is_empty(): return
	chain_t += dt
	while not chain.is_empty() and chain[0]["at"] <= chain_t:
		var it: Dictionary = chain.pop_front()
		chain_n += 1
		var last := chain.is_empty()
		var st := minf(12.0, chain_n * 0.6)               # each pop a little higher
		if it["kind"] == "bomb":
			if not it["b"]["done"]:
				in_chain = true
				_explode(it["b"], 1.6, false)
				in_chain = false
		else:
			var e = it["m"]
			if e != null and is_instance_valid(e) and e.alive():
				var c := Vector2(e.position.x + it["ox"], e.position.y + it["oy"])
				arena.hit_by = "kenin"
				e.hit(MARK_DMG, 0.0, _mul())
				if nv("kChainSplash") > 0.0:
					for o in arena.foes():                                  # 연쇄 반응: the pop spills onto foes nearby
						if o != e and Vector2(o.position.x, o.position.y - 50.0).distance_to(c) < 90.0: o.hit(MARK_DMG * 0.5, 0.0, _mul())
				arena.hit_by = ""
				booms.append({"x": c.x, "y": c.y, "t": 0.0, "life": 300.0, "big": false, "r": 46.0})
				arena.spark(c, 6)
				arena.pfx.hit(c.x, c.y, 1 if it["i"] % 2 == 0 else -1, 0.9)
				arena.sfx("hit2" if it["i"] % 2 == 0 else "hit1", 0.7, {"st": st})
				arena.sfx("slam", 0.25, {"st": st})
				arena.hitstop = maxf(arena.hitstop, 28.0)          # 스톱 모션: every pop holds the world a beat
				_shake(2.0 + minf(6.0, chain_n * 0.4), 1 if it["i"] % 2 == 0 else -1)
		if last:
			_chain_finale(it)

## the chain's last pop: a big one, the count, the screen kicks
func _chain_finale(it: Dictionary) -> void:
	var c: Vector2
	if it["kind"] == "bomb": c = Vector2(it["b"]["x"], it["b"]["y"])
	else:
		var e = it["m"]
		c = Vector2(e.position.x + it["ox"], e.position.y + it["oy"]) if e != null and is_instance_valid(e) else _P().position
	booms.append({"x": c.x, "y": c.y, "t": 0.0, "life": 520.0, "big": true, "r": BOMB_R * 1.25})
	arena.sfx("heavy", 1.0)
	arena.sfx("slam", 0.9)
	arena.hitstop = maxf(arena.hitstop, 90.0)
	arena.flash = maxf(arena.flash, 0.3)
	_shake(10.0 + minf(8.0, chain_tot * 0.5), 1)
	arena.post_wave(c, 1.4, 600.0, 0.35)
	arena.post_ca(0.02)
	arena.spark_ring(c, 16)
	if chain_tot >= 2: arena.big_word("연쇄 ×%d" % chain_tot, Color("#e8ffb0"), 900.0, Vector2.ZERO, c + Vector2(0, -90.0))

## ult.gd: a shot that always lands (a tracer toward `at`, the damage dealt by ult.gd), each one a stamp on the foe
func ult_shot(o: Vector2, at: Vector2, m) -> void:
	var v := (at - o).normalized() * SHOT_V * 1.6
	var life := clampf(o.distance_to(at) / (SHOT_V * 1.6), 20.0, 200.0)
	shots.append({"x": o.x, "y": o.y, "vx": v.x, "vy": v.y, "dmg": 0.0, "dry": false, "t": SHOT_LIFE - life, "mul": _mul(), "fake": true})
	arena.sfx("thrust", 0.85, {"st": 5.0 + randf() * 2.0})
	arena.pfx.hit(at.x, at.y, 1 if v.x >= 0.0 else -1, 0.9)
	arena.spark(o, 3)
	if m != null and is_instance_valid(m) and m.alive():
		add_marks(m, 1, 40)

## the detonator with nothing to set off: the box itself kicks (a small blast in front of him)
func dud_blast(c: Vector2) -> void:
	arena.hit_by = "kenin"
	for e in arena.foes():
		if Vector2(e.position.x, e.position.y - 50.0).distance_to(c) < 90.0:
			e.hit(BOMB_DMG * 0.6, signf(e.position.x - c.x) * 6.0, _mul())
	arena.hit_by = ""
	booms.append({"x": c.x, "y": c.y, "t": 0.0, "life": 320.0, "big": false, "r": 70.0})
	arena.sfx("slam", 0.6)
	_shake(4.0, 1)
	arena.spark_ring(c, 8)

## ult.gd: a bomb slapped straight onto the foe
func ult_bomb(m) -> void:
	if m == null or not is_instance_valid(m) or not m.alive(): return
	bomb_fx.append({"x": m.position.x, "y": m.position.y - 50.0, "vx": 0.0, "vy": 0.0, "m": m, "ox": randf_range(-14.0, 14.0), "oy": randf_range(-80.0, -30.0), "on_floor": false, "t": 0.0, "fuse": 99999.0, "done": false})
	arena.sfx("ui_move", 0.6, {"st": -7.0})

func live_bombs() -> int:
	return bomb_fx.filter(func(b): return not b["done"]).size()


# ---------- drawing (arena.fx_layer, in pixels) ----------
const OLV := Color("#9cc14a")
const OLV_L := Color("#e2f5b8")
const BRASS := Color("#f1c35a")
const SOOT := Color("#26231f")
const MARK_COL := [Color("#9cc14a"), Color("#c9d64a"), Color("#f1c35a"), Color("#f0963a"), Color("#ff5a3a")]

func draw(g: CanvasItem) -> void:
	var t := float(Time.get_ticks_msec())
	# the covering shot's aim (frames 3-4): a dotted line to the head, a crosshair closing in on it
	for a in assists:
		var ht: float = a["t"] - assist_lead()
		if a["fired"] or ht < 0.0 or _as_frame(ht) < 3: continue
		var tg = a["tg"]
		if tg == null or not is_instance_valid(tg) or not tg.alive(): continue
		var mz := Vector2(a["x"] + a["dir"] * 30.0 * CH.SCALE["kenin"], a["y"] - 50.0 * CH.SCALE["kenin"])
		var hd := Vector2(tg.position.x, tg.position.y - 70.0)
		var acc := 0.0
		for i in 3: acc += _as_ms()[i]
		var k := clampf((ht - acc) / (_as_ms()[3] + _as_ms()[4]), 0.0, 1.0)
		var n := int(mz.distance_to(hd) / 10.0)
		for i in n:
			if i % 2 == 0: g.draw_line(mz.lerp(hd, float(i) / n), mz.lerp(hd, float(i + 1) / n), Color(1, 0.3, 0.2, 0.35 + 0.4 * k), 2.0)
		var cr := lerpf(26.0, 9.0, k)
		var cp := PFX.PX.new(g, hd.x, hd.y)
		cp.circle(0, 0, cr / PFX.S, Color(1, 0.3, 0.2, 0.6 + 0.4 * k))
		cp.line(-cr / PFX.S - 3, 0, -cr / PFX.S + 2, 0, Color.WHITE)
		cp.line(cr / PFX.S - 2, 0, cr / PFX.S + 3, 0, Color.WHITE)
		cp.line(0, -cr / PFX.S - 3, 0, -cr / PFX.S + 2, Color.WHITE)
		cp.line(0, cr / PFX.S - 2, 0, cr / PFX.S + 3, Color.WHITE)
	# 약점 표시: a red cracked-shield mark over the foe while it lasts (blinks in its last second)
	for e in arena.foes():
		if not e.has_meta("kvuln_t"): continue
		var left := float(e.get_meta("kvuln_t")) - t
		if left <= 0.0 or (left < 1000.0 and int(t / 120.0) % 2 == 0): continue
		var fly: bool = e.get("M") != null and e.M.has("fly")
		var p := PFX.PX.new(g, e.position.x + 22.0, e.position.y - (60.0 if fly else 132.0))
		var rc := Color("#ff5a3a")
		p.rect(-3, -3, 7, 6, rc)
		p.rect(-2, 3, 5, 1, rc)
		p.rect(-1, 4, 3, 1, rc)
		p.px(0, -2, Color.WHITE)
		p.px(1, -1, Color.WHITE)
		p.px(0, 0, Color.WHITE)
		p.px(1, 1, Color.WHITE)
	for s in shots:
		if s["t"] < 0.0: continue
		var p := PFX.PX.new(g, s["x"], s["y"])
		var dl := Vector2(s["vx"], s["vy"]).normalized() * -5.0
		if s["dry"]:
			p.px(0, 0, Color("#b9bfa8"))
			p.px(dl.x * 0.4, dl.y * 0.4, Color(0.72, 0.75, 0.66, 0.5))
		elif s.get("big", false):
			# the finisher's big round: a fat slug with a long hot trail
			p.line(dl.x * 3.0, dl.y * 3.0, 0, 0, Color("#f08a3a"))
			p.line(dl.x * 1.6, dl.y * 1.6, 0, 0, BRASS)
			p.disc(0, 0, 1.6, Color.WHITE)
		else:
			p.line(dl.x, dl.y, 0, 0, BRASS)
			p.px(0, 0, Color.WHITE)
			p.px(dl.x * 0.5, dl.y * 0.5, OLV_L)
	for b in bomb_fx:
		var p := PFX.PX.new(g, b["x"], b["y"])
		p.disc(0, 0, 3.4, SOOT)
		p.px(-1, -1, Color("#5b544a"))
		p.rect(-1, -5, 2, 1, Color("#6b6156"))
		var blink: bool = b["fuse"] < 900.0 and int(b["fuse"] / 90.0) % 2 == 0 or b["fuse"] >= 900.0 and int(b["fuse"] / 220.0) % 2 == 0
		p.px(1, -6, Color("#ff5a3a") if blink else Color("#ffd08a"))
	# stamps (owner 2026-11-04: many hid the foe): one mark per foe, beside its head, with the count — it pops when a stamp
	# lands, throbs faster and turns hotter the more it wears
	for k in marks:
		var e = marks[k]["m"]
		if e == null or not is_instance_valid(e) or not e.alive(): continue
		var pts: Array = marks[k]["pts"]
		var n := 0
		var newest := 1.0e9
		for q in pts:
			if q["t"] < 0.0: continue
			n += 1
			newest = minf(newest, q["t"])
		if n == 0: continue
		var cc: Color = MARK_COL[mini(MARK_COL.size() - 1, n - 1)]
		var beat := maxf(110.0, 330.0 - n * 30.0)
		var pop := 1.0 + maxf(0.0, 1.0 - newest / 140.0) * 0.8
		var r := (3.0 + (0.6 if int(t / beat) % 2 == 0 else 0.0)) * pop
		var fly: bool = e.get("M") != null and e.M.has("fly")
		var mp := Vector2(e.position.x - 26.0, e.position.y - (58.0 if fly else 126.0))
		var p := PFX.PX.new(g, mp.x, mp.y)
		p.disc(0, 0, r + 1.0, Color(0, 0, 0, 0.55))
		p.circle(0, 0, r, cc)
		p.line(-r - 2, 0, -r + 1, 0, OLV_L)
		p.line(r - 1, 0, r + 2, 0, OLV_L)
		p.line(0, -r - 2, 0, -r + 1, OLV_L)
		p.line(0, r - 1, 0, r + 2, OLV_L)
		if newest < 70.0: p.disc(0, 0, r * 0.6, Color.WHITE)
		if n >= 2:
			var fs := int(16.0 * (1.0 + (pop - 1.0) * 0.5))
			var txt := "×%d" % n
			var tp := mp + Vector2(r * PFX.S + 6.0, fs * 0.38)
			for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(1, 1)]:
				g.draw_string(UI.anton(true), tp + o * 1.5, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
			g.draw_string(UI.anton(true), tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, cc.lightened(0.25))
	for bo in booms:
		var kk: float = bo["t"] / bo["life"]
		var rad: float = float(bo.get("r", BOMB_R * (1.15 if bo["big"] else 1.0))) / PFX.S
		var p := PFX.PX.new(g, bo["x"], bo["y"])
		var f := PFX.fr(bo["t"])
		if f < 2: p.disc(0, 0, rad * 0.45, Color("#fff4cf"))
		var cc: Color = [Color("#fff4cf"), Color("#ffd06a"), Color("#f08a3a"), Color("#8c4a2a"), Color("#3a2a22")][mini(4, int(kk * 5.0))]
		p.circle(0, 0, rad * (0.35 + kk * 0.75), cc)
		if kk < 0.6: p.circle(0, 0, rad * (0.35 + kk * 0.75) - 1.0, cc)
		for i in 10:
			if kk > 0.7: break
			var a := i / 10.0 * TAU + 0.2
			var r0 := rad * (0.4 + kk * 0.8)
			var r1 := r0 + (5.0 if i % 2 else 2.0) * (1.0 - kk)
			p.line(cos(a) * r0, sin(a) * r0, cos(a) * r1, sin(a) * r1, OLV_L if i % 3 == 0 else Color("#ffd06a"))
