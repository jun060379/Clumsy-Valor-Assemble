extends SceneTree
## 캐릭터 도트화 fidelity captures (needs a display): godot --path . -s tests/cap_pix.gd -- JOBS.json OUTDIR
## Each job draws one character frame with the char_pix material into a 400x440 transparent SubViewport at 1 world px
## per pixel, the feet at (200, 400) — the prototype's charPix canvas (ox = cx - 200, oy = cy - 400).
## job: {n, c, anim, f, mode, X, Y, dir, breath?, lights?: [{x, y, r, a, c: "r,g,b"}]}

func frames(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out: String = args[1]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(5)
	var P = arena.player
	var vp := SubViewport.new()
	vp.size = Vector2i(400, 440)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var node := Node2D.new()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat: ShaderMaterial = P.pix_mat().duplicate()
	P.pix_mat_add(mat)
	node.material = mat
	vp.add_child(node)
	var hold := [{}]     # lambdas capture locals by value: share a container
	node.draw.connect(func():
		var job: Dictionary = hold[0]
		if job.is_empty(): return
		var X: float = job["X"]
		var Y: float = job["Y"]
		P.draw_frame(job["c"], job["anim"], int(job["f"]), Vector2(X, Y), int(job["dir"]), Color.WHITE, "", node, NAN, 0, "cap", float(job.get("breath", -1.0)), job.has("lights")))
	for j in jobs:
		hold[0] = j
		# world (X - 200 + i, Y - 400 + j) -> pixel (i, j)
		vp.canvas_transform = Transform2D(0.0, Vector2(200.0 - float(j["X"]), 400.0 - float(j["Y"])))
		P.set_pix(j["mode"])
		var Ls: Array = []
		for l in j.get("lights", []):
			var cc: PackedStringArray = String(l["c"]).split(",")
			Ls.append([Vector2(l["x"], l["y"]), float(l["r"]), float(l.get("a", 1.0)), Color8(int(cc[0]), int(cc[1]), int(cc[2]))])
		arena.pfx.set_process(false)
		P.pix_frame(1.0, Ls)
		node.queue_redraw()
		await frames(3)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out + "/" + j["n"] + ".png")
	print("done ", jobs.size())
	quit()
