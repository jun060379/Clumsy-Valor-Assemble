extends SceneTree
## Screens with Korean text, to check for tofu boxes (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_fonts.gd -- OUTDIR
## In a web build (exported with tests/ included, run with -s res://tests/cap_fonts.gd) it prints SHOT and waits 2 s instead.
## The rare syllables (똠 쀍 햏 뷁 펲 닭 읊, outside KS X 1001) go into a talk line and a notice on purpose.

const RARE := "똠 쀍 햏 뷁 펲 닭 읊 · ★ ≫ Ⓧ ♪ ← → ✓ ⚠"

var out := ""

func frames(k: int) -> void:
	for i in k: await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if OS.has_feature("web"):          # the page's screenshot is taken by the browser driver on this line
		print("SHOT ", name)
		await create_timer(2.0).timeout
		return
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "user://cap_fonts"
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.rec = ["estelle", "aida", "luce"]
	arena.fame.r = 2
	arena.shilling = 420
	var M = arena.ui_root.menu

	# talk box: a line with the rare syllables, then Eilin's desk choices
	arena.open_dialog("eilin", null, "에일린", "길드 접수원", ["뷁! 똠얌꿍 먹고 닭 한 마리, 쀍햏 펲 읊조리며 ♪ — 「길드」 《어설픈 용맹》 ≫"])
	arena.dlg.shown = 999.0
	await frames(30)
	await shot("dialog_rare")
	arena.dlg.active = false
	arena.fame.notice(RARE, "알림", Color.WHITE, true, 60000.0)
	arena.fame.notice("의뢰 완료 · 명성 +12 ★", "", Color("#ffd34d"), false, 60000.0)
	await frames(150)                    # past the decode glitch
	await shot("notice")
	arena.fame.eil_work()
	arena.dlg.shown = 999.0
	await frames(40)
	await shot("dialog_desk")
	arena.dlg.active = false
	await frames(5)

	for b in [["gbk", "quest"], ["gbk", "fac"], ["gbk", "people"], ["abk", "home"]]:
		M.open_book(b[0], b[1])
		await frames(70)
		await shot("book_%s_%s" % b)
		M.close_page()
		await frames(30)

	for p in ["bag", "forge", "opts"]:
		M.open_page(p)
		await frames(70)
		await shot("page_" + p)
		M.close_page()
		await frames(30)

	M.open_codex("rune")
	await frames(90)
	await shot("codex_rune")
	M.close_page()
	await frames(30)

	M.open_char("estelle")
	await frames(70)
	await shot("char_attr")
	var C = M.ext["char"]
	for tb in ["gear", "skill", "rec"]:
		C._tab(tb)
		await frames(70)
		await shot("char_" + tb)
		if tb == "gear":                 # the swap panel's "무기 · 교체" head (spaced Anton over Noto)
			C._key(KEY_ENTER)
			await frames(40)
			await shot("char_gear_swap")
			C._key(KEY_ESCAPE)
			await frames(30)
	print("CAP done")
	quit()
