extends SceneTree
## the ledge lift and the rock vault (needs a display): godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_ledge.gd -- OUTDIR
var out := ""
func frames(k: int) -> void:
	for i in k: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.enter_dungeon()
	await frames(60)
	for m in arena.mobs: m.hp = 0.0
	var P = arena.player
	var so = arena.solids[-1]
	P.position = Vector2(so.x - 60.0, arena.ground_y)
	await frames(30)
	Input.action_press("right")
	await frames(3)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	for k in 40:
		await frames(1)
		await shot("a%02d" % k)
	Input.action_release("right")
	# under the ledge: a full jump, then a late double jump that falls a bit short
	var pl = arena.platforms[-1]
	P.position = Vector2(pl.x + 60.0, arena.ground_y)
	await frames(30)
	Input.action_press("jump")
	await frames(30)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	for k in 50:
		await frames(1)
		await shot("b%02d" % k)
	quit()
