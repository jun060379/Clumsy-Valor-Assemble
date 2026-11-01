extends RefCounted
## UI motion kit: the prototype's CSS / WAAPI timing in immediate-mode drawing.
##   · the named easings (--bk, --ez, --mv, IN, steps) as exact cubic-beziers
##   · kf(): a CSS @keyframes / WAAPI keyframe list evaluated at a time, per-segment easing, fill both
##   · Tr: CSS transitions — ask for a value every frame, get it eased toward the latest target
##   · Clock: a per-owner stopwatch of named one-shot animations (start("pop") ... at("pop") -> ms since)
##   · web test hook: window.cvaTS(v) sets the time scale at once (screenshots of motion mid-way; 0 freezes)

const UI := preload("res://scripts/ui_kit.gd")

# ---------- easings ----------
## named curves: [x1, y1, x2, y2]
const E := {
	"bk": [0.2, 1.5, 0.4, 1.0],       # --bk overshoot
	"bk4": [0.2, 1.4, 0.4, 1.0],
	"bk6": [0.2, 1.6, 0.4, 1.0],
	"ez": [0.16, 1.0, 0.3, 1.0],      # --ez
	"ez2": [0.2, 0.9, 0.25, 1.0],     # sortie / fame_ui EZ
	"mv": [0.7, 0.0, 0.2, 1.0],       # --mv
	"in": [0.6, 0.0, 0.9, 0.4],       # IN
	"out": [0.2, 0.8, 0.2, 1.0],
	"ease": [0.25, 0.1, 0.25, 1.0],
	"ease-in": [0.42, 0.0, 1.0, 1.0],
	"ease-out": [0.0, 0.0, 0.58, 1.0],
	"ease-in-out": [0.42, 0.0, 0.58, 1.0],
	"linear": [0.0, 0.0, 1.0, 1.0],
}

