extends SceneTree
## Luce renewal (owner 2026-11-04, 필드 밖 딜포터): her prayer lays 빛의 가호; the one in control's hits draw her
## holy bolts from the bench (at most every 0.5 s) and heal the party; leaving, she hands 강화 on; 구원 shields:
## godot --headless --path . -s tests/test_luce.gd

const ST := preload("res://scripts/status.gd")
var arena
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await process_frame

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(3)
	var P = arena.player
	arena.enter_dungeon()
	await frames(20)
	for m in arena.mobs: m.hp = 0.0
	P.party = ["estelle", "luce", "aida"]
	for c in P.party: P.hpm[c] = 100.0
	P.switch_char("estelle")
	var m = arena.spawn("goblin", P.position.x + 200.0, 0.0)
	m.spawn_t = 0.0
	m.hp = 9999.0
	m.max_hp = 9999.0
	m.cd = 99999.0
	await frames(2)

	print("빛의 가호")
	var n0: int = arena.luce_fx.size()
	m.hit(0.5, 0.0)
	ok(arena.luce_fx.size() == n0, "no blessing: no bolt")
	P.bless_start()
	m.hit(0.5, 0.0)
	ok(arena.luce_fx.size() == n0 + 1 and String(arena.luce_fx.back()["by"]) == "luce", "a hit draws Luce's bolt from the bench")
	m.hit(0.5, 0.0)
	ok(arena.luce_fx.size() == n0 + 1, "within 0.5 s: no second bolt")
	P.hpm["aida"] = 50.0
	P.l_bolt_cd = 0.0
	m.hit(0.5, 0.0)
	ok(P.hpm["aida"] > 50.0, "each bolt heals the bench too")
	var h0: float = m.hp
	for i in 120:
		await process_frame
	ok(m.hp < h0, "the bolt landed (%.0f → %.0f)" % [h0, m.hp])

	print("leaving, she hands 강화 on")
	P.switch_char("luce")
	ST.ally(P)["buff"]["t"] = 0.0
	P.swap_cd = 0.0
	P.party_lock = 0.0
	P.swap(false, "aida")
	ok(ST.atk_k(P) > 1.1, "강화 on the one coming in (x%.2f)" % ST.atk_k(P))

	print("DONE: %d failed" % fails)
	quit(1 if fails > 0 else 0)
