extends Node2D
## A dungeon monster, ported from the prototype's mob loop (MOBDEF + updDungeon):
## patrol while unaware, notice (!!), turn slowly, close in, telegraph (red glint ~0.26 s before the hit), strike.
## Strips are 150x150 frames; drawn at scale s with the feet 100*s below the frame top... (origin -75s,-100s).

const DEF := {
	"goblin": {"name": "고블린", "hp": 50, "atk": 8, "ms": 0.15, "s": 2.4, "range": 70, "aggro": 620, "cd": [900, 1500], "hit": 6, "reach": 95,
		"anims": {"idle": ["goblin_idle", 4, 140], "run": ["goblin_run", 8, 80], "atk": ["goblin_attack", 8, 75], "hurt": ["goblin_takehit", 4, 80], "die": ["goblin_death", 4, 130]}},
	"mush": {"name": "독버섯", "hp": 60, "atk": 7, "ms": 0.07, "s": 3.0, "range": 62, "aggro": 480, "cd": [1100, 1800], "hit": 6, "reach": 80, "burst_hit": 7,
		"anims": {"idle": ["mush_idle", 4, 160], "run": ["mush_run", 8, 95], "atk": ["mush_attack", 8, 85], "burst": ["mush_attack3", 11, 80], "hurt": ["mush_takehit", 4, 85], "die": ["mush_death", 4, 140]}},
	"skel": {"name": "해골 광부", "hp": 80, "atk": 12, "ms": 0.08, "s": 3.0, "range": 88, "aggro": 560, "cd": [1200, 1900], "hit": 6, "reach": 120, "shield_p": 0.35,
		"anims": {"idle": ["skel_idle", 4, 160], "run": ["skel_walk", 4, 140], "atk": ["skel_attack", 8, 85], "shield": ["skel_shield", 4, 110], "hurt": ["skel_takehit", 4, 85], "die": ["skel_death", 4, 150]}},
	"eye": {"name": "동굴 눈알", "hp": 35, "atk": 6, "ms": 0.11, "s": 3.0, "fly": 68, "range": 300, "aggro": 640, "cd": [1500, 2300], "hit": 4, "ranged": "eye_proj",
		"anims": {"idle": ["eye_flight", 8, 80], "run": ["eye_flight", 8, 70], "atk": ["eye_attack3", 6, 90], "hurt": ["eye_takehit", 4, 85], "die": ["eye_death", 4, 130]}},
}
static var TEX := {}

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


static func tex(key: String) -> Texture2D:
	if not TEX.has(key):
		TEX[key] = load("res://assets/mobs/%s.png" % key)
	return TEX[key]


func setup(k: String, at: Vector2, delay: float) -> void:
	kind = k
	M = DEF[k]
	hp = M["hp"]
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
	var d := dmg * 10.0 * mul
	hp -= d
	last_dmg = d
	hit_now = true
	flash = 120.0
	kx = kb * 0.6
	var hd := signf(position.x - arena.player.position.x)
	arena.damage_text(position + Vector2(0, -95 if not M.has("fly") else -40), roundi(d), dmg > 1.0)
	arena.spark(position + Vector2(-hd * 10.0, -20.0 if M.has("fly") else -62.0 * M["s"] / 3.0), 14 if dmg > 1.0 else 8)
	if hp <= 0.0:
		dead = 1.0
		set_a("die")
		arena.sfx("break", 0.8)
		arena.spark(position + Vector2(0, -40), 16)


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
		position.x += kx * dt * 0.12
		kx *= pow(0.985, dt)
		if absf(kx) < 0.05: kx = 0.0
	position.x = clampf(position.x, 40.0, arena.world_w - 40.0)
	if M.has("fly"):
		var ty := minf(arena.ground_y - M["fly"], maxf(arena.ground_y - 330.0 - 40.0, P.position.y - 95.0))
		base_y += (ty - base_y) * minf(1.0, dt / 900.0)
		position.y = base_y + sin(ph) * 8.0
	if pl != null:
		position.x = clampf(position.x, pl.x + 18.0, pl.x + pl.w - 18.0)
	(material as ShaderMaterial).set_shader_parameter("flash", clampf(flash / 120.0 * 0.85, 0.0, 1.0))
	queue_redraw()

	if is_dead():
		if anim != "die": set_a("die")
		if f < A[1] - 1 and ft >= A[2]:
			ft = 0.0
			f += 1
		dead += dt
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
			hurt_t = 260.0
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
			var hit_f: int = M.get("burst_hit", 7) if key == "burst" else M["hit"]
			if f == hit_f:
				if key == "burst":
					arena.ring(position + Vector2(0, -30), 60.0)
					if absf(dx) < 120.0 and absf(P.position.y - position.y) < 80.0:
						P.take_hit(self, M["atk"] * 1.3)
				elif M.has("ranged"):
					arena.shoot(self, position + Vector2(dir * 30.0, -28.0), Vector2(dir * 0.36, ((P.position.y - 60.0) - (position.y - 28.0)) / maxf(300.0, adx) * 0.36))
					arena.sfx("swing", 0.4)
				else:
					arena.sfx("swing", 0.7)
					var in_front: bool = dx * dir > -20.0 and adx < M["reach"]
					if in_front and absf(P.position.y - position.y) < 90.0:
						P.take_hit(self, M["atk"])
			if f >= A[1]:
				set_a("idle")
				st = "idle"
				cd = M["cd"][0] + randf() * (M["cd"][1] - M["cd"][0])
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
				position.x += dir * M["ms"] * 0.42 * dt
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
		if turn_t > 300.0:
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
			if M["anims"].has("burst") and adx < 90.0 and randf() < 0.45:
				k = "burst"
			set_a(k)
			var AA: Array = M["anims"][k]
			var hf: int = M.get("burst_hit", 7) if k == "burst" else M["hit"]
			atk_clock = 0.0
			hit_at = hf * AA[2]
			flared = false
			return
		if want == "close" or want == "away":
			st = "run"
			set_a("run")
			position.x += (1.0 if want == "close" else -1.0) * dir * M["ms"] * dt
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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(dir, 1))
	draw_texture_rect_region(tex(A[0]), Rect2(-75.0 * s, -100.0 * s, 150.0 * s, 150.0 * s), Rect2(fr * 150, 0, 150, 150), Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)
	if not is_dead():
		# small HP bar over the head
		var bw := 36.0 if M.has("fly") else 44.0
		var by := -(40.0 if M.has("fly") else (150.0 if kind == "skel" else 115.0))
		draw_rect(Rect2(-bw / 2.0 - 1.0, by - 1.0, bw + 2.0, 6.0), Color(0.05, 0.03, 0.07, 0.8))
		draw_rect(Rect2(-bw / 2.0, by, bw * clampf(hp / max_hp, 0.0, 1.0), 4.0), Color("#ff4d6a"))
		if mark != "":
			var k := minf(1.0, mark_t / 90.0)
			var col := Color("#ffd23a") if mark == "!!" else Color("#cfd6e6")
			draw_string_outline(arena.font_black, Vector2(-10, by - 12.0 - 6.0 * k), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0.08, 0.04, 0.06, 1.0 - maxf(0.0, (mark_t - 700.0) / 200.0)))
			draw_string(arena.font_black, Vector2(-10, by - 12.0 - 6.0 * k), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(col, 1.0 - maxf(0.0, (mark_t - 700.0) / 200.0)))
