extends RefCounted
## A music clock: one time, `music_t` (s into a track, wrapping with its loop), that everything riding on the music is
## a function of — the title scene's every move, and the sound effects' 16th-note snaps in the dungeon. It reads the
## stream's playback position (plus the time since the last mix, minus the output latency) while the stream is really
## advancing; otherwise — headless tests, 배경음 off, the desktop before audio starts, a dummy driver whose position
## never moves — a wall clock started with the track carries the same timeline, so a scene runs the same way
## everywhere (and deterministically in a capture).
##
## One instance per track. The grid is set with `setup()` (or `new(grid)`): {bpm, t0, half_time, len, loop} — a
## constant grid — plus an optional measured beat map (`beats`: the time of every beat, `i0`: the downbeat's index;
## scripts/beat_maps.gd, from tools/make_beat_maps.py) for the dungeon tracks, whose tempo ramps a couple of BPM over
## their length. The default grid (no setup) is the title's, kept in the constants below, which the title scene and
## its static helpers (bar_t / sec_t / section_at) read directly:
## 184.57 BPM taken as 92 BPM half-time — pulse 0.650 s, bar 1.3005 s, 8-bar phrase 10.40 s, the first downbeat at
## 0.09 s; the track is 164.44 s and loops straight back onto the hit at 0.09. Section helpers are title-only.

const T0 := 0.09                 # the first downbeat (s)
const BAR := 1.3005              # s per bar (92 BPM half-time, 4 beats of 0.3251)
const PULSE := BAR / 2.0         # 0.650 s
const BEAT := BAR / 4.0          # 0.3251 s (the track's own 184.6 BPM)
const PHRASE := BAR * 8.0        # 10.40 s
const LEN := 164.44              # the loop's length (s)
## section starts in bars: A "모인다" 0, B the cut-ins 35, C the village wide 65, D ASSEMBLE 91, the outro 115
const SEC := {"A": 0, "B": 35, "C": 65, "D": 91, "out": 115}
const STALL := 0.4               # s of an unmoving stream position before the wall clock takes over
const BPB := 4                   # beats per bar

var music_t := 0.0               # s into the track, 0 .. len_s
var live := false                # the timeline runs (the title went live: at once on the desktop, on the first tap on the web)
var lap := 0                     # how many times the track has looped since going live
var wall := 0.0                  # the fallback clock (s), re-synced to the stream whenever it is healthy
var src_pos := -1.0              # the stream's last position
var stall := 0.0                 # s the position has not moved
var healthy := false             # the stream is advancing: music_t follows it
var wrapped := false             # set for one step when the loop wrapped
var hold := false                # the clock stands still (captures: a frame at an exact music_t)

# ---- the grid (the title's unless setup() is called) ----
var t0 := T0                     # the first downbeat (s)
var bpm := 184.57                # the track's own tempo (a nominal when a beat map is set)
var beat_s := BEAT               # s per beat of the track's own BPM
var pulse_s := PULSE             # the pulse the scene and the sfx 16th grid ride: the beat, or two beats half-time
var half_time := true            # the pulse is two beats
var len_s := LEN                 # the file's length (s)
var loop_s := 0.0                # where the stream goes back to at the end (s; the .import's loop_offset)
var beats := PackedFloat32Array()   # a measured beat map (s of every beat, rising), empty = the constant grid
var i0 := 0                      # the downbeat's index in the map


func _init(grid := {}) -> void:
	if not grid.is_empty(): setup(grid)

## the grid: {bpm, t0, half_time (false), len, loop (0), beats (an array of beat times, optional), i0 (0)}
func setup(g: Dictionary) -> void:
	bpm = float(g.get("bpm", 184.57))
	t0 = float(g.get("t0", 0.0))
	half_time = bool(g.get("half_time", false))
	len_s = float(g.get("len", 0.0))
	loop_s = float(g.get("loop", 0.0))
	beat_s = 60.0 / bpm
	pulse_s = beat_s * (2.0 if half_time else 1.0)
	beats = PackedFloat32Array(g.get("beats", []))
	i0 = int(g.get("i0", 0))
	if beats.size() >= 2:
		i0 = clampi(i0, 0, beats.size() - 1)
		t0 = beats[i0]
		beat_s = (beats[beats.size() - 1] - beats[0]) / float(beats.size() - 1)
		bpm = 60.0 / beat_s
		pulse_s = beat_s * (2.0 if half_time else 1.0)

## the title goes live: the timeline starts at 0 (the stream starts with it)
func start(at := 0.0) -> void:
	live = true
	lap = 0
	music_t = at
	wall = at
	src_pos = -1.0
	stall = 0.0
	healthy = false
	wrapped = false

func stop() -> void:
	live = false

## a file time past the end comes back in at the loop point (the title and the town loop to 0)
func wrap_t(t: float) -> float:
	if len_s <= 0.0: return t
	if t >= 0.0 and t < len_s: return t
	if t < 0.0: return fposmod(t, len_s)
	var span := len_s - loop_s
	if span <= 0.0: return fposmod(t, len_s)
	return loop_s + fposmod(t - len_s, span)

## one frame: dt (s), pos = the stream's playback position (s) or -1 when nothing plays
func step(dt: float, pos := -1.0) -> void:
	wrapped = false
	if not live or hold: return
	var prev := music_t
	wall += dt
	if pos >= 0.0:
		if absf(pos - src_pos) > 0.0005:
			# the position moved: the stream is alive (its first value alone proves nothing — a dummy driver sits at 0)
			if src_pos >= 0.0: healthy = true
			stall = 0.0
			src_pos = pos
		else:
			stall += dt
			if stall > STALL: healthy = false
	else:
		healthy = false
		src_pos = -1.0
	if pos >= 0.0 and healthy:
		music_t = wrap_t(pos)
		wall = music_t
	else:
		music_t = wrap_t(wall)
		wall = music_t
	if music_t < prev - (len_s - loop_s) * 0.5:
		lap += 1
		wrapped = true

