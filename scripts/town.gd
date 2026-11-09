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
const HILL_ON := false         # the hall's slope picture as the recess face (false: the old dark dirt). Off (owner
# 2026-11-09: "일단 그 언덕 텍스쳐 넣은 거 빼자. 옆에 오르 내리막길이라던가 막 잘림")
const PLAZA_SUN := true        # the sun reaches the lower plaza (owner 2026-11-09: "빛을 언덕 아래로도 쏘자"), kept with the slope picture out
const HILL_FOOT := 4.0         # where the slope picture's last row sits, below the lower street's floor line
# the slopes (owner 2026-11-06 dropped the stone stairs: back to the long slopes)
const UPA := SX0                 # the slope up to the hall terrace: UPA..SX1
const DNB := EX1                 # the slope down from it: DX1..DNB
const RMA := SX0                 # the ramp down to the lower plaza: RMA..RX1
const LWA := STX1                # the slope down to the lower street: LWA..STX1+SL
const SURFR := 6.0
const PXK := 1.78
const CAMPFIRE := preload("res://assets/fx/town/campfire.png")
const CAMP_APEX := 24.0         # the crossed logs' top above the ground (pixel3d ring); the flames start there
const CAMP_UP := 14.0            # the campfire set back on the plane, behind the people (owner 2026-11-08: "모닥불 좀 밀고")
const RIVER := preload("res://assets/fx/town/river.png")
const LIFE := preload("res://scripts/town_life.gd")
const TFX := preload("res://scripts/town_fx.gd")
const TF := preload("res://scripts/townsfolk.gd")
const BRAN := preload("res://scripts/bran.gd")
const LIT := preload("res://scripts/lit.gd")
const SHADE := preload("res://scripts/shade.gd")
const SKY := preload("res://scripts/sky.gd")
## the hall facade's windows (g_hall_win px): they light up from 18:40 and before 06:20
# the pixel3d hall's windows (px in hx/g_hall_win.png, from its glass; owner 2026-11-08: "창문 빛")
const HALL_WIN3 := [[116, 476], [116, 386], [218, 386], [218, 478], [336, 325], [336, 479], [436, 185], [436, 325], [536, 324], [536, 479], [654, 384], [654, 478], [756, 386], [756, 478]]
const HALL_WIN := [[87, 359], [93, 289], [169, 287], [169, 369], [247, 235], [253, 365], [323, 129], [327, 233], [389, 359], [401, 235], [489, 369], [495, 287], [561, 289], [563, 359]]
## leaf rows of the canopies (baked by splitting each tree by the prototype's colour rule: g >= r*0.85 and g > b*1.3)
const TREE_ROWS := {"f_tree2": [2, 247], "f_tree3": [2, 247], "f_bigtree": [2, 307],
	"f_oak": [0, 276], "f_round": [0, 251], "f_young": [0, 195], "f_tall": [0, 281]}   # tools/make_town_trees.py, drawn 1:1
const LAMP_BAN := Vector2(34, 102)    # where the lamp's banner (hx/q_lamp_ban, pixel3d) sits on hx/q_lamp_base
## the wagon's horse (horse_strip: 8 cells of 214x184, 2-px grid, 2026-11-06 redraw; frame 0 is cut into base / neck / tail / neck root)
const HCW := 214
const HCH := 184
const HDX := 210.0                   # the horse at the new wagon's shaft (g_wagon2 280 wide, horse 2026-11-06)
const NECK_PIV := Vector2(128, 60)
const TAIL_PIV := Vector2(28, 62)
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
var hx := {}
## the pixel3d buildings stand ON the floor (owner 2026-11-07: "밑바닥 기준을 바닥 면적으로 삼아야지"): set down this many
## px so the front of the footprint lies inside the ground band, not on its back edge
## P3D[k] = [the sky rows above the reference's row 0 in px (FX anchored on the old sprite add it), set-down px]
## (tools/export_pixel3d.py prints both; the set-down also covers the rows the render reaches below the reference;
## the tents' pegs and the kiln's front are kept on/behind the stand line, owner 2026-11-08: "너무 앞으로 나와있음")
const P3D := {"g_hall": [0.0, 0.0], "g_forge": [32.0, 14.0], "g_barn": [20.0, 14.0], "g_store": [20.0, 16.0],
	"g_tentR": [48.0, 10.0], "g_tentL": [48.0, 10.0], "g_kiln": [16.0, 14.0], "q_fountain": [12.0, 14.0],
	"g_cottage": [20.0, 14.0], "g_well": [16.0, 14.0],
	# the props, rebuilt on the 2-px grid (owner 2026-11-08: "2px 칸으로 다시 짓기" / "넣자")
	"q_barrelL": [4.0, 14.0], "q_barrelM": [4.0, 14.0], "q_barrelS": [4.0, 14.0], "q_crateL": [4.0, 14.0], "q_crateS": [4.0, 14.0],
	"q_bench": [4.0, 14.0], "q_benchL": [4.0, 14.0], "q_board": [6.0, 14.0], "q_planter": [6.0, 14.0], "q_planterL": [6.0, 14.0],
	"q_pot": [4.0, 14.0], "g_ring": [2.0, 16.0], "g_yard": [4.0, 14.0], "g_wagon2": [16.0, 16.0],
	"q_lamp_base": [4.0, 16.0], "q_bridge": [8.0, 14.0], "q_lights": [2.0, 14.0]}
## where the base of a pixel3d building meets the ground plane, px below the stand line (the P3D set-downs above are
## for 14); the plane's back edge is RAISE above the stand line (owner 2026-11-08: buildings behind the people, on the plane)
var FOOT := 0.0
func setdown(k: String) -> float:
	if k == "g_hall": return 8.0          # the hall on its own plinth on the terrace paving, a little forward (owner 2026-11-08)
	return float(P3D[k][1]) - 14.0 + FOOT if P3D.has(k) else 0.0
var sh_tex := {}
## the pixel3d ground shadows (shadow/) are baked into the ground light maps (tools/bake_ground_light.py, from
## tests/dump_light_layout.gd), shaded there on the palette - not laid over as a translucent colour
const SH_IN_MAP := true
## the pixel3d sprites' normal maps (assets/town/nrm): the lamps light them live (shaders/char_pix.gdshader pl_*)
var nrm := {}
var ct_cache := {}
func lit_ct(k: String, im: Texture2D) -> Texture2D:
	if not nrm.has(k): return im
	var id := im.get_instance_id()
	if not ct_cache.has(id):
		var ct := CanvasTexture.new()
		ct.diffuse_texture = im
		ct.normal_texture = nrm[k]
		ct_cache[id] = ct
	return ct_cache[id]
func _lamp_uniforms(L: Array, T: Dictionary) -> void:
	var nk := clampf((T["sky"].a - 0.33) / 0.33, 0.0, 1.0)
	var vr: Rect2 = arena.view_rect().grow(300.0)
	var arr: Array = []
	if nk > 0.02:
		for l in L:
			if not (l["k"] in ["lamp", "fire", "bulb"]): continue
			if not vr.has_point(Vector2(l["x"], l["y"])): continue
			arr.append(Vector4(l["x"], l["y"], float(l["r"]) * (1.7 if l["k"] != "bulb" else 1.2), float(l["a"]) * nk))
			if arr.size() >= 12: break
	var n := arr.size()
	while arr.size() < 12: arr.append(Vector4.ZERO)
	for m in [material, near_node.material if near_node != null else null]:
		if not (m is ShaderMaterial): continue
		m.set_shader_parameter("pl_n", n)
		m.set_shader_parameter("pl_a", arr)
		m.set_shader_parameter("pal_lut", load("res://assets/town/light/pal_lut.png"))
		m.set_shader_parameter("pal_fx", load("res://assets/town/light/pal_fx.png"))
## the lamps' light with its shadows (tools/bake_ground_light.py: ground_n blue, traced past the pixel3d outlines)
## eases the night's dark where it reaches, so the sprites' own lamp-lit faces and rims (the per-placement night
## renders), the ground's warm and the people near a lamp show; gently (owner 2026-11-08: not a glare)
func _light_uniforms(T: Dictionary) -> void:
	var m = lit.amb_node.material
	if not (m is ShaderMaterial) or not gmaps.has("n"): return
	lit.glow_soft = false
	m.set_shader_parameter("gmap", gmaps["n"])
	m.set_shader_parameter("lift", clampf((T["sky"].a - 0.33) / 0.33, 0.0, 1.0))
	glass_on = T["lamp"] > 0.3
	var gr: Array = glass_r.duplicate()
	glass_r.clear()
	m.set_shader_parameter("glass_n", gr.size())
	while gr.size() < 8: gr.append(Vector4.ZERO)
	m.set_shader_parameter("glass", gr)
