extends RefCounted
## Shared look for the menus and the HUD (prototype "persona skin"): theme colours per member, fonts,
## slanted plates, CSS-style easing, a solid-silhouette material for the standing art.

## TXCOL: [theme colour, light partner] per member (the prototype calls Aida "shovel")
const TXCOL := {"estelle": [Color("#ff3d7f"), Color("#ffe0ea")], "aida": [Color("#3ddc84"), Color("#e2ffe9")], "luce": [Color("#ffc21f"), Color("#fff3c8")]}
const EN := {"estelle": "ESTELLE", "aida": "AYDA", "luce": "LUCE"}

## Every font the game draws with (tools/make_fonts.py rebuilds them). The Noto ones carry all 11,172 Hangul syllables,
## the jamo, Latin-1 and the symbol blocks; Black Han Sans only has 2,581 syllables upstream and Anton no Hangul, so each
## falls back on a Noto of its weight. tests/test_fonts.gd checks every string the scripts can show against these.
const _BHS := preload("res://assets/fonts/BlackHanSans.woff2")
const _NOTO_K := preload("res://assets/fonts/NotoSansKR-Black.woff2")
const _NOTO_B := preload("res://assets/fonts/NotoSansKR-Bold.woff2")
const _ANTON := preload("res://assets/fonts/Anton.woff2")
const _SERIF_K := preload("res://assets/fonts/NotoSerifKR-Black.woff2")     # guild titles (fame_skin.serif)
const _SERIF_B := preload("res://assets/fonts/NotoSerifKR-Bold.woff2")      # the rune codex (ui_codex)
const _SYM := preload("res://assets/fonts/DejaVuSans-sym.ttf")              # ☠ ✉ … that Noto lacks

static var _cache := {}
static var _chains_set := chains()


## The fallback chains, set once on the shared resources (every preload of a path is the same object), so the fonts are
## complete however they're reached: here, fame_skin.gd, arena.font_bold / font_black / font_anton, ui_codex's serif.
static func chains() -> bool:
	if _NOTO_B.fallbacks.has(_SYM): return true
	for fb in [[_NOTO_B, _SYM], [_NOTO_K, _SYM], [_BHS, _NOTO_K], [_ANTON, _NOTO_B], [_SERIF_K, _NOTO_K], [_SERIF_B, _NOTO_B]]:
		var f: Font = fb[0]
		f.fallbacks = [fb[1]]
	return true

## every base font, for tests/test_fonts.gd
static func all_fonts() -> Dictionary:
	chains()
	return {"BlackHanSans": _BHS, "NotoSansKR-Black": _NOTO_K, "NotoSansKR-Bold": _NOTO_B, "Anton": _ANTON,
		"NotoSerifKR-Black": _SERIF_K, "NotoSerifKR-Bold": _SERIF_B}

## plain Anton (no FontVariation: arena.gd's outlined words skew the canvas themselves)
static func anton_file() -> Font:
	chains()
	return _ANTON

static func serif() -> Font:
	chains()
	return _SERIF_K

static func serif_b() -> Font:
	chains()
	return _SERIF_B
static var _solid: ShaderMaterial
static var _glow: Texture2D


static func col(c: String) -> Color:
	return TXCOL.get(c, TXCOL["estelle"])[0]

static func col2(c: String) -> Color:
	return TXCOL.get(c, TXCOL["estelle"])[1]


## "Black Han Sans" with Noto Black behind it for the glyphs it lacks (· — ← … and the syllables outside its 2,581)
static func bhs() -> Font:
	chains()
	return _BHS

static func noto() -> Font:
	chains()
	return _NOTO_B

static func noto_k() -> Font:
	chains()
	return _NOTO_K

## Anton, optionally italic (slanted outlines) and letter-spaced; Korean falls back to Noto Bold
static func anton(italic := false, spacing := 0) -> Font:
	var key := "anton%d_%d" % [int(italic), spacing]
	if not _cache.has(key):
		chains()
		var v := FontVariation.new()
		v.base_font = _ANTON
		if italic:
			v.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
		v.spacing_glyph = spacing
		_cache[key] = v
	return _cache[key]

static func spaced(f: Font, spacing: int) -> Font:
	var key := "sp%d_%d" % [f.get_instance_id(), spacing]
	if not _cache.has(key):
		var v := FontVariation.new()
		v.base_font = f
		v.spacing_glyph = spacing
		v.fallbacks = chain_of(f)
		_cache[key] = v
	return _cache[key]

## the fallbacks a variation built on f needs: a FontVariation only follows its base's fallbacks one level down, so a
## variation of a variation (spaced(anton())) would lose the Hangul behind Anton
static func chain_of(f: Font) -> Array[Font]:
	var b := f
	while b is FontVariation and b.base_font != null:
		b = b.base_font
	return b.fallbacks


