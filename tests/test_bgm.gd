extends SceneTree
## Music (bgm.gd): town.ogg loads and loops, plays in town, carries on into the guild hall without restarting, fades
## out in the dungeon, comes back in town where it left off; the 배경음 setting mutes it. The title track (title.ogg)
## loads and loops on its own player; tests/test_title.gd covers the title → town cross-fade. The dungeon: battle.ogg
## from 0 on entry (never restarted room to room), boss.ogg from 0 in the boss room while the battle fades over a bar,
## the boss track out over 1.5 s when the boss is down, the low-HP overlay with its hysteresis (0.29 on, 0.35 still
## on, 0.41 off) started on a bar line and ducking the track 6 dB, the impact duck's envelope, the loop offsets in the
## .import files, the town resuming where it paused, the training ground silent.
var fails := 0

func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", what)
	else:
		print("ok ", what)

func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps

func run(arena, s: float) -> void:
	for i in int(s / 0.05):
		arena.bgm._process(0.05)
		await process_frame

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var B = arena.bgm
	var st = load("res://assets/bgm/town.ogg")
	ok(st is AudioStreamOggVorbis, "town.ogg is an AudioStreamOggVorbis")
	ok(st.loop, "town.ogg loops (import loop=true)")
	ok(absf(st.get_length() - 75.0) < 0.2, "75 s long (%.2f)" % st.get_length())
	ok(B.ap.stream == st and B.ap.stream.loop, "the player has the looping stream")
	var bi := AudioServer.get_bus_index(&"BGM")
	ok(bi > 0 and AudioServer.get_bus_send(bi) == &"Master", "BGM bus into Master")
	ok(AudioServer.get_bus_volume_db(bi) <= -0.5, "BGM bus sits a touch under the sfx (%.1f dB; both tracks are at -14 LUFS)" % AudioServer.get_bus_volume_db(bi))
	var tt = load("res://assets/bgm/title.ogg")
	ok(tt is AudioStreamOggVorbis and tt.loop and absf(tt.get_length() - 164.44) < 0.2, "title.ogg loops, 164.44 s long (%.2f)" % tt.get_length())
	ok(B.tap.stream == tt and B.tap.bus == &"BGM" and not B.tap.playing, "the title player holds it on the BGM bus, silent in a test run (the title is off)")
	ok(B.ap.bus == &"BGM", "player on the BGM bus (not the slow bus)")
	# the dungeon tracks: their files, lengths and loop points (the streams and the .import files)
	for tr in [["battle", 105.79, 4.99, B.bp], ["boss", 174.35, 13.49, B.bsp], ["lowhp", 60.24, 20.18, B.lp]]:
		var s2 = load("res://assets/bgm/%s.ogg" % tr[0])
		ok(s2 is AudioStreamOggVorbis and absf(s2.get_length() - tr[1]) < 0.2, "%s.ogg: an ogg of %.2f s (%.2f)" % [tr[0], tr[1], s2.get_length()])
		ok(s2.loop and near(s2.loop_offset, tr[2], 0.001), "%s.ogg loops back to %.2f (%.2f)" % [tr[0], tr[2], s2.loop_offset])
		ok(tr[3].stream == s2 and tr[3].bus == &"BGM" and not tr[3].playing, "%s: its player on the BGM bus, silent in town" % tr[0])
		var imp := FileAccess.get_file_as_string("res://assets/bgm/%s.ogg.import" % tr[0])
		ok(imp.contains("loop=true") and imp.contains("loop_offset=%s" % str(tr[2])), "%s.ogg.import: loop=true, loop_offset=%s" % [tr[0], str(tr[2])])
	ok(B.clocks.size() == 4 and B.clocks["battle"].beats.size() > 100 and not B.clocks["battle"].live, "a clock per track (beat.gd), the dungeon ones on their beat maps, idle")
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await run(arena, 1.2)
	ok(arena.level_kind() == "town" and B.ap.playing and B.gain >= 1.0, "playing at full in town (gain %.2f)" % B.gain)
	ok(B.audible() == "town" and B.clock() == B.clocks["town"] and B.clocks["town"].live and B.grid() == null, "the audible clock is the town's; no dungeon grid in town")
	# town -> hall: no restart, no dip
	var p0: float = B.ap.get_playback_position()
	arena.go_hall(0, Vector2(1800.0, arena.ground_y), 1)
	await run(arena, 0.3)
	ok(arena.level_kind() == "hall" and B.ap.playing and B.gain >= 1.0, "still playing at full in the hall")
	ok(B.ap.get_playback_position() + 0.05 >= p0, "the hall did not restart it (%.2f -> %.2f)" % [p0, B.ap.get_playback_position()])
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await run(arena, 0.3)
	# into the dungeon: the town fades over ~0.8 s, then stops; the battle track starts from 0
	var P = arena.player
	P.inv = 1.0e9                     # the cave's mobs must not touch her HP here
	arena.enter_dungeon()
	await run(arena, 0.3)
	ok(B.gain > 0.0 and B.gain < 1.0, "fading in the dungeon (gain %.2f)" % B.gain)
	ok(B.wanted_battle() and B.bp.playing and B.bgain >= 1.0, "battle.ogg at full right away (bgain %.2f)" % B.bgain)
	# (headless, the Dummy driver still mixes in real time: the clock follows the stream, not the test's 0.05 s steps,
	# so only "from 0, not from somewhere in the track" is checked)
	ok(B.clocks["battle"].live and B.clocks["battle"].music_t < 3.0 and B.clocks["battle"].music_t > 0.0, "its clock started from 0 (%.2f s)" % B.clocks["battle"].music_t)
	ok(B.audible() == "battle" and B.grid() == B.clocks["battle"] and B.clock() == B.clocks["battle"], "the dungeon grid is the battle clock")
	ok(B.next_sixteenth() >= 0.0 and B.next_sixteenth() <= B.clocks["battle"].sixteenth_len() + 0.001, "next_sixteenth: within one 16th (%.3f)" % B.next_sixteenth())
	await run(arena, 0.8)
	ok(B.gain == 0.0 and not B.ap.playing, "the town is silent in the dungeon")
	var at: float = B.paused_at
	ok(at >= 0.0, "kept its place (%.2f s)" % at)
	# room to room: the battle track never restarts
	var D = arena.level
	var fk := ""
	var bk := ""
	for k in D.rooms:
		if D.rooms[k]["type"] == "fight" and fk == "": fk = k
		if D.rooms[k]["type"] == "boss": bk = k
	var mt0: float = B.clocks["battle"].music_t
	D.from = "L"
	D.cur = fk
	D.enter()
	await run(arena, 0.3)
	ok(arena.level_kind() == "dungeon" and B.bp.playing and B.bgain >= 1.0 and B.clocks["battle"].music_t > mt0, "the next room keeps it playing (%.2f -> %.2f s)" % [mt0, B.clocks["battle"].music_t])
	# the boss room: boss.ogg from 0, the battle out over one bar (2.508 s)
	D.from = "L"
	D.cur = bk
	D.enter()
	await run(arena, 0.3)
	ok(B.boss_fight() and B.wanted_boss() and not B.wanted_battle(), "the boss room: the boss track is wanted, the battle no more")
	ok(B.bsp.playing and B.bsgain >= 1.0 and B.clocks["boss"].live and B.clocks["boss"].music_t < 3.0, "boss.ogg from 0 (bsgain %.2f, %.2f s)" % [B.bsgain, B.clocks["boss"].music_t])
	ok(B.bp.playing and B.bgain < 1.0 and B.bgain > 0.75, "the battle track is fading over a bar (bgain %.2f after 0.3 s)" % B.bgain)
	ok(B.audible() == "boss" and B.grid() == B.clocks["boss"], "the grid is the boss clock from here")
	await run(arena, 1.0)
	ok(B.bgain > 0.35 and B.bgain < 0.6, "1.3 s in: about half way (bgain %.2f)" % B.bgain)
	await run(arena, 1.5)
	ok(B.bgain == 0.0 and not B.bp.playing and not B.clocks["battle"].live, "2.8 s in: the battle track is out and stopped")
	ok(B.bsp.playing and B.bsgain >= 1.0, "the boss track plays on")
	# the low-HP overlay with its hysteresis
	P.hp = P.MAX_HP * 0.29
	await run(arena, 0.1)
	ok(B.low and (B.low_due >= 0.0 or B.lp.playing), "HP 0.29: the overlay is wanted, scheduled onto the next bar line (in %.2f s)" % B.low_due)
	ok(B.low_due <= B.clocks["boss"].bar_len() + 0.2 and B.low_pos == 0.0, "within a bar, from 0 the first time")
	await run(arena, 3.5)
	ok(B.lp.playing and B.lgain >= 1.0 and B.clocks["lowhp"].live, "it is in at full (lgain %.2f)" % B.lgain)
	ok(near(B.bsp.volume_db, B._db(1.0) - 6.0, 0.05), "the boss track is ducked 6 dB under it (%.1f dB)" % B.bsp.volume_db)
	ok(near(B.lp.volume_db, B._db(1.0), 0.05), "the overlay itself at full")
	P.hp = P.MAX_HP * 0.35
	await run(arena, 0.5)
	ok(B.low and B.lp.playing and B.lgain >= 1.0, "HP 0.35: still in (hysteresis up to 0.40)")
	P.hp = P.MAX_HP * 0.41
	await run(arena, 0.5)
	ok(not B.low and B.lp.playing and B.lgain < 0.7 and B.lgain > 0.3, "HP 0.41: fading out over 1 s (lgain %.2f after 0.5 s)" % B.lgain)
	ok(near(B.bsp.volume_db, B._db(1.0) - 6.0 * B.lgain, 0.05), "the duck lets go with it (%.1f dB)" % B.bsp.volume_db)
	await run(arena, 0.8)
	ok(not B.lp.playing and B.lgain == 0.0 and not B.clocks["lowhp"].live and near(B.bsp.volume_db, B._db(1.0), 0.05), "out and stopped, the boss track back at full")
	P.hp = P.MAX_HP * 0.2
	await run(arena, 0.1)
	ok(B.low and B.low_due >= 0.0 and near(B.low_pos, 20.18, 0.001), "HP 0.2 again: scheduled, this time from the loop point (20.18), its bar 8")
	await run(arena, 3.5)
	ok(B.lp.playing and B.lgain >= 1.0 and B.clocks["lowhp"].music_t >= 20.0, "in again from 20.18 (clock %.2f)" % B.clocks["lowhp"].music_t)
	P.hp = P.MAX_HP
	await run(arena, 1.6)
	ok(not B.lp.playing and B.lgain == 0.0, "full HP: out")
	# the impact duck: 40 ms attack, the dip, 120 ms release
	B.duck(4.0, 120.0)
	B._process(0.02)
	ok(near(B.duck_v, 2.0, 0.01), "duck(4, 120): 2 dB after 20 ms (the 40 ms attack)")
	B._process(0.02)
	ok(near(B.duck_v, 4.0, 0.01) and near(B.bsp.volume_db, B._db(1.0) - 4.0, 0.05), "4 dB at 40 ms: the boss track dips 4 dB (%.1f)" % B.bsp.volume_db)
	B._process(0.07)
	ok(near(B.duck_v, 4.0, 0.01), "110 ms: still down")
	B._process(0.03)
	ok(near(B.duck_v, 4.0 - 4.0 * 0.02 / 0.12, 0.02), "140 ms: the dip ended at 120, the 120 ms release has run 20 (%.2f)" % B.duck_v)
	B._process(0.06)
	ok(near(B.duck_v, 4.0 - 4.0 * 0.08 / 0.12, 0.02), "200 ms: two thirds back (%.2f)" % B.duck_v)
	B._process(0.04)
	ok(B.duck_v == 0.0 and B.duck_db == 0.0 and near(B.bsp.volume_db, B._db(1.0), 0.05), "240 ms: released")
	B.duck(6.0, 250.0)
	B._process(0.04)
	B.duck(4.0, 120.0)
	ok(near(B.duck_v, 6.0, 0.01) and B.duck_db == 6.0 and near(B.duck_t, 0.21, 0.001), "a smaller duck during a deeper one changes nothing")
	for i in 10: B._process(0.05)
	ok(B.duck_v == 0.0, "gone after the dip and the release")
	# the boss down: the boss track out over 1.5 s, nothing takes its place
	D.room()["cleared"] = true
	await run(arena, 0.75)
	ok(B.boss_done() and not B.wanted_boss() and not B.wanted_battle(), "cleared boss room: no track wanted")
	ok(B.bsp.playing and B.bsgain > 0.35 and B.bsgain < 0.65, "the boss track half way out at 0.75 s (bsgain %.2f)" % B.bsgain)
	await run(arena, 1.0)
	ok(not B.bsp.playing and B.bsgain == 0.0 and not B.bp.playing and B.grid() == null and B.clock() == null, "silent in the cleared boss room: no grid, no clock")
	# back to town: the town fades back in from where it stopped
	arena.leave_dungeon()
	await run(arena, 0.3)
	ok(B.ap.playing and B.gain > 0.0 and B.gain < 1.0, "fading back in in town (gain %.2f)" % B.gain)
	ok(B.ap.get_playback_position() + 0.05 >= at, "resumed where it left off, not from 0")
	await run(arena, 0.8)
	ok(B.gain >= 1.0, "full again in town")
	# the next sortie: battle.ogg from 0 again, the overlay's intro again
	arena.enter_dungeon()
	await run(arena, 0.3)
	ok(B.bp.playing and B.bgain >= 1.0 and B.clocks["battle"].music_t < 3.0 and not B.low_intro, "a new sortie: battle.ogg from 0 (%.2f s), the low-HP intro fresh" % B.clocks["battle"].music_t)
	await run(arena, 0.8)
	ok(not B.ap.playing, "the town is out")
	# the training ground stays silent
	arena.go_training()
	await run(arena, 1.5)
	ok(not B.ap.playing and not B.bp.playing and not B.bsp.playing and not B.lp.playing and B.gain == 0.0 and B.bgain == 0.0 and B.clock() == null, "training ground: nothing plays")
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await run(arena, 1.2)
	# the 배경음 setting
	arena.music = false
	await run(arena, 1.0)
	ok(not B.ap.playing and B.gain == 0.0, "배경음 off: silent")
	arena.enter_dungeon()
	await run(arena, 0.5)
	ok(not B.bp.playing and B.bgain == 0.0 and B.grid() == null, "배경음 off in the dungeon: no battle track, no grid")
	P.hp = P.MAX_HP * 0.2
	await run(arena, 0.5)
	ok(not B.lp.playing and B.low_due < 0.0, "배경음 off: no low-HP overlay either")
	P.hp = P.MAX_HP
	arena.leave_dungeon()
	await run(arena, 0.5)
	arena.music = true
	await run(arena, 1.0)
	ok(B.ap.playing and B.gain >= 1.0, "배경음 on: back")
	# web: a first play that the browser blocked is retried on input
	B.ap.stop()
	var ev := InputEventScreenTouch.new()
	ev.pressed = true
	B._input(ev)
	ok(B.ap.playing, "a tap (re)starts it")
	print("bgm checks done, bad=", fails)
	print("FAILS: %d" % fails)
	quit()