## jump the timeline (captures, tests): the wall clock carries on from there
func set_time(at: float) -> void:
	music_t = wrap_t(at)
	wall = music_t
	healthy = false
	stall = STALL + 1.0

## the stream's position corrected for the mix and the output latency (the value `step` wants: what is heard now,
## for things seen now)
static func stream_pos(ap: AudioStreamPlayer) -> float:
	if ap == null or not ap.playing: return -1.0
	return maxf(0.0, ap.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())

## the stream's position at the mix: what a sound started now plays together with (the output latency delays both
## the same way), for the sound effects' snaps
static func mix_pos(ap: AudioStreamPlayer) -> float:
	if ap == null or not ap.playing: return -1.0
	return maxf(0.0, ap.get_playback_position() + AudioServer.get_time_since_last_mix())


# ---------- the grid ----------
## beats since the downbeat at time t (fractional; negative before it): the map when there is one, else t0 + n·beat
func beat_at(t: float) -> float:
	var n := beats.size()
	if n < 2: return (t - t0) / beat_s
	if t <= beats[0]: return (t - beats[0]) / (beats[1] - beats[0]) - i0
	if t >= beats[n - 1]: return (t - beats[n - 1]) / (beats[n - 1] - beats[n - 2]) + (n - 1 - i0)
	var i := beats.bsearch(t) - 1          # beats[i] <= t < beats[i + 1]
	i = clampi(i, 0, n - 2)
	return i - i0 + (t - beats[i]) / (beats[i + 1] - beats[i])

## the time of (fractional) beat b since the downbeat
func time_of(b: float) -> float:
	var n := beats.size()
	if n < 2: return t0 + b * beat_s
	var x := b + i0
	if x <= 0.0: return beats[0] + x * (beats[1] - beats[0])
	if x >= n - 1: return beats[n - 1] + (x - (n - 1)) * (beats[n - 1] - beats[n - 2])
	var i := int(floor(x))
	return beats[i] + (x - i) * (beats[i + 1] - beats[i])

## s per beat around time t
func beat_len_at(t: float) -> float:
	var n := beats.size()
	if n < 2: return beat_s
	var i := clampi(beats.bsearch(t) - 1, 0, n - 2)
	return beats[i + 1] - beats[i]

## beats per pulse (two half-time)
func bpp() -> int:
	return 2 if half_time else 1

## the pulse's 16th, in beats
func six_b() -> float:
	return bpp() / 4.0

## s of one 16th of the pulse grid at the current time (title 0.1625, the 95.7 tracks ~0.157)
func sixteenth_len() -> float:
	return beat_len_at(music_t) * six_b()

## s of one bar at the current time
func bar_len() -> float:
	return beat_len_at(music_t) * BPB

## seconds from `now` (music time; the current time when omitted) to the next 16th of the pulse grid — 0 when `now`
## sits on one; across the loop: the rest of the file, then the first 16th at or after the loop point
func next_sixteenth(now := -1.0) -> float:
	return _next(now, six_b())

## seconds from `now` to the next bar line, the same way
func next_bar(now := -1.0) -> float:
	return _next(now, float(BPB))

## the next grid line of `unit` beats
func _next(now: float, unit: float) -> float:
	if now < 0.0: now = music_t
	var k := beat_at(now) / unit
	var nk := ceilf(k - 1.0e-4)
	if absf(nk - k) <= 1.0e-4: return 0.0   # on the line
	var tn := time_of(nk * unit)
	if len_s > 0.0 and tn > len_s:
		var nk2 := ceilf(beat_at(loop_s) / unit - 1.0e-4)
		return (len_s - now) + (time_of(nk2 * unit) - loop_s)
	return tn - now

## the bar's start (s) on the title's grid
static func bar_t(n: int) -> float:
	return T0 + n * BAR

## bars since the first downbeat (−1 just before it)
func bar() -> int:
	return floori(beat_at(music_t) / BPB)

func bar_phase() -> float:
	return fposmod(beat_at(music_t) / BPB, 1.0)

func pulse_phase() -> float:
	return fposmod(beat_at(music_t) / bpp(), 1.0)

func beat_phase() -> float:
	return fposmod(beat_at(music_t), 1.0)

## the beat inside the bar (0..3)
func beat_in_bar() -> int:
	return posmod(floori(beat_at(music_t)), BPB)

func phrase() -> int:
	return floori(float(bar()) / 8.0)

## "A", "B", "C", "D" or "out" for the current music_t (the title)
func section() -> String:
	return section_at(music_t)

static func section_at(t: float) -> String:
	var b := floori((t - T0) / BAR)
	if b < SEC["B"]: return "A"
	if b < SEC["C"]: return "B"
	if b < SEC["D"]: return "C"
	if b < SEC["out"]: return "D"
	return "out"

## the section's first downbeat (s)
static func sec_t(name: String) -> float:
	return bar_t(SEC[name])

## a 0..1..0 bump that peaks right on a phase of 0 and is gone by `w` of the cycle (a beat's hop)
static func bump(phase: float, w := 0.35) -> float:
	var u := phase / w
	if u >= 1.0: return 0.0
	return sin(u * PI)
