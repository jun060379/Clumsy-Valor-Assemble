extends SceneTree
## Town frame time (owner 2026-11-06 "렉"): the hero stands at a few spots of the town, MEASURE frames each; prints the
## mean and the 99th-percentile frame time per spot and overall. Headless = scripts + _draw building (no GPU raster).
## godot --headless --path . --fixed-fps 60 -s tests/bench_town.gd [-- MEASURE]
const SPOTS := [1640.0, 2100.0, 3000.0, 4050.0, 5107.0, 6300.0, 7500.0]
func _initialize() -> void:
	var n := 240
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: n = int(args[0])
	seed(1)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	for i in 10: await process_frame
	arena.go_town(Vector2(5107.0, arena.ground_y), 1)
	for i in 20: await process_frame
	var all := []
	for x in SPOTS:
		arena.player.position.x = x
		arena.player.position.y = arena.level.floor_at(x)
		for i in 30: await process_frame
		var ft := []
		var t0 := Time.get_ticks_usec()
		for i in n:
			await process_frame
			var t := Time.get_ticks_usec()
			ft.append(t - t0)
			t0 = t
		all += ft
		print("TOWN x=%d %s" % [x, _st(ft)])
	print("TOWN all %s" % _st(all))
	quit()
func _st(ft: Array) -> String:
	var s := ft.duplicate()
	s.sort()
	var m := 0.0
	for v in ft: m += v
	m /= ft.size()
	return "mean=%.2fms p99=%.2fms" % [m / 1000.0, s[int(s.size() * 0.99)] / 1000.0]
