extends Node2D
## 버섯 동굴: a side-scrolling map of wide rooms (a left→right spine from the entrance to the boss, plus 1–2 side branches
## that climb or drop a floor and lead to a treasure or rest room). Ported from the prototype's dunReset / dungeonEnter /
## updDungeon and its cave drawing. Rock is drawn as textured polygons; torches, lanterns, mushrooms and crystals are real lights.

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
const SIGNI := {"fight": 0, "boss": 1, "vault": 2, "camp": 3, "start": 4, "town": 4}
const DOPEN := [30, 26, 122, 170]

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
var dress: Array = []
var spores: Array = []
var tex := {}
var t_rock: Texture2D
var t_wall: Texture2D
var lights: Node2D
var cmod: CanvasModulate
var bg_layer: CanvasLayer
var bg_node: Node2D
var front: Node2D
var light_tex: GradientTexture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	z_index = -5
	light_mask = 3                   # lit by the cave's lights (cull mask 2); characters are not
	for f in DirAccess.get_files_at("res://assets/cave"):
		if f.ends_with(".png"):
			tex[f.get_basename()] = load("res://assets/cave/" + f)
		elif f.ends_with(".png.import"):
			var k := f.get_basename().get_basename()
			if not tex.has(k): tex[k] = load("res://assets/cave/" + k + ".png")
	t_rock = tex["rtex"]
	t_wall = _wall_tile()
	light_tex = GradientTexture2D.new()
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(1.0, 0.5)
	light_tex.width = 256
	light_tex.height = 256
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	light_tex.gradient = gr
	lights = Node2D.new()
	add_child(lights)
	cmod = CanvasModulate.new()
	cmod.color = Color(0.62, 0.58, 0.74)
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
	front.light_mask = 3
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.draw.connect(_draw_front)
	arena.add_child(front)


func cleanup() -> void:
	cmod.queue_free()
	bg_layer.queue_free()
	front.queue_free()
	queue_free()


## the wall-kit stone, mirrored into a seamless tile (art region [104,2,95,95], 1 art px = 2 world px)
func _wall_tile() -> Texture2D:
	var src: Image = (tex["wkit"] as Texture2D).get_image()
	src.decompress()
	var part := src.get_region(Rect2i(104, 2, 95, 95))
	var im := Image.create(190, 190, false, part.get_format())
	im.blit_rect(part, Rect2i(0, 0, 95, 95), Vector2i(0, 0))
	var fx := part.duplicate()
	fx.flip_x()
	im.blit_rect(fx, Rect2i(0, 0, 95, 95), Vector2i(95, 0))
	var fy := part.duplicate()
	fy.flip_y()
	im.blit_rect(fy, Rect2i(0, 0, 95, 95), Vector2i(0, 95))
	var fxy := fx.duplicate()
	fxy.flip_y()
	im.blit_rect(fxy, Rect2i(0, 0, 95, 95), Vector2i(95, 95))
	return ImageTexture.create_from_image(im)


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
	dress = _dressing()
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
	_build_lights()
	queue_redraw()

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
	_flicker(tt)
	queue_redraw()
	front.queue_redraw()
	bg_node.queue_redraw()

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


# ---------- set dressing ----------
func _rnd_seq(seed: int) -> Callable:
	var st := [seed]
	return func() -> float:
		st[0] = (st[0] * 9301 + 49297) % 233280
		return float(st[0]) / 233280.0

