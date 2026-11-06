extends RefCounted
## The town's ambient effects, each with a cause in the scene (owner 2026-11-06: "환경이나 그 외에 의한 근거가 있어야지"):
##  - fire: the forge's furnace glows from inside and flares (painted per frame, tools/bake_town_fx.py furnace)
##  - smoke: the forge and the bathhouse chimneys smoke (pixelfx fire/town-chimney-smoke sheet)
##  - heat: the air shimmers over the campfire, the hearth and the forge chimney (a screen-reading shader that shifts
##    whole world-px rows, so the shimmer stays on the pixel grid)
##  - light: buildings and props near a fire or a lamp catch its colour on the edges that face it (rim, like the
##    characters' rimEntity); moths circle the lit lamps at night; by day the sun falls through the big tree's canopy in
##    shafts with dust turning in them
##  - water: wading the river throws a crown of drops and spreads rings; the fountain's stream runs (light sliding
##    down it) and churns where it lands; rain bursts on the roofs and the ground and rings the river
##  - wind: leaves tumble (a turning sprite, not a square); a strong gust drags dust off the road and makes the tent
##    cloth flap; feet: running through grass kicks bits of it up
## Everything is drawn on the 1-px world grid (the characters' dot), positions from the placed sprites.

# the forge's furnace, painted per frame (tools/bake_town_fx.py furnace): 48 frames 150x112 at 12 fps, cols 8, laid
# over the forge sprite at 60,150 — the mouth glowing from inside, the light spilling onto the arch's stones and outlines
const FURNACE := preload("res://assets/fx/town/furnace.png")
const FUR_SPILL := preload("res://assets/fx/town/furnace_spill.png")
const FUR_AT := Vector2(60, 150)
const FUR_SZ := Vector2(150, 112)
const SMOKE := preload("res://assets/fx/town/chimney_smoke.png")
# pixelfx weather/town-bigtree-rays, kept to the air under the big tree's canopy (tools/bake_town_fx.py rays): 48 frames
# 690x150 at 8 fps, cols 6; its top-left 28 px in from the tree's left and 138 px above the tree's foot
const RAYS := preload("res://assets/fx/town/tree_rays.png")
const RAYS_AT := Vector2(28, -138)
const RAYS_SZ := Vector2(690, 150)
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
var bits: Array = []              # grass bits and road dust wisps: {k, x, y, vx, vy, t, life, c}
var grass_f := -1
var prev_g := 0.0
var rays_k := 0.0
var emis: Node2D                  # emissive: drawn over the ambient darkness (the furnace)


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
	emis = Node2D.new()
	emis.z_index = 10
	emis.z_as_relative = false
	emis.draw.connect(func(): _draw_furnace(emis))
	town.add_child(emis)


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
	_step_light(dt)
	_step_water(dt)
	_step_wind(dt)
	var vp: Viewport = arena.get_viewport()
	haze_mat.set_shader_parameter("wpx", (vp.get_final_transform() * vp.get_canvas_transform()).x.length())
	haze.queue_redraw()


## world layer, right after the buildings: the furnace light on the stones round its mouth (under the scene's light)
func draw_world(ci: CanvasItem) -> void:
	emis.queue_redraw()
	var o = origin("g_forge")
	if o == null: return
	var fi := int(Time.get_ticks_msec() / 1000.0 * 12.0) % 48
	ci.draw_texture_rect_region(FUR_SPILL, Rect2(o + FUR_AT, FUR_SZ), Rect2((fi % 8) * FUR_SZ.x, (fi / 8) * FUR_SZ.y, FUR_SZ.x, FUR_SZ.y))

## the furnace glows on its own light, over the dusk (z 10, above lit.gd's ambient)
func _draw_furnace(ci: CanvasItem) -> void:
	var o = origin("g_forge")
	if o == null: return
	var fi := int(Time.get_ticks_msec() / 1000.0 * 12.0) % 48
	ci.draw_texture_rect_region(FURNACE, Rect2(o + FUR_AT, FUR_SZ), Rect2((fi % 8) * FUR_SZ.x, (fi / 8) * FUR_SZ.y, FUR_SZ.x, FUR_SZ.y))

