extends Node2D
## The controlled party member and the party around her.
## Estelle (shield, charge thrust), Aida (rift blink / rift sigil / rift strike), Luce (light bolts, pillar, lightning, heal).
## Ported from the web prototype's update(), partySwap() and the sortie module's counter swap.
## Units as in the prototype: world px, ms, px/ms, px/ms^2.

const CH = preload("res://scripts/chars.gd")
const SK := preload("res://scripts/skins.gd")

const GRAV := 0.0021
const JUMPV := 0.74
const DJUMPV := 0.80
const FALLMAX := 1.15
var RUN := 0.36              # run speed (gear and 바람 걸음 scale it: runes.gd tick)
const BUF := 170.0
const MELEE_K := 0.86
const CW := 224.0            # drawn cell size before scale (half the 448x352 source)
const CHH := 176.0
const BASE := 170.0          # feet line inside a drawn cell
const QTE_T := 3410.0        # tag-in window

var arena
var who := "estelle"         # current member
var CSCALE := 1.3
var MAX_HP := 70.0

var vx := 0.0
var vy := 0.0
var dir := 1
var on := true
var anim := "idle"
var f := 0
var ft := 0.0
var t := 0.0
var air := 0
var air_top := 0.0            # the highest point of the current flight (y, smaller = higher): a landing from LAND_MIN px down rings land.ogg
const LAND_MIN := 48.0        # px of drop before touchdown gets its land sound (a kerb or a stair step stays quiet)
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
var buf := {"attack": 0.0, "jump": 0.0, "guard": 0.0, "dash": 0.0, "swap": 0.0}
var mark_mouse := false    # mouse.moved: a real mouse has moved since the sigil came up (it then follows the pointer)
var keys := {}
var pressed := {}
var ghosts: Array = []
var hp := 70.0
var inv := 0.0
var bash_t := 0.0
var dead_t := 0.0
# Aida's rift
var rift_q := false          # quick (blink) vs heavy (sigil / strike)
var dig_to := 0.0
var dig_y := NAN
var dig_air := false
var blink_face := 0
var r_strike = null          # {r, x0}
var r_follow := false
var tp_cd := 0.0
var mark_t := 0.0
var mx := 0.0
var my := 0.0
var gate_in := Vector2.INF
var gate_out := Vector2.INF
var gate_t := 0.0
# the rift gates (riftStep / riftExit): pfx tears she walks through; her sprite is cut at the gate's line
const RIFTM := {"heavy": {"a": 105.0, "b": 150.0, "oa": 60.0, "ob": 130.0, "rel": 200.0, "h": 150.0, "k": 1.0, "w": 1.0},
	"quick": {"a": 20.0, "b": 110.0, "oa": 10.0, "ob": 80.0, "rel": 110.0, "h": 118.0, "k": 2.2, "w": 0.7}}
var g_in = null
var g_out = null
var in_t := 0.0
var out_t := 0.0
var rd := 1
var gdx := 0.0
var gclip = null             # {x, keep}: keep < 0 = only what is left of x shows, > 0 = right
# Luce
var heal_cd := 0.0
var heal_t := 0.0
var cw_r := 0.0
# party (prototype PARTY): the leader picked at the start screen; the others live in town until taken along
var party: Array = ["estelle"]
var hpm := {}
var swap_cd := 0.0
var swap_to := 0.0
var outs: Array = []         # members leaving the field: {c,x,y,dir,t,dead}
var qte := {"t": 0.0, "cd": 0.0, "who": [], "hit": null, "low": false}
var tag_to := 0.0
var tag_ref = null
var tag_hit := false
var tag_mul := 1.0
var tag_timer := 0.0
var air_tag := false
var air_y := 0.0
var last_hp := 70.0
var party_down := false
var cam_focus := {"x": 0.0, "t": 0.0}
var pd_back := false         # neutral dodge: a quicker, longer backstep that can be cancelled into an attack
var teeter_q := false
var teeter_t := 0.0
var edge_idle := 0.0
var xs := 0.0                # x at the start of the frame (edge hold)
var plat = null              # town: the sloped surface she stands on


func _ready() -> void:
	for c in ["estelle", "aida", "luce"]:
		for i in 5: SK.sheet(c, i)         # load the worn costume's sheets now (skins.gd resolves every draw)
		hpm[c] = CH.STATS[c]["hp"]
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	material = pix_mat()
	switch_char("estelle")
	hp = MAX_HP
	last_hp = hp


func switch_char(c: String) -> void:
	who = c
	CSCALE = CH.SCALE[c]
	MAX_HP = arena.runes.max_hp(c) if _rk() else CH.STATS[c]["hp"]

static func is_fly(e) -> bool:
	return e.get("M") != null and e.M.has("fly")

func atk_mul() -> float:
	return CH.STATS[who]["atk"] * (arena.runes.atk_k(who) if _rk() else 1.0)


# ---------- helpers ----------
func set_anim(n: String, frame := -1) -> void:
	if SK.entry(who, n) == null:
		n = "idle"
		frame = 0
	if anim != n or frame >= 0:
		anim = n
		f = maxi(frame, 0)
		ft = 0.0
		hit_done = false
		fx_done = false

func durs() -> Array:
	if who == "aida" and (anim == "tp_in" or anim == "dig_out"):
		if rift_q:
			return [30, 40, 40, 40] if anim == "tp_in" else [40, 40, 50, 60]
		return [50, 60, 70, 90] if anim == "tp_in" else [60, 60, 80, 100]
	return SK.entry(who, anim)[1]

func dur() -> float:
	var a: Array = durs()
	var d := float(a[f] if f < a.size() else a[a.size() - 1])
	if anim.begins_with("attack") or anim in ["air_combo", "kneel_attack", "cthrust", "lfinisher"]:
		d /= CH.STATS[who]["as"]
	return d

func frames() -> int:
	return durs().size()

func attacking() -> bool:
	return anim.begins_with("attack") or anim in ["kneel_attack", "air_combo", "dive", "cthrust", "lfinisher"]

func busy_rift() -> bool:
	return anim in ["tp_in", "dig_out", "rturn", "mark", "amark", "dig_in"]

func want(k: String) -> bool:
	return buf[k] > 0.0

func take(k: String) -> void:
	buf[k] = 0.0

func cur_atk():
	if anim == "air_combo":
		return CH.ATK["air1"] if f < 3 else (CH.ATK["air2"] if f < 6 else CH.ATK["air3"])
	if anim == "cthrust":
		# the charged thrust (charge / gcharge release): 3 damage and kb 16 when fully charged, else 2 and 10
		var ct: Dictionary = CH.ATK["cthrust"].duplicate()
		ct["dmg"] = 3 if cfull else 2
		ct["kb"] = 16 if cfull else 10
		return ct
	return CH.ATK.get(anim)

func move_axis() -> int:
	return (1 if keys["right"] else 0) - (1 if keys["left"] else 0)

func foes_alive() -> Array:
	return arena.foes()

## nearest foe, front-weighted; null if none in range
func target(rng: float):
	var best = null
	var bd := INF
	for e in foes_alive():
		var ey: float = e.position.y - 50.0
		var dx: float = e.position.x - position.x
		var d := Vector2(dx, (ey - (position.y - 60.0 * CSCALE)) * 1.5).length() * (1.8 if dx * dir < 0.0 else 1.0)
		if d < rng and d < bd:
			bd = d
			best = e
	return best


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and ev.device != InputEvent.DEVICE_ID_EMULATION and ev.relative.length() > 2.0:
		mark_mouse = true

## how high / low the sigil may go: the town reaches up the hill and down to the lower street, a cave room up to its
## ceiling, everywhere else 60 .. the ground
func mark_y_range() -> Vector2:
	var L = arena.level
	match arena.level_kind():
		"town": return Vector2(-600.0, float(L.LOWF))
		"dungeon": return Vector2(arena.ground_y - float(L.tpl.get("top", 300.0)) - 60.0, arena.ground_y)
	return Vector2(60.0, arena.ground_y)

func read_input() -> void:
	for k in ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "swap"]:
		keys[k] = Input.is_action_pressed(k)
		pressed[k] = Input.is_action_just_pressed(k)
	# scripted moments (sortie run-out / dash-in, an ult) hold or steer the keys
	var fo = arena.forced_keys()
	if fo != null:
		for k in keys:
			keys[k] = bool(fo.get(k, false))
			pressed[k] = false
		return
	# the press (or tap) that closed a talk box stays with it: no swing, jump or interact until it is let go
	if arena.dlg != null and arena.dlg.swallow():
		for k in ["attack", "jump", "up"]:
			pressed[k] = false
			if buf.has(k): buf[k] = 0.0
		keys["attack"] = false
		keys["jump"] = false
	# the attack key doubles as interact: at a door it opens, and doesn't swing
	if (pressed["attack"] or pressed["up"]) and on and not attacking() and arena.try_interact():
		pressed["attack"] = false
		keys["attack"] = false
		buf["attack"] = 0.0


# ---------- attacks ----------
## with no direction held, a fresh attack turns toward a foe behind if nothing is in front
func auto_face() -> void:
	if keys["left"] or keys["right"]:
		return
	var R := 420.0 if who == "luce" else 170.0 * CSCALE
	var front := false
	var back = null
	for e in foes_alive():
		var dx: float = e.position.x - position.x
		if absf(dx) > R or absf(e.position.y - position.y) > (230.0 if is_fly(e) else 110.0):
			continue
		if dx * dir >= -12.0:
			front = true
			break
		if back == null or absf(dx) < absf(back.position.x - position.x):
			back = e
	if not front and back != null:
		dir = -dir

func start_attack() -> void:
	auto_face()
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

