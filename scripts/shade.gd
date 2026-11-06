extends Node2D
## The town's sun shade (owner 2026-11-07: "스프라이트 검게 만들어서 덧붙이는 거임? ... 빛과 그림자 이론을 기반 삼아서"),
## one sun for everything (lit.gd sun3: where it is, how high), drawn as a MASK at the game's pixel size in a
## SubViewport (1 texel = 2 screen px, snapped to the world's 2-px grid: crisp, stepped edges that do not crawl) and laid
## over the world as LIGHT, not as black:
##   shade = albedo x sky light   (a cool blue-violet multiply: what only the sky reaches)
##   sun   = albedo x sun light   (a touch of warmth in the low sun)
## Mask passes, in this order:
##  1. ground: each caster's shadow ON THE GROUND PLANE. Every column of its silhouette (from its lowest to its highest
##     opaque pixel) is a post; the post's shadow runs away from the sun, as long as the post is tall over tan(sun
##     height), across the plane and into its depth (the street in front when the sun is behind the town). The caster's
##     footprint reaches back into the plane (buildings deep, trees round their trunk). Clipped to the ground band.
##  2. everything standing is cleared from it (the ground's shadow lies under them, not on them)
##  3. standing things: each caster's silhouette slid down the sun's slope (lit.gd sun_dir) onto what stands beside it,
##     clipped at its foot, and NEVER on itself (the shader drops every texel inside its own unmoved silhouette): a
##     flat front cannot shade itself; its form shade is baked in its sprite (bake_light2.py)
##  4. the level's own deep shade (the town: under the terraces over the lower plaza)
##  5. cloud shadows: a drifting tiling cookie (assets/light/cloud_cookie.png), kept to solid things only
##  6. the lights cut holes in it (lightShape x 1.3 x boost)
## The level provides: shade_occluders() / shade_props() -> [[tex, x, y_bottom, sink, flip, scale, tree], ...],
## surf_top(x), cloud_bottom(x) (where cloud shade stops: the town's plaza), shade_extra(ci), and G (ground y).
## Phones: a third of the screen (not grid-snapped).

const LIT := preload("res://scripts/lit.gd")
const COOKIE := preload("res://assets/light/cloud_cookie.png")
const PK := 2.0
const KD := 0.45          # the ground plane seen from the side: 1 px of depth = KD px on screen
const FRONT := 26.0       # the ground band in front of the foot line (and RAISE behind it: town.gd)
const SELF_SH := """
shader_type canvas_item;
render_mode blend_add;
// one slid copy of a caster's silhouette into the red channel (COLOR.rg = 0.5 + (the copy's offset in UV) / 8).
// A texel that also lies inside the caster's own unmoved silhouette is dropped: nothing shades itself.
varying vec2 off;
void vertex() { off = (COLOR.rg - 0.5) * 8.0; }    // (the fragment's COLOR comes multiplied by the texture)
void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 su = UV + off;     // the same screen texel in the unmoved silhouette
	float s = (su.x >= 0.0 && su.x <= 1.0 && su.y >= 0.0 && su.y <= 1.0) ? texture(TEXTURE, su).a : 0.0;
	COLOR = (a > 0.5 && s < 0.5) ? vec4(1.0, 0.0, 0.0, 1.0) : vec4(0.0);
}
"""
const SOLID_SH := """
shader_type canvas_item;
// a silhouette as a flat colour (the modulate), whatever the texture's own colours
varying vec4 c;
void vertex() { c = COLOR; }
void fragment() {
	COLOR = vec4(c.rgb, texture(TEXTURE, UV).a > 0.5 ? c.a : 0.0);
}
"""
const COMP_SH := """
shader_type canvas_item;
render_mode blend_mul;
// the mask as light: 0 = in the sun, 1 = only the sky. TEXTURE: the ground / deep / cloud shade (alpha);
// st: the standing shade (red) where something solid stands (green)
uniform vec3 sky = vec3(0.6, 0.66, 0.9);
uniform vec3 sunc = vec3(1.0);
uniform sampler2D st : filter_nearest;
void fragment() {
	vec4 b = texture(st, UV);
	float a = max(texture(TEXTURE, UV).a, b.r * b.g);
	COLOR = vec4(mix(sunc, sky, a), 1.0);
}
"""
const CUT_SH := """
shader_type canvas_item;
render_mode blend_mul;
// multiplies colour AND alpha by (1 - a): where the drawn shape is opaque the target is cleared, everywhere else in
// its rectangle (transparent texels) it is left alone. (rgb 0 there used to black out the sprite's whole cell, which
// put out the hall windows around the heroine at night.)
void fragment() {
	float a = texture(TEXTURE, UV).a * COLOR.a;
	COLOR = vec4(vec3(1.0 - a), 1.0 - a);
}
"""
const CLOUD_SH := """
shader_type canvas_item;
uniform sampler2D ck : filter_linear, repeat_enable;
uniform vec2 org;
uniform vec2 csize = vec2(1800.0, 840.0);
uniform float alpha = 1.0;
varying vec2 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec2 u = (wp - org) / csize;
	float c = (u.y < 0.0 || u.y > 1.0) ? 0.0 : texture(ck, vec2(fract(u.x), u.y)).r;
	COLOR = vec4(0.0, 0.0, 0.0, texture(TEXTURE, UV).a * c * alpha);
}
"""

