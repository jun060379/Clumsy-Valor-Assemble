extends SceneTree
## Character levels and the memory tree (memory.gd), its combat hooks, fame's chapter tasks, save/load, the 스킬 · 기억 · 기록 tabs:
## godot --headless -s tests/test_memory.gd   → "memory: N ok, M failed"

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
	var M = R.memory
	var P = arena.player
	var MD = M.MD
	R.rng.seed = 11
	M.reset()
	R.mem = 0
	R.mats["lamp"] = 0
	R.changed()

	# ---- levels ----
	check(M.lv("estelle") == 1 and near(M.lvm("estelle"), 1.0) and M.pts_left("estelle") == 0, "starts at Lv1, ×1, no points")
	var hp1: float = R.max_hp("estelle")
	check(M.level_up("estelle") == "nomem", "no 기억석 → no level")
	R.mem = 100
	check(M.level_up("estelle") == "lv" and R.mem == 88 and M.lv("estelle") == 2, "Lv2 costs 12 (mem %d)" % R.mem)
	check(near(M.lvm("estelle"), 1.15) and near(R.lvm("estelle"), 1.15), "LVM 1.15 at Lv2")
	var B: Dictionary = R.CH.STATS["estelle"]
	check(near(R.max_hp("estelle"), roundf(B["hp"] * 1.15) + R.gear_tot("estelle")["hp"]), "max HP grows with the level (%s → %s)" % [hp1, R.max_hp("estelle")])
	check(near(P.MAX_HP, R.max_hp("estelle")), "her MAX_HP follows")
	check(near(R.atk_k("estelle"), (1.0 + R.gear_tot("estelle")["atk"] / 100.0) * 1.15), "attack ×1.15")
	check(M.level_up("estelle") == "lv" and R.mem == 72 and M.lv("estelle") == 3, "Lv3 costs 16")
	check(not M.brk_need("estelle").is_empty() and M.brk_need("estelle")["m"] == "lamp", "돌파 at Lv3 needs the lamp")
	check(M.lv_preview("estelle").begins_with("Lv4 점프 · 체력 %d · 공격 ×1.6 · 노드 II 단계" % roundi(B["hp"] * 1.6)), "preview: " + M.lv_preview("estelle"))
	check(M.level_up("estelle") == "nomat" and M.lv("estelle") == 3, "no lamp → stuck at Lv3")
	R.mats["lamp"] = 4
	check(M.level_up("estelle") == "brk" and R.mats["lamp"] == 1 and M.lv("estelle") == 3 and M.any_break(), "돌파 eats 3 lamps")
	check(M.level_up("estelle") == "lv" and M.lv("estelle") == 4 and R.mem == 52, "then Lv4 for 20")
	check(MD.LVCUM[12] == 594 and M.lv_cost(11) == 130, "the ladder: 594 in all, Lv11→12 130")
	check(M.brk_need("aida").is_empty() and MD.BRKC["aida"][3]["m"] == "grave", "Aida breaks through with 묘역의 무언가")

	# ---- nodes ----
	check(M.pts_left("estelle") == 3, "3 points at Lv4")
	check(M.can_take("estelle", "A0") and M.take("estelle", "A0"), "take A0 (tier I)")
	check(not M.can_take("estelle", "A3"), "A3 needs 2 in 검")
	check(M.node_need("estelle", "A3", ["A0", "A3"]).begins_with("검에 2포인트 필요"), "A3 reason: " + M.node_need("estelle", "A3", ["A0", "A3"]))
	check(M.take("estelle", "A1") and M.take("estelle", "A3"), "A1 then A3")
	check(M.pts_left("estelle") == 0 and not M.can_take("estelle", "B0"), "points spent")
	check(M.held("estelle", "A0") and not M.drop("estelle", "A0"), "A0 holds A3 up: cannot drop")
	check(M.node_need("estelle", "A5", ["A0", "A1", "A3", "A5"]) == "Lv 7에 열림", "A5 opens at Lv7")
	check(M.node_need("estelle", "X0", ["X0"]) == "Lv 5에 열림", "cross nodes at Lv5")
	check(M.tier_name("estelle", "X3") == "혼합 · 검 1 + 방패 1 + 의지 1" and M.tier_name("estelle", "B6") == "방패 · KEY", "tier tags")
	# effects: 밤의 훈련 (+10% normal), 한 걸음 더 (+15% heavy), 될 때까지 (every 3rd normal hit ×1.5)
	P.anim = "attack1"
	var o1: float = M.out_mul("estelle", null)
	check(near(o1, 1.1), "normal hit ×1.1 (%s)" % o1)
	var e = arena.mobs[0] if arena.mobs.size() > 0 else null
	if e == null:
		e = Node2D.new()
		e.set_script(load("res://scripts/mob.gd"))
	M.combo = 0
	var hits: Array = []
	for i in 3: hits.append(M.out_mul("estelle", e))
	check(near(hits[0], 1.1) and near(hits[2], 1.65), "third normal hit ×1.5 %s" % str(hits))
	P.anim = "cthrust"
	check(near(M.out_mul("estelle", e), 1.15), "charged ×1.15")
	P.anim = "idle"
	check(M.clear_nodes("estelle") and M.pts_left("estelle") == 3, "초기화 gives the points back")

	# 빈틈 (renewal): +15% on a 무방비 foe (경직 · 띄움 · 그로기)
	M.take("estelle", "A2")
	check(near(M.out_mul("estelle", e), 1.0), "빈틈: nothing on a foe standing")
	e.set_meta("st", {"stagger": {"t": 1000.0}})
	check(near(M.out_mul("estelle", e), 1.15), "빈틈: ×1.15 on a staggered foe")
	e.remove_meta("st")
	# 버티는 몸 (+10 HP) is a stat node
	M.clear_nodes("estelle")
	var h0: float = R.max_hp("estelle")
	M.take("estelle", "B2")
	check(near(R.max_hp("estelle"), roundf(R.CH.STATS["estelle"]["hp"] * M.lvm("estelle") * 1.1) + R.gear_tot("estelle")["hp"]), "버티는 몸 +10% max HP (%s → %s)" % [h0, R.max_hp("estelle")])
	# 둥근 방패 (guard −15%) and 받아내기 (parry → 기력 +5; renewal: in 의지)
	M.take("estelle", "B0")
	M.take("estelle", "C2")
	var i0: float = R.in_mul()
	P.anim = "guard"
	check(near(R.in_mul(), i0 * 0.85), "guard: taken ×0.85")
	P.anim = "idle"
	arena.ult.v["estelle"] = 0.0
	R.ev("parry")
	check(near(arena.ult.v["estelle"], 5.0), "parry → 기력 +5 (%s)" % arena.ult.v["estelle"])

	# 의족을 박고 (renewal: 의지 KEY): guard → auto parry, two charges, 6 s each
	M.tree["estelle"]["lv"] = 12
	M.clear_nodes("estelle")
	for id in ["C0", "C1", "C2", "C3", "C4", "C6"]: check(M.take("estelle", id), "take " + id)
	R.changed()
	R.tick(16.0)
	check(int(M.gp["estelle"]["n"]) == 2 and R.rbn("n_gp") == 2, "자동 패링 ×2 tag")
	P.anim = "guard"
	var mob = arena.mobs[0] if arena.mobs.size() > 0 else e
	check(M.guard_hit(mob, true) == "gp" and int(M.gp["estelle"]["n"]) == 1, "guard hit spends a charge")
	check(M.guard_hit(mob, false) == "", "not facing: no auto parry")
	R.tick(6000.0)
	check(int(M.gp["estelle"]["n"]) == 2, "a charge comes back in 6 s")
	P.anim = "idle"

	# 성소 on Luce, shared by the party
	M.tree["luce"]["lv"] = 12
	M.clear_nodes("luce")
	for id in ["C0", "C1", "C2", "C3", "C4", "C6"]: M.take("luce", id)      # (renewal: 성소 is the 기도 KEY)
	P.party = ["estelle", "aida", "luce"]
	check(near(M.sanc_v(), 12000.0), "성소 covers Estelle while Luce is in the party")
	P.inv = 0.0
	P.hp = P.MAX_HP
	check(M.guard_hit(mob, true) == "miss" and M.sanc["cd"] > 0.0, "성소 takes the blow")
	P.inv = 0.0
	P.anim = "guard"
	check(M.guard_hit(mob, true) == "gp", "then the cooldown (auto parry next)")
	P.anim = "idle"
	R.tick(12100.0)
	check(not (M.sanc["cd"] > 0.0), "re-woven after 12 s")
	P.party = ["estelle", "aida"]
	check(M.sanc_v() == 0.0, "no Luce, no dome")
	P.party = ["estelle", "aida", "luce"]

	# multipliers: QTE time, swap cooldown, ult gain, cooldowns, dash recharge
	M.tree["aida"]["lv"] = 12
	M.clear_nodes("aida")
	for id in ["C0", "C1", "B0", "B1", "X1"]: M.take("aida", id)      # (renewal: 망자의 귀띔 is the 그림자 + 균열 cross node)
	check(near(M.mul("aida", "qteT"), 1.2) and near(M.mul("aida", "cd"), 0.85) and near(M.mul("aida", "rch"), 0.75), "Aida: QTE ×1.2, rift cd ×0.85, dash charge ×0.75")
	M.clear_nodes("estelle")
	for id in ["C0", "C1", "C2", "C3", "A0", "A1", "X2"]: M.take("estelle", id)      # (어설픈 욕지거리 is the 검 + 의지 cross node now)
	P.qte["t"] = 0.0
	P.qte["cd"] = 0.0
	P.qte_offer("parry")
	check(near(P.qte["t"], P.QTE_T * 1.25), "믿고 기다리기: QTE ×1.25 (%s)" % P.qte["t"])
	P.qte_end()
	arena.ult.v["estelle"] = 0.0
	arena.ult.state = ""
	arena.ult.auto_t = 0.0
	var k: float = R.ult_k()
	arena.ult_gain(10.0)
	check(near(arena.ult.v["estelle"], 10.0 * k) and k > 1.09, "어설픈 욕지거리: 기력 ×1.1 in ult_k (%s)" % k)
	P.swap_cd = 0.0
	P.hpm["aida"] = 50.0
	P.swap(false, "aida")
	check(P.who == "aida" and near(P.swap_cd, 2200.0), "swap cooldown by Aida's own nodes (%s)" % P.swap_cd)
	P.swap_cd = 0.0
	P.swap(false, "estelle")
	check(P.who == "estelle" and near(P.swap_cd, 2200.0 * 0.75), "먼저 달려가기: Estelle's swap ×0.75 (%s)" % P.swap_cd)

	# heals scale with Luce's level
	M.tree["luce"]["lv"] = 5
	M.clear_nodes("luce")
	R.changed()
	check(near(P._lvh("luce"), 1.75 * (1.0 + R.gear_tot("luce")["heal"] / 100.0)), "heal ×LVM ×회복량")

	# memDecay: the cave is for Lv1–6
	P.party = ["estelle"]
	M.tree["estelle"]["lv"] = 6
	check(near(R.mem_decay(), 1.0), "Lv6: full 기억석")
	M.tree["estelle"]["lv"] = 8
	check(near(R.mem_decay(), 0.5), "Lv8: half")
	M.tree["estelle"]["lv"] = 12
	check(near(R.mem_decay(), 0.1), "Lv12: 10%")
	P.party = ["estelle", "aida", "luce"]

	# ---- fame's chapter tasks ----
	var F = arena.fame
	F.rec = ["estelle", "aida", "luce"]
	var t_lv3 := {"fn": "anyLv3"}
	var t_br := {"fn": "breakthrough"}
	check(F.t_val(t_lv3) == 1 and F.t_val({"fn": "anyLv6"}) == 1, "세계수 Lv3 / Lv6 tasks read the levels")
	check(F.t_val(t_br) == 1, "광부의 등잔 task reads the breakthrough")
	check(F.t_val({"fn": "engraved"}) == R.engraved() and R.engraved() > 0, "engraved runes %d" % R.engraved())
	check(F.t_val({"fn": "maxStar"}) == R.max_star() and R.max_star() >= 1, "max star %d" % R.max_star())
	for c in M.ROSTER: M.tree[c] = {"lv": 1, "on": [], "br": {}}
	check(F.t_val(t_lv3) == 0 and F.t_val(t_br) == 0, "tasks read 0 again at Lv1")

	# ---- save / load ----
	M.tree["estelle"] = {"lv": 6, "on": ["A0", "B0", "C0", "A1", "A3"], "br": {"3": 1}}
	M.tree["luce"] = {"lv": 2, "on": ["B1"], "br": {}}
	M._changed()
	P.hpm["luce"] = R.max_hp("luce")
	var SG = load("res://scripts/save_game.gd").new(arena)
	var snap: Dictionary = SG.snapshot()
	check(snap.has("memory") and snap["memory"]["tree"]["estelle"]["lv"] == 6, "snapshot has the trees")
	var js: Dictionary = JSON.parse_string(JSON.stringify(snap))
	M.reset()
	R.changed()
	SG.apply(js)
	check(M.lv("estelle") == 6 and M.T("estelle")["on"].size() == 5 and M.T("estelle")["br"].has("3"), "trees restored: %s" % str(M.T("estelle")))
	check(M.lv("luce") == 2 and M.T("luce")["on"] == ["B1"], "Luce restored")
	check(near(P.hpm["luce"], R.max_hp("luce")), "standby HP over the Lv1 cap survives the load (%s / %s)" % [P.hpm["luce"], R.max_hp("luce")])
	M.set_state({"v": 1, "tree": {"aida": {"lv": 2, "on": ["A0", "A1", "Z9"], "br": {}}}})
	check(M.T("aida")["on"].is_empty(), "a tree with more nodes than points is cleared")

	# ---- the tabs ----
	var UIR = arena.ui_root
	var menu = UIR.menu if UIR != null else null
	if menu != null:
		menu.open_page("char")
		await process_frame
		var pg = menu.ext.get("char")
		check(pg != null, "character page")
		if pg != null:
			for tb in ["skill", "match", "rec"]:
				pg._tab(tb)
				pg.queue_redraw()
				await process_frame
				await process_frame
				check(pg.tab == tb and pg.hits.size() > 4, "tab %s draws with %d hit areas" % [tb, pg.hits.size()])
			# keyboard on the memory tab: Enter on a takeable node spends a point; the level row levels up
			M.tree["estelle"] = {"lv": 2, "on": [], "br": {}}
			R.mem = 50
			pg.c = "estelle"
			pg._tab("match")
			pg.mx.sel = "A0"
			pg._key(KEY_ENTER)
			check(M.T("estelle")["on"] == ["A0"], "Enter takes A0")
			pg._key(KEY_ENTER)
			check(M.T("estelle")["on"].is_empty(), "Enter again lets it go")
			pg._key(KEY_UP)
			pg.queue_redraw()
			await process_frame
			await process_frame
			check(pg.mx.sel == "LV", "up from the top row reaches the level button")
			pg._key(KEY_ENTER)
			check(M.lv("estelle") == 3 and R.mem == 34, "Enter there levels up (mem %d)" % R.mem)
			pg._tab("rec")
			pg._key(KEY_DOWN)
			pg._key(KEY_ENTER)
			check(pg.mx.say_t > 0.0, "Enter on a line says it")
			M.tree["estelle"]["lv"] = 12
			pg._tab("skill")
			pg._tab("rec")
			check(pg.mx.memo(), "Lv12: the memorial opens")
			pg._tab("skill")
			pg._key(KEY_DOWN)
			check(pg.mx.si == 1, "skill list moves")
		menu.close_page()

	print("memory: %d ok, %d failed" % [ok, bad])
	quit(1 if bad > 0 else 0)
