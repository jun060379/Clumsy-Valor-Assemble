extends Node
## 환경음 (prototype AMB / lifeAudio / hsnd / hclockSnd): wind, rain and running water as filtered-noise loops, and the
## little sounds of the world — birdsong on clear days, crickets at night, the campfire and the forge crackling, Bran's
## hammer ringing, the hall's creaking boards, the stairs' thud, the grandfather clock's tick and its hourly chime.
## Everything is synthesized once (AudioStreamWAV) and cached; the 환경음 setting (arena.ambient) mutes all of it.

const RATE := 22050
const NOISE_S := 2.0

var arena
var loops := {}                 # wind / rain / water -> AudioStreamPlayer
var gains := {}                 # current linear gain of each loop (setTargetAtTime)
var master := 0.0
var pool: Array = []
var cache := {}
var noise := PackedFloat32Array()
var queue: Array = []           # [ms left, stream, gain]
var last := {}                  # due() timers
var tick_ph := -1
var hr := -1


func _ready() -> void:
	for i in 6:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		pool.append(ap)

func _build() -> void:
	if not loops.is_empty(): return
	var n := int(RATE * NOISE_S)
	noise.resize(n)
	for i in n: noise[i] = randf() * 2.0 - 1.0
	for k in [["wind", "bandpass", 420.0, 0.6], ["rain", "highpass", 1400.0, 0.4], ["water", "lowpass", 900.0, 0.5]]:
		var ap := AudioStreamPlayer.new()
		ap.stream = _wav(_filter(noise, k[1], k[2], k[3], true), true)
		ap.volume_db = -80.0
		add_child(ap)
		ap.play()
		loops[k[0]] = ap
		gains[k[0]] = 0.0

# ---------- synthesis ----------
## RBJ biquad over a buffer; `loop` runs it twice so the end meets the start without a click
static func _filter(src: PackedFloat32Array, type: String, f: float, q: float, loop := false) -> PackedFloat32Array:
	var w0 := TAU * f / RATE
	var al := sin(w0) / (2.0 * q)
	var cw := cos(w0)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	match type:
		"lowpass":
			b0 = (1.0 - cw) / 2.0; b1 = 1.0 - cw; b2 = b0
		"highpass":
			b0 = (1.0 + cw) / 2.0; b1 = -(1.0 + cw); b2 = b0
		_:
			b0 = al; b1 = 0.0; b2 = -al
	var a0 := 1.0 + al
	var a1 := -2.0 * cw
	var a2 := 1.0 - al
	b0 /= a0; b1 /= a0; b2 /= a0; a1 /= a0; a2 /= a0
	var out := PackedFloat32Array()
	out.resize(src.size())
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for pass_i in (2 if loop else 1):
		for i in src.size():
			var x := src[i]
			var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
			x2 = x1; x1 = x; y2 = y1; y1 = y
			out[i] = y
	return out

static func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w

## an oscillator sweeping f0 -> f1 (exponential) with an attack and an exponential fall to silence at dur;
## q > 0 sends it through a band-pass at the sweep's middle x1.6 (hsnd)
func tone_stream(f0: float, f1: float, dur: float, type: String, atk := 0.008, q := 0.0) -> AudioStreamWAV:
	var key := "t%d_%d_%d_%s_%d_%d" % [int(f0), int(f1), int(dur * 1000.0), type, int(atk * 1000.0), int(q * 10.0)]
	if cache.has(key): return cache[key]
	var n := int(RATE * (dur + 0.02))
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := f0 * pow(f1 / f0, minf(1.0, t / dur))
		ph = fposmod(ph + f / RATE, 1.0)
		var v := 0.0
		match type:
			"square": v = 1.0 if ph < 0.5 else -1.0
			"triangle": v = 1.0 - 4.0 * absf(ph - 0.5)
			"sawtooth": v = ph * 2.0 - 1.0
			_: v = sin(ph * TAU)
		var env := t / atk if t < atk else (pow(0.0001, (t - atk) / maxf(0.001, dur - atk)) if t < dur else 0.0)
		s[i] = v * env
	if q > 0.0: s = _filter(s, "bandpass", (f0 + f1) / 2.0 * 1.6, q)
	var w := _wav(s)
	cache[key] = w
	return w

## a 30 ms crackle: a scrap of noise through a band-pass (tick)
func tick_stream(f: float) -> AudioStreamWAV:
	var fb := int(f / 500.0) * 500
	var key := "k%d" % fb
	if cache.has(key): return cache[key]
	var n := int(RATE * 0.04)
	var s := PackedFloat32Array()
	s.resize(n)
	var o := randi() % maxi(1, noise.size() - n)
	for i in n:
		var t := float(i) / RATE
		s[i] = noise[o + i] * pow(0.0001, minf(1.0, t / 0.03))
	var w := _wav(_filter(s, "bandpass", float(fb), 1.0 / sqrt(2.0)))
	cache[key] = w
	return w

func play(st: AudioStream, vol: float, delay_ms := 0.0) -> void:
	if delay_ms > 0.0:
		queue.append([delay_ms, st, vol])
		return
	var best = pool[0]
	for ap in pool:
		if not ap.playing:
			best = ap
			break
	best.stream = st
	best.volume_db = linear_to_db(maxf(0.00001, vol))
	best.pitch_scale = 0.62 if arena.witch > 0.0 else 1.0
	best.play()

## hsnd: the hall's small sounds (creaks, thuds, the clock), muted with 환경음
func hsnd(f0: float, f1: float, dur: float, vol: float, type := "sine", q := 0.8, delay_ms := 0.0) -> void:
	if not arena.ambient: return
	play(tone_stream(f0, f1, dur, type, 0.012, q), vol, delay_ms)

