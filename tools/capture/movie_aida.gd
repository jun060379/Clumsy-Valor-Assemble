extends SceneTree
## Aida in the cave with sound (combo, portal dashes, the rift skill), for Movie Maker:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 900x500 --path . --fixed-fps 30 --write-movie OUT.avi -s tools/capture/movie_aida.gd
var arena
func frames(n: int) -> void:
	for i in n: await process_frame
func press(a: String, n := 2) -> void:
	Input.action_press(a); await frames(n); Input.action_release(a)
func gob(P, dx: float):
	var m = arena.spawn("goblin", P.position.x + dx, 0.0)
	m.hp = 999.0; m.max_hp = 999.0; m.cd = 9999.0
	return m
func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.fame.join()
	for c in ["aida", "luce"]: arena.toggle_member(c)
	arena.enter_dungeon()
	await frames(40)
	var P = arena.player
	arena.clear_room()
	P.switch_char("aida")
	await frames(20)
	var g = gob(P, 80.0)
	await frames(15)
	for k in 2:
		for i in 3:
			await press("attack"); await frames(8)
		await frames(20)
	# portal dashes
	for i in 3:
		Input.action_press("right" if i % 2 == 0 else "left")
		await press("dash", 3)
		Input.action_release("right"); Input.action_release("left")
		await frames(35)
	# the rift skill (guard key) a couple of times
	for i in 2:
		await press("guard", 4)
		await frames(45)
	g.hp = 10.0
	for i in 3:
		await press("attack"); await frames(8)
	await frames(30)
	quit()
