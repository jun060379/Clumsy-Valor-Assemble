extends Control
## Base for the step 5-2 menu pages (대장간, 가방, 캐릭터, 도감 books, Bran's choices): a full-screen custom-drawn Control
## that is shown while menu.page is one of its keys. Taps go through hit areas registered while drawing; keys go to _key().

const UI := preload("res://scripts/ui_kit.gd")
const RN := preload("res://scripts/runes.gd")
const CH := preload("res://scripts/chars.gd")
const SYM := preload("res://assets/fonts/NotoSansKR-sym.otf")      # − Ⅰ Ⅱ Ⅲ Ⅳ ★ … the UI fonts lack
const SYM2 := preload("res://assets/fonts/DejaVuSans-env.ttf")     # ✉ (Eilin's "관리국 서신 받기 ✉")
const SYM3 := preload("res://assets/fonts/NotoSansKR-kh.otf")      # Ⓧ (KH on a pad) and ≫ (건너뛰기 ≫), from Noto Sans CJK KR
static var _sym_done := false

var arena
var menu
var keys: Array = []
var key := ""
var t := 0.0
var hits: Array = []             # [Rect2 | PackedVector2Array, Callable]
var hover := Vector2(-999, -999)
var tex := {}


func _ready() -> void:
	if not _sym_done:
		_sym_done = true
		for f in [UI.noto(), UI.noto_k()]:
			var a: Array[Font] = f.fallbacks
			for sf in [SYM, SYM2, SYM3]:
				if not a.has(sf): a.append(sf)
			f.fallbacks = a
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false

func R():
	return arena.runes

func live() -> bool:
	return keys.has(menu.page)

func open(k: String) -> void:
	key = k
	t = 0.0
	hits.clear()
	_opened()

func _opened() -> void:
	pass

func _tick(_dt: float) -> void:
	pass

func _process(delta: float) -> void:
	var v := live()
	visible = v
	if not v: return
	var dt := minf(delta * 1000.0, 100.0)
	t += dt
	_tick(dt)
	queue_redraw()

func _input(ev: InputEvent) -> void:
	if not live() or menu.ui_root.sweep.active or menu.ui_root.title.active:
		return
	if ev is InputEventMouseMotion:
		hover = ev.position
		if ev.button_mask & MOUSE_BUTTON_MASK_LEFT: _drag(ev.relative, ev.position)     # a finger (or held mouse) drags
		return
	var handled := false
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_LEFT:
			handled = true
			var p: Vector2 = ev.position
			for i in range(hits.size() - 1, -1, -1):
				var h: Array = hits[i]
				var inside: bool = h[0].has_point(p) if h[0] is Rect2 else Geometry2D.is_point_in_polygon(p, h[0])
				if inside:
					h[1].call()
					break
		elif ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			handled = true
			_wheel(-1 if ev.button_index == MOUSE_BUTTON_WHEEL_UP else 1, ev.position)
	elif ev is InputEventMouseButton:
		handled = true
	elif ev is InputEventKey and ev.pressed:
		handled = true
		if not ev.echo or ev.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			_key(k)
	elif ev is InputEventKey:
		handled = true
	elif ev is InputEventJoypadButton and ev.pressed:
		handled = true
		match ev.button_index:
			JOY_BUTTON_B: _key(KEY_ESCAPE)
			JOY_BUTTON_A: _key(KEY_ENTER)
			JOY_BUTTON_DPAD_UP: _key(KEY_UP)
			JOY_BUTTON_DPAD_DOWN: _key(KEY_DOWN)
			JOY_BUTTON_DPAD_LEFT: _key(KEY_LEFT)
			JOY_BUTTON_DPAD_RIGHT: _key(KEY_RIGHT)
			JOY_BUTTON_LEFT_SHOULDER: _key(KEY_Q)
			JOY_BUTTON_RIGHT_SHOULDER: _key(KEY_E)
	elif ev is InputEventScreenTouch:
		handled = true
	if handled:
		get_viewport().set_input_as_handled()

func _key(k: int) -> void:
	if k == KEY_ESCAPE: back()

func _wheel(_d: int, _p: Vector2) -> void:
	pass

## a drag with the finger or the held mouse (pages that scroll override it)
func _drag(_rel: Vector2, _p: Vector2) -> void:
	pass

func back() -> void:
	menu.close_page()

func hit(r, cb: Callable) -> void:
	hits.append([r, cb])

func _draw() -> void:
	hits.clear()
	_paint(get_viewport_rect().size)

func _paint(_vs: Vector2) -> void:
	pass

func tx(p: String) -> Texture2D:
	if not tex.has(p): tex[p] = load(p)
	return tex[p]

func tcol() -> Color:
	return UI.col(arena.player.who)

