extends RefCounted
## The town's ambient effects, each with a cause in the scene (owner 2026-11-06: "환경이나 그 외에 의한 근거가 있어야지"):
##  - fire: the forge's hearth burns (pixelfx flames clipped to its arch, tools/bake_town_fx.py)
##  - smoke: the forge and the bathhouse chimneys smoke; the puffs swell, curl and lean with the wind (town_life.gust)
##  - heat: the air shimmers over the campfire, the hearth and the forge chimney (a screen-reading shader that shifts
##    whole world-px rows, so the shimmer stays on the pixel grid)
##  - light: buildings and props near a fire or a lamp catch its colour on the edges that face it (rim, like the
##    characters' rimEntity); moths circle the lit lamps at night; by day the sun falls through the big tree's canopy in
##    shafts with dust turning in them
##  - water: wading the river throws a crown of drops and spreads rings; the fountain's stream runs (light sliding
##    down it) and churns where it lands; rain bursts on the roofs and the ground and rings the river
## Everything is drawn on the 1-px world grid (the characters' dot), positions from the placed sprites.

const FORGE_FIRE := preload("res://assets/fx/town/forge_fire.png")
const FORGE_BOX := Vector2(80, 177)            # the hearth box in assets/town/hx/g_forge.png (bake_town_fx.py BOX)
const FORGE_FW := 100
const FORGE_FH := 75
const FORGE_CHIMNEY := Vector2(111, 4)         # the chimney mouths in the hx sprites
const COTTAGE_CHIMNEY := Vector2(320, 2)
const HAZE_SH := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scr : hint_screen_texture, filter_nearest;
uniform float wpx = 1.0;          // screen px per world px
varying vec2 wp;
void vertex() { wp = VERTEX; }
void fragment() {
	// strongest low in the box, fading up and to the sides; each world-px row shifted by a whole world px or not at all
	float fade = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x) * smoothstep(0.0, 0.55, UV.y) * COLOR.a;
	float row = floor(wp.y);
	float w = sin(row * 0.62 + TIME * 6.5 + sin(row * 0.11 + TIME * 1.7) * 2.2) * 1.25 * fade;
	float o = (w > 0.5) ? 1.0 : ((w < -0.5) ? -1.0 : 0.0);
	if (o == 0.0) discard;
	COLOR = vec4(textureLod(scr, SCREEN_UV + vec2(o * wpx * SCREEN_PIXEL_SIZE.x, 0.0), 0.0).rgb, 1.0);
}
"""

const RIM_SH := """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform int n = 0;
uniform vec4 lp[8];               // light: world xy, radius, strength
uniform vec4 lc[8];
varying vec2 wp;
varying float fl;
void vertex() { wp = VERTEX; fl = COLOR.r < 0.5 ? -1.0 : 1.0; }
void fragment() {
	// TEXTURE is the sprite's rim map (tools/bake_town_fx.py rim): its edge pixels with the outward normal in RG
	vec4 e = texture(TEXTURE, UV);
	if (e.a < 0.1) discard;
	vec2 nrm = normalize((e.rg * 2.0 - 1.0) * vec2(fl, 1.0) + vec2(0.0001));
	vec2 c = floor(wp) + 0.5;
	vec3 add = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		if (lp[i].z <= 0.0) continue;
		vec2 d = lp[i].xy - c;
		float dist = length(d);
		float k = 1.0 - dist / lp[i].z;
		if (k <= 0.0) continue;
		float face = dot(nrm, d / max(dist, 0.001));
		if (face < 0.2) continue;
		add += lc[i].rgb * lp[i].w * k * (face > 0.55 ? 1.0 : 0.55) * e.a;
	}
	if (add.r + add.g + add.b < 0.03) discard;
	COLOR = vec4(add, 1.0);
}
"""
const RIM_K := 1.5                # rim strength (PLACEHOLDER)

static var _discs: Array = []
static var _white: Texture2D

var town
var arena
var puffs: Array = []
var emit_t := {}
var haze: Node2D
var haze_mat: ShaderMaterial
var rim: Node2D
var rim_mat: ShaderMaterial
var glow: Node2D                  # additive: moths' glints, the canopy shafts
var moths: Array = []
var drops: Array = []             # water drops in flight: {x, y, vx, vy, t, life, gy}
var rings: Array = []             # rings on water: {x, y, t, life, r}
var roofs: Array = []             # the climbable sprite tops (town.tpl "climb"), where rain lands
var wade_f := -1
var motes: Array = []


func _init(tn) -> void:
	town = tn
	arena = tn.arena
	haze = Node2D.new()
	haze_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = HAZE_SH
	haze_mat.shader = sh
	haze.material = haze_mat
	haze.z_index = 1
	haze.draw.connect(_draw_haze)
	town.add_child(haze)
	rim = Node2D.new()
	rim_mat = ShaderMaterial.new()
	var sh2 := Shader.new()
	sh2.code = RIM_SH
	rim_mat.shader = sh2
	rim.material = rim_mat
	rim.z_index = 10
	rim.z_as_relative = false
	rim.draw.connect(_draw_rim)
	town.add_child(rim)
	glow = Node2D.new()
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	glow.z_index = 10
	glow.z_as_relative = false
	glow.draw.connect(_draw_glow)
	town.add_child(glow)


## a soft round puff on the pixel grid: a solid core, a lighter ring, a dithered rim (radius 1..24, white)
static func disc(r: int) -> Texture2D:
	if _discs.is_empty():
		for rr in range(0, 25):
			var n := rr * 2 + 1
			var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
			for y in n:
				for x in n:
					var d := Vector2(x - rr, y - rr).length() / maxf(0.5, rr + 0.35)
					var a := 0.0
					if d <= 0.55: a = 1.0
					elif d <= 0.8: a = 0.62
					elif d <= 1.0: a = 0.34 if (x + y) % 2 == 0 else 0.0
					im.set_pixel(x, y, Color(1, 1, 1, a))
			_discs.append(ImageTexture.create_from_image(im))
	return _discs[clampi(r, 0, 24)]

static func white() -> Texture2D:
	if _white == null:
		var im := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(im)
	return _white

## where a placed building's (pre-scaled) sprite has its top-left in the world
func origin(k: String):
	for b in town.bld:
		if b[0] != k: continue
		var t: Texture2D = town.hx.get(k, town.tex[k])
		var h: float = t.get_height() if town.hx.has(k) else t.get_height() * town.ks(k)
		return Vector2(roundf(b[1]), b[2] - h + b[3] * town.PK * town.ks(k))
	return null

func _every(id: String, ms: float, dt: float) -> int:
	var t: float = emit_t.get(id, randf() * ms) - dt
	var n := 0
	while t <= 0.0:
		t += ms * (0.75 + randf() * 0.5)
		n += 1
	emit_t[id] = t
	return n


func step(dt: float) -> void:
	var vr: Rect2 = arena.view_rect().grow(300.0)
	var g: float = town.life.gust
	for c in [["g_forge", FORGE_CHIMNEY, true, 210.0], ["g_cottage", COTTAGE_CHIMNEY, false, 300.0]]:
		var o = origin(c[0])
		if o == null: continue
		var p: Vector2 = o + c[1]
		if not vr.has_point(p): continue
		for i in _every(c[0], c[3], dt):
			puffs.append({"x": p.x + randf_range(-3, 3), "y": p.y, "vx": randf_range(-0.003, 0.003), "vy": -0.022 - randf() * 0.01,
				"r0": 2.0 + randf(), "r1": 11.0 + randf() * 6.0, "t": 0.0, "life": 2800.0 + randf() * 1400.0, "ph": randf() * 9.0, "dark": c[2]})
	for f in puffs:
		f["t"] += dt
		var u: float = f["t"] / f["life"]
		# the draught leans the plume over as it rises, more in a gust; a slow curl on top
		f["vx"] += (0.000012 + g * 0.00002) * dt
		f["x"] += (f["vx"] + sin(f["t"] / 520.0 + f["ph"]) * 0.006) * dt
		f["y"] += f["vy"] * (1.0 - u * 0.5) * dt
	puffs = puffs.filter(func(f): return f["t"] < f["life"])
	_step_light(dt)
	_step_water(dt)
	var vp: Viewport = arena.get_viewport()
	haze_mat.set_shader_parameter("wpx", (vp.get_final_transform() * vp.get_canvas_transform()).x.length())
	haze.queue_redraw()


## world layer, right after the buildings: the hearth fire
func draw_world(ci: CanvasItem) -> void:
	var o = origin("g_forge")
	if o == null: return
	var fi := int(Time.get_ticks_msec() / 1000.0 * 30.0) % 90
	ci.draw_texture_rect_region(FORGE_FIRE, Rect2(o + FORGE_BOX, Vector2(FORGE_FW, FORGE_FH)), Rect2((fi % 10) * FORGE_FW, (fi / 10) * FORGE_FH, FORGE_FW, FORGE_FH))

## front layer: the smoke
func draw_front(ci: CanvasItem) -> void:
	for f in puffs:
		var u: float = f["t"] / f["life"]
		var r := roundi(lerpf(f["r0"], f["r1"], sqrt(u)))
		var a: float = minf(1.0, u / 0.08) * (1.0 - u) * (0.62 if f["dark"] else 0.55)
		var c: Color = Color(0.5, 0.48, 0.5).lerp(Color(0.68, 0.66, 0.7), u) if f["dark"] else Color(0.9, 0.88, 0.86).lerp(Color(0.7, 0.7, 0.74), u)
		ci.draw_texture(disc(r), Vector2(roundf(f["x"]) - r, roundf(f["y"]) - r), Color(c, a))

## the heat boxes (the haze shader shifts what is already drawn under them)
func _draw_haze() -> void:
	var w := white()
	var cx: float = 4350.0 + 27.0 * town.PK
	haze.draw_texture_rect(w, Rect2(cx - 20.0, town.G - 70.0, 40.0, 56.0), false, Color(1, 1, 1, 0.9))
	var o = origin("g_forge")
	if o != null:
		var p: Vector2 = o + FORGE_CHIMNEY
		haze.draw_texture_rect(w, Rect2(p.x - 18.0, p.y - 44.0, 36.0, 44.0), false, Color(1, 1, 1, 0.8))
		haze.draw_texture_rect(w, Rect2(o.x + FORGE_BOX.x + 20.0, o.y + FORGE_BOX.y + 8.0, 60.0, 40.0), false, Color(1, 1, 1, 0.6))


# ---------- light ----------
## the point lights the rim reads: fires, lamps, string bulbs and lit windows near the screen, strongest first
func _rim_lights() -> Array:
	var vr: Rect2 = arena.view_rect().grow(250.0)
	var out := []
	for l in town.lit.L:
		if not (l["k"] in ["fire", "lamp", "bulb", "win"]): continue
		var p := Vector2(l["x"], l["y"])
		if not vr.has_point(p): continue
		out.append(l)
	out.sort_custom(func(a, b): return float(a["a"]) * float(a["r"]) > float(b["a"]) * float(b["r"]))
	return out.slice(0, 8)

func _step_light(dt: float) -> void:
	var ls := _rim_lights()
	var lp := PackedVector4Array()
	var lc := PackedVector4Array()
	var nk: float = town.life.night_k()
	for l in ls:
		var c: Color = l["c"]
		# fires always cast it; lamps and windows only once it is dark enough for them to matter
		var a: float = float(l["a"]) * RIM_K * (1.0 if l["k"] == "fire" else nk)
		lp.append(Vector4(l["x"], l["y"], float(l["r"]) * 0.9, a))
		lc.append(Vector4(c.r, c.g, c.b, 1.0))
	rim_mat.set_shader_parameter("n", lp.size())
	while lp.size() < 8:
		lp.append(Vector4.ZERO)
		lc.append(Vector4.ZERO)
	rim_mat.set_shader_parameter("lp", Array(lp))
	rim_mat.set_shader_parameter("lc", Array(lc))
	rim.set_meta("ls", ls)
	rim.queue_redraw()
	# moths: three to a lit lamp at night, each on its own wobbling loop round the flame
	var t := Time.get_ticks_msec() / 1000.0
	moths.clear()
	if nk > 0.35:
		for l in ls:
			if l["k"] != "lamp": continue
			for i in 3:
				var ph: float = float(l["x"]) * 0.01 + i * 2.1
				var a := t * (2.2 + i * 0.7) + ph
				var r := 9.0 + 5.0 * sin(t * 1.3 + ph * 2.0)
				moths.append(Vector2(l["x"] + cos(a) * r + sin(t * 7.0 + ph) * 2.0, l["y"] - 4.0 + sin(a * 1.7) * r * 0.55 + cos(t * 9.0 + ph) * 1.5))
	# canopy shafts: dust motes drift down through them by day
	var sun: float = arena.tod_now()["sun"]
	if sun > 0.35 and arena.weather == "clear":
		var tr = _tree_box("f_bigtree")
		if tr != null and arena.view_rect().grow(200.0).intersects(tr):
			while motes.size() < 26:
				motes.append({"x": tr.position.x + randf() * tr.size.x, "y": tr.position.y + tr.size.y * (0.55 + randf() * 0.45), "ph": randf() * 9.0, "t": randf() * 4000.0})
			for m in motes:
				m["t"] += dt
				m["x"] += sin(m["t"] / 700.0 + m["ph"]) * 0.004 * dt + town.life.gust * 0.01 * dt
				m["y"] += 0.004 * dt
				if m["t"] > 6000.0 or m["y"] > tr.end.y:
					m["x"] = tr.position.x + randf() * tr.size.x
					m["y"] = tr.position.y + tr.size.y * 0.55
					m["t"] = 0.0
	else:
		motes.clear()
	glow.queue_redraw()

## a placed tree's box in the world (deco_back, its 1.35x size)
func _tree_box(k: String):
	for d in town.deco_back:
		if d[0] != k: continue
		var t: Texture2D = town.hx.get(k + "_trunk", town.tex[k])
		var s: float = 1.0 if town.hx.has(k + "_trunk") else town.ks(k)
		return Rect2(roundf(d[1]), d[2] - t.get_height() * s, t.get_width() * s, t.get_height() * s)
	return null

## the rim pass: each lit sprite's rim map (assets/town/rim/) drawn where the sprite is; RIM_SH keeps the light-facing edges
var rim_tex := {}
func _rim_map(k: String):
	if not rim_tex.has(k):
		var path := "res://assets/town/rim/%s.png" % k
		rim_tex[k] = load(path) if ResourceLoader.exists(path) else null
	return rim_tex[k]

func _rim_spr(k: String, x: float, y_bottom: float, sink: float, flip: bool) -> void:
	var m = _rim_map(k)
	if m == null: return
	var s: float = town.ks(k)
	var w: float = m.get_width() * (1.0 if town.hx.has(k) else s)
	var h: float = m.get_height() * (1.0 if town.hx.has(k) else s)
	var y: float = y_bottom - h + sink * town.PK * s
	if flip:
		rim.draw_set_transform_matrix(Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2(roundf(x) + w, 0)))
		rim.draw_texture_rect(m, Rect2(0, y, w, h), false, Color(0, 1, 1))
		rim.draw_set_transform(Vector2.ZERO)
	else:
		rim.draw_texture_rect(m, Rect2(roundf(x), y, w, h), false)

func _draw_rim() -> void:
	var ls: Array = rim.get_meta("ls", [])
	if ls.is_empty(): return
	var near := func(x0: float, x1: float) -> bool:
		for l in ls:
			if float(l["x"]) + float(l["r"]) > x0 and float(l["x"]) - float(l["r"]) < x1: return true
		return false
	for b in town.bld:
		if b[0] == "g_anvil" or b[0] == "g_wagon": continue
		var t: Texture2D = town.hx.get(b[0], town.tex[b[0]])
		if not near.call(b[1], b[1] + t.get_width() * (1.0 if town.hx.has(b[0]) else town.ks(b[0]))): continue
		_rim_spr(b[0], b[1], b[2], b[3], b.size() > 7 and b[7])
	_rim_spr("g_hall", town.HXB, town.TTOP, 1.0, false)
	for i in town.deco_props.size():
		var d: Array = town.deco_props[i]
		if town.life.jig.get(i, 0.0) > 0.02: continue
		if not near.call(d[1], d[1] + town.tex[d[0]].get_width() * town.ks(d[0])): continue
		_rim_spr(d[0], d[1], d[2], 0.0, d.size() > 3 and d[3])

func _draw_glow() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in moths.size():
		var m: Vector2 = moths[i]
		var up := int(t * 18.0 + i) % 2 == 0
		var X := roundf(m.x)
		var Y := roundf(m.y)
		glow.draw_rect(Rect2(X, Y, 1, 1), Color(1.0, 0.86, 0.6, 0.9))
		glow.draw_rect(Rect2(X - 1, Y - (1 if up else 0), 1, 1), Color(0.9, 0.75, 0.55, 0.55))
		glow.draw_rect(Rect2(X + 1, Y - (1 if up else 0), 1, 1), Color(0.9, 0.75, 0.55, 0.55))
	if motes.is_empty(): return
	var tr = _tree_box("f_bigtree")
	if tr == null: return
	var sun: float = arena.tod_now()["sun"]
	var sd: Vector2 = town.LIT.sun_dir(arena.tod_h)
	var lean := clampf(sd.x, -1.2, 1.2)
	# shafts falling from gaps in the canopy, widening as they fall, brightest just under the leaves and fading out
	# before the ground; they lean with the sun and breathe slowly
	var top: float = tr.position.y + tr.size.y * 0.42
	var bot: float = tr.end.y - 6.0
	var dx := lean * (bot - top) * 0.6
	for j in 4:
		var cx: float = tr.position.x + tr.size.x * (0.22 + j * 0.19) + sin(j * 7.3) * 14.0
		var w0 := 4.0 + float(j % 2) * 3.0
		var w1 := w0 * 3.2
		var a := (0.16 + 0.07 * sin(t * 0.5 + j * 2.3)) * sun
		var mid := top + (bot - top) * 0.25
		var wm := lerpf(w0, w1, 0.25)
		var cm := cx + dx * 0.25
		var pts := PackedVector2Array([Vector2(cx - w0 / 2.0, top), Vector2(cx + w0 / 2.0, top), Vector2(cm + wm / 2.0, mid),
			Vector2(cx + dx + w1 / 2.0, bot), Vector2(cx + dx - w1 / 2.0, bot), Vector2(cm - wm / 2.0, mid)])
		var c0 := Color(1.0, 0.95, 0.78, 0.0)
		var c1 := Color(1.0, 0.95, 0.78, a)
		glow.draw_polygon(pts, PackedColorArray([c0, c0, c1, c0, c0, c1]))
	for m in motes:
		var k: float = 0.5 + 0.5 * sin(m["t"] / 300.0 + m["ph"])
		glow.draw_rect(Rect2(roundf(m["x"]), roundf(m["y"]), 1, 1), Color(1.0, 0.97, 0.85, 0.9 * k * sun))


# ---------- water ----------
const W_HI := Color("#d9f2ff")
const W_MID := Color("#9fd2ec")
const W_LO := Color("#5f9fc4")

## a splash at (x, y): a crown of drops thrown up and out (n), a ring or two spreading on the surface (big: 2)
func splash(x: float, y: float, n: int, big := false) -> void:
	for i in n:
		var a := -PI / 2.0 + randf_range(-1.0, 1.0) * (0.9 if big else 1.2)
		var sp := randf_range(0.06, 0.16) * (1.3 if big else 1.0)
		drops.append({"x": x + randf_range(-3, 3), "y": y - 1.0, "vx": cos(a) * sp, "vy": sin(a) * sp, "t": 0.0, "life": 900.0, "gy": y})
	rings.append({"x": x, "y": y, "t": 0.0, "life": 600.0 if big else 420.0, "r": 16.0 if big else 6.0})
	if big: rings.append({"x": x, "y": y, "t": -140.0, "life": 700.0, "r": 24.0})

## where rain landing at x stops: the highest climbable top over it (roofs, crates), else the ground
func roof_y(x: float) -> float:
	var y := INF
	for r in roofs:
		if x < r["x0"] or x > r["x1"]: continue
		y = minf(y, lerpf(r["y0"], r["y1"], (x - r["x0"]) / maxf(1.0, r["x1"] - r["x0"])) - 3.0)
	return y

## a raindrop hits at (x, y): a tiny crown on stone and earth; rings where it falls on the river
func rain_hit(x: float, y: float) -> void:
	if x > town.RIV0 and x < town.RIV1 and absf(y - (town.LOWF + 20.0)) < 30.0:
		rings.append({"x": x, "y": town.LOWF + 20.0, "t": 0.0, "life": 380.0, "r": 4.0 + randf() * 3.0})
		return
	for i in 3:
		drops.append({"x": x, "y": y - 1.0, "vx": randf_range(-0.06, 0.06), "vy": -0.07 - randf() * 0.07, "t": 0.0, "life": 320.0, "gy": y})

func _step_water(dt: float) -> void:
	if roofs.is_empty():
		for r in town.tpl:
			if r.has("climb"): roofs.append(r)
	var P = arena.player
	# wading: every footfall in the river throws a crown; standing in it, the water rings round the legs now and then
	if town.kind == "town" and P.position.x > town.RIV0 and P.position.x < town.RIV1 and P.position.y > town.LOWF + 10.0:
		var wy: float = town.LOWF + 20.0
		if P.anim == "run" and P.f != wade_f and P.f in P.SK.steps(P.who, "run"):
			splash(P.position.x + P.dir * 6.0, wy, 7, false)
		elif absf(P.vx) < 0.02 and randf() < dt / 900.0:
			rings.append({"x": P.position.x, "y": wy, "t": 0.0, "life": 900.0, "r": 14.0})
		if not P.on and P.vy > 0.3 and P.position.y > wy - 30.0 and not has_meta("dove"):
			set_meta("dove", true)
			splash(P.position.x, wy, 14, true)
		if P.on: remove_meta("dove")
	wade_f = P.f
	# the fountain's stream churns where it lands
	var fo = _fountain()
	if fo != null and arena.view_rect().grow(100.0).has_point(fo + Vector2(140, 130)) and randf() < dt / 70.0:
		var bx: float = fo.x + randf_range(124.0, 156.0)
		drops.append({"x": bx, "y": fo.y + 128.0, "vx": randf_range(-0.05, 0.05), "vy": -0.06 - randf() * 0.07, "t": 0.0, "life": 500.0, "gy": fo.y + 129.0})
	for d in drops:
		d["t"] += dt
		d["vy"] += 0.0006 * dt
		d["x"] += d["vx"] * dt
		d["y"] += d["vy"] * dt
		if d["y"] > d["gy"] and d["vy"] > 0.0: d["t"] = d["life"]
	drops = drops.filter(func(d): return d["t"] < d["life"])
	for r in rings: r["t"] += dt
	rings = rings.filter(func(r): return r["t"] < r["life"])

func _fountain():
	return Vector2(roundf(town.HDOOR - 52.0 * town.PK * town.BS), town.LOWF - 205.0)

## front layer: drops, rings, the running stream
func draw_water(ci: CanvasItem) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var fo = _fountain()
	if fo != null and arena.view_rect().grow(60.0).has_point(fo + Vector2(140, 100)):
		# light sliding down the stream (x 132..148, y 68..129 in the sprite): two bright runs and a dark seam
		for i in 4:
			var yy: float = fmod(t * 70.0 + i * 15.5, 62.0)
			var x: float = fo.x + 134.0 + float((i * 5) % 12)
			ci.draw_rect(Rect2(x, fo.y + 68.0 + yy, 1, 4), Color(W_HI, 0.85))
		ci.draw_rect(Rect2(fo.x + 140.0 + roundf(sin(t * 9.0)), fo.y + 70.0, 1, 58), Color(W_LO, 0.35))
		# foam at the foot
		for i in 9:
			var fx: float = fo.x + 122.0 + i * 4.0 + roundf(sin(t * 11.0 + i * 1.7) * 1.5)
			var on := sin(t * 13.0 + i * 2.3) > -0.2
			if on: ci.draw_rect(Rect2(fx, fo.y + 127.0 - (1.0 if i % 3 == 0 else 0.0), 2 if i % 2 == 0 else 1, 1), Color(W_HI, 0.9))
	for d in drops:
		var k: float = d["t"] / d["life"]
		ci.draw_rect(Rect2(roundf(d["x"]), roundf(d["y"]), 1, 1), Color(W_HI if k < 0.5 else W_MID, 1.0 - k * 0.5))
	for r in rings:
		if r["t"] < 0.0: continue
		var k: float = r["t"] / r["life"]
		var R: float = 2.0 + (r["r"] - 2.0) * sqrt(k)
		var n := maxi(8, roundi(R * 2.4))
		var c := Color(W_HI if k < 0.4 else W_MID, (1.0 - k) * 0.8)
		var seen := {}
		for i in n:
			var a := TAU * i / n
			var p := Vector2(roundf(r["x"] + cos(a) * R), roundf(r["y"] + sin(a) * R * 0.28))
			if seen.has(p): continue
			seen[p] = true
			if sin(a) < -0.1 and k > 0.5: continue           # the far side fades first
			ci.draw_rect(Rect2(p, Vector2.ONE), c)
