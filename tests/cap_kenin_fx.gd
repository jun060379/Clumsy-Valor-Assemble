extends SceneTree
## Kenin's gun and bomb effects (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/cap_kenin_fx.gd -- OUTDIR
var out := ""

func frames(k: int) -> void:
	for i in k: await process_frame

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + n + ".png")

var arena
func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.join()
	arena.fame.rec.append("kenin")
	arena.toggle_member("kenin")
	arena.enter_dungeon()
	await frames(40)
	arena.clear_room()
	var P = arena.player
	P.swap_cd = 0.0
	P.swap(false, "kenin")
	await frames(30)
	P.position.x += 400.0
	P.dir = 1
	var m = arena.spawn("goblin", P.position.x + 200.0, 0.0)
	m.spawn_t = 0.0
	m.hp = 99999.0
	m.max_hp = 99999.0
	m.cd = 99999.0
	await frames(20)
	var K = arena.kenin
	var o: Vector2 = P.position + Vector2(P.dir * 40.0, -70.0)
	K.fire(o, Vector2(P.dir, 0), 10.0)
	for i in 8:
		await frames(2)
		await shot("a%02d" % i)
	K.ammo = 6
	K.fire(o, Vector2(P.dir, 0), 10.0, true, true)
	for i in 8:
		await frames(2)
		await shot("b%02d" % i)
	K.bombs = 3
	K.throw_bomb(o, P.dir, P.position.x + P.dir * 200.0)
	for i in 50:
		await frames(4)
		await shot("c%02d" % i)
	quit()
