extends Node2D
## 길드 마을: street (spawn) → an earth band rising to the guild terrace → terrace → band down → upper street (camp, wagon, barn)
## → slope down; and under it a ramp into the lower plaza (fountain) → riverside valley → bridge → big tree.
## Ported from the prototype's GUILD TOWN v3 (terrY / TPL / townLand / BLD / drawTown) and its time of day.

const PK := 2.0
const BS := 1.35              # buildings and trees are drawn 1.35x; people-scale props stay 1x
const BIGK := ["g_store", "g_tentR", "g_barn", "g_cottage", "g_well", "g_forge", "g_anvil", "g_kiln", "g_hall", "q_fountain", "f_tree2", "f_tree3", "f_bigtree", "f_bush1", "f_bush2", "f_bush3"]
const TOWN_W := 9450.0
const SX0 := 1850.0
const SX1 := 2350.0
const RX1 := 2550.0
const DX1 := 3550.0
const EX1 := 4050.0
const STX1 := 6150.0
const RIV0 := 8350.0
const RIV1 := 8590.0
const SL := 420.0
const BAND := 58.0
const SURFR := 6.0
const PXK := 1.78
## hour, sky tint rgba, ambient rgb, sun, lamp
const TODK := [[0, [8, 12, 48, .72], [.32, .35, .58], 0, 1], [4.5, [20, 22, 70, .6], [.42, .42, .64], 0, 1], [5.8, [255, 140, 160, .38], [.72, .66, .82], .3, .8], [7.5, [255, 215, 190, .14], [.94, .9, .9], .75, .25],
	[12, [255, 255, 255, 0], [1, 1, 1], 1, .1], [16, [255, 215, 160, .12], [1, .95, .88], .85, .2], [17.6, [255, 150, 90, .3], [.98, .82, .72], .6, .55], [18.5, [235, 105, 95, .4], [.86, .7, .74], .42, .85],
	[19.5, [110, 70, 140, .5], [.6, .55, .75], .15, 1], [21, [25, 30, 95, .66], [.4, .42, .66], 0, 1], [24, [8, 12, 48, .72], [.32, .35, .58], 0, 1]]

