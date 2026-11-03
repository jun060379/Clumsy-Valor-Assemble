extends Node2D
## 궁극기 (prototype ULT / ultGain / ultTick / tryUlt / ultBegin / ultStep / ultEnd / drawUltWorld):
## every member has their own 기력 gauge (390 / 300 / 240); hits dealt fill it (damage x0.7), a blocked hit +5, a hit
## taken +12; members on standby fill at 0.4x. A full gauge AND the 30 s cooldown since the last use let the ult key fire:
## the cut-in (ult_cut.gd: splash, then the clip) holds the world, then the scripted move plays with the input held:
##   에스텔 「수호의 맹세」: the oath (crest stamped, shield rising), 8 s in which every blow is parried, roses wheel round her
##   아이다 「땅 밑의 문」: sigils sprayed out engrave runes on and around foes; rifts open one after another, she bursts
##        out of each faster and faster; every rune on a foe detonates
##   루체 「루체 펀치」: a star blooms over her raised hand, she grabs it and punches it forward as a beam
## Ult damage is x2.5 across the board. The cut-in opens on parry + slam; each move's impact (the oath, the runes'
## detonation, the punch) plays ult.wav on the music's grid and ducks the track (arena.sfx "ult").

const CH := preload("res://scripts/chars.gd")
const ULTMAX := {"estelle": 390.0, "aida": 300.0, "luce": 240.0, "kenin": 270.0}       # kenin: PLACEHOLDER
const INFO := {
	"estelle": {"name": "수호의 맹세", "sub": "ESTELLE BELLACITA", "col": Color8(255, 110, 190), "col2": Color8(255, 220, 240)},
	"aida": {"name": "땅 밑의 문", "sub": "SUNAGAWA AYDA", "col": Color8(120, 50, 220), "col2": Color8(210, 180, 255)},
	"luce": {"name": "루체 펀치", "sub": "LUCE LUMEN", "col": Color8(255, 200, 80), "col2": Color8(255, 248, 220)},
	"kenin": {"name": "연쇄 기폭", "sub": "KENIN CLAW", "col": Color8(140, 180, 60), "col2": Color8(230, 245, 200)},
}
const PAL := {"estelle": ["#ffffff", "#ffd3ea", "#ff96d2", "#d650aa", "#7a2a66"], "aida": ["#ffffff", "#e9d2ff", "#b06cff", "#7a3ad0", "#3a1260"], "luce": ["#ffffff", "#ffe9a0", "#ffd34d", "#e8a33a", "#a8742a"], "kenin": ["#ffffff", "#eef8d8", "#c4e07a", "#8fbf3a", "#4a6a1e"]}
const IRIS := ["#ff6fae", "#ffa96b", "#ffe97a", "#86ffb4", "#6fd8ff", "#8f8cff", "#e07aff"]
const CD := 30000.0
const DMG := 2.5
const VOW := 8000.0

var arena
var v := {"estelle": 0.0, "aida": 0.0, "luce": 0.0, "kenin": 0.0}
var cd := {"estelle": 0.0, "aida": 0.0, "luce": 0.0, "kenin": 0.0}
var state := ""                 # "" / cut / act
var t := 0.0
var who := "estelle"
var fx: Array = []
var done := {}
var sh := {}                    # Aida's plan: pts, times, gap, t0, cur
var star = null
var auto_t := 0.0               # Estelle's vow: auto-parry time left
var ualpha := 1.0
var glow: Node2D


func _ready() -> void:
	z_index = 9
	glow = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	glow.draw.connect(_draw_glow)
	add_child(glow)


# ---------- the gauge ----------
func cur() -> String:
	return arena.player.who

func value(c := "") -> float:
	return v[cur() if c == "" else c]

func vmax(c := "") -> float:
	return ULTMAX[cur() if c == "" else c]

func frac(c := "") -> float:
	return clampf(value(c) / vmax(c), 0.0, 1.0)

func ready_now(c := "") -> bool:
	var k := cur() if c == "" else c
	return v[k] >= ULTMAX[k] and cd[k] <= 0.0

## ultTick: cooldowns; "궁극기 준비!" when it comes back with a full gauge; the vow runs down
func tick(dt: float) -> void:
	for c in cd:
		if cd[c] > 0.0:
			cd[c] = maxf(0.0, cd[c] - dt)
			if c == cur() and cd[c] == 0.0 and v[c] >= ULTMAX[c]:
				_ready_fx()
	if auto_t > 0.0: auto_t = maxf(0.0, auto_t - dt)

## ultGain
func gain(n: float) -> void:
	if state != "" or auto_t > 0.0: return
	var P = arena.player
	for c in P.party:
		if c != P.who: v[c] = minf(ULTMAX[c], v[c] + n * 0.4)
	var c0: String = P.who
	var was: bool = v[c0] >= ULTMAX[c0]
	v[c0] = minf(ULTMAX[c0], v[c0] + n)
	if not was and v[c0] >= ULTMAX[c0] and cd[c0] <= 0.0:
		_ready_fx()

func _ready_fx() -> void:
	var P = arena.player
	arena.sfx("ui_ok", 0.8)
	arena.text(P.position + Vector2(0, -150.0 * P.CSCALE), "궁극기 준비!", Color("#ffe9a8"))

## tryUlt
func try_ult() -> bool:
	var P = arena.player
	if state != "" or not ready_now() or P.hp <= 0.0 or P.anim == "death" or arena.fade_dir != 0:
		return false
	who = P.who
	v[who] = 0.0
	cd[who] = CD
	state = "cut"
	t = 0.0
	P.vx = 0.0
	P.inv = 99999.0
	arena.ucut().start(who)
	var vr: Rect2 = arena.view_rect()
	arena.post_wave(Vector2(vr.get_center().x, vr.position.y + 250.0 * vr.size.y / get_viewport_rect().size.y), 1.6, 700.0, 0.7)
	arena.post_ca(0.02)
	arena.sfx("ult_charge", 1.0)          # the cut-in: the charge
	arena.sfx("slam", 0.5)
	return true