func lunge_assist() -> void:
	lunge = 0.0
	if not on or who == "luce":
		return
	var reach := 140.0 * CSCALE * MELEE_K
	var best := INF
	for e in foes_alive():
		var dx: float = (e.position.x - position.x) * dir
		var fly: bool = is_fly(e)
		if absf(e.position.y - position.y) > (200.0 if fly else 110.0):
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

## Luce: every strike is a gesture; the real hit is light the game draws
func luce_gesture(atk) -> void:
	if atk == null or f != atk["hit"][0] or hit_done:
		return
	hit_done = true
	fx_done = true
	add_ghost(140.0, -dir * 14.0 * CSCALE)
	var tg = target(420.0)
	if tg != null:
		dir = int(signf(tg.position.x - position.x)) if tg.position.x != position.x else dir
	var gy: float = (arena.ground_y if is_fly(tg) else tg.position.y) if tg != null else position.y
	if anim == "attack3":
		arena.pillar(tg.position.x if tg != null else position.x + dir * 95.0 * CSCALE, gy, 2.0, dir)
		arena.sfx("heavy", 0.8)
		arena.shake(5, dir)
		arena.hitstop = 30.0
	elif anim == "attack_high":
		arena.lightning(tg.position.x if tg != null else position.x + dir * 80.0 * CSCALE, gy, 0.8, 2.0, dir)
		arena.sfx("heavy", 0.7)
		arena.shake(4, dir)
		arena.hitstop = 25.0
	else:
		var sz := 1.15 if anim == "attack2" else (1.1 if anim == "air_combo" and f >= 7 else 1.0)
		var n := 2 if anim == "attack2" else 1
		for i in n:
			var o := Vector2(position.x - dir * (30.0 + i * 18.0), position.y - 125.0 * CSCALE - i * 16.0)
			arena.bolt(o, tg, sz, 150.0 + i * 90.0, dir, hit_sound())
		arena.sfx("thrust", 0.6)

func check_hits() -> void:
	var atk = cur_atk()
	if who == "luce":
		luce_gesture(atk)
		return
	if atk == null or hit_done:
		return
	if f < atk["hit"][0] or f > atk["hit"][1]:
		return
	if not fx_done:
		fx_done = true
		add_ghost(140.0, -dir * 14.0 * CSCALE)
		if atk.has("arc"):
			var c: Array = atk["arc"]
			arena.slash_fx(position + Vector2(dir * c[0] * CSCALE, c[1] * CSCALE), c[2] * CSCALE * MELEE_K * 1.12, c[3], c[4], dir, CH.COLOR[who], c[5] if c.size() > 5 else 1.0)
		# swingWorld: dust kicked off the ground toward the swing
		if on:
			var heavy0: bool = anim in ["attack3", "cthrust", "cwave"]
			arena.pfx.dust(position.x + dir * 18.0 * CSCALE, position.y, dir, heavy0)
			if heavy0: arena.pfx.dust(position.x - dir * 10.0 * CSCALE, position.y, -dir, false)
		arena.swing_air(self)
		if atk.get("streak", false):
			arena.streak_fx(position.x + dir * 20.0 * CSCALE, position.x + dir * (170.0 if anim == "cthrust" else 105.0) * CSCALE, position.y - 50.0 * CSCALE, dir)
	var b: Array = atk["box"]
	var bw: float = b[2] * CSCALE * MELEE_K
	var bx: float = position.x + b[0] * CSCALE * MELEE_K if dir > 0 else position.x - b[0] * CSCALE * MELEE_K - bw
	var by: float = position.y + b[1] * CSCALE
	var bh: float = b[3] * CSCALE
	var hit_any := false
	var hp0 := Vector2.INF
	for e in foes_alive():
		var ex: float = e.position.x
		var ey: float = e.position.y
		if in_arc(atk, ex, ey, 95.0, bx, by, bw, bh):
			e.hit(atk["dmg"], dir * atk["kb"], atk_mul())
			hit_any = true
			if hp0 == Vector2.INF: hp0 = Vector2(ex, ey - 50.0)
	if hit_any:
		hit_done = true
		var heavy: bool = atk.get("heavy", false)
		arena.sfx(hit_sound())
		if heavy: _rev("heavy")
		if who == "aida" and _rk(): arena.runes.clone_hits(atk)
		arena.hitstop = atk.get("stop", 55)
		arena.shake(atk.get("shake", 4), dir)
		# 타격감: the weight of the blow (by its sound: hit1 / hit2 light, hit3, heavy) — the hitstop by weight, the
		# chromatic pulse, the zoom punch and the kick (the punch distortion is the mob's, in mob.hit); 화면 효과 off:
		# the lines above stand as they are
		arena.impact(hit_weight(), hp0, dir)
		var ac: Array = atk.get("arc", [])
		arena.slash_mark(hp0, (ac[3] + ac[4]) / 2.0 if ac.size() > 4 else 0.0, atk["dmg"])
		if heavy:
			arena.flash = 0.2
		if anim in ["attack3", "cthrust", "attack_high"] or (anim == "air_combo" and f >= 6):
			qte_offer("finisher")


## the hit's sound: the ground combo's n-th hit plays hit<n> (F / A / C), the air combo cycles 1 / 2 / 3 by its hit,
## the kneeling slash and the dive are hit1, the upward slash hit2; the charged thrust lands heavy
func hit_sound() -> String:
	if who == "aida":
		# Aida's otherworld: the dark-energy zing on the light blows, the void boom on the third and the charge
		return "aida_heavy" if anim in ["attack3", "cthrust"] or (anim == "air_combo" and f >= 6) else "aida_hit"
	match anim:
		"attack1", "kneel_attack", "dive": return "hit1"
		"attack2", "attack_high": return "hit2"
		"attack3": return "hit3"
		"air_combo": return "hit1" if f < 3 else ("hit2" if f < 6 else "hit3")
		"cthrust": return "heavy"
	return "hit1"

## the blow's weight for the screen (arena.impact): hit1 / hit2 are light, hit3 is hit3, the charged thrust heavy
func hit_weight() -> String:
	var hs := hit_sound()
	if hs == "aida_heavy": return "hit3" if anim != "cthrust" else "heavy"
	if hs == "aida_hit": return "light"
	match hs:
		"hit3": return "hit3"
		"heavy": return "heavy"
	return "light"

## the foe as a vertical segment (ey-eh .. ey) tested against the swing: point-blank always counts,
## arcs test sample points against the crescent sector, thrusts use the box
func in_arc(atk, ex: float, ey: float, eh: float, bx: float, by: float, bw: float, bh: float) -> bool:
	var vert := ey > by and ey - eh < by + bh
	var front := (ex - position.x) * dir
	if vert and front > -28.0 * CSCALE and front < 50.0 * CSCALE:
		return true
	if not atk.has("arc"):
		return ex + 22.0 > bx - 20.0 and ex - 22.0 < bx + bw and vert
	var c: Array = atk["arc"]
	var cx: float = position.x + dir * c[0] * CSCALE
	var cy: float = position.y + c[1] * CSCALE
	var R: float = c[2] * CSCALE * MELEE_K * 1.12
	var lo := minf(c[3], c[4])
	var hi := maxf(c[3], c[4])
	for i in 6:
		var py := ey - eh * i * 0.2
		var dx := (ex - cx) * dir
		var dy := py - cy
		if Vector2(dx, dy).length() > R * 1.08:
			continue
		var ang := rad_to_deg(atan2(dy, dx))
		if ang >= lo and ang <= hi:
			return true
	return false


# ---------- Aida's rift ----------
## snd: the 'dig' volume (the backstab blink .9, the tap hop .8, the aimed rift 1; the rift strike only has its thrust)
func rift_enter(to_x: float, to_y: float, quick: bool, snd := 0.0) -> void:
	rift_q = quick
	dig_to = clampf(to_x, 30.0, arena.world_w - 30.0)
	dig_y = to_y
	dig_air = not on
	set_anim("tp_in")
	gate_in = position + Vector2(dir * (30.0 if quick else 42.0) * CSCALE, 0)
	gate_out = Vector2.INF
	gate_t = 0.0
	# the rift opens with a snap and she's through with a swish (the old 'dig' rumble is gone)
	arena.sfx("aida_open", 0.9 if snd <= 0.0 else maxf(0.7, snd))
	arena.sfx("aida_pass", 0.8, {"delay_ms": 60.0})

func rift_exit() -> void:
	position.x = dig_to
	if not is_nan(dig_y):
		position.y = dig_y
		dig_y = NAN
		var onp: bool = position.y >= arena.ground_y - 1.0
		for pl in arena.platforms:
			if absf(position.y - pl.y) < 24.0 and position.x > pl.x - 2.0 and position.x < pl.x + pl.w + 2.0:
				position.y = pl.y
				onp = true
		on = onp
		if not onp:
			vy = 0.0
	if blink_face != 0:
		dir = blink_face
		blink_face = 0
		inv = maxf(inv, 250.0)
	gate_out = position + Vector2(-dir * (30.0 if rift_q else 42.0) * CSCALE, 0)
	gate_t = 0.0
	# riftExit: the way in closes, the way out opens behind her and she steps out of it
	if g_in != null:
		g_in["rel"] = true
		g_in = null
	var M: Dictionary = RIFTM["quick" if rift_q else "heavy"]
	rd = dir
	out_t = 0.0
	g_out = arena.pfx.gate(position.x - dir * (30.0 if rift_q else 42.0) * CSCALE, position.y, M["h"] * CSCALE, M["k"], M["w"])
	gdx = -dir * 125.0 * CSCALE
	gclip = {"x": g_out["x"], "keep": dir}
	arena.sfx("aida_close", 0.85)          # the way in shuts: a short crack
	if r_strike != null:
		# both gates snap shut: whatever stood on the path she cut through is cut
		var s = r_strike
		r_strike = null
		var dmg: float = 2.0 + round(s["r"] * 2.0)
		var lo: float = minf(s["x0"], position.x) - 20.0
		var hi: float = maxf(s["x0"], position.x) + 20.0
		var hit := false
		for m in foes_alive():
			if m.position.x < lo or m.position.x > hi or absf(m.position.y - position.y) > 100.0:
				continue
			m.hit(dmg, -dir * 8.0, atk_mul())
			hit = true
		if hit:
			arena.streak_fx(s["x0"], position.x, position.y - 62.0 * CSCALE, dir, Color("#b37bff"))
			qte_offer("finisher")
		arena.sfx("aida_heavy", 1.0)
		arena.shake(5.0 + s["r"] * 7.0, dir)
		arena.post_wave(Vector2((s["x0"] + position.x) / 2.0, position.y - 60.0 * CSCALE), 0.8 + s["r"] * 0.6, 520.0, 0.2)
		arena.hitstop = maxf(arena.hitstop, 80.0 + s["r"] * 60.0 if hit else 30.0)
	set_anim("dig_out")
	dig_air = not on