func _wall_segs() -> Array:
	var rnd := _rnd_seq(int(tpl["w"]) * 3 + int(tpl["top"]))
	var segs: Array = []
	for p in tpl["props"]:
		if p.size() > 3 and p[3] == "w":
			segs.append([p[1] - 170.0 - rnd.call() * 80.0, p[1] + 170.0 + rnd.call() * 80.0, p[2] + 250.0 + rnd.call() * 80.0])
	for s in tpl["solids"]:
		if rnd.call() < 0.7:
			segs.append([s[0] - 60.0, s[0] + s[1] + 60.0, s[2] + 200.0 + rnd.call() * 120.0])
	segs.sort_custom(func(a, b): return a[0] < b[0])
	var m: Array = []
	for s0 in segs:
		var s1 := [maxf(-40.0, s0[0]), minf(tpl["w"] + 40.0, s0[1]), minf(tpl["top"] + 170.0, s0[2])]
		if not m.is_empty() and s1[0] < m[-1][1] + 60.0:
			m[-1][1] = maxf(m[-1][1], s1[1])
			m[-1][2] = maxf(m[-1][2], s1[2])
		else:
			m.append(s1)
	var out: Array = []
	for i in m.size():
		out.append({"x0": m[i][0], "x1": m[i][1], "h": m[i][2], "poly": _wall_poly(m[i][0], m[i][1], m[i][2], int(m[i][0]) * 7 + int(m[i][2]) + i * 131)})
	return out

## an organic, angular back-wall silhouette: chunky facets along a crest with 1–3 shoulders
func _wall_poly(x0: float, x1: float, h: float, seed: int) -> PackedVector2Array:
	var rnd := _rnd_seq(seed)
	var G: float = arena.ground_y
	var w := x1 - x0
	var tl: float = w * (0.08 + rnd.call() * 0.08)
	var tr: float = w * (0.08 + rnd.call() * 0.08)
	var peaks: Array = []
	for i in 1 + int(rnd.call() * 3):
		peaks.append([x0 + tl + rnd.call() * (w - tl - tr), (24.0 + rnd.call() * 36.0)])
	var top := G - h
	var pts := PackedVector2Array()
	pts.append(Vector2(x0, G + 30))
	pts.append(Vector2(x0 + tl * 0.3, top + 80))
	var x: float = x0 + tl
	while x <= x1 - tr:
		var y := top + 52.0
		for pk in peaks:
			y -= maxf(0.0, pk[1] * (1.0 - absf(x - pk[0]) / (w * 0.35)))
		y += (rnd.call() - 0.5) * 16.0
		pts.append(Vector2(x, roundf(y / 2.0) * 2.0))
		x += 20.0 + floorf(rnd.call() * 28.0)
	pts.append(Vector2(x1 - tr * 0.3, top + 80))
	pts.append(Vector2(x1, G + 30))
	return pts

func _dressing() -> Array:
	var rnd := _rnd_seq(int(tpl["w"]) + int(tpl["top"]) * 3)
	var d: Array = []
	var door_xs: Array = tpl["door"].values().map(func(a): return a[0])
	var free := func(x: float) -> bool: return not door_xs.any(func(dx): return absf(dx - x) < 170.0) and not tpl["solids"].any(func(s): return x > s[0] - 60.0 and x < s[0] + s[1] + 60.0)
	var x := 200.0
	while x < tpl["w"] - 150.0:
		if free.call(x): d.append(["back", "pillarA" if rnd.call() < 0.5 else "pillarB", x, 0.0])
		x += 520.0 + rnd.call() * 300.0
	for s in tpl["solids"]:
		if s[0] > 40: d.append(["front", "bouldM", s[0] - 10.0, 0.0])
		if s[0] + s[1] < tpl["w"] - 40: d.append(["front", "bouldS", s[0] + s[1] + 14.0, 0.0])
	for l in tpl["ledges"]:
		if l[2] >= 220: d.append(["hang", "mossA" if rnd.call() < 0.5 else "mossB", l[0] + l[2] * (0.3 + rnd.call() * 0.4), float(l[1])])
	x = 380.0
	while x < tpl["w"] - 200.0:
		if free.call(x): d.append(["front", "bouldL" if rnd.call() < 0.5 else "bouldS", x, 0.0])
		x += 700.0 + rnd.call() * 400.0
	return d