var arena
var G := 430.0
var LOWF := 750.0
var TTOP := 235.0
var HDOOR := 0.0
var HXB := 0.0
var HX2 := 2700.0
var HTOP2 := 0.0
var HS := 0.0
var tpl: Array = []            # sloped one-way surfaces {x0,x1,y0,y1}
var bld: Array = []
var deco_back: Array = []
var deco_props: Array = []
var lamps: Array = []
var light_strings: Array = []
var doors: Array = []
var tex := {}
var t_solid: Texture2D
var t_band: Texture2D
var t_wall: Texture2D
var near_door = null
var tod_h := 18.5
var tod_auto := true
var lights: Node2D
var cmod: CanvasModulate
var bg_layer: CanvasLayer
var bg_node: Node2D
var front: Node2D
var light_tex: GradientTexture2D
var tfx: Array = []
var emit_t := {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -5
	G = arena.ground_y
	LOWF = G + 320.0
	TTOP = G - 195.0
	HS = PK * 3.2 / 3.0
	HTOP2 = TTOP - 220.0 * PK + 2.0
	HDOOR = HX2 + 162.0 * PK
	HXB = HDOOR - 162.0 * PK * 1.35
	for f in DirAccess.get_files_at("res://assets/town"):
		var k := f.replace(".import", "").get_basename()
		if not tex.has(k): tex[k] = load("res://assets/town/" + k + ".png")
	_build_tex()
	_layout()
	light_tex = GradientTexture2D.new()
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	light_tex.gradient = gr
	lights = Node2D.new()
	add_child(lights)
	cmod = CanvasModulate.new()
	arena.add_child(cmod)
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	arena.add_child(bg_layer)
	bg_node = Node2D.new()
	bg_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg_node.draw.connect(_draw_bg)
	bg_layer.add_child(bg_node)
	front = Node2D.new()
	front.z_index = 8
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.draw.connect(_draw_front)
	arena.add_child(front)
	_build_lights()

func cleanup() -> void:
	cmod.queue_free()
	bg_layer.queue_free()
	front.queue_free()
	queue_free()


# ---------- layout ----------
func HM(x: float, y: float) -> Vector2:
	return Vector2(HDOOR + (x - HDOOR) * 1.35, TTOP + (y - TTOP) * 1.35)

func _hp(sx0: float, sx1: float, sy: float) -> Dictionary:
	var a := HM(HX2 + sx0 * HS, HTOP2 + sy * HS)
	var b := HM(HX2 + sx1 * HS, 0.0)
	return {"x0": a.x, "x1": b.x, "y0": a.y + 4.0, "y1": a.y + 4.0}

func ks(k: String) -> float:
	return BS if BIGK.has(k) else 1.0

func _layout() -> void:
	tpl = [{"x0": SX0, "x1": SX1, "y0": G, "y1": TTOP}, {"x0": SX1, "x1": DX1, "y0": TTOP, "y1": TTOP}, {"x0": DX1, "x1": EX1, "y0": TTOP, "y1": G},
		{"x0": EX1, "x1": STX1, "y0": G, "y1": G}, {"x0": STX1, "x1": STX1 + SL, "y0": G, "y1": LOWF}, {"x0": RIV0 - 20.0, "x1": RIV1 + 20.0, "y0": LOWF, "y1": LOWF},
		_hp(12, 98, 141), _hp(207, 292, 141), _hp(10, 100, 115), _hp(205, 294, 115), _hp(37, 117, 56), _hp(186, 266, 56), _hp(74, 98, 30), _hp(202, 228, 30)]
	# [sprite, left x, surface y, sink, door dx|null, name, target, flip]
	bld = [["g_store", 300.0, G, 0, 160.0, "창고", ""], ["g_yard", 820.0, G, 0, 378.0, "훈련장", "arena"],
		["g_tentR", 4120.0, G, 2, null, "", "", true], ["g_ring", 4350.0, G, 4, null], ["g_tentR", 4490.0, G, 2, null],
		["g_wagon", 4820.0, G, 0, 287.0, "출격 마차", "dungeon"], ["g_barn", 5520.0, G, 0, 230.0, "헛간", ""],
		["g_cottage", 6730.0, LOWF, 0, 140.0, "목욕집", ""], ["g_well", 7100.0, LOWF, 0, null], ["g_forge", 7350.0, LOWF, 0, 373.0, "대장간", "forge"], ["g_anvil", 7790.0, LOWF, 0, null], ["g_kiln", 7900.0, LOWF, 0, 113.0, "숯가마", ""]]
	doors = []
	for b in bld:
		if b.size() > 4 and b[4] != null:
			doors.append({"x": b[1] + b[4], "y": b[2], "name": b[5], "to": b[6]})
	doors.append({"x": HDOOR, "y": TTOP, "name": "길드 본관", "to": "hall"})
	# buildings grow about their door (doors stay put); tents away from the campfire; the rest about their middle
	for b in bld:
		var k: String = b[0]
		if not BIGK.has(k): continue
		var w: float = tex[k].get_width()
		var ax: float = b[1] + b[4] if b.size() > 4 and b[4] != null else ((b[1] + w if b.size() > 7 and b[7] else b[1]) if k == "g_tentR" else b[1] + w / 2.0)
		b[1] = ax - (ax - b[1]) * BS
	deco_back = [["f_tree2", -30.0, G, 0, false, 1.4], ["f_tree3", 140.0, G, 0, true, 1.4], ["f_bush1", 250.0, G, 0, false, 0.8], ["f_grass1", 770.0, G, 0, false, 0.6],
		["f_tree2", 1620.0, G, 0, true, 1.4], ["f_bush2", 1740.0, G, 0, false, 0.8], ["f_bush1", 4040.0, G, 0, true, 0.8], ["f_tree3", 5310.0, G, 0, false, 1.4], ["f_grass1", 6040.0, G, 0, true, 0.6],
		["f_grass2", 8620.0, LOWF, 0, false, 0.6], ["f_bush3", 8620.0, LOWF, 0, false, 0.8], ["f_bigtree", 8700.0, LOWF, 0, false, 2.2], ["f_bush1", 9250.0, LOWF, 0, true, 0.8]]
	for d in deco_back:
		if BIGK.has(d[0]):
			var w2: float = tex[d[0]].get_width()
			d[1] = d[1] + w2 / 2.0 - w2 * BS / 2.0
	deco_props = [["q_barrelL", 630.0, G], ["q_barrelS", 690.0, G], ["q_crateL", 1560.0, G], ["q_crateS", 1624.0, G],
		["q_barrelM", HX2 + 470.0, TTOP], ["q_barrelS", HX2 + 522.0, TTOP], ["q_crateL", HX2 + 120.0, TTOP],
		["q_board", 2600.0, LOWF], ["q_bench", HDOOR - 230.0, LOWF], ["q_bench", HDOOR + 84.0, LOWF, true], ["q_planter", HDOOR - 320.0, LOWF], ["q_planter", HDOOR + 238.0, LOWF, true],
		["q_pot", HDOOR - 140.0, LOWF], ["q_pot", HDOOR + 112.0, LOWF], ["q_barrelL", 3560.0, LOWF], ["q_barrelM", 3616.0, LOWF], ["q_crateL", 4400.0, LOWF], ["q_crateS", 4464.0, LOWF],
		["q_barrelL", 5000.0, LOWF], ["q_crateL", 5700.0, LOWF], ["q_barrelS", 5764.0, LOWF], ["q_crateS", 6650.0, LOWF], ["q_barrelM", 8150.0, LOWF]]
	lamps = [[SX1 + 40.0, TTOP], [DX1 - 40.0, TTOP], [HDOOR - 400.0, LOWF], [HDOOR + 380.0, LOWF], [4700.0, LOWF], [5600.0, LOWF], [1700.0, G]]
	light_strings = [[HDOOR - 420.0, HDOOR - 20.0], [HDOOR + 20.0, HDOOR + 420.0], [4250.0, 4650.0], [5250.0, 5650.0]]

## build the strip textures once from the kit: ground strip on mirrored dirt (solid), and the earth band with a root edge
func _build_tex() -> void:
	var gi: Image = tex["k_ground"].get_image()
	var di: Image = tex["k_dirt"].get_image()
	gi.decompress()
	di.decompress()
	gi.convert(Image.FORMAT_RGBA8)
	di.convert(Image.FORMAT_RGBA8)
	var gw := gi.get_width()
	var gh := gi.get_height() - 2
	var dh := di.get_height()
	var solid := Image.create(gw * 2, gh + dh * 14, false, Image.FORMAT_RGBA8)
	for i in 2:
		for j in 14:
			var part := di.get_region(Rect2i(0, 0, mini(di.get_width(), gw), dh))
			if j % 2 == 1: part.flip_y()
			solid.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(i * gw, gh - 12 + j * dh))
		var gpart := gi.get_region(Rect2i(0, 0, gw, gh))
		if i == 1: gpart.flip_x()
		solid.blend_rect(gpart, Rect2i(Vector2i.ZERO, gpart.get_size()), Vector2i(i * gw, 0))
	t_solid = ImageTexture.create_from_image(solid)
	var bh := int(BAND)
	var band := Image.create(gw * 2, bh, false, Image.FORMAT_RGBA8)
	for i in 2:
		var y := gh - 12
		while y < bh:
			var part2 := di.get_region(Rect2i(0, 0, mini(di.get_width(), gw), dh))
			band.blit_rect(part2, Rect2i(Vector2i.ZERO, part2.get_size()), Vector2i(i * gw, y))
			y += dh
		band.fill_rect(Rect2i(i * gw, bh - 8, gw, 4), Color(0.08, 0.04, 0.03, 1))
		band.fill_rect(Rect2i(i * gw, bh - 4, gw, 4), Color8(42, 24, 16))
		var gp2 := gi.get_region(Rect2i(0, 0, gw, gh))
		if i == 1: gp2.flip_x()
		band.blend_rect(gp2, Rect2i(Vector2i.ZERO, gp2.get_size()), Vector2i(i * gw, 0))
	t_band = ImageTexture.create_from_image(band)
	var wall := Image.create(di.get_width() * 2, dh * 2, false, Image.FORMAT_RGBA8)
	for i in 2:
		for j in 2:
			var p3 := di.duplicate()
			if i == 1: p3.flip_x()
			if j == 1: p3.flip_y()
			wall.blit_rect(p3, Rect2i(Vector2i.ZERO, p3.get_size()), Vector2i(i * di.get_width(), j * dh))
	for x in wall.get_width():
		for y in wall.get_height():
			var c := wall.get_pixel(x, y)
			wall.set_pixel(x, y, Color(c.r * 0.38, c.g * 0.38, c.b * 0.38, c.a))
	t_wall = ImageTexture.create_from_image(wall)


