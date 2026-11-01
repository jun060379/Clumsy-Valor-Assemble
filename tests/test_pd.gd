extends SceneTree
## WP-D (D1): the cave lit as the prototype lights it — lit.gd's ambient and shaped lights instead of Light2Ds, rock baked
## at art resolution with DIR8 rims toward each light, the door spill on the floor, rims on characters and monsters
var fails := 0

func ok(c: bool, what: String) -> void:
	print(("  ok   " if c else "  FAIL ") + what)
	if not c: fails += 1

func count(n: Node, f: Callable) -> int:
	var c := 1 if f.call(n) else 0
	for ch in n.get_children(): c += count(ch, f)
	return c

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var CT := load("res://scripts/cave_ter.gd")
	arena.weather = "clear"
	arena.enter_dungeon()
	await process_frame
	var D = arena.level
	for i in 3: arena._process(0.016)
	ok(count(arena, func(n): return n is Light2D) == 0, "no Light2D in the cave")
	ok(count(arena, func(n): return n is CanvasModulate) == 0, "no CanvasModulate: the ambient is lit.gd's multiply")
	ok(D.lit != null and D.lit.get_parent() == arena, "the cave draws its light with lit.gd")
	var a: Color = D.lit.amb
	ok(absf(a.r - 0.36) < 0.01 and absf(a.g - 0.385) < 0.01 and absf(a.b - 0.62) < 0.01, "ambient = todNow at 22:30 (%.3f %.3f %.3f)" % [a.r, a.g, a.b])
	arena.weather = "rain"
	arena._process(0.016)
	ok(D.lit.amb.b < a.b - 0.1, "rain darkens the cave ambient as the prototype's todNow does")
	arena.weather = "clear"
	arena._process(0.016)
	# the start room: two wall torches, the town door, the heroine's glow
	ok(D.room()["type"] == "start", "starts in the entrance")
	var fires: Array = D.L.filter(func(l): return l["k"] == "fire")
	ok(fires.size() == 2 and fires.all(func(l): return l["r"] == 230.0 and l.has("gy")), "two wall torches as fires (r 230)")
	ok(D.L.any(func(l): return l["k"] == "player"), "the heroine's own faint glow is in the light pass")
	ok(not D.L_rim.any(func(l): return l["k"] == "player"), "...but not in the rim lights")
	ok(D.L.any(func(l): return l["k"] == "soft" and absf(l["x"] - 300.0) < 1.0 and l["r"] == 260.0), "the town door glows (r 150 + 110)")
	var rl: Array = D.rim_lights()
	ok(rl.size() == D.L_rim.size() and rl.all(func(r): return r[0] is Vector2 and r[3] is Color), "rim_lights(): [pos, r, strength, colour]")
	ok(arena.pfx.rim_lights().size() == rl.size(), "the character shader reads the cave's rim lights")
	# flicker: fires vary over time
	var a0: float = fires[0]["a"]
	D._light_step(12.345)
	ok(absf(D.L.filter(func(l): return l["k"] == "fire")[0]["a"] - a0) > 0.0001, "torches flicker (fl)")
	# every template: masses, walls with rim, ceiling without, ground holding the raised rock
	for tn in D.RTPL.keys():
		var r = D.room()
		r["tpl"] = tn
		D.enter()
		var T: Dictionary = D.RTPL[tn]
		var nw: int = D._wall_segs(T).size()
		ok(D.masses.size() == nw + 4 + T["ledges"].size(), "%s: %d masses (walls %d, shell 4, ledges %d)" % [tn, D.masses.size(), nw, T["ledges"].size()])
		var ceil = D.masses.filter(func(e): return e["gain"] == 0.0)
		ok(ceil.size() == 1, "%s: only the ceiling takes no rim" % tn)
		var gm: Dictionary = D.masses.filter(func(e): return e["gain"] == 0.9)[0]["m"]
		var gimg: Image = gm["img"]
		var solid_ok := true
		for so in T["solids"]:
			var px := int((so[0] + so[1] / 2.0 - gm["ox"]) / 2.0)
			var py := int((arena.ground_y - so[2] + 20.0 - gm["oy"]) / 2.0)
			if gimg.get_pixel(px, py).a < 0.5: solid_ok = false
		ok(solid_ok, "%s: the raised rock is part of the ground mass" % tn)
		ok(D.masses.filter(func(e): return e["s"] != null).size() == T["ledges"].size(), "%s: every ledge casts its soft shadow" % tn)
	# a torch lights the rock that faces it: the stair room's torch on the 220 block
	var r2 = D.room()
	r2["tpl"] = "stair"
	D.enter()
	arena.player.position.x = 640.0
	arena.snap_camera()
	for i in 3: arena._process(0.016)
	var g: Dictionary = D.masses.filter(func(e): return e["gain"] == 0.9)[0]
	var mat: ShaderMaterial = g["n"].material
	var rc: PackedVector4Array = mat.get_shader_parameter("rc")
	var up: Vector4 = rc[6]
	ok(mat.get_shader_parameter("on") == 1 and rc.size() == 8, "the ground takes the room's light on its edges")
	ok(up.w > 0.0 and up.x > up.z, "the torch above lights the up-facing edges warm (%.2f %.2f %.2f)" % [up.x, up.y, up.z])
	var rd: PackedFloat32Array = mat.get_shader_parameter("rd")
	ok(rd[2] > 0.0 and rd[6] == 0.0, "the far side (down-facing) is deepened, not the lit side")
	var w: Array = CT.rim_weights(Vector2(0, -1))
	ok(w[0][0] == 6 and absf(w[0][1] - 1.0) < 0.001, "paintRim: straight up is band 6 at full weight")
	# doors: a sealed fight door gives no light, a sealed boss door does; an open one spills on the floor (additive, after the light pass)
	var rm = D.room()
	rm["cleared"] = false
	D.gate_open = false
	D.open_k = 0.0
	D.doors = [{"d": "R", "x": 2220.0, "y": arena.ground_y, "town": false, "boss": false}]
	var nb = D.rooms.get(D.rkey(rm["x"] + 1, rm["y"]))
	if nb == null:
		nb = {"x": rm["x"] + 1, "y": rm["y"], "k": D.rkey(rm["x"] + 1, rm["y"]), "type": "fight", "doors": {}, "visited": false, "tpl": "stair"}
		D.rooms[nb["k"]] = nb
	nb["type"] = "fight"
	D._light_step(1.0)
	ok(not D.L.any(func(l): return absf(l["x"] - 2220.0) < 1.0), "a sealed door gives no light")
	nb["type"] = "boss"
	D._light_step(1.0)
	var bl: Array = D.L.filter(func(l): return absf(l["x"] - 2220.0) < 1.0)
	ok(bl.size() == 1 and bl[0]["r"] == 150.0, "the boss door glows red even sealed")
	nb["type"] = "fight"
	D.gate_open = true
	D.open_k = 1.0
	D._light_step(1.0)
	bl = D.L.filter(func(l): return absf(l["x"] - 2220.0) < 1.0)
	ok(bl.size() == 1 and bl[0]["r"] == 260.0 and absf(bl[0]["a"] - 0.72) < 0.001, "an open door: r 260, a 0.6 x 1.2")
	ok(D.front_add.z_index == 9 and (D.front_add.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "the door spill is added after the light pass")
	ok(arena.get_children().find(D.front_add) > arena.get_children().find(D.lit), "...drawn after lit.gd's composite")
	ok(not D.has_method("_dressing") and not D.tex.is_empty(), "no extra dressing (the prototype draws none)")
	# the lip: the tile's top piece halved, olive moss over the blue-grey rock (it reads blue-white under the night light)
	ok(CT._lip.get_width() == 80 and CT._lip.get_height() == 7, "lip strip 80 x 7")
	# a monster by the torch takes its rim
	arena.player.position.x = 300.0
	var m = arena.spawn("goblin", 700.0, 0.0, arena.ground_y - 220.0, null, false, 1)
	for i in 5: arena._process(0.016)
	var near: Array = m.rim_near()
	ok(not near.is_empty() and near[0][2] is Color, "a monster near the torch takes a rim (%d lights)" % near.size())
	ok(m.rim_n != null and m.rim_n.get_parent() == m and (m.rim_n.material as ShaderMaterial).shader != null, "the monster draws its rim pass over the sprite")
	# phones: the shallow band only
	ok(g["n"].material.get_shader_parameter("deep") == (not arena.low_end), "phones skip the deep band")
	print("FAILS: %d" % fails)
	quit()
