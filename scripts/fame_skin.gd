extends RefCounted
## Fonts and small drawing / sound helpers for the guild system's screens (fame_fx.gd, fame_book.gd).
## Every font falls back on a tiny symbol subset (FameSymbols: ✓ › Ⅰ–Ⅳ █ ▓ ▒ ░ ╳ ⚠, from Noto Sans CJK KR) for the glyphs
## Black Han Sans and the Noto Sans KR subset lack. Serif = Noto Serif CJK KR Black, Hangul KS X 1001 subset.

const _BHS := preload("res://assets/fonts/BlackHanSans.woff")
const _NK := preload("res://assets/fonts/NotoSansKR-Black.otf")
const _NB := preload("res://assets/fonts/NotoSansKR-Bold.otf")
const _AN := preload("res://assets/fonts/Anton.woff2")
const _SYM := preload("res://assets/fonts/FameSymbols.otf")
const _SERIF := preload("res://assets/fonts/NotoSerifKR-Black-sub.otf")

static var _c := {}


static func _ff(key: String, base: FontFile, fb: Array) -> Font:
	if not _c.has(key):
		var f: FontFile = base.duplicate()
		f.fallbacks = fb
		_c[key] = f
	return _c[key]

static func bhs() -> Font:
	return _ff("bhs", _BHS, [_NK, _SYM])

static func noto() -> Font:
	return _ff("nb", _NB, [_SYM])

static func noto_k() -> Font:
	return _ff("nk", _NK, [_SYM])

static func serif() -> Font:
	return _ff("serif", _SERIF, [_NK, _SYM])

static func anton(italic := false, spacing := 0) -> Font:
	var key := "an%d_%d" % [int(italic), spacing]
	if not _c.has(key):
		var v := FontVariation.new()
		v.base_font = _ff("an", _AN, [_NB, _SYM])
		if italic: v.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		v.spacing_glyph = spacing
		_c[key] = v
	return _c[key]

static func spaced(f: Font, sp: int) -> Font:
	var key := "sp%d_%d" % [f.get_instance_id(), sp]
	if not _c.has(key):
		var v := FontVariation.new()
		v.base_font = f
		v.spacing_glyph = sp
		_c[key] = v
	return _c[key]

