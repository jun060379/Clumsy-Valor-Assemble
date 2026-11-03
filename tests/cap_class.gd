extends SceneTree
## Class labels on the character page (each member), the party page and the guild book's 인물 page (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_class.gd -- OUTDIR

var out := ""

func frames(k: int) -> void:
	for i in k: await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.rec = ["estelle", "aida", "luce"]
	arena.fame.r = 2
	var M = arena.ui_root.menu
	M.open_book("gbk", "people")
	await frames(80)
	await shot("book_people")
	M.close_page()
	await frames(30)
	for c in ["estelle", "aida", "luce"]:
		M.open_char(c)
		await frames(80)
		await shot("char_" + c)
		M.close_page()
		await frames(40)
	M.open_page("party")
	await frames(80)
	await shot("party")
	print("CAP done")
	quit()
