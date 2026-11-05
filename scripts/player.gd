extends Node2D
## The controlled party member and the party around her.
## Estelle (shield, charge thrust), Aida (rift blink / rift sigil / rift strike), Luce (light bolts, pillar, lightning, heal).
## Ported from the web prototype's update(), partySwap() and the sortie module's counter swap.
## Units as in the prototype: world px, ms, px/ms, px/ms^2.

const CH = preload("res://scripts/chars.gd")
const SK := preload("res://scripts/skins.gd")
const BAL := preload("res://scripts/balance.gd")
const ST := preload("res://scripts/status.gd")      # 공용 상태 (P.ally: 보호막 · 강화 · 재생)

const GRAV := 0.0021
const JUMPV := 0.74
const DJUMPV := 0.80
## an early release brakes the first jump's rise by this much more gravity (PLACEHOLDER: 2 ≈ half the height on a tap)
const JUMP_CUT_G := 2.0
var jump_cut := false
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
var k_rep := 0                  # Kenin: rounds still to come in this burst (the fire frame replays for each, 따다닥)
const K_REWIND := 38.0          # ms the frame before the shot shows on each replay
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
var slot_req := -1         # 1 · 2 · 3 on the keyboard: swap straight to that party slot (consumed in the step)
var slot_req_t := 0
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
## QA 2026-11-04 (mashed QTEs chained Aida > Kenin > Estelle > Aida in a blink): after a tag or a bench assist the party
## keys rest until its motion has played (party_lock), and no new QTE is offered for QTE_GAP after one was answered
var party_lock := 0.0
var qte_gap := 0.0
var tag_src := ""           # who opened the QTE the incoming member answered (등을 맡긴다)
var l_bless_t := 0.0        # Luce's 빛의 가호 (ms left): the one in control's hits draw her bolts from the bench
var l_bolt_cd := 0.0
var a_follow := {}          # Aida: the follow-up window after a launch {"m", "t" ms, "k" damage bonus}
var a_left := {}            # Aida's 남은 균열 (left where she swapped out) {"x", "y", "t" ms to the burst}
var cp_quiet := false        # swap() called by 교대 패링: no "TAG!" caption, no tag-in flash (the clash is the moment)
var cp := {}                 # 교대 패링 in progress {"m", "t", "to", "hit", "fu"}: in → clash → recoil → the follow-up window
var a_exec_cd := 0.0        # 처형's cooldown (ms): solo routes wait it out; a foe the party left 무방비 ignores it
var a_exec := {}            # Aida's 처형 (the empowered strike's own motion) {"tg", "t", "k", "x", "g0", "top", "hit1", "hit2"}
var a_emp := false          # the rift strike in flight is the empowered one (무방비 target: instant, full, bigger)
var e_guard_t := 0.0        # 용감한 희생: Estelle's covering guard (ms left) takes the next blow
var e_assist := {}          # … and her figure beside the one in control {"t", "x", "y", "dir"}
var qte_pend := {}          # a parry made during the gap (교대 패링): its QTE opens once the gap is over {"r", "t" ms left}
const QTE_GAP := 1600.0
const LOCK_TAG := 1050.0
const LOCK_ASSIST := 1150.0
const LOCK_SWAP := 450.0
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
	for c in CH.NAME:
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
	return CH.STATS[who]["atk"] * (arena.runes.atk_k(who) if _rk() else 1.0) * ST.atk_k(self)     # 강화


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

## the strike of the current ground attack has gone out (its hit frame reached): the recovery may be cancelled
func rec_cancel_ok() -> bool:
	if not anim in ["attack1", "attack2", "attack3", "cthrust", "lfinisher", "kneel_attack"]:
		return false
	var ca = cur_atk()
	if ca == null or not ca.has("hit"):
		return f >= 3
	return f > ca["hit"][0] or fx_done or hit_done

func busy_rift() -> bool:
	return anim in ["tp_in", "dig_out", "rturn", "mark", "amark", "dig_in"]

func want(k: String) -> bool:
	return buf[k] > 0.0

## during a hitstop the world (and this step) is held: a press made then is kept in the buffer instead of lost
func buffer_only() -> void:
	for k in buf:
		if InputMap.has_action(k) and Input.is_action_just_pressed(k): buf[k] = BUF

func take(k: String) -> void:
	buf[k] = 0.0

func cur_atk():
	var key := anim
	if anim == "air_combo": key = "air1" if f < 3 else ("air2" if f < 6 else "air3")
	var base = CH.ATK.get(key)
	if base == null: return null
	var a: Dictionary = base.duplicate()
	if anim == "cthrust":
		# the charged thrust (charge / gcharge release): full charge hits harder and knocks back further
		a["kb"] = 16 if cfull else 10
		key = "cthrust" if cfull else "cthrust_part"
	a["dmg"] = BAL.p(who, key, float(a["dmg"]))          # balance.gd: % of 공격력
	return a

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
	# 1 · 2 · 3 (top row or keypad): the party slot to swap to, unless the key is bound to something else
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		var i := [KEY_1, KEY_2, KEY_3].find(k)
		if i < 0: i = [KEY_KP_1, KEY_KP_2, KEY_KP_3].find(k)
		if i >= 0 and not (arena != null and arena.get("cfg") != null and arena.cfg.kb_uses(k)):
			slot_req = i
			slot_req_t = Time.get_ticks_msec()

## 마우스 조준 (설정 · 키보드+마우스일 때만): Kenin's shots, Luce's bolts / pillar / lightning and Aida's sigil follow the pointer
func mouse_aim() -> bool:
	if arena == null or arena.get("cfg") == null: return false
	return arena.cfg.aim == "mouse" and arena.cfg.act_dev() == "kbm" and arena.forced_keys() == null

var aim_test := Vector2.INF      # tests: stands in for the pointer
## 마우스 조준: every member turns to the pointer's side as a blow starts (a combo's next hit, a charged release too)
func face_aim() -> void:
	if not mouse_aim(): return
	var adx := aim_pt().x - position.x
	if absf(adx) > 8.0: dir = int(signf(adx))

func aim_pt() -> Vector2:
	return aim_test if aim_test.is_finite() else get_global_mouse_position()

## the foe nearest p (its body, ~50 px up), within r
func foe_near(p: Vector2, r: float):
	var best = null
	var bd := r
	for e in foes_alive():
		var d: float = p.distance_to(e.position + Vector2(0, -50.0))
		if d < bd:
			bd = d
			best = e
	return best

func floor_y(x: float) -> float:
	var L = arena.level
	return L.floor_at(x) if L != null and L.has_method("floor_at") else arena.ground_y

## where Luce's strike lands: the nearest foe in range, or with 마우스 조준 the foe under the pointer, else the pointer's
## spot (within rng); turns her to face it. {"tg", "x", "y" (the ground there), "aim" (where a bolt with no foe flies)}
func luce_spot(rng: float, ahead: float) -> Dictionary:
	var tg = null
	if mouse_aim():
		var ap := aim_pt()
		tg = foe_near(ap, 170.0)
		if tg != null and absf(tg.position.x - position.x) > rng * 1.5: tg = null
		if tg == null:
			var x := clampf(clampf(ap.x, position.x - rng, position.x + rng), 30.0, arena.world_w - 30.0)
			if absf(x - position.x) > 8.0: dir = int(signf(x - position.x))
			return {"tg": null, "x": x, "y": floor_y(x), "aim": Vector2(x, minf(ap.y, floor_y(x) - 20.0))}
	else:
		tg = target(rng)
	if tg != null:
		dir = int(signf(tg.position.x - position.x)) if tg.position.x != position.x else dir
		return {"tg": tg, "x": tg.position.x, "y": arena.ground_y if is_fly(tg) else tg.position.y, "aim": Vector2.INF}
	return {"tg": null, "x": position.x + dir * ahead * CSCALE, "y": position.y, "aim": Vector2.INF}

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
	if mouse_aim():
		face_aim()
		return
	if keys["left"] or keys["right"]:
		return
	var R := 420.0 if who == "luce" or who == "kenin" else 170.0 * CSCALE
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
			set_anim("air_combo", 0)           # (Dead Cells-like, owner 2026-11-05: no longer spends the double jump)
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
	if not on or who == "luce" or who == "kenin":
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

## Kenin: every attack frame in KATK's "fire" pulls the trigger once (kenin.gd flies the ball); flat shots lean toward
## the nearest foe ahead a little (at most ~17°)
func kenin_shoot() -> void:
	var ka = CH.KATK.get(anim)
	if ka == null or hit_done or not ka["fire"].has(f):
		return
	hit_done = true
	fx_done = true
	var aimm := mouse_aim()
	if aimm and not ka.get("up", false) and not ka.get("down", false):
		var adx := aim_pt().x - position.x
		if absf(adx) > 8.0: dir = int(signf(adx))
	# the muzzle in world px (a cell draws at half size × CSCALE): chest height, just past the outstretched hands
	var S := CSCALE
	var mz := position + Vector2(dir * 34.0 * S, -44.0 * S)
	var d := Vector2(dir, 0.0)
	if ka.get("up", false):
		mz = position + Vector2(dir * 22.0 * S, -84.0 * S)
		d = Vector2(dir * 0.5, -0.866)
	elif ka.get("down", false):
		mz = position + Vector2(dir * 4.0 * S, -6.0 * S)
		d = Vector2(dir * 0.17, 0.985)
	else:
		if anim == "kneel_attack": mz = position + Vector2(dir * 36.0 * S, -24.0 * S)
		var tg = null if aimm else target(720.0)
		if aimm:
			# 마우스 조준: straight at the pointer, up to ~57° off level
			var av := aim_pt() - mz
			var ang0 := clampf(atan2(av.y, absf(av.x)), -1.0, 1.0)
			d = Vector2(dir * cos(ang0), sin(ang0))
		elif tg != null and (tg.position.x - position.x) * dir > 0.0:
			var aim: Vector2 = (tg.position + Vector2(0, -55.0) - mz).normalized()
			var ang := clampf(atan2(aim.y, absf(aim.x)), -0.3, 0.3)
			d = Vector2(dir * cos(ang), sin(ang))
	var kd: float = BAL.p("kenin", anim, float(ka["dmg"]))
	var heavy: bool = ka.get("heavy", false) or (anim == "air_combo" and f == 8)
	if heavy: kd *= 1.0 + arena.kenin.nv("kHeavyShot")    # 헤드샷 연습
	var first := k_rep <= 0
	k_rep = (arena.kenin.BURST - 1) if first else k_rep - 1
	var last := k_rep == 0
	# a finisher (3타, the air combo's last) goes 따닥 — 팡: two light rounds, then one big round carrying half the damage
	var big := heavy and last
	var share := 1.0
	if heavy: share = (0.5 if big else 0.25) * arena.kenin.BURST
	if not arena.kenin.fire(mz, d, kd * share, first, big):
		k_rep = 0
		# empty: no shot; on the ground he stops and looks at the pistol
		if on: set_anim("kdry")
		return
	add_ghost(120.0, -dir * 10.0 * S)
	if big:
		slide = -dir * 0.32 if on else slide          # the big round's kick: a skid back
		arena.shake(6, -dir)
		arena.hitstop = maxf(arena.hitstop, 70.0)
		arena.flash = maxf(arena.flash, 0.1)
		add_ghost(180.0, -dir * 22.0 * S)
		if ka.get("heavy", false): qte_offer("finisher")
	else:
		arena.shake(1.5, -dir)