# ---------- lights ----------
func _add_light(p: Vector2, r: float, col: Color, energy: float, flick: bool) -> void:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.texture_scale = r * 2.2 / 256.0
	l.color = col
	l.energy = energy
	l.position = p
	l.range_item_cull_mask = 2      # the cave only (light_mask 3): characters, mobs and loot keep the ambient and their rim light
	l.set_meta("e0", energy)
	l.set_meta("flick", flick)
	l.set_meta("ph", p.x * 0.01)
	lights.add_child(l)

func _build_lights() -> void:
	for c in lights.get_children():
		c.queue_free()
	var G: float = arena.ground_y
	for p in tpl["props"]:
		var y: float = G - p[2]
		var k: String = p[0]
		var mode: String = p[3] if p.size() > 3 else ""
		if mode == "w": _add_light(Vector2(p[1], y - 164.0), 230.0, Color8(255, 160, 80), 1.15, true)
		elif mode == "c": _add_light(Vector2(p[1], y - 184.0), 170.0, Color8(255, 196, 110), 0.85, false)
		elif k.begins_with("mush"): _add_light(Vector2(p[1], y - 30.0), 150.0 if k == "mushL" else 100.0, Color8(90, 255, 210), 0.75, false)
		elif k.begins_with("crys"): _add_light(Vector2(p[1], y - 35.0), 150.0 if k == "crysL" else 100.0, Color8(190, 120, 255), 0.7, false)
	if room()["type"] == "camp": _add_light(Vector2(tpl["w"] * 0.75, G - 36.0), 300.0, Color8(255, 150, 70), 1.1, true)
	if chest != null: _add_light(Vector2(chest["x"], G - 40.0), 160.0, Color8(255, 210, 100), 0.8, false)
	for d in doors:
		var c: Color = DOORSTY[door_kind(d)]
		_add_light(Vector2(d["x"], d["y"] - 70.0), 190.0, c, 0.0, false)
		lights.get_child(lights.get_child_count() - 1).set_meta("door", d)
	_add_light(Vector2.ZERO, 260.0, Color8(255, 230, 210), 0.45, false)
	lights.get_child(lights.get_child_count() - 1).set_meta("player", true)

func _flicker(tt: float) -> void:
	var vr: Rect2 = arena.view_rect()
	for l in lights.get_children():
		# a light renders only when its circle reaches the screen (each one is another pass over what it touches)
		l.visible = l.has_meta("player") or vr.grow(l.texture_scale * 32.0).has_point(l.position)
		if l.has_meta("player"):
			l.position = arena.player.position + Vector2(0, -70)
		elif l.has_meta("door"):
			var d: Dictionary = l.get_meta("door")
			var open: bool = (gate_open or d["town"]) and not (d["boss"] and not gate_open)
			l.energy = (1.0 if d["town"] and not d["boss"] else open_k) * (0.9 if open else 0.0)
			if l.energy <= 0.01: l.visible = false     # a shut door's light costs a pass for nothing
		elif l.get_meta("flick"):
			var ph: float = l.get_meta("ph")
			l.energy = l.get_meta("e0") * (0.85 + 0.1 * sin(tt * 7.0 + ph) + 0.05 * sin(tt * 19.0 + ph * 3.0))


# ---------- drawing ----------
func ceil_y() -> float:
	return arena.ground_y - tpl["top"] - 250.0

func _thsh(i: float, s: float) -> float:
	var v := sin(i * 127.1 + s * 311.7) * 43758.5453
	return v - floorf(v)

