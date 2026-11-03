extends SceneTree
## 편성: the three slots, the desk of files, a file lifted, sent (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_party.gd -- OUTDIR
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
	arena.fame.rec = ["estelle", "aida", "luce", "kenin"]
	arena.fame.r = 2
	var P = arena.player
	P.party = ["estelle", "luce"]
	var M = arena.ui_root.menu
	M.open_page("party")
	await frames(80)
	await shot("p1_slots")
	var pg = M.ext["party"]
	pg.slot = 2
	await frames(30)
	await shot("p2_empty_pick")
	pg.open_desk()
	await frames(50)
	await shot("p3_desk")
	pg.file_tap("kenin")
	await frames(25)
	await shot("p4_lift")
	pg.file_tap("kenin")
	await frames(12)
	await shot("p5_fly")
	await frames(16)
	await shot("p6_stamp")
	await frames(60)
	await shot("p7_back")
	print("party ", P.party)
	print("CAP done")
	quit()
