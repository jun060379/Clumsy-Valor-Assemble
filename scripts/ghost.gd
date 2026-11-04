extends Node2D
## The training ground's ghost (prototype `ghost`, hitGhost, drawGhost): a little sheet that drifts along the yard
## and now and then turns toward her. It bumps into her (guard / parry / hurt like any blow), flickers when struck,
## and comes back 4 s after it is banished, with a ring, 420 px to one side of her.
## Aida striking it from behind (its back to her) hits twice as hard: BACKSTAB, and a 기습 QTE call.

const RUNES := preload("res://scripts/runes.gd")
const EL := preload("res://scripts/elements.gd")
const DUMMY := preload("res://scripts/dummy.gd")
const DEV := preload("res://scripts/dev.gd")
const ST := preload("res://scripts/status.gd")
const E: Dictionary = RUNES.ENEMY["ghost"]       # 유령: hp 30, atk 10, ms 0.09, dark / dark

var arena
var kind := "ghost"
var elite := true                # banishing it drops like an elite (dropLoot(…, true))
var M := {"atkEl": E["atkEl"], "defEl": E["defEl"]}
var hp: float = E["hp"]
var max_hp: float = E["hp"]
var dir := 1
var hurt_t := 0.0                # recoiling (ms); also drifts by kb
var kb := 0.0
var daze := 0.0                  # stands still (after a tag strike)
var on := false                  # in the training ground, banished or not
var up := false                  # alive
var t := 0.0
var st := "idle"                 # what player.take_hit / counter_swap poke on a foe
var flared := false
var flare_t := -1.0
var bar_st := {}

var _js_cb
func _ready() -> void:
	z_index = 0
	if DEV.on and OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(func(a: Array): test_cmd(str(a[0]) if a.size() > 0 else ""))
		JavaScriptBridge.get_interface("window").cvaTrain = _js_cb

## web test hook (screenshots): window.cvaTrain("go") enters the training ground · "x <px>" puts her there ·
## "tod <h>" sets the clock · "ghost <dx>" puts the ghost dx from her · "state" → window.__train
func test_cmd(cmd: String) -> void:
	var w := cmd.split(" ")
	var P = arena.player
	match w[0]:
		"go": arena.go_training()
		"x":
			P.position = Vector2(float(w[1]), arena.ground_y)
			P.on = true
			P.plat = null
			arena.snap_camera()
		"tod": arena.tod_h = float(w[1])
		"ghost":
			position.x = P.position.x + float(w[1])
			hurt_t = 0.0
	if DEV.on and OS.has_feature("web"): JavaScriptBridge.eval("window.__train=" + JSON.stringify({"lk": arena.level_kind(), "train": arena.train != null, "x": P.position.x, "ghost": position.x, "up": alive(), "score": arena.score}), true)

func alive() -> bool:
	return on and up

func is_dead() -> bool:
	return not alive()

func set_a(_a: String) -> void:
	pass

## entering the training ground: up at x 700 with full HP
func enter() -> void:
	on = true
	up = true
	hp = max_hp
	position = Vector2(700.0, arena.ground_y)
	hurt_t = 0.0
	daze = 0.0
	t = 0.0
	bar_st = {}
	visible = true

func leave() -> void:
	on = false
	up = false
	t = 0.0
	visible = false

func hit(dmg: float, _kb: float, mul := 1.0) -> void:
	if not alive():
		return
	var P = arena.player
	var R = arena.get("runes")
	if R != null: mul *= R.out_mul(self)          # (등 뒤의 그림자 is in here)
	var bs: bool = P.who == "aida" and P.dir == dir
	if bs:
		mul *= 2.0
		P.qte_offer("backstab")
		arena.text(position + Vector2(0, -100), "BACKSTAB", Color("#ffd34d"))
		arena.flash = maxf(arena.flash, 0.15)
	mul *= ST.dmg_mul(self)
	var p := position + Vector2(0, -80)
	var d: float = arena.elem_hit(p, dmg * 10.0 * mul, M["defEl"])
	hp -= d
	if hp > 0.0: ST.on_hit(arena, self)
	if R != null: hp -= R.after_hit(self)
	arena.damage_text(p, roundi(d), dmg > 1.0, Color("#cfe8ff"))
	var hd := signf(position.x - P.position.x)
	arena.spark(position + Vector2(-hd * 10.0, -60.0), 14 if dmg > 1.0 else 8)
	hurt_t = maxf(hurt_t, 350.0)
	kb = P.dir * 1.5
	arena.score += roundi(d / 10.0)
	if hp <= 0.0:
		up = false
		t = 0.0
		arena.sfx("down", 1.0)
		arena.spark(position + Vector2(0, -30), 24)
		arena.ring(position + Vector2(0, -30), 10.0)
		arena.score += 8
		arena.text(position + Vector2(0, -90), "BANISHED", Color("#99ddff"))
		if R != null: R.on_kill(self)            # 도감, the kill event, an elite's drop
	arena.best = maxi(arena.best, arena.score)

