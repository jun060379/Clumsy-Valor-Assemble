extends SceneTree
## Walk captures under the title (needs a display):
##   godot --rendering-driver opengl3 --resolution 900x500 --path . -s tests/cap_walk.gd -- OUTDIR strips
##     24-frame strips of 에스텔 / 아이다 / 루체 / 브랜 walking under the title: OUTDIR/strip_<who>.png. The crop is a fixed
##     rect of the WORLD (it does not follow the walker), so a planted foot stays on the same guide line while the body
##     passes over it; red ticks every 10 world px along the ground.
##   ... -s tests/cap_walk.gd -- OUTDIR scale
##     OUTDIR/scale.png: per member, the idle frame next to two walk frames (passing, contact) on one feet line, drawn
##     the way the game draws them; 브랜's forge cell next to his walk cells.
##   ... --fixed-fps 30 --write-movie OUTDIR/title_walk.avi -s tests/cap_walk.gd -- OUTDIR movie
##     ~15 s of the title: the three walk past the hall's front (the title's own camera), then the camera at the forge
##     for 브랜's stroll.

var out := ""
var arena
var T
var folk

func frames(k: int) -> void:
	for i in k:
		if pin != null: pin.set("at", cam_at)
		await process_frame

var pin: Node                 # runs after the arena and the title each frame: puts the camera at cam_at

var cam_at = null             # held camera centre (the title's camera would take it back each frame)

func xf() -> Transform2D:
	return root.get_final_transform() * root.get_canvas_transform()

## the screen region of world rect r
func screen_rect(r: Rect2) -> Rect2i:
	var a: Vector2 = xf() * r.position
	var b: Vector2 = xf() * r.end
	return Rect2i(Vector2i(roundi(a.x), roundi(a.y)), Vector2i(roundi(b.x - a.x), roundi(b.y - a.y)))

func grab(r: Rect2) -> Image:
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	var sr := screen_rect(r)
	var cut := Image.create(sr.size.x, sr.size.y, false, Image.FORMAT_RGBA8)
	cut.fill(Color(0, 0, 0, 1))
	var inside := sr.intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	if inside.size.x > 0 and inside.size.y > 0:
		cut.blit_rect(im.convert_to(Image.FORMAT_RGBA8) if im.get_format() != Image.FORMAT_RGBA8 else im, inside, inside.position - sr.position)
	return cut

## everyone but `who` stands still far from the way; nobody stops to greet
func quiet(who: String) -> void:
	for c in folk.folk():
		var n: Dictionary = folk.npc(c)
		if c == who: continue
		n["mode"] = "idle"
		n["wait"] = 1e9
		n["path"] = []
		n["x"] = 400.0 + 150.0 * folk.folk().find(c)
		n["r"] = "top"
	for a in ["estelle", "aida", "luce", "eilin"]:
		for b in ["estelle", "aida", "luce"]:
			folk.greet_cd[a + "|" + b] = 1e9
			folk.greet_cd[b + "|" + a] = 1e9

func strip(who: String) -> void:
	var L = arena.level
	var world: Rect2
	var feet := 0.0
	var BR = L.bran
	if who == "bran":
		BR.x = BR.home
		BR.goal = NAN
		BR.play("idle")
		arena.player.position = Vector2(BR.home - 2000.0, BR.y)
		feet = BR.y
		world = Rect2(BR.home + BR.MID - 150.0, feet - 150.0, 220.0, 165.0)
		cam_at = Vector2(BR.home, feet - 0.32 * 500.0)
		await frames(30)
		BR.stroll()
		while BR.anim != "walk": await frames(1)
		await frames(12)                          # into the stride
	else:
		quiet(who)
		var n: Dictionary = folk.npc(who)
		var x0: float = L.HXB + 250.0          # the hall's terrace: bare boards, no grass over the feet
		n["r"] = "top"
		n["x"] = x0
		n["mode"] = "idle"
		n["wait"] = 1e9
		n["path"] = []
		n["talk_t"] = 0.0
		feet = L.floor_at(x0)
		cam_at = Vector2(x0 + 60.0, feet - 0.32 * 500.0)
		await frames(30)
		folk.go(n, x0 + 900.0, "top", false)
		await frames(40)                          # into the stride
		world = Rect2(float(n["x"]) - 90.0, feet - 160.0, 260.0, 175.0)
		cam_at = Vector2(float(n["x"]) + 40.0, feet - 0.32 * 500.0)
		await frames(2)
	var shots: Array = []
	for i in 24:
		shots.append(await grab(world))
		await frames(2)                                    # every 3rd frame: 24 shots ≈ 1.2 s ≈ one cycle at 60 fps
	var w: int = shots[0].get_width()
	var h: int = shots[0].get_height()
	var S := 2
	var cols := 12
	var big := Image.create(cols * w * S + (cols - 1) * 4, 2 * h * S + 4, false, Image.FORMAT_RGBA8)
	big.fill(Color(0.1, 0.1, 0.12, 1))
	var fy: int = int(screen_rect(Rect2(world.position, Vector2(1, feet - world.position.y))).size.y)
	for i in 24:
		var im: Image = shots[i]
		im.resize(w * S, h * S, Image.INTERPOLATE_NEAREST)
		# ground ticks every 10 world px (fixed in the world: the crop does not move)
		for k in range(0, int(world.size.x) + 1, 10):
			var sx := int(float(k) / world.size.x * w * S)
			for y in range(fy * S - 2, mini(h * S, fy * S + 10)):
				if sx < w * S: im.set_pixel(sx, y, Color(1, 0.25, 0.25) if k % 50 else Color(1, 0.9, 0.2))
		big.blit_rect(im, Rect2i(0, 0, w * S, h * S), Vector2i((i % cols) * (w * S + 4), (i / cols) * (h * S + 4)))
	big.save_png("%s/strip_%s.png" % [out, who])
	print("strip ", who, " ", big.get_size())