## Luce: every strike is a gesture; the real hit is light the game draws
func luce_gesture(atk) -> void:
	if atk == null or f != atk["hit"][0] or hit_done:
		return
	hit_done = true
	fx_done = true
	add_ghost(140.0, -dir * 14.0 * CSCALE)
	var sp := luce_spot(420.0, 80.0 if anim == "attack_high" else 95.0)
	var tg = sp["tg"]
	var gy: float = sp["y"]
	if anim == "attack3":
		arena.pillar(sp["x"], gy, BAL.p("luce", "attack3"), dir)
		arena.sfx("heavy", 0.8)
		arena.shake(5, dir)
		arena.hitstop = 30.0
	elif anim == "attack_high":
		arena.lightning(sp["x"], gy, 0.8, BAL.p("luce", "attack_high"), dir)
		arena.sfx("heavy", 0.7)
		arena.shake(4, dir)
		arena.hitstop = 25.0
	else:
		var sz := 1.15 if anim == "attack2" else (1.1 if anim == "air_combo" and f >= 7 else 1.0)
		var n := 2 if anim == "attack2" else 1
		for i in n:
			var o := Vector2(position.x - dir * (30.0 + i * 18.0), position.y - 125.0 * CSCALE - i * 16.0)
			arena.bolt(o, tg, sz, 150.0 + i * 90.0, dir, hit_sound(), sp["aim"])
		arena.sfx("thrust", 0.6)

func check_hits() -> void:
	var atk = cur_atk()
	if who == "luce":
		luce_gesture(atk)
		return
	if who == "kenin":
		kenin_shoot()
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
			var brk: bool = who == "estelle" and anim == "cthrust" and cfull and _ev("eBreak") > 0.0 and (ST.has(e, "stagger") if not ST.big(e) else ST.groggy_on(e))
			e.hit(atk["dmg"], dir * atk["kb"], atk_mul())
			if who == "aida" and anim == "attack3" and e.alive(): aida_launch(e)
			if who == "estelle":
				if brk and e.alive():
					# 압도적인 힘으로!: a full thrust into a staggered foe breaks it — the stagger ends in a heavy extra blow
					e.hit(atk["dmg"] * _ev("eBreak"), dir * 6.0, atk_mul())
					if ST.has(e, "stagger"):
						ST.of(e)["stagger"]["t"] = 0.0
						ST.of(e)["stagger"]["imm"] = ST.K.stagger.imm
					arena.text(e.position + Vector2(0, -200), "브레이크!", Color("#ffd34d"))
					arena.shake(10, dir)
				else:
					estg(e, _estg_of())
			hit_any = true
			if hp0 == Vector2.INF: hp0 = Vector2(ex, ey - 50.0)
	if hit_any:
		hit_done = true
		var heavy: bool = atk.get("heavy", false)
		arena.sfx(hit_sound())
		if heavy: _rev("heavy")
		if _rk() and (who == "aida" or _av("aShadow") > 0.0): arena.runes.clone_hits(atk)      # 남겨진 그림자: it fights on after a swap
		arena.hitstop = atk.get("stop", 55)
		arena.shake(atk.get("shake", 4), dir)
		# 타격감: the weight of the blow (by its sound: hit1 / hit2 light, hit3, heavy) — the hitstop by weight, the
		# chromatic pulse, the zoom punch and the kick (the punch distortion is the mob's, in mob.hit); 화면 효과 off:
		# the lines above stand as they are
		arena.impact(hit_weight(), hp0, dir)
		# the old cross-cut + ring (slash_mark) is gone: the baked pfx hit on the target carries the impact (owner 2026-11-05)
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
		var emp: bool = s.get("emp", false)
		var dmg: float = lerpf(BAL.p("aida", "rift_min"), BAL.p("aida", "rift_max"), clampf(s["r"], 0.0, 1.0)) * _am("riftK") * float(s.get("k", 1.0))
		var lo: float = minf(s["x0"], position.x) - 20.0
		var hi: float = maxf(s["x0"], position.x) + 20.0
		var hit := false
		var hit_exposed = null
		for m in foes_alive():
			if m.position.x < lo or m.position.x > hi or absf(m.position.y - position.y) > 110.0:
				continue
			var was_exp: bool = ST.exposed(m)
			m.hit(dmg, -dir * 8.0, atk_mul())
			if _av("riftLaunch") > 0.0 and m.alive(): ST.add(arena, m, "air", -1.0, "aida")      # 무너진 땅
			if was_exp and hit_exposed == null: hit_exposed = m
			hit = true
		if hit:
			arena.streak_fx(s["x0"], position.x, position.y - 62.0 * CSCALE, dir, Color("#f2e6ff") if emp else Color("#b37bff"))
			if emp:
				arena.streak_fx(s["x0"], position.x, position.y - 58.0 * CSCALE, dir, Color("#9a4dff"))
				# the 강화 균열 베기: a rift tears open in the ground under the foe and slashes up through it
				var tg2 = s.get("tg")
				var ex: float = tg2.position.x if tg2 != null and is_instance_valid(tg2) else position.x - dir * 95.0 * CSCALE
				var erupt = arena.pfx.gate(ex, position.y, 230.0 * CSCALE, 1.8, 1.5)
				erupt["rel"] = true
				arena.slash_fx(Vector2(ex, position.y - 80.0 * CSCALE), 120.0 * CSCALE, deg_to_rad(110.0), deg_to_rad(-70.0), dir, Color("#e9d2ff"), 1.4)
				arena.spark(Vector2(ex, position.y - 90.0 * CSCALE), 22)
				arena.shake(9, dir)
				arena.flash = maxf(arena.flash, 0.3)
				arena.sfx("heavy", 1.0)
				arena.text(position + Vector2(0, -175.0 * CSCALE), "처형!", Color("#e9d2ff"))
			qte_offer("finisher")
			# 기습의 문 (KEY): a 무방비 foe struck → one more follow-up on another foe near, +40%
			if hit_exposed != null and _av("riftChain") > 0.0 and float(s.get("k", 1.0)) <= 1.0:
				var nx = null
				var nd := 420.0
				for m2 in foes_alive():
					if m2 == hit_exposed: continue
					var d2: float = absf(m2.position.x - position.x)
					if d2 < nd:
						nd = d2
						nx = m2
				if nx != null: a_follow = {"m": nx, "t": 800.0, "k": _av("riftChain")}
		arena.sfx("aida_heavy", 1.0)
		arena.shake(5.0 + s["r"] * 7.0, dir)
		arena.post_wave(Vector2((s["x0"] + position.x) / 2.0, position.y - 60.0 * CSCALE), 0.8 + s["r"] * 0.6, 520.0, 0.2)
		arena.hitstop = maxf(arena.hitstop, (80.0 + s["r"] * 60.0) * (1.6 if emp else 1.0) if hit else 30.0)
		if emp: arena.post_wave(position + Vector2(0, -60.0 * CSCALE), 1.6, 620.0, 0.32)
		a_emp = false
	set_anim("dig_out")
	dig_air = not on

