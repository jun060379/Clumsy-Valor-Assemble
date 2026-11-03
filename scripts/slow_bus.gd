extends Node
## Bullet-time audio (prototype slowBus / witchAudio, N05): every sound — sfx, the ambience loops, the hall's small
## sounds, voices, the UI's pings — plays through one bus, "Slow". While witch time runs (arena.witch > 0) the bus is
## muffled (low-pass 20 kHz → 520 Hz), quieter (gain → 0.62), the running loops sag to 0.6× speed and every sound that
## starts plays at 0.62× (lower and slower, as createBufferSource / the -700 ¢ oscillators do); then it all recovers.
## The ramps are the prototype's setTargetAtTime time constants (on .06 / .08 / .1 s, off .18 / .2 / .25 s).
## Players join the bus by themselves when they enter the tree (node_added); one that must stay dry (the "boom" of
## the slow-down and the witch-end chirp, which the prototype plays raw) sets its bus back to Master. A player with
## the `own_pitch` meta (arena.gd's sfx pool: the combo's semitones, the jitter) sets its own pitch and applies the
## 0.62× itself.

const BUS := &"Slow"
const CUT_ON := 520.0
const CUT_OFF := 20000.0
const GAIN_ON := 0.62
const RATE_NEW := 0.62
const RATE_LOOP := 0.6

var arena
var on := false
var cut := CUT_OFF
var gain := 1.0
var loop_rate := 1.0
var idx := -1
var fx := -1                     # the low-pass's effect index on the bus
var players := {}                # AudioStreamPlayer -> [was playing, last position]


## the "Slow" bus (from default_bus_layout.tres, or made here): a low-pass into Master
static func ensure_bus() -> int:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, &"Master")
	if lp_index(i) < 0:
		var f := AudioEffectLowPassFilter.new()
		f.cutoff_hz = CUT_OFF
		AudioServer.add_bus_effect(i, f)
	return i

static func lp_index(i: int) -> int:
	for e in AudioServer.get_bus_effect_count(i):
		if AudioServer.get_bus_effect(i, e) is AudioEffectLowPassFilter: return e
	return -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	idx = ensure_bus()
	fx = lp_index(idx)
	_apply()
	get_tree().node_added.connect(_added)
	_walk(get_tree().root)

func _walk(n: Node) -> void:
	_added(n)
	for c in n.get_children(): _walk(c)

func _added(n: Node) -> void:
	if not (n is AudioStreamPlayer) or players.has(n): return
	if n.bus == &"Master" and not n.has_meta("raw"): n.bus = BUS
	players[n] = [false, 0.0]
	n.tree_exiting.connect(func(): players.erase(n), CONNECT_ONE_SHOT)

static func is_loop(st: AudioStream) -> bool:
	if st is AudioStreamWAV: return st.loop_mode != AudioStreamWAV.LOOP_DISABLED
	if st is AudioStreamOggVorbis or st is AudioStreamMP3: return st.loop
	return false

## setTargetAtTime: v → target with time constant tau (s)
static func approach(v: float, target: float, tau: float, dt: float) -> float:
	return target + (v - target) * exp(-dt / tau)

func _process(delta: float) -> void:
	if arena == null: return
	var w: bool = arena.witch > 0.0
	if w != on: on = w
	var dt := minf(delta, 0.1)
	cut = approach(cut, CUT_ON if on else CUT_OFF, 0.06 if on else 0.18, dt)
	gain = approach(gain, GAIN_ON if on else 1.0, 0.08 if on else 0.2, dt)
	loop_rate = approach(loop_rate, RATE_LOOP if on else 1.0, 0.1 if on else 0.25, dt)
	if not on and absf(loop_rate - 1.0) < 0.002: loop_rate = 1.0
	_apply()
	for p in players:
		if not is_instance_valid(p) or p.bus != BUS: continue
		var rec: Array = players[p]
		var playing: bool = p.playing
		if p.stream != null and is_loop(p.stream):
			if absf(p.pitch_scale - loop_rate) > 0.001: p.pitch_scale = loop_rate
		elif playing:
			var pos: float = p.get_playback_position()
			# a sound that just started (or restarted): at 0.62× in slow time, 1× otherwise
			if (not rec[0] or pos + 0.03 < rec[1]) and not p.has_meta("own_pitch"):
				p.pitch_scale = RATE_NEW if on else 1.0
			rec[1] = pos
		rec[0] = playing

func _apply() -> void:
	if idx < 0 or idx >= AudioServer.bus_count or AudioServer.get_bus_name(idx) != BUS:
		idx = ensure_bus()
		fx = lp_index(idx)
	var wet := cut < CUT_OFF * 0.95
	AudioServer.set_bus_effect_enabled(idx, fx, wet)      # out of slow time the bus is a plain wire
	if wet: (AudioServer.get_bus_effect(idx, fx) as AudioEffectLowPassFilter).cutoff_hz = cut
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(0.0001, gain)))
