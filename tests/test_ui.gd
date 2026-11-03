extends SceneTree
## Front end: top-right menu button opens the hub through the sweep, 설정 / 조작 안내 open, a key slot rebinds.
func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var U = arena.ui_root
	print("title active ", U.title.active, " holds ", U.holds())
	U.menu.open_hub()
	var n := 0
	while U.sweep.active and n < 2000:
		await process_frame
		n += 1
	print("page ", U.menu.page, " sweep ", U.sweep.active, " holds ", U.holds())
	U.menu.enter(U.menu.hub_index("help"))          # 조작 안내
	n = 0
	while (U.sweep.active or n < 2) and n < 2000:
		await process_frame
		n += 1
	print("page ", U.menu.page, " from_hub ", U.menu.from_hub)
	U.menu.opts.t = 9000.0
	for i in 10: await process_frame
	print("opts visible ", U.menu.opts.visible, " hits ", U.menu.opts.hits.size())
	_click(U.menu.opts.hits[0][0])       # WASD + 마우스형
	for i in 3: await process_frame
	print("preset: left ", OS.get_keycode_string(arena.cfg.kb["left"][0]), " rmb ", arena.cfg.rmb)
	# find the jump slot by trying hits until cap == [jump, 0]
	for h in U.menu.opts.hits:
		_click(h[0])
		await process_frame
		if U.menu.opts.cap.size() > 0 and U.menu.opts.cap[0] == "jump":
			break
	print("cap ", U.menu.opts.cap)
	var k := InputEventKey.new()
	k.physical_keycode = KEY_K
	k.pressed = true
	root.push_input(k, true)
	await process_frame
	print("jump now ", arena.cfg.kb["jump"], " events ", InputMap.action_get_events("jump").size())
	arena.cfg.use_preset("arrow")
	print("restored ", OS.get_keycode_string(arena.cfg.kb["jump"][0]))
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	n = 0
	while (U.sweep.active or n < 2) and n < 2000:
		await process_frame
		n += 1
	print("back to ", U.menu.page)
	U.menu.close_hub()
	n = 0
	while (U.sweep.active or n < 2) and n < 2000:
		await process_frame
		n += 1
	print("closed: page '", U.menu.page, "' holds ", U.holds(), " fatigue ", arena.fatigue.value())
	quit()

func _click(poly: PackedVector2Array) -> void:
	var c := Vector2.ZERO
	for v in poly: c += v
	c /= poly.size()
	for p in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = p
		e.position = c
		e.global_position = c
		root.push_input(e, true)