func rift_strike(r: float, tg = null, emp := false, bonus := 1.0) -> void:
	var R := (200.0 + r * 220.0) * CSCALE
	var best = tg
	var bdx := INF
	if best == null:
		for m in foes_alive():
			var dx: float = (m.position.x - position.x) * dir
			if dx > 10.0 and dx < R and absf(m.position.y - position.y) < 120.0 and dx < bdx:
				bdx = dx
				best = m
	else:
		dir = 1 if best.position.x >= position.x else -1
	a_emp = emp
	if emp:
		# 강화 균열 베기: the tear opens white-cored and wide, the hit holds longer (PLACEHOLDER art: the existing fx scaled)
		arena.flash = maxf(arena.flash, 0.18)
		arena.sfx("aida_open", 1.0)
		add_ghost(260.0)
	var to: float = best.position.x + dir * 95.0 * CSCALE if best != null else position.x + dir * (150.0 + r * 110.0) * CSCALE
	blink_face = -dir if best != null else 0
	r_strike = {"r": r, "x0": position.x, "emp": emp, "k": bonus}
	r_follow = best != null
	var ty = best.position.y if best != null and not is_fly(best) else NAN
	if emp and best != null and ST.has(best, "air"): ty = float(ST.of(best)["air"]["y0"])      # owner: she stays on the ground, the rift rises to it
	r_strike["tg"] = best
	rift_enter(to, ty, false)
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
	if not a_follow.is_empty():
		a_follow["t"] = float(a_follow["t"]) - dt
		var fm = a_follow["m"]
		if float(a_follow["t"]) <= 0.0 or who != "aida" or not is_instance_valid(fm) or not fm.alive():
			a_follow = {}
		elif anim in ["attack3", "idle", "run", "stop", "attack1"] and want("attack") and (ST.exposed(fm) or ST.big(fm)) and (a_exec_cd <= 0.0 or ax_free(fm)):
			# 추격 균열 베기: one more press after the launch → out of the rift behind the lifted foe, empowered
			pressed["attack"] = false
			take("attack")
			var k: float = a_follow["k"]
			a_follow = {}
			aida_exec(fm, k)
	if not cp.is_empty():
		_cp_step(dt)
		for g in ghosts: g["t"] += dt
		ghosts = ghosts.filter(func(g): return g["t"] < g["life"])
		queue_redraw()
		return
	if not a_exec.is_empty():
		_aexec_step(dt)
		for g in ghosts: g["t"] += dt
		ghosts = ghosts.filter(func(g): return g["t"] < g["life"])
		queue_redraw()
		return

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

	# variable jump height (owner 2026-11-05): letting go of jump early doesn't snap the rise off any more, it brakes it
	# (heavier gravity while rising), so a tap still gets about half the height; only the first jump (the double jump
	# always goes all the way), and an attack pressed right after takes over with the height it has (no cut in the gap)
	jump_cut = not keys["jump"] and not on and vy < 0.0 and anim in ["jump", "runjump"] and not mantled

	var move := move_axis()
	var a := anim
	if regrab_t > 0.0: regrab_t -= dt
	if a == "climb":
		# the ledge climb plays out in place (she already stands on the lip); a hit still interrupts it
		ledge_off_t += dt
		vx = 0.0
		vy = 0.0
		advance(dt, 0)
		queue_redraw()
		return
	if a == "hang":
		# hanging by one hand, swaying: up / jump / toward the ledge climbs, down / away lets go
		vx = 0.0
		vy = 0.0
		advance(dt, 0)
		var mvh := move_axis()
		if want("jump") or keys["up"] or (mvh == ledge_side and ft > 160.0 and f > 0):
			take("jump")
			_climb_start(ledge_at.y, ledge_at.x, ledge_side, 0)
		elif keys["down"] or mvh == -ledge_side:
			regrab_t = 300.0
			position.x -= ledge_side * 6.0
			vy = 0.05
			set_anim("jump", 4)
		queue_redraw()
		return

	# ---- state machine ----
	if a == "hurt" and bounce_t > 0.0:
		bounce_t -= dt
		vx = -dir * 0.5 * maxf(0.0, bounce_t / BOUNCE)
	elif a == "hurt" or a == "death" or a == "tag_out":
		vx = 0.0
	elif a == "tag_in" or a == "swap_in":
		vx = 0.0
	elif a == "kdry":
		vx = 0.0
	elif a == "kfire":
		vx = 0.0
		if f >= 2 and not fx_done:
			fx_done = true
			var n: int = arena.kenin.chain_detonate(position + Vector2(dir * 30.0 * CSCALE, -40.0 * CSCALE))
			arena.sfx("slam", 0.8)
			arena.shake(5.0, dir)
			if n == 0: arena.kenin.dud_blast(position + Vector2(dir * 60.0 * CSCALE, -30.0 * CSCALE))
	elif a in ["charge", "acharge", "lgather", "gcharge", "kcharge"]:
		if move != 0 and a != "lgather": dir = move
		vx = 0.0
		charge_t += dt * _mk("cspd")              # 다시 한 번: gathers faster
		arena.charge_fx(position + Vector2(-dir * 2.0, -64.0 * CSCALE), charge_t, CH.COLOR[who])
		if charge_t >= 650.0 and not cfull:
			cfull = true
			arena.sfx("ui_ok")
			arena.flash = 0.08
		if not keys["attack"]:
			var r := minf(1.0, (charge_t - 200.0) / 450.0)
			face_aim()
			if charge_t < 200.0:
				if a == "gcharge": set_anim("guard", 1)      # a tap under the shield: back to guard
				else: set_anim("attack1", 2)
			elif a == "lgather":
				set_anim("lfinisher")
				cw_r = r
				arena.sfx("ui_ok", 0.5)
			elif a == "acharge":
				rift_strike(r)
			elif a == "kcharge":
				set_anim("kfire")
				arena.sfx("ui_ok", 0.6, {"st": -3.0})
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
		var aim_on := mouse_aim()
		if aim_on:
			var mw0 := aim_pt()
			mx = mw0.x
			my = mw0.y
		elif mark_mouse:
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
			# a tap hops back — with 마우스 조준 a quick click still goes to the pointer (only the pointer on her hops back)
			if (mark_t < 150.0 and not aim_on) or Vector2(mx, my).distance_to(position) < (40.0 if aim_on else 16.0):
				rift_enter(position.x - dir * 90.0 * CSCALE, NAN, false, 0.8)    # tap = short hop backwards through a hole
			else:
				rift_enter(mx, my, false, 1.0)
				dig_air = true
				tp_cd = 3000.0 * _cdk()
				_rev("skill")
				if _rk() and (arena.runes.has("clone") or _av("aClone") > 0.0): arena.runes.clone_start()
	elif a in ["dash", "airdash", "backstep"]:
		if a == "dash" and who == "kenin":
			# the roll: tuck, five spins at full tilt, uncurl (frames 7-8); a wall stops it dead (bounce below)
			var spk: Array = [0.25, 0.75, 0.95, 0.95, 0.95, 0.9, 0.75, 0.25, 0.0]
			vx = dir * (spk[f] if f < spk.size() else 0.0)
			if f == 7 and move == dir: set_anim("run")
		elif a == "dash":
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
	elif a == "bomb":
		if on: vx = 0.0
		else: vx *= pow(0.996, dt)
		if f == 6 and not fx_done:
			fx_done = true
			var btg = target(460.0)
			var btx: float = btg.position.x if btg != null and (btg.position.x - position.x) * dir > 0.0 else NAN
			if mouse_aim():
				# 마우스 조준: the lob reaches for the foe under the pointer, else the pointer's spot
				var bap := aim_pt()
				var bf = foe_near(bap, 170.0)
				face_aim()
				btx = bf.position.x if bf != null else bap.x
			arena.kenin.throw_bomb(position + Vector2(dir * 14.0 * CSCALE, -80.0 * CSCALE), dir, btx)
			_rev("skill")
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
			var hv := float(roundi(luce_heal("heal")))    # 공격력의 170% × 회복량 (the rest comes from 빛의 가호)
			bless_start()
			hp = minf(MAX_HP, hp + hv)
			var al := 0
			for c in party:
				if c != who and hpm[c] > 0.0 and hpm[c] < _mhp(c):
					hpm[c] = minf(_mhp(c), hpm[c] + hv)
					al += 1
			heal_cd = 14000.0 * _cdk()
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
						e.hit(BAL.p(who, "dive_slam"), dir * 6, atk_mul())
						if who == "estelle": estg(e, E_STG["dive"])
		elif a == "air_combo":
			# Dead Cells-like (owner 2026-11-05): the swing keeps the jump's rise and the run's momentum, steerable
			# (facing stays put); only a fall is held up a little
			if vy > 0.0: vy = minf(vy, 0.12)
			var mv := move_axis()
			if mv != 0: vx += (mv * RUN * 0.85 - vx) * minf(1.0, dt / 80.0)
			else: vx *= pow(0.996, dt)
			# the double jump cuts the swing once its strike is out
			if want("jump") and air < 1 and f >= 2 and not air_tag:
				take("jump")
				air = 1
				vy = -DJUMPV
				set_anim("double_jump")
				arena.sfx("djump")
				arena.pfx.djump(self)
			var air_ok := (f == 2 or f == 5) and ft > dur() * 0.55
			if want("attack") and air_ok and combo_win > 0.0:
				take("attack")
				face_aim()
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
			if a == "attack3" and f == 2 and who != "kenin": vx = dir * 0.45
			if a == "attack3" and f == 3 and ft < 40.0 and who != "kenin": vx = dir * 0.2
			if a == "lfinisher" and f == 2 and not fx_done:
				fx_done = true
				var sp := luce_spot(520.0, 95.0)
				arena.lightning(sp["x"], sp["y"], 1.0 + cw_r * 1.2, lerpf(BAL.p("luce", "lfinisher_min"), BAL.p("luce", "lfinisher_max"), clampf(cw_r, 0.0, 1.0)), dir)
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
				face_aim()
				set_anim("attack2")
				arena.sfx("swing")
				if who != "kenin": position.x += dir * 8.0
				lunge_assist()
			elif a == "attack2" and chain_ok and want("attack"):
				take("attack")
				face_aim()
				set_anim("attack3")
				arena.sfx("swing")
				lunge_assist()
			if f >= 3 and want("guard") and who == "estelle":
				take("guard")
				face_aim()
				if _shield_throw(): pass
				else:
					set_anim("parry")
					ghit = false
			# recovery cancel: once the strike is out, the rest of the swing can be cut into a skill or a jump
			# (the windup stays committed; dash and swap already cut anywhere)
			elif on and rec_cancel_ok():
				if want("guard"):
					take("guard")
					use_skill(move)
				elif want("jump"):
					take("jump")
					on = false
					vy = -JUMPV
					vx = dir * 0.1
					set_anim("jump", 2)
					arena.sfx("jump")
					arena.dust(position, 0, false)
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

	var want_x := position.x + vx * dt
	physics(dt, a)
	if who == "kenin" and anim == "dash" and f >= 1 and f <= 6 and absf(vx) > 0.5 and absf(position.x - want_x) > absf(vx * dt) * 0.6:
		roll_bounce()
	advance(dt, move)
	tag_motion(dt)

	for g in ghosts:
		g["t"] += dt
	ghosts = ghosts.filter(func(g): return g["t"] < g["life"])
	queue_redraw()


## Kenin's roll hits a wall: the hurt frames, bounced back a little (no damage)
const BOUNCE := 260.0
var bounce_t := 0.0
func roll_bounce() -> void:
	set_anim("hurt")
	bounce_t = BOUNCE
	inv = maxf(inv, 300.0)
	arena.shake(4, -dir)
	arena.sfx("down", 0.6)
	arena.dust(position + Vector2(dir * 18.0 * CSCALE, 0), -dir, false)
	arena.spark(position + Vector2(dir * 30.0 * CSCALE, -40.0 * CSCALE), 5)

## guard key = each member's skill
func use_skill(move: int) -> void:
	if mouse_aim(): move = 0            # 마우스 조준: the skill goes the pointer's way, not the held key's
	face_aim()
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
			if mouse_aim():
				mark_mouse = true          # 마우스 조준: the sigil starts at the pointer
				var ap := aim_pt()
				mx = ap.x
				my = ap.y
			if on: arena.sfx("swing", 0.3)      # the air sigil comes up silently
	elif who == "luce":
		if heal_cd <= 0.0 and on:
			set_anim("heal")
			heal_t = 0.0
			arena.sfx("swing", 0.2)
	elif who == "kenin":
		if arena.kenin.can_throw():
			if move != 0: dir = move
			set_anim("bomb")
		else:
			arena.text(position + Vector2(0, -150.0 * CSCALE), "폭탄 없음", Color("#b9bfa8"))


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

## auto-vault (Dead Cells-like, owner 2026-11-05): in the air, pushing into a rock's side with her feet no more than
## MANTLE px under its top, she hops up over the lip (once per jump) (PLACEHOLDER reach)
const MANTLE := 52.0
const LEDGE_ASSIST := 46.0
var mantled := false
## ledge hang and climb (owner 2026-11-05, generated with 2dimg2motion, no weapons drawn): one strip of 14 frames of
## 448x512 per costume — 0-5 the one-hand hang loop, 6-13 the two-arm climb. In every frame the ledge corner is the
## canvas point (230, 300); per climb frame, how far her feet hang under the lip and her body's centre (canvas px)
## per costume: the strip, which strip frame each of the 8 climb steps shows (climb_02 cut: owner 2026-11-05, it jumps),
## per step how far her feet hang under the lip and her body's centre, where the climb leaves her and the hang's feet / centre
const LEDGE := {
	"estelle_base": {"tex": preload("res://assets/chars/estelle_ledge.png"), "map": [6, 6, 8, 9, 10, 11, 12, 13],
		"feet": [184, 184, 146, 98, 71, 0, 0, 0], "cx": [190, 190, 210, 224, 230, 329, 306, 309], "end": 309.0, "hang": [200.0, 195.0]},
	"estelle_misuk": {"tex": preload("res://assets/chars/estelle_misuk_ledge.png"), "map": [6, 6, 7, 8, 9, 10, 11, 12],
		"feet": [198, 198, 159, 125, 74, 0, 0, 0], "cx": [202, 202, 204, 217, 222, 336, 311, 322], "end": 322.0, "hang": [198.0, 202.0]},
}
const HANG_REACH := [36.0, 150.0]         # world px her feet may be under a lip for her to catch it (PLACEHOLDER)
var ledge_at := Vector2.ZERO              # the corner she holds / climbs over (world)
var ledge_side := 1
var regrab_t := 0.0
var ledge_off := Vector2.ZERO              # a climb picked up mid-jump: the drawing starts where she was and eases in
var ledge_off_t := 1e9
const LEDGE_EASE := 170.0

func has_ledge_art() -> bool:
	return LEDGE.has(SK.worn(who))

func _lk() -> float:
	return 0.5 * CH.SCALE[who]

func _ledge_meta() -> Dictionary:
	return LEDGE.get(SK.worn(who), {})

## catch the lip and hang (the corner at lip_x, `top`; she faces it from `side`)
func _hang_start(top: float, lip_x: float, side: int) -> bool:
	if not has_ledge_art() or regrab_t > 0.0: return false
	var k := _lk()
	var hm: Array = _ledge_meta()["hang"]
	if top + hm[0] * k > arena.ground_y - 4.0: return false          # a low wall: no room to hang, she climbs it
	ledge_at = Vector2(lip_x, top)
	ledge_side = side
	dir = side
	position = Vector2(lip_x - side * (230.0 - hm[1]) * k, top + hm[0] * k)
	vx = 0.0
	vy = 0.0
	on = false
	air = 0
	set_anim("hang", 0)
	arena.sfx("land", 0.3)
	return true

