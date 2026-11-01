extends Node2D
## 길드 본관 (interior), one map per floor:
##   1F: living room | lobby (front door, reception counter, stairs up) | board corridor, dining, kitchen
##   2F: library | stair hall (stairwell down, stairs up) | guest rooms      3F: members' corridor      attic: the locked master room
## Ported from the prototype's hall.js (HFL / hwall / hallBays / hprop / hallRamp / hpart / hallSun / hcurtains / hallLights / HDOORS).
## Art: assets/hall, 1 art px = 2 world px. The back wall is built from bays (window / plain); anything hung on or set against
## the wall gets a plain bay behind it.

const LITS := preload("res://scripts/lit.gd")
const HD := preload("res://scripts/hall_data.gd")
const TLIFE := preload("res://scripts/town_life.gd")
const SK := preload("res://scripts/skins.gd")
const PLASTER := Color(186 / 255.0, 162 / 255.0, 135 / 255.0)
## the sky behind the windows: day / dusk / night pictures cross-fade with the hour
const HSKY := [[0.0, "night"], [4.6, "night"], [5.9, "dusk"], [7.6, "day"], [16.2, "day"], [17.6, "dusk"], [18.9, "dusk"], [20.3, "night"], [24.0, "night"]]
const SKYC := {"day": [150, 200, 245], "dusk": [240, 150, 120], "night": [40, 50, 110]}

var kind := "hall"
var arena
var fl := 0
var F: Dictionary
var W := 3540.0
var G := 430.0
var C := -50.0
var tex := {}
var flames: Array = []
var bays: Array = []
var ramps: Array = []
var landing = null
var open := {}
var odir := {}
var draft = null
var px := 0.0
var near_door = null
var doors: Array = []
var lit                       # lit.gd: ambient multiply and the shaped lights (hallLights through lightShape)
var ldefs: Array = []         # the lights: {k, x, y, gy, r, a, c, ph}
var front: Node2D
var lbl_layer: CanvasLayer
var labels: Node2D
var glow: Node2D
var light_tex: GradientTexture2D
var chand_light = null        # the chandelier's light dict (it swings)
var sun := 0.0
var wr = null
var tfx: Array = []
var motes: Array = []
var adust: Array = []
var emit_t := {}
var arch_o := {}
var hatch := false
var snd_f := -1
var snd_on := true
var snd_vy := 0.0
## hall life (hallLifeUpd / hallLifeDraw / hcat)
const HJIG := ["barrel", "chairA", "chairB", "chS", "chF", "chB", "armS", "stool", "plant", "ivy", "kettle", "coat", "catbed", "pot", "bread", "candle", "candela", "armchair", "libladder", "desk", "table", "sofa"]
var jig := {}                 # prop index -> 0..1 (struck: it rocks and hops)
var jcd := {}
var jx := Transform2D.IDENTITY   # the jig transform hi() draws under
var drops: Array = []         # bread rolled off the table: {x, y, vx, vy, t}
var moths: Array = []         # {l (light dict), ph, r, t, life}
var mouse = null              # the attic mouse: {x, dir, st: run|sniff|flee, t, stop}
var mouse_t := 3000.0
var cat := {"st": "sleep", "t": 0.0, "dir": 1.0, "z": 0.0}
var dust_f := -1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = preload("res://scripts/player.gd").pix_mat_marked()     # 캐릭터 도트화 for Eilin drawn among the props
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -5
	G = arena.ground_y
	C = G - HD.RH
	F = HD.floors()[fl]
	W = F["W"]
	for f in DirAccess.get_files_at("res://assets/hall"):
		var k := f.replace(".import", "").get_basename()
		if not tex.has(k): tex[k] = load("res://assets/hall/" + k + ".png")
	for i in 4:
		flames.append(load("res://assets/cave/flame%d.png" % i))
	wr = _win_rect()
	bays = _bays()
	if F.has("stair"):
		var s: float = F["stair"]
		ramps = [{"ramp": true, "x0": s + HD.SR[0], "y0": HD.LANDY, "x1": s + HD.SR[1], "y1": G}]
		landing = {"x0": s, "x1": s + HD.SR[0], "y": HD.LANDY}
	for d in HD.doors():
		if d["fl"] == fl: doors.append(d)
	px = arena.player.position.x
	light_tex = GradientTexture2D.new()
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	light_tex.gradient = gr
	lit = preload("res://scripts/lit.gd").new(arena)
	lit.attach()
	# additive pass: sunlight through the windows, dust motes in it
	glow = Node2D.new()
	glow.z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.draw.connect(_draw_glow)
	add_child(glow)
	front = Node2D.new()
	front.z_index = 8
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.draw.connect(_draw_front)
	front.material = material
	arena.add_child(front)
	# prompts and her speech bubble ride the camera on their own canvas so the evening ambient doesn't dim them
	lbl_layer = CanvasLayer.new()
	lbl_layer.follow_viewport_enabled = true
	arena.add_child(lbl_layer)
	arena.move_child(lbl_layer, 0)
	labels = Node2D.new()
	labels.draw.connect(_draw_labels)
	lbl_layer.add_child(labels)
	_build_lights()

func cleanup() -> void:
	lit.cleanup()
	front.queue_free()
	lbl_layer.queue_free()
	queue_free()


# ---------- helpers ----------
func HW(k: String) -> float:
	return tex[k].get_width() * 2.0 if tex.has(k) else 0.0

func HH(k: String) -> float:
	return tex[k].get_height() * 2.0 if tex.has(k) else 0.0

func prop_w(k: String) -> float:
	return 96.0 if k == "arch" else HW(k)

## a hall sprite at 2x, bottom-anchored; clip = optional world rect
## a prop's picture through CSS filter brightness(.45) saturate(.6), made once
var _dim := {}
func dim_tex(k: String) -> Texture2D:
	if not _dim.has(k):
		var im: Image = (tex[k] as Texture2D).get_image()
		_dim[k] = ImageTexture.create_from_image(dim_image(im, 0.45, 0.6)) if im != null and not im.is_empty() else tex[k]
	return _dim[k]

static func dim_image(src: Image, br: float, sat: float) -> Image:
	var im := src.duplicate() as Image
	if im.is_compressed(): im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	var s := sat
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a <= 0.0: continue
			var r := c.r * br
			var g := c.g * br
			var b := c.b * br
			im.set_pixel(x, y, Color(clampf((0.213 + 0.787 * s) * r + (0.715 - 0.715 * s) * g + (0.072 - 0.072 * s) * b, 0.0, 1.0),
				clampf((0.213 - 0.213 * s) * r + (0.715 + 0.285 * s) * g + (0.072 - 0.072 * s) * b, 0.0, 1.0),
				clampf((0.213 - 0.213 * s) * r + (0.715 - 0.715 * s) * g + (0.072 + 0.928 * s) * b, 0.0, 1.0), c.a))
	return im

func hi(ci: CanvasItem, k: String, x: float, yb: float, flip := false, clip := Rect2(), mod := Color.WHITE) -> void:
	if not tex.has(k): return
	var t: Texture2D = tex[k]
	var w := t.get_width() * 2.0
	var h := t.get_height() * 2.0
	var vr: Rect2 = arena.view_rect()
	if x + w < vr.position.x - 60.0 or x > vr.end.x + 60.0: return
	var dst := Rect2(roundf(x), roundf(yb - h), w, h)
	if flip:
		ci.draw_set_transform_matrix(jx * Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2(dst.position.x + w, dst.position.y)))
		ci.draw_texture_rect(t, Rect2(0, 0, w, h), false, mod)
		ci.draw_set_transform_matrix(jx)
		return
	if clip.has_area():
		var c := dst.intersection(clip)
		if not c.has_area(): return
		var src := Rect2((c.position - dst.position) / 2.0, c.size / 2.0)
		ci.draw_texture_rect_region(t, c, src, mod)
		return
	ci.draw_texture_rect(t, dst, false, mod)

## a hall texture tiled at 2x over a world rect, the pattern anchored at (ox, oy)
func hfill(ci: CanvasItem, k: String, x: float, y: float, w: float, h: float, ox := 0.0, oy := 0.0, mod := Color.WHITE) -> void:
	if not tex.has(k) or w <= 0.0 or h <= 0.0: return
	ci.draw_texture_rect_region(tex[k], Rect2(x, y, w, h), Rect2((x - ox) / 2.0, (y - oy) / 2.0, w / 2.0, h / 2.0), mod, false, false)

func cam_x() -> float:
	return arena.view_rect().position.x

func vw() -> float:
	return arena.view_rect().size.x