## the world clock while the cut-in plays (it holds everything else)
func cut_step(dt: float) -> void:
	t += dt
	if t >= arena.ucut().length(who):
		state = "act"
		arena.ucut().stop()
		begin()


# ---------- the move ----------
func _foes() -> Array:
	return arena.foes()

static func _ey(e) -> float:
	var fly: bool = e.get("M") != null and e.M.has("fly")
	return e.position.y - (10.0 if fly else 55.0)

func begin() -> void:
	t = 0.0
	fx.clear()
	done = {}
	star = null
	ualpha = 1.0
	var P = arena.player
	var near: Array = _foes().filter(func(e): return absf(e.position.x - P.position.x) < 620.0)
	near.sort_custom(func(a, b): return absf(a.position.x - P.position.x) < absf(b.position.x - P.position.x))
	if who == "aida":
		var pts: Array = []
		for e in near.slice(0, 6):
			pts.append({"e": e, "x": e.position.x, "y": _ey(e), "lit": false})
		var want := maxi(9, pts.size() * 2 + 3)
		var G: float = arena.ground_y
		for i in range(pts.size(), want):
			var a := float(i) / want * TAU + randf() * 0.5
			var r := 170.0 + randf() * 230.0
			pts.append({"e": null, "x": clampf(P.position.x + cos(a) * r * 1.3, 40.0, arena.world_w - 40.0), "y": clampf(P.position.y - 80.0 + sin(a) * r * 0.75, G - 330.0, G - 60.0), "lit": false})
		# visiting order: nearest neighbour from where she stands
		var order: Array = []
		var cx: float = P.position.x
		var cy: float = P.position.y - 80.0
		var left := pts.duplicate()
		while not left.is_empty():
			var bi := 0
			var bd := 1.0e9
			for i in left.size():
				var d := Vector2(left[i]["x"] - cx, left[i]["y"] - cy).length()
				if d < bd:
					bd = d
					bi = i
			var p: Dictionary = left[bi]
			left.remove_at(bi)
			order.append(p)
			cx = p["x"]
			cy = p["y"]
		var times: Array = []
		var gap: Array = []
		var tt := order.size() * 34.0 + 330.0
		var g := 250.0
		for i in order.size():
			times.append(tt)
			gap.append(g)
			tt += g
			g = maxf(55.0, g * 0.8)
		sh = {"pts": order, "times": times, "gap": gap, "t0": order.size() * 34.0 + 330.0, "cur": null}
		for i in order.size():
			fx.append({"k": "rune", "p": order[i], "i": i, "t": 0.0, "life": 99999.0})

func once(k: String) -> bool:
	if done.has(k): return false
	done[k] = true
	return true

func pose(an: String, f: int) -> void:
	var P = arena.player
	P.anim = an
	P.f = f
	P.ft = 0.0
	P.hit_done = true
	P.fx_done = true
	P.vx = 0.0

func hit(e, dmg: float) -> void:
	if e == null or not is_instance_valid(e) or not e.alive(): return
	var P = arena.player
	e.hit(dmg * DMG, P.dir * 5.0, P.atk_mul())
	arena.spark(e.position + Vector2(0, -50), 14)

## ultStep (the world ran this frame with the keys held; she is posed on top)
func step(dt: float) -> void:
	if state != "act": return
	t += dt
	var P = arena.player
	P.inv = 600.0
	var S: float = P.CSCALE
	if who == "estelle":
		pose("vow", 0 if t < 140.0 else (1 if t < 300.0 else 2))
		if once("vow"):
			arena.post_wave(P.position + Vector2(0, -70.0), 1.4, 650.0, 0.4)
			auto_t = VOW
			fx.append({"k": "oath", "x": P.position.x, "y": P.position.y, "s": S * 0.9, "t": 0.0, "life": 1000.0})
			fx.append({"k": "rose", "t": 0.0, "life": 99999.0, "end": -1.0, "n": 30})
			for e in _foes():
				if absf(e.position.x - P.position.x) < 260.0 and absf(e.position.y - P.position.y) < 160.0: hit(e, 2.0)
			arena.sfx("ult", 1.0)              # the impact (snapped to the grid, the music ducks 6 dB)
			arena.sfx("parry", 1.0)
			arena.flash = 0.3
			arena.shake(6, P.dir)
			arena.impact("ult", P.position + Vector2(0, -70.0), P.dir)   # 타격감
		if t >= 420.0: end()
	elif who == "aida":
		_step_aida(dt, P, S)
	elif who == "kenin":
		_step_kenin(dt, P, S)
	else:
		_step_luce(dt, P, S)