var sh_log = null                    # dump_light_layout: {key@x: [shadow key, canvas x, canvas y]} of what was drawn
var sh_seen := {}                     # every pixel3d ground shadow placed: key@x -> [shadow key, canvas x, canvas y]
var sh_img := {}                      # their masks on the CPU (baked_shadow_at)
## how far left of the usual place (x - 24) a shadow canvas starts: widened so a low sun's shadow is whole
## (data/shadow_pad.json, tools/export_p3d_shadow.py; owner 2026-11-09 "그림자 작업해야지 그래")
var sh_pad := {}
func _sh_pad(k: String) -> float:
	if sh_pad.is_empty():
		sh_pad["_"] = 0
		var f := FileAccess.open("res://data/shadow_pad.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary: sh_pad.merge(d)
	return float(sh_pad.get(k, 0))
func sh_place(k: String, x: float, y: float, ci: CanvasItem) -> void:
	if sh_log != null: sh_log[k + "@" + str(roundf(x))] = [k, roundf(x) - 24.0, y]
	sh_seen[k + "@" + str(roundf(x))] = [k, roundf(x) - 24.0 - _sh_pad(k), y]
	if SH_IN_MAP: return
	var lv := sun_side()
	if sh_tex.has(k + lv):
		var st: Texture2D = sh_tex[k + lv]
		ci.draw_texture_rect(st, Rect2(roundf(x) - 24.0 - _sh_pad(k), y, st.get_width(), st.get_height()), false)                 # baked ground shadows under the pixel3d buildings: "<k>" / "<k>_m" / "<k>_e" (tools/pixel3d)
## how deep the buildings' baked ground shadow is at a point (0..1): what stands there is in it too (owner
## 2026-11-08: "물체끼리 드리우는 그림자" - a barrel or a person in the hall's shadow is shaded, shade.gd)
func baked_shadow_at(p: Vector2) -> float:
	var lv := sun_side()
	if lv == "_n": return 0.0
	for e in sh_seen.values():
		var key: String = e[0] + lv
		if not sh_tex.has(key): continue
		var t: Texture2D = sh_tex[key]
		var q := p - Vector2(e[1], e[2])
		if q.x < 0.0 or q.y < 0.0 or q.x >= t.get_width() or q.y >= t.get_height(): continue
		if not sh_img.has(key):
			var im: Image = t.get_image()
			if im.is_compressed(): im.decompress()
			sh_img[key] = im
		var a: float = sh_img[key].get_pixel(int(q.x), int(q.y)).a
		if a > 0.0: return a
	return 0.0
var lit_tex := {}                # sun-side versions: "<k>_m" / "<k>_e"                     # pre-scaled (BS) textures, drawn 1:1
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
var mirror_mat: ShaderMaterial
var mirror_node: Node2D
var near_grass: Node2D
const NEAR_GRASS := preload("res://assets/town/near_grass.png")
var mirror_bb: BackBufferCopy
var tuft_mat: ShaderMaterial
var tuft_node: Node2D
var tufts: Array = []                 # town_life.build_tufts: [x, base y, kind, flip]
var tuft_tex := {}                    # kind -> [sway strip, frame width, height]
const TUFT_LEANS := -2                # the first frame's lean (tools/bake_grass_sway.py LEANS = -2..4)
var gci: CanvasItem              # what _shear draws on (the ground node)
var ground_mat: ShaderMaterial
var gmaps := {}
var gmap_now := ""
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
	for k in ["g_tentL", "q_benchL", "q_planterL", "bg_range_far", "bg_range_mid", "bg_range_near", "bg_wood", "bg_hills"]:   # pixel3d mirrored solids, far ranges
		hx[k] = load("res://assets/town/hx/" + k + ".png")
	# the sun-side versions (tools/bake_sun_light.py): <k>_m = sun from the left (morning), <k>_e = from the right
	for f in DirAccess.get_files_at("res://assets/town/nrm"):
		var nk2 := f.replace(".import", "").get_basename()
		if not nrm.has(nk2): nrm[nk2] = load("res://assets/town/nrm/" + nk2 + ".png")
	for f in DirAccess.get_files_at("res://assets/town/shadow"):
		var sk := f.replace(".import", "").get_basename()
		if not sh_tex.has(sk): sh_tex[sk] = load("res://assets/town/shadow/" + sk + ".png")
	for f in DirAccess.get_files_at("res://assets/town/lit"):
		var lk := f.replace(".import", "").get_basename()
		if not lit_tex.has(lk): lit_tex[lk] = load("res://assets/town/lit/" + lk + ".png")
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
	# light and shade on the ground from what stands around it (tools/bake_ground_light.py, owner 2026-11-07)
	if ResourceLoader.exists("res://assets/town/light/pal_lut.png"):
		ground_mat = ShaderMaterial.new()
		ground_mat.shader = preload("res://shaders/ground_lit.gdshader")
		ground_mat.set_shader_parameter("pal_lut", load("res://assets/town/light/pal_lut.png"))
		ground_mat.set_shader_parameter("pal_fx", load("res://assets/town/light/pal_fx.png"))
		for t in ["d", "m", "e", "n"]: gmaps[t] = load("res://assets/town/light/ground_" + t + ".png")
		ground_mat.set_shader_parameter("gmap_cell", Vector2(2.0, 2.0))     # tools/bake_ground_light.py CX, CY
		ground_node.material = ground_mat
	blade_mat = ShaderMaterial.new()
	blade_mat.shader = preload("res://shaders/grass_blades.gdshader")
	blade_back = Node2D.new()
	blade_back.z_index = -6
	blade_back.material = blade_mat
	blade_back.draw.connect(func(): _draw_blade_meshes(blade_back, "back"))
	arena.add_child(blade_back)
	tuft_mat = ShaderMaterial.new()
	tuft_mat.shader = preload("res://shaders/grass_tuft.gdshader")
	tuft_node = Node2D.new()
	tuft_node.z_index = -6
	tuft_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tuft_node.material = tuft_mat
	tuft_node.draw.connect(_draw_tufts)
	arena.add_child(tuft_node)
	blade_front = Node2D.new()
	blade_front.z_index = 8
	blade_front.material = blade_mat
	blade_front.draw.connect(func(): _draw_blade_meshes(blade_front, "front"))
	arena.add_child(blade_front)
	if arena.dbg.has("nograss"):
		blade_back.visible = false
		blade_front.visible = false
		tuft_node.visible = false
	if arena.dbg.has("nolit"):
		lit.visible = false
		if shade.get("sv") != null: shade.sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# the river as a mirror (owner 2026-11-08: "물에 미러효과 넣고 이런식으로"): over everything but the light and the
	# front layer, so the people on the bank and the bridge show in it too
	mirror_bb = BackBufferCopy.new()
	mirror_bb.copy_mode = BackBufferCopy.COPY_MODE_RECT
	mirror_bb.rect = Rect2(RIV0 - 420.0, LOWF - 400.0, RIV1 - RIV0 + 840.0, 820.0)     # the water and what it mirrors
	mirror_bb.z_index = 7
	arena.add_child(mirror_bb)
	mirror_mat = ShaderMaterial.new()
	mirror_mat.shader = preload("res://shaders/water_mirror.gdshader")
	mirror_mat.set_shader_parameter("wl", LOWF + 20.0)
	mirror_node = Node2D.new()
	mirror_node.z_index = 7
	mirror_node.material = mirror_mat
	mirror_node.draw.connect(func(): mirror_node.draw_colored_polygon(river_poly(), Color.WHITE))
	arena.add_child(mirror_node)
	front = Node2D.new()
	front.z_index = 8
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.draw.connect(_draw_front)
	arena.add_child(front)
	# props whose foot is set lower on the plane than the people's stand line are nearer the camera: drawn over the
	# people (owner 2026-11-06: depth). z 1: over the player (0), under the grass blades in front (8) and the light (9)
	near_node = Node2D.new()
	near_node.z_index = 1
	near_node.material = material          # the same shader: the lamps light the near props too
	near_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	near_node.draw.connect(_draw_near)
	arena.add_child(near_node)
	# the near grass along the bottom of the screen (owner 2026-11-09, sketch 5): in front of everything but the light
	near_grass = Node2D.new()
	near_grass.z_index = 8
	near_grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	near_grass.draw.connect(_draw_near_grass)
	arena.add_child(near_grass)
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
	tuft_node.queue_free()
	mirror_node.queue_free()
	near_grass.queue_free()
	mirror_bb.queue_free()
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
		["g_ring", 4350.0, G - CAMP_UP, 0, null], ["g_tentR", 4490.0, G, 2, null],
		["g_wagon", 4820.0, G, 0, 287.0, "출격 마차", "dungeon"], ["g_well", 5281.0, G, 0, null], ["g_barn", 5600.0, G, 0, 230.0, "헛간", ""],
		["g_cottage", 6629.0, LOWF, 0, 140.0, "목욕집", ""], ["g_forge", 7269.0, LOWF, 0, 373.0, "대장간", "forge"], ["g_anvil", 7695.0, LOWF, 0, null], ["g_kiln", 7883.0, LOWF, 0, 113.0, "숯가마", ""]]
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
		["f_round", 1560.0, G, 4.5, true, 1.3], ["f_bush2", 1740.0, G, 0, false, 0.8], ["f_bush1", 3930.0, floor_at(3990.0), 0, true, 0.8], ["f_tall", 5440.0, G, 4.5, false, 1.4], ["f_grass1", 6040.0, G, 0, true, 0.6],
		["f_grass2", 8620.0, LOWF, 0, false, 0.6], ["f_bush3", 8620.0, LOWF, 0, false, 0.8], ["f_bigtree", 8609.0, LOWF, 0, false, 2.2], ["f_bush1", 9250.0, LOWF, 0, true, 0.8]]
	for d in deco_back:
		if BIGK.has(d[0]):
			var w2: float = tex[d[0]].get_width()
			d[1] = d[1] + w2 / 2.0 - w2 * BS / 2.0
	# nature on the ground plane (owner 2026-11-06): one palette with the ground, no outlines; the old bushes become the
	# old bushes kept (owner: the code-drawn shrub did not fit); small clusters at doors and trees, set at depths on the plane (y = stand line + d), calm stretches between
	if tex.has("k_lawn_0"):
		for d in deco_back:
			if String(d[0]).begins_with("f_grass"): d[0] = ""      # the old grass sprites go too: the blades do that job
		deco_back = deco_back.filter(func(d): return d[0] != "")
		deco_back.sort_custom(func(p, q): return p[2] < q[2])
	deco_props = [["q_barrelL", 630.0, G], ["q_barrelS", 690.0, G], ["q_crateL", 1560.0, G], ["q_crateS", 1624.0, G],
		["q_barrelM", HX2 + 470.0, TTOP], ["q_barrelS", HX2 + 522.0, TTOP], ["q_crateL", HX2 + 120.0, TTOP],
		["q_board", 2600.0, LOWF], ["q_bench", HDOOR - 230.0, LOWF], ["q_bench", HDOOR + 84.0, LOWF, true], ["q_planter", HDOOR - 320.0, LOWF], ["q_planter", HDOOR + 238.0, LOWF, true],
		["q_pot", HDOOR - 140.0, LOWF], ["q_pot", HDOOR + 112.0, LOWF], ["q_barrelL", 3560.0, LOWF], ["q_barrelM", 3616.0, LOWF], ["q_crateL", 4400.0, LOWF], ["q_crateS", 4464.0, LOWF],
		["q_barrelL", 5000.0, LOWF], ["q_crateL", 5700.0, LOWF], ["q_barrelS", 5764.0, LOWF], ["q_barrelM", 8180.0, LOWF], ["q_crateS", 8235.0, LOWF]]
	# stones on the ground (owner 2026-11-06), cut from the map scene, 2-px grid: [piece, x, surface y]
	# only on level ground: a flat-bottomed stone on the slope's bend sat on it like a lid (owner 2026-11-07)
	rocks = [["f2_pebble", 1534.0, G + 9.0], ["f2_pebble", 5420.0, G + 12.0], ["f2_rock", 6080.0, G - 4.0],
		["f2_pebble", 7050.0, LOWF + 10.0], ["f2_pebble", 9180.0, LOWF + 13.0], ["f2_rock", 2446.0, TTOP + 4.0], ["f2_pebble", 2410.0, TTOP + 12.0]]
	lamps = [[SX1 + 40.0, TTOP], [DX1 - 40.0, TTOP], [HDOOR - 400.0, LOWF], [HDOOR + 380.0, LOWF], [4700.0, LOWF], [5600.0, LOWF], [1700.0, G]]
	light_strings = [[HDOOR - 420.0, HDOOR - 20.0], [HDOOR + 20.0, HDOOR + 420.0], [4250.0, 4650.0], [5250.0, 5650.0]]
	STONE.append([HDOOR - 420.0, HDOOR + 420.0])               # the hall's forecourt / the plaza under it: paved
	for b in bld:
		if b[0] == "g_yard": CLEAR.append([b[1] - 20.0, b[1] + tex["g_yard"].get_width() + 20.0])   # the whole training yard
	CLEAR.append([7305.0, 7685.0])                             # the forge yard
	# the slopes are grass (owner 2026-11-06: everywhere but the paths made dirt on purpose is grass, slopes too)
	CLEAR.append([6720.0, 6880.0])                             # the bath house door
	CLEAR.sort_custom(func(p, q): return p[0] < q[0])
	# crates, barrels, benches, pots and lamps step forward onto the plane like the people (buildings stay at its back)
	if tex.has("k_lawn_0"):
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
	# the hall's slope (owner 2026-11-09: "길드 본관 밑 근경은 안오는 게 자연스러워보이고 대신 밑 풀밭을 언덕처럼"): the
	# processed slope picture (tools/make_town_hill_nai.py, palette only) as the face between the upper walk and the lower
	# street, its foot on the lower street's floor; rows past its ends repeat its edge rows. Lit like the ground.
	if HILL_ON:
		var hi := (load("res://assets/town/k_hill.png") as Texture2D).get_image()
		hi.convert(Image.FORMAT_RGBA8)
		var hh := int(LOWF + 20.0 - G)
		var hw := hi.get_width()
		var him := Image.create(hw, hh, false, Image.FORMAT_RGBA8)
		var foot := int(LOWF + HILL_FOOT - G)          # the image row where the picture's last row lands
		for y in hh:
			var sy := clampi(hi.get_height() - 1 - (foot - y), 0, hi.get_height() - 1)
			him.blit_rect(hi, Rect2i(0, sy, hw, 1), Vector2i(0, y))
		t_wall = ImageTexture.create_from_image(him)


