extends SceneTree
## Kenin in the cave, with sound, for Movie Maker: shots until the pistol runs dry, a sticky bomb, a bomb set off by a
## shot, the roll into a wall, Estelle's finisher answered by his covering shot from the bench (no swap), the ult.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 900x500 --path . --fixed-fps 30 --write-movie OUT.avi -s tools/capture/movie_kenin.gd
var arena

func frames(n: int) -> void:
	for i in n: await process_frame

func press(a: String, n := 2) -> void:
	Input.action_press(a)
	await frames(n)
	Input.action_release(a)

func gob(x: float, hp := 999.0):
	var m = arena.spawn("goblin", x, 0.0)
	m.hp = hp
	m.max_hp = maxf(m.max_hp, hp)
	m.cd = 9999.0          # never attacks on its own
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0        # and stays put
	return m

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.join()
	arena.fame.rec.append("kenin")
	arena.toggle_member("kenin")
	arena.enter_dungeon()
	await frames(40)
	var P = arena.player
	arena.clear_room()
	P.position.x = 520.0
	P.dir = 1
	P.swap_cd = 0.0
	P.swap(false, "kenin")
	await frames(30)
	var g1 = gob(P.position.x + 300.0)
	var g2 = gob(P.position.x + 430.0)
	await frames(20)
	print("SCENE shots")
	for c in 3:                          # two combos empty the cylinder, the third clicks dry
		for i in 3:
			await press("attack")
			await frames(7)
		await frames(10)
	await frames(30)
	print("SCENE bomb")
	await press("guard")
	await frames(110)                    # the fuse runs out on the goblin
	print("SCENE bomb+shot")
	arena.kenin.ammo = arena.kenin.AMMO
	await press("guard")
	await frames(24)
	await press("attack")
	await frames(40)
	print("SCENE roll into the wall")
	# the nearest raised rock to the right (or the world's right edge): roll into its side
	var wx: float = arena.world_w - 30.0
	for so in arena.solids:
		if so.x > P.position.x + 60.0 and so.x < wx: wx = so.x - 12.0
	var gx: float = g1.position.x
	g1.position.x = wx - 700.0
	g2.position.x = wx - 760.0
	P.position.x = wx - 230.0
	P.dir = 1
	await frames(10)
	Input.action_press("right")
	await press("dash", 3)
	await frames(24)
	Input.action_release("right")
	await frames(20)
	g1.position.x = gx
	g2.position.x = gx + 130.0
	print("SCENE qte from the bench")
	P.position.x = g1.position.x - 150.0
	P.dir = 1
	P.swap_cd = 0.0
	P.swap(false, "estelle")
	await frames(40)
	P.qte["cd"] = 0.0
	P.qte_offer("finisher")
	await frames(6)
	await press("swap")
	await frames(40)
	P.qte["cd"] = 0.0
	P.qte_offer("finisher")
	await frames(6)
	await press("swap")
	await frames(40)
	print("SCENE detonator")
	P.swap_cd = 0.0
	await press("swap")
	await frames(40)
	arena.kenin.bombs = arena.kenin.BOMBS
	await press("guard")
	await frames(26)
	await press("guard")
	await frames(20)
	arena.kenin.add_marks(g1, 4)
	arena.kenin.add_marks(g2, 3)
	await frames(20)
	await press("attack", 30)            # held: the box comes out; let go: the plunger, the chain
	await frames(70)
	print("SCENE ult")
	arena.ult.v["kenin"] = arena.ult.ULTMAX["kenin"]
	arena.ult.cd["kenin"] = 0.0
	await press("ult", 3)
	await frames(260)
	print("SCENE done")
	quit()
