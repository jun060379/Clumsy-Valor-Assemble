extends SceneTree
## Full-screen fidelity captures (needs a display, window 900x500): godot --path . -s tests/cap_scene.gd -- SHOTS.json OUTDIR
## shot: {n, scene: town|train|dungeon|hall, x, tod, c, dir, pix, post, fx: none|slash|attack2|pillar|heal|thrust, t}
## Prints the hero's screen position for each shot (to line crops up with the prototype's).

func frames(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var shots: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	var P = arena.player
	var X = arena.pfx
	var cur := ""
	for s in shots:
		var sc: String = s.get("scene", "town")
		if sc != cur:
			cur = sc
			if sc == "town": arena.go_town(Vector2(s["x"], arena.ground_y), int(s.get("dir", 1)))
			elif sc == "dungeon": arena.enter_dungeon()
			elif sc == "hall": arena.go_hall(0, Vector2(s["x"], arena.ground_y), int(s.get("dir", 1)))
			else: arena.go_training()
			await frames(40)
			for m in arena.mobs: m.visible = false
		arena.tod_auto = false
		arena.tod_h = float(s.get("tod", 12.0))
		arena.weather = "clear"
		P.switch_char(s.get("c", "estelle"))
		P.dir = int(s.get("dir", 1))
		var gy: float = arena.level.floor_at(float(s["x"])) if arena.level != null and arena.level.has_method("floor_at") else arena.ground_y
		P.position = Vector2(float(s["x"]), gy)
		P.set_anim("idle")
		P.set_pix(s.get("pix", "shade"))
		arena.screen_fx = bool(s.get("post", true))
		arena.snap_camera()
		X.clear()
		X.dbg_k = 0.0
		var cs: float = P.CSCALE
		var px: float = P.position.x
		var py: float = P.position.y
		var d: int = P.dir
		match s.get("fx", "none"):
			"slash": X.slash(Vector2(px + d * 10 * cs, py - 75 * cs), 80 * cs * 0.86 * 1.12, -100, 30, d, P.who)
			"attack2": X.slash(Vector2(px + d * 4 * cs, py - 62 * cs), 100 * cs * 0.86 * 1.12, 205, -12, d, P.who, 0.4)
			"pillar": X.pillar(px + d * 150, py, cs)
			"heal":
				seed(7)
				for i in 6: X.heal_cross(px, py, cs)
			"thrust": X.thrust(px + d * 20 * cs, px + d * 170 * cs, py - 50 * cs, P.who)
		for e in X.L:
			e["seed"] = 3.0
			e["t"] = float(s.get("t", 60.0))
		await frames(int(s.get("wait", 30)))
		for e in X.L: e["t"] = float(s.get("t", 60.0))
		await frames(3)
		await RenderingServer.frame_post_draw
		if s.get("dbg_bloom", false):
			var pf = arena.get("post")
			for k in pf.bsv.size():
				pf.bsv[k].get_texture().get_image().save_png(out + "/" + s["n"] + "_b%d.png" % k)
		var im: Image = root.get_texture().get_image()
		im.save_png(out + "/" + s["n"] + ".png")
		var sp: Vector2 = root.get_final_transform() * root.get_canvas_transform() * P.position
		print("SHOT ", s["n"], " ", sp.x, " ", sp.y)
	quit()
