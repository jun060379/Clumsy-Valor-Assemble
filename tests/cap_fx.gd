extends SceneTree
## Pixel-effect fidelity captures (needs a display, window 900x500): godot --path . -s tests/cap_fx.gd -- JOBS.json OUTDIR
## On the training ground at noon, post off. Each job spawns one effect with the prototype's arguments for that attack,
## holds it at time t, and saves the frame with and without the effect layer (NAME_a / NAME_b, a 520x400 window
## around the hero; offs.json: the window's corner relative to her feet). job: {n, c, dir, kind: arc|thrust|hit, arc: [cx, cy, r, a0, a1, sy], x1, yo, t}

func frames(n: int) -> void:
	for i in n:
		await process_frame

func grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.go_training()
	await frames(30)
	for d in arena.dummies: d.visible = false
	arena.tod_auto = false
	arena.tod_h = 12.0
	arena.screen_fx = false
	var P = arena.player
	var X = arena.pfx
	X.dbg_k = 0.0
	P.visible = false
	await frames(60)          # the first frames after entering still settle (camera, lights): wait them out
	var offs := {}
	for j in jobs:
		X.clear()
		P.switch_char(j["c"])
		P.dir = int(j["dir"])
		P.position = Vector2(700, arena.ground_y)
		P.set_anim("idle")
		arena.snap_camera()
		P.visible = false
		await frames(4)
		var cs: float = P.CSCALE
		var px: float = P.position.x
		var py: float = P.position.y
		var d: int = P.dir
		match j["kind"]:
			"arc":
				var a: Array = j["arc"]
				X.slash(Vector2(px + d * a[0] * cs, py + a[1] * cs), a[2] * cs * 0.86 * 1.12, a[3], a[4], d, P.who, float(a[5]))
			"thrust": X.thrust(px + d * 20 * cs, px + d * float(j["x1"]) * cs, py - float(j["yo"]) * cs, P.who)
			"hit": X.hit(px + d * 120, py - 80, d, 1.0)
		for e in X.L:
			e["seed"] = 3.0
			e["t"] = float(j["t"])
		await frames(3)
		var A := await grab()
		X.visible = false
		await frames(3)
		var B := await grab()
		X.visible = true
		var sp: Vector2 = root.get_final_transform() * root.get_canvas_transform() * P.position
		var r := Rect2i(int(roundf(sp.x)) - 260, int(roundf(sp.y)) - 320, 520, 400).intersection(Rect2i(Vector2i.ZERO, A.get_size()))
		A.get_region(r).save_png(out + "/" + j["n"] + "_a.png")
		B.get_region(r).save_png(out + "/" + j["n"] + "_b.png")
		offs[j["n"]] = [r.position.x - int(roundf(sp.x)), r.position.y - int(roundf(sp.y))]
	FileAccess.open(out + "/offs.json", FileAccess.WRITE).store_string(JSON.stringify(offs))
	print("done ", jobs.size())
	quit()