## a rock block: textured polygon (rock texture at 2 world px per art px), jittered sides, lit left band, shaded right band, dark outline
func rock(x0: float, x1: float, y0: float, y1: float, lip: bool, fringe: bool, jag := 6.0) -> void:
	var sd := x0 + y0
	var pts := PackedVector2Array()
	var x := x0 + 6.0
	while x <= x1 - 6.0:
		pts.append(Vector2(x, y0))
		x += 8.0
	pts.append(Vector2(x1 - 6.0, y0))
	pts.append(Vector2(x1, y0 + 6.0))
	var y := y0 + 6.0
	while y <= y1:
		pts.append(Vector2(x1 + roundf((_thsh(y, sd + 1.0) - 0.5) * jag * 2.0), y))
		y += 10.0
	pts.append(Vector2(x1, y1))
	pts.append(Vector2(x0, y1))
	y = y1
	while y >= y0 + 6.0:
		pts.append(Vector2(x0 + roundf((_thsh(y, sd + 2.0) - 0.5) * jag * 2.0), y))
		y -= 10.0
	pts.append(Vector2(x0, y0 + 6.0))
	_poly_tex(pts, t_rock, 2.0, Color.WHITE)
	draw_rect(Rect2(x0 - 4.0, y0, 10.0, y1 - y0), Color(0.75, 0.69, 0.86, 0.12))
	draw_rect(Rect2(x1 - 8.0, y0, 12.0, y1 - y0), Color(0.06, 0.04, 0.1, 0.3))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color8(23, 16, 31), 2.0)
	if lip: _lip(x0 + 2.0, x1 - 2.0, y0)
	if fringe: _fringe(x0 + 4.0, x1 - 4.0, y1 - 8.0)

func _poly_tex(pts: PackedVector2Array, t: Texture2D, k: float, col: Color) -> void:
	pts = clean_poly(pts)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		for part in Geometry2D.decompose_polygon_in_convex(pts):
			_poly_tex_raw(part, t, k, col)
		return
	_poly_tex_raw(pts, t, k, col)

## drop repeated and collinear points so the polygon always triangulates
static func clean_poly(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_to(p) > 0.5:
			out.append(p)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) < 0.5:
		out.remove_at(out.size() - 1)
	var i := 0
	while out.size() > 3 and i < out.size():
		var a := out[(i - 1 + out.size()) % out.size()]
		var b := out[i]
		var c := out[(i + 1) % out.size()]
		if absf((b - a).cross(c - b)) < 0.01:
			out.remove_at(i)
		else:
			i += 1
	return out

func _poly_tex_raw(pts: PackedVector2Array, t: Texture2D, k: float, col: Color) -> void:
	var uvs := PackedVector2Array()
	var sz := t.get_size() * k
	for p in pts:
		uvs.append(Vector2(p.x / sz.x, p.y / sz.y))
	draw_colored_polygon(pts, col, uvs, t)

## moss lip: the top rows of the tile set's top piece, tiled (mirrored every other) along an edge
func _lip(x0: float, x1: float, y: float) -> void:
	var t: Texture2D = tex["tT"]
	var x := floorf(x0 / 80.0) * 80.0
	var i := int(x / 80.0)
	while x < x1:
		var a := maxf(x, x0)
		var b := minf(x + 80.0, x1)
		var src := Rect2(a - x, 0, b - a, 14)
		if i % 2 == 1:
			src = Rect2(80.0 - (b - x), 0, b - a, 14)
		draw_texture_rect_region(t, Rect2(a, y - 4.0, b - a, 14.0), src)
		x += 80.0
		i += 1

## stalactite fringe under a ledge, tapering toward both ends
func _fringe(x0: float, x1: float, y: float) -> void:
	var t: Texture2D = tex["rfringe"]
	var w := 352.0
	var x := floorf(x0 / w) * w
	while x < x1:
		var a := maxf(x, x0)
		var b := minf(x + w, x1)
		var edge := minf(a - x0, x1 - b)
		var k := clampf(edge / 60.0, 0.35, 1.0)
		draw_texture_rect_region(t, Rect2(a, y, b - a, 64.0 * k), Rect2((a - x) / 2.0, 7, (b - a) / 2.0, 32))
		x += w

