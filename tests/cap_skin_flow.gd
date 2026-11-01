extends SceneTree
## Costume flow capture in town (needs a display): godot --path . --fixed-fps 60 -s tests/cap_skin_flow.gd -- OUTDIR [SKIN_ID]
## One take: idle (breathing), a walk (as the townsfolk walk her), a run (keys), an attack combo out of the run, back to
## idle: OUTDIR/flow_<nnn>.png every 2nd frame. Then an idle close-up over one breath (2.8 s), cropped tight and scaled 3x
## with nearest filtering: OUTDIR/breath_<nnn>.png every 4th frame.

var out := ""
var arena
var P
var n := 0

func frames(k: int) -> void:
	for i in k: await process_frame

func shot(seq: String, w := 460, h := 340, up := 300, zoom := 1) -> void:
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	var sp: Vector2 = root.get_final_transform() * root.get_canvas_transform() * P.position
	var r := Rect2i(int(sp.x) - w / 2, int(sp.y) - up, w, h).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	var c := im.get_region(r)
	if zoom > 1: c.resize(c.get_width() * zoom, c.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	c.save_png("%s/%s_%03d.png" % [out, seq, n])
	n += 1

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
	arena.go_town(Vector2(500.0, arena.ground_y), 1)
	await frames(40)
	for f in arena.get("folk") if arena.get("folk") != null else []: f.visible = false
	P = arena.player
	P.switch_char("estelle")
	P.position = Vector2(500.0, arena.level.floor_at(500.0))
	P.dir = 1
	P.set_anim("idle")
	arena.snap_camera()
	await frames(20)
	# idle
	for i in 60:
		await process_frame
		if i % 2 == 0: await shot("flow")
	# walk (the player never walks: stepped by hand at townsfolk.gd WALKSP 0.2 px/ms, the costume's walk timing)
	P.set_process(false)
	P.set_physics_process(false)
	P.anim = "walk"
	P.f = 0
	var ft := 0.0
	for i in 70:
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
		if i % 2 == 0: await shot("flow")
	P.set_process(true)
	P.set_physics_process(true)
	P.set_anim("run")
	# run, then the combo out of it (taps, never held: a held key charges)
	Input.action_press("right")
	for i in 50:
		await process_frame
		if i % 2 == 0: await shot("flow")
	Input.action_release("right")
	for i in 110:
		if i in [0, 16, 34]: Input.action_press("attack")
		if i in [2, 18, 36]: Input.action_release("attack")
		await process_frame
		if i % 2 == 0: await shot("flow")
	# the breath close-up
	P.set_anim("idle")
	await frames(30)
	n = 0
	for i in 168:
		await process_frame
		if i % 4 == 0: await shot("breath", 150, 210, 195, 3)
	print("CAP done")
	quit()
