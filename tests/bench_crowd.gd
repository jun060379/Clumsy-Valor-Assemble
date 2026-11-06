extends SceneTree
## Perf bench (owner 2026-11-06): the scene with the most foes the game makes -- a tier-4 cave room with both of its
## waves up at once (10 foes) and a full party fighting -- reproduced from a fixed seed, the bot pressing the same keys
## on the same frames. Measures, over MEASURE frames after WARM:
##   - wall time per frame -> FPS average and 1% low (the 99th-percentile frame time)
##   - arena._process broken down by subsystem (arena.prof, µs per frame)
##   - a state hash (foes' and the player's positions and hp, rounded) after the run: the same code -> the same hash
## Prints RESULT lines; tools/bench.sh runs it under a display (rendering counts) and logs / compares.
## xvfb-run -a godot --path . --fixed-fps 60 --resolution 900x500 -s tests/bench_crowd.gd [-- MEASURE]
const WARM := 90
var MEASURE := 900

var fc := 0
## every frame of the setup starts the global RNG afresh too (by frame count), so nothing drifts in before measuring
func frames(k: int) -> void:
	for i in k:
		fc += 1
		seed(1000 + fc)
		await process_frame

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: MEASURE = int(args[0])
	seed(20261106)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.cfg.aim = "off"
	arena.repeat_ms = 0.0
	seed(5)
	arena.enter_dungeon()
	await frames(30)
	var D = arena.level
	var room_k = null
	for k in D.rooms:
		if D.rooms[k]["type"] == "fight" and int(D.rooms[k]["tier"]) == 4: room_k = k
	if room_k == null:
		for k in D.rooms:
			if D.rooms[k]["type"] == "fight": room_k = k
	D.from = "L"
	D.cur = room_k
	seed(6)
	D.enter()
	await frames(5)
	for m in arena.mobs.duplicate(): m.queue_free()
	arena.mobs.clear()
	seed(20261106)
	var P = arena.player
	var x0: float = P.position.x
	var i := 0
	for w in D.WAVES[4]:
		for e in w:
			var m = arena.spawn(e[0], x0 + 260.0 + i * 70.0, 0.0, -1.0, null, e.size() > 1, 4)
			m.hp = 1e9                 # nobody dies: the crowd stays the same size the whole run
			m.max_hp = 1e9
			i += 1
	P.hp = 1e9
	for c in P.hpm.keys(): P.hpm[c] = 1e9
	if arena.get("amb") != null: arena.amb.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(WARM)
	seed(20261106)
	if arena.runes != null: arena.runes.rng.seed = 20261106
	arena.prof = {}
	var ft := PackedInt64Array()
	var t0 := Time.get_ticks_usec()
	for f in MEASURE:
		for a in ["left", "right", "attack", "guard", "dash", "jump"]: Input.action_release(a)
		match f % 120:
			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19: Input.action_press("right")
			40, 48, 56, 64, 72: Input.action_press("attack")
			90: Input.action_press("dash")
			100: Input.action_press("jump")
			60, 61, 62, 63, 64, 65, 66, 67, 68, 69: Input.action_press("left")
		seed(20261106 + f)        # the global RNG restarts every frame: a stray draw (audio, wall-clock fx) cannot carry over
		if arena.runes != null: arena.runes.rng.seed = 20261106 + f
		await process_frame
		var t := Time.get_ticks_usec()
		ft.append(t - t0)
		t0 = t
	var sorted := Array(ft)
	sorted.sort()
	var mean := 0.0
	for v in ft: mean += v
	mean /= ft.size()
	var p99: float = sorted[int(sorted.size() * 0.99)]
	print("RESULT foes=%d frames=%d" % [arena.mobs.size(), MEASURE])
	print("RESULT fps_avg=%.1f fps_1pct_low=%.1f frame_ms_avg=%.2f frame_ms_p99=%.2f" % [1e6 / mean, 1e6 / p99, mean / 1000.0, p99 / 1000.0])
	var keys: Array = arena.prof.keys()
	keys.sort_custom(func(a, b): return arena.prof[a] > arena.prof[b])
	for k in keys:
		print("RESULT prof %s=%.3f ms/frame" % [k, arena.prof[k] / 1000.0 / MEASURE])
	print("RESULT prof render+other=%.3f ms/frame" % (mean / 1000.0 - _sum(arena.prof) / 1000.0 / MEASURE))
	var h := ""
	for m in arena.mobs:
		h += "%s:%d,%d,%d;" % [m.kind, roundi(m.position.x), roundi(m.position.y), roundi((1e9 - m.hp) / 25.0)]
	# hp lost counted in 25s: one hit's size still wobbles run to run (a timing read off the audio clock -- not tracked
	# down yet), positions are exact
	h += "P:%d,%d,%d" % [roundi(P.position.x), roundi(P.position.y), roundi((1e9 - P.hp) / 25.0)]
	print("RESULT state_hash=%s" % h.md5_text())
	if OS.get_environment("BENCH_DUMP") != "": print("STATE ", h)
	quit()

func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k in d: s += d[k]
	return s