func _step_aida(_dt: float, P, S: float) -> void:
	var pts: Array = sh["pts"]
	# 1) sigils sprayed in every direction
	if t < sh["t0"]:
		pose("ucast", 0 if t < 180.0 else (1 if t < sh["t0"] * 0.6 else (2 if t < sh["t0"] * 0.85 else 3)))
		ualpha = 1.0
		for i in pts.size():
			if t >= i * 34.0 and once("sg%d" % i):
				fx.append({"k": "sigil", "x0": P.position.x + P.dir * 44.0 * S, "y0": P.position.y - 78.0 * S, "p": pts[i], "t": 0.0, "life": 230.0})
				if i % 3 == 0: arena.sfx("swing", 0.35)
		return
	# 2) rifts open one after another; she bursts out of each, faster and faster
	var times: Array = sh["times"]
	var gaps: Array = sh["gap"]
	var j := -1
	for i in times.size():
		if t >= times[i]: j = i
	if j >= 0 and j < pts.size() and t < times[j] + gaps[j]:
		var p: Dictionary = pts[j]
		if once("j%d" % j):
			P.add_ghost(200.0)
			var px: float = P.position.x
			var py: float = P.position.y - 70.0 * S
			var nx := 0.0
			var ny := 0.0
			var d := 1
			var e = p["e"]
			var live: bool = e != null and is_instance_valid(e) and e.alive()
			if live:
				var side := 1 if j % 2 == 1 else -1
				nx = e.position.x + side * 62.0
				ny = e.position.y if not (e.M.has("fly")) else arena.ground_y
				d = -side
			else:
				nx = p["x"]
				ny = minf(arena.ground_y, p["y"] + 70.0 * S)
				d = int(signf(p["x"] - px)) if p["x"] != px else P.dir
			nx = clampf(nx, 30.0, arena.world_w - 30.0)
			fx.append({"k": "trail", "x0": px, "y0": py, "x1": nx, "y1": ny - 70.0 * S, "t": 0.0, "life": 260.0})
			fx.append({"k": "hollow", "x": nx - d * 38.0 * S, "y": ny - 70.0 * S, "r": (110.0 + (20.0 if live else 0.0)) * S * 0.27, "t": 0.0, "life": maxf(320.0, gaps[j] * 2.4), "seed": randf() * 9.0})
			sh["cur"] = {"x": nx, "y": ny, "dir": d, "t0": t}
			p["lit"] = true
			arena.sfx("dig", 0.5 + 0.3 * minf(1.0, j / 8.0))
			if live:
				var a0: float = [-0.96, 0.96, PI / 2.0, 0.0][randi() % 4] + (randf() - 0.5) * 0.25
				fx.append({"k": "tear", "x": e.position.x, "y": _ey(e), "ang": a0, "len": (150.0 + randf() * 50.0) * S, "t": 0.0, "life": 420.0})
				hit(e, 1.0)
				if j < 4: arena.hitstop = 30.0
				arena.shake(4.0 + j * 0.4, d)
				arena.sfx("hit%d" % (j % 3 + 1), 0.8)       # the rifts' hits climb F / A / C as they come faster
		var c: Dictionary = sh["cur"]
		P.position = Vector2(c["x"], c["y"])
		P.vy = 0.0
		P.dir = c["dir"]
		var lt: float = t - c["t0"]
		var gp: float = gaps[j]
		pose("ulunge", 0 if lt < gp * 0.3 else (1 if lt < gp * 0.55 else (2 if lt < gp * 0.8 else 3)))
		ualpha = minf(1.0, 0.25 + lt / maxf(50.0, gp * 0.45))
		if lt < gp * 0.5: P.position.x = c["x"] + c["dir"] * (lt / (gp * 0.5) - 1.0) * -28.0
		return
	# 3) every rune on a foe detonates
	var tf: float = times[times.size() - 1] + maxf(180.0, gaps[gaps.size() - 1])
	if t >= tf:
		var u := t - tf
		ualpha = 1.0
		pose("ufin", 0 if u < 200.0 else (1 if u < 420.0 else (2 if u < 700.0 else 3)))
		if u >= 420.0 and once("boom"):
			arena.post_ca(0.025)
			for f in fx:
				if f["k"] != "rune": continue
				f["life"] = f["t"] + 1.0
				var p: Dictionary = f["p"]
				var e = p["e"]
				var live: bool = e != null and is_instance_valid(e) and e.alive()
				var bx: float = e.position.x if live else p["x"]
				var by: float = (_ey(e) + 5.0) if live else p["y"]
				fx.append({"k": "burst", "x": bx, "y": by, "r": 130.0 if live else 60.0, "t": 0.0, "life": 520.0})
				if live: arena.post_wave(Vector2(bx, e.position.y - 50.0), 1.0, 560.0, 0.2)
				if live: hit(e, 2.0)
			arena.sfx("ult", 1.0)              # the impact
			arena.sfx("slam", 1.0)
			arena.shake(15, P.dir)
			arena.flash = 0.35
			arena.hitstop = 100.0
			arena.impact("ult", P.position + Vector2(P.dir * 120.0, -60.0), P.dir)   # 타격감
		if u > 1250.0: end()

## 케닌 「연쇄 기폭」: one foe. A snap reload, then he blinks around it — ground, air, low, overhead, the far side — two
## shots from every spot (each one a stamp, kenin.gd ult_shot) and bombs slapped onto it; reload again, the same round
## faster; then he lands behind it, sets the box down, grins, and slams the plunger: every stamp and bomb goes off in a
## chain (kenin.gd chain_detonate). Every blink holds the world a beat (스톱 모션) and leaves an afterimage.
## spot: [dx, dy (above the foe's feet; 0 = on the floor), faces (+1 = toward the foe), anim, frames, muzzle, bomb]
const K_SPOTS := [
	[-150.0, 0.0, "attack1", [1, 2, 3, 4], "flat", false],
	[130.0, 170.0, "air_combo", [1, 2, 4, 5], "flat", true],
	[-190.0, 0.0, "kneel_attack", [2, 3, 4, 5], "kneel", false],
	[-30.0, 290.0, "dive", [0, 1, 1, 2], "down", true],
	[155.0, 0.0, "attack2", [1, 2, 3, 4], "flat", false],
	[-120.0, 210.0, "air_combo", [4, 5, 7, 8], "flat", true],
]
const K_RELOAD := 300.0
const K_BLINK := [240.0, 165.0]          # a blink's length, round 1 / round 2

func _k_round_t(r: int) -> float:
	return K_RELOAD + (K_BLINK[0] * K_SPOTS.size() + K_RELOAD) * r

