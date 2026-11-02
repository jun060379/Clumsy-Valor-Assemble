extends SceneTree
## Eilin's stroll (eilin.gd, tools/make_eilin_walk.py): the walkL sheet matches EILM, she walks on it (not the trot),
## steps off on the passing pose, mirrors for walking left, and her feet don't slide (one cycle = her walking speed)
var bad := 0

func ok(c: bool, what: String) -> void:
	if not c:
		bad += 1
		print("FAIL ", what)
	else:
		print("ok ", what)

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var E = arena.eil
	var M: Array = E.EILM["walkL"]
	var tex: Texture2D = load("res://assets/eilin/walkL.png")
	ok(tex.get_width() == M[0] * M[1] and tex.get_height() == M[2], "walkL.png is %d cells of %d x %d" % [M[0], M[1], M[2]])
	var S: Dictionary = E.sheet("walkL")
	ok(S["n"] == M[0] and absf(S["h"] - M[2] * E.scale_of("walkL")) < 1.0, "scaled sheet %d frames, %d px tall" % [S["n"], S["h"]])
	var S0: Dictionary = E.sheet("idleS")
	ok(absf(S["h"] - S0["h"]) <= 3, "same drawn cell height as her standing art (%d vs %d)" % [S["h"], S0["h"]])
	# feet: one cycle carries her as far as the art's planted foot slides (68.5 px, make_eilin_walk.py)
	var cyc: float = M[0] * E.EILSPD["walkL"]
	ok(absf(cyc * E.EIL_SPD - 68.5) < 3.0, "one cycle %.0f ms = %.1f px at EIL_SPD" % [cyc, cyc * E.EIL_SPD])
	# 18:00 at the counter: she walks out of the hall (left, to the door at x 1800) ...
	arena.tod_h = 17.99
	arena.go_hall(0, Vector2(1500.0, arena.ground_y), 1)
	E.snap()
	arena.tod_h = 18.0
	var seen := {}
	var first := -1
	var faces := {}
	for i in 1500:
		E.world(16.0)
		E.upd(16.0)
		if E.walking() and E.here():
			seen[E.a] = true
			faces[E.face] = true
			if first < 0 and E.a == "walkL": first = E.f
	# ... and at 20:30 back in from the street (right, to the hall's door)
	arena.go_town(Vector2(1400.0, arena.ground_y), 1)
	for i in 3000:
		E.world(16.0)
		E.upd(16.0)
	print("town: ", E.map, " ", E.spot)
	arena.tod_h = 20.6
	for i in 1500:
		E.world(16.0)
		E.upd(16.0)
		if E.walking() and E.here():
			seen[E.a] = true
			faces[E.face] = true
	print("anims while walking ", seen.keys(), " faces ", faces.keys(), " first frame ", first)
	ok(seen.has("walkL") and not seen.has("run") and not seen.has("start") and not seen.has("turn"), "walks on walkL only")
	ok(first == E.WALK_IN, "steps off on the passing pose (frame %d)" % first)
	ok(faces.has(-1) and faces.has(1), "walked both ways (left is the mirrored sheet)")
	print("eilin walk checks done, bad=", bad)
	quit()
