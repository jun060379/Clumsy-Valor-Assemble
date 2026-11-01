extends RefCounted
## The cave's rock masses as the prototype bakes them (estelle-prototype.html 4936-5045): one art-resolution canvas per
## mass (1 art px = 2 world px), drawn 2x with nearest filtering.
##  - terrain(): a slab (ceiling, side walls, ledges): jittered sides, seamless rock texture, lit left band, shaded right
##    band, darker toward the foot (or a faint gradient over a fringe), dark 1-px outline, moss lip on top, stalactite
##    fringe underneath that tapers toward both ends and takes the rock texture into its roots
##  - ground(): the floor and every raised rock block as ONE stepped silhouette (groundMass): lit / shaded step faces,
##    occlusion in the inside corners, darker with depth, a lip along every top
##  - wall(): a back wall (wallMass): an angular crest with 1-3 shoulders, the wall-kit stone, darker toward the foot
## Each mass also takes the room's light on its edges (drawTerrain / rimMasks / tintDir / paintRim): the DIR8 edge
## bands of its silhouette (2 and 5 art px deep) that face each light get the light's colour, strong to nothing by
## angle and distance, and the strongest light deepens the far side. That is RIM_SH, fed per frame by rim_params().
## Masses depend only on the room template, so each is built once and kept (CACHE).

const PAD := 12
const D1 := [Vector2i(2, 0), Vector2i(1, 1), Vector2i(0, 2), Vector2i(-1, 1), Vector2i(-2, 0), Vector2i(-1, -1), Vector2i(0, -2), Vector2i(1, -1)]
const D5 := [Vector2i(5, 0), Vector2i(4, 4), Vector2i(0, 5), Vector2i(-4, 4), Vector2i(-5, 0), Vector2i(-4, -4), Vector2i(0, -5), Vector2i(4, -4)]
const DARK := Color8(23, 16, 31)          # #17101f
const RIM_SH := """
shader_type canvas_item;
// drawTerrain's light: LB (the rims, added) then DB (the far side, laid over), from the mass's own silhouette.
// rc[i]: the summed light on the DIR8 edge band i (a > 0: in use); rd[i]: the dark side's strength on band i.
uniform vec4 rc[8];
uniform float rd[8];
uniform float fk = 1.0;
uniform int on = 0;
uniform bool deep = true;       // phones: the 2-px band only (one fetch per direction instead of two)
const ivec2 O1[8] = ivec2[8](ivec2(2, 0), ivec2(1, 1), ivec2(0, 2), ivec2(-1, 1), ivec2(-2, 0), ivec2(-1, -1), ivec2(0, -2), ivec2(1, -1));
const ivec2 O5[8] = ivec2[8](ivec2(5, 0), ivec2(4, 4), ivec2(0, 5), ivec2(-4, 4), ivec2(-5, 0), ivec2(-4, -4), ivec2(0, -5), ivec2(4, -4));
void fragment() {
	vec4 b = texture(TEXTURE, UV);
	if (on == 0 || b.a < 0.5) {
		COLOR = b;
	} else {
		ivec2 sz = textureSize(TEXTURE, 0);
		ivec2 p = clamp(ivec2(floor(UV * vec2(sz))), ivec2(0), sz - 1);
		vec3 R = vec3(0.0);
		float keep = 1.0;
		for (int i = 0; i < 8; i++) {
			if (rc[i].a <= 0.0 && rd[i] <= 0.0) continue;
			ivec2 q1 = p + O1[i];
			ivec2 q5 = p + O5[i];
			bool in1 = q1.x >= 0 && q1.y >= 0 && q1.x < sz.x && q1.y < sz.y && texelFetch(TEXTURE, q1, 0).a > 0.5;
			float m = 1.0;
			if (in1) {
				bool in5 = !deep || (q5.x >= 0 && q5.y >= 0 && q5.x < sz.x && q5.y < sz.y && texelFetch(TEXTURE, q5, 0).a > 0.5);
				m = in5 ? 0.0 : 0.45;
			}
			if (m <= 0.0) continue;
			R += rc[i].rgb * m;
			keep *= 1.0 - rd[i] * m;
		}
		vec3 c = min(b.rgb + min(R, vec3(1.0)) * fk, vec3(1.0));
		float A = 1.0 - keep;
		COLOR = vec4(mix(c, vec3(10.0, 6.0, 20.0) / 255.0, A), b.a);
	}
}
"""

