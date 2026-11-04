extends SceneTree
## Keyboard 1 · 2 · 3 swap straight to that party slot (a key bound to something else is left alone); 마우스 조준
## (settings aim = "mouse", keyboard + mouse only): Luce strikes the foe under the pointer (or the pointer's spot),
## Kenin's flat shots fly at the pointer, Aida's sigil starts at the pointer; off, the old auto-aim stands:
## godot --headless --path . -s tests/test_controls.gd

var arena
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await process_frame

func until(cond: Callable, ms := 6000.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() - t0 > ms / Engine.time_scale + 2000: return false
	return true

func key(k: int) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)
	var u := InputEventKey.new()
	u.physical_keycode = k
	u.keycode = k
	u.pressed = false
	Input.parse_input_event(u)

func gob(x: float):
	var m = arena.spawn("goblin", x, 0.0)
	m.hp = 9999.0
	m.max_hp = 9999.0
	m.cd = 99999.0
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0
	return m

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(3)
	var P = arena.player
	var C = arena.cfg
	C.dev = "kbm"
	arena.enter_dungeon()
	await frames(20)
	P.party = ["estelle", "aida", "luce"]
	for c in P.party: P.hpm[c] = 100.0
	for m in arena.mobs: m.hp = 0.0

	print("slot keys")
	P.swap_cd = 0.0
	P.party_lock = 0.0
	key(KEY_3)
	ok(await until(func(): return P.who == "luce"), "3 → slot 3 (luce)")
	await until(func(): return P.party_lock <= 0.0 and P.swap_cd <= 0.0 and P.anim != "swap_in")
	key(KEY_KP_2)
	ok(await until(func(): return P.who == "aida"), "keypad 2 → slot 2 (aida)")
	await until(func(): return P.party_lock <= 0.0 and P.swap_cd <= 0.0 and P.anim != "swap_in")
	key(KEY_2)
	await frames(10)
	ok(P.who == "aida", "the slot already in control: nothing happens")
	C.bind("jump", 1, KEY_1)
	key(KEY_1)
	await frames(10)
	ok(P.who == "aida", "1 bound to jump: no swap")
	C.bind("jump", 1, 0)
	key(KEY_1)
	ok(await until(func(): return P.who == "estelle"), "1 → slot 1 (estelle)")

	print("마우스 조준 off: the old auto-aim")
	C.aim = "off"
	P.switch_char("luce")
	P.dir = 1
	var right = gob(P.position.x + 300.0)
	var left = gob(P.position.x - 330.0)
	P.aim_test = left.position + Vector2(0, -50)
	ok(not P.mouse_aim(), "mouse_aim off")
	var sp: Dictionary = P.luce_spot(420.0, 95.0)
	ok(sp["tg"] == right, "luce: the nearest foe ahead")

	print("마우스 조준 on")
	C.aim = "mouse"
	ok(P.mouse_aim(), "mouse_aim on (keyboard + mouse)")
	P.dir = 1
	sp = P.luce_spot(420.0, 95.0)
	ok(sp["tg"] == left and P.dir == -1, "luce: the foe under the pointer, turned to it")
	P.aim_test = P.position + Vector2(200.0, -200.0)
	sp = P.luce_spot(420.0, 95.0)
	ok(sp["tg"] == null and absf(sp["x"] - P.aim_test.x) < 1.0 and P.dir == 1, "luce: no foe there → the pointer's spot")
	ok(sp["aim"].is_finite(), "a bolt with no foe flies at the pointer")
	C.dev = "pad"
	ok(not P.mouse_aim(), "on a pad: off")
	C.dev = "kbm"

	P.switch_char("kenin")
	P.party_lock = 0.0
	P.qte_gap = 0.0
	arena.kenin.ammo = 18
	P.dir = 1
	P.aim_test = P.position + Vector2(300.0, -260.0)
	P.set_anim("attack1", 3)
	P.hit_done = false
	var n0: int = arena.kenin.shots.size()
	P.kenin_shoot()
	ok(arena.kenin.shots.size() == n0 + 1, "kenin fires")
	var s: Dictionary = arena.kenin.shots.back()
	var ang := atan2(float(s["vy"]), absf(float(s["vx"])))
	ok(ang < -0.5, "kenin: the shot climbs toward the pointer (%.2f rad)" % ang)
	P.aim_test = P.position + Vector2(-300.0, -60.0)
	P.set_anim("attack1", 3)
	P.hit_done = false
	P.kenin_shoot()
	ok(P.dir == -1 and float(arena.kenin.shots.back()["vx"]) < 0.0, "kenin: pointer behind → turns and shoots back")

	P.switch_char("estelle")
	P.on = true
	P.dir = 1
	P.aim_test = P.position + Vector2(-200.0, -20.0)
	P.start_attack()
	ok(P.dir == -1, "estelle: the swing turns to the pointer behind")
	await frames(2)
	P.set_anim("idle")
	P.dir = 1
	P.use_skill(1)
	ok(P.dir == -1, "estelle: the skill turns to the pointer, not the held key")
	P.set_anim("idle")

	P.switch_char("aida")
	P.tp_cd = 0.0
	P.on = true
	P.aim_test = P.position + Vector2(250.0, -120.0)
	P.use_skill(0)
	ok(Vector2(P.mx, P.my).distance_to(P.aim_test) < 1.0, "aida: the sigil starts at the pointer")
	await frames(3)
	ok(arena.mark_pos.is_finite() and arena.mark_pos.distance_to(P.aim_test) < 40.0 or not P.keys["guard"], "aida: the sigil follows the pointer")

	C.aim = "off"
	C.dev = "auto"
	C.save()
	print("DONE: %d failed" % fails)
	quit(1 if fails > 0 else 0)
