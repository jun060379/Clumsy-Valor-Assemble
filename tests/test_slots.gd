extends SceneTree
## Save slots: godot --headless --path . -s tests/test_slots.gd
## save_game.gd's file argument (the autosave and the three slots, user://save_test_N.json in a test run), the round
## trip of a slot (write, change the world, load it back), the header read (place / day / time / adventurer level /
## party / timestamp) that leaves the world alone, newest(), the day counter across midnight, and the hub's 저장:
## allowed in the town, the hall and the training ground, greyed with its line in a dungeon; the picker writes an
## empty slot at once and asks 덮어쓰기? over a filled one; a tap counts on the release inside the row.

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func mouse(M, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	M._input_save(ev)

func key(M, k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	M._input_save(ev)

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var S = arena.save
	var P = arena.player
	var F = arena.fame
	var M = arena.ui_root.menu
	for e in S.files(): DirAccess.remove_absolute(e[2])
	# ---- the files ----
	check(S.path == "user://save_test.json" and S.slot_path(1) == "user://save_test_1.json" and S.slot_path(3) == "user://save_test_3.json", "test runs: save_test.json and save_test_1..3.json")
	var fl: Array = S.files()
	check(fl.size() == 4 and fl[0][0] == "auto" and fl[0][1] == "자동 저장" and fl[3][1] == "슬롯 3", "the list: 자동 저장, 슬롯 1·2·3")
	check(S.header(S.slot_path(1)).is_empty() and S.read(S.slot_path(1)) == null and S.newest() == "", "nothing saved: empty headers, no newest")
	# ---- a slot written in the hall ----
	F.rec = ["estelle", "aida", "luce"]
	F.alv = 4
	P.party = ["estelle", "luce"]
	arena.shilling = 345
	arena.tod_h = 23.9
	arena.day_n = 3
	arena._clock_on(60.0 * 1000.0 * 0.2)       # 12 in-game minutes: past midnight
	check(arena.day_n == 4 and arena.tod_h < 1.0, "the clock passing midnight starts day 4 (%.2f h)" % arena.tod_h)
	arena.tod_h = 18.5
	var s0: Array = arena.HALL.HD.SPAWN[2]
	arena.go_hall(2, Vector2(s0[0], s0[1]), -1)
	for i in 3: await process_frame
	var at_hall: Vector2 = P.position
	check(S.save(S.slot_path(1)), "slot 1 written")
	check(FileAccess.file_exists("user://save_test_1.json"), "… to save_test_1.json")
	var h: Dictionary = S.header(S.slot_path(1))
	check(h.get("place", "") == "본관 3층" and int(h.get("day", 0)) == 4 and h.get("time", "") == "18:30", "header: 본관 3층, day 4, 18:30 (%s)" % [h])
	check(int(h.get("lv", 0)) == 4 and h.get("party", []) == ["에스텔", "루체"], "header: Lv 4, 에스텔 · 루체")
	check(absf(float(h.get("t", 0)) - Time.get_unix_time_from_system()) < 5.0 and String(h.get("when", "")).length() == 16, "header: a real timestamp (%s)" % h.get("when", ""))
	# ---- the header read leaves the world alone; the round trip ----
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	P.party = ["estelle"]
	arena.shilling = 1
	arena.tod_h = 9.0
	arena.day_n = 9
	F.alv = 1
	S.header(S.slot_path(1))
	check(arena.level_kind() == "town" and arena.shilling == 1 and P.party == ["estelle"] and arena.day_n == 9, "reading a header does not load anything")
	check(arena.load_file(S.slot_path(1)), "slot 1 loads")
	for i in 3: await process_frame
	check(arena.level_kind() == "hall" and arena.level.fl == 2 and (P.position - at_hall).length() < 2.0, "back in the hall, 3층, where she stood")
	check(arena.shilling == 345 and P.party == ["estelle", "luce"] and absf(arena.tod_h - 18.5) < 0.01 and arena.day_n == 4 and F.alv == 4, "the shillings, the party, the clock, the day and the level came back")
	check(S.loaded_from == S.slot_path(1), "loaded_from: slot 1")
	check(not arena.load_file(S.slot_path(2)), "an empty slot does not load")
	# a slot in town, one on the training ground, one in the cave (the autosave), newest()
	arena.go_town(Vector2(1200.0, arena.ground_y), 1)
	S.save(S.slot_path(2))
	check(S.header(S.slot_path(2))["place"] == "마을", "a town save: 마을")
	arena.go_training()
	S.save(S.slot_path(3))
	check(S.header(S.slot_path(3))["place"] == "훈련장", "a training ground save: 훈련장")
	arena.go_town(Vector2(5107.0, arena.ground_y), 1)
	arena.enter_dungeon()
	for i in 3: await process_frame
	check(arena.level_kind() == "dungeon" and FileAccess.file_exists(S.path), "into the cave: the autosave written")
	var ha: Dictionary = S.header(S.path)
	check(String(ha["place"]).begins_with("동굴 · ") and String(ha["place"]).length() > 5, "a cave save: 동굴 · its room (%s)" % ha["place"])
	check(S.read(S.path)["scene"] == "town", "… and it still loads at the sortie wagon (scene town)")
	check(S.newest() == S.path, "newest(): the autosave, written last")
	DirAccess.remove_absolute(S.path)
	check(S.newest() == S.slot_path(3), "without it: slot 3, the last slot written")
	# ---- the hub's 저장 by scene ----
	check(not arena.can_save_here() and M._info("save") == M.NO_SAVE_LINE, "in the cave: 저장 is greyed with its line")
	M._show_hub(true)
	M.open_save()
	check(not M.sv_open and M.toast == M.NO_SAVE_LINE and M.toast_t > 0.0, "in the cave: 저장 does not open, the line shows")
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	check(arena.can_save_here() and M._info("save") == "", "in town: 저장 allowed")
	arena.go_training()
	check(arena.can_save_here(), "on the training ground: 저장 allowed")
	arena.go_hall(0, Vector2(1900.0, 430.0), 1)
	check(arena.can_save_here(), "in the hall: 저장 allowed")
	check(M.hub_index("save") >= 0 and M.PHM[M.hub_index("save")][1] == "저장" and M.hub_index("save") < M.hub_index("opts"), "the hub has 저장, before 설정")
	# ---- the picker ----
	DirAccess.remove_absolute(S.slot_path(2))
	M.toast_t = 0.0
	M.enter(M.hub_index("save"))
	check(M.sv_open and M.sv_rows.size() == 3 and M.sv_rows.all(func(r): return r["on"]), "저장: the picker with 슬롯 1·2·3, all pickable")
	check(not M.sv_rows[0]["h"].is_empty() and M.sv_rows[1]["h"].is_empty() and not M.sv_rows[2]["h"].is_empty(), "their headers: 1 and 3 filled, 2 empty")
	for i in 3: await process_frame
	check(M.sv_rects.size() == 3 and M.sv_btns.size() == 1, "the rows and 닫기 drawn")
	var r2: Rect2 = M.sv_rects[1]
	mouse(M, r2.get_center(), true)
	mouse(M, Vector2(5, 5), false)
	check(M.sv_open and M.sv_sel == 1 and not FileAccess.file_exists(S.slot_path(2)), "pressed on 슬롯 2, released off it: nothing written")
	mouse(M, r2.get_center(), true)
	mouse(M, r2.get_center(), false)
	check(FileAccess.file_exists(S.slot_path(2)) and not M.sv_open and M.toast == M.SAVED_LINE % 2, "an empty 슬롯 2: written at once, the picker closes, \"%s\"" % M.toast)
	check(S.header(S.slot_path(2))["place"] == "본관 1층", "slot 2 now holds the hall, 1층")
	# a filled slot asks first
	var t1: float = float(S.header(S.slot_path(1))["t"])
	M.enter(M.hub_index("save"))
	key(M, KEY_ENTER)
	check(M.sv_open and M.sv_confirm and M.sv_csel == 1, "Enter on the filled 슬롯 1: 덮어쓰기? with 취소 picked")
	key(M, KEY_ENTER)
	check(M.sv_open and not M.sv_confirm and S.header(S.slot_path(1))["place"] == "본관 3층", "취소: nothing written")
	key(M, KEY_ENTER)
	key(M, KEY_LEFT)
	check(M.sv_csel == 0, "←: 덮어쓰기")
	key(M, KEY_ENTER)
	check(not M.sv_open and S.header(S.slot_path(1))["place"] == "본관 1층" and float(S.header(S.slot_path(1))["t"]) >= t1, "덮어쓰기: slot 1 overwritten with the hall's 1층")
	M.enter(M.hub_index("save"))
	key(M, KEY_ESCAPE)
	check(not M.sv_open, "Esc closes the picker")
	M.page = ""
	for e in S.files(): DirAccess.remove_absolute(e[2])
	print("FAILS: %d" % fails)
	quit()
