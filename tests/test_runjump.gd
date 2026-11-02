extends SceneTree
## A run jump lands straight into the run (no idle → start), and holds its fall frame in the air (no flicker to the landing frame and back), lands into jump 6.
var fails := 0
func check(c: bool, m: String) -> void:
	print(("ok   " if c else "FAIL ") + m)
	if not c: fails += 1
func fr(n):
	for i in n: await process_frame
func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await fr(10)
	var P = arena.player
	P.switch_char("estelle")
	Input.action_press("right")
	await fr(60)
	check(P.anim == "run", "running (%s)" % P.anim)
	Input.action_press("jump")
	var seq: Array = []
	for i in 240:
		await process_frame
		if seq.is_empty() or seq[-1] != [P.anim, P.f]: seq.append([P.anim, P.f])
	print(seq)
	var air: Array = seq.filter(func(s): return s[0] == "runjump")
	var fs: Array = air.map(func(s): return s[1])
	var back := false
	for i in range(1, fs.size()):
		if fs[i] < fs[i - 1]: back = true
	check(not air.is_empty() and not back and fs.max() <= 4, "the run jump's frames only go forward and hold on 4 (%s)" % str(fs))
	var i0 := seq.find(air[-1]) if not air.is_empty() else -1
	check(i0 >= 0 and i0 + 1 < seq.size() and seq[i0 + 1] == ["run", 1], "still running: it lands straight into the run (%s)" % str(seq.slice(i0 + 1, i0 + 3)))
	check(seq.filter(func(s): return s[0] == "start").is_empty(), "no stop-and-start after the landing")
	Input.action_release("right")
	print("runjump: FAILS %d" % fails)
	quit()