func rift_strike(r: float) -> void:
	var R := (200.0 + r * 220.0) * CSCALE
	var best = null
	var bdx := INF
	for m in foes_alive():
		var dx: float = (m.position.x - position.x) * dir
		if dx > 10.0 and dx < R and absf(m.position.y - position.y) < 120.0 and dx < bdx:
			bdx = dx
			best = m
	var to: float = best.position.x + dir * 95.0 * CSCALE if best != null else position.x + dir * (150.0 + r * 110.0) * CSCALE
	blink_face = -dir if best != null else 0
	r_strike = {"r": r, "x0": position.x}
	r_follow = best != null
	rift_enter(to, best.position.y if best != null and not is_fly(best) else NAN, false)
	arena.sfx("thrust", 0.8 + r * 0.3)

## dash = blink behind an enemy within 260 px in the dash direction
func aida_blink() -> bool:
	var best = null
	var bdx := INF
	for c in foes_alive():
		var dx: float = (c.position.x - position.x) * dir
		if dx > 20.0 and dx < 260.0 and absf(c.position.y - position.y) < 120.0 and dx < bdx:
			bdx = dx
			best = c
	if best == null:
		return false
	var back: int = -best.dir if best.get("dir") != null else dir
	blink_face = -back
	rift_enter(best.position.x + back * 125.0 * CSCALE, best.position.y if not is_fly(best) else NAN, true, 0.9)
	if best.has_method("daze"):
		best.daze(700.0)
	return true


# ---------- afterimages ----------
func add_ghost(life: float, ox := 0.0) -> void:
	ghosts.append({"c": who, "anim": anim, "f": f, "x": position.x + ox, "y": position.y, "dir": dir, "t": 0.0, "life": life})


# ---------- main step ----------
func step(dt: float) -> void:
	xs = position.x
	read_input()
	if _rk(): arena.runes.tick(dt)
	t += dt
	if inv > 0.0: inv -= dt
	if bash_t > 0.0: bash_t -= dt
	if tp_cd > 0.0: tp_cd -= dt
	if heal_cd > 0.0: heal_cd -= dt
	gate_t += dt
	if combo_win > 0.0: combo_win -= dt
	if coyote > 0.0: coyote -= dt
	if drop_t > 0.0: drop_t -= dt
	for k in buf:
		if pressed[k]:
			buf[k] = BUF
		elif buf[k] > 0.0:
			buf[k] -= dt
	party_step(dt)

	tap_t += dt
	for d in [-1, 1]:
		if pressed["left" if d < 0 else "right"]:
			if tap_dir == d and tap_t < 220.0:
				buf["dash"] = BUF
			tap_dir = d
			tap_t = 0.0

	if charges < 2:
		recharge += dt
		if recharge >= 1300.0 * _mk("rch"):          # 등불을 끄고 / 깊은 그늘: faster dash charge
			recharge = 0.0
			charges += 1
	var dash_ok := charges > 0 and dash_cd <= 0.0 and not anim in ["hurt", "death", "dive", "dash", "airdash", "backstep", "tag_in", "swap_in"] and not busy_rift()
	if want("dash") and dash_ok and neutral_dodge():
		take("dash")
	elif want("dash") and dash_ok:
		take("dash")
		var dd := move_axis()
		dir = dd if dd != 0 else dir
		charges -= 1
		_rev("dash")
		if who == "aida" and aida_blink():
			pass
		elif on:
			set_anim("dash")
			arena.sfx("dash")
			arena.pfx.dash_start(self, false)
		else:
			set_anim("airdash")
			vy = minf(vy, 0.05)
			arena.sfx("dash")
			arena.pfx.dash_start(self, true)
		dash_cd = 200.0
	if dash_cd > 0.0: dash_cd -= dt

	if not keys["jump"] and not on and vy < -0.32 and "jump" in anim:
		vy = -0.32

	var move := move_axis()
	var a := anim

	# ---- state machine ----
	if a == "hurt" or a == "death" or a == "tag_out":
		vx = 0.0
	elif a == "tag_in" or a == "swap_in":
		vx = 0.0
	elif a in ["charge", "acharge", "lgather", "gcharge"]:
		if move != 0 and a != "lgather": dir = move
		vx = 0.0
		charge_t += dt
		arena.charge_fx(position + Vector2(-dir * 2.0, -64.0 * CSCALE), charge_t, CH.COLOR[who])
		if charge_t >= 650.0 and not cfull:
			cfull = true
			arena.sfx("ui_ok")
			arena.flash = 0.08
		if not keys["attack"]:
			var r := minf(1.0, (charge_t - 200.0) / 450.0)
			if charge_t < 200.0:
				if a == "gcharge": set_anim("guard", 1)      # a tap under the shield: back to guard
				else: set_anim("attack1", 2)
			elif a == "lgather":
				set_anim("lfinisher")
				cw_r = r
				arena.sfx("ui_ok", 0.5)
			elif a == "acharge":
				rift_strike(r)
			else:
				set_anim("cthrust")
				arena.sfx("thrust")
				slide = 0.0
				if cfull: add_ghost(160.0)
	elif a in ["tp_in", "dig_out", "rturn", "dig_in"]:
		vx = 0.0
		if dig_air and a != "rturn": vy = 0.0
		_rift_step(a, dt)
	elif a == "mark" or a == "amark":
		vx = 0.0
		if dig_air: vy = 0.0
		mark_t += dt
		# keys / the stick steer the sigil; on PC the mouse drags it once it has moved
		var sp := 0.55 * dt
		if mark_mouse:
			var mw := get_global_mouse_position()
			mx += (mw.x - mx) * minf(1.0, dt / 60.0)
			my += (mw.y - my) * minf(1.0, dt / 60.0)
		else:
			mx += float(move) * sp
			my += ((1.0 if keys["down"] else 0.0) - (1.0 if keys["up"] else 0.0)) * sp
		var off := Vector2(mx - position.x, my - position.y).limit_length(400.0)
		mx = clampf(position.x + off.x, 30.0, arena.world_w - 30.0)
		var yr := mark_y_range()
		my = clampf(position.y + off.y, yr.x, yr.y)
		if absf(off.x) > 12.0: dir = int(signf(off.x))
		arena.mark_pos = Vector2(mx, my)
		if not keys["guard"]:
			arena.mark_pos = Vector2.INF
			if mark_t < 150.0 or Vector2(mx, my).distance_to(position) < 16.0:
				rift_enter(position.x - dir * 90.0 * CSCALE, NAN, false, 0.8)    # tap = short hop backwards through a hole
			else:
				rift_enter(mx, my, false, 1.0)
				dig_air = true
				tp_cd = 3000.0 * _cdk()
				_rev("skill")
				if _rk() and arena.runes.has("clone"): arena.runes.clone_start()
	elif a in ["dash", "airdash", "backstep"]:
		if a == "dash":
			var sp1: Array = [0.7, 0.85, 0.8, 0.35]
			vx = dir * (sp1[f] if f < sp1.size() else 0.0)
			if f == 3 and move == dir: set_anim("run")
		elif a == "airdash":
			var sp2: Array = [1.05, 1.25, 1.2, 1.05, 0.7, 0.35]
			vx = dir * (sp2[f] if f < sp2.size() else 0.0)
		else:
			var sp3: Array = [0.55, 0.45, 0.1]
			vx = -dir * (sp3[f] if f < sp3.size() else 0.0) * (1.75 if pd_back else 1.0)
		ghost_t += dt
		if ghost_t > 28.0 and absf(vx) > 0.4:
			ghost_t = 0.0
			add_ghost(200.0)
		if (a != "backstep" or pd_back) and f >= 1 and want("attack"):
			pd_back = false
			take("attack")
			start_attack()
			if on: slide = vx
		elif a == "dash" and f >= 1 and want("jump"):
			take("jump")
			on = false
			vy = -JUMPV
			set_anim("runjump", 1)
			arena.sfx("jump")
	elif a == "heal":
		vx = 0.0
		heal_t += dt
		if randf() < dt / 75.0 and heal_t < 700.0: arena.pfx.heal_cross(position.x, position.y, CSCALE)
		if heal_t >= 700.0 and not fx_done and _rk() and arena.runes.has("aura"):
			fx_done = true
			arena.runes.aura_start()
			heal_cd = 9000.0 * _cdk()
			_rev("skill")
			_rev("heal")
			arena.sfx("ui_ok", 0.9)
		if heal_t >= 700.0 and not fx_done:
			fx_done = true
			_rev("skill")
			_rev("heal")
			var hv := float(roundi(30.0 * _lvh("luce")))    # 30 × level × 회복량
			hp = minf(MAX_HP, hp + hv)
			var al := 0
			for c in party:
				if c != who and hpm[c] > 0.0 and hpm[c] < _mhp(c):
					hpm[c] = minf(_mhp(c), hpm[c] + hv)
					al += 1
			heal_cd = 9000.0 * _cdk()
			arena.sfx("ui_ok", 0.9)
			arena.flash = 0.1
			arena.pfx.heal_burst(position.x, position.y, CSCALE)
			arena.text(position + Vector2(0, -130.0 * CSCALE), "+%d" % int(hv), Color("#ffe9a8"))
			if al > 0:
				arena.text(position + Vector2(0, -165.0 * CSCALE), "동료 +%d" % int(hv), Color("#fff1b0"))
	elif attacking():
		if a == "dive":
			if f == 1 and not fx_done:
				fx_done = true
				arena.pfx.dive_start(self)
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
				arena.pfx.slam(position.x, position.y, who)
				arena.hitstop = 50.0
				for e in foes_alive():
					if absf(e.position.x - position.x) < 110.0 and absf(e.position.y - position.y) < 40.0:
						e.hit(2, dir * 6, atk_mul())
		elif a == "air_combo":
			vy = minf(vy + GRAV * dt * 0.35, 0.12)
			vx = dir * 0.04
			var air_ok := (f == 2 or f == 5) and ft > dur() * 0.55
			if want("attack") and air_ok and combo_win > 0.0:
				take("attack")
				set_anim("air_combo", 3 if f < 3 else 6)
				arena.sfx("swing")
				combo_win = 0.0
			if on and not air_tag:
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
			if a == "lfinisher" and f == 2 and not fx_done:
				fx_done = true
				var tg = target(520.0)
				if tg != null: dir = int(signf(tg.position.x - position.x)) if tg.position.x != position.x else dir
				var gy: float = (arena.ground_y if is_fly(tg) else tg.position.y) if tg != null else position.y
				arena.lightning(tg.position.x if tg != null else position.x + dir * 95.0 * CSCALE, gy, 1.0 + cw_r * 1.2, 2.0 + round(cw_r * 2.0), dir)
				arena.shake(6.0 + cw_r * 8.0, dir)
				arena.hitstop = 40.0 + cw_r * 50.0
				arena.flash = 0.25 + cw_r * 0.2
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
			if f >= 3 and want("guard") and who == "estelle":
				take("guard")
				if _shield_throw(): pass
				else:
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
		if a == "guard" and not ghit and on and want("attack"):
			# gcharge: attack while holding the shield charges the thrust (released >= 200 ms: cthrust, else guard)
			take("attack")
			set_anim("gcharge")
			charge_t = 0.0
			cfull = false
		elif a == "guard" and on and want("jump"):
			take("jump")
			set_anim("backstep")
			pass                    # (no slide sound: it read wrong on these motions)
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
			if plat != null and arena.level != null:
				drop_t = 260.0
				plat = null
				on = false
				vy = 0.1
				set_anim("jump", 4)
			elif arena.platform_under(position) != null:
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
	tag_motion(dt)

	for g in ghosts:
		g["t"] += dt
	ghosts = ghosts.filter(func(g): return g["t"] < g["life"])
	queue_redraw()