func _img(k: String, x: float, y: float, s := 1.0, flip := false, col := Color.WHITE, ci: CanvasItem = null) -> void:
	if not tex.has(k): return
	if ci == null: ci = self
	var t: Texture2D = tex[k]
	var w := t.get_width() * s
	var h := t.get_height() * s
	if flip:
		ci.draw_set_transform(Vector2(x, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(t, Rect2(-w / 2.0, y - h, w, h), false, col)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(t, Rect2(x - w / 2.0, y - h, w, h), false, col)

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
	bg_node.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.06, 0.25))

func _draw() -> void:
	if tpl.is_empty(): return
	var G: float = arena.ground_y
	var tt := Time.get_ticks_msec() / 1000.0
	var cy := ceil_y()
	# back walls and pillars
	for w in walls:
		_poly_tex(w["poly"], t_wall, 2.0, Color(0.72, 0.68, 0.8))
		var cl: PackedVector2Array = w["poly"].duplicate()
		draw_polyline(cl, Color8(18, 12, 26), 2.0)
	for d in dress:
		if d[0] == "back": _img(d[1], d[2], G + 4.0, 1.0, false, Color(0.75, 0.72, 0.82))
	_draw_doors(tt)
	# wall fixtures and props
	for p in tpl["props"]:
		var y: float = G - p[2]
		var k: String = p[0]
		var mode: String = p[3] if p.size() > 3 else ""
		if mode == "w":
			_img("torchF", p[1], y - 110.0)
			_img("fflame%d" % (int(tt * 9.0 + p[1]) % 4), p[1], y - 150.0)
		elif mode == "c":
			var yb := y - 150.0 - 112.0
			var yt := cy + 20.0
			var ch: Texture2D = tex["chain"]
			var yy := yb - ch.get_height()
			while yy > yt - ch.get_height():
				draw_texture_rect(ch, Rect2(p[1] - ch.get_width() / 2.0, maxf(yt, yy), ch.get_width(), minf(ch.get_height(), yb - maxf(yt, yy))), false)
				yy -= ch.get_height() - 6.0
			_img("lantern", p[1], y - 150.0)
		elif k.begins_with("mush") or k.begins_with("crys"):
			_img(k, p[1], y + 4.0, 1.0, int(p[1] * 7) % 3 == 0)
		elif tex.has(k):
			_img(k, p[1], y + 4.0)
	# room shell and rock masses
	rock(-TW * 8.0, tpl["w"] + TW * 8.0, cy - TW * 6.0, cy, false, true, 0.0)
	rock(-TW * 8.0, 0.0, cy - 10.0, G + 20.0, false, false)
	rock(tpl["w"], tpl["w"] + TW * 8.0, cy - 10.0, G + 20.0, false, false)
	rock(-TW * 8.0, tpl["w"] + TW * 8.0, G - SURF, G + H + 60.0, true, false, 0.0)
	for so in arena.solids:
		rock(so.x, so.x + so.w, so.top - SURF, G + 2.0, true, false, 3.0)
	for pl in arena.platforms:
		draw_rect(Rect2(pl.x + 10.0, pl.y + 24.0, pl.w, 26.0), Color(0, 0, 0, 0.3))
		rock(pl.x, pl.x + pl.w, pl.y - SURF, pl.y - SURF + 34.0, true, true, 2.0)
	for d in dress:
		if d[0] == "hang": _img(d[1], d[2], G - d[3] + 30.0 + 130.0)
	var rm := room()
	if rm["type"] == "camp":
		var x: float = tpl["w"] * 0.75
		draw_rect(Rect2(x - 24.0, G - 6.0, 48.0, 6.0), Color8(58, 42, 32))
		var fi := int(tt * 10.0) % 4
		_img("flame%d" % fi, x, G - 2.0, 1.4)
		_img("flame%d" % ((fi + 2) % 4), x - 12.0, G - 2.0, 1.0)
		_img("flame%d" % ((fi + 1) % 4), x + 12.0, G - 2.0, 1.0)
	if chest != null:
		var cx: float = chest["x"]
		draw_rect(Rect2(cx - 26.0, G - 34.0, 52.0, 34.0), Color8(90, 58, 32))
		draw_rect(Rect2(cx - 26.0, G - 44.0, 52.0, 14.0), Color8(122, 82, 48))
		draw_rect(Rect2(cx - 4.0, G - 34.0, 8.0, 10.0), Color8(232, 192, 96))