# ---------- surfaces ----------
func terr_y(x: float) -> float:
	if x < SX0: return G
	if x < RX1: return G + (LOWF - G) * (x - SX0) / (RX1 - SX0)
	if x < RIV0 or x >= RIV1: return LOWF
	return LOWF + 60.0

func plat_y(p: Dictionary, x: float) -> float:
	return p.y0 + (p.y1 - p.y0) * clampf((x - p.x0) / (p.x1 - p.x0), 0.0, 1.0)

func up_y(x: float) -> float:
	if x < SX1: return G + (TTOP - G) * (x - SX0) / (SX1 - SX0)
	if x < DX1: return TTOP
	if x < EX1: return TTOP + (G - TTOP) * (x - DX1) / (EX1 - DX1)
	if x < STX1: return G
	return G + (LOWF - G) * minf(1.0, (x - STX1) / SL)

func ramp_y(x: float) -> float:
	return G + (LOWF - G) * (x - SX0) / (RX1 - SX0) if x < RX1 else LOWF

## landing in town: the terrain (with slopes) and the sloped one-way surfaces. Returns true while standing.
func land(P, prev_x: float, dt: float) -> bool:
	var prev_y: float = P.position.y - P.vy * dt
	var t := terr_y(P.position.x)
	if P.position.y > t + 2.0:
		if P.on and P.position.y - t <= 36.0:
			P.position.y = t
		else:
			var tp := terr_y(prev_x)
			if tp >= P.position.y - 2.0:
				P.position.x = prev_x
				t = tp
	if P.vy >= 0.0:
		if P.on and not P.keys["down"]:
			for p in tpl:
				if P.position.x < p.x0 - 2.0 or P.position.x > p.x1 + 2.0: continue
				var py := plat_y(p, P.position.x)
				if P.plat == p or absf(py - P.position.y) <= 4.0:
					P.position.y = py
					P.plat = p
					return true
		if P.position.y >= t - 0.5:
			P.position.y = t
			P.plat = null
			return true
		if P.drop_t <= 0.0:
			for p in tpl:
				if P.position.x < p.x0 - 8.0 or P.position.x > p.x1 + 8.0: continue
				var py2 := plat_y(p, P.position.x)
				var pp := plat_y(p, prev_x)
				if P.on and P.plat == p:
					P.position.y = py2
					return true
				if (not P.on or not P.keys["down"]) and prev_y <= pp + 2.0 and P.position.y >= py2 - 0.5:
					P.position.y = py2
					P.plat = p
					return true
		if P.on and P.plat == null and t - P.position.y <= 36.0 and t >= P.position.y:
			P.position.y = t
			return true
	P.plat = null
	return false