## climb up onto `top` (lip_x = the corner, or NAN in the middle of a ledge): from the hang, or straight from a jump that
## came up a little short (it starts on the frame matching how far below she is); false without the art
func _climb_start(top: float, lip_x: float, side: int, from := -1) -> bool:
	if not has_ledge_art(): return false
	var k := _lk()
	var M := _ledge_meta()
	var st := from
	if st < 0:
		var dyc: float = (position.y - top) / k
		st = 4
		for i in 5:
			if M["feet"][i] <= dyc + 15.0:
				st = i
				break
	var lx: float = lip_x if not is_nan(lip_x) else position.x - side * (float(M["cx"][st]) - 230.0) * k
	ledge_off = Vector2.ZERO
	ledge_off_t = 1e9
	if from < 0:
		# where that frame would draw her feet vs where her feet are now: slide the picture over instead of popping
		var drawn := Vector2(lx + side * (float(M["cx"][st]) - 230.0) * k, top + float(M["feet"][st]) * k)
		ledge_off = position - drawn
		ledge_off_t = 0.0
	ledge_at = Vector2(lx, top)
	ledge_side = side
	dir = side
	position = Vector2(lx + side * (float(M["end"]) - 230.0) * k, top)      # where the climb leaves her standing
	vx = 0.0
	vy = 0.0
	on = true
	air = 0
	mantled = false
	set_anim("climb", st)
	arena.sfx("jump", 0.4)
	return true

## the hang / climb frames, drawn about the corner (not about her feet); the hang sways a little about her hand
func _draw_ledge(c: String, an: String, fr: int, at: Vector2, d: int, col: Color, ci: CanvasItem) -> bool:
	var M: Dictionary = LEDGE.get(SK.worn(c), {})
	if M.is_empty(): return false
	var tex: Texture2D = M["tex"]
	var k: float = 0.5 * CH.SCALE[c]
	var corner: Vector2 = at + (ledge_at - position)
	if an == "climb" and ledge_off_t < LEDGE_EASE:
		var q := ledge_off_t / LEDGE_EASE
		corner += ledge_off * (1.0 - q) * (1.0 - q)
	var i: int = (fr % 6) if an == "hang" else int(M["map"][mini(fr, 7)])
	var rot := 0.0
	if an == "hang": rot = sin(t / 1000.0 * TAU / 1.6) * 0.06 * ledge_side
	ci.draw_set_transform_matrix(Transform2D(0.0, Vector2(d, 1), 0.0, corner) * Transform2D(rot, Vector2(6.0 * k, 0)) * Transform2D(0.0, Vector2(-6.0 * k, 0)))
	ci.draw_texture_rect_region(tex, Rect2(-230.0 * k, -300.0 * k, 448.0 * k, 512.0 * k), Rect2(i * 448, 0, 448, 512), col)
	ci.draw_set_transform(Vector2.ZERO)
	return true

func _mantle(top: float, side: int, lip_x: float) -> void:
	if on or mantled or move_axis() != side or attacking() or a_busy_for_mantle(): return
	var dy := position.y - top
	if dy <= 0.0: return
	if has_ledge_art():
		if dy <= HANG_REACH[0] and _climb_start(top, lip_x, side): return
		if dy <= HANG_REACH[1] and vy > -0.25:
			if _hang_start(top, lip_x, side): return
			_climb_start(top, lip_x, side)
		return
	if dy > MANTLE: return
	mantled = true
	vy = -sqrt(2.0 * GRAV * (dy + 14.0))
	vx = side * 0.12
	set_anim("double_jump")          # the tuck-and-roll reads as a vault over the lip
	arena.sfx("jump", 0.5)
	arena.dust(position, side, false)

func a_busy_for_mantle() -> bool:
	return anim in ["hurt", "death", "dive", "guard", "parry", "tp_in", "dig_out", "dig_in", "mark", "amark"]

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
		elif jump_cut: g *= JUMP_CUT_G
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
				_mantle(so.top, 1, so.x)
			elif prev_x >= so.x + so.w + 12.0:
				position.x = so.x + so.w + 12.0
				_mantle(so.top, -1, so.x + so.w)
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
	# ledge assist (Dead Cells-like, owner 2026-11-05): coming up under a ledge, if the jump would top out with her feet
	# a little short of its lip, it gets a smooth lift that carries her just over it (once per jump; not holding down,
	# not dropping through) — no snap
	# catching a ledge's end from beside it (it has no side to push into): falling past its corner, pushing toward it
	if not landed and not on and has_ledge_art() and regrab_t <= 0.0 and vy > -0.25 and drop_t <= 0.0 and not keys["down"] and not attacking() and not (a in ["dive", "hurt", "death"]):
		var mvg := move_axis()
		for pl in arena.platforms:
			var dyg: float = position.y - pl.y
			if dyg < HANG_REACH[0] or dyg > HANG_REACH[1]: continue
			if mvg == 1 and position.x > pl.x - 30.0 and position.x < pl.x - 2.0:
				if _hang_start(pl.y, pl.x, 1):
					return
			elif mvg == -1 and position.x > pl.x + pl.w + 2.0 and position.x < pl.x + pl.w + 30.0:
				if _hang_start(pl.y, pl.x + pl.w, -1):
					return
	if not landed and not on and not mantled and drop_t <= 0.0 and not keys["down"] and not (a in ["dive", "hurt", "death"]):
		for pl in arena.platforms:
			var dy: float = position.y - pl.y
			if dy <= 0.0 or dy > 110.0 or position.x < pl.x + 6.0 or position.x > pl.x + pl.w - 6.0: continue
			var reach: float = vy * vy / (2.0 * GRAV) if vy < 0.0 else 0.0
			var short: float = dy - reach
			if short > 0.0 and short <= LEDGE_ASSIST and (vy > -0.3 or dy < 60.0):
				if not attacking() and _climb_start(pl.y, NAN, dir):
					landed = true
					break
				mantled = true
				vy = -sqrt(2.0 * GRAV * (dy + 12.0))
				if not attacking() and anim in ["jump", "runjump"]:
					set_anim("double_jump")          # a tuck up over the lip instead of a bare float
					arena.sfx("jump", 0.4)
				break
	if landed and not on:
		on = true
		vy = 0.0
		air = 0
		mantled = false
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
		if who == "kenin" and k_rep > 0 and CH.KATK.has(anim) and CH.KATK[anim]["fire"].has(f - 1):
			# the burst's next round: back to the frame before the shot, briefly, and fire again (one kick per round)
			f = maxi(0, f - 2)
			ft = maxf(0.0, dur() - K_REWIND)
			hit_done = false
			continue
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
			elif n == "bomb":
				if on: set_anim("kneel" if keys["down"] else "idle")
				else:
					anim = "jump"
					f = 4
			elif n in ["stop", "hurt", "attack1", "attack2", "attack3", "attack_high", "parry", "cthrust", "lfinisher", "heal", "kfire", "kdry"]:
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
			elif n == "climb":
				on = true
				set_anim("idle")
			elif n == "hang":
				f = 0
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
		if anim == "attack1" and f == 2 and keys["attack"] and on and who == "kenin":
			set_anim("kcharge", 0)
			charge_t = 110.0
			cfull = false
			break
		if anim == "attack1" and f == 2 and keys["attack"] and on and who == "aida" and aida_emp_target() != null:
			aida_exec(aida_emp_target(), 1.0)          # 무방비 ahead: no gathering, the 처형 at once
			break
		if anim == "attack1" and f == 2 and keys["attack"] and on and who != "kenin":
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
	if who == "kenin" and anim == "dash": return f <= 6           # the roll is invincible until it uncurls
	return (anim == "dash" and f <= 2) or (anim == "airdash" and f <= 3) or anim == "tp_in" or anim == "dig_in" or (anim == "dig_out" and f <= 1) or anim == "swap_in"

func take_hit(m, raw: float) -> String:
	if inv > 0.0 or dash_inv() or anim == "death" or hp <= 0.0:
		return "miss"
	var facing: bool = (m.position.x - position.x) * dir > 0.0
	var mg: String = arena.runes.memory.guard_hit(m, facing) if _rk() else ""   # 성소 / 의족을 박고 (memory nodes)
	if mg == "miss": return "miss"
	raw *= arena.taken_mul(m)                              # the mob's attack element against her own (hurtAmt)
	if e_guard_t > 0.0 and who != "estelle":
		return _e_cover(m)
	var auto: bool = (who == "estelle" and arena.auto_parry() > 0.0) or mg == "gp"   # 수호의 맹세: every blow is parried
	var pw := 1 + ST.parry_extra(m)                        # 둔화: a frame more to parry a slowed foe
	if auto and not (anim == "parry" and f <= pw and facing):
		dir = 1 if m.position.x > position.x else -1
		set_anim("parry")
		facing = true
	if who == "estelle" and anim == "parry" and f <= pw and facing:
		var pp: bool = m.get("flared") == true
		if auto and mg != "gp": arena.ult.rose_burst(position + Vector2(dir * 34.0 * CSCALE, -62.0 * CSCALE))
		bash_t = 420.0
		f = 2
		ft = 0.0
		position.x += dir * 16.0
		arena.parry_fx(self, m)
		m.hit(BAL.p("estelle", "parry_bash"), dir * 8, atk_mul())
		estg(m, E_STG["pparry"] if pp else E_STG["parry"])
		if pp and _ev("pparryAoe") > 0.0:
			# 방패 밀치기: a perfect parry shakes everyone near
			for e2 in foes_alive():
				if e2 != m and absf(e2.position.x - position.x) < 260.0 and absf(e2.position.y - position.y) < 160.0: estg(e2, _ev("pparryAoe"))
			arena.post_wave(position + Vector2(0, -60.0), 1.0, 420.0, 0.3)
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
		var tk0 := raw * 0.5 * 0.75 * _inm()
		var tk := ST.absorb(self, tk0)      # 보호막 first
		hp -= tk
		# Estelle renewal: a block builds 경직, and 30% of what she took becomes a shield (handed on with a swap)
		estg(m, E_STG["guard"])
		ST.ally_add(self, "shield", tk0 * 0.3 * (1.0 + _ev("eShieldK")))
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
		qte_offer("parry")          # owner 2026-11-04: Estelle's guard counts as a parry for the QTEs
		arena.ult_gain(5.0)
		if hp <= 0.0: die()
		return "guard"
	var tk2 := ST.absorb(self, raw * (0.75 if who == "estelle" else 1.0) * _inm())    # Estelle's passive: 25% less damage taken; 보호막 first
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
		bounce_t = 0.0
		set_anim("hurt")
	return "hit"

## every joined member off the field back to full HP (the fallen stand up again); returns who was hurt or down
func revive_fallen() -> Array:
	var up: Array = []
	for c in roster():
		if c != who and hpm.has(c) and hpm[c] < _mhp(c):
			hpm[c] = _mhp(c)
			up.append(c)
	return up

func die() -> void:
	hp = 0.0
	set_anim("death")
	dead_t = 0.0
	arena.sfx("jingle_death", 1.0)
	arena.sfx("down", 0.8)                  # the body hits the ground (owner 2026-11-04: no scream)
	if arena.bgm != null and arena.bgm.grid() != null: arena.bgm.duck(6.0, 600.0)


