extends SceneTree
## scripted cave fight with sound, for Movie Maker (the town, the real sortie into the cave, combo, dash, guard, jump attack, ult):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 900x500 --path . --fixed-fps 30 --write-movie OUT.avi -s tools/capture/movie_fight.gd
var arena

func frames(n: int) -> void:
	for i in n: await process_frame

func press(a: String, n := 2) -> void:
	Input.action_press(a)
	await frames(n)
	Input.action_release(a)

func gob(P, dx: float, hp := 999.0):
	var m = arena.spawn("goblin", P.position.x + dx, 0.0)
	m.hp = hp
	m.max_hp = maxf(m.max_hp, hp)
	m.cd = 9999.0          # never attacks on its own
	return m

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.join()
	for c in ["aida", "luce"]: arena.toggle_member(c)
	arena.tod_h = 14.0
	# a breath of town first, then into the cave through the real sortie flow (so the music hand-off is heard)
	arena.go_town(Vector2(5107.0, arena.ground_y), -1)
	arena.snap_camera()
	await frames(45)
	if arena.sortie != null and arena.sortie.has_method("open_dsel"):
		arena.sortie.open_dsel(0)
		await frames(20)
		arena.sortie.dsel.do_launch()
		var t0 := Time.get_ticks_msec()
		while arena.level_kind() != "dungeon" or arena.sortie.din["on"] != 0 or arena.sortie.swp["on"] or arena.sortie.dpl["on"]:
			await process_frame
			if Time.get_ticks_msec() - t0 > 60000: break
	else:
		arena.enter_dungeon()
	await frames(20)
	var P = arena.player
	arena.clear_room()
	await frames(10)
	# one sturdy goblin right in front: a combo, then a second one further for the dash
	var g1 = gob(P, 70.0)
	await frames(20)
	for i in 3:
		await press("attack")
		await frames(8)
	await frames(14)
	# dash past, turn, combo again
	Input.action_press("right")
	await press("dash", 3)
	Input.action_release("right")
	await frames(10)
	Input.action_press("left")
	await frames(2)
	Input.action_release("left")
	await frames(4)
	var g2 = gob(P, P.dir * 70.0)
	await frames(6)
	for i in 3:
		await press("attack")
		await frames(8)
	await frames(10)
	# let one goblin swing at her: guard it (parry if the timing lands), then hit back
	g2.cd = 0.0
	await frames(8)
	Input.action_press("guard")
	await frames(26)
	Input.action_release("guard")
	g2.cd = 9999.0
	await frames(8)
	for i in 2:
		await press("attack")
		await frames(8)
	await frames(10)
	# a jump attack
	await press("jump", 3)
	await frames(5)
	await press("attack")
	await frames(20)
	# the ult
	if arena.ult != null:
		arena.ult.v[P.who] = arena.ult.ULTMAX[P.who]
		arena.ult.cd[P.who] = 0.0
		await press("ult", 3)
		await frames(120)
	# finish both
	g1.hp = 12.0
	g2.hp = 12.0
	for i in 3:
		await press("attack")
		await frames(8)
	await frames(40)
	quit()
