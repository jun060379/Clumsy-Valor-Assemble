extends Node2D
## 길드 마을: street (spawn) → an earth band rising to the guild terrace → terrace → band down → upper street (camp, wagon, barn)
## → slope down; and under it a ramp into the lower plaza (fountain) → riverside valley → bridge → big tree.
## Ported from the prototype's GUILD TOWN v3 (terrY / TPL / townLand / BLD / drawTown) and its time of day.

const PK := 2.0
const BS := 1.35              # buildings and trees are drawn 1.35x; people-scale props stay 1x
const BIGK := ["g_store", "g_tentR", "g_barn", "g_cottage", "g_well", "g_forge", "g_anvil", "g_kiln", "g_hall", "q_fountain", "f_bush1", "f_bush2", "f_bush3"]
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
# the slopes (owner 2026-11-06 dropped the stone stairs: back to the long slopes)
const UPA := SX0                 # the slope up to the hall terrace: UPA..SX1
const DNB := EX1                 # the slope down from it: DX1..DNB
const RMA := SX0                 # the ramp down to the lower plaza: RMA..RX1
const LWA := STX1                # the slope down to the lower street: LWA..STX1+SL
const SURFR := 6.0
const PXK := 1.78
const CAMPFIRE := preload("res://assets/fx/town/campfire.png")
const RIVER := preload("res://assets/fx/town/river.png")
const LIFE := preload("res://scripts/town_life.gd")
const TFX := preload("res://scripts/town_fx.gd")
const TF := preload("res://scripts/townsfolk.gd")
const BRAN := preload("res://scripts/bran.gd")
const LIT := preload("res://scripts/lit.gd")
const SHADE := preload("res://scripts/shade.gd")
const SKY := preload("res://scripts/sky.gd")
## the hall facade's windows (g_hall_win px): they light up from 18:40 and before 06:20
const HALL_WIN := [[87, 359], [93, 289], [169, 287], [169, 369], [247, 235], [253, 365], [323, 129], [327, 233], [389, 359], [401, 235], [489, 369], [495, 287], [561, 289], [563, 359]]
## leaf rows of the canopies (baked by splitting each tree by the prototype's colour rule: g >= r*0.85 and g > b*1.3)
const TREE_ROWS := {"f_tree2": [2, 247], "f_tree3": [2, 247], "f_bigtree": [2, 307],
	"f_oak": [0, 276], "f_round": [0, 251], "f_young": [0, 195], "f_tall": [0, 281]}   # tools/make_town_trees.py, drawn 1:1
const LAMP_BAN := Vector2(30, 97)     # where the lamp's banner (q_lamp_ban) sits on q_lamp
## the wagon's horse (horse_strip: 8 cells of 214x148; frame 0 is cut into base / neck / tail / neck root)
const HCW := 214
const HCH := 148
const HDX := 159.0                   # the horse at the new wagon's shaft (g_wagon2 280 wide)
const NECK_PIV := Vector2(128, 56)
const TAIL_PIV := Vector2(30, 46)
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
var sway_t := {}            # per tree: leaf-ball frame clock
var deco_props: Array = []
var rocks: Array = []
var deco_front: Array = []      # nature in front of the stand line: drawn after buildings and props
var lamps: Array = []
var light_strings: Array = []
var doors: Array = []
var tex := {}
var t_solid: Texture2D
var t_band: Texture2D
var t_wall: Texture2D
var near_door = null
var kind := "town"
var lit                       # lit.gd: shade, ambient, lights, hall windows, fog (drawLighting)
var hx := {}                     # pre-scaled (BS) textures, drawn 1:1
var win_sv: SubViewport         # the hall windows drawn apart (LIT.wc): the heroine cut out of them
var win_draw: Node2D
var win_cut: Node2D
var shade                     # shade.gd: sun shadow volumes, cloud shadows, the deep shade under the terraces
var bg_layer: CanvasLayer
var bg_node: Node2D
var front: Node2D
var ground_node: Node2D
var blade_back: Node2D
var blade_front: Node2D
var blade_mat: ShaderMaterial
var bmesh := {}
var gci: CanvasItem              # what _shear draws on (the ground node)
var g_vr := Rect2()              # the span the ground node was last drawn for
var near_node: Node2D           # props standing nearer than the people's line (drawn over them)
var light_tex: GradientTexture2D
var tfx: Array = []
var emit_t := {}
var fxa                       # the ambient effects with a cause (town_fx.gd)
var life                      # wind, grass, props, birds, weather (town_life.gd)
var folk                      # townsfolk (lives on the arena)
var bran
var folk_node: Node2D
var lbl_layer: CanvasLayer
var labels: Node2D
var prof_cache := {}
var horse := {"st": "idle", "t": 0.0, "next": 4000.0, "neck": 0.0, "tail": 0.0, "chew": 0.0, "st_t": 0.0, "frame": 0, "wake": false}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = preload("res://scripts/player.gd").pix_mat_marked()     # 캐릭터 도트화 for Eilin drawn among the props
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
	# owner 2026-11-06: the 1.35x sprites re-drawn at 1.35x on the 1-px grid (tools/rebake_town.py), drawn 1:1 — their
	# pixels the same size as the characters'. tex[] keeps the originals for layout, climb tops and shadows
	for k in tex.keys():
		if ResourceLoader.exists("res://assets/town/hx/" + k + ".png"): hx[k] = load("res://assets/town/hx/" + k + ".png")
	_build_tex()
	_build_ground2()
	_layout()
	_build_climb()
	light_tex = GradientTexture2D.new()
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	light_tex.gradient = gr
	lit = LIT.new(arena)
	lit.attach()
	shade = SHADE.new(arena, self)
	lit.set_shade(shade)
	lit.pre_fn = _draw_windows
	lit.pre.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lit.post_fn = func(ci): SKY.draw_fog(ci, self, [[G, 0.8], [TTOP, 0.6]])
	_win_setup()
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	arena.add_child(bg_layer)
	bg_node = Node2D.new()
	bg_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg_node.draw.connect(_draw_bg)
	bg_layer.add_child(bg_node)
	# the ground on its own canvas item under the blades behind the line, which are under the scenery (perf, owner
	# 2026-11-06 "렉": the blades went to the GPU, shaders/grass_blades.gdshader)
	ground_node = Node2D.new()
	ground_node.z_index = -7
	ground_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground_node.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground_node.draw.connect(_draw_ground)
	arena.add_child(ground_node)
	blade_mat = ShaderMaterial.new()
	blade_mat.shader = preload("res://shaders/grass_blades.gdshader")
	blade_back = Node2D.new()
	blade_back.z_index = -6
	blade_back.material = blade_mat
	blade_back.draw.connect(func(): _draw_blade_meshes(blade_back, "back"))
	arena.add_child(blade_back)
	blade_front = Node2D.new()
	blade_front.z_index = 8
	blade_front.material = blade_mat
	blade_front.draw.connect(func(): _draw_blade_meshes(blade_front, "front"))
	arena.add_child(blade_front)
	if arena.dbg.has("nograss"):
		blade_back.visible = false
		blade_front.visible = false
	if arena.dbg.has("nolit"):
		lit.visible = false
		if shade.get("sv") != null: shade.sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	front = Node2D.new()
	front.z_index = 8
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.draw.connect(_draw_front)
	arena.add_child(front)
	# props whose foot is set lower on the plane than the people's stand line are nearer the camera: drawn over the
	# people (owner 2026-11-06: depth). z 1: over the player (0), under the grass blades in front (8) and the light (9)
	near_node = Node2D.new()
	near_node.z_index = 1
	near_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	near_node.draw.connect(_draw_near)
	arena.add_child(near_node)
	life = LIFE.new(self)
	fxa = TFX.new(self)
	bran = BRAN.new(self)
	folk = TF.of(arena)
	folk.town = self
	folk.place()
	# townsfolk are drawn like the party (smooth filtering), behind the player
	folk_node = Node2D.new()
	folk_node.z_index = -1
	folk_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	folk_node.draw.connect(func(): folk.draw(folk_node))
	folk_node.material = arena.player.pix_mat()      # 캐릭터 도트화 for the townsfolk too
	arena.add_child(folk_node)
	# speech bubbles and fireflies ride the camera on their own canvas, so the night ambient doesn't dim them
	lbl_layer = CanvasLayer.new()
	lbl_layer.follow_viewport_enabled = true
	arena.add_child(lbl_layer)
	arena.move_child(lbl_layer, 0)
	labels = Node2D.new()
	labels.draw.connect(_draw_labels)
	lbl_layer.add_child(labels)