func step(dt: float) -> void:
	t += dt
	if not on:
		return
	var P = arena.player
	var W: float = arena.world_w
	if not up:
		if t > 4000.0:
			up = true
			hp = max_hp
			position.x = clampf(P.position.x + (-1.0 if randf() < 0.5 else 1.0) * 420.0, 80.0, W - 80.0)
			t = 0.0
			hurt_t = 0.0
			daze = 0.0
			bar_st = {}
			arena.ring(position + Vector2(0, -30), 20.0)
		queue_redraw()
		return
	if daze > 0.0: daze -= dt
	if ST.step(arena, self, dt): daze = maxf(daze, 60.0)       # 경직 · 빙결 · 그로기 hold her too
	if hurt_t > 0.0:
		hurt_t -= dt
		position.x += kb * dt * 0.3
	elif daze > 0.0:
		pass                                   # lost her: stands still, still facing where she was
	else:
		position.x += dir * float(E["ms"]) * dt
		if position.x < 60.0 or position.x > W - 60.0: dir = -dir
		if absf(P.position.x - position.x) > 200.0 and randf() < 0.004 * dt / 16.7:
			dir = 1 if P.position.x > position.x else -1
	position.x = clampf(position.x, 50.0, W - 50.0)
	# it bumps into her: her guard, parry and hurt rules (player.take_hit)
	if absf(position.x - P.position.x) < 40.0 and absf(position.y - P.position.y) < 60.0 and hurt_t <= 0.0 and daze <= 0.0 and P.anim != "death":
		var r: String = P.take_hit(self, float(E["atk"]))
		match r:
			"parry":
				hurt_t = 900.0
				kb = P.dir * 2.0
				arena.score += 3
				arena.best = maxi(arena.best, arena.score)
			"guard":
				hurt_t = 500.0
				kb = P.dir * 1.0
			"hit":
				hurt_t = 400.0
				kb = 0.0
	st = "idle"
	queue_redraw()

func _draw() -> void:
	if not alive():
		return
	var y := -30.0 + sin(t / 300.0) * 6.0
	var a := 0.4 if hurt_t > 0.0 and int(t / 40.0) % 2 == 1 else 0.85
	var pts := PackedVector2Array()
	pts.append(Vector2(-22, y + 20))
	_quad(pts, Vector2(-22, y + 20), Vector2(-24, y - 30), Vector2(0, y - 34))
	_quad(pts, Vector2(0, y - 34), Vector2(24, y - 30), Vector2(22, y + 20))
	for i in 4:
		pts.append(Vector2(22 - i * 11 - 5, y + 12 + (8 if i % 2 == 1 else 0)))
	draw_colored_polygon(pts, Color(Color("#b9c8ff"), a))
	var ec := Color(Color("#2a2a44"), a)
	for ex in [-7.0, 7.0]:
		draw_set_transform(Vector2(ex + dir * 3.0, y - 12.0), 0.0, Vector2(3.0 / 5.0, 1.0))
		draw_circle(Vector2.ZERO, 5.0, ec)
	draw_set_transform(Vector2.ZERO)
	DUMMY.bar(self, bar_st, 0.0, y - 48.0, 40.0, maxf(0.0, hp) / max_hp, false)
	EL.draw_tag(self, 0.0, y - 53.0, M["defEl"])
	ST.draw(self, self, y - 74.0)

static func _quad(pts: PackedVector2Array, a: Vector2, c: Vector2, b: Vector2) -> void:
	for i in range(1, 11):
		var u := i / 10.0
		pts.append(a.lerp(c, u).lerp(c.lerp(b, u), u))