func _k_target():
	var K = arena.kenin
	var tg = sh.get("tg")
	if tg != null and is_instance_valid(tg) and tg.alive(): return tg
	# it fell: the next foe near the spot, or keep shooting the spot
	var best = null
	var bd := 500.0
	for e in _foes():
		var d: float = absf(e.position.x - sh["tx"])
		if d < bd:
			bd = d
			best = e
	sh["tg"] = best
	return best

func _k_reload(P, S: float, n: int) -> void:
	var K = arena.kenin
	K.ammo = K.AMMO
	K.bombs = K.BOMBS
	K.reload_t = 0.0
	pose("bomb", 1)
	arena.big_word("재장전!" if n == 0 else "재장전!!", Color("#e8ffb0"), 520.0, Vector2.ZERO, P.position + Vector2(0, -170.0 * S))
	arena.sfx("ui_ok", 0.9, {"st": 3.0 + n * 3.0})
	arena.sfx("ui_move", 0.7, {"st": -2.0, "delay_ms": 90.0})
	arena.flash = maxf(arena.flash, 0.12)
	arena.hitstop = maxf(arena.hitstop, 70.0)

func _step_kenin(_dt: float, P, S: float) -> void:
	var K = arena.kenin
	if once("init"):
		var tg0 = null
		var bd := 640.0
		for e in _foes():
			var d: float = absf(e.position.x - P.position.x)
			if d < bd and absf(e.position.y - P.position.y) < 260.0:
				bd = d
				tg0 = e
		var tx: float = tg0.position.x if tg0 != null else P.position.x + P.dir * 200.0
		sh = {"tg": tg0, "tx": tx, "ty": tg0.position.y if tg0 != null else P.position.y, "side": -1.0 if tx >= P.position.x else 1.0, "chain_end": -1.0}
		_k_reload(P, S, 0)
	var tg = _k_target()
	if tg != null:
		sh["tx"] = tg.position.x
		sh["ty"] = tg.position.y
	var tx: float = sh["tx"]
	var ty: float = sh["ty"]
	var aim := Vector2(tx, (_ey(tg) if tg != null else ty - 55.0))
	P.cam_focus = {"x": tx, "t": 300.0}
	var n_spots := K_SPOTS.size()
	var r1 := _k_round_t(1)
	var t_end_rounds := r1 + K_BLINK[1] * n_spots
	if t < K_RELOAD:
		pose("bomb", 1 if t < 150.0 else 2)
		return
	if t < t_end_rounds:
		var rnd := 0 if t < r1 - K_RELOAD else (1 if t >= r1 else -1)
		if rnd == -1:
			if once("reload2"): _k_reload(P, S, 1)
			pose("bomb", 1 if t < r1 - K_RELOAD * 0.5 else 2)
			return
		var t0: float = K_RELOAD if rnd == 0 else r1
		var bl: float = K_BLINK[rnd]
		var i := mini(n_spots - 1, int((t - t0) / bl))
		var u: float = t - t0 - i * bl
		var sp: Array = K_SPOTS[i]
		var side: float = sh["side"] * (1.0 if rnd == 0 else -1.0)       # round 2 comes from the mirrored spots
		var px: float = clampf(tx + sp[0] * side * S / 0.88, 40.0, arena.world_w - 40.0)
		var fl: float = K._floor(px)
		var py: float = fl if sp[1] == 0.0 else minf(fl, ty) - sp[1] * S / 0.88
		var key := "b%d_%d" % [rnd, i]
		if once(key):
			P.add_ghost(220.0)                                    # the afterimage where he was
			P.position = Vector2(px, py)
			P.dir = 1 if tx >= px else -1
			arena.spark_ring(Vector2(px, py - 50.0 * S), 8)
			arena.sfx("swing", 0.7, {"st": 6.0 + i})
			arena.hitstop = maxf(arena.hitstop, 45.0 if rnd == 0 else 30.0)   # 스톱 모션: every blink lands on a held frame
		P.position = Vector2(px, py)
		P.vy = 0.0
		var frs: Array = sp[3]
		pose(sp[2], frs[mini(frs.size() - 1, int(u / (bl / frs.size())))])
		var D: int = P.dir
		var mz: Vector2
		match sp[4]:
			"down": mz = P.position + Vector2(D * 4.0, -6.0) * S
			"kneel": mz = P.position + Vector2(D * 36.0, -24.0) * S
			_: mz = P.position + Vector2(D * 34.0, -44.0) * S
		for k in 2:
			if u >= bl * (0.28 + 0.3 * k) and once(key + "s%d" % k):
				var hp := aim + Vector2(randf_range(-10.0, 10.0), randf_range(-16.0, 16.0))
				K.ult_shot(mz, hp, tg)
				if tg != null: hit(tg, 0.4)
				K.ammo = maxi(0, K.ammo - 1)
		if sp[5] and u >= bl * 0.8 and once(key + "b"):
			K.ult_bomb(tg)
			K.bombs = maxi(0, K.bombs - 1)
		return
	# the finale: behind the foe, the box, a grin, the plunger
	var tf := t - t_end_rounds
	if once("behind"):
		P.add_ghost(260.0)
		var away: float = sh["side"]                              # he started on this side of it: lands on the other
		var bx := clampf(tx - away * 95.0 * S / 0.88, 40.0, arena.world_w - 40.0)
		P.position = Vector2(bx, K._floor(bx))
		P.vy = 0.0
		P.dir = 1 if tx >= bx else -1
		arena.spark_ring(P.position + Vector2(0, -50.0 * S), 10)
		arena.sfx("swing", 0.8, {"st": 2.0})
		arena.hitstop = maxf(arena.hitstop, 60.0)
	P.vy = 0.0
	if tf < 360.0:
		pose("detonate", 4 if tf < 120.0 else (5 if tf < 240.0 else 6))
	elif tf < 600.0:
		pose("detonate", 6)                                       # the grin, held
		if once("grip"):
			arena.sfx("ui_ok", 0.7, {"st": -5.0})
			arena.flash = maxf(arena.flash, 0.1)
	else:
		pose("detonate", 7 if tf < 700.0 else 8)
		if once("slam"):
			var n: int = K.chain_detonate(P.position + Vector2(P.dir * 30.0 * S, -30.0 * S))
			if n == 0: K.dud_blast(P.position + Vector2(P.dir * 60.0 * S, -30.0 * S))
			arena.sfx("ult", 1.0)              # the impact
			arena.sfx("slam", 1.0)
			arena.flash = 0.35
			arena.hitstop = 110.0
			arena.post_ca(0.02)
			arena.impact("ult", P.position + Vector2(P.dir * 30.0 * S, -30.0 * S), P.dir)   # 타격감
		if not K.chaining() and sh["chain_end"] < 0.0: sh["chain_end"] = t
		if (sh["chain_end"] >= 0.0 and t - sh["chain_end"] > 450.0) or tf > 6000.0: end()

