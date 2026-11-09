extends SceneTree
## dumps the face between the upper walk and the lower street (the hall's slope; tools/make_town_slope.py draws it):
## godot --path . --fixed-fps 60 --resolution 900x500 -s tests/dump_face.gd -- OUT.json
##   x0, step, top[] (where the upper walk's front band ends), bot[] (where the lower plane's back starts), raise, band
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	for i in 10: await process_frame
	arena.go_town(Vector2(5107.0, arena.ground_y), 1)
	for i in 20: await process_frame
	var T = arena.level
	var top: Array = []
	var bot: Array = []
	var x: float = T.SX0
	while x <= T.STX1 + T.SL:
		top.append(roundf(T.up_y(x) + T.BAND))
		bot.append(roundf(T.terr_y(x) - T.RAISE))
		x += 2.0
	var d := {"x0": T.SX0, "step": 2.0, "top": top, "bot": bot, "raise": T.RAISE, "band": T.BAND, "lowf": T.LOWF, "g": T.G}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	quit()
