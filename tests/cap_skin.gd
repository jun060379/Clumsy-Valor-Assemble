extends SceneTree
## Costume captures in town (needs a display): godot --path . --fixed-fps 60 -s tests/cap_skin.gd -- OUTDIR SKIN_ID
## Plays idle, a start into the run, the stop, a turn, a standing jump, a running jump, and a walk (as the townsfolk walk),
## and saves a crop around her every few frames: OUTDIR/<seq>_<nnn>.png (prints the list).

var out := ""
var arena
var n := 0

func frames(k: int) -> void:
	for i in k: await process_frame

func shot(seq: String) -> void:
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	var P = arena.player
	var sp: Vector2 = root.get_final_transform() * root.get_canvas_transform() * P.position
	var r := Rect2i(int(sp.x) - 210, int(sp.y) - 270, 420, 320).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	im.get_region(r).save_png("%s/%s_%03d.png" % [out, seq, n])
	n += 1

func hold(k: String, on: bool) -> void:
	if on: Input.action_press(k)
	else: Input.action_release(k)

func run_seq(seq: String, k: int, every: int) -> void:
	n = 0
	for i in k:
		await process_frame
		if i % every == 0: await shot(seq)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var skin: String = args[1] if args.size() > 1 else "estelle_base"
	DirAccess.make_dir_recursive_absolute(out)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.skins.grant(skin, "dev", true)
	print("equip ", skin, " ", arena.skins.equip(skin), " worn ", arena.SKINS.worn("estelle"))
	arena.tod_auto = false
	arena.tod_h = 12.0
	arena.weather = "clear"
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await frames(40)
	for f in arena.get("folk") if arena.get("folk") != null else []: f.visible = false
	var P = arena.player
	P.switch_char("estelle")
	P.position.y = arena.level.floor_at(900.0)
	P.set_anim("idle")
	arena.snap_camera()
	await frames(20)
	await run_seq("idle", 48, 4)
	hold("right", true)
	await run_seq("run", 80, 2)
	hold("right", false)
	await run_seq("stop", 30, 2)
	hold("left", true)
	await run_seq("turn", 14, 1)
	hold("left", false)
	await frames(30)
	hold("jump", true)
	await run_seq("jump", 70, 2)
	hold("jump", false)
	await frames(30)
	hold("right", true)
	await frames(50)
	hold("jump", true)
	await run_seq("runjump", 60, 2)
	hold("jump", false)
	hold("right", false)
	await frames(60)
	# the walk as the townsfolk walk her: 0.2 px/ms (townsfolk.gd WALKSP), the costume's walk timing
	P.set_process(false)
	P.set_physics_process(false)
	P.anim = "walk"
	P.f = 0
	var ft := 0.0
	n = 0
	for i in 140:
		var dt := 1000.0 / 60.0
		P.position.x += 0.2 * dt
		P.position.y = arena.level.floor_at(P.position.x)
		ft += dt
		var du: Array = arena.SKINS.entry("estelle", "walk")[1]
		while ft >= float(du[P.f % du.size()]):
			ft -= float(du[P.f % du.size()])
			P.f = (P.f + 1) % du.size()
		arena.snap_camera()
		P.queue_redraw()
		await process_frame
		if i % 2 == 0: await shot("walk")
	print("CAP done")
	quit()