func _step_luce(dt: float, P, S: float) -> void:
	var D: int = P.dir
	var hx: float = P.position.x + D * 18.0 * S
	var hy: float = P.position.y - 150.0 * S
	var fx0: float = P.position.x + D * 52.0 * S
	var fy0: float = P.position.y - 78.0 * S
	if once("st"):
		star = {"k": "star", "x": hx, "y": hy, "s": 0.0, "t": 0.0, "life": 99999.0, "spin": 0.0}
		fx.append(star)
	star["spin"] += dt * 0.006
	if t < 520.0:
		pose("lpunch", 0 if t < 260.0 else 1)
		star["x"] = hx
		star["y"] = hy + sin(t / 90.0) * 3.0
		star["s"] = minf(1.0, t / 380.0)
		if randf() < dt / 18.0:
			var a := randf() * TAU
			var r := 60.0 + randf() * 60.0
			arena.fx.append({"k": "sp", "x": hx + cos(a) * r, "y": hy + sin(a) * r, "vx": -cos(a) * 0.25, "vy": -sin(a) * 0.25, "t": 0.0, "life": 220.0})
		if t > 140.0 and once("chime"): arena.sfx("ui_ok", 0.7)
	elif t < 760.0:
		pose("lpunch", 1)
		var u := (t - 520.0) / 240.0
		var e := u * u
		star["x"] = hx + (fx0 - D * 30.0 * S - hx) * e
		star["y"] = hy + (fy0 - hy) * e
		star["s"] = 1.0 - 0.35 * e
		if u > 0.85 and once("grab"):
			fx.append({"k": "burst", "x": star["x"], "y": star["y"], "r": 70.0, "t": 0.0, "life": 300.0})
			arena.sfx("guard", 0.8)
			arena.shake(4, D)
	elif t < 920.0:
		pose("lpunch", 2 if t - 760.0 < 80.0 else 3)
		star["x"] = P.position.x - D * 8.0 * S
		star["y"] = fy0
		star["s"] = 0.7 + sin(t / 25.0) * 0.08
		arena.shake(2.0 + (t - 760.0) / 40.0, D)
	else:
		pose("lpunch", 4 if t < 1000.0 else (5 if t < 1450.0 else 6))
		star["x"] = fx0 + D * 10.0
		star["y"] = fy0
		star["s"] = 0.9 if t < 1100.0 else maxf(0.0, 0.9 - (t - 1100.0) / 200.0)
		if once("punch"):
			arena.post_wave(Vector2(fx0, fy0), 1.8, 700.0, 0.55)
			arena.post_ca(0.03)
			var vs: Vector2 = get_viewport_rect().size
			fx.append({"k": "beam", "x": fx0, "y": fy0, "dir": D, "len": maxf(700.0, vs.x), "w": 96.0, "t": 0.0, "life": 820.0})
			fx.append({"k": "burst", "x": fx0, "y": fy0, "r": 160.0, "t": 0.0, "life": 520.0})
			for e in _foes():
				var ey: float = e.position.y - 50.0
				if (e.position.x - P.position.x) * D > -30.0 and absf(ey - fy0) < 170.0: hit(e, 4.0)
			for i in 14:
				fx.append({"k": "twinkle", "x": fx0 + D * randf() * 500.0, "y": fy0 + (randf() - 0.5) * 120.0, "vy": -0.02 - randf() * 0.05, "t": 0.0, "life": 500.0 + randf() * 500.0})
			arena.sfx("ult", 1.0)              # the impact
			arena.sfx("slam", 1.0)
			arena.sfx("heavy", 0.8)
			arena.flash = 0.55
			arena.shake(18, D)
			arena.hitstop = 120.0
			arena.impact("ult", Vector2(fx0, fy0), D)   # 타격감
		if t >= 1750.0:
			star["life"] = star["t"]
			end()

## ultEnd
func end() -> void:
	state = ""
	t = 0.0
	var P = arena.player
	P.inv = 700.0
	ualpha = 1.0
	if P.on: P.set_anim("idle", 0)
	else: P.set_anim("jump", 4)
	for f in fx:
		if f["k"] == "rune": f["life"] = f["t"] + 1.0

## a parry during the vow bursts roses where the blow is stopped
func rose_burst(p: Vector2) -> void:
	fx.append({"k": "rburst", "x": p.x, "y": p.y, "t": 0.0, "life": 380.0, "seed": randi()})

func fx_step(dt: float) -> void:
	for f in fx:
		f["t"] += dt
		if f["k"] == "twinkle": f["y"] += f["vy"] * dt
	fx = fx.filter(func(f): return f["t"] < f["life"])
	queue_redraw()
	glow.queue_redraw()


