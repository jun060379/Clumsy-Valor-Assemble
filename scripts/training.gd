extends "res://scripts/town.gd"
## 훈련장 (prototype drawArena / drawPlank / the arena's lamps): the town's sky and kit on a 2000 px yard —
## the g_yard fence and gate, three swaying trees, bushes, barrels and crates, three street lamps that light at dusk,
## the ground strip with its grass, and the one-way platforms drawn with the bridge's planks.
## The way out is the gate (x 450, 길드 마을로). The dummies and the ghost live on the arena (arena.dummies / arena.ghost).
## Built on town.gd for its drawing helpers, wind and weather (town_life.gd); it is not arena.level (the arena's
## level stays null here, as before).

const AW := 2000.0
const DOOR_X := 450.0

var plank_tex: Texture2D
var glow: Node2D              # the lanterns' soft glow, added (lampAt glow), day and night


func _ready() -> void:
	kind = "training"
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -5
	G = arena.ground_y
	LOWF = G + 320.0
	TTOP = G - 195.0
	for f in DirAccess.get_files_at("res://assets/town"):
		var k := f.replace(".import", "").get_basename()
		if not tex.has(k): tex[k] = load("res://assets/town/" + k + ".png")
	plank_tex = tex["q_bridge"]
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
	# drawLighting as in the town (lit.gd / shade.gd): the yard, its trees and props cast shadows, clouds drift over
	lit = LIT.new(arena)
	lit.attach()
	shade = SHADE.new(arena, self)
	lit.set_shade(shade)
	lit.post_fn = func(ci): SKY.draw_fog(ci, self, [[G, 0.8]])
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
	glow = Node2D.new()
	var gm := CanvasItemMaterial.new()
	gm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = gm
	glow.draw.connect(_draw_glow)
	add_child(glow)
	life = LIFE.new(self)

func cleanup() -> void:
	lit.cleanup()
	bg_layer.queue_free()
	front.queue_free()
	queue_free()


# ---------- layout ----------
func _layout() -> void:
	tpl = []
	bld = []
	light_strings = []
	# [sprite, left x, surface y, sink, flip, sway amp, phase] — the trees sway whole, like the bushes (drawArena)
	deco_back = [["f_tree3", -60.0, G, 0, false, 1.2, 1.0], ["f_tree2", 1150.0, G, 0, true, 1.2, 2.0], ["f_tree3", AW - 200.0, G, 0, true, 1.2, 5.0],
		["f_bush2", 150.0, G, 0, false, 0.8, 3.0], ["f_bush1", 640.0, G, 0, true, 0.8, 4.0], ["f_bush3", 1500.0, G, 0, false, 0.8, 6.0], ["f_bush1", AW - 420.0, G, 0, false, 0.8, 7.0]]
	deco_props = [["q_barrelL", 1080.0, G], ["q_barrelS", 1130.0, G], ["q_crateL", 170.0, G], ["q_crateS", 220.0, G], ["q_crateL", AW - 90.0, G], ["q_barrelM", AW - 140.0, G]]
	# [x, surface, flip]
	lamps = [[330.0, G, false], [1230.0, G, true], [AW - 260.0, G, true]]
	doors = [{"x": DOOR_X, "y": G, "name": "길드 마을로", "to": "town"}]

## the lantern glass of a lamp standing at x (lanternAt, mirrored for a flipped lamp)
func lamp_glass(x: float, surf: float, flip: bool) -> Vector2:
	var p := lantern_at(x, surf)
	return Vector2(x - (p.x - x), p.y) if flip else p

## lightSources on the training ground: its three lamps
func light_sources() -> Array:
	var L: Array = []
	var t := Time.get_ticks_msec() / 1000.0
	for i in lamps.size():
		var p := lamp_glass(lamps[i][0], lamps[i][1], lamps[i][2])
		L.append({"k": "lamp", "x": p.x, "y": p.y, "gy": lamps[i][1], "r": 150.0, "a": LIT.fl(t, i + 1), "c": Color8(255, 196, 110)})
	return L

