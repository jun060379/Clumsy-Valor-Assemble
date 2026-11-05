extends Node2D
## A dungeon monster, ported from the prototype's mob loop (MOBDEF + updDungeon):
## patrol while unaware, notice (!!), turn slowly, close in, telegraph (red glint ~0.26 s before the hit), strike.
## Strips are 150x150 frames; drawn at scale s with the feet 100*s below the frame top... (origin -75s,-100s).

const DEF := {
	"goblin": {"name": "고블린", "atkEl": "phys", "defEl": ["phys"], "hp": 50, "atk": 8, "ms": 0.15, "s": 2.4, "range": 70, "aggro": 620, "cd": [900, 1500], "hit": 6, "reach": 95,
		"anims": {"idle": ["goblin_idle", 4, 140], "run": ["goblin_run", 8, 80], "atk": ["goblin_attack", 8, 75], "hurt": ["goblin_takehit", 4, 80], "die": ["goblin_death", 4, 130]}},
	"mush": {"name": "독버섯", "atkEl": "plant", "defEl": ["plant"], "hp": 60, "atk": 7, "ms": 0.07, "s": 3.0, "range": 62, "aggro": 480, "cd": [1100, 1800], "hit": 6, "reach": 80, "burst_hit": 7,
		"anims": {"idle": ["mush_idle", 4, 160], "run": ["mush_run", 8, 95], "atk": ["mush_attack", 8, 85], "burst": ["mush_attack3", 11, 80], "hurt": ["mush_takehit", 4, 85], "die": ["mush_death", 4, 140]}},
	"skel": {"name": "해골 광부", "atkEl": "phys", "defEl": ["dark", "phys"], "weak": ["holy"], "hp": 80, "atk": 12, "ms": 0.08, "s": 3.0, "range": 88, "aggro": 560, "cd": [1200, 1900], "hit": 6, "reach": 120, "shield_p": 0.35,
		"anims": {"idle": ["skel_idle", 4, 160], "run": ["skel_walk", 4, 140], "atk": ["skel_attack", 8, 85], "shield": ["skel_shield", 4, 110], "hurt": ["skel_takehit", 4, 85], "die": ["skel_death", 4, 150]}},
	"eye": {"name": "동굴 눈알", "atkEl": "dark", "defEl": ["dark"], "weak": ["holy"], "hp": 35, "atk": 6, "ms": 0.11, "s": 3.0, "fly": 68, "range": 300, "aggro": 640, "cd": [1500, 2300], "hit": 4, "ranged": "eye_proj",
		"anims": {"idle": ["eye_flight", 8, 80], "run": ["eye_flight", 8, 70], "atk": ["eye_attack3", 6, 90], "hurt": ["eye_takehit", 4, 85], "die": ["eye_death", 4, 130]}},
	"boss": {"name": "감독관 해골", "atkEl": "dark", "defEl": ["dark", "earth"], "weak": ["holy"], "hp": 620, "atk": 18, "ms": 0.07, "s": 4.0, "range": 120, "aggro": 2000, "cd": [900, 1400], "boss": true, "hit": 6, "reach": 160, "shield_p": 0.2,
		"tint": Color(1.25, 0.72, 0.95),
		"anims": {"idle": ["skel_idle", 4, 170], "run": ["skel_walk", 4, 150], "atk": ["skel_attack", 8, 80], "atk2": ["skel_attack2", 8, 85], "wave": ["skel_attack3", 6, 95], "shield": ["skel_shield", 4, 110], "hurt": ["skel_takehit", 4, 90], "die": ["skel_death", 4, 190]}},
}
static var TEX := {}
const EL := preload("res://scripts/elements.gd")
const DUMMY := preload("res://scripts/dummy.gd")
const ST := preload("res://scripts/status.gd")      # 공용 상태
## rimEntity for monsters: the 1-2 world px of outline that faces each of the (up to 3) strongest nearby lights, added in
## the light's colour (min(0.9, k * 2.4)); nothing on the far side
const RIM_SH := """
shader_type canvas_item;
render_mode blend_add;
uniform vec4 rl[3];
uniform vec4 rcol[3];
uniform int n = 0;
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec3 o = vec3(0.0);
	if (a > 0.0) {
		for (int i = 0; i < 3; i++) {
			if (i >= n) break;
			float an = texture(TEXTURE, UV + rl[i].xy * TEXTURE_PIXEL_SIZE).a;
			o += rcol[i].rgb * rl[i].z * a * (1.0 - an);
		}
	}
	COLOR = vec4(o, 1.0);
}
"""
static var _rim_sh: Shader