## the window glass in a bay (transparent pixels of bayW), world px from the bay's left / floor
func _win_rect() -> Variant:
	var im: Image = tex["bayW"].get_image()
	if im.is_compressed(): im.decompress()
	var x0 := 100000
	var x1 := -1
	var y0 := 100000
	var y1 := -1
	for yy in im.get_height():
		for xx in im.get_width():
			if im.get_pixel(xx, yy).a < 20.0 / 255.0:
				x0 = mini(x0, xx)
				x1 = maxi(x1, xx)
				y0 = mini(y0, yy)
				y1 = maxi(y1, yy)
	if x1 < 0: return null
	return {"x0": x0 * 2.0, "x1": (x1 + 1) * 2.0, "top": (im.get_height() - y0) * 2.0, "bot": (im.get_height() - y1 - 1) * 2.0}

func _bays() -> Array:
	if F.get("gable", false): return []
	var walls := []
	for p in F["props"]:
		if String(p[4]).contains("w"): walls.append([p[1] - 6.0, p[1] + prop_w(p[0]) + 6.0])
	for wx in F.get("walls", []):
		walls.append([wx - 40.0, wx + 40.0])
	var L := []
	for r in F["rooms"]:
		var x0: float = r[0]
		var x1: float = r[1]
		var st := x0
		if r.size() > 2:
			var g: float = r[2]
			st = g - ceilf((g - x0) / HD.HBAY) * HD.HBAY
		var x := st
		while x < x1:
			var plain := false
			for wsp in walls:
				if wsp[0] < x + HD.HBAY and wsp[1] > x:
					plain = true
					break
			L.append([x, plain, x0, x1])
			x += HD.HBAY
	return L


# ---------- time of day ----------
func hsky_mix() -> Array:
	var h := fposmod(arena.tod_h, 24.0)
	var i := 0
	while i < HSKY.size() - 2 and HSKY[i + 1][0] <= h: i += 1
	var a: Array = HSKY[i]
	var b: Array = HSKY[i + 1]
	var t: float = (h - a[0]) / maxf(0.001, b[0] - a[0])
	return [[a[1], 1.0]] if a[1] == b[1] else [[a[1], 1.0], [b[1], t]]

func hsky() -> Array:
	var M := hsky_mix()
	var c: Array = SKYC[M[0][0]].duplicate()
	if M.size() > 1:
		var c2: Array = SKYC[M[1][0]]
		for j in 3: c[j] = roundf(c[j] + (c2[j] - c[j]) * M[1][1])
	return c

## indoors: the outdoor ambient a little darker but never black, the lamps always lit
func tod_now() -> Dictionary:
	var T: Dictionary = arena.tod_now()
	sun = T["sun"]
	var amb: Color = T["amb"]
	return {"amb": Color(maxf(0.3, amb.r * 0.86), maxf(0.3, amb.g * 0.86), maxf(0.3, amb.b * 0.86)), "lamp": maxf(T["lamp"], 0.55), "sky": T["sky"]}


# ---------- lights ----------
func _add_light(p: Vector2, r: float, col: Color, a: float, kind_: String, gy := 0.0, fac := "") -> Dictionary:
	var l := {"k": kind_, "x": p.x, "y": p.y, "gy": gy, "r": r, "a0": a, "a": a, "c": col, "ph": float(ldefs.size())}
	if fac != "": l["fac"] = fac
	ldefs.append(l)
	return l

func _build_lights() -> void:
	for p in F["props"]:
		var k: String = p[0]
		var x: float = p[1]
		var y := HD.prop_y(p)
		var w := HW(k)
		match k:
			"fire": _add_light(Vector2(x + 96.0, y - 40.0), 240.0, Color8(255, 140, 60), 1.1, "fire", y, "fire")
			"hearth": _add_light(Vector2(x + 89.0, y - 30.0), 200.0, Color8(255, 140, 60), 1.0, "fire", y, "hearth")
			"sconce": _add_light(Vector2(x + w / 2.0, y - HH(k) * 0.7), 120.0, Color8(255, 200, 120), 0.8, "soft")
			"candela": _add_light(Vector2(x + w / 2.0, y - HH(k) + 14.0), 110.0, Color8(255, 214, 140), 0.75, "soft")
			"candle": _add_light(Vector2(x + w / 2.0, y - HH(k) + 4.0), 90.0, Color8(255, 214, 140), 0.7, "soft")
			"door3": _add_light(Vector2(x + w / 2.0, y - 80.0), 100.0, Color8(87, 211, 194), 0.7, "soft")
	if fl == 0:
		chand_light = _add_light(Vector2(2020.0, C + 190.0), 330.0, Color8(255, 220, 150), 0.9, "soft")
		chand_light["chand"] = true
		chand_light["fac"] = "chand"
	# the windows' daylight glow is drawn in the additive pass (_draw_glow)

## hFac: a facility the guild has restored (the fireplace, the kitchen hearth, the lobby chandelier); always on
## when the fame system is not there
func hfac(id: String) -> bool:
	return arena.fame == null or arena.fame.fac_ok(id)

## rimLights in the hall: its own lights as they are
func rim_lights() -> Array:
	return lit.rim_lights()

func chand_a() -> float:
	var t := Time.get_ticks_msec() / 1000.0
	var k := 0.0
	if draft != null: k = draft["v"] * maxf(0.0, 1.0 - absf(2020.0 - draft["x"]) / 800.0)
	return 0.016 * sin(t * 0.9) + 0.006 * sin(t * 2.3 + 1.0) + 0.03 * k * sin(t * 3.1)


# ---------- surfaces: floor, the landing (one-way) and the stair ramp ----------
func ramp_y(r: Dictionary, x: float) -> float:
	return r["y0"] + (r["y1"] - r["y0"]) * (x - r["x0"]) / (r["x1"] - r["x0"])

## stairs: up at either end steps on; once on, you follow the slope until you walk off an end (jumping lets go)
func land(P, prev_x: float, dt: float) -> bool:
	var prev_y: float = P.position.y - P.vy * dt
	var x: float = P.position.x
	if P.plat != null and P.plat.has("ramp"):
		var r: Dictionary = P.plat
		if P.vy < 0.0:
			P.plat = null
			return false
		if x < r["x0"] or x > r["x1"]:
			P.plat = null
			var yy: float = r["y0"] if x < r["x0"] else r["y1"]
			if absf(P.position.y - yy) < 16.0:
				P.position.y = yy
				if landing != null and yy == landing["y"]: P.plat = landing
				return true
			return false
		P.position.y = ramp_y(r, x)
		return true
	for r in ramps:
		if x < r["x0"] - 2.0 or x > r["x1"] + 2.0: continue
		var ry := ramp_y(r, clampf(x, r["x0"], r["x1"]))
		if P.on and P.keys["up"] and absf(P.position.y - ry) < 22.0:
			P.plat = r
			P.position.y = ry
			return true
		if not P.on and P.vy >= 0.0 and prev_y <= ry + 1.0 and P.position.y >= ry and not P.keys["down"]:
			P.plat = r
			P.position.y = ry
			return true
	if P.vy >= 0.0:
		if landing != null and x >= landing["x0"] - 2.0 and x <= landing["x1"] + 2.0:
			var ly: float = landing["y"]
			if P.on and P.plat == landing:
				P.position.y = ly
				return true
			if P.drop_t <= 0.0 and prev_y <= ly + 1.0 and P.position.y >= ly - 0.5:
				P.position.y = ly
				P.plat = landing
				return true
		if P.position.y >= G - 0.5:
			P.position.y = G
			P.plat = null
			return true
	P.plat = null
	return false

func support_span(x: float, y: float) -> Variant:
	if absf(y - G) < 3.0: return [-1e9, 1e9]
	if landing != null and absf(y - landing["y"]) < 3.0 and x > landing["x0"] - 2.0 and x < landing["x1"] + 40.0: return [-1e9, 1e9]
	for r in ramps:
		if x >= r["x0"] - 2.0 and x <= r["x1"] + 2.0: return [-1e9, 1e9]
	return null

func floor_at(_x: float) -> float:
	return G

func stair_hint() -> bool:
	var P = arena.player
	if (P.plat != null and P.plat.has("ramp")) or not P.on or near_door != null: return false
	for r in ramps:
		if absf(P.position.x - r["x1"]) < 40.0 and absf(P.position.y - r["y1"]) < 4.0: return true
		if absf(P.position.x - r["x0"]) < 40.0 and absf(P.position.y - r["y0"]) < 4.0: return true
	return false