# ---------- drawing ----------
## dark parts (rifts, tears) with normal blending
func _draw() -> void:
	for f in fx:
		if arena.get("pfx") != null and arena.pfx.owns(f["k"]): continue     # drawn in pixels by pfx.gd
		var k: float = f["t"] / f["life"]
		match f["k"]:
			"hollow": _hollow(f)
			"tear":
				var u := k
				var op := minf(1.0, u / 0.12) * (1.0 - maxf(0.0, (u - 0.5) / 0.5))
				var dv := Vector2(cos(f["ang"]), sin(f["ang"]))
				var h: float = f["len"] / 2.0
				var c := Vector2(f["x"], f["y"])
				var n := Vector2(-dv.y, dv.x)
				var pts := PackedVector2Array()
				for i in 13:
					var s := float(i) / 12.0
					pts.append(c + dv * (s * 2.0 - 1.0) * h * minf(1.0, u * 4.0) + n * sin(s * PI) * 7.5)
				for i in range(12, -1, -1):
					var s2 := float(i) / 12.0
					pts.append(c + dv * (s2 * 2.0 - 1.0) * h * minf(1.0, u * 4.0) - n * sin(s2 * PI) * 7.5)
				draw_colored_polygon(pts, Color(0.02, 0.01, 0.04, op))
				draw_polyline(pts, Color(0.85, 0.7, 1.0, op), 1.5)
	# the vow's timer over her head
	if auto_t > 0.0:
		var P = arena.player
		var x: float = P.position.x
		var y: float = P.position.y - 160.0 * P.CSCALE
		draw_rect(Rect2(x - 30.0, y, 60.0, 5.0), Color(20 / 255.0, 8 / 255.0, 30 / 255.0, 0.7))
		draw_rect(Rect2(x - 30.0, y, 60.0 * auto_t / VOW, 5.0), Color("#ff9fd2"))

## a cluster of dark spheres jostling into one, a shifting rainbow rim (the ZZZ-style Hollow)
func _hollow(f: Dictionary) -> void:
	var T: float = f["t"]
	var L: float = f["life"]
	var op := 1.0
	if T < 150.0: op = UI_bk(T / 150.0)
	elif T > L - 150.0: op = maxf(0.0, (L - T) / 150.0)
	var R0: float = f["r"] * 2.0 * op
	if R0 < 2.0: return
	var ph := T / 1000.0
	var c := Vector2(f["x"], f["y"])
	var seed: float = f["seed"]
	var blobs := [[0.0, 0.0, 1.0, 1.0]]
	for i in 4:
		var a := i / 4.0 * TAU + seed + ph * (1.2 + i * 0.4) * (1.0 if i % 2 == 0 else -1.0)
		blobs.append([cos(a) * 0.5, sin(a) * 0.45, 0.55 + 0.1 * sin(seed + i), 1.0])
	for b in blobs:
		var bc: Vector2 = c + Vector2(b[0], b[1]) * R0
		var br: float = b[2] * R0 * (1.0 + 0.12 * sin(ph * 8.0 + b[2] * 9.0))
		draw_circle(bc, br + 3.0, Color(IRIS[int(ph * 6.0 + b[2] * 7.0) % IRIS.size()]))
		draw_circle(bc, br + 1.0, Color("#b06cff"))
	for b in blobs:
		var bc2: Vector2 = c + Vector2(b[0], b[1]) * R0
		var br2: float = b[2] * R0 * (1.0 + 0.12 * sin(ph * 8.0 + b[2] * 9.0))
		draw_circle(bc2, br2, Color("#22093a"))
		draw_circle(bc2, br2 * 0.7, Color("#12061f"))
	draw_circle(c, R0 * 0.4, Color("#050208"))
	for i in 6:
		var a2 := seed * 3.0 + i * 1.1 + ph * (1.0 + i * 0.2)
		var rr := R0 * (1.35 + 0.3 * sin(i + seed))
		draw_rect(Rect2(c + Vector2(cos(a2), sin(a2)) * rr - Vector2(1.5, 1.5), Vector2(3, 3)), Color(IRIS[(i + int(T / 90.0)) % IRIS.size()]))

static func UI_bk(u: float) -> float:
	var x := clampf(u, 0.0, 1.0)
	var c := 2.2
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)

