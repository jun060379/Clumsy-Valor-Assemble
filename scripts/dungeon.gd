extends Node2D
## 버섯 동굴: a side-scrolling map of wide rooms (a left→right spine from the entrance to the boss, plus 1–2 side branches
## that climb or drop a floor and lead to a treasure or rest room). Ported from the prototype's dunReset / dungeonEnter /
## updDungeon and its cave drawing (drawDungeon 5127): the rock masses are baked at art resolution as the prototype bakes
## them (cave_ter.gd) and take the room's light on their edges; the room is lit as drawLighting lights it (lit.gd): the
## night-blue ambient multiplied over everything, then the torches, lanterns, mushrooms, crystals, doors and the heroine's
## own glow added as shaped pools. No Light2D.

const H := 500.0
const TW := 80.0
const SURF := 4.0
## room templates. heights are ABOVE the floor. solids = raised rock [x,w,h]; ledges = one-way [x,h,w];
## door anchors [x,h] per side; props [k,x,h,mode] (w = wall torch, c = hanging lantern)
const RTPL := {
	"stair": {"w": 2300, "top": 620, "name": "계단 갱도", "solids": [[520, 240, 110], [760, 260, 220], [1760, 300, 130]], "ledges": [[1080, 300, 260], [1390, 430, 230], [1060, 560, 250]],
		"door": {"L": [80, 0], "R": [2220, 0], "U": [1180, 560], "D": [1420, 0]}, "props": [["frame", 300, 0], ["cart", 1300, 0], ["rail", 1220, 0], ["rail", 1335, 0], ["torch", 640, 220, "w"], ["torch", 1900, 130, "w"], ["mushM", 880, 220], ["crysS", 1500, 430], ["lantern", 1460, 560, "c"], ["rockM", 2050, 0]]},
	"pit": {"w": 2500, "top": 560, "name": "꺼진 골짜기", "solids": [[0, 620, 220], [1880, 620, 220]], "ledges": [[860, 150, 240], [1360, 150, 240], [1080, 320, 300], [1060, 500, 280]],
		"door": {"L": [90, 220], "R": [2410, 220], "U": [1200, 500], "D": [1240, 0]}, "props": [["frame", 400, 220], ["torch", 560, 220, "w"], ["torch", 1950, 220, "w"], ["mushL", 1000, 0], ["mushM", 1480, 0], ["crysL", 2200, 220], ["rubble", 1250, 0], ["lantern", 1480, 320, "c"]]},
	"tower": {"w": 1700, "top": 760, "name": "수직 갱도", "solids": [[1200, 500, 170]], "ledges": [[280, 140, 260], [680, 280, 260], [280, 420, 260], [760, 560, 300], [340, 700, 280]],
		"door": {"L": [80, 0], "R": [1620, 170], "U": [480, 700], "D": [760, 0]}, "props": [["frame", 1350, 170], ["torch", 560, 0, "w"], ["torch", 1000, 280, "w"], ["mushS", 360, 140], ["crysS", 820, 560], ["lantern", 900, 560, "c"], ["rockL", 1080, 0]]},
	"hall": {"w": 2700, "top": 440, "name": "버섯 대광장", "solids": [[700, 130, 90], [1300, 170, 150], [1980, 130, 90]], "ledges": [[950, 240, 260], [1560, 240, 260], [1260, 400, 260]],
		"door": {"L": [80, 0], "R": [2620, 0], "U": [1390, 400], "D": [480, 0]}, "props": [["mushL", 420, 0], ["mushM", 1100, 0], ["mushL", 1700, 0], ["mushS", 2300, 0], ["torch", 760, 90, "w"], ["torch", 2040, 90, "w"], ["crysL", 1360, 150], ["frame", 2450, 0]]},
	"camp": {"w": 1400, "top": 300, "name": "쉼터", "solids": [], "ledges": [[520, 180, 320]], "door": {"L": [80, 0], "R": [1320, 0], "U": [680, 180], "D": [1080, 0]}, "props": [["frame", 260, 0], ["mushM", 980, 0], ["lantern", 680, 180, "c"], ["crysS", 1200, 0]]},
	"vault": {"w": 1400, "top": 300, "name": "보물 창고", "solids": [[560, 280, 60]], "ledges": [[520, 200, 360]], "door": {"L": [80, 0], "R": [1320, 0], "U": [700, 200], "D": [1100, 0]}, "props": [["crysL", 360, 0], ["crysL", 1040, 0], ["crysS", 460, 0], ["lantern", 700, 200, "c"], ["cart", 1200, 0]]},
	"boss": {"w": 2100, "top": 420, "name": "무너진 갱도", "solids": [], "ledges": [[200, 170, 280], [1620, 170, 280], [900, 320, 300]], "door": {"L": [80, 0], "R": [2020, 0], "U": [1050, 320], "D": [1050, 0]}, "props": [["frame", 120, 0], ["frame", 1980, 0], ["rubble", 700, 0], ["rubble", 1400, 0], ["torch", 560, 0, "w"], ["torch", 1540, 0, "w"], ["crysL", 1700, 170]]},
	"start": {"w": 1500, "top": 300, "name": "동굴 입구", "solids": [[900, 260, 90]], "ledges": [[1120, 200, 240]], "door": {"L": [80, 0], "R": [1420, 0], "U": [1240, 200], "D": [620, 0]}, "props": [["frame", 240, 0], ["cart", 640, 0], ["rail", 560, 0], ["rail", 675, 0], ["torch", 420, 0, "w"], ["torch", 1030, 90, "w"]]},
}
const FIGHT_TPL := ["stair", "pit", "tower", "hall"]
const SPAWN := {"stair": ["g", "g", "s1", "s2", "p0", "p1", "p2"], "pit": ["g", "g", "s0", "s1", "p0", "p1", "p2"], "tower": ["g", "g", "s0", "p0", "p1", "p2", "p3"], "hall": ["g", "g", "g", "s1", "p0", "p1", "p2"], "boss": ["g"]}
const WAVES := {
	1: [[["goblin"], ["goblin"], ["eye"]], [["mush"], ["goblin"], ["goblin"]]],
	2: [[["mush"], ["mush"], ["eye"], ["goblin"]], [["goblin"], ["goblin"], ["mush"], ["eye"]]],
	3: [[["skel"], ["goblin"], ["eye"], ["mush"]], [["skel"], ["skel"], ["goblin", 1], ["eye"]]],
	4: [[["skel"], ["mush"], ["mush"], ["eye"], ["goblin"]], [["skel", 1], ["goblin"], ["goblin"], ["eye"], ["eye"]]],
}
const DIRS := {"L": [-1, 0, "R"], "R": [1, 0, "L"], "U": [0, -1, "D"], "D": [0, 1, "U"]}
## door look per kind of room behind it: light colour; the signboard names it
const DOORSTY := {"fight": Color8(255, 168, 58), "boss": Color8(255, 60, 50), "camp": Color8(255, 160, 80), "vault": Color8(255, 210, 100), "start": Color8(190, 210, 255), "town": Color8(235, 240, 255)}
const DOORA := {"fight": 0.6, "boss": 0.8, "camp": 0.75, "vault": 0.75, "start": 0.45, "town": 0.7}     # DOORSTY .a
const DOORPT := {"boss": true}                                                                          # sh 'point': lit while sealed
const SIGNI := {"fight": 0, "boss": 1, "vault": 2, "camp": 3, "start": 4, "town": 4}
const DOPEN := [30, 26, 122, 170]
const CT := preload("res://scripts/cave_ter.gd")
const LIT := preload("res://scripts/lit.gd")