# ---------- step ----------
func step(dt: float) -> void:
	var T := tod_now()
	var tt := Time.get_ticks_msec() / 1000.0
	if chand_light != null:
		var ang := chand_a()
		var pv := C + 24.0 + HH("chain") * 0.6 - HH("chain")
		var ln := C + 190.0 - pv
		chand_light["x"] = 2020.0 + sin(ang) * ln
		chand_light["y"] = pv + cos(ang) * ln
	for l in ldefs:
		var a0: float = l["a0"]
		var ph: float = l["ph"]
		l["a"] = a0 * (LITS.fl(tt, ph) if l["k"] == "fire" or l.has("chand") else 1.0)
		l["boost"] = T["lamp"]
		if l["k"] == "soft" and draft != null and absf(l["x"] - draft["x"]) < 600.0:
			var k: float = draft["v"] * (1.0 - absf(l["x"] - draft["x"]) / 600.0)
			l["a"] *= 1.0 - 0.35 * k * (0.5 + 0.5 * sin(tt * 31.0 + l["x"]))
	lit.L = ldefs.filter(func(l): return not l.has("fac") or hfac(l["fac"]))
	lit.amb = T["amb"]
	lit.redraw()
	var P = arena.player
	var E = arena.eil
	var eh: bool = E.here() and E.wait <= 0.0
	# partition walls: the door swings open by itself as you walk up to it and shuts behind you; a shut door blocks
	for wx in F.get("walls", []):
		var k := "%d:%d" % [fl, int(wx)]
		var d := absf(P.position.x - wx)
		if eh: d = minf(d, absf(E.x - wx))
		var o: float = open.get(k, 0.0)
		var want := 1 if d < 90.0 else (0 if d > 130.0 else (1 if o > 0.5 else 0))
		var n := clampf(o + (1.0 if want == 1 else -1.0) * dt / 180.0, 0.0, 1.0)
		if n > 0.0 and o == 0.0:
			arena.sfx("ready", 0.18)
			odir[k] = 1 if P.position.x < wx else -1
			draft = {"v": 1.0, "dir": 1 if P.position.x < wx else -1, "x": wx}
		open[k] = n
		if n < 0.6 or P.position.y < G - 40.0:
			if px <= wx and P.position.x > wx - 16.0:
				P.position.x = wx - 16.0
				P.vx = 0.0
			elif px >= wx and P.position.x < wx + 16.0:
				P.position.x = wx + 16.0
				P.vx = 0.0
	px = P.position.x
	# boards creak under your feet; the stairs thud (환경음)
	var AM = arena.get("amb")
	if AM != null:
		var stp: bool = P.on and P.anim == "run" and P.f != snd_f and P.f in P.SK.steps(P.who, "run")
		snd_f = P.f
		if stp:
			if P.plat != null and P.plat.has("ramp"): AM.hsnd(95.0, 55.0, 0.12, 0.06, "sine", 0.7)
			elif randf() < 0.14: AM.creak()
		if P.on and not snd_on and snd_vy > 0.5:
			AM.hsnd(80.0, 45.0, 0.18, 0.08, "sine", 0.7)
			if randf() < 0.5: AM.creak()
		snd_on = P.on
		snd_vy = P.vy
	if draft != null:
		draft["v"] *= pow(0.9982, dt)
		if draft["v"] < 0.02: draft = null
	# the landing arch's double door opens as someone steps up to it
	for i in F["props"].size():
		var p: Array = F["props"][i]
		if p[0] != "arch": continue
		var ax: float = p[1] + 48.0
		var ay := HD.prop_y(p)
		var wnt := (absf(P.position.x - ax) < 120.0 and absf(P.position.y - ay) < 60.0) or (eh and absf(E.x - ax) < 110.0 and absf(E.y - ay) < 60.0)
		var o2: float = arch_o.get(i, 0.0)
		if wnt and o2 == 0.0: arena.sfx("ready", 0.15)
		arch_o[i] = clampf(o2 + (1.0 if wnt else -1.0) * dt / 260.0, 0.0, 1.0)
	_life(dt, P, AM)
	# doors
	near_door = null
	if P.on and not P.attacking():
		var best := 1e9
		for d in doors:
			var dx := absf(P.position.x - d["x"])
			if dx < d["r"] and absf(P.position.y - d["y"]) < 6.0 and dx < best:
				near_door = d
				best = dx
		if near_door == null:
			near_door = E.door_near(P)
	_fx(dt)
	queue_redraw()
	glow.queue_redraw()
	front.queue_redraw()
	labels.queue_redraw()

## hallLifeUpd: struck props jump (a pot clinks), the bread can roll off, footstep dust, moths at the lamps after dark,
## the attic mouse, the cat on its cushion
func _life(dt: float, P, AM) -> void:
	var t := float(Time.get_ticks_msec())
	if P.on and P.anim == "run" and P.f != dust_f and P.f in P.SK.steps(P.who, "run"): TLIFE.puff(arena, P.position.x - P.dir * 8.0, P.position.y, 2)
	dust_f = P.f
	var at = P.cur_atk() if P.attacking() else null
	if at != null and P.f >= at["hit"][0] and P.f <= at["hit"][1]:
		var b: Array = at["box"]
		var bw: float = b[2] * P.CSCALE * P.MELEE_K
		var bx: float = P.position.x + b[0] * P.CSCALE * P.MELEE_K if P.dir > 0 else P.position.x - b[0] * P.CSCALE * P.MELEE_K - bw
		var by: float = P.position.y + b[1] * P.CSCALE
		var bh: float = b[3] * P.CSCALE
		for i in F["props"].size():
			var p: Array = F["props"][i]
			var k: String = p[0]
			if not HJIG.has(k) or jcd.get(i, 0.0) > t: continue
			var x0: float = p[1]
			var w := HW(k)
			var yb := HD.prop_y(p)
			var y0 := yb - HH(k)
			if bx < x0 + w and bx + bw > x0 and by < yb and by + bh > y0:
				strike(i, P.dir)
	for i in jig.keys():
		jig[i] = jig[i] * pow(0.99, dt) if jig[i] > 0.02 else 0.0
		if jig[i] <= 0.0: jig.erase(i)
	for a in drops:
		a["t"] += dt
		a["vy"] += 0.0016 * dt
		a["x"] += a["vx"] * dt
		a["y"] += a["vy"] * dt
		if a["y"] > G - 3.0:
			a["y"] = G - 3.0
			a["vy"] = -a["vy"] * 0.3
			a["vx"] *= 0.9
			if absf(a["vy"]) < 0.03: a["vy"] = 0.0
	drops = drops.filter(func(a): return a["t"] < 7000.0)
	# moths find the soft lamps after dark
	var nk: float = night_k()
	var vr: Rect2 = arena.view_rect()
	if nk > 0.4 and moths.size() < 5 and randf() < dt / 1500.0:
		var Ls: Array = lit.L.filter(func(l): return l["k"] == "soft" and l["x"] > vr.position.x - 100.0 and l["x"] < vr.end.x + 100.0)
		if Ls.size() > 0:
			moths.append({"l": Ls[randi() % Ls.size()], "ph": randf() * 9.0, "r": 12.0 + randf() * 14.0, "t": 0.0, "life": 9000.0 + randf() * 9000.0})
	for m in moths: m["t"] += dt
	moths = moths.filter(func(m): return m["t"] < m["life"] and nk > 0.3)
	# the attic mouse: runs along the floor, may stop to sniff, flees with a squeak when you come within 150 px
	if F.get("gable", false):
		var x0: float = F["rooms"][0][0]
		var x1: float = F["rooms"][0][1]
		if mouse == null:
			mouse_t -= dt
			if mouse_t <= 0.0:
				var dir := 1.0 if randf() < 0.5 else -1.0
				mouse = {"x": x0 + 10.0 if dir > 0.0 else x1 - 10.0, "dir": dir, "st": "run", "t": 0.0, "stop": x0 + 150.0 + randf() * (x1 - x0 - 300.0) if randf() < 0.6 else null}
				mouse_t = 7000.0 + randf() * 9000.0
		else:
			var ms: Dictionary = mouse
			ms["t"] += dt
			if absf(P.position.x - ms["x"]) < 150.0 and ms["st"] != "flee":
				ms["st"] = "flee"
				ms["dir"] = 1.0 if P.position.x < ms["x"] else -1.0
				if AM != null: AM.hsnd(3200.0, 2600.0, 0.06, 0.012, "square", 5.0)
			if ms["st"] == "run" and ms["stop"] != null and absf(ms["x"] - ms["stop"]) < 6.0:
				ms["st"] = "sniff"
				ms["t"] = 0.0
				ms["stop"] = null
			if ms["st"] == "sniff":
				if ms["t"] > 1200.0 + randf() * 30.0: ms["st"] = "run"
			else:
				ms["x"] += ms["dir"] * (0.42 if ms["st"] == "flee" else 0.22) * dt
			if ms["x"] < x0 - 20.0 or ms["x"] > x1 + 20.0: mouse = null
	# the cat on its cushion: sits up and watches within 130 px, curls up again once you are 200 px off
	for p in F["props"]:
		if p[0] != "catbed": continue
		var cx: float = p[1] + 28.0
		var d := absf(P.position.x - cx)
		cat["t"] += dt
		cat["z"] += dt
		if d < 130.0 and cat["st"] == "sleep":
			cat["st"] = "sit"
			cat["t"] = 0.0
		elif d > 200.0 and cat["st"] == "sit" and cat["t"] > 2500.0:
			cat["st"] = "sleep"
			cat["t"] = 0.0
		cat["dir"] = -1.0 if P.position.x < cx else 1.0

