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
	# Dead Cells-like air attack: keeps the run's momentum, keeps the double jump
	await frames(30)
	Input.action_press("right")
	await frames(10)
	Input.action_press("jump")
	await frames(6)
	Input.action_press("attack")
	await frames(2)
	Input.action_release("attack")
	await frames(6)
	ok(P.anim == "air_combo" and P.vx > 0.2, "air attack keeps the run (vx %.2f, %s)" % [P.vx, P.anim])
	ok(P.vy < 0.0, "air attack keeps the rise (vy %.2f)" % P.vy)
	Input.action_release("jump")
	await frames(10)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	Input.action_release("right")
	await frames(2)
	ok(P.anim == "double_jump", "the double jump is still there after an air attack (%s)" % P.anim)
	# auto-vault: a short hop into the rock in the start room still gets her on top
	await frames(40)
	var so = null
	for q in arena.solids: so = q
	if so != null:
		P.position = Vector2(so.x - 40.0, arena.ground_y)
		P.vx = 0.0
		await frames(20)
		Input.action_press("right")
		await frames(4)
		Input.action_press("jump")
		await frames(2)
		Input.action_release("jump")
		await frames(30)
		Input.action_release("right")
		for i in 200:
			if P.on: break
			await process_frame
		ok(absf(P.position.y - so.top) < 2.0, "a short hop into a rock vaults up on top (y %.0f top %.0f)" % [P.position.y, so.top])
	# ledge assist: rising under a ledge a bit short of its lip, she's lifted onto it
	var pl = null
	for q in arena.platforms: pl = q
	if pl != null:
		await frames(20)
		P.position = Vector2(pl.x + pl.w / 2.0, pl.y + 40.0)
		P.on = false
		P.mantled = false
		P.set_anim("jump", 3)
		P.vy = -0.1
		for i in 300:
			await process_frame
			if P.on: break
		ok(absf(P.position.y - pl.y) < 2.0, "a jump topping out under a ledge is lifted onto it (y %.0f lip %.0f)" % [P.position.y, pl.y])
	# (owner video) climbing up near a ledge's end, facing off it: she must still end standing on the ledge
	if pl != null:
		await frames(20)
		P.position = Vector2(pl.x + 14.0, pl.y + 40.0)
		P.on = false
		P.mantled = false
		P.dir = -1
		P.set_anim("jump", 3)
		P.vy = -0.1
		for i in 400:
			await process_frame
			if P.on and P.anim == "idle": break
		await frames(30)
		ok(P.on and absf(P.position.y - pl.y) < 2.0 and P.position.x >= pl.x, "a climb at a ledge's end leaves her on it (x %.0f, ledge %.0f..%.0f, y %.0f)" % [P.position.x, pl.x, pl.x + pl.w, P.position.y])
	# (owner video, touch stick) hanging with the stick held down-and-toward the ledge: she climbs, she doesn't drop
	if pl != null and P.has_ledge_art():
		await frames(20)
		P.position = Vector2(pl.x + pl.w + 14.0, pl.y + 120.0)
		P.on = false
		P.vy = 0.05
		P.regrab_t = 0.0
		P.set_anim("jump", 4)
		Input.action_press("left")
		Input.action_press("down")
		var seen_hang := false
		for i in 200:
			await process_frame
			if P.anim == "hang": seen_hang = true
			if P.on and P.anim in ["climb", "idle", "run", "start"] and absf(P.position.y - pl.y) < 2.0: break
		Input.action_release("down")
		Input.action_release("left")
		ok(seen_hang and absf(P.position.y - pl.y) < 2.0, "down+toward on the stick while hanging climbs (hang %s, y %.0f lip %.0f)" % [seen_hang, P.position.y, pl.y])
	# dash pop: an air dash clipping just under a ledge's top pops her up onto it
	if pl != null:
		await frames(20)
		P.position = Vector2(pl.x + 30.0, pl.y + 18.0)
		P.on = false
		P.vy = 0.0
		P.dir = 1
		P.set_anim("airdash")
		await frames(3)
		ok(P.on and absf(P.position.y - pl.y) < 1.0, "an air dash just under a ledge pops onto it (y %.0f lip %.0f)" % [P.position.y, pl.y])
	# landing out of an air attack's recovery: a buffered ground attack goes out right away
	await frames(30)
	P.position = Vector2(1500.0, arena.ground_y - 6.0)
	P.on = false
	P.vy = 0.3
	P.set_anim("air_combo", 3)
	P.hit_done = true
	for i in 60:
		await process_frame
		if P.on: break
	ok(P.anim in ["idle", "run", "start"], "touching down after the air strike ends the swing (anim %s)" % P.anim)
	print("DONE fails=%d" % fails)
	quit(1 if fails > 0 else 0)
