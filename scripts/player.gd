extends Node2D
## Estelle: movement, jumps, dash, ground/air combos, charge thrust, shield guard.
## Ported from the web prototype's update(). Units are kept as they were there:
## world pixels, milliseconds, velocities in px/ms, gravity in px/ms^2.

const AN = preload("res://scripts/estelle_anims.gd")

const GRAV := 0.0021
const JUMPV := 0.74
const DJUMPV := 0.80
const FALLMAX := 1.15
const RUN := 0.36
const BUF := 170.0
const CSCALE := 1.3          # Estelle is drawn 1.3x the sheet's half size
const MELEE_K := 0.86
const CW := 224.0            # drawn cell size before CSCALE (half the 448x352 source)
const CH := 176.0
const BASE := 170.0          # feet line inside a drawn cell
const MAX_HP := 70.0
const ATK_SPEED := 0.95      # Estelle's attack speed stat: attack frames last 1/0.95 as long

var arena                    # the room: ground, platforms, foes, fx
var sheets: Array[Texture2D] = []

var vx := 0.0
var vy := 0.0
var dir := 1
var on := true
var anim := "idle"
var f := 0
var ft := 0.0
var t := 0.0
var air := 0
var coyote := 0.0
var combo_win := 0.0
var slide := 0.0
var lunge := 0.0
var hit_done := false
var fx_done := false
var charges := 2
var recharge := 0.0
var dash_cd := 0.0
var ghost_t := 0.0
var charge_t := 0.0
var cfull := false
var ghit := false
var drop_t := 0.0
var tap_dir := 0
var tap_t := 999.0
var buf := {"attack": 0.0, "jump": 0.0, "guard": 0.0, "dash": 0.0}
var keys := {}
var pressed := {}
var ghosts: Array = []       # afterimages: {anim,f,x,y,dir,t,life}
var hp := MAX_HP
var inv := 0.0               # invulnerable time after a hit (ms)
var bash_t := 0.0            # a landed parry drives her forward with the shield
var dead_t := 0.0


func _ready() -> void:
	for i in 5:
		sheets.append(load("res://assets/chars/estelle/estelle_%d.png" % i))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


# ---------- helpers ----------
func set_anim(n: String, frame := -1) -> void:
	if not AN.A.has(n):
		n = "idle"
		frame = 0
	if anim != n or frame >= 0:
		anim = n
		f = maxi(frame, 0)
		ft = 0.0
		hit_done = false
		fx_done = false

func dur() -> float:
	var a: Array = AN.A[anim][1]
	var d := float(a[f] if f < a.size() else a[a.size() - 1])
	if anim.begins_with("attack") or anim in ["air_combo", "kneel_attack", "cthrust"]:
		d /= ATK_SPEED
	return d

func frames() -> int:
	return AN.A[anim][1].size()

func attacking() -> bool:
	return anim.begins_with("attack") or anim in ["kneel_attack", "air_combo", "dive", "cthrust"]

func want(k: String) -> bool:
	return buf[k] > 0.0

func take(k: String) -> void:
	buf[k] = 0.0

func cur_atk():
	var a = null
	if anim == "air_combo":
		a = AN.ATK["air1"] if f < 3 else (AN.ATK["air2"] if f < 6 else AN.ATK["air3"])
	elif AN.ATK.has(anim):
		a = AN.ATK[anim]
	return a

func move_axis() -> int:
	return (1 if keys["right"] else 0) - (1 if keys["left"] else 0)


# ---------- input ----------
func read_input() -> void:
	for k in ["left", "right", "up", "down", "jump", "attack", "guard", "dash"]:
		keys[k] = Input.is_action_pressed(k)
		pressed[k] = Input.is_action_just_pressed(k)


# ---------- attacks ----------
func start_attack() -> void:
	if not on:
		if keys["down"]:
			set_anim("dive")
			vy = -0.15
		else:
			set_anim("air_combo", 0)
			air = 1
			vy = minf(vy, 0.05)
		arena.sfx("swing")
		return
	if keys["up"]:
		set_anim("attack_high")
	elif keys["down"]:
		set_anim("kneel_attack")
	else:
		slide = vx
		set_anim("attack1")
		lunge_assist()
	arena.sfx("swing")