func support_span(x: float, y: float):
	if absf(y - terr_y(x)) < 3.0: return [-1e9, 1e9]
	for p in tpl:
		if x > p.x0 - 2.0 and x < p.x1 + 2.0 and absf(plat_y(p, x) - y) < 3.0:
			return [p.x0 - 2.0, p.x1 + 2.0]
	return null

## mobs and the camera ask where the floor is
func floor_at(x: float) -> float:
	var y := terr_y(x)
	for i in 6:
		var p: Dictionary = tpl[i]
		if x >= p.x0 and x <= p.x1: y = minf(y, plat_y(p, x))
	return y


# ---------- time of day ----------
func tod_now() -> Dictionary:
	var hh := fposmod(tod_h, 24.0)
	var i := 0
	while i < TODK.size() - 2 and TODK[i + 1][0] <= hh: i += 1
	var a: Array = TODK[i]
	var b: Array = TODK[i + 1]
	var k: float = (hh - a[0]) / maxf(0.001, b[0] - a[0])
	var sky := Color(lerpf(a[1][0], b[1][0], k) / 255.0, lerpf(a[1][1], b[1][1], k) / 255.0, lerpf(a[1][2], b[1][2], k) / 255.0, lerpf(a[1][3], b[1][3], k))
	var amb := Color(lerpf(a[2][0], b[2][0], k), lerpf(a[2][1], b[2][1], k), lerpf(a[2][2], b[2][2], k))
	return {"sky": sky, "amb": amb, "sun": lerpf(a[3], b[3], k), "lamp": lerpf(a[4], b[4], k)}