## guard key = each member's skill
func use_skill(move: int) -> void:
	if who == "estelle":
		if _shield_throw(): return
		set_anim("parry")
		ghit = false
		arena.sfx("swing", 0.5)          # the guard comes up: a quick swish, not a block (that sounds on contact)
		if move != 0: dir = move
	elif who == "aida":
		if tp_cd <= 0.0:
			set_anim("mark" if on else "amark")
			mark_t = 0.0
			dig_air = not on
			mx = position.x
			my = position.y
			mark_mouse = false
			if on: arena.sfx("swing", 0.3)      # the air sigil comes up silently
	elif who == "luce":
		if heal_cd <= 0.0 and on:
			set_anim("heal")
			heal_t = 0.0
			arena.sfx("swing", 0.2)


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
				pass                    # (no slide sound: it read wrong on these motions)
			elif move == -dir:
				dir = move
				vx = 0.0
				set_anim("start")
		elif a == "run":
			vx = dir * RUN
			if move == 0:
				set_anim("stop")
				pass                    # (no slide sound: it read wrong on these motions)
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
			use_skill(move)
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
			arena.pfx.djump(self)
		if want("attack"):
			take("attack")
			start_attack()
		if want("guard") and who != "luce":
			take("guard")
			use_skill(move)


## neutral dash (no direction) while an attack is coming = a quick backstep away from it, still facing the attacker
func neutral_dodge() -> bool:
	if not on or keys["left"] or keys["right"]:
		return false
	var m = arena.threatened()
	if m == null:
		return false
	dir = 1 if m.position.x > position.x else -1
	charges -= 1
	_rev("dash")
	set_anim("backstep")
	pd_back = true
	arena.sfx("dash", 0.9)
	arena.dust(position + Vector2(dir * 10.0 * CSCALE, 0), dir, false)
	dash_cd = 200.0
	return true

## what is under her feet as an x-span, or null
func support_span(x: float, y: float) -> Variant:
	if arena.level != null and arena.level.has_method("land"):
		return arena.level.support_span(x, y)
	if absf(y - arena.ground_y) < 1.0:
		return [-1e9, 1e9]
	for so in arena.solids:
		if absf(y - so.top) < 1.0 and x > so.x - 2.0 and x < so.x + so.w + 2.0:
			return [so.x - 2.0, so.x + so.w + 2.0]
	for pl in arena.platforms:
		if absf(y - pl.y) < 1.0 and x > pl.x - 2.0 and x < pl.x + pl.w + 2.0:
			return [pl.x - 2.0, pl.x + pl.w + 2.0]
	return null

## edge gravity: attacks, lunges, guard pushes and hurt knockback stop at the lip of what she stands on;
## a plain dash does too unless the stick is held that way (then it's on purpose)
func edge_hold(x0: float) -> void:
	if not on:
		return
	var s0 = support_span(x0, position.y)
	if s0 == null or support_span(position.x, position.y) != null:
		return
	var nx := clampf(position.x, s0[0] + 1.0, s0[1] - 1.0)
	if nx == position.x:
		return
	position.x = nx
	vx = 0.0
	teeter_q = true
	if teeter_t <= 0.0:
		teeter_t = 260.0
		arena.dust(position, 0, false)

func physics(dt: float, a: String) -> void:
	air_top = position.y if on else minf(air_top, position.y)
	if not on and not air_tag:
		var g := GRAV
		if a == "dive" or ((a in ["tp_in", "dig_out", "mark", "amark", "dig_in"]) and dig_air): g = 0.0
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
	var prev_x := position.x
	position.x = clampf(position.x + vx * dt, 30.0, arena.world_w - 30.0)
	position.y += vy * dt
	# raised rock: stand on top, blocked from the sides, pushed out the way she came in (never up on top)
	for so in arena.solids:
		if position.y > so.top + 2.0 and position.x > so.x - 12.0 and position.x < so.x + so.w + 12.0:
			if on and position.y - so.top <= 14.0 and vy >= 0.0:
				position.y = so.top
			elif prev_x <= so.x - 12.0:
				position.x = so.x - 12.0
			elif prev_x >= so.x + so.w + 12.0:
				position.x = so.x + so.w + 12.0
			elif not (vy > 0.0 and position.y - so.top <= 40.0):
				position.x = so.x - 12.0 if prev_x < so.x + so.w / 2.0 else so.x + so.w + 12.0
			else:
				position.y = so.top
				vy = 0.0
	if position.y < arena.ceil_y + 150.0 and vy < 0.0:
		position.y = arena.ceil_y + 150.0
		vy = 0.0
	if air_tag:
		return
	if on:
		var mv := move_axis()
		if teeter_t > 0.0: teeter_t -= dt
		if attacking() or a in ["hurt", "guard", "parry", "backstep"] or (a == "dash" and mv != dir):
			edge_hold(xs if absf(xs - position.x) < 300.0 else prev_x)
		# teeter: once after being stopped at the lip, and on loop while standing idle with toes over it
		if anim == "idle" and mv == 0 and not keys["down"]:
			if teeter_q:
				teeter_q = false
				set_anim("teeter")
			else:
				var sp = support_span(position.x, position.y)
				if sp != null and sp[0] > -1e8:
					var gap: float = sp[1] - position.x if dir > 0 else position.x - sp[0]
					if gap < 14.0:
						edge_idle += dt
						if edge_idle > 380.0: set_anim("teeterL")
					else:
						edge_idle = 0.0
				else:
					edge_idle = 0.0
		elif anim != "teeter" and anim != "teeterL":
			edge_idle = 0.0
	# the landing sound leads the touchdown by LAND_LEAD frames (audio output latency, the clip's own attack): when the
	# fall will reach the surface below within that, it's cued now, and the touchdown itself stays quiet
	if vy < 0.0: land_cued = false          # going up again (a double jump): the next landing cues afresh
	if not on and vy > 0.0 and not land_cued and a in ["jump", "runjump", "double_jump"]:
		var ly := _land_y()
		if ly < 1e8 and ly - position.y <= vy * dt * LAND_LEAD and ly >= position.y - 1.0:
			land_cued = true
			land_sfx()
	var landed := false
	if arena.level != null and arena.level.has_method("land"):
		landed = arena.level.land(self, prev_x, dt)
		if landed and not on:
			on = true
			vy = 0.0
			air = 0
			if a in ["jump", "runjump", "double_jump"]:
				land_anim()
				if not land_cued: land_sfx()
				arena.dust(position, 0, false)
			land_cued = false
		elif landed:
			vy = 0.0
		elif on:
			on = false
			vy = 0.05
			coyote = 90.0
			if not attacking() and a != "kneel" and not busy_rift():
				set_anim("jump", 4)
		return
	if vy >= 0.0:
		for so in arena.solids:
			if prev_y <= so.top + 1.0 and position.y >= so.top and position.x > so.x - 2.0 and position.x < so.x + so.w + 2.0:
				position.y = so.top
				landed = true
		if landed:
			pass
		elif position.y >= arena.ground_y:
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
			land_anim()
			if not land_cued: land_sfx()
			arena.dust(position, 0, false)
		land_cued = false
	elif landed:
		on = true
	elif on:
		var support: bool = position.y >= arena.ground_y - 0.5 or support_span(position.x, position.y) != null
		if not support:
			on = false
			vy = 0.05
			coyote = 90.0
			if not attacking() and a != "kneel" and not busy_rift():
				set_anim("jump", 4)


