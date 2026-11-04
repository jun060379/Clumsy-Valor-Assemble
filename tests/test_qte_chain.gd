extends SceneTree
## 패링 as everyone's basic QTE condition (owner 2026-11-04): a 교대 패링 (a swap that catches a glint) opens the
## next member's QTE once the gap is over (교대 → 교대); Estelle's guard counts as a parry; a parry ignores the
## QTE cooldown: godot --headless --path . -s tests/test_qte_chain.gd

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

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(3)
	var P = arena.player
	arena.enter_dungeon()
	await frames(20)
	for m in arena.mobs: m.hp = 0.0
	P.party = ["estelle", "aida", "luce"]
	for c in P.party: P.hpm[c] = 100.0
	P.switch_char("estelle")
	var m = arena.spawn("goblin", P.position.x + 140.0, 0.0)
	m.spawn_t = 0.0
	m.hp = 9999.0
	m.max_hp = 9999.0
	await frames(3)

	print("교대 패링 → the next member's QTE")
	P.qte_end()
	P.qte["cd"] = 3000.0
	P.counter_swap(m, "aida")
	ok(P.who == "aida" and not P.cp.is_empty(), "the swap caught the glint: aida sliding in")
	ok(await until(func(): return P.cp.get("hit", false)), "the clash (beat 1 → 2)")
	ok(not P.qte_pend.is_empty(), "its parry waits for the gap")
	ok(m.kx * P.dir > 0.0 and m.tilt != 0.0, "the foe is thrown back on its heels")
	ok(await until(func(): return P.cp.is_empty()), "no press: the window closes, she just stands")
	ok(await until(func(): return P.qte["t"] > 0.0), "after the gap a QTE is up (cooldown ignored)")
	ok(P.qte["who"].has("estelle") and P.qte["who"].has("luce") and not P.qte["who"].has("aida"), "for the others: %s" % str(P.qte["who"]))

	print("Estelle's guard counts as a parry")
	await until(func(): return P.party_lock <= 0.0 and P.anim != "tag_in" and P.anim != "swap_in" and P.cp.is_empty())
	P.qte_end()
	P.qte_gap = 0.0
	P.qte_pend = {}
	P.switch_char("estelle")
	P.inv = 0.0
	P.dir = 1 if m.position.x > P.position.x else -1
	P.set_anim("guard", 1)
	var r: String = P.take_hit(m, 5.0)
	ok(r == "guard", "blocked")
	ok(P.qte["t"] > 0.0 and P.qte["who"].has("aida") and P.qte["who"].has("luce"), "a guard opens the parry QTE: %s" % str(P.qte["who"]))

	print("DONE: %d failed" % fails)
	quit(1 if fails > 0 else 0)