# ---------- party: switching, QTE tag-in, counter swap ----------
func party_step(dt: float) -> void:
	ST.ally_step(self, dt)
	if l_bless_t > 0.0: l_bless_t -= dt
	if l_bolt_cd > 0.0: l_bolt_cd -= dt
	if a_exec_cd > 0.0: a_exec_cd -= dt
	if not a_left.is_empty():
		a_left["t"] = float(a_left["t"]) - dt
		if float(a_left["t"]) <= 0.0:
			var at := Vector2(a_left["x"], a_left["y"])
			if a_left.get("g") != null: a_left["g"]["rel"] = true
			a_left = {}
			var up = arena.pfx.gate(at.x, at.y, 200.0 * CSCALE, 1.8, 1.3)      # the burst: a tall tear snaps open and shut
			up["rel"] = true
			arena.slash_fx(at + Vector2(0, -70.0 * CSCALE), 100.0 * CSCALE, deg_to_rad(100.0), deg_to_rad(-80.0), 1, Color("#d7b8ff"), 1.3)
			arena.spark(at + Vector2(0, -60.0 * CSCALE), 16)
			arena.hit_by = "aida"
			var ak: float = CH.STATS["aida"]["atk"] * (arena.runes.atk_k("aida") if _rk() else 1.0)
			for e in foes_alive():
				if absf(e.position.x - at.x) < 150.0 and absf(e.position.y - at.y) < 120.0:
					e.hit(1.0, 0.0, ak)
					ST.add(arena, e, "air", -1.0, "aida")
			arena.hit_by = ""
			arena.post_wave(at + Vector2(0, -40.0), 1.0, 480.0, 0.25)
			arena.sfx("aida_close", 0.9)
			arena.dust(at, 0, true)
	if e_guard_t > 0.0: e_guard_t -= dt
	if not e_assist.is_empty():
		e_assist["t"] = float(e_assist["t"]) + dt
		if float(e_assist["t"]) > maxf(_ev("eStay"), 700.0) + 250.0: e_assist = {}                      # 강화 · 재생 clocks (재생 heals the bench too)
	if swap_cd > 0.0: swap_cd -= dt
	if party_lock > 0.0: party_lock -= dt
	if qte_gap > 0.0: qte_gap -= dt
	if not qte_pend.is_empty():
		qte_pend["t"] = float(qte_pend["t"]) - dt
		if qte_gap <= 0.0:
			var r: String = qte_pend["r"]
			qte_pend = {}
			qte_offer(r)
		elif float(qte_pend["t"]) <= 0.0:
			qte_pend = {}
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
	# back in town or the guild hall: everyone is healed, and members who fell in the cave stand up again
	if arena.level_kind() in ["town", "hall"]:
		revive_fallen()
		if hp > 0.0 and hp < MAX_HP and anim != "death":
			hp = MAX_HP
			last_hp = hp
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
	if slot_req >= 0:
		var si := slot_req
		slot_req = -1
		if Time.get_ticks_msec() - slot_req_t < 250 and si < party.size() and party[si] != who and arena.forced_keys() == null:
			party_input(party[si])
	if tag_timer > 0.0:
		tag_timer -= dt
		if tag_timer <= 0.0 and not tag_hit:
			tag_hit = true
			tag_strike()

## ROSTER: the members who have joined the guild (fame.rec), plus whoever is in control, in the prototype's order
func roster() -> Array:
	var F = arena.get("fame") if arena != null else null
	return ["estelle", "aida", "luce", "kenin"].filter(func(c): return c == who or party.has(c) or F == null or F.recruited(c))

func party_next():
	var al: Array = party.filter(func(c): return c == who or hpm[c] > 0.0)
	if al.size() < 2:
		return null
	return al[(al.find(who) + 1) % al.size()]

## the swap key / a portrait tap: during a QTE it becomes a tag-in strike; on a glinting attack it is a counter swap
func party_input(to = null) -> void:
	if anim in ["tag_in", "swap_in"] or party_lock > 0.0:
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
			if stays(nx): counter_assist(m, nx)
			else: counter_swap(m, nx)
			return
	if qte["t"] > 0.0:
		# the swap key tags in whoever has the chance; a tapped portrait tags in only if that face has it
		var c = (to if qte["who"].has(to) else null) if to != null else _qte_member()
		if c != null:
			if stays(c): bench_assist(c, null)
			else: swap(true, c)
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
	party_lock = LOCK_TAG if tag else LOCK_SWAP
	if tag: qte_gap = QTE_GAP
	hpm[old] = maxf(0.0, hp)
	var was_dead := anim == "death"
	outs.append({"c": old, "anim": "death" if was_dead else "tag_out", "x": position.x, "y": position.y, "dir": dir, "t": 0.0, "dead": was_dead})
	if old == "luce" and not was_dead:
		# Luce renewal: leaving, she hands the one coming in 강화 (축복 nodes: stronger, longer, 기력)
		ST.ally_add(self, "buff", L_BUFF + _lv("buffK"), L_BUFF_MS + _lv("buffMs"))
		if _lv("buffUlt") > 0.0 and arena.get("ult") != null: arena.ult.v[nx] = minf(arena.ult.ULTMAX[nx], arena.ult.v[nx] + _lv("buffUlt"))
	if old == "aida" and not was_dead:
		a_left = {"x": position.x, "y": position.y, "t": 1000.0, "g": arena.pfx.gate(position.x, position.y, 120.0 * CSCALE, 1.2, 0.8)}       # 남은 균열: her own rift gate, bursts in 1 s
		a_follow = {}
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
	tag_src = String(qte.get("src", "")) if tag else ""
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
		if nx == "luce":
			ST.ally_add(self, "shield", _mhp(old) * 0.2)          # 구원: a shield for the one leaving (it stays with the party)
			bless_start()
		if nx == "luce" and q_low:
			var sv := roundf(luce_heal("save_heal"))
			hpm[old] = minf(_mhp(old), hpm[old] + sv)
			arena.text(position + Vector2(0, -175.0 * CSCALE), "구원! " + CH.NAME[old] + " +%d" % int(sv), Color("#fff1b0"))
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
		if not cp_quiet: arena.text(position + Vector2(0, -150.0 * CSCALE), "TAG!  " + CH.NAME[nx], Color("#ffe39a"))
	else:
		swap_cd = 2200.0 * _mk("swap")
		if on:
			swap_to = keep_x
			position.x = clampf(keep_x - keep_dir * 170.0, 30.0, arena.world_w - 30.0)
			set_anim("swap_in")
		# a plain swap-in: the statuses on the foe ahead react at half strength
		var sw = target(260.0)
		if sw != null: ST.tag_react(arena, sw, false)
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
		var tm := ST.tag_mul(R0)                 # 취약: the tag-in blow lands as a sure crit
		if tag_src == "estelle" and who != "estelle": tm *= 1.0 + _ev("eTagK")      # 등을 맡긴다
		if tm > 1.0: arena.text(R0.position + Vector2(0, -200), "치명!", Color("#ff8a5a"))
		R0.hit(BAL.p(who, "tag") * M * tm, dir * 8.0, atk_mul())
		ST.tag_react(arena, R0, true)            # QTE tag-in: the statuses on it react, full strength
		if who == "estelle": estg(R0, E_STG["tag"])
		if R0.get("daze") != null: R0.daze = maxf(R0.daze, 500.0)     # the training ghost loses her for a moment
	arena.hitstop = 120.0        # QA: the tag-in blow holds a beat
	arena.shake(7, dir)
	arena.post_wave(position + Vector2(dir * 60.0, -50.0), 1.1, 460.0, 0.22)
	arena.streak_fx(position.x - dir * 30.0, position.x + dir * 170.0, position.y - 50.0 * CSCALE, dir, CH.COLOR[who])
	arena.dust(position, dir, true)
	for d in foes_alive():
		if d != R0 and (d.position.x - position.x) * dir > -30.0 and absf(d.position.x - position.x) < 200.0 and absf(d.position.y - position.y) < 60.0:
			d.hit(BAL.p(who, "tag"), dir * 8, atk_mul())

## a QTE answered from the bench (Kenin): he appears, shoots and is gone; the one in control stays, and her swap is ready
func bench_assist(c: String, tg) -> void:
	if c == "kenin": arena.kenin.assist(tg if tg != null else qte_target())
	if c == "estelle": _e_assist(tg if tg != null else qte_target(), qte["hit"])
	qte_end()
	swap_cd = 0.0
	party_lock = maxf(LOCK_ASSIST, arena.kenin.assist_total() + 250.0) if c == "kenin" else LOCK_ASSIST
	qte_gap = QTE_GAP
	_rev("tag")
	arena.flash = maxf(arena.flash, 0.12)
	arena.text(position + Vector2(0, -150.0 * CSCALE), ("원호 방어!  " if c == "estelle" else "원호!  ") + CH.NAME[c], CH.COLOR[c].lightened(0.4))

## members whose QTE is answered from the bench without a swap: Kenin always, Estelle with 용감한 희생
func stays(c: String) -> bool:
	return CH.QTE_STAY.has(c) or (c == "estelle" and _ev("eStay") > 0.0)

## 용감한 희생: Estelle leaps in front of the one in control — what they just took comes back as a shield, a parry
## counter and 경직 on the foe ahead, then for 2 s she takes the next blow meant for them (that block is a parry too)
func _e_assist(tg, q_hit) -> void:
	var sh: float = float(q_hit["taken"]) if q_hit != null else MAX_HP * 0.15
	ST.ally_add(self, "shield", sh)
	e_guard_t = _ev("eStay")
	e_assist = {"t": 0.0, "x": position.x + dir * 46.0 * CSCALE, "y": position.y, "dir": dir}
	if tg != null and is_instance_valid(tg) and tg.alive():
		arena.hit_by = "estelle"
		tg.hit(BAL.p("estelle", "parry_bash"), dir * 8.0, CH.STATS["estelle"]["atk"] * (arena.runes.atk_k("estelle") if _rk() else 1.0))
		arena.hit_by = ""
		estg(tg, E_STG["assist"])
	arena.sfx("parry", 0.9)
	arena.sfx("guard", 0.7)
	arena.spark(position + Vector2(dir * 50.0 * CSCALE, -60.0 * CSCALE), 10)

## the covering guard takes the blow: no damage, a parry counter, 경직, and a parry for the QTEs
func _e_cover(m) -> String:
	e_guard_t = 0.0
	arena.parry_fx(self, m)
	m.hit(BAL.p("estelle", "parry_bash"), dir * 8, CH.STATS["estelle"]["atk"] * (arena.runes.atk_k("estelle") if _rk() else 1.0))
	estg(m, E_STG["parry"])
	arena.text(position + Vector2(0, -150.0 * CSCALE), "막았다!", Color("#ffd3ea"))
	inv = maxf(inv, 450.0)
	qte_offer("parry")
	return "parry"

func qte_target():
	return target(1100.0)

## a glinting attack answered from the bench: the attack is cancelled as in a counter swap, the shot does the rest
func counter_assist(m, c: String) -> void:
	m.st = "hurt"
	m.hurt_t = 1300.0
	m.flared = false
	m.flare_t = -1.0
	m.atk_clock = 0.0
	m.set_a("hurt")
	m.cd = maxf(m.cd, 1600.0)
	arena.proj = arena.proj.filter(func(p): return p["m"] != m or absf(p["x"] - position.x) > 500.0)
	bench_assist(c, m)
	arena.hitstop = maxf(arena.hitstop, 150.0)
	arena.sfx("parry", 1.0, {"st": 7.0})
	arena.text(Vector2(m.position.x, m.position.y - 190.0), "PARRY!", Color("#ffffff"))
	arena.parry_word()

