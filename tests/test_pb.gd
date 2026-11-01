extends SceneTree
## Package B (dungeon numbers and feedback): boss HP by tier, silent reinforcements, kill shake + dust,
## the H2.mob slanted bar with its ghost trail, the eye's flight ceiling from the room's top, spores blown by swings,
## the camp fire healing only recruited members, no 실링 HUD line, the minimap at the top right.
## godot --headless -s tests/test_pb.gd   (prints PASS / FAIL lines, exits 1 on a failure)

var fails := 0
var arena

func ok(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c: fails += 1

func run(n: int) -> void:
	for i in n: arena._process(0.016)

func goto(D, pred: Callable) -> bool:
	for k in D.rooms:
		if pred.call(D.rooms[k]):
			D.from = "L"
			D.cur = k
			D.enter()
			return true
	return false

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.enter_dungeon()
	var D = arena.level
	var P = arena.player
	# ---------- A2: the boss is tier 4: 620 * 1.48 = 918 ----------
	ok(goto(D, func(r): return r["type"] == "boss"), "found the boss room")
	ok(int(D.room()["tier"]) == 4, "boss room tier is 4 (%d)" % int(D.room()["tier"]))
	var boss = null
	for m in arena.mobs:
		if m.kind == "boss": boss = m
	ok(boss != null and int(boss.max_hp) == 918 and int(boss.hp) == 918, "boss hp 918/918 (%s)" % (str(boss.max_hp) if boss else "none"))
	# a fight room scales the same way: goblin 50 * (1 + 0.12 * tier)
	ok(goto(D, func(r): return r["type"] == "fight" and not r["cleared"]), "found a fight room")
	var t: int = int(D.room()["tier"])
	var g = arena.spawn("goblin", 600.0, 0.0, -1.0, null, false, t)
	ok(int(g.max_hp) == roundi(50.0 * (1.0 + 0.12 * t)), "goblin hp by tier %d: %d" % [t, int(g.max_hp)])
	var ge = arena.spawn("goblin", 600.0, 0.0, -1.0, null, true, t)
	ok(int(ge.max_hp) == roundi(50.0 * 1.6 * (1.0 + 0.12 * t)), "elite goblin hp by tier: %d" % int(ge.max_hp))
	# ---------- B1: reinforcements come in aware, with no !! / react pause ----------
	for m in arena.mobs.duplicate():
		if m.alive() or m.spawn_t > 0.0: m.queue_free()
	arena.mobs.clear()
	D.waves = [[["goblin"]], [["goblin"], ["goblin"]]]
	D.wave = 1
	D.spawn_wave()
	var silent: bool = arena.mobs.size() == 2
	for m in arena.mobs:
		silent = silent and m.aw and m.mark == "" and m.react == 0.0 and m.home == m.position.x
	ok(silent, "wave 2 spawns aware, without the !! mark or the 360 ms react")
	ok(D.msg == "증원!", "the 증원! line still shows")
	# ---------- B2: a kill shakes the screen, kicks dust, sparks ----------
	run(40)
	var m0 = arena.mobs[0]
	arena.shake_amt = 0.0
	var nfx: int = arena.pfx.L.filter(func(e): return e["k"] == "dust").size()
	m0.hit(999.0, 0.0)
	ok(m0.is_dead(), "the mob dies")
	ok(arena.shake_amt >= 8.0, "an ordinary kill shakes (shake %.1f)" % arena.shake_amt)
	ok(arena.pfx.L.filter(func(e): return e["k"] == "dust").size() >= nfx + 2, "and kicks dust both ways")
	# ---------- B3: H2.mob bar: the ghost trail lags, the hit flashes white ----------
	var m1 = arena.mobs[1]
	m1.queue_redraw()
	await process_frame
	ok(m1.bar_st.has("g") and is_equal_approx(m1.bar_st["g"], 1.0), "the mob bar keeps ghostOf state")
	m1.hp = m1.max_hp * 0.5
	m1.queue_redraw()
	await process_frame
	ok(m1.bar_st["g"] > 0.9 and m1.bar_st.has("hf") and m1.bar_st["gw"] > 0.0, "after a hit the ghost stays (%.2f) and the bar flashes" % m1.bar_st["g"])
	# ---------- B4: the eye's ceiling follows the room's top ----------
	ok(goto(D, func(r): return true), "re-entered a room")
	D.tpl = D.RTPL["tower"]
	var eye = arena.spawn("eye", 600.0, 0.0)
	P.position.y = arena.ground_y - 900.0
	for i in 400: eye.step(16.0)
	var ceil_y: float = arena.ground_y - 760.0 - 40.0
	ok(absf(eye.base_y - ceil_y) < 5.0, "eye climbs to GROUND-760-40 in the tower (%.0f vs %.0f)" % [eye.base_y, ceil_y])
	P.position.y = arena.ground_y
	# ---------- B5: a swing pushes the spores ----------
	run(2)
	ok(D.spores.size() >= 46, "spores are up")
	var sp: Dictionary = D.spores[0]
	sp["x"] = P.position.x + P.dir * 60.0 * P.CSCALE
	sp["y"] = P.position.y - 70.0 * P.CSCALE
	sp.erase("vx")
	P.on = true
	P.anim = "attack1"
	arena.swing_air(P)
	ok(sp.get("vx", 0.0) * P.dir > 0.25, "a swing blows the spore its way (vx %.3f)" % sp.get("vx", 0.0))
	var x0: float = sp["x"]
	D.step(16.0)
	ok((sp["x"] - x0) * P.dir > 2.0, "and the spore drifts with it")
	sp["x"] = 500.0
	sp["y"] = 400.0
	sp.erase("vx")
	arena.streak_fx(400.0, 600.0, 400.0, 1)
	ok(sp.get("vx", 0.0) > 0.5, "a thrust streak blows it (vx %.3f)" % sp.get("vx", 0.0))
	sp.erase("vx")
	arena.pfx.slam(500.0, 420.0, P.who)
	ok(sp.has("vx") and sp.has("vy2"), "a slam pushes it")
	# ---------- A7: the camp fire heals recruited members only (party or not) ----------
	if goto(D, func(r): return r["type"] == "camp"):
		D.room()["rest_used"] = false
		var who: Array = P.hpm.keys()
		for c in who: P.hpm[c] = 1.0
		P.position = Vector2(D.tpl["w"] * 0.75, arena.ground_y)
		D.step(16.0)
		var good := true
		for c in who:
			var rec: bool = arena.fame == null or arena.fame.recruited(c)
			good = good and ((P.hpm[c] > 1.0) == rec)
		ok(good, "camp fire healed exactly the recruited members")
	# ---------- B6 / B7: HUD ----------
	var hsrc: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	ok(not hsrc.contains("\"실링 %d\""), "no 실링 line in the dungeon HUD")
	ok(hsrc.contains("var y0 := 16.0"), "minimap sits at the top right (ry 16)")
	arena.leave_dungeon()
	print("FAILS %d" % fails)
	quit(1 if fails > 0 else 0)
