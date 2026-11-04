extends SceneTree
## 공용 상태 icons over foes (needs a display): godot --path . --resolution 900x500 -s tests/cap_status.gd -- OUTDIR
const ST := preload("res://scripts/status.gd")
func frames(k: int) -> void:
	for i in k: await process_frame
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.enter_dungeon()
	await frames(60)
	for m in arena.mobs: m.hp = 0.0
	await frames(30)
	var P = arena.player
	var x0: float = P.position.x
	var L := []
	for i in 4:
		var m = arena.spawn("goblin" if i != 2 else "skel", x0 + 160.0 + i * 120.0, 0.0)
		m.spawn_t = 0.0
		m.cd = 99999.0
		m.hp = 999.0
		m.max_hp = 999.0
		m.M = m.M.duplicate()
		m.M["ms"] = 0.0
		L.append(m)
	await frames(5)
	ST.add(arena, L[0], "vuln", 0.25, "kenin")
	ST.add(arena, L[0], "burn", 100.0, "estelle")
	ST.add(arena, L[0], "burn", 100.0, "aida")
	ST.add(arena, L[1], "bleed", -1.0, "kenin")
	ST.add(arena, L[1], "stagger", 60.0)
	ST.add(arena, L[2], "slow", 100.0, "luce")
	ST.add(arena, L[2], "slow", 100.0, "luce")
	ST.add(arena, L[3], "vuln", 0.2)
	ST.add(arena, L[3], "bleed")
	ST.add(arena, L[3], "burn", 100.0)
	ST.add(arena, L[3], "stagger", 100.0)
	await frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/status.png")
	print("SHOT")
	quit()
