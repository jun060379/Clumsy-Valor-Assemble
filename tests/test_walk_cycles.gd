extends SceneTree
## The members' own walk cycles and Bran's stroll (tools/make_walk.py, 2026-11): godot --headless -s tests/test_walk_cycles.gd
## Frame counts and rows (에스텔 초심 36-39, 아이다 / 루체 기본 35-), every frame's sole on the idle's feet line (±1 px,
## from the bounds), the size matching the idle, the head steady across the cycle (no horizontal jitter); the stride
## measured here again on the sheets (the planted sole's shift frame to frame) against the costume's stated stride and
## frame times (each frame's ground = speed × its time, the feet planted); the title's and town life's gaits keep ground
## speed / play rate = the art's stride speed; 아이다 no longer plays her run row as a walk; 브랜's walk cells, his stroll
## out and back at the art's pace, stopping for whoever comes near (still talkable where he stands) and finishing after.
var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

## the alpha (0..1) of the band of rows y0..y1 of one cell, as rows of floats; `boots`: only brownish pixels (아이다's
## shovel blade drags low)
func band(img: Image, cx: int, cy: int, w: int, y0: int, y1: int, boots := false) -> Array:
	var out: Array = []
	for y in range(y0, y1):
		var r := PackedFloat32Array()
		r.resize(w)
		for x in w:
			var p := img.get_pixel(cx + x, cy + y)
			var a := p.a
			if boots and not (p.r > p.g and p.g > p.b and p.r - p.b > 0.1 and p.get_luminance() < 0.7): a = 0.0
			r[x] = a
		out.append(r)
	return out

