extends RefCounted
## The title's music clock (assets/bgm/title.ogg): one time, `music_t` (s into the track, wrapping with the loop), that
## every beat of the title scene is a function of. It reads the stream's playback position (plus the time since the
## last mix, minus the output latency) while the stream is really advancing; otherwise — headless tests, 배경음 off, the
## desktop before audio starts, a dummy driver whose position never moves — a wall clock started when the title went
## live carries the same timeline, so the scene runs the same way everywhere (and deterministically in a capture).
##
## The grid, measured on the track: 184.6 BPM taken as 92 BPM half-time — pulse 0.650 s, bar 1.3005 s, 8-bar phrase
## 10.40 s, the first downbeat at 0.09 s; the track is 164.44 s and loops straight back onto the hit at 0.09.

const T0 := 0.09                 # the first downbeat (s)
const BAR := 1.3005              # s per bar (92 BPM half-time, 4 beats of 0.3251)
const PULSE := BAR / 2.0         # 0.650 s
const BEAT := BAR / 4.0          # 0.3251 s (the track's own 184.6 BPM)
const PHRASE := BAR * 8.0        # 10.40 s
const LEN := 164.44              # the loop's length (s)
## section starts in bars: A "모인다" 0, B the cut-ins 35, C the village wide 65, D ASSEMBLE 91, the outro 115
const SEC := {"A": 0, "B": 35, "C": 65, "D": 91, "out": 115}
const STALL := 0.4               # s of an unmoving stream position before the wall clock takes over

var music_t := 0.0               # s into the track, 0 .. LEN
var live := false                # the timeline runs (the title went live: at once on the desktop, on the first tap on the web)
var lap := 0                     # how many times the track has looped since going live
var wall := 0.0                  # the fallback clock (s), re-synced to the stream whenever it is healthy
var src_pos := -1.0              # the stream's last position
var stall := 0.0                 # s the position has not moved
var healthy := false             # the stream is advancing: music_t follows it
var wrapped := false             # set for one step when the loop wrapped
var hold := false                # the clock stands still (captures: a frame at an exact music_t)


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
		music_t = fposmod(pos, LEN)
		wall = music_t
	else:
		music_t = fposmod(wall, LEN)
		wall = music_t
	if music_t < prev - LEN * 0.5:
		lap += 1
		wrapped = true

## jump the timeline (captures, tests): the wall clock carries on from there
func set_time(at: float) -> void:
	music_t = fposmod(at, LEN)
	wall = music_t
	healthy = false
	stall = STALL + 1.0

## the stream's position corrected for the mix and the output latency (the value `step` wants)
static func stream_pos(ap: AudioStreamPlayer) -> float:
	if ap == null or not ap.playing: return -1.0
	return maxf(0.0, ap.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())


# ---------- the grid ----------
## the bar's start (s)
static func bar_t(n: int) -> float:
	return T0 + n * BAR

## bars since the first downbeat (−1 just before it)
func bar() -> int:
	return floori((music_t - T0) / BAR)

func bar_phase() -> float:
	return fposmod((music_t - T0) / BAR, 1.0)

func pulse_phase() -> float:
	return fposmod((music_t - T0) / PULSE, 1.0)

func beat_phase() -> float:
	return fposmod((music_t - T0) / BEAT, 1.0)

## the beat inside the bar (0..3)
func beat_in_bar() -> int:
	return posmod(floori((music_t - T0) / BEAT), 4)

func phrase() -> int:
	return floori(float(bar()) / 8.0)

## "A", "B", "C", "D" or "out" for the current music_t
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
