extends SceneTree
## Screenshots of the pixel effects (needs a display): godot --path . --rendering-driver opengl3 -s tests/cap_vfx.gd -- OUTDIR
## Each shot holds the effect clock (pfx.dbg_k = 0) at a chosen time and saves the frame.

var arena
var SHOTS: Array = [] if OS.get_cmdline_user_args().size() > 1 else [["swing", "estelle", [40, 80, 160]], ["swing", "aida", [40, 120, 240]], ["swing", "luce", [80]], ["swing2", "estelle", [80]], ["thrust", "estelle", [40, 120]], ["thrust", "aida", [80, 200]], ["hit", "estelle", [40, 120]], ["pillar", "luce", [120, 320]], ["bolt", "luce", [40, 160]], ["gate", "aida", [120, 400]], ["slam", "estelle", [80]], ["slam", "aida", [120]], ["djump", "estelle", [80]], ["heal", "luce", [200, 500]], ["rose", "estelle", [120]], ["hollow", "aida", [400]], ["utear", "aida", [120]], ["parry", "estelle", [120, 280]]]
var out := "user://"

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	im.save_png(out + "/" + name + ".png")
	print("saved ", name)

func hold(e: Dictionary, t: float) -> void:
	e["t"] = t

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out = args[0]
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(5)
	var P = arena.player
	var X = arena.pfx
	if args.size() > 1 and args[1] == "noon":
		arena.go_training()
		await frames(30)
		arena.tod_h = 12.0
		P.position = Vector2(700, arena.ground_y)
		arena.snap_camera()
		await frames(30)
		for md in ["off", "dot", "shade"]:
			for pf in [false, true]:
				arena.screen_fx = pf
				P.set_pix(md)
				await frames(4)
				await shot("noon_%s_%s" % [md, "post" if pf else "raw"])
		arena.screen_fx = false
		var mm = P.material
		P.material = null
		await frames(4)
		await shot("noon_nomat")
		P.material = mm
		print("player screen ", root.get_viewport().get_canvas_transform() * P.position)
		quit()
		return
	if args.size() > 1 and args[1] == "dun":
		arena.enter_dungeon()
		await frames(60)
		for m in arena.mobs: m.visible = false
		await frames(10)
		await shot("dun_on")
		X.dbg_k = 0.0
		X.slash(P.position + Vector2(10 * P.CSCALE, -75 * P.CSCALE), 80 * P.CSCALE * 0.86 * 1.12, -100, 30, 1, "estelle")
		for e in X.L: hold(e, 80.0)
		await frames(4)
		await shot("dun_slash")
		arena.screen_fx = false
		await frames(4)
		await shot("dun_slash_off")
		quit()
		return
	if args.size() > 1 and args[1] == "town":
		arena.go_town(Vector2(3024, arena.ground_y), 1)
		await frames(40)
		arena.tod_h = 18.5
		arena.tod_auto = false
		P.position = Vector2(3024, arena.level.floor_at(3024))
		arena.snap_camera()
		await frames(60)
		for md in ["off", "dot", "shade"]:
			P.set_pix(md)
			await frames(4)
			await shot("town_" + md)
		arena.screen_fx = false
		await frames(4)
		await shot("town_shade_nopost")
		P.set_pix("off")
		await frames(4)
		await shot("town_off_nopost")
		arena.screen_fx = true
		var xf: Transform2D = root.get_viewport().get_canvas_transform()
		print("player screen ", xf * P.position)
		quit()
		return
	arena.go_training()
	await frames(30)
	arena.tod_h = 12.0
	for d in arena.dummies: d.visible = false
	P.position = Vector2(700, arena.ground_y)
	arena.snap_camera()
	await frames(10)
	X.dbg_k = 0.0
	var S: Array = SHOTS
	for sh in S:
		X.clear()
		P.switch_char(sh[1])
		P.dir = 1
		await frames(2)
		var x: float = P.position.x
		var y: float = P.position.y
		var cs: float = P.CSCALE
		match sh[0]:
			"swing": X.slash(Vector2(x + 10 * cs, y - 75 * cs), 80 * cs * 0.86 * 1.12, -100, 30, 1, sh[1])
			"swing2": X.slash(Vector2(x + 4 * cs, y - 62 * cs), 100 * cs * 0.86 * 1.12, 205, -12, 1, sh[1])
			"thrust": X.thrust(x + 20 * cs, x + 170 * cs, y - 50 * cs, sh[1])
			"hit": X.hit(x + 150, y - 80, 1, 1.0)
			"pillar": X.pillar(x + 150, y, cs)
			"bolt": X.bolt(x + 150, y, 1.0)
			"gate": X.gate(x + 60, y, 150 * cs, 1.0, 1.0)
			"slam": X.slam(x, y, sh[1])
			"djump": X.djump(P)
			"heal":
				for i in 6: X.heal_cross(x, y, cs)
				X.heal_burst(x, y, cs)
			"rose": X.rose_burst(x + 40, y - 80)
			"hollow": X.hollow(x + 150, y - 90, 140 * cs, 900.0)
			"utear": X.utear(x + 150, y - 90, 200)
			"parry": X.parry_at(Vector2(x + 60, y - 90), 1)
		for t in sh[2]:
			for e in X.L: hold(e, t)
			if X.pp != null: X.pp["t"] = t
			await frames(2)
			await shot("%s_%s_%d" % [sh[0], sh[1], int(t)])
	X.clear()
	# attack tell on a goblin, perfect-dodge afterimages
	P.switch_char("estelle")
	var m = arena.spawn("goblin", P.position.x + 220, 0.0)
	await frames(30)
	for tt in [40.0, 120.0, 240.0]:
		m.flare_t = tt
		m.st = "atk"
		await frames(2)
		m.flare_t = tt
		await shot("tell_%d" % int(tt))
	m.flare_t = -1.0
	P.set_anim("dash")
	arena.perfect_dodge()
	print("ghost_i ", X.ghost_i != null, " snap ", X.snap_player() != null)
	for i in 20:
		P.position.x += 12.0
		await frames(1)
	for tt in [100.0, 300.0, 500.0]:
		for g in X.trail: g["t"] = tt * 0.8
		if X.ghost_i == null: X.dodge_snap()
		X.ghost_i["t"] = tt
		arena.witch = 1000.0
		await frames(2)
		await shot("dodge_%d" % int(tt))
	arena.witch = 0.0
	P.position.x = 700.0
	P.set_anim("idle")
	# bloom on / off at the same frame: a flat pink square, a thin gold bar
	var sq := Node2D.new()
	sq.z_index = 12
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sq.material = um
	var px0: Vector2 = P.position
	sq.draw.connect(func():
		sq.draw_rect(Rect2(px0.x + 100, px0.y - 260, 40, 40), Color("#ff40c0"))
		sq.draw_rect(Rect2(px0.x + 200, px0.y - 260, 8, 60), Color("#ffd34d")))
	arena.add_child(sq)
	await frames(6)
	await shot("rect_on")
	arena.screen_fx = false
	await frames(4)
	await shot("rect_off")
	arena.screen_fx = true
	sq.queue_free()
	P.switch_char("luce")
	await frames(2)
	X.pillar(P.position.x + 150, P.position.y, P.CSCALE)
	for e in X.L: hold(e, 120.0)
	await frames(6)
	await shot("bl_on")
	arena.screen_fx = false
	await frames(4)
	await shot("bl_off")
	arena.screen_fx = true
	X.clear()
	P.switch_char("estelle")
	X.dbg_k = 1.0
	quit()