func lantern_at(x: float, surf: float) -> Vector2:
	var im: Texture2D = tex["q_lamp"]
	var lx := 91.0 / 113.0 * im.get_width() - 56.0
	var ly := 83.0 / 197.0 * im.get_height()
	return Vector2(x + lx, surf - (im.get_height() - ly))


# ---------- lights ----------
func _add_light(p: Vector2, r: float, col: Color, kind: String) -> void:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.texture_scale = r * 2.2 / 64.0
	l.color = col
	l.position = p
	l.set_meta("kind", kind)
	l.set_meta("ph", p.x * 0.01)
	lights.add_child(l)

func _build_lights() -> void:
	for lp in lamps:
		_add_light(lantern_at(lp[0], lp[1]), 150.0, Color8(255, 196, 110), "lamp")
	for s in light_strings:
		var yy: float = up_y((s[0] + s[1]) / 2.0) + BAND - 10.0
		for i in 7:
			var u := (i + 0.5) / 7.0
			_add_light(Vector2(s[0] + (s[1] - s[0]) * (0.07 + u * 0.86), yy + 58.0 * (0.55 + sin(u * PI) * 0.3)), 60.0, Color8(255, 210, 130), "lamp")
	_add_light(Vector2(4350.0 + 27.0 * PK, G - 20.0), 260.0, Color8(255, 150, 70), "fire")
	_add_light(Vector2(7443.0, LOWF - 50.0), 200.0, Color8(255, 140, 50), "fire")
	_add_light(Vector2(HDOOR, TTOP - 60.0), 200.0, Color8(255, 196, 120), "lamp")
	_add_light(Vector2(HDOOR, LOWF - 90.0), 260.0, Color8(255, 170, 90), "lamp")


# ---------- step ----------
func step(dt: float) -> void:
	if tod_auto:
		tod_h = fposmod(tod_h + dt / 1000.0 / 60.0, 24.0)      # one in-game hour per real minute
	var T := tod_now()
	cmod.color = T["amb"]
	var tt := Time.get_ticks_msec() / 1000.0
	for l in lights.get_children():
		var ph: float = l.get_meta("ph")
		if l.get_meta("kind") == "fire":
			l.energy = 0.6 + 0.6 * T["lamp"] + 0.1 * sin(tt * 7.0 + ph)
		else:
			l.energy = 1.1 * T["lamp"] + 0.04 * sin(tt * 5.0 + ph)
	# doors
	var P = arena.player
	near_door = null
	if P.on and not P.attacking():
		for d in doors:
			if absf(P.position.x - d["x"]) < 46.0 and absf(P.position.y - d["y"]) < 6.0:
				near_door = d
				break
	# ambient: smoke, embers, fountain drops, leaves
	_emit("camp", 170.0, dt, func(): tfx.append({"k": "smoke", "x": 4350.0 + 27.0 * PK + randf_range(-3, 3), "y": G - 64.0, "vx": 0.006, "vy": -0.03 - randf() * 0.012, "s": 10.0, "t": 0.0, "life": 2600.0, "dark": false}))
	_emit("forge", 130.0, dt, func(): tfx.append({"k": "smoke", "x": 7428.0, "y": LOWF - 208.0 * BS, "vx": 0.006, "vy": -0.03 - randf() * 0.012, "s": 11.0 * BS, "t": 0.0, "life": 2600.0, "dark": true}))
	_emit("emb", 160.0, dt, func(): tfx.append({"k": "ember", "x": 4350.0 + 27.0 * PK + randf_range(-8, 8), "y": G - 22.0, "vx": randf_range(-0.015, 0.015), "vy": -0.06 - randf() * 0.04, "t": 0.0, "life": 700.0 + randf() * 600.0}))
	_emit("fnt", 60.0, dt, func(): tfx.append({"k": "drop", "x": HDOOR + randf_range(-8, 8), "y": LOWF - 100.0 * BS, "vx": randf_range(-0.025, 0.025), "vy": 0.02, "t": 0.0, "life": 1000.0, "floor": LOWF - 40.0 * BS}))
	_emit("leaf", 420.0, dt, func(): tfx.append({"k": "leaf", "x": 8750.0 + randf() * 450.0, "y": LOWF - 340.0 + randf() * 120.0, "vx": 0.02, "vy": 0.025 + randf() * 0.02, "t": 0.0, "life": 6500.0, "ph": randf() * 9.0, "c": Color("#8f8a3a") if randf() < 0.5 else Color("#b8aa52")}))
	for f in tfx:
		f["t"] += dt
		f["x"] += f["vx"] * dt
		f["y"] += f["vy"] * dt
		if f["k"] == "leaf": f["vx"] = 0.02 + sin(f["t"] / 300.0 + f["ph"]) * 0.03
		if f["k"] == "drop":
			f["vy"] += 0.0009 * dt
			if f["y"] > f["floor"]: f["t"] = f["life"]
	tfx = tfx.filter(func(f): return f["t"] < f["life"])
	queue_redraw()
	front.queue_redraw()
	bg_node.queue_redraw()