## draws every texture as one flat colour (the draw call's modulate) keeping its alpha: outlines and silhouettes
static func solid_mat() -> ShaderMaterial:
	if _solid == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nvarying vec4 vc;\nvoid vertex(){ vc = COLOR; }\nvoid fragment(){ COLOR = vec4(vc.rgb, texture(TEXTURE, UV).a * vc.a); }"
		_solid = ShaderMaterial.new()
		_solid.shader = sh
	return _solid

## soft white radial blob (flashes)
static func glow() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128
		gt.height = 128
		_glow = gt
	return _glow


## CSS cubic-bezier(x1,y1,x2,y2) at time u (0..1)
static func bez(x1: float, y1: float, x2: float, y2: float, u: float) -> float:
	if u <= 0.0: return 0.0
	if u >= 1.0: return 1.0
	var lo := 0.0
	var hi := 1.0
	var s := u
	for i in 22:
		s = (lo + hi) * 0.5
		var x := 3.0 * x1 * (1.0 - s) * (1.0 - s) * s + 3.0 * x2 * (1.0 - s) * s * s + s * s * s
		if x < u: lo = s
		else: hi = s
	return 3.0 * y1 * (1.0 - s) * (1.0 - s) * s + 3.0 * y2 * (1.0 - s) * s * s + s * s * s

## CSS "--bk" overshoot ease, cubic-bezier(.2,1.5,.4,1)
static func bk(u: float) -> float:
	return bez(0.2, 1.5, 0.4, 1.0, clampf(u, 0.0, 1.0))


## parallelogram: top edge shifted right by sk
static func para(ci: CanvasItem, x: float, y: float, w: float, h: float, sk: float, c: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x + sk, y), Vector2(x + w + sk, y), Vector2(x + w, y + h), Vector2(x, y + h)]), c)

## CSS clip-path polygon in percent of a rect
static func clip(r: Rect2, pct: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pct:
		out.append(r.position + Vector2(r.size.x * p[0] / 100.0, r.size.y * p[1] / 100.0))
	return out

## rotate points about a pivot
static func rot(pts: PackedVector2Array, pivot: Vector2, a: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(pivot + (p - pivot).rotated(a))
	return out

static func text_w(f: Font, s: String, fs: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## text with a plain offset shadow
static func shadow_text(ci: CanvasItem, f: Font, p: Vector2, s: String, fs: int, c: Color, sh := Color(0, 0, 0, 1), off := Vector2(1, 1)) -> void:
	ci.draw_string(f, p + off, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(sh, sh.a * c.a))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

## four-point star (the ✦ / ✧ ornaments; the fonts lack the glyph)
static func star4(ci: CanvasItem, c: Vector2, r: float, col: Color, hollow := false) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var a := i * PI / 4.0 - PI / 2.0
		var rr := r if i % 2 == 0 else r * 0.32
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	if hollow:
		pts.append(pts[0])
		ci.draw_polyline(pts, col, 1.2, true)
	else:
		ci.draw_colored_polygon(pts, col)

## ✕
static func cross(ci: CanvasItem, c: Vector2, r: float, col: Color, w := 2.0) -> void:
	ci.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, w, true)
	ci.draw_line(c + Vector2(r, -r), c + Vector2(-r, r), col, w, true)

## halftone dot tile (radial-gradient dots on an 11 px grid)
static func dot_tile(a: float) -> Texture2D:
	var key := "dots%.2f" % a
	if not _cache.has(key):
		var im := Image.create(11, 11, false, Image.FORMAT_RGBA8)
		for y in 11:
			for x in 11:
				var d := Vector2(x + 0.5 - 5.5, y + 0.5 - 5.5).length() / 5.5
				var v := clampf((0.33 - d) / 0.03, 0.0, 1.0)
				im.set_pixel(x, y, Color(0, 0, 0, a * v))
		_cache[key] = ImageTexture.create_from_image(im)
	return _cache[key]

## dots over a rect, fading out to the right over `fade` of its width (CSS mask linear-gradient)
static func dots(ci: CanvasItem, r: Rect2, a: float, fade := 1.0, scroll := Vector2.ZERO) -> void:
	var tex := dot_tile(a)
	var strips := 14
	var fw := r.size.x * fade
	for i in strips:
		var x0 := r.position.x + fw * i / strips
		var k := 1.0 - float(i) / strips
		ci.draw_texture_rect_region(tex, Rect2(x0, r.position.y, fw / strips + 1.0, r.size.y), Rect2(x0 + scroll.x, r.position.y + scroll.y, fw / strips + 1.0, r.size.y), Color(1, 1, 1, k))
	if fade < 1.0:
		return

## repeating-conic-gradient rays (5° dark of every 13°), spinning slowly
static func burst(ci: CanvasItem, c: Vector2, rr: float, a: float, spin: float) -> void:
	var step := deg_to_rad(13.0)
	var w := deg_to_rad(5.0)
	var n := int(TAU / step) + 1
	for i in n:
		var a0 := spin + i * step
		ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * rr, c + Vector2(cos(a0 + w), sin(a0 + w)) * rr]), Color(0, 0, 0, a))
