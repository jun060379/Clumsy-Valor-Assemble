extends SceneTree
## Luce's prayer, its release and the 빛의 가호 halo (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_heal.gd -- OUTDIR
var out := ""
func frames(k: int) -> void:
	for i in k: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.enter_dungeon()
	await frames(60)
	for m in arena.mobs: m.hp = 0.0
	await frames(20)
	var P = arena.player
	P.party = ["estelle", "aida", "luce"]
	for c in P.party: P.hpm[c] = 50.0
	P.switch_char("luce")
	P.position.x += 520.0
	await frames(20)
	P.heal_cd = 0.0
	P.set_anim("heal")
	P.heal_t = 0.0
	arena.pfx.pray(P.position.x, P.position.y)
	for k in 100:
		await shot("f%03d" % k)
	P.switch_char("estelle")
	await frames(10)
	await shot("halo")
	P.halo_glint = 160.0
	await frames(2)
	await shot("glint")
	quit()
