extends SceneTree
## WP4 PARTY v2 (#pt2) and WP16 the witch-time slow bus.
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
	check(pg.sel == P.who, "opens on the leader (ptSel = CHAR)")
	for i in 5: await process_frame
	check(pg._L.size() == 3, "three columns for three recruits")
	var on_w: float = pg._L[pg.sel]["r"].size.x
	var off_w: float = pg._L["aida"]["r"].size.x
	check(absf(on_w / off_w - 2.6) < 0.05, "the picked column is 2.6× wide (%.2f)" % (on_w / off_w))
	pg._key(KEY_ESCAPE)
	await settle(U)
	check(M.page == "hub", "Esc goes back to the hub it came from")
	M.close_hub()
	await settle(U)

	# ---- the top bar's 파티 ----
	M._bar_click("pty")
	await process_frame
	check(M.page == "party", "top bar 파티 opens it")
	# a tap on another column picks it; the width eases over .55 s
	for i in 3: await process_frame
	var poly: PackedVector2Array = pg._L["aida"]["poly"]
	var cpos := Vector2.ZERO
	for p in poly: cpos += p
	cpos /= poly.size()
	_click(cpos)
	await process_frame
	check(pg.sel == "aida", "a tap picks Aida's column")
	for i in 4: await process_frame
	var k: float = pg.tr.get_v("flex_aida", 2.6, 550.0, "ez")
	check(k > 1.0 and k < 2.6, "her column is widening (%.2f)" % k)
	pg.tr.step(1000.0)
	check(absf(pg.tr.get_v("flex_aida", 2.6, 550.0, "ez") - 2.6) < 0.001, "and settles at 2.6")

	# ---- 빼기 / 넣기 ----
	var B: Array = pg.bar()
	check(B[0][1] == "빼기" and B[0][2] and B[1][2], "Aida in the party: 빼기 · 리더로 on")
	pg.press("in")
	check(not P.party.has("aida") and P.party.size() == 2, "빼기 takes her out")
	B = pg.bar()
	check(B[0][1] == "넣기" and B[0][2], "now 넣기")
	pg.press("in")
	check(P.party.has("aida") and P.party.size() == 3, "넣기 brings her back")
	pg.pick("estelle")
	B = pg.bar()
	check(not B[0][2] and not B[1][2] and B[2][2], "the leader: 빼기 and 리더로 off, 정보 on")
	pg.press("in")
	check(P.party.has("estelle"), "a disabled 빼기 does nothing")
	# ---- 리더로 for a member out of the party ----
	pg.pick("luce")
	pg.press("in")
	check(not P.party.has("luce"), "Luce out")
	pg.press("lead")
	check(P.party.has("luce") and P.who == "luce", "리더로 brings her in and gives her control")
	pg.pick("estelle")
	pg.press("lead")
	check(P.who == "estelle", "리더로 back to Estelle")
	# taps on the bar go through the top layer
	pg.pick("aida")
	for i in 3: await process_frame
	check(pg.top_hits.size() == 4, "bar ×3 and ✕ are tappable")
	_click(_center(pg.top_hits[0][0]))
	await process_frame
	check(not P.party.has("aida"), "tapping 빼기 works")
	_click(_center(pg.top_hits[0][0]))
	await process_frame
	check(P.party.has("aida"), "tapping 넣기 works")
	# keys
	pg.pick("estelle")
	pg._key(KEY_RIGHT)
	check(pg.sel == "aida", "→ picks the next member")
	pg._key(KEY_DOWN)
	pg._key(KEY_ENTER)
	check(not P.party.has("aida") and pg.focus == 0, "↓ Enter presses 빼기")
	pg._key(KEY_ENTER)
	pg._key(KEY_UP)
	check(P.party.has("aida") and pg.focus == -1, "Enter again 넣기, ↑ back to the columns")

	# ---- the save keeps the party ----
	pg.pick("luce")
	pg.press("in")
	arena.save_now()
	var d = JSON.parse_string(FileAccess.get_file_as_string(arena.save.path))
	check(d is Dictionary and d.has("party") and not d["party"].has("luce") and d["party"].size() == 2, "the save keeps the party %s" % str(d.get("party") if d is Dictionary else null))
	pg.press("in")

	# ---- 정보: sweep → the character screen on that member ----
	pg.pick("aida")
	pg.press("info")
	await settle(U)
	for i in 3: await process_frame
	check(M.page == "char" and M.ext["char"].c == "aida", "정보 opens Aida's character screen")
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
	arena.sfx("hit", 0.5)
	var hit_ap = arena.sfx_pool.filter(func(a): return a.stream != null and a.stream.resource_path.ends_with("hit.wav"))
	check(hit_ap.size() > 0 and absf(hit_ap[0].pitch_scale - 0.62) < 0.001 and hit_ap[0].bus == &"Slow", "witch: a new sfx plays at 0.62×")
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
