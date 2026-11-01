extends SceneTree
## Headless walk through the guild hall and Eilin's day: godot --headless -s tests/test_hall.gd

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	for i in 5: arena._process(0.016)
	print("town: ", arena.level_kind(), " eilin ", arena.eil.map, " ", arena.eil.spot)
	for fl in 4:
		var s: Array = arena.HALL.HD.SPAWN[fl]
		arena.go_hall(fl, Vector2(s[0], s[1]), 1)
		for i in 60: arena._process(0.016)
		print("floor ", fl, " ", arena.HALL.HD.FLN[fl], " W ", arena.world_w, " player ", arena.player.position, " doors ", arena.level.doors.size(), " bays ", arena.level.bays.size())
	# climb floor 0's stairs: walk to the ramp's foot, hold up, walk left onto the landing
	arena.go_hall(0, Vector2(1585.0, 430.0), -1)
	var P = arena.player
	for i in 20: arena._process(0.016)
	Input.action_press("up")
	for i in 5: arena._process(0.016)
	Input.action_release("up")
	print("on the ramp: ", P.position, " ", P.plat)
	Input.action_press("left")
	for i in 120: arena._process(0.016)
	Input.action_release("left")
	await process_frame
	await process_frame
	for i in 30: arena._process(0.016)
	print("after the stairs: ", P.position, " plat ", P.plat)
	# Eilin through the day: jump the clock and let her walk
	arena.tod_auto = false
	for h in [7.6, 12.2, 13.5, 18.2, 20.8, 23.2, 8.5]:
		arena.tod_h = h
		for i in 6000: arena.eil.world(16.0)
		print("%.1fh -> %s %s x=%.0f y=%.0f path %d" % [h, arena.eil.map, arena.eil.spot, arena.eil.x, arena.eil.y, arena.eil.path.size()])
	# talk at the counter
	arena.go_hall(0, Vector2(2020.0, 430.0), 1)
	for i in 10: arena._process(0.016)
	print("near ", arena.level.near_door["name"] if arena.level.near_door != null else null)
	arena.tod_h = 9.0
	for i in 6000: arena.eil.world(16.0)
	for i in 10: arena._process(0.016)
	arena.try_interact()
	print("dialog ", arena.dlg.active, " ", arena.dlg.lines)
	arena.dlg.active = false
	arena.go_town(Vector2(3024.0, 235.0), 1)
	for i in 30: arena._process(0.016)
	print("back in town: ", arena.level_kind(), " ", arena.player.position)
	quit()