static var CACHE := {}
static var _rtex: Image
static var _kit: Image
static var _lip: Image
static var _fringe: Image
static var _shader: Shader
static var _ao: Image


## Math.round
static func jr(v: float) -> float:
	return floorf(v + 0.5)

## JS remainder (sign of the dividend)
static func jrem(a: int, b: int) -> int:
	return a - b * int(float(a) / b)

static func thsh(i: float, s: float) -> float:
	var v := sin(i * 127.1 + s * 311.7) * 43758.5453
	return v - floorf(v)

static func shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = RIM_SH
	return _shader

static func _img(t: Texture2D) -> Image:
	var im := t.get_image()
	if im.is_compressed(): im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im

## the prototype's art sources: the seamless rock, the wall-kit tile (mirrored 2x2), the lip strip (the tile set's top
## piece halved: every other pixel, then mirrored) and the fringe strip
static func init_art(tex: Dictionary) -> void:
	if _rtex != null: return
	_rtex = _img(tex["rtex"])
	_fringe = _img(tex["rfringe"])
	var wk := _img(tex["wkit"])
	var part := wk.get_region(Rect2i(104, 2, 95, 95))
	_kit = Image.create(190, 190, false, Image.FORMAT_RGBA8)
	_kit.blit_rect(part, Rect2i(0, 0, 95, 95), Vector2i(0, 0))
	var fx := part.duplicate()
	fx.flip_x()
	_kit.blit_rect(fx, Rect2i(0, 0, 95, 95), Vector2i(95, 0))
	var fy := part.duplicate()
	fy.flip_y()
	_kit.blit_rect(fy, Rect2i(0, 0, 95, 95), Vector2i(0, 95))
	var fxy := fx.duplicate()
	fxy.flip_y()
	_kit.blit_rect(fxy, Rect2i(0, 0, 95, 95), Vector2i(95, 95))
	_ao = Image.create(56, 40, false, Image.FORMAT_RGBA8)
	blend_radial(_ao, Rect2i(0, 0, 56, 40), Vector2(28, 26), 1.0, 26.0, Color8(10, 6, 18), 0.5)
	var tT := _img(tex["tT"])
	var w := tT.get_width() / 2
	_lip = Image.create(w * 2, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		for x in w:
			var c := tT.get_pixel(x * 2 + 1, y * 2 + 1)
			_lip.set_pixel(x, y, c)
			_lip.set_pixel(w * 2 - 1 - x, y, c)


# ---------- raster helpers ----------
## fill a polygon (pixel centres, even-odd) into `img`, moved by `off`: in `col`, or copied span by span from `src`
## (an image of the same size: the clip of the prototype's path)
static func fill_poly(img: Image, pts: PackedVector2Array, col: Color, src: Image = null, off := Vector2i.ZERO) -> void:
	var H := img.get_height()
	var W := img.get_width()
	var rows := {}
	var n := pts.size()
	for i in n:
		var a := pts[i] + Vector2(off)
		var b := pts[(i + 1) % n] + Vector2(off)
		if a.y == b.y: continue
		var lo := minf(a.y, b.y)
		var hi := maxf(a.y, b.y)
		var y0 := maxi(0, int(ceilf(lo - 0.5)))
		var y1 := mini(H - 1, int(ceilf(hi - 0.5)) - 1)
		for y in range(y0, y1 + 1):
			var yc := y + 0.5
			var x := a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y)
			if not rows.has(y): rows[y] = []
			rows[y].append(x)
	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var j := 0
		while j + 1 < xs.size():
			var p0 := clampi(int(ceilf(xs[j] - 0.5)), 0, W)
			var p1 := clampi(int(ceilf(xs[j + 1] - 0.5)), 0, W)
			if p1 > p0:
				if src != null: img.blit_rect(src, Rect2i(p0, y, p1 - p0, 1), Vector2i(p0, y))
				else: img.fill_rect(Rect2i(p0, y, p1 - p0, 1), col)
			j += 2

## the dark outline: the path filled in `col` at each offset (the prototype fills the path moved by each)
static func outline_poly(out: Image, pts: PackedVector2Array, col: Color, offs: Array) -> void:
	for o in offs: fill_poly(out, pts, col, null, o)

