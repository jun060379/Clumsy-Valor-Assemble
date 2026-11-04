extends SceneTree
## Balance check (headless): each member, Lv1, no gear runes or nodes — 6 s of mashed attack on a still goblin (damage per
## second, sustained) and the ult on one goblin (total). godot --headless --path . -s tools/balance/measure.gd
var arena

func frames(n: int) -> void:
	for i in n: await process_frame

func gob(x: float):
	var m = arena.spawn("goblin", x, 0.0)
	m.hp = 99999.0
	m.max_hp = 99999.0
	m.cd = 999999.0
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0
	return m

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(5)
	arena.fame.join()
	arena.fame.rec = ["estelle", "aida", "luce", "kenin"]
	var P = arena.player
	P.party = ["estelle", "aida", "luce"]
	arena.enter_dungeon()
	await frames(30)
	arena.clear_room()
	var R = arena.runes
	for c in ["estelle", "aida", "luce", "kenin"]:
		for s in R.gear[c]: R.gear[c][s] = null
	var out := []
	for c in ["aida", "kenin", "luce", "estelle"]:
		arena.clear_room()
		if not P.party.has(c): P.party[2] = c
		P.swap_cd = 0.0
		P.party_lock = 0.0
		P.swap(false, c)
		await frames(40)
		P.position.x = 600.0
		P.dir = 1
		var g = gob(P.position.x + (300.0 if c in ["luce", "kenin"] else 90.0))
		await frames(10)
		if c == "kenin": arena.kenin.ammo = arena.kenin.amax()
		var hp0: float = g.hp
		var t0 := Time.get_ticks_msec()
		var game_ms := 0.0
		while game_ms < 6000.0:
			Input.action_press("attack")
			await frames(2)
			Input.action_release("attack")
			await frames(4)
			game_ms += 6.0 * 1000.0 / 60.0
		var dps: float = (hp0 - g.hp) / 6.0
		await frames(60)
		var hp1: float = g.hp
		arena.ult.v[c] = arena.ult.ULTMAX[c]
		arena.ult.cd[c] = 0.0
		if c == "kenin": arena.kenin.marks.clear()
		arena.ult.try_ult()
		var tu := Time.get_ticks_msec()
		while arena.ult.state != "" and Time.get_ticks_msec() - tu < 15000: await process_frame
		await frames(90)
		out.append("%s  공격력 %d  6초 연타 %d (초당 %d)  궁 1대상 %d" % [c, roundi(10.0 * R.stats(c)["atk"]), roundi(hp0 - g.hp - (hp1 - g.hp) + (hp1 - g.hp) * 0.0) , roundi(dps), roundi(hp1 - g.hp)])
		g.queue_free()
	for l in out: print("BAL ", l)
	quit()
