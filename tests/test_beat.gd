extends SceneTree
## The music clock per track (beat.gd): the title's default grid is untouched, a constant {bpm, t0, half_time, len,
## loop} grid, the measured beat maps (beat_maps.gd) and bgm.grid_of(), next_sixteenth / next_bar across the loop
## wrap, the wall-clock fallback with a loop offset.
## godot --headless --path . -s tests/test_beat.gd

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps

func _initialize() -> void:
	var BEAT = load("res://scripts/beat.gd")
	var BGM = load("res://scripts/bgm.gd")
	var MAPS = load("res://scripts/beat_maps.gd")

	print("-- the title's grid (the defaults)")
	var t = BEAT.new()
	check(near(t.t0, 0.09) and near(t.beat_s, 0.325125) and near(t.pulse_s, 0.65025) and t.half_time and near(t.len_s, 164.44) and t.loop_s == 0.0 and t.beats.is_empty(), "a bare Beat is the title's grid: t0 0.09, beat 0.3251, pulse 0.650 half-time, 164.44 s, loop 0")
	t.start(0.0)
	t.set_time(0.09 + 1.3005 * 3.0 + 0.325125 * 2.0)
	check(t.bar() == 3 and t.beat_in_bar() == 2 and near(t.bar_phase(), 0.5) and near(t.pulse_phase(), 0.0, 0.02) and near(t.beat_phase(), 0.0, 0.02), "two beats into bar 3: bar 3, beat 2, bar phase .5, pulse / beat phase 0")
	check(near(t.sixteenth_len(), 0.1625) and near(t.bar_len(), 1.3005), "title: a 16th of the pulse is 0.1625 s, a bar 1.3005")
	check(near(t.next_sixteenth(0.09), 0.0) and near(t.next_sixteenth(0.1), 0.1525) and near(t.next_sixteenth(0.09 + 0.1625 * 3.0 - 0.02), 0.02), "title: on the line 0, 0.1 → 0.1525, 20 ms before the 4th 16th → 0.02")
	check(near(t.next_sixteenth(164.4), 0.13), "title across the wrap: 164.4 → the rest of the file (0.04) + the first 16th at 0.09 = 0.13 (%.3f)" % t.next_sixteenth(164.4))
	check(near(t.next_bar(0.1), 1.2905) and near(t.next_bar(164.0), 0.53), "title next bar: 0.1 → 1.2905, 164.0 → 0.44 + 0.09")
	check(near(BEAT.bar_t(35), 45.6075) and BEAT.section_at(45.7) == "B", "the static title helpers still read the constants")

	print("-- a constant 95.7 grid")
	var b = BEAT.new({"bpm": 95.7, "t0": 0.12, "half_time": false, "len": 105.79, "loop": 4.99})
	var beat := 60.0 / 95.7
	check(near(b.beat_s, 0.62696, 0.0001) and near(b.pulse_s, b.beat_s, 0.0001) and not b.half_time and near(b.sixteenth_len(), 0.15674, 0.0001) and near(b.bar_len(), 2.5078, 0.001), "95.7 BPM: beat 0.627 s = the pulse, a 16th 0.157 s, a bar 2.508 s")
	check(near(b.beat_at(0.12), 0.0) and near(b.beat_at(0.12 + 4.0 * beat), 4.0) and near(b.time_of(8.0), 0.12 + 8.0 * beat), "beat_at / time_of on the constant grid")
	b.start(0.0)
	b.set_time(0.12 + beat * 6.5)
	check(b.bar() == 1 and b.beat_in_bar() == 2 and near(b.beat_phase(), 0.5) and near(b.bar_phase(), 0.625), "6.5 beats in: bar 1, beat 2, beat phase .5, bar phase .625")
	var six := beat / 4.0
	check(near(b.next_sixteenth(0.12), 0.0) and near(b.next_sixteenth(0.12 + 0.05), six - 0.05) and near(b.next_sixteenth(0.12 + six * 5.0 + 0.001), six - 0.001, 0.0005), "next 16th: 0 on the line, else the rest of the 16th")
	check(near(b.next_bar(0.12 + beat * 6.5), 1.5 * beat) and near(b.next_bar(0.12), 0.0), "next bar: 1.5 beats from 6.5 beats in, 0 on the downbeat")
	# across the loop: the last 16th before the end is at 0.12 + 674 * six = 105.763; from 105.77 the next one is past the
	# end (105.79), where the file goes back to 4.99: the first 16th at or after 4.99 is 0.12 + 32 * six = 5.136
	check(near(b.next_sixteenth(105.75), 105.763 - 105.75, 0.001), "105.75: the last 16th before the end is still ahead (%.3f)" % b.next_sixteenth(105.75))
	var k := ceilf((4.99 - 0.12) / six - 0.0001)
	var first_after := 0.12 + k * six
	var d_wrap: float = (105.79 - 105.77) + (first_after - 4.99)
	check(near(b.next_sixteenth(105.77), d_wrap, 0.001), "across the wrap: 105.77 → 0.02 to the end + %.3f from the loop point to its next 16th = %.3f (%.3f)" % [first_after - 4.99, d_wrap, b.next_sixteenth(105.77)])
	var kb := ceilf((4.99 - 0.12) / (4.0 * beat) - 0.0001)
	check(near(b.next_bar(105.5), (105.79 - 105.5) + (0.12 + kb * 4.0 * beat - 4.99), 0.001), "next bar across the wrap (the last bar line is 105.45): the first bar line after the loop point")
	check(near(b.wrap_t(105.79), 4.99) and near(b.wrap_t(106.0), 5.2) and near(b.wrap_t(50.0), 50.0), "wrap_t: the end goes back to the loop point")
	b.set_time(105.7)
	b.step(0.1, -1.0)
	check(near(b.music_t, 5.0) and b.wrapped and b.lap == 1, "the wall clock wraps to the loop point: 105.7 + 0.1 → 5.00, lap 1 (%.2f)" % b.music_t)
	b.step(0.1, 5.1)
	b.step(0.1, 5.2)
	check(b.healthy and near(b.music_t, 5.2), "a moving stream position after the wrap is followed")
	var h = BEAT.new({"bpm": 184.57, "t0": 0.09, "half_time": true, "len": 164.44})
	check(h.bpp() == 2 and near(h.pulse_s, 2.0 * 60.0 / 184.57, 0.0001) and near(h.sixteenth_len(), 60.0 / 184.57 / 2.0, 0.0001), "half_time: the pulse is two beats, its 16th half a beat")

	print("-- the measured beat maps")
	for n in ["town", "battle", "boss", "lowhp"]:
		var g: Dictionary = BGM.grid_of(n)
		var m = BEAT.new(g)
		var arr: Array = MAPS.MAPS[n]["beats"]
		check(m.beats.size() == arr.size() and m.beats.size() > 90 and m.i0 == MAPS.MAPS[n]["i0"], "%s: the map is packed into the clock (%d beats, downbeat [%d])" % [n, m.beats.size(), m.i0])
		var mono := true
		var dmin := 9.0
		var dmax := 0.0
		for i in range(1, arr.size()):
			var d: float = arr[i] - arr[i - 1]
			if d <= 0.0: mono = false
			dmin = minf(dmin, d)
			dmax = maxf(dmax, d)
		check(mono and dmin > 60.0 / 97.0 and dmax < 60.0 / 93.0, "%s: beats rise, every interval between 93 and 97 BPM (%.1f..%.1f)" % [n, 60.0 / dmax, 60.0 / dmin])
		check(near(m.t0, arr[m.i0]) and near(m.t0, g["t0"], 0.09), "%s: the downbeat is the map's [i0] = %.3f, within 90 ms of the measured %.2f" % [n, m.t0, g["t0"]])
		check(near(m.beat_at(m.t0), 0.0) and near(m.time_of(0.0), m.t0) and near(m.beat_at(arr[arr.size() - 1]), arr.size() - 1 - m.i0) and near(m.time_of(1.5), (arr[m.i0 + 1] + arr[m.i0 + 2]) / 2.0), "%s: beat_at / time_of follow the map (1.5 beats = midway between beats 1 and 2)" % n)
		check(arr[arr.size() - 1] >= g["len"] - 0.05 and arr[0] <= 0.5, "%s: the map covers the whole file (%.2f .. %.2f of %.2f)" % [n, arr[0], arr[arr.size() - 1], g["len"]])
	var bt = BEAT.new(BGM.grid_of("battle"))
	var i1: int = bt.i0 + 1
	var six1: float = (bt.beats[i1 + 1] - bt.beats[i1]) / 4.0
	check(near(bt.next_sixteenth(bt.beats[i1] + 0.03), six1 - 0.03, 0.001) and near(bt.next_sixteenth(bt.beats[i1]), 0.0), "battle: the 16th comes from the beat's own length (%.4f)" % six1)
	var lbt: float = bt.beats[bt.beats.size() - 1]
	check(bt.next_sixteenth(105.75) > 0.0 and bt.next_sixteenth(105.75) < 0.5 and near(bt.next_sixteenth(105.75), (105.79 - 105.75) + (bt.time_of(ceilf(bt.beat_at(4.99) / 0.25 - 0.0001) * 0.25) - 4.99), 0.001), "battle across the wrap: the rest of the file and the first 16th after 4.99 (last map beat %.2f)" % lbt)
	check(near(bt.next_bar(4.99), bt.time_of(ceilf(bt.beat_at(4.99) / 4.0) * 4.0) - 4.99, 0.001), "battle: next bar from the loop point")
	var bs = BEAT.new(BGM.grid_of("boss"))
	check(near(bs.beat_at(13.49), 20.0, 0.1), "boss: the loop point 13.49 sits on beat 20 (bar 5) of its map (%.2f)" % bs.beat_at(13.49))
	var lh = BEAT.new(BGM.grid_of("lowhp"))
	check(near(lh.beat_at(20.18), 32.0, 0.1), "lowhp: the loop point 20.18 is its bar 8 (beat %.2f)" % lh.beat_at(20.18))
	var tw = BEAT.new(BGM.grid_of("town"))
	check(near(60.0 / tw.beat_s, 96.0, 0.1) and near(tw.beat_at(75.0), 120.0 - tw.i0, 0.05), "town: 96 BPM, 30 bars in its 75 s (%.2f BPM, %.2f beats)" % [60.0 / tw.beat_s, tw.beat_at(75.0)])

	print("FAILS: %d" % fails)
	quit()
