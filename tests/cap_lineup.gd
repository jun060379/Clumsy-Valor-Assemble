extends SceneTree
## The four members in control at the same spot in town, idle and a run frame, the screen crops side by side (needs a display):
## godot --path . --resolution 900x500 -s tests/cap_lineup.gd -- OUTDIR
var out := ""

func frames(k: int) -> void:
	for i in k: await process_frame

func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.join()
	arena.fame.rec.append("kenin")
	arena.tod_h = 13.0
	var P = arena.player
	var crops: Array = []
	for c in ["estelle", "aida", "luce", "kenin"]:
		P.switch_char(c)
		P.who = c
		P.position = Vector2(2700.0, arena.level.floor_at(2700.0))
		P.dir = 1
		P.set_anim("idle", 0)
		arena.snap_camera()
		await frames(20)
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		var sp: Vector2 = P.get_global_transform_with_canvas().origin
		crops.append(img.get_region(Rect2i(int(sp.x) - 90, int(sp.y) - 170, 180, 190)))
		P.set_anim("run", 2)
		await frames(1)
		await RenderingServer.frame_post_draw
		img = root.get_texture().get_image()
		crops.append(img.get_region(Rect2i(int(sp.x) - 90, int(sp.y) - 170, 180, 190)))
	var sheet := Image.create(180 * crops.size(), 190, false, Image.FORMAT_RGBA8)
	for i in crops.size():
		sheet.blit_rect(crops[i], Rect2i(0, 0, 180, 190), Vector2i(180 * i, 0))
	sheet.save_png(out + "/lineup.png")
	print("CAP done")
	quit()