var arena
var level
var sv: SubViewport
var sv2: SubViewport               # the standing shade: red = slid silhouettes, green = what can receive them
var d_rcv: Node2D
var d_ground: Node2D
var d_clear: Node2D
var d_sun: Node2D
var d_cloud: Node2D
var d_cut: Node2D
var cloud_mat: ShaderMaterial
var comp_mat: ShaderMaterial
var k := 0.5
var steps := 10
var sun := 0.0
var s3 := Vector3(0, 1, 0)
var dir := Vector2(0, 1)
var lights: Array = []
var vr := Rect2()
var org := Vector2.ZERO
var clock := -1.0                 # tests: a fixed cloud clock in seconds (the prototype's P.t / 1000)
var gcache := {}                  # caster -> [the sun it was made for, its ground shadow triangles]
var prof := {}                    # texture -> [[x, lowest opaque y, highest opaque y] every 4 texture px]


func _mat(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = code
	m.shader = sh
	return m

func _node(fn: Callable, m: Material, into: SubViewport = null) -> Node2D:
	var n := Node2D.new()
	n.material = m
	n.draw.connect(fn)
	(into if into != null else sv).add_child(n)
	return n

func _vp() -> SubViewport:
	var v := SubViewport.new()
	v.disable_3d = true
	v.transparent_bg = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(v)
	return v

func _init(a, lv) -> void:
	arena = a
	level = lv
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if arena.low_end:
		k = 0.34
		steps = 5
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	comp_mat = _mat(COMP_SH)
	material = comp_mat
	sv = _vp()
	sv2 = _vp()
	d_ground = _node(_draw_ground, null)
	d_clear = _node(_draw_clear, _mat(CUT_SH))
	d_rcv = _node(_draw_rcv, _mat(SOLID_SH), sv2)
	d_sun = _node(_draw_sun, _mat(SELF_SH), sv2)
	var c2 := _node(_draw_cut2, _mat(CUT_SH), sv2)
	c2.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	comp_mat.set_shader_parameter("st", sv2.get_texture())
	cloud_mat = _mat(CLOUD_SH)
	cloud_mat.set_shader_parameter("ck", COOKIE)
	d_cloud = _node(_draw_cloud, cloud_mat)
	d_cut = _node(_draw_cut, _mat(CUT_SH))
	d_cut.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

## per step: the sun (strength, direction, colour) and the lights that cut the shade (with their boost)
func update(T: Dictionary, h: float, ls: Array) -> void:
	sun = T["sun"]
	s3 = LIT.sun3(h)
	dir = LIT.sun_dir(h)
	lights = ls
	vr = arena.view_rect()
	var vs: Vector2 = get_viewport_rect().size
	org = vr.position if arena.low_end else (vr.position / PK).floor() * PK
	var sz := Vector2i(maxi(2, int(ceilf((vr.size.x + PK) * k))), maxi(2, int(ceilf((vr.size.y + PK) * k))))
	for v in [sv, sv2]:
		if v.size != sz: v.size = sz
		v.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, -org * k)
	var t := Time.get_ticks_msec() / 1000.0 if clock < 0.0 else clock
	var A := minf(1.0, 1.35 * sun)
	cloud_mat.set_shader_parameter("org", Vector2(fmod(t * 18.0, 1800.0), level.G - 460.0))
	cloud_mat.set_shader_parameter("alpha", 0.3 * (1.0 - (1.0 - A) * (1.0 - A)))
	# the light: the sky's blue in the shade, deeper and more violet as the sun sinks; the low sun itself warm
	var low := clampf(1.0 - s3.y / 0.6, 0.0, 1.0)
	var sky := Color(0.60, 0.67, 0.92).lerp(Color(0.52, 0.50, 0.80), low)
	var sk := Color(0.70, 0.70, 0.80).lerp(sky, A)            # at night only the deep shade is left: a plain dim
	comp_mat.set_shader_parameter("sky", Vector3(sk.r, sk.g, sk.b))
	var sc := Color(1, 1, 1).lerp(Color(1.0, 0.975, 0.92).lerp(Color(1.0, 0.93, 0.80), low), A)
	comp_mat.set_shader_parameter("sunc", Vector3(sc.r, sc.g, sc.b))