## touchdown after a jump or a fall of LAND_MIN px or more: land.ogg (never for a small step down)
## the landing: on the touchdown frame itself (no snap, the file starts on its transient), every landing after a real
## jump or fall, louder the further she fell
const LAND_LEAD := 3.0          # frames the landing sound leads the touchdown
var land_cued := false

## the surface under her feet (the nearest top at or below her): the level's floor where it has one, else the ground,
## the solids' tops and the platforms under x
func _land_y() -> float:
	var best := 1e9
	var L = arena.level
	if L != null and L.has_method("floor_at"):
		best = float(L.floor_at(position.x))
	else:
		best = arena.ground_y
	for so in arena.solids:
		if position.x > so.x - 2.0 and position.x < so.x + so.w + 2.0 and so.top >= position.y - 1.0: best = minf(best, so.top)
	if not keys.get("down", false):
		for pl in arena.platforms:
			if position.x > pl.x - 2.0 and position.x < pl.x + pl.w + 2.0 and pl.y >= position.y - 1.0: best = minf(best, pl.y)
	return best

func land_sfx() -> void:
	var h: float = position.y - air_top
	if h >= 12.0: arena.sfx("land", lerpf(0.3, 0.6, clampf(h / 160.0, 0.0, 1.0)))

## a jump touching down: still running (a direction held, moving that way) lands straight into the run on a contact
## frame; the standing landing → idle → start → run stopped her and set off again after every run jump
func land_anim() -> void:
	var held := (1 if keys.get("right", false) else 0) - (1 if keys.get("left", false) else 0)
	if held != 0 and held == dir and absf(vx) > 0.2:
		set_anim("run", 1)
	else:
		set_anim("jump", 6)

func advance(dt: float, move: int) -> void:
	ft += dt
	var loops := 0
	while ft >= dur() and loops < 20:
		loops += 1
		# in the air a jump holds its fall frame (jump 5, runjump 4): stepping on would flash the landing frame for a tick
		# before the hold put it back, over and over while she falls
		if not on and ((anim == "runjump" and f >= 4) or (anim == "jump" and f >= 5)):
			ft = 0.0
			break
		ft -= dur()
		f += 1
		if on and anim == "run" and f in SK.steps(who, "run"): arena.sfx("foot", 0.6)     # a foot lands: the surface's step
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
			elif n == "mark" or n == "amark":
				f = 0
			elif n == "lgather":
				f = 1                   # prayer hold: the two floating frames sway
			elif n in ["stop", "hurt", "attack1", "attack2", "attack3", "attack_high", "parry", "cthrust", "lfinisher", "heal"]:
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
			elif n == "tp_in" or n == "dig_in":
				rift_exit()
			elif n == "dig_out":
				rift_q = false
				if r_follow:
					r_follow = false
					set_anim("attack2")
					combo_win = 0.0
					arena.sfx("swing")
					lunge_assist()
				else:
					set_anim("run" if move == dir else "idle")
			elif n == "rturn":
				dir = -dir
				set_anim("idle")
			elif n == "dash":
				set_anim("run" if move == dir else "idle")
			elif n == "teeter":
				set_anim("idle")
			elif n == "teeterL":
				f = 0
			elif n == "tag_in":
				set_anim("idle")
			elif n == "swap_in":
				position.x = swap_to
				set_anim("run" if move == dir else "stop")
			elif n == "backstep":
				pd_back = false
				set_anim("guard" if keys["guard"] else "idle", 1 if keys["guard"] else 0)
			elif n == "death":
				f = 3
			else:
				f = 0
			break
		if anim == "attack1" and f == 2 and keys["attack"] and on:
			set_anim({"estelle": "charge", "aida": "acharge", "luce": "lgather"}[who], 1)
			charge_t = 110.0
			cfull = false
			break
		if anim == "attack1" or anim == "attack2": combo_win = 450.0
		if anim == "air_combo" and (f == 2 or f == 5): combo_win = 420.0
		if anim == "air_combo" and (f == 3 or f == 6) and not air_tag:
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
	return (anim == "dash" and f <= 2) or (anim == "airdash" and f <= 3) or anim == "tp_in" or anim == "dig_in" or (anim == "dig_out" and f <= 1) or anim == "swap_in"

func take_hit(m, raw: float) -> String:
	if inv > 0.0 or dash_inv() or anim == "death" or hp <= 0.0:
		return "miss"
	var facing: bool = (m.position.x - position.x) * dir > 0.0
	var mg: String = arena.runes.memory.guard_hit(m, facing) if _rk() else ""   # 성소 / 의족을 박고 (memory nodes)
	if mg == "miss": return "miss"
	raw *= arena.taken_mul(m)                              # the mob's attack element against her own (hurtAmt)
	var auto: bool = (who == "estelle" and arena.auto_parry() > 0.0) or mg == "gp"   # 수호의 맹세: every blow is parried
	if auto and not (anim == "parry" and f <= 1 and facing):
		dir = 1 if m.position.x > position.x else -1
		set_anim("parry")
		facing = true
	if who == "estelle" and anim == "parry" and f <= 1 and facing:
		if auto and mg != "gp": arena.ult.rose_burst(position + Vector2(dir * 34.0 * CSCALE, -62.0 * CSCALE))
		bash_t = 420.0
		f = 2
		ft = 0.0
		position.x += dir * 16.0
		arena.parry_fx(self, m)
		m.hit(2, dir * 8, atk_mul())
		m.hurt_t = 950.0
		m.set_a("hurt")
		m.st = "hurt"
		if m.flared:
			arena.perfect_parry(m)
			_rev("pparry")
		qte_offer("parry")
		_rev("parry")
		_rev("skill")
		return "parry"
	if who == "estelle" and (anim == "guard" or anim == "parry" or anim == "backstep") and facing:
		var tk := raw * 0.5 * 0.75 * _inm()
		hp -= tk
		_rev("block")
		arena.sfx("guard", 0.9)
		arena.hitstop = 60.0
		arena.shake(4, -dir)
		arena.spark(position + Vector2(dir * 34.0 * CSCALE, -60.0 * CSCALE), 8)
		inv = 450.0
		position.x -= dir * 10.0
		set_anim("guard", 2)
		ghit = true
		arena.text(position + Vector2(0, -120.0 * CSCALE), "-" + str(roundi(tk)), Color("#cfe3ff"))
		qte_offer("hit", {"raw": raw * 0.5, "taken": tk, "victim": who})
		arena.ult_gain(5.0)
		if hp <= 0.0: die()
		return "guard"
	var tk2 := raw * (0.75 if who == "estelle" else 1.0) * _inm()    # Estelle's passive: 25% less damage taken
	hp -= tk2
	arena.ult_gain(12.0)
	arena.post_ca(0.02)
	inv = 1200.0
	arena.sfx("hurt", 0.8)
	arena.shake(8, -dir)
	arena.flash = 0.25
	arena.impact("hurt", position + Vector2(0, -60.0 * CSCALE), -dir)   # 타격감: the red vignette, the kick back
	vx = 0.0
	air_tag = false
	arena.text(position + Vector2(0, -130.0 * CSCALE), "-" + str(roundi(tk2)), Color("#ff9d9d"))
	position.x -= (1.0 if m.position.x > position.x else -1.0) * 18.0
	if hp <= 0.0:
		die()
	else:
		qte_offer("hit", {"raw": raw, "taken": tk2, "victim": who})
		set_anim("hurt")
	return "hit"

func die() -> void:
	hp = 0.0
	set_anim("death")
	dead_t = 0.0
	arena.sfx("jingle_death", 1.0)
	arena.sfx("death", 0.9)
	if arena.bgm != null and arena.bgm.grid() != null: arena.bgm.duck(6.0, 600.0)


# ---------- party: switching, QTE tag-in, counter swap ----------
func party_step(dt: float) -> void:
	if swap_cd > 0.0: swap_cd -= dt
	if qte["cd"] > 0.0: qte["cd"] -= dt
	if qte["t"] > 0.0:
		qte["t"] -= dt
		if qte["t"] <= 0.0: qte_end()
	if cam_focus["t"] > 0.0: cam_focus["t"] -= dt
	for o in outs:
		o["t"] += dt
	outs = outs.filter(func(o): return o["t"] < 600.0)
	if hp < last_hp and hp > 0.0 and hp <= MAX_HP * 0.35:
		qte_offer("low")
	last_hp = hp
	# Luce's passive: while she is in the party, members on standby slowly recover
	if party.has("luce"):
		for c in party:
			if c != who and hpm[c] > 0.0:
				hpm[c] = minf(_mhp(c), hpm[c] + dt * 0.002 * _lvm("luce"))
	if anim == "death":
		dead_t += dt
		if dead_t > 650.0 and not party_down:
			party_down = true
			var nx = null
			for c in party:
				if c != who and hpm[c] > 0.0:
					nx = c
					break
			if nx != null:
				swap(true, nx)
		if dead_t > 2200.0 and party_down and anim == "death":
			# partyDeath: in the cave the party falls back to town; everyone who has joined is healed
			var dun: bool = arena.level_kind() == "dungeon"
			if dun: arena.text(position + Vector2(0, -150.0), "파티 전멸… 마을로 후퇴", Color("#ff9d9d"))
			for c in roster():
				hpm[c] = _mhp(c)
			hp = MAX_HP
			last_hp = hp
			if not dun:
				var L = arena.level
				position = Vector2(380.0, L.floor_at(380.0) if L != null and L.has_method("floor_at") else arena.ground_y)
				vx = 0.0
				vy = 0.0
				plat = null
			inv = 1500.0
			set_anim("idle")
			arena.party_wiped()
	else:
		party_down = false
	if pressed["swap"] or want("swap"):
		take("swap")
		party_input()
	if tag_timer > 0.0:
		tag_timer -= dt
		if tag_timer <= 0.0 and not tag_hit:
			tag_hit = true
			tag_strike()

