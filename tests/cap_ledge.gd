extends SceneTree
## the ledge hang and climb (needs a display): godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_ledge.gd -- OUTDIR
var out := ""
var n := 0
func frames(k: int) -> void:
	for i in k: await process_frame
func shot() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/f%03d.png" % n)
	n += 1
func rec(k: int) -> void:
	for i in k:
		await frames(1)
		await shot()
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
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 1 and P.SK.cur != null: P.SK.cur.equipped["estelle"] = ua[1]      # e.g. estelle_misuk
	var so = arena.solids[-1]
	# falling beside a ledge's end: she catches the corner and hangs, sways, then climbs
	var pl = arena.platforms[-1]
	await frames(10)
	P.position = Vector2(pl.x + pl.w + 14.0, pl.y + 120.0)
	P.on = false
	P.vy = 0.0
	P.set_anim("jump", 4)
	Input.action_press("right")
	await rec(14)
	Input.action_release("right")
	await rec(60)
	print("anim after catch: ", P.anim)
	Input.action_press("up")
	await rec(36)
	Input.action_release("up")
	print("anim after climb: ", P.anim, " y ", P.position.y, " top ", pl.y)
	# a short hop into it: straight into the climb from its middle
	P.position = Vector2(so.x - 30.0, arena.ground_y)
	P.on = true
	await frames(20)
	Input.action_press("right")
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await rec(40)
	Input.action_release("right")
	quit()
