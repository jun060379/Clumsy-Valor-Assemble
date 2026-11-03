extends SceneTree
## Kenin's character page, every tab (his illustrations on 상세 · 장비 · 스킬 · 기억 · 기록) (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_kenin_ui.gd -- OUTDIR
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
	arena.fame.rec = ["estelle", "aida", "luce", "kenin"]
	arena.fame.r = 2
	var M = arena.ui_root.menu
	M.open_char("kenin")
	await frames(90)
	var pg = M.ext["char"]
	for tb in ["attr", "gear", "skill", "match", "rec"]:
		pg._tab(tb)
		await frames(110)
		await shot("kenin_" + tb)
	print("CAP done")
	quit()
