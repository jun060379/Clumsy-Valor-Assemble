extends SceneTree
## Headless check of the training ground (훈련장) as in the prototype: godot --headless -s tests/test_training.gd
## no waves or cave mouth; dummies break and come back, the unbreakable row; the ghost wanders, bumps, is parried,
## is backstabbed by Aida (2x + QTE call), is banished and returns after 4 s with a ring; the gate leads to town; F2 still enters the cave.

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func run(arena, ms: float) -> void:
	var n := int(ms / 16.0)
	for i in n:
		arena._process(0.016)

func hud_of(n: Node) -> Node:
	for c in n.get_children():
		if c.has_method("_objective"): return c
		var r := hud_of(c)
		if r != null: return r
	return null

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.ui_root.visible = false
	var P = arena.player
	arena.go_training()
	var G = arena.ghost
	check(P.position.x == 530.0 and G.alive() and G.position.x == 700.0, "she comes in at 530, the ghost is up at 700")
	await process_frame
	check(arena.level == null and arena.train != null and arena.world_w == 2000.0, "training ground: no level, scenery node, 2000 px wide")
	check(arena.platforms.size() == 3, "three plank platforms (ARENA_PLATS)")
	check(arena.dummies.size() == 10 and arena.dummies.filter(func(d): return d.inv).size() == 6, "4 dummies + an unbreakable row of 6")
	check(arena.foes().has(G), "the ghost is a foe")
	check(not ("wave" in arena), "no monster waves")
	run(arena, 3000)
	check(arena.mobs.is_empty(), "nothing spawns in the training ground")

	# ---- a breakable dummy ----
	var d = arena.dummies[1]
	var s0: int = arena.score
	d.hit(99.0, 3.0)
	check(d.is_dead() and not arena.foes().has(d), "a dummy breaks (and is no longer a foe)")
	check(arena.score > s0 and arena.best >= arena.score, "breaking scores: %d best %d" % [arena.score, arena.best])
	for i in 200: d.step(16.0)
	check(not d.is_dead() and d.hp == d.max_hp, "the dummy stands back up after 3 s")
	var inv = arena.dummies[5]
	inv.hit(999.0, 3.0)
	check(inv.alive() and inv.hp == inv.max_hp, "the unbreakable row does not break")

	# ---- the ghost bumps into her ----
	P.inv = 0.0
	P.set_anim("idle")
	G.position.x = P.position.x + 20.0
	G.hurt_t = 0.0
	var hp0: float = P.hp
	G.step(16.0)
	check(P.hp < hp0 and G.hurt_t > 0.0, "the ghost's touch hurts her (%.1f -> %.1f)" % [hp0, P.hp])

	# ---- parry ----
	P.inv = 0.0
	P.hp = P.MAX_HP
	G.hp = G.max_hp
	G.daze = 0.0
	P.dir = 1
	P.set_anim("parry")
	P.f = 0
	G.position.x = P.position.x + 25.0
	G.hurt_t = 0.0
	var gh: float = G.hp
	var sc: int = arena.score
	hp0 = P.hp
	G.step(16.0)
	check(P.hp == hp0 and G.hp < gh and G.hurt_t >= 900.0 and arena.score >= sc + 3, "Estelle's parry on the ghost: no damage, it recoils, +3 (hp %.1f->%.1f ghost %.0f->%.0f hurt %.0f score %d->%d)" % [hp0, P.hp, gh, G.hp, G.hurt_t, sc, arena.score])

	# ---- Aida's backstab ----
	arena.fame.join()     # Eilin's introduction: Aida and Luce join the guild (a fresh game is solo)
	P.party = ["estelle", "aida", "luce"]
	P.swap_cd = 0.0
	P.swap(false, "aida")
	G.hp = G.max_hp
	G.dir = 1
	P.dir = 1
	P.qte_end()
	P.qte["cd"] = 0.0
	G.hit(1.0, 3.0)
	var back: float = G.max_hp - G.hp
	G.hp = G.max_hp
	P.dir = -1
	G.hit(1.0, 3.0)
	var front: float = G.max_hp - G.hp
	check(back >= front * 1.75, "BACKSTAB: from behind %.0f vs facing %.0f" % [back, front])

	# ---- banished, back in 4 s ----
	G.hp = 1.0
	G.hit(5.0, 3.0)
	check(not G.alive() and not arena.foes().has(G), "banished")
	var rings0: int = arena.fx.filter(func(e): return e["k"] == "ring").size()
	for i in 260: G.step(16.0)
	check(G.alive() and G.hp == G.max_hp, "back after 4 s")
	check(absf(absf(G.position.x - P.position.x) - 420.0) < 30.0 or G.position.x < 110.0 or G.position.x > 1890.0, "420 px to one side of her (ghost %.0f, her %.0f)" % [G.position.x, P.position.x])
	check(arena.fx.filter(func(e): return e["k"] == "ring").size() > rings0, "with a ring")

	# ---- it wanders ----
	G.hurt_t = 0.0
	G.daze = 0.0
	P.position.x = 100.0
	G.position.x = 1000.0
	G.dir = -1
	var x0: float = G.position.x
	for i in 30: G.step(16.0)
	check(absf(G.position.x - x0) > 30.0, "the ghost drifts (%.0f -> %.0f)" % [x0, G.position.x])

	# ---- objective line ----
	check(hud_of(arena)._objective() == "유령 퇴치 0 / 1", "objective while the ghost is up")

	# ---- the gate: 길드 마을로 ----
	P.position = Vector2(450.0, arena.ground_y)
	P.on = true
	P.set_anim("idle")
	arena.train.step(16.0)
	check(arena.train.near_door != null and arena.train.near_door["name"] == "길드 마을로", "the gate at x 450")
	arena.try_interact()
	run(arena, 800)
	check(arena.level_kind() == "town" and arena.train == null and not G.alive(), "the gate leads to town; the ghost stays behind")

	# ---- F2 still goes into the cave from the training ground ----
	arena.go_training()
	var e := InputEventKey.new()
	e.keycode = KEY_F2
	e.pressed = true
	arena._unhandled_input(e)
	run(arena, 800)
	check(arena.level_kind() == "dungeon", "F2 from the training ground enters the cave")

	print("FAILS: %d" % fails)
	quit()