func sfx(n: String, v := 0.4) -> void:
	arena.sfx(n, v)


# ---------- drawing helpers ----------
## a gem: a diamond with a white rim and a lit top half
static func gem(ci: CanvasItem, c: Vector2, r: float, col: Color, rim := true) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	if rim:
		var o := r + maxf(1.5, r * 0.18)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -o), c + Vector2(o, 0), c + Vector2(0, o), c + Vector2(-o, 0)]), Color(1, 1, 1, col.a))
	ci.draw_colored_polygon(pts, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(-r, 0)]), col.lightened(0.35))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.1), c + Vector2(0, -r * 0.55), c + Vector2(r * 0.1, -r * 0.45), c + Vector2(-r * 0.35, 0)]), Color(1, 1, 1, 0.55 * col.a))

## wrapped paragraphs [[text, size, colour, font?]...] from (x, y) in width w; returns the height used
static func paras(ci: CanvasItem, x: float, y: float, w: float, ps: Array, gap := 3.0) -> float:
	var yy := y
	for p in ps:
		var s: String = p[0]
		var fs: int = p[1]
		var col: Color = p[2]
		var f: Font = p[3] if p.size() > 3 and p[3] != null else UI.noto()
		if s == "":
			yy += fs * 0.5
			continue
		var sz := f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, fs)
		ci.draw_multiline_string(f, Vector2(x, yy + f.get_ascent(fs)), s, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, col)
		yy += sz.y + gap
	return yy - y

static func paras_h(w: float, ps: Array, gap := 3.0) -> float:
	var h := 0.0
	for p in ps:
		var f: Font = p[3] if p.size() > 3 and p[3] != null else UI.noto()
		if p[0] == "": h += p[1] * 0.5
		else: h += f.get_multiline_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, w, p[1]).y + gap
	return h

static func text(ci: CanvasItem, f: Font, p: Vector2, s: String, fs: int, col: Color) -> void:
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

static func tw(f: Font, s: String, fs: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## text centred on x
static func ctext(ci: CanvasItem, f: Font, p: Vector2, s: String, fs: int, col: Color) -> void:
	ci.draw_string(f, p - Vector2(tw(f, s, fs) / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## a rect turned about its centre (CSS rotate) as a polygon
static func rrect(r: Rect2, deg: float) -> PackedVector2Array:
	return UI.rot(UI.clip(r, [[0, 0], [100, 0], [100, 100], [0, 100]]), r.get_center(), deg_to_rad(deg))

## the round ✕ (as the menu's) with its hit area
func close_x(vs: Vector2, cb: Callable) -> void:
	var c := Vector2(vs.x - 14.0 - 18.0, 14.0 + 18.0)
	draw_circle(c + Vector2(3, 3), 18.0, tcol())
	draw_circle(c, 18.0, Color.BLACK)
	draw_arc(c, 17.0, 0, TAU, 32, Color.WHITE, 2.0, true)
	UI.cross(self, c, 5.0, Color.WHITE, 2.0)
	hit(Rect2(c - Vector2(22, 22), Vector2(44, 44)), cb)

## a slanted tab button (fsub): white when on
func tab_btn(p: Vector2, label: String, n: int, on: bool, cb: Callable, col := Color.WHITE) -> float:
	var f := UI.noto_k()
	var s := label
	var w := tw(f, s, 13) + (tw(UI.anton(), str(n), 12) + 8.0 if n >= 0 else 0.0) + 24.0
	var poly := PackedVector2Array([p + Vector2(4, 0), p + Vector2(w + 4, 0), p + Vector2(w, 22), p + Vector2(0, 22)])
	if on: draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(3, 3), poly[1] + Vector2(3, 3), poly[2] + Vector2(3, 3), poly[3] + Vector2(3, 3)]), tcol())
	draw_colored_polygon(poly, Color.WHITE if on else Color.BLACK)
	var rim := poly.duplicate()
	rim.append(poly[0])
	draw_polyline(rim, col if not on else Color.WHITE, 1.5)
	draw_string(f, p + Vector2(12, 16), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.BLACK if on else Color(0.67, 0.67, 0.67))
	if n >= 0:
		draw_string(UI.anton(), p + Vector2(16 + tw(f, s, 13), 16), str(n), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.5) if on else Color(1, 1, 1, 0.45))
	hit(poly, cb)
	return w + 8.0

## the background of a menu page: the theme colour, rays, dots, the black band
func page_ground(vs: Vector2, col: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), col)
	UI.burst(self, Vector2(vs.x * 0.1, vs.y * 0.8), maxf(vs.x, vs.y) * 1.6, 0.14, t / 80000.0 * TAU)
	var sc := Vector2(-fmod(t / 6000.0, 1.0) * 44.0, fmod(t / 6000.0, 1.0) * 22.0)
	UI.dots(self, Rect2(Vector2.ZERO, vs), 0.26, 1.0, sc)

