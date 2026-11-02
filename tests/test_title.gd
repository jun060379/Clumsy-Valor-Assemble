extends SceneTree
## The music-driven title: godot --headless --path . -s tests/test_title.gd
## beat.gd's grid and sections, the clock's fallbacks and the loop wrap, what the scene shows at a music time for an
## empty / three-member / rank-7 save (the light ladder, the framings, the cut-in slots, the crowd), the empty-state
## cut-in, and a bare title with no fame and no audio running the whole 165 s timeline headless without errors.

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

	# ---- the title on an arena ----
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var T = arena.ui_root.title
	var F = arena.fame
	var B = arena.bgm
	check(not T.gate and not T.live, "a test run: no gate (not the web), not live until the title is used")
	T.active = true
	T.visible = true
	T.go_live()
	check(T.live and T.beat.music_t == 0.0, "go_live: the clock starts at 0")
	check(B.wanted_title() and B.tap.playing and B.tap.stream.loop, "bgm: the title track is wanted and playing, looping")
	check(not B.wanted(), "bgm: the town is not wanted under the title")
	T.beat.hold = true
	# ---- an empty save ----
	F.rec = ["estelle"]
	F.fac = {}
	F.r = 1
	T.crowd_seed.clear()
	check(T.people() == ["estelle"] and T.lit_windows() == 1 and T.crowd_n() == 0 and T.open_spots(), "empty: 에스텔 alone, one light, no crowd, open spots")
	at(T, 5.0)
	check(T.sec == "A" and T.lights_on == 0 and not T.intro_done and not T.menu_in, "5 s: section A, no lights yet, the intro running")
	at(T, 9.5)
	check(T.lights_on == 1 and T.intro_done, "9.5 s: the first light (Eilin's window), the menu usable")
	at(T, 30.0)
	check(T.lights_on == 1 and T.fB == 0.0 and T.fC == 0.0 and T.menu_in, "30 s: the A framing, the menu in")
	at(T, 56.5)
	check(T.sec == "B" and near(T.fB, 1.0) and T.slot() == 1 and T.slot_who(1) == "", "56.5 s, empty save: the cut-in's second slot is the empty chair")
	check(T.slot_who(0) == "estelle" and T.slot_who(2) == "estelle" and T.slot_who(3) == "", "empty save slots: 에스텔, chair, 에스텔, chair")
	at(T, 80.0)
	check(T.slot() == 3 and T.slot_who(3) == "", "80 s, empty save: the empty chair")
	# ---- three members, four facilities, rank 3 ----
	F.rec = ["estelle", "aida", "luce"]
	F.fac = {"fire": 1, "chand": 1, "forge": 1, "hearth": 1}
	F.r = 3
	T.crowd_seed.clear()
	check(T.people().size() == 3 and T.lit_windows() == 5 and T.crowd_n() == 6, "three: 3 people, 5 lights, a crowd of 6")
	at(T, 9.5)
	check(T.lights_on == 1, "9.5 s: one light")
	at(T, 9.22 + 1.3005 * 2.5)
	check(T.lights_on == 3, "two and a half bars after the slap: three lights (%d)" % T.lights_on)
	at(T, 30.0)
	check(T.lights_on == 5, "30 s: all five (%d)" % T.lights_on)
	T._sync_crowd()
	check(T.crowd_seed.size() == 6, "the crowd's seeds follow the rank (%d)" % T.crowd_seed.size())
	check(T.slot_who(0) == "estelle" and T.slot_who(1) == "aida" and T.slot_who(2) == "luce" and T.slot_who(3) == "", "three slots: 에스텔, 아이다, 루체, then the empty chair")
	at(T, 50.0)
	check(T.sec == "B" and near(T.fB, 1.0) and T.fC == 0.0 and T.slot() == 0, "50 s: the cut-in (에스텔)")
	at(T, 60.0)
	check(T.slot() == 1 and T._panel_figure(root.get_visible_rect().size)[0] == "aida", "60 s: 아이다's cut-in")
	at(T, 90.0)
	check(T.sec == "C" and near(T.fC, 1.0) and T.fB == 0.0 and near(T.kF, 0.55) and near(T.gy, 0.80), "90 s: the village wide — the hall at .55, the ground at .80 H")
	at(T, 130.0)
	check(T.sec == "D" and T.fB == 0.0 and T.fC == 0.0 and T.lights_on == 5, "130 s: ASSEMBLE in the A framing, all lights")
	at(T, 155.0)
	check(T.sec == "out" and T.wedge.is_empty(), "155 s: the outro, no wedge yet")
	# ---- the wedges ----
	at(T, 45.7)
	check(not T.wedge.is_empty() and T.wedge[1] == 1 and T.wedge[2] < 1.0, "45.7 s: section B's wedge mid-sweep, left → right")
	at(T, 118.5)
	check(not T.wedge.is_empty() and T.wedge[3] == true, "118.5 s: section D's wedge carries the biggest burst")
	at(T, 164.3)
	check(not T.wedge.is_empty() and T.wedge[1] == -1, "164.3 s: the loop's wedge from the right")
	# ---- the loop wrap ----
	T.beat.hold = false
	T.beat.set_time(164.4)
	T.beat.step(0.1, -1.0)
	T._tick()
	check(T.beat.lap == 1 and near(T.mt, 0.06) and T.sec == "A", "the wrap: lap 1, 0.06 s, section A")
	check(not T.wedge.is_empty() and T.wedge[1] == -1, "just after the wrap: the wedge uncovers the intro")
	check(T.menu_in and T.intro_done and T.lights_on == 5, "after the wrap: the menu stays, the lights stay")
	var m: Array = T._hall_motion(root.get_visible_rect().size, 1.0)
	check(m[3] == 1.0, "after the wrap: the hall is already there")
	T.beat.hold = true
	# ---- rank 7 ----
	F.r = 7
	F.fac = {"a": 1, "b": 1, "c": 1, "d": 1, "e": 1, "f": 1, "g": 1}
	T.crowd_seed.clear()
	check(T.crowd_n() == 18 and T.lit_windows() == 7, "rank 7: a crowd of 18, the whole ladder")
	T.beat.lap = 0
	at(T, 17.5)
	var st: Array = T._crowd_start(0)
	check(near(st[0], 17.09) and not st[1], "17.5 s: the crowd sprints in from 17.09, one per beat")
	at(T, 90.0)
	st = T._crowd_start(2)
	check(near(st[0], 84.6225 + 0.26 + 2.0 * 1.3005) and not st[1], "section C: the third figure sprints in two bars after the switch")
	at(T, 130.0)
	check(T._crowd_start(17)[1], "section D: the crowd is present")
	# ---- hand-off: the clock stops, the town takes over from 0 ----
	for i in 20:
		B._process(0.05)
		await process_frame
	check(B.tgain >= 1.0 and B.tap.playing and not B.ap.playing, "under the title: the title track at full, the town silent")
	T.beat.hold = false
	T.active = false
	T.visible = false
	T.beat.stop()
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	for i in 6:
		B._process(0.05)
		await process_frame
	check(B.wanted() and not B.wanted_title() and B.ap.playing and B.tgain < 1.0 and B.tgain > 0.0, "after the hand-off: the town starts while the title fades (tgain %.2f)" % B.tgain)
	check(B.ap.get_playback_position() < 0.5, "the town starts from 0 (%.2f)" % B.ap.get_playback_position())
	for i in 30:
		B._process(0.05)
		await process_frame
	check(B.tgain == 0.0 and not B.tap.playing and B.gain >= 1.0, "1.5 s on: the title track is off, the town at full")
	# ---- a title with no fame and no audio runs the whole timeline ----
	var bare = load("res://scripts/title.gd").new()
	bare.arena = null
	bare.ui_root = null
	root.add_child(bare)
	bare.go_live()
	check(bare.live and bare.people() == ["estelle"] and bare.lit_windows() == 1 and bare.crowd_n() == 0, "no fame: 에스텔, one light, no crowd")
	var tt := 0.0
	var seen := {}
	while tt < 165.0:
		bare.beat.set_time(tt)
		bare._tick()
		seen[bare.sec] = true
		await process_frame
		tt += 0.25
	check(seen.size() == 5, "no fame, no audio: every section drew (%s)" % [seen.keys()])
	bare.beat.hold = false
	bare.beat.set_time(164.4)
	bare.beat.step(0.1)
	bare._tick()
	await process_frame
	check(bare.beat.lap == 1 and bare.menu_in, "no fame: the loop wrapped")
	bare.burst_t = bare.clock
	bare.outro = 0.0
	for i in 3: await process_frame
	check(bare.outro > 0.0, "no fame: the burst and the outro draw")
	bare.queue_free()
	print("FAILS: %d" % fails)
	quit()