## a struck prop jumps; a pot clinks; the bread (or something off the table) may roll off
func strike(i: int, dir: int) -> void:
	var p: Array = F["props"][i]
	var k: String = p[0]
	var x0: float = p[1]
	var w := HW(k)
	var yb := HD.prop_y(p)
	jig[i] = 1.0
	jcd[i] = Time.get_ticks_msec() + 380.0
	arena.sfx("guard", 0.35 if k == "pot" else 0.22)
	var AM = arena.get("amb")
	if k == "pot" and AM != null: AM.hsnd(900.0, 880.0, 0.4, 0.03, "triangle", 2.0)
	TLIFE.puff(arena, x0 + w / 2.0, yb, 3)
	if (k == "bread" or k == "table") and randf() < 0.45:
		drops.append({"x": x0 + w / 2.0, "y": yb - HH(k) + 4.0, "vx": dir * (0.08 + randf() * 0.1), "vy": -0.32 - randf() * 0.15, "t": 0.0})

## nightK: 0 by day .. 1 at night (the world sky's alpha)
func night_k() -> float:
	var T: Dictionary = arena.tod_now()
	var sky: Color = T["sky"]
	return clampf((sky.a - 0.33) / 0.33, 0.0, 1.0)

## where the fires are on this floor (ambience.gd crackle)
func fire_xs() -> Array:
	var o := []
	for p in F["props"]:
		if p[0] == "fire" or p[0] == "hearth": o.append(float(p[1]))
	return o

## the grandfather clock's x on this floor, or null
func clock_x() -> Variant:
	for p in F["props"]:
		if p[0] == "clock": return float(p[1])
	return null

func _emit(id: String, every: float, dt: float, fn: Callable) -> void:
	emit_t[id] = emit_t.get(id, 0.0) + dt
	while emit_t[id] > every:
		emit_t[id] -= every
		fn.call()

## embers off the fires, candle wisps, the kettle's steam, dust drifting in the window light, attic dust
func _fx(dt: float) -> void:
	var vr: Rect2 = arena.view_rect()
	var VX0 := vr.position.x - 200.0
	var VX1 := vr.end.x + 200.0
	for p in F["props"]:
		var k: String = p[0]
		var x: float = p[1]
		if x < VX0 or x > VX1: continue
		var y := HD.prop_y(p)
		if (k == "fire" or k == "hearth") and hfac(k):
			var cx := x + (96.0 if k == "fire" else 89.0)
			var cy := y - (30.0 if k == "fire" else 22.0)
			var ww := 50.0 if k == "fire" else 34.0
			_emit("emb%d" % int(x), 140.0 if k == "fire" else 200.0, dt, func(): tfx.append({"k": "ember", "x": cx + (randf() - 0.5) * ww, "y": cy, "vx": (randf() - 0.5) * 0.03, "vy": -0.05 - randf() * 0.04, "t": 0.0, "life": 700.0 + randf() * 700.0}))
		elif k == "kettle":
			var kx := x + HW(k) - 4.0
			var ky := y - HH(k) + 12.0
			_emit("ket%d" % int(x), 520.0, dt, func(): tfx.append({"k": "smoke", "x": kx + (randf() - 0.5) * 6.0, "y": ky, "vx": 0.006, "vy": -0.03 - randf() * 0.012, "s": 5.0 * (0.7 + randf() * 0.4), "t": 0.0, "life": 2600.0 + randf() * 900.0}))
		elif k == "candle" or k == "candela":
			var wx2 := x + HW(k) / 2.0
			var wy := y - HH(k) - (2.0 if k == "candle" else -8.0)
			_emit("cw%d" % int(x), 1400.0, dt, func(): tfx.append({"k": "smoke", "x": wx2 + (randf() - 0.5) * 6.0, "y": wy, "vx": 0.006, "vy": -0.03 - randf() * 0.012, "s": 3.0 * (0.7 + randf() * 0.4), "t": 0.0, "life": 2600.0 + randf() * 900.0}))
	for f in tfx:
		f["t"] += dt
		var dx: float = f["vx"]
		if f["k"] == "smoke" and draft != null and absf(f["x"] - draft["x"]) < 700.0: dx += draft["dir"] * 0.05 * draft["v"]
		f["x"] += dx * dt
		f["y"] += f["vy"] * dt
	tfx = tfx.filter(func(f): return f["t"] < f["life"])
	# dust motes: only where daylight comes in
	if sun > 0.08 and not F.get("gable", false) and motes.size() < 45 and randf() < dt / 55.0:
		var vis := bays.filter(func(b): return not b[1] and b[0] + HD.HBAY > vr.position.x and b[0] < vr.end.x)
		if vis.size() > 0:
			var b: Array = vis[randi() % vis.size()]
			motes.append({"x": b[0] + 20.0 + randf() * (HD.HBAY - 40.0), "y": G - 30.0 - randf() * 220.0, "ph": randf() * 9.0, "t": 0.0, "life": 5000.0 + randf() * 4000.0})
	var P = arena.player
	for m in motes:
		m["t"] += dt
		m["x"] += (sin(m["t"] / 1700.0 + m["ph"]) * 0.006 + 0.004) * dt
		m["y"] += (sin(m["t"] / 1300.0 + m["ph"] * 2.0) * 0.005 - 0.002) * dt
		if absf(P.position.x - m["x"]) < 40.0 and absf(P.position.y - 60.0 - m["y"]) < 70.0 and absf(P.vx) > 0.1:
			m["x"] += signf(m["x"] - P.position.x) * 0.05 * dt
			m["y"] -= 0.02 * dt
		if draft != null and absf(m["x"] - draft["x"]) < 600.0: m["x"] += draft["dir"] * 0.04 * draft["v"] * dt
	motes = motes.filter(func(m): return m["t"] < m["life"] and m["x"] > vr.position.x - 100.0 and m["x"] < vr.end.x + 100.0)
	# the attic: dust sifting from the rafters
	if F.get("gable", false):
		var x0: float = F["rooms"][0][0]
		var x1: float = F["rooms"][0][1]
		if adust.size() < 40 and randf() < dt / 260.0:
			var ax := x0 + 40.0 + randf() * (x1 - x0 - 80.0)
			adust.append({"x": ax, "y": roof_y(ax) + 16.0, "ph": randf() * 9.0, "t": 0.0, "v": 0.012 + randf() * 0.02})
		for d in adust:
			d["t"] += dt
			d["y"] += d["v"] * dt
			d["x"] += sin(d["t"] / 700.0 + d["ph"]) * 0.01 * dt
		adust = adust.filter(func(d): return d["y"] < G - 2.0)

func roof_y(x: float) -> float:
	var x0: float = F["rooms"][0][0]
	var x1: float = F["rooms"][0][1]
	var mid := (x0 + x1) / 2.0
	if x < mid: return G - 150.0 + (C - 10.0 - (G - 150.0)) * (x - x0) / (mid - x0)
	return C - 10.0 + (G - 150.0 - (C - 10.0)) * (x - mid) / (x1 - mid)


# ---------- interaction ----------
func try_interact() -> bool:
	if near_door == null:
		return false
	var d = near_door
	var P = arena.player
	var E = arena.eil
	match d["act"]:
		"town":
			arena.sfx("ready", 0.6)
			arena.fade_then(func(): arena.go_town(Vector2(E.HDOOR, E.TTOP), 1))
		"go":
			var to: Array = d["to"]
			arena.sfx("ready", 0.5)
			arena.fade_then(func(): arena.go_hall(to[0], Vector2(to[1], to[2]), 1))
		"counter":
			if E.at_desk(): E.talk()
			else: arena.text(P.position + Vector2(0, -170), "에일린 — " + E.desk_away(), Color("#bfeee6"))
		"eilin":
			E.talk()
		"locked":
			arena.sfx("guard", 0.4)
			arena.text(P.position + Vector2(0, -170), "잠겨 있다… 길드장의 방", Color("#bfeee6"))
		"board":
			arena.fame.open_book("gbk", "quest")      # fameOpen('quest')
		"party":
			arena.sortie.party_ui.show_it()           # openParty
		"library":
			arena.ui_root.menu.open_char(P.who)       # cxOpen(CHAR)
		"wardrobe":
			# 옷장 (fame_data FAC "wardrobe"): the end room of the 2nd-floor corridor, behind its odd door
			if arena.fame != null and not arena.fame.fac_ok("wardrobe"):
				arena.sfx("guard", 0.3)
				arena.text(P.position + Vector2(0, -140.0 * 1.3), "먼지 쌓인 옷장… 시설 복구가 필요하다", Color("#bfeee6"))
			else:
				arena.ui_root.menu.open_wardrobe()
		"room":
			if arena.fame != null and not arena.fame.fac_ok("rooms"):
				arena.sfx("guard", 0.3)
				arena.text(P.position + Vector2(0, -140.0 * 1.3), "먼지투성이 방… 시설 복구가 필요하다", Color("#bfeee6"))
			else:
				arena.ui_root.menu.open_char(d["c"])
		_:
			arena.sfx("guard", 0.4)
			arena.text(P.position + Vector2(0, -170), d["name"] + " — 준비 중", Color("#ffe9a8"))
	return true