## an item / rune line for gear: "공격력 +14.2% · 치명 +2.4%"
func gear_line(it: Dictionary, kind: String) -> String:
	return R().gear_text(it, kind)

func rune_head(r: String, st: int, nx := 0) -> String:
	var Rd: Dictionary = RN.RUNE[r]
	return "[%s] %s · ★%d ×%s%s" % [Rd["n"], RN.gname(Rd["g"]), st, RN.fmt(RN.RSM[st]), (" → ★%d ×%s" % [nx, RN.fmt(RN.RSM[nx])]) if nx > 0 else ""]

static func rune_kind(r: String) -> String:
	var Rd: Dictionary = RN.RUNE[r]
	if Rd["k"] == "w": return "무기 룬" + (" · " + Rd["cls"] if Rd.has("cls") else "")
	if Rd["k"] == "a": return "방어구 룬"
	return "장신구 룬" + (" · " + RN.pname(Rd["who"]) + " 전용" if Rd.has("who") else "")


# ---------- CSS box helpers (the DOM-mirroring pages: 가방, 대장간) ----------
## a box transform: translate to p, then about the local pivot: rotate, scale, skewX (CSS order translate · rotate · scale · skew)
static func xf(p: Vector2, pivot: Vector2, rot_deg := 0.0, sc := 1.0, skew_deg := 0.0) -> Transform2D:
	var m := Transform2D(Vector2(1, 0), Vector2(tan(deg_to_rad(skew_deg)), 1), Vector2.ZERO)
	m = Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO) * m
	m = Transform2D(deg_to_rad(rot_deg), Vector2.ZERO) * m
	return Transform2D(0.0, p + pivot) * m * Transform2D(0.0, -pivot)

static func poly(r: Rect2, pct: Array, m: Transform2D) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pct: out.append(m * (r.position + Vector2(r.size.x * q[0] / 100.0, r.size.y * q[1] / 100.0)))
	return out

const SQ := [[0, 0], [100, 0], [100, 100], [0, 100]]

## text whose CSS line box is at y with line height lh
func txt(ci: CanvasItem, f: Font, x: float, y: float, s: String, fs: int, col: Color, lh := 0.0) -> float:
	var asc := f.get_ascent(fs)
	var h := asc + f.get_descent(fs)
	if lh <= 0.0: lh = h
	ci.draw_string(f, Vector2(x, y + (lh - h) / 2.0 + asc), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return tw(f, s, fs)

## inline runs [[text, font, size, colour], ...] ("\n" = <br>), Korean breaking anywhere, latin per word; returns the
## lines as [[x, run, text]...] per line, for width w. Measuring and drawing share it.
func flow(runs: Array, w: float) -> Array:
	var lines: Array = [[]]
	var x := 0.0
	for r in runs:
		var s: String = r[0]
		var f: Font = r[1]
		var fs: int = r[2]
		var toks: Array = []
		var cur := ""
		for ch in s:
			if ch == "\n":
				if cur != "": toks.append(cur)
				toks.append("\n")
				cur = ""
			elif ch == " ":
				toks.append(cur + " ")
				cur = ""
			elif ch.unicode_at(0) >= 0x1100:
				if cur != "": toks.append(cur)
				toks.append(ch)
				cur = ""
			else:
				cur += ch
		if cur != "": toks.append(cur)
		for tk in toks:
			if tk == "\n":
				lines.append([])
				x = 0.0
				continue
			var tw0 := tw(f, tk.rstrip(" "), fs)
			if x > 0.0 and x + tw0 > w + 0.5:
				lines.append([])
				x = 0.0
				if tk == " ": continue
			var ln: Array = lines[-1]
			if not ln.is_empty() and ln[-1][1] == r:
				ln[-1][2] += tk
			else:
				ln.append([x, r, tk])
			x += tw(f, tk, fs)
	return lines

static func flow_w(lines: Array) -> float:
	var w := 0.0
	for ln in lines:
		if ln.is_empty(): continue
		var last: Array = ln[-1]
		var r: Array = last[1]
		w = maxf(w, last[0] + (r[1] as Font).get_string_size(String(last[2]).rstrip(" "), HORIZONTAL_ALIGNMENT_LEFT, -1, r[2]).x)
	return w

func draw_flow(ci: CanvasItem, lines: Array, x: float, y: float, lh: float, a := 1.0) -> void:
	for i in lines.size():
		for seg in lines[i]:
			var r: Array = seg[1]
			txt(ci, r[1], x + seg[0], y + i * lh, seg[2], r[2], Color(r[3], r[3].a * a), lh)