func _draw_doors(tt: float) -> void:
	var fr: Texture2D = tex["dframe"]
	for d in doors:
		if d["boss"] and not gate_open: continue
		var kind := door_kind(d)
		var c: Color = DOORSTY[kind]
		var open: bool = gate_open or d["town"]
		var k: float = 1.0 if d["town"] and not d["boss"] else open_k
		var w := fr.get_width()
		var h := fr.get_height()
		var x: float = roundf(d["x"] - w / 2.0)
		var y: float = roundf(d["y"] + 8.0 - h)
		draw_texture(fr, Vector2(x, y))
		var ox: float = x + DOPEN[0]
		var oy: float = y + DOPEN[1]
		var ow: float = DOPEN[2] - DOPEN[0]
		var fy: float = d["y"] + 6.0
		if open and k > 0.0:
			var fl := 0.82 + 0.18 * sin(tt * 9.0) * sin(tt * 5.3) if kind == "camp" else (0.72 + 0.28 * sin(tt * 2.2) if kind == "boss" else 0.92 + 0.08 * sin(tt * 3.1 + d["x"]))
			var A := k * fl
			# light in the tunnel: brightest low in the middle, motes drifting in it
			var steps := 6
			for i in steps:
				var u := float(i) / steps
				draw_rect(Rect2(ox, oy + (fy - oy) * u, ow, (fy - oy) / steps + 1.0), Color(c, (0.3 + 0.45 * u) * A))
			draw_rect(Rect2(ox + ow * 0.3, oy + 8.0, ow * 0.4, fy - oy - 8.0), Color(1, 0.97, 0.9, 0.35 * A))
			for i in 8:
				var sp := 0.4 + (i % 4) * 0.25
				var mx := ox + 6.0 + fposmod(i * 37.0 + sin(tt * 0.7 + i) * 10.0 + ow * 4.0, ow - 12.0)
				var my := fy - 6.0 - fposmod(tt * 22.0 * sp + i * 53.0, (fy - oy) - 14.0)
				draw_rect(Rect2(roundf(mx), roundf(my), 2, 2), Color(1, 0.96, 0.86, 0.5 * A * (0.5 + 0.5 * sin(tt * 2.0 + i * 1.3))))
		if not open:
			var pk: Texture2D = tex["dplank"]
			draw_texture(pk, Vector2(roundf(d["x"] - pk.get_width() / 2.0), roundf(d["y"] + 8.0 - pk.get_height())))
		draw_rect(Rect2(x, y, w, h), Color(0.05, 0.03, 0.09, 0.18 * (1.0 - k)))
		# the crooked signboard
		var si: int = SIGNI.get(kind, 0)
		var sg: Texture2D = tex["sign%d" % si]
		var ang := fposmod(sin(d["x"] * 12.9898 + d["y"] * 4.1) * 43758.5, 1.0) * 0.11 + (-0.03 if d["d"] == "L" else 0.03) + sin(tt * 1.3 + d["x"]) * 0.006
		var sx: float = d["x"] + fposmod(d["x"] * 7.0, 13.0) - 6.0
		var sy: float = y - sg.get_height() * 0.5 + 12.0
		draw_set_transform(Vector2(roundf(sx), roundf(sy)), ang)
		draw_texture(sg, -sg.get_size() / 2.0)
		draw_texture(tex["sign%de" % si], -sg.get_size() / 2.0, Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, 0.22 + 0.6 * k))
		draw_set_transform(Vector2.ZERO)

