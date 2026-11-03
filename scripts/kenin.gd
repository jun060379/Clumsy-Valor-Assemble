extends RefCounted
## 케닌 클로 (도적 · 원거리 · 트릭스터): the pistol, the sticky bombs, the QTE covering shot and the chain detonation.
## Lives on the arena as `arena.kenin`; player.gd calls fire / throw / assist, ult.gd calls detonate_all.
## The loop the owner set (2026-11-03): from the bench his QTE shoots a foe's head without swapping (a mark, the swap
## cooldown reset); out front he empties the cylinder and the bombs at high power, then he is weak until he reloads —
## and he reloads fast only off the field, so he goes back into the party to rearm.
##   ammo   AMMO shots out front; empty = the "dry" shots (×DRY). On the field an empty pistol reloads after
##          RELOAD_FIELD ms; on the bench one round comes back every RELOAD_BENCH ms.
##   bombs  BOMBS charges; one back every BOMB_BENCH ms on the bench, BOMB_FIELD ms out front. A thrown bomb sticks to
##          the first foe it touches (or rests on the floor) and blows after FUSE ms; a bullet hitting a foe that wears
##          one sets it off at once ×BOMB_HEAD.
##   marks  the QTE headshot leaves a mark on the foe (stacks); the ult detonates every mark and every bomb.
## Every number here is a PLACEHOLDER until the owner tunes it.

const CH := preload("res://scripts/chars.gd")
const PFX := preload("res://scripts/pfx.gd")

const AMMO := 6
const BOMBS := 3
const RELOAD_FIELD := 2600.0
const RELOAD_BENCH := 300.0
const BOMB_BENCH := 1600.0
const BOMB_FIELD := 7000.0
const FUSE := 2500.0
const DRY := 0.25
const BOMB_DMG := 3.0
const BOMB_R := 120.0
const BOMB_HEAD := 1.5
const HEAD_DMG := 4.0
const MARK_DMG := 2.5
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
var marks := {}                 # instance id -> {m, n}
var assists: Array = []         # {x, y, dir, tg, t, fired}


func _init(a) -> void:
	arena = a

func reset() -> void:
	ammo = AMMO
	bombs = BOMBS
	reload_t = 0.0
	bomb_t = 0.0
	shots.clear()
	bomb_fx.clear()
	booms.clear()
	marks.clear()
	assists.clear()

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
	if field:
		if ammo <= 0:
			reload_t += dt
			if reload_t >= RELOAD_FIELD:
				ammo = AMMO
				reload_t = 0.0
				arena.sfx("ui_ok", 0.5)
				arena.text(P.position + Vector2(0, -150.0 * P.CSCALE), "재장전 완료", Color("#e2f5b8"))
		else:
			reload_t = 0.0
	elif ammo < AMMO:
		reload_t += dt
		while reload_t >= RELOAD_BENCH and ammo < AMMO:
			reload_t -= RELOAD_BENCH
			ammo += 1
	if bombs < BOMBS:
		bomb_t += dt
		var need := BOMB_FIELD if field else BOMB_BENCH
		if bomb_t >= need:
			bomb_t = 0.0
			bombs += 1
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


# ---------- the pistol ----------
## one shot from the muzzle (o) along d (a unit vector); empty = a dry click with a weak ball
func fire(o: Vector2, d: Vector2, dmg: float) -> void:
	var is_dry := ammo <= 0
	if not is_dry: ammo -= 1
	var k := DRY if is_dry else 1.0
	shots.append({"x": o.x, "y": o.y, "vx": d.x * SHOT_V, "vy": d.y * SHOT_V, "dmg": dmg * k, "dry": is_dry, "t": 0.0, "mul": _mul()})
	# PLACEHOLDER sounds: there is no gunshot in the packs yet (the stab, pitched up); a dry pistol clicks
	if is_dry:
		arena.sfx("ui_move", 0.7, {"st": -4.0})
		if ammo <= 0 and reload_t < 200.0 and on_field():
			arena.text(_P().position + Vector2(0, -150.0 * _P().CSCALE), "탄창 비었음", Color("#b9bfa8"))
	else:
		arena.sfx("thrust", 0.75, {"st": 5.0})
	arena.pfx.hit(o.x, o.y, int(signf(d.x)) if d.x != 0.0 else 1, 0.55 if is_dry else 0.8)

func _step_shots(dt: float) -> void:
	for s in shots:
		s["t"] += dt
		var x0: float = s["x"]
		s["x"] += s["vx"] * dt
		s["y"] += s["vy"] * dt
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
	m.hit(s["dmg"], signf(s["vx"]) * (1.5 if s["dry"] else 3.0), s["mul"])
	arena.hit_by = ""
	arena.spark(Vector2(s["x"], s["y"]), 4 if s["dry"] else 7)
	arena.sfx("hit1", 0.4 if s["dry"] else 0.6)
	if not s["dry"]:
		arena.ult_gain(2.0)
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
	var v := 0.5
	if not is_nan(tx) and (tx - o.x) * d > 0.0: v = clampf(absf(tx - o.x) / 290.0, 0.3, 1.1)
	bomb_fx.append({"x": o.x, "y": o.y, "vx": d * v, "vy": -0.3, "m": null, "ox": 0.0, "oy": 0.0, "on_floor": false, "t": 0.0, "fuse": FUSE, "done": false})
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
	var R := BOMB_R * (1.15 if k > 1.0 else 1.0)
	arena.hit_by = "kenin"
	for e in arena.foes():
		var ec: Vector2 = Vector2(e.position.x, e.position.y - 50.0)
		if ec.distance_to(c) < R + 30.0:
			var dd := signf(e.position.x - c.x) if e.position.x != c.x else 1.0
			e.hit(BOMB_DMG * k, dd * 9.0, _mul())
	arena.hit_by = ""
	booms.append({"x": c.x, "y": c.y, "t": 0.0, "life": 420.0, "big": k > 1.0})
	arena.sfx("heavy", 1.0)
	arena.sfx("slam", 0.5)          # PLACEHOLDER: no explosion in the packs yet
	arena.shake(7.0 if k > 1.0 else 5.0, 1)
	arena.hitstop = maxf(arena.hitstop, 45.0)
	arena.post_wave(c, 1.0 * k, 520.0, 0.25)
	arena.dust(Vector2(c.x, _floor(c.x)), 0, true)
	arena.spark_ring(c, 12)
	if head: arena.text(c + Vector2(0, -60.0), "명중 기폭!", Color("#ffe08a"))