# ---------- drawing ----------
func _draw() -> void:
	var vr: Rect2 = arena.view_rect()
	var VX0 := vr.position.x - 80.0
	var VX1 := vr.end.x + 80.0
	# the building's shell around the rooms
	var VY0 := vr.position.y - 20.0
	var VH := vr.size.y + 40.0
	hfill(self, "tex", VX0, VY0, VX1 - VX0, VH, 0.0, 0.0, Color(0.45, 0.45 * 0.96, 0.45 * 0.95))
	if F.get("gable", false): _gable()
	else: _wall()
	if F.has("well"): _well_back(F["well"][0], F["well"][1])
	_curtains()
	var E = arena.eil
	for p in F["props"]:
		var fg: String = p[4]
		if not (fg.contains("f") or fg.contains("r")): _prop(self, p)
	if E.here() and E.layer() == "free" and not E.hide:
		E.draw_on(self, roundf(E.x), roundf(E.y))
	if fl == 0:
		# a little doll on the counter for each member who has joined, in her worn costume's doll (skins.gd "doll")
		var ro: Array = arena.player.roster()
		for i in mini(3, ro.size()):
			var dt: Texture2D = SK.tex(ro[i], "doll")
			if dt != null: draw_texture_rect(dt, Rect2(roundf(1920.0 + i * 18.0), roundf(G - HH("counter") + 4.0 - dt.get_height() * 2.0), dt.get_width() * 2.0, dt.get_height() * 2.0), false)
	hfill(self, "top", 0.0, G, W, 30.0, 0.0, G)
	for p in F["props"]:
		if String(p[4]).contains("r"): _prop(self, p)
	for wx in F.get("walls", []):
		var k := "%d:%d" % [fl, int(wx)]
		_partition(wx, open.get(k, 0.0), odir.get(k, 1))
	# embers and wisps
	for f in tfx:
		var k2: float = f["t"] / f["life"]
		if f["k"] == "ember":
			draw_rect(Rect2(roundf(f["x"]), roundf(f["y"]), 2, 2), Color(1, 0.9, 0.64, 1.0 - k2) if k2 < 0.5 else Color(0.92, 0.48, 0.15, 1.0 - k2))
		else:
			var s: float = maxf(2.0, roundf(f["s"] * (0.5 + k2 * 1.4) / 2.0) * 2.0)
			var a: float = (k2 / 0.15 if k2 < 0.15 else 1.0 - (k2 - 0.15) / 0.85) * 0.35
			draw_rect(Rect2(roundf((f["x"] - s / 2.0) / 2.0) * 2.0, roundf((f["y"] - s / 2.0) / 2.0) * 2.0, s, s), Color(0.84, 0.8, 0.75, a))
	_life_draw()

## hallLifeDraw: the dropped bread, moths, attic dust, cobwebs and the mouse
func _life_draw() -> void:
	var t := float(Time.get_ticks_msec())
	var q := func(x: float, y: float, w: float, h: float, c: Color) -> void: draw_rect(Rect2(roundf(x / 2.0) * 2.0, roundf(y / 2.0) * 2.0, w, h), c)
	for a in drops:
		var al: float = 1.0 - (a["t"] - 6000.0) / 1000.0 if a["t"] > 6000.0 else 1.0
		q.call(a["x"] - 5.0, a["y"] - 5.0, 10.0, 6.0, Color(Color("#b07434"), al))
		q.call(a["x"] - 3.0, a["y"] - 5.0, 6.0, 2.0, Color(Color("#d9a35c"), al))
		q.call(a["x"] - 5.0, a["y"] - 1.0, 10.0, 2.0, Color(Color("#7a4a22"), al))
	for m in moths:
		var s: float = m["t"] / 1000.0
		var a: float = minf(1.0, minf(m["t"] / 600.0, (m["life"] - m["t"]) / 600.0))
		var l: Dictionary = m["l"]
		var x: float = l["x"] + cos(s * 2.3 + m["ph"]) * m["r"] + sin(s * 7.1 + m["ph"]) * 4.0
		var y: float = l["y"] + sin(s * 1.7 + m["ph"] * 2.0) * m["r"] * 0.6 + sin(s * 9.0) * 3.0
		q.call(x, y, 2.0, 2.0, Color(Color("#5a4a3a"), a))
		if int((t + m["ph"] * 100.0) / 70.0) % 2 == 1:
			q.call(x - 4.0, y - 2.0, 4.0, 2.0, Color(Color("#e8dcc0"), a))
			q.call(x + 2.0, y - 2.0, 4.0, 2.0, Color(Color("#e8dcc0"), a))
		else:
			q.call(x - 2.0, y - 4.0, 2.0, 2.0, Color(Color("#cfc2a4"), a))
			q.call(x + 2.0, y - 4.0, 2.0, 2.0, Color(Color("#cfc2a4"), a))
	if not F.get("gable", false): return
	for d in adust:
		draw_rect(Rect2(roundf(d["x"] / 2.0) * 2.0, roundf(d["y"] / 2.0) * 2.0, 2, 2), Color(200 / 255.0, 186 / 255.0, 160 / 255.0, 0.55))
	_cobwebs()
	if mouse != null:
		var ms: Dictionary = mouse
		var b := float(int(t / 150.0) % 2) if ms["st"] == "sniff" else float(int(t / 60.0) % 2)
		draw_set_transform(Vector2(roundf(ms["x"]), G), 0.0, Vector2(ms["dir"], 1.0))
		draw_rect(Rect2(-6, -6, 10, 6), Color("#6e6460"))
		draw_rect(Rect2(-4, -8, 6, 2), Color("#6e6460"))
		draw_rect(Rect2(4, -6 + b, 4, 4), Color("#6e6460"))
		draw_rect(Rect2(6, -4 + b, 2, 2), Color("#2a1a1a"))
		draw_rect(Rect2(2, -10, 2, 2), Color("#8a7f7a"))
		draw_rect(Rect2(-12, -4, 6, 2), Color("#9a7a7a"))
		draw_rect(Rect2(-14, -6, 2, 2), Color("#9a7a7a"))
		draw_rect(Rect2(-4, -2 + b, 2, 2), Color("#4a403c"))
		draw_rect(Rect2(2, -2 + (1.0 - b), 2, 2), Color("#4a403c"))
		draw_set_transform(Vector2.ZERO)

## the back wall of one room, bay by bay
func _wall() -> void:
	var LOW := HH("bayW")
	var BM := HH("beam")
	var vr: Rect2 = arena.view_rect()
	var VX0 := vr.position.x - 200.0
	var VX1 := vr.end.x + 200.0
	var M := hsky_mix()
	var cx := cam_x()
	for r in F["rooms"]:
		var x0: float = r[0]
		var x1: float = r[1]
		if x1 < VX0 or x0 > VX1: continue
		draw_rect(Rect2(x0, C, x1 - x0, G - LOW - C), PLASTER)
		for m in M:
			if m[1] <= 0.01: continue
			hfill(self, "sky_" + m[0], x0, G - LOW, x1 - x0, LOW, cx * 0.65, G - 80.0 - 300.0, Color(1, 1, 1, m[1]))
		_hwx(maxf(x0, VX0), minf(x1, VX1), G - LOW, LOW)
	var post: Texture2D = tex["post"]
	for b in bays:
		var x: float = b[0]
		if x + HD.HBAY < VX0 or x > VX1: continue
		var clip := Rect2(b[2], C, b[3] - b[2], HD.RH)
		hi(self, "bayP" if b[1] else "bayW", x, G, false, clip)
		hi(self, "beam", x, G - LOW, false, clip)
		hi(self, "beam", x, C + BM, false, clip)
		var pr := Rect2(x, C + BM, post.get_width() * 2.0, G - LOW - BM * 2.0 - C).intersection(clip)
		if pr.has_area(): draw_texture_rect_region(post, pr, Rect2(0, 0, post.get_width(), 1))
	for r in F["rooms"]:
		var x0: float = r[0]
		var x1: float = r[1]
		if x1 < VX0 or x0 > VX1: continue
		draw_texture_rect_region(post, Rect2(x1 - post.get_width() * 2.0, C, post.get_width() * 2.0, HD.RH), Rect2(0, 0, post.get_width(), 1))
		hfill(self, "under", x0, C, x1 - x0, 52.0, x0, C)

