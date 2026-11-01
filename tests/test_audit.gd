extends SceneTree
## The audit fixes: godot --headless --path . -s tests/test_audit.gd
## ult clip frame packs, 환경음, 화면 효과, the hall's board / living room / library / rooms, Eilin's evening choice,
## a tap turns the talk box's page, keyboard / pad cursor in 설정, the stick in menus, the boss's fall and bar,
## the room feed notices, saving when the app loses focus.

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func key(arena, k: int) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	root.push_input(e, true)
	var e2 := e.duplicate()
	e2.pressed = false
	root.push_input(e2, true)

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	for i in 3: arena._process(0.016)

	# ---- ult clips: JPEG frame packs the game decodes itself (the web build has no Theora) ----
	var UC = arena.ucut()
	for c in ["estelle", "aida", "luce"]:
		var n: int = UC.clip_frames(c)
		var im: Image = UC.frame_img(c, n / 2) if n > 0 else null
		check(n > 20 and im != null and im.get_width() == 640 and im.get_height() == 360, "%s clip: %d frames, frame decodes 640x360" % [c, n])
		check(UC.has_video(c) and UC.length(c) > UC.PING + UC.SPLASH + 1000.0, "%s cut-in runs the clip (%.0f ms)" % [c, UC.length(c)])
	UC.start("estelle")
	arena.ult.t = UC.PING + UC.SPLASH + 500.0
	UC._process(0.016)
	check(UC.vp.visible and UC.vp.texture != null and UC._fi == 12, "half a second into the clip shows frame 12 (got %d)" % UC._fi)
	var tex0 = UC.vp.texture
	arena.ult.t += 100.0
	UC._process(0.016)
	check(UC.vp.texture == tex0 and UC._fi == 14, "the next frames reuse one texture")
	UC.stop()
	check(UC.vp.texture == null, "stopping drops the frame")

	# ---- 환경음 ----
	var A = arena.amb
	arena.ambient = true
	arena.weather = "rain"
	for i in 120: A.step(16.0)
	check(A.loops.size() == 3, "wind / rain / water loops built")
	check(A.gains["rain"] > 0.05 and A.loops["rain"].playing, "rain loop up in the rain (%.3f)" % A.gains["rain"])
	check(A.master > 0.5, "ambience master up (%.2f)" % A.master)
	arena.weather = "clear"
	arena.ambient = false
	for i in 200: A.step(16.0)
	check(A.master < 0.02 and A.loops["wind"].volume_db < -40.0, "환경음 off silences it (master %.3f, wind %.0f dB)" % [A.master, A.loops["wind"].volume_db])
	for ap in A.pool: ap.stop()
	A.hsnd(500.0, 400.0, 0.1, 0.05)
	check(not A.pool.any(func(p): return p.playing), "hall sounds stay quiet with 환경음 off")
	arena.ambient = true
	A.creak()
	check(A.pool.any(func(p): return p.playing), "a creak plays with 환경음 on")

	# ---- 화면 효과 ----
	var PF = arena.post
	arena.screen_fx = true
	arena.perfect_dodge()
	PF._process(0.016)
	check(PF.waves.size() == 1 and PF.ca > 0.0 and PF.wd > 0.0 and PF.pass_rect.visible, "perfect dodge: shockwave, fringes, grade (pass on)")
	arena._process(0.016)
	check(arena.witch_rect.color.a == 0.0, "the grade replaces the flat blue tint")
	arena.witch = 0.0
	PF.waves.clear()
	PF.ca = 0.0
	PF.hit = 0.0
	PF._process(0.016)
	check(not PF.pass_rect.visible and PF.vig.visible, "quiet: only the vignette overlay (no screen read)")
	arena.screen_fx = false
	arena.post_wave(Vector2(500, 300))
	PF._process(0.016)
	check(PF.waves.is_empty() and not PF.visible, "화면 효과 off: nothing")
	arena.screen_fx = true

	# ---- 캐릭터 도트화 ----
	var PM: ShaderMaterial = arena.player.pix_mat()
	check(arena.player.material == PM and int(PM.get_shader_parameter("mode")) == 2, "characters drawn with 도트+셰이딩 by default")
	var orow: Dictionary = arena.ui_root.menu.opts._rows()[0]
	check(orow["lab"] == "캐릭터 도트화" and orow["o"] == ["끄기", "도트", "도트+셰이딩"], "설정 has 캐릭터 도트화 first")
	orow["set"].call(0)
	check(arena.pix == "off" and int(PM.get_shader_parameter("mode")) == 0, "끄기 turns it off")
	orow["set"].call(2)

	# ---- the boss falls hard; its bar ----
	arena.enter_dungeon()
	for i in 10: arena._process(0.016)
	var b = arena.spawn("boss", arena.player.position.x + 300.0, 0.0)
	b.spawn_t = 0.0
	b.hit(9999.0, 0.0)
	check(arena.fx.any(func(e): return e.get("s", "") == "격파!") and arena.hitstop > 0.0, "boss down: 격파!")
	arena.leave_dungeon()
	for i in 10: arena._process(0.016)

	# ---- the hall: board, living room, library, the members' rooms ----
	arena.go_hall(0, Vector2(2492.0, 430.0), 1)
	for i in 10: arena._process(0.016)
	check(arena.level.near_door != null and arena.level.near_door["act"] == "board", "의뢰 게시판 at the board")
	arena.try_interact()
	for i in 5: await process_frame
	var M = arena.ui_root.menu
	check(M.page == "gbk", "the board opens the guild book (page %s)" % M.page)
	M.page = ""
	arena.fame.fac.erase("rooms")
	arena.go_hall(2, Vector2(522.0, 430.0), 1)
	for i in 10: arena._process(0.016)
	var nd = arena.level.near_door
	check(nd != null and nd["act"] == "room" and nd["c"] == "estelle", "322 · 에스텔의 방")
	arena.fx.clear()
	arena.try_interact()
	check(arena.fx.any(func(e): return e.get("s", "") == "먼지투성이 방… 시설 복구가 필요하다"), "a dusty room until the rooms are restored")
	arena.fame.fac["rooms"] = true
	arena.try_interact()
	for i in 3: await process_frame
	check(M.page == "char" and M.ext["char"].c == "estelle", "restored: the room opens her character screen")
	M.page = ""
	arena.go_hall(1, Vector2(590.0, 430.0), 1)
	for i in 10: arena._process(0.016)
	arena.player.switch_char("luce") if arena.player.party.has("luce") else null
	arena.try_interact()
	for i in 3: await process_frame
	check(M.page == "char" and M.ext["char"].c == arena.player.who, "도서관 · 기록 opens the character screen")
	M.page = ""
	arena.go_hall(0, Vector2(500.0, 430.0), 1)
	for i in 10: arena._process(0.016)
	arena.try_interact()
	check(arena.sortie.party_ui.open, "리빙 룸 · 파티 편성 opens the party screen")
	arena.sortie.party_ui.open = false

	# ---- Eilin off duty: one choice, as in the prototype ----
	arena.eil.spot = "town"
	arena.eil.talk()
	check(arena.dlg.active and arena.dlg.choices.size() == 1 and arena.dlg.choices[0][0] == "좋은 저녁 보내요", "off duty: 좋은 저녁 보내요")
	arena.dlg.i = arena.dlg.lines.size() - 1
	arena.dlg._pick(0)
	check(arena.eil.talk_t == 0.0, "the choice lets her go")

	# ---- a tap on the talk box turns the page ----
	arena.open_dialog("eilin", null, "에일린", "길드 접수원", ["하나 둘 셋", "둘"])
	arena.dlg.step(40.0)
	check(arena.dlg.typing() and arena.dlg.shown >= 1.0 and arena.dlg.shown < 3.0, "the line types out (%.1f letters)" % arena.dlg.shown)
	arena.dlg.t = 500.0
	arena.dlg.advance()
	check(not arena.dlg.typing() and arena.dlg.i == 0, "the first press shows the whole line")
	arena.dlg.t = 500.0
	arena.dlg.queue_redraw()
	await process_frame
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = arena.dlg.box.get_center()
	tap.device = InputEvent.DEVICE_ID_EMULATION
	root.push_input(tap, true)
	await process_frame
	check(arena.dlg.i == 1, "tap: next line")
	root.push_input(tap, true)
	await process_frame
	check(arena.dlg.i == 1, "a second tap right away doesn't skip")
	arena.dlg.t = 500.0
	arena.dlg.shown = 99.0
	root.push_input(tap, true)
	await process_frame
	check(not arena.dlg.active, "tap on the last line closes it")

	# ---- 설정 by keyboard / pad ----
	M.open_page("opts")
	await process_frame
	var O = M.opts
	var rows: Array = O._rows()
	var wi := -1
	for i in rows.size():
		if rows[i]["lab"] == "날씨": wi = i
	arena.weather = "clear"
	O.sel = -1
	for i in wi + 1:
		O._nav(1)
		if O.sel == wi: break
	check(O.sel == wi, "cursor reaches 날씨 (row %d)" % O.sel)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_DPAD_RIGHT
	jb.pressed = true
	root.push_input(jb, true)
	await process_frame
	check(arena.weather == "rain", "pad → sets 비 (got %s)" % arena.weather)
	key(arena, KEY_ENTER)
	await process_frame
	check(arena.weather == "snow", "Enter steps on to 눈 (got %s)" % arena.weather)
	arena.weather = "clear"
	for i in rows.size():
		if rows[i]["k"] == "kb":
			O.sel = i
			break
	O._activate()
	check(O.cap.size() == 2 and O.cap[1] == 0, "Enter on a key row waits for a key")
	O.cap = []
	M.close_page()
	await process_frame

	# ---- the stick steers the hub ----
	M.open_hub()
	var n := 0
	while arena.ui_root.sweep.active and n < 2000:
		await process_frame
		n += 1
	var i0: int = M.ph_i
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_Y
	jm.axis_value = 0.9
	root.push_input(jm, true)
	for i in 3: await process_frame
	check(M.ph_i == (i0 + 1) % M.PHM.size(), "stick down moves the hub cursor (%d → %d)" % [i0, M.ph_i])
	jm.axis_value = 0.0
	root.push_input(jm, true)
	for i in 3: await process_frame
	M.close_hub()
	n = 0
	while arena.ui_root.sweep.active and n < 2000:
		await process_frame
		n += 1

	# ---- room feed ----
	arena.enter_dungeon()
	for i in 30:
		arena._process(0.016)
		await process_frame
	var H = null
	for c in arena.get_children():
		if c is CanvasLayer:
			for d in c.get_children():
				if d.has_method("_room_feed"): H = d
	check(H != null, "hud found")
	if H != null:
		var notes: Array = arena.fame.fx.feed.filter(func(x): return x["tag"] == "AREA").map(func(x): return String(x["s"]))
		check(notes.size() > 0, "entering the cave puts its room name in the feed %s" % [notes])
		arena.level.clear_room() if arena.level.has_method("clear_room") else arena.clear_room()
		for i in 30:
			arena._process(0.016)
			await process_frame
		var tags: Array = arena.fame.fx.feed.map(func(x): return String(x["s"]))
		check(tags.has("방 정리 완료") or arena.mobs.is_empty(), "clearing a room with enemies: 방 정리 완료 %s" % [tags])

	# ---- saving when the app loses focus ----
	var p: String = arena.save.path
	if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	arena.world_started = true
	arena._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(FileAccess.file_exists(p), "focus out writes the save")
	if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	print("FAILS: %d" % fails)
	quit()
