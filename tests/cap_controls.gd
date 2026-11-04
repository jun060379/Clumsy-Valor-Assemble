extends SceneTree
## 1 · 2 · 3 slot swaps and 마우스 조준 in play (a drawn crosshair stands in for the pointer), then the 조작 안내 rows
## (needs a display): godot --path . --fixed-fps 60 --resolution 900x500 --write-movie OUT.avi -s tests/cap_controls.gd -- OUTDIR
var out := ""
var arena
var P
var cross: Line2D
var cross2: Line2D

func frames(k: int) -> void:
	for i in k:
		_cross()
		await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)

func _cross() -> void:
	if cross == null or not P.aim_test.is_finite(): return
	cross.position = P.aim_test
	cross2.position = P.aim_test

func key(k: int) -> void:
	for d in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = k
		e.keycode = k
		e.pressed = d
		Input.parse_input_event(e)

func hold(a: String, n: int) -> void:
	Input.action_press(a)
	await frames(n)
	Input.action_release(a)

func gob(x: float):
	var m = arena.spawn("goblin", x, 0.0)
	m.hp = 99999.0
	m.max_hp = 99999.0
	m.cd = 99999.0
	m.M = m.M.duplicate()
	m.M["ms"] = 0.0
	return m

func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(10)
	P = arena.player
	arena.fame.rec = ["estelle", "aida", "luce", "kenin"]
	arena.cfg.dev = "kbm"
	arena.cfg.kbm_seen = true
	arena.cfg.aim = "mouse"
	if OS.get_cmdline_user_args().size() > 1:
		arena.ui_root.menu.open_page("help")
		await frames(60)
		var O0 = arena.ui_root.menu.opts
		O0.scroll = 99999.0
		O0._clamp_scroll()
		await frames(60)
		await shot("help_rows")
		quit()
		return
	arena.enter_dungeon()
	await frames(60)
	for m in arena.mobs: m.hp = 0.0
	P.party = ["luce", "kenin", "aida"]
	for c in P.party: P.hpm[c] = 100.0
	P.switch_char("luce")
	await frames(20)
	for w in [cross, cross2]: pass
	cross = Line2D.new()
	cross.points = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0)])
	cross.width = 3.0
	cross.default_color = Color(1, 0.3, 0.3)
	cross2 = Line2D.new()
	cross2.points = PackedVector2Array([Vector2(0, -14), Vector2(0, 14)])
	cross2.width = 3.0
	cross2.default_color = Color(1, 0.3, 0.3)
	cross.z_index = 100
	cross2.z_index = 100
	P.get_parent().add_child(cross)
	P.get_parent().add_child(cross2)
	var x0: float = P.position.x
	var gl = gob(x0 - 300.0)
	gob(x0 + 260.0)
	# Luce: the pointer on the goblin behind her → the bolts go back
	P.aim_test = gl.position + Vector2(0, -50)
	await frames(20)
	for i in 3:
		await hold("attack", 6)
		await frames(22)
	await shot("luce_bolts_back")
	await frames(30)
	# the pointer on an empty spot ahead → the pillar there
	P.aim_test = Vector2(x0 + 140.0, P.position.y - 120.0)
	for i in 3:
		await hold("attack", 6)
		await frames(26)
	await shot("luce_pillar_at_pointer")
	await frames(40)
	# 2 → Kenin, shooting up at the pointer
	key(KEY_2)
	await frames(70)
	await shot("hud_slot_numbers")
	P.aim_test = P.position + Vector2(260.0, -230.0)
	for i in 2:
		await hold("attack", 6)
		await frames(14)
	await shot("kenin_up")
	await frames(40)
	P.aim_test = P.position + Vector2(-280.0, -60.0)
	await hold("attack", 6)
	await frames(14)
	await shot("kenin_back")
	await frames(60)
	# 3 → Aida: the sigil on the pointer, released → through the rift to it
	key(KEY_3)
	await frames(80)
	P.aim_test = P.position + Vector2(300.0, -40.0)
	Input.action_press("guard")
	await frames(20)
	await shot("aida_sigil")
	await frames(10)
	Input.action_release("guard")
	await frames(70)
	await shot("aida_after")
	cross.visible = false
	cross2.visible = false
	# the key list
	arena.ui_root.menu.open_page("help")
	await frames(60)
	var O = arena.ui_root.menu.opts
	O.scroll = 99999.0
	O._clamp_scroll()
	await frames(60)
	await shot("help_rows")
	arena.cfg.aim = "off"
	arena.cfg.dev = "auto"
	arena.cfg.save()
	print("CAP done")
	quit()