var arena
var kind := "goblin"
var M: Dictionary
var hp := 0.0
var max_hp := 0.0
var dir := -1
var st := "idle"
var anim := "idle"
var f := 0
var ft := 0.0
var cd := 0.0
var flash := 0.0
var kx := 0.0
var hold_t := 0.0             # 교대 패링: its swing hangs mid-air (ms) until the newcomer's blade meets it
var tilt := 0.0               # 교대 패링: knocked back on its heels (rad, springs back; drawn with the body)
var sq := 0.0                 # 타격감: squash-and-stretch ms left (x 1.18 / y 0.86 easing back over SQ_MS)
const SQ_MS := 70.0
var dead := 0.0
var hurt_t := 0.0
var ph := 0.0
var base_y := 0.0
var spawn_t := 0.0
var aw := false               # aware of the player
var home := 0.0
var pt := 0.0                 # patrol timer
var walk := false
var react := 0.0
var lost := 0.0
var turn_t := 0.0
var call_t := 0.0
var atk_clock := 0.0
var hit_at := 0.0
var flared := false
var flare_t := -1.0           # glint age (ms), -1 = none
var hit_now := false
var last_dmg := 0.0
var mark := ""
var mark_t := 0.0
var pl = null                 # platform it patrols on
var elite := false
var phase := 0
var tier := 1
var bar_st := {}              # H2.mob ghost trail / hit flash state
var rim_n: Node2D             # the rim from the room's lights (rimEntity), drawn over the sprite


static func tex(key: String) -> Texture2D:
	if not TEX.has(key):
		TEX[key] = load("res://assets/mobs/%s.png" % key)
	return TEX[key]


func setup(k: String, at: Vector2, delay: float, is_elite := false, room_tier := 0) -> void:
	kind = k
	M = DEF[k]
	elite = is_elite or M.has("boss")
	# spawnMob: M.hp*(elite?1.6:1)*(1+0.12*tier); the boss room is always tier 4 (918). Tier 0 = outside a room (raw hp).
	hp = round(M["hp"] * (1.6 if is_elite else 1.0) * (1.0 + 0.12 * room_tier)) if room_tier > 0 else M["hp"]
	max_hp = hp
	base_y = at.y - M.get("fly", 0)
	position = Vector2(at.x, base_y)
	home = at.x
	spawn_t = delay
	cd = 700.0 + randf() * 900.0
	ph = randf() * 6.0
	pt = 600.0 + randf() * 1500.0
	dir = -1 if randf() < 0.5 else 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = arena.flash_mat.duplicate()
	if _rim_sh == null:
		_rim_sh = Shader.new()
		_rim_sh.code = RIM_SH
	rim_n = Node2D.new()
	rim_n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rm := ShaderMaterial.new()
	rm.shader = _rim_sh
	rim_n.material = rm
	rim_n.draw.connect(_draw_rim)
	add_child(rim_n)


func set_a(a: String) -> void:
	if anim != a:
		anim = a
		f = 0
		ft = 0.0


func is_dead() -> bool:
	return dead > 0.0

func alive() -> bool:
	return dead <= 0.0 and spawn_t <= 0.0