## a repeating pattern of `t` anchored at (ox, oy)
static func pattern(t: Image, W: int, H: int, ox: int, oy: int) -> Image:
	var im := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var tw := t.get_width()
	var th := t.get_height()
	var y := posmod(oy, th) - th
	while y < H:
		var x := posmod(ox, tw) - tw
		while x < W:
			im.blit_rect(t, Rect2i(0, 0, tw, th), Vector2i(x, y))
			x += tw
		y += th
	return im

static func blend_fill(img: Image, r: Rect2i, col: Color) -> void:
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x <= 0 or r.size.y <= 0: return
	var s := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	s.fill(col)
	img.blend_rect(s, Rect2i(Vector2i.ZERO, r.size), r.position)

## a vertical linear gradient (createLinearGradient(0, ga, 0, gb), two stops) over rect r
static func blend_vgrad(img: Image, r: Rect2i, ga: float, gb: float, c0: Color, c1: Color) -> void:
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x <= 0 or r.size.y <= 0: return
	var s := Image.create(1, r.size.y, false, Image.FORMAT_RGBA8)
	for j in r.size.y:
		var u := clampf((r.position.y + j + 0.5 - ga) / maxf(0.001, gb - ga), 0.0, 1.0)
		s.set_pixel(0, j, c0.lerp(c1, u))
	s.resize(r.size.x, r.size.y, Image.INTERPOLATE_NEAREST)
	img.blend_rect(s, Rect2i(Vector2i.ZERO, r.size), r.position)

## a radial gradient (centre c, radius r0 -> r1, colour col, alpha a0 -> 0) over rect r
static func blend_radial(img: Image, r: Rect2i, c: Vector2, r0: float, r1: float, col: Color, a0: float) -> void:
	r = r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if r.size.x <= 0 or r.size.y <= 0: return
	var s := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	for j in r.size.y:
		for i in r.size.x:
			var d := Vector2(r.position.x + i + 0.5, r.position.y + j + 0.5).distance_to(c)
			var u := clampf((d - r0) / (r1 - r0), 0.0, 1.0)
			s.set_pixel(i, j, Color(col, a0 * (1.0 - u)))
	img.blend_rect(s, Rect2i(Vector2i.ZERO, r.size), r.position)

static func _solid(W: int, H: int, col: Color) -> Image:
	var s := Image.create(W, H, false, Image.FORMAT_RGBA8)
	s.fill(col)
	return s

## the lip strip along a top edge, clipped to [xl, xr)
static func lip(out: Image, xl: int, xr: int, y: int, xs: int) -> void:
	var lw := _lip.get_width()
	var x := xs
	while x < xr:
		var a := maxi(x, xl)
		var b := mini(x + lw, xr)
		if b > a: out.blend_rect(_lip, Rect2i(a - x, 0, b - a, _lip.get_height()), Vector2i(a, y))
		x += lw

static func _mass(out: Image, ox: float, oy: float) -> Dictionary:
	return {"img": out, "ox": ox, "oy": oy, "w": out.get_width(), "h": out.get_height()}

## on the main thread: the mass's texture
static func finish(m: Dictionary) -> Dictionary:
	if not m.has("tex"): m["tex"] = ImageTexture.create_from_image(m["img"])
	return m


# ---------- the masses ----------
## one mass from its spec (dungeon.gd _mass_specs): "wall" / "terrain" / "ground" with the prototype's arguments
static func build(kind: String, a: Array) -> Dictionary:
	match kind:
		"wall": return wall(a[0], a[1], a[2], a[3], a[4])
		"ground": return ground(a[0], a[1], a[2], a[3], a[4], a[5])
	return terrain(a[0], a[1], a[2], a[3], a[4])

