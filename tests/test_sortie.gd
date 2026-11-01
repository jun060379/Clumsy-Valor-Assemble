extends SceneTree
## Sortie flow end to end, 기력 / ult, element multipliers, party screen, save round trip:
## godot --headless --path . -s tests/test_sortie.gd

const EL := preload("res://scripts/elements.gd")

var arena
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func frames(n: int) -> void:
	for i in n: await process_frame

## wait until cond() (at most ms of game time)
func until(cond: Callable, ms := 15000.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() - t0 > ms / Engine.time_scale + 2000: return false
	return true

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	Engine.time_scale = 4.0
	await frames(3)
	var P = arena.player
	var S = arena.sortie
	ok(arena.level_kind() == "town", "starts in town")

	print("elements")
	ok(is_equal_approx(EL.eff_mul("holy", ["dark"]), 1.75) and is_equal_approx(EL.eff_mul("holy", ["phys"]), 0.25), "holy x1.75 on dark, x0.25 otherwise")
	ok(is_equal_approx(EL.eff_mul("fire", ["ice", "plant"]), 2.25), "multiplies over several own elements")
	var E: Dictionary = EL.damage(10.0, "aida", ["dark", "phys"])
	ok(E["dmg"] == 8.0 and E["parts"].size() == 2, "Aida's hybrid hit splits (dark 3 + phys 5 = %d)" % E["dmg"])
	ok(is_equal_approx(EL.taken_mul("dark", "luce"), 1.5) and is_equal_approx(EL.taken_mul("phys", "estelle"), 1.0), "mob attack element vs member (dark on Luce x1.5)")

	print("sortie: wagon -> dungeon select -> launch -> sweep -> dun card -> dash in -> deploy cut")
	S.open_dsel(0)
	ok(S.dsel.open and S.holds(), "dungeon select open, world held")
	var seen_before: bool = S.tc.seen.has("dun_cave")
	S.dsel.do_launch()
	ok(await until(func(): return S.swp["on"]), "launch -> band sweep")
	ok(await until(func(): return arena.level_kind() == "dungeon"), "under the black band: into the cave")
	ok(await until(func(): return S.tc.active and S.tc.kind == "dun"), "'dun' title card on the band")
	ok(not seen_before and S.tc.seen.has("dun_cave"), "first visit marked seen")
	ok(abs(P.position.x - 32.0) < 2.0, "dinPrep: at the very edge (x %.0f)" % P.position.x)
	ok(await until(func(): return S.din["on"] == 1), "bands peel, she dashes in")
	ok(await until(func(): return S.dpl["on"]), "skids to a stop: deploy cut")
	ok(abs(P.position.x - S.din["to"]) < 2.0 and P.anim == "stop", "stopped at %.0f" % P.position.x)
	ok(await until(func(): return S.din["on"] == 0 and not S.swp["on"] and not S.dpl["on"]), "sortie flow finished")

	print("elements in the cave")
	var D = arena.level
	arena.clear_room()
	var m = arena.spawn("eye", P.position.x + 120.0, 0.0)
	await frames(2)
	var h0: float = m.hp
	P.switch_char("luce")
	P.set_anim("idle", 0)
	m.hit(1.0, 0.0, 1.0)
	ok(is_equal_approx(h0 - m.hp, 18.0), "Luce's holy on the dark eye: 10 x 1.75 -> %.0f" % (h0 - m.hp))
	P.switch_char("estelle")
	P.set_anim("idle", 0)
	var g = arena.spawn("goblin", P.position.x + 120.0, 0.0)
	await frames(2)
	var g0: float = g.hp
	g.hit(1.0, 0.0, 1.0)
	# phys on a phys mob is x1: the hit is the base 10 times her own gear/level/crit multipliers only (no element change)
	var own: float = arena.runes.out_mul(g) if arena.get("runes") != null else 1.0
	ok(g0 - g.hp >= 10.0 * own - 0.01, "Estelle's phys on the goblin: x1 (before her own bonuses) -> %.0f" % (g0 - g.hp))

	print("기력 / ult")
	var U = arena.ult
	for c in U.v: U.v[c] = 0.0
	for c in U.cd: U.cd[c] = 0.0
	U.gain(100.0)
	ok(is_equal_approx(U.v["estelle"], 100.0) and is_equal_approx(U.v["aida"], 40.0), "gain: leader +100, bench +40 (x0.4)")
	ok(not U.try_ult(), "not ready below the max")
	for c in ["estelle", "aida", "luce"]:
		arena.clear_room()
		var tg = arena.spawn("skel", P.position.x + 140.0, 0.0)
		P.dir = 1
		await frames(2)
		P.switch_char(c)
		P.set_anim("idle", 0)
		U.v[c] = U.ULTMAX[c]
		U.cd[c] = 0.0
		var th: float = tg.hp
		ok(U.try_ult() and U.state == "cut", c + ": ult fires, cut-in")
		ok(await until(func(): return U.state == "act"), c + ": cut-in ends, the move plays")
		ok(await until(func(): return U.state == ""), c + ": move ends")
		ok(U.cd[c] > 20000.0 and U.v[c] == 0.0, c + ": gauge spent, 30 s cooldown")
		ok(tg.hp < th, c + ": the move hit (%.0f -> %.0f)" % [th, tg.hp])
		if c == "estelle":
			ok(U.auto_t > 0.0, "estelle: 8 s auto-parry running")
			P.inv = 0.0
			var r: String = P.take_hit(tg, 10.0)
			ok(r == "parry", "estelle: a blow during the vow is parried (%s)" % r)
			U.auto_t = 0.0
	P.switch_char("estelle")
	P.set_anim("idle", 0)

	print("boss card, clear screen, RETURN sweep")
	var bk := ""
	for k in D.rooms:
		if D.rooms[k]["type"] == "boss": bk = k
	D.from = "L"
	D.cur = bk
	arena.fade_then(func(): D.enter())
	ok(await until(func(): return S.tc.active and S.tc.kind == "boss"), "uncleared boss room -> 'boss' card")
	var bx: float = P.position.x
	await frames(5)
	ok(P.position.x == bx, "world held under the card")
	S.tc.finish()
	ok(await until(func(): return not S.tc.active), "card skipped")
	P.inv = 1.0e9
	ok(await until(func():
		for mm in arena.mobs: mm.hit(9999.0, 0.0)
		return D.room()["cleared"]), "boss down, room cleared")
	P.inv = 0.0
	# the boss chest (runes.gd loot): break it open first, as a player would, so the town door lets you go
	if arena.get("runes") != null and arena.runes.loot != null:
		var L = arena.runes.loot
		L.step(1300.0)
		for i in 60:
			L.step(50.0)
			if L.chest != null and L.chest["landed"]: break
		for i in 40:
			if L.chest == null or L.chest["broken"]: break
			L.hit_chest()
			L.step(400.0)
		ok(L.chest != null and L.chest["broken"], "boss chest broken open")
		L.items.clear()             # (the player would walk over and pick the drops up)
	var td = null
	for d in D.doors:
		if d["town"]: td = d
	D.near_gate = td
	D.try_interact()
	ok(S.clear.open, "town door in the cleared boss room -> clear screen")
	await frames(30)
	S.clear.leave()
	ok(await until(func(): return S.swp["on"]), "go -> RETURN sweep")
	ok(await until(func(): return arena.level_kind() == "town"), "back in town")
	ok(await until(func(): return not S.swp["on"] and not S.clear.open), "sweep and clear screen gone")
	ok(abs(P.position.x - S.town_x) < 2.0, "at the wagon again (x %.0f)" % P.position.x)

	print("edge sortie: run out, run back in")
	P.position = Vector2(31.0, arena.level.floor_at(31.0))
	S.open_dsel(-1)
	S.dsel.do_launch()
	ok(await until(func(): return S.run["on"]), "off the left edge: she runs out")
	ok(await until(func(): return arena.level_kind() == "dungeon"), "then the sweep into the cave")
	S.tc.finish()
	ok(await until(func(): return S.din["on"] == 0 and not S.swp["on"] and S.dpl["on"] == false), "entry done")
	S.go_town()
	ok(await until(func(): return S.rin["on"]), "RETURN: runs in from the left edge")
	ok(await until(func(): return not S.rin["on"]), "run-in done")
	ok(abs(P.position.x - 160.0) < 2.0, "stops at x 160 (%.0f)" % P.position.x)

	print("party screen")
	await until(func(): return not S.swp["on"])
	S.party_ui.show_it()
	ok(S.holds(), "party screen holds the world")
	P.party = ["estelle", "aida", "luce"]
	P.switch_char("estelle")
	P.set_anim("idle", 0)
	var n0: int = P.party.size()
	S.party_ui.press("luce", "out")
	ok(not P.party.has("luce") and P.party.size() == n0 - 1, "luce out")
	S.party_ui.press("estelle", "out")
	ok(P.party.has("estelle"), "the one in control can't leave")
	S.party_ui.press("aida", "out")
	S.party_ui.press("estelle", "out")
	ok(P.party == ["estelle"], "at least one member stays (%s)" % str(P.party))
	S.party_ui.press("luce", "in")
	ok(P.party.has("luce"), "luce back in")
	S.party_ui.press("luce", "ctl")
	ok(P.who == "luce", "조작: luce takes control")
	S.party_ui.close()

	print("save round trip")
	arena.tod_h = 7.25
	U.v["aida"] = 123.0
	S.tc.seen["dun_cave"] = 1
	ok(arena.save.save(), "saved")
	var snap: Dictionary = arena.save.snapshot()
	arena.tod_h = 20.0
	U.v["aida"] = 0.0
	P.party = ["estelle", "aida", "luce"]
	S.tc.seen = {}
	var d0 = arena.save.read()
	ok(d0 is Dictionary and d0["v"] == 1, "read back")
	var sc: Array = arena.save.apply(d0)
	ok(is_equal_approx(arena.tod_h, 7.25), "clock restored")
	ok(P.party == snap["party"], "party restored %s" % str(P.party))
	ok(is_equal_approx(U.v["aida"], 123.0), "기력 restored")
	ok(S.tc.seen.has("dun_cave"), "title cards seen restored")
	ok(sc[0] == "town" and abs(sc[1].x - snap["x"]) < 1.0 and P.who == snap["who"], "scene / position / leader restored %s" % str(sc))
	ok(not d0.has("fame") or arena.get("fame") != null, "fame only saved when the system exists")

	Engine.time_scale = 1.0
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