## the player's blade landed
func hit(dmg: float, kb: float, mul := 1.0) -> void:
	if not alive():
		return
	var R = arena.get("runes")
	if R != null: mul *= R.out_mul(self)
	mul *= ST.dmg_mul(self)                    # 공용 상태: 취약, 그로기
	var d: float = arena.elem_hit(position + Vector2(0, -95 if not M.has("fly") else -40), dmg * 10.0 * mul, M["defEl"], M.get("weak", []))   # elements (+ 신성 약점) + 기력
	hp -= d
	if R != null: hp -= R.after_hit(self)
	last_dmg = d
	hit_now = true
	if hp > 0.0: ST.on_hit(arena, self)        # 출혈's extra damage, 띄움 kept up
	if hp > 0.0 and not ST._in and arena.hit_by == "": arena.player.bless_proc(self)      # 빛의 가호: Luce's bolt follows
	flash = 120.0
	kx = kb * 0.6
	var hd := signf(position.x - arena.player.position.x)
	# 타격감: the sprite squashes, the screen punches at the hit point by the blow's weight (dmg 1 light, 2 hit3, 3+ heavy)
	var hp_at := position + Vector2(0, -20.0 if M.has("fly") else -62.0 * M["s"] / 3.0)
	if arena.screen_fx:
		sq = SQ_MS
		arena.punch(hp_at, 0.35 if dmg <= 1.0 else (0.6 if dmg < 3.0 else 1.0))
	arena.damage_text(position + Vector2(0, -95 if not M.has("fly") else -40), roundi(d), dmg > 1.0)
	if arena.get("pfx") != null and not arena.quiet_hit: arena.pfx.hit(position.x - hd * 10.0, position.y - (20.0 if M.has("fly") else 62.0 * M["s"] / 3.0), int(hd) if hd != 0.0 else 1, 1.25 if dmg >= 2.0 else 1.0)
	if hp <= 0.0:
		# hitDummy on hp<=0: break, a jolt of shake, sparks and dust ...
		arena.sfx("down", 1.0)                 # a body goes down (the dummies keep their "break")
		arena.shake_amt = maxf(arena.shake_amt, 8.0)
		arena.spark(position + Vector2(0, -40), 20)
		arena.dust(position, 0, true)
		# ... then mobDie
		dead = 1.0
		set_a("die")
		arena.sfx("down", 0.6)
		arena.spark(position + Vector2(0, -40), 16)
		if M.has("boss"):
			# mobDie: the boss goes down hard — a heavy body fall (no voice; owner 2026-11-04) 120 ms after the break
			arena.sfx("boss_fall", 1.0, {"delay_ms": 120.0})
			arena.shake(14, 1)
			arena.flash = 0.5
			arena.hitstop = 160.0
			arena.text(position + Vector2(0, -200), "격파!", Color("#ffd34d"))
			arena.impact("boss", hp_at, 1)       # 타격감: three punches over half a second, the colour fringes
		if R != null: R.on_kill(self)


## the squash's clock runs on real time (arena steps it through a hitstop too) and its scale about the feet
func fx_step(dt: float) -> void:
	if sq > 0.0: sq = maxf(0.0, sq - dt)
	if tilt != 0.0:
		tilt -= tilt * minf(1.0, dt / 140.0)
		if absf(tilt) < 0.004: tilt = 0.0

func squash() -> Vector2:
	if sq <= 0.0: return Vector2.ONE
	var k: float = sq / SQ_MS
	k = k * k
	return Vector2(1.0 + 0.18 * k, 1.0 - 0.14 * k)


func notice(call: bool) -> void:
	if aw:
		return
	aw = true
	lost = 0.0
	react = 360.0
	dir = 1 if arena.player.position.x > position.x else -1
	set_mark("!!")
	if call:
		for o in arena.mobs:
			if o != self and o.alive() and not o.aw and absf(o.position.x - position.x) < 360.0 and o.call_t <= 0.0:
				o.call_t = 260.0 + randf() * 260.0

