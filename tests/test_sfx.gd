extends SceneTree
## The sound effects as instruments on the music (arena.gd sfx): the logical name → file map (thrust = stab, dash =
## dodge, "ready" cycles ui1 / ui2 / ui3 never repeating, "hit" alone stays the old file, ui_move / ui_ok / ui_back →
## menu_move / menu_ok / menu_back), the pack's OGGs (sfx_stream loads <file>.ogg first, then .wav; jump / djump / land
## are OGG now, hit1 stays WAV) with a LEVEL entry each, the pickup words → pick_coin / pick_stone / pick_rune (jitter
## ±0.7 st, never snapped, vol 0.55), the ult's ult_sub layer at the same moment, the landing gate (LAND_MIN), the
## death jingle and its duck, the boss impacts, the combo's hit1 / hit2 / hit3 by the player's attack, the per-file
## levels, the old two-argument calls, the pitch from semitones with witch time's 0.62× on top, the jitter, the snap:
## a no-op in town, a hold of at most 90 ms onto the next 16th of the dungeon clock (a held clock makes it exact),
## played from the scheduled list the next frame; the perfect parry's +7 st; heavy / parry / ult ducking the music in
## the dungeon only; the raw cues on the SFX bus.
## godot --headless --path . -s tests/test_sfx.gd

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

## the pool player that last started: the one with this stream
## the player sounding `file`; a base with variants (hit1 → hit1_1..4) matches any of them
func player_of(file: String) -> AudioStreamPlayer:
	for ap in arena.sfx_pool:
		if ap.playing and ap.stream != null:
			var f: String = ap.stream.resource_path.get_file().get_basename()
			if f == file or (arena.VARIANTS.has(file) and f.begins_with(file + "_")): return ap
	return null