func creak() -> void:
	var b := 150.0 + randf() * 90.0
	hsnd(b, b * 0.78, 0.22 + randf() * 0.12, 0.035, "sawtooth", 3.0)
	hsnd(b * 2.1, b * 1.6, 0.16, 0.012, "sawtooth", 4.0)

func _due(k: String, ms: float, dt: float) -> bool:
	last[k] = float(last.get(k, 0.0)) - dt
	if last[k] <= 0.0:
		last[k] = ms
		return true
	return false

static func _ear(P: Vector2, x: float, y: float, r: float) -> float:
	return clampf(1.0 - Vector2(P.x - x, (P.y - y) * 1.5).length() / r, 0.0, 1.0)

# ---------- every frame (lifeAudio: it runs under menus too) ----------
func _process(delta: float) -> void:
	if arena == null or arena.player == null: return
	step(minf(delta * 1000.0, 100.0))

func step(dt: float) -> void:
	for q in queue: q[0] -= dt
	var due_now := queue.filter(func(q): return q[0] <= 0.0)
	queue = queue.filter(func(q): return q[0] > 0.0)
	for q in due_now: play(q[1], q[2])
	if not arena.ambient:
		queue.clear()
		master = maxf(0.0, master - dt / 200.0 * master - 0.001)
		for k in loops: loops[k].volume_db = linear_to_db(maxf(0.00001, gains[k] * master))
		return
	_build()
	var P: Vector2 = arena.player.position
	var lk: String = arena.level_kind()
	var L = arena.level
	var wx: String = arena.weather
	var T: Dictionary = arena.tod_now()
	var sun: float = T["sun"]
	var sky: Color = T["sky"]
	if lk == "dungeon":
		sun = 0.0
		sky.a = 0.72        # the cave keeps the 22:30 sky (todNow)
	if lk == "hall": sun = 0.0
	var nk := clampf((sky.a - 0.33) / 0.33, 0.0, 1.0)
	master = lerpf(master, 0.6, 1.0 - exp(-dt / 300.0))
	var IN := 0.3 if lk == "hall" else 1.0
	var gust := 0.0
	if lk == "town" and L.get("life") != null: gust = L.life.gust
	var want := {
		"wind": (0.012 + gust * 0.045 + (0.02 if wx != "clear" else 0.0)) * IN,
		"rain": (0.07 * (0.45 if IN < 1.0 else 1.0)) if wx == "rain" else 0.0,
		"water": (0.09 * _ear(P, L.HDOOR, L.LOWF - 60.0, 420.0) + 0.05 * _ear(P, (L.RIV0 + L.RIV1) / 2.0, L.LOWF, 500.0)) if lk == "town" else 0.0,
	}
	var tau := {"wind": 400.0, "rain": 600.0, "water": 300.0}
	for k in loops:
		gains[k] = lerpf(gains[k], want[k], 1.0 - exp(-dt / tau[k]))
		loops[k].volume_db = linear_to_db(maxf(0.00001, gains[k] * master))
	var m := master
	if wx == "clear" and sun > 0.3 and _due("bird", 1500.0 + randf() * 4000.0, dt):
		var b := 2400.0 + randf() * 1200.0
		var bs := tone_stream(b, b * 1.35, 0.07, "sine")
		for i in 2 + randi() % 3: play(bs, 0.025 * m, i * 110.0)
	if nk > 0.5 and wx != "snow" and _due("cricket", 350.0 + randf() * 600.0, dt):
		var cs := tone_stream(4300.0, 4250.0, 0.025, "sine")
		for i in 3: play(cs, 0.01 * nk * m, i * 45.0)
	var fv := 0.0
	if lk == "hall" and L.has_method("fire_xs"):
		for x in L.fire_xs(): fv = maxf(fv, _ear(P, x + 120.0, L.G, 560.0))
	elif lk == "town":
		fv = maxf(_ear(P, 4350.0 + 27.0 * L.PK, L.G, 520.0), _ear(P, 7348.0, L.LOWF, 420.0))
		var hv := _ear(P, 7348.0, L.LOWF, 600.0)
		if hv > 0.02 and _due("hammer", 1500.0, dt):
			play(tone_stream(880.0, 860.0, 0.35, "triangle"), 0.05 * hv * m)
			play(tone_stream(1760.0, 1700.0, 0.25, "sine"), 0.025 * hv * m)
	if fv > 0.02 and randf() < dt / 1000.0 * 14.0 * fv:
		play(tick_stream(1800.0 + randf() * 2500.0), 0.12 * fv * m)
	if lk == "hall": _clock(dt, P, L)
	else:
		tick_ph = -1
		hr = -1

## hclockSnd: on the ground floor the grandfather clock ticks every second and strikes the hours
func _clock(_dt: float, P: Vector2, L) -> void:
	if int(L.fl) != 0 or not L.has_method("clock_x"):
		hr = -1
		return
	var cx = L.clock_x()
	if cx == null: return
	var ear := maxf(0.0, 1.0 - absf(P.x - cx) / 700.0)
	var ph := int(Time.get_ticks_msec() / 1000)
	if ph != tick_ph:
		tick_ph = ph
		if ear > 0.05:
			hsnd(2400.0 if ph % 2 else 2000.0, 2300.0 if ph % 2 else 1900.0, 0.03, 0.012 * ear, "square", 6.0)
	var h := int(floor(fposmod(arena.tod_h, 24.0)))
	if hr == -1: hr = h
	if h != hr:
		hr = h
		var n := ((h + 11) % 12) + 1
		var v := 0.02 + 0.05 * ear
		for i in n:
			hsnd(587.0, 585.0, 1.8, v, "sine", 0.6, i * 1300.0)
			hsnd(1174.0, 1170.0, 1.2, v * 0.4, "sine", 0.6, i * 1300.0)