## 교대 패링 (owner 2026-11-05, after 젠존제's defensive assist): two beats. The newcomer slides in trailing ghosts and
## CATCHES the glinting blow in a guard pose (the clash: the longest freeze, the gold arcs, sparks, the negative frame,
## the zoom punch); then both are thrown apart — the foe reels back on its heels (kx + tilt), she slides a step and
## braces. A press of attack inside the window after it is the follow-up: her tag-in strike at x2.5. No press: she
## just stands, the next member's QTE is open (교대 → 교대). Poses from existing art (CP_POSE); mobs get no new art.
const CP_IN := 120.0          # ms: the slide in
const CP_WIN := 1000.0        # ms: the follow-up window closes
const CP_POSE := {            # [in, clash, after] per member: [anim, frame]. She DEFLECTS: a low lunge in, the rising cut
	# knocks the blade up, the follow-through held as she is shoved. Non-Estelle poses are PLACEHOLDER tag_in frames
	"estelle": [["dash", 2], ["attack2", 2], ["attack2", 3]], "aida": [["dash", 2], ["tag_in", 2], ["tag_in", 3]],
	"luce": [["dash", 2], ["tag_in", 2], ["tag_in", 3]], "kenin": [["dash", 2], ["tag_in", 2], ["tag_in", 3]]}

func counter_swap(m, nx: String) -> void:
	# its swing hangs where it is (아슬아슬: the blade is already coming down) until her blade meets it at the clash
	m.hold_t = CP_IN + 400.0
	m.flared = false
	m.flare_t = -1.0
	arena.proj = arena.proj.filter(func(p): return p["m"] != m or absf(p["x"] - position.x) > 500.0)
	qte["who"] = [nx]
	qte["t"] = maxf(qte["t"], 1.0)
	qte["hit"] = null
	qte["low"] = false
	cp_quiet = true
	swap(true, nx)
	cp_quiet = false
	# her own staging over swap()'s tag-in: she comes in from behind her old spot and stops at the foe's reach
	var fly: bool = is_fly(m)
	dir = 1 if m.position.x >= position.x else -1
	var to := clampf(m.position.x - dir * 66.0 * CSCALE, 30.0, arena.world_w - 30.0)
	position.x = clampf(to - dir * 190.0, 30.0, arena.world_w - 30.0)
	if fly:
		air_tag = true
		air_y = minf(arena.ground_y - 60.0, m.position.y + 30.0)
		position.y = air_y
		on = false
	else:
		air_tag = false
		position.y = m.position.y
		on = true
	vy = 0.0
	vx = 0.0
	tag_ref = m
	tag_to = to
	tag_hit = true
	tag_timer = 0.0
	tag_mul = 1.0
	cam_focus = {"x": (to + m.position.x) / 2.0, "t": 1200.0}
	m.kx = 0.0
	cp = {"m": m, "t": 0.0, "to": to, "hit": false, "fu": false}
	_cp_pose(0)
	inv = maxf(inv, 1400.0)
	party_lock = maxf(party_lock, CP_WIN + 150.0)
	add_ghost(160.0)
	arena.sfx("dash", 0.7)

func _cp_pose(i: int) -> void:
	var ps: Array = CP_POSE.get(who, CP_POSE["aida"])[i]
	var an: String = ps[0]
	if air_tag and who == "estelle" and i > 0: an = "air_parry"
	if anim != an or f != int(ps[1]): set_anim(an, int(ps[1]))

func _cp_step(dt: float) -> void:
	var m = cp["m"]
	var live: bool = m != null and is_instance_valid(m) and m.alive()
	var t0: float = cp["t"]
	cp["t"] = t0 + dt
	var tt: float = cp["t"]
	var to: float = cp["to"]
	vx = 0.0
	vy = 0.0
	if air_tag:
		position.y = air_y
		on = false
	# beat 1: in
	if tt < CP_IN:
		position.x += (to - position.x) * minf(1.0, dt / 40.0)
		if int(tt / 30.0) != int(t0 / 30.0): add_ghost(140.0)
		_cp_pose(0)
		return
	# the clash
	if not cp["hit"]:
		cp["hit"] = true
		position.x = to
		_cp_pose(1)
		var cpt := Vector2(position.x + dir * 44.0 * CSCALE, position.y - 72.0 * CSCALE)
		if live:
			var fp: Vector2 = m.flare_pos()
			if fp.is_finite(): cpt = Vector2((cpt.x + fp.x) / 2.0, (cpt.y + fp.y) / 2.0)
			m.hold_t = 0.0
			m.st = "hurt"
			m.atk_clock = 0.0
			m.set_a("hurt")
			m.cd = maxf(m.cd, 1800.0)
			m.kx = dir * 3.2                         # its blade knocked up, thrown back on its heels
			m.tilt = dir * 0.3
			m.hurt_t = maxf(m.hurt_t, 1100.0)
			if m.get("daze") != null: m.daze = maxf(m.daze, 600.0)
			if who == "estelle": estg(m, E_STG["parry"])
			elif ST.big(m): ST.add(arena, m, "stagger", 35.0, who)       # a boss: the groggy gauge takes the clash (PLACEHOLDER)
		arena.slash_fx(Vector2(position.x + dir * 36.0 * CSCALE, position.y - 70.0 * CSCALE), 115.0 * CSCALE, deg_to_rad(70.0), deg_to_rad(-110.0), dir, Color("#fff1b0"), 1.4)
		arena.hitstop = maxf(arena.hitstop, 230.0)
		arena.flash = maxf(arena.flash, 0.5)
		arena.shake(11, dir)
		arena.impact("parry", cpt, dir)
		arena.pfx.parry_at(cpt, dir)
		arena.spark(cpt, 18)
		arena.spark_ring(cpt, 8)
		arena.post_wave(cpt, 1.8, 700.0, 0.35)
		arena.post_ca(0.014)
		arena.witch = maxf(arena.witch, 320.0)
		arena.witch_max = maxf(arena.witch_max, 320.0)
		arena.sfx("parry", 1.0, {"st": 7.0})
		arena.sfx("slam", 0.8)
		arena.text(Vector2(to, position.y - 190.0 * CSCALE), "PARRY!", Color("#ffffff"))
		arena.parry_word()
		qte_offer("parry")          # 교대 패링 is a parry: the next member's QTE opens after the gap (교대 → 교대)
		return
	# beat 2: thrown apart — one hard shove back (fast, easing out, feet skidding) and she braces where it leaves her
	var rt := tt - CP_IN
	var r0 := t0 - CP_IN
	if rt < 90.0:
		var k1 := 1.0 - pow(1.0 - clampf(rt / 90.0, 0.0, 1.0), 3.0)
		var k0 := 1.0 - pow(1.0 - clampf(r0 / 90.0, 0.0, 1.0), 3.0)
		position.x -= dir * 18.0 * CSCALE * (k1 - k0)
		ax_rot = -dir * 0.1 * (1.0 - k1)                 # knocked back on her heels, straightening as she stops
		if r0 <= 0.0:
			arena.dust(position, -dir, true)
			add_ghost(120.0)
		elif int(rt / 30.0) != int(r0 / 30.0): arena.dust(position, -dir, false)
	else: ax_rot = 0.0
	_cp_pose(2 if rt > 60.0 else 1)
	# the follow-up window: her tag-in strike, x2.5
	if rt > 200.0 and want("attack") and live:
		take("attack")
		cp = {}
		ax_rot = 0.0
		tag_mul = maxf(tag_mul, 2.5)
		var here := position.x
		tag_in_at(m, position.x)
		position.x = here                                   # the strike launches from where the shove left her, no re-entry
		arena.text(position + Vector2(0, -175.0 * CSCALE), "추격!", Color("#ffe39a"))
		return
	if rt > CP_WIN - CP_IN or not live:
		cp = {}
		ax_rot = 0.0
		set_anim("idle")
		if air_tag:
			air_tag = false
			on = false

func qte_offer(reason: String, data = null) -> void:
	var cands: Array = CH.QTE_WHO.get(reason, []).filter(func(c): return party.has(c) and c != who and hpm[c] > 0.0)
	if cands.is_empty():
		return
	if qte_gap > 0.0:
		# 교대 → 교대: a parry in the gap (a swap that caught a glint) opens its QTE when the gap ends
		if reason == "parry": qte_pend = {"r": "parry", "t": QTE_GAP + 1200.0}
		return
	if qte["t"] <= 0.0:
		if qte["cd"] > 0.0 and reason != "hit" and reason != "parry":     # a parry is earned: no cooldown
			return
		qte["who"] = []
		qte["hit"] = null
		qte["low"] = false
	for c in cands:
		if not qte["who"].has(c): qte["who"].append(c)
	qte["src"] = who
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
	# Aida: the 무방비 foe ahead wears her sigil (the next strike goes out empowered); her 남은 균열 pulses where she left
	if who == "aida" and anim != "death":
		var et = aida_emp_target()
		if et != null:
			var pc: Vector2 = et.position - position + Vector2(0, -150.0)
			var pu := 0.6 + 0.4 * sin(t / 90.0)
			var dm := PackedVector2Array([pc + Vector2(0, -11), pc + Vector2(8, 0), pc + Vector2(0, 11), pc + Vector2(-8, 0)])
			draw_colored_polygon(dm, Color(0.69, 0.42, 1.0, 0.85 * pu))
			draw_polyline(dm + PackedVector2Array([dm[0]]), Color(0.95, 0.9, 1.0, pu), 1.5)
			draw_circle(Vector2(dir * 30.0 * CSCALE, -40.0 * CSCALE), 5.0 * pu, Color(0.8, 0.6, 1.0, 0.7))
	# 용감한 희생: Estelle's shield up in front of the one in control while her covering guard lasts
	if not e_assist.is_empty():
		var et: float = e_assist["t"]
		var ea := minf(1.0, minf(et / 120.0, (maxf(_ev("eStay"), 700.0) + 250.0 - et) / 250.0))
		draw_frame("estelle", "guard", 1, Vector2(e_assist["x"], e_assist["y"]) - position, e_assist["dir"], Color(1, 1, 1, ea), "", null, NAN, 0, "eassist")
	# Kenin's covering shot from the bench (kenin.gd assists): rolls in, uncurls, aims, fires, fades out
	if arena.kenin != null:
		var tot: float = arena.kenin.assist_total()
		for a in arena.kenin.assists:
			var at: float = a["t"]
			var al := minf(1.0, minf(at / 120.0, (tot - at) / 160.0))
			var ps: Array = arena.kenin.assist_pose(a)
			draw_frame("kenin", ps[0], ps[1], Vector2(ps[2], a["y"]) - position, a["dir"], Color(1, 1, 1, al), "", null, NAN, 0, "assist", -1.0, al >= 1.0)
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
	if inv > 0.0 and anim != "hurt" and anim != "tag_in" and a_exec.is_empty() and int(t / 60.0) % 2 == 0 and not arena.ult_busy(): return
	var col := Color.WHITE
	if anim == "hurt" and ft < 60.0: col.g = 3.0         # the hurt flash: white over the frame (char_pix flag 1)
	col.a *= arena.ult_alpha()
	var variant := ""
	if anim == "tp_in" or anim == "dig_out":
		variant = "_air" if dig_air else ("_q" if rift_q else "")
	if not anim in ["tp_in", "dig_out"] and (gclip != null or gdx != 0.0 or g_in != null or g_out != null): _rift_clean()
	var br := t if anim == "idle" and not arena.ult_busy() else -1.0
	var rim := col.a >= 1.0
	if not ax_portals.is_empty(): _ax_draw_portals(false)
	if gclip != null: draw_frame(who, an, fr2, Vector2(gdx, 0), dir, col, variant, null, gclip["x"] - position.x, gclip["keep"], "P", br, rim)
	else: draw_frame(who, an, fr2, Vector2(gdx, 0), dir, col, variant, null, NAN, 0, "P", br, rim)
	if not ax_portals.is_empty(): _ax_draw_portals(true)

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
	if an == "climb" or an == "hang":
		if not _draw_ledge(c, an, fr, at, d, col, ci): draw_frame(c, "double_jump", mini(fr, 5), at, d, col, variant, ci)
		return
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
	var rr: float = ax_rot if sk == "P" else 0.0       # 처형's tilt (rotated frames skip the pixel slot)
	var pix := sk != "" and is_pix(ci.material) and col.g < 4.0 and rr == 0.0
	if pix:
		var wa: Vector2 = ci.get_global_transform() * at
		var si := pix_slot(sk, c, row, rf[1], wa, d, sc, bands, rim)
		if si >= 0: col.b += 4.0 * (si + 1)
	var mode0: bool = pix_mat().get_shader_parameter("mode") == 0
	if rr != 0.0:
		var pv := 90.0 * sc                              # about her middle, not her feet
		ci.draw_set_transform_matrix(Transform2D(rr * d, at + Vector2(0, -pv)) * Transform2D(0.0, Vector2(d, 1), 0.0, Vector2(0, pv)))
	else: ci.draw_set_transform(at, 0.0, Vector2(d, 1))
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