## occluders (the prototype's arena list): the yard's fence and gate, the three trees
func shade_occluders() -> Array:
	var o: Array = [[tex["g_yard"], roundf((900.0 - tex["g_yard"].get_width()) / 2.0), G, 0.0, false, 1.0, false]]
	for d in deco_back:
		if d[0].contains("tree"): o.append([tex[d[0]], d[1], d[2], d[3], d[4], 1.0, true])
	return o

func shade_props() -> Array:
	var o: Array = []
	for d in deco_props:
		o.append([tex[d[0]], d[1], d[2], 0.0, false, 1.0, false])
	return o

func surf_top(_x: float) -> float:
	return G

func cloud_bottom(_x: float) -> float:
	return G + 380.0

func shade_extra(_ci: CanvasItem) -> void:
	pass

## the town grows its buildings and trees 1.35x; the training ground draws the kit at its own size (ks is 1 outside town)
func ks(_k: String) -> float:
	return 1.0

## flat yard: the ground is the floor everywhere (rain, apples and pigeons land on it)
func terr_y(_x: float) -> float:
	return G

func up_y(_x: float) -> float:
	return G

func floor_at(_x: float) -> float:
	return G


# ---------- step ----------
func step(dt: float) -> void:
	var T := tod_now()
	var vr: Rect2 = arena.view_rect()
	var P = arena.player
	near_door = null
	if P.on and not P.attacking():
		for d in doors:
			if absf(P.position.x - d["x"]) < 46.0 and absf(P.position.y - d["y"]) < 6.0:
				near_door = d
				break
	life.step(dt)
	# leaves blow off the trees on screen (more in a gust)
	for d in deco_back:
		var k: String = d[0]
		if not k.contains("tree"): continue
		var w: float = tex[k].get_width() * ks(k)
		if d[1] > vr.end.x or d[1] + w < vr.position.x: continue
		if randf() < 0.004 * (0.3 + life.gust * 2.0) * w / ks(k) / 250.0 * dt / 16.7:
			var h: float = tex[k].get_height() * ks(k)
			tfx.append({"k": "leaf", "x": d[1] + w * (0.2 + randf() * 0.6), "y": d[2] - h * (0.6 + randf() * 0.25), "vx": 0.02, "vy": 0.02 + randf() * 0.02, "t": 0.0, "life": 4500.0,
				"ph": randf() * 9.0, "c": Color("#6f8f44") if randf() < 0.5 else Color("#97ad58")})
	var gl: float = life.gust * 0.05
	for f in tfx:
		f["t"] += dt
		f["x"] += f["vx"] * dt
		f["y"] += f["vy"] * dt
		if f["k"] == "leaf": f["vx"] = 0.02 + gl + sin(f["t"] / 300.0 + f["ph"]) * 0.03
		if f["k"] == "drop":
			f["vy"] += 0.0009 * dt
			if f["y"] > f["floor"]: f["t"] = f["life"]
	tfx = tfx.filter(func(f): return f["t"] < f["life"])
	_light_step(T)
	queue_redraw()
	glow.queue_redraw()
	front.queue_redraw()
	bg_node.queue_redraw()

func try_interact() -> bool:
	if near_door == null:
		return false
	arena.sfx("ready", 0.6)
	arena.fade_then(func(): arena.go_town(Vector2(820.0 + 378.0, arena.ground_y), 1))
	return true


