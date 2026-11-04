extends SceneTree
## skill texts with final values and a value's breakdown card (needs a display):
## godot --path . --resolution 900x500 -s tests/cap_values.gd -- OUTDIR
func frames(k: int) -> void:
	for i in k: await process_frame
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.rec = ["estelle", "aida", "luce", "kenin"]
	var M = arena.ui_root.menu
	M.open_char("luce")
	await frames(90)
	var pg = M.ext["char"]
	pg._tab("skill")
	await frames(60)
	pg.mx._pick_move(4)
	await frames(60)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/val_skill.png")
	pg.mx.tip = "#luce.heal"
	pg.mx.tip_p = Vector2(600, 300)
	pg.mx.tip_t = 0.0
	await frames(30)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/val_tip.png")
	print("SHOT")
	quit()
