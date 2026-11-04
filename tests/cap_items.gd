extends SceneTree
## Gear icons on the character screen's 장비 tab (rows, card, swap list) and the bag (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_items.gd -- OUTDIR
const RN := preload("res://scripts/runes.gd")
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
	var R = arena.runes
	for n in [["바스타드 소드", "weapon", "전사"], ["응시하는 마도서", "weapon", "워락"], ["광휘의 홀", "weapon", "사제"], ["가죽 두건", "head", ""], ["사슬 갑옷", "body", ""], ["사냥꾼 장화", "shoe", ""], ["유리 펜던트", "acc", ""], ["그림자 송곳니", "weapon", "도적"]]:
		var it := {"n": n[0], "slot": n[1], "g": "rare", "lv": 3, "r": 1, "seed": randi(), "sub": null, "rune": "", "rs": 1}
		if n[2] != "": it["cls"] = n[2]
		if n[1] in ["head", "body", "shoe"]: it["wt"] = "경갑"
		R.gearbag.append(it)
	var M = arena.ui_root.menu
	for c in ["aida", "kenin"]:
		M.open_char(c)
		await frames(60)
		var pg = M.ext["char"]
		pg._tab("gear")
		await frames(90)
		await shot("gear_" + c)
		pg._pick_gi(0)
		pg.picking = true
		await frames(40)
		await shot("swap_" + c)
		M.close_page()
		await frames(40)
	M.open_page("bag")
	await frames(90)
	await shot("bag")
	var bg = M.ext["bag"]
	bg._cat("rune")
	await frames(80)
	await shot("bag_rune")
	M.close_page()
	await frames(40)
	for k in RN.RUNE: R.seen_r[k] = 1
	M.open_codex("rune", "oath")
	await frames(120)
	await shot("codex_rune")
	print("CAP done")
	quit()
