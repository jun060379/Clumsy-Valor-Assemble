extends SceneTree
## Kenin's ult cut-in splash, a few frames (needs a display):
## godot --path . --fixed-fps 30 --resolution 900x500 -s tests/cap_ult_kenin.gd -- OUTDIR
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
	arena.toggle_member("kenin")
	arena.enter_dungeon()
	await frames(40)
	arena.clear_room()
	var P = arena.player
	P.swap_cd = 0.0
	P.swap(false, "kenin")
	await frames(30)
	arena.ult.v["kenin"] = arena.ult.ULTMAX["kenin"]
	arena.ult.cd["kenin"] = 0.0
	arena.ult.try_ult()
	for i in 14:
		await frames(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/u%02d.png" % i)
	print("CAP done")
	quit()