## eased u (0..1) for a named curve or an explicit [x1,y1,x2,y2]
static func ez(name, u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var c: Array = E.get(name, E["linear"]) if name is String else name
	if c[0] == 0.0 and c[1] == 0.0 and c[2] == 1.0 and c[3] == 1.0: return u
	return UI.bez(c[0], c[1], c[2], c[3], u)

## CSS steps(n, end)
static func steps(n: int, u: float) -> float:
	return floorf(clampf(u, 0.0, 0.9999) * n) / n

## progress of a one-shot: t ms since it began, delay, duration -> eased 0..1 (fill both)
static func p(t: float, delay: float, dur: float, name = "linear") -> float:
	return ez(name, (t - delay) / maxf(1.0, dur))

## linear 0..1 with no easing
static func lin(t: float, delay: float, dur: float) -> float:
	return clampf((t - delay) / maxf(1.0, dur), 0.0, 1.0)

# ---------- keyframes ----------
## kf(t, stops, dur, delay, ease): stops = [[offset, value], ...] (value float / Vector2 / Color / Array of floats),
## offsets 0..1 ascending; the easing applies per segment (CSS animation-timing-function). A stop may carry its own
## easing as a third entry (WAAPI keyframe easing), used for the segment that starts at it.
static func kf(t: float, stops: Array, dur: float, delay := 0.0, ezn = "linear"):
	var u := clampf((t - delay) / maxf(1.0, dur), 0.0, 1.0)
	if u <= stops[0][0]: return stops[0][1]
	for i in range(stops.size() - 1):
		var a: Array = stops[i]
		var b: Array = stops[i + 1]
		if u <= b[0]:
			var span: float = b[0] - a[0]
			var lu: float = (u - a[0]) / span if span > 0.0 else 1.0
			var e = a[2] if a.size() > 2 else ezn
			return mix(a[1], b[1], ez(e, lu))
	return stops[stops.size() - 1][1]

static func mix(a, b, k: float):
	if a is Array:
		var o := []
		for i in a.size(): o.append(lerpf(a[i], b[i], k))
		return o
	if a is float or a is int: return lerpf(float(a), float(b), k)
	return a.lerp(b, k)

## a looping keyframe set (infinite CSS animations): alternate = ping-pong
static func loop(t: float, stops: Array, dur: float, ezn = "ease-in-out", alternate := false, delay := 0.0):
	var tt := maxf(0.0, t - delay)
	if alternate:
		var n := int(tt / dur)
		var f := fmod(tt, dur)
		if n % 2 == 1: f = dur - f
		return kf(f, stops, dur, 0.0, ezn)
	return kf(fmod(tt, dur), stops, dur, 0.0, ezn)

## 0..1..0 pulse of an infinite "50% {…}" animation
static func pulse(t: float, dur: float, ezn = "ease-in-out") -> float:
	return kf(fmod(maxf(0.0, t), dur), [[0.0, 0.0], [0.5, 1.0], [1.0, 0.0]], dur, 0.0, ezn)

# ---------- transitions ----------
## CSS transition store: tr(key, target, dur, ease) returns the value eased from where it was when the target changed.
## Keep one Tr per owner; call step(dt) once a frame.
class Tr:
	var v := {}             # key -> [from, to, t, dur, ease]
	var clock := 0.0
	func step(dt: float) -> void:
		clock += dt
	func get_v(key, target, dur: float, ezn = "ease"):
		if not v.has(key):
			v[key] = [target, target, -1e9, dur, ezn]
			return target
		var s: Array = v[key]
		if s[1] != target:
			var cur = _now(s)
			v[key] = [cur, target, clock, dur, ezn]
			s = v[key]
		return _now(s)
	func _now(s: Array):
		var u: float = clampf((clock - s[2]) / maxf(1.0, s[3]), 0.0, 1.0)
		if u >= 1.0: return s[1]
		return UIA_mix(s[0], s[1], UIA_ease(s[4], u))
	## a value snaps (no transition) next time
	func snap(key) -> void:
		v.erase(key)
	func clear() -> void:
		v.clear()
	func busy() -> bool:
		for k in v:
			if clock - v[k][2] < v[k][3]: return true
		return false
	static func UIA_ease(n, u: float) -> float:
		u = clampf(u, 0.0, 1.0)
		var c: Array = E.get(n, E["linear"]) if n is String else n
		return UI.bez(c[0], c[1], c[2], c[3], u)
	static func UIA_mix(a, b, k: float):
		if a is Array:
			var o := []
			for i in a.size(): o.append(lerpf(a[i], b[i], k))
			return o
		if a is float or a is int: return lerpf(float(a), float(b), k)
		return a.lerp(b, k)


# ---------- springs (fame_ui.js spring(): resp = period in s, damp = damping ratio) ----------
class Spring:
	var x := 0.0
	var v := 0.0
	var t := 0.0
	var resp := 0.45
	var damp := 1.0
	func _init(x0 := 0.0, r := 0.45, d := 1.0) -> void:
		x = x0
		t = x0
		resp = r
		damp = d
	func to(target: float, kick := 0.0) -> void:
		t = target
		v += kick
	func snap(val: float) -> void:
		x = val
		t = val
		v = 0.0
	## dt in ms
	func step(dt: float) -> float:
		var d := minf(0.05, dt / 1000.0)
		var k := pow(TAU / resp, 2.0)
		var c := 4.0 * PI * damp / resp
		var h := d / 4.0
		for i in 4:
			v += (-k * (x - t) - c * v) * h
			x += v * h
		return x

# ---------- one-shot clocks ----------
class Clock:
	var t := {}             # name -> ms since start
	func start(n: String, at := 0.0) -> void:
		t[n] = at
	func step(dt: float) -> void:
		for k in t: t[k] += dt
	func at(n: String) -> float:
		return t.get(n, 1e9)
	func has(n: String) -> bool:
		return t.has(n)
	func stop(n: String) -> void:
		t.erase(n)


# ---------- group pen ----------
## A drawing proxy with a group transform and opacity, so immediate-mode code can be moved and faded as a CSS element:
## pen.draw_*(...) forwards to the canvas item with pen.xf composed into every transform and pen.a multiplied into
## every colour. Code that draws through "_ci.draw_*" gets element-level motion by pointing _ci at a Pen.
class Pen:
	var ci: CanvasItem
	var xf := Transform2D.IDENTITY
	var a := 1.0
	var mod := Color(1, 1, 1, 1)
	func _init(c: CanvasItem) -> void:
		ci = c
	## start a group: its transform (about nothing; build it with UIA.xf) and its opacity
	func group(m: Transform2D, alpha := 1.0) -> void:
		xf = m
		a = alpha
		ci.draw_set_transform_matrix(xf)
	func reset() -> void:
		group(Transform2D.IDENTITY, 1.0)
	func c(col: Color) -> Color:
		return Color(col.r * mod.r, col.g * mod.g, col.b * mod.b, col.a * a * mod.a)
	func draw_set_transform(p: Vector2, r := 0.0, s := Vector2.ONE) -> void:
		ci.draw_set_transform_matrix(xf * Transform2D(r, s, 0.0, p))
	func draw_set_transform_matrix(m: Transform2D) -> void:
		ci.draw_set_transform_matrix(xf * m)
	func draw_string(f: Font, p: Vector2, s: String, al := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, fs := 16, col := Color.WHITE, jf := 3, dir := 0, ori := 0) -> void:
		if a <= 0.003: return
		ci.draw_string(f, p, s, al, w, fs, c(col), jf, dir, ori)
	func draw_string_outline(f: Font, p: Vector2, s: String, al := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, fs := 16, sz := 1, col := Color.WHITE) -> void:
		if a <= 0.003: return
		ci.draw_string_outline(f, p, s, al, w, fs, sz, c(col))
	func draw_multiline_string(f: Font, p: Vector2, s: String, al := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, fs := 16, ml := -1, col := Color.WHITE) -> void:
		if a <= 0.003: return
		ci.draw_multiline_string(f, p, s, al, w, fs, ml, c(col))
	func draw_rect(r: Rect2, col: Color, filled := true, w := -1.0, aa := false) -> void:
		if a <= 0.003: return
		ci.draw_rect(r, c(col), filled, w, aa)
	func draw_colored_polygon(pts: PackedVector2Array, col: Color, uvs := PackedVector2Array(), tex: Texture2D = null) -> void:
		if a <= 0.003 or pts.size() < 3: return
		ci.draw_colored_polygon(pts, c(col), uvs, tex)
	func draw_polyline(pts: PackedVector2Array, col: Color, w := -1.0, aa := false) -> void:
		if a <= 0.003: return
		ci.draw_polyline(pts, c(col), w, aa)
	func draw_line(p0: Vector2, p1: Vector2, col: Color, w := -1.0, aa := false) -> void:
		if a <= 0.003: return
		ci.draw_line(p0, p1, c(col), w, aa)
	func draw_circle(p: Vector2, r: float, col: Color, filled := true, w := -1.0, aa := false) -> void:
		if a <= 0.003: return
		ci.draw_circle(p, r, c(col), filled, w, aa)
	func draw_arc(p: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w := -1.0, aa := false) -> void:
		if a <= 0.003: return
		ci.draw_arc(p, r, a0, a1, n, c(col), w, aa)
	func draw_texture_rect(t: Texture2D, r: Rect2, tile: bool, col := Color.WHITE, tr := false) -> void:
		if a <= 0.003: return
		ci.draw_texture_rect(t, r, tile, c(col), tr)
	func draw_texture_rect_region(t: Texture2D, r: Rect2, src: Rect2, col := Color.WHITE, tr := false, clip := true) -> void:
		if a <= 0.003: return
		ci.draw_texture_rect_region(t, r, src, c(col), tr, clip)
	func draw_texture(t: Texture2D, p: Vector2, col := Color.WHITE) -> void:
		if a <= 0.003: return
		ci.draw_texture(t, p, c(col))

# ---------- drawing helpers ----------
## brightness(k) filter look for a flat draw: k > 1 lifts toward white, k < 1 darkens
static func bright(c: Color, k: float) -> Color:
	if k >= 1.0: return c.lerp(Color(1, 1, 1, c.a), clampf((k - 1.0) / 2.0, 0.0, 1.0))
	return Color(c.r * k, c.g * k, c.b * k, c.a)

## transform for "translate(tx,ty) rotate(r) scale(s)" about a pivot (CSS order: rightmost applies first)
static func xf(pivot: Vector2, tr := Vector2.ZERO, rot := 0.0, sc := Vector2.ONE, skx := 0.0) -> Transform2D:
	var m := Transform2D(rot, sc, skx, pivot + tr)
	return m * Transform2D(0.0, -pivot)

## polygon of a rect clipped horizontally: keep the part between fractions a..b of the width (clip-path inset)
static func inset_x(pts: PackedVector2Array, r: Rect2, a: float, b: float) -> PackedVector2Array:
	var x0 := r.position.x + r.size.x * a
	var x1 := r.position.x + r.size.x * b
	var out := Geometry2D.intersect_polygons(pts, PackedVector2Array([Vector2(x0, r.position.y - 9999), Vector2(x1, r.position.y - 9999), Vector2(x1, r.end.y + 9999), Vector2(x0, r.end.y + 9999)]))
	return out[0] if out.size() > 0 else PackedVector2Array()


# ---------- web test hook ----------
static var _cb
static var hooked := false
## window.cvaTS(v): Engine.time_scale = v right away (0 = frozen); window.cvaUI = what screen is up
static func hook_web() -> void:
	if hooked or not OS.has_feature("web"): return
	hooked = true
	_cb = JavaScriptBridge.create_callback(func(a: Array):
		Engine.time_scale = clampf(float(a[0]) if a.size() > 0 else 1.0, 0.0, 8.0))
	var w = JavaScriptBridge.get_interface("window")
	if w != null: w.cvaTS = _cb

## with ?uiclock in the page URL: window.cvaT = scaled ms since start, every frame (screenshot scripts wait on it)
class ClockNode extends Node:
	var ms := 0.0
	var w
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		w = JavaScriptBridge.get_interface("window")
	func _process(delta: float) -> void:
		ms += delta * 1000.0
		if w != null: w.cvaT = ms

static func clock_node() -> Node:
	if not OS.has_feature("web"): return null
	var q = JavaScriptBridge.eval("location.search", true)
	if not (q is String and q.contains("uiclock")): return null
	return ClockNode.new()
