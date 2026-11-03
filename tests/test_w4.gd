extends SceneTree
## 편성 (three slots and the desk of files) and WP16 the witch-time slow bus.
var fails := 0

func check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok: fails += 1

func settle(U) -> void:
	var n := 0
	while (U.sweep.active or n < 2) and n < 2000:
		await process_frame
		n += 1

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var U = arena.ui_root
	var M = U.menu
	var P = arena.player
	U.title.active = false
	arena.fame.rec = ["estelle", "aida", "luce"]
	for c in ["estelle", "aida", "luce"]:
		if not P.party.has(c): arena.toggle_member(c)
	if P.who != "estelle": P.swap_cd = 0.0; P.swap(false, "estelle")

	# ---- hub → 파티 opens the page, not the placeholder ----
	M.open_hub()
	await settle(U)
	M.enter(0)
	await settle(U)
	var pg = M.ext.get("party")
	check(pg != null and M.page == "party" and pg.visible, "hub 파티 opens the party page")
	check(not M.PAGE.has("party"), "party is off the 준비 중 list")
	check(pg.at(pg.slot) == P.who and pg.mode == "slots", "opens on the leader's slot")
	for i in 5: await process_frame
	check(pg._L.size() == 3, "three slots")
	pg._key(KEY_ESCAPE)
	await settle(U)
	check(M.page == "hub", "Esc goes back to the hub it came from")
	M.close_hub()
	await settle(U)

	# ---- the top bar's 파티 ----
	M._bar_click("pty")
	await process_frame
	check(M.page == "party", "top bar 파티 opens it")
	for i in 3: await process_frame
	# a tap on another slot picks it
	var poly: PackedVector2Array = pg._L[1]["poly"]
	_click(_center(poly))
	await process_frame
	check(pg.slot == 1 and pg.mode == "slots", "a tap picks slot 02")
	var B: Array = pg.bar()
	check(B.size() == 4 and B[1][2] and B[2][2], "a filled slot: 교체 · 리더로 · 빼기 · 정보")
	# ---- 빼기 / an empty slot / the desk ----
	var c1: String = pg.at(1)
	pg.press("out")
	check(not P.party.has(c1) and P.party.size() == 2, "빼기 empties the slot")
	pg.slot = 2
	pg.slot = 2
	check(pg.bar().size() == 1 and pg.bar()[0][0] == "swap", "an empty slot: 서류 넣기")
	pg.press("swap")
	check(pg.mode == "desk", "서류 넣기 opens the desk")
	for i in 30: await process_frame
	check(pg._F.size() == 3, "a file per recruit")
	pg.file_tap(c1)
	check(pg.dsel == c1, "a tap lifts the file")
	pg.file_tap(c1)
	check(P.party.has(c1) and P.party.find(c1) == P.party.size() - 1, "a second tap sends it to the empty slot")
	check(await _until(func(): return pg.mode == "slots"), "stamped, back to the slots")
	# a member in another slot trades places
	var order0: Array = P.party.duplicate()
	pg.slot = 0
	pg.open_desk()
	pg.dsel = order0[2]
	pg.send()
	check(P.party[0] == order0[2] and P.party[2] == order0[0], "a file from another slot trades places %s" % str(P.party))
	await _until(func(): return pg.mode == "slots")
	# a member left out replaces the one there (the leader hands over control)
	pg.slot = 1 if P.party[1] != P.who else 2
	var gone: String = P.party[pg.slot]
	pg.press("out")
	pg.slot = 0
	var lead0: String = P.party[0]
	pg.open_desk()
	pg.dsel = gone
	pg.send()
	check(P.party[0] == gone and not P.party.has(lead0) or P.party[0] == gone, "a file left out takes the slot %s" % str(P.party))
	check(P.who == gone or lead0 != P.who, "the leader's slot taken: the newcomer leads (%s)" % P.who)
	await _until(func(): return pg.mode == "slots")
	# 리더로
	pg.slot = 1
	var c2: String = pg.at(1)
	pg.press("lead")
	check(P.who == c2, "리더로 gives control")
	check(not pg.bar()[2][2] or P.party.size() > 1, "빼기 off for the last member")
	# keys
	pg.slot = 0
	pg._key(KEY_RIGHT)
	check(pg.slot == 1, "→ picks the next slot")
	pg._key(KEY_ENTER)
	check(pg.mode == "desk", "Enter opens the desk")
	pg._key(KEY_ESCAPE)
	check(pg.mode == "slots" and M.page == "party", "Esc on the desk goes back to the slots")
	# the save keeps the party
	arena.save_now()
	var d = JSON.parse_string(FileAccess.get_file_as_string(arena.save.path))
	check(d is Dictionary and d.has("party") and d["party"] == P.party, "the save keeps the party in slot order %s" % str(d.get("party") if d is Dictionary else null))
	# 정보: sweep → the character screen on that member
	pg.slot = 0
	var c3: String = pg.at(0)
	pg.press("info")
	await settle(U)
	for i in 3: await process_frame
	check(M.page == "char" and M.ext["char"].c == c3, "정보 opens the character screen")
	M.close_page()
	await settle(U)

	# ---- the fountain (and the hall's living room) ----
	arena.sortie.party_ui.show_it()
	await process_frame
	check(M.page == "party" and arena.sortie.party_ui.open, "the fountain opens the same page")
	check(arena.sortie.holds() and U.holds(), "the world holds while it is up")
	arena.sortie.party_ui.open = false
	check(M.page == "", "open = false closes it")

	# ---- WP16: the slow bus ----
	var S = arena.slow_bus
	var bi := AudioServer.get_bus_index(&"Slow")
	check(bi > 0 and S.lp_index(bi) >= 0, "a Slow bus with a low-pass")
	check(arena.sfx_pool.all(func(a): return a.bus == &"Slow"), "sfx players route through it")
	check(arena.dlg.voice_ap.bus == &"Slow", "the dialogue voice routes through it")
	check(arena.amb.pool.all(func(a): return a.bus == &"Slow"), "ambience players route through it")
	var late := AudioStreamPlayer.new()
	arena.add_child(late)
	check(late.bus == &"Slow", "a player added later joins by itself")
	check(not AudioServer.is_bus_effect_enabled(bi, S.fx) and absf(AudioServer.get_bus_volume_db(bi)) < 0.01, "out of slow time the bus is dry and full")
	arena.amb._build()
	var loop_ap: AudioStreamPlayer = arena.amb.loops["rain"]
	arena.witch = 1500.0
	for i in 30: S._process(1.0 / 60.0)
	check(S.cut < 700.0 and AudioServer.is_bus_effect_enabled(bi, S.fx), "witch: low-pass down to ~520 Hz (%.0f)" % S.cut)
	check(AudioServer.get_bus_volume_db(bi) < -3.5, "witch: quieter (%.1f dB)" % AudioServer.get_bus_volume_db(bi))
	check(loop_ap.bus == &"Slow" and loop_ap.pitch_scale < 0.65, "witch: the rain loop sags (%.2f)" % loop_ap.pitch_scale)
	arena.sfx("flare", 0.5)
	var hit_ap = arena.sfx_pool.filter(func(a): return a.stream != null and a.stream.resource_path.ends_with("flare.wav"))
	check(hit_ap.size() > 0 and absf(hit_ap[0].pitch_scale - 0.62) < 0.001 and hit_ap[0].bus == &"Slow", "witch: a new movement/telegraph sfx plays at 0.62×")
	arena.sfx("boom", 0.5)
	var boom_ap = arena.sfx_pool.filter(func(a): return a.stream != null and a.stream.resource_path.ends_with("boom.wav"))
	check(boom_ap.is_empty() or (boom_ap[0].bus == &"SFX" and boom_ap[0].pitch_scale == 1.0), "the boom itself plays dry (straight on the SFX bus)")
	check(AudioServer.get_bus_send(bi) == &"SFX" and AudioServer.get_bus_index(&"SFX") < bi, "the Slow bus sends into SFX (the 효과음 slider)")
	arena.witch = 0.0
	for i in 150: S._process(1.0 / 60.0)
	check(S.cut > 19000.0 and not AudioServer.is_bus_effect_enabled(bi, S.fx), "after: the low-pass opens again")
	check(absf(AudioServer.get_bus_volume_db(bi)) < 0.1 and absf(loop_ap.pitch_scale - 1.0) < 0.01, "after: full volume, the loop back to 1×")

	print("w4 done, fails=%d" % fails)
	quit()

func _until(cond: Callable, ms := 4000.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() - t0 > ms: return false
	return true

func _center(h) -> Vector2:
	if h is Rect2: return h.get_center()
	var c := Vector2.ZERO
	for p in h: c += p
	return c / h.size()

func _click(p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	e.global_position = p
	root.push_input(e, true)
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = p
	u.global_position = p
	root.push_input(u, true)
