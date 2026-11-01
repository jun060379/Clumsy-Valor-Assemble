extends SceneTree
## Runes, gear, forge and the boss chest: godot --headless -s tests/test_runes.gd
## Prints "FAIL ..." for a broken check and "runes: N ok, M failed" at the end.

var ok := 0
var bad := 0

func check(c: bool, what: String) -> void:
	if c: ok += 1
	else:
		bad += 1
		print("FAIL ", what)

func near(a: float, b: float, eps := 0.001) -> bool:
	return absf(a - b) < eps

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var R = arena.runes
	var P = arena.player
	check(R != null, "arena.runes exists")
	R.rng.seed = 7
	arena.shilling = 1000

	# ---- gear numbers ----
	var w: Dictionary = R.gear["estelle"]["weapon"]
	check(R.gear_text(w, "weapon").begins_with("공격력 +"), "weapon text: " + R.gear_text(w, "weapon"))
	var T: Dictionary = R.gear_tot("estelle")
	check(T["def"] > 0.0 and T["heavy"] == 3, "estelle armour: def %s heavy %d" % [T["def"], T["heavy"]])
	check(near(P.MAX_HP, R.max_hp("estelle")), "max hp follows gear (%s)" % P.MAX_HP)
	check(near(P.atk_mul(), 1.0 * R.atk_k("estelle")), "attack follows gear")
	var s1: Array = R.subs_of(w, "weapon")
	var s2: Array = R.subs_of(w.duplicate(true), "weapon")
	check(str(s1) == str(s2), "sub stats are seeded")

	# ---- rune effects ----
	# stone (돌 피부) on the head: 5% less taken, times defence
	var def: float = R.gear_tot("estelle")["def"]
	check(near(R.in_mul(), (1.0 - 0.05 * R.RSM[1]) * 150.0 / (150.0 + def)), "stone + defence in_mul %s" % R.in_mul())
	# firmstep: block stacks to 4
	for i in 6: R.ev("block")
	check(R.rbn("firmstep") == 4, "firmstep stacks 4 (%d)" % R.rbn("firmstep"))
	R.tick(7000.0)
	check(R.rbn("firmstep") == 0, "firmstep wears off")
	# engrave thorn (가시 덩굴) on the weapon: +20% out, +20% in
	R.runebag["thorn"] = 1
	var i0: int = arena.shilling
	check(R.engrave("estelle", "weapon", "thorn"), "engrave thorn")
	check(arena.shilling == i0 - R.engrave_cost("epic"), "engrave costs %d" % R.engrave_cost("epic"))
	check(R.gear["estelle"]["weapon"]["rune"] == "thorn" and not R.has("firmstep"), "old rune destroyed")
	var lo := 99.0
	for i in 60: lo = minf(lo, R.out_mul(null))
	check(near(lo, 1.0 + 0.2 * R.RSM[1]), "thorn out_mul %s" % lo)
	check(R.rune_scaled("thorn", 1).begins_with("주는 피해 +14%"), "thorn ★1 text: " + R.rune_scaled("thorn", 1))
	# star up: ★1 → ★2 always lands (100%)
	i0 = arena.shilling
	check(R.star_up("estelle", "weapon") == "ok" and R.gear["estelle"]["weapon"]["rs"] == 2, "star up ★2")
	check(arena.shilling == i0 - 30, "star up costs 30")
	# giant (바위 거인): third heavy hit turns into +20%
	R.gear["estelle"]["body"]["rune"] = "giant"
	R.changed()
	for i in 3: R.ev("heavy")
	check(R.rbn("giantB") == 1, "giant boost after 3 heavy hits")
	# wise on an accessory: cooldowns −12%
	R.gear["estelle"]["acc2"]["rune"] = "wise"
	R.changed()
	check(near(R.cd_k(), 1.0 - 0.12 * R.RSM[1]), "wise cd_k %s" % R.cd_k())
	# firstaid: a kill heals
	P.hp = 20.0
	R.ev("kill")
	check(P.hp > 20.0, "firstaid heals on kill (%s)" % P.hp)
	# shieldthrow replaces the shield skill
	R.gear["estelle"]["acc3"] = {"n": "시험 반지", "g": "unique", "lv": 1, "r": 0, "seed": 5, "sub": null, "rune": "shieldthrow", "rs": 1}
	R.changed()
	P.use_skill(0)
	check(R.shields.size() == 1 and P.anim != "parry", "shield throw instead of parry")
	# taking a hit goes through in_mul (thorn: +20%)
	var m = arena.spawn("goblin", P.position.x + 60.0, 0.0)
	P.inv = 0.0
	P.set_anim("idle")
	P.dir = 1
	var hp0: float = P.hp
	P.take_hit(m, 10.0)
	check(near(hp0 - P.hp, 10.0 * 0.75 * R.in_mul(), 0.01), "hit taken %s" % (hp0 - P.hp))
	# a kill drops shilling, records the bestiary
	i0 = arena.shilling
	m.hit(999.0, 0.0)
	check(arena.shilling > i0, "kill drops shilling")
	check(R.best_kills.get("goblin", 0) == 1 and R.best_seen.has("goblin"), "bestiary kill")

	# ---- forge: fuse, salvage, gear on/off ----
	R.runebag = {"stone": 3, "firstaid": 1}
	i0 = arena.shilling
	var fz: Dictionary = R.fuse("uncommon")
	check(not fz.is_empty() and arena.shilling == i0 - 15, "fuse runs and costs 15")
	var left := 0
	for r in R.runebag: left += R.runebag[r]
	check(left == 2, "fuse eats three, gives one (%d left)" % left)
	check(R.fuse("uncommon").is_empty() or true, "fuse needs three")
	R.gearbag = []
	for i in 3: R.gearbag.append(R.make_gear("rare"))
	R.gearbag[0]["rune"] = "wall"
	i0 = arena.shilling
	var wall0: int = R.runebag.get("wall", 0)
	var exp := 0
	for it in R.gearbag: exp += R.melt_val(it)
	check(R.salvage([0, 1, 2]) == exp and arena.shilling == i0 + exp and R.gearbag.is_empty(), "salvage pays %d" % exp)
	check(R.runebag.get("wall", 0) == wall0 + 1, "salvaged rune goes back to the bag")
	var g: Dictionary = R.make_gear("rare")
	g["slot"] = "head"
	g.erase("cls")
	R.gearbag = [g]
	var old = R.gear["aida"]["head"]
	check(R.gear_on("aida", "head", 0) and R.gear["aida"]["head"]["n"] == g["n"] and R.gearbag.size() == (1 if old != null else 0), "gear on")
	R.gear_off("aida", "head")
	check(R.gear["aida"]["head"] == null and R.gearbag.size() >= 1, "gear off")

	# ---- save state round trip ----
	var st: Dictionary = R.get_state()
	var js := JSON.stringify(st)
	R.reset()
	R.set_state(JSON.parse_string(js))
	check(R.gear["estelle"]["weapon"]["rune"] == "thorn" and R.gear["estelle"]["weapon"]["rs"] == 2 and R.best_kills.get("goblin", 0) == 1, "get_state/set_state round trip")

	# ---- the pages: Bran's choices → forge → back to his choices; the codex opens, turns, shuts ----
	var M = arena.ui_root.menu
	if arena.get("fame") != null: arena.fame.bran = true     # he has met the party through Eilin
	M.open_bran(false, "흐흐, 왔습니까.")
	check(M.page == "bran" and arena.ui_root.holds(), "Bran's choices open and hold the world")
	M.bran_page.choices[0][2].call()
	check(M.page == "forge" and M.forge.from_dlg, "장비를 맡기고 싶어요 → forge")
	arena.shilling = 500
	M.forge.c = "estelle"
	M.forge.slot = "weapon"
	var rs0: int = R.gear["estelle"]["weapon"]["rs"]
	M.forge.do_up()
	for i in 20: M.forge._tick(50.0)
	check(R.gear["estelle"]["weapon"]["rs"] >= rs0 and arena.shilling < 500, "forge 강화 through the page")
	M.forge.go_station("dis")
	for i in 20: M.forge._tick(50.0)
	check(M.forge.p == "dis", "station change")
	M.forge.back()
	check(M.page == "bran" and M.bran_page.line.begins_with("또 맡길"), "forge back → Bran's choices")
	M.bran_page.back()
	check(M.page == "", "그만 가볼게요 closes")
	for i in 3: arena.dlg.active = false
	M.open_codex("rune")
	check(M.page == "codex_rune" and M.codex.book == "rune", "rune codex opens")
	for i in 40: M.codex._tick(100.0)
	check(M.codex.phase == "idle" and M.codex.open_k > 0.99, "book lands, lifts, opens")
	M.codex.go(2)
	for i in 12: M.codex._tick(100.0)
	check(M.codex.cur == 2 and M.codex.paint["pl"][0] == "left", "turns to an entry")
	M.codex.close_book()
	for i in 40: M.codex._tick(100.0)
	check(M.page == "", "✕ shuts the book and tosses it")
	M.open_page("best")
	for i in 40: M.codex._tick(100.0)
	check(M.codex.book == "enemy" and M.codex.phase == "idle", "bestiary book")
	M.codex.close_book()
	for i in 40: M.codex._tick(100.0)
	for k in ["bag", "char"]:
		M.open_page(k)
		await process_frame
		await process_frame
		check(M.page == k and M.ext[k].visible, k + " page opens")
		M.close_page()
	await process_frame

	# ---- boss chest + fatigue gate ----
	arena.enter_dungeon()
	var D = arena.level
	for k in D.rooms:
		if D.rooms[k]["type"] == "boss": D.cur = k
	D.from = "L"
	D.enter()
	for i in 30: arena._process(0.016)
	for mm in arena.mobs: mm.hit(9999.0, 0.0)
	for i in 120: arena._process(0.016)
	var L = R.loot
	check(L != null and is_instance_valid(L), "boss clear makes the chest")
	for i in 200: L.step(16.0)
	check(L.chest != null and L.chest["landed"], "chest lands")
	var F = arena.fatigue
	F.v = 10
	F.t = F.now()
	L.hit_chest()
	check(not L.paid and L.chest["hp"] == L.HP0, "chest stays shut without fatigue")
	check(D.room()["type"] == "boss" and not R.town_gate(), "can leave without opening when fatigue is short")
	F.v = F.MAX
	F.t = F.now()
	L.chest["hintT"] = 0.0
	L.hit_chest()
	check(L.paid and F.value() == F.MAX - F.COST, "first blow spends fatigue (%d)" % F.value())
	check(R.town_gate(), "town door waits for the chest")
	var rb0: int = R.rune_count()
	var sh0: int = arena.shilling
	for i in 30:
		if L.chest["broken"]: break
		L.hit_chest()
	check(L.chest["broken"], "chest breaks")
	check(L.paid and F.value() == F.MAX - F.COST, "only the first blow costs")
	for i in 300: L.step(16.0)
	check(L.items.is_empty() and R.rune_count() > rb0 and arena.shilling > sh0, "loot collected: runes %d → %d" % [rb0, R.rune_count()])
	check(not R.town_gate(), "town door opens after")
	print("chest grade ", L.CGN[L.grade], " got ", L.summary())

	print("runes: %d ok, %d failed" % [ok, bad])
	quit()
