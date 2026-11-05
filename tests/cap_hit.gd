extends SceneTree
## the baked enemy hit, both ways (needs a display): godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_hit.gd -- OUTDIR
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
	await frames(30)
	var P = arena.player
	for k in 8:
		arena.pfx.hit(P.position.x + 90.0, P.position.y - 70.0, 1, 1.25)
		arena.pfx.hit(P.position.x - 90.0, P.position.y - 70.0, -1, 1.0)
		await frames(k + 1)
		await shot("hit_%d" % k)
		await frames(40)
	print("CAP done")
	quit()
