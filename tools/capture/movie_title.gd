extends SceneTree
## the title over the live town with its track, 30 s, for Movie Maker:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 900x500 --path . --fixed-fps 30 --write-movie OUT.avi -s tools/capture/movie_title.gd
var arena
func frames(n: int) -> void:
	for i in n: await process_frame
func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(3)
	# a save with three members so the town has life
	arena.fame.join()
	for c in ["aida", "luce"]: arena.toggle_member(c)
	arena.tod_h = 17.5
	var T = arena.ui_root.title
	T.active = true
	T.visible = true
	await frames(900)     # 30 s: gate-less desktop intro, section A, into the first wedge (45.6 s would need 1370)
	quit()
