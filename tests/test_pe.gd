extends SceneTree
## Input parity (WP-E): the pad's button map and thresholds, the 방향키형 preset (no C, left Shift, both Ctrls), the
## dialogue's pad keys, Aida's sigil range, the portrait tap, the touch hit areas and the stick.
## godot --headless --path . -s tests/test_pe.gd

const CFG := preload("res://scripts/settings.gd")
var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func jb(b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func jm(ax: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = ax
	e.axis_value = v
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func feed(e: InputEvent) -> void:
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func kev(k: int, down: bool, loc := KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.location = loc
	e.pressed = down
	return e

const ACTS := ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "ult", "swap"]
func held() -> Array:
	return ACTS.filter(func(a): return Input.is_action_pressed(a))

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	if arena.ui_root != null and arena.ui_root.title.active:
		arena.ui_root.title.active = false
	var P = arena.player
	arena.cfg.use_preset("arrow")

	# ---- E1: PADBTN ----
	var want := {JOY_BUTTON_A: ["jump"], JOY_BUTTON_B: ["dash"], JOY_BUTTON_X: ["attack"], JOY_BUTTON_Y: ["guard"],
		JOY_BUTTON_LEFT_SHOULDER: ["swap"], JOY_BUTTON_RIGHT_SHOULDER: ["swap"], JOY_BUTTON_DPAD_UP: ["up"], JOY_BUTTON_DPAD_DOWN: ["down"],
		JOY_BUTTON_DPAD_LEFT: ["left"], JOY_BUTTON_DPAD_RIGHT: ["right"]}
	for b in want:
		jb(b, true)
		var h := held()
		check(h == want[b], "pad button %d → %s (got %s)" % [b, want[b], h])
		jb(b, false)
	check(held().is_empty(), "every pad button lets go")
	for c in [[JOY_AXIS_TRIGGER_LEFT, 0.45, []], [JOY_AXIS_TRIGGER_LEFT, 0.6, ["guard"]], [JOY_AXIS_TRIGGER_RIGHT, 0.45, []], [JOY_AXIS_TRIGGER_RIGHT, 0.6, ["ult"]],
			[JOY_AXIS_LEFT_X, 0.4, []], [JOY_AXIS_LEFT_X, 0.5, ["right"]], [JOY_AXIS_LEFT_X, -0.5, ["left"]],
			[JOY_AXIS_LEFT_Y, 0.55, []], [JOY_AXIS_LEFT_Y, 0.65, ["down"]], [JOY_AXIS_LEFT_Y, -0.65, ["up"]]]:
		jm(c[0], c[1])
		var h2 := held()
		check(h2 == c[2], "axis %d at %.2f → %s (got %s)" % [c[0], c[1], c[2], h2])
		jm(c[0], 0.0)
	check(held().is_empty(), "the stick and triggers let go")
	# Back = 설정, Start = the menu (menu.gd), in play only
	var M = arena.ui_root.menu
	var eb := InputEventJoypadButton.new()
	eb.button_index = JOY_BUTTON_BACK
	eb.pressed = true
	root.push_input(eb, true)
	await process_frame
	check(M.page == "opts", "Back opens 설정 (page %s)" % M.page)
	M.close_page()
	for i in 200:
		if not arena.ui_root.sweep.active and M.page == "": break
		await process_frame
	check(M.page == "" and not arena.ui_root.holds(), "settings closed again")

	# LB in play swaps (partyInput), Y is the skill
	arena.fame.join()
	arena.toggle_member("aida")
	P.swap_cd = 0.0
	var w0: String = P.who
	jb(JOY_BUTTON_LEFT_SHOULDER, true)
	P.step(16.0)
	jb(JOY_BUTTON_LEFT_SHOULDER, false)
	await process_frame
	check(P.who != w0, "LB swaps %s → %s" % [w0, P.who])
	for i in 80: P.step(16.0)
	await process_frame
	P.swap_cd = 0.0
	var w1: String = P.who
	jb(JOY_BUTTON_Y, true)
	P.step(16.0)
	jb(JOY_BUTTON_Y, false)
	await process_frame
	check(P.who == w1, "Y does not swap any more (%s → %s, anim %s)" % [w1, P.who, P.anim])
	# no swap during an ultimate or a door's fade-out
	P.swap_cd = 0.0
	arena.fade_dir = 1
	P.party_input()
	check(P.who == w1, "no swap while a door fades out (%s)" % P.who)
	arena.fade_dir = 0
	arena.fade = 0.0
	for i in 80: P.step(16.0)

	# ---- E3: the 방향키형 keys ----
	var kb: Dictionary = arena.cfg.kb
	check(kb["swap"] == [CFG.L_CTRL, CFG.R_CTRL], "swap is L-Ctrl · R-Ctrl (got %s)" % [kb["swap"]])
	check(CFG.key_name(kb["swap"][0]) == "L-Ctrl" and CFG.key_name(kb["swap"][1]) == "R-Ctrl" and CFG.key_name(kb["dash"][0]) == "L-Shift", "the key screen names the sides")
	var cases := [[KEY_C, KEY_LOCATION_UNSPECIFIED, []], [KEY_CTRL, KEY_LOCATION_LEFT, ["swap"]], [KEY_CTRL, KEY_LOCATION_RIGHT, ["swap"]],
		[KEY_SHIFT, KEY_LOCATION_LEFT, ["dash"]], [KEY_SHIFT, KEY_LOCATION_RIGHT, []], [KEY_A, KEY_LOCATION_UNSPECIFIED, ["guard"]],
		[KEY_D, KEY_LOCATION_UNSPECIFIED, ["ult"]], [KEY_SPACE, KEY_LOCATION_UNSPECIFIED, []], [KEY_TAB, KEY_LOCATION_UNSPECIFIED, []]]
	for c in cases:
		feed(kev(c[0], true, c[1]))
		var h3 := held()
		check(h3 == c[2], "%s → %s (got %s)" % [OS.get_keycode_string(c[0]) + ["", " L", " R"][c[1]], c[2], h3])
		feed(kev(c[0], false, c[1]))
	# binding a right Shift keeps its side
	check(CFG.code_of(kev(KEY_SHIFT, true, KEY_LOCATION_RIGHT)) == CFG.R_SHIFT and CFG.code_of(kev(KEY_K, true)) == KEY_K, "a captured key keeps a modifier's side only")
	# a platform that doesn't say which side: both sides from then on
	arena.cfg.note(kev(KEY_CTRL, true))
	check(not arena.cfg.sides, "a sideless modifier switches to both-sides binding")
	feed(kev(KEY_SHIFT, true))
	check(Input.is_action_pressed("dash"), "…then any Shift dashes")
	feed(kev(KEY_SHIFT, false))
	arena.cfg.sides = true
	arena.cfg.apply_keys()
	# the 설정 guide's pad rows
	var O = arena.ui_root.menu.opts
	arena.cfg.dev = "pad"
	var rows: Array = O._rows()
	var g := {}
	for r in rows:
		if r["k"] == "okb": g[r["lab"]] = r["v"]
	check(g.get("가드") == "Y · LT" and g.get("동료 전환") == "LB · RB" and g.get("궁극기") == "RT", "the pad guide: 가드 Y · LT, 동료 전환 LB · RB")
	arena.cfg.dev = "auto"

	# ---- dialogue: B turns the page like Esc, the stick doesn't race through choices ----
	arena.open_dialog("x", null, "테스트", "", ["하나", "둘", "셋"])
	var D = arena.dlg
	D.shown = D.line().length()
	D.t = 500.0
	var e1 := InputEventJoypadButton.new()
	e1.button_index = JOY_BUTTON_B
	e1.pressed = true
	root.push_input(e1, true)
	await process_frame
	check(D.i == 1, "pad B turns the page (i=%d active %s t %.0f typing %s)" % [D.i, D.active, D.t, D.typing()])
	D.shown = D.line().length()
	D.t = 500.0
	e1.button_index = JOY_BUTTON_Y
	root.push_input(e1, true)
	await process_frame
	check(D.i == 1, "pad Y does nothing in a talk")
	e1.button_index = JOY_BUTTON_A
	root.push_input(e1, true)
	await process_frame
	check(D.i == 2, "pad A turns the page")
	D.active = false
	D._close()

	# ---- E2: the sigil's reach ----
	var yr: Vector2 = P.mark_y_range()
	var lk: String = arena.level_kind()
	if lk == "town":
		check(yr == Vector2(-600.0, arena.level.LOWF), "town: the sigil reaches -600 .. the lower street")
	arena.enter_dungeon()
	await process_frame
	yr = P.mark_y_range()
	check(arena.level_kind() == "dungeon" and is_equal_approx(yr.x, arena.ground_y - float(arena.level.tpl["top"]) - 60.0) and yr.y == arena.ground_y,
		"cave room: up to its ceiling - 60 (%s)" % yr)

	# ---- portrait tap during a QTE swaps to the face tapped ----
	if not P.party.has("luce"): arena.toggle_member("luce")
	P.switch_char("estelle")
	P.hpm["aida"] = 50.0
	P.hpm["luce"] = 40.0
	P.swap_cd = 0.0
	P.qte["t"] = 1000.0
	P.qte["who"] = {"aida": true}
	P.party_input("luce")
	check(P.who == "luce", "a portrait without the QTE chance swaps to that face (got %s)" % P.who)
	P.qte["t"] = 0.0
	for i in 80: P.step(16.0)

	# ---- touch: exact circles, the stick's thresholds and zone ----
	var TC = get_nodes_in_group("touch_controls")[0]
	var b0: Dictionary = TC.BTN[3]
	var c0: Vector2 = TC.btn_center(b0)
	check(TC._hit_button(c0 + Vector2(TC.btn_r(b0) - 1.0, 0)) != null and TC._hit_button(c0 + Vector2(TC.btn_r(b0) + 4.0, 0)) == null, "a button takes a touch only inside its circle")
	var R: float = TC.STICK_R * TC.K()
	TC.stick_id = 7
	TC.stick_o = Vector2(300, 400)
	TC.stick_p = TC.stick_o + Vector2(R * 0.24, 0)
	TC._apply_stick()
	check(not Input.is_action_pressed("right"), "the stick: 24 % across is still")
	TC.stick_p = TC.stick_o + Vector2(R * 0.27, 0)
	TC._apply_stick()
	check(Input.is_action_pressed("right"), "…27 % across moves")
	TC.stick_p = TC.stick_o + Vector2(0, R * 0.44)
	TC._apply_stick()
	check(not Input.is_action_pressed("down") and not Input.is_action_pressed("right"), "44 % down is still")
	TC.stick_p = TC.stick_o + Vector2(0, R * 3.0)
	TC._apply_stick()
	check(Input.is_action_pressed("down"), "far down presses down")
	TC.stick_id = -1
	TC._apply_stick()
	check(held().is_empty(), "letting go of the stick lets go of every direction")
	var vs: Vector2 = TC.get_viewport_rect().size
	check(TC.in_zone(Vector2(vs.x * 0.4, vs.y * 0.9)) and not TC.in_zone(Vector2(vs.x * 0.5, vs.y * 0.9)) and not TC.in_zone(Vector2(vs.x * 0.2, vs.y * 0.1)), "the stick zone is the lower-left 46 % x 78 %")

	print("FAILS ", fails)
	quit(1 if fails > 0 else 0)
