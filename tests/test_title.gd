extends SceneTree
## The growing title: godot --headless --path . -s tests/test_title.gd
## people() follows fame.rec (에스텔 always), the light ladder follows the restored facilities (+ Eilin's window, 7 steps
## at most), the crowd follows the guild rank; the sky stays in the pink family; a title with no fame (arena null)
## draws without errors.

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var T = arena.ui_root.title
	var F = arena.fame
	# ---- a fresh save ----
	F.rec = ["estelle"]
	F.fac = {}
	F.r = 1
	check(T.people() == ["estelle"], "fresh: 에스텔 alone on the steps (%s)" % [T.people()])
	check(T.lit_windows() == 1, "fresh: one window lit, Eilin's (%d)" % T.lit_windows())
	check(T.crowd_n() == 0, "fresh: no crowd at rank 1 (%d)" % T.crowd_n())
	# ---- members, facilities, rank ----
	F.rec = ["estelle", "aida", "luce"]
	F.fac = {"fire": 1, "chand": 1, "forge": 1, "hearth": 1}
	F.r = 3
	check(T.people().size() == 3 and T.people()[0] == "estelle", "rec 3: three people, 에스텔 first (%s)" % [T.people()])
	check(T.lit_windows() == 5, "4 facilities: 5 windows lit (%d)" % T.lit_windows())
	check(T.crowd_n() == 6, "rank 3: a crowd of 6 (%d)" % T.crowd_n())
	F.rec = ["aida", "estelle"]
	check(T.people() == ["estelle", "aida"], "에스텔 is always first (%s)" % [T.people()])
	F.r = 7
	check(T.crowd_n() == 18, "rank 7: the crowd caps at 18 (%d)" % T.crowd_n())
	var big := {}
	for i in 20: big["f%d" % i] = 1
	F.fac = big
	check(T.lit_windows() == T.LIGHT_STEPS and T.LIGHT_STEPS == 7, "more facilities than steps: the whole ladder lit (%d)" % T.lit_windows())
	F.fac = {"a": 1, "b": 1, "c": 1, "d": 1, "e": 1, "f": 1}
	check(T.lit_windows() == 7, "6 facilities: all 7 steps (%d)" % T.lit_windows())
	F.fac = {"a": 1, "b": 1}
	check(T.lit_windows() == 3, "2 facilities: both windows and the door lantern (%d)" % T.lit_windows())
	F.fac = big
	# the springs and the crowd seeds follow the counts
	T.active = true
	T.visible = true
	T.t = 0.0
	for i in 5: await process_frame
	check(T.drops.size() == 2 and T.crowd_seed.size() == 18, "drops %d / crowd seeds %d follow the counts" % [T.drops.size(), T.crowd_seed.size()])
	T.active = false
	T.visible = false
	# ---- the sky ----
	for h in [0.0, 3.0, 6.0, 9.0, 12.0, 15.0, 18.0, 19.5, 21.0, 23.9]:
		var c: Color = T.sky(h)
		check(c.r > c.g and c.r >= c.b * 0.95 and c.s > 0.5, "sky at %.1f h stays pink (%s)" % [h, c])
	check(T.sky(12.0) == T.PINK, "noon: the plain pink")
	arena.tod_h = 12.0
	check(T.night() == 0.0 and T.hour() == 12.0, "noon: day factor 0, the hour read from arena.tod_h")
	arena.tod_h = 23.0
	check(T.night() == 1.0, "23 h: night factor 1")
	# ---- a title with no fame at all draws ----
	var bare = load("res://scripts/title.gd").new()
	bare.arena = null
	bare.ui_root = null
	root.add_child(bare)
	check(bare.people() == ["estelle"] and bare.lit_windows() == 1 and bare.crowd_n() == 0, "no fame: 에스텔, one window, no crowd")
	bare.t = 0.0
	for i in 30: await process_frame         # draws through the intro beats (the slam sfx is skipped without an arena)
	bare.t = 1200.0
	for i in 10: await process_frame
	bare._finish_intro()
	for i in 5: await process_frame
	check(bare.drops.size() == 1 and bare.intro_done, "no fame: the intro ran and settled, one drop spring")
	bare.burst_t = bare.clock
	bare.outro = 0.0
	for i in 3: await process_frame
	check(bare.outro > 0.0, "no fame: the burst and the outro draw")
	bare.queue_free()
	print("FAILS: %d" % fails)
	quit()