func stop_all() -> void:
	for ap in arena.sfx_pool: ap.stop()
	arena.sfx_due.clear()

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.repeat_ms = 0.0          # the fast-repeat lightening is checked on its own below
	var P = arena.player
	var B = arena.bgm

	print("-- the files")
	for f in ["ui1", "ui2", "ui3", "hit", "slam", "dive", "dig", "break", "boom", "witch_end", "flare", "alert", "alert_q", "tick"]:
		var st = arena.sfx_stream(f)
		check(st is AudioStreamWAV, "assets/sfx/%s.wav loads" % f)
	for base in arena.VARIANTS:
		for k in int(arena.VARIANTS[base]):
			check(arena.sfx_stream("%s_%d" % [base, k + 1]) is AudioStreamOggVorbis, "assets/sfx/%s_%d.ogg loads" % [base, k + 1])
	for f in ["jump", "djump", "land"]:
		check(arena.sfx_stream(f) is AudioStreamOggVorbis, "assets/sfx/%s.ogg loads" % f)
	for f in ["thrust", "dash", "ready"]:
		check(not ResourceLoader.exists("res://assets/sfx/%s.wav" % f), "the old %s.wav is gone" % f)
	check(arena.sfx_file("thrust").begins_with("stab_") and arena.sfx_file("dash").begins_with("dodge_") and arena.sfx_file("hit") == "hit" and arena.sfx_file("heavy").begins_with("heavy_") and arena.sfx_file("step") == "tick", "logical → file: thrust = stab_k, dash = dodge_k, hit itself, heavy = heavy_k, step = tick")
	check(arena.sfx_file("foot").begins_with("step_grass_"), "a footstep in town: the grass set")
	var seen := {}
	var prev := ""
	for i in 40:
		var f: String = arena.sfx_file("hit1")
		seen[f] = true
		check(f != prev, "round robin never repeats a variant back to back (%s)" % f) if f == prev else null
		prev = f
	check(seen.size() == 4, "hit1 cycles its four variants (%d seen)" % seen.size())
	# the pack: processed OGGs, loaded before any .wav of the same name
	const PACK := ["pick_coin", "pick_stone", "pick_rune", "menu_move", "menu_ok", "menu_back", "jingle_lv", "jingle_rank", "jingle_quest", "jingle_death", "jingle_book", "impact_boss_in", "impact_boss_down", "jump", "djump", "land"]
	for f in PACK:
		var st2 = arena.sfx_stream(f)
		check(st2 is AudioStreamOggVorbis and not st2.loop, "assets/sfx/%s.ogg loads (a one-shot ogg)" % f)
		check(not ResourceLoader.exists("res://assets/sfx/%s.wav" % f), "no %s.wav beside it" % f)
		check(arena.LEVEL.has(f) and arena.LEVEL[f] > 0.0, "LEVEL has %s (%.2f)" % [f, float(arena.LEVEL.get(f, 0.0))])
	check(arena.sfx_path("jump").ends_with("jump.ogg") and not ResourceLoader.exists("res://assets/sfx/jump.wav"), "a name with only .ogg (jump) resolves to the ogg")
	check(arena.sfx_path("slam").ends_with("slam.wav") and not ResourceLoader.exists("res://assets/sfx/slam.ogg"), "a name with only .wav (slam) resolves to the wav")
	check(arena.sfx_path("no_such_sound") == "" and arena.sfx_stream("no_such_sound") == null, "a missing name: no path, a null stream")
	for f in ["jump", "djump", "land"]:
		check(arena.sfx_stream(f) is AudioStreamOggVorbis and arena.sfx_stream(f).get_length() > 0.1, "%s.ogg: %.2f s" % [f, arena.sfx_stream(f).get_length()])
	check(arena.sfx_file("ui_move") == "menu_move" and arena.sfx_file("ui_ok") == "menu_ok" and arena.sfx_file("ui_back") == "menu_back", "ui_move / ui_ok / ui_back → menu_move / menu_ok / menu_back")
	check(arena.PICKUPS["실링"] == "pick_coin" and arena.PICKUPS["기억석"] == "pick_stone" and arena.PICKUPS["룬 · "] == "pick_rune" and arena.PICKUPS["장비"] == "pick_rune", "pickup words → pick_coin / pick_stone / pick_rune (룬 and 장비 share)")
	check(arena.LAYERS.is_empty(), "no layers: the recordings stand alone")
	var seq := []
	for i in 9: seq.append(arena.sfx_file("ready"))
	var norep := true
	for i in range(1, seq.size()):
		if seq[i] == seq[i - 1]: norep = false
	check(seq.slice(0, 3) == ["ui2", "ui3", "ui1"] or seq.slice(0, 3) == ["ui1", "ui2", "ui3"] or seq.slice(0, 3) == ["ui3", "ui1", "ui2"], "'ready' cycles the three UI clicks (%s)" % [seq.slice(0, 3)])
	check(norep and seq.count("ui1") == 3 and seq.count("ui2") == 3 and seq.count("ui3") == 3, "never the same click twice in a row, evenly")

	print("-- the combo's hits (player.gd hit_sound)")
	for c in [["attack1", 0, "hit1"], ["attack2", 0, "hit2"], ["attack3", 0, "hit3"], ["kneel_attack", 0, "hit1"], ["attack_high", 0, "hit2"], ["air_combo", 1, "hit1"], ["air_combo", 4, "hit2"], ["air_combo", 7, "hit3"], ["cthrust", 0, "heavy"], ["dive", 2, "hit1"]]:
		P.anim = c[0]
		P.f = c[1]
		check(P.hit_sound() == c[2], "%s (frame %d) → %s" % [c[0], c[1], P.hit_sound()])
	P.set_anim("idle", 0)

	print("-- in town: no grid, no snap, no duck")
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await run(0.3)
	check(B.grid() == null and arena.snap_delay() == 0.0, "town: no dungeon grid, snap_delay 0")
	stop_all()
	arena.sfx("hit1", 1.0, {"jitter": 0.0})
	var ap = player_of("hit1")
	check(ap != null and arena.sfx_due.is_empty(), "sfx('hit1') plays at once in town")
	check(near(ap.volume_db, linear_to_db(0.9) - 4.0, 0.01) and ap.pitch_scale == 1.0 and ap.bus == &"Slow", "hit1 at its level (0.9, -4 dB), pitch 1, through the Slow bus")
	stop_all()
	arena.sfx("swing")
	arena.sfx("guard", 0.9)
	arena.sfx("thrust", 0.5)
	check(player_of("swing") != null and player_of("guard") != null and player_of("stab") != null, "the old one- and two-argument calls still play (thrust came out as stab)")
	check(near(player_of("guard").volume_db, linear_to_db(0.9 * 0.9) - 4.0, 0.01) and near(player_of("stab").volume_db, linear_to_db(0.5 * 0.9) - 4.0, 0.01), "the caller's volume times the file's level")
	stop_all()
	arena.sfx("heavy", 1.0, {"jitter": 0.0})
	check(B.duck_t == 0.0 and B.duck_db == 0.0, "heavy in town does not duck the music")
	stop_all()
	arena.sfx("hit1", 1.0, {"st": 12.0, "jitter": 0.0})
	check(near(player_of("hit1").pitch_scale, 2.0, 0.001), "st 12 → pitch_scale 2")
	stop_all()
	arena.sfx("hit1", 1.0, {"st": -12.0, "jitter": 0.0})
	check(near(player_of("hit1").pitch_scale, 0.5, 0.001), "st -12 → 0.5")
	stop_all()
	arena.sfx("parry", 1.0, {"st": 7.0})
	check(near(player_of("parry").pitch_scale, pow(2.0, 7.0 / 12.0), 0.001) and near(player_of("parry").volume_db, linear_to_db(1.2) - 4.0, 0.01), "parry +7 st → 1.498 (a fifth), at its 1.2 level")
	stop_all()
	var pitches := {}
	for i in 12:
		arena.sfx("hurt", 0.8)
		var hp = player_of("hurt")
		pitches[snappedf(hp.pitch_scale, 0.0001)] = true
		check(hp.pitch_scale >= pow(2.0, -0.5 / 12.0) - 0.001 and hp.pitch_scale <= pow(2.0, 0.5 / 12.0) + 0.001, "hurt's jitter stays within ±0.5 st (%.4f)" % hp.pitch_scale)
		stop_all()
	check(pitches.size() >= 6, "the jitter varies from play to play (%d distinct of 12)" % pitches.size())
	arena.sfx("step")
	check(player_of("tick").pitch_scale == 1.0, "step (the UI tick): no jitter")
	stop_all()
	arena.witch = 1000.0
	arena.sfx("swing", 1.0, {"st": 12.0, "jitter": 0.0})
	check(near(player_of("swing").pitch_scale, 2.0 * 0.62, 0.001), "witch time: 0.62× on top of the semitones for a movement sound (1.24)")
	stop_all()
	arena.sfx("hit1", 1.0, {"st": 12.0, "jitter": 0.0})
	check(near(player_of("hit1").pitch_scale, 2.0, 0.001), "witch time leaves an impact's pitch alone")
	stop_all()
	arena.sfx("boom", 0.9)
	check(player_of("boom").pitch_scale == 1.0 and player_of("boom").bus == &"SFX", "the raw cues (boom) stay dry and at 1×, straight on the SFX bus")
	arena.witch = 0.0
	stop_all()
	# the ult: one file, no layer
	arena.sfx("ult", 1.0)
	check(player_of("ult") != null and arena.sfx_due.is_empty() and arena.sfx_pool.filter(func(a): return a.playing).size() == 1, "sfx('ult') in town: the one file plays at once")
	stop_all()
	# the pickups: by the notice's word, with jitter, never snapped
	for w in [["실링 +3", "pick_coin"], ["기억석 +1", "pick_stone"], ["룬 · 불씨", "pick_rune"], ["장비 · 낡은 검", "pick_rune"]]:
		arena.text(Vector2(100, 100), w[0], Color.WHITE)
		var pp = player_of(w[1])
		check(pp != null and arena.sfx_due.is_empty(), "text('%s') rings %s at once" % [w[0], w[1]])
		if pp != null:
			check(near(pp.volume_db, linear_to_db(0.55 * arena.LEVEL[w[1]]) - 4.0, 0.01), "…at 0.55 × its level")
			check(pp.pitch_scale >= pow(2.0, -0.7 / 12.0) - 0.001 and pp.pitch_scale <= pow(2.0, 0.7 / 12.0) + 0.001, "…within ±0.7 st (%.4f)" % pp.pitch_scale)
		stop_all()
	arena.text(Vector2(100, 100), "보상 · 실링 +6", Color.WHITE)
	check(player_of("pick_coin") == null, "a line that does not start with a pickup word is plain floating text, no ring")
	arena.text(Vector2(100, 100), "도감 등록: 고블린", Color.WHITE)
	check(player_of("pick_coin") == null and player_of("pick_rune") == null, "…nor does any other text")
	stop_all()
	var pj := {}
	for i in 10:
		arena.text(Vector2(100, 100), "실링 +1", Color.WHITE)
		pj[snappedf(player_of("pick_coin").pitch_scale, 0.0001)] = true
		stop_all()
	check(pj.size() >= 5, "the pickup jitter varies (%d distinct of 10)" % pj.size())
	for k in [["sh", "pick_coin"], ["mem", "pick_stone"], ["rune", "pick_rune"], ["gear", "pick_rune"], ["skin", "pick_rune"]]:
		arena.loot_pick(k[0])
		check(player_of(k[1]) != null, "the chest's loot (%s) rings %s" % [k[0], k[1]])
		stop_all()
	check(not arena.has_method("loot_tink"), "the procedural tinks are gone")
	# the landing gate: a touchdown from LAND_MIN px or more rings land.ogg, a kerb does not
	P.air_top = P.position.y - 160.0
	P.land_sfx()
	check(player_of("land") != null and near(player_of("land").volume_db, linear_to_db(0.6 * arena.LEVEL["land"]) - 4.0, 0.01), "a landing from 160 px: land.ogg at 0.6")
	stop_all()
	P.air_top = P.position.y - 40.0
	P.land_sfx()
	check(player_of("land") != null and player_of("land").volume_db < linear_to_db(0.6 * arena.LEVEL["land"]) - 4.0, "a small hop's landing: quieter")
	stop_all()
	P.air_top = P.position.y - 10.0
	P.land_sfx()
	check(player_of("land") == null, "a 10 px step down: quiet")
	P.air_top = P.position.y
	# the death jingle: in town, no dungeon track to duck
	var hp0: float = P.hp
	P.die()
	check(player_of("jingle_death") != null and P.anim == "death", "die(): jingle_death with the death anim")
	check(B.duck_t == 0.0 and B.duck_db == 0.0, "…no duck in town (no dungeon track)")
	P.hp = hp0
	P.set_anim("idle", 0)
	P.dead_t = 0.0
	stop_all()
	arena.sfx("ui1", 0.4, {"delay_ms": 30.0})
	check(player_of("ui1") == null and arena.sfx_due.size() == 1 and near(arena.sfx_due[0]["t"], 30.0), "delay_ms: scheduled, not played yet")
	arena.sfx_step(20.0)
	check(player_of("ui1") == null and near(arena.sfx_due[0]["t"], 10.0), "20 ms on: still waiting")
	arena.sfx_step(20.0)
	check(player_of("ui1") != null and arena.sfx_due.is_empty(), "40 ms on: played")
	stop_all()

	print("-- in the dungeon: the snap")
	P.inv = 1.0e9
	arena.enter_dungeon()
	await run(0.5)
	var C = B.clocks["battle"]
	check(B.grid() == C and C.live, "the battle clock is the grid")
	C.hold = true                        # a held clock: exact distances to the next 16th
	var six: float = C.sixteenth_len()
	check(near(six, 60.0 / 95.2 / 4.0, 0.01), "a 16th of the battle grid is ~0.157 s (%.4f)" % six)
	# 50 ms before a 16th: held 50 ms
	var line: float = C.time_of(8.0 * 0.25 * 4.0)      # beat 8
	C.set_time(line - 0.05)
	check(near(C.next_sixteenth(), 0.05, 0.001) and near(arena.snap_delay(), 0.05, 0.001), "50 ms before a 16th: snap_delay 0.05")
	stop_all()
	arena.sfx("hit1", 1.0, {"jitter": 0.0})
	check(player_of("hit1") == null and arena.sfx_due.size() == 1 and near(arena.sfx_due[0]["t"], 50.0, 1.0), "hit1 is held for the 16th (%.1f ms)" % (arena.sfx_due[0]["t"] if not arena.sfx_due.is_empty() else -1.0))
	arena._process(0.03)
	check(player_of("hit1") == null and arena.sfx_due.size() == 1, "30 ms on: not yet")
	arena._process(0.03)
	check(player_of("hit1") != null and arena.sfx_due.is_empty(), "60 ms on: it plays (from arena._process, whatever holds the world)")
	stop_all()
	# 90 ms before: still held; 95 ms: at once
	C.set_time(line - 0.09)
	arena.sfx("heavy", 1.0, {"jitter": 0.0})
	check(player_of("heavy") == null and arena.sfx_due.size() == 1 and near(arena.sfx_due[0]["t"], 90.0, 1.0), "90 ms before: held (the limit)")
	stop_all()
	C.set_time(line - 0.095)
	arena.sfx("heavy", 1.0, {"jitter": 0.0})
	check(player_of("heavy") != null and arena.sfx_due.is_empty(), "95 ms before: played at once — never a hold over 90 ms")
	check(B.duck_t > 0.0 and B.duck_db == 4.0 and near(B.duck_t, 0.12, 0.001), "heavy in the dungeon ducks the music 4 dB for 120 ms")
	stop_all()
	B.duck_t = 0.0
	B.duck_db = 0.0
	B.duck_v = 0.0
	C.set_time(line)
	arena.sfx("hit2", 1.0, {"jitter": 0.0})
	check(player_of("hit2") != null and arena.sfx_due.is_empty(), "right on the line: at once")
	stop_all()
	C.set_time(line - 0.04)
	arena.sfx("hurt", 0.8)
	arena.sfx("dash")
	arena.sfx("ready", 0.4)
	arena.sfx("step")
	check(player_of("hurt") != null and player_of("dodge") != null and player_of("tick") != null and arena.sfx_due.is_empty(), "hurt, dodge, the UI click and ticks never snap")
	stop_all()
	arena.sfx("hit3", 1.0, {"snap": false, "jitter": 0.0})
	check(player_of("hit3") != null and arena.sfx_due.is_empty(), "snap: false turns it off for a call")
	stop_all()
	arena.sfx("step", 1.0, {"snap": true})
	check(player_of("tick") == null and arena.sfx_due.size() == 1, "snap: true turns it on for a call")
	stop_all()
	# a snapped hit scheduled, then witch time starts before it plays: the pitch is read when it sounds
	C.set_time(line - 0.05)
	arena.sfx("swing", 1.0, {"jitter": 0.0, "snap": true})
	arena.witch = 1000.0
	arena.sfx_step(60.0)
	check(player_of("swing") != null and near(player_of("swing").pitch_scale, 0.62, 0.001), "witch time that began while a snapped swing waited: it sounds at 0.62×")
	arena.witch = 0.0
	stop_all()
	# the ult's impact: snapped, the deep duck
	C.set_time(line - 0.03)
	arena.sfx("ult", 1.0)
	check(player_of("ult") == null and arena.sfx_due.size() == 1 and near(arena.sfx_due[0]["t"], 30.0, 1.0), "the ult impact snaps too (1 due)")
	arena.sfx_step(40.0)
	check(player_of("ult") != null and B.duck_db == 6.0 and near(B.duck_t, 0.25, 0.001) and near(player_of("ult").volume_db, -4.0, 0.01), "…and ducks the music 6 dB for 250 ms when it sounds, at full level")
	stop_all()
	B.duck_t = 0.0
	B.duck_db = 0.0
	B.duck_v = 0.0
	# a fast repeat plays lighter (REPEAT_K) when repeat_ms is on
	arena.repeat_ms = 300.0
	arena.hit_last_ms = -99999.0
	arena.sfx("hit1", 1.0, {"jitter": 0.0, "snap": false})
	var first_db: float = player_of("hit1").volume_db
	stop_all()
	arena.sfx("hit2", 1.0, {"jitter": 0.0, "snap": false})
	check(near(player_of("hit2").volume_db, first_db + linear_to_db(arena.REPEAT_K), 0.05), "a hit within 300 ms of the last: 0.7× (the fast combo stays light)")
	arena.repeat_ms = 0.0
	stop_all()
	B.duck_t = 0.0
	B.duck_db = 0.0
	B.duck_v = 0.0
	# the death jingle ducks the dungeon track 6 dB for 600 ms
	var hp1: float = P.hp
	P.die()
	check(player_of("jingle_death") != null and B.duck_db == 6.0 and near(B.duck_t, 0.6, 0.001), "die() in the dungeon: jingle_death, the music ducked 6 dB for 600 ms")
	P.hp = hp1
	P.set_anim("idle", 0)
	P.dead_t = 0.0
	stop_all()
	B.duck_t = 0.0
	B.duck_db = 0.0
	B.duck_v = 0.0
	# the boss down: impact_boss_down lands 120 ms after the break
	var bm = arena.spawn("boss", P.position.x + 300.0, 0.0)
	await process_frame
	bm.hp = 1.0
	bm.hit(1.0, 0.0)
	var due_down: Array = arena.sfx_due.filter(func(q): return q["file"] == "impact_boss_down")
	check(bm.is_dead() and player_of("down") != null and due_down.size() == 1 and near(due_down[0]["t"], 120.0, 1.0), "the boss falls: the body-down now, impact_boss_down due in 120 ms (%s)" % str(due_down.size()))
	arena.sfx_step(130.0)
	check(player_of("impact_boss_down") != null, "…and it sounds")
	stop_all()
	arena.hitstop = 0.0
	# the perfect parry: a glinting blow parried rings a fifth up
	C.set_time(line)
	var m = arena.spawn("goblin", P.position.x + 120.0, 0.0)
	await process_frame
	m.flared = false
	arena.parry_fx(P, m)
	check(near(player_of("parry").pitch_scale, 1.0, 0.001), "a plain parry: pitch 1")
	stop_all()
	arena.hitstop = 0.0
	m.flared = true
	arena.parry_fx(P, m)
	check(near(player_of("parry").pitch_scale, pow(2.0, 7.0 / 12.0), 0.001), "a glinting blow parried (perfect): +7 st")
	stop_all()
	arena.hitstop = 0.0
	# the slow bus leaves the pool's pitch alone (own_pitch) — a frame later the semitones are still there
	C.set_time(line)
	arena.sfx("hit3", 1.0, {"st": 5.0, "jitter": 0.0})
	var h3 = player_of("hit3")
	await process_frame
	await process_frame
	check(h3 != null and near(h3.pitch_scale, pow(2.0, 5.0 / 12.0), 0.001), "slow_bus.gd leaves the pool's own pitch alone (%.3f)" % h3.pitch_scale)
	stop_all()
	C.hold = false
	# the boss card: impact_boss_in as the card comes up (sortie.pre_step)
	var D = arena.level
	var bk := ""
	for k in D.rooms:
		if D.rooms[k]["type"] == "boss": bk = k
	var sv: bool = arena.sortie.tc.active
	D.from = "L"
	D.cur = bk
	D.enter()
	arena.fade_dir = 0
	arena.sortie.last_cur = ""
	D.room()["tc"] = false
	var pre: bool = arena.sortie.pre_step()
	check(pre and arena.sortie.tc.active and arena.sortie.tc.kind == "boss" and player_of("impact_boss_in") != null, "the boss room entered: the card plays with impact_boss_in")
	arena.sortie.tc.active = sv
	arena.sortie.tc.visible = false
	stop_all()
	arena.hitstop = 0.0
	# the 배경음 setting off: no grid, so no snap
	arena.music = false
	await run(1.0)
	check(B.grid() == null and arena.snap_delay() == 0.0, "배경음 off: no grid, the snap is a no-op")
	arena.sfx("hit1")
	check(player_of("hit1") != null and arena.sfx_due.is_empty(), "…hits play at once")
	arena.music = true
	stop_all()

	print("FAILS: %d" % fails)
	quit()