## ROSTER: the members who have joined the guild (fame.rec), plus whoever is in control, in the prototype's order
func roster() -> Array:
	var F = arena.get("fame") if arena != null else null
	return ["estelle", "aida", "luce"].filter(func(c): return c == who or party.has(c) or F == null or F.recruited(c))

func party_next():
	var al: Array = party.filter(func(c): return c == who or hpm[c] > 0.0)
	if al.size() < 2:
		return null
	return al[(al.find(who) + 1) % al.size()]

## the swap key / a portrait tap: during a QTE it becomes a tag-in strike; on a glinting attack it is a counter swap
func party_input(to = null) -> void:
	if anim in ["tag_in", "swap_in"]:
		return
	if (arena.ult != null and arena.ult.state != "") or arena.fade_dir == 1:
		return      # partyInput: not during an ultimate or a door's fade-out
	if to != null and (to == who or hpm[to] <= 0.0):
		return      # a portrait of someone down does nothing
	var m = flared_mob()
	if m != null:
		var nx = to if to != null and to != who and hpm[to] > 0.0 else _qte_member()
		if nx == null: nx = party_next()
		if nx != null and nx != who:
			counter_swap(m, nx)
			return
	if qte["t"] > 0.0:
		# the swap key tags in whoever has the chance; a tapped portrait tags in only if that face has it
		var c = (to if qte["who"].has(to) else null) if to != null else _qte_member()
		if c != null:
			swap(true, c)
			return
	swap(false, to)

func _qte_member():
	for c in party:
		if qte["who"].has(c) and hpm[c] > 0.0 and c != who:
			return c
	return null

func flared_mob():
	var best = null
	for m in arena.mobs:
		if not m.alive() or m.st != "atk" or not m.flared or m.atk_clock > m.hit_at + 180.0:
			continue
		var d: float = absf(m.position.x - position.x)
		if d > 560.0: continue
		if best == null or d < absf(best.position.x - position.x): best = m
	return best

func swap(tag: bool, to = null) -> void:
	var nx = to if to != null else party_next()
	if nx == null or nx == who or hpm[nx] <= 0.0:
		arena.text(position + Vector2(0, -140.0 * CSCALE), "교대할 동료가 없다", Color("#cfd6e6"))
		return
	if not tag and swap_cd > 0.0:
		return
	var old := who
	hpm[old] = maxf(0.0, hp)
	var was_dead := anim == "death"
	outs.append({"c": old, "anim": "death" if was_dead else "tag_out", "x": position.x, "y": position.y, "dir": dir, "t": 0.0, "dead": was_dead})
	if not was_dead:
		arena.dust(position, -dir, false)
		arena.sfx("dash", 0.55)
	var keep_x := position.x
	var keep_dir := dir
	switch_char(nx)
	hp = hpm[nx] if hpm[nx] > 0.0 else MAX_HP
	last_hp = hp
	vx = 0.0
	inv = maxf(inv, 700.0 if tag else 450.0)
	charge_t = 0.0
	arena.mark_pos = Vector2.INF
	if tag and not qte["who"].has(nx):
		tag = false
	var q_hit = qte["hit"]
	var q_low: bool = qte["low"]
	if tag:
		qte_end()
		swap_cd = 900.0 * _mk("swap")
		_rev("tag")
		# what each member brings when tagged in
		if nx == "estelle" and q_hit != null and q_hit["victim"] == old:
			hpm[old] = minf(_mhp(old), hpm[old] + q_hit["taken"])
			var take_dmg: float = q_hit["raw"] * 0.75
			hp = maxf(1.0, hp - take_dmg)
			last_hp = hp
			arena.text(position + Vector2(0, -175.0 * CSCALE), "수호! " + CH.NAME[old] + " 피해 대신 받음", Color("#ffe39a"))
		if nx == "luce" and q_low:
			hpm[old] = minf(_mhp(old), hpm[old] + 30.0)
			arena.text(position + Vector2(0, -175.0 * CSCALE), "구원! " + CH.NAME[old] + " +30", Color("#fff1b0"))
		tag_mul = 2.0 if nx == "aida" else 1.0
		if nx == "aida":
			arena.text(position + Vector2(0, -175.0 * CSCALE), "기습! 교대 공격 2배", Color("#d7b8ff"))
		arena.flash = maxf(arena.flash, 0.22)
		arena.hitstop = 70.0
		arena.shake(6, dir)
		arena.post_wave(position + Vector2(0, -60.0), 1.2, 520.0, 0.25)
		arena.post_ca(0.012)
		arena.sfx("heavy", 0.9)
		var tg = target(1600.0)
		tag_in_at(tg, keep_x)
		arena.text(position + Vector2(0, -150.0 * CSCALE), "TAG!  " + CH.NAME[nx], Color("#ffe39a"))
	else:
		swap_cd = 2200.0 * _mk("swap")
		if on:
			swap_to = keep_x
			position.x = clampf(keep_x - keep_dir * 170.0, 30.0, arena.world_w - 30.0)
			set_anim("swap_in")
		else:
			set_anim("jump", 4)

## the newcomer leaps in from behind the target; a flying target is met in the air, mid-combo
func tag_in_at(tg, keep_x: float) -> void:
	if tg != null:
		var fly: bool = is_fly(tg)
		if fly:
			air_tag = true
			air_y = minf(arena.ground_y - 60.0, tg.position.y + 30.0)
			position.y = air_y
			on = false
			vy = 0.0
		else:
			air_tag = false
			position.y = tg.position.y
			on = true
			vy = 0.0
		dir = int(signf(tg.position.x - keep_x)) if tg.position.x != keep_x else dir
		tag_ref = tg
		tag_to = clampf(tg.position.x - dir * 72.0, 30.0, arena.world_w - 30.0)
		position.x = clampf(tag_to - dir * 220.0, 30.0, arena.world_w - 30.0)
		cam_focus = {"x": (tag_to + tg.position.x) / 2.0, "t": 1100.0}
		tg.kx = 0.0
	else:
		tag_ref = null
		tag_to = clampf(keep_x + dir * 120.0, 30.0, arena.world_w - 30.0)
		position.x = clampf(keep_x - dir * 80.0, 30.0, arena.world_w - 30.0)
		if not on:
			position.y = arena.ground_y
			on = true
			vy = 0.0
	set_anim("air_combo" if air_tag else "tag_in")
	tag_hit = false
	tag_timer = 460.0            # never let a tag be eaten

func tag_motion(dt: float) -> void:
	if anim == "swap_in":
		position.x += (swap_to - position.x) * minf(1.0, dt / 95.0)
	if anim == "tag_in" or (air_tag and anim == "air_combo"):
		if f < 3:
			position.x += (tag_to - position.x) * minf(1.0, dt / 55.0)
		if f >= 3 and not tag_hit:
			tag_hit = true
			tag_strike()
	if air_tag:
		if anim == "air_combo" or anim == "tag_in":
			vy = 0.0
			position.y = air_y
			on = false
		else:
			air_tag = false

func tag_strike() -> void:
	arena.sfx("heavy", 1.0)
	var R0 = tag_ref
	var M := tag_mul
	tag_mul = 1.0
	if R0 != null and is_instance_valid(R0) and R0.alive():
		R0.hit(2.0 * M, dir * 8.0, atk_mul())
		if R0.get("daze") != null: R0.daze = maxf(R0.daze, 500.0)     # the training ghost loses her for a moment
	arena.hitstop = 80.0
	arena.shake(7, dir)
	arena.post_wave(position + Vector2(dir * 60.0, -50.0), 1.1, 460.0, 0.22)
	arena.streak_fx(position.x - dir * 30.0, position.x + dir * 170.0, position.y - 50.0 * CSCALE, dir, CH.COLOR[who])
	arena.dust(position, dir, true)
	for d in foes_alive():
		if d != R0 and (d.position.x - position.x) * dir > -30.0 and absf(d.position.x - position.x) < 200.0 and absf(d.position.y - position.y) < 60.0:
			d.hit(2, dir * 8, atk_mul())

## swapping on a glinting attack: cancel it and tag in on that mob (x2.5), PARRY
func counter_swap(m, nx: String) -> void:
	m.st = "hurt"
	m.hurt_t = 1300.0
	m.flared = false
	m.flare_t = -1.0
	m.atk_clock = 0.0
	m.set_a("hurt")
	m.cd = maxf(m.cd, 1600.0)
	arena.proj = arena.proj.filter(func(p): return p["m"] != m or absf(p["x"] - position.x) > 500.0)
	qte["who"] = [nx]
	qte["t"] = maxf(qte["t"], 1.0)
	qte["hit"] = null
	qte["low"] = false
	swap(true, nx)
	tag_in_at(m, position.x)
	tag_mul = maxf(tag_mul, 2.5)
	inv = maxf(inv, 900.0)
	arena.hitstop = maxf(arena.hitstop, 190.0)
	arena.flash = maxf(arena.flash, 0.5)
	arena.shake(10, dir)
	arena.sfx("parry", 1.0, {"st": 7.0})     # a glint caught: the perfect parry's fifth
	arena.sfx("slam", 0.8)
	arena.text(Vector2(tag_to, position.y - 190.0 * CSCALE), "PARRY!", Color("#ffffff"))
	arena.parry_word()