func redraw() -> void:
	queue_redraw()
	for n in sv2.get_children(): n.queue_redraw()
	d_ground.queue_redraw()
	d_clear.queue_redraw()
	d_sun.queue_redraw()
	d_cloud.queue_redraw()
	d_cut.queue_redraw()

func _draw() -> void:
	draw_texture_rect(sv.get_texture(), Rect2(org, Vector2(sv.size) / k), false)

## the silhouette rectangle of an occluder entry
static func box(o: Array) -> Rect2:
	var tx: Texture2D = o[0]
	var s: float = o[5]
	var w := tx.get_width() * s
	var h := tx.get_height() * s
	return Rect2(o[1], roundf(o[2] - h + o[3] * PK * s), w, h)

func _sil(ci: CanvasItem, o: Array, at: Vector2, h_vis: float, col: Color) -> void:
	var tx: Texture2D = o[0]
	var s: float = o[5]
	var w := tx.get_width() * s
	var hv := minf(tx.get_height() * s, h_vis)
	if hv <= 0.5: return
	var src := Rect2(0, 0, tx.get_width(), hv / s)
	if o[4]:
		ci.draw_set_transform(Vector2(at.x + w, 0.0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(tx, Rect2(0, at.y, w, hv), src, col)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(tx, Rect2(at.x, at.y, w, hv), src, col)

## a texture's posts: every 4 px, its lowest and highest opaque row (texture px, from the top)
func _prof(tx: Texture2D) -> Array:
	if prof.has(tx): return prof[tx]
	var im := tx.get_image()
	if im.is_compressed(): im.decompress()
	var out: Array = []
	var w := im.get_width()
	var h := im.get_height()
	var x := 0
	while x < w:
		var top := -1
		var bot := -1
		for y in h:
			var o := false
			for dx in 4:
				if x + dx < w and im.get_pixel(x + dx, y).a > 0.5:
					o = true
					break
			if o:
				if top < 0: top = y
				bot = y
		if top >= 0: out.append([x, top, bot])
		x += 4
	prof[tx] = out
	return out

## a convex polygon cut to y0 <= y <= y1
static func _clip_y(p: PackedVector2Array, y0: float, y1: float) -> PackedVector2Array:
	for side in 2:
		var q := PackedVector2Array()
		var n := p.size()
		for i in n:
			var a := p[i]
			var b := p[(i + 1) % n]
			var ina := a.y >= y0 if side == 0 else a.y <= y1
			var inb := b.y >= y0 if side == 0 else b.y <= y1
			if ina: q.append(a)
			if ina != inb:
				var yy := y0 if side == 0 else y1
				q.append(a.lerp(b, (yy - a.y) / (b.y - a.y)))
		p = q
		if p.size() < 3: return p
	return p

## 1. the ground plane's shade
func _draw_ground() -> void:
	if sun > 0.01:
		var vx0 := vr.position.x - 40.0
		var vx1 := vr.end.x + 40.0
		var hl := Vector2(s3.x, s3.z)
		var cot := sqrt(1.0 - s3.y * s3.y) / maxf(s3.y, 0.05)
		var away := -hl.normalized() if hl.length() > 0.01 else Vector2.ZERO
		var raise: float = level.get("RAISE") if level.get("RAISE") != null else 12.0
		for o in level.shade_occluders():
			var b := box(o)
			var reach := minf(b.size.y * cot, b.size.y * 2.2)
			if b.end.x + reach < vx0 or b.position.x - reach > vx1: continue
			# the shape only changes with the sun: kept per caster until the sun has moved
			var key := "%s:%d:%d" % [o[0].get_rid(), int(o[1]), int(o[2])]
			var c = gcache.get(key)
			if c == null or (c[0] as Vector3).distance_to(s3) > 0.004:
				c = [s3, _ground_tris(o, b, away, cot, reach, raise)]
				gcache[key] = c
			var tri: PackedVector2Array = c[1]
			if tri.size() >= 3:
				var cols := PackedColorArray()
				cols.resize(tri.size())
				cols.fill(Color(0, 0, 0, 1))
				var idx := PackedInt32Array()
				idx.resize(tri.size())
				for i in tri.size(): idx[i] = i
				RenderingServer.canvas_item_add_triangle_array(d_ground.get_canvas_item(), idx, tri, cols)
	level.shade_extra(d_ground)

## one caster's shadow on the ground plane as triangles: a post per 4 texture px of its silhouette
func _ground_tris(o: Array, b: Rect2, away: Vector2, cot: float, reach: float, raise: float) -> PackedVector2Array:
	var yb: float = o[2]
	var tx: Texture2D = o[0]
	var s: float = o[5]
	var tree: bool = o[6]
	# the footprint's depth: a building runs back the whole band, a tree is round its trunk
	var dback := (raise + 4.0) / KD if not tree else b.size.x * 0.3
	var dfront := 0.0 if not tree else b.size.x * 0.3
	var y0 := yb - raise - 2.0
	var y1 := yb + FRONT
	var out := PackedVector2Array()
	for pp in _prof(tx):
		var x: float = b.position.x + (tx.get_width() - pp[0] - 4.0 if o[4] else pp[0]) * s
		var h_hi: float = b.size.y - pp[1] * s - o[3] * PK * s       # the post: from h_lo up to h_hi over the ground
		var h_lo: float = maxf(0.0, (tx.get_height() - pp[2]) * s - o[3] * PK * s)
		h_hi = minf(h_hi, reach / maxf(cot, 0.01))
		var pts := PackedVector2Array()
		for hh in [h_lo, h_hi]:
			var L: float = hh * cot
			var off := Vector2(away.x * L, away.y * L * KD)
			for dx in [0.0, 4.0 * s]:
				for dd in [-dback, dfront]:
					pts.append(Vector2(x + dx, yb + dd * KD) + off)
		var hull := Geometry2D.convex_hull(pts)
		if hull.size() > 1: hull.remove_at(hull.size() - 1)
		hull = _clip_y(hull, y0, y1)
		for i in range(1, hull.size() - 1):
			out.append(hull[0]); out.append(hull[i]); out.append(hull[i + 1])
	return out

## 2. the ground's shade does not climb what stands on it (what stands takes the standing shade, 3.)
func _draw_clear() -> void:
	if sun <= 0.01: return
	for o in level.shade_occluders() + level.shade_props():
		var b := box(o)
		if b.end.x < vr.position.x - 40.0 or b.position.x > vr.end.x + 40.0: continue
		_sil(d_clear, o, b.position, b.size.y, Color.WHITE)

## 3. what stands beside a caster, in its shade (never the caster itself)
func _draw_sun() -> void:
	if sun <= 0.01: return
	var vx0 := vr.position.x - 300.0
	var vx1 := vr.end.x + 300.0
	var n := dir.length()
	var u := dir / n
	for o in level.shade_occluders():
		var b := box(o)
		if b.end.x + 400.0 < vx0 or b.position.x - 50.0 > vx1: continue
		var yb: float = o[2]
		var Ln := minf((yb - b.position.y) * n, 900.0)
		var st := maxf(PK, Ln / float(steps * 4))
		var d := st
		while d <= Ln:
			var p := (b.position + u * d).round()
			var ofs := (p - b.position) / b.size
			if o[4]: ofs.x = -ofs.x
			var hv := minf(b.size.y, yb + 4.0 - p.y)
			if hv > 0.5:
				# a polygon, not a rect: its vertex colours reach the shader's vertex() (a batched rect's modulate does not)
				var c := Color(0.5 + ofs.x / 8.0, 0.5 + ofs.y / 8.0, 1.0, 1.0)
				var v1 := hv / b.size.y
				var u0 := 1.0 if o[4] else 0.0
				d_sun.draw_polygon(PackedVector2Array([p, p + Vector2(b.size.x, 0), p + Vector2(b.size.x, hv), p + Vector2(0, hv)]),
					PackedColorArray([c, c, c, c]), PackedVector2Array([Vector2(u0, 0), Vector2(1.0 - u0, 0), Vector2(1.0 - u0, v1), Vector2(u0, v1)]), o[0])
			d += st

## what the standing shade can fall on: the ground and everything standing on it (never the sky or the far hills)
func _draw_rcv() -> void:
	if sun <= 0.01: return
	_solid(d_rcv, Color(0, 1, 0, 1), 20.0)

func _draw_cut2() -> void:
	_draw_cut_on(d_cut2_node())

func d_cut2_node() -> CanvasItem:
	return sv2.get_child(sv2.get_child_count() - 1)

## cloud shadows on what is solid: the ground under the surface line and every standing thing
func _draw_cloud() -> void:
	if sun <= 0.05: return
	_solid(d_cloud, Color.WHITE, 0.0)

## the ground under the surface line (from `up` px over it) and every standing thing, the heroine and the dummies too
func _solid(ci: CanvasItem, col: Color, up: float) -> void:
	var vx0 := vr.position.x - 40.0
	var vx1 := vr.end.x + 40.0
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var x := floorf(vx0 / 24.0) * 24.0
	while x <= vx1 + 24.0:
		var t: float = level.surf_top(x) - up
		var b: float = level.cloud_bottom(x)
		top.append(Vector2(x, t))
		bot.append(Vector2(x, maxf(t, b)))
		x += 24.0
	# one quad per column keeps every polygon simple where the bottom line jumps
	for i in top.size() - 1:
		if bot[i].y - top[i].y < 0.5 and bot[i + 1].y - top[i + 1].y < 0.5: continue
		ci.draw_colored_polygon(PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]]), col)
	var all: Array = level.shade_occluders() + level.shade_props()
	for o in all:
		var bx := box(o)
		if bx.end.x < vx0 or bx.position.x > vx1: continue
		if o[2] > level.cloud_bottom(bx.get_center().x) + 1.0: continue
		_sil(ci, o, bx.position, bx.size.y, col)
	if level.kind == "training":
		for dm in arena.dummies:
			if dm.visible and dm.get("tex") != null and dm.dead <= 0.0:
				var tw: float = dm.tex.get_width() * 0.82
				var th: float = dm.tex.get_height() * 0.82
				ci.draw_texture_rect(dm.tex, Rect2(dm.position.x - tw / 2.0, dm.position.y - th, tw, th), false, col)
	var P = arena.player
	if P.visible and P.position.y <= level.cloud_bottom(P.position.x) + 1.0:
		P.draw_frame(P.who, P.anim, P.f, P.position, P.dir, col, "", ci)

func _draw_cut() -> void:
	_draw_cut_on(d_cut)

func _draw_cut_on(ci: CanvasItem) -> void:
	var vx0 := vr.position.x - 300.0
	var vx1 := vr.end.x + 300.0
	for l in lights:
		if l["x"] < vx0 or l["x"] > vx1: continue
		LIT.shape(ci, l, 1.3 * l.get("boost", 1.0))
