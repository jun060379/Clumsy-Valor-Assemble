extends SceneTree
## Headless check of WP9 (combat feedback) and WP13 (gcharge, rift sigil): godot --headless -s tests/test_w9.gd
## per-element split numbers with icons and colours, the number / word / crit rules, pickup words to the feed (GET),
## parryWord's hard-cut timeline, the ground shadow, the camera (lead, CAMF whip, camY per scene, the view's aspect),
## the lootGet tink, Estelle's gcharge and Aida's sigil.

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func run(arena, ms: float) -> void:
	for i in int(ms / 16.0):
		arena._process(0.016)

## press a key for one engine frame's worth of "just pressed", then let it be held
func press(arena, k: String) -> void:
	Input.action_press(k)
	await process_frame
	await process_frame

func txts(arena) -> Array:
	return arena.fx.filter(func(e): return e["k"] == "txt")

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	arena.ui_root.visible = false
	var P = arena.player
	arena.go_training()
	arena.ghost.leave()
	await process_frame

	# ---- damage numbers ----
	var A = arena
	check(A.txt_num("-23") and A.txt_num("+5") and not A.txt_num("약점!") and not A.txt_num("PARRY!"), "numbers start with a digit (after a sign)")
	check(A.txt_big("-46!") and A.txt_big("치명 12") and not A.txt_big("-46"), "'!' or 치명 makes the crit slab")
	var d = arena.dummies[1]
	arena.fx.clear()
	arena.hit_by = "aida"
	d.hit(1.0, 4.0)
	arena.hit_by = ""
	var nums := txts(arena).filter(func(e): return A.txt_num(e["s"]))
	check(nums.size() == 2, "Aida (dark + phys) on a dummy: two numbers")
	if nums.size() == 2:
		check(nums[0]["ic"] == "dark" and nums[1]["ic"] == "phys", "each with its element icon")
		check(is_equal_approx(nums[1]["x"] - nums[0]["x"], 44.0) and is_equal_approx(nums[1]["y"] - nums[0]["y"], 6.0), "44 px apart, the second 6 px lower")
		check(nums[0]["col"] == arena.ELEM.ELC["dark"], "a neutral part is in its element colour (ELC)")
	arena.fx.clear()
	arena.damage_text_e(Vector2(500, 200), {"dmg": 30, "mul": 1.5, "parts": [{"el": "phys", "dmg": 30, "mul": 1.5}]}, Color("#ffd1e6"))
	arena.damage_text_e(Vector2(600, 200), {"dmg": 5, "mul": 0.5, "parts": [{"el": "phys", "dmg": 5, "mul": 0.5}]}, Color("#ffd1e6"))
	arena.damage_text_e(Vector2(700, 200), {"dmg": 30, "mul": 1.0, "parts": [{"el": "holy", "dmg": 15, "mul": 1.75}, {"el": "dark", "dmg": 15, "mul": 0.5}]}, Color("#ffd1e6"))
	var t3 := txts(arena)
	check(t3.size() == 4 and t3[0]["col"] == Color("#ffd34d") and t3[1]["col"] == Color("#aaaabb"), "single number: weak #ffd34d, resist #aab")
	check(t3.size() == 4 and t3[2]["col"] == Color("#ffd34d") and t3[3]["col"] == Color("#8f97a8"), "split parts: weak #ffd34d, resist #8f97a8")
	check(t3.size() == 4 and t3[0]["life"] == 600.0 and t3[0]["s"] == "-30", "600 ms, '-n'")
	arena.fx.clear()
	arena.dummies[5].hit(1.0, 4.0)       # the unbreakable row: one plain number, no icon
	var t4 := txts(arena).filter(func(e): return A.txt_num(e["s"]))
	check(t4.size() == 1 and t4[0]["ic"] == "" and t4[0]["col"] == Color("#ffe9a8"), "an unbreakable dummy shows a plain #ffe9a8 number")

	# ---- pickup words go to the notice feed with a GET tag ----
	arena.fx.clear()
	var F = arena.fame.fx
	F.feed.clear()
	for s in ["실링 +12", "기억석 +3", "룬 · 불씨", "장비 · 낡은 검"]:
		arena.text(Vector2(500, 200), s, Color("#ffd34d"))
	check(txts(arena).is_empty() and F.feed.size() == 4 and F.feed.all(func(n): return n["tag"] == "GET"), "실링 / 기억석 / 룬 · / 장비 → the feed, tagged GET")
	check(F.feed[0]["col"] == Color("#ffd34d"), "the feed line keeps the word's colour")
	arena.text(Vector2(500, 200), "보물방 · 실링 +5", Color("#ffd34d"))
	check(txts(arena).size() == 1, "other words still float")

	# ---- parryWord ----
	var cuts := {0: true, 49: true, 50: false, 89: false, 90: true, 139: true, 140: false, 169: false, 170: true, 519: true, 520: false, 559: false, 560: true, 599: true, 600: false, 619: false, 620: false}
	var bad := []
	for ms in cuts:
		if arena.pryw_visible(float(ms)) != cuts[ms]: bad.append(ms)
	check(bad.is_empty(), "PARRY hard cuts at 0/50/90/140/170/520/560/600 ms, gone by 620 %s" % [bad])
	arena.pryw_t0 = -1.0
	arena.fx.clear()
	arena.parry_fx(P, null)
	check(arena.pryw_t0 >= 0.0, "a parry starts the full-screen word")
	check(txts(arena).any(func(e): return e["s"] == "PARRY!" and e["col"] == Color("#ffd34d")), "…and the 'PARRY!' tag over her")
	check(arena.big_words.filter(func(w): return not w["screen"]).is_empty(), "no over-head pop word any more")
	arena.hitstop = 0.0
	arena.flash = 0.0

	# ---- ground shadow ----
	P.position = Vector2(1500, arena.ground_y)
	P.on = true
	check(arena.shadow_y() == arena.ground_y and is_equal_approx(arena.shadow_rx(arena.ground_y), 34.0), "standing: 34 px wide at her feet")
	P.position.y = arena.ground_y - 200.0
	P.on = false
	check(arena.shadow_y() == arena.ground_y and is_equal_approx(arena.shadow_rx(arena.shadow_y()), 17.0), "200 px up: half as wide, on the ground")
	P.position.y = arena.ground_y - 300.0
	check(is_equal_approx(arena.shadow_rx(arena.shadow_y()), 34.0 * 0.4), "never narrower than 0.4")
	P.position = Vector2(600, arena.ground_y - 200.0)
	check(arena.shadow_y() == arena.ground_y - 150.0, "over a plank: on the plank")
	P.position = Vector2(1000, arena.ground_y)
	P.on = true
	P.vy = 0.0
	P.set_anim("idle", 0)

	# ---- camera ----
	P.dir = 1
	check(arena.cam_x_target() == 1070.0, "lead: +70 px facing right")
	P.dir = -1
	check(arena.cam_x_target() == 930.0, "lead: -70 px facing left")
	P.position.x = 100.0
	check(arena.cam_x_target() == arena.get_viewport_rect().size.x / 2.0, "clamped at the world's left edge")
	P.position.x = 1000.0
	P.dir = 1
	arena.cam.position.x = 1000.0
	arena._process(0.016)
	var step1: float = arena.cam.position.x - 1000.0
	check(absf(step1 - 70.0 * 16.0 / 90.0) < 0.5, "follow: 16/90 per 16 ms (%.2f)" % step1)
	P.cam_focus = {"x": 1070.0, "t": 500.0}
	arena.cam.position.x = 1000.0
	arena._process(0.016)
	var step2: float = arena.cam.position.x - 1000.0
	check(absf(step2 - 70.0 * 16.0 / 45.0) < 0.5, "CAMF whip: 16/45 per 16 ms (%.2f)" % step2)
	P.cam_focus = {"x": 0.0, "t": 0.0}
	check(arena.cam_y_top() == 0.0, "training ground: camY 0")
	check(arena.view_w(Vector2(1920, 1080)) == 889 and arena.view_w(Vector2(3000, 1000)) == 1400 and arena.view_w(Vector2(1000, 1000)) == 800, "view: 500 tall, aspect clamped 1.6..2.8")
	arena.go_town(Vector2(640, arena.ground_y), 1)
	check(arena.cam_y_top() == 0.0 and arena.cam.position.y == arena.get_viewport_rect().size.y / 2.0, "town spawn: camY 0")
	P.position.y = arena.ground_y - 195.0
	check(is_equal_approx(arena.cam_y_top(), -195.0 * 0.9), "town, up on the terrace: (P.y - GROUND) x 0.9")
	P.position.y = arena.ground_y + 320.0
	check(is_equal_approx(arena.cam_y_top(), 336.0) and is_equal_approx(arena.cam_y_top(true), 288.0), "lower plaza: x 1.05 while following, x 0.9 on entry")
	P.position.y = arena.ground_y - 2000.0
	check(arena.cam_y_top() == -720.0, "camY never above -720")
	arena.go_hall(0, Vector2(1760, arena.ground_y), 1)
	check(arena.cam_y_top() == 0.0, "hall floor: camY 0")
	P.position.y = arena.ground_y - 130.0
	check(arena.cam_y_top() == -90.0, "hall gallery: camY -90")

	# shadow in the cave: raised rock is not a floor for it (GROUND below, as drawn in the prototype)
	arena.enter_dungeon()
	var rock: Dictionary = arena.solids[0] if not arena.solids.is_empty() else {}
	if not rock.is_empty():
		P.position = Vector2(rock.x + rock.w / 2.0, rock.top)
		P.on = true
		check(arena.shadow_y() == arena.ground_y, "standing on raised cave rock: the shadow stays on GROUND")
	# the hall: the landing is a plank for it; on the stairs (P.ramp) it sits at her feet
	arena.go_hall(0, Vector2(1760, arena.ground_y), 1)
	var Hl = arena.level
	if Hl.landing != null:
		P.position = Vector2((Hl.landing["x0"] + Hl.landing["x1"]) / 2.0, Hl.landing["y"] - 100.0)
		P.on = false
		check(arena.shadow_y() == Hl.landing["y"], "over the hall landing: on the landing")
		var r: Dictionary = Hl.ramps[0]
		var rx: float = (r["x0"] + r["x1"]) / 2.0
		P.position = Vector2(rx, Hl.ramp_y(r, rx))
		P.on = true
		P.plat = r
		check(arena.shadow_y() == P.position.y, "on the stairs: at her feet")
		P.plat = null
	else:
		check(false, "hall floor 0 has a landing")
	P.position = Vector2(1760, arena.ground_y)

	# ---- the lootGet ring: the pack's pickup sounds by the item's kind ----
	for ap in arena.sfx_pool: ap.stop()
	arena.loot_pick("mem")
	var tk = null
	for ap in arena.sfx_pool:
		if ap.playing and ap.stream == arena.sfx_stream("pick_stone"): tk = ap
	check(tk != null and not arena.has_method("loot_tink"), "the chest's 기억석 rings pick_stone (the procedural tink is gone)")
	for ap in arena.sfx_pool: ap.stop()

	# ---- Estelle's gcharge ----
	arena.go_training()
	arena.ghost.leave()
	P.position = Vector2(1000, arena.ground_y)
	P.on = true
	P.dir = 1
	P.set_anim("idle", 0)
	await press(arena, "guard")
	run(arena, 400)
	check(P.anim == "guard", "holding the shield: guard")
	await press(arena, "attack")
	run(arena, 48)
	check(P.anim == "gcharge", "attack under the shield: gcharge")
	run(arena, 300)
	check(P.anim == "gcharge" and P.charge_t >= 200.0, "she holds it while attack is held")
	Input.action_release("attack")
	run(arena, 32)
	check(P.anim == "cthrust", "released after >= 200 ms: the charged thrust")
	check(not P.cfull and P.cur_atk()["dmg"] == 2 and P.cur_atk()["kb"] == 10, "held under 650 ms: 2 damage, kb 10")
	P.cfull = true
	check(P.cur_atk()["dmg"] == 3 and P.cur_atk()["kb"] == 16, "fully charged: 3 damage, kb 16")
	P.cfull = false
	check(load("res://scripts/chars.gd").ATK["cthrust"]["dmg"] == 3, "the shared ATK table is left alone")
	run(arena, 800)
	Input.action_release("guard")
	run(arena, 300)
	await press(arena, "guard")
	run(arena, 400)
	await press(arena, "attack")
	run(arena, 64)
	Input.action_release("attack")
	run(arena, 32)
	check(P.anim == "guard", "released before 200 ms: back to guard")
	Input.action_release("guard")
	run(arena, 300)

	# ---- Aida's rift sigil ----
	P.switch_char("aida")
	P.set_anim("idle", 0)
	P.tp_cd = 0.0
	run(arena, 50)
	await press(arena, "guard")
	run(arena, 300)
	check(P.anim in ["mark", "amark"] and arena.sigil_on(), "aiming the rift: the sigil shows")
	await press(arena, "right")
	run(arena, 300)
	Input.action_release("right")
	check(arena.mark_pos.x > P.position.x + 100.0, "the sigil moves with the stick")
	Input.action_release("guard")
	run(arena, 50)
	check(not arena.sigil_on(), "released: the sigil is gone")
	run(arena, 1500)

	print("FAILS: %d" % fails)
	quit()
