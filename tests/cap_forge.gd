extends SceneTree
## the forge's stations with the gear sprites (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_forge.gd -- OUTDIR
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
	var R = arena.runes
	for i in 9: R.gearbag.append(R.make_gear(["normal", "rare", "epic", "legend"][i % 4] if false else R.roll_grade0(0.6)))
	if arena.get("fame") != null: arena.fame.bran = true
	var M = arena.ui_root.menu
	M.open_bran(false, "흐흐, 왔습니까.")
	await frames(10)
	M.bran_page.choices[0][2].call()
	await frames(90)
	M.forge.c = "estelle"
	M.forge.slot = "weapon"
	await frames(60)
	await shot("forge_up")
	M.forge.picking_open()
	await frames(60)
	await shot("forge_pick")
	M.forge.picking_close()
	await frames(30)
	M.forge.go_station("dis")
	await frames(90)
	await shot("forge_dis")
	M.forge._drag(Vector2(0, -150), Vector2.ZERO)
	await frames(10)
	await shot("forge_dis_drag")
	print("CAP done")
	quit()
