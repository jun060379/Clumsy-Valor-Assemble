extends SceneTree
## town music (bgm.gd): town.ogg loads and loops, plays in town, carries on into the guild hall without restarting,
## fades out in the dungeon, comes back in town where it left off; the 배경음 setting mutes it. The title track
## (title.ogg) loads and loops on its own player; tests/test_title.gd covers the title → town cross-fade.
var fails := 0

func ok(c: bool, what: String) -> void:
	if not c:
		fails += 1
		print("FAIL ", what)
	else:
		print("ok ", what)

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
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await run(arena, 1.2)
	ok(arena.level_kind() == "town" and B.ap.playing and B.gain >= 1.0, "playing at full in town (gain %.2f)" % B.gain)
	# town -> hall: no restart, no dip
	var p0: float = B.ap.get_playback_position()
	arena.go_hall(0, Vector2(1800.0, arena.ground_y), 1)
	await run(arena, 0.3)
	ok(arena.level_kind() == "hall" and B.ap.playing and B.gain >= 1.0, "still playing at full in the hall")
	ok(B.ap.get_playback_position() + 0.05 >= p0, "the hall did not restart it (%.2f -> %.2f)" % [p0, B.ap.get_playback_position()])
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await run(arena, 0.3)
	# into the dungeon: fades over ~0.8 s, then stops
	arena.enter_dungeon()
	await run(arena, 0.3)
	ok(B.gain > 0.0 and B.gain < 1.0, "fading in the dungeon (gain %.2f)" % B.gain)
	await run(arena, 0.8)
	ok(B.gain == 0.0 and not B.ap.playing, "silent in the dungeon")
	var at: float = B.paused_at
	ok(at >= 0.0, "kept its place (%.2f s)" % at)
	# back to town: fades back in from where it stopped
	arena.leave_dungeon()
	await run(arena, 0.3)
	ok(B.ap.playing and B.gain > 0.0 and B.gain < 1.0, "fading back in in town (gain %.2f)" % B.gain)
	ok(B.ap.get_playback_position() + 0.05 >= at, "resumed where it left off, not from 0")
	await run(arena, 0.8)
	ok(B.gain >= 1.0, "full again in town")
	# the 배경음 setting
	arena.music = false
	await run(arena, 1.0)
	ok(not B.ap.playing and B.gain == 0.0, "배경음 off: silent")
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
	quit()