func cleanup() -> void:
	lit.cleanup()
	bg_layer.queue_free()
	front.queue_free()
	near_node.queue_free()
	ground_node.queue_free()
	blade_back.queue_free()
	blade_front.queue_free()
	folk_node.queue_free()
	lbl_layer.queue_free()
	folk.town = null
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
	tpl = [{"x0": SX0, "x1": SX1, "y0": G, "y1": TTOP, "a": UPA}, {"x0": SX1, "x1": DX1, "y0": TTOP, "y1": TTOP}, {"x0": DX1, "x1": EX1, "y0": TTOP, "y1": G, "b": DNB},
		{"x0": EX1, "x1": STX1, "y0": G, "y1": G}, {"x0": STX1, "x1": STX1 + SL, "y0": G, "y1": LOWF, "a": LWA}, {"x0": RIV0 - 20.0, "x1": RIV1 + 20.0, "y0": LOWF, "y1": LOWF},
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
	deco_back = [["f_oak", -110.0, G, 7, false, 1.0], ["f_young", 735.0, G, 4.5, true, 1.6], ["f_bush1", 250.0, G, 0, false, 0.8], ["f_grass1", 770.0, G, 0, false, 0.6],
		["f_round", 1560.0, G, 4.5, true, 1.3], ["f_bush2", 1740.0, G, 0, false, 0.8], ["f_bush1", 4040.0, G, 0, true, 0.8], ["f_tall", 5330.0, G, 4.5, false, 1.4], ["f_grass1", 6040.0, G, 0, true, 0.6],
		["f_grass2", 8620.0, LOWF, 0, false, 0.6], ["f_bush3", 8620.0, LOWF, 0, false, 0.8], ["f_bigtree", 8609.0, LOWF, 0, false, 2.2], ["f_bush1", 9250.0, LOWF, 0, true, 0.8]]
	for d in deco_back:
		if BIGK.has(d[0]):
			var w2: float = tex[d[0]].get_width()
			d[1] = d[1] + w2 / 2.0 - w2 * BS / 2.0
	# nature on the ground plane (owner 2026-11-06): one palette with the ground, no outlines; the old bushes become the
	# old bushes kept (owner: the code-drawn shrub did not fit); small clusters at doors and trees, set at depths on the plane (y = stand line + d), calm stretches between
	if tex.has("k_lawn"):
		for d in deco_back:
			if String(d[0]).begins_with("f_grass"): d[0] = ""      # the old grass sprites go too: the blades do that job
		deco_back = deco_back.filter(func(d): return d[0] != "")
		deco_back.sort_custom(func(p, q): return p[2] < q[2])
	deco_props = [["q_barrelL", 630.0, G], ["q_barrelS", 690.0, G], ["q_crateL", 1560.0, G], ["q_crateS", 1624.0, G],
		["q_barrelM", HX2 + 470.0, TTOP], ["q_barrelS", HX2 + 522.0, TTOP], ["q_crateL", HX2 + 120.0, TTOP],
		["q_board", 2600.0, LOWF], ["q_bench", HDOOR - 230.0, LOWF], ["q_bench", HDOOR + 84.0, LOWF, true], ["q_planter", HDOOR - 320.0, LOWF], ["q_planter", HDOOR + 238.0, LOWF, true],
		["q_pot", HDOOR - 140.0, LOWF], ["q_pot", HDOOR + 112.0, LOWF], ["q_barrelL", 3560.0, LOWF], ["q_barrelM", 3616.0, LOWF], ["q_crateL", 4400.0, LOWF], ["q_crateS", 4464.0, LOWF],
		["q_barrelL", 5000.0, LOWF], ["q_crateL", 5700.0, LOWF], ["q_barrelS", 5764.0, LOWF], ["q_crateS", 6650.0, LOWF], ["q_barrelM", 8150.0, LOWF]]
	# stones on the ground (owner 2026-11-06), cut from the map scene, 2-px grid: [piece, x, surface y]
	rocks = [["f2_rock", 1790.0, G], ["f2_pebble", 1534.0, G], ["f2_pebble", 5420.0, G], ["f2_rock", 6080.0, G],
		["f2_pebble", 7050.0, LOWF], ["f2_rock", 8560.0, LOWF], ["f2_pebble", 9180.0, LOWF], ["f2_pebble", 2420.0, TTOP]]
	lamps = [[SX1 + 40.0, TTOP], [DX1 - 40.0, TTOP], [HDOOR - 400.0, LOWF], [HDOOR + 380.0, LOWF], [4700.0, LOWF], [5600.0, LOWF], [1700.0, G]]
	light_strings = [[HDOOR - 420.0, HDOOR - 20.0], [HDOOR + 20.0, HDOOR + 420.0], [4250.0, 4650.0], [5250.0, 5650.0]]
	STONE.append([HDOOR - 420.0, HDOOR + 420.0])               # the hall's forecourt / the plaza under it: paved
	for b in bld:
		if b[0] == "g_yard": CLEAR.append([b[1] - 20.0, b[1] + tex["g_yard"].get_width() + 20.0])   # the whole training yard
	CLEAR.append([7400.0, 7780.0])                             # the forge yard
	# the slopes are grass (owner 2026-11-06: everywhere but the paths made dirt on purpose is grass, slopes too)
	CLEAR.append([6720.0, 6880.0])                             # the bath house door
	CLEAR.sort_custom(func(p, q): return p[0] < q[0])
	# crates, barrels, benches, pots and lamps step forward onto the plane like the people (buildings stay at its back)
	if tex.has("k_lawn"):
		var dep := [6.0, 9.0, 4.0, 8.0, 11.0, 5.0, 7.0]
		for i in deco_props.size(): deco_props[i][2] = deco_props[i][2] + dep[i % dep.size()]
		for lp in lamps: lp[1] = lp[1] + 7.0

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


# ---------- climbable tops: one-way (sloped) surfaces traced from each placed sprite's top silhouette ----------
## first opaque row of every column, median-filtered over 13 columns (drops thin spikes: finials, poles)
func _top_profile(k: String) -> Dictionary:
	if prof_cache.has(k): return prof_cache[k]
	var img: Image = tex[k].get_image()
	if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var data := img.get_data()
	var top := PackedInt32Array()
	top.resize(w)
	for x in w:
		top[x] = -1
		for y in h:
			if data[(y * w + x) * 4 + 3] > 40:
				top[x] = y
				break
	var sm := PackedInt32Array()
	sm.resize(w)
	for i in w:
		sm[i] = -1
		if top[i] < 0: continue
		var win := []
		for j in range(maxi(0, i - 6), mini(w, i + 7)):
			if top[j] >= 0: win.append(top[j])
		win.sort()
		sm[i] = win[win.size() / 2]
	var P0 := {"w": w, "h": h, "top": sm}
	prof_cache[k] = P0
	return P0

func _rdp(pts: Array, eps: float) -> Array:
	if pts.size() < 3: return pts
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var md := 0.0
	var mi := 0
	var ln := maxf(0.0001, a.distance_to(b))
	for i in range(1, pts.size() - 1):
		var p: Vector2 = pts[i]
		var d := absf((b.y - a.y) * p.x - (b.x - a.x) * p.y + b.x * a.y - b.y * a.x) / ln
		if d > md:
			md = d
			mi = i
	if md > eps:
		var l := _rdp(pts.slice(0, mi + 1), eps)
		var r := _rdp(pts.slice(mi), eps)
		return l.slice(0, l.size() - 1) + r
	return [a, b]

func _add_climb(k: String, x: float, y_bottom: float, sink: float, flip: bool) -> void:
	if not tex.has(k): return
	var P0 := _top_profile(k)
	var s := ks(k)
	var pw: int = P0["w"]
	var ph: int = P0["h"]
	var top: PackedInt32Array = P0["top"]
	var y0 := y_bottom - (ph - sink * PK) * s
	var base := y_bottom - 26.0
	var runs := []
	var run := []
	for i in range(0, pw, 4):
		var v := top[i]
		if v < 0 or v > ph - 6:
			if run.size() > 0: runs.append(run)
			run = []
			continue
		run.append(Vector2(i, v))
	if run.size() > 0: runs.append(run)
	for r in runs:
		var sp := _rdp(r, 3.0)
		for i in sp.size() - 1:
			var A: Vector2 = sp[i]
			var B: Vector2 = sp[i + 1]
			if B.x - A.x < 12.0: continue
			if absf(B.y - A.y) / (B.x - A.x) > 1.25: continue
			var X0 := x + (pw - B.x if flip else A.x) * s
			var X1 := x + (pw - A.x if flip else B.x) * s
			var Y0 := y0 + (B.y if flip else A.y) * s + 3.0
			var Y1 := y0 + (A.y if flip else B.y) * s + 3.0
			# keep only the part clearly above the floor, so walking past never climbs it by itself
			if Y0 > base and Y1 > base: continue
			if Y0 > base:
				X0 = X0 + (X1 - X0) * (Y0 - base) / (Y0 - Y1)
				Y0 = base
			if Y1 > base:
				X1 = X0 + (X1 - X0) * (base - Y0) / (Y1 - Y0)
				Y1 = base
			if X1 - X0 >= 10.0:
				tpl.append({"x0": X0, "x1": X1, "y0": Y0, "y1": Y1, "climb": k})

func _build_climb() -> void:
	for b in bld:
		if b[0] == "g_ring" or b[0] == "g_anvil": continue
		_add_climb("g_wagon2" if b[0] == "g_wagon" else b[0], b[1], b[2], b[3], b.size() > 7 and b[7])
	_add_climb("g_hall", HXB, TTOP, 1.0, false)
	for d in deco_props:
		if d[0] == "q_pot": continue
		_add_climb(d[0], d[1], d[2], 0.0, d.size() > 3 and d[3])
	_add_climb("q_fountain", HDOOR - 52.0 * PK * BS, LOWF, 0.0, false)


## in the river below the bridge: feet here are in the water (owner 2026-11-06)
func wet_at(x: float, y: float) -> bool:
	return kind == "town" and x > RIV0 and x < RIV1 and y > LOWF + 20.0

# ---------- surfaces ----------
## a slope from 0 to 1 over u in [0, 1] with its two corners rounded over ROUND px (owner 2026-11-06: the slope met the
## flat at a hard kink): straight in the middle, a quadratic ease at each end; walking and drawing both use it
const ROUND := 70.0
func rr(u: float, span: float) -> float:
	u = clampf(u, 0.0, 1.0)
	var c := clampf(ROUND / maxf(1.0, span), 0.0, 0.45)
	if c <= 0.0: return u
	var sl := 1.0 / (1.0 - c)
	if u < c: return sl * u * u / (2.0 * c)
	if u > 1.0 - c: return 1.0 - sl * (1.0 - u) * (1.0 - u) / (2.0 * c)
	return sl * (u - c / 2.0)

func terr_y(x: float) -> float:
	if x < SX0: return G
	if x < RX1: return ramp_y(x)
	if x < RIV0 or x >= RIV1: return LOWF
	return LOWF + 60.0

func plat_y(p: Dictionary, x: float) -> float:
	var a: float = p.get("a", p.x0)
	var b: float = p.get("b", p.x1)
	if p.y0 == p.y1: return p.y0
	return p.y0 + (p.y1 - p.y0) * rr((x - a) / (b - a), b - a)

func up_y(x: float) -> float:
	if x < SX1: return G + (TTOP - G) * rr((x - UPA) / (SX1 - UPA), SX1 - UPA)
	if x < DX1: return TTOP
	if x < EX1: return TTOP + (G - TTOP) * rr((x - DX1) / (DNB - DX1), DNB - DX1)
	if x < STX1: return G
	return G + (LOWF - G) * rr((x - LWA) / (STX1 + SL - LWA), STX1 + SL - LWA)

func ramp_y(x: float) -> float:
	return G + (LOWF - G) * rr((x - RMA) / (RX1 - RMA), RX1 - RMA) if x < RX1 else LOWF

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
## the world's one clock lives on the arena (shared with the hall and Eilin's day)
func tod_now() -> Dictionary:
	return arena.tod_now()

func lantern_at(x: float, surf: float) -> Vector2:
	var im: Texture2D = tex["q_lamp"]
	var lx := 76.0 / 113.0 * im.get_width() - 56.0     # the lantern glass on q_lamp (2026-11-06 redraw, 2-px grid)
	var ly := 100.0 / 197.0 * im.get_height()
	return Vector2(x + lx, surf - (im.get_height() - ly))


# ---------- lights (lightSources, drawLighting: lit.gd / shade.gd) ----------
## the hall windows' glow: up from 18:40, down by 06:20
func hall_win() -> float:
	var hh := fposmod(arena.tod_h, 24.0)
	return clampf((hh - 18.7) / 0.9, 0.0, 1.0) if hh >= 12.0 else clampf((6.3 - hh) / 0.7, 0.0, 1.0)

## a point on a building grown about its door (BM)
func bm(k: String, x: float, y: float) -> Vector2:
	for b in bld:
		if b[0] == k and b.size() > 4 and b[4] != null:
			var ax: float = b[1] + b[4]
			return Vector2(ax + (x - ax) * BS, b[2] + (y - b[2]) * BS)
	return Vector2(x, y)

func win_y0() -> float:
	return TTOP - (tex["g_hall_win"].get_height() - PK) * BS

func light_sources() -> Array:
	var L: Array = []
	var t := Time.get_ticks_msec() / 1000.0
	for i in lamps.size():
		var p := lantern_at(lamps[i][0], lamps[i][1])
		L.append({"k": "lamp", "x": p.x, "y": p.y, "gy": lamps[i][1], "r": 150.0, "a": LIT.fl(t, i), "c": Color8(255, 196, 110)})
	for s in light_strings:
		var yy: float = up_y((s[0] + s[1]) / 2.0) + BAND - 10.0 + 18.0
		for i in 7:
			var bu: Array = LIT.BULBS[i]
			L.append({"k": "bulb", "x": s[0] + (s[1] - s[0]) * bu[0], "y": yy - 18.0 + bu[1], "r": 60.0, "a": 0.8 + 0.2 * sin(t * 3.0 + i * 1.7), "c": Color8(255, 214, 140)})
	L.append({"k": "fire", "x": 4350.0 + 27.0 * PK, "y": G - 30.0, "gy": G, "r": 230.0, "a": LIT.fl(t, 9) * 1.1, "c": Color8(255, 150, 70)})
	var fp := bm("g_forge", 7443.0, LOWF - 52.0)        # the forge: a contained glow in the mouth, not a sun
	L.append({"k": "fire", "x": fp.x, "y": fp.y, "gy": LOWF, "r": 170.0, "a": LIT.fl(t, 4) * 0.5, "c": Color8(255, 140, 60)})
	L.append({"k": "soft", "x": HDOOR, "y": LOWF - 80.0 * BS, "r": 200.0, "a": 0.7, "c": Color8(200, 230, 255)})
	# the warm glow at the door you stand by, as big as its building
	if near_door != null and near_door.has("to"):
		var dk := 1.0
		if near_door["name"] == "길드 본관": dk = BS
		else:
			for b in bld:
				if b.size() > 4 and b[4] != null and absf(b[1] + b[4] - near_door["x"]) < 2.0:
					dk = ks(b[0])
					break
		L.append({"k": "soft", "x": near_door["x"], "y": near_door["y"] - 46.0 * dk, "r": 110.0 * dk, "a": 0.85, "c": Color8(255, 200, 130)})
	var wf := hall_win()
	if wf > 0.01:
		var y0 := win_y0()
		for w in HALL_WIN:
			L.append({"k": "win", "x": HXB + w[0] * BS, "y": y0 + w[1] * BS, "r": 70.0 * BS, "a": wf * (0.9 + 0.1 * sin(t * 1.3 + w[0])), "c": Color8(255, 200, 120)})
	return L

## how deep the shade is at each light (cheap geometric test) -> boost: lights read brighter in shade
func _boost(L: Array, T: Dictionary) -> void:
	var u := LIT.sun_dir(arena.tod_h)
	var occ := shade_occluders()
	for l in L:
		var sh := 0.0
		var lx: float = l["x"]
		var ly: float = l["y"]
		if kind == "town" and lx > SX0 and lx < STX1 + SL and ly > minf(LOWF, up_y(lx) + BAND - 14.0):
			sh = 0.85            # under the terraces
		else:
			for o in occ:
				var bx: Rect2 = SHADE.box(o)
				var yb: float = o[2]
				if ly < bx.position.y or ly > yb + 8.0: continue
				var rch := (yb - ly) * u.x / u.y
				if lx > minf(bx.position.x, bx.position.x + rch) and lx < maxf(bx.end.x, bx.end.x + rch):
					sh = maxf(sh, 0.55 if o[6] else 0.7)
		l["boost"] = minf(1.25, maxf(T["lamp"], sh * 1.2))

func _light_step(T: Dictionary) -> void:
	var L := light_sources()
	_boost(L, T)
	lit.L = L
	lit.amb = T["amb"]
	# (the ambient multiply in lit.gd covers the whole screen, the sky behind the world included, as in the prototype)
	shade.update(T, arena.tod_h, L)
	lit.redraw()
	if win_sv != null: _win_step()

## rimLights for the character shader: dimmed by day, plus the sky (sun or moon) as a far light
func rim_lights() -> Array:
	var T := tod_now()
	var nk := clampf((T["sky"].a - 0.33) / 0.33, 0.0, 1.0)
	var out: Array = lit.rim_lights(0.12 + 0.88 * nk)
	var h := fposmod(arena.tod_h, 24.0)
	var day := h >= 6.0 and h < 18.0
	var u := (h - 6.0) / 12.0 if day else fposmod(h - 18.0, 24.0) / 12.0
	var ang := PI * (1.0 - u)
	var P = arena.player
	var warm := day and (h < 8.5 or h > 16.0)
	out.append([P.position + Vector2(cos(ang) * 1600.0, -200.0 - sin(ang) * 1400.0), 4000.0, (0.95 if warm else 0.75) if day else 0.6,
		(Color8(255, 165, 105) if warm else Color8(255, 238, 210)) if day else Color8(150, 175, 255)])
	return out

## occluders: buildings (not the ring or the anvil), the hall, the trees — [tex, x, y_bottom, sink, flip, scale, tree]
func shade_occluders() -> Array:
	var o: Array = []
	for b in bld:
		var k: String = b[0]
		if k == "g_ring" or k == "g_anvil": continue
		var tx: Texture2D = tex["g_wagon2"] if k == "g_wagon" and tex.has("g_wagon2") else tex[k]
		o.append([tx, b[1], b[2], b[3], b.size() > 7 and b[7], ks(k), false])
	o.append([tex["g_hall"], HXB, TTOP, 1.0, false, BS, false])
	for d in deco_back:
		if d[0].contains("tree"): o.append([tex[d[0]], d[1], d[2], d[3], d[4], ks(d[0]), true])
	return o

func shade_props() -> Array:
	var o: Array = []
	for d in deco_props:
		o.append([tex[d[0]], d[1], d[2], 0.0, d.size() > 3 and d[3], ks(d[0]), false])
	return o

## surfTop: what clouds land on from above
func surf_top(x: float) -> float:
	if x < SX0: return G
	if x < STX1 + SL: return up_y(x)
	return LOWF

## cloud shade stops at the terraces' edge: the lower plaza lives in their shade
func cloud_bottom(x: float) -> float:
	if x >= SX0 and x <= STX1 + SL: return minf(LOWF, up_y(x) + BAND - 14.0)
	return G + 380.0

## the lower plaza lives under the terraces: deep shade
func shade_extra(ci: CanvasItem) -> void:
	var vr: Rect2 = arena.view_rect()
	if vr.end.x < SX0 or vr.position.x > STX1 + SL: return
	var pts := PackedVector2Array([Vector2(SX0, G)])
	var x := SX0
	while x <= STX1 + SL:
		pts.append(Vector2(x, minf(LOWF, up_y(x) + BAND - 14.0)))
		x += 40.0
	pts.append(Vector2(STX1 + SL, LOWF + 40.0))
	pts.append(Vector2(SX0, LOWF + 40.0))
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.55))

