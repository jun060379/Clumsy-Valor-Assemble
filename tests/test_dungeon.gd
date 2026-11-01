extends SceneTree
## Headless walk through the cave: godot --headless -s tests/test_dungeon.gd

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	arena.enter_dungeon()
	var D = arena.level
	print("rooms: ", D.rooms.size(), "  start ", D.cur, " tpl ", D.room()["tpl"])
	var visited := 0
	for step in 40:
		for i in 20:
			arena._process(0.016)
		for m in arena.mobs:
			if not m.is_dead(): m.hit(999.0, 0.0)
		for i in 150:
			arena._process(0.016)
		var rm = D.room()
		var nxt = null
		for d in D.doors:
			if d["town"]: continue
			var n = D.rooms[D.rkey(rm["x"] + D.DIRS[d["d"]][0], rm["y"] + D.DIRS[d["d"]][1])]
			if not n["visited"]:
				nxt = d
				break
		if nxt == null:
			break
		D.near_gate = nxt
		D.try_interact()
		for i in 40:
			arena._process(0.016)
		visited += 1
		print("-> ", D.cur, " ", D.room()["type"], " ", D.room()["tpl"], " mobs ", arena.mobs.size(), " gate ", D.gate_open, " player ", arena.player.position)
	print("visited ", visited, " cleared ", D.rooms.values().filter(func(r): return r["cleared"]).size(), "/", D.rooms.size())
	arena.leave_dungeon()
	print("back: level ", arena.level, " world ", arena.world_w)
	quit()