## terrain(x0,x1,y0,y1,o): o = {lip, fringe, jag, topJag, dark, open}
static func terrain(x0: float, x1: float, y0: float, y1: float, o: Dictionary) -> Dictionary:
	var tex := _rtex
	var fh: int = _fringe.get_height() if o.get("fringe", false) else 0
	var W2 := int(ceilf((x1 - x0) / 2.0)) + PAD * 2
	var H2 := int(ceilf((y1 - y0) / 2.0)) + PAD + fh + 2
	var L := PAD
	var R := W2 - PAD
	var T := PAD
	var opn: bool = o.get("open", false)
	var B: int = H2 + 20 if opn else H2 - fh - 2
	var sd := x0 + y0
	var jag: float = o.get("jag", 0.0)
	if jag == 0.0: jag = 3.0                   # o.jag||3
	var tj: float = o.get("topJag", 0.0)
	var pts := PackedVector2Array()
	pts.append(Vector2(L + 3, T))
	var x := L + 3
	while x <= R - 3:
		pts.append(Vector2(x, T + (jr(thsh(x, sd) * tj) if tj > 0.0 else 0.0)))
		x += 4
	pts.append(Vector2(R - 3, T))
	pts.append(Vector2(R, T + 3))
	var y := T + 3
	while y <= B:
		pts.append(Vector2(R + jr((thsh(y, sd + 1.0) - 0.5) * jag * 2.0), y))
		y += 5
	pts.append(Vector2(R, B))
	pts.append(Vector2(L, B))
	y = B
	while y >= T + 3:
		pts.append(Vector2(L + jr((thsh(y, sd + 2.0) - 0.5) * jag * 2.0), y))
		y -= 5
	pts.append(Vector2(L, T + 3))
	var out := Image.create(W2, H2, false, Image.FORMAT_RGBA8)
	outline_poly(out, pts, DARK, [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(0, 2)])
	var px := int(jr(-x0 / 2.0))
	var py := int(jr(-y0 / 2.0))
	var inner := pattern(tex, W2, H2, jrem(px, tex.get_width()), jrem(py, tex.get_height()))
	blend_fill(inner, Rect2i(L - 4, T, 7, B - T), Color8(190, 175, 220, 41))
	blend_fill(inner, Rect2i(R - 6, T, 10, B - T), Color(16 / 255.0, 10 / 255.0, 26 / 255.0, 0.30))
	if o.get("fringe", false) and not opn:
		blend_vgrad(inner, Rect2i(0, T, W2, B - T), T, B, Color(16 / 255.0, 10 / 255.0, 26 / 255.0, 0.0), Color(16 / 255.0, 10 / 255.0, 26 / 255.0, 0.12))
	if not opn and not o.get("fringe", false):
		for da in [[0.55, 0.12], [0.75, 0.22], [0.9, 0.3]]:
			blend_fill(inner, Rect2i(L - 4, int(jr(T + (B - T) * da[0])), R - L + 8, int(jr((B - T) * (1.0 - da[0]) + 2.0))), Color(16 / 255.0, 10 / 255.0, 26 / 255.0, da[1]))
	if o.get("dark", 0.0) > 0.0:
		blend_fill(inner, Rect2i(0, 0, W2, H2), Color(14 / 255.0, 9 / 255.0, 26 / 255.0, o["dark"]))
	fill_poly(out, pts, Color.WHITE, inner)
	if o.get("lip", false):
		var lw := _lip.get_width()
		lip(out, L + 1, R - 1, T - 2, L - posmod(int(jr(x0 / 2.0)), lw))
	if o.get("fringe", false):
		_fringe_into(out, inner, L, R, B, fh, x0)
	return _mass(out, x0 - PAD * 2, y0 - PAD * 2)

