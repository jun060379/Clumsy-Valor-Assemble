extends SceneTree
## the camera following a run through the town, shot every frame (the scrolling: 지직거림 check; needs a display):
## godot --path . --fixed-fps 60 --resolution 2340x1080 -s tests/cap_pan.gd -- OUTDIR
var out := ""
func frames(k: int) -> void:
	for i in k: await process_frame
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.go_town(Vector2(6500.0, arena.ground_y), 1)
	await frames(10)
	arena.player.position = Vector2(6500.0, arena.level.LOWF)
	await frames(30)
	Input.action_press("right")
	await frames(20)
	for i in 40:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/p%02d.png" % i)
		await frames(1)
	Input.action_release("right")
	print("CAP done")
	quit()