## step in toward a foe just out of reach so the first swing connects
func lunge_assist() -> void:
	lunge = 0.0
	if not on:
		return
	var reach := 140.0 * CSCALE * MELEE_K
	var best := INF
	for e in arena.foes():
		var dx: float = (e.position.x - position.x) * dir
		if absf(e.position.y - position.y) > 110.0:
			continue
		if dx < reach - 25.0:
			if dx > -20.0:
				return
			continue
		if dx > reach + 140.0:
			continue
		best = minf(best, dx)
	if best < INF:
		lunge = best - (reach - 35.0)

func check_hits() -> void:
	var atk = cur_atk()
	if atk == null or hit_done:
		return
	if f < atk["hit"][0] or f > atk["hit"][1]:
		return
	if not fx_done:
		fx_done = true
		add_ghost(140.0, -dir * 14.0 * CSCALE)
		if atk.has("arc"):
			var c: Array = atk["arc"]
			arena.slash_fx(position + Vector2(dir * c[0] * CSCALE, c[1] * CSCALE), c[2] * CSCALE * MELEE_K * 1.12, c[3], c[4], dir)
		if atk.get("streak", false):
			arena.streak_fx(position.x + dir * 20.0 * CSCALE, position.x + dir * (170.0 if anim == "cthrust" else 105.0) * CSCALE, position.y - 50.0 * CSCALE, dir)
	var b: Array = atk["box"]
	var bw: float = b[2] * CSCALE * MELEE_K
	var bx: float = position.x + b[0] * CSCALE * MELEE_K if dir > 0 else position.x - b[0] * CSCALE * MELEE_K - bw
	var by: float = position.y + b[1] * CSCALE
	var bh: float = b[3] * CSCALE
	var hit_any := false
	for e in arena.foes():
		var ex: float = e.position.x
		var ey: float = e.position.y
		var eh := 95.0
		var vert := ey > by and ey - eh < by + bh
		var front := (ex - position.x) * dir
		var point_blank := vert and front > -28.0 * CSCALE and front < 50.0 * CSCALE
		if point_blank or (ex + 22.0 > bx - 20.0 and ex - 22.0 < bx + bw and vert):
			e.hit(atk["dmg"], dir * atk["kb"])
			hit_any = true
	if hit_any:
		hit_done = true
		var heavy: bool = atk.get("heavy", false)
		arena.sfx("heavy" if heavy else "hit")
		arena.hitstop = atk.get("stop", 55)
		arena.shake(atk.get("shake", 4), dir)
		if heavy:
			arena.flash = 0.2


# ---------- afterimages ----------
func add_ghost(life: float, ox := 0.0) -> void:
	ghosts.append({"anim": anim, "f": f, "x": position.x + ox, "y": position.y, "dir": dir, "t": 0.0, "life": life})