## the stalactite fringe under a slab: the strip from row 7, tiled; tapered toward both ends (smoothstep over 30 art px);
## the rock texture carries into the roots and fades over 13 rows; darker toward the tips; a dark outline left, right, below
static func _fringe_into(out: Image, inner_tex: Image, L: int, R: int, B: int, fh: int, x0: float) -> void:
	var F0 := 7
	var dep := fh - F0
	var W2 := out.get_width()
	var H2 := out.get_height()
	var fw := _fringe.get_width()
	var xs := L - posmod(int(jr(x0 / 2.0)), fw)
	var top := B - 4
	# one period of the finished fringe (the strip and the rock texture share the 176 px period), then tiled
	var fd := _fringe.get_data()
	var td := inner_tex.get_data()
	var tile := PackedByteArray()
	tile.resize(fw * dep * 4)
	var dk := [16.0, 10.0, 26.0]
	var cx0 := clampi(L + 40, 0, maxi(0, W2 - fw))          # a column run clear of the slab's side bands
	for i in fw:
		var x := cx0 + i
		var fx := posmod(x - xs, fw)
		for j in dep:
			var yy := top + j
			if yy < 0 or yy >= H2: continue
			var fi := ((F0 + j) * fw + fx) * 4
			if fd[fi + 3] < 128: continue
			var ag := clampf(1.0 - (j + 0.5) / 13.0, 0.0, 1.0)
			var gk := 0.08 + 0.42 * clampf((j + 0.5) / dep, 0.0, 1.0)
			var ti := (yy * W2 + mini(x, W2 - 1)) * 4
			var oi := (j * fw + fx) * 4
			for ch in 3:
				var v := float(fd[fi + ch])
				if ag > 0.0: v = lerpf(v, float(td[ti + ch]), ag)
				tile[oi + ch] = int(clampf(roundf(lerpf(v, dk[ch], gk)), 0.0, 255.0))
			tile[oi + 3] = 255
	var timg := Image.create_from_data(fw, dep, false, Image.FORMAT_RGBA8, tile)
	var fc := Image.create(W2, H2, false, Image.FORMAT_RGBA8)
	var a := maxi(0, L + 2)
	var b := mini(W2, R - 2)
	var x := xs
	while x < b:
		var u0 := maxi(x, a)
		var u1 := mini(x + fw, b)
		if u1 > u0: fc.blit_rect(timg, Rect2i(u0 - x, 0, u1 - u0, dep), Vector2i(u0, top))
		x += fw
	# taper toward both ends (smoothstep over 30 art px)
	var clear := Color(0, 0, 0, 0)
	for c in range(a, b):
		var k := minf(1.0, minf(c + 0.5 - L - 2, R - 2 - (c + 0.5)) / 30.0)
		if k >= 1.0: continue
		var bot := top + int(jr(dep * (0.15 + 0.85 * maxf(k, 0.0) * maxf(k, 0.0) * (3.0 - 2.0 * maxf(k, 0.0)))))
		if k < 0.0: bot = top
		if bot < top + dep: fc.fill_rect(Rect2i(c, bot, 1, top + dep - bot), clear)
	var band := Rect2i(0, maxi(0, top - 1), W2, mini(H2, top + dep + 2) - maxi(0, top - 1))
	var s := _solid(W2, H2, DARK)
	for o in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		out.blit_rect_mask(s, fc, band, band.position + o)
	out.blend_rect(fc, band, band.position)

## groundMass(x0, x1, yb, steps): steps = [[x0, x1, top], ...]; G = the floor, surf = its lip depth
static func ground(x0: float, x1: float, yb: float, steps: Array, G: float, surf: float) -> Dictionary:
	var tex := _rtex
	var xs := {x0: true, x1: true}
	for s in steps:
		xs[maxf(x0, s[0])] = true
		xs[minf(x1, s[1])] = true
	var xl: Array = xs.keys()
	xl.sort()
	var prof: Array = []
	for i in xl.size() - 1:
		var m: float = (xl[i] + xl[i + 1]) / 2.0
		var ty := G - surf
		for s in steps:
			if m > s[0] and m < s[1]: ty = minf(ty, s[2])
		if not prof.is_empty() and prof[-1][2] == ty: prof[-1][1] = xl[i + 1]
		else: prof.append([xl[i], xl[i + 1], ty])
	var ymin := 1e9
	for p in prof: ymin = minf(ymin, p[2])
	var oy := ymin - PAD * 2
	var ox := x0 - PAD * 2
	var W2 := int(ceilf((x1 - x0) / 2.0)) + PAD * 2
	var H2 := int(ceilf((yb - oy) / 2.0))
	var ax := func(v: float) -> float: return jr((v - ox) / 2.0)
	var ay := func(v: float) -> float: return jr((v - oy) / 2.0)
	var B := H2 + 4
	var jag := 3.0
	var pts := PackedVector2Array()
	pts.append(Vector2(ax.call(x0), B))
	pts.append(Vector2(ax.call(x0), ay.call(prof[0][2])))
	var n := prof.size()
	for i in n:
		var Y: float = ay.call(prof[i][2])
		var XB: float = ax.call(prof[i][1])
		pts.append(Vector2(XB - (3.0 if i < n - 1 else 0.0), Y))
		if i < n - 1:
			var Y2: float = ay.call(prof[i + 1][2])
			var sd: float = prof[i][1] * 0.37
			if Y2 < Y:
				pts.append(Vector2(XB, Y))
				var y := Y
				while y > Y2 + 3.0:
					pts.append(Vector2(XB + jr((thsh(y, sd) - 0.5) * jag * 2.0), y))
					y -= 5.0
				pts.append(Vector2(XB, Y2 + 3.0))
				pts.append(Vector2(XB + 3.0, Y2))
			else:
				pts.append(Vector2(XB, Y + 3.0))
				var y := Y + 3.0
				while y < Y2:
					pts.append(Vector2(XB + jr((thsh(y, sd) - 0.5) * jag * 2.0), y))
					y += 5.0
				pts.append(Vector2(XB, Y2))
	pts.append(Vector2(ax.call(x1), B))
	var out := Image.create(W2, H2, false, Image.FORMAT_RGBA8)
	outline_poly(out, pts, DARK, [Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 0), Vector2i(0, 2)])
	var inner := pattern(tex, W2, H2, jrem(int(jr(-ox / 2.0)), tex.get_width()), jrem(int(jr(-oy / 2.0)), tex.get_height()))
	var lit := Color8(190, 175, 220)
	var shd := Color(16 / 255.0, 10 / 255.0, 26 / 255.0)
	for i in n - 1:
		var XB := int(ax.call(prof[i][1]))
		var Y: float = ay.call(prof[i][2])
		var Y2: float = ay.call(prof[i + 1][2])
		var t0 := int(minf(Y, Y2))
		var b0 := int(maxf(Y, Y2)) + 10
		if Y2 < Y: blend_vgrad(inner, Rect2i(XB - 4, t0, 7, b0 - t0), t0, b0, Color(lit, 0.18), Color(lit, 0.0))
		else: blend_vgrad(inner, Rect2i(XB - 6, t0, 10, b0 - t0), t0, b0, Color(shd, 0.32), Color(shd, 0.0))
	for i in n - 1:
		var XB: float = ax.call(prof[i][1])
		var Y: float = ay.call(prof[i][2])
		var Y2: float = ay.call(prof[i + 1][2])
		if Y == Y2: continue
		var low := maxf(Y, Y2)
		inner.blend_rect(_ao, Rect2i(0, 0, 56, 40), Vector2i(int(XB) - 28, int(low) - 26))
	var gy: float = ay.call(G)
	blend_vgrad(inner, Rect2i(0, int(gy), W2, H2), gy, H2, Color(shd, 0.0), Color(shd, 0.45))
	fill_poly(out, pts, Color.WHITE, inner)
	var lw := _lip.get_width()
	for p in prof:
		var Lx := int(ax.call(p[0])) + 1
		var Rx := int(ax.call(p[1])) - 1
		lip(out, Lx, Rx, int(ay.call(p[2])) - 2, Lx - posmod(int(jr(p[0] / 2.0)), lw))
	return _mass(out, ox, oy)