# ---------- drawing (back to front, as drawArena) ----------
func _draw() -> void:
	var vr0: Rect2 = arena.view_rect().grow(60.0)
	for i in 3:
		var d: Array = deco_back[i]
		_sway(d[0], d[1], d[2], d[3], d[4], d[5], d[6], vr0)
	_spr("g_yard", roundf((900.0 - tex["g_yard"].get_width()) / 2.0), G)
	for i in range(3, deco_back.size()):
		var d: Array = deco_back[i]
		_sway(d[0], d[1], d[2], d[3], d[4], d[5] * (1.0 + life.rust.get(i, 0.0) * 4.0), d[6], vr0)
	_shear(t_solid, -PK * 2.0, AW + PK * 2.0, func(_x): return G)
	var tms := float(Time.get_ticks_msec())
	for i in deco_props.size():
		var d: Array = deco_props[i]
		var j: float = life.jig.get(i, 0.0)
		var xf := Transform2D.IDENTITY
		if j > 0.02:
			# struck: it rocks and hops
			var c := Vector2(d[1] + tex[d[0]].get_width() * ks(d[0]) / 2.0, d[2])
			xf = Transform2D(sin(tms / 28.0) * 0.08 * j, c) * Transform2D(0.0, -c - Vector2(0, absf(sin(tms / 60.0)) * 6.0 * j))
		_spr(d[0], d[1], d[2], 0.0, false, null, xf)
	for lp in lamps:
		_lamp_at(lp[0], lp[1], lp[2], vr0)
	# the grass strip's top and its blades (drawArena draws them before the figures)
	_shear(t_solid, -PK * 2.0, AW + PK * 2.0, func(_x): return G, SURFR)
	life.draw_blades(self, -PK * 2.0, AW + PK * 2.0, func(_x): return G)
	for f in tfx:
		var k: float = f["t"] / f["life"]
		if f["k"] == "leaf":
			draw_rect(Rect2(roundf(f["x"]), roundf(f["y"]), PK * 2.0 if sin(f["t"] / 180.0 + f["ph"]) > 0.0 else PK, PK), Color(f["c"], minf(1.0, (1.0 - k) * 3.0)))
		elif f["k"] == "drop":
			draw_rect(Rect2(roundf(f["x"]), roundf(f["y"]), PK, PK), Color(0.75, 0.9, 1.0, 0.95))
	# one-way platforms (drawPlank)
	for pl in arena.platforms:
		_plank(pl)

## a street lamp at x (lampAt): the sprite stands 28 art px left of x; a flipped lamp mirrors about x
func _lamp_at(x: float, surf: float, flip: bool, vr: Rect2) -> void:
	if x + 140.0 < vr.position.x or x - 140.0 > vr.end.x: return
	if flip:
		draw_set_transform(Vector2(x * 2.0, 0.0), 0.0, Vector2(-1, 1))
		_lamp(x - 28.0 * PK, surf, Rect2(-1e6, -1e6, 2e6, 2e6))
		draw_set_transform(Vector2.ZERO)
	else:
		_lamp(x - 28.0 * PK, surf, vr)

## drawPlank: the bridge's deck (rows 22..38 of q_bridge) tiled along the platform, a shadow lip, two posts
func _plank(pl: Dictionary) -> void:
	var im := plank_tex
	var y0: float = pl.y - 8.0
	var x0: float = pl.x - 6.0
	var w: float = pl.w + 12.0
	var seg: float = im.get_width() - 40.0
	var x := 0.0
	while x < w:
		var ww := minf(seg, w - x)
		draw_texture_rect_region(im, Rect2(x0 + x, y0, ww, 16.0), Rect2(20.0, 22.0, ww, 16.0))
		x += seg
	draw_rect(Rect2(x0 + 4.0, y0 + 16.0, w - 8.0, 3.0), Color(30 / 255.0, 18 / 255.0, 12 / 255.0, 0.55))
	for px in [x0 + 14.0, x0 + w - 22.0]:
		draw_rect(Rect2(px, y0 + 16.0, 8.0, 22.0), Color("#5a3a22"))
		draw_rect(Rect2(px, y0 + 16.0, 2.0, 22.0), Color("#3a2414"))

func _draw_glow() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for lp in lamps:
		var p := lamp_glass(lp[0], lp[1], lp[2])
		var a := 0.32 + sin(t * 5.0 + lp[0]) * 0.04
		glow.draw_texture_rect(light_tex, Rect2(p.x - 36.0, p.y - 36.0, 72.0, 72.0), false, Color(1.0, 190 / 255.0, 90 / 255.0, a))

func _draw_front() -> void:
	life.draw_front(front)
	var fnt: Font = arena.font_black
	var tt := Time.get_ticks_msec() / 1000.0
	if near_door != null:
		var d = near_door
		var s2: String = d["name"] + "  ·  공격 키"
		var tw := fnt.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
		var y2: float = d["y"] - 230.0 + sin(tt * 4.0) * 3.0
		front.draw_rect(Rect2(d["x"] - tw / 2.0, y2 - 16.0, tw, 24.0), Color(0, 0, 0, 0.6))
		front.draw_string(fnt, Vector2(d["x"] - tw / 2.0 + 10.0, y2 + 1.0), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffe9a8"))