# ---------- main step ----------
func step(dt: float) -> void:
	read_input()
	t += dt
	if inv > 0.0: inv -= dt
	if bash_t > 0.0: bash_t -= dt
	if anim == "death":
		dead_t += dt
		if dead_t > 2200.0:
			respawn()
	if combo_win > 0.0: combo_win -= dt
	if coyote > 0.0: coyote -= dt
	if drop_t > 0.0: drop_t -= dt
	for k in buf:
		if pressed[k]:
			buf[k] = BUF
		elif buf[k] > 0.0:
			buf[k] -= dt

	# double-tap a direction = dash
	tap_t += dt
	for d in [-1, 1]:
		if pressed["left" if d < 0 else "right"]:
			if tap_dir == d and tap_t < 220.0:
				buf["dash"] = BUF
			tap_dir = d
			tap_t = 0.0

	# dash: 2 charges, each refills in 1.3 s
	if charges < 2:
		recharge += dt
		if recharge >= 1300.0:
			recharge = 0.0
			charges += 1
	var dash_ok := charges > 0 and dash_cd <= 0.0 and not anim in ["hurt", "death", "dive", "dash", "airdash", "backstep"]
	if want("dash") and dash_ok:
		take("dash")
		var dd := move_axis()
		dir = dd if dd != 0 else dir
		charges -= 1
		if on:
			set_anim("dash")
			arena.dust(position, -dir, true)
		else:
			set_anim("airdash")
			vy = minf(vy, 0.05)
		arena.sfx("dash")
		dash_cd = 200.0
	if dash_cd > 0.0: dash_cd -= dt

	# variable jump height: let go early = shorter hop
	if not keys["jump"] and not on and vy < -0.32 and "jump" in anim:
		vy = -0.32

	var move := move_axis()
	var a := anim

	# ---- state machine ----
	if a == "hurt" or a == "death":
		vx = 0.0
	elif a == "charge":
		if move != 0: dir = move
		vx = 0.0
		charge_t += dt
		arena.charge_fx(position + Vector2(-dir * 2.0, -64.0 * CSCALE), charge_t)
		if charge_t >= 650.0 and not cfull:
			cfull = true
			arena.sfx("ready")
			arena.flash = 0.08
		if not keys["attack"]:
			if charge_t >= 200.0:
				set_anim("cthrust")
				arena.sfx("thrust")
				slide = 0.0
				if cfull:
					add_ghost(160.0)
			else:
				set_anim("attack1", 2)
	elif a in ["dash", "airdash", "backstep"]:
		if a == "dash":
			var sp: Array = [0.7, 0.85, 0.8, 0.35]
			vx = dir * (sp[f] if f < sp.size() else 0.0)
			if f == 3 and move == dir:
				set_anim("run")
		elif a == "airdash":
			var sp2: Array = [1.05, 1.25, 1.2, 1.05, 0.7, 0.35]
			vx = dir * (sp2[f] if f < sp2.size() else 0.0)
		else:
			var sp3: Array = [0.55, 0.45, 0.1]
			vx = -dir * (sp3[f] if f < sp3.size() else 0.0)
		ghost_t += dt
		if ghost_t > 28.0 and absf(vx) > 0.4:
			ghost_t = 0.0
			add_ghost(200.0)
		if a != "backstep" and f >= 1 and want("attack"):
			take("attack")
			start_attack()
			if on: slide = vx
		elif a == "dash" and f >= 1 and want("jump"):
			take("jump")
			on = false
			vy = -JUMPV
			set_anim("runjump", 1)
			arena.sfx("jump")
	elif attacking():
		if a == "dive":
			if f < 2:
				vx = 0.0
			elif f == 2:
				vy = minf(vy + GRAV * dt * 2.2, 1.3)
				vx = 0.0
			if on and f == 2:
				set_anim("dive", 3)
				arena.sfx("slam")
				arena.shake(14, dir)
				arena.flash = 0.35
				arena.dust(position, 0, true)
				arena.hitstop = 50.0
				for e in arena.foes():
					if absf(e.position.x - position.x) < 110.0 and absf(e.position.y - position.y) < 40.0:
						e.hit(2, dir * 6)
		elif a == "air_combo":
			vy = minf(vy + GRAV * dt * 0.35, 0.12)
			vx = dir * 0.04
			var air_ok := (f == 2 or f == 5) and ft > dur() * 0.55
			if want("attack") and air_ok and combo_win > 0.0:
				take("attack")
				set_anim("air_combo", 3 if f < 3 else 6)
				arena.sfx("swing")
				combo_win = 0.0
			if on:
				set_anim("jump", 6)
				vx = 0.0
				arena.dust(position, 0, false)
		else:
			vx = 0.0
			if a == "attack1":
				slide *= pow(0.992, dt)
				vx = slide
				if f == 2 and ft < 30.0: vx += dir * 0.25
			if a == "attack2" and f == 2 and ft < 30.0: vx = dir * 0.3
			if a == "attack3" and f == 2: vx = dir * 0.45
			if a == "attack3" and f == 3 and ft < 40.0: vx = dir * 0.2
			if a == "cthrust":
				var cs: Array = [1.0, 0.55, 0.08, 0.0]
				vx = dir * cs[mini(f, 3)]
				if f == 0 and ft < 20.0: arena.dust(position + Vector2(-dir * 20.0 * CSCALE, 0), -dir, true)
			var chain_ok := (f == 3 and ft > dur() * 0.6) or f >= 4
			if a == "attack1" and chain_ok and want("attack"):
				take("attack")
				set_anim("attack2")
				arena.sfx("swing")
				position.x += dir * 8.0
				lunge_assist()
			elif a == "attack2" and chain_ok and want("attack"):
				take("attack")
				set_anim("attack3")
				arena.sfx("swing")
				lunge_assist()
			# guard-cancel out of the recovery frames
			if f >= 3 and want("guard"):
				take("guard")
				set_anim("parry")
				ghit = false
		check_hits()
	elif a == "guard" or a == "parry":
		if bash_t > 0.0: vx = dir * 0.75 * minf(1.0, bash_t / 320.0)
		elif on: vx = 0.0
		else: vx *= pow(0.992, dt)
		if move != 0 and bash_t <= 0.0: dir = move
		if a == "guard" and not ghit and not keys["guard"]:
			set_anim("idle")
		elif a == "guard" and on and want("jump"):
			take("jump")
			set_anim("backstep")
			arena.sfx("skid")
			arena.dust(position + Vector2(dir * 14.0 * CSCALE, 0), dir, false)
	elif a == "kneel":
		vx = 0.0
		if not keys["down"]:
			set_anim("idle")
		if want("attack"):
			take("attack")
			set_anim("kneel_attack")
			arena.sfx("swing")
		elif want("jump"):
			take("jump")
			if arena.platform_under(position) != null:   # drop through a thin platform
				drop_t = 260.0
				on = false
				vy = 0.1
				set_anim("jump", 4)
	else:
		locomotion(dt, move, a)

	if anim == "parry" and f >= 2 and bash_t <= 0.0:
		if keys["guard"]:
			set_anim("guard", 1)
			ghit = false
		elif f == 3:
			set_anim("idle")

	physics(dt, a)
	advance(dt, move)

	for g in ghosts:
		g["t"] += dt
	ghosts = ghosts.filter(func(g): return g["t"] < g["life"])
	queue_redraw()


