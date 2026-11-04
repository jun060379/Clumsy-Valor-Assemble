extends SceneTree
## the boss row: groggy gauge and status chips under the boss bar (needs a display):
## godot --path . --resolution 900x500 -s tests/cap_boss_status.gd -- OUTDIR
const ST := preload("res://scripts/status.gd")
func frames(k: int) -> void:
	for i in k: await process_frame
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.enter_dungeon()
	await frames(60)
	for m in arena.mobs: m.hp = 0.0
	var P = arena.player
	var b = arena.spawn("boss", P.position.x + 300.0, 0.0)
	b.spawn_t = 0.0
	b.cd = 99999.0
	await frames(140)
	ST.add(arena, b, "stagger", 180.0, "estelle")
	ST.add(arena, b, "burn", 100.0, "luce")
	ST.add(arena, b, "burn", 100.0, "estelle")
	ST.add(arena, b, "bleed", -1.0, "kenin")
	ST.add(arena, b, "vuln", 0.25, "kenin")
	await frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/boss_status.png")
	print("SHOT")
	quit()