func qte_offer(reason: String, data = null) -> void:
	var cands: Array = CH.QTE_WHO.get(reason, []).filter(func(c): return party.has(c) and c != who and hpm[c] > 0.0)
	if cands.is_empty():
		return
	if qte["t"] <= 0.0:
		if qte["cd"] > 0.0 and reason != "hit":
			return
		qte["who"] = []
		qte["hit"] = null
		qte["low"] = false
	for c in cands:
		if not qte["who"].has(c): qte["who"].append(c)
	if reason == "hit": qte["hit"] = data
	if reason == "low": qte["low"] = true
	qte["t"] = QTE_T * _mk("qteT")
	qte["cd"] = 3500.0
	arena.sfx("ui_ok", 0.5)

func qte_end() -> void:
	qte["t"] = 0.0
	qte["who"] = []
	qte["hit"] = null
	qte["low"] = false


# ---------- drawing ----------
func _draw() -> void:
	for o in outs:
		var k: float = o["t"] / 600.0
		var ofs := Vector2(o["x"] - o["dir"] * 140.0 * k, o["y"]) - position
		var fr := mini(int(o["t"] / 150.0), 3)
		draw_frame(o["c"], o["anim"], fr, ofs, -o["dir"] if not o["dead"] else o["dir"], Color(1, 1, 1, 1.0 - k), "", null, NAN, 0, "out" + str(o["c"]))
	# afterimages (ghostFx): the frame tinted with PAL[CHAR].ghost, smooth (never pixelated), 0.35 at birth
	var gt: Array = CH.GHOST[who]
	for g in ghosts:
		var k2: float = 1.0 - g["t"] / g["life"]
		var gc: Color = gt[0]
		draw_frame(g["c"], g["anim"], g["f"], Vector2(g["x"], g["y"]) - position, g["dir"], Color(gc.r, gc.g + (6.0 if gt[1] > 0.77 else 4.0), gc.b, 0.35 * k2))
	var an := anim
	var fr2 := f
	if who == "estelle" and an == "parry" and bash_t <= 0.0:
		an = "guard"
		fr2 = 1
	if who == "estelle" and not on and (an == "guard" or an == "parry"):
		an = "air_" + an
	# invincible: she blinks out every other 60 ms (not while hurt or tagging in)
	if inv > 0.0 and anim != "hurt" and anim != "tag_in" and int(t / 60.0) % 2 == 0 and not arena.ult_busy(): return
	var col := Color.WHITE
	if anim == "hurt" and ft < 60.0: col.g = 3.0         # the hurt flash: white over the frame (char_pix flag 1)
	col.a *= arena.ult_alpha()
	var variant := ""
	if anim == "tp_in" or anim == "dig_out":
		variant = "_air" if dig_air else ("_q" if rift_q else "")
	if not anim in ["tp_in", "dig_out"] and (gclip != null or gdx != 0.0 or g_in != null or g_out != null): _rift_clean()
	var br := t if anim == "idle" and not arena.ult_busy() else -1.0
	var rim := col.a >= 1.0
	if gclip != null: draw_frame(who, an, fr2, Vector2(gdx, 0), dir, col, variant, null, gclip["x"] - position.x, gclip["keep"], "P", br, rim)
	else: draw_frame(who, an, fr2, Vector2(gdx, 0), dir, col, variant, null, NAN, 0, "P", br, rim)

## 캐릭터 도트화 (charPix): shaders/char_pix.gdshader. One shared material for the party, the townsfolk and the hero over
## the slow-time grade; a "marked" twin for the level nodes that draw Eilin among their props (her draws carry r + 1).
const PIX_SH := preload("res://shaders/char_pix.gdshader")
const CB := preload("res://scripts/char_bounds.gd")
const PIXM := {"off": 0, "dot": 1, "shade": 2}
static var _pix: ShaderMaterial
static var _pixm: ShaderMaterial
static var _mats: Array = []
static func pix_mat() -> ShaderMaterial:
	if _pix == null:
		_pix = ShaderMaterial.new()
		_pix.shader = PIX_SH
		_mats.append(_pix)
	return _pix

static func pix_mat_marked() -> ShaderMaterial:
	if _pixm == null:
		_pixm = ShaderMaterial.new()
		_pixm.shader = PIX_SH
		_pixm.set_shader_parameter("marked", true)
		_pixm.set_shader_parameter("mode", pix_mat().get_shader_parameter("mode"))
		_mats.append(_pixm)
	return _pixm

## another material drawing characters with the same slots (tests/cap_pix.gd)
static func pix_mat_add(m: ShaderMaterial) -> void:
	if not _mats.has(m): _mats.append(m)

static func is_pix(m) -> bool:
	return m != null and _mats.has(m)

static func set_pix(m: String) -> void:
	pix_mat()
	pix_mat_marked()
	for mm in _mats: mm.set_shader_parameter("mode", PIXM.get(m, 2))

## per frame (pfx.gd): the screen scale for draws without a slot, and rimLights() — the lights the rim reads,
## each [world pos, r, a, colour] as the prototype lists them
static var RIM_L: Array = []
static func pix_frame(zoom: float, lights: Array) -> void:
	RIM_L = lights
	pix_mat()
	pix_mat_marked()
	for m in _mats: m.set_shader_parameter("zoom", zoom)

## ---- slots: each pixelated draw names one (the hero "P", a townsperson, ...); it carries the exact world -> texel
## mapping, the lit ramp's rows and the rim lights of that body. Its index rides in the draw colour (b + 4 * (slot + 1)).
const NSLOT := 16
static var _slot := {}
static var S_O := PackedVector4Array()
static var S_M := PackedVector4Array()
static var S_L := PackedVector4Array()
static var S_B := PackedVector4Array()
static var S_T := PackedInt32Array()
static var R_L := PackedVector4Array()
static var R_C := PackedVector4Array()

static func _slot_of(key: String) -> int:
	if S_O.is_empty():
		S_O.resize(NSLOT)
		S_M.resize(NSLOT)
		S_L.resize(NSLOT)
		S_B.resize(NSLOT * 3)
		S_T.resize(NSLOT * 20)
		R_L.resize(NSLOT * 3)
		R_C.resize(NSLOT * 3)
	if not _slot.has(key):
		if _slot.size() >= NSLOT: return -1
		_slot[key] = _slot.size()
	return _slot[key]

static func _jr(v: float) -> float:
	return floorf(v + 0.5)

## rimEntity's choice: the lights whose reach (r * 2.2) holds the body centre (cx, cy - 60), strongest three
static func rim_near(cx: float, cy: float) -> Array:
	var near: Array = []
	for l in RIM_L:
		var dv: Vector2 = l[0] - Vector2(cx, cy - 60.0)
		var d := dv.length()
		var R: float = l[1] * 2.2
		if d >= R: continue
		var u := dv / (d if d > 0.0 else 1.0)
		near.append([pow(1.0 - d / R, 1.3) * l[2], u, l[3]])
	near.sort_custom(func(a, b): return a[0] > b[0])
	return near.slice(0, 3)

static var _f32 := PackedFloat32Array([0.0])
static func f32(v: float) -> float:
	_f32[0] = v
	return _f32[0]

## charPix draws on a canvas at ox = round(cx - 200), oy = round(cy - 400); Skia maps each device pixel back into the
## sheet in float32 (x stepped in 32.32 fixed point from the span's first pixel, y per row). Where the exact coordinate is
## a whole 1/16 step, that mapping lands just under it or not: one bit per column / row
static func _ties(i: int, wa: Vector2, d: int, sc: float, rows: bool) -> void:
	for k in 20: S_T[i * 20 + k] = 0
	var oxw := floorf(wa.x - 200.0 + 0.5)
	var oyw := floorf(wa.y - 400.0 + 0.5)
	var oi := Vector2(floorf(wa.x), floorf(wa.y))
	var A := f32(f32(f32(sc) * d) * 0.5)
	var T := f32(f32(f32(f32(sc) * d) * -112.0) + f32(wa.x - oxw))
	var inv := f32(1.0 / A)
	var it := f32(-T * inv)
	var i0 := floorf(minf(T, f32(T + A * 448.0)))
	var x0 := f32(f32(f32(i0 + 0.5) * inv) + it)
	var F0: float = float(int(x0 * 4294967296.0)) - 2147483648.0
	var dx: float = float(int(inv * 4294967296.0))
	for b in 300:
		var col := oi.x - 150.0 + b - oxw            # this world column on the charPix canvas
		var ex := (col + 0.5 - T) / A - 0.5
		if absf(ex * 16.0 - roundf(ex * 16.0)) >= 0.004: continue
		if (F0 + (col - i0) * dx) / 4294967296.0 < roundf(ex * 16.0) / 16.0: S_T[i * 20 + b / 32] |= 1 << (b % 32)
	if not rows: return
	var Ay := f32(f32(sc) * 0.5)
	var Ty := f32(f32(f32(sc) * -170.0) + f32(wa.y - oyw))
	var invy := f32(1.0 / Ay)
	var ity := f32(-Ty * invy)
	for b in 256:
		var row := oi.y - 240.0 + b - oyw
		var ey := (row + 0.5 - Ty) / Ay - 0.5
		if absf(ey * 16.0 - roundf(ey * 16.0)) >= 0.004: continue
		var y := f32(f32(f32(row + 0.5) * invy) + ity)
		if float(int(y * 4294967296.0)) / 4294967296.0 - 0.5 < roundf(ey * 16.0) / 16.0: S_T[i * 20 + 10 + b / 32] |= 1 << (b % 32)

