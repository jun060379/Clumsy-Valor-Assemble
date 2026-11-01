extends SceneTree
func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.enter_dungeon()
	var P = arena.player
	print("solids ", arena.solids, " start ", P.position)
	Input.action_press("right")
	for i in 400:
		if i % 30 == 0: Input.action_press("jump")
		if i % 30 == 10: Input.action_release("jump")
		arena._process(0.016)
		if i % 25 == 0: print(i, " ", P.position, " on=", P.on, " anim=", P.anim, " vx=", snapped(P.vx, 0.01))
	quit()
