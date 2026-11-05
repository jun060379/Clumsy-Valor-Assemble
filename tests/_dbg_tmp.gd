extends SceneTree
func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	for i in 10: await process_frame
	arena.go_town(Vector2(8400.0, arena.ground_y), 1)
	for i in 30: await process_frame
	var L = arena.level
	arena.player.position = Vector2(8380.0, L.floor_at(8380.0))
	for i in 30: await process_frame
	Input.action_press("right")
	for i in 40:
		await process_frame
		if i % 8 == 0: print("DBG x ", roundi(arena.player.position.x), " y ", arena.player.position.y, " floor ", L.floor_at(arena.player.position.x), " LOWF ", L.LOWF, " anim ", arena.player.anim, " on ", arena.player.on, " drops ", L.fxa.drops.size(), " rings ", L.fxa.rings.size())
	quit()