## the hall facade's lit windows: drawn into their own small canvas (the facade's size) with someone walking past one now
## and then, the window glows, and the heroine cut out of it (whoever stands in front of the hall hides them); laid over
## the world after the ambient at the windows' strength
func _win_setup() -> void:
	win_sv = SubViewport.new()
	win_sv.disable_3d = true
	win_sv.transparent_bg = true
	win_sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	win_sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	var k := 0.5 if arena.low_end else 1.0
	var im: Texture2D = tex["g_hall_win"]
	win_sv.size = Vector2i(ceili(im.get_width() * BS * k), ceili(im.get_height() * BS * k))
	lit.add_child(win_sv)
	win_sv.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, -Vector2(HXB, win_y0()) * k)
	win_draw = Node2D.new()
	win_draw.draw.connect(_draw_win_canvas)
	win_sv.add_child(win_draw)
	win_cut = Node2D.new()
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADE.CUT_SH
	m.shader = sh
	win_cut.material = m
	win_cut.draw.connect(func():
		# everyone standing in front of the hall cuts the windows' glow (the player, the townsfolk, Eilin): the lights
		# are drawn over the facade, so without the cut they'd paint over the people
		var P = arena.player
		if P.visible: P.draw_frame(P.who, P.anim, P.f, P.position, P.dir, Color.WHITE, "", win_cut)
		if folk != null: folk.draw(win_cut)
		var E = arena.eil
		if E != null and E.map == "town" and not E.hide: E.draw_on(win_cut, roundf(E.x), roundf(E.y)))
	win_sv.add_child(win_cut)