var kind := "dungeon"
var arena
var rooms := {}
var cur := ""
var from := ""
var tpl: Dictionary
var waves: Array = []
var wave := 0
var gate_open := false
var open_k := 0.0
var doors: Array = []
var chest = null
var msg := ""
var msg_t := 0.0
var near_gate = null
var atk_t := 0.0
var walls: Array = []
var spores: Array = []
var tex := {}
var lit                          # lit.gd: the ambient multiply and the shaped lights (drawLighting)
var L: Array = []                # lightSources() this frame (light dicts as lit.gd takes them)
var L_rim: Array = []            # DUN._L: no player light, no small glows (rims on rock and on characters)
var amb := Color(0.36, 0.385, 0.62)
var masses: Array = []           # [{m: cave_ter mass, n: Node2D, gain}]
var n_walls: Node2D              # draw order inside the cave node (drawDungeon): back walls, doors (+ their light),
var n_doors: Node2D              # wall fixtures, the rock masses, then the camp fire, the chest and the door tags
var n_door_add: Node2D
var n_props: Node2D
var n_rock: Node2D
var n_misc: Node2D
var bg_layer: CanvasLayer
var bg_node: Node2D
var front: Node2D                # after the light pass (drawDungeonFront): spores, floor fog, the door prompt
var front_add: Node2D            # the door spill on the floor, additive
var sign_w := {}                 # sign emission as flat white (tintImg) and its blur


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = -5
	for f in DirAccess.get_files_at("res://assets/cave"):
		if f.ends_with(".png"):
			tex[f.get_basename()] = load("res://assets/cave/" + f)
		elif f.ends_with(".png.import"):
			var k := f.get_basename().get_basename()
			if not tex.has(k): tex[k] = load("res://assets/cave/" + k + ".png")
	CT.init_art(tex)
	_sign_tints()
	n_walls = _layer(Callable(), -1)
	n_doors = _layer(_draw_doors, -1)
	n_door_add = _layer(_draw_doors_add, CanvasItemMaterial.BLEND_MODE_ADD)
	n_props = _layer(_draw_props, -1)
	n_rock = _layer(Callable(), -1)
	n_misc = _layer(_draw_misc, -1)
	lit = LIT.new(arena)
	lit.attach()
	bg_layer = CanvasLayer.new()
	bg_layer.layer = -10
	arena.add_child(bg_layer)
	bg_node = Node2D.new()
	bg_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg_node.draw.connect(_draw_bg)
	bg_layer.add_child(bg_node)
	front_add = Node2D.new()
	front_add.z_index = 9
	front_add.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	front_add.material = am
	front_add.draw.connect(_draw_spill)
	arena.add_child(front_add)
	front = Node2D.new()
	front.z_index = 9
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.draw.connect(_draw_front)
	arena.add_child(front)

func _layer(fn: Callable, blend: int) -> Node2D:
	var n := Node2D.new()
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if blend >= 0:
		var m := CanvasItemMaterial.new()
		m.blend_mode = blend
		n.material = m
		n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if fn.is_valid(): n.draw.connect(fn)
	add_child(n)
	return n

## tintImg: the signboard's emission as a flat silhouette (tinted per door when drawn), and a blurred copy (blur 4px)
func _sign_tints() -> void:
	for si in 5:
		var im: Image = (tex["sign%de" % si] as Texture2D).get_image()
		if im.is_compressed(): im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		for y in im.get_height():
			for x in im.get_width():
				var c := im.get_pixel(x, y)
				im.set_pixel(x, y, Color(1, 1, 1, c.a))
		var pad := 8
		var bl := Image.create(im.get_width() + pad * 2, im.get_height() + pad * 2, false, Image.FORMAT_RGBA8)
		bl.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(pad, pad))
		var sz := bl.get_size()
		bl.resize(maxi(1, sz.x / 4), maxi(1, sz.y / 4), Image.INTERPOLATE_BILINEAR)
		bl.resize(sz.x, sz.y, Image.INTERPOLATE_BILINEAR)
		sign_w[si] = [ImageTexture.create_from_image(im), ImageTexture.create_from_image(bl), pad]


func cleanup() -> void:
	lit.cleanup()
	bg_layer.queue_free()
	front.queue_free()
	front_add.queue_free()
	queue_free()


