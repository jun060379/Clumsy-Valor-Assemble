extends SceneTree
## The music-driven title over the live town: godot --headless --path . -s tests/test_title.gd
## beat.gd's grid and the clock's fallbacks and loop wrap; the title always showing the town (a save in the hall → the
## town under the title → 불러오기 restores the hall); the hero out walking under the title and the party restored on
## the hand-off; the stride-matched title gait; the follow camera (the subject's choice, the preference, no repeat,
## the idle return, the pan's speed cap); the new intro's times; the slabs' press / release logic; the 시작 card with
## and without a save; the 450 ms feedback before the outro; the keyboard path; a bare title with no arena running
## the whole 165 s timeline headless without errors. 시작 continues the autosave (no card) or, with no save at all, asks
## with the new-story card; 불러오기's slot card lists 자동 저장 + 슬롯 1·2·3 and passes over the empty ones.

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

## one title frame of `ms` (the camera and the feedback clocks run on it)
func tick(T, ms: float) -> void:
	T.clock += ms
	T._camera(ms)

func mouse(T, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	T._input(ev)

func key(T, k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	T._input(ev)

func _initialize() -> void:
	var BEAT = load("res://scripts/beat.gd")
	# ---- the grid and the clock ----
	check(near(BEAT.bar_t(0), 0.09) and near(BEAT.bar_t(35), 45.6075) and near(BEAT.bar_t(115), 149.6475), "bars 0 / 35 / 115 start at 0.09 / 45.6 / 149.6 s")
	check(near(BEAT.PULSE, 0.65025) and near(BEAT.BEAT, 0.325125), "pulse 0.650 s, beat 0.3251 s")
	var b = BEAT.new()
	b.start(0.0)
	b.step(0.5, -1.0)
	check(near(b.music_t, 0.5), "no stream: the wall clock runs (%.2f)" % b.music_t)
	for i in 10: b.step(0.1, 0.0)
	check(near(b.music_t, 1.5) and not b.healthy, "a stuck stream position: the wall clock carries on")
	b.step(0.1, 7.0)
	b.step(0.1, 7.1)
	check(b.healthy and near(b.music_t, 7.1), "a moving stream: music_t follows it")
	b.set_time(164.4)
	b.step(0.1, -1.0)
	check(near(b.music_t, 0.06) and b.wrapped and b.lap == 1, "the wrap: 164.4 + 0.1 → 0.06, lap 1")

	# ---- the title on an arena ----
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var T = arena.ui_root.title
	var F = arena.fame
	var B = arena.bgm
	var P = arena.player
	var folk = arena.FOLK.of(arena)
	var vs: Vector2 = root.get_visible_rect().size
	check(arena.level_kind() == "town" and not T.gate and not arena.title_mode, "a test run: the world in town, no gate, the town not held for the title")
	# ---- the intro's times ----
	check(near(T.T_LOGO, 0.42) and near(T.T_MENU[0], 1.065, 0.01) and near(T.T_MENU[1] - T.T_MENU[0], 0.1625, 0.001) and near(T.T_MENU[3], 1.553, 0.01), "the logo on 0.42, the slabs on four 16ths from 1.07")
	check(near(T.T_CURSOR, 1.716, 0.01) and near(T.T_MOTTO, 2.11) and near(T.T_EMBLEM, 2.76) and near(T.T_CAM, 3.23), "the cursor on 1.72, the motto 2.11, the flower 2.76, the camera settled by 3.23")
	# ---- always the town: a save in the hall ----
	F.rec = ["estelle", "aida", "luce"]
	F.fac = {"fire": 1, "chand": 1}
	F.r = 3
	P.who = "estelle"
	P.party = ["estelle", "aida"]
	var s0: Array = arena.HALL.HD.SPAWN[1]
	arena.go_hall(1, Vector2(s0[0], s0[1]), 1)
	for i in 3: await process_frame
	check(arena.level_kind() == "hall" and arena.level.fl == 1, "the save woke in the hall, floor 1")
	var saved: bool = arena.save.save()
	arena.save.loaded = true                  # (as a boot from this save would leave it)
	check(saved and FileAccess.file_exists(arena.save.path), "a save written in the hall")
	var hall_at: Vector2 = P.position
	T.active = true
	T.visible = true
	await process_frame
	await process_frame
	check(T.live and arena.title_mode and arena.level_kind() == "town", "the title up: the town is the backdrop, not the hall")
	check(arena.title_back.get("kind", "") == "hall" and int(arena.title_back.get("fl", -1)) == 1, "the hall remembered for the hand-off (%s)" % [arena.title_back])
	check(not P.visible and P.position.x < -5000.0, "the hero's node hidden and parked off-world")
	check(folk.title_mode and folk.folk() == ["estelle", "aida", "luce"], "title mode: everyone who joined walks the town, the hero too (%s)" % [folk.folk()])
	check(folk.npc("estelle")["placed"] and folk.npc("aida")["placed"] and folk.npc("luce")["placed"], "everyone placed")
	check(B.wanted_title() and B.tap.playing and not B.wanted(), "bgm: the title track plays, the town is not wanted")
	# ---- the stride-matched gait ----
	var ge: Array = folk.title_gait("estelle")
	var ga: Array = folk.title_gait("aida")
	var gl: Array = folk.title_gait("luce")
	check(near(folk.natural_speed("estelle"), 0.058, 0.001) and near(ge[0], 0.058, 0.001) and near(ge[1], 1.0), "에스텔's 초심 walk: 0.058 px/ms at its native cadence, the feet planted (%s)" % [ge])
	check(near(ga[0], 0.09, 0.001) and near(ga[1], 0.62, 0.01), "아이다's run-row walk slowed to 0.09 px/ms, its frames slowed the same (%s)" % [ga])
	check(near(gl[1], folk.TITLE_PACE, 0.001) and near(gl[0] / gl[1], 0.20, 0.001), "루체's: the frames at TITLE_PACE, the ground speed in the same ratio (%s)" % [gl])
	for c in ["estelle", "aida", "luce"]:
		var g: Array = folk.title_gait(c)
		check(near(g[0] / g[1], folk.natural_speed(c), 0.0001), "%s: ground speed / frame rate = the sheet's stride speed (no sliding feet)" % c)
	var E0 = arena.eil
	check(not E0.hurry() and near(E0.spd(), E0.EIL_SPD * 0.7, 0.0001), "Eilin under the title: never the trot, her walkL stroll at 0.7 with its frames at 0.7")
	var ne = folk.npc("estelle")
	ne["r"] = "top"
	ne["x"] = 3000.0
	ne["mode"] = "idle"
	ne["wait"] = 0.0
	ne["path"] = []
	ne["talk_t"] = 0.0
	folk.go(ne, 3800.0, "top", true)
	check(near(folk.path_left(ne), 800.0) and folk.walking(ne), "path_left / walking")
	var x0: float = ne["x"]
	var f0: int = ne["f"]
	for i in 10: folk._upd(ne, 16.0)
	check(near(ne["x"] - x0, 0.058 * 160.0, 0.5) and ne["anim"] == "walk" and ne["dir"] == 1, "under the title she walks at the art's pace, never runs (%.1f px in 160 ms, %s)" % [ne["x"] - x0, ne["anim"]])
	var flips := 0
	var d0: int = ne["dir"]
	for i in 70:
		folk._upd(ne, 16.0)
		if ne["dir"] != d0: flips += 1
		d0 = ne["dir"]
	check(ne["f"] != f0 and flips == 0, "the walk's frames advance (frame %d), no flips on a straight way" % ne["f"])
	# ---- the camera: home, the pull-in, the follow ----
	T.beat.hold = true
	var home: Vector2 = T._home()
	check(near(home.x, arena.level.HXB + 330.0) and near(home.y, arena.level.TTOP - 160.0), "home: the hall's front (%s)" % [home])
	at(T, 0.5)
	T.cam_phase = "home"
	T.subject = ""
	T.cam_lap = T.beat.lap
	tick(T, 16.0)
	check(near(T.cam_pos.x, home.x - 60.0 * (1.0 - T._pull()), 0.5) and T.cam_pos.x < home.x - 20.0, "0.5 s: the pull-in under way from 60 px left (%.1f)" % (home.x - T.cam_pos.x))
	at(T, 3.2)
	tick(T, 16.0)
	check(near(T.cam_pos.x, home.x, 1.0) and arena.cam_override is Vector2, "3.2 s: settled on the hall's front, the arena's camera overridden")
	at(T, 30.0)
	# nobody walks: the pick finds no one, the camera stays home
	for c in folk.folk():
		var n = folk.npc(c)
		n["mode"] = "idle"
		n["path"] = []
		n["wait"] = 1.0e9
	T.pick_t = 10.0
	tick(T, 16.0)
	check(T.subject == "" and T.cam_phase == "home" and T.pick_subject() == "", "nobody walking: no subject")
	# a short path does not qualify; a long one does; members before Eilin; not the same one twice in a row
	var na = folk.npc("aida")
	na["r"] = "top"
	na["x"] = 2600.0
	na["mode"] = "idle"
	na["wait"] = 0.0
	na["path"] = []
	folk.go(na, 2800.0, "top", false)
	check(folk.path_left(na) < 280.0 and T.pick_subject() == "", "a walker with 200 px to go does not qualify")
	folk.go(na, 1400.0, "top", false)
	ne["mode"] = "idle"
	ne["wait"] = 0.0
	ne["path"] = []
	ne["x"] = 3200.0
	folk.go(ne, 4300.0, "top", false)
	var E = arena.eil
	E.map = "town"
	E.x = 1700.0
	E.path = [{"t": "walk", "x": 2900.0, "y": arena.level.TTOP}, {"t": "arrive", "spot": "counter"}]
	E.wait = 0.0
	E.talk_t = 0.0
	E.hide = false
	var ws: Array = T.walkers()
	check(ws.size() == 3 and ws.filter(func(w): return w[0] == "eilin").size() == 1, "three walkers in town, Eilin among them (%s)" % [ws.map(func(w): return w[0])])
	T.last_subject = ""
	var p1: String = T.pick_subject()
	check(p1 in ["estelle", "aida"], "a member is preferred to Eilin (%s)" % p1)
	T.last_subject = p1
	var p2: String = T.pick_subject()
	check(p2 != p1 and p2 in ["estelle", "aida"], "never the same subject twice while another member qualifies (%s → %s)" % [p1, p2])
	ne["path"] = []
	ne["mode"] = "idle"
	na["path"] = []
	na["mode"] = "idle"
	T.last_subject = "eilin"
	check(T.pick_subject() == "eilin", "only Eilin walking: she is picked even after herself")
	T.last_subject = ""
	# the follow: the subject held at 0.42 W walking right, the pan capped at 140 px/s
	ne["mode"] = "idle"
	ne["wait"] = 0.0
	ne["x"] = 3400.0
	folk.go(ne, 5200.0, "top", false)
	E.path = []
	T.subject = "estelle"
	T.cam_phase = "follow"
	T.cam_pos = home
	T.cam_v = Vector2.ZERO
	var vmax := 0.0
	for i in 800:
		var before: Vector2 = T.cam_pos
		folk._upd(ne, 16.0)
		tick(T, 16.0)
		vmax = maxf(vmax, (T.cam_pos - before).length() / 0.016)
	var want_x: float = float(ne["x"]) + 0.08 * vs.x
	check(T.cam_phase == "follow" and T.subject == "estelle", "following 에스텔")
	check(absf(T.cam_pos.x - want_x) < 40.0, "she is held near 0.42 W walking right (camera %.0f, wanted %.0f)" % [T.cam_pos.x, want_x])
	check(vmax <= 141.0, "the pan never exceeds 140 px/s (%.0f)" % vmax)
	check(T.cam_pos.y >= T._cam_y(float(arena.level.TTOP)) - 2.0 and T.cam_pos.y <= T._cam_y(arena.ground_y) + 2.0 and near(T._cam_y(float(arena.level.TTOP)), home.y, 0.5), "the camera's y keeps her feet at 0.82 H, the terrace at the hall front's height (%.0f)" % T.cam_pos.y)
	# she stops: the camera glides to a stop and holds, then looks for the next one; nobody for 12 s → home
	ne["path"] = []
	ne["mode"] = "idle"
	ne["wait"] = 1.0e9
	tick(T, 16.0)
	check(T.subject == "" and T.cam_phase == "hold" and T.last_subject == "estelle" and T.hold_t >= 4000.0 and T.hold_t <= 8000.0, "she stopped: a 4–8 s hold (%.0f ms)" % T.hold_t)
	var held: Vector2 = T.cam_pos
	for i in 35: tick(T, 100.0)
	check((T.cam_pos - T.hold_at).length() < 6.0 and (T.cam_pos - held).length() < 120.0, "the camera glides to a stop near where she stopped (%.0f px on)" % (T.cam_pos - held).length())
	var guard := 0
	while T.cam_phase != "home" and guard < 200:
		tick(T, 100.0)
		guard += 1
	check(T.cam_phase == "home" and T.idle_t >= 12000.0 and T.ret_dur >= 3000.0, "nobody walked for 12 s: the drift back to the hall (%.0f ms for %.0f px)" % [T.ret_dur, (T.cam_pos - home).length()])
	var far: float = (T.ret_from - home).length()
	check(near(T.ret_dur, maxf(3000.0, 1.5 * far / 140.0 * 1000.0), 1.0), "the drift: 3 s, or as long as 140 px/s needs")
	var vret := 0.0
	var steps := 0
	while T.ret_dur > 0.0 and steps < 2000:
		var b0: Vector2 = T.cam_pos
		tick(T, 50.0)
		vret = maxf(vret, (T.cam_pos - b0).length() / 0.05)
		steps += 1
	check((T.cam_pos - home).length() < 1.0 and vret <= 141.0, "home again (%.0f px off), the drift never past 140 px/s (%.0f)" % [(T.cam_pos - home).length(), vret])
	# a short drift: 3 s exactly
	T.cam_pos = home + Vector2(150.0, 0.0)
	T.cam_phase = "hold"
	T.hold_t = 0.0
	T.idle_t = 13000.0
	tick(T, 16.0)
	check(near(T.ret_dur, 3000.0) and T.cam_phase == "home", "150 px from the hall: the drift takes 3 s (%.0f)" % T.ret_dur)
	var st2 := 0
	while T.ret_dur > 0.0 and st2 < 1000:
		tick(T, 50.0)
		st2 += 1
	check(st2 >= 59 and st2 <= 61, "… and it does (%d × 50 ms)" % st2)
	# ---- the intro on the beat ----
	T.beat.hold = true
	check(near(T.T_MENU[0], 1.065, 0.01) and near(T.T_MENU[1], 1.2276, 0.01) and near(T.T_MENU[2], 1.39, 0.01) and near(T.T_MENU[3], 1.553, 0.01), "the slabs land on 1.07 / 1.23 / 1.39 / 1.55")
	var lap0: int = T.beat.lap
	T.skip = false
	T.beat.lap = 0
	at(T, T.T_MENU[2] - 0.05)
	var u_before: float = T.mu(T.T_MENU[2] - T.SLAB_IN, T.SLAB_IN, "bk")
	at(T, T.T_MENU[2])
	var u_on: float = T.mu(T.T_MENU[2] - T.SLAB_IN, T.SLAB_IN, "bk")
	check(not near(u_before, 1.0, 0.005) and near(u_on, 1.0, 0.001), "the third slab is still moving 50 ms before its 16th and lands on it (%.2f → %.2f)" % [u_before, u_on])
	at(T, T.T_CURSOR)
	check(near(T.mu(T.T_CURSOR - T.CUR_IN, T.CUR_IN, "bk"), 1.0, 0.001), "the brush lands on 1.72")
	T.beat.lap = lap0
	# the logo never collides with the menu at 900×500 and 1000×460 (nor 1087×500)
	for sz in [Vector2(900, 500), Vector2(1000, 460), Vector2(1087, 500)]:
		var lr: Rect2 = T._logo_rect(sz)
		var s0r: Rect2 = T.slab_rect(sz, 0)
		check(lr.end.y < s0r.position.y - 2.0 and lr.size.x <= 0.36 * sz.x + 0.5, "%dx%d: the logo (bottom %.0f) clears the first slab (top %.0f)" % [sz.x, sz.y, lr.end.y, s0r.position.y])
	# ---- the slabs: press / release ----
	T.beat.hold = false
	at(T, 30.0)
	T.beat.hold = true
	T.outro = -1.0
	T.commit_k = -1
	T.confirm = false
	T.menu_in = true
	T.intro_done = true
	T.refresh_saves()
	check(T.has_save and T.auto_file == arena.save.path, "the autosave is there: 시작 will continue it, 불러오기 is live")
	for i in 3: await process_frame        # a draw: the slab rects
	check(T.item_rects.size() == T.items.size() and T.item_rects[0].size.x > 0.0, "the slabs' rects are laid out (%d)" % T.item_rects.size())
	var r0: Rect2 = T.item_rects[0]
	var r1: Rect2 = T.item_rects[1]
	check(near(r0.position.y + 4.0, 0.56 * vs.y, 1.0) and near(r1.position.y - r0.position.y, 0.088 * vs.y, 1.0), "the column from 0.56 H, 0.088 H apart")
	var outside := Vector2(vs.x * 0.8, vs.y * 0.2)
	mouse(T, outside, true)
	mouse(T, outside, false)
	check(not T.confirm and T.commit_k < 0 and T.outro < 0.0, "a stray tap after the intro does nothing")
	mouse(T, r1.get_center(), true)
	check(T.press_k == 1 and T.sel == 1 and T._slab_scale(1) <= 1.0, "a press on 불러오기: the squash, the selection follows")
	mouse(T, outside, false)
	check(T.press_k < 0 and T.commit_k < 0 and not T.confirm and T.outro < 0.0, "released outside it: nothing")
	mouse(T, r0.get_center(), true)
	mouse(T, r1.get_center(), false)
	check(T.commit_k < 0 and not T.confirm, "pressed on 시작, released on 불러오기: nothing")
	# the intro: a tap only finishes it
	T.intro_done = false
	T.menu_in = false
	T.skip = false
	mouse(T, r0.get_center(), true)
	mouse(T, r0.get_center(), false)
	check(T.intro_done and T.skip and T.commit_k < 0 and not T.confirm, "during the intro a tap on a slab only finishes the intro")
	# 시작 with the autosave: the feedback, then straight in (no card)
	mouse(T, r0.get_center(), true)
	mouse(T, r0.get_center(), false)
	check(T.commit_k == 0 and not T.confirm and T.load_file == arena.save.path and T.outro < 0.0, "시작 over the autosave: no card, the feedback runs, the autosave to load")
	T.commit_k = -1
	T.load_file = ""
	# 불러오기: the slot card — 자동 저장 + 슬롯 1·2·3, the empty ones greyed and passed over
	var slot2: String = arena.save.slot_path(2)
	check(slot2 == "user://save_test_2.json", "slot 2's file is save_test_2.json in a test run (%s)" % slot2)
	for k in range(1, 4): DirAccess.remove_absolute(arena.save.slot_path(k))
	arena.save.save(slot2)
	mouse(T, r1.get_center(), true)
	mouse(T, r1.get_center(), false)
	check(T.confirm and T.confirm_kind == "load" and T.rows.size() == 4 and T.commit_k < 0, "불러오기: the slot card with four rows, nothing loads yet")
	check(T.rows[0]["on"] and not T.rows[1]["on"] and T.rows[2]["on"] and not T.rows[3]["on"], "자동 저장 and 슬롯 2 can be picked, the empty 1 and 3 not")
	check(T.rows[0]["h"]["place"] == "본관 2층" and T.rows[2]["h"]["party"] == ["에스텔", "아이다"], "the rows carry the headers (%s / %s)" % [T.rows[0]["h"]["place"], T.rows[2]["h"]["party"]])
	check(T.confirm_sel == 0, "the first filled row picked")
	key(T, KEY_DOWN)
	check(T.confirm_sel == 2, "↓ passes over the empty 슬롯 1 (%d)" % T.confirm_sel)
	key(T, KEY_DOWN)
	check(T.confirm_sel == 0, "↓ passes over the empty 슬롯 3 and wraps (%d)" % T.confirm_sel)
	for i in 3: await process_frame        # a draw: the rows' rects
	check(T.confirm_rects.size() == 4 and T.close_rects.size() == 1, "the rows and 닫기 laid out")
	mouse(T, T.confirm_rects[1].get_center(), true)
	mouse(T, T.confirm_rects[1].get_center(), false)
	check(T.confirm and T.commit_k < 0, "a tap on the empty 슬롯 1 does nothing")
	mouse(T, T.close_rects[0].get_center(), true)
	mouse(T, T.close_rects[0].get_center(), false)
	check(not T.confirm, "닫기 closes the card")
	mouse(T, r1.get_center(), true)
	mouse(T, r1.get_center(), false)
	for i in 3: await process_frame
	mouse(T, T.confirm_rects[2].get_center(), true)
	mouse(T, outside, false)
	check(T.confirm and T.commit_k < 0, "pressed on 슬롯 2, released off it: nothing")
	mouse(T, T.confirm_rects[2].get_center(), true)
	mouse(T, T.confirm_rects[2].get_center(), false)
	check(not T.confirm and T.commit_k == 1 and T.load_file == slot2, "슬롯 2 picked: the card closes, the feedback on 불러오기, slot 2 to load")
	T.commit_k = -1
	T.load_file = ""
	DirAccess.remove_absolute(slot2)
	# 시작 with no save at all: the 새로운 이야기 card
	DirAccess.rename_absolute(arena.save.path, arena.save.path + ".bak")
	T.refresh_saves()
	check(not T.has_save and T.auto_file == "", "no save anywhere: 불러오기 greyed (NO SAVE)")
	mouse(T, r1.get_center(), true)
	mouse(T, r1.get_center(), false)
	check(not T.confirm and T.commit_k < 0, "불러오기 with nothing to load: nothing opens")
	mouse(T, r0.get_center(), true)
	mouse(T, r0.get_center(), false)
	check(T.confirm and T.confirm_kind == "fresh" and T.confirm_sel == 0 and T.commit_k < 0, "시작 with no save: the 새로운 이야기를 시작합니다 card, 시작 picked")
	for i in 3: await process_frame        # a draw: the card's buttons
	check(T.confirm_rects.size() == 2, "the card's two buttons")
	mouse(T, T.confirm_rects[1].get_center(), true)
	mouse(T, T.confirm_rects[1].get_center(), false)
	check(not T.confirm and T.commit_k < 0, "취소: the card closes, nothing starts")
	T.sel = 0
	key(T, KEY_ENTER)
	check(T.confirm and T.confirm_kind == "fresh", "Enter on 시작: the same card")
	key(T, KEY_ENTER)
	check(not T.confirm and T.commit_k == 0 and T.load_file == "", "Enter on 시작 in it: the feedback, a new game to start")
	T.commit_k = -1
	DirAccess.rename_absolute(arena.save.path + ".bak", arena.save.path)
	T.refresh_saves()
	# the pick's feedback: the slab slams, a burst, the others drop out 60 ms apart, the outro 450 ms on
	T.beat.hold = true
	T.sel = 0
	key(T, KEY_ENTER)
	check(T.commit_k == 0 and T.outro < 0.0 and T.release_k == 0, "Enter on 시작 (autosave): the feedback, the same squash and spring as a tap's")
	check(T._slab_drop(1) == 0.0 and T._slab_drop(3) == 0.0, "the others have not dropped yet")
	T.clock += 100.0
	check(T._slab_scale(0) < 1.0 and T._slab_drop(1) > 0.0 and T._slab_drop(2) == 0.0 and T._slab_drop(0) == 0.0, "100 ms: the picked slab in its slam, the first other dropping, the next not yet")
	T.clock += 60.0
	check(T._slab_drop(2) > 0.0 and T._slab_drop(3) == 0.0, "160 ms: the second other dropping, 60 ms after the first")
	T.clock += 300.0
	check(T._slab_drop(3) > 0.0, "the last other dropping")
	mouse(T, r1.get_center(), true)
	mouse(T, r1.get_center(), false)
	check(T.commit_k == 0 and not T.confirm, "input is ignored while the feedback runs")
	T.commit_t = T.clock - 460.0
	T._process(0.016)
	check(T.outro >= 0.0 and T.burst_t >= 0.0, "450 ms after the pick: the outro (and the burst) begin")
	T.outro = -1.0
	T.commit_k = -1
	T.burst_t = -1.0
	T.handed = false
	# ---- the hand-off: the autosave (made in the hall) loads — the hall back, the hero back, her party hers ----
	for i in 20:
		B._process(0.05)
		await process_frame
	check(B.tgain >= 1.0, "under the title: the title track at full")
	T.beat.hold = false
	T.load_file = arena.save.path
	T._go()
	for i in 3: await process_frame
	check(not T.active and not arena.title_mode, "the hand-off: the title off")
	check(arena.level_kind() == "hall" and arena.level.fl == 1 and P.visible and (P.position - hall_at).length() < 2.0, "시작 restored the hall, floor 1, where she stood (%s)" % arena.level_kind())
	check(arena.title_back.is_empty() and arena.cam_override == null and not folk.title_mode and folk.folk() == ["luce"], "the camera and the townsfolk are the game's again, the party hers (%s)" % [folk.folk()])
	check(P.party == ["estelle", "aida"] and P.who == "estelle" and arena.save.loaded_from == arena.save.path, "the party kept (%s)" % [P.party])
	for i in 6:
		B._process(0.05)
		await process_frame
	check(B.wanted() and not B.wanted_title() and B.ap.playing and B.tgain < 1.0, "the town starts while the title fades (tgain %.2f)" % B.tgain)
	# the title again over the hall: the town, the hall remembered; leaving without a restore keeps the town
	arena.enter_title_mode()
	check(arena.title_mode and arena.level_kind() == "town" and arena.title_back.get("kind", "") == "hall", "the title again: the town, the hall remembered")
	arena.leave_title_mode(false)
	check(not arena.title_mode and arena.level_kind() == "town" and arena.title_back.is_empty(), "leaving without the restore: the town stays, the hall forgotten")
	DirAccess.remove_absolute(arena.save.path)
	# ---- a title with no arena and no audio runs the whole timeline ----
	var bare = load("res://scripts/title.gd").new()
	bare.arena = null
	bare.ui_root = null
	root.add_child(bare)
	bare.go_live()
	check(bare.live, "no arena: live")
	var tt := 0.0
	var seen := {}
	while tt < 165.0:
		bare.beat.set_time(tt)
		bare._tick()
		bare._camera(16.0)
		seen[bare.sec] = true
		await process_frame
		tt += 0.25
	check(seen.size() == 5, "no arena, no audio: every section drew (%s)" % [seen.keys()])
	bare.beat.hold = false
	bare.beat.set_time(164.4)
	bare.beat.step(0.1)
	bare._tick()
	await process_frame
	check(bare.beat.lap == 1 and bare.menu_in and not bare.wedge.is_empty(), "no arena: the loop wrapped behind the wedge, the menu stays")
	bare.commit_k = 1
	bare.commit_t = bare.clock
	for i in 3: await process_frame
	bare.burst_t = bare.clock
	bare.outro = 0.0
	for i in 3: await process_frame
	check(bare.outro > 0.0, "no arena: the feedback, the burst and the outro draw")
	bare.queue_free()
	print("FAILS: %d" % fails)
	quit()
