extends SceneTree
## Aida's launch combo (1 · 2 · 3타 → follow-up) and the empowered strike on a staggered foe (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 --write-movie OUT.avi -s tests/cap_aida.gd -- OUTDIR
const ST := preload("res://scripts/status.gd")
var out := ""
var arena
func frames(k: int) -> void:
	for i in k: await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func tap(n := 5) -> void:
	Input.action_press("attack")
	await frames(n)
	Input.action_release("attack")
func gob(x: float):
	var m = arena.spawn("goblin", x, 0.0)
	m.spawn_t = 0.0
	m.hp = 99999.0
	m.max_hp = 99999.0
	m.cd = 99999.0
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0
	return m
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.cfg.aim = "off"
	arena.enter_dungeon()
	await frames(60)
	for m in arena.mobs: m.hp = 0.0
	await frames(20)
	var P = arena.player
	P.party = ["aida", "estelle", "luce"]
	for c in P.party: P.hpm[c] = 100.0
	P.switch_char("aida")
	P.position.x += 520.0          # away from the door (the attack key would open it)
	P.dir = 1
	await frames(20)
	Input.action_press("jump")
	await frames(4)
	Input.action_release("jump")
	await frames(16)
	Input.action_press("down")
	await frames(2)
	Input.action_press("attack")
	await frames(3)
	Input.action_release("attack")
	for k in 40:
		await frames(1)
		if P.on and P.anim == "dive": break
	Input.action_release("down")
	for k in 14:
		await shot("dv_%02d" % k)
		await frames(2)
	quit()
