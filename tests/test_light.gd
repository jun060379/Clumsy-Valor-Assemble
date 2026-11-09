extends SceneTree
## outdoor light (WP5-7): shaped lights instead of Light2Ds, the shade mask, hall windows, night sky, fog, sky ambient
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func lights_in(n: Node) -> int:
	var c := 1 if n is Light2D else 0
	for ch in n.get_children(): c += lights_in(ch)
	return c

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var LIT := load("res://scripts/lit.gd")
	var SKY := load("res://scripts/sky.gd")
	arena.weather = "clear"
	arena.go_town(Vector2(4400, arena.ground_y), 1)
	await process_frame
	var T = arena.level
	ok(lights_in(arena) == 0, "no Light2D in the town (nothing lights the characters through their albedo)")
	ok(arena.get_children().filter(func(c): return c is CanvasModulate).is_empty(), "no CanvasModulate: the ambient is lit.gd's multiply")
	# noon: sun shadows and clouds on, lamps weak
	arena.tod_h = 12.0
	for i in 5: arena._process(0.016)
	ok(T.lit.L.size() >= 7 + 28 + 3, "light sources: lamps, bulbs, fires, fountain (%d)" % T.lit.L.size())
	ok(T.lit.L.all(func(l): return l.has("boost")), "every light has its shade boost")
	ok(T.shade_occluders().size() >= 15, "occluders: buildings, the hall, trees")
	ok(T.shade.sun > 0.9 and T.shade.cloud_mat.get_shader_parameter("alpha") > 0.9, "noon: full sun, clouds at full strength")
	var d8: Vector2 = LIT.sun_dir(8.0)
	var d17: Vector2 = LIT.sun_dir(17.0)
	ok(d8.x < -0.5 and d17.x > 0.5 and absf(LIT.sun_dir(12.0).x) < 0.1, "shadows lean with the hour (8:00 %.2f, 17:00 %.2f)" % [d8.x, d17.x])
	# under the terraces: with the plaza open to the sun (PLAZA_SUN) the plaza is open to the noon sun (owner 2026-11-09): no deep
	# shade, no boost, clouds pass over it; the deep shade comes back with the sun low behind the town and at night
	var under: Array = T.lit.L.filter(func(l): return l["k"] == "bulb")
	if T.PLAZA_SUN:
		ok(T.deep_shade() < 0.01 and not under.is_empty() and under[0]["boost"] <= 1.0, "noon: the lower plaza in the sun, bulbs not boosted")
		ok(T.cloud_bottom(3000.0) > T.LOWF, "clouds pass over the slope and the lower plaza")
		arena.tod_h = 21.0
		ok(T.deep_shade() > 0.99, "night: the deep shade under the terraces is back")
		arena.tod_h = 12.0
	else:
		ok(not under.is_empty() and under[0]["boost"] > 1.0, "bulbs under the terraces burn brighter in the shade")
		ok(T.cloud_bottom(3000.0) < T.LOWF and T.cloud_bottom(8000.0) > T.LOWF, "no cloud shade on the lower plaza")
	# night: windows, stars, moon, no sun shade
	arena.tod_h = 21.0
	P_at(arena, Vector2(3100, T.TTOP))
	for i in 5: arena._process(0.016)
	ok(T.hall_win() > 0.99, "hall windows lit at 21:00")
	ok(T.lit.L.filter(func(l): return l["k"] == "win").size() == T.HALL_WIN.size(), "a window light per hall window")
	ok(T._win_on() and T.win_sv.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "the window canvas renders in front of the hall")
	ok(T.shade.sun < 0.01, "no sun shade at night")
	ok(SKY.night_k(arena.tod_now()) > 0.9, "the night sky shows at 21:00")
	ok(T.lit.amb.b > T.lit.amb.r and T.lit.amb.r < 0.5, "the blue night ambient (it multiplies the sky too)")
	arena.tod_h = 12.0
	for i in 3: arena._process(0.016)
	ok(T.hall_win() < 0.01 and not T._win_on(), "windows dark at noon")
	ok(SKY.night_k(arena.tod_now()) < 0.02, "no stars at noon")
	# the window silhouette
	arena.tod_h = 22.0
	T.life.sil_t = 0.0
	for i in 3: arena._process(0.016)
	ok(T.life.sil != null, "someone walks past a lit window")
	# the near-door glow
	P_at(arena, Vector2(T.HDOOR, T.TTOP))
	for i in 3: arena._process(0.016)
	ok(T.near_door != null and T.lit.L.any(func(l): return l["k"] == "soft" and absf(l["x"] - T.HDOOR) < 2.0 and l["r"] > 140.0), "the hall door glows when you stand at it")
	# rim lights for the character shader
	ok(T.rim_lights().size() == T.lit.L.size() + 1, "rim lights: the light list plus the sky")
	# the hall: shaped lights too
	arena.go_hall(0, Vector2(1760, arena.ground_y), 1)
	await process_frame
	for i in 3: arena._process(0.016)
	var H = arena.level
	ok(lights_in(arena) == 0, "no Light2D in the hall")
	ok(H.lit.L.size() > 0 and H.lit.L.any(func(l): return l["k"] == "fire" or l["k"] == "soft"), "hall lights (%d)" % H.lit.L.size())
	# the chandelier and the fires follow the hall's facilities
	if arena.fame != null:
		arena.fame.fac.erase("chand")
		for i in 2: arena._process(0.016)
		ok(not H.lit.L.any(func(l): return l.has("chand")), "an unrestored chandelier gives no light")
		arena.fame.fac["chand"] = 1
		for i in 2: arena._process(0.016)
		ok(H.lit.L.any(func(l): return l.has("chand")), "the restored chandelier lights the lobby")
	# the training ground: the same light, its own occluders
	arena.go_training()
	await process_frame
	arena.tod_h = 12.0
	for i in 3: arena._process(0.016)
	var Y = arena.train
	ok(lights_in(arena) == 0, "no Light2D on the training ground")
	ok(Y.shade_occluders().size() == 4, "training occluders: the yard and three trees")
	ok(Y.lit.L.size() == 3 and Y.lit.L.all(func(l): return l["k"] == "lamp"), "three lamps with cones and pools")
	ok(Y.shade.sun > 0.9, "sun shadows on the training ground at noon")
	arena.tod_h = 21.0
	for i in 3: arena._process(0.016)
	ok(Y.lit.amb.r < 0.5 and SKY.night_k(arena.tod_now()) > 0.9, "night on the training ground")
	ok(Y.rim_lights().size() == 4, "training rim lights: three lamps and the sky")
	print("FAILS: ", fails)
	quit()

func P_at(arena, p: Vector2) -> void:
	arena.player.position = p
	arena.player.vy = 0.0
	arena.player.on = true
	arena.snap_camera()