## hwx: the weather outside the windows: rain streaks / snow flakes on the sky band (the wall art covers all but the glass)
func _hwx(x0: float, x1: float, y0: float, h: float) -> void:
	var k: String = arena.weather
	if k != "rain" and k != "snow": return
	var band := Rect2(x0, y0, x1 - x0, h)
	draw_rect(band, Color(60 / 255.0, 70 / 255.0, 90 / 255.0, 0.28))
	var t := float(Time.get_ticks_msec())
	if k == "rain":
		var c := Color(210 / 255.0, 225 / 255.0, 245 / 255.0, 0.7)
		var x := floorf(x0 / 6.0) * 6.0
		while x < x1:
			for j in 2:
				var r := sin(x * 12.99 + j * 71.3) * 43758.5
				var u := r - floorf(r)
				var yy := y0 + fmod(t * (0.7 + u * 0.3) + u * 1900.0, h + 60.0) - 30.0
				var xx := x + roundf(((yy - y0) * 0.12) / 2.0) * 2.0
				var ry := roundf(yy / 2.0) * 2.0
				for rc in [Rect2(xx, ry, 2, 14), Rect2(xx + 2.0, ry + 14.0, 2, 6)]:
					var q: Rect2 = rc.intersection(band)
					if q.has_area(): draw_rect(q, c)
			x += 6.0
	else:
		var c2 := Color(245 / 255.0, 248 / 255.0, 1.0, 0.85)
		var x := floorf(x0 / 18.0) * 18.0
		while x < x1:
			var r := sin(x * 7.31) * 43758.5
			var u := r - floorf(r)
			var yy := y0 + fmod(t * (0.03 + u * 0.03) + u * 900.0, h + 20.0) - 10.0
			var xx := x + sin(t / 900.0 + u * 9.0) * 6.0
			var s := 4.0 if u > 0.7 else 2.0
			var q2 := Rect2(roundf(xx / 2.0) * 2.0, roundf(yy / 2.0) * 2.0, s, s).intersection(band)
			if q2.has_area(): draw_rect(q2, c2)
			x += 18.0

## the attic: a gabled room under the rafters
func _gable() -> void:
	var x0: float = F["rooms"][0][0]
	var x1: float = F["rooms"][0][1]
	var mid := (x0 + x1) / 2.0
	var pts := PackedVector2Array([Vector2(x0, G + 2.0), Vector2(x0, G - 150.0), Vector2(mid, C - 10.0), Vector2(x1, G - 150.0), Vector2(x1, G + 2.0)])
	var mw := HW("mwall")
	var oy := G - HH("mwall")
	var uvs := PackedVector2Array()
	for p in pts: uvs.append(Vector2((p.x - x0) / mw, (p.y - oy) / mw))
	draw_colored_polygon(pts, Color.WHITE, uvs, tex["mwall"])
	draw_colored_polygon(pts, Color(20 / 255.0, 12 / 255.0, 10 / 255.0, 0.3))
	draw_polyline(PackedVector2Array([Vector2(x0 - 4.0, G - 146.0), Vector2(mid, C - 14.0), Vector2(x1 + 4.0, G - 146.0)]), Color("#2a1810"), 12.0)

func _cobwebs() -> void:
	var x0: float = F["rooms"][0][0]
	var x1: float = F["rooms"][0][1]
	var mid := (x0 + x1) / 2.0
	var col := Color(220 / 255.0, 215 / 255.0, 205 / 255.0, 0.28)
	for cw in [[mid, C + 2.0, 1.0], [mid, C + 2.0, -1.0], [x0 + 6.0, G - 146.0, 1.0], [x1 - 6.0, G - 146.0, -1.0]]:
		var c := Vector2(cw[0], cw[1])
		var sx: float = cw[2]
		for i in 5:
			var a := (0.25 + i * 0.28) * PI / 2.0
			draw_line(c, c + Vector2(sx * cos(a) * 46.0, sin(a) * 46.0), col, 1.0)
		for r in [14.0, 26.0, 38.0]:
			var L := PackedVector2Array()
			for i in 5:
				var a2 := (0.25 + i * 0.28) * PI / 2.0
				L.append(c + Vector2(sx * cos(a2) * r, sin(a2) * r))
				if i < 4:
					var am := a2 + 0.14 * PI / 2.0
					L.append(c + Vector2(sx * cos(am) * r * 0.9, sin(am) * r * 0.9))
			draw_polyline(L, col, 1.0)

## a stairwell going down: a dark slot in the floor behind a railing (the railing is drawn in front)
func _well_back(x0: float, x1: float) -> void:
	draw_rect(Rect2(x0, G - 2.0, x1 - x0, 34.0), Color("#0c0708"))
	var c0 := Color("#0c0708")
	var c1 := Color(c0, 0.0)
	draw_polygon(PackedVector2Array([Vector2(x0, G + 30.0), Vector2(x1, G + 30.0), Vector2(x1, G + 70.0), Vector2(x0, G + 70.0)]), PackedColorArray([c0, c0, c1, c1]))

## curtains frame the windows; they breathe a little and belly out in a door's draft
func _curtains() -> void:
	if not F.has("curtains") or wr == null: return
	var L: Array = F["curtains"]
	var t := Time.get_ticks_msec() / 1000.0
	var cx0 := cam_x()
	for b in bays:
		var x: float = b[0]
		if b[1] or x < L[0] or x > L[1] or x + HD.HBAY < cx0 - 80.0 or x > cx0 + vw() + 80.0: continue
		var wc: float = x + (wr["x0"] + wr["x1"]) / 2.0
		var yb: float = G - wr["bot"] + 10.0
		var half: float = (wr["x1"] - wr["x0"]) / 2.0
		for cc in [["curtL", wc - half - 44.0, 0.0], ["curtR", wc + half - 14.0, 1.7]]:
			var im: Texture2D = tex[cc[0]]
			var ccx: float = cc[1]
			var kk := 0.0
			if draft != null: kk = draft["v"] * maxf(0.0, 1.0 - absf(ccx - draft["x"]) / 700.0)
			var sw: float = sin(t * 0.8 + x * 0.01 + cc[2]) * 0.5 + (draft["dir"] if draft != null else 0.0) * kk * (3.0 + sin(t * 6.0 + cc[2]))
			var rows := im.get_height()
			var y0 := yb - rows * 2.0
			var i := 0
			while i < rows:
				var n := mini(4, rows - i)
				var off := roundf(sw * pow(float(i) / rows, 1.6) * 3.0) * 2.0
				draw_texture_rect_region(im, Rect2(roundf(ccx) + off, y0 + i * 2.0, im.get_width() * 2.0, n * 2.0), Rect2(0, i, im.get_width(), n))
				i += 4

## a partition wall seen edge-on, with a side-view door that swings away from whoever opened it
func _partition(wx: float, o: float, d: int) -> void:
	var D: Texture2D = tex["pdoor"]
	var DN := 5
	var fw := D.get_width() / DN
	var DH := D.get_height() * 2.0
	var HG := 6.0
	var strip: Texture2D = tex["pstrip"]
	var sw := HW("pstrip")
	var sh := HH("pstrip")
	var top := C + HH("pcap") - 6.0
	var bot := G - DH - HH("pfoot") + 8.0
	var X0 := roundf(wx - sw / 2.0)
	var dk := Color(24 / 255.0, 12 / 255.0, 6 / 255.0)
	draw_polygon(PackedVector2Array([Vector2(X0 + sw, C), Vector2(X0 + sw + 22.0, C), Vector2(X0 + sw + 22.0, G), Vector2(X0 + sw, G)]), PackedColorArray([Color(dk, 0.45), Color(dk, 0.0), Color(dk, 0.0), Color(dk, 0.45)]))
	draw_polygon(PackedVector2Array([Vector2(X0 - 10.0, C), Vector2(X0, C), Vector2(X0, G), Vector2(X0 - 10.0, G)]), PackedColorArray([Color(dk, 0.0), Color(dk, 0.3), Color(dk, 0.3), Color(dk, 0.0)]))
	var mul := Color(196 / 255.0, 150 / 255.0, 124 / 255.0)
	var y := top
	while y < bot + 4.0:
		var h := minf(sh, bot + 4.0 - y)
		draw_texture_rect_region(strip, Rect2(X0, roundf(y), sw, h), Rect2(0, 0, strip.get_width(), h / 2.0), mul)
		y += sh
	draw_rect(Rect2(X0 - 2.0, top, 2.0, bot - top + 4.0), Color("#24140c"))
	draw_rect(Rect2(X0 + sw, top, 2.0, bot - top + 4.0), Color("#24140c"))
	hi(self, "pcap", roundf(wx - HW("pcap") / 2.0), C + HH("pcap"))
	hi(self, "pfoot", roundf(wx - HW("pfoot") / 2.0), G - DH + 6.0)
	var f := clampi(roundi(o * (DN - 1)), 0, DN - 1)
	draw_set_transform(Vector2(roundf(wx), G - DH), 0.0, Vector2(d, 1))
	draw_texture_rect_region(D, Rect2(-HG, 0, fw * 2.0, DH), Rect2(f * fw, 0, fw, D.get_height()))
	draw_set_transform(Vector2.ZERO)

