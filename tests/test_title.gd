extends SceneTree
## The music-driven title over the live town: godot --headless --path . -s tests/test_title.gd
## beat.gd's grid and sections, the clock's fallbacks and the loop wrap; the title's hold on the town (title_mode puts
## the party out in town and the hero aside, restored on the hand-off), the camera override and its framings by
## section, the passing greetings (once per pair per cooldown), the bgm hand-off, and a bare title with no arena and
## no audio running the whole 165 s timeline headless without errors.

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps

## jump the title's clock and derive the frame
func at(T, t: float) -> void:
	T.beat.set_time(t)
	T._tick()
	T._camera()

func _initialize() -> void:
	var BEAT = load("res://scripts/beat.gd")
	# ---- the grid ----
	check(near(BEAT.bar_t(0), 0.09) and near(BEAT.bar_t(35), 45.6075) and near(BEAT.bar_t(65), 84.6225) and near(BEAT.bar_t(91), 118.4355) and near(BEAT.bar_t(115), 149.6475), "bars 0 / 35 / 65 / 91 / 115 start at 0.09 / 45.6 / 84.6 / 118.4 / 149.6 s")
	check(near(BEAT.PULSE, 0.65025) and near(BEAT.BEAT, 0.325125) and near(BEAT.PHRASE, 10.404), "pulse 0.650 s, beat 0.3251 s, phrase 10.40 s")
	for p in [[0.0, "A"], [45.5, "A"], [45.7, "B"], [84.5, "B"], [84.7, "C"], [118.3, "C"], [118.5, "D"], [149.5, "D"], [149.7, "out"], [164.4, "out"]]:
		check(BEAT.section_at(p[0]) == p[1], "section at %.1f s is %s (%s)" % [p[0], p[1], BEAT.section_at(p[0])])
	var b = BEAT.new()
	b.start(0.0)
	b.set_time(45.7)
	check(b.bar() == 35 and b.phrase() == 4 and b.section() == "B", "45.7 s: bar 35, phrase 4, section B (bar %d phrase %d %s)" % [b.bar(), b.phrase(), b.section()])
	b.set_time(0.09 + 1.3005 * 3.0 + 0.325125 * 2.0)
	check(b.beat_in_bar() == 2 and near(b.bar_phase(), 0.5) and near(b.pulse_phase(), 0.0, 0.02), "two beats into a bar: beat 2, bar phase .5, pulse phase 0")
	check(near(BEAT.bump(0.0), 0.0) and near(BEAT.bump(0.175), 1.0) and BEAT.bump(0.5) == 0.0, "bump peaks mid-window and is gone after it")
	# ---- the clock: wall fallback, a stuck stream, a healthy stream, the wrap ----
	b.start(0.0)
	b.step(0.5, -1.0)
	check(near(b.music_t, 0.5), "no stream: the wall clock runs (%.2f)" % b.music_t)
	for i in 10: b.step(0.1, 0.0)              # a dummy driver: 'playing' but the position never moves
	check(near(b.music_t, 1.5) and not b.healthy, "a stuck stream position: the wall clock carries on (%.2f, healthy %s)" % [b.music_t, b.healthy])
	b.step(0.1, 7.0)
	b.step(0.1, 7.1)
	check(b.healthy and near(b.music_t, 7.1), "a moving stream: music_t follows it (%.2f)" % b.music_t)
	for i in 4: b.step(0.1, 7.1)
	check(b.healthy and near(b.music_t, 7.1), "a short stall (under %.1f s) keeps following the stream" % BEAT.STALL)
	b.step(0.1, 7.1)
	check(not b.healthy and near(b.music_t, 7.2), "a longer stall: the wall clock takes over where the stream stopped (%.2f)" % b.music_t)
	b.start(0.0)
	b.step(0.1, 0.0)
	b.step(0.1, 0.0)
	check(not b.healthy and near(b.music_t, 0.2), "a fresh start on a dummy driver: the first position alone proves nothing (%.2f)" % b.music_t)
	b.set_time(164.4)
	b.step(0.1, -1.0)
	check(near(b.music_t, 0.06) and b.wrapped and b.lap == 1, "the wrap: 164.4 + 0.1 → 0.06, lap 1 (%.2f lap %d)" % [b.music_t, b.lap])
	b.hold = true
	b.step(1.0, -1.0)
	check(near(b.music_t, 0.06), "hold: the clock stands still")
	b.stop()
	check(not b.live, "stop")

	# ---- the title on an arena: the town lives under it ----
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var T = arena.ui_root.title
	var F = arena.fame
	var B = arena.bgm
	var P = arena.player
	var folk = arena.FOLK.of(arena)
	check(not T.gate and not T.live and not arena.title_mode, "a test run: no gate (not the web), not live, the town not held for the title")
	check(arena.level_kind() == "town", "the world started in town")
	F.rec = ["estelle", "aida", "luce"]
	F.fac = {"fire": 1, "chand": 1}
	F.r = 3
	P.who = "estelle"
	P.party = ["estelle", "aida"]
	var home: Vector2 = P.position
	T.active = true
	T.visible = true
	await process_frame
	await process_frame
	check(T.live and arena.title_mode, "the title up: live, the town in title mode")
	check(not P.visible and P.position.x < -5000.0 and arena.title_park == home, "the hero hidden and parked off-world (parked at %s)" % [arena.title_park])
	check(folk.title_mode and folk.folk() == ["aida", "luce"], "title mode: the party and the rest out in town, the hero not (%s)" % [folk.folk()])
	check(folk.npc("aida")["placed"] and folk.npc("luce")["placed"], "everyone placed")
	check(B.wanted_title() and B.tap.playing and not B.wanted(), "bgm: the title track plays, the town is not wanted")
	check(arena.cam_override is Vector2 and T.framing == "F1", "the title drives the camera: F1 (%s)" % T.framing)
	T.beat.hold = true
	var L = arena.level
	at(T, 30.0)
	var f1: Vector2 = T._framing("F1")
	check(near(f1.x, L.HXB + 330.0) and near(f1.y, L.TTOP - 160.0), "F1 본관 정면: HXB + 330, the terrace at ~.82 H (%s)" % [f1])
	check(T.sec == "A" and T.framing == "F1" and near(T.cam_pos.x, f1.x + 40.0 * sin(PI * (30.0 - 0.09) / 45.52), 2.0), "30 s: F1 with its drift (%s)" % [T.cam_pos])
	await process_frame
	check(near(arena.cam.position.x, T.cam_pos.x, 1.0) and near(arena.cam.position.y, T.cam_pos.y, 1.0), "the arena's camera follows the title's (%s)" % [arena.cam.position])
	var drift := func(t: float) -> float: return 40.0 * sin(PI * (t - 0.09) / (BEAT.bar_t(35) - 0.09))
	at(T, 2.5)
	check(near(T.cam_pos.x, f1.x - 60.0 + drift.call(2.5), 1.0), "2.5 s: the intro's pull-in starts 60 px left of F1 (%s)" % [T.cam_pos])
	at(T, 3.3)
	check(near(T.cam_pos.x, f1.x + drift.call(3.3), 1.0), "3.3 s: settled into F1")
	for p in [[45.7, "F1"], [46.0, "F2"], [50.0, "F2"], [84.7, "F2"], [90.0, "F3"], [118.5, "F3"], [130.0, "F2"], [150.0, "F1"], [155.0, "F1"]]:
		at(T, p[0])
		check(T.framing == p[1], "%.1f s: framing %s (%s)" % [p[0], p[1], T.framing])
	at(T, 45.7)
	check(not T.wedge.is_empty() and T.wedge[1] == 1, "45.7 s: section B's wedge mid-sweep")
	at(T, 118.5)
	check(not T.wedge.is_empty() and T.wedge[3] == true, "118.5 s: section D's wedge carries the biggest burst")
	at(T, 149.8)
	check(not T.wedge.is_empty(), "149.8 s: the outro's wedge (back to F1)")
	at(T, 164.3)
	check(not T.wedge.is_empty() and T.wedge[1] == -1, "164.3 s: the loop's wedge from the right")
	# the loop wrap
	T.beat.hold = false
	T.beat.set_time(164.4)
	T.beat.step(0.1, -1.0)
	T._tick()
	check(T.beat.lap == 1 and near(T.mt, 0.06) and T.sec == "A" and T.framing == "F1", "the wrap: lap 1, section A, F1")
	check(not T.wedge.is_empty() and T.wedge[1] == -1 and T.menu_in and T.intro_done, "just after the wrap: the wedge uncovers the intro, the menu stays")
	T.beat.hold = true
	# ---- the passing greetings ----
	var a = folk.npc("aida")
	var c = folk.npc("luce")
	for n in [a, c]:
		n["r"] = "top"
		n["mode"] = "move"
		n["path"] = [{"x": 1000.0, "r": "top"}]
		n["chat"] = null
		n["partner"] = null
		n["seek"] = null
		n["talk_t"] = 0.0
	a["x"] = 3000.0
	c["x"] = 3040.0
	folk.greet_cd.clear()
	var g0: int = folk.greets
	folk.step(16.0)
	check(folk.greets == g0 + 1 and a["mode"] == "greet" and c["mode"] == "greet", "two walkers within 60 px: both stop to greet")
	check(a["dir"] == 1 and c["dir"] == -1 and a["say"] != "" and c["say"] != "" and a["say"] in folk.EMOTES and c["say"] in folk.EMOTES, "they face each other and show emotes (%s %s)" % [a["say"], c["say"]])
	for i in 80: folk.step(16.0)
	check(a["mode"] == "move" and c["mode"] == "move", "1.2 s on: both walk again")
	a["x"] = 3000.0
	c["x"] = 3040.0
	folk.step(16.0)
	check(folk.greets == g0 + 1, "the pair's cooldown: no second greeting yet")
	folk.greet_cd["aida|luce"] = 1.0
	folk.step(16.0)
	folk.step(16.0)
	check(folk.greets == g0 + 2, "the cooldown over: they greet again")
	check(not folk.greet_cd.is_empty() and folk.greet_cd["aida|luce"] > 19000.0, "a 20 s cooldown per pair")
	# ---- the hand-off: the hero back, her party hers, the camera hers, the town's music ----
	for i in 20:
		B._process(0.05)
		await process_frame
	check(B.tgain >= 1.0, "under the title: the title track at full")
	T.beat.hold = false
	arena.leave_title_mode()
	check(not arena.title_mode and P.visible and P.position == home, "leaving title mode: the hero back where she stood, visible")
	check(arena.cam_override == null and not folk.title_mode and folk.folk() == ["luce"], "the camera and the townsfolk are the game's again, the party hers (%s)" % [folk.folk()])
	T._go()
	check(not T.active and not arena.title_mode, "the hand-off: the title off")
	for i in 6:
		B._process(0.05)
		await process_frame
	check(B.wanted() and not B.wanted_title() and B.ap.playing and B.tgain < 1.0 and B.tgain > 0.0, "the town starts while the title fades (tgain %.2f)" % B.tgain)
	check(B.ap.get_playback_position() < 0.5, "the town starts from 0 (%.2f)" % B.ap.get_playback_position())
	for i in 30:
		B._process(0.05)
		await process_frame
	check(B.tgain == 0.0 and not B.tap.playing and B.gain >= 1.0, "1.5 s on: the title track is off, the town at full")
	# ---- a title with no arena and no audio runs the whole timeline ----
	var bare = load("res://scripts/title.gd").new()
	bare.arena = null
	bare.ui_root = null
	root.add_child(bare)
	bare.go_live()
	check(bare.live and bare.framing == "F1", "no arena: live, F1")
	var tt := 0.0
	var seen := {}
	while tt < 165.0:
		bare.beat.set_time(tt)
		bare._tick()
		bare._camera()
		seen[bare.sec] = true
		await process_frame
		tt += 0.25
	check(seen.size() == 5, "no arena, no audio: every section drew (%s)" % [seen.keys()])
	bare.beat.hold = false
	bare.beat.set_time(164.4)
	bare.beat.step(0.1)
	bare._tick()
	await process_frame
	check(bare.beat.lap == 1 and bare.menu_in, "no arena: the loop wrapped")
	bare.burst_t = bare.clock
	bare.outro = 0.0
	for i in 3: await process_frame
	check(bare.outro > 0.0, "no arena: the burst and the outro draw")
	bare.queue_free()
	print("FAILS: %d" % fails)
	quit()