func _win_on() -> bool:
	var vr: Rect2 = arena.view_rect()
	return hall_win() > 0.01 and HXB + tex["g_hall_win"].get_width() * BS > vr.position.x and HXB < vr.end.x and win_y0() < vr.end.y and TTOP > vr.position.y

func _win_step() -> void:
	var on := _win_on()
	win_sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if on:
		win_draw.queue_redraw()
		win_cut.queue_redraw()

func _draw_win_canvas() -> void:
	var im: Texture2D = tex["g_hall_win"]
	var y0 := win_y0()
	var imh: Texture2D = hx.get("g_hall_win", im)
	win_draw.draw_texture_rect(imh, Rect2(HXB, y0, imh.get_width() if hx.has("g_hall_win") else im.get_width() * BS, imh.get_height() if hx.has("g_hall_win") else im.get_height() * BS), false)
	var s2 = life.sil
	if s2 != null:
		# the silhouette darkens only the window pixels: the window art itself, tinted brown
		var u: float = s2["t"] / s2["life"]
		var wx: float = s2["wx"] + s2["dir"] * (u - 0.5) * 34.0
		var wy: float = s2["wy"] + 4.0
		var brown := Color(70.0 / 255.0, 40.0 / 255.0, 25.0 / 255.0, 0.72)
		for r in [Rect2(wx - 8.0, wy - 4.0, 16.0, 16.0), Rect2(wx - 3.0, wy - 14.0, 6.0, 10.0), Rect2(wx - 5.0, wy - 12.0, 10.0, 6.0)]:
			var dr := Rect2(HXB + r.position.x * BS, y0 + r.position.y * BS, r.size.x * BS, r.size.y * BS)
			win_draw.draw_texture_rect_region(imh, dr, Rect2(r.position * BS, r.size * BS) if hx.has("g_hall_win") else r, brown)
	for l in lit.L:
		if l["k"] == "win": LIT.shape(win_draw, l, 1.0)

func _draw_windows(ci: CanvasItem) -> void:
	if not _win_on(): return
	var im: Texture2D = tex["g_hall_win"]
	ci.draw_texture_rect(win_sv.get_texture(), Rect2(HXB, win_y0(), im.get_width() * BS, im.get_height() * BS), false, Color(1, 1, 1, hall_win()))


# ---------- step ----------
func step(dt: float) -> void:
	var T := tod_now()
	var vr: Rect2 = arena.view_rect()
	# doors
	var P = arena.player
	near_door = null
	if P.on and not P.attacking():
		for d in doors:
			if absf(P.position.x - d["x"]) < 46.0 and absf(P.position.y - d["y"]) < 6.0:
				near_door = d
				break
		if near_door == null:
			near_door = arena.eil.door_near(P)
		var tl: bool = arena.dlg.locked()       # TALKLOCK: no new talk with the townsfolk or Bran yet
		if near_door == null and not tl:
			var n = folk.near(P)
			if n != null:
				near_door = {"x": n["x"], "y": n["y"], "name": TF.CH.NAME[n["c"]], "act": "npc", "c": n["c"], "hide": n["say_t"] > 0.0}
		if near_door == null and not tl and bran.is_near(P):
			near_door = {"x": bran.x + bran.MID, "y": bran.y, "name": "브랜", "act": "bran"}
		if near_door == null and absf(P.position.x - HDOOR) < 120.0 and absf(P.position.y - LOWF) < 30.0:
			near_door = {"x": HDOOR, "y": LOWF - 20.0, "name": "파티 편성", "act": "party"}     # the fountain (nearFountain)
	life.step(dt)
	fxa.step(dt)
	folk.step(dt)
	bran.step(dt)
	_horse_step(dt)
	# leaves blow off the trees on screen (more in a gust)
	for d in deco_back:
		var k: String = d[0]
		if not k.contains("tree"): continue
		var w: float = tex[k].get_width()
		var s: float = ks(k)
		if d[1] > vr.end.x or d[1] + w * s < vr.position.x: continue
		if randf() < 0.004 * (0.3 + life.gust * 2.0) * w / 250.0 * dt / 16.7:
			var h: float = tex[k].get_height()
			tfx.append({"k": "leaf", "x": d[1] + w * s * (0.2 + randf() * 0.6), "y": d[2] - h * s * (0.6 + randf() * 0.25), "vx": 0.02, "vy": 0.02 + randf() * 0.02, "t": 0.0, "life": 4500.0,
				"ph": randf() * 9.0, "c": Color("#6f8f44") if randf() < 0.5 else Color("#97ad58")})
	# ambient: smoke, embers, fountain drops, leaves
	var gx: float = life.gust * 0.03
	_emit("leaf", 420.0, dt, func(): tfx.append({"k": "leaf", "x": 8750.0 + randf() * 450.0, "y": LOWF - 340.0 + randf() * 120.0, "vx": 0.02, "vy": 0.025 + randf() * 0.02, "t": 0.0, "life": 6500.0, "ph": randf() * 9.0, "c": Color("#8f8a3a") if randf() < 0.5 else Color("#b8aa52")}))
	_emit("leaf2", 1100.0, dt, func(): tfx.append({"k": "leaf", "x": randf() * 500.0, "y": G - 300.0, "vx": 0.02, "vy": 0.02 + randf() * 0.02, "t": 0.0, "life": 5000.0, "ph": randf() * 9.0, "c": Color("#9a9446")}))
	var gl: float = life.gust * 0.05
	for f in tfx:
		f["t"] += dt
		f["x"] += f["vx"] * dt
		f["y"] += f["vy"] * dt
		if f["k"] == "leaf": f["vx"] = 0.02 + gl + sin(f["t"] / 300.0 + f["ph"]) * 0.03
		elif f["k"] == "spark": f["vy"] += 0.0005 * dt
		if f["k"] == "drop":
			f["vy"] += 0.0009 * dt
			if f["y"] > f["floor"]: f["t"] = f["life"]
	tfx = tfx.filter(func(f): return f["t"] < f["life"])
	_light_step(T)
	queue_redraw()
	front.queue_redraw()
	near_node.queue_redraw()
	# the ground is static: drawn for the view and 600 px either side, redrawn only when the view leaves that
	var gvr: Rect2 = arena.view_rect()
	if not g_vr.encloses(gvr): ground_node.queue_redraw()
	blade_back.queue_redraw()
	blade_front.queue_redraw()
	life.blade_uniforms(blade_mat)
	bg_node.queue_redraw()
	folk_node.queue_redraw()
	labels.queue_redraw()

func _emit(id: String, every: float, dt: float, fn: Callable) -> void:
	emit_t[id] = emit_t.get(id, 0.0) + dt
	while emit_t[id] > every:
		emit_t[id] -= every
		fn.call()

