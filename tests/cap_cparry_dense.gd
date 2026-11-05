extends SceneTree
## 교대 패링 in two beats: Aida in control, a goblin's glint, swap → Estelle slides in and CATCHES it (the clash), both
## thrown apart, then the follow-up on a press (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 --write-movie OUT.avi -s tests/cap_cparry_dense.gd -- OUTDIR [follow]
var out := ""
var arena
func frames(k: int) -> void:
	for i in k: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var follow: bool = args.size() > 1
	DirAccess.make_dir_recursive_absolute(out)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.cfg.aim = "off"
	if args.size() > 2 and args[2] == "kenin":
		arena.fame.join()
		arena.fame.rec.append("kenin")
		arena.toggle_member("kenin")
	arena.enter_dungeon()
	await frames(60)
	for m in arena.mobs: m.hp = 0.0
	await frames(20)
	var P = arena.player
	var tgt: String = args[2] if args.size() > 2 else "estelle"
	var first: String = "estelle" if tgt != "estelle" else "aida"
	P.party = [first, tgt, "luce" if tgt != "luce" and first != "luce" else "aida"]
	for c in P.party: P.hpm[c] = 100.0
	P.switch_char(first)
	P.position.x += 520.0
	P.dir = 1
	await frames(20)
	var m = arena.spawn("goblin", P.position.x + 62.0, 0.0)
	m.spawn_t = 0.0
	m.hp = 99999.0
	m.max_hp = 99999.0
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0
	m.cd = 200.0
	await frames(5)
	# wait for its glint, then swap on it
	while not (m.st == "atk" and m.flared):
		await frames(1)
	await frames(3)
	await shot("cp_glint")
	P.party_input(tgt)
	for i in 90:
		if follow and i == 30:
			await frames(1)
			Input.action_press("attack")
		if follow and i == 32:
			Input.action_release("attack")
		await frames(1)
		await shot("d%02d" % i)
	print("CAP done")
	quit()