## glows, runes, beams with additive blending
func _draw_glow() -> void:
	var g := glow
	var C: Array = PAL[who]
	var col: Color = INFO[who]["col"]
	for f in fx:
		if arena.get("pfx") != null and arena.pfx.owns(f["k"]): continue
		var k: float = f["t"] / f["life"]
		match f["k"]:
			"burst":
				var r: float = f["r"] * (0.3 + k * 0.9)
				var c := Color(C[mini(4, int(k * 5.0))])
				var p := Vector2(f["x"], f["y"])
				if k < 0.15: g.draw_circle(p, r * 0.35, Color(C[0]))
				g.draw_arc(p, r, 0, TAU, 40, Color(c, 1.0 - k * 0.5), 3.0 * (1.0 - k) + 1.0)
				for i in 12:
					var a := i / 12.0 * TAU + 0.13
					if k < 0.8: g.draw_line(p + Vector2(cos(a), sin(a)) * (r + 4.0), p + Vector2(cos(a), sin(a)) * (r + 4.0 + (6.0 if i % 2 else 14.0) * (1.0 - k)), Color(C[0] if k < 0.3 else C[2]), 2.0)
				g.draw_set_transform(p + Vector2(0, 40), 0.0, Vector2(1.0, 0.25))
				g.draw_arc(Vector2.ZERO, r * 1.2, 0, TAU, 48, Color(Color(C[0] if k < 0.4 else C[2]), 1.0 - k), 4.0)
				g.draw_set_transform(Vector2.ZERO)
			"star":
				if f["s"] <= 0.0: continue
				var p2 := Vector2(f["x"], f["y"])
				var R1: float = maxf(4.0, 26.0 * f["s"])
				for q in 3:
					g.draw_circle(p2, R1 * (3.0 - q * 0.6), Color(1.0, 0.75, 0.3, 0.12))
				var pts := PackedVector2Array()
				for q in 16:
					var rr: float = R1 * 0.42 if q % 2 == 1 else (R1 if q % 4 == 0 else R1 * 0.72)
					var a2: float = q * PI / 8.0 - PI / 2.0 + f["spin"]
					pts.append(p2 + Vector2(cos(a2), sin(a2)) * rr)
				g.draw_colored_polygon(pts, Color("#ffe9a0"))
				pts.append(pts[0])
				g.draw_polyline(pts, Color.WHITE, 2.0)
				g.draw_circle(p2, R1 * 0.3, Color.WHITE)
			"beam":
				var u := k
				var grow := minf(1.0, f["t"] / 90.0)
				var a3 := 1.0 if u < 0.4 else 1.0 - (u - 0.4) / 0.6
				var L: float = f["len"] * grow
				var w: float = f["w"] * (1.0 + u * 2.0 if u < 0.15 else 1.3 - u * 0.8)
				g.draw_set_transform(Vector2(f["x"], f["y"]), 0.0, Vector2(f["dir"], 1))
				for m in [[1.6, Color(1, 0.75, 0.31, 0.28)], [1.0, Color(1, 0.84, 0.47, 0.75)], [0.45, Color(1, 0.98, 0.9, 1.0)]]:
					var wm: float = w * m[0]
					g.draw_colored_polygon(PackedVector2Array([Vector2(-wm * 0.3, 0), Vector2(0, -wm * 0.5), Vector2(L, -wm * 0.32), Vector2(L + 40.0, 0), Vector2(L, wm * 0.32), Vector2(0, wm * 0.5)]), Color(m[1], m[1].a * a3))
				for q in 9:
					var xx := fmod(q * 137.0 + f["t"] * 1.6, maxf(1.0, L))
					var yy := fmod(q * 53.0, maxf(1.0, w)) - w / 2.0
					g.draw_line(Vector2(xx, yy * 0.6), Vector2(xx + 60.0 + q * 8.0, yy * 0.6), Color(1, 1, 1, 0.8 * a3), 2.0)
				g.draw_set_transform(Vector2.ZERO)
			"sigil":
				var p: Dictionary = f["p"]
				var u2 := minf(1.0, f["t"] / f["life"])
				var e := 1.0 - pow(1.0 - u2, 2.0)
				var x: float = f["x0"] + (p["x"] - f["x0"]) * e
				var y: float = f["y0"] + (p["y"] - f["y0"]) * e - sin(u2 * PI) * 40.0
				g.draw_polyline(PackedVector2Array([Vector2(x, y - 7), Vector2(x + 6, y), Vector2(x, y + 7), Vector2(x - 6, y), Vector2(x, y - 7)]), Color(0.82, 0.7, 1.0, 0.9), 2.0)
				g.draw_line(Vector2(x, y), Vector2(x - (p["x"] - f["x0"]) * 0.08, y - (p["y"] - f["y0"]) * 0.08), Color(0.47, 0.2, 0.86, 0.6), 4.0)
			"rune":
				var p3: Dictionary = f["p"]
				var born: float = f["i"] * 34.0 + 230.0
				if f["t"] < born: continue
				var e3 = p3["e"]
				var live: bool = e3 != null and is_instance_valid(e3) and e3.alive()
				var x3: float = e3.position.x if live else p3["x"]
				var y3: float = _ey(e3) if live else p3["y"]
				var a4 := minf(1.0, (f["t"] - born) / 150.0) * (1.0 if p3["lit"] else 0.75)
				var s: float = (17.0 if p3["e"] != null else 11.0) * (1.25 if p3["lit"] else 1.0) + sin(f["t"] / 70.0) * 1.5
				var rc := Color(0.88, 0.78, 1.0, a4) if p3["lit"] else Color(col, a4)
				var c3 := Vector2(x3, y3)
				g.draw_arc(c3, s * 1.5, 0, TAU, 28, rc, 2.0)
				var rot: float = f["t"] / 400.0
				var tri := PackedVector2Array()
				for q in 4:
					var aa := rot + q * TAU / 3.0
					tri.append(c3 + Vector2(cos(aa), sin(aa)) * s)
				g.draw_polyline(tri, rc, 2.0)
				if p3["e"] != null:
					g.draw_line(c3 + Vector2(-s, -s) * 0.7, c3 + Vector2(s, s) * 0.7, rc, 2.0)
					g.draw_line(c3 + Vector2(s, -s) * 0.7, c3 + Vector2(-s, s) * 0.7, rc, 2.0)
			"trail":
				var a5 := 1.0 - k
				g.draw_line(Vector2(f["x0"], f["y0"]), Vector2(f["x1"], f["y1"]), Color(0.59, 0.35, 1.0, 0.8 * a5), 10.0 * a5 + 1.0)
				g.draw_line(Vector2(f["x0"], f["y0"]), Vector2(f["x1"], f["y1"]), Color(0.92, 0.86, 1.0, 0.9 * a5), 3.0 * a5 + 0.5)
			"twinkle":
				var L2 := 3.0 if k < 0.25 else (2.0 if k < 0.6 else 1.0)
				var tc := Color("#ffffff") if k < 0.3 else (Color("#ffe9a0") if k < 0.65 else Color("#e8a33a"))
				var pp := Vector2(f["x"], f["y"])
				g.draw_line(pp - Vector2(L2 * 2.0, 0), pp + Vector2(L2 * 2.0, 0), tc, 2.0)
				g.draw_line(pp - Vector2(0, L2 * 2.0), pp + Vector2(0, L2 * 2.0), tc, 2.0)
			"oath": _oath(g, f)
			"rose": _rose(g, f)
			"rburst":
				var fr: float = f["t"] / 33.0
				var pr := Vector2(f["x"], f["y"])
				var rng := RandomNumberGenerator.new()
				rng.seed = f["seed"]
				if fr < 2.0: g.draw_circle(pr, 8.0 - fr * 3.0, Color.WHITE)
				if fr < 4.0:
					var Ll: float = [18.0, 22.0, 14.0, 8.0][int(fr)]
					g.draw_line(pr - Vector2(Ll, 0), pr + Vector2(Ll, 0), Color("#fff3b0"), 2.0)
					g.draw_line(pr - Vector2(0, Ll), pr + Vector2(0, Ll), Color("#fff3b0"), 2.0)
				for i in 14:
					var a6 := i / 14.0 * TAU + rng.randf() * 0.4
					var vv := 1.3 + rng.randf() * 1.5
					var q2 := pr + Vector2(cos(a6) * vv * fr * 3.6, sin(a6) * vv * fr * 2.6 + 0.36 * fr * fr)
					g.draw_rect(Rect2(q2, Vector2(4, 4)), Color("#ffd3ea") if fr < 3.0 else (Color("#ff96d2") if i % 2 else Color("#d650aa")))