## wallMass(x0, x1, h, seed, yb, pk): a back wall standing on yb
static func wall(x0: float, x1: float, h: float, seed: int, yb: float, pk := 1.0) -> Dictionary:
	var sd := [seed]
	var rnd := func() -> float:
		sd[0] = (sd[0] * 9301 + 49297) % 233280
		return float(sd[0]) / 233280.0
	var pad := 14
	var Wa := int(ceilf((x1 - x0) / 2.0))
	var Ha := int(ceilf(h / 2.0))
	var W2 := Wa + pad * 2
	var H2 := Ha + pad + 12
	var L := pad
	var R := W2 - pad
	var T := pad
	var B := H2 + 2
	var tl := jr(Wa * (0.08 + rnd.call() * 0.08))
	var tr := jr(Wa * (0.08 + rnd.call() * 0.08))
	var peaks: Array = []
	for i in 1 + int(rnd.call() * 3):
		var px: float = L + tl + rnd.call() * (Wa - tl - tr)
		peaks.append([px, (12.0 + rnd.call() * 18.0) * pk])
	var crest: Array = []
	var x := L + tl
	while x <= R - tr:
		var y := T + 26.0
		for p in peaks: y -= maxf(0.0, p[1] * (1.0 - absf(x - p[0]) / (Wa * 0.35)))
		y += jr((rnd.call() - 0.5) * 8.0)
		crest.append(Vector2(minf(x, R - tr), jr(y)))
		x += 10 + floorf(rnd.call() * 14.0)
	crest.append(Vector2(R - tr, jr(T + 26 + rnd.call() * 8.0)))
	var side := func(sx: float, yA: float, yB: float, dr: float) -> Array:
		var o: Array = []
		var yy := yA
		while yy < yB:
			var k := (yy - yA) / (yB - yA)
			o.append(Vector2(jr(sx + dr * (1.0 - k) * (tl if dr < 0.0 else tr) * -1.0 + (rnd.call() - 0.5) * 6.0), yy))
			yy += 8 + floorf(rnd.call() * 10.0)
		return o
	var pts := PackedVector2Array()
	pts.append(Vector2(L, B))
	var sl: Array = side.call(float(L), crest[0].y, float(B), -1.0)
	sl.reverse()
	for p in sl: pts.append(p)
	for p in crest: pts.append(p)
	for p in side.call(float(R), crest[-1].y, float(B), 1.0): pts.append(p)
	pts.append(Vector2(R, B))
	var inner := pattern(_kit, W2, H2, jrem(int(jr(-x0 / 2.0)), _kit.get_width()), 0)
	var dk := Color(14 / 255.0, 9 / 255.0, 26 / 255.0)
	blend_vgrad(inner, Rect2i(0, 0, W2, H2), T, B, Color(dk, 0.18), Color(dk, 0.55))
	var out := Image.create(W2, H2, false, Image.FORMAT_RGBA8)
	outline_poly(out, pts, Color8(18, 12, 26), [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)])
	fill_poly(out, pts, Color.WHITE, inner)
	return _mass(out, x0 - pad * 2, yb - h - pad * 2)

