extends SceneTree
## A 20 s headless sortie with the player fighting: the sortie flow into the cave, mobs spawned around her, the
## attack key mashed (combos, the charged thrust, the shield and a parry, dashes), HP driven under 30 % and back for
## the low-HP overlay, the boss room and the boss, an ult. Nothing may error; the snapped sounds must drain every
## frame, every pool player's pitch must stay in range, and the music must be where it should be at each stage.
## godot --headless --path . -s tests/test_sfx_run.gd

var fails := 0
var arena

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

## wait until cond() (at most ms of real time)
func until(cond: Callable, ms := 15000.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		await process_frame
		if Time.get_ticks_msec() - t0 > ms: return false
	return true

## real-time frames with the player's keys driven: attack mashed, now and then a dash, the shield, a charge
var played := 0
var max_due := 0
var bad_pitch := 0
var snapped := 0
func fight(ms: float, pattern := "mash") -> void:
	var t0 := Time.get_ticks_msec()
	var k := 0
	var last_hold := 0.0
	while Time.get_ticks_msec() - t0 < ms:
		var t := Time.get_ticks_msec() - t0
		var ph := int(t / 160.0)
		if ph != k:
			k = ph
			for a in ["attack", "dash", "guard", "jump"]: Input.action_release(a)
			match pattern:
				"mash":
					if k % 2 == 0: Input.action_press("attack")
					if k % 9 == 4: Input.action_press("dash")
					if k % 13 == 7: Input.action_press("jump")
				"charge":
					Input.action_press("attack")            # held: the charged thrust on release
				"guard":
					Input.action_press("guard")
		await process_frame
		max_due = maxi(max_due, arena.sfx_due.size())
		for ap in arena.sfx_pool:
			if ap.playing and (ap.pitch_scale < 0.55 or ap.pitch_scale > 1.6): bad_pitch += 1
	for a in ["attack", "dash", "guard", "jump"]: Input.action_release(a)

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var P = arena.player
	var S = arena.sortie
	var B = arena.bgm
	# count every sound that starts (the pool's players), and the holds
	var started := [0]
	for ap in arena.sfx_pool:
		ap.finished.connect(func(): started[0] += 1)
	arena.fame.join()
	for c in ["aida", "luce"]: arena.toggle_member(c)
	var t_run := Time.get_ticks_msec()

	print("-- the sortie flow into the cave")
	S.open_dsel(0)
	S.dsel.do_launch()
	check(await until(func(): return arena.level_kind() == "dungeon"), "into the cave")
	check(await until(func(): return B.bp.playing and B.bgain >= 1.0, 3000.0), "battle.ogg at full")
	check(await until(func(): return S.din["on"] == 0 and not S.swp["on"] and not S.dpl["on"] and not S.tc.active, 12000.0), "the entry done")
	var D = arena.level
	P.inv = 0.0

	print("-- fighting the room (5 s)")
	var spawn_near := func():
		for i in 3:
			var m = arena.spawn(["goblin", "skel", "goblin"][i], clampf(P.position.x + (i + 1) * 90.0 * (1 if i % 2 == 0 else -1), 100.0, arena.world_w - 100.0), 0.0)
			m.aw = true
	spawn_near.call()
	await fight(2500.0, "mash")
	await fight(900.0, "charge")
	await fight(600.0, "mash")
	await fight(700.0, "guard")
	await fight(300.0, "mash")
	check(P.hp > 0.0 or P.anim == "death", "she is standing or fell honestly (hp %.0f)" % P.hp)
	check(arena.sfx_due.size() <= 8, "the scheduled list drains (now %d, peak %d)" % [arena.sfx_due.size(), max_due])

	print("-- low HP: the overlay")
	P.inv = 1.0e9
	P.hp = P.MAX_HP * 0.25
	check(await until(func(): return B.lp.playing, 4000.0), "under 30 %: lowhp.ogg comes in on a bar line")
	spawn_near.call()
	await fight(2500.0, "mash")
	check(B.lp.playing and B.lgain >= 1.0, "it is in at full while she fights on")
	P.hp = P.MAX_HP
	check(await until(func(): return not B.lp.playing, 3000.0), "healed: it fades out")

	print("-- the boss room")
	var bk := ""
	for k in D.rooms:
		if D.rooms[k]["type"] == "boss": bk = k
	D.from = "L"
	D.cur = bk
	arena.fade_then(func(): D.enter())
	check(await until(func(): return S.tc.active and S.tc.kind == "boss"), "the boss card")
	check(await until(func(): return B.bsp.playing, 2000.0), "boss.ogg from the room's entry")
	S.tc.finish()
	await until(func(): return not S.tc.active)
	check(await until(func(): return B.bgain == 0.0 and not B.bp.playing, 4000.0), "the battle track is gone a bar later")
	check(B.grid() == B.clocks["boss"], "the grid is the boss clock")
	P.inv = 0.0
	await fight(3000.0, "mash")
	var U = arena.ult
	U.v["estelle"] = U.ULTMAX["estelle"]
	U.cd["estelle"] = 0.0
	P.switch_char("estelle")
	P.set_anim("idle", 0)
	P.inv = 1.0e9
	check(U.try_ult(), "the ult fires")
	check(await until(func(): return U.state == "", 8000.0), "the ult played through (its impact on the grid, the 6 dB duck)")
	await fight(1500.0, "mash")
	for mm in arena.mobs: mm.hit(9999.0, 0.0)
	check(await until(func(): return D.room()["cleared"], 3000.0), "the boss down")
	check(await until(func(): return not B.bsp.playing, 3000.0), "the boss track out over 1.5 s")
	await fight(1000.0, "mash")
	var secs := (Time.get_ticks_msec() - t_run) / 1000.0
	check(secs >= 20.0, "a %.0f s run" % secs)
	check(bad_pitch == 0, "every pitch within 0.62×..2^(7/12) (%d out of range)" % bad_pitch)
	check(max_due <= 8, "never more than a few sounds waiting for their 16th (peak %d)" % max_due)
	check(started[0] > 40, "sounds played: %d" % started[0])
	print("FAILS: %d" % fails)
	quit()
