extends SceneTree
## the town at a few spots, the hero standing there (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_town.gd -- OUTDIR [old]   (old: the 1.35x originals)
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
	if args.size() > 1: arena.level.hx = {}
	var L = arena.level
	for s in [["hall", L.HDOOR + 60.0, L.TTOP], ["cottage", 6900.0, L.LOWF], ["bigtree", 8900.0, L.LOWF], ["barn", 5700.0, L.G]]:
		arena.player.position = Vector2(s[1], s[2])
		await frames(40)
		await shot(s[0])
	print("CAP done")
	quit()