func set_mark(k: String) -> void:
	mark = k
	mark_t = 0.0
	arena.sfx("alert_q" if k == "?" else "alert", 0.7)


func flare_pos() -> Vector2:
	if M.has("fly"):
		return position + Vector2(dir * 18.0, -30.0)
	return position + Vector2(dir * 28.0 * M["s"] / 3.0, -66.0 * M["s"] / 3.0)


func step(dt: float) -> void:
	var P = arena.player
	if spawn_t > 0.0:
		spawn_t -= dt
		if spawn_t <= 0.0:
			arena.ring(position + Vector2(0, -40), 30.0)
			arena.dust(position, 0, true)
			arena.sfx("dig", 0.5)
		return
	if hold_t > 0.0:
		hold_t -= dt
		return
	if mark != "":
		mark_t += dt
		if mark_t > 900.0: mark = ""
	if flare_t >= 0.0:
		flare_t += dt
		if flare_t > 420.0: flare_t = -1.0
	ft += dt
	var A: Array = M["anims"].get(anim, M["anims"]["idle"])
	if flash > 0.0: flash -= dt
	ph += dt / 600.0
	if kx != 0.0:
		position.x += kx * dt * 0.12 * (0.3 if M.has("boss") else 1.0)
		kx *= pow(0.985, dt)
		if absf(kx) < 0.05: kx = 0.0
	position.x = clampf(position.x, 40.0, arena.world_w - 40.0)
	if M.has("fly"):
		var top := 330.0           # the flight ceiling follows the room's height (GROUND - tpl.top - 40)
		if arena.level != null and String(arena.level.kind) == "dungeon": top = float(arena.level.tpl.get("top", 330.0))
		var ty := minf(arena.ground_y - M["fly"], maxf(arena.ground_y - top - 40.0, P.position.y - 95.0))
		base_y += (ty - base_y) * minf(1.0, dt / 900.0)
		position.y = base_y + sin(ph) * 8.0
	if pl != null:
		position.x = clampf(position.x, pl.x + 18.0, pl.x + pl.w - 18.0)
	elif not M.has("fly"):
		for so in arena.solids:
			if position.x > so.x - 22.0 and position.x < so.x + so.w + 22.0 and position.y > so.top + 1.0:
				position.x = so.x - 22.0 if position.x < so.x + so.w / 2.0 else so.x + so.w + 22.0
	(material as ShaderMaterial).set_shader_parameter("flash", clampf(flash / 120.0 * 0.85, 0.0, 1.0))
	queue_redraw()

	if is_dead():
		if anim != "die": set_a("die")
		if f < A[1] - 1 and ft >= A[2]:
			ft = 0.0
			f += 1
		dead += dt
		return

	# 공용 상태: 경직 · 띄움 · 그로기 hold it (the hurt frame), no AI
	if ST.step(arena, self, dt):
		hit_now = false
		last_dmg = 0.0
		hurt_t = 0.0
		st = "hurt"
		if anim != "hurt": set_a("hurt")
		f = mini(f, M["anims"]["hurt"][1] - 1) if M["anims"].has("hurt") else 0
		return

	# got hit -> short stagger (a skeleton may block with its shield instead), never mid-swing
	if hit_now and anim != "hurt" and st != "atk":
		if M.has("shield_p") and (P.position.x - position.x) * dir > 0.0 and randf() < M["shield_p"] and anim != "shield":
			set_a("shield")
			hurt_t = 350.0
			hp = minf(max_hp, hp + round(last_dmg) * 0.6)
			arena.text(position + Vector2(0, -130), "막음", Color("#cfe3ff"))
		else:
			set_a("hurt")
			hurt_t = 120.0 if M.has("boss") else 260.0
	if hit_now and not aw:
		notice(true)
		react = 520.0
		arena.text(position + Vector2(0, -150), "기습!", Color("#ffd23a"))
	last_dmg = 0.0
	hit_now = false

	if hurt_t > 0.0:
		hurt_t -= dt
		st = "hurt"
		if _adv(A) and f >= A[1]: f = A[1] - 1
		if hurt_t <= 0.0:
			set_a("idle")
			st = "idle"
			cd = maxf(cd, 400.0)
		return

	var dx: float = P.position.x - position.x
	var adx := absf(dx)
	var dy := absf(P.position.y - (position.y + M.get("fly", 0)))

	if st == "atk":
		atk_clock += dt
		if not flared and atk_clock >= hit_at - 260.0:
			flared = true
			flare_t = 0.0
			arena.sfx("flare", 0.6)
		if _adv(A):
			var key := anim
			var hit_f: int = M.get("burst_hit", 7) if key == "burst" else (3 if key == "wave" else M["hit"])
			if f == hit_f:
				if key == "burst":
					arena.ring(position + Vector2(0, -30), 60.0)
					if absf(dx) < 120.0 and absf(P.position.y - position.y) < 80.0:
						P.take_hit(self, M["atk"] * 1.3)
				elif key == "wave":
					arena.shoot(self, position + Vector2(dir * 80.0, -60.0), Vector2(dir * 0.5, 0.0), true)
					arena.sfx("heavy", 0.6)
				elif M.has("ranged"):
					arena.shoot(self, position + Vector2(dir * 30.0, -28.0), Vector2(dir * 0.36, ((P.position.y - 60.0) - (position.y - 28.0)) / maxf(300.0, adx) * 0.36))
					arena.sfx("swing", 0.4)
				else:
					arena.sfx("heavy" if M.has("boss") else "swing", 0.7)
					var reach: float = M["reach"] * (1.25 if key == "atk2" else 1.0)
					var in_front: bool = dx * dir > -20.0 and adx < reach
					if in_front and absf(P.position.y - position.y) < (140.0 if M.has("boss") else 90.0):
						P.take_hit(self, M["atk"] * (1.4 if key == "atk2" else 1.0))
					if key == "atk2":
						arena.shake(7, dir)
						arena.dust(Vector2(position.x + dir * 90.0, arena.ground_y), dir, true)
			if f >= A[1]:
				set_a("idle")
				st = "idle"
				cd = M["cd"][0] + randf() * (M["cd"][1] - M["cd"][0])
				react = maxf(react, ST.recovery(self))      # 둔화: a longer rest after the swing (its timing stays)
		return

	# vision: an unaware mob only sees what is in front of it
	if not aw:
		var view := 520.0 if M.has("fly") else 440.0
		var front := dx * dir > -30.0
		if call_t > 0.0:
			call_t -= dt
		if (front and adx < view and dy < 170.0) or (adx < 40.0 and dy < 60.0) or (call_t < 0.0):
			call_t = 0.0
			notice(true)
		else:
			pt -= dt
			if pt <= 0.0:
				if walk:
					walk = false
					pt = 1400.0 + randf() * 1800.0
					if randf() < 0.6: dir *= -1
				else:
					walk = true
					pt = 900.0 + randf() * 1400.0
			var lo: float = pl.x + 30.0 if pl != null else maxf(80.0, home - 170.0)
			var hi: float = pl.x + pl.w - 30.0 if pl != null else minf(arena.world_w - 80.0, home + 170.0)
			if walk:
				position.x += dir * M["ms"] * 0.42 * ST.speed_mul(self) * dt
				if position.x < lo:
					position.x = lo
					dir = 1
					walk = false
					pt = 900.0
				elif position.x > hi:
					position.x = hi
					dir = -1
					walk = false
					pt = 900.0
				st = "run"
				set_a("run")
			else:
				st = "idle"
				set_a("idle")
			if _adv(A) and f >= A[1]: f = 0
			return
	if react > 0.0:
		react -= dt
		st = "idle"
		set_a("idle")
		if _adv(A) and f >= A[1]: f = 0
		return
	cd -= dt
	var seen: bool = adx < M["aggro"] + 120.0 and dy < 260.0
	if not seen:
		lost += dt
		if lost > 2600.0:
			aw = false
			lost = 0.0
			home = position.x
			walk = false
			pt = 1200.0
			set_mark("?")
	else:
		lost = 0.0
	if seen and dx * dir < 0.0:
		turn_t += dt
		if turn_t > (160.0 if M.has("boss") else 300.0):
			dir *= -1
			turn_t = 0.0
	else:
		turn_t = 0.0
	if seen and dx * dir >= 0.0:
		var want := ""
		if M.has("ranged"):
			want = "away" if adx < 180.0 else ("close" if adx > M["range"] else "hold")
		else:
			want = "close" if adx > M["range"] * 0.85 else "hold"
		var in_range: bool = adx < M["range"] + 80.0 if M.has("ranged") else adx < M["range"]
		if cd <= 0.0 and in_range:
			st = "atk"
			var k := "atk"
			if M.has("boss"):
				phase = 1 if hp < max_hp * 0.5 else 0
				var r := randf()
				k = "wave" if adx > 220.0 else ("atk2" if r < 0.4 else "atk")
				if phase == 1 and r < 0.25: k = "wave"
			elif M["anims"].has("burst") and adx < 90.0 and randf() < 0.45:
				k = "burst"
			set_a(k)
			var AA: Array = M["anims"][k]
			var hf: int = M.get("burst_hit", 7) if k == "burst" else (3 if k == "wave" else M["hit"])
			atk_clock = 0.0
			hit_at = hf * AA[2]
			flared = false
			return
		if want == "close" or want == "away":
			st = "run"
			set_a("run")
			position.x += (1.0 if want == "close" else -1.0) * dir * M["ms"] * (1.3 if phase == 1 else 1.0) * ST.speed_mul(self) * dt
		else:
			st = "idle"
			set_a("idle")
	else:
		st = "idle"
		set_a("idle")
	# keep them from stacking on one spot
	for o in arena.mobs:
		if o == self or not o.alive() or o.M.has("fly") != M.has("fly"):
			continue
		var d: float = position.x - o.position.x
		if absf(d) < 46.0:
			position.x += (signf(d) if d != 0.0 else 1.0) * 0.05 * dt
	if _adv(A) and f >= A[1]: f = 0


