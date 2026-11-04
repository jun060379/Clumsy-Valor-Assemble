extends SceneTree
## Estelle renewal (owner 2026-11-04): her blows build 경직, a block builds 경직 and a shield, a parry 60 / a perfect
## parry 100, other members build none; 용감한 희생 turns 수호 into a covering guard from the bench:
## godot --headless --path . -s tests/test_estelle.gd

const ST := preload("res://scripts/status.gd")
var arena
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await process_frame

func gob(x: float):
	var m = arena.spawn("goblin", x, 0.0)
	m.spawn_t = 0.0
	m.hp = 9999.0
	m.max_hp = 9999.0
	m.cd = 99999.0
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0
	return m

func g(m) -> float:
	return float(ST.of(m).get("stagger", {}).get("g", 0.0))

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

	print("her blows build 경직")
	var a = gob(P.position.x + 400.0)
	P.anim = "attack1"
	P.estg(a, P._estg_of())
	ok(is_equal_approx(g(a), 8.0), "1타 +8 (%.0f)" % g(a))
	P.anim = "attack3"
	P.estg(a, P._estg_of())
	ok(is_equal_approx(g(a), 28.0), "3타 +20")
	P.estg(a, P.E_STG["pparry"])
	ok(ST.has(a, "stagger"), "a perfect parry fills it: 경직")

	print("a block: 경직 + a shield")
	var b = gob(P.position.x + 120.0)
	P.inv = 0.0
	ST.ally(P)["shield"] = 0.0
	P.dir = 1
	P.set_anim("guard", 1)
	ok(P.take_hit(b, 20.0) == "guard", "blocked")
	ok(g(b) > 0.0 and float(ST.ally(P)["shield"]) > 0.0, "gauge %.0f, shield %.1f" % [g(b), float(ST.ally(P)["shield"])])

	print("other members build none")
	var c = gob(P.position.x + 600.0)
	P.switch_char("aida")
	P.anim = "attack1"
	ok(is_equal_approx(P._estg_of() if P.who == "estelle" else 0.0, 0.0), "aida's blows: 0")

	print("용감한 희생: the covering guard")
	var M = arena.runes.memory
	M.tree["estelle"]["lv"] = 12
	M.clear_nodes("estelle")
	for id in ["C0", "C1", "C2", "C3", "C5"]: M.take("estelle", id)
	ok(P.stays("estelle"), "her QTE stays on the bench")
	ST.ally(P)["shield"] = 0.0
	P.qte["hit"] = {"raw": 10.0, "taken": 10.0, "victim": "aida"}
	P.qte["t"] = 1000.0
	P.qte["who"] = ["estelle"]
	P.bench_assist("estelle", c)
	ok(P.who == "aida" and P.e_guard_t > 0.0, "aida stays, Estelle guards")
	ok(is_equal_approx(float(ST.ally(P)["shield"]), 10.0), "what aida took comes back as a shield")
	ok(g(c) > 0.0 or ST.has(c, "stagger"), "the foe ahead staggers")
	P.inv = 0.0
	var hp0: float = P.hp
	ok(P.take_hit(c, 30.0) == "parry" and is_equal_approx(P.hp, hp0), "the next blow is hers (no damage, a parry)")

	print("DONE: %d failed" % fails)
	quit(1 if fails > 0 else 0)