# ---------- climbable tops: one-way (sloped) surfaces traced from each placed sprite's top silhouette ----------
## first opaque row of every column, median-filtered over 13 columns (drops thin spikes: finials, poles)
func _top_profile(k: String) -> Dictionary:
	if prof_cache.has(k): return prof_cache[k]
	var img: Image = (hx[k] if P3D.has(k) and hx.has(k) else tex[k]).get_image()     # the pixel3d art's own outline
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
	if P3D.has(k) and hx.has(k):           # drawn 1:1 from hx, set down (as _spr)
		y_bottom += sink * PK * s + setdown(k)
		sink = 0.0
		s = 1.0
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
## which light version to draw (tools/bake_light2.py; owner 2026-11-06): morning while the sun is low in the east,
## evening while it is low in the west, night under the moon and the town's lights, the art as drawn around noon
func sun_side() -> String:
	var hh := fposmod(float(arena.tod_h), 24.0)
	if hh >= 5.5 and hh < 10.5: return "_m"
	if hh >= 14.5 and hh < 19.5: return "_e"
	if hh >= 19.5 or hh < 5.5: return "_n"           # moonlight + the lamps, fires and windows near each building
	return ""

func tod_now() -> Dictionary:
	return arena.tod_now()

func lantern_at(x: float, surf: float) -> Vector2:
	var im: Texture2D = tex["q_lamp"]
	# the lantern glass's centre on q_lamp_base (x 74..97, y 81..98 of 113 x 197; owner 2026-11-07: the light had
	# drifted off the glass when the lamp was redrawn)
	var lx := 86.0 / 113.0 * im.get_width() - 56.0
	var ly := 90.0 / 197.0 * im.get_height()
	if hx.has("q_lamp_base"):      # the pixel3d lantern: its glass 112 px over the foot, the lamp set down 2
		return Vector2(x + lx, surf - 110.0)
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
	if P3D.has("g_hall"): return TTOP - hx["g_hall"].get_height() + PK * BS + setdown("g_hall")   # the hall sprite's top
	return TTOP - (tex["g_hall_win"].get_height() - PK) * BS

## the lit windows' canvas size (the pixel3d hall: its own size, hx/g_hall_win.png drawn from its glass)
func win_size() -> Vector2:
	if P3D.has("g_hall") and hx.has("g_hall_win"): return hx["g_hall_win"].get_size()
	return tex["g_hall_win"].get_size() * BS

func light_sources() -> Array:
	var L: Array = []
	var t := Time.get_ticks_msec() / 1000.0
	for i in lamps.size():
		var p := lantern_at(lamps[i][0], lamps[i][1])
		L.append({"k": "lamp", "x": p.x, "y": p.y, "gy": lamps[i][1], "r": 150.0, "a": LIT.fl(t, i), "c": Color8(255, 196, 110), "glass": true})
	for s in light_strings:
		var yy: float = up_y((s[0] + s[1]) / 2.0) + BAND - 10.0 + 18.0
		for i in 7:
			var bu: Array = LIT.BULBS[i]
			L.append({"k": "bulb", "x": s[0] + (s[1] - s[0]) * bu[0], "y": yy - 18.0 + bu[1], "r": 60.0, "a": 0.8 + 0.2 * sin(t * 3.0 + i * 1.7), "c": Color8(255, 214, 140)})
	L.append({"k": "fire", "x": 4350.0 + 27.0 * PK, "y": G - CAMP_UP - 30.0, "gy": G - CAMP_UP, "r": 230.0, "a": LIT.fl(t, 9) * 1.1, "c": Color8(255, 150, 70)})
	var fp := bm("g_forge", 7348.0, LOWF - 52.0)        # the forge: a contained glow in the mouth, not a sun
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
		var p3w := P3D.has("g_hall")
		for w in (HALL_WIN3 if p3w else HALL_WIN):
			var wk: float = 1.0 if p3w else BS
			L.append({"k": "win", "x": HXB + w[0] * wk, "y": y0 + w[1] * wk, "r": 70.0 * BS, "a": wf * (0.9 + 0.1 * sin(t * 1.3 + w[0])), "c": Color8(255, 200, 120)})
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
			sh = 0.85 * deep_shade()            # under the terraces (open to the sun with the slope in)
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
	_lamp_uniforms(L, T)
	_light_uniforms(T)
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
		if k == "g_wagon": k = "g_wagon2"
		if P3D.has(k) and hx.has(k):
			# the pixel3d art's own silhouette (clouds pass over it); no sun volume: its ground shadow is baked (shadow/)
			o.append([hx[k], b[1], b[2] + b[3] * PK * ks(k) + setdown(k), 0.0, b.size() > 7 and b[7], 1.0, false, true])
			continue
		var tx: Texture2D = tex["g_wagon2"] if k == "g_wagon" and tex.has("g_wagon2") else tex[k]
		o.append([tx, b[1], b[2], b[3], b.size() > 7 and b[7], ks(k), false])
	o.append([hx["g_hall"], HXB, TTOP + PK * BS + setdown("g_hall"), 0.0, false, 1.0, false, true])
	for d in deco_back:
		# a tree with a card shadow (tools/pixel3d/tree_relief.py --flat, baked into the ground maps) needs no sun volume
		# every tree (owner 2026-11-08: test_light's occluders): the oak, round, young and tall ones have no "tree" in
		# their names and were left out, so the cloud shadows passed over them
		if d[0].contains("tree") or d[0] in ["f_oak", "f_round", "f_young", "f_tall"]: o.append([tex[d[0]], d[1], d[2], d[3], d[4], ks(d[0]), true, ResourceLoader.exists("res://assets/town/shadow/" + d[0] + "_card.png")])
	return o

