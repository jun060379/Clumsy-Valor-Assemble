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
	var a = gob(P.position.x + 95.0)
	await frames(10)
	# mash until the third swing lands and lifts it
	for i in 14:
		await tap(3)
		await frames(6)
		if ST.has(a, "air"): break
	await frames(6)
	await shot("aida_3_launch")
	await tap(4)
	for i in 30:
		await frames(1)
		if P.r_strike != null: break
	for i in 40:
		await frames(1)
		if P.r_strike == null: break
	await frames(2)
	await shot("aida_follow")
	await frames(60)
	await shot("aida_after")
	var b = gob(P.position.x + 230.0 * (1 if P.dir > 0 else -1))
	await frames(10)
	ST.add(arena, b, "stagger", 100.0, "estelle")
	P.dir = 1 if b.position.x > P.position.x else -1
	await frames(8)
	await shot("aida_sigil")
	arena.level.set("near_gate", null)
	Input.action_press("attack")
	for i in 40:
		await frames(1)
		arena.level.set("near_gate", null)      # (she stands by a room gate here: the key would open it)
		if P.r_strike != null: break
	Input.action_release("attack")
	for i in 40:
		await frames(1)
		if P.r_strike == null: break
	await frames(2)
	await shot("aida_emp")
	await frames(30)
	# her 남은 균열 after a swap-out
	P.swap_cd = 0.0
	P.party_lock = 0.0
	P.swap(false, "estelle")
	await frames(20)
	await shot("aida_left_gate")
	for i in 60:
		await frames(1)
		if P.a_left.is_empty(): break
	await frames(3)
	await shot("aida_left_burst")
	await frames(30)
	print("CAP done")
	quit()
