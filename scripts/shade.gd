extends Node2D
## The shade mask of the prototype's drawLighting (estelle-prototype.html 2904-2916, 3110-3166): black where it is shaded,
## built at half size in a SubViewport and laid over the world at 0.62 (before the ambient multiply, lit.gd).
##  - sun shadow volumes: every occluder's silhouette smeared along the sun direction (lit.gd sun_dir) at 0.34 x sun,
##    clipped at its own foot, so the shade leans and stretches with the hour
##  - the level's own deep shade (the town: 0.55 under the terraces over the lower plaza)
##  - cloud shadows: a drifting tiling cookie (assets/light/cloud_cookie.png, the prototype's cloudCookie baked), kept to
##    solid things only: the ground below the surface line, occluders, props and the heroine; never the sky
##  - the lights cut holes in it (lightShape x 1.3 x boost)
## The level provides: shade_occluders() / shade_props() -> [[tex, x, y_bottom, sink, flip, scale, tree], ...],
## surf_top(x), cloud_bottom(x) (where cloud shade stops: the town's plaza), shade_extra(ci), and G (ground y).
## Phones: a third of the screen instead of half, five smear steps instead of nine.

const LIT := preload("res://scripts/lit.gd")
const COOKIE := preload("res://assets/light/cloud_cookie.png")
const PK := 2.0
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
var d_sun: Node2D
var d_cloud: Node2D
var d_cut: Node2D
var cloud_mat: ShaderMaterial
var k := 0.5
var steps := 8
var sun := 0.0
var dir := Vector2(0, 1)
var lights: Array = []
var vr := Rect2()
var clock := -1.0                 # tests: a fixed cloud clock in seconds (the prototype's P.t / 1000)


func _init(a, lv) -> void:
	arena = a
	level = lv
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if arena.low_end:
		k = 0.34
		steps = 4
	sv = SubViewport.new()
	sv.disable_3d = true
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(sv)
	d_sun = Node2D.new()
	d_sun.draw.connect(_draw_sun)
	sv.add_child(d_sun)
	d_cloud = Node2D.new()
	cloud_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CLOUD_SH
	cloud_mat.shader = sh
	cloud_mat.set_shader_parameter("ck", COOKIE)
	d_cloud.material = cloud_mat
	d_cloud.draw.connect(_draw_cloud)
	sv.add_child(d_cloud)
	d_cut = Node2D.new()
	var cm := ShaderMaterial.new()
	var sh2 := Shader.new()
	sh2.code = CUT_SH
	cm.shader = sh2
	d_cut.material = cm
	d_cut.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	d_cut.draw.connect(_draw_cut)
	sv.add_child(d_cut)

## per step: the sun (strength, direction) and the lights that cut the shade (with their boost)
func update(T: Dictionary, h: float, ls: Array) -> void:
	sun = T["sun"]
	dir = LIT.sun_dir(h)
	lights = ls
	vr = arena.view_rect()
	var vs: Vector2 = get_viewport_rect().size
	var sz := Vector2i(maxi(2, int(ceilf(vs.x * k))), maxi(2, int(ceilf(vs.y * k))))
	if sv.size != sz: sv.size = sz
	var s: float = sz.x / vr.size.x
	sv.canvas_transform = Transform2D(0.0, Vector2(s, s), 0.0, -vr.position * s)
	var t := Time.get_ticks_msec() / 1000.0 if clock < 0.0 else clock
	var A := minf(1.0, 1.35 * sun)
	cloud_mat.set_shader_parameter("org", Vector2(fmod(t * 18.0, 1800.0), level.G - 460.0))
	cloud_mat.set_shader_parameter("alpha", 1.0 - (1.0 - A) * (1.0 - A))      # the prototype draws the cloud canvas twice

func redraw() -> void:
	queue_redraw()
	d_sun.queue_redraw()
	d_cloud.queue_redraw()
	d_cut.queue_redraw()

func _draw() -> void:
	draw_texture_rect(sv.get_texture(), vr, false, Color(1, 1, 1, 0.62))

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

func _draw_sun() -> void:
	var vx0 := vr.position.x - 300.0
	var vx1 := vr.end.x + 300.0
	if sun > 0.01:
		var n := dir.length()
		var u := dir / n
		var col := Color(0, 0, 0, 0.34 * sun)
		for o in level.shade_occluders():
			if o.size() > 7 and o[7]: continue          # its ground shadow is baked
			var b := box(o)
			if b.end.x + 400.0 < vx0 or b.position.x - 50.0 > vx1: continue
			var yb: float = o[2]
			var Ln := maxf(120.0, (yb - b.position.y) * 1.15 * n)
			var st := maxf(10.0, Ln / steps)
			var d := 0.0
			while d <= Ln:
				var p := b.position + u * d
				_sil(d_sun, o, p, yb + 4.0 - p.y, col)          # clipped at the foot
				d += st
	level.shade_extra(d_sun)

## cloud shadows on what is solid: the ground under the surface line and every standing thing
func _draw_cloud() -> void:
	if sun <= 0.05: return
	var vx0 := vr.position.x - 40.0
	var vx1 := vr.end.x + 40.0
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	var x := floorf(vx0 / 24.0) * 24.0
	while x <= vx1 + 24.0:
		var t: float = level.surf_top(x)
		var b: float = level.cloud_bottom(x)
		top.append(Vector2(x, t))
		bot.append(Vector2(x, maxf(t, b)))
		x += 24.0
	# one quad per column keeps every polygon simple where the bottom line jumps
	for i in top.size() - 1:
		if bot[i].y - top[i].y < 0.5 and bot[i + 1].y - top[i + 1].y < 0.5: continue
		d_cloud.draw_colored_polygon(PackedVector2Array([top[i], top[i + 1], bot[i + 1], bot[i]]), Color.WHITE)
	var all: Array = level.shade_occluders() + level.shade_props()
	for o in all:
		var bx := box(o)
		if bx.end.x < vx0 or bx.position.x > vx1: continue
		if o[2] > level.cloud_bottom(bx.get_center().x) + 1.0: continue
		_sil(d_cloud, o, bx.position, bx.size.y, Color.WHITE)
	# clouds pass over people too (and the practice dummies)
	if level.kind == "training":
		for dm in arena.dummies:
			if dm.visible and dm.get("tex") != null and dm.dead <= 0.0:
				var tw: float = dm.tex.get_width() * 0.82
				var th: float = dm.tex.get_height() * 0.82
				d_cloud.draw_texture_rect(dm.tex, Rect2(dm.position.x - tw / 2.0, dm.position.y - th, tw, th), false)
	var P = arena.player
	if P.visible and P.position.y <= level.cloud_bottom(P.position.x) + 1.0:
		P.draw_frame(P.who, P.anim, P.f, P.position, P.dir, Color.WHITE, "", d_cloud)

func _draw_cut() -> void:
	var vx0 := vr.position.x - 300.0
	var vx1 := vr.end.x + 300.0
	for l in lights:
		if l["x"] < vx0 or l["x"] > vx1: continue
		LIT.shape(d_cut, l, 1.3 * l.get("boost", 1.0))
