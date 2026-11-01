extends SceneTree
## Costume move captures in town (needs a display): godot --path . --fixed-fps 60 -s tests/cap_skin_moves.gd -- OUTDIR [SKIN_ID]
## The fight rows cap_skin.gd doesn't play: the attack combo (keys), kneel and its attack, the upward slash, dash (keys),
## guard and a landed parry, the air combo, air guard / air parry, dive, double jump, hurt, death, vow, tag in / out, teeter.
## Saves a crop around her every 2nd frame: OUTDIR/<seq>_<nnn>.png and prints "seq anim:frame ..." per shot (the frame list).

var out := ""
var arena
var P
var n := 0
var air_y := NAN            # pin her in the air at this y (air guard / parry, double jump)

func frames(k: int) -> void:
	for i in k: await process_frame

func shot(seq: String) -> void:
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	var sp: Vector2 = root.get_final_transform() * root.get_canvas_transform() * P.position
	var r := Rect2i(int(sp.x) - 230, int(sp.y) - 300, 460, 340).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	im.get_region(r).save_png("%s/%s_%03d.png" % [out, seq, n])
	print("SHOT %s %03d %s:%d" % [seq, n, P.anim, P.f])
	n += 1

func tick() -> void:
	P.inv = 0.0
	if not is_nan(air_y):
		P.position.y = air_y
		P.vy = 0.0
		P.on = false
		arena.snap_camera()
	await process_frame

## k frames, a shot every 2nd; keys: {frame: [action, down]}
func run_seq(seq: String, k: int, keys := {}) -> void:
	n = 0
	for i in k:
		if keys.has(i):
			for kv in keys[i]:
				if kv[1]: Input.action_press(kv[0])
				else: Input.action_release(kv[0])
		await tick()
		if i % 2 == 0: await shot(seq)

func reset_pos() -> void:
	for a in ["left", "right", "attack", "guard", "dash", "jump", "down"]: Input.action_release(a)
	air_y = NAN
	P.position = Vector2(900.0, arena.level.floor_at(900.0))
	P.vx = 0.0
	P.vy = 0.0
	P.on = true
	P.dir = 1
	P.bash_t = 0.0
	P.air_tag = false
	P.set_anim("idle")
	arena.snap_camera()
	await frames(20)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	var skin: String = args[1] if args.size() > 1 else "estelle_base"
	DirAccess.make_dir_recursive_absolute(out)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	arena.skins.grant(skin, "dev", true)
	print("equip ", skin, " ", arena.skins.equip(skin), " worn ", arena.SKINS.worn("estelle"))
	arena.tod_auto = false
	arena.tod_h = 12.0
	arena.weather = "clear"
	arena.go_town(Vector2(900.0, arena.ground_y), 1)
	await frames(40)
	for f in arena.get("folk") if arena.get("folk") != null else []: f.visible = false
	P = arena.player
	P.switch_char("estelle")
	await reset_pos()

	# the 3-hit combo: a tap every 10 frames (a held key would charge)
	var ck := {}
	for t in [0, 16, 34]:
		ck[t] = [["attack", true]]
		ck[t + 2] = [["attack", false]]
	await run_seq("combo", 110, ck)
	await reset_pos()
	await run_seq("dash", 44, {0: [["right", true], ["dash", true]], 2: [["dash", false]], 6: [["right", false]]})
	await reset_pos()
	# guard: the key held is the stance (parry's frames 0-1 show as guard 1), then a blow blocked, then a landed parry
	await run_seq("guard", 30, {0: [["guard", true]]})
	P.set_anim("guard", 2)
	P.ghit = true
	await run_seq("guardhit", 24)
	Input.action_release("guard")
	await reset_pos()
	P.set_anim("parry", 2)
	P.bash_t = 420.0
	await run_seq("parry", 30)
	await reset_pos()
	# the air rows, pinned in the air
	# air combo: taps while pinned in the air (each hit chains inside its window)
	air_y = P.position.y - 150.0
	P.position.y = air_y
	P.on = false
	P.set_anim("air_combo", 0)
	n = 0
	var tapped := -1
	for i in 70:
		# chain: a tap (straight into the input buffer, as player.gd read_input files one) in the 1st / 2nd hit's last
		# frame; the buffer holds it until the window (player.gd air_ok)
		if P.anim == "air_combo" and (P.f == 2 or P.f == 5) and tapped != P.f:
			tapped = P.f
			P.buf["attack"] = P.BUF
		await tick()
		if i % 2 == 0: await shot("air_combo")
	await reset_pos()
	air_y = P.position.y - 150.0
	P.set_anim("guard", 0)
	Input.action_press("guard")
	await run_seq("air_guard", 30)
	P.set_anim("guard", 2)
	P.ghit = true
	await run_seq("air_guardhit", 20)
	Input.action_release("guard")
	P.set_anim("parry", 2)
	P.bash_t = 420.0
	await run_seq("air_parry", 24)
	await reset_pos()
	air_y = P.position.y - 160.0
	P.air = 0
	P.set_anim("double_jump")
	await run_seq("double_jump", 30)
	await reset_pos()
	# dive from high up: falls on its held frame, slams, gets up
	P.position.y -= 220.0
	P.on = false
	P.set_anim("dive")
	await run_seq("dive", 80)
	await reset_pos()
	Input.action_press("down")
	await run_seq("kneel", 50)
	await run_seq("kneel_attack", 44, {0: [["attack", true]], 2: [["attack", false]]})
	Input.action_release("down")
	await reset_pos()
	Input.action_press("up")
	P.set_anim("attack_high")
	await run_seq("attack_high", 30)
	Input.action_release("up")
	await reset_pos()
	P.set_anim("hurt")
	await run_seq("hurt", 20)
	await reset_pos()
	P.set_anim("death")
	await run_seq("death", 70)
	await reset_pos()
	P.set_anim("teeter")
	await run_seq("teeter", 40)
	await reset_pos()
	P.tag_in_at(null, 780.0)          # the game's own tag-in: from x 700 to 900 (town has no ground_y floor: put her on it)
	P.position.y = arena.level.floor_at(P.position.x)
	await run_seq("tag_in", 44)
	await reset_pos()
	P.set_anim("tag_out")
	await run_seq("tag_out", 40)
	await reset_pos()
	# vow: the ult poses it frame by frame (ult.gd pose), each held
	n = 0
	for fr in 3:
		P.set_anim("vow", fr)
		await frames(3)
		await shot("vow")
	print("CAP done")
	quit()
