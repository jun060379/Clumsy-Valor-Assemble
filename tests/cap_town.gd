extends SceneTree
## the town at a few spots, the hero standing there (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_town.gd -- OUTDIR [old] [nolit]   (old: the 1.35x originals; nolit: no shade / lights)
var out := ""
func frames(k: int) -> void:
	for i in k: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.go_town(Vector2(5107.0, arena.ground_y), 1)
	await frames(20)
	if args.has("old"): arena.level.hx = {}
	if args.has("nolit"): arena.level.lit.visible = false
	var L = arena.level
	for a in args:                       # at=X[,Y]: stand there and shoot every other frame for 2 s (h=HOUR sets the time)
		if String(a).begins_with("h="): arena.tod_h = float(String(a).substr(2))
		if String(a).begins_with("w="): arena.weather = String(a).substr(2)
	for a in args:
		if String(a).begins_with("at="):
			var xy := String(a).substr(3).split(",")
			arena.player.position = Vector2(float(xy[0]), L.floor_at(float(xy[0])) if xy.size() < 2 else float(xy[1]))
			await frames(40)
			for i in 60:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(out + "/a%02d.png" % i)
				await frames(2)
			print("CAP done")
			quit()
			return
	if args.has("camp"):                 # the campfire, every other frame for 3 s
		arena.player.position = Vector2(4250.0, L.G)
		await frames(40)
		for i in 90:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(330, 280, 300, 170)).save_png(out + "/c%02d.png" % i)
			await frames(2)
		print("CAP done")
		quit()
		return
	for s in [["camp", 4300.0, L.G], ["hall", L.HDOOR + 60.0, L.TTOP], ["cottage", 6900.0, L.LOWF], ["bigtree", 8900.0, L.LOWF], ["barn", 5700.0, L.G]]:
		arena.player.position = Vector2(s[1], s[2])
		await frames(40)
		await shot(s[0])
	print("CAP done")
	quit()