func shade_props() -> Array:
	var o: Array = []
	for d in deco_props:
		var k: String = d[0]
		if hx.has(k):        # the pixel3d prop as drawn (_spr): its own art 1:1, set down, its mirrored build
			var fl: bool = d.size() > 3 and d[3]
			var kk := k + "L" if fl and hx.has(k + "L") else k
			o.append([hx[kk], d[1], d[2] + setdown(kk), 0.0, fl and kk == k, 1.0, false])
		else:
			o.append([tex[k], d[1], d[2], 0.0, d.size() > 3 and d[3], ks(k), false])
	return o

## surfTop: what clouds land on from above
func surf_top(x: float) -> float:
	if x < SX0: return G
	if x < STX1 + SL: return up_y(x)
	return LOWF

## cloud shade stops at the terraces' edge: the lower plaza lives in their shade
func cloud_bottom(x: float) -> float:
	if x >= SX0 and x <= STX1 + SL and not PLAZA_SUN: return minf(LOWF, up_y(x) + BAND - 14.0)
	return G + 380.0

## how much of the old "under the terraces" deep shade the lower plaza and the hall's slope keep (0..1). With the slope
## in (PLAZA_SUN) the plaza is open to the sky: the sun reaches it and the slope unless it is right behind the town, low
## (owner 2026-11-09: "빛을 언덕 아래로도 쏘자 완전 뒤에서 오는 역광이 아닌 이상 빛이 들어올겅ㆍ님"): only round sunrise
## and sunset, and at night (the ambient carries the night).
func deep_shade() -> float:
	if not PLAZA_SUN: return 1.0
	var hh := fposmod(arena.tod_h, 24.0)
	var day := clampf((hh - 5.5) / 13.5, 0.0, 1.0)
	var low := 1.0 - sin(day * PI)              # 0 at noon, 1 with the sun on the horizon behind the town
	return clampf((low - 0.8) / 0.18, 0.0, 1.0)

## the lower plaza lives under the terraces: deep shade
func shade_extra(ci: CanvasItem) -> void:
	var dk := deep_shade()
	if dk <= 0.01: return
	var vr: Rect2 = arena.view_rect()
	if vr.end.x < SX0 or vr.position.x > STX1 + SL: return
	var pts := PackedVector2Array([Vector2(SX0, G)])
	var x := SX0
	while x <= STX1 + SL:
		pts.append(Vector2(x, minf(LOWF, up_y(x) + BAND - 14.0)))
		x += 40.0
	pts.append(Vector2(STX1 + SL, LOWF + 40.0))
	pts.append(Vector2(SX0, LOWF + 40.0))
	ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.55 * dk))      # shade.gd colours it (cool, never black)

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
	win_sv.size = Vector2i(ceili(win_size().x * k), ceili(win_size().y * k))
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
	return hall_win() > 0.01 and HXB + win_size().x > vr.position.x and HXB < vr.end.x and win_y0() < vr.end.y and TTOP > vr.position.y

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
	if s2 != null and not P3D.has("g_hall"):      # PLACEHOLDER: the passing silhouette is laid out on the old hall art
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
	ci.draw_texture_rect(win_sv.get_texture(), Rect2(HXB, win_y0(), win_size().x, win_size().y), false, Color(1, 1, 1, hall_win()))


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
	near_grass.queue_redraw()
	mirror_mat.set_shader_parameter("t", Time.get_ticks_msec() / 1000.0)
	near_node.queue_redraw()
	# the ground is static: drawn for the view and 600 px either side, redrawn only when the view leaves that
	if ground_mat != null:
		var gt: String = sun_side().trim_prefix("_")
		if gt == "": gt = "d"
		if gt != gmap_now:
			gmap_now = gt
			ground_mat.set_shader_parameter("gmap", gmaps[gt])
			blade_mat.set_shader_parameter("gmap", gmaps[gt])
			blade_mat.set_shader_parameter("pal_lut", ground_mat.get_shader_parameter("pal_lut"))
			blade_mat.set_shader_parameter("pal_fx", ground_mat.get_shader_parameter("pal_fx"))
			blade_mat.set_shader_parameter("lit_on", 1.0)
			# the map's cell (tools/bake_ground_light.py CX, CY): the shader's default (4, 2) read every blade's light from
			# half its x, so the blades stood lit over the trees' shadows (owner 2026-11-08: "나무 하단 그림자가 어긋나있음")
			blade_mat.set_shader_parameter("gmap_cell", Vector2(2.0, 2.0))
			tuft_mat.set_shader_parameter("gmap", gmaps[gt])
			tuft_mat.set_shader_parameter("pal_lut", ground_mat.get_shader_parameter("pal_lut"))
			tuft_mat.set_shader_parameter("pal_fx", ground_mat.get_shader_parameter("pal_fx"))
			tuft_mat.set_shader_parameter("lit_on", 1.0)
	var gvr: Rect2 = arena.view_rect()
	if not g_vr.encloses(gvr): ground_node.queue_redraw()
	blade_back.queue_redraw()
	blade_front.queue_redraw()
	tuft_node.queue_redraw()
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
	var my := G - mt.get_height() * PXK - 40.0
	if hx.has("bg_range_near"):
		# three ranges, each wider than its parallax travel over the town (no repeat), the farther the paler
		# (tools/make_bg_ranges.py; owner 2026-11-08: "원경도 반복임. 공기 산란도 없음")
		_layer(hx["bg_range_far"], 0.05, my - 28.0 - 62.0 - cam_y * 0.06, 1.0, cam_x, vs)
		_layer(hx["bg_range_mid"], 0.1, my - 28.0 - 30.0 - cam_y * 0.09, 1.0, cam_x, vs)
		_layer(hx["bg_range_near"], 0.16, my - 28.0 - cam_y * 0.12, 1.0, cam_x, vs)
	else:
		_layer(hx.get("bg_mountains", mt), 0.16, my - cam_y * 0.12, 1.0 if hx.has("bg_mountains") else PXK, cam_x, vs)
	var T := tod_now()
	var dim: float = 1.0 - 0.75 * T["sun"]
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.07, 0.05, 0.16, 0.2 * dim))
	var fo: Texture2D = tex["bg_forest"]
	if hx.has("bg_wood"):
		# the middle distance (owner 2026-11-08: "근경과 가까운 배경은 없는데"), pixel3d strips wider than their travel
		# (tools/pixel3d/bgmid.js, branch wip/layer3d): the far wood, then nearer hills with trees, drawn below
		_layer(hx["bg_wood"], 0.42, G - 198.0 - cam_y * 0.25, 1.0, cam_x, vs)
		bg_node.draw_rect(Rect2(0, roundf(G - 198.0 - cam_y * 0.25) + 168.0, vs.x, vs.y + 400.0), Color8(12, 88, 98))   # its ground on down
	else:
		_layer(hx.get("bg_forest", fo), 0.42, G + 2.0 - 242.0 * PXK - cam_y * 0.25, 1.0 if hx.has("bg_forest") else PXK, cam_x, vs)
	bg_node.draw_rect(Rect2(0, G + 1.0 - cam_y * 0.25, vs.x, vs.y + 400.0), Color8(14, 74, 78))
	if hx.has("bg_hills"):
		_layer(hx["bg_hills"], 0.65, G - 182.0 - cam_y * 0.28, 1.0, cam_x, vs)
		bg_node.draw_rect(Rect2(0, roundf(G - 182.0 - cam_y * 0.28) + 298.0, vs.x, vs.y + 400.0), Color8(61, 81, 46))
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
			var tw2 := float(g2w[k])
			var sx2 := fposmod(x, tw2)
			sx2 = minf(sx2, tw2 - PK)
			var tt: Texture2D = g2[k][vi][int(sx2) / GPIECE]
			var th2: float = tt.get_height() if clip_h < 0.0 else minf(tt.get_height(), clip_h + RAISE)
			gc.draw_texture_rect_region(tt, Rect2(x, y0 - RAISE, PK, th2), Rect2(sx2 - float(int(sx2) / GPIECE * GPIECE), 0, PK, th2))
			# the turf lip: wherever the top of this column is grass (the lawn, and the grassy bits inside the clearing),
			# the green runs a ragged few rows down over the earth face -- the edge that makes the ground a block
			var green: bool = k == "lawn" or (g2green.has(k) and g2green[k][int(sx2) % g2green[k].size()])
			# (the turf lip made the ground a block with an earth face; with the lawn running on in front there is no
			# face: owner 2026-11-09 "사전에 입체감 넣겠다고 넣은 이런거 빼버리고")
			if green and not FIELD_ON:
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
	if vi >= 0 and not g2.is_empty():
		_clear_caps(a, b, f)
		_stone_caps(a, b, f)
		_clear_front(a, b, f)