# ---------- the map ----------
func rkey(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

func generate() -> void:
	rooms = {}
	var add := func(x: int, y: int, p, d: String) -> Dictionary:
		var r := {"x": x, "y": y, "k": rkey(x, y), "type": "fight", "doors": {}, "dist": (p["dist"] + 1) if p != null else 0, "seen": false, "visited": false, "cleared": false, "once": false}
		rooms[r["k"]] = r
		if p != null:
			p["doors"][d] = true
			r["doors"][DIRS[d][2]] = true
		return r
	var can := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and y <= 4 and not rooms.has(rkey(x, y))
	var n := 6 + randi() % 2
	var p: Dictionary = add.call(0, 2, null, "")
	var main: Array = [p]
	for i in range(1, n):
		p = add.call(i, 2, p, "R")
		main.append(p)
	var ends: Array = []
	var used_x: Array = []
	var nb := 2 if randf() < 0.65 else 1
	for b in nb:
		var cands: Array = main.slice(1, main.size() - 1).filter(func(r): return not used_x.any(func(x): return absi(x - r["x"]) < 2))
		if cands.is_empty(): break
		var r: Dictionary = cands[randi() % cands.size()]
		var vd := ("U" if randf() < 0.7 else "D") if b == 0 else ("D" if not ends.is_empty() and ends[0]["y"] < 2 else "U")
		if not can.call(r["x"], r["y"] + DIRS[vd][1]): continue
		used_x.append(r["x"])
		var q: Dictionary = add.call(r["x"], r["y"] + DIRS[vd][1], r, vd)
		var hd := "R" if randf() < 0.7 else "L"
		var ln := 1 + randi() % 3
		for k in ln:
			var nx: int = q["x"] + DIRS[hd][0]
			if not can.call(nx, q["y"]): break
			q = add.call(nx, q["y"], q, hd)
		ends.append(q)
	main[0]["type"] = "start"
	main[0]["cleared"] = true
	var boss: Dictionary = main[main.size() - 1]
	boss["type"] = "boss"
	if ends.size() > 0: ends[0]["type"] = "vault"
	if ends.size() > 1: ends[1]["type"] = "camp"
	else:
		var m: Dictionary = main[main.size() / 2]
		if m["type"] == "fight": m["type"] = "camp"
	for r in rooms.values():
		r["tpl"] = FIGHT_TPL[randi() % FIGHT_TPL.size()] if r["type"] == "fight" else r["type"]
		r["tier"] = clampi(ceili(float(r["dist"]) * 4.0 / maxf(1.0, boss["dist"])), 1, 4)
		if r["type"] != "fight" and r["type"] != "boss": r["cleared"] = true
	cur = main[0]["k"]
	from = ""
	prebuild()


func anchor_of(d: String) -> Vector2:
	var a: Array = tpl["door"][d]
	return Vector2(a[0], arena.ground_y - a[1])

func room() -> Dictionary:
	return rooms[cur]

func enter() -> void:
	var rm := room()
	tpl = RTPL[rm["tpl"]]
	rm["visited"] = true
	rm["seen"] = true
	for d in rm["doors"]:
		var o = rooms.get(rkey(rm["x"] + DIRS[d][0], rm["y"] + DIRS[d][1]))
		if o != null: o["seen"] = true
	var G: float = arena.ground_y
	arena.clear_room()
	arena.world_w = tpl["w"]
	arena.ceil_y = G - tpl["top"] - 250.0
	arena.solids = tpl["solids"].map(func(s): return {"x": float(s[0]), "w": float(s[1]), "top": G - s[2]})
	arena.platforms = tpl["ledges"].map(func(l): return {"x": float(l[0]), "y": G - l[1], "w": float(l[2])})
	doors = rm["doors"].keys().map(func(d): var a := anchor_of(d); return {"d": d, "x": a.x, "y": a.y, "town": false, "boss": false})
	if rm["type"] == "start": doors.append({"d": "town", "x": 300.0, "y": G, "town": true, "boss": false})
	if rm["type"] == "boss": doors.append({"d": "town", "x": tpl["w"] / 2.0, "y": G, "town": true, "boss": true})
	chest = {"x": tpl["w"] / 2.0} if rm["type"] == "vault" and not rm.get("looted", false) else null
	walls = _wall_segs()
	# stand just inside the door you came through
	var ent := anchor_of(from) if from != "" else anchor_of("L")
	var P = arena.player
	P.position = Vector2(clampf(ent.x + (110.0 if ent.x < tpl["w"] / 2.0 else -110.0), 60.0, tpl["w"] - 60.0), ent.y)
	P.on = true
	P.vy = 0.0
	P.dir = 1 if ent.x < tpl["w"] / 2.0 else -1
	arena.snap_camera()
	wave = 0
	if not rm["cleared"]:
		waves = [[["boss"]]] if rm["type"] == "boss" else WAVES[rm["tier"]]
		gate_open = false
		open_k = 0.0
		spawn_wave()
	else:
		waves = []
		gate_open = true
		open_k = 1.0
	msg = ("⚠ 감독관 해골" if rm["type"] == "boss" else tpl["name"] + (" (정리됨)" if rm["cleared"] and rm["type"] == "fight" else ""))
	msg_t = 1400.0 if rm["once"] else 2600.0
	rm["once"] = true
	_build_masses()
	_light_step(Time.get_ticks_msec() / 1000.0)
	_redraw_all()

func spawn_wave() -> void:
	if wave >= waves.size(): return
	var W0: Array = waves[wave]
	var sp: Array = SPAWN.get(room()["tpl"], ["g"]).duplicate()
	sp.shuffle()
	for j in W0.size():
		var e: Array = W0[j]
		var k: String = e[0]
		var where: String = "g" if k == "eye" else sp[j % sp.size()]
		var delay: float = (350.0 + j * 220.0) if wave > 0 else (120.0 + j * 120.0)
		var m = _spawn_at(k, where, e.size() > 1, delay)
		if wave > 0:
			m.aw = true            # dunWave: reinforcements come in already aware, silently (no !!, no beep, no react pause)
			m.home = m.position.x
	if wave > 0:
		msg = "증원!"
		msg_t = 1200.0

func _spawn_at(k: String, where: String, elite: bool, delay: float):
	var G: float = arena.ground_y
	var x := 0.0
	var y := G
	var pl = null
	var idx := int(where.substr(1)) if where.length() > 1 else -1
	if where[0] == "p" and idx < arena.platforms.size():
		pl = arena.platforms[idx]
		x = pl.x + pl.w * (0.25 + randf() * 0.5)
		y = pl.y
	elif where[0] == "s" and idx < arena.solids.size():
		var so: Dictionary = arena.solids[idx]
		pl = {"x": so.x, "w": so.w}
		x = so.x + so.w * (0.3 + randf() * 0.4)
		y = so.top
	else:
		for t in 20:
			x = 300.0 + randf() * (tpl["w"] - 600.0)
			if absf(x - arena.player.position.x) > 260.0 and not arena.solids.any(func(so): return x > so.x - 40.0 and x < so.x + so.w + 40.0):
				break
	return arena.spawn(k, x, delay, y, pl, elite, maxi(1, int(room().get("tier", 1))))   # room.tier||1 (boss room: 4)


func step(dt: float) -> void:
	if msg_t > 0.0: msg_t -= dt
	if gate_open and open_k < 1.0: open_k = minf(1.0, open_k + dt / 900.0)
	var rm := room()
	var alive: Array = arena.mobs.filter(func(m): return not m.is_dead())
	if alive.is_empty() and not gate_open and not waves.is_empty() and arena.mobs.all(func(m): return m.spawn_t <= 0.0):
		if wave < waves.size() - 1:
			wave += 1
			spawn_wave()
		else:
			gate_open = true
			open_k = 0.0
			rm["cleared"] = true
			arena.sfx("ready", 0.8)
			msg = "버섯 동굴 정복!" if rm["type"] == "boss" else "방 정리 — 문이 열렸다"
			msg_t = 2200.0
			if rm["type"] == "fight" and randf() < 0.55:
				pay()
			if rm["type"] == "boss" and arena.get("runes") != null:
				arena.runes.boss_cleared(self)
	var P = arena.player
	var G: float = arena.ground_y
	# camp fire / vault chest
	if rm["type"] == "camp" and not rm.get("rest_used", false) and absf(P.position.x - tpl["w"] * 0.75) < 90.0 and P.position.y > G - 10.0:
		rm["rest_used"] = true
		for c in P.hpm:            # every ROSTER member, not just the party
			if arena.fame != null and not arena.fame.recruited(c): continue
			P.hpm[c] = minf(arena.runes.max_hp(c), P.hpm[c] + arena.runes.max_hp(c) * 0.5)
		P.hp = minf(P.MAX_HP, P.hp + P.MAX_HP * 0.5)
		arena.ring(P.position + Vector2(0, -60), 30.0, Color("#bff0c0"))
		arena.text(P.position + Vector2(0, -160), "모닥불 · 파티 체력 회복", Color("#bff0c0"))
		arena.sfx("ready", 1.0)
	if chest != null and absf(P.position.x - chest["x"]) < 70.0 and absf(P.position.y - G) < 10.0:
		rm["looted"] = true
		chest = null
		if arena.get("runes") != null:
			arena.runes.vault(P.position)
		else:
			var g := 12 + randi() % 8
			arena.shilling += g
			arena.text(P.position + Vector2(0, -190), "보물방 · 실링 +%d" % g, Color("#ffd34d"))
		arena.ring(P.position + Vector2(0, -60), 40.0, Color("#ffd34d"))
		arena.flash = 0.2
	# doors
	near_gate = null
	if P.attacking() or P.anim in ["parry", "guard"]: atk_t = 650.0
	elif atk_t > 0.0: atk_t -= dt
	var hostile: bool = arena.mobs.any(func(m): return not m.is_dead() and m.spawn_t <= 0.0 and (m.aw or absf(m.position.x - P.position.x) < 520.0))
	if P.on and atk_t <= 0.0 and not hostile:
		for d in doors:
			if (gate_open or d["town"]) and not (d["boss"] and not gate_open) and absf(P.position.x - d["x"]) < 55.0 and absf(P.position.y - d["y"]) < 8.0:
				near_gate = d
	# spores
	var cam_r: Rect2 = arena.view_rect()
	while spores.size() < 46:
		spores.append({"x": cam_r.position.x + randf() * cam_r.size.x, "y": cam_r.position.y + cam_r.size.y * (0.2 + randf()), "v": 0.008 + randf() * 0.02, "ph": randf() * 6.0, "s": 4 if randf() < 0.3 else 2, "c": Color8(150, 255, 215) if randf() < 0.75 else Color8(220, 170, 255)})
	var tt := Time.get_ticks_msec() / 1000.0
	for s in spores:
		var sk: float = 0.2 if arena.witch > 0.0 else 1.0
		s["y"] -= s["v"] * dt * sk
		if s.has("vx"):
			s["x"] += s["vx"] * dt * sk
			s["vx"] *= pow(0.992, dt)
		if s.has("vy2"):
			s["y"] += s["vy2"] * dt * sk
			s["vy2"] *= pow(0.99, dt)
		s["x"] += sin(tt * 0.8 + s["ph"]) * 0.15
		if s["y"] < cam_r.position.y - 20.0 or s["x"] < cam_r.position.x - 40.0 or s["x"] > cam_r.end.x + 40.0:
			s["x"] = cam_r.position.x + randf() * cam_r.size.x
			s["y"] = cam_r.end.y + 10.0
	_light_step(tt)
	_redraw_all()

## airPush: a swing, a thrust or a slam blows the spores near it along
func air_push(x: float, y: float, d: float, R: float, F: float) -> void:
	for s in spores:
		var dd := Vector2(s["x"] - x, s["y"] - y).length()
		if dd < R:
			var k := 1.0 - dd / R
			s["vx"] = s.get("vx", 0.0) + d * F * k
			s["vy2"] = s.get("vy2", 0.0) - F * 0.35 * k * randf()

## the attack key at a door: move on
func try_interact() -> bool:
	if near_gate == null:
		return false
	var d = near_gate
	arena.sfx("ready", 0.6)
	arena.player.vx = 0.0
	arena.player.set_anim("idle")
	if d["town"]:
		if d["boss"] and arena.get("runes") != null and arena.runes.town_gate():
			return true
		arena.sortie.town_door()          # RETURN sweep home, or the clear screen in the cleared boss room
	else:
		var rm := room()
		var n: Dictionary = rooms[rkey(rm["x"] + DIRS[d["d"]][0], rm["y"] + DIRS[d["d"]][1])]
		from = DIRS[d["d"]][2]
		cur = n["k"]
		arena.fade_then(func(): enter())
	return true

func pay() -> void:
	var P = arena.player
	var rw: String = ["iron", "rune", "heal"][randi() % 3]
	if arena.get("runes") != null:
		arena.runes.pay(rw)        # dunPay: shilling, a rune (rollGrade(1), capped by the dungeon) or healing
		return
	if rw == "heal":
		for c in P.party:
			P.hpm[c] = minf(arena.runes.max_hp(c), P.hpm[c] + arena.runes.max_hp(c) * 0.35)
		P.hp = minf(P.MAX_HP, P.hp + P.MAX_HP * 0.35)
		arena.text(P.position + Vector2(0, -190), "보상 · 회복", Color("#9fe3a0"))
	elif rw == "iron":
		arena.shilling += 6
		arena.text(P.position + Vector2(0, -190), "보상 · 실링 +6", Color("#ffd34d"))
	else:
		arena.text(P.position + Vector2(0, -190), "보상 · 룬 (룬은 길드 시스템 단계에서)", Color("#c58cff"))
	arena.ring(P.position + Vector2(0, -60), 40.0, Color("#ffd34d"))

func door_kind(d: Dictionary) -> String:
	if d["town"]: return "town"
	var rm := room()
	var n = rooms.get(rkey(rm["x"] + DIRS[d["d"]][0], rm["y"] + DIRS[d["d"]][1]))
	return n["type"] if n != null and DOORSTY.has(n["type"]) else "fight"


# ---------- the room's rock ----------
func _rnd_seq(seed: int) -> Callable:
	var st := [seed]
	return func() -> float:
		st[0] = (st[0] * 9301 + 49297) % 233280
		return float(st[0]) / 233280.0

## wallSegs: a back wall behind every wall torch and most raised rock, merged where they meet
func _wall_segs(T: Dictionary = {}) -> Array:
	var tp: Dictionary = T if not T.is_empty() else tpl
	var rnd := _rnd_seq(int(tp["w"]) * 3 + int(tp["top"]))
	var segs: Array = []
	for p in tp["props"]:
		if p.size() > 3 and p[3] == "w":
			segs.append([p[1] - 170.0 - rnd.call() * 80.0, p[1] + 170.0 + rnd.call() * 80.0, p[2] + 250.0 + rnd.call() * 80.0])
	for s in tp["solids"]:
		if rnd.call() < 0.7:
			segs.append([s[0] - 60.0, s[0] + s[1] + 60.0, s[2] + 200.0 + rnd.call() * 120.0])
	segs.sort_custom(func(a, b): return a[0] < b[0])
	var m: Array = []
	for s0 in segs:
		var s1 := [maxf(-40.0, s0[0]), minf(tp["w"] + 40.0, s0[1]), minf(tp["top"] + 170.0, s0[2])]
		if not m.is_empty() and s1[0] < m[-1][1] + 60.0:
			m[-1][1] = maxf(m[-1][1], s1[1])
			m[-1][2] = maxf(m[-1][2], s1[2])
		else:
			m.append(s1)
	return m.map(func(v): return {"x0": CT.jr(v[0]), "x1": CT.jr(v[1]), "h": CT.jr(v[2])})

func ceil_y() -> float:
	return arena.ground_y - tpl["top"] - 250.0

## drawDungeon's drawTerrain calls for a template: back walls (rim 0.6), the ceiling (no rim), the side walls, the ground
## with every raised block in it (rim 0.9), the ledges (with a soft drop shadow): [key, kind, args, gain, layer, shadow]
func _mass_specs(tn: String) -> Array:
	var T: Dictionary = RTPL[tn]
	var G: float = arena.ground_y
	var w: float = T["w"]
	var cy: float = G - T["top"] - 250.0
	var out: Array = []
	var ws := _wall_segs(T)
	for i in ws.size():
		var sg: Dictionary = ws[i]
		out.append(["w%d" % i, "wall", [sg["x0"], sg["x1"], sg["h"], int(sg["x0"] * 7 + sg["h"] + i * 131), G], 0.6, 0, false])
	out.append(["ceil", "terrain", [-TW * 8.0, w + TW * 8.0, cy - TW * 6.0, cy, {"fringe": true}], 0.0, 1, false])
	out.append(["lw", "terrain", [-TW * 8.0, 0.0, cy - 10.0, G + 20.0, {"jag": 6.0}], 1.0, 1, false])
	out.append(["rw", "terrain", [w, w + TW * 8.0, cy - 10.0, G + 20.0, {"jag": 6.0}], 1.0, 1, false])
	var steps: Array = T["solids"].map(func(so): return [float(so[0]), float(so[0] + so[1]), G - so[2] - SURF])
	out.append(["ground", "ground", [-TW * 8.0, w + TW * 8.0, G + H + 60.0, steps, G, SURF], 0.9, 1, false])
	for i in T["ledges"].size():
		var l: Array = T["ledges"][i]
		var py: float = G - l[1]
		out.append(["p%d" % i, "terrain", [float(l[0]), float(l[0] + l[2]), py - SURF, py - SURF + 34.0, {"lip": true, "fringe": true, "jag": 2.0}], 1.0, 1, true])
	return out

static var PEND := {}            # template -> [WorkerThreadPool task, its masses]: built off the main thread

static func _build_set(specs: Array, res: Dictionary) -> void:
	for sp in specs:
		res[sp[0]] = CT.build(sp[1], sp[2])

func _ck(tn: String) -> String:
	return "%s@%d" % [tn, int(arena.ground_y)]

## every template this map uses, baked in the background as soon as the map exists
func prebuild() -> void:
	var seen := {}
	for r in rooms.values():
		var tn: String = r["tpl"]
		var ck := _ck(tn)
		if seen.has(ck) or CT.CACHE.has(ck) or PEND.has(ck): continue
		seen[ck] = true
		var res := {}
		var id := WorkerThreadPool.add_task(_build_set.bind(_mass_specs(tn), res), false, "cave " + tn)
		PEND[ck] = [id, res]

## settle every background bake (leaving the cave, or quitting with bakes still running)
static func drain() -> void:
	for ck in PEND.keys():
		WorkerThreadPool.wait_for_task_completion(PEND[ck][0])
		CT.CACHE[ck] = PEND[ck][1]
	PEND.clear()

func _exit_tree() -> void:
	drain()

func _build_masses() -> void:
	for par in [n_walls, n_rock]:
		for c in par.get_children():
			par.remove_child(c)
			c.queue_free()
	masses = []
	var tn: String = room()["tpl"]
	var ck := _ck(tn)
	var specs := _mass_specs(tn)
	if PEND.has(ck):
		WorkerThreadPool.wait_for_task_completion(PEND[ck][0])
		CT.CACHE[ck] = PEND[ck][1]
		PEND.erase(ck)
	if not CT.CACHE.has(ck):
		var res := {}
		_build_set(specs, res)
		CT.CACHE[ck] = res
	var C: Dictionary = CT.CACHE[ck]
	for sp in specs:
		_add_mass(n_walls if sp[4] == 0 else n_rock, CT.finish(C[sp[0]]), sp[3], sp[5])

func _add_mass(par: Node2D, m: Dictionary, gain: float, shadow: bool) -> void:
	var sn: Node2D = null
	if shadow:
		sn = Node2D.new()
		sn.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sn.draw.connect(_draw_mass_shadow.bind(sn, m))
		par.add_child(sn)
	var n := Node2D.new()
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = CT.shader()
	mat.set_shader_parameter("deep", not arena.low_end)
	n.material = mat
	n.draw.connect(_draw_mass.bind(n, m))
	par.add_child(n)
	masses.append({"m": m, "n": n, "s": sn, "gain": gain})

func _draw_mass(n: Node2D, m: Dictionary) -> void:
	n.draw_texture_rect(m["tex"], Rect2(CT.jr(m["ox"]), CT.jr(m["oy"]), m["w"] * 2.0, m["h"] * 2.0), false)

func _draw_mass_shadow(n: Node2D, m: Dictionary) -> void:
	var sb: Dictionary = CT.shadow_of(m)
	var t: Texture2D = sb["tex"]
	var p: float = sb["pad"] * 2.0
	n.draw_texture_rect(t, Rect2(CT.jr(m["ox"]) + 10.0 - p, CT.jr(m["oy"]) + 14.0 - p, t.get_width() * 2.0, t.get_height() * 2.0), false, Color(1, 1, 1, 0.6))


# ---------- light ----------
## lightSources() in the cave: wall torches, hanging lanterns, glowing mushrooms and crystals, the camp fire, the chest,
## the doors (an open one, or the boss door even sealed), the cave eyes, and a faint glow around the heroine
func _light_sources(tt: float) -> Array:
	var out: Array = []
	var G: float = arena.ground_y
	for p in tpl["props"]:
		var y: float = G - p[2]
		var k: String = p[0]
		var mode: String = p[3] if p.size() > 3 else ""
		var x: float = p[1]
		if mode == "w": out.append({"k": "fire", "x": x, "y": y - 164.0, "gy": y, "r": 230.0, "a": LIT.fl(tt, x * 0.01) * 1.25, "c": Color8(255, 160, 80)})
		elif mode == "c": out.append({"k": "soft", "x": x, "y": y - 184.0, "r": 170.0, "a": 0.85, "c": Color8(255, 196, 110)})
		elif k.begins_with("mush"): out.append({"k": "soft", "x": x, "y": y - 30.0, "r": 150.0 if k == "mushL" else 100.0, "a": 0.75, "c": Color8(90, 255, 210)})
		elif k.begins_with("crys"): out.append({"k": "soft", "x": x, "y": y - 35.0, "r": 150.0 if k == "crysL" else 100.0, "a": 0.7, "c": Color8(190, 120, 255)})
	if room()["type"] == "camp": out.append({"k": "fire", "x": tpl["w"] * 0.75, "y": G - 36.0, "gy": G, "r": 300.0, "a": LIT.fl(tt, 5.0) * 1.1, "c": Color8(255, 150, 70)})
	if chest != null: out.append({"k": "soft", "x": chest["x"], "y": G - 40.0, "r": 160.0, "a": 0.8, "c": Color8(255, 220, 130)})
	for d in doors:
		if d["boss"] and not gate_open: continue
		var kd := door_kind(d)
		var ko: float = 1.0 if d["town"] else open_k
		if gate_open or d["town"] or DOORPT.has(kd):
			out.append({"k": "soft", "x": d["x"], "y": d["y"] - 50.0, "r": 150.0 + 110.0 * ko, "a": DOORA[kd] * (0.6 + 0.6 * ko), "c": DOORSTY[kd]})
	for m in arena.mobs:
		if m.kind == "eye" and not m.is_dead():
			out.append({"k": "soft", "x": m.position.x, "y": m.position.y - 30.0, "r": 90.0, "a": 0.6, "c": Color8(200, 120, 255)})
	var P = arena.player
	out.append({"k": "player", "x": P.position.x, "y": P.position.y - 70.0, "r": 160.0, "a": 0.35, "c": Color8(230, 220, 255)})
	return out

## per frame: the light list, the cave's ambient (todNow at 22:30, the weather included), and each mass's edge light
func _light_step(tt: float) -> void:
	if tpl.is_empty(): return
	L = _light_sources(tt)
	L_rim = L.filter(func(l): return l["k"] != "player" and (l["k"] != "soft" or l["r"] > 100.0))
	var h: float = arena.tod_h
	arena.tod_h = 22.5
	amb = arena.tod_now()["amb"]
	arena.tod_h = h
	lit.L = L
	lit.amb = amb
	lit.redraw()
	var vr: Rect2 = arena.view_rect()
	for e in masses:
		var m: Dictionary = e["m"]
		var x := CT.jr(m["ox"])
		var y := CT.jr(m["oy"])
		var w: float = m["w"] * 2.0
		var hh: float = m["h"] * 2.0
		var on: bool = not (x > vr.end.x + 60.0 or x + w < vr.position.x - 60.0)
		e["n"].visible = on
		if e["s"] != null: e["s"].visible = on
		if not on: continue
		var mat: ShaderMaterial = e["n"].material
		if e["gain"] <= 0.0:
			mat.set_shader_parameter("on", 0)
			continue
		var P: Array = CT.rim_params(x, y, w, hh, L_rim, e["gain"])
		mat.set_shader_parameter("rc", P[0])
		mat.set_shader_parameter("rd", P[1])
		mat.set_shader_parameter("fk", 0.94 + 0.06 * sin(tt * 7.0 + x * 0.01))
		mat.set_shader_parameter("on", 1)

## rimLights() in the cave: DUN._L (no player light, no small glows), [pos, r, strength, colour] for char_pix and the mobs
func rim_lights() -> Array:
	var out: Array = []
	for l in L_rim:
		out.append([Vector2(l["x"], l["y"]), l["r"], l["a"], l["c"]])
	return out

func _redraw_all() -> void:
	for n in [n_doors, n_door_add, n_props, n_misc, front, front_add, bg_node]:
		n.queue_redraw()


# ---------- drawing ----------
func _img(k: String, x: float, y: float, s := 1.0, flip := false, col := Color.WHITE, ci: CanvasItem = null) -> void:
	if not tex.has(k): return
	if ci == null: ci = self
	var t: Texture2D = tex[k]
	var w := roundf(t.get_width() * s)
	var h := roundf(t.get_height() * s)
	if flip:
		ci.draw_set_transform(Vector2(roundf(x), 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(t, Rect2(-roundf(w / 2.0), roundf(y - h), w, h), false, col)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(t, Rect2(roundf(x - w / 2.0), roundf(y - h), w, h), false, col)

## a radial falloff (the prototype's two-stop radial gradients), optionally clipped to a rect
func _radial(ci: CanvasItem, c: Vector2, r: float, col: Color, a: float, clip := Rect2()) -> void:
	if a <= 0.003: return
	var t := LIT.soft_tex()
	var full := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
	var dst := full if clip.size == Vector2.ZERO else full.intersection(clip)
	if dst.size.x <= 0.0 or dst.size.y <= 0.0: return
	var ts := t.get_size()
	var src := Rect2((dst.position - full.position) / full.size * ts, dst.size / full.size * ts)
	ci.draw_texture_rect_region(t, dst, src, Color(col, a))

func _draw_bg() -> void:
	var vs := get_viewport_rect().size
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color8(26, 21, 38))
	var im: Texture2D = tex["bg"]
	var c: Vector2 = arena.cam.get_screen_center_position()
	var left := c.x - vs.x / 2.0
	var vy := clampf(-(c.y - H / 2.0) * 0.03, -10.0, 10.0)
	var sc := maxf(1.0, vs.y / im.get_height())
	var w := im.get_width() * sc
	var y := (vs.y - im.get_height() * sc) / 2.0 + vy
	var off := fposmod(left * 0.12, w)
	var x := -off
	var i := 0
	while x < vs.x:
		if i % 2 == 1:
			bg_node.draw_set_transform(Vector2(x + w, y), 0.0, Vector2(-1, 1))
			bg_node.draw_texture_rect(im, Rect2(0, 0, w, im.get_height() * sc), false)
			bg_node.draw_set_transform(Vector2.ZERO)
		else:
			bg_node.draw_texture_rect(im, Rect2(x, y, w, im.get_height() * sc), false)
		x += w
		i += 1
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color(8 / 255.0, 5 / 255.0, 16 / 255.0, 0.25))

## wall fixtures and the few props that match the set (drawDungeon): torches, lanterns on their chains, mushrooms, crystals
func _draw_props() -> void:
	if tpl.is_empty(): return
	var G: float = arena.ground_y
	var tt := Time.get_ticks_msec() / 1000.0
	var cy := ceil_y()
	for p in tpl["props"]:
		var y: float = G - p[2]
		var k: String = p[0]
		var x: float = p[1]
		var mode: String = p[3] if p.size() > 3 else ""
		if mode == "w":
			_img("torchF", x, y - 110.0, 1.0, false, Color.WHITE, n_props)
			_img("fflame%d" % (int(floorf(tt * 9.0 + x)) % 4), x, y - 150.0, 1.0, false, Color.WHITE, n_props)
		elif mode == "c":
			# lanternChain: up to the ceiling, or to a ledge above it
			var yb := y - 150.0 - 112.0
			var yt := minf(yb - 40.0, cy + 20.0)
			for pl in arena.platforms:
				if x > pl.x and x < pl.x + pl.w and pl.y + 40.0 < yb and pl.y + 40.0 > yt: yt = pl.y + 40.0
			var ch: Texture2D = tex["chain"]
			var yy := yb - ch.get_height()
			while yy > yt - ch.get_height():
				var y0 := maxf(yt, yy)
				n_props.draw_texture_rect(ch, Rect2(roundf(x - ch.get_width() / 2.0), roundf(y0), ch.get_width(), minf(ch.get_height(), yb - y0)), false)
				yy -= ch.get_height() - 6.0
			_img("lantern", x, y - 150.0, 1.0, false, Color.WHITE, n_props)
		elif k.begins_with("mush") or k.begins_with("crys"):
			_img(k, x, y + 4.0, 1.0, int(x * 7) % 3 == 0, Color.WHITE, n_props)

## drawDoors: one shared timber frame in a pool of shade, the boards while sealed, a crooked signboard
func _draw_doors() -> void:
	if tpl.is_empty(): return
	var fr: Texture2D = tex["dframe"]
	var tt := Time.get_ticks_msec() / 1000.0
	var ci := n_doors
	for d in doors:
		if d["boss"] and not gate_open: continue
		var kd := door_kind(d)
		var open: bool = gate_open or d["town"]
		var k: float = 1.0 if d["town"] and not d["boss"] else open_k
		var w := fr.get_width()
		var h := fr.get_height()
		var x: float = roundf(d["x"] - w / 2.0)
		var y: float = roundf(d["y"] + 8.0 - h)
		_radial(ci, Vector2(d["x"], d["y"] - h * 0.45), w * 0.9, Color8(6, 4, 12), 0.5, Rect2(d["x"] - w, d["y"] - h * 1.5, w * 2.0, h * 1.6))
		ci.draw_texture(fr, Vector2(x, y))
		if not open:
			var pk: Texture2D = tex["dplank"]
			ci.draw_texture(pk, Vector2(roundf(d["x"] - pk.get_width() / 2.0), roundf(d["y"] + 8.0 - pk.get_height())))
		ci.draw_rect(Rect2(x, y, w, h), Color(Color8(12, 8, 22), 0.18 * (1.0 - k)))
		var si: int = SIGNI.get(kd, 0)
		var sg: Texture2D = tex["sign%d" % si]
		ci.draw_set_transform(_sign_at(d, y, sg), _sign_ang(d, tt))
		ci.draw_texture(sg, -sg.get_size() / 2.0)
		ci.draw_set_transform(Vector2.ZERO)
	# the camp fire, the chest and the door tags come after the rock (n_misc)

func _sign_at(d: Dictionary, y: float, sg: Texture2D) -> Vector2:
	var sx: float = d["x"] + fmod(d["x"] * 7.0, 13.0) - 6.0
	return Vector2(roundf(sx), roundf(y - sg.get_height() * 0.5 + 12.0))

func _sign_ang(d: Dictionary, tt: float) -> float:
	var v: float = sin(d["x"] * 12.9898 + d["y"] * 4.1) * 43758.5
	return fmod(v, 1.0) * 0.11 + (-0.03 if d["d"] == "L" else 0.03) + sin(tt * 1.3 + d["x"]) * 0.006

## the light of an open door (added): the opening fills with an arch of light, dimmer under the lintel and against the
## posts, brightest low in the middle, with motes drifting in it; a glow around the opening; a flash as the boards go;
## the signboard's paint glows in the door's colour
func _draw_doors_add() -> void:
	if tpl.is_empty(): return
	var fr: Texture2D = tex["dframe"]
	var tt := Time.get_ticks_msec() / 1000.0
	var ci := n_door_add
	for d in doors:
		if d["boss"] and not gate_open: continue
		var kd := door_kind(d)
		var c: Color = DOORSTY[kd]
		var open: bool = gate_open or d["town"]
		var k: float = 1.0 if d["town"] and not d["boss"] else open_k
		var w := fr.get_width()
		var h := fr.get_height()
		var x: float = roundf(d["x"] - w / 2.0)
		var y: float = roundf(d["y"] + 8.0 - h)
		var ox0: float = x + DOPEN[0]
		var oy0: float = y + DOPEN[1]
		var ow: float = DOPEN[2] - DOPEN[0]
		var oh: float = DOPEN[3] - DOPEN[1]
		var ocx := ox0 + ow / 2.0
		if open and k > 0.0:
			var fl := (0.82 + 0.18 * sin(tt * 9.0) * sin(tt * 5.3)) if kd == "camp" else ((0.72 + 0.28 * sin(tt * 2.2)) if kd == "boss" else (0.92 + 0.08 * sin(tt * 3.1 + d["x"])))
			var A := k * fl
			var fy: float = d["y"] + 6.0
			var clip := Rect2(ox0, oy0, ow, fy - oy0)
			var ym := oy0 + (fy - oy0) * 0.3
			ci.draw_polygon(PackedVector2Array([Vector2(ox0, oy0), Vector2(ox0 + ow, oy0), Vector2(ox0 + ow, ym), Vector2(ox0, ym)]),
				PackedColorArray([Color(c, 0.35 * A), Color(c, 0.35 * A), Color(c, 0.6 * A), Color(c, 0.6 * A)]))
			ci.draw_polygon(PackedVector2Array([Vector2(ox0, ym), Vector2(ox0 + ow, ym), Vector2(ox0 + ow, fy), Vector2(ox0, fy)]),
				PackedColorArray([Color(c, 0.6 * A), Color(c, 0.6 * A), Color(c, 0.75 * A), Color(c, 0.75 * A)]))
			var y6 := oy0 + 6.0
			for half in 2:
				var xa := ox0 + ow * 0.5 * half
				var xb := xa + ow * 0.5
				var aa := 0.0 if half == 0 else 0.45 * A
				var ab := 0.45 * A if half == 0 else 0.0
				ci.draw_polygon(PackedVector2Array([Vector2(xa, y6), Vector2(xb, y6), Vector2(xb, fy), Vector2(xa, fy)]),
					PackedColorArray([Color(c, aa), Color(c, ab), Color(c, ab), Color(c, aa)]))
			_radial(ci, Vector2(ocx, fy - oh * 0.22), oh * 0.72, Color8(255, 248, 230), 0.6 * A, clip)
			for i in 8:
				var sp := 0.4 + (i % 4) * 0.25
				var mx := ox0 + 6.0 + fmod(i * 37.0 + sin(tt * 0.7 + i) * 10.0 + ow * 4.0, ow - 12.0)
				var my := fy - 6.0 - fmod(tt * 22.0 * sp + i * 53.0, oh - 14.0)
				ci.draw_rect(Rect2(roundf(mx), roundf(my), 2, 2), Color(Color8(255, 246, 220), 0.5 * A * (0.5 + 0.5 * sin(tt * 2.0 + i * 1.3))))
			_radial(ci, Vector2(ocx, oy0 + oh * 0.6), ow * 1.25, c, 0.22 * A, Rect2(ocx - ow * 1.3, oy0 - ow * 0.7, ow * 2.6, oh + ow * 0.8))
			if open_k < 1.0 and not d["town"]:
				ci.draw_rect(Rect2(ox0 - open_k * 24.0, oy0 - open_k * 16.0, ow + open_k * 48.0, fy - oy0 + open_k * 16.0), Color(c, 0.6 * (1.0 - open_k)))
		var si: int = SIGNI.get(kd, 0)
		var sg: Texture2D = tex["sign%d" % si]
		var em: Array = sign_w[si]
		ci.draw_set_transform(_sign_at(d, y, sg), _sign_ang(d, tt))
		ci.draw_texture(em[0], -sg.get_size() / 2.0, Color(c, 0.22 + 0.6 * k))
		if k > 0.0:
			var bt: Texture2D = em[1]
			ci.draw_texture(bt, -bt.get_size() / 2.0, Color(c, 0.35 * k))
		ci.draw_set_transform(Vector2.ZERO)

## after the rock, still under the light pass: the camp fire, the chest, the door tags
func _draw_misc() -> void:
	if tpl.is_empty(): return
	var G: float = arena.ground_y
	var tt := Time.get_ticks_msec() / 1000.0
	var ci := n_misc
	var rm := room()
	var fnt: Font = arena.font_black
	if rm["type"] == "camp":
		var x: float = tpl["w"] * 0.75
		ci.draw_rect(Rect2(x - 24.0, G - 6.0, 48.0, 6.0), Color8(58, 42, 32))
		var fi := int(tt * 10.0) % 4
		_img("flame%d" % fi, x, G - 2.0, 1.4, false, Color.WHITE, ci)
		_img("flame%d" % ((fi + 2) % 4), x - 12.0, G - 2.0, 1.0, false, Color.WHITE, ci)
		_img("flame%d" % ((fi + 1) % 4), x + 12.0, G - 2.0, 1.0, false, Color.WHITE, ci)
		var s3: String = "쉬었다" if rm.get("rest_used", false) else "모닥불 — 다가가면 회복"
		var tw3 := fnt.get_string_size(s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		ci.draw_string(fnt, Vector2(x - tw3 / 2.0, G - 110.0), s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.86, 0.86, 0.86, 0.5) if rm.get("rest_used", false) else Color("#ffe9a8"))
	if chest != null:
		var cx: float = chest["x"]
		ci.draw_rect(Rect2(cx - 26.0, G - 34.0, 52.0, 34.0), Color8(90, 58, 32))
		ci.draw_rect(Rect2(cx - 26.0, G - 44.0, 52.0, 14.0), Color8(122, 82, 48))
		ci.draw_rect(Rect2(cx - 4.0, G - 34.0, 8.0, 10.0), Color8(232, 192, 96))
	var ARW := {"L": "◀", "R": "▶", "U": "▲", "D": "▼"}
	for d in doors:
		if d["boss"] and not gate_open: continue
		var open: bool = gate_open or (d["town"] and not d["boss"])
		var tag: String = "마을로" if d["town"] else ARW[d["d"]]
		if not d["town"]:
			var n = rooms.get(rkey(rm["x"] + DIRS[d["d"]][0], rm["y"] + DIRS[d["d"]][1]))
			if n != null and n["visited"]:
				tag += " " + {"boss": "보스", "camp": "쉼터", "vault": "보물", "start": "입구"}.get(n["type"], "")
			elif n != null and n["type"] == "boss":
				tag += " ☠"
		var tw := fnt.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0
		var y: float = d["y"] - 248.0
		ci.draw_rect(Rect2(d["x"] - tw / 2.0, y - 15.0, tw, 22.0), Color(0.04, 0.03, 0.05, 0.75))
		ci.draw_string(fnt, Vector2(d["x"] - tw / 2.0 + 10.0, y + 1.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffe9a8") if open else Color("#9c917a"))

## drawDoorSpill: the floor in front of an open door, soft pools of its light on the walkable surface (added, after the
## light pass); the frame itself is not lit by it
func _draw_spill() -> void:
	if tpl.is_empty(): return
	var fr: Texture2D = tex["dframe"]
	var tt := Time.get_ticks_msec() / 1000.0
	var w := float(fr.get_width())
	var ow: float = DOPEN[2] - DOPEN[0]
	var st := LIT.soft_tex()
	for d in doors:
		if d["boss"] and not gate_open: continue
		if not (gate_open or d["town"]): continue
		var kd := door_kind(d)
		var k: float = 1.0 if d["town"] and not d["boss"] else open_k
		if k <= 0.0: continue
		var fl := (0.82 + 0.18 * sin(tt * 9.0) * sin(tt * 5.3)) if kd == "camp" else ((0.72 + 0.28 * sin(tt * 2.2)) if kd == "boss" else (0.92 + 0.08 * sin(tt * 3.1 + d["x"])))
		var A := k * fl
		var cx: float = roundf(d["x"] - w / 2.0) + DOPEN[0] + ow / 2.0
		var fy: float = d["y"] - SURF + 3.0
		for e in [[w * 1.3, 18.0, 0.42, 0.0], [w * 0.62, 10.0, 0.5, ow * 0.18 * sin(tt * 0.6 + d["x"])], [w * 0.5, 8.0, 0.4, -ow * 0.22], [ow * 0.62, 3.5, 0.9, 0.0]]:
			front_add.draw_texture_rect(st, Rect2(cx + e[3] - e[0], fy - e[1], e[0] * 2.0, e[1] * 2.0), false, Color(DOORSTY[kd], e[2] * A))

## drawDungeonFront (after the light pass): floating spores, low fog hugging the floor, the door prompt
func _draw_front() -> void:
	if tpl.is_empty(): return
	var G: float = arena.ground_y
	var tt := Time.get_ticks_msec() / 1000.0
	for s in spores:
		var a: float = 0.45 + 0.4 * sin(tt * 2.0 + s["ph"])
		var sz: float = s["s"]
		front.draw_rect(Rect2(roundf(s["x"]) - sz, roundf(s["y"]) - sz, sz * 2.0 + 2.0, sz * 2.0 + 2.0), Color(s["c"], a * 0.25))
		front.draw_rect(Rect2(roundf(s["x"]), roundf(s["y"]), sz, sz), Color(s["c"], a))
	var vr: Rect2 = arena.view_rect()
	for i in 3:
		var off := fposmod(tt * (8.0 + i * 5.0) + i * 300.0, 600.0)
		var x := floorf((vr.position.x - off) / 600.0) * 600.0 + off - 600.0
		while x < vr.end.x + 600.0:
			front.draw_set_transform(Vector2(x + 300.0, G - 14.0 - i * 10.0), 0.0, Vector2(1.0, (26.0 - i * 4.0) / 320.0))
			front.draw_circle(Vector2.ZERO, 320.0, Color(120 / 255.0, 100 / 255.0, 170 / 255.0, 0.06 - i * 0.015))
			x += 600.0
		front.draw_set_transform(Vector2.ZERO)
	if near_gate != null:
		var fnt: Font = arena.font_black
		var d2 = near_gate
		var s: String = arena.cfg.kh() + ("마을로 돌아가기" if d2["town"] else "이동")
		var tw2 := fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
		var y2: float = d2["y"] - 280.0 + sin(tt * 4.0) * 3.0
		front.draw_rect(Rect2(d2["x"] - tw2 / 2.0, y2 - 16.0, tw2, 24.0), Color(0, 0, 0, 0.6))
		front.draw_string(fnt, Vector2(d2["x"] - tw2 / 2.0 + 10.0, y2 + 1.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffe9a8"))