func locomotion(dt: float, move: int, a: String) -> void:
	if on:
		if a == "turn":
			var tk: Array = [0.8, 0.3, -0.1, -0.6]
			vx = dir * RUN * tk[mini(f, 3)]
			if move == dir and f < 2:
				set_anim("run", 0)
		elif a == "stop":
			vx *= 0.88
			if move == dir:
				set_anim("run")
			elif move == -dir:
				if absf(vx) > 0.12:
					set_anim("turn")
					arena.dust(position, 0, false)
				else:
					dir = move
					vx = 0.0
					set_anim("start")
		elif a == "start":
			var sk: Array = [0.45, 0.75, 1.0, 1.0]
			vx = dir * RUN * sk[mini(f, 3)]
			if move == 0:
				set_anim("stop")
				arena.sfx("skid")
			elif move == -dir:
				dir = move
				vx = 0.0
				set_anim("start")
		elif a == "run":
			vx = dir * RUN
			if move == 0:
				set_anim("stop")
				arena.sfx("skid")
				arena.dust(position + Vector2(-dir * 10.0 * CSCALE, 0), dir, false)
			elif move != dir:
				set_anim("turn")
				arena.dust(position, 0, false)
		else:
			vx = 0.0
			if move != 0:
				dir = move
				set_anim("start")
			elif keys["down"]:
				set_anim("kneel")
		if want("jump") and a != "kneel":
			take("jump")
			on = false
			vy = -JUMPV
			var running := absf(vx) > 0.2
			set_anim("runjump" if running else "jump", 1 if running else 2)
			arena.sfx("jump")
			arena.dust(position, 0, false)
			if a == "idle": vx = 0.0
		if want("attack"):
			take("attack")
			start_attack()
		if want("guard"):
			take("guard")
			set_anim("parry")
			ghit = false
			arena.sfx("guard")
			if move != 0: dir = move
	else:
		if move != 0:
			dir = move
			vx += (move * RUN * 0.95 - vx) * minf(1.0, dt / 60.0)
		else:
			vx *= pow(0.996, dt)
		if not anim in ["double_jump", "runjump", "jump"]:
			set_anim("jump", 4)
		if anim == "jump":
			if vy > 0.0 and f < 4: set_anim("jump", 4)
			if f > 5: f = 5
		if anim == "runjump" and f >= 5: f = 4
		if want("jump") and coyote > 0.0:
			take("jump")
			coyote = 0.0
			vy = -JUMPV
			set_anim("jump", 2)
			arena.sfx("jump")
		elif want("jump") and air < 1 and anim != "double_jump":
			take("jump")
			air = 1
			vy = -DJUMPV
			set_anim("double_jump")
			arena.sfx("djump")
			arena.ring(position + Vector2(0, -10), 26.0)
		if want("attack"):
			take("attack")
			start_attack()
		if want("guard"):
			take("guard")
			set_anim("parry")
			ghit = false
			arena.sfx("guard")
			if move != 0: dir = move


