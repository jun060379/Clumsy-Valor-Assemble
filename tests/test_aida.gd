extends SceneTree
## Aida renewal (owner 2026-11-04, 빈틈 처형형): 3타 lifts a small foe (a boss: groggy), one more press → the
## empowered follow-up rift strike; a 무방비 foe ahead → the strike goes out at once, empowered; +20% on 무방비;
## her 남은 균열 bursts after a swap-out and lifts; a foe going 무방비 opens her QTE from the bench:
## godot --headless --path . -s tests/test_aida.gd

const ST := preload("res://scripts/status.gd")
var arena
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await process_frame

func until(cond: Callable, ms := 4000.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() - t0 > ms / Engine.time_scale + 2000: return false
	return true

func gob(x: float, kind := "goblin"):
	var m = arena.spawn(kind, x, 0.0)
	m.spawn_t = 0.0
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
	arena.enter_dungeon()
	await frames(20)
	for m in arena.mobs: m.hp = 0.0
	if arena.get("runes") != null: arena.runes.force_roll = 0.999
	P.party = ["aida", "estelle", "luce"]
	for c in P.party: P.hpm[c] = 100.0
	P.switch_char("aida")
	await frames(2)

	print("3타 lifts, the follow-up is empowered")
	var a = gob(P.position.x + 110.0)
	P.dir = 1
	P.aida_launch(a)
	ok(ST.has(a, "air") and not P.a_follow.is_empty(), "lifted, the follow-up window open")
	P.set_anim("idle")
	Input.action_press("attack")
	var got := false
	for i in 6:
		await process_frame
		if not P.a_exec.is_empty(): got = true
	Input.action_release("attack")
	ok(got, "one more press → 처형 (the empowered strike's own motion)")
	var h0: float = a.hp
	await until(func(): return P.a_exec.is_empty())
	ok(P.a_exec.is_empty() and a.hp < h0 and P.on, "it rose, slammed and landed (hp %.0f → %.0f)" % [h0, a.hp])

	print("a boss is not lifted (groggy instead)")
	var bs = gob(P.position.x + 500.0, "boss")
	P.aida_launch(bs)
	ok(not ST.has(bs, "air") and float(ST.of(bs).get("groggy", {}).get("g", 0.0)) > 0.0, "boss: groggy gauge")

	print("무방비 ahead: no gathering")
	var b = gob(P.position.x + 200.0)
	ST.add(arena, b, "stagger", 100.0, "estelle")
	P.dir = 1
	ok(P.aida_emp_target() == b, "the staggered foe is her target (sigil)")
	ok(is_equal_approx(arena.runes.out_mul(b), arena.runes.out_mul(a) * (1.2 if not ST.exposed(a) else 1.0)) or arena.runes.out_mul(b) > 1.15, "+20% on 무방비")

	print("남은 균열")
	await until(func(): return P.party_lock <= 0.0 and P.anim in ["idle", "run", "stop"])
	var c = gob(P.position.x + 30.0)
	P.swap_cd = 0.0
	P.swap(false, "estelle")
	ok(not P.a_left.is_empty(), "left where she swapped out")
	await until(func(): return P.a_left.is_empty())
	ok(ST.has(c, "air") or c.position.y < P.position.y - 5.0 or float(ST.of(c).get("air", {}).get("hits", -1)) >= 0, "it burst and lifted the foe")

	print("a foe going 무방비 opens 기습 from the bench")
	P.qte_end()
	P.qte_gap = 0.0
	P.qte["cd"] = 0.0
	var d = gob(P.position.x + 300.0)
	ST.add(arena, d, "stagger", 100.0, "estelle")
	ok(P.qte["t"] > 0.0 and P.qte["who"].has("aida"), "QTE for aida: %s" % str(P.qte["who"]))

	print("DONE: %d failed" % fails)
	quit(1 if fails > 0 else 0)
