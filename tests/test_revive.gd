extends SceneTree
## Members who fell in the cave stand up again in town: godot --headless -s tests/test_revive.gd
var fails := 0

func ok(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", msg)

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var P = arena.player
	arena.fame.join()
	for c in ["aida", "luce"]: arena.toggle_member(c)
	arena.enter_dungeon()
	for i in 5: await process_frame
	P.hpm["aida"] = 0.0
	P.hpm["luce"] = 0.0
	for i in 10: P.party_step(16.0)
	ok(P.hpm["aida"] <= 0.0 and P.hpm["luce"] <= 0.0, "the fallen stay down in the cave")
	arena.leave_dungeon()
	for i in 3: await process_frame
	P.party_step(16.0)
	ok(arena.level_kind() == "town", "back in town")
	ok(P.hpm["aida"] == P._mhp("aida"), "aida stands up at full hp in town (%s)" % P.hpm["aida"])
	ok(P.hpm["luce"] == P._mhp("luce"), "luce stands up at full hp in town (%s)" % P.hpm["luce"])
	# the hall too
	P.hpm["aida"] = 0.0
	arena.go_hall(0, Vector2(400.0, arena.ground_y), 1)
	for i in 3: await process_frame
	P.party_step(16.0)
	ok(P.hpm["aida"] == P._mhp("aida"), "aida stands up in the hall")
	print("revive checks done, FAILS ", fails)
	quit()
