extends SceneTree
## 설정 · 소리: the buses (Master 0, SFX and Voice into Master, Slow → SFX, BGM → Master), the four volume sliders of
## options.gd (전체 음량 · 배경음 · 효과음 · 보이스: k "sld", 11 steps, the label carrying the percent) right after the
## 배경음 켜기/끄기 toggle, each slider onto its bus (linear_to_db(v); 0 % mutes; BGM keeps bgm.gd's BUS_DB trim under
## it), the 효과음 slider answering with ui_ok (and only that), the values round-tripping through settings.gd save /
## load ("audio" / master · bgm · sfx · voice), apply_audio at startup, the 배경음 toggle still silencing the music.
## godot --headless --path . -s tests/test_audio_opts.gd

const SETTINGS := preload("res://scripts/settings.gd")

var fails := 0
var arena

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps

func run(s: float) -> void:
	for i in int(s / 0.05):
		arena.bgm._process(0.05)
		await process_frame

func playing(file: String) -> AudioStreamPlayer:
	var st = arena.sfx_cache.get(file)
	for ap in arena.sfx_pool:
		if ap.stream == st and ap.playing: return ap
	return null

func n_playing() -> int:
	var n := 0
	for ap in arena.sfx_pool:
		if ap.playing: n += 1
	return n

func stop_all() -> void:
	for ap in arena.sfx_pool: ap.stop()
	arena.sfx_due.clear()

func bus(n: StringName) -> int:
	return AudioServer.get_bus_index(n)

func sld_rows(opts) -> Array:
	return sld_of(opts._rows())

func sld_of(rows: Array) -> Array:
	return rows.filter(func(R): return R["k"] == "sld" and R.has("vol"))