## Estelle's memory node value (her tree, whoever is in control)
func _ev(key: String) -> float:
	return arena.runes.memory.val("estelle", key) if _rk() else 0.0

## Aida's memory node value / product (her tree)
func _av(key: String) -> float:
	return arena.runes.memory.val("aida", key) if _rk() else 0.0

func _am(key: String) -> float:
	return arena.runes.memory.mul("aida", key) if _rk() else 1.0

## Luce's memory node value / product (her tree)
func _lv(key: String) -> float:
	return arena.runes.memory.val("luce", key) if _rk() else 0.0

func _lm(key: String) -> float:
	return arena.runes.memory.mul("luce", key) if _rk() else 1.0

## Luce renewal (owner 2026-11-04, 필드 밖 딜포터): her prayer lays 빛의 가호 on the party for 12 s; while it lasts a
## hit by the one in control draws a holy bolt from her on the bench (60% of her attack, at most every 0.5 s) and
## heals the party a little. Numbers PLACEHOLDER.
const L_BLESS := 12000.0
const L_BOLT_GAP := 500.0
const L_VOLLEY := 3
const L_BUFF := 0.15
const L_BUFF_MS := 8000.0

func bless_start() -> void:
	l_bless_t = L_BLESS + _lv("blessT")
	arena.text(position + Vector2(0, -175.0 * CSCALE), "빛의 가호", Color("#fff1b0"))

func bless_proc(e) -> void:
	if l_bless_t <= 0.0 or l_bolt_cd > 0.0 or who == "luce" or not party.has("luce") or hpm.get("luce", 0.0) <= 0.0: return
	if e == null or not is_instance_valid(e) or not e.alive(): return
	l_bolt_cd = L_BOLT_GAP * _lm("boltGap")
	var lk: float = CH.STATS["luce"]["atk"] * (arena.runes.atk_k("luce") if _rk() else 1.0)
	# 와바박 (owner 2026-11-04): a volley, not one bolt: 3 in quick succession (강림: 5), fanned out behind her spot.
	# bless_bolt is the volley's total before the volley bonus (x1.25), split across the bolts. PLACEHOLDER
	var n := L_VOLLEY + (2 if _lv("bolt2") > 0.0 else 0)
	var dmg: float = BAL.p("luce", "bless_bolt") * _lm("boltK") * 1.25 / float(L_VOLLEY)
	for i in n:
		var a := -0.9 + 1.8 * float(i) / maxf(1.0, n - 1.0)
		var o := position + Vector2(-dir * (26.0 + cos(a) * 30.0), -150.0 * CSCALE + sin(a) * 40.0)
		arena.bolt_as(o, e, "luce", dmg, lk, 50.0 + i * 55.0)
	if _lv("boltSlow") > 0.0: ST.add(arena, e, "slow", _lv("boltSlow"), "luce")      # 빛의 사슬
	var hv := luce_heal("bless_heal") * _lm("boltHeal")
	if hp > 0.0: hp = minf(MAX_HP, hp + hv)
	for c in party:
		if c != who and hpm[c] > 0.0: hpm[c] = minf(_mhp(c), hpm[c] + hv)

## Aida renewal (owner 2026-11-04): 빈틈 처형형. The nearest 무방비 foe ahead within the rift strike's full reach —
## against it the strike needs no gathering and goes out empowered (instant, full power, the bigger effect)
func aida_emp_target():
	var R := 420.0 * CSCALE
	var best = null
	var bdx := INF
	for m in foes_alive():
		var dx: float = (m.position.x - position.x) * dir
		if dx > -10.0 and dx < R and absf(m.position.y - position.y) < 260.0 and dx < bdx and ST.exposed(m) and (a_exec_cd <= 0.0 or ax_free(m)):
			bdx = dx
			best = m
	return best

## 처형 (owner 2026-11-04): three beats. In · out: she sinks through a portal opened on the floor and comes up out of
## another under the foe, swinging up (30%). The float: she shoots up, slowing into the top, tosses the shovel and
## catches it as she tilts clockwise. Catch · spin · slam: overhead, one forward somersault, then down faster and faster
## into the floor (70%). Frames: rows 30-33 (ax_*, tools/sprite_flow/pack_aida_exec.py); the height is hers in game.
const AX_SEQ := ["ax_sink", "ax_rise", "ax_spin", "ax_slam"]
const AX_TOP := {"ax_sink": [127, 69, 31, 25, 25, 92], "ax_rise": [176, 205, 265, 236, 209, 226, 214, 209], "ax_spin": [163, 182, 156, 169, 177, 204, 215], "ax_slam": [162, 164, 163, 139, 118, 108, 162]}
const AX_HIT1 := ["ax_rise", 0]
const AX_HIT2 := ["ax_slam", 3]
const AX_H := 150.0          # how high she flies (world px before CSCALE)
const AX_CD := 6000.0        # 처형's cooldown alone (ms). PLACEHOLDER
const AX_FOLLOW := 900.0     # the window after 3타 to press for it (ms)

## a foe the party left 무방비 (경직 · 그로기: other members' work, not her own 띄움): 처형 on it ignores the cooldown
func ax_free(e) -> bool:
	return e != null and is_instance_valid(e) and (ST.has(e, "stagger") or ST.groggy_on(e))
var ax_rot := 0.0            # the sprite's clockwise tilt (rad) while she floats
const AX_FP_BACK := preload("res://assets/fx/aida_fportal_back.png")
const AX_FP_FRONT := preload("res://assets/fx/aida_fportal_front.png")
var ax_portals: Array = []   # [{x, y, t, life, r}] the floor portals, drawn flat (the z axis) around her

func aida_exec(tg, k := 1.0) -> void:
	if tg == null or not is_instance_valid(tg) or not tg.alive(): return
	var g0: float = position.y
	if ST.has(tg, "air"): g0 = float(ST.of(tg)["air"]["y0"])
	elif not is_fly(tg): g0 = tg.position.y
	a_exec = {"tg": tg, "t": 0.0, "k": k, "x": tg.position.x, "g0": g0, "hit1": false, "hit2": false, "exp": ST.exposed(tg), "out": false}
	if not ax_free(tg) and k >= 1.0: a_exec_cd = AX_CD         # the chain (기습의 문, k < 1) and party openings cost nothing
	dir = 1 if tg.position.x >= position.x else -1
	a_follow = {}
	vx = 0.0
	vy = 0.0
	inv = maxf(inv, 1300.0)
	set_anim("ax_sink", 0)
	z_index = 2          # in front of the foe she carries
	ax_portals = [{"x": position.x, "y": position.y, "t": 0.0, "life": 300.0, "r": 64.0 * CSCALE}]
	arena.sfx("aida_open", 1.0)
	arena.post_ca(0.02)

## 처형 is paid for (owner 2026-11-04): it needs its condition and takes about a second, so it hits that hard
func _aexec_dmg(key: String) -> float:
	return BAL.p("aida", key) * _am("riftK") * float(a_exec["k"])

## the frame of the 처형 sequence at time tt: [anim, frame] or [] once over
func _ax_at(tt: float) -> Array:
	var acc := 0.0
	for an in AX_SEQ:
		var T: Array = SK.entry(who, an)[1]
		for i in T.size():
			acc += float(T[i])
			if tt < acc: return [an, i]
	return []

## when frame i of anim an starts (ms into the sequence)
func _ax_t(an: String, i: int) -> float:
	var acc := 0.0
	for a2 in AX_SEQ:
		var T: Array = SK.entry(who, a2)[1]
		for j in T.size():
			if a2 == an and j == i: return acc
			acc += float(T[j])
	return acc

## her height: off the floor hard, easing into the top; a breath of float; then down faster and faster onto impact
func _ax_alt(tt: float) -> float:
	var H: float = a_exec.get("H", AX_H * CSCALE)
	var t0 := _ax_t("ax_rise", 0)
	var ta := _ax_t("ax_rise", 5)
	var td := _ax_t("ax_spin", 5)
	var ti := _ax_t("ax_slam", 3)
	if tt < t0: return 0.0
	if tt < ta: return H * (1.0 - pow(1.0 - (tt - t0) / (ta - t0), 3.2))
	if tt < td: return H * (1.0 + 0.05 * (tt - ta) / (td - ta))
	if tt < ti: return H * 1.05 * (1.0 - pow((tt - td) / (ti - td), 2.2))
	return 0.0

## the tilt: clockwise slowly while she floats and reaches for the shovel, back upright as the somersault takes over
func _ax_tilt(tt: float) -> float:
	var r0 := _ax_t("ax_rise", 2)
	var r1 := _ax_t("ax_rise", 7)
	var r2 := _ax_t("ax_spin", 0)
	var r3 := _ax_t("ax_spin", 2)
	if tt < r0 or tt >= r3: return 0.0
	if tt < r1: return deg_to_rad(20.0) * smoothstep(0.0, 1.0, (tt - r0) / (r1 - r0))
	if tt < r2: return deg_to_rad(20.0)
	return deg_to_rad(20.0) * (1.0 - (tt - r2) / (r3 - r2))