## the shift (cell px, + = backwards) of b's soles that best overlaps a's
func shift(a: Array, b: Array, w: int, lo := -4, hi := 30) -> int:
	var best := -1.0
	var bs := 0
	for s in range(lo, hi + 1):
		var t := 0.0
		for y in a.size():
			var ra: PackedFloat32Array = a[y]
			var rb: PackedFloat32Array = b[y]
			for x in range(maxi(0, s), mini(w, w + s)):
				t += minf(ra[x], rb[x - s])
		if t > best:
			best = t
			bs = s
	return bs

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var SK = arena.SKINS
	var SD = load("res://scripts/skin_data.gd")
	var CH = load("res://scripts/chars.gd")
	var folk = arena.FOLK.of(arena)
	var spec := {"estelle": [36, 35, 340, SD.STRIDE_EST], "aida": [35, 11, 339, SD.STRIDE_AIDA], "luce": [35, 27, 339, SD.STRIDE_LUCE]}
	for c in spec:
		var row0: int = spec[c][0]
		var n: int = spec[c][1]
		var feet: int = spec[c][2]
		var e: Array = SK.entry(c, "walk")
		var cyc := 0
		for ms in e[1]: cyc += int(ms)
		check(int(e[0]) == row0 and (e[1] as Array).size() == n, "%s: her own walk, %d frames from row %d (%s)" % [c, n, row0, e])
		check(cyc >= 1000 and cyc <= 1300, "%s: a two-step cycle of %d ms" % [c, cyc])
		var path: String = SK.sheet_row(c, row0).resource_path
		check(path == "res://assets/skins/%s_base/sheet_5.png" % c, "%s: the rows come from her 기본 / 초심 sheet_5 (%s)" % [c, path])
		for i in n:
			var rf: Array = SK.resolve(c, "walk", i)
			if rf != [row0 + i / 9, i % 9]:
				check(false, "%s walk frame %d resolves to %s" % [c, i, rf])
		check(SK.bob(c, "walk").is_empty(), "%s: no stride bob on top (the frames carry their own)" % c)
		# feet line and size, from the bounds the shader uses
		var B: Array = SK.bounds(c)
		var idle_b: int = B[1]
		var idle_h: int = B[1] - B[0]
		var bots: Array = []
		var hs: Array = []
		for i in n:
			var k: int = ((row0 + i / 9) * 9 + i % 9) * 2
			bots.append(int(B[k + 1]))
			hs.append(int(B[k + 1]) - int(B[k]))
		check(bots.min() >= feet - 1 and bots.max() <= feet + 1 and absi(idle_b - feet) <= 1, "%s: every frame's sole on the feet line %d ±1 (bottoms %d..%d, idle %d)" % [c, feet, bots.min(), bots.max(), idle_b])
		check(absf(float(hs.max()) / idle_h - 1.0) <= 0.03, "%s: the passing frame stands as tall as the idle (%d vs %d px)" % [c, hs.max(), idle_h])
		# the sheet itself: head steady, the stride
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		var heads: Array = []
		var bands: Array = []
		for i in n:
			var cx: int = (i % 9) * CH.CELL_W
			var cy: int = ((row0 + i / 9) % 7) * CH.CELL_H
			var top: int = B[((row0 + i / 9) * 9 + i % 9) * 2]
			var sx := 0.0
			var cnt := 0.0
			for y in range(top + 12, top + 30):
				for x in range(150, 300):
					var a := img.get_pixel(cx + x, cy + y).a
					if a > 0.5:
						sx += x
						cnt += 1.0
			heads.append(sx / maxf(1.0, cnt))
			bands.append(band(img, cx + 64, cy, 320, feet - 9, feet + 2, c == "aida"))
		check(heads.max() - heads.min() <= 8.0, "%s: the head keeps its column through the cycle (%.1f..%.1f)" % [c, heads.min(), heads.max()])
		var tot := 0
		var worst := 0.0
		var spd: float = folk.natural_speed(c)
		var wk: float = 0.5 * CH.SCALE[c]
		for i in n:
			var s := shift(bands[i], bands[(i + 1) % n], 320)
			tot += s
			worst = maxf(worst, absf(s * wk - spd * float(e[1][i])))
		var meas: float = tot * wk
		# (아이다: within 8 % — this plain overlap, without the tool's colour weighting, reads her creeping pose as -3 px)
		check(absf(meas / float(spec[c][3]) - 1.0) <= (0.08 if c == "aida" else 0.06), "%s: the sole's travel over a cycle measured again on the sheet, %.1f world px, matches the stated stride %.1f" % [c, meas, spec[c][3]])
		var tol: float = 4.0 if c == "aida" else 1.6       # 아이다's held poses (50 ms floor) where the boot barely moves or creeps
		check(worst <= tol, "%s: each frame's ground (speed × its time) matches its sole's shift within %.2f world px" % [c, worst])
		check(absf(spd - float(spec[c][3]) / cyc) < 0.0001, "%s: natural speed = stride / cycle (%.4f px/ms)" % [c, spd])
		var tg: Array = folk.title_gait(c)
		var wg: Array = folk.town_gait(c)
		check(absf(tg[0] / tg[1] - spd) < 0.0001 and absf(wg[0] / wg[1] - spd) < 0.0001, "%s: title (%.4f ×%.2f) and town (%.4f ×%.2f) walk at the stride speed for their cadence" % [c, tg[0], tg[1], wg[0], wg[1]])
		check(wg[1] >= 1.0 and wg[1] <= folk.TOWN_RATE + 0.0001, "%s: town life plays the walk at most ×%.1f" % [c, folk.TOWN_RATE])
	check(int(SK.entry("aida", "walk")[0]) != int(SK.entry("aida", "run")[0]), "아이다's walk is no longer her run row played slow")
	check(SK.resolve("aida", "run", 3) == [1, 3] and SK.resolve("luce", "run", 3) == [1, 3], "their runs are as before")
	var wl: String = load("res://scripts/ui_char_wear.gd").partial_line("aida_base")
	check(wl.contains("걷기"), "the 의상 line names the new walk (%s)" % wl)

	# ---- town life: a member walks at the town gait with planted feet ----
	arena.fame.join()
	var T = arena.level
	var F = T.folk
	var n = F.npc("luce")
	n["placed"] = true
	n["r"] = "top"
	n["x"] = 3000.0
	n["talk_t"] = 0.0
	n["chat_cd"] = 99999.0
	F.go(n, 3600.0, "top", false)
	var x0: float = n["x"]
	for i in 30: F._upd(n, 16.0)
	var g: Array = F.town_gait("luce")
	check(absf(n["x"] - x0 - g[0] * 480.0) < 0.5 and n["anim"] == "walk", "town life: 루체 walks %.1f px in 480 ms at %.4f px/ms" % [n["x"] - x0, g[0]])

	# ---- 브랜 ----
	var BR = T.bran
	var wt: Texture2D = BR.WALK
	check(wt.get_width() == BR.WALK_MS.size() * BR.WCW and wt.get_height() == BR.CHH and BR.WALK_MS.size() == 25, "브랜's walk: 25 cells of %d x %d art px" % [BR.WCW, BR.CHH])
	var wim := Image.load_from_file(ProjectSettings.globalize_path("res://assets/bran/walk.png"))
	var bb: Array = []
	var bt: Array = []
	for i in 25:
		var lo := 99
		var hi := -1
		for y in BR.CHH:
			for x in BR.WCW:
				if wim.get_pixel(i * BR.WCW + x, y).a > 0.5:
					lo = mini(lo, y)
					hi = maxi(hi, y)
		bb.append(hi)
		bt.append(hi - lo + 1)
	var pim := Image.load_from_file(ProjectSettings.globalize_path("res://assets/bran/px.png"))
	var plo := 99
	var phi := -1
	for y in BR.CHH:
		for x in BR.CW:
			if pim.get_pixel(x, y).a > 0.5:
				plo = mini(plo, y)
				phi = maxi(phi, y)
	check(bb.min() == phi and bb.max() == phi, "브랜's soles on his forge cells' feet row %d in every frame (%d..%d)" % [phi, bb.min(), bb.max()])
	check(absi(bt.max() - (phi - plo + 1)) <= 1, "브랜 walks as tall as he stands (%d vs %d art px)" % [bt.max(), phi - plo + 1])
	var wb: Array = []
	for i in 25: wb.append(band(wim, i * BR.WCW, 0, BR.WCW, phi - 4, phi + 1))
	var tot2 := 0
	for i in 25: tot2 += shift(wb[i], wb[(i + 1) % 25], BR.WCW, -2, 6)
	var cyc2 := 0
	for ms in BR.WALK_MS: cyc2 += int(ms)
	# his boots are a few art px wide and move ~1.4 art px a frame: whole-pixel overlaps on the drawn cells are coarse,
	# the tool measures on a 4x render (heel 28 → 22 over frames 6-13 here, 7.3 by the stated speed)
	check(absf(tot2 * BR.S / BR.WALK_STRIDE - 1.0) <= 0.25 and absf(BR.WALK_SPD * cyc2 - BR.WALK_STRIDE) < 0.5, "브랜's boot travels %d art px a cycle (%.0f world px; stated %.1f over %d ms → %.4f px/ms)" % [tot2, tot2 * BR.S, BR.WALK_STRIDE, cyc2, BR.WALK_SPD])
	# the stroll: out, rest, home, back to work
	var P = arena.player
	P.position = Vector2(BR.home - 1500.0, BR.y)
	BR.play("idle")
	BR.stroll()
	var far: float = BR.x
	var moved := 0.0
	var steps := 0
	var walked_ms := 0.0
	var px: float = BR.x
	var seen_walk := false
	while BR.strolling() and steps < 2000:
		BR.step(16.0)
		if BR.anim == "walk":
			seen_walk = true
			walked_ms += 16.0
			moved += absf(BR.x - px)
		px = BR.x
		far = minf(far, BR.x)
		steps += 1
	check(seen_walk and not BR.strolling() and BR.x == BR.home and BR.dir == 1, "브랜 strolls out and comes back to his anvil (%d ticks)" % steps)
	check(BR.home - far >= BR.STROLL_MIN - 0.5 and BR.home - far <= BR.STROLL_MAX + 0.5, "… %.0f px away from the anvil" % (BR.home - far))
	check(absf(moved / maxf(1.0, walked_ms) - BR.WALK_SPD) < 0.002, "… at the walk art's pace (%.4f px/ms)" % (moved / maxf(1.0, walked_ms)))
	# someone comes near mid-stroll: he stops and turns to them, is talkable there, and finishes the stroll after
	BR.stroll()
	for i in 40: BR.step(16.0)
	var xs: float = BR.x
	check(BR.anim == "walk" and xs < BR.home, "mid-stroll, away from the anvil (%.0f)" % (BR.home - xs))
	P.position = Vector2(xs + BR.MID - 70.0, BR.y)
	for i in 10: BR.step(16.0)
	check(BR.anim == "talk" and BR.x == xs and BR.dir == -1 and BR.is_near(P), "someone near: he stops where he is and turns to them; still talkable (is_near)")
	P.on = true
	P.vy = 0.0
	T.near_door = null
	arena._process(0.016)
	check(T.near_door != null and T.near_door.get("act", "") == "bran" and absf(float(T.near_door["x"]) - (BR.x + BR.MID)) < 0.01, "the town offers 브랜's talk where he stands (%s)" % [T.near_door])
	P.position = Vector2(BR.home - 1500.0, BR.y)
	BR.talk_t = 0.0
	var k2 := 0
	while BR.strolling() and k2 < 3000:
		BR.step(16.0)
		k2 += 1
	check(not BR.strolling() and BR.x == BR.home, "they leave: he finishes the stroll at his anvil")
	var hammered := false
	for i in 3000:
		BR.step(16.0)
		if BR.anim == "hammer":
			hammered = true
			check(BR.x == BR.home, "the hammer only swings at the anvil")
			break
	check(hammered, "and goes back to work")
	print("walk checks done, fails=", fails)
	print("FAILS %d" % fails)
	quit()