## fill slot `key` for one frame drawn with its feet at world `wa`; bands: [[src top, src bottom, dest top, dest height]]
## in cell rows / local units (before scale `sc`); returns the slot (-1: none left)
static func pix_slot(key: String, c: String, row: int, col: int, wa: Vector2, d: int, sc: float, bands: Array, rim: bool) -> int:
	var i := _slot_of(key)
	if i < 0: return -1
	var oi := Vector2(floorf(wa.x), floorf(wa.y))
	var cx0 := float(col * CH.CELL_W)
	var cy0 := float((row % CH.ROWS_PER_SHEET) * CH.CELL_H)
	S_O[i] = Vector4(oi.x, oi.y, wa.x - oi.x, wa.y - oi.y)
	S_M[i] = Vector4(d * 2.0 / sc, 0.0, cx0 + CH.CELL_W / 2.0, cx0)
	# the sprite's own top and bottom rows (alpha > 100), through the bands, for the lit-from-above ramp
	var bi: int = (row * 9 + col) * 2
	var BB: Array = SK.bounds(c)
	var tb := Vector2(0, 0)
	if bi + 1 < BB.size() and BB[bi] >= 0:
		for j in 2:
			var sr: float = BB[bi + j] + 0.5
			for b in bands:
				if sr >= b[0] and sr < b[1]:
					tb[j] = floorf(wa.y + sc * (b[2] + (sr - b[0]) / (b[1] - b[0]) * b[3])) - oi.y
					break
	_ties(i, wa, d, sc, bands.size() == 1)
	var near: Array = rim_near(wa.x, wa.y) if rim else []
	S_L[i] = Vector4(tb.x, tb.y, bands.size(), near.size())
	for j in 3:
		if j < bands.size():
			var b: Array = bands[j]
			S_B[i * 3 + j] = Vector4(sc * b[2] + wa.y - oi.y - S_O[i].w, sc * b[3], cy0 + b[0], cy0 + b[1])
		if j < near.size():
			var n: Array = near[j]
			var u: Vector2 = n[1]
			R_L[i * 3 + j] = Vector4(-_jr(-u.x * 2.0), -_jr(-u.y * 2.0), minf(0.9, n[0] * 2.4), 0.0)
			var lc: Color = n[2]
			R_C[i * 3 + j] = Vector4(lc.r, lc.g, lc.b, 0.0)
	for m in _mats:
		m.set_shader_parameter("s_o", S_O)
		m.set_shader_parameter("s_m", S_M)
		m.set_shader_parameter("s_l", S_L)
		m.set_shader_parameter("s_b", S_B)
		m.set_shader_parameter("s_t", S_T)
		m.set_shader_parameter("r_l", R_L)
		m.set_shader_parameter("r_c", R_C)
	return i

## `ci`: draw onto another canvas item (the townsfolk use the same sheets); null = the player itself
func _rift_step(a: String, dt: float) -> void:
	if who != "aida": return
	var M: Dictionary = RIFTM["quick" if rift_q else "heavy"]
	if a == "tp_in":
		if g_in == null:
			rd = dir
			in_t = 0.0
			g_in = arena.pfx.gate(position.x + dir * (30.0 if rift_q else 42.0) * CSCALE, position.y, M["h"] * CSCALE, M["k"], M["w"])
		in_t += dt
		var u := clampf((in_t - M["a"]) / M["b"], 0.0, 1.0)
		gdx = rd * 125.0 * CSCALE * u * u
		gclip = {"x": g_in["x"], "keep": -rd} if u > 0.0 else null
	elif a == "dig_out" and g_out != null:
		out_t += dt
		var u2 := clampf((out_t - M["oa"]) / M["ob"], 0.0, 1.0)
		var w := 1.0 - u2
		gdx = -rd * 125.0 * CSCALE * w * w
		gclip = {"x": g_out["x"], "keep": rd}
		if out_t > M["rel"]:
			g_out["rel"] = true
			g_out = null
			gclip = null
			gdx = 0.0

func _rift_clean() -> void:
	if g_in != null: g_in["rel"] = true
	if g_out != null: g_out["rel"] = true
	g_in = null
	g_out = null
	gclip = null
	gdx = 0.0

## `cx`/`keep`: cut the sprite at local x = cx (keep < 0: the part left of it shows, > 0: the right)
## `sk`: the pixelation slot of this body (draws on a char_pix material); `breath` >= 0: the idle breathing at that clock;
## `rim`: the body takes the directional rim of nearby lights
func draw_frame(c: String, an: String, fr: int, at: Vector2, d: int, col: Color, variant := "", ci: CanvasItem = null, cx := NAN, keep := 0, sk := "", breath := -1.0, rim := false) -> void:
	if ci == null: ci = self
	var rf: Array = SK.resolve(c, an, fr, variant)        # the worn costume's own animations first (skins.gd)
	var row: int = rf[0]
	var sheet: Texture2D = SK.sheet_row(c, row)            # its row, or the original art's row it doesn't draw yet
	if sheet == null: return
	var src := Rect2(rf[1] * CH.CELL_W, (row % CH.ROWS_PER_SHEET) * CH.CELL_H, CH.CELL_W, CH.CELL_H)
	var sc: float = CH.SCALE[c] * (CH.ROWFIX_AIDA.get(row, 1.0) if c == "aida" else 1.0)
	var bt: Array = SK.bob(c, an)
	if not bt.is_empty(): at.y += bt[fr % bt.size()]
	var w := CW * sc
	var h := CHH * sc
	# drawFrame's idle breathing: hips and legs stay, the chest stretches by whole pixels, head and shoulders ride on top
	var bands: Array = [[0.0, float(CH.CELL_H), -BASE, CHH]]
	if breath >= 0.0 and row == 0:
		var top: float = SK.breath_top(c)
		var hg := 341.0 - top
		var yW := roundf(341.0 - hg * 0.47)
		var yN := roundf(341.0 - hg * 0.74)
		var ph := fmod(breath, 2800.0) / 2800.0
		var e := ph / 0.38 if ph < 0.38 else (1.0 if ph < 0.52 else (1.0 - (ph - 0.52) / 0.4 if ph < 0.92 else 0.0))
		var dd := roundf(4.0 * e * e * (3.0 - 2.0 * e))
		var k := 0.5
		bands = [[yW, float(CH.CELL_H), -BASE + yW * k, (CH.CELL_H - yW) * k],
			[yN, yW, -BASE + (yN - dd * 2.0) * k, (yW - yN + dd * 2.0) * k + 0.5],
			[0.0, yN, -BASE - dd * 2.0 * k, yN * k + 0.5]]
	var pix := sk != "" and is_pix(ci.material) and col.g < 4.0
	if pix:
		var wa: Vector2 = ci.get_global_transform() * at
		var si := pix_slot(sk, c, row, rf[1], wa, d, sc, bands, rim)
		if si >= 0: col.b += 4.0 * (si + 1)
	var mode0: bool = pix_mat().get_shader_parameter("mode") == 0
	ci.draw_set_transform(at, 0.0, Vector2(d, 1))
	var parts: Array = []
	if bands.size() == 1 or (pix and not mode0):
		var y0: float = -BASE - (6.0 if bands.size() > 1 else 0.0)
		parts.append([Rect2(-w / 2.0, y0 * sc, w, (CHH - BASE - y0) * sc), src])
	else:
		for b in bands:
			parts.append([Rect2(-w / 2.0, b[2] * sc, w, b[3] * sc), Rect2(src.position.x, src.position.y + b[0], src.size.x, b[1] - b[0])])
	for pt in parts:
		var dr: Rect2 = pt[0]
		var sr: Rect2 = pt[1]
		if not is_nan(cx):
			var bx := d * (cx - at.x)
			var u0 := -w / 2.0
			var u1 := w / 2.0
			if keep * d > 0: u0 = maxf(u0, bx)
			else: u1 = minf(u1, bx)
			if u1 <= u0: continue
			var s0 := sr.position.x + (u0 + w / 2.0) / w * sr.size.x
			var s1 := sr.position.x + (u1 + w / 2.0) / w * sr.size.x
			ci.draw_texture_rect_region(sheet, Rect2(u0, dr.position.y, u1 - u0, dr.size.y), Rect2(s0, sr.position.y, s1 - s0, sr.size.y), col)
		else:
			ci.draw_texture_rect_region(sheet, dr, sr, col)
	ci.draw_set_transform(Vector2.ZERO)


# ---------- rune hooks (runes.gd; step 5-2) ----------
func _rk() -> bool:
	return arena != null and arena.get("runes") != null

func _rev(e: String) -> void:
	if _rk(): arena.runes.ev(e)

func _cdk() -> float:
	return arena.runes.cd_k() if _rk() else 1.0

func _inm() -> float:
	return arena.runes.in_mul() if _rk() else 1.0

## memory nodes: a multiplier of the member in control (rch, swap, qteT), the level multiplier, max HP of any member
func _mk(key: String) -> float:
	return arena.runes.memory.mul(who, key) if _rk() else 1.0

func _lvm(c: String) -> float:
	return arena.runes.lvm(c) if _rk() else 1.0

## heals that grow with the level and 회복량 (30 × LVM × (1 + heal%))
func _lvh(c: String) -> float:
	return _lvm(c) * (1.0 + (arena.runes.gear_tot(c)["heal"] / 100.0 if _rk() else 0.0))

func _mhp(c: String) -> float:
	return arena.runes.max_hp(c) if _rk() else CH.STATS[c]["hp"]

## 방패 던지기 replaces Estelle's shield skill
func _shield_throw() -> bool:
	if not _rk() or not arena.runes.has("shieldthrow", "estelle"): return false
	if arena.runes.shield_cd <= 0.0: arena.runes.shield_throw()
	return true