func _emit(id: String, every: float, dt: float, fn: Callable) -> void:
	emit_t[id] = emit_t.get(id, 0.0) + dt
	while emit_t[id] > every:
		emit_t[id] -= every
		fn.call()

func try_interact() -> bool:
	if near_door == null:
		return false
	var d = near_door
	var to: String = d["to"]
	if to == "arena":
		arena.sfx("ready", 0.6)
		arena.fade_then(func(): arena.go_training())
	elif to == "dungeon":
		arena.sfx("ready", 0.6)
		arena.fade_then(func(): arena.enter_dungeon())
	else:
		arena.sfx("guard", 0.4)
		arena.text(arena.player.position + Vector2(0, -170), d["name"] + " — 준비 중", Color("#ffe9a8"))
	return true


# ---------- drawing ----------
func _draw_bg() -> void:
	var vs := get_viewport_rect().size
	var c: Vector2 = arena.cam.get_screen_center_position()
	var cam_x := c.x - vs.x / 2.0
	var cam_y := c.y - vs.y / 2.0
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color8(49, 120, 122))
	var sky: Texture2D = tex["bg_sky"]
	var sh := G + 4.0 + 200.0
	var sw := sky.get_width() * sh / sky.get_height()
	var x := -fposmod(cam_x * 0.02, sw) - sw
	while x < vs.x + sw:
		bg_node.draw_texture_rect(sky, Rect2(x, -200.0 - cam_y * 0.08, sw, sh), false)
		x += sw
	var mt: Texture2D = tex["bg_mountains"]
	_layer(mt, 0.16, G - mt.get_height() * PXK - 40.0 - cam_y * 0.12, PXK, cam_x, vs)
	var T := tod_now()
	var dim: float = 1.0 - 0.75 * T["sun"]
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.07, 0.05, 0.16, 0.2 * dim))
	var fo: Texture2D = tex["bg_forest"]
	_layer(fo, 0.42, G + 2.0 - 242.0 * PXK - cam_y * 0.25, PXK, cam_x, vs)
	bg_node.draw_rect(Rect2(0, G + 1.0 - cam_y * 0.25, vs.x, vs.y + 400.0), Color8(14, 74, 78))
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.04, 0.03, 0.09, 0.2 + 0.2 * dim))
	var skc: Color = T["sky"]
	if skc.a > 0.003:
		bg_node.draw_rect(Rect2(Vector2.ZERO, vs), skc)

## ping-pong tiling (every other tile mirrored)
func _layer(im: Texture2D, par: float, y: float, k: float, cam_x: float, vs: Vector2) -> void:
	var w := im.get_width() * k
	var h := im.get_height() * k
	var off := fposmod(cam_x * par, w * 2.0)
	var x := -off
	var i := 0
	while x < vs.x:
		if i % 2 == 1:
			bg_node.draw_set_transform(Vector2(x + w, y), 0.0, Vector2(-1, 1))
			bg_node.draw_texture_rect(im, Rect2(0, 0, w, h), false)
			bg_node.draw_set_transform(Vector2.ZERO)
		else:
			bg_node.draw_texture_rect(im, Rect2(x, y, w, h), false)
		x += w
		i += 1