## the soft drop shadow of a ledge (drawTerrain o.shadow): its silhouette in black, padded 12, blurred ~3 art px
static func shadow_of(m: Dictionary) -> Dictionary:
	if m.has("sb"): return m["sb"]
	var src: Image = m["img"]
	var pad := 12
	var W := src.get_width() + pad * 2
	var H := src.get_height() + pad * 2
	var s := Image.create(W, H, false, Image.FORMAT_RGBA8)
	s.blit_rect_mask(_solid(src.get_width(), src.get_height(), Color.BLACK), src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(pad, pad))
	s.resize(maxi(1, W / 4), maxi(1, H / 4), Image.INTERPOLATE_BILINEAR)
	s.resize(W, H, Image.INTERPOLATE_BILINEAR)
	m["sb"] = {"tex": ImageTexture.create_from_image(s), "pad": pad}
	return m["sb"]


# ---------- the light on the edges ----------
## paintRim's weights: the facing band gets most, its neighbour the rest, the next two 0.18 of theirs
static func rim_weights(u: Vector2) -> Array:
	var ang := fposmod(atan2(u.y, u.x), TAU)
	var f := ang / (PI / 4.0)
	var i0 := int(floorf(f)) % 8
	var i1 := (i0 + 1) % 8
	var t := f - floorf(f)
	return [[i0, 1.0 - t], [i1, t], [(i0 + 7) % 8, 0.18 * (1.0 - t)], [(i1 + 1) % 8, 0.18 * t]]

## drawTerrain's light pass for one mass at world (x, y, w, h): the rim colour per DIR8 band (rc) and the dark far side
## (rd) from the lights [{x, y, r, a, c, k}]; `gain` = o.rim
static func rim_params(x: float, y: float, w: float, h: float, lights: Array, gain: float) -> Array:
	var rc := PackedVector4Array()
	rc.resize(8)
	var rd := PackedFloat32Array()
	rd.resize(8)
	var best = null
	for l in lights:
		var R: float = l["r"] * 2.1
		var nx := clampf(l["x"], x, x + w)
		var ny := clampf(l["y"], y, y + h)
		var dist := Vector2(l["x"] - nx, l["y"] - ny).length()
		if dist > R: continue
		var a0: float = 1.06 if l["k"] == "fire" else float(l.get("a", 1.0))
		var k := pow(1.0 - dist / R, 1.4) * a0 * gain * 1.5
		var u := Vector2(l["x"] - (x + w / 2.0), l["y"] - (y + h / 2.0))
		if dist > 0.0: u = Vector2(l["x"] - nx, l["y"] - ny)
		var n := u.length()
		u = u / (n if n > 0.0 else 1.0)
		var c: Color = l["c"]
		for iw in rim_weights(u):
			if iw[1] <= 0.01: continue
			var al := minf(1.0, k * iw[1])
			var v: Vector4 = rc[iw[0]]
			rc[iw[0]] = Vector4(v.x + c.r * al, v.y + c.g * al, v.z + c.b * al, 1.0)
		if best == null or k > best[0]: best = [k, u]
	if best != null:
		for iw in rim_weights(-best[1]):
			if iw[1] <= 0.01: continue
			rd[iw[0]] = minf(1.0, best[0] * 0.55 * iw[1])
	return [rc, rd]
