extends SceneTree
## Package F: the bag rebuilt on the prototype's BAG v2 (rows, sub tabs, the spot, equip / melt), the forge on FORGE v2's
## clock (strike at 150 ms, back at 610 ms, ★6 cut-in, engrave after the 380 ms flight, fuse at 420 ms, salvage after
## the cracks, the 500 ms station wipe, the gear pick), the character screen's 상성 card text and scrolling stats,
## the guild book's polaroids.
## godot --headless -s tests/test_pf.gd   (prints PASS / FAIL lines, exits 1 on a failure)

var fails := 0
var arena

func ok(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c: fails += 1

func tick(pg, ms: float, step := 10.0) -> void:
	var n := int(ms / step)
	for i in n: pg._tick(step)

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var R = arena.runes
	var M = arena.ui_root.menu
	for c in ["estelle", "aida", "luce"]:
		if not arena.fame.rec.has(c): arena.fame.rec.append(c)
	arena.fame.bran = true
	R.gearbag.clear()
	R.gearbag.append({"slot": "body", "n": "사슬 갑옷", "g": "common", "wt": "중갑", "lv": 3, "r": 2, "v2": 1})
	R.gearbag.append({"slot": "head", "n": "가죽 두건", "g": "rare", "wt": "경갑", "lv": 3, "r": 1, "v2": 1})
	R.gearbag.append({"slot": "acc", "n": "유리 펜던트", "g": "epic", "lv": 1, "r": 2, "v2": 1})
	R.gearbag.append({"slot": "weapon", "cls": "사제", "n": "축복받은 홀", "g": "legend", "lv": 3, "r": 2, "v2": 1, "rune": "lamp", "rs": 2})
	R.iron = 1234
	R.changed()

	# ---------- 가방 ----------
	M.open_page("bag")
	var B = M.ext["bag"]
	ok(M.page == "bag", "bag opens")
	var L: Array = B.rows()
	ok(L.size() == 3 and L[0]["v"]["g"] == "epic" and L[2]["v"]["g"] == "common", "장비 rows: plain pieces, best grade first")
	B._sub("rune")
	L = B.rows()
	ok(L[0]["grp"] == "on" and L[-1]["grp"] == "off" and L[-1]["v"]["n"] == "축복받은 홀", "룬 각인 장비: worn first, then the bag's")
	B._cat("rune")
	L = B.rows()
	var gord: Array = R.GORD
	var sorted_ok := true
	for i in range(1, L.size()):
		if gord.find(R.RUNE[L[i]["v"]]["g"]) < gord.find(R.RUNE[L[i - 1]["v"]]["g"]): sorted_ok = false
	ok(sorted_ok and L.size() > 0, "보유 룬 sorted by grade")
	B._sub("set")
	L = B.rows()
	ok(L.size() > 0 and L[0]["kind"] == "erune", "각인된 룬 lists engraved runes")
	B._cat("mat")
	L = B.rows()
	ok(L.size() == 2 and L[0]["kind"] == "sh" and B.loc(int(L[0]["v"])) == "1,234", "재화: 실링 1,234 and 기억석")
	B._cat("gear")
	B._sub("plain")
	B._pick(2)
	ok(B.sel == 2 and B.sel_t == 0.0, "picking a row starts its turn")
	# melt the common body (index 2 after sorting): +6 + 3*3 = 15
	var iron0: int = R.iron
	var bi: int = R.gearbag.find(B.rows()[2]["v"])
	R.melt(bi)
	ok(R.iron == iron0 + 15 and R.gearbag.size() == 3, "녹이기 pays meltVal")
	ok(B.bg_slot("acc") == "장신구" and B.bg_slot("acc2") == "장신구 2", "slot names as bgSlot")
	M.page = ""

	# ---------- 대장간 ----------
	M.open_page("forge")
	var F = M.forge
	F.c = "estelle"
	F.slot = "weapon"
	var it: Dictionary = R.gear["estelle"]["weapon"]
	it["rs"] = 2
	R.force_roll = 0.0
	var enh0: int = arena.fame.fc("enh")
	F.do_up()
	ok(F.busy == 1 and F.bran_hit, "strike: Bran's hammer pose up, busy")
	ok(int(it["rs"]) == 3 and int(F.hold.get("rs", 0)) == 2, "the roll is made at the tap; the anvil keeps ★2 until the hit")
	tick(F, 140.0)
	ok(F.stamps.is_empty(), "no banner before 150 ms")
	tick(F, 20.0)
	ok(F.stamps.size() == 1 and F.stamps[0]["s"] == "SUCCESS" and not F.hold.has("rs"), "the hit at 150 ms: SUCCESS, ★3 shown")
	ok(arena.fame.fc("enh") == enh0 + 1, "finc('enh') on a strike")
	tick(F, 460.0)
	ok(F.busy == 0 and not F.bran_hit, "back to the portrait at 610 ms")
	R.force_roll = 0.999
	F.do_up()
	tick(F, 200.0)
	ok(F.stamps[-1]["s"] == "MISS" and F.stamps[-1]["fail"] and int(it["rs"]) == 3, "a miss keeps the star")
	tick(F, 500.0)
	it["rs"] = 6
	R.force_roll = 0.0
	F.do_up()
	ok(F.clk.has("cut") and not F.bran_hit, "★6 and up: the cut-in instead of the pose")
	tick(F, 330.0)
	ok(F.stamps.is_empty() or F.stamps[-1]["s"] != "SUCCESS" or F.stamps[-1]["t0"] < F.t - 300.0, "cut-in: no hit before 340 ms")
	tick(F, 20.0)
	ok(F.stamps[-1]["s"] == "SUCCESS" and int(it["rs"]) == 7, "cut-in: the hit lands at 340 ms")
	tick(F, 600.0)
	ok(F.busy == 0 and not F.clk.has("cut"), "cut-in gone at 920 ms")
	# station change: the rail and slab answer at once, the station snaps in at 500 ms
	F.go_station("eng")
	ok(F.sp == "eng" and F.p == "up" and F.wiping, "wipe: slab first, station still 강화")
	tick(F, 490.0)
	ok(F.p == "up", "still 강화 at 490 ms")
	tick(F, 20.0)
	ok(F.p == "eng" and not F.wiping and F.it_off == 3, "각인 snaps in at 500 ms, its parts 3 steps late")
	# engrave: the rune lands after the 380 ms flight
	var Lr: Array = R.eng_list("estelle", "weapon")
	if not Lr.is_empty():
		F.eng = 0
		var r0: String = Lr[0]
		F.do_eng()
		ok(String(it["rune"]) != r0 or r0 == "firmstep", "the old rune stays during the flight")
		tick(F, 390.0)
		ok(String(it["rune"]) == r0 and int(it["rs"]) == 1 and F.stamps[-1]["s"] == "ENGRAVED", "engraved at 380 ms, ★1")
	tick(F, 400.0)
	# fuse: needs three of a grade
	F.go_station("fuse")
	tick(F, 520.0)
	R.runebag["wall"] = 3
	var G: Array = R.fuse_groups()
	for i in G.size():
		if G[i]["g"] == "rare": F.fz = i
	R.force_roll = 0.0
	var fuse0: int = arena.fame.fc("fuse")
	F.do_fuse()
	tick(F, 410.0)
	ok(F.stamps.is_empty() or F.stamps[-1]["s"] != "FUSED", "fuse: nothing before 420 ms")
	tick(F, 20.0)
	ok(F.stamps[-1]["s"] == "FUSED" and arena.fame.fc("fuse") == fuse0 + 1, "fuse: FUSED at 420 ms, finc('fuse')")
	tick(F, 950.0)
	ok(F.busy == 0, "fuse done after the slots pop back")
	# salvage
	F.go_station("dis")
	tick(F, 520.0)
	var n0: int = R.gearbag.size()
	var V: Array = F._dis_list()
	F.dis_toggle(V[0])
	F.dis_toggle(V[1])
	var iron1: int = R.iron
	F.do_dis()
	tick(F, 2 * 90.0 + 400.0)
	ok(R.gearbag.size() == n0, "salvage pays after the cracks")
	tick(F, 40.0)
	ok(R.gearbag.size() == n0 - 2 and R.iron > iron1 and F.stamps[-1]["s"] == "SALVAGED", "salvaged at n×90+420 ms")
	tick(F, 600.0)
	R.force_roll = -1.0
	# the gear pick
	F.go_station("up")
	tick(F, 520.0)
	F.picking_open()
	ok(F.picking, "anvil tap opens the pick")
	F.gs = "rune"
	F.pick_row(1)
	tick(F, 260.0)
	ok(not F.picking and not (F.c == "estelle" and F.slot == "weapon"), "a row picks another piece after the panel slides out")
	F.back()
	ok(M.page == "", "✕ closes")

	# ---------- 캐릭터 · 상성 ----------
	var CH = load("res://scripts/ui_char.gd")
	var mt: Array = CH.match_text("estelle")
	ok(mt.size() == 2 and mt[0][0] == "물리" and mt[0][1] == " 공격: 유리 없음 / 불리 없음", "상성: 물리 공격: 유리 없음 / 불리 없음")
	ok(mt[1][0] == "받는 피해" and mt[1][1] == ": 약점 없음 / 저항 신성×0.25", "상성: 받는 피해: 약점 없음 / 저항 신성×0.25")
	var ml: Array = CH.match_text("luce")
	ok(ml[0][1].begins_with(" 공격: 신성 약점인 대상"), "상성: 신성 공격 line")
	var ma: Array = CH.match_text("aida")
	ok(ma.size() == 3 and ma[0][0] == "어둠" and ma[0][1] == " 공격: 유리 신성 / 불리 어둠", "상성: 아이다 어둠 공격")

	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