## the strip texture sheared along y=f(x) in 2 px columns, so slopes become clean pixel stairs
func _shear(t: Texture2D, x0: float, x1: float, f: Callable, clip_h := -1.0) -> void:
	var vr: Rect2 = arena.view_rect()
	var a := maxf(x0, floorf((vr.position.x - 10.0) / PK) * PK)
	var b := minf(x1, vr.end.x + 10.0)
	var tw := float(t.get_width())
	var th: float = t.get_height() if clip_h < 0.0 else minf(t.get_height(), clip_h)
	var x := a
	while x < b:
		var sx := fposmod(x, tw)
		var y: float = roundf(f.call(x + PK / 2.0)) - SURFR
		draw_texture_rect_region(t, Rect2(x, y, PK, th), Rect2(minf(sx, tw - PK), 0, PK, th))
		x += PK

func _spr(k: String, x: float, y_bottom: float, sink := 0.0, flip := false, ci: CanvasItem = null) -> void:
	if not tex.has(k): return
	if ci == null: ci = self
	var im: Texture2D = tex[k]
	var s := ks(k)
	var w := im.get_width() * s
	var h := im.get_height() * s
	var y := y_bottom - h + sink * PK * s
	if flip:
		ci.draw_set_transform(Vector2(roundf(x) + w, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(im, Rect2(0, y, w, h), false)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(im, Rect2(roundf(x), y, w, h), false)

func _draw() -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	# 1. recess wall (dark dirt) behind the lower level
	var pts := PackedVector2Array([Vector2(SX0, G)])
	var x := SX0
	while x <= STX1 + SL:
		pts.append(Vector2(x, minf(LOWF, up_y(x) + BAND - 10.0)))
		x += 30.0
	pts.append(Vector2(STX1 + SL, LOWF + 20.0))
	pts.append(Vector2(SX0, LOWF + 20.0))
	var uvs := PackedVector2Array()
	for p in pts: uvs.append(p / t_wall.get_size())
	draw_colored_polygon(pts, Color.WHITE, uvs, t_wall)
	# 2. lower level: floor + valley, river
	_shear(t_solid, RX1, RIV0, func(_x): return LOWF)
	_shear(t_solid, RIV1, TOWN_W + PK, func(_x): return LOWF)
	draw_rect(Rect2(RIV0, LOWF + 18.0, RIV1 - RIV0, 700.0), Color("#3f6f9e"))
	x = RIV0
	while x < RIV1:
		draw_rect(Rect2(x, LOWF + 18.0 + (PK if sin(tt * 2.0 + x * 0.05) > 0.6 else 0.0), PK, PK), Color("#5f93c4"))
		x += PK
	# 3. lower plaza: light strings, fountain
	var L: Texture2D = tex["q_lights"]
	for s in light_strings:
		var yy: float = up_y((s[0] + s[1]) / 2.0) + BAND - 10.0
		draw_texture_rect(L, Rect2(s[0], yy, s[1] - s[0], L.get_height()), false)
	_spr("q_fountain", HDOOR - 52.0 * PK * BS, LOWF)
	# 4. upper bands, west street, ramp
	_shear(t_solid, -PK, SX0, func(_x): return G)
	_shear(t_band, SX0, STX1 + SL, up_y)
	_shear(t_solid, STX1 - 40.0, STX1 + SL + 40.0, func(_x): return LOWF)
	_shear(t_solid, SX0, RX1, ramp_y)
	# 5. trees, buildings, the hall, props, lamps, bridge
	for d in deco_back:
		_spr(d[0], d[1], d[2], d[3], d[4])
	for b in bld:
		if b[0] == "g_anvil": continue
		_spr(b[0], b[1], b[2], b[3], b.size() > 7 and b[7])
	_spr("g_hall", HXB, TTOP, 1.0)
	for d in deco_props:
		_spr(d[0], d[1], d[2], 0.0, d.size() > 3 and d[3])
	for lp in lamps:
		_spr("q_lamp", lp[0] - 28.0 * PK, lp[1])
	_spr("q_bridge", RIV0 - 38.0, LOWF + 28.0)
	_spr("g_anvil", 7790.0, LOWF)
	# campfire on the art-pixel grid
	var fxx := 4350.0 + 27.0 * PK
	var n := int(28.0 / PK)
	var cols := [Color("#7a2a1e"), Color("#c0461f"), Color("#ea7a26"), Color("#f6b545"), Color("#fde7a2")]
	for i in n:
		var u := (i + 0.5) / n
		var edge := 1.0 - absf(u - 0.5) * 2.0
		var k := 0.55 + 0.45 * sin(tt * 10.0 + i * 1.9) * sin(tt * 6.3 + i * 0.7) + 0.2 * sin(tt * 17.0 + i)
		var hh := maxi(1, roundi(32.0 / PK * (0.25 + 0.75 * edge) * maxf(0.3, k)))
		var x0 := roundf((fxx - 14.0) / PK) * PK + i * PK
		for j in hh:
			var v := float(j) / hh
			draw_rect(Rect2(x0, roundf((G - 9.0) / PK) * PK - (j + 1) * PK, PK, PK), cols[clampi(roundi((1.0 - v) * edge * 4.4 - 0.4), 0, 4)])

func _draw_front() -> void:
	# grass strip in front of feet
	var fl: Callable = func(x): return G
	_front_shear(-PK, SX0, fl)
	_front_shear(SX0, STX1 + SL, up_y)
	_front_shear(SX0, RX1, ramp_y)
	_front_shear(RX1, RIV0, func(_x): return LOWF)
	_front_shear(RIV1, TOWN_W + PK, func(_x): return LOWF)
	for f in tfx:
		var k: float = f["t"] / f["life"]
		match f["k"]:
			"smoke":
				var s: float = maxf(PK, roundf(f["s"] * (0.5 + k * 1.4) / PK) * PK)
				var a: float = (k / 0.15 if k < 0.15 else 1.0 - (k - 0.15) / 0.85) * (0.5 if f["dark"] else 0.4)
				var c := Color(0.27, 0.24, 0.24, a) if f["dark"] else Color(0.84, 0.8, 0.75, a)
				front.draw_rect(Rect2(roundf((f["x"] - s / 2.0) / PK) * PK, roundf((f["y"] - s / 2.0) / PK) * PK, s, s), c)
			"ember":
				front.draw_rect(Rect2(roundf(f["x"]), roundf(f["y"]), PK, PK), Color(1, 0.9, 0.64, 1.0 - k) if k < 0.5 else Color(0.92, 0.48, 0.15, 1.0 - k))
			"leaf":
				front.draw_rect(Rect2(roundf(f["x"]), roundf(f["y"]), PK * 2.0 if sin(f["t"] / 180.0 + f["ph"]) > 0.0 else PK, PK), Color(f["c"], minf(1.0, (1.0 - k) * 3.0)))
			"drop":
				front.draw_rect(Rect2(roundf(f["x"]), roundf(f["y"]), PK, PK), Color(0.75, 0.9, 1.0, 0.95))
	# door labels and the prompt
	var fnt: Font = arena.font_black
	var tt := Time.get_ticks_msec() / 1000.0
	if near_door != null:
		var d = near_door
		var s2: String = d["name"] + "  ·  공격 키"
		var tw := fnt.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
		var y2: float = d["y"] - 230.0 + sin(tt * 4.0) * 3.0
		front.draw_rect(Rect2(d["x"] - tw / 2.0, y2 - 16.0, tw, 24.0), Color(0, 0, 0, 0.6))
		front.draw_string(fnt, Vector2(d["x"] - tw / 2.0 + 10.0, y2 + 1.0), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffe9a8"))

func _front_shear(x0: float, x1: float, f: Callable) -> void:
	var vr: Rect2 = arena.view_rect()
	var a := maxf(x0, floorf((vr.position.x - 10.0) / PK) * PK)
	var b := minf(x1, vr.end.x + 10.0)
	var tw := float(t_solid.get_width())
	var x := a
	while x < b:
		var sx := fposmod(x, tw)
		var y: float = roundf(f.call(x + PK / 2.0)) - SURFR
		front.draw_texture_rect_region(t_solid, Rect2(x, y, PK, SURFR), Rect2(minf(sx, tw - PK), 0, PK, SURFR))
		x += PK