func try_interact() -> bool:
	if near_door == null:
		return false
	var d = near_door
	var to: String = d.get("to", "")
	if to == "arena":
		arena.sfx("ui_ok", 0.6)
		arena.fade_then(func(): arena.go_training())
	elif to == "dungeon":
		arena.sortie.open_dsel(0)          # 출격 마차: the dungeon select
	elif to == "hall":
		arena.sfx("ui_ok", 0.6)
		var s0: Array = arena.HALL.HD.SPAWN[0]
		arena.fade_then(func(): arena.go_hall(0, Vector2(s0[0], s0[1]), s0[2]))
	elif d.get("act", "") == "eilin":
		arena.eil.talk()
	elif d.get("act", "") == "party":
		arena.sortie.party_ui.show_it()
	elif d.get("act", "") == "npc":
		folk.talk(d["c"])
	elif d.get("act", "") == "bran" or to == "forge":
		bran.talk()
	else:
		arena.sfx("guard", 0.4)
		arena.text(arena.player.position + Vector2(0, -170), d["name"] + " — 준비 중", Color("#ffe9a8"))
	return true


# ---------- drawing ----------
func _draw_bg() -> void:
	var bz: float = arena.base_zoom
	bg_layer.scale = Vector2(bz, bz)          # the far layers on the same whole-px scale as the world
	var vs := get_viewport_rect().size / bz
	var c: Vector2 = arena.cam.get_screen_center_position()
	var cam_x := c.x - vs.x / 2.0
	var cam_y := c.y - vs.y / 2.0
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color8(49, 120, 122))
	var sky: Texture2D = tex["bg_sky"]
	var sh := G + 4.0 + 200.0
	var sw := sky.get_width() * sh / sky.get_height()
	var x := -fposmod(roundf(cam_x * 0.02), sw) - sw
	while x < vs.x + sw:
		bg_node.draw_texture_rect(sky, Rect2(x, roundf(-200.0 - cam_y * 0.08), sw, sh), false)
		x += sw
	var mt: Texture2D = tex["bg_mountains"]
	_layer(hx.get("bg_mountains", mt), 0.16, G - mt.get_height() * PXK - 40.0 - cam_y * 0.12, 1.0 if hx.has("bg_mountains") else PXK, cam_x, vs)
	var T := tod_now()
	var dim: float = 1.0 - 0.75 * T["sun"]
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.07, 0.05, 0.16, 0.2 * dim))
	var fo: Texture2D = tex["bg_forest"]
	_layer(hx.get("bg_forest", fo), 0.42, G + 2.0 - 242.0 * PXK - cam_y * 0.25, 1.0 if hx.has("bg_forest") else PXK, cam_x, vs)
	bg_node.draw_rect(Rect2(0, G + 1.0 - cam_y * 0.25, vs.x, vs.y + 400.0), Color8(14, 74, 78))
	# far haze: a vertical gradient, light above the forest, heavier toward the ground
	var hy0 := G - 260.0 - cam_y * 0.25
	var hy1 := G + 20.0 - cam_y * 0.25
	var hc := Color(10.0 / 255.0, 8.0 / 255.0, 24.0 / 255.0)
	var ha0 := 0.18 * dim
	var ha1 := 0.2 + 0.28 * dim
	if hy0 > 0.0: bg_node.draw_rect(Rect2(0, 0, vs.x, hy0), Color(hc, ha0))
	bg_node.draw_polygon(PackedVector2Array([Vector2(0, hy0), Vector2(vs.x, hy0), Vector2(vs.x, hy1), Vector2(0, hy1)]),
		PackedColorArray([Color(hc, ha0), Color(hc, ha0), Color(hc, ha1), Color(hc, ha1)]))
	if hy1 < vs.y: bg_node.draw_rect(Rect2(0, hy1, vs.x, vs.y - hy1), Color(hc, ha1))
	var skc: Color = T["sky"]
	if skc.a > 0.003:
		bg_node.draw_rect(Rect2(Vector2.ZERO, vs), skc)
	SKY.draw_night(bg_node, T, arena.tod_h, cam_x, G - mt.get_height() * PXK - 40.0 - cam_y * 0.12, vs.x)

## ping-pong tiling (every other tile mirrored)
func _layer(im: Texture2D, par: float, y: float, k: float, cam_x: float, vs: Vector2) -> void:
	var w := im.get_width() * k
	var h := im.get_height() * k
	var off := fposmod(roundf(cam_x * par), w * 2.0)
	var x := -off
	y = roundf(y)
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
	# the town draws its ground on ground_node for a wide span; the training ground (extends this) on itself, for the view
	var gc: CanvasItem = gci if gci != null else self
	var vr: Rect2 = g_vr if gci != null else arena.view_rect()
	var a := maxf(x0, floorf((vr.position.x - 10.0) / PK) * PK)
	var b := minf(x1, vr.end.x + 10.0)
	var tw := float(t.get_width())
	var th: float = t.get_height() if clip_h < 0.0 else minf(t.get_height(), clip_h)
	var x := a
	var vi := 0 if t == t_solid else (1 if t == t_band else -1)
	while x < b:
		var y0: float = roundf(f.call(x + PK / 2.0))
		if vi >= 0 and not g2.is_empty():
			# the ground plane (owner 2026-11-06): its back edge RAISE px above the line people and buildings stand on
			var k: String = gzone(x)
			var tt: Texture2D = g2[k][vi]
			var tw2 := float(tt.get_width())
			var th2: float = tt.get_height() if clip_h < 0.0 else minf(tt.get_height(), clip_h + RAISE)
			var sx2 := fposmod(x, tw2)
			gc.draw_texture_rect_region(tt, Rect2(x, y0 - RAISE, PK, th2), Rect2(minf(sx2, tw2 - PK), 0, PK, th2))
			# the turf lip: wherever the top of this column is grass (the lawn, and the grassy bits inside the clearing),
			# the green runs a ragged few rows down over the earth face -- the edge that makes the ground a block
			var green: bool = k == "lawn" or (g2green.has(k) and g2green[k][int(sx2) % g2green[k].size()])
			if green:
				var d := roundf(3.0 + 6.0 * _vnoise(x / 11.0) + 2.0 * _vnoise(x / 3.0 + 40.0))
				var rim := 99.0
				for z in CLEAR: rim = minf(rim, minf(absf(x - z[0]), absf(x - z[1])))
				if k != "lawn": d = roundf(1.0 + 3.0 * _vnoise(x / 2.0 + 9.0))     # a short ragged drip under a grassy bit
				else: d = roundf(d * _lip_taper(x))
				if d < 1.0:
					x += PK
					continue
				gc.draw_rect(Rect2(x, y0 - RAISE + LIPY, PK, d), LIPC)
				gc.draw_rect(Rect2(x, y0 - RAISE + LIPY + d, PK, 1.0), LIPC2)
			x += PK
			continue
		var sx := fposmod(x, tw)
		var y: float = y0 - SURFR
		gc.draw_texture_rect_region(t, Rect2(x, y, PK, th), Rect2(minf(sx, tw - PK), 0, PK, th))
		x += PK
	if vi >= 0 and not g2.is_empty(): _clear_caps(a, b, f)

## ---------- ground plane (tools/make_town_ground2.py) ----------
const RAISE := 12.0             # rows of the plane showing behind the stand line
# trodden paths (owner 2026-11-06: a lot of it is walked -- worn dirt before every door and gate, the camp, the barn)
var CLEAR := [[300.0, 700.0], [4080.0, 4960.0], [5440.0, 6100.0]]
var g2 := {}
var g2green := {}
var capgreen := []                # per tile column: is the top of the ground grass there (for the turf lip)
const LIPY := 28.0               # the row of the tile where the top meets the earth face
const LIPC := Color8(112, 134, 57)
const LIPC2 := Color8(88, 108, 50)
## where the turf lip runs out (the last grassy column at each end of each clearing): it tapers to nothing toward
## these over ~16 px, raggedly, instead of stopping in a straight cut
var lip_ends := []
func _lip_taper(x: float) -> float:
	var m := 1.0
	for e in lip_ends: m = minf(m, absf(x - e) / 16.0)
	return clampf(m + 0.25 * (_vnoise(x / 2.3 + 5.0) - 0.5), 0.0, 1.0)