func _aexec_step(dt: float) -> void:
	var tg = a_exec["tg"]
	var live: bool = tg != null and is_instance_valid(tg) and tg.alive()
	var t0: float = a_exec["t"]
	a_exec["t"] = t0 + dt
	var tt: float = a_exec["t"]
	var g0: float = a_exec["g0"]
	for pt in ax_portals: pt["t"] += dt
	ax_portals = ax_portals.filter(func(pt): return pt["t"] < pt["life"])
	var cur := _ax_at(tt)
	var prev := _ax_at(t0)
	if cur.is_empty():
		_aexec_end(tg, live)
		return
	if anim != cur[0] or f != cur[1]: set_anim(cur[0], cur[1])
	# under the foe the second portal opens; she comes up out of it
	if cur[0] == "ax_sink" and cur[1] >= 3 and not a_exec["out"]:
		a_exec["out"] = true
		position.x = float(a_exec["x"])                 # right under the foe
		ax_portals.append({"x": position.x, "y": g0, "t": 0.0, "life": 340.0, "r": 76.0 * CSCALE})
		arena.sfx("aida_close", 1.0)
	var alt := _ax_alt(tt)
	position.y = g0 - alt
	on = alt <= 0.0
	vx = 0.0
	vy = 0.0
	ax_rot = _ax_tilt(tt)
	# the foe hangs where her swing left it while she flies past it; coming down, her feet drive it to the floor
	if live and a_exec["hit1"] and not a_exec["hit2"] and not is_fly(tg):
		var py: float = a_exec.get("py", tg.position.y)
		tg.position.x = position.x + dir * 6.0 * CSCALE
		tg.position.y = clampf(position.y + float(a_exec.get("fh", 0.0)), py, g0)
		if ST.has(tg, "air"): ST.of(tg)["air"]["vy"] = 0.0
	var fresh: bool = prev.is_empty() or prev != cur
	# hit 1: out of the portal, the shovel swung up
	if not a_exec["hit1"] and cur[0] == AX_HIT1[0] and cur[1] >= AX_HIT1[1]:
		a_exec["hit1"] = true
		if live:
			arena.quiet_hit = true
			tg.hit(_aexec_dmg("exec_up"), 0.0, atk_mul())
			arena.quiet_hit = false
			if not is_fly(tg):
				# popped up a little, held there; she must clear its head: fly that much higher
				var fh: float = 124.0 * float(tg.M.get("s", 3.0)) / 3.0 if tg.get("M") is Dictionary else 120.0
				a_exec["fh"] = fh
				a_exec["py"] = g0 - 40.0 * CSCALE
				a_exec["H"] = maxf(AX_H * CSCALE, 40.0 * CSCALE + fh + 30.0 * CSCALE)
		# a rift torn straight up with the swing (not a swing arc: Aida's arcs trail a dimension tear off to the side)
		var up = arena.pfx.gate(position.x + dir * 10.0 * CSCALE, g0, 200.0 * CSCALE, 1.6, 1.2)
		up["rel"] = true
		arena.sfx("aida_hit", 1.0)
		arena.dust(position, 0, true)
		arena.shake(6, dir)
		arena.hitstop = maxf(arena.hitstop, 45.0)
	# the toss: a faint trail as she lets go; the catch: a beat and a small ring
	if fresh and cur[0] == "ax_rise" and cur[1] == 1: add_ghost(140.0)
	if fresh and cur[0] == "ax_rise" and cur[1] == 6:
		arena.hitstop = maxf(arena.hitstop, 60.0)
		arena.post_wave(position + Vector2(dir * 20.0, -120.0 * CSCALE), 0.6, 320.0, 0.16)
		arena.sfx("aida_close", 0.6)
	# the somersault: a trail (no swing arc: Aida's arcs are dimension tears, and a full circle tore the screen)
	if fresh and cur[0] == "ax_spin" and cur[1] == 2: add_ghost(160.0)
	if fresh and cur[0] == "ax_slam" and cur[1] == 0: add_ghost(120.0)
	# hit 2: the slam
	if not a_exec["hit2"] and cur[0] == AX_HIT2[0] and cur[1] >= AX_HIT2[1]:
		a_exec["hit2"] = true
		if live:
			if ST.has(tg, "air"):                 # driven into the floor: down now, the lift over
				tg.position.y = float(ST.of(tg)["air"].get("y0", g0))
				ST.of(tg)["air"]["t"] = 0.0
			arena.quiet_hit = true
			tg.hit(_aexec_dmg("exec_slam"), dir * 6.0, atk_mul())
			arena.quiet_hit = false
		arena.pfx.rewind_slam(position.x + dir * 20.0 * CSCALE, position.y)
		arena.post_wave(position + Vector2(dir * 40.0, 0.0), 0.8, 420.0, 0.2)
		arena.shake(12, dir)
		arena.flash = maxf(arena.flash, 0.15)
		arena.hitstop = maxf(arena.hitstop, 110.0)
		arena.sfx("heavy", 1.0)
		arena.sfx("slam", 0.8)
		arena.dust(position, dir, true)
		ax_portals.append({"x": position.x + dir * 20.0 * CSCALE, "y": g0, "t": 0.0, "life": 300.0, "r": 120.0 * CSCALE, "burst": true})
		arena.dust(position + Vector2(dir * 60.0 * CSCALE, 0), dir, true)
		arena.dust(position - Vector2(dir * 60.0 * CSCALE, 0), -dir, true)
		arena.text(position + Vector2(0, -175.0 * CSCALE), "처형!", Color("#e9d2ff"))

## the floor portals, in the pixels and colours of Aida's other effects (pfx.gd: the void, the lavender tear ramp):
## an eye of the void lying flat on the floor (squashed to the z axis). It opens from a white slit, its torn rim
## flickers, tear-motes circle in it, and it shuts back to a slit and blinks out. `front` false draws the far half
## (behind her), true the near half and rim (over her legs, so she reads as sinking in / rising out). The slam's
## "burst" entry is a torn ring of light running out along the floor.
const PFXS := preload("res://scripts/pfx.gd")
func _ax_draw_portals(front: bool) -> void:
	for pt in ax_portals:
		var u: float = pt["t"] / pt["life"]
		var px := PFXS.PX.new(self, pt["x"] - position.x, pt["y"] - position.y, 2.0)
		var R: float = pt["r"] / 2.0
		var TL: Array = PFXS.TEARL
		var TV: Color = PFXS.TVOID
		if pt.get("burst", false):
			if not front: continue
			var rr := R * (0.5 + 1.1 * u)
			var c: Color = TL[0] if u < 0.25 else (TL[1] if u < 0.5 else (TL[2] if u < 0.75 else TL[3]))
			for a in 64:
				if (a * 7 + int(u * 9.0)) % 5 == 0: continue                  # torn, not a clean ring
				var th := TAU * a / 64.0
				var j := 1.0 + 0.08 * sin(a * 2.3)
				px.px(cos(th) * rr * j, sin(th) * rr * 0.24 * j, c)
			continue
		# the portal, baked from pixelfx (tools/pixelfx_fx/aida-floor-portal.js): 18 frames of 180x84 by the portal's
		# own clock, pivot (90, 54), drawn 50 art px in radius; its far half behind her, its near half in front
		var fi := clampi(int(u * 18.0), 0, 17)
		var sc: float = 2.0 * R / 50.0
		var tex: Texture2D = AX_FP_FRONT if front else AX_FP_BACK
		draw_texture_rect_region(tex, Rect2(roundf(pt["x"] - position.x) - 90.0 * sc, roundf(pt["y"] - position.y) - 54.0 * sc, 180.0 * sc, 84.0 * sc), Rect2((fi % 3) * 180, (fi / 3) * 84, 180, 84))

func _aexec_end(tg, live: bool) -> void:
	qte_offer("finisher")
	_rev("heavy")
	var was_exp: bool = a_exec["exp"]
	var k0: float = a_exec["k"]
	a_exec = {}
	set_anim("idle")
	z_index = 0
	ax_rot = 0.0
	ax_portals = []
	inv = maxf(inv, 250.0)
	# 기습의 문 (KEY): one more 처형 on another foe near
	if was_exp and _av("riftChain") > 0.0 and k0 <= 1.0:
		var nx = null
		var nd := 420.0
		for m2 in foes_alive():
			if live and m2 == tg: continue
			var d2: float = absf(m2.position.x - position.x)
			if d2 < nd:
				nd = d2
				nx = m2
		if nx != null: a_follow = {"m": nx, "t": 800.0, "k": _av("riftChain")}

## 3타 lifts small foes (보스 · 정예: groggy instead); 높이 차기 (airK) lifts higher
func aida_launch(e) -> void:
	ST.add(arena, e, "air", -1.0, "aida")
	if _av("airK") > 0.0 and ST.has(e, "air"): ST.of(e)["air"]["vy"] = float(ST.of(e)["air"]["vy"]) * (1.0 + _av("airK"))
	# the follow-up window (owner 2026-11-04: 0.9 s); bosses / elites are not lifted but still open it
	if a_follow.is_empty() or not is_instance_valid(a_follow["m"]): a_follow = {"m": e, "t": AX_FOLLOW, "k": 1.0}

## Estelle renewal (owner 2026-11-04): her blows build 경직 (only hers: 경직 is a status members apply, not a universal
## stagger). 방패 nodes: 단단한 테두리 (stgK) more gauge, 뒤흔들기 (stgImm) shorter immunity, 무너뜨리기 (groggyK) more
## groggy on bosses / elites. Numbers PLACEHOLDER.
const E_STG := {"attack1": 8.0, "attack2": 8.0, "attack3": 20.0, "attack_high": 10.0, "kneel_attack": 10.0, "dive": 15.0,
	"cthrust": 40.0, "cthrust_part": 20.0, "guard": 15.0, "parry": 60.0, "pparry": 100.0, "tag": 50.0, "ult": 100.0, "assist": 50.0}

func estg(e, base: float) -> void:
	if e == null or not is_instance_valid(e) or not e.alive() or base <= 0.0: return
	var amt := base * (1.0 + _ev("stgK"))
	if ST.big(e): amt *= 1.0 + _ev("groggyK")
	ST.add(arena, e, "stagger", amt, "estelle")
	if _ev("stgImm") > 0.0 and e.has_meta("st") and ST.of(e).has("stagger"): ST.of(e)["stagger"]["immk"] = 1.0 - _ev("stgImm")

## the gauge an Estelle blow builds, by its animation
func _estg_of() -> float:
	match anim:
		"air_combo": return 15.0 if f >= 6 else 6.0
		"cthrust": return E_STG["cthrust"] if cfull else E_STG["cthrust_part"]
	return float(E_STG.get(anim, 0.0))

func _lvm(c: String) -> float:
	return arena.runes.lvm(c) if _rk() else 1.0

## heals that grow with the level and 회복량 (30 × LVM × (1 + heal%))
## Luce's heals follow her attack (owner 2026-11-04): coefficient % of her 공격력 (10 × atk × level × gear) × 회복량
func luce_heal(key: String) -> float:
	var R = arena.get("runes")
	var ak: float = 10.0 * float(CH.STATS["luce"]["atk"]) * (R.atk_k("luce") if R != null else 1.0)
	var hk: float = 1.0 + (R.gear_tot("luce")["heal"] / 100.0 if R != null else 0.0)
	return BAL.p("luce", key) * ak * hk

func _lvh(c: String) -> float:
	return _lvm(c) * (1.0 + (arena.runes.gear_tot(c)["heal"] / 100.0 if _rk() else 0.0))

func _mhp(c: String) -> float:
	return arena.runes.max_hp(c) if _rk() else CH.STATS[c]["hp"]

## 방패 던지기 replaces Estelle's shield skill
func _shield_throw() -> bool:
	if not _rk() or not arena.runes.has("shieldthrow", "estelle"): return false
	if arena.runes.shield_cd <= 0.0: arena.runes.shield_throw()
	return true
