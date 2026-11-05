extends SceneTree
## (owner 2026-11-05) a QTE answered by Aida with a 무방비 foe in reach comes in as 처형, not the tag-in blow:
## godot --headless --path . -s tests/test_qte_exec.gd
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
	P.party = ["estelle", "aida", "luce"]
	for c in P.party: P.hpm[c] = 100.0
	P.switch_char("estelle")
	var m = arena.spawn("goblin", P.position.x + 160.0, 0.0)
	m.spawn_t = 0.0
	m.hp = 9999.0
	m.max_hp = 9999.0
	await frames(5)
	# plain QTE (no opening): the tag-in blow
	P.qte_gap = 0.0
	P.qte["cd"] = 0.0
	P.qte_offer("parry")
	await frames(2)
	P.party_input("aida")
	await frames(2)
	ok(P.who == "aida" and P.anim == "tag_in", "no opening: the usual tag-in (%s)" % P.anim)
	for i in 120: await process_frame
	P.switch_char("estelle")
	P.set_anim("idle")
	P.party_lock = 0.0
	await frames(10)
	# with the goblin staggered (무방비): 처형
	ST.add(arena, m, "stagger", 100.0, "estelle")
	P.a_exec_cd = 0.0
	P.qte_end()
	P.qte_gap = 0.0
	P.qte["cd"] = 0.0
	P.qte_offer("parry")
	await frames(2)
	ok(ST.exposed(m), "the goblin is 무방비")
	P.party_input("aida")
	await frames(2)
	ok(P.who == "aida" and not P.a_exec.is_empty() and P.anim.begins_with("ax_"), "an opening: Aida comes in with 처형 (%s)" % P.anim)
	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