func physics(dt: float, a: String) -> void:
	if not on:
		var g := GRAV
		if a == "dive": g = 0.0
		elif a == "airdash": g *= 0.35
		elif a == "guard" or a == "parry": g *= 0.45
		elif absf(vy) < 0.14 and not attacking(): g *= 0.55
		elif vy > 0.0: g *= 1.55
		vy = minf(FALLMAX, vy + g * dt)
	if lunge > 0.0:
		if attacking():
			var st := minf(lunge, dt * 1.15)
			position.x += dir * st
			lunge -= st
		else:
			lunge = 0.0
	var prev_y := position.y
	position.x = clampf(position.x + vx * dt, 30.0, arena.world_w - 30.0)
	position.y += vy * dt

	# landing: ground, then one-way platforms (unless dropping through)
	var landed := false
	if vy >= 0.0:
		if position.y >= arena.ground_y:
			position.y = arena.ground_y
			landed = true
		elif drop_t <= 0.0 and (not keys["down"] or a == "dive"):
			for pl in arena.platforms:
				if prev_y <= pl.y + 1.0 and position.y >= pl.y and position.x > pl.x - 2.0 and position.x < pl.x + pl.w + 2.0:
					position.y = pl.y
					landed = true
	if landed and not on:
		on = true
		vy = 0.0
		air = 0
		if a in ["jump", "runjump", "double_jump"]:
			set_anim("jump", 6)
			arena.sfx("step")
			arena.dust(position, 0, false)
	elif landed:
		on = true
	elif on:
		var support: bool = position.y >= arena.ground_y - 0.5 or arena.platform_under(position) != null
		if not support:
			on = false
			vy = 0.05
			coyote = 90.0
			if not attacking() and a != "kneel":
				set_anim("jump", 4)


func advance(dt: float, move: int) -> void:
	ft += dt
	var guard_loops := 0
	while ft >= dur() and guard_loops < 20:
		guard_loops += 1
		ft -= dur()
		f += 1
		if f >= frames():
			var n := anim
			if n in ["idle", "run", "kneel"]:
				f = 0
			elif n == "start":
				set_anim("run", 0)
			elif n == "guard":
				ghit = false
				if keys["guard"]: f = 1
				else: set_anim("idle")
			elif n == "turn":
				dir = -dir
				set_anim("run", 0)
				vx = dir * RUN * 0.7
			elif n in ["stop", "hurt", "attack1", "attack2", "attack3", "attack_high", "parry", "cthrust"]:
				set_anim("kneel" if keys["down"] else "idle")
				if n.begins_with("attack"): combo_win = 0.0
			elif n == "kneel_attack":
				set_anim("kneel" if keys["down"] else "idle")
			elif n == "jump" or n == "runjump":
				if on: set_anim("idle")
				else:
					anim = "jump"
					f = 5
			elif n == "double_jump" or n == "airdash":
				anim = "jump"
				f = 4
			elif n == "air_combo":
				if on: set_anim("idle")
				else:
					anim = "jump"
					f = 4
			elif n == "dive":
				set_anim("idle")
			elif n == "dash":
				set_anim("run" if move == dir else "idle")
			elif n == "backstep":
				set_anim("guard" if keys["guard"] else "idle", 1 if keys["guard"] else 0)
			elif n == "death":
				f = 3
			else:
				f = 0
			break
		if anim == "attack1" and f == 2 and keys["attack"] and on:
			set_anim("charge", 1)
			charge_t = 110.0
			cfull = false
			break
		if anim == "attack1" or anim == "attack2": combo_win = 450.0
		if anim == "air_combo" and (f == 2 or f == 5): combo_win = 420.0
		if anim == "air_combo" and (f == 3 or f == 6):
			anim = "jump"
			f = 4
			combo_win = 0.0
			break
		if anim == "jump" and f == 7 and on:
			set_anim("kneel" if keys["down"] else "idle")
			break
		if anim == "guard" and f == 2 and not ghit:
			f = 1
		if anim == "dive" and f == 3 and not on:
			f = 2
		hit_done = false