func _flame(ci: CanvasItem, x: float, yb: float, s: float, ph: float) -> void:
	var fr := int(Time.get_ticks_msec() / 110.0 + ph) % 4
	var im: Texture2D = flames[fr]
	var w := im.get_width() * 2.0 * s
	var h := im.get_height() * 2.0 * s
	ci.draw_texture_rect(im, Rect2(roundf(x - w / 2.0), roundf(yb - h), w, h), false)

func _prop(ci: CanvasItem, p: Array) -> void:
	var k: String = p[0]
	var x: float = p[1]
	var y := HD.prop_y(p)
	var fg: String = p[4]
	var E = arena.eil
	if k == "arch":
		_arch_door(ci, p, x, y)
		return
	if k == "ladder" and fl == 2: _ladder_up(ci, x, y)
	var j: float = jig.get(F["props"].find(p), 0.0)
	if j > 0.02:
		# struck: it rocks and hops
		var tms := float(Time.get_ticks_msec())
		var c := Vector2(x + HW(k) / 2.0, y)
		jx = Transform2D(sin(tms / 28.0) * 0.08 * j, c) * Transform2D(0.0, -c - Vector2(0, absf(sin(tms / 60.0)) * 6.0 * j))
		ci.draw_set_transform_matrix(jx)
	if k == "banner":
		hi(ci, "banN" if _rank() >= 3 else "banO", x, y)       # the banner over the door is replaced from rank 3
		_unjig(ci)
		return
	if k == "herbs":
		ci.draw_rect(Rect2(roundf(x + HW(k) / 2.0 - 1.0), G - 256.0, 2.0, y - HH(k) - (G - 256.0) + 4.0), Color("#5a4028"))
	if k == "counter" and fl == 0 and E.here() and E.layer() == "counter": E.draw_on(ci, E.x, G - 1.0)
	if k == "table" and fl == 0 and E.here() and E.layer() == "table": E.draw_on(ci, E.x, G - 1.0)
	if jx != Transform2D.IDENTITY: ci.draw_set_transform_matrix(jx)     # Eilin's drawing above resets the transform
	hi(ci, k, x, y, fg.contains("m"))
	_unjig(ci)
	match k:
		"board": _board(ci, x, y)
		"catbed": _cat(ci, x, y)
		"shelf":
			# the library's shelves stay dark until it is restored
			if not hfac("library"): ci.draw_rect(Rect2(x, y - HH(k), HW(k), HH(k)), Color(20 / 255.0, 14 / 255.0, 10 / 255.0, 0.55))
		"clock": _pendulum(ci, x, y)
		"tboard": _trophies(ci, x, y)
		"fire":
			if not hfac("fire"): return
			_flame(ci, x + 74.0, y - 24.0, 0.42, 0.0)
			_flame(ci, x + 96.0, y - 22.0, 0.52, 2.0)
			_flame(ci, x + 118.0, y - 24.0, 0.42, 1.0)
		"hearth":
			if not hfac("hearth"): return
			_flame(ci, x + 79.0, y - 17.0, 0.4, 1.0)
			_flame(ci, x + 99.0, y - 17.0, 0.36, 3.0)
		"shelf":
			# the library is not restored yet: its shelves stand in the dark (rgba(20,14,10,.55) over each)
			if not hfac("library"): ci.draw_rect(Rect2(roundf(x), roundf(y - HH(k)), HW(k), HH(k)), Color8(20, 14, 10, 140))

func _unjig(ci: CanvasItem) -> void:
	if jx == Transform2D.IDENTITY: return
	jx = Transform2D.IDENTITY
	ci.draw_set_transform(Vector2.ZERO)

## hcat: the cat asleep on its cushion by the fire (z's), sitting up to watch you when you are near
func _cat(ci: CanvasItem, x: float, y: float) -> void:
	var t := float(Time.get_ticks_msec())
	var sit: bool = cat["st"] == "sit"
	ci.draw_set_transform(Vector2(roundf(x + 28.0), roundf(y - 12.0)), 0.0, Vector2(2.0 * (cat["dir"] if sit else 1.0), 2.0))
	if sit: TLIFE.cat_sit(ci, t, false, false)
	else: TLIFE.cat_sleep(ci, t)
	ci.draw_set_transform(Vector2.ZERO)
	if not sit and int(cat["z"] / 900.0) % 3 == 0:
		ci.draw_string(arena.font_black, Vector2(x + 40.0, y - 26.0 - fmod(cat["z"], 900.0) / 60.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.75))

## stair-landing archway with its double door: the leaves swing in as you step onto the landing
func _arch_door(ci: CanvasItem, p: Array, x: float, y: float) -> void:
	var cx := x + 48.0
	hi(ci, "archF", roundf(cx - HW("archF") / 2.0), y)
	var D: Texture2D = tex["archD"]
	var o: float = arch_o.get(F["props"].find(p), 0.0)
	var f := clampi(roundi(o * 3.0), 0, 3)
	var fw := D.get_width() / 4.0
	ci.draw_texture_rect_region(D, Rect2(roundf(cx - fw), roundf(y - D.get_height() * 2.0), fw * 2.0, D.get_height() * 2.0), Rect2(f * fw, 0, fw, D.get_height()))

## the attic hatch: the ladder runs on up to the ceiling, and the lid opens when you come to it
func _ladder_up(ci: CanvasItem, x: float, y: float) -> void:
	var h := HH("ladder")
	var w := HW("ladder")
	var top := C + 52.0 + HH("hatchC") - 8.0
	var clip := Rect2(x, top, w, y - h - top + 2.0)
	var yy := y - h
	while yy > top - h:
		hi(ci, "ladder", x, yy, false, clip)
		yy -= h
	var o: bool = absf(arena.player.position.x - (x + w / 2.0)) < 100.0
	if o != hatch:
		arena.sfx("guard", 0.15)
		hatch = o
	var k := "hatchO" if o else "hatchC"
	hi(ci, k, roundf(x + w / 2.0 - HW(k) / 2.0), C + 52.0 + HH(k))

## the notices pinned on the quest board
func _board(ci: CanvasItem, x: float, yb: float) -> void:
	var w := HW("board")
	var h := HH("board")
	var P4 := [[0.11, 0.34, 0.79, "qp0"], [0.42, 0.58, 0.46, "qp2"], [0.66, 0.88, 0.70, "qp3"], [0.46, 0.62, 0.84, "qp1"]]
	for q in P4:
		var k: String = q[3]
		hi(ci, k, roundf(x + w * (q[0] + q[1]) / 2.0 - HW(k) / 2.0), roundf(yb - h + h * q[2]) + 2.0)
	# hboardFlap: the notices lift and flap in a door's draft, and flutter now and then on their own
	var v := 0.0
	if draft != null: v = draft["v"] * maxf(0.0, 1.0 - absf(x + w / 2.0 - draft["x"]) / 700.0)
	var t := Time.get_ticks_msec() / 1000.0
	for i in P4.size():
		var q: Array = P4[i]
		var kk := maxf(0.08 * maxf(0.0, sin(t * 0.7 + i * 2.0) - 0.8) * 5.0, v) * (0.6 + 0.4 * sin(t * (14.0 + i * 3.0) + i))
		if kk < 0.05: continue
		var lift := roundf(kk * 6.0 / 2.0) * 2.0
		var x0 := roundf((x + w * q[0]) / 2.0) * 2.0
		var x1 := roundf((x + w * q[1]) / 2.0) * 2.0
		var y := roundf((yb - h + h * q[2]) / 2.0) * 2.0
		ci.draw_rect(Rect2(x0, y - 2.0, x1 - x0, 2.0), Color(40 / 255.0, 24 / 255.0, 14 / 255.0, 0.45))
		ci.draw_rect(Rect2(x0, y - 2.0 - lift, x1 - x0, lift), Color("#d8cbaa"))
		ci.draw_rect(Rect2(x0, y - 2.0 - lift, x1 - x0, 2.0), Color("#efe4c8"))

