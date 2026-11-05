extends SceneTree
## the owner's case: running off the rock toward the ledge and jumping (needs a display)
var out := ""
var n := 0
func shot() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/f%03d.png" % n)
	n += 1
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	for i in 10: await process_frame
	arena.enter_dungeon()
	for i in 60: await process_frame
	for m in arena.mobs: m.hp = 0.0
	var P = arena.player
	var so = arena.solids[-1]
	P.position = Vector2(1040.0, so.top)
	for i in 30: await process_frame
	Input.action_press("right")
	for i in 8: await process_frame
	Input.action_press("jump")
	for i in 5: await process_frame
	Input.action_release("jump")
	for i in 110:
		await process_frame
		await shot()
		if i % 8 == 0: print(P.anim, " ", P.position, " vy ", snappedf(P.vy, 0.01))
	quit()