## smooth value noise in [0, 1] (no period)
func _vnoise(u: float) -> float:
	var i := floorf(u)
	var f := u - i
	var a := fposmod(sin(i * 127.1) * 43758.5453, 1.0)
	var b := fposmod(sin((i + 1.0) * 127.1) * 43758.5453, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	return a + (b - a) * f
## where buildings, props and fences meet the ground: the blades grow thick there (town_life.build_blades)
func grass_edges() -> Array:
	var o: Array = []
	for b in bld:
		var k: String = b[0]
		if not tex.has(k): continue
		var w: float = tex[k].get_width() * ks(k)
		o.append(b[1] - 3.0)
		o.append(b[1] + w + 3.0)
	for d in deco_props:
		o.append(d[1] - 3.0)
		o.append(d[1] + tex[d[0]].get_width() * ks(d[0]) + 3.0)
	for d in deco_back:
		if String(d[0]).contains("tree") or String(d[0]) in ["f_oak", "f_round", "f_young", "f_tall"]:
			var tw2: float = tex[d[0]].get_width() * ks(d[0])
			o.append(d[1] + tw2 * 0.42)
			o.append(d[1] + tw2 * 0.58)
	o.append(HXB + 8.0)
	o.append(HXB + tex["g_hall"].get_width() * BS - 8.0)
	return o

## footprints of what stands on the ground ([x0, x1, depth of its base on the plane]): no blade grows out of them
func grass_feet() -> Array:
	var o: Array = []
	for b in bld:
		var k: String = b[0]
		if not tex.has(k) or k in ["g_yard", "g_ring"]: continue    # see-through fences: grass grows between the posts
		o.append([b[1] + 2.0, b[1] + tex[k].get_width() * ks(k) - 2.0, 0.0])
	for d in deco_props:
		o.append([d[1], d[1] + tex[d[0]].get_width() * ks(d[0]), d[2] - floor_at(d[1])])
	o.append([HXB, HXB + tex["g_hall"].get_width() * BS, 0.0])
	o.append([RIV0 - 10.0, RIV1 + 10.0, 99.0])
	for r in rocks:
		if tex.has(r[0]): o.append([r[1] + 4.0, r[1] + tex[r[0]].get_width() - 4.0, 0.0])
	return o

## stone paving (owner 2026-11-06: "이걸로 돌길이나 돌 장식도 깔 수 있는 거 아님?"): the hall's forecourt and the plaza under it
var STONE := []
func gzone(x: float) -> String:
	for z in STONE:
		if x >= z[0] and x < z[1]: return "stone"
	for z in CLEAR:
		if x >= z[0] and x < z[1]: return "clear"
	return "lawn"

func _build_ground2() -> void:
	if not tex.has("k_lawn"): return
	for k in ["lawn", "clear", "stone"]:
		if not tex.has("k_" + k): continue
		var im: Image = tex["k_" + k].get_image()
		im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		var w := im.get_width()
		var h := im.get_height()
		var deep := 520
		var solid := Image.create(w, deep, false, Image.FORMAT_RGBA8)
		solid.blit_rect(im, Rect2i(0, 0, w, h), Vector2i.ZERO)
		var last := im.get_region(Rect2i(0, h - 1, w, 1))
		for y in range(h, deep): solid.blit_rect(last, Rect2i(0, 0, w, 1), Vector2i(0, y))
		var band := solid.get_region(Rect2i(0, 0, w, int(BAND + RAISE)))
		var gr := []
		for xx in w:
			var ng := 0
			for yy in range(14, 28):
				var c := im.get_pixel(xx, yy)
				if c.a > 0.5 and c.g > c.r + 0.03: ng += 1
			gr.append(ng >= 3)             # grass reaching the front edge of the top at this column
		if k == "stone": gr.fill(false)     # moss between the stones is not a turf lip
		g2green[k] = gr
		g2[k] = [ImageTexture.create_from_image(solid), ImageTexture.create_from_image(band)]

## the clearing's own ragged ends over the lawn at each clearing edge
func _clear_caps(a: float, b: float, f: Callable) -> void:
	if not tex.has("k_clear_cap"): return
	var gc: CanvasItem = gci if gci != null else self
	var cap: Texture2D = tex["k_clear_cap"]
	var cw := float(cap.get_width())
	for z in CLEAR:
		for side in 2:
			var ex: float = z[0] if side == 0 else z[1]
			var x0: float = ex - cw / 2.0
			if x0 + cw < a or x0 > b: continue
			var y0: float = roundf(f.call(ex)) - RAISE
			if side == 0: gc.draw_texture_rect(cap, Rect2(x0, y0, cw, cap.get_height()), false)
			else:
				gc.draw_set_transform(Vector2(x0 + cw, 0), 0.0, Vector2(-1, 1))
				gc.draw_texture_rect(cap, Rect2(0, y0, cw, cap.get_height()), false)
				gc.draw_set_transform(Vector2.ZERO)
			# the turf lip under the cap's grassy columns too: the green carries on down the face to where the path begins
			if capgreen.is_empty():
				var ci: Image = cap.get_image()
				ci.decompress()
				for xx in ci.get_width():
					var ng := 0
					for yy in range(14, 28):
						var c := ci.get_pixel(xx, yy)
						if c.a > 0.5 and c.g > c.r + 0.03: ng += 1
					capgreen.append(ng >= 3)
				var cwi := ci.get_width()
				var last := 0
				for xx in cwi:
					if capgreen[xx]: last = xx
					else: break
				for zc in CLEAR:
					lip_ends.append(zc[0] - cwi / 2.0 + last)
					lip_ends.append(zc[1] + cwi / 2.0 - last)
			for xx in int(cw):
				var col: int = xx if side == 0 else int(cw) - 1 - xx
				if not capgreen[col]: continue
				var wx: float = x0 + xx
				var d := roundf((3.0 + 6.0 * _vnoise(wx / 11.0) + 2.0 * _vnoise(wx / 3.0 + 40.0)) * _lip_taper(wx))
				if d < 1.0: continue
				var yb: float = roundf(f.call(wx)) - RAISE
				gc.draw_rect(Rect2(wx, yb + LIPY, 1.0, d), LIPC)
				gc.draw_rect(Rect2(wx, yb + LIPY + d, 1.0, 1.0), LIPC2)

func _spr(k: String, x: float, y_bottom: float, sink := 0.0, flip := false, ci: CanvasItem = null, xf := Transform2D.IDENTITY) -> void:
	if not tex.has(k): return
	if ci == null: ci = self
	var im: Texture2D = tex[k]
	var s := ks(k)
	var w := im.get_width() * s
	var h := im.get_height() * s
	if hx.has(k):
		im = hx[k]
		w = im.get_width()
		h = im.get_height()
	var y := y_bottom - h + sink * PK * s
	if flip:
		ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2(roundf(x) + w, 0)))
		ci.draw_texture_rect(im, Rect2(0, y, w, h), false)
		ci.draw_set_transform(Vector2.ZERO)
	elif xf != Transform2D.IDENTITY:
		ci.draw_set_transform_matrix(xf)
		ci.draw_texture_rect(im, Rect2(roundf(x), y, w, h), false)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(im, Rect2(roundf(x), y, w, h), false)

## the ground: recess wall, floors, bands (static: the river is drawn with the scenery)
func _draw_ground() -> void:
	gci = ground_node
	var gn := ground_node
	g_vr = arena.view_rect().grow_individual(600.0, 200.0, 600.0, 200.0)
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
	gn.draw_colored_polygon(pts, Color.WHITE, uvs, t_wall)
	# 2. lower level: floor + valley, river
	_shear(t_solid, RX1, RIV0, func(_x): return LOWF)
	_shear(t_solid, RIV1, TOWN_W + PK, func(_x): return LOWF)
	# 3. lower plaza: light strings, fountain
	var L: Texture2D = tex["q_lights"]
	for s in light_strings:
		var yy: float = up_y((s[0] + s[1]) / 2.0) + BAND - 10.0
		gn.draw_texture_rect(L, Rect2(s[0], yy, s[1] - s[0], L.get_height()), false)
	_spr("q_fountain", HDOOR - 52.0 * PK * BS, LOWF, 0.0, false, gn)
	# 4. upper bands, west street, ramp
	_shear(t_solid, -PK, SX0, func(_x): return G)
	_shear(t_band, SX0, STX1 + SL, up_y)
	_shear(t_solid, STX1 - 40.0, STX1 + SL + 40.0, func(_x): return LOWF)
	_shear(t_solid, SX0, RX1, ramp_y)

func _draw() -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	# the river: pixelfx water/town-river (tools/pixelfx_fx/town-river.js), 120 frames 240x96 at 10 fps, exactly the
	# river's width; deeper down its darkest step; the bridge deck's shadow lies on the water just under it
	var rfi := int(tt * 10.0) % 120
	draw_texture_rect_region(RIVER, Rect2(RIV0, LOWF + 18.0, 240.0, 96.0), Rect2((rfi % 7) * 240, (rfi / 7) * 96, 240, 96))
	draw_rect(Rect2(RIV0, LOWF + 114.0, RIV1 - RIV0, 700.0), Color("#05222b"))
	draw_rect(Rect2(RIV0, LOWF + 18.0, RIV1 - RIV0, 5.0), Color(0.05, 0.1, 0.18, 0.35))
	# 5. trees, buildings, the hall, props, lamps, bridge
	var vr0: Rect2 = arena.view_rect().grow(60.0)
	for i in deco_back.size():
		var d: Array = deco_back[i]
		var dk: String = d[0]
		if dk.contains("tree"): _tree(dk, d[1], d[2], d[3], d[4], d[5], d[1] * 0.003, vr0)
		else: _sway(dk, d[1], d[2], d[3], d[4], d[5] * (1.0 + life.rust.get(i, 0.0) * 4.0), d[1] * 0.003, vr0)
	for r in rocks:
		if tex.has(r[0]) and r[1] < vr0.end.x and r[1] + 120.0 > vr0.position.x: _spr(r[0], r[1], r[2] + 2.0)
	for b in bld:
		if b[0] == "g_anvil": continue
		if b[0] == "g_wagon":
			_draw_wagon(b)
			continue
		if b[0] == "g_tentR": fxa.draw_tent(self, b)
		else: _spr(b[0], b[1], b[2], b[3], b.size() > 7 and b[7])
	fxa.draw_world(self)
	_spr("g_hall", HXB, TTOP, 1.0)
	var fp := HM(HX2 + 162.0 * PK, HTOP2 + 6.0 * PK)
	_flag(fp.x, fp.y, 1.75 * BS)
	_draw_props(self, false)
	for d in deco_front:
		_ground_shadow(d[0], d[1], d[2])
		_sway(d[0], d[1], d[2], 0.0, d[4], d[5], d[1] * 0.003, vr0)
	var E = arena.eil
	if E.map == "town" and not E.hide:
		var vr: Rect2 = arena.view_rect()
		if E.x > vr.position.x - 200.0 and E.x < vr.end.x + 200.0:
			E.y = floor_at(E.x)
			E.draw_on(self, roundf(E.x), roundf(E.y))
	_spr("q_bridge", RIV0 - 38.0, LOWF + 28.0)
	bran.draw(self)
	# campfire: pixelfx fire/town-campfire (tools/pixelfx_fx/town-campfire.js: the flames, smoke and sparks only — the stones
	# and logs are the town art's), 90 frames at 30 fps, owner 2026-11-06
	var fxx := 4350.0 + 27.0 * PK
	var cfi := int(tt * 30.0) % 90
	# the flames start at the top of the log teepee (g_ring's apex at 54,1; the ring sits at G - 55), as a log fire does
	draw_texture_rect_region(CAMPFIRE, Rect2(roundf(fxx - 64.0), roundf(G - 47.0 - 112.0), 128, 128), Rect2((cfi % 10) * 128, (cfi / 10) * 128, 128, 128))
	if not _is_near(deco_props[2][1], deco_props[2][2]): life.draw_cat(self)    # the cat sleeps on deco_props[2]