## front layer: the chimney smoke (pixelfx fire/town-chimney-smoke: 80 frames 96x150 at 20 fps, the mouth at 24,140),
## each chimney on its own phase; grey at the forge, paler steam off the bathhouse
func draw_front(ci: CanvasItem) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var vr: Rect2 = arena.view_rect().grow(160.0)
	for c in [["g_forge", FORGE_CHIMNEY, 0, Color(0.85, 0.82, 0.85)], ["g_cottage", COTTAGE_CHIMNEY, 37, Color(1.55, 1.55, 1.6, 0.85)]]:
		var o = origin(c[0])
		if o == null: continue
		var p: Vector2 = o + c[1]
		if not vr.has_point(p): continue
		var fi: int = (int(t * 20.0) + int(c[2])) % 80
		ci.draw_texture_rect_region(SMOKE, Rect2(p - Vector2(24, 140), Vector2(96, 150)), Rect2((fi % 12) * 96, (fi / 12) * 150, 96, 150), c[3])

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
	# canopy rays: only in clear sun
	var sun: float = arena.tod_now()["sun"]
	rays_k = clampf((sun - 0.35) / 0.3, 0.0, 1.0) if arena.weather == "clear" else 0.0
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
	if rays_k <= 0.0: return
	var tr = _tree_box("f_bigtree")
	if tr == null or not arena.view_rect().grow(200.0).intersects(tr): return
	# sun past the big tree's canopy edges, where its sprite leaves air under the leaves
	var fi := int(t * 8.0) % 48
	glow.draw_texture_rect_region(RAYS, Rect2(Vector2(roundf(tr.position.x), roundf(tr.end.y)) + RAYS_AT, RAYS_SZ), Rect2((fi % 6) * RAYS_SZ.x, (fi / 6) * RAYS_SZ.y, RAYS_SZ.x, RAYS_SZ.y), Color(1, 1, 1, rays_k))


# ---------- water ----------
const W_HI := Color("#d9f2ff")
const W_MID := Color("#9fd2ec")
const W_LO := Color("#5f9fc4")

## a splash at (x, y) on the waterline: a pixelfx one-shot — water/town-wade for a stride or a fish (30 frames 80x48,
## pivot 30,36), water/splash (no stone, the river's palette; 76 frames 176x100, pivot 88,78) for a body dropping in
const WADE := preload("res://assets/fx/town/wade.png")
const DIVE := preload("res://assets/fx/town/dive.png")
var shots: Array = []
func splash(x: float, y: float, _n: int, big := false, flip := false) -> void:
	if big: shots.append({"tex": DIVE, "fw": 176, "fh": 100, "cols": 7, "n": 76, "px": 88, "py": 78, "x": x, "y": y, "t": 0.0, "flip": false})
	else: shots.append({"tex": WADE, "fw": 80, "fh": 48, "cols": 5, "n": 30, "px": 30, "py": 36, "x": x, "y": y, "t": 0.0, "flip": flip})

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
			splash(P.position.x + P.dir * 4.0, wy, 7, false, P.dir < 0)
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
	for sh in shots: sh["t"] += dt
	shots = shots.filter(func(sh): return sh["t"] < sh["n"] * 1000.0 / 30.0)
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
	for sh in shots:
		var fi: int = mini(int(sh["t"] * 30.0 / 1000.0), sh["n"] - 1)
		var src := Rect2((fi % sh["cols"]) * sh["fw"], (fi / sh["cols"]) * sh["fh"], sh["fw"], sh["fh"])
		var X: float = roundf(sh["x"])
		var Y: float = roundf(sh["y"]) - sh["py"]
		if sh["flip"]:
			ci.draw_set_transform(Vector2(X, 0), 0.0, Vector2(-1, 1))
			ci.draw_texture_rect_region(sh["tex"], Rect2(-sh["px"], Y, sh["fw"], sh["fh"]), src)
			ci.draw_set_transform(Vector2.ZERO)
		else:
			ci.draw_texture_rect_region(sh["tex"], Rect2(X - sh["px"], Y, sh["fw"], sh["fh"]), src)
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


# ---------- wind and feet ----------
const GRASS_C := [Color("#6f8f44"), Color("#97ad58"), Color("#bccd78")]
const DUST_C := Color("#c9b48c")

func _step_wind(dt: float) -> void:
	var P = arena.player
	var vr: Rect2 = arena.view_rect()
	var g: float = town.life.gust
	# running through grass: the blades you kick fly up and settle (not on the bridge, not in the river)
	var in_water: bool = P.position.x > town.RIV0 - 40.0 and P.position.x < town.RIV1 + 40.0 and P.position.y > town.LOWF - 10.0
	if P.on and P.anim == "run" and P.f != grass_f and P.f in P.SK.steps(P.who, "run") and not in_water:
		for i in 3:
			bits.append({"k": "grass", "x": P.position.x - P.dir * randf_range(2, 10), "y": P.position.y - 2.0, "vx": -P.dir * randf_range(0.01, 0.05), "vy": -randf_range(0.06, 0.12),
				"t": 0.0, "life": 650.0, "c": GRASS_C[randi() % 3], "gy": P.position.y})
	grass_f = P.f
	# a strong gust drags dust off the ground: low wisps racing downwind
	if g > 1.2 and prev_g <= 1.2 or (g > 1.3 and randf() < dt / 120.0):
		for i in 3:
			var x := vr.position.x - 20.0 + randf() * vr.size.x * 0.7
			var gy: float = town.floor_at(x)
			bits.append({"k": "wisp", "x": x, "y": gy - randf_range(1, 10), "vx": 0.18 + randf() * 0.12, "vy": -0.004, "t": 0.0, "life": 900.0 + randf() * 500.0, "c": DUST_C,
				"len": 4 + randi() % 6, "gy": gy})
	prev_g = g
	for b in bits:
		b["t"] += dt
		b["x"] += b["vx"] * dt
		b["y"] += b["vy"] * dt
		if b["k"] == "grass":
			b["vy"] += 0.0004 * dt
			b["vx"] += (g * 0.00004) * dt
			if b["y"] > b["gy"]: b["t"] = b["life"]
		else:
			b["y"] += sin(b["t"] / 140.0 + b["x"] * 0.05) * 0.01 * dt
	bits = bits.filter(func(b): return b["t"] < b["life"])