# ---------- getting hit ----------
func dash_inv() -> bool:
	return (anim == "dash" and f <= 2) or (anim == "airdash" and f <= 3)

## A monster's blow (or projectile) reaches her. Same rules as the prototype: parry window, shield, hurt.
func take_hit(m, raw: float) -> String:
	if inv > 0.0 or dash_inv() or anim == "death" or hp <= 0.0:
		return "miss"
	var facing: bool = (m.position.x - position.x) * dir > 0.0
	if anim == "parry" and f <= 1 and facing:
		bash_t = 420.0
		f = 2
		ft = 0.0
		position.x += dir * 16.0
		arena.parry_fx(self, m)
		m.hit(2, dir * 8)
		m.hurt_t = 950.0
		m.set_a("hurt")
		m.st = "hurt"
		if m.flared:
			arena.perfect_parry(m)
		return "parry"
	if (anim == "guard" or anim == "parry" or anim == "backstep") and facing:
		var tk := raw * 0.5 * 0.75
		hp -= tk
		arena.sfx("guard", 0.9)
		arena.hitstop = 60.0
		arena.shake(4, -dir)
		arena.spark(position + Vector2(dir * 34.0 * CSCALE, -60.0 * CSCALE), 8)
		inv = 450.0
		position.x -= dir * 10.0
		set_anim("guard", 2)
		ghit = true
		arena.text(position + Vector2(0, -120.0 * CSCALE), "-" + str(roundi(tk)), Color("#cfe3ff"))
		if hp <= 0.0: die()
		return "guard"
	var tk2 := raw * 0.75          # Estelle's passive: 25% less damage taken
	hp -= tk2
	inv = 1200.0
	arena.sfx("hurt", 0.8)
	arena.shake(8, -dir)
	arena.flash = 0.25
	vx = 0.0
	arena.text(position + Vector2(0, -130.0 * CSCALE), "-" + str(roundi(tk2)), Color("#ff9d9d"))
	position.x -= (1.0 if m.position.x > position.x else -1.0) * 18.0
	if hp <= 0.0:
		die()
	else:
		set_anim("hurt")
	return "hit"

func die() -> void:
	hp = 0.0
	set_anim("death")
	dead_t = 0.0

func respawn() -> void:
	hp = MAX_HP
	inv = 1500.0
	set_anim("idle")
	arena.text(position + Vector2(0, -150.0), "재정비", Color("#ffe9a8"))


# ---------- drawing ----------
func _draw() -> void:
	for g in ghosts:
		var k: float = 1.0 - g["t"] / g["life"]
		draw_frame(g["anim"], g["f"], Vector2(g["x"], g["y"]) - position, g["dir"], Color(1.0, 0.55, 0.85, 0.45 * k))
	var an := anim
	var fr := f
	if an == "parry" and bash_t <= 0.0:   # the shield bash only shows on a landed parry; otherwise the raised shield
		an = "guard"
		fr = 1
	if not on and (an == "guard" or an == "parry"):
		an = "air_" + an
	var col := Color.WHITE
	if inv > 0.0 and anim != "death" and int(t / 70.0) % 2 == 0:
		col = Color(1, 1, 1, 0.45)
	draw_frame(an, fr, Vector2.ZERO, dir, col)

func draw_frame(an: String, fr: int, at: Vector2, d: int, col: Color) -> void:
	var rf: Array = AN.resolve(an, fr)
	var row: int = rf[0]
	var sheet: Texture2D = sheets[row / AN.ROWS_PER_SHEET]
	var src := Rect2(rf[1] * AN.CELL_W, (row % AN.ROWS_PER_SHEET) * AN.CELL_H, AN.CELL_W, AN.CELL_H)
	var w := CW * CSCALE
	var h := CH * CSCALE
	draw_set_transform(at, 0.0, Vector2(d, 1))
	draw_texture_rect_region(sheet, Rect2(-w / 2.0, -BASE * CSCALE, w, h), src, col)
	draw_set_transform(Vector2.ZERO)