## crates, barrels, benches, pots and lamps: the ones whose foot is on the stand line here, the nearer ones on near_node
func _is_near(x: float, y: float) -> bool:
	return y > floor_at(x) + 0.5

func _draw_near() -> void:
	_draw_props(near_node, true)

func _draw_props(ci: CanvasItem, near: bool) -> void:
	var vr0: Rect2 = arena.view_rect().grow(60.0)
	var tms := float(Time.get_ticks_msec())
	for i in deco_props.size():
		var d: Array = deco_props[i]
		if _is_near(d[1], d[2]) != near: continue
		var j: float = life.jig.get(i, 0.0)
		var xf := Transform2D.IDENTITY
		if j > 0.02:
			# struck: it rocks and hops
			var cx: float = d[1] + tex[d[0]].get_width() * ks(d[0]) / 2.0
			var c := Vector2(cx, d[2])
			xf = Transform2D(sin(tms / 28.0) * 0.08 * j, c) * Transform2D(0.0, -c - Vector2(0, absf(sin(tms / 60.0)) * 6.0 * j))
		_spr(d[0], d[1], d[2], 0.0, d.size() > 3 and d[3], ci, xf)
	for lp in lamps:
		if _is_near(lp[0], lp[1]) != near: continue
		_lamp(lp[0] - 28.0 * PK, lp[1], vr0, ci)
	if near and _is_near(deco_props[2][1], deco_props[2][2]): life.draw_cat(ci)   # on its crate, as near as the crate