## ---------- ground plane (tools/make_town_ground2.py) ----------
var RAISE := 12.0               # rows of the plane showing behind the stand line (+ DEEP)
## extra depth of the plane behind the stand line (owner 2026-11-08: "한 30까지 해도 될듯 30으로"; ?deepN overrides, ?deep0 the old plane):
## the plane rows of the ground tiles are stretched back by this many rows
var DEEP := 30
# trodden paths (owner 2026-11-06: a lot of it is walked -- worn dirt before every door and gate, the camp, the barn)
var CLEAR := [[300.0, 700.0], [4080.0, 4960.0], [5440.0, 6100.0]]
var g2 := {}                    # per zone: [solid pieces, band pieces], each piece GPIECE px wide (phones' texture limit)
var g2w := {}                   # per zone: the tile's whole width
var g2green := {}
const GPIECE := 2400

## an image as textures GPIECE px wide, left to right
func _pieces(im: Image) -> Array:
	var out := []
	var x := 0
	while x < im.get_width():
		out.append(ImageTexture.create_from_image(im.get_region(Rect2i(x, 0, mini(GPIECE, im.get_width() - x), im.get_height()))))
		x += GPIECE
	return out
var capgreen := []                # per tile column: is the top of the ground grass there (for the turf lip)
var LIPY := 28.0                 # the row of the tile where the top meets the earth face (+ DEEP)
const LIPC := Color8(111, 120, 56)        # leaf ramp step 3 (map palette)
const LIPC2 := Color8(80, 81, 36)         # leaf ramp step 2
## where the turf lip runs out (the last grassy column at each end of each clearing): it tapers to nothing toward
## these over ~16 px, raggedly, instead of stopping in a straight cut
var lip_ends := []
func _lip_taper(x: float) -> float:
	var m := 1.0
	for e in lip_ends: m = minf(m, absf(x - e) / 16.0)
	return clampf(m + 0.25 * (_vnoise(x / 2.3 + 5.0) - 0.5), 0.0, 1.0)

var FIELD_ON := false
const CURB := 18                 # the paving tile's curb rows above LIPY (rows 40..57 of k_stone)
const PAVE_WIN := 96.0           # px each side of a paving end looked at (a stone's half-width more than the meander)
const FIELD_LAWN := Color8(131, 141, 64)      # the lawn ramp's body (row 4 step 4: the field's and the plane's front)
const FIELD_LAWN_L := Color8(151, 161, 76)    # a step lighter: a blade's tip

## the paving's ends below the walk (owner 2026-11-09: "돌타일, 흙타일과 풀 타일이 맞닿는 부분의 연결타일 더자연스럽게
## 다듬어서 넣기", "좀 더 자연스럽게"): each stone is kept or dropped WHOLE, by where its middle lies against an edge that
## meanders down the rows, its rank (k_field_rank R, tools/make_town_field.py) shifting it a little so a few stones stand
## out in the grass or leave a gap; a joint stays beside a kept stone; the grass grows over the rim of the stones that
## border it, a cell here and there. inside (the paving's own solid): what goes shows the lawn's solid; outside (the
## lawn's): kept stones laid on it, from the paving's first field row (where its curb was)
func _paving_ends(solid: Image, inside: bool, lawn: Image, stone: Image) -> void:
	var rk: Image = tex["k_field_rank"].get_image()
	rk.decompress()
	var rw := rk.get_width()
	var rh := rk.get_height()
	var fy0 := int(LIPY) - CURB
	var sw := solid.get_width()
	var ny := mini(rh, (solid.get_height() - 1 - fy0) / 2)
	# (built before _layout fills STONE: the same zone as _layout's)
	var zones: Array = STONE if not STONE.is_empty() else [[HDOOR - 420.0, HDOOR + 420.0]]
	for z in zones:
		for side in 2:
			var e: float = z[0] if side == 0 else z[1]
			var c0 := int(floorf((e - PAVE_WIN) / 2.0))
			var nc := int(PAVE_WIN)                       # cells across the window (2 * PAVE_WIN px / 2)
			# 0 grass, 1 kept stone, 2 kept joint
			var g := PackedByteArray(); g.resize(nc * ny)
			for cy in ny:
				var edge := (_vnoise(cy / 9.0 + 13.0 + side * 40.0) - 0.5) * 44.0 + (_vnoise(cy / 3.0 + 7.0) - 0.5) * 12.0
				for i in nc:
					var cx := c0 + i
					if cx < 0 or cx >= rw: continue
					var px := rk.get_pixel(cx, cy)
					if px.r <= 0.001: continue
					var mx := (cx + roundi(px.g * 255.0) - 128) * 2.0 + 1.0       # the stone's middle (px)
					var dc := (e - mx) if side == 0 else (mx - e)                  # > 0 out on the lawn
					if dc + (px.r - 0.5) * 28.0 < edge: g[cy * nc + i] = 1
			for cy in ny:                                   # the joints round the kept stones
				for i in nc:
					var cx := c0 + i
					if g[cy * nc + i] != 0 or cx < 0 or cx >= rw: continue
					if rk.get_pixel(cx, cy).r > 0.001: continue
					var nb := false
					for j in [-1, 0, 1]:
						for q in [-1, 0, 1]:
							var yy: int = cy + j
							var ii: int = i + q
							if yy >= 0 and yy < ny and ii >= 0 and ii < nc and g[yy * nc + ii] == 1: nb = true
					if nb: g[cy * nc + i] = 2
			for cy in ny:
				var y := fy0 + cy * 2
				for i in nc:
					var xa := (c0 + i) * 2
					if xa < 0 or xa >= sw - 1: continue
					var d: float = (e - (xa + 1.0)) if side == 0 else ((xa + 1.0) - e)
					if (d < 0.0) != inside: continue
					var v := g[cy * nc + i]
					# the grass over a bordering stone's rim: a cell of the stone's outline (joint or stone) that touches
					# grass, now and then
					if v != 0:
						var gr := false
						for o in [[-1, 0], [1, 0], [0, -1]]:
							var ii: int = i + o[0]
							var yy: int = cy + o[1]
							if ii >= 0 and ii < nc and yy >= 0 and g[yy * nc + ii] == 0: gr = true
						if gr and fposmod(sin((c0 + i) * 12.9898 + cy * 78.233) * 43758.5453, 1.0) < 0.55: v = 0
					if inside and v == 0:
						for q in 4: solid.set_pixel(xa + (q & 1), y + (q >> 1), lawn.get_pixel(xa + (q & 1), y + (q >> 1)))
					elif not inside and v != 0:
						for q in 4: solid.set_pixel(xa + (q & 1), y + (q >> 1), stone.get_pixel(xa + (q & 1), y - fy0 + (q >> 1)))

## the clearing's front edge: the lawn in front grows a few cells up over the path, raggedly, with a blade standing up
## here and there (no earth face, no dark line). Drawn over the ground and the clearing's end caps alike, so the edge
## runs on through the caps and thins out where their path does.
func _clear_front(a: float, b: float, f: Callable) -> void:
	if not FIELD_ON or not tex.has("k_clear_cap"): return
	var gc: CanvasItem = gci if gci != null else self
	var hw := float(tex["k_clear_cap"].get_width()) / 2.0
	for z in CLEAR:
		var x := maxf(floorf(a / PK) * PK, floorf((z[0] - hw) / PK) * PK)
		var x1 := minf(b, z[1] + hw)
		while x < x1:
			# the edge as a fringe of grass, not a smooth mound: a slow rise and fall, each column a cell up or down
			# of it, the odd blade two cells taller; a column standing over both neighbours lights its tip
			var ef := func(xx: float) -> int:
				var hj := fposmod(sin(xx * 0.731 + 4.1) * 43758.5453, 1.0)
				var base := 0.6 + 1.8 * _vnoise(xx / 34.0 + 3.0) + (1.0 if hj > 0.6 else 0.0) + (2.0 if hj > 0.95 else 0.0)
				return int(floorf(base * clampf(1.0 - maxf(z[0] - xx, xx - z[1]) / hw, 0.0, 1.0)))
			var e: int = ef.call(x)
			var yb: float = roundf(f.call(x)) - RAISE + LIPY
			if e > 0:
				gc.draw_rect(Rect2(x, yb - 2.0 * e, PK, 2.0 * e), FIELD_LAWN)
				if e >= 2 and e > ef.call(x - PK) and e > ef.call(x + PK):
					gc.draw_rect(Rect2(x, yb - 2.0 * e, PK, PK), FIELD_LAWN_L)
			x += PK

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
		if tex.has(r[0]): o.append([r[1] + 4.0, r[1] + tex[r[0]].get_width() - 4.0, r[2] - floor_at(r[1])])
	return o

## stone paving (owner 2026-11-06: "이걸로 돌길이나 돌 장식도 깔 수 있는 거 아님?"): the hall's forecourt and the plaza under it
var STONE := []
func gzone(x: float) -> String:
	for z in STONE:
		if x >= z[0] and x < z[1]: return "stone"
	for z in CLEAR:
		if x >= z[0] and x < z[1]: return "clear"
	return "lawn"