## the oath: a crest stamped on the floor, a big shield rising behind her, then gone
func _oath(g: Node2D, f: Dictionary) -> void:
	var t0: float = f["t"]
	var s: float = f["s"] * 2.0
	var p := Vector2(f["x"], f["y"])
	var k := 1.0 - pow(1.0 - clampf(t0 / 220.0, 0.0, 1.0), 3.0)
	var rx := (5.0 + 15.0 * k) * s
	var fd := clampf((t0 - 700.0) / 300.0, 0.0, 1.0)
	var c := Color.WHITE if t0 < 120.0 else (Color("#fff3b0") if t0 < 300.0 else (Color("#7a2a66") if fd > 0.5 else Color("#ffd34d")))
	g.draw_set_transform(p, 0.0, Vector2(1.0, 0.28))
	g.draw_arc(Vector2.ZERO, rx, 0, TAU, 48, Color(c, 1.0 - fd), 4.0)
	if t0 < 500.0: g.draw_arc(Vector2.ZERO, rx - 6.0, 0, TAU, 48, Color("#ff96d2"), 2.0)
	g.draw_set_transform(Vector2.ZERO)
	if t0 >= 120.0:
		var rise := 1.0 - pow(1.0 - clampf((t0 - 120.0) / 260.0, 0.0, 1.0), 3.0)
		var a := clampf(1.0 - (t0 - 600.0) / 250.0, 0.0, 1.0)
		if a > 0.0:
			var oy := (-27.0 + 10.0 * (1.0 - rise)) * s
			var S0 := PackedVector2Array()
			for q in [[-15, -19], [15, -19], [15, 1], [0, 18], [-15, 1], [-15, -19]]:
				S0.append(p + Vector2(q[0] * s, q[1] * s + oy))
			g.draw_polyline(S0, Color(Color.WHITE if t0 < 300.0 else Color("#ff96d2"), a), 3.0)
			if t0 < 650.0:
				var cc := Color.WHITE if t0 < 300.0 else Color("#ffd34d")
				g.draw_line(p + Vector2(0, oy - 14.0 * s), p + Vector2(0, oy + 12.0 * s), Color(cc, a), 2.0)
				g.draw_line(p + Vector2(-9.0 * s, oy - 6.0 * s), p + Vector2(9.0 * s, oy - 6.0 * s), Color(cc, a), 2.0)

## the rose citadel: petals wheel round her for the 8 s, fewer as time runs out; they scatter when it ends
func _rose(g: Node2D, f: Dictionary) -> void:
	var P = arena.player
	if auto_t <= 0.0 and f["end"] < 0.0: f["end"] = f["t"]
	var ex: float = 0.0 if f["end"] < 0.0 else (f["t"] - f["end"]) / 450.0
	if ex > 1.0:
		f["life"] = 0.0
		return
	var t0: float = f["t"]
	var s: float = P.CSCALE * 1.8
	var K := clampf(auto_t / VOW, 0.0, 1.0)
	var n: int = f["n"] if ex > 0.0 else ceili(30.0 * K)
	f["n"] = n
	var p: Vector2 = P.position
	var k := 1.0 - pow(1.0 - clampf(t0 / 300.0, 0.0, 1.0), 3.0)
	g.draw_set_transform(p, 0.0, Vector2(1.0, 0.28))
	g.draw_arc(Vector2.ZERO, 16.0 * k * s, 0, TAU, 40, Color(Color.WHITE if t0 < 150.0 else Color("#d650aa"), 1.0 - ex), 2.0)
	g.draw_set_transform(Vector2.ZERO)
	var blink := auto_t < 1500.0 and ex <= 0.0 and int(t0 / 120.0) % 2 == 0
	for i in 30:
		if i >= n: continue
		var sp := 1.0 - pow(1.0 - clampf((t0 - 120.0 - i * 12.0) / 300.0, 0.0, 1.0), 3.0)
		if sp <= 0.0: continue
		var a := t0 * 0.0042 * (1.0 + (i % 3) * 0.18) + i * 1.37
		var z := sin(a)
		var hh := (-4.0 - float((i * 37) % 46)) * s
		var r := (17.0 + (i % 4) * 4.0) * sp * s
		var x := cos(a) * r
		var y := hh + z * r * 0.28
		if ex > 0.0:
			x += cos(a) * ex * 80.0
			y += ex * ex * 100.0
		if blink and i % 2 == 1: continue
		var c := (Color("#7a2a66") if i % 2 else Color("#d650aa")) if z < 0.0 else (Color.WHITE if i % 5 == 0 else (Color("#ff96d2") if i % 2 else Color("#d650aa")))
		g.draw_rect(Rect2(p + Vector2(x, y), Vector2(4, 4)), Color(c, 1.0 - ex))