func _adv(A: Array) -> bool:
	if ft >= A[2]:
		ft -= A[2]
		f += 1
		return true
	return false


func _draw() -> void:
	if spawn_t > 0.0:
		return
	var A: Array = M["anims"].get(anim, M["anims"]["idle"])
	var s: float = M["s"]
	var fr := mini(f, A[1] - 1)
	var alpha := 1.0
	if is_dead():
		alpha = maxf(0.0, 1.0 - maxf(0.0, dead - 900.0) / 600.0)
	if alpha <= 0.0:
		return
	# shadow on the floor
	var floor_dy: float = (arena.ground_y - position.y) if M.has("fly") else 0.0
	draw_set_transform(Vector2(0, floor_dy - 1.0), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 16.0 * s / 3.0, Color(0, 0, 0, 0.28 * alpha))
	var sqs := squash()
	draw_set_transform(Vector2.ZERO, tilt, Vector2(dir * sqs.x, sqs.y))
	var tint: Color = M.get("tint", Color(1.15, 0.8, 1.25) if elite else Color.WHITE)
	var stt: Color = ST.body_tint(self) if not is_dead() else Color.WHITE      # 공용 상태 on the body
	draw_texture_rect_region(tex(A[0]), Rect2(-75.0 * s, -100.0 * s, 150.0 * s, 150.0 * s), Rect2(fr * 150, 0, 150, 150), Color(tint.r * stt.r, tint.g * stt.g, tint.b * stt.b, alpha))
	draw_set_transform(Vector2.ZERO)
	if not is_dead(): ST.draw_body(self, self, 40.0 if M.has("fly") else 62.0 * s / 3.0 * 1.6)
	if rim_n != null: rim_n.queue_redraw()
	# (a boss's statuses and groggy gauge are drawn under its bar in the HUD: hud.gd _draw_boss_status)
	if not is_dead() and not M.has("boss"):
		# small HP bar over the head
		var bw := 36.0 if M.has("fly") else 44.0
		var by := -(40.0 if M.has("fly") else (150.0 if kind == "skel" else 115.0))
		DUMMY.bar(self, bar_st, 0.0, by, bw, maxf(0.0, hp) / max_hp, elite)    # H2.mob: slanted, ghost trail, hit flash
		EL.draw_tag(self, 0.0, by - 5.0, M["defEl"])          # elTag: its own elements over the bar
		ST.draw_bar_icons(self, self, bw * 0.5, by + 2.0, arena.font_black)      # 공용 상태: big icons beside the bar
		if mark != "":
			var k := minf(1.0, mark_t / 90.0)
			var col := Color("#ffd23a") if mark == "!!" else Color("#cfd6e6")
			draw_string_outline(arena.font_black, Vector2(-10, by - 12.0 - 6.0 * k), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0.08, 0.04, 0.06, 1.0 - maxf(0.0, (mark_t - 700.0) / 200.0)))
			draw_string(arena.font_black, Vector2(-10, by - 12.0 - 6.0 * k), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(col, 1.0 - maxf(0.0, (mark_t - 700.0) / 200.0)))