## a ground tile with its plane (rows 3..28, back to front) stretched over 3..28+DEEP, nearest row: same colours,
## more depth; the earth face below moves down with it
func _deepen(im: Image) -> Image:
	var w := im.get_width()
	var h := im.get_height()
	var st := Image.create(w, h + DEEP, false, Image.FORMAT_RGBA8)
	st.blit_rect(im, Rect2i(0, 0, w, 3), Vector2i.ZERO)
	for yy in range(3, 28 + DEEP):
		var sy := 3 + int(float(yy - 3) * 25.0 / float(25 + DEEP))
		st.blit_rect(im, Rect2i(0, sy, w, 1), Vector2i(0, yy))
	st.blit_rect(im, Rect2i(0, 28, w, h - 28), Vector2i(0, 28 + DEEP))
	return st

## no steps (owner 2026-11-09, Owlboy: "암만봐도 이게 젤 낫네"): the lawn runs straight on; depth from the near art
const FIELD_STEPS := false
## the front of the walk joined from its 2400-px pieces (tools/make_town_field.py), or null
func _join_field(pre: String) -> Image:
	if not tex.has(pre + "0"): return null
	var parts: Array[Image] = []
	var i := 0
	while tex.has(pre + str(i)):
		var im: Image = tex[pre + str(i)].get_image()
		im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		parts.append(im)
		i += 1
	var out := Image.create(parts.size() * parts[0].get_width(), parts[0].get_height(), false, Image.FORMAT_RGBA8)
	for j in parts.size(): out.blit_rect(parts[j], Rect2i(0, 0, parts[j].get_width(), parts[j].get_height()), Vector2i(j * parts[0].get_width(), 0))
	return out
## the earth step under the walk at x (tile x; px, even): none mostly, in about every other 520 px a stretch 120..300 px rising
## to 8..16 px and easing out at both ends over 24 px
func field_edge(x: float) -> int:
	if not FIELD_STEPS: return 0
	var _hsh := func(v: float) -> float: return fposmod(sin(v) * 43758.5453, 1.0)
	var cell := floorf(x / 520.0)
	var r: float = _hsh.call(cell * 3.17 + 11.0)
	if r > 0.6: return 0
	var a: float = cell * 520.0 + 60.0 + _hsh.call(cell * 5.3) * 300.0
	var len: float = 120.0 + _hsh.call(cell * 7.9) * 180.0
	var h: float = 8.0 + roundf(_hsh.call(cell * 2.3) * 4.0) * 2.0
	if x < a or x > a + len: return 0
	var k := clampf(minf(x - a, a + len - x) / 24.0, 0.0, 1.0)
	return int(roundf(h * k / 2.0)) * 2

func _build_ground2() -> void:
	if not tex.has("k_lawn_0"): return
	for k in arena.dbg:
		if String(k).begins_with("deep"): DEEP = int(String(k).substr(4))
	RAISE = 12.0 + DEEP
	LIPY = 28.0 + DEEP
	if DEEP > 0:
		for ck in ["k_clear_cap", "k_stone_cap"]:
			if not tex.has(ck) or tex[ck].get_height() >= 101 + DEEP: continue      # drawn that deep already
			var ci: Image = tex[ck].get_image()
			ci.decompress()
			ci.convert(Image.FORMAT_RGBA8)
			tex[ck] = ImageTexture.create_from_image(_deepen(ci))
	var field_im: Image = null
	var lawn_solid: Image = null
	var field_stone: Image = _join_field("k_field_stone_")
	FIELD_ON = tex.has("k_field_0")
	if tex.has("k_field_0"):
		# the caps at the clearings' and the paving's ends end at the walk's front edge too: the lawn runs on below
		for ck in ["k_clear_cap", "k_stone_cap"]:
			if not tex.has(ck): continue
			var cim: Image = tex[ck].get_image()
			cim.decompress()
			cim.convert(Image.FORMAT_RGBA8)
			var cy := int(LIPY) - (CURB if ck == "k_stone_cap" else 0)
			if cim.get_height() > cy:
				cim.fill_rect(Rect2i(0, cy, cim.get_width(), cim.get_height() - cy), Color(0, 0, 0, 0))
				tex[ck] = ImageTexture.create_from_image(cim)
		var fparts: Array[Image] = []
		var fi := 0
		while tex.has("k_field_%d" % fi):
			var fim: Image = tex["k_field_%d" % fi].get_image()
			fim.decompress()
			fim.convert(Image.FORMAT_RGBA8)
			fparts.append(fim)
			fi += 1
		field_im = Image.create(fparts.size() * fparts[0].get_width(), fparts[0].get_height(), false, Image.FORMAT_RGBA8)
		for j in fparts.size(): field_im.blit_rect(fparts[j], Rect2i(0, 0, fparts[j].get_width(), fparts[j].get_height()), Vector2i(j * fparts[0].get_width(), 0))
	for k in ["lawn", "clear", "stone"]:
		if not tex.has("k_" + k + "_0"): continue
		# the tile in 2400-px pieces (tools/split_wide.py: a 9600-px texture fails on phones), joined here on the CPU
		var parts: Array[Image] = []
		var pi := 0
		while tex.has("k_%s_%d" % [k, pi]):
			var pim: Image = tex["k_%s_%d" % [k, pi]].get_image()
			pim.decompress()
			pim.convert(Image.FORMAT_RGBA8)
			parts.append(pim)
			pi += 1
		var fw := 0
		for pim in parts: fw += pim.get_width()
		var im := Image.create(fw, parts[0].get_height(), false, Image.FORMAT_RGBA8)
		var px := 0
		for pim in parts:
			im.blit_rect(pim, Rect2i(0, 0, pim.get_width(), pim.get_height()), Vector2i(px, 0))
			px += pim.get_width()
		var w := im.get_width()
		var h := im.get_height()
		var deep := 520
		var solid := Image.create(w, deep, false, Image.FORMAT_RGBA8)
		if DEEP > 0 and h < 101 + DEEP:      # the old 28-row plane (tools/make_town_ground3.py draws it 58 deep)
			im = _deepen(im)
			h = im.get_height()
		solid.blit_rect(im, Rect2i(0, 0, w, h), Vector2i.ZERO)
		var last := im.get_region(Rect2i(0, h - 1, w, 1))
		for y in range(h, deep): solid.blit_rect(last, Rect2i(0, 0, w, 1), Vector2i(0, y))
		# in front of the walk the lawn runs on toward the camera, no earth section (owner 2026-11-08: "풀 타일부터
		# 근경까지 풀로 이어지게 할거임"; tools/make_town_field.py)
		# both (owner 2026-11-09: "둘 다 섞지 뭐", "가끔씩만 단차두는 연출로"): here and there the walk keeps an earth
		# edge (field_edge px of its section), a step down to the lawn; elsewhere the lawn runs straight on
		# the paving's curb (rows LIPY - CURB .. LIPY, the walk's front face drawn for depth) goes (owner 2026-11-09:
		# "사전에 입체감 넣겠다고 넣은 이런거 빼버리고"): the flagstones start where the cobbles end
		var fim: Image = field_stone if k == "stone" and field_stone != null else field_im
		var fy0 := int(LIPY) - (CURB if k == "stone" and field_stone != null else 0)
		if fim != null:
			var fx := 0
			while fx < mini(w, fim.get_width()):
				solid.blit_rect(fim, Rect2i(fx, 0, 2, fim.get_height()), Vector2i(fx, fy0 + field_edge(float(fx))))
				fx += 2
		# where the kinds meet (owner 2026-11-09: "돌타일, 흙타일과 풀 타일이 맞닿는 부분의 연결타일 더자연스럽게 다듬어서
		# 넣기"): the paving ends in loose stones in the grass, the clearing's front edge is grass grown ragged over it
		if field_im != null and field_stone != null and tex.has("k_field_rank"):
			if k == "lawn": _paving_ends(solid, false, null, field_stone)
			elif k == "stone" and lawn_solid != null: _paving_ends(solid, true, lawn_solid, field_stone)
		if k == "lawn": lawn_solid = solid
		var band := solid.get_region(Rect2i(0, 0, w, int(BAND + RAISE)))
		var gr := []
		for xx in w:
			var ng := 0
			for yy in range(14 + DEEP, 28 + DEEP):
				var c := im.get_pixel(xx, yy)
				if c.a > 0.5 and c.g > c.r + 0.03: ng += 1
			gr.append(ng >= 3)             # grass reaching the front edge of the top at this column
		if k == "stone": gr.fill(false)     # moss between the stones is not a turf lip
		g2green[k] = gr
		g2w[k] = w
		g2[k] = [_pieces(solid), _pieces(band)]

