extends SceneTree
## scripted cave fight, one PNG per frame and every sfx start logged as "SFX <name> <frame>" (sound-timing checks):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 900x500 --fixed-fps 30 --path . -s tools/capture/cap_fight.gd -- OUTDIR
## OUTDIR defaults to user://cap_fight. Frames: OUTDIR/f0000.png …
var arena
var out := "user://cap_fight"
var last := {}
var fi := 0

func frames(n: int) -> void:
	for i in n: await process_frame

func press(a: String, n := 2) -> void:
	Input.action_press(a)
	await rec(n)
	Input.action_release(a)

func poll() -> void:
	for e in arena.sfx_log:
		print("SFX ", e[0], " ", fi, " ", e[1])
	arena.sfx_log.clear()

func rec(n: int) -> void:
	for i in n:
		await process_frame
		await RenderingServer.frame_post_draw
		poll()
		root.get_texture().get_image().save_png(out + "/f%04d.png" % fi)
		fi += 1

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: out = a[0]
	if out.begins_with("user://"): out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.join()
	for c in ["aida", "luce"]: arena.toggle_member(c)
	arena.enter_dungeon()
	await frames(40)
	print("ENTER ", fi)
	var P = arena.player
	arena.clear_room()
	arena.snap_camera()
	await rec(20)
	# three goblins to the right, walk up to them
	for i in 3: arena.spawn("goblin", P.position.x + 260.0 + i * 60.0, 0.0)
	await rec(20)
	Input.action_press("right")
	await rec(22)
	Input.action_release("right")
	await rec(4)
	# combo 1-2-3
	for i in 3:
		await press("attack")
		await rec(7)
	await rec(10)
	# dash through, turn, combo again
	Input.action_press("right")
	await press("dash", 3)
	Input.action_release("right")
	await rec(8)
	Input.action_press("left")
	await rec(2)
	Input.action_release("left")
	for i in 3:
		await press("attack")
		await rec(7)
	await rec(6)
	# guard (a block if a goblin swings), then a jump attack
	Input.action_press("guard")
	await rec(20)
	Input.action_release("guard")
	await rec(6)
	await press("jump", 3)
	await rec(4)
	await press("attack")
	await rec(16)
	# the ult: fill the gauge and fire
	if arena.ult != null:
		arena.ult.v[P.who] = arena.ult.ULTMAX[P.who]
		arena.ult.cd[P.who] = 0.0
		Input.action_press("ult")
		await rec(3)
		Input.action_release("ult")
		await rec(110)
	# a last combo on whatever is left
	for i in 3:
		await press("attack")
		await rec(7)
	await rec(30)
	print("END ", fi)
	quit()
