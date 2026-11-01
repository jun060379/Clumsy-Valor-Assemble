extends SceneTree
## town life: climbable tops exist, townsfolk walk and chat once Luce leaves the party, Bran talks, weather runs
func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var T = arena.level
	var t0 := Time.get_ticks_msec()
	print("tpl ", T.tpl.size(), " climb ", T.tpl.filter(func(p): return p.has("climb")).size())
	arena.toggle_member("luce")
	arena.toggle_member("aida")
	print("party ", arena.player.party, " who ", arena.player.who)
	arena.weather = "rain"
	var F = T.folk
	for i in 3000:
		arena._process(0.016)
		if i % 500 == 0:
			for c in F.folk():
				var n = F.npc(c)
				print(i, " ", c, " ", n["mode"], " x=", snapped(n["x"], 1), " r=", n["r"], " say=", n["say"] if n["say_t"] > 0 else "")
	print("rain ", T.life.rain.size(), " birds ", T.life.birds.size(), " ms ", Time.get_ticks_msec() - t0)
	# stand on a roof: drop onto the store's top
	var P = arena.player
	var best = null
	for p in T.tpl:
		if p.has("climb") and p["climb"] == "g_store": best = p
	if best != null:
		P.position = Vector2((best.x0 + best.x1) / 2.0, best.y0 - 60.0)
		P.on = false
		P.vy = 0.1
		for i in 60: arena._process(0.016)
		print("roof ", best, " -> ", P.position, " on=", P.on)
	T.bran.talk()
	print("dlg ", arena.dlg.active, " ", arena.dlg.lines)
	arena.toggle_member("luce")
	print("party ", arena.player.party)
	quit()