func draw_bits(ci: CanvasItem) -> void:
	for b in bits:
		var k: float = b["t"] / b["life"]
		var X := roundf(b["x"])
		var Y := roundf(b["y"])
		if b["k"] == "grass":
			var c: Color = b["c"]
			ci.draw_rect(Rect2(X, Y, 1, 1), Color(c, 1.0 - k * 0.6))
			if int(b["t"] / 70.0) % 2 == 0: ci.draw_rect(Rect2(X, Y - 1, 1, 1), Color(c.darkened(0.2), 1.0 - k * 0.6))
		else:
			var a := sin(k * PI) * 0.45
			ci.draw_rect(Rect2(X - b["len"], Y, b["len"], 1), Color(b["c"], a))
			ci.draw_rect(Rect2(X - b["len"] - 3, Y, 3, 1), Color(b["c"], a * 0.45))

## a leaf tumbling: four turns of a small leaf (flat, tipped, edge-on, tipped the other way), a darker vein
func draw_leaf(ci: CanvasItem, f: Dictionary, a: float) -> void:
	var c: Color = f["c"]
	var d := c.darkened(0.3)
	var X := roundf(f["x"])
	var Y := roundf(f["y"])
	var fr := int(f["t"] / 110.0 + f["ph"] * 3.0) % 4
	match fr:
		0:
			ci.draw_rect(Rect2(X - 1, Y, 3, 1), Color(c, a))
			ci.draw_rect(Rect2(X, Y + 1, 1, 1), Color(d, a))
		1:
			ci.draw_rect(Rect2(X - 1, Y - 1, 1, 1), Color(c, a))
			ci.draw_rect(Rect2(X, Y, 1, 1), Color(c, a))
			ci.draw_rect(Rect2(X + 1, Y + 1, 1, 1), Color(d, a))
		2:
			ci.draw_rect(Rect2(X, Y - 1, 1, 2), Color(d, a))
		3:
			ci.draw_rect(Rect2(X + 1, Y - 1, 1, 1), Color(c, a))
			ci.draw_rect(Rect2(X, Y, 1, 1), Color(c, a))
			ci.draw_rect(Rect2(X - 1, Y + 1, 1, 1), Color(d, a))

## a tent with its cloth flapping in the wind: 1-px rows of the middle shifted a pixel back and forth (the ridge and
## the pegged hem stay put), more in a gust
func draw_tent(ci: CanvasItem, b: Array) -> void:
	var k: String = b[0]
	var im: Texture2D = town.hx.get(k, town.tex[k])
	var s: float = town.ks(k)
	var w: float = im.get_width() * (1.0 if town.hx.has(k) else s)
	var h: float = im.get_height() * (1.0 if town.hx.has(k) else s)
	var x := roundf(b[1])
	var y0: float = b[2] - h + b[3] * town.PK * s
	var flip: bool = b.size() > 7 and b[7]
	var vr: Rect2 = arena.view_rect().grow(40.0)
	if x > vr.end.x or x + w < vr.position.x: return
	var t := Time.get_ticks_msec() / 1000.0
	var g: float = town.life.gust
	var amp := 0.35 + minf(1.4, g) * 0.75
	if flip: ci.draw_set_transform(Vector2(x + w, 0), 0.0, Vector2(-1, 1))
	var ox := 0.0 if flip else x
	var r := 0
	var ih := int(h)
	while r < ih:
		var u := float(r) / h
		var flap := sin(u * PI) * sin(u * PI)                 # still at the ridge and the hem, loose in the middle
		var o := roundf(sin(t * 3.4 - u * 5.0 + x * 0.01) * amp * flap)
		var rh := mini(2, ih - r)
		var src := Rect2(0, r, w, rh) if town.hx.has(k) else Rect2(0, r / s, w / s, rh / s)
		ci.draw_texture_rect_region(im, Rect2(ox + o, y0 + r, w, rh), src)
		r += 2
	if flip: ci.draw_set_transform(Vector2.ZERO)