## the grass blades (GPU, shaders/grass_blades.gdshader): only the chunks in view
func _draw_blade_meshes(ci: CanvasItem, which: String) -> void:
	if bmesh.is_empty():
		var fg: Callable = func(_x): return G
		var fl: Callable = func(_x): return LOWF
		bmesh = life.build_blade_meshes([[-PK, SX0, fg], [SX0, STX1 + SL, up_y], [SX0, RX1, ramp_y], [RX1, RIV0, fl], [RIV1, TOWN_W + PK, fl]])
	var vr: Rect2 = arena.view_rect()
	for c in bmesh[which]:
		if c[1] < vr.position.x or c[0] > vr.end.x: continue
		ci.draw_mesh(c[2], null)

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
				fxa.draw_leaf(front, f, minf(1.0, (1.0 - k) * 3.0))
			"drop":
				front.draw_rect(Rect2(roundf(f["x"]), roundf(f["y"]), PK, PK), Color(0.75, 0.9, 1.0, 0.95))
			"spark":
				front.draw_rect(Rect2(roundf(f["x"] / PK) * PK, roundf(f["y"] / PK) * PK, PK, PK), Color(Color("#fde7a2") if k < 0.5 else Color("#ea7a26"), 1.0 - k))
	fxa.draw_front(front)
	# the river in front of whoever wades it: the top rows of the water again, see-through, the waterline solid, so a
	# body in the river is under the surface from the waist down (the bridge piers too)
	var rfi2 := int(Time.get_ticks_msec() / 1000.0 * 10.0) % 120
	front.draw_texture_rect_region(RIVER, Rect2(RIV0, LOWF + 20.0, 240.0, 44.0), Rect2((rfi2 % 7) * 240, (rfi2 / 7) * 96 + 2, 240, 44), Color(1, 1, 1, 0.55))
	front.draw_texture_rect_region(RIVER, Rect2(RIV0, LOWF + 18.0, 240.0, 2.0), Rect2((rfi2 % 7) * 240, (rfi2 / 7) * 96, 240, 2))
	fxa.draw_water(front)
	fxa.draw_bits(front)
	life.draw_front(front)
	if arena.eil.map == "town": arena.eil.draw_say(front, floor_at(arena.eil.x))
	# door labels and the prompt
	var fnt: Font = arena.font_black
	var tt := Time.get_ticks_msec() / 1000.0
	if near_door != null and not near_door.get("hide", false):
		var d = near_door
		# KH() + the name (+ 입장 for a way in): "X " on keyboard, "Ⓧ " on a pad, nothing on touch
		var s2: String = arena.cfg.kh() + String(d["name"]) + (" 입장" if String(d.get("to", "")) != "" else "")
		var tw := maxf(140.0, fnt.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24.0)
		var y2: float = d["y"] - 150.0 + sin(tt * 4.0) * 3.0
		front.draw_rect(Rect2(d["x"] - tw / 2.0, y2 - 16.0, tw, 24.0), Color(0, 0, 0, 0.55))
		var sw2 := fnt.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		front.draw_string(fnt, Vector2(d["x"] - sw2 / 2.0, y2), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffe9a8") if String(d.get("to", "")) != "" else Color("#cfd6e6"))

func _front_shear(x0: float, x1: float, f: Callable) -> void:
	if not g2.is_empty(): return
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


# ---------- living sprites ----------
## tree: the trunk stays, the canopy bends as one soft mass in 2 px rows (the top moves most)
func _tree(k: String, x: float, y_bottom: float, sink: float, flip: bool, amp: float, ph: float, vr: Rect2) -> void:
	if tex.has(k + "_sway"):
		# leaf balls rippling in 1-px steps, baked (tools/make_tree_sway.py): 24 frames 6 wide, 0.1 s each, quicker in a gust
		var sw: Texture2D = tex[k + "_sway"]
		var fw := float(sw.get_width() / 6)
		var fh := float(sw.get_height() / 4)
		x = roundf(x)
		if x > vr.end.x or x + fw < vr.position.x or y_bottom - fh > vr.end.y or y_bottom < vr.position.y: return
		sway_t[k + str(x)] = sway_t.get(k + str(x), ph * 7.0) + get_process_delta_time() * (1.0 + life.gust * 1.5) / 0.1
		var fi: int = int(sway_t[k + str(x)]) % 24
		draw_set_transform(Vector2(x + (fw if flip else 0.0), y_bottom), 0.0, Vector2(-1.0 if flip else 1.0, 1.0))
		draw_texture_rect_region(sw, Rect2(0, -fh + sink * PK, fw, fh), Rect2((fi % 6) * fw, (fi / 6) * fh, fw, fh))
		draw_set_transform(Vector2.ZERO)
		return
	var trunk: Texture2D = tex[k + "_trunk"]
	var leaf: Texture2D = tex[k + "_leaf"]
	var s := ks(k)
	var rk := 1.0                     # texel rows per original row
	var sk := sink * PK
	if hx.has(k + "_trunk"):
		trunk = hx[k + "_trunk"]
		leaf = hx[k + "_leaf"]
		rk = s
		sk *= s
		s = 1.0
	var w := float(trunk.get_width())
	var h := float(trunk.get_height())
	x = roundf(x)
	if x > vr.end.x or x + w * s < vr.position.x or y_bottom - h * s > vr.end.y or y_bottom < vr.position.y: return
	var t := Time.get_ticks_msec() / 1000.0
	var g: float = 0.5 + life.gust * 1.1
	var lean := (sin(t * 0.9 + ph) * 0.6 + sin(t * 0.37 + ph * 2.0) * 0.4) * amp * 1.6 * g
	var rows: Array = TREE_ROWS[k]
	var top: int = roundi(rows[0] * rk)
	var bot: int = mini(roundi(rows[1] * rk), int(h) - 1)
	var span := maxf(1.0, bot - top)
	var y0 := -h + sk
	draw_set_transform(Vector2(x + (w * s if flip else 0.0), y_bottom), 0.0, Vector2(-s if flip else s, s))
	draw_texture(trunk, Vector2(0, y0))
	var r := top
	while r <= bot:
		var u := 1.0 - (r - top) / span
		var o := roundf((lean * u * u + sin(t * 2.6 + ph + r * 0.07) * 0.6 * u * g) / 2.0) * 2.0
		var rh := minf(2.0, h - r)
		draw_texture_rect_region(leaf, Rect2(o, y0 + r, w, rh), Rect2(0, r, w, rh))
		r += 2
	draw_set_transform(Vector2.ZERO)


## contact shadow on the plane under a piece: the ground one step darker in a flat oval
func _ground_shadow(k: String, x: float, y: float) -> void:
	var w: float = tex[k].get_width()
	var cx := roundf(x + w / 2.0)
	var rx := roundf(w * 0.42)
	draw_rect(Rect2(cx - rx + 2.0, y - 1.0, rx * 2.0 - 4.0, 1.0), Color(0.05, 0.09, 0.05, 0.28))
	draw_rect(Rect2(cx - rx, y, rx * 2.0, 1.0), Color(0.05, 0.09, 0.05, 0.28))
	draw_rect(Rect2(cx - rx + 3.0, y + 1.0, rx * 2.0 - 6.0, 1.0), Color(0.05, 0.09, 0.05, 0.2))

## bush / grass clump: rows shear with the wind, the bottom 28% stays planted
func _sway(k: String, x: float, y_bottom: float, sink: float, flip: bool, amp: float, ph: float, vr: Rect2) -> void:
	var im: Texture2D = tex[k]
	var s := ks(k)
	var sk := sink * PK
	if hx.has(k):
		im = hx[k]
		sk *= s
		s = 1.0
	var w := float(im.get_width())
	var h := float(im.get_height())
	x = roundf(x)
	if x > vr.end.x or x + w * s < vr.position.x or y_bottom - h * s > vr.end.y or y_bottom < vr.position.y: return
	var t := Time.get_ticks_msec() / 1000.0
	var g: float = 0.6 + life.gust * 0.8
	var cut := floorf(h * 0.72)
	var y0 := -h + sk
	draw_set_transform(Vector2(x + (w * s if flip else 0.0), y_bottom), 0.0, Vector2(-s if flip else s, s))
	var r := 0.0
	while r < h:
		var u := maxf(0.0, 1.0 - r / cut)
		var o := roundf((sin(t * 1.6 + ph + r * 0.06) * amp * u * g + sin(t * 0.55 + ph) * amp * 0.5 * u) * PK) if r < cut else 0.0
		var rh := minf(2.0, h - r)
		draw_texture_rect_region(im, Rect2(o, y0 + r, w, rh), Rect2(0, r, w, rh))
		r += 2.0
	draw_set_transform(Vector2.ZERO)

## street lamp: the banner under the arm flutters, more in a gust
func _lamp(x: float, surf: float, vr: Rect2, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	var base: Texture2D = tex["q_lamp_base"]
	var ban: Texture2D = tex["q_lamp_ban"]
	x = roundf(x)
	if x > vr.end.x or x + base.get_width() < vr.position.x: return
	var y := roundf(surf - base.get_height())
	ci.draw_texture(base, Vector2(x, y))
	var t := Time.get_ticks_msec() / 1000.0
	var bh := float(ban.get_height())
	var r := 0.0
	while r < bh:
		var u := r / bh
		var o := roundf((sin(t * 2.4 - r * 0.09 + x * 0.01) * 1.6 + sin(t * 0.9 + x) * 1.2) * u * (0.5 + life.gust * 1.4))
		ci.draw_texture_rect_region(ban, Rect2(x + LAMP_BAN.x + o, y + LAMP_BAN.y + r, ban.get_width(), minf(2.0, bh - r)), Rect2(0, r, ban.get_width(), minf(2.0, bh - r)))
		r += 2.0

## pennant on the hall's pole: pixel columns riding a travelling sine; limp when the wind drops
func _flag(px: float, py: float, k: float) -> void:
	var vr: Rect2 = arena.view_rect()
	if px > vr.end.x + 40.0 or px + 40.0 < vr.position.x: return
	var w: float = 0.25 + minf(1.3, life.gust) * 0.9
	var t := Time.get_ticks_msec() / 1000.0
	var N := 13
	for c in N:
		var u := c / (N - 1.0)
		var hh := maxf(2.0, roundf(11.0 * (1.0 - u * 0.75)))
		var droop := (1.0 - w) * u * 6.0
		var off := roundf(sin(t * (4.0 + w * 6.0) - c * 0.55) * (0.6 + w * 2.2) * u + droop)
		var cx := roundf(px + c * k * (0.75 + w * 0.25))
		var cy := roundf(py + off * k)
		draw_rect(Rect2(cx, cy, ceilf(k), roundf(hh * k)), Color("#486e7c"))
		draw_rect(Rect2(cx, cy, ceilf(k), roundf(maxf(1.0, hh * 0.45) * k)), Color("#6a96a4"))
		draw_rect(Rect2(cx, roundf(cy + (hh - 1.0) * k), ceilf(k), ceilf(k)), Color("#2e4a58"))

## the wagon's horse lives: grazes, tosses its head, looks about, swishes its tail, now and then lies down and sleeps
func _horse_step(dt: float) -> void:
	var H := horse
	H["t"] += dt
	H["next"] -= dt
	H["st_t"] += dt
	var st: String = H["st"]
	if st == "down":
		H["frame"] = [1, 2, 3][mini(2, int(H["st_t"] / 300.0))]
		if H["st_t"] >= 900.0:
			H["st"] = "lie"
			H["st_t"] = 0.0
			H["next"] = 6000.0 + randf() * 8000.0
	elif st == "up":
		H["frame"] = [5, 6, 7][mini(2, int(H["st_t"] / 280.0))]
		if H["st_t"] >= 840.0:
			H["st"] = "idle"
			H["st_t"] = 0.0
			H["frame"] = 0
			H["next"] = 3000.0 + randf() * 3000.0
	elif st == "lie" or st == "sleep":
		H["frame"] = 4 if st == "sleep" else 3
		if H["next"] <= 0.0:
			if st == "lie" and randf() < 0.6:
				H["st"] = "sleep"
				H["next"] = 5000.0 + randf() * 6000.0
			elif st == "sleep":
				H["st"] = "lie"
				H["next"] = 2500.0 + randf() * 3000.0
				H["wake"] = true
			else:
				H["st"] = "up"
				H["st_t"] = 0.0
		if H["st"] == "lie" and H["wake"] and H["next"] <= 0.0:
			H["wake"] = false
			H["st"] = "up"
			H["st_t"] = 0.0
	else:
		H["frame"] = 0
		if H["next"] <= 0.0:
			var r := randf()
			if st == "graze": H["st"] = "graze" if r < 0.35 else ("toss" if r < 0.55 else "idle")
			else: H["st"] = "graze" if r < 0.4 else ("toss" if r < 0.55 else ("look" if r < 0.7 else ("down" if r < 0.85 else "idle")))
			H["st_t"] = 0.0
			match H["st"]:
				"graze": H["next"] = 3500.0 + randf() * 4000.0
				"toss": H["next"] = 900.0
				"look": H["next"] = 2200.0
				_: H["next"] = 2500.0 + randf() * 3000.0
	st = H["st"]
	var target := 0.0
	if st == "graze": target = 0.95
	elif st == "toss": target = -0.3 if H["st_t"] < 300.0 else 0.05
	elif st == "look": target = -0.15
	H["neck"] += (target - H["neck"]) * minf(1.0, dt * (0.012 if st == "toss" else 0.0032))
	if H["frame"] != 0: H["neck"] = 0.0
	H["chew"] = sin(H["t"] / 140.0) * 0.05 if st == "graze" and H["neck"] > 0.8 else 0.0
	H["tail"] = sin(H["t"] / 430.0) * 0.12 + sin(H["t"] / 170.0) * 0.05 * (1.0 if sin(H["t"] / 2300.0) > 0.6 else 0.0)

func _draw_wagon(b: Array) -> void:
	var W2: Texture2D = tex["g_wagon2"]
	var x := roundf(b[1])
	var vr: Rect2 = arena.view_rect()
	if x > vr.end.x + 20.0 or x + 480.0 < vr.position.x: return
	var wy := roundf(b[2] - W2.get_height() + b[3] * PK)
	draw_texture(W2, Vector2(x, wy))
	var H := horse
	var hx := x + HDX
	var hy := roundf(b[2] - HCH + 2.0)
	var breath := 1.0 if sin(H["t"] / 900.0) > 0.2 else 0.0
	var fr: int = H["frame"]
	if fr != 0:
		draw_texture_rect_region(tex["horse_strip"], Rect2(hx, hy + (breath if fr == 4 else 0.0), HCW, HCH), Rect2(fr * HCW, 0, HCW, HCH))
		return
	draw_set_transform(Vector2(hx, hy) + TAIL_PIV, -H["tail"], Vector2.ONE)
	draw_texture(tex["horse_tail"], -TAIL_PIV)
	draw_set_transform(Vector2.ZERO)
	draw_texture(tex["horse_base"], Vector2(hx, hy))
	draw_texture(tex["horse_root"], Vector2(hx, hy - breath))
	draw_set_transform(Vector2(hx, hy - breath) + NECK_PIV, H["neck"] + H["chew"], Vector2.ONE)
	draw_texture(tex["horse_neck"], -NECK_PIV)
	draw_set_transform(Vector2.ZERO)

## bubbles and fireflies (on the camera-following canvas that the ambient doesn't dim)
func _draw_labels() -> void:
	life.draw_flies(labels, light_tex)
	folk.draw_bubbles(labels, arena.font_bold)
	bran.draw_bubble(labels, arena.font_bold)