## grandfather clock: the pendulum swings in the case (2 s period)
func _pendulum(ci: CanvasItem, x: float, y: float) -> void:
	var w := HW("clock")
	var h := HH("clock")
	var cx := roundf(x + w / 2.0)
	var py := roundf(y - h * 0.62)
	var a := 0.12 * sin(Time.get_ticks_msec() / 1000.0 * PI)
	ci.draw_set_transform(Vector2(cx, py), a, Vector2.ONE)
	ci.draw_texture_rect(tex["pend"], Rect2(-HW("pend") / 2.0, -2.0, HW("pend"), HH("pend")), false)
	ci.draw_set_transform(Vector2.ZERO)

## HALL.rank(): the guild's fame rank 0..6 (fame.gd r - 1)
func _rank() -> int:
	return clampi(arena.fame.r - 1, 0, 6) if arena.fame != null else 1

## trophies on the dining hall board: one per fame rank; a lone hook waits over every empty plaque
func _trophies(ci: CanvasItem, x: float, y: float) -> void:
	var n := mini(6, _rank())
	var w := HW("tboard")
	var h := HH("tboard")
	var FR := [0.100, 0.258, 0.418, 0.580, 0.739, 0.900]
	for i in n:
		var k := "tr%d" % i
		if tex.has(k): hi(ci, k, roundf(x + w * FR[i] - HW(k) / 2.0), y - h - 2.0)
	for i in range(n, 6):
		var hx := roundf((x + w * FR[i]) / 2.0) * 2.0
		ci.draw_rect(Rect2(hx - 2.0, y - h - 6.0, 4.0, 4.0), Color("#b88a3a"))

## sunlight through the windows: window-shaped patches on the floor that lean and stretch with the hour, long shafts at dusk
func _draw_glow() -> void:
	# daylight from each window: a soft sky-tinted glow (hallLights' window lights)
	if sun > 0.05 and not F.get("gable", false):
		var sk := hsky()
		var wcol := Color((160.0 + sk[0] * 0.38) / 255.0, (160.0 + sk[1] * 0.38) / 255.0, (160.0 + sk[2] * 0.38) / 255.0, 0.26 * sun * 0.6)
		var c0 := cam_x()
		for b in bays:
			if b[1] or b[0] + HD.HBAY < c0 - 60.0 or b[0] > c0 + vw() + 60.0: continue
			glow.draw_texture_rect(light_tex, Rect2(b[0] + 76.0 - 121.0, G - 150.0 - 121.0, 242.0, 242.0), false, wcol)
	if F.get("gable", false) or sun < 0.03 or wr == null:
		_draw_motes()
		return
	var h := fposmod(arena.tod_h, 24.0)
	var M := hsky_mix()
	var dusk := 0.0
	for m in M:
		if m[0] == "dusk": dusk = m[1]
	var low := minf(1.0, absf(h - 12.5) / 5.5)
	var lean := (1.0 if h < 12.5 else -1.0) * (0.25 + low * 1.3)
	var col := Color8(255, 168, 90) if dusk > 0.3 else Color8(255, 236, 200)
	var A := (0.05 + 0.13 * dusk) * minf(1.0, sun * 1.6)
	var cx0 := cam_x()
	for b in bays:
		var x: float = b[0]
		if b[1] or x + HD.HBAY + 160.0 < cx0 or x - 160.0 > cx0 + vw(): continue
		var wx0: float = x + wr["x0"]
		var wx1: float = x + wr["x1"]
		var wy0: float = G - wr["top"]
		var wy1: float = G - wr["bot"]
		var fy := G + 18.0
		var dx := lean * (fy - wy1) * 0.55
		if dusk > 0.3:
			glow.draw_polygon(PackedVector2Array([Vector2(wx0, wy0), Vector2(wx1, wy0), Vector2(wx1 + dx, fy), Vector2(wx0 + dx, fy)]),
				PackedColorArray([Color(col, A * 0.55), Color(col, A * 0.55), Color(col, 0.0), Color(col, 0.0)]))
		var pw := (wx1 - wx0 - 4.0) / 2.0
		var fx := wx0 + dx * 0.92
		var st := (1.0 + low * 1.6) * 0.5
		var pc := Color(col, A * 1.6)
		for i in 2:
			for j in 2:
				var yA := G + 2.0 + j * 7.0 * st + (2.0 if j == 1 else 0.0)
				var yB := yA + 7.0 * st
				var xa := fx + i * (pw + 4.0)
				var sk := lean * 4.0
				glow.draw_colored_polygon(PackedVector2Array([Vector2(roundf(xa + sk * j), roundf(yA)), Vector2(roundf(xa + pw + sk * j), roundf(yA)),
					Vector2(roundf(xa + pw + sk * (j + 1)), roundf(yB)), Vector2(roundf(xa + sk * (j + 1)), roundf(yB))]), pc)
	_draw_motes()

func _draw_motes() -> void:
	for m in motes:
		var k: float = m["t"] / m["life"]
		var a: float = minf(minf(1.0, k * 5.0), (1.0 - k) * 4.0) * sun * (0.5 + 0.5 * sin(m["t"] / 400.0 + m["ph"]))
		if a < 0.02: continue
		glow.draw_rect(Rect2(roundf(m["x"] / 2.0) * 2.0, roundf(m["y"] / 2.0) * 2.0, 2, 2), Color(1.0, 240 / 255.0, 205 / 255.0, minf(1.0, 0.95 * a)))

## stairs, railings, signs and the chandelier stand in front of people; then the prompts and her speech bubble
func _draw_front() -> void:
	if F.has("stair"): hi(front, "stairs", F["stair"], HD.LANDY - 71.0 + HH("stairs"))
	if F.has("well"):
		var x0: float = F["well"][0]
		var x1: float = F["well"][1]
		var rw := HW("rail")
		var x := x0
		var clip := Rect2(x0, G - 120.0, x1 - x0, 124.0)
		while x < x1 - 4.0:
			hi(front, "rail", x, G + 2.0, false, clip)
			x += rw
	for p in F["props"]:
		if String(p[4]).contains("f"): _prop(front, p)
	if fl == 0:
		var cx := 2020.0
		var cy := C + 24.0
		var pv := cy + HH("chain") * 0.6 - HH("chain")
		front.draw_set_transform(Vector2(cx, pv), chand_a(), Vector2.ONE)
		var ch_top := cy + HH("chain") * 0.6 - HH("chain") - pv
		# not yet restored: chain and chandelier hang dark and dull (filter brightness(.45) saturate(.6)), no light
		var lit := hfac("chand")
		front.draw_texture_rect(tex["chain"] if lit else dim_tex("chain"), Rect2(-HW("chain") / 2.0, ch_top, HW("chain"), HH("chain")), false)
		var cb := cy + HH("chain") * 0.6 - 8.0 + HH("chand") - pv
		front.draw_texture_rect(tex["chand"] if lit else dim_tex("chand"), Rect2(-HW("chand") / 2.0, cb - HH("chand"), HW("chand"), HH("chand")), false)
		front.draw_set_transform(Vector2.ZERO)

func _draw_labels() -> void:
	var front := labels
	var E = arena.eil
	E.draw_say(front, E.y)
	var fnt: Font = arena.font_black
	var tt := Time.get_ticks_msec() / 1000.0
	var P = arena.player
	if arena.dlg.active:
		return
	if near_door != null:
		var d = near_door
		# KH() + the name (+ 나가기 on the way out)
		var out: bool = d.get("act", "") == "town"
		var s2: String = arena.cfg.kh() + String(d["name"]) + (" 나가기" if out else "")
		var tw := maxf(140.0, fnt.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24.0)
		var y2: float = d["y"] - 150.0 + sin(tt * 4.0) * 3.0
		front.draw_rect(Rect2(d["x"] - tw / 2.0, y2 - 16.0, tw, 24.0), Color(0, 0, 0, 0.55))
		var sw2 := fnt.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		front.draw_string(fnt, Vector2(d["x"] - sw2 / 2.0, y2), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffe9a8") if out else Color("#cfd6e6"))
	elif stair_hint():
		var s3 := "↑ 계단"
		var w3 := fnt.get_string_size(s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0
		var y3: float = P.position.y - 230.0
		front.draw_rect(Rect2(P.position.x - w3 / 2.0, y3 - 16.0, w3, 22.0), Color(0, 0, 0, 0.6))
		front.draw_string(fnt, Vector2(P.position.x - w3 / 2.0 + 8.0, y3), s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffe9a8"))