func _draw_front() -> void:
	if tpl.is_empty(): return
	var G: float = arena.ground_y
	var tt := Time.get_ticks_msec() / 1000.0
	for d in dress:
		if d[0] == "front": _img(d[1], d[2], G + 6.0, 1.0, false, Color.WHITE, front)
	# door spill on the floor
	for d in doors:
		var open: bool = (gate_open or d["town"]) and not (d["boss"] and not gate_open)
		if not open: continue
		var k: float = 1.0 if d["town"] and not d["boss"] else open_k
		var c: Color = DOORSTY[door_kind(d)]
		for i in 4:
			var hw: float = [200.0, 95.0, 60.0, 45.0][i]
			var hh: float = [18.0, 10.0, 8.0, 3.5][i]
			front.draw_set_transform(Vector2(d["x"], d["y"] - SURF + 3.0), 0.0, Vector2(1.0, hh / hw))
			front.draw_circle(Vector2.ZERO, hw, Color(c, [0.16, 0.2, 0.18, 0.5][i] * k))
		front.draw_set_transform(Vector2.ZERO)
	# spores
	for s in spores:
		var a: float = 0.45 + 0.4 * sin(tt * 2.0 + s["ph"])
		var sz: float = s["s"]
		front.draw_rect(Rect2(roundf(s["x"]) - sz, roundf(s["y"]) - sz, sz * 2.0 + 2.0, sz * 2.0 + 2.0), Color(s["c"], a * 0.25))
		front.draw_rect(Rect2(roundf(s["x"]), roundf(s["y"]), sz, sz), Color(s["c"], a))
	# low fog hugging the floor
	var vr: Rect2 = arena.view_rect()
	for i in 3:
		var off := fposmod(tt * (8.0 + i * 5.0) + i * 300.0, 600.0)
		var x := floorf((vr.position.x - off) / 600.0) * 600.0 + off - 600.0
		while x < vr.end.x + 600.0:
			front.draw_set_transform(Vector2(x + 300.0, G - 14.0 - i * 10.0), 0.0, Vector2(1.0, (26.0 - i * 4.0) / 320.0))
			front.draw_circle(Vector2.ZERO, 320.0, Color(0.47, 0.39, 0.67, 0.06 - i * 0.015))
			x += 600.0
		front.draw_set_transform(Vector2.ZERO)
	# door tags and the prompt
	var ARW := {"L": "◀", "R": "▶", "U": "▲", "D": "▼"}
	var rm := room()
	var fnt: Font = arena.font_black
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
		front.draw_rect(Rect2(d["x"] - tw / 2.0, y - 15.0, tw, 22.0), Color(0.04, 0.03, 0.05, 0.75))
		front.draw_string(fnt, Vector2(d["x"] - tw / 2.0 + 10.0, y + 1.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#ffe9a8") if open else Color("#9c917a"))
	if near_gate != null:
		var d2 = near_gate
		var s: String = arena.cfg.kh() + ("마을로 돌아가기" if d2["town"] else "이동")
		var tw2 := fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 20.0
		var y2: float = d2["y"] - 280.0 + sin(tt * 4.0) * 3.0
		front.draw_rect(Rect2(d2["x"] - tw2 / 2.0, y2 - 16.0, tw2, 24.0), Color(0, 0, 0, 0.6))
		front.draw_string(fnt, Vector2(d2["x"] - tw2 / 2.0 + 10.0, y2 + 1.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffe9a8"))
	if rm["type"] == "camp":
		var s3: String = "쉬었다" if rm.get("rest_used", false) else "모닥불 — 다가가면 회복"
		var tw3 := fnt.get_string_size(s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		front.draw_string(fnt, Vector2(tpl["w"] * 0.75 - tw3 / 2.0, G - 110.0), s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.86, 0.86, 0.86, 0.5) if rm.get("rest_used", false) else Color("#ffe9a8"))