static func tw(f: Font, s: String, fs: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


# ---------- easing (CSS) ----------
static func bez(x1: float, y1: float, x2: float, y2: float, u: float) -> float:
	if u <= 0.0: return 0.0
	if u >= 1.0: return 1.0
	var lo := 0.0
	var hi := 1.0
	var s := u
	for i in 20:
		s = (lo + hi) * 0.5
		var x := 3.0 * x1 * (1.0 - s) * (1.0 - s) * s + 3.0 * x2 * (1.0 - s) * s * s + s * s * s
		if x < u: lo = s
		else: hi = s
	return 3.0 * y1 * (1.0 - s) * (1.0 - s) * s + 3.0 * y2 * (1.0 - s) * s * s + s * s * s

## EZ cubic-bezier(.2,.9,.25,1)
static func ez(u: float) -> float:
	return bez(0.2, 0.9, 0.25, 1.0, clampf(u, 0.0, 1.0))

## BK cubic-bezier(.2,1.5,.4,1)
static func bk(u: float) -> float:
	return bez(0.2, 1.5, 0.4, 1.0, clampf(u, 0.0, 1.0))

## IN cubic-bezier(.5,0,.7,.4)-ish (ease in)
static func ein(u: float) -> float:
	return bez(0.5, 0.0, 0.75, 0.0, clampf(u, 0.0, 1.0))

## progress of a timed animation: start at t0, lasting d
static func k(t: float, t0: float, d: float) -> float:
	return clampf((t - t0) / d, 0.0, 1.0)


# ---------- shapes ----------
static func para(ci, r: Rect2, sk: float, c: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(sk, 0), Vector2(r.end.x + sk, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), c)

static func clip(r: Rect2, pct: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pct:
		out.append(r.position + Vector2(r.size.x * p[0] / 100.0, r.size.y * p[1] / 100.0))
	return out

## a small padlock (the fonts lack 🔒)
static func lock(ci, p: Vector2, s: float, c: Color) -> void:
	ci.draw_arc(p + Vector2(s * 0.5, s * 0.42), s * 0.27, PI, TAU, 10, c, maxf(1.2, s * 0.13))
	ci.draw_rect(Rect2(p + Vector2(s * 0.12, s * 0.42), Vector2(s * 0.76, s * 0.55)), c)

## a sealed envelope (✉)
static func envelope(ci, r: Rect2, c: Color, seal := Color("#d52a36")) -> void:
	ci.draw_rect(r, c)
	ci.draw_polyline(PackedVector2Array([r.position, r.position + Vector2(r.size.x / 2.0, r.size.y * 0.58), Vector2(r.end.x, r.position.y)]), Color(0, 0, 0, 0.55), 1.2, true)
	ci.draw_circle(r.position + Vector2(r.size.x / 2.0, r.size.y * 0.58), r.size.y * 0.18, seal)

## repeating dots (radial-gradient dot grid): one small tile, repeated (the canvas item needs texture_repeat on)
static func dots(ci, r: Rect2, step: float, rad: float, c: Color, off := Vector2.ZERO) -> void:
	var key := "dot%d_%d" % [int(step * 10.0), int(rad * 10.0)]
	if not _c.has(key):
		var n := int(step)
		var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var h := n / 2.0
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - h, y + 0.5 - h).length()
				im.set_pixel(x, y, Color(1, 1, 1, clampf(rad + 0.5 - d, 0.0, 1.0)))
		_c[key] = ImageTexture.create_from_image(im)
	ci.draw_texture_rect_region(_c[key], r, Rect2(r.position - off, r.size), c)

## a text that fits a box width (shrinks the size until it does)
static func fit_size(f: Font, s: String, fs: int, w: float, mn := 9) -> int:
	while fs > mn and tw(f, s, fs) > w: fs -= 1
	return fs


# ---------- tiny synth (the prototype's tbeep / uiTone / paperSfx) ----------
static var _snd := {}
static var _pool: Array = []

static func _wav(key: String, maker: Callable) -> AudioStreamWAV:
	if not _snd.has(key):
		var data: PackedByteArray = maker.call()
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = 22050
		w.stereo = false
		w.data = data
		_snd[key] = w
	return _snd[key]

static func _pcm(samples: PackedFloat32Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(samples.size() * 2)
	for i in samples.size():
		b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	return b

## f Hz, d seconds; type square / sine / saw / tri; exponential decay like the prototype's gain ramp
static func beep_wav(f: float, d: float, ty := "square") -> AudioStreamWAV:
	return _wav("b%s_%d_%d" % [ty, int(f), int(d * 1000.0)], func():
		var n := int(22050.0 * (d + 0.02))
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var tt := i / 22050.0
			var ph := fmod(tt * f, 1.0)
			var v := 0.0
			match ty:
				"sine": v = sin(ph * TAU)
				"saw": v = ph * 2.0 - 1.0
				"tri": v = 4.0 * absf(ph - 0.5) - 1.0
				_: v = 1.0 if ph < 0.5 else -1.0
			var env := exp(-tt / maxf(0.005, d) * 5.0) * minf(1.0, tt / 0.004)
			out[i] = v * env * 0.6
		return _pcm(out))

static func noise_wav(d: float) -> AudioStreamWAV:
	return _wav("n%d" % int(d * 1000.0), func():
		var n := int(22050.0 * d)
		var out := PackedFloat32Array()
		out.resize(n)
		for i in n:
			var kk := float(i) / n
			out[i] = (randf() * 2.0 - 1.0) * pow(1.0 - kk, 1.6) * (kk / 0.08 if kk < 0.08 else 1.0) * 0.5
		return _pcm(out))

static func play(host: Node, st: AudioStream, vol := 0.05) -> void:
	if _pool.is_empty() or not is_instance_valid(_pool[0]):
		_pool.clear()
		for i in 4:
			var ap := AudioStreamPlayer.new()
			host.add_child(ap)
			_pool.append(ap)
	var best: AudioStreamPlayer = _pool[0]
	for ap in _pool:
		if not ap.playing:
			best = ap
			break
	best.stream = st
	best.volume_db = linear_to_db(maxf(0.002, vol * 6.0))
	best.play()
