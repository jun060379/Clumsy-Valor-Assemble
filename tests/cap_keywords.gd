extends SceneTree
## 키워드 강조 in the skill and memory texts, and a keyword's card (needs a display):
## godot --path . --resolution 900x500 -s tests/cap_keywords.gd -- OUTDIR
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
	pg._tab("skill")
	await frames(60)
	pg.mx._pick_move(3)
	await frames(60)
	await shot("kw_skill")
	pg.mx.tip = "표식"
	pg.mx.tip_p = Vector2(640, 330)
	pg.mx.tip_t = 0.0
	await frames(30)
	await shot("kw_tip")
	pg._tab("match")
	await frames(60)
	pg.mx._node("C6")
	await frames(40)
	await shot("kw_node")
	print("CAP done")
	quit()
