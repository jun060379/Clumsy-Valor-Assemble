extends SceneTree
## Screenshots of the 옷장 (wardrobe) and the character page's 의상 tab (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_skin_ui.gd -- OUTDIR

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
	arena.fame.rec = ["estelle", "aida", "luce"]
	arena.fame.r = 2
	arena.fame.fac["wardrobe"] = 1
	arena.shilling = 420
	var S = arena.skins
	S.grant("estelle_misuk", "story", true)
	S.grant("estelle_s1", "fame", true)
	S.grant("aida_s2", "level", true)
	var dx := 3002.0
	for d in load("res://scripts/hall_data.gd").doors():
		if d["act"] == "wardrobe": dx = d["x"]
	arena.go_hall(1, Vector2(dx, 430.0), 1)
	await frames(30)
	await shot("hall_wardrobe_door")
	var M = arena.ui_root.menu
	M.open_wardrobe()
	await frames(110)
	await shot("wardrobe_open")
	var W = M.wardrobe
	W._key(KEY_RIGHT)                 # 미숙한 결의
	await frames(45)
	await shot("wardrobe_misuk")
	W._key(KEY_ENTER)
	await frames(18)
	await shot("wardrobe_change")
	await frames(60)
	W._key(KEY_RIGHT)
	W._key(KEY_RIGHT)                 # the shop costume, art not in yet
	await frames(50)
	await shot("wardrobe_wip_shop")
	W._key(KEY_E)
	await frames(90)
	await shot("wardrobe_aida")
	W._key(KEY_Q)
	await frames(60)
	W.sel = 0
	W._pick(0)
	W._key(KEY_ENTER)
	await frames(40)
	await shot("wardrobe_chosim")
	W._key(KEY_ESCAPE)
	await frames(80)
	M.open_char("estelle")
	await frames(20)
	var C = M.ext["char"]
	C._key(KEY_LEFT)
	await frames(70)
	await shot("char_wear_tab")
	C._key(KEY_DOWN)
	await frames(50)
	await shot("char_wear_misuk")
	C._key(KEY_DOWN)
	await frames(50)
	await shot("char_wear_wip")
	print("CAP done")
	quit()
