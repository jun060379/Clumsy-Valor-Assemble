extends SceneTree
## Eilin's gaits (eilin.gd, tools/make_eilin_walk.py): the walkL sheet matches EILM, she strolls on it as a rule (steps
## off on the passing pose, mirrors for walking left, feet don't slide: one cycle = her walking speed) and breaks into
## the trot ("run", with its start / stop / turn sheets) when a leg has more than RUN_FAR to go or she is late for her
## stint; the gait changes only at a leg's start or once GAIT_HOLD has passed since the last change; the trot is 1.9x.
var bad := 0

func ok(c: bool, what: String) -> void:
	if not c:
		bad += 1
		print("FAIL ", what)
	else:
		print("ok ", what)

## tick her world and animation until `done` says so (or n ticks); returns the ticks spent
func run_until(E, done: Callable, n := 20000) -> int:
	for i in n:
		E.world(16.0)
		E.upd(16.0)
		if done.call(): return i
	return n

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var E = arena.eil
	arena.tod_auto = false
	var M: Array = E.EILM["walkL"]
	var tex: Texture2D = load("res://assets/eilin/walkL.png")
	ok(tex.get_width() == M[0] * M[1] and tex.get_height() == M[2], "walkL.png is %d cells of %d x %d" % [M[0], M[1], M[2]])
	var MR: Array = E.EILM["run"]
	var rtex: Texture2D = load("res://assets/eilin/run.png")
	ok(rtex.get_width() == MR[0] * MR[1] and rtex.get_height() == MR[2], "run.png is %d cells of %d x %d" % [MR[0], MR[1], MR[2]])
	var S: Dictionary = E.sheet("walkL")
	ok(S["n"] == M[0] and absf(S["h"] - M[2] * E.scale_of("walkL")) < 1.0, "scaled sheet %d frames, %d px tall" % [S["n"], S["h"]])
	var S0: Dictionary = E.sheet("idleS")
	ok(absf(S["h"] - S0["h"]) <= 3, "same drawn cell height as her standing art (%d vs %d)" % [S["h"], S0["h"]])
	# feet: one cycle carries her as far as the art's planted foot slides (68.5 px, make_eilin_walk.py)
	var cyc: float = M[0] * E.EILSPD["walkL"]
	ok(absf(cyc * E.EIL_SPD - 68.5) < 3.0, "one cycle %.0f ms = %.1f px at EIL_SPD" % [cyc, cyc * E.EIL_SPD])
	# ---- speeds ----
	ok(E.EIL_SPD == 0.075 and absf(E.EIL_RUN_SPD - 0.075 * 1.9) < 1e-6, "the stroll at 0.075 px/ms, the trot 1.9x = %.4f" % E.EIL_RUN_SPD)
	ok(E.RUN_FAR == 520.0 and E.LATE_MIN == 20.0 and E.GAIT_HOLD == 600.0, "RUN_FAR 520 px · LATE_MIN 20 min (20 s) · GAIT_HOLD 0.6 s")

	# ---- a short leg walks: 18:00 at the counter, the leg to the hall door is 206 px (and she is on time) ----
	arena.tod_h = 17.99
	arena.go_hall(0, Vector2(1500.0, arena.ground_y), 1)
	E.snap()
	arena.tod_h = 18.0
	ok(E.plan() == "town" and not E.late(), "18:00: off to town, on time")
	run_until(E, func(): return E.walking() and E.wait <= 0.0 and not E.leg_new and E.map == "h0")
	var seen := {}
	var first := -1
	var dx := []
	var leg: float = E.leg_left()
	while E.map == "h0":
		seen[E.a] = true
		if first < 0 and E.a == "walkL": first = E.f
		var x0: float = E.x
		E.world(16.0)
		E.upd(16.0)
		if E.map == "h0" and E.walking(): dx.append(absf(E.x - x0))
	ok(leg < E.RUN_FAR and absf(leg - 206.0) < 20.0, "the hall leg is %.0f px (< RUN_FAR)" % leg)
	ok(seen.has("walkL") and not seen.has("run") and not seen.has("start") and E.gait == "walk", "a short leg walks: walkL only (%s)" % [seen.keys()])
	ok(first == E.WALK_IN, "steps off on the passing pose (frame %d)" % first)
	ok(dx.size() > 20 and dx.max() <= E.EIL_SPD * 16.0 + 1e-4 and dx.count(dx.max()) >= dx.size() - 2, "walks at EIL_SPD (%.2f px per 16 ms)" % dx.max())
	ok(E.face == -1, "walked left (the mirrored sheet)")

	# ---- a long leg runs: the street from the hall door to her lamp, 1384 px ----
	run_until(E, func(): return E.map == "town" and E.walking() and E.wait <= 0.0 and not E.leg_new)
	leg = E.leg_left()
	var runseen := {}
	var rdx := []
	var first_run: String = E.a
	var eased := ""            # the animation she went into when the trot eased off to the stroll
	var walk_left := -1.0
	while E.walking():
		var far: bool = E.leg_left() > E.RUN_FAR
		if far: runseen[E.a] = true
		elif E.gait == "walk" and eased == "" and E.a != "run":
			eased = E.a
			walk_left = E.leg_left()
		var x0: float = E.x
		E.world(16.0)
		E.upd(16.0)
		if far and E.walking() and E.a == "run": rdx.append(absf(E.x - x0))
	ok(leg > E.RUN_FAR and absf(leg - 1384.0) < 20.0, "the street leg is %.0f px (> RUN_FAR)" % leg)
	ok(first_run == "start" and runseen.has("run") and not runseen.has("walkL"), "a long leg runs: lunges off through start, trots on run (%s)" % [runseen.keys()])
	ok(rdx.size() > 20 and absf(rdx.max() - E.EIL_RUN_SPD * 16.0) < 1e-4 and rdx.count(rdx.max()) >= rdx.size() - 2, "runs at 1.9x (%.3f px per 16 ms)" % rdx.max())
	ok(eased == "walkL" and walk_left <= E.RUN_FAR and walk_left > E.RUN_FAR - 30.0, "eases off into the stroll (no skid) with %.0f px to go" % walk_left)
	ok(E.spot == "town" and E.face == -1, "and stands at her lamp")

	# ---- a late plan runs: 18:24, the same 206 px leg ----
	arena.tod_h = 17.99
	arena.go_hall(0, Vector2(1500.0, arena.ground_y), 1)
	E.snap()
	arena.tod_h = 18.4
	ok(E.plan() == "town" and E.late(), "18:24: 24 minutes late for the town")
	run_until(E, func(): return E.walking() and E.wait <= 0.0 and not E.leg_new and E.map == "h0")
	var late_seen := {}
	run_until(E, func():
		if E.map != "h0": return true
		late_seen[E.a] = true
		return false)
	ok(late_seen.has("start") and late_seen.has("run") and not late_seen.has("walkL"), "a late plan runs the short leg (%s)" % [late_seen.keys()])
	arena.tod_h = 18.2
	ok(not E.late() and E.hurry() == (E.leg_left() > E.RUN_FAR), "18:12 is not late yet (hurry only by distance)")

	# ---- a day of errands: the gait never changes twice within GAIT_HOLD, the trot keeps its sheets ----
	arena.tod_h = 7.4
	E.snap()
	var tms := 0.0
	var last_sw := -1e9
	var min_gap := 1e9
	var n_sw := 0
	var mid_leg := 0           # changes on the way (not at a leg's start)
	var g0: String = E.gait
	var sheets := {"walk": {}, "run": {}}
	var stops := {"walk": 0, "run": 0}
	for h in [7.5, 12.0, 13.0, 18.0, 20.5, 22.5, 7.5, 12.4, 13.0]:
		arena.tod_h = h
		for i in 8000:
			var was_run: bool = E.was_run           # the gait her animation was on going into this tick
			var fresh: bool = E.leg_new              # this tick is a leg's first step
			E.world(16.0)
			E.upd(16.0)
			tms += 16.0
			if E.gait != g0:
				if last_sw > -1e8: min_gap = minf(min_gap, tms - last_sw)
				if not fresh: mid_leg += 1
				n_sw += 1
				g0 = E.gait
				last_sw = tms
			if E.a in ["start", "turn", "run", "walkL"]: sheets["run" if E.was_run else "walk"][E.a] = true
			if E.a == "stop" and E.f == 0 and E.t == 0.0: stops["run" if was_run else "walk"] += 1     # the skid's first tick
			if E.path.is_empty() and E.spot != "walking": break
	ok(n_sw >= 8 and mid_leg >= 4, "%d gait changes over the day, %d of them on the way" % [n_sw, mid_leg])
	ok(min_gap >= E.GAIT_HOLD, "never twice within GAIT_HOLD (closest %.2f s)" % (min_gap / 1000.0))
	ok(sheets["run"].has("start") and sheets["run"].has("turn") and sheets["run"].has("run"), "the trot lunges off (start), wheels round (turn), trots (run): %s" % [sheets["run"].keys()])
	ok(sheets["walk"].keys() == ["walkL"], "the stroll keeps clear of the trot's sheets: %s" % [sheets["walk"].keys()])
	ok(stops["run"] >= 1 and stops["walk"] == 0, "a runner skids to a stand (stop x%d); a stroller just stops (x%d)" % [stops["run"], stops["walk"]])
	ok(E.spot == "counter" and E.map == "h0", "and ends the loop at the counter")
	print("eilin walk checks done, bad=", bad)
	quit()