func scale_sheet() -> void:
	var L = arena.level
	var x0: float = L.HXB + 250.0
	var feet: float = L.floor_at(x0)
	quiet("")
	for c in folk.folk(): folk.npc(c)["x"] = 300.0
	var src := GDScript.new()
	src.source_code = """extends Node2D
var arena
var x0 := 0.0
var feet := 0.0
func _process(_d): queue_redraw()
func _draw():
	var P = arena.player
	var BR = arena.level.bran
	var cs := ["estelle", "aida", "luce"]
	var walk_f := {"estelle": [0, 17], "aida": [3, 8], "luce": [0, 13]}
	draw_line(Vector2(x0 - 80, feet), Vector2(x0 + 900, feet), Color(1, 0.3, 0.3), 1.0)
	for i in cs.size():
		var c: String = cs[i]
		var bx := x0 + i * 240.0
		P.draw_frame(c, "idle", 0, Vector2(bx, feet), 1, Color.WHITE, "", self)
		P.draw_frame(c, "walk", walk_f[c][0], Vector2(bx + 70.0, feet), 1, Color.WHITE, "", self)
		P.draw_frame(c, "walk", walk_f[c][1], Vector2(bx + 140.0, feet), 1, Color.WHITE, "", self)
	var bx2 := x0 + 720.0
	draw_set_transform(Vector2(bx2, feet), 0.0, Vector2(BR.S, BR.S))
	draw_texture_rect_region(BR.PX, Rect2(-BR.AX, -BR.FY, BR.CW, BR.CHH), Rect2(0, 0, BR.CW, BR.CHH))
	for k in 2:
		var fi: int = [0, 8][k]
		draw_set_transform(Vector2(bx2 + 70.0 + 70.0 * k + BR.MID, feet), 0.0, Vector2(BR.S, BR.S))
		draw_texture_rect_region(BR.WALK, Rect2(-BR.WBX, -BR.FY, BR.WCW, BR.CHH), Rect2(fi * BR.WCW, 0, BR.WCW, BR.CHH))
	draw_set_transform(Vector2.ZERO)
"""
	src.reload()
	var nd := Node2D.new()
	nd.set_script(src)
	nd.set("arena", arena)
	nd.set("x0", x0)
	nd.set("feet", feet)
	nd.z_index = 50
	L.add_child(nd)
	var halves: Array = []
	for part in 2:
		var wx := x0 - 80.0 + part * 470.0
		cam_at = Vector2(wx + 235.0, feet - 0.32 * 500.0)
		await frames(20)
		halves.append(await grab(Rect2(wx, feet - 175.0, 470.0, 190.0)))
	var w: int = halves[0].get_width()
	var h: int = halves[0].get_height()
	var big := Image.create(w * 2, h, false, Image.FORMAT_RGBA8)
	big.blit_rect(halves[0], Rect2i(0, 0, w, h), Vector2i(0, 0))
	big.blit_rect(halves[1], Rect2i(0, 0, w, h), Vector2i(w, 0))
	big.resize(w * 4, h * 2, Image.INTERPOLATE_NEAREST)
	big.save_png("%s/scale.png" % out)
	nd.queue_free()
	print("scale ", big.get_size())

func movie() -> void:
	var L = arena.level
	var hd: float = L.HDOOR
	# the three cross the hall's front, the title camera on its own
	var plan := {"estelle": [hd - 420.0, hd + 520.0], "aida": [hd + 330.0, hd - 600.0], "luce": [hd - 700.0, hd + 300.0]}
	for c in plan:
		var n: Dictionary = folk.npc(c)
		n["r"] = "top"
		n["x"] = plan[c][0]
		n["mode"] = "idle"
		n["wait"] = 1e9
		n["path"] = []
		folk.go(n, plan[c][1], "top", false)
	for i in 30 * 10: await process_frame
	# the forge: 브랜's stroll
	var BR = L.bran
	arena.player.position = Vector2(BR.home - 2000.0, BR.y)
	BR.x = BR.home
	BR.goal = NAN
	BR.play("idle")
	BR.stroll()
	cam_at = Vector2(BR.home - 40.0, BR.y - 0.32 * 500.0)
	await frames(30 * 5)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var mode: String = args[1] if args.size() > 1 else "strips"
	DirAccess.make_dir_recursive_absolute(out)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(5)
	arena.fame.rec = ["estelle", "aida", "luce"]
	arena.tod_auto = false
	arena.tod_h = 12.0
	arena.weather = "clear"
	var ps := GDScript.new()
	ps.source_code = """extends Node
var arena
var at = null
func _process(_d):
	if at is Vector2:
		arena.cam_override = at
		arena.cam.position = at
		arena.cam.reset_smoothing()
"""
	ps.reload()
	pin = Node.new()
	pin.set_script(ps)
	pin.set("arena", arena)
	pin.process_priority = 100000
	root.add_child(pin)
	T = arena.ui_root.title
	folk = arena.FOLK.of(arena)
	T.active = true
	T.visible = true
	await frames(10)
	print("title live ", T.live, " mode ", arena.title_mode, " folk ", folk.folk())
	if mode == "strips":
		await frames(150)                       # past the intro's pull-in
		for c in ["estelle", "aida", "luce", "bran"]: await strip(c)
	elif mode == "scale":
		await scale_sheet()
	else:
		await movie()
	quit()
