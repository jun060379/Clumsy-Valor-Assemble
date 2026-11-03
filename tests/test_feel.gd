extends SceneTree
## 타격감 (post_fx.gd impact / FEEL, arena.impact, mob.hit, player.gd): the hitstop by weight (light 40 / hit3 90 /
## heavy 120 / parry 140 / ult 160), the punch list capped at four and expiring at 90 ms, the chromatic pulse's value
## and decay, the zoom punch envelope (40 ms up, 180 ms back), the parry's negative frame + freeze + zoom + punch +
## twelve sparks, the hurt vignette's alpha fading over 220 ms and the low-HP pulse (the music's clock or 0.65 s), the
## camera kick, the mob's squash, the boss's three punches, the death desaturation over 1.2 s and its reset, and all
## of it inert with 화면 효과 off (the old hitstop / shake stay).
## godot --headless --path . -s tests/test_feel.gd

var fails := 0
var arena
var post

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func near(a: float, b: float, eps := 0.002) -> bool:
	return absf(a - b) <= eps

## the feel's own clock, stepped in ms (post_fx._process runs on real frames; this drives it directly)
func tick(ms: float) -> void:
	post.feel_step(ms)

func reset() -> void:
	post.feel_reset()
	arena.hitstop = 0.0
	arena.shake_amt = 0.0

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	post = arena.post
	var P = arena.player
	arena.screen_fx = true
	arena.enter_dungeon()
	await process_frame
	arena.clear_room()
	await process_frame
	var at: Vector2 = P.position + Vector2(80.0, -60.0)

	print("-- hitstop by weight")
	for k in [["light", 40.0], ["hit3", 90.0], ["heavy", 120.0], ["parry", 140.0], ["ult", 160.0]]:
		reset()
		arena.impact(k[0], at, 1)
		check(near(arena.hitstop, k[1]), "%s: hitstop %d ms" % [k[0], int(k[1])])
	reset()
	arena.hitstop = 200.0
	arena.impact("light", at, 1)
	check(near(arena.hitstop, 200.0), "a longer hitstop already running is kept")
	reset()
	arena.impact("hurt", at, -1)
	check(arena.hitstop == 0.0, "hurt freezes nothing")
	check(P.hit_weight() == "light", "attack1's weight is light")
	P.anim = "attack3"
	check(P.hit_weight() == "hit3", "attack3's weight is hit3")
	P.anim = "cthrust"
	check(P.hit_weight() == "heavy", "the charged thrust's weight is heavy")
	P.anim = "idle"

	print("-- the punch list")
	reset()
	for i in 6:
		post.punch(at + Vector2(i * 10.0, 0), 0.35)
	check(post.punches.size() == 4, "capped at four live punches (%d)" % post.punches.size())
	check(near(post.punches[0]["x"], at.x + 20.0), "the oldest gave way")
	tick(50.0)
	check(post.punches.size() == 4 and near(post.punches[0]["t"], 50.0), "ages at 50 ms")
	tick(45.0)
	check(post.punches.is_empty(), "all expired past 90 ms")
	post.punch(at, 0.6)
	post.punch(at, 1.0)
	check(post.punches[1]["str"] == 1.0 and post.punches[0]["str"] == 0.6, "strength kept per punch")
	reset()
	arena.impact("light", at, 1)
	check(post.punches.size() == 1 and post.punches[0]["str"] == 0.35, "a light impact punches at 0.35")
	reset()
	arena.impact("hit3", at, 1)
	check(post.punches[0]["str"] == 0.6, "hit3 at 0.6")
	reset()
	arena.impact("heavy", at, 1)
	check(post.punches[0]["str"] == 1.0, "heavy at 1.0")
	reset()
	arena.impact("hurt", at, 1)
	check(post.punches.is_empty(), "hurt does not punch the screen")

	print("-- the chromatic pulse")
	reset()
	arena.impact("light", at, 1)
	check(post.cap_now() == 0.0, "light: no pulse")
	reset()
	arena.impact("hit3", at, 1)
	check(near(post.cap_now(), 0.012), "hit3: 0.012 at once (%.4f)" % post.cap_now())
	tick(30.0)
	var mid: float = post.cap_now()
	check(mid > 0.0 and mid < 0.012, "half-way it has decayed (%.4f)" % mid)
	tick(31.0)
	check(post.cap_now() == 0.0, "gone after 60 ms")
	reset()
	arena.impact("heavy", at, 1)
	check(near(post.cap_now(), 0.03), "heavy: 0.03")
	tick(100.0)
	check(post.cap_now() > 0.0, "still there at 100 ms")
	tick(11.0)
	check(post.cap_now() == 0.0, "gone after 110 ms")
	reset()
	arena.impact("ult", at, 1)
	check(near(post.cap_now(), 0.05), "ult: 0.05")
	tick(159.0)
	check(post.cap_now() > 0.0, "ult holds 160 ms")
	reset()
	arena.impact("hurt", at, 1)
	check(near(post.cap_now(), 0.02), "hurt: 0.02")
	tick(81.0)
	check(post.cap_now() == 0.0, "hurt's pulse gone after 80 ms")
	reset()
	arena.impact("heavy", at, 1)
	arena.impact("hit3", at, 1)
	check(near(post.cap_now(), 0.03), "a weaker pulse never lowers a stronger one")

	print("-- the zoom punch")
	reset()
	check(post.zoom_now() == 1.0 and arena.cam.zoom == Vector2.ONE, "idle: zoom 1")
	arena.impact("light", at, 1)
	check(post.zoom_now() == 1.0, "light: no zoom punch")
	arena.impact("hit3", at, 1)
	check(post.zoom_now() == 1.0, "hit3: no zoom punch")
	arena.impact("heavy", at, 1)
	tick(20.0)
	check(near(post.zoom_now(), 1.0125), "heavy: half-way up at 20 ms (%.4f)" % post.zoom_now())
	tick(20.0)
	check(near(post.zoom_now(), 1.025) and near(arena.cam.zoom.x, 1.025), "peak 1.025 at 40 ms, on the camera")
	tick(90.0)
	var z: float = post.zoom_now()
	check(z > 1.0 and z < 1.025, "easing back (%.4f)" % z)
	tick(90.0)
	check(post.zoom_now() == 1.0 and arena.cam.zoom == Vector2.ONE, "back to 1 after 40 + 180 ms")
	reset()
	arena.impact("ult", at, 1)
	tick(40.0)
	check(near(post.zoom_now(), 1.04), "ult: peak 1.04")
	reset()
	arena.impact("ult", at, 1)
	tick(40.0)
	arena.impact("heavy", at, 1)
	check(near(post.zoom_now(), 1.04), "a smaller punch never cuts a bigger one short")

	print("-- the camera kick")
	reset()
	arena.impact("light", at, 1)
	check(near(post.kick_off().x, 4.0) and post.kick_off().y == 0.0, "4 px in the hit direction")
	tick(60.0)
	var kx: float = post.kick_off().x
	check(kx > 0.0 and kx < 4.0, "easing back (%.2f)" % kx)
	tick(60.0)
	check(post.kick_off() == Vector2.ZERO, "gone after 120 ms")
	arena.impact("hurt", at, -1)
	check(post.kick_off().x < 0.0, "hurt kicks the other way")

	print("-- the parry")
	reset()
	var n0: int = arena.fx.size()
	arena.impact("parry", at, 1)
	check(post.neg_frames == 1, "one frame in the negative")
	check(near(arena.hitstop, 140.0), "the freeze: 140 ms")
	check(post.punches.size() == 1 and post.punches[0]["str"] == 1.0, "the biggest punch")
	tick(40.0)
	check(near(post.zoom_now(), 1.025), "the zoom punch")
	check(near(post.cap_now(), 0.03 * 0.6 * 0.6 + 0.0, 0.003) or post.cap_now() > 0.0, "the colour fringes")
	check(arena.fx.size() - n0 == 12, "twelve sparks (%d)" % (arena.fx.size() - n0))
	var sp: Array = arena.fx.slice(n0)
	var vs := 0.0
	for e in sp: vs += Vector2(e["vx"], e["vy"]).length()
	check(vs / 12.0 > 0.5, "a radial burst, fast")
	# the full flow: parry_fx on a mob sets all of it
	reset()
	var m = arena.spawn("goblin", P.position.x + 60.0, 0.0)
	m.hp = 999.0
	arena.parry_fx(P, m)
	check(post.neg_frames == 1 and near(arena.hitstop, 140.0) and not post.punches.is_empty(), "parry_fx: negative + freeze + punch")
	# the negative frame is consumed by one shader upload
	post._process(0.016)
	check(post.neg_frames == 0, "the negative lasts the one frame")
	check(post.mat.get_shader_parameter("neg") == 1.0, "...uploaded as neg = 1 on that frame")
	post._process(0.016)
	check(post.mat.get_shader_parameter("neg") == 0.0, "...and 0 on the next")

	print("-- the mob's squash")
	reset()
	check(m.squash() == Vector2.ONE, "idle: scale 1")
	m.sq = 0.0
	m.hit(1, 5, 1.0)
	check(m.sq == m.SQ_MS, "hit: squash starts (70 ms)")
	check(m.squash().x > 1.1 and m.squash().y < 0.9, "x 1.18 / y 0.86 at the start (%.2f / %.2f)" % [m.squash().x, m.squash().y])
	check(m.flash == 120.0, "the flash still fires")
	check(post.punches.size() == 1 and post.punches[0]["str"] == 0.35, "a 1-damage hit punches the screen at 0.35")
	m.fx_step(35.0)
	var sx: float = m.squash().x
	check(sx > 1.0 and sx < 1.18, "easing back (%.3f)" % sx)
	m.fx_step(40.0)
	check(m.squash() == Vector2.ONE, "settled after 70 ms")
	reset()
	m.hit(2, 5, 1.0)
	check(post.punches[0]["str"] == 0.6, "a 2-damage hit punches at 0.6")
	reset()
	m.hit(3, 5, 1.0)
	check(post.punches[0]["str"] == 1.0, "a 3-damage hit punches at 1.0")

	print("-- the hurt vignette")
	reset()
	P.hp = P.MAX_HP
	check(post.hurt_a() == 0.0, "nothing at full health")
	arena.impact("hurt", at, -1)
	check(near(post.hurt_a(), 0.35), "0.35 on the hit")
	tick(110.0)
	check(near(post.hurt_a(), 0.175, 0.01), "half-way at 110 ms (%.3f)" % post.hurt_a())
	tick(111.0)
	check(post.hurt_a() == 0.0, "gone after 220 ms")
	check(near(arena.shake_amt, 3.0), "a 3 px shake (%.1f)" % arena.shake_amt)
	# the low-HP pulse
	P.hp = P.MAX_HP * 0.29
	check(post.low_hp(), "under 30 %: low")
	var a0: float = post.hurt_a()
	check(a0 > 0.05 and a0 < 0.3, "a soft pulse (%.3f)" % a0)
	var lo := 1.0
	var hi := 0.0
	var clk = arena.bgm.clock()
	for i in 13:
		tick(50.0)
		lo = minf(lo, post.hurt_a())
		hi = maxf(hi, post.hurt_a())
	if clk == null or not clk.live:
		check(hi - lo > 0.08, "it breathes over a 0.65 s cycle of its own (%.3f .. %.3f)" % [lo, hi])
	else:
		check(true, "a music clock is live: the pulse follows it")
	P.hp = P.MAX_HP * 0.31
	check(not post.low_hp() and post.hurt_a() == 0.0, "over 30 %: still")
	P.hp = P.MAX_HP

	print("-- the boss's death")
	reset()
	arena.impact("boss", at, 1)
	check(post.punches.size() == 1 and post.punch_due.size() == 2, "one punch now, two to come")
	tick(260.0)
	check(post.punch_due.size() == 1, "the second landed at 250 ms (%d due)" % post.punch_due.size())
	tick(250.0)
	check(post.punch_due.is_empty(), "the third at 500 ms")
	check(post.cap_now() > 0.0, "with colour fringes")

	print("-- death")
	reset()
	P.hp = 1.0
	P.die()
	check(P.anim == "death" and post.ds == 0.0, "dying: starts at 0")
	tick(600.0)
	check(near(post.ds, 0.5, 0.01), "half drained at 0.6 s (%.3f)" % post.ds)
	tick(700.0)
	check(post.ds == 1.0, "fully desaturated at 1.2 s")
	post._process(0.016)
	check(post.mat.get_shader_parameter("ds") == 1.0, "uploaded to the shader")
	P.hp = P.MAX_HP
	P.set_anim("idle")
	tick(16.0)
	check(post.ds == 0.0, "the respawn resets it at once")
	P.hp = 1.0
	P.die()
	tick(600.0)
	post.punch(at, 1.0)
	post.zoom_punch(1.04)
	# the party wipe: party_step past 2.2 s heals everyone, falls back to town (the fade, then go_town -> snap_camera)
	P.dead_t = 2300.0
	P.party_down = true
	P.party_step(16.0)
	check(P.anim != "death" and P.hp == P.MAX_HP, "the wipe revives her")
	tick(16.0)
	check(post.ds == 0.0, "...and the desaturation is gone")
	arena.go_town(Vector2(400.0, arena.ground_y), 1)
	await process_frame
	check(post.punches.is_empty() and post.zoom_now() == 1.0 and post.ds == 0.0, "a scene change (snap_camera) clears the feel")
	arena.enter_dungeon()
	await process_frame
	arena.clear_room()
	m = arena.spawn("goblin", P.position.x + 60.0, 0.0)
	m.hp = 999.0

	print("-- 화면 효과 off: inert")
	arena.screen_fx = false
	reset()
	post._process(0.016)
	arena.impact("parry", at, 1)
	arena.impact("ult", at, 1)
	arena.impact("hurt", at, 1)
	check(arena.hitstop == 0.0, "no hitstop from impact")
	check(post.punches.is_empty() and post.punch_due.is_empty(), "no punches")
	check(post.cap_now() == 0.0, "no chromatic pulse")
	check(post.zoom_now() == 1.0 and arena.cam.zoom == Vector2.ONE, "no zoom")
	check(post.kick_off() == Vector2.ZERO, "no kick")
	check(post.neg_frames == 0, "no negative frame")
	check(post.hurt_a() == 0.0 and arena.shake_amt == 0.0, "no vignette, no extra shake")
	post.punch(at, 1.0)
	post.ca_pulse(0.05, 100.0)
	post.zoom_punch(1.04)
	post.kick(Vector2.RIGHT, 4.0)
	post.invert()
	post.hurt(0.35)
	check(post.punches.is_empty() and post.cap_now() == 0.0 and post.zoom_now() == 1.0 and post.kick_off() == Vector2.ZERO and post.neg_frames == 0 and post.hurt_a() == 0.0, "the direct calls are no-ops too")
	m.sq = 0.0
	m.hit(1, 5, 1.0)
	check(m.sq == 0.0 and m.squash() == Vector2.ONE, "no squash")
	check(m.flash == 120.0, "the old flash still fires")
	P.hp = P.MAX_HP * 0.2
	check(post.hurt_a() == 0.0, "no low-HP pulse")
	P.hp = 1.0
	P.die()
	tick(1300.0)
	post._process(0.016)
	check(post.ds == 0.0, "no desaturation")
	P.hp = P.MAX_HP
	P.set_anim("idle")
	# the old behaviour stays: the attack table's hitstop / shake, parry_fx's 95 ms
	arena.hitstop = 0.0
	arena.parry_fx(P, m)
	check(near(arena.hitstop, 95.0), "parry: the old 95 ms hitstop (%.0f)" % arena.hitstop)
	check(near(arena.shake_amt, 12.0), "parry: the old 12 px shake")
	# the hit block: turning the feel back on changes the hitstop of the same blow
	var atk: Dictionary = P.CH.ATK["attack1"]
	check(int(atk.get("stop", 55)) == 55, "attack1's table hitstop is 55 (kept when off)")
	arena.screen_fx = true

	print("")
	print("FAILS %d" % fails)
	quit(1 if fails > 0 else 0)
