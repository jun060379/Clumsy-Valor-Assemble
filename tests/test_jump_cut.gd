extends SceneTree
## the jump cut (owner 2026-11-05): tap ≈ half height, hold = full, a tap then an attack within the grace keeps rising,
## the double jump always goes all the way. godot --headless --path . -s tests/test_jump_cut.gd
var arena
var fails := 0
func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1
func frames(n: int) -> void:
	for i in n: await process_frame
func rise(P, hold_frames: int, attack_after := -1, dj := false) -> float:
	await frames(30)
	var y0: float = P.position.y
	Input.action_press("jump")
	await frames(hold_frames)
	Input.action_release("jump")
	var top: float = P.position.y
	var k := 0
	if dj:
		await frames(4)
		Input.action_press("jump")
		await frames(2)
		Input.action_release("jump")
	while k < 120:
		if k == attack_after:
			Input.action_press("attack")
			await frames(2)
			Input.action_release("attack")
		await process_frame
		top = minf(top, P.position.y)
		k += 1
		if P.on and k > 5: break
	return y0 - top
func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.enter_dungeon()
	await frames(40)
	for m in arena.mobs: m.hp = 0.0
	var P = arena.player
	P.position.x += 400.0
	await frames(20)
	var full: float = await rise(P, 40)
	var tap: float = await rise(P, 2)
	var tap_atk: float = await rise(P, 2, 3)
	var dj: float = await rise(P, 2, -1, true)
	print("full %.0f  tap %.0f  tap+attack %.0f  tap+double %.0f" % [full, tap, tap_atk, dj])
	ok(tap > full * 0.4 and tap < full * 0.75, "a tap is about half the full height")
	ok(tap_atk > tap + 15.0, "tap then attack in the grace keeps more height")
	ok(dj > full, "the double jump tapped still goes high")
	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