## rimEntity(() => drawMob(d, true), d.x, d.y + (fly ? 40 : 0)): the lights whose reach (r * 2.2) holds the body centre,
## strongest three, each lighting the edge that faces it
func rim_near() -> Array:
	var Ls: Array = arena.pfx.rim_lights() if arena.get("pfx") != null else []
	var c := position + Vector2(0.0, (40.0 if M.has("fly") else 0.0) - 60.0)
	var near: Array = []
	for l in Ls:
		var dv: Vector2 = l[0] - c
		var d := dv.length()
		var R: float = l[1] * 2.2
		if d >= R: continue
		near.append([pow(1.0 - d / R, 1.3) * l[2], dv / (d if d > 0.0 else 1.0), l[3]])
	near.sort_custom(func(a, b): return a[0] > b[0])
	return near.slice(0, 3)

func _draw_rim() -> void:
	var mat: ShaderMaterial = rim_n.material
	if spawn_t > 0.0 or is_dead():
		mat.set_shader_parameter("n", 0)
		return
	var near := rim_near()
	mat.set_shader_parameter("n", near.size())
	if near.is_empty(): return
	var s: float = M["s"]
	var rl := PackedVector4Array()
	var rc := PackedVector4Array()
	for i in 3:
		if i < near.size():
			var u: Vector2 = near[i][1]
			var o := Vector2(roundf(u.x * 2.0) * dir, roundf(u.y * 2.0)) / s      # world px -> sprite texels (flipped with the body)
			rl.append(Vector4(o.x, o.y, minf(0.9, near[i][0] * 2.4), 0.0))
			var lc: Color = near[i][2]
			rc.append(Vector4(lc.r, lc.g, lc.b, 0.0))
		else:
			rl.append(Vector4.ZERO)
			rc.append(Vector4.ZERO)
	mat.set_shader_parameter("rl", rl)
	mat.set_shader_parameter("rcol", rc)
	var A: Array = M["anims"].get(anim, M["anims"]["idle"])
	var fr := mini(f, A[1] - 1)
	var sqs := squash()
	rim_n.draw_set_transform(Vector2.ZERO, tilt, Vector2(dir * sqs.x, sqs.y))
	rim_n.draw_texture_rect_region(tex(A[0]), Rect2(-75.0 * s, -100.0 * s, 150.0 * s, 150.0 * s), Rect2(fr * 150, 0, 150, 150))
	rim_n.draw_set_transform(Vector2.ZERO)
