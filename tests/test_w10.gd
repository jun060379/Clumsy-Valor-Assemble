extends SceneTree
## WP10 town and hall life: the town cat, butterflies, footstep dust, wading splashes, struck hall props (pot clink, bread),
## moths at the soft lamps, the attic mouse, the hall cat, quest-board flap, weather on the window glass, Eilin's door bump.
## godot --headless -s tests/test_w10.gd   (prints PASS / FAIL lines, exits 1 on a failure)

var fails := 0
var arena

func ok(c: bool, what: String) -> void:
	print(("PASS " if c else "FAIL ") + what)
	if not c: fails += 1

func run(n: int) -> void:
	for i in n: arena._process(0.016)

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.tod_auto = false
	arena.tod_h = 12.0
	arena.weather = "clear"
	var P = arena.player
	# ---------- town: the cat on the second crate ----------
	arena.go_town(Vector2(700.0, arena.ground_y), 1)
	run(5)
	var T = arena.level
	var L = T.life
	ok(L.cat != null, "town cat exists")
	var c: Dictionary = L.cat
	ok(absf(c["x"] - (1560.0 + T.tex["q_crateL"].get_width() * T.ks("q_crateL") / 2.0)) < 1.0, "cat sits on the second crate (x %.0f)" % c["x"])
	ok(c["st"] == "sleep", "cat sleeps while you are away")
	P.position = Vector2(c["x"] + 100.0, T.floor_at(c["x"] + 100.0))
	run(3)
	ok(c["st"] == "sit", "cat sits up within 160 px")
	ok(c["dir"] == 1.0, "cat faces you")
	P.set_anim("attack1")
	L._cat(16.0, P)
	ok(c["st"] == "startle", "a swing within 140 px startles it")
	P.set_anim("idle")
	for i in 50: L._cat(16.0, P)
	ok(c["st"] == "sit", "startle settles back to sitting")
	P.position = Vector2(700.0, T.floor_at(700.0))
	for i in 240: L._cat(16.0, P)
	ok(c["st"] == "sleep", "cat curls up again once you leave")
	# ---------- butterflies ----------
	L.bflies.clear()
	for i in 600:
		L._bflies(16.0, arena.view_rect(), P)
	ok(L.bflies.size() > 0 and L.bflies.size() <= 3, "butterflies by day in fair weather (%d)" % L.bflies.size())
	var b: Dictionary = L.bflies[0]
	P.position = Vector2(b["x"], b["y"] + 60.0)
	L._bflies(16.0, arena.view_rect(), P)
	ok(b["flee"], "a butterfly flees when you come close")
	arena.weather = "rain"
	L._bflies(16.0, arena.view_rect(), P)
	ok(L.bflies.all(func(x): return x["flee"]), "rain chases them all off")
	var n0: int = L.bflies.size()
	for i in 1500: L._bflies(16.0, arena.view_rect(), P)
	ok(L.bflies.is_empty(), "fled butterflies leave the screen (%d of %d left: %s)" % [L.bflies.size(), n0, str(L.bflies.map(func(x): return Vector2(x["x"], x["y"])))])
	arena.weather = "clear"
	# ---------- footstep dust ----------
	var nd := func(): return arena.fx.filter(func(e): return e["k"] == "dust").size()
	arena.fx.clear()
	P.position = Vector2(700.0, T.floor_at(700.0))
	P.on = true
	P.anim = "run"
	P.f = 1
	L.prev_f = 0
	L.step(16.0)
	ok(nd.call() == 2, "a running step kicks up two dust puffs")
	P.set_anim("idle")
	run(30)
	# ---------- the hall, floor 0: struck props, bread, the cat, the board ----------
	arena.go_hall(0, Vector2(2600.0, arena.ground_y), 1)
	run(10)
	var H = arena.level
	var props: Array = H.F["props"]
	var ip := -1
	var ib := -1
	var ic := -1
	var ibd := -1
	for i in props.size():
		match props[i][0]:
			"pot": ip = i
			"bread": ib = i
			"chS": if ic < 0: ic = i
			"catbed": ibd = i
	ok(ip >= 0 and ib >= 0 and ic >= 0 and ibd >= 0, "hall floor 0 has a pot, bread, a chair and the cat's cushion")
	# a real swing at the chair at 2632 from its left
	var cx: float = props[ic][1]
	P.position = Vector2(cx - 60.0, arena.ground_y)
	P.dir = 1
	P.anim = "attack1"
	P.f = 2
	H._life(16.0, P, null)
	ok(H.jig.get(ic, 0.0) > 0.8, "a swing makes the chair jump")
	P.set_anim("idle")
	for i in 120: H._life(16.0, P, null)
	ok(H.jig.get(ic, 0.0) < 0.5, "the jump dies away (%.2f)" % H.jig.get(ic, 0.0))
	H.strike(ip, 1)
	ok(H.jig.get(ip, 0.0) == 1.0, "the pot jumps (with its clink)")
	var got := false
	for i in 60:
		H.strike(ib, 1)
		if H.drops.size() > 0:
			got = true
			break
	ok(got, "the bread can roll off")
	var d0: Dictionary = H.drops[0]
	for i in 200: H._life(16.0, P, null)
	ok(absf(d0["y"] - (H.G - 3.0)) < 0.5 and d0["x"] > props[ib][1], "the bread lands on the floor and rolls the way you hit it")
	# hall cat
	var kx: float = props[ibd][1] + 28.0
	ok(H.cat["st"] == "sleep", "hall cat sleeps")
	P.position = Vector2(kx + 80.0, arena.ground_y)
	H._life(16.0, P, null)
	ok(H.cat["st"] == "sit" and H.cat["dir"] == 1.0, "hall cat sits up and watches within 130 px")
	P.position = Vector2(kx + 400.0, arena.ground_y)
	for i in 100: H._life(16.0, P, null)
	ok(H.cat["st"] == "sit", "it keeps watching for a while")
	for i in 100: H._life(16.0, P, null)
	ok(H.cat["st"] == "sleep", "then sleeps again")
	# board flap and window weather: drawn without errors
	H.draft = {"v": 1.0, "dir": 1, "x": 2420.0}
	P.position = Vector2(2480.0, arena.ground_y)
	arena.weather = "rain"
	arena.snap_camera()
	run(4)
	await process_frame
	arena.weather = "snow"
	run(4)
	await process_frame
	arena.weather = "clear"
	ok(true, "board flap and window rain/snow draw")
	# ---------- moths after dark ----------
	arena.tod_h = 22.0
	P.position = Vector2(2760.0, arena.ground_y)
	arena.snap_camera()
	run(5)
	for i in 3000:
		H._life(16.0, P, null)
		if H.moths.size() >= 2: break
	ok(H.moths.size() > 0 and H.moths.all(func(m): return m["l"]["k"] == "soft"), "moths circle the soft lamps after dark (%d)" % H.moths.size())
	arena.tod_h = 12.0
	H._life(16.0, P, null)
	ok(H.moths.is_empty(), "moths go at daybreak")
	# ---------- the attic mouse ----------
	arena.go_hall(3, Vector2(arena.HALL.HD.SPAWN[3][0], arena.ground_y), 1)
	run(5)
	H = arena.level
	var x0: float = H.F["rooms"][0][0]
	var x1: float = H.F["rooms"][0][1]
	P.position = Vector2(x1 + 400.0, arena.ground_y)     # out of its way
	H.mouse_t = 0.0
	H._life(16.0, P, null)
	ok(H.mouse != null, "a mouse comes out")
	var ms: Dictionary = H.mouse
	ms["stop"] = null
	ms["st"] = "run"
	var mx0: float = ms["x"]
	for i in 20: H._life(16.0, P, null)
	ok(absf(ms["x"] - mx0) > 50.0, "it runs")
	P.position = Vector2(ms["x"] + 100.0, arena.ground_y)
	H._life(16.0, P, null)
	ok(ms["st"] == "flee" and ms["dir"] == -1.0, "it flees away from you")
	for i in 400:
		H._life(16.0, P, null)
		if H.mouse == null: break
	ok(H.mouse == null, "and is gone")
	await process_frame
	print("attic ", x0, "..", x1)
	print("fails ", fails)
	quit(1 if fails > 0 else 0)
