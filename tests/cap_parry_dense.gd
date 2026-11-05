extends SceneTree
## Estelle's own parry (guard tapped on a goblin's glint), shot every frame (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 --write-movie OUT.avi -s tests/cap_parry_dense.gd -- OUTDIR [follow]
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
	P.party = ["estelle", "aida", "luce"]
	for c in P.party: P.hpm[c] = 100.0
	P.switch_char("estelle")
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
	while not (m.st == "atk" and m.flared):
		await frames(1)
	for i in 60:
		if i == 9:
			await frames(1)
			Input.action_press("guard")
		if i == 12: Input.action_release("guard")
		await frames(1)
		print(i, " ", P.anim, " ", P.f, " hp ", P.hp, " bash ", P.bash_t)
		await shot("d%02d" % i)
	print("CAP done")
	quit()