## the paving's ends (tools/make_town_stone.py): cobbles thinning into the turf, the front curb ending on a stone.
## The cap's first STONE_B px lie over the lawn (transparent where it is plain lawn), the rest over the paving.
const STONE_B := 40.0
func _stone_caps(a: float, b: float, f: Callable) -> void:
	if not tex.has("k_stone_cap"): return
	var gc: CanvasItem = gci if gci != null else self
	var cap: Texture2D = tex["k_stone_cap"]
	var cw := float(cap.get_width())
	for z in STONE:
		for side in 2:
			var x0: float = z[0] - STONE_B if side == 0 else z[1] + STONE_B - cw
			if x0 + cw < a or x0 > b: continue
			var y0: float = roundf(f.call(z[0] if side == 0 else z[1])) - RAISE
			if side == 0: gc.draw_texture_rect(cap, Rect2(x0, y0, cw, cap.get_height()), false)
			else:
				gc.draw_set_transform(Vector2(x0 + cw, 0), 0.0, Vector2(-1, 1))
				gc.draw_texture_rect(cap, Rect2(0, y0, cw, cap.get_height()), false)
				gc.draw_set_transform(Vector2.ZERO)

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
					for yy in range(14 + DEEP, 28 + DEEP):
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
				if FIELD_ON: break
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
	if flip and hx.has(k + "L"):         # its own mirrored build, lit by the same sun
		k = k + "L"
		flip = false
		im = hx[k]
	var lv := sun_side()
	if lv != "" and lit_tex.has(k + lv): im = lit_tex[k + lv]
	# a sprite drawn in several places has its own night look at each (the lamps near it differ)
	if lv == "_n" and lit_tex.has(k + "_n_" + str(int(roundf(x)))): im = lit_tex[k + "_n_" + str(int(roundf(x)))]
	var y := y_bottom - h + sink * PK * s + setdown(k)
	# the ground shadow the building casts at this hour (owner 2026-11-07: "허공에 뜬거 수정"), drawn under it; its
	# canvas starts 24 px left of the sprite (the render's margin) and at the sprite's top
	if not flip and sh_tex.has(k): sh_place(k, x, y, ci)
	im = lit_ct(k, im)
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
	var wo := Vector2(0.0, G) if HILL_ON else Vector2.ZERO
	for p in pts: uvs.append((p - wo) / t_wall.get_size())
	gn.draw_colored_polygon(pts, Color.WHITE, uvs, t_wall)
	# 2. lower level: floor + valley, river
	_shear(t_solid, RX1, RIV0, func(_x): return LOWF)
	_shear(t_solid, RIV1, TOWN_W + PK, func(_x): return LOWF)
	# 3. lower plaza: light strings, fountain
	var L: Texture2D = hx.get("q_lights", tex["q_lights"])
	for s in light_strings:
		var yy: float = up_y((s[0] + s[1]) / 2.0) + BAND - 10.0 - (P3D["q_lights"][0] if hx.has("q_lights") else 0.0)
		gn.draw_texture_rect(L, Rect2(s[0], yy, s[1] - s[0], L.get_height()), false)
	_spr("q_fountain", HDOOR - 52.0 * PK * BS, LOWF, 0.0, false, gn)
	# 4. upper bands, west street, ramp
	_shear(t_solid, -PK, SX0, func(_x): return G)
	_shear(t_band, SX0, STX1 + SL, up_y)
	_shear(t_solid, STX1 - 40.0, STX1 + SL + 40.0, func(_x): return LOWF)
	_shear(t_solid, SX0, RX1, ramp_y)

## the river in front of the walk (owner 2026-11-08, sketch 5): from the waterline under the bridge it runs on toward
## the camera between the lawns, widening and bending a little left; the water, its mirror and its banks share it
func river_poly() -> PackedVector2Array:
	var wl := LOWF + 20.0
	var L := PackedVector2Array()
	var R := PackedVector2Array()
	for i in 41:
		var d := float(i) * 10.0
		var u := d / 100.0
		var c := (RIV0 + RIV1) / 2.0 - 30.0 * minf(u, 1.0)
		var hw := (RIV1 - RIV0) / 2.0 + u * u * 70.0 + u * 30.0
		L.append(Vector2(roundf((c - hw) / PK) * PK, wl + d))
		R.append(Vector2(roundf((c + hw) / PK) * PK, wl + d))
	R.reverse()
	return L + R

## the near grass: a strip at the bottom of the view, sliding a little faster than the world (it is nearer), sunk
## low where the river comes out under it so the water shows
func _draw_near_grass() -> void:
	var vr: Rect2 = arena.view_rect()
	var tw := float(NEAR_GRASS.get_width())
	var th := float(NEAR_GRASS.get_height())
	var y0 := roundf((vr.end.y - th) / PK) * PK
	var off := vr.position.x * 0.25                  # parallax: 1.25x the world's scroll
	var rc := (RIV0 + RIV1) / 2.0 - 30.0
	var x := floorf(vr.position.x / PK) * PK
	while x < vr.end.x:
		var sx := fposmod(x + off, tw)
		sx = floorf(sx / PK) * PK
		if x >= SX0 and x <= STX1 + SL:                 # the lower street under the terraces: its own front (later)
			x += PK
			continue
		var dip := clampf((340.0 - absf(x - rc)) / 60.0, 0.0, 1.0)      # over the river's mouth
		var y := y0 + roundf(dip * 22.0 / PK) * PK
		near_grass.draw_texture_rect_region(NEAR_GRASS, Rect2(x, y, PK, th), Rect2(minf(sx, tw - PK), 0, PK, th))
		x += PK

func _draw() -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	# the river: pixelfx water/town-river (tools/pixelfx_fx/town-river.js), 120 frames 240x96 at 10 fps, exactly the
	# river's width; deeper down its darkest step; the bridge deck's shadow lies on the water just under it
	var rfi := int(tt * 10.0) % 120
	draw_texture_rect_region(RIVER, Rect2(RIV0, LOWF + 18.0, 240.0, 96.0), Rect2((rfi % 7) * 240, (rfi / 7) * 96, 240, 96))
	draw_rect(Rect2(RIV0, LOWF + 114.0, RIV1 - RIV0, 700.0), Color("#05222b"))
	var rp := river_poly()
	draw_colored_polygon(rp, Color8(12, 88, 98))
	# its banks: a cell of sand at the water, a cell of earth under the lawn's edge (palette)
	var n := rp.size() / 2
	for side in 2:
		for i in n - 1:
			var p: Vector2 = rp[i] if side == 0 else rp[rp.size() - 1 - i]
			var q: Vector2 = rp[i + 1] if side == 0 else rp[rp.size() - 2 - i]
			var sgn := -1.0 if side == 0 else 1.0
			var y := p.y
			while y < q.y:
				var x := roundf(lerpf(p.x, q.x, (y - p.y) / (q.y - p.y)) / PK) * PK
				# outside the water (the mirror covers the polygon): sand at the edge, earth beyond it
				var xs := x - PK if side == 0 else x
				draw_rect(Rect2(xs, y, PK, PK), Color8(222, 190, 144))
				draw_rect(Rect2(xs + sgn * PK, y, PK, PK), Color8(101, 60, 46))
				y += PK
	draw_rect(Rect2(RIV0, LOWF + 18.0, RIV1 - RIV0, 5.0), Color(0.05, 0.1, 0.18, 0.35))
	# 5. trees, buildings, the hall, props, lamps, bridge
	var vr0: Rect2 = arena.view_rect().grow(60.0)
	for i in deco_back.size():
		var d: Array = deco_back[i]
		var dk: String = d[0]
		if dk.contains("tree"): _tree(dk, d[1], d[2], d[3], d[4], d[5], d[1] * 0.003, vr0)
		else: _sway(dk, d[1], d[2], d[3], d[4], d[5] * (1.0 + life.rust.get(i, 0.0) * 4.0), d[1] * 0.003, vr0)
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
	draw_texture_rect_region(CAMPFIRE, Rect2(roundf(fxx - 64.0), roundf(G - CAMP_UP - CAMP_APEX - 112.0), 128, 128), Rect2((cfi % 10) * 128, (cfi / 10) * 128, 128, 128))

## crates, barrels, benches, pots and lamps: the ones whose foot is on the stand line here, the nearer ones on near_node
func _is_near(x: float, y: float) -> bool:
	return y > floor_at(x) + 0.5

func _draw_near() -> void:
	_draw_props(near_node, true)

func _draw_props(ci: CanvasItem, near: bool) -> void:
	# depth by where each thing meets the ground (owner 2026-11-06: "깊이 기준은 땅에 맞다는 기준으로 보고 앞에 있을 수록
	# 앞에"): crates, barrels, lamps and rocks are drawn from the back of the plane to the front; the ones nearer than
	# the people's stand line go on near_node, over the people
	var vr0: Rect2 = arena.view_rect().grow(60.0)
	var tms := float(Time.get_ticks_msec())
	var items: Array = []
	for i in deco_props.size():
		var d: Array = deco_props[i]
		if _is_near(d[1], d[2]) == near and d[1] < vr0.end.x and d[1] + 200.0 > vr0.position.x: items.append([d[2], 0, i])
	for i in lamps.size():
		var lp: Array = lamps[i]
		if _is_near(lp[0], lp[1]) == near: items.append([lp[1], 1, i])
	for i in rocks.size():
		var r: Array = rocks[i]
		if tex.has(r[0]) and _is_near(r[1], r[2]) == near and r[1] < vr0.end.x and r[1] + 120.0 > vr0.position.x: items.append([r[2], 2, i])
	items.sort_custom(func(p, q): return p[0] < q[0] or (p[0] == q[0] and p[1] < q[1]))
	for it in items:
		match it[1]:
			0:
				var i: int = it[2]
				var d: Array = deco_props[i]
				var j: float = life.jig.get(i, 0.0)
				var xf := Transform2D.IDENTITY
				if j > 0.02:
					# struck: it rocks and hops
					var cx: float = d[1] + tex[d[0]].get_width() * ks(d[0]) / 2.0
					var c := Vector2(cx, d[2])
					xf = Transform2D(sin(tms / 28.0) * 0.08 * j, c) * Transform2D(0.0, -c - Vector2(0, absf(sin(tms / 60.0)) * 6.0 * j))
				_spr(d[0], d[1], d[2], 0.0, d.size() > 3 and d[3], ci, xf)
				if i == 2: life.draw_cat(ci)          # the cat sleeps on this crate, as near as it
			1:
				var lp: Array = lamps[it[2]]
				_lamp(lp[0] - 28.0 * PK, lp[1], vr0, ci)
			2:
				var r: Array = rocks[it[2]]
				_spr(r[0], r[1], r[2], 0.0, false, ci)

