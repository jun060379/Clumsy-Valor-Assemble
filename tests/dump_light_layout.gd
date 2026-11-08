extends SceneTree
## dumps what tools/bake_ground_light.py bakes the town's ground light from (needs a display):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/dump_light_layout.gd -- docs/work/town-art/light_layout.json
##   p3d:    [shadow key, canvas x, canvas y] of every pixel3d sprite's ground shadow (assets/town/shadow/<key>_<look>)
##   obj:    [kind, x0, x1, foot y, height] of the rest that stands on the ground (trees, bushes, rocks)
##   lights: [kind, x, y, radius, r, g, b, alpha] at night
func frames(k: int) -> void:
	for i in k: await process_frame
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.go_town(Vector2(5107.0, arena.ground_y), 1)
	await frames(20)
	var T = arena.level
	T.sh_log = {}
	# walk the camera along the town: every sprite gets drawn once (they are culled to the view)
	var x := 0.0
	while x <= T.TOWN_W + 450.0:
		for y in [T.G, T.LOWF, T.TTOP]:
			arena.player.position = Vector2(x, y)
			await frames(3)
			T.queue_redraw()
			if T.get("near_node") != null: T.near_node.queue_redraw()
			await frames(2)
		x += 300.0
	var p3d: Array = T.sh_log.values()
	var obj: Array = []
	for d in T.deco_back:
		var k: String = d[0]
		if not T.tex.has(k) or k.begins_with("f_grass"): continue
		var w: float = T.tex[k].get_width() * T.ks(k)          # d[5] is the sway's amplitude, not a scale
		var h: float = T.tex[k].get_height() * T.ks(k)
		var kind := "tree" if (k.contains("tree") or k in ["f_oak", "f_round", "f_young", "f_tall"]) else "bush"
		obj.append([kind, d[1], d[1] + w, d[2], h])
	# the trees' and bushes' card shadows (tools/pixel3d/tree_relief.py --flat): [key, sprite x, sprite bottom y, flip, width]
	var cards: Array = []
	for d in T.deco_back:
		var ck: String = d[0]
		if not FileAccess.file_exists("res://assets/town/shadow/" + ck + "_card.png"): continue
		var cs: float = 1.0 if T.hx.has(ck) else T.ks(ck)
		var ct: Texture2D = T.hx.get(ck, T.tex[ck])
		cards.append([ck, d[1], d[2] + d[3] * T.PK * cs, d[4], ct.get_width() * cs, ct.get_height() * cs])
	for r in T.rocks:
		if T.tex.has(r[0]): obj.append(["prop", r[1], r[1] + T.tex[r[0]].get_width(), r[2], T.tex[r[0]].get_height()])
	arena.tod_h = 21.0
	await frames(5)
	var lights: Array = []
	for l in T.light_sources():
		var c: Color = l["c"]
		lights.append([l["k"], l["x"], l["y"], l["r"], c.r, c.g, c.b, l["a"]])
	# the ground's stand lines along the town (every 2 px): the walked surface, and the lower street under it
	var floors: Array = []
	var fx := 0.0
	while fx <= T.TOWN_W:
		floors.append([roundf(T.floor_at(fx)), T.LOWF])
		fx += 2.0
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"W": T.TOWN_W, "p3d": p3d, "obj": obj, "lights": lights, "floors": floors, "cards": cards}))
	f.close()
	print("DUMP ", p3d.size(), " shadows ", obj.size(), " objects ", lights.size(), " lights")
	quit()