## the index of the slider row for key k in a _rows() list
func row_i(rows: Array, k: String) -> int:
	for i in rows.size():
		if rows[i].get("vol", "") == k: return i
	return -1

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var C = arena.cfg
	var B = arena.bgm
	var U = arena.ui_root

	print("-- the buses")
	check(bus(&"Master") == 0 and bus(&"SFX") > 0 and bus(&"Voice") > 0 and bus(&"Slow") > 0 and bus(&"BGM") > 0, "Master, SFX, Voice, Slow and BGM exist (%d / %d / %d / %d)" % [bus(&"SFX"), bus(&"Voice"), bus(&"Slow"), bus(&"BGM")])
	check(AudioServer.get_bus_send(bus(&"SFX")) == &"Master" and AudioServer.get_bus_send(bus(&"Voice")) == &"Master" and AudioServer.get_bus_send(bus(&"BGM")) == &"Master", "SFX, Voice and BGM send to Master")
	check(AudioServer.get_bus_send(bus(&"Slow")) == &"SFX" and bus(&"SFX") < bus(&"Slow"), "Slow sends into SFX (and SFX sits before it, as a send must)")
	check(AudioServer.get_bus_effect_count(0) == 1 and AudioServer.get_bus_effect(0, 0) is AudioEffectLimiter, "the Master limiter is still there")
	check(arena.slow_bus.idx == bus(&"Slow") and arena.slow_bus.fx >= 0, "slow_bus.gd found its bus and its low-pass")
	for ap in arena.sfx_pool:
		check(ap.bus == &"Slow", "a pool player idles on the Slow bus")
		break
	check(arena.amb.pool[0].bus == &"Slow" and arena.dlg.voice_ap.bus == &"Slow", "the ambience pool and the talk voice ride the Slow bus (→ SFX)")
	check(B.ap.bus == &"BGM" and B.bp.bus == &"BGM", "the music stays on BGM")
	stop_all()
	arena.sfx("boom", 0.5)
	check(playing("boom") != null and playing("boom").bus == &"SFX", "a raw cue (boom) goes straight to SFX, not Master")
	stop_all()

	print("-- the saved values are on the buses at startup")
	for k in SETTINGS.AUDIO_KEYS:
		var i := bus(SETTINGS.AUDIO_BUS[k])
		var v: float = C.get_vol(k)
		check(near(AudioServer.get_bus_volume_db(i), SETTINGS.bus_db(k, v), 0.01) and AudioServer.is_bus_mute(i) == (v <= 0.0), "%s: bus %s at %.1f dB for %.2f" % [k, SETTINGS.AUDIO_BUS[k], AudioServer.get_bus_volume_db(i), v])
	check(SETTINGS.AUDIO_DEF == {"master": 1.0, "bgm": 0.8, "sfx": 1.0, "voice": 1.0}, "the defaults: 1.0 / 0.8 / 1.0 / 1.0")
	# from here the sliders start at their defaults
	for k in SETTINGS.AUDIO_KEYS: C.set_vol(k, SETTINGS.AUDIO_DEF[k])
	check(near(AudioServer.get_bus_volume_db(0), 0.0) and near(AudioServer.get_bus_volume_db(bus(&"BGM")), B.BUS_DB + linear_to_db(0.8)) and near(AudioServer.get_bus_volume_db(bus(&"SFX")), 0.0) and near(AudioServer.get_bus_volume_db(bus(&"Voice")), 0.0), "defaults applied: Master 0 dB, BGM %.1f + %.1f, SFX 0, Voice 0" % [B.BUS_DB, linear_to_db(0.8)])
	check(near(SETTINGS.bus_db("bgm", 1.0), B.BUS_DB) and near(SETTINGS.bus_db("bgm", 0.5), B.BUS_DB + linear_to_db(0.5)) and near(SETTINGS.bus_db("sfx", 0.5), linear_to_db(0.5)), "bus_db: BGM = BUS_DB + linear_to_db(v), the others linear_to_db(v)")

	print("-- the rows")
	U.menu.open_page("opts")
	for i in 3: await process_frame
	var O = U.menu.opts
	check(U.menu.page == "opts" and O.visible and O.mode == "opts", "the 설정 page is open")
	var rows: Array = O._rows()
	var ti := -1
	for i in rows.size():
		if rows[i]["k"] == "tog" and rows[i]["lab"] == "배경음 켜기/끄기": ti = i
	check(ti >= 0 and rows[ti]["o"] == ["켜기", "끄기"], "the 배경음 켜기/끄기 toggle is a row (%d)" % ti)
	var S := sld_of(rows)
	check(S.size() == 4, "four volume sliders")
	var labs: Array = S.map(func(R): return R["lab"])
	check(labs == ["전체 음량 100%", "배경음 80%", "효과음 100%", "보이스 100%"], "labelled with the percent: %s" % [labs])
	check(S.map(func(R): return R["vol"]) == ["master", "bgm", "sfx", "voice"], "…for master / bgm / sfx / voice")
	for R in S:
		check(int(R["n"]) == 11 and int(R["on"]) == roundi(C.get_vol(R["vol"]) * 10.0), "%s: 11 steps, at step %d" % [R["vol"], int(R["on"])])
	var si := -1
	for i in rows.size():
		if rows[i].has("vol") and si < 0: si = i
	check(ti >= 0 and si == ti + 1 and rows[ti + 4].get("vol", "") == "voice", "the sliders sit right under the toggle (rows %d..%d)" % [si, si + 3])
	var oh := -1
	for i in rows.size():
		if rows[i]["k"] == "oh" and oh < 0: oh = i
	check(oh > si + 3, "…before the 조작키 heading")
	var t12 := rows.filter(func(R): return R["k"] == "sld" and not R.has("vol"))
	check(t12.size() == 1 and int(t12[0]["n"]) == 12, "the 12-step 시간 slider is untouched")
	# the draw pass registered a hit cell per step, tagged with its row (the list is scrolled so all four are in the box)
	O.sel = row_i(rows, "sfx")
	O._nav(1)
	stop_all()
	check(O.sel == row_i(rows, "voice") and O.scroll > 0.0, "the cursor on 보이스 scrolled the list (%.0f)" % O.scroll)
	O.t = 9000.0
	for i in 5: await process_frame
	for R in S:
		var cells: Array = O.hits.filter(func(h): return h.size() > 2 and h[2].get("vol", "") == R["vol"])
		check(cells.size() == 11, "%s: 11 tap cells drawn (%d)" % [R["vol"], cells.size()])

	print("-- a slider onto its bus")
	for R in S:
		var k: String = R["vol"]
		var i := bus(SETTINGS.AUDIO_BUS[k])
		stop_all()
		R["set"].call(5)
		check(near(C.get_vol(k), 0.5), "%s step 5 → 0.5" % k)
		check(near(AudioServer.get_bus_volume_db(i), SETTINGS.bus_db(k, 0.5), 0.01) and not AudioServer.is_bus_mute(i), "…bus %s at %.2f dB" % [SETTINGS.AUDIO_BUS[k], AudioServer.get_bus_volume_db(i)])
		var fresh: Dictionary = sld_rows(O)[S.find(R)]      # the rows are rebuilt on every _rows(): the same slot
		check(int(fresh["on"]) == 5 and String(fresh["lab"]).ends_with(" 50%"), "…the row reads '%s'" % fresh["lab"])
		R["set"].call(0)
		check(near(C.get_vol(k), 0.0) and AudioServer.is_bus_mute(i), "%s step 0 → muted" % k)
		R["set"].call(10)
		check(near(C.get_vol(k), 1.0) and not AudioServer.is_bus_mute(i) and near(AudioServer.get_bus_volume_db(i), SETTINGS.bus_db(k, 1.0), 0.01), "%s step 10 → 1.0, unmuted, %.1f dB" % [k, AudioServer.get_bus_volume_db(i)])
		for j in S.size():
			if S[j] == R: continue
			var k2: String = S[j]["vol"]
			var want: float = 1.0 if j < S.find(R) else float(SETTINGS.AUDIO_DEF[k2])     # the rows before it ended at step 10
			check(near(C.get_vol(k2), want), "…%s untouched by the %s slider (%.2f)" % [k2, k, C.get_vol(k2)])
	check(near(AudioServer.get_bus_volume_db(bus(&"Slow")), 0.0, 0.5), "the Slow bus is not a volume control (still ~0 dB)")

	print("-- the 효과음 slider clicks, the others do not")
	var sfx_row = S[2]
	var bgm_row = S[1]
	stop_all()
	sfx_row["set"].call(7)
	check(playing("menu_ok") != null and n_playing() == 1, "효과음 → ui_ok (menu_ok) once, at the new level")
	check(near(AudioServer.get_bus_volume_db(bus(&"SFX")), linear_to_db(0.7), 0.01), "…SFX bus at %.2f dB before it sounds" % AudioServer.get_bus_volume_db(bus(&"SFX")))
	stop_all()
	bgm_row["set"].call(7)
	check(n_playing() == 0, "배경음 → no click (the music is playing)")
	S[0]["set"].call(9)
	S[3]["set"].call(9)
	check(n_playing() == 0, "전체 음량 / 보이스 → no click from the row itself")
	# through the keyboard cursor: the generic row sound, except on the 효과음 row (its own click only)
	rows = O._rows()
	O.sel = row_i(rows, "sfx")
	stop_all()
	O._side(1)
	check(near(C.get_vol("sfx"), 0.8) and playing("menu_ok") != null and n_playing() == 1, "→ on the 효과음 row: one step up, one menu_ok, no menu_move")
	stop_all()
	O.sel = row_i(rows, "master")
	O._side(-1)
	check(near(C.get_vol("master"), 0.8) and playing("menu_move") != null and n_playing() == 1, "← on the 전체 음량 row: one step down, menu_move")
	stop_all()
	O._activate()
	check(near(C.get_vol("master"), 0.9) and playing("menu_ok") != null, "Enter on it: the next step, menu_ok")
	stop_all()
	O._nav(1)
	check(playing("menu_move") != null, "the cursor moving: menu_move")
	stop_all()
	# a tap on a cell goes through _click: the tagged row decides the sound
	var cell_sfx: Array = O.hits.filter(func(h): return h.size() > 2 and h[2].get("vol", "") == "sfx")
	var cell_mas: Array = O.hits.filter(func(h): return h.size() > 2 and h[2].get("vol", "") == "master")
	if cell_sfx.size() == 11 and cell_mas.size() == 11:
		var c3: PackedVector2Array = cell_sfx[3][0]
		var cen := Vector2.ZERO
		for v in c3: cen += v
		cen /= c3.size()
		O._click(cen)
		check(near(C.get_vol("sfx"), 0.3) and playing("menu_ok") != null and n_playing() == 1, "a tap on the 효과음 row's cell 3: 30 %%, one menu_ok (%d playing)" % n_playing())
		stop_all()
		var m6: PackedVector2Array = cell_mas[6][0]
		cen = Vector2.ZERO
		for v in m6: cen += v
		cen /= m6.size()
		O._click(cen)
		check(near(C.get_vol("master"), 0.6) and playing("menu_ok") != null, "a tap on the 전체 음량 row's cell 6: 60 %, menu_ok")
		stop_all()
	else:
		check(false, "the slider cells were drawn (%d / %d)" % [cell_sfx.size(), cell_mas.size()])
	U.menu.close_page()
	await process_frame
	check(U.menu.page == "" and playing("menu_back") != null, "closing the page: ui_back")
	stop_all()

	print("-- save / load")
	C.set_vol("master", 0.6)
	C.set_vol("bgm", 0.3)
	C.set_vol("sfx", 0.9)
	C.set_vol("voice", 0.0)
	C.save()
	var cf := ConfigFile.new()
	check(cf.load(SETTINGS.PATH) == OK and near(float(cf.get_value("audio", "master")), 0.6) and near(float(cf.get_value("audio", "bgm")), 0.3) and near(float(cf.get_value("audio", "sfx")), 0.9) and near(float(cf.get_value("audio", "voice")), 0.0), "settings.cfg [audio] master / bgm / sfx / voice")
	check(bool(cf.get_value("ui", "bgm", true)) == arena.music, "…beside the old [ui] bgm toggle")
	var C2 = SETTINGS.new(arena)
	check(near(C2.get_vol("master"), 0.6) and near(C2.get_vol("bgm"), 0.3) and near(C2.get_vol("sfx"), 0.9) and near(C2.get_vol("voice"), 0.0), "a fresh settings.gd reads them back")
	# apply_audio puts the loaded values on the buses (what arena._ready does at startup)
	AudioServer.set_bus_volume_db(bus(&"SFX"), 3.0)
	AudioServer.set_bus_mute(bus(&"Voice"), false)
	C2.apply_audio()
	check(near(AudioServer.get_bus_volume_db(bus(&"SFX")), linear_to_db(0.9), 0.01) and AudioServer.is_bus_mute(bus(&"Voice")) and near(AudioServer.get_bus_volume_db(bus(&"BGM")), B.BUS_DB + linear_to_db(0.3), 0.01) and near(AudioServer.get_bus_volume_db(0), linear_to_db(0.6), 0.01), "apply_audio: every bus from the loaded values, Voice muted at 0")
	cf.set_value("audio", "sfx", 7.0)
	cf.set_value("audio", "bgm", -2.0)
	cf.save(SETTINGS.PATH)
	var C3 = SETTINGS.new(arena)
	check(near(C3.get_vol("sfx"), 1.0) and near(C3.get_vol("bgm"), 0.0), "out-of-range values are clamped on load")
	for k in SETTINGS.AUDIO_KEYS: C.set_vol(k, SETTINGS.AUDIO_DEF[k])
	C.save()
	check(near(SETTINGS.new(arena).get_vol("bgm"), 0.8), "back at the defaults, saved")

	print("-- the 배경음 toggle and the slider")
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await run(1.2)
	check(arena.music and B.ap.playing and B.gain >= 1.0, "the town track plays")
	C.set_vol("bgm", 0.0)
	check(B.ap.playing and AudioServer.is_bus_mute(bus(&"BGM")), "배경음 0 %: the track keeps running, its bus is muted")
	C.set_vol("bgm", 0.8)
	check(not AudioServer.is_bus_mute(bus(&"BGM")) and near(AudioServer.get_bus_volume_db(bus(&"BGM")), B.BUS_DB + linear_to_db(0.8), 0.01), "배경음 80 %: unmuted, BUS_DB + the slider")
	arena.music = false
	await run(1.0)
	check(not B.ap.playing and B.gain == 0.0 and not AudioServer.is_bus_mute(bus(&"BGM")), "the toggle off: the track fades out and stops (the bus itself untouched)")
	arena.music = true
	await run(1.0)
	check(B.ap.playing and B.gain >= 1.0, "the toggle on: back")
	stop_all()

	print("FAILS: %d" % fails)
	quit()