## the grass blades (GPU, shaders/grass_blades.gdshader): only the chunks in view
func _draw_blade_meshes(ci: CanvasItem, which: String) -> void:
	if bmesh.is_empty():
		var fg: Callable = func(_x): return G
		var fl: Callable = func(_x): return LOWF
		var surfs := [[-PK, SX0, fg], [SX0, STX1 + SL, up_y], [SX0, RX1, ramp_y], [RX1, RIV0, fl], [RIV1, TOWN_W + PK, fl]]
		bmesh = life.build_blade_meshes(surfs)
		# the lower level under the terraces and the slopes has the recess wall or the hill's face behind it, not the plane: no tufts
		var under: Callable = func(x): return 1e9 if x >= SX0 and x <= STX1 + SL else -1e9
		var none: Callable = func(_x): return -1e9
		tufts = life.build_tufts([[-PK, SX0, fg, none], [SX0, STX1 + SL, up_y, none], [SX0, RX1, ramp_y, under], [RX1, RIV0, fl, under], [RIV1, TOWN_W + PK, fl, under]])
		for k in life.TUFT_KINDS:
			var tx: Texture2D = load("res://assets/town/grass/" + k + ".png")
			tuft_tex[k] = [tx, tx.get_width() / 7.0, float(tx.get_height())]
	var vr: Rect2 = arena.view_rect()
	for c in bmesh[which]:
		if c[1] < vr.position.x or c[0] > vr.end.x: continue
		ci.draw_mesh(c[2], null)

## the tufts on the back of the plane, each in the sway frame of its wind (town_life.tuft_lean)
func _draw_tufts() -> void:
	if bmesh.is_empty(): return
	var vr: Rect2 = arena.view_rect()
	for t in tufts:
		var x: float = t[0]
		if x + 60.0 < vr.position.x or x - 60.0 > vr.end.x: continue
		var e: Array = tuft_tex[t[2]]
		var fw: float = e[1]
		var h: float = e[2]
		var fi := clampi(roundi(life.tuft_lean(x, t[1], h)) - TUFT_LEANS, 0, 6)
		var at := Vector2(x - fw / 2.0, t[1] - h)
		if t[3]:
			tuft_node.draw_set_transform(Vector2(2.0 * x, 0.0), 0.0, Vector2(-1, 1))
			tuft_node.draw_texture_rect_region(e[0], Rect2(at, Vector2(fw, h)), Rect2(clampi(4 - fi, 0, 6) * fw, 0, fw, h))     # mirrored: the frame leaning the other way
			tuft_node.draw_set_transform(Vector2.ZERO)
		else:
			tuft_node.draw_texture_rect_region(e[0], Rect2(at, Vector2(fw, h)), Rect2(fi * fw, 0, fw, h))

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
	# (the mirror, z 7, covers a wading body from the waterline down; only the line itself is drawn again here)
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
## The leaf wave is played by the wind, not looped (owner 2026-11-07: "항상 반복하는 게 아니라 속도와 유동성을 고려하여
## 바람에 의한 것을 강조"): a tree rests (sheet frame 23: every ball home) until the grass's gust wave (the same field
## as shaders/grass_blades.gdshader) reaches it; then, likelier the stronger the wind, its crown runs ONE wave (frames
## 0..23), faster in a strong gust, and a strong gust chains a second. Calm air: few, slow waves; a gust: quick ones.
var tree_wave := {}               # tree key -> [frame (float), playing, waves left]
func _tree_wave(key: String, cx: float) -> int:
	var st: Array = tree_wave.get(key, [23.0, false, 0])
	var t: float = life.now() / 1000.0
	var g := sin(cx * 0.0065 - t * 2.4) * 0.6 + sin(cx * 0.017 - t * 3.1 + 2.0) * 0.4
	var gw: float = maxf(0.0, g - 0.35) * (0.6 + life.gust)
	var dt := get_process_delta_time()
	if not st[1]:
		if gw > 0.12 and randf() < dt * (0.6 + 4.0 * minf(life.gust, 1.2)):
			st = [0.0, true, 2 if life.gust > 1.2 else 1]
	else:
		st[0] += dt * 10.0 * (0.7 + 0.9 * minf(life.gust, 1.6))
		if st[0] >= 24.0:
			st[2] -= 1
			if st[2] > 0: st[0] -= 24.0
			else: st = [23.0, false, 0]
	tree_wave[key] = st
	return mini(int(st[0]), 23)

## tree: the trunk stays, the canopy bends as one soft mass in 2 px rows (the top moves most)
func _tree(k: String, x: float, y_bottom: float, sink: float, flip: bool, amp: float, ph: float, vr: Rect2) -> void:
	if tex.has(k + "_sway"):
		# leaf balls rippling in 1-px steps, baked (tools/make_tree_sway.py): 24 frames 6 wide, 0.1 s each, quicker in a gust
		var sw: Texture2D = tex[k + "_sway"]
		var fw := float(sw.get_width() / 6)
		var fh := float(sw.get_height() / 4)
		x = roundf(x)
		if x > vr.end.x or x + fw < vr.position.x or y_bottom - fh > vr.end.y or y_bottom < vr.position.y: return
		var fi: int = _tree_wave(k + str(x), x + fw / 2.0)
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
	x = roundf(x / PK) * PK                   # on the 2-px grid
	if x > vr.end.x or x + w * s < vr.position.x or y_bottom - h * s > vr.end.y or y_bottom < vr.position.y: return
	var t := Time.get_ticks_msec() / 1000.0
	var g: float = 0.6 + life.gust * 0.8
	var cut := floorf(h * 0.72)
	var y0 := -h + sk
	draw_set_transform(Vector2(x + (w * s if flip else 0.0), y_bottom), 0.0, Vector2(-s if flip else s, s))
	var r := 0.0
	while r < h:
		var u := maxf(0.0, 1.0 - r / cut)
		# whole cells only (owner 2026-11-08: "깨지지 않고 들어가는지"): a 1-px shift broke the 2-px grid
		var o := roundf(sin(t * 1.6 + ph + r * 0.06) * amp * u * g + sin(t * 0.55 + ph) * amp * 0.5 * u) * PK if r < cut else 0.0
		var rh := minf(2.0, h - r)
		draw_texture_rect_region(im, Rect2(o, y0 + r, w, rh), Rect2(0, r, w, rh))
		r += 2.0
	draw_set_transform(Vector2.ZERO)

## street lamp: the banner under the arm flutters, more in a gust
## the lantern's glass lit full at night (owner 2026-11-08: "가로등 등 안에 지금 점 하나 들어있음. 꽉 채우기"): the
## panes in the cream ramp's top three steps, hot low in the middle; the night's dark leaves them alone (amb_light glass)
const GLASS_TEX := preload("res://assets/town/q_lamp_glass.png")
const GLASS_AT := Vector2(76.0, 80.0)          # the panes on q_lamp_base (20 x 26 px)
var glass_on := false
var glass_r: Array = []                         # where the lit panes are drawn (world rects), for the ambient shader
func _lamp(x: float, surf: float, vr: Rect2, ci: CanvasItem = null) -> void:
	if ci == null: ci = self
	var lv := sun_side()
	var base: Texture2D = lit_tex.get("q_lamp_base" + lv, hx.get("q_lamp_base", tex["q_lamp_base"]))
	var ban: Texture2D = hx.get("q_lamp_ban", tex["q_lamp_ban"])
	x = roundf(x)
	if lv == "_n" and lit_tex.has("q_lamp_base_n_" + str(int(x))): base = lit_tex["q_lamp_base_n_" + str(int(x))]
	if x > vr.end.x or x + base.get_width() < vr.position.x: return
	var y := roundf(surf - base.get_height() + setdown("q_lamp_base"))
	if glass_on and glass_r.size() < 8: glass_r.append(Vector4(x + GLASS_AT.x, y + GLASS_AT.y, x + GLASS_AT.x + 20.0, y + GLASS_AT.y + 26.0))
	if sh_tex.has("q_lamp_base"): sh_place("q_lamp_base", x, y, ci)
	ci.draw_texture(lit_ct("q_lamp_base", base), Vector2(x, y))
	if glass_on: ci.draw_texture(GLASS_TEX, Vector2(x, y) + GLASS_AT)
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
	var x := roundf(b[1])
	var vr: Rect2 = arena.view_rect()
	if x > vr.end.x + 20.0 or x + 480.0 < vr.position.x: return
	_spr("g_wagon2", x, b[2], b[3])
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