# ---------- the QTE: covering fire from the bench ----------
func _as_ms() -> Array:
	return CH.A_KENIN["headshot"][1]

func assist_total() -> float:
	var s := 0.0
	for v in _as_ms(): s += v
	return s

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
	var side := 1
	var x: float = P.position.x + P.dir * 160.0
	var y: float = P.position.y
	if tg != null:
		# from behind the foe (the far side from the one in control), facing its back
		var away := -1 if tg.position.x < P.position.x else 1
		x = tg.position.x + away * 80.0
		side = -away
		var fly: bool = tg.get("M") != null and tg.M.has("fly")
		y = _floor(x) if fly else tg.position.y
	assists.append({"x": clampf(x, 30.0, arena.world_w - 30.0), "y": y, "dir": side, "tg": tg, "t": 0.0, "fired": false})
	arena.sfx("dash", 0.6)
	arena.dust(Vector2(x, y), 0, false)

func _step_assists(dt: float) -> void:
	var tot := assist_total()
	for a in assists:
		a["t"] += dt
		if not a["fired"] and _as_frame(a["t"]) >= AS_FIRE:
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
	arena.hit_by = "kenin"
	tg.hit(HEAD_DMG, a["dir"] * 6.0, _mul())
	arena.hit_by = ""
	var id: int = tg.get_instance_id()
	if marks.has(id): marks[id]["n"] += 1
	else: marks[id] = {"m": tg, "n": 1}
	arena.spark_ring(hp, 10)
	arena.sfx("heavy", 0.9)
	arena.hitstop = maxf(arena.hitstop, 70.0)
	arena.flash = maxf(arena.flash, 0.18)
	arena.shake(5, a["dir"])
	arena.text(hp + Vector2(0, -40.0), "HEADSHOT!", Color("#e8ffb0"))
	var b = _bomb_on(tg)
	if b != null: _explode(b, BOMB_HEAD, true)


# ---------- the ult: 연쇄 기폭 ----------
## every bomb and every mark goes off; returns how many went
func detonate_all() -> int:
	var n := 0
	for b in bomb_fx.duplicate():
		if not b["done"]:
			_explode(b, 1.6, false)
			n += 1
	arena.hit_by = "kenin"
	for k in marks.keys():
		var e = marks[k]["m"]
		if e != null and is_instance_valid(e) and e.alive():
			var st: int = marks[k]["n"]
			e.hit(MARK_DMG * st, 0.0, _mul())
			booms.append({"x": e.position.x, "y": e.position.y - 70.0, "t": 0.0, "life": 420.0, "big": st > 1})
			arena.spark_ring(Vector2(e.position.x, e.position.y - 70.0), 10)
			n += st
	arena.hit_by = ""
	marks.clear()
	return n

func marked_count() -> int:
	var n := 0
	for k in marks: n += int(marks[k]["n"])
	return n

func live_bombs() -> int:
	return bomb_fx.filter(func(b): return not b["done"]).size()


# ---------- drawing (arena.fx_layer, in pixels) ----------
const OLV := Color("#9cc14a")
const OLV_L := Color("#e2f5b8")
const BRASS := Color("#f1c35a")
const SOOT := Color("#26231f")

func draw(g: CanvasItem) -> void:
	var t := float(Time.get_ticks_msec())
	for s in shots:
		var p := PFX.PX.new(g, s["x"], s["y"])
		var dl := Vector2(s["vx"], s["vy"]).normalized() * -5.0
		if s["dry"]:
			p.px(0, 0, Color("#b9bfa8"))
			p.px(dl.x * 0.4, dl.y * 0.4, Color(0.72, 0.75, 0.66, 0.5))
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
	for k in marks:
		var e = marks[k]["m"]
		if e == null or not is_instance_valid(e) or not e.alive(): continue
		var p := PFX.PX.new(g, e.position.x, e.position.y - 128.0)
		var r := 4.0 + (1.0 if int(t / 260.0) % 2 == 0 else 0.0)
		p.circle(0, 0, r, OLV)
		p.line(-r - 2, 0, -r + 1, 0, OLV_L)
		p.line(r - 1, 0, r + 2, 0, OLV_L)
		p.line(0, -r - 2, 0, -r + 1, OLV_L)
		p.line(0, r - 1, 0, r + 2, OLV_L)
		if marks[k]["n"] > 1:
			for i in mini(5, marks[k]["n"]):
				p.px(-4 + i * 2, r + 4, BRASS)
	for bo in booms:
		var kk: float = bo["t"] / bo["life"]
		var rad: float = (BOMB_R * (1.15 if bo["big"] else 1.0)) / PFX.S
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
