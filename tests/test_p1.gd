extends SceneTree
## Touch controls parity, the boss-clear CLEAR card, the HUD's QTE card / ult-ready mark / HP-rune notch:
## godot --headless --path . -s tests/test_p1.gd

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func touch(p: Vector2, down: bool, idx := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.position = p
	e.pressed = down
	e.index = idx
	root.push_input(e, true)

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	for i in 3: arena._process(0.016)
	if arena.ui_root != null and arena.ui_root.title.active:
		arena.ui_root.title.active = false
	var P = arena.player
	var TC = get_nodes_in_group("touch_controls")[0]
	var hud = null
	for n in TC.get_parent().get_children():
		if n.has_method("_draw_qte_card"): hud = n

	# ---- WP1: touch controls ----
	arena.cfg.dev = "touch"
	await process_frame
	await process_frame
	check(TC.shown and TC.visible, "touch UI forced on in 설정 shows the pads")
	check(TC.lbl_a > 0.5, "labels show at first")
	TC.step(6100.0)
	TC.step(700.0)
	check(TC.lbl_a == 0.0, "labels fade out once seen (6 s)")
	TC.idle_t = 0.0
	TC.step(3100.0)
	TC.step(700.0)
	check(is_equal_approx(TC.dim, 0.5), "pads dim to half after 3 s idle")
	# skill button: icon, label and cooldown per member
	P.switch_char("luce")
	P.heal_cd = 4500.0
	check(TC.SK_LBL[P.who] == "힐" and is_equal_approx(TC.skill_cd(), 0.5), "루체: skill button says 힐, sweep follows heal_cd / 9000")
	P.switch_char("aida")
	P.tp_cd = 1500.0
	check(TC.SK_LBL[P.who] == "균열" and is_equal_approx(TC.skill_cd(), 0.5), "아이다: 균열, sweep follows tp_cd / 3000")
	P.tp_cd = 0.0
	P.heal_cd = 0.0
	P.switch_char("estelle")
	check(TC.SK_LBL[P.who] == "가드" and TC.skill_cd() == 0.0 and TC.SK_ICON["estelle"] != null, "에스텔: 가드 with sk_est_skill.png, no sweep")
	# a pressed button: white, 0.88
	var atk: Dictionary = TC.BTN[3]
	touch(TC.btn_center(atk), true, 3)
	await process_frame
	check(Input.is_action_pressed("attack"), "tapping the attack circle presses attack")
	TC.step(200.0)
	check(TC.press["attack"] == 1.0, "pressed button shrinks (press 1 -> scale .88)")
	touch(TC.btn_center(atk), false, 3)
	await process_frame
	check(not Input.is_action_pressed("attack"), "lifting releases it")
	# interact label (interUI)
	if arena.level_kind() != "town":
		arena.go_town(Vector2(5107.0, arena.ground_y), 1)
		for i in 4: await process_frame
	var L = arena.level
	L.near_door = {"name": "출격 마차", "to": "dungeon"}
	check(TC.inter_label() == "출격", "near the sortie wagon the attack button says 출격")
	L.near_door = {"name": "대장간", "to": "forge"}
	check(TC.inter_label() == "대장간", "at the forge: 대장간")
	L.near_door = {"name": "길드 본관", "to": "hall"}
	check(TC.inter_label() == "입장", "at the hall door: 입장")
	L.near_door = {"name": "파티 편성", "act": "party"}
	check(TC.inter_label() == "편성", "at the fountain: 편성")
	L.near_door = {"name": "루체", "act": "npc", "c": "luce"}
	check(TC.inter_label() == "대화", "next to a guildmate: 대화")
	L.near_door = {"name": "창고", "to": ""}
	check(TC.inter_label() == "문", "a shut door: 문")
	L.near_door = null
	check(TC.inter_label() == "", "nothing near: plain attack")
	# ULT tag: fill, tap, the cut-in starts
	var U = arena.ult
	U.v[P.who] = U.ULTMAX[P.who]
	U.cd[P.who] = 0.0
	check(TC.ult_ready(), "full 기력 and no cooldown -> the tag is ready")
	check(TC.hit_ult(TC.ult_center()) and not TC.hit_ult(TC.ult_center() + Vector2(0, 80)), "the tag's hit box")
	touch(TC.ult_center(), true, 5)
	await process_frame
	await process_frame
	touch(TC.ult_center(), false, 5)
	await process_frame
	check(U.state != "", "tapping the ULT tag fires the ultimate (state %s)" % U.state)
	check(U.cd[P.who] > 25000.0 and not TC.ult_ready(), "then it cools down (%d s on the tag)" % ceili(U.cd[P.who] / 1000.0))
	U.end()
	U.state = ""
	arena.ucut().stop()
	U.cd[P.who] = 0.0
	U.v[P.who] = 0.0
	var pb: Vector2 = TC.pip_base(TC.get_viewport())
	var dc: Vector2 = TC.btn_center(TC.BTN[0])
	check(pb.y < dc.y - TC.btn_r(TC.BTN[0]) and absf(pb.x + 8.0 - dc.x) < 1.0, "dash pips sit above the dash button")

	# ---- WP11: bench ult-ready mark, QTE card, HP-rune notch ----
	for c in ["aida", "luce"]:
		if not P.party.has(c): arena.toggle_member(c)
	check(P.party.size() == 3, "three in the party")
	U.v["luce"] = U.ULTMAX["luce"]
	check(hud.bench_ult_ready("luce") and not hud.bench_ult_ready("aida"), "bench ult-ready mark only on a full gauge")
	U.v["luce"] = 0.0
	P.switch_char("aida")
	P.qte["t"] = 0.0
	P.qte["cd"] = 0.0
	P.qte_offer("hit", {"raw": 5.0, "taken": 5.0, "victim": "aida"})
	for i in 3: await process_frame
	check(P.qte["t"] > 0.0 and hud.qte_on.has("estelle"), "수호 chance: Estelle's card comes up on the bench")
	P.qte_end()
	for i in 2: await process_frame
	check(not hud.qte_on.has("estelle"), "card gone when the window closes")
	P.switch_char("estelle")
	check(not hud.hp_rune_on("wall"), "no notch without 철벽")
	var G: Dictionary = arena.runes.gear["estelle"]
	var slot: String = G.keys()[0]
	var keep = G[slot]
	G[slot] = {"rune": "wall", "g": "rare", "n": "test"}
	check(hud.hp_rune_on("wall"), "철벽 equipped -> notch at 50%")
	hud.HPRUNE["memtest"] = {"at": 0.3, "n": "기억", "has": func(): return true}
	check(hud.hp_rune_on("memtest"), "a memory node can hook in with its own has()")
	hud.HPRUNE.erase("memtest")
	P.hp = P.MAX_HP * 0.4
	for i in 3: await process_frame
	G[slot] = keep
	P.hp = P.MAX_HP

	# ---- WP8: boss clear card ----
	arena.enter_dungeon()
	for i in 4: await process_frame
	arena.runes.boss_cleared(arena.level)
	var Lt = arena.runes.loot
	await process_frame
	check(Lt.card_on() and Lt.card_layer != null and Lt.card_layer.follow_viewport_enabled, "boss falls -> CLEAR card layer up")
	check(Lt.card_layer.get_child_count() == 6, "grade / vignette / light / dots+art passes, heroine, chest")
	check(Lt.boss_name() == "감독관 해골", "'던전 정복 · 감독관 해골'")
	var W: float = 900.0
	check(Lt.card_x(0.0, W) > W and absf(Lt.card_x(400.0, W) - (W * 0.5 - 12.0)) < 1.0 and Lt.card_x(2300.0, W) < -W * 0.3, "CLEAR slides in from the right, drifts, leaves left")
	check(Lt.card_k(80.0) == 0.5 and Lt.card_k(1000.0) == 1.0 and Lt.card_k(2100.0) == 0.5, "fades in 160 ms, out from 1.9 s")
	Lt.step(130.0)
	check(Lt._ping != null and Lt._ping.data.size() > 20000, "glass ping synthesized at 120 ms")
	Lt.step(1300.0)
	check(Lt.chest != null, "the chest starts falling at 1.25 s, under the card")
	Lt.step(1000.0)
	await process_frame
	check(not Lt.card_on() and not Lt.card_layer.visible, "card done after 2.3 s")
	print("FAILS: %d" % fails)
	quit()
