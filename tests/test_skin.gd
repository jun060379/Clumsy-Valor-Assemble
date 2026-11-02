extends SceneTree
## Costume skins (skin_data.gd, skins.gd): the registry, the resolver's fallback to 기본, the five unlock sources (fame grade,
## boss chest, level / memorial, shop, story) and the dev grant, the save round trip and an old save's migration, the
## missing-asset guard ("준비 중": never worn, never sold, never drawn with stand-in art), the hall's 옷장 door and facility,
## the wardrobe page and the 의상 tab driven by keys and taps.
## godot --headless -s tests/test_skin.gd   → "skin: N ok, M failed"
## With a costume's files in assets/skins/estelle_s1/ (the end-to-end run copies the 기본 files there for a moment) the
## ready-costume checks run too: worn sheets / face / standing art come from the folder, the chest can drop it, it saves.

var ok := 0
var bad := 0

func check(c: bool, what: String) -> void:
	if c: ok += 1
	else:
		bad += 1
		print("FAIL ", what)

func frames(n: int) -> void:
	for i in n: await process_frame

func key(page, k: int) -> void:
	page._key(k)

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await frames(3)
	var SD = load("res://scripts/skin_data.gd")
	var SK = load("res://scripts/skins.gd")
	var S = arena.skins
	var F = arena.fame
	var R = arena.runes
	var M = R.memory
	S.reset()
	SK.rescan()
	var e2e: bool = ResourceLoader.exists("res://assets/skins/estelle_s1/sheet_0.png")
	print("end-to-end costume folder present: ", e2e)

	# ---- the registry ----
	var ids := {}
	var kinds := {}
	for s in SD.SKINS:
		check(not ids.has(s["id"]), "unique id " + s["id"])
		ids[s["id"]] = 1
		check(s["c"] in ["estelle", "aida", "luce"], "member of " + s["id"])
		check(s.has("n") and s.has("d") and s["unlock"] is Dictionary and s["unlock"].has("kind") and s["unlock"].has("value") and s.has("dir"), "fields of " + s["id"])
		check(String(s["unlock"]["kind"]) in ["default", "fame", "drop", "level", "shop", "story"], "unlock kind of " + s["id"])
		kinds[s["unlock"]["kind"]] = 1
		if not SD.is_base(s["id"]) and s["id"] != "estelle_misuk":
			check(String(s["dir"]) == "res://assets/skins/%s/" % s["id"], "asset folder of " + s["id"])
			check(s.get("placeholder", false) == true, "invented names are flagged placeholder: " + s["id"])
	for c in ["aida", "luce"]:
		var L: Array = SD.of(c)
		check(L.size() == 3 and L[0]["id"] == SD.BASE[c] and L[0]["n"] == "기본" and L[0]["dir"] == "", "%s: 기본 + two slots" % c)
	var LE: Array = SD.of("estelle")
	check(LE.size() == 4 and LE[0]["id"] == "estelle_base" and LE[0]["n"] == "초심" and LE[0]["dir"] == "res://assets/skins/estelle_base/" and LE[0].get("partial", false), "Estelle: 초심 (default, partial) first")
	check(LE[1]["id"] == "estelle_misuk" and LE[1]["n"] == "미숙한 결의" and LE[1]["dir"] == "" and LE[1]["unlock"]["kind"] == "story", "미숙한 결의: the original art, a story reward")
	for c in ["estelle", "aida", "luce"]:
		check(S.owns(SD.BASE[c]) and SK.worn(c) == SD.BASE[c], "%s owns and wears 기본" % c)
	for k in ["fame", "drop", "level", "shop", "story"]: check(kinds.has(k), "an example slot unlocks by " + k)
	check(SD.how("estelle_s1", F.FD.FRANK).begins_with("길드 명성 2등급") and SD.how("aida_s2").contains("메모리얼") and SD.how("estelle_s2").contains("실링 300"), "how-to-get lines")

	# ---- the resolver: 기본 files and the fallback ----
	for c in ["estelle", "aida", "luce"]:
		for k in SD.ASSETS:
			for i in int(SD.ASSETS[k].get("n", 1)):
				var bp: String = SK.base_path(c, k, i)
				check(ResourceLoader.exists(bp), "기본 %s %s %d exists (%s)" % [c, k, i, bp])
	check(SK.base_path("estelle", "sheet", 3) == "res://assets/chars/estelle/estelle_3.png" and SK.base_path("aida", "bust") == "res://assets/fame/por_aida.png" and SK.base_path("luce", "doll") == "res://assets/hall/dollC.png", "기본 paths")
	check(SK.path("luce", "sheet", 0) == SK.base_path("luce", "sheet", 0) and SK.sheet("luce", 0) != null and SK.face("luce") != null, "worn 기본 resolves to the 기본 files")
	check(SK.path_of("aida_s1", "aida", "st_gear") == SK.base_path("aida", "st_gear"), "a key the costume lacks falls back to 기본")
	check(SK.path_of("nope", "aida", "face") == SK.base_path("aida", "face") and SK.tex_of("nope", "face") == null, "an unknown id never breaks the resolver")
	check(SK.bounds("luce") == load("res://scripts/char_bounds.gd").B["luce"], "기본 bounds for 캐릭터 도트화")

	# ---- 초심: a default drawn in parts, its own run / walk; the rest from the original art row by row ----
	var CB0: Array = load("res://scripts/char_bounds.gd").B["estelle"]
	var CH0 = load("res://scripts/chars.gd")
	check(SK.is_ready("estelle_base") and SK.worn("estelle") == "estelle_base", "초심 is worn by default")
	for r in [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 26, 27, 28, 35, 36, 37]: check(SK.has_row("estelle_base", r), "초심 draws row %d" % r)
	for r in [1, 2, 25, 29, 38, 41]: check(not SK.has_row("estelle_base", r), "초심 leaves row %d (unused) to the original art" % r)
	for an in CH0.A_EST:
		if int(CH0.A_EST[an][0]) >= 0: check(SK.has_row("estelle_base", int(SK.entry("estelle", an)[0])), "초심 draws its own " + an)
	check(SK.sheet_row("estelle", 0).resource_path == "res://assets/skins/estelle_base/sheet_0.png", "idle from 초심")
	check(SK.sheet_row("estelle", 8).resource_path == "res://assets/skins/estelle_base/sheet_1.png" and SK.sheet_row("estelle", 28).resource_path == "res://assets/skins/estelle_base/sheet_4.png", "attack1 (row 8) and teeter (row 28) from 초심's sheets")
	check(SK.entry("estelle", "parry")[0] == 15 and (SK.entry("estelle", "parry")[1] as Array).size() == 4 and int(SK.entry("estelle", "parry")[1][0]) + int(SK.entry("estelle", "parry")[1][1]) == 215, "parry: 4 frames, the same 215 ms parry window")
	check(SK.sheet_row("estelle", 7).resource_path == "res://assets/skins/estelle_base/sheet_1.png" and SK.sheet_row("estelle", 36).resource_path == "res://assets/skins/estelle_base/sheet_5.png", "runjump and run rows from its own sheets")
	check((SK.entry("estelle", "run")[1] as Array).size() == 8 and (SK.entry("estelle", "walk")[1] as Array).size() == 10, "its own run (8 key frames) and walk (10)")
	var rs := 0
	for ms in SK.entry("estelle", "run")[1]: rs += int(ms)
	var ws := 0
	for ms in SK.entry("estelle", "walk")[1]: ws += int(ms)
	check(rs >= 560 and rs <= 720 and ws >= 900 and ws <= 1250, "run / walk cycles at a natural cadence (%d / %d ms for two steps)" % [rs, ws])
	check(SK.resolve("estelle", "run", 7) == [35, 7] and SK.resolve("estelle", "walk", 9) == [37, 0], "frames past nine run on into the next row")
	check(SK.resolve("estelle", "swap_in", 2)[0] == 35, "composite moves built from run use 초심's run")
	check(SK.resolve("estelle", "attack1", 2) == [8, 2] and SK.resolve("aida", "run", 3) == [1, 3], "everything else as before")
	check(SK.bob("estelle", "run") == load("res://scripts/skin_data.gd").BOB_RUN and SK.bob("estelle", "run").size() == 8 and SK.bob("estelle", "walk").is_empty() and SK.bob("estelle", "attack1").is_empty() and SK.bob("aida", "run") == load("res://scripts/chars.gd").BOB["aida"]["run"], "초심's run has its own bounce (matched to its airborne frame); its walk carries its own")
	check(SK.steps("estelle") == [1, 5] and SK.steps("luce") == [1, 5], "footfalls")
	var B0: Array = SK.bounds("estelle")
	check(B0.size() >= 38 * 18 and B0[35 * 18] >= 0 and B0[25 * 18] == CB0[25 * 18], "bounds: 초심's rows merged over the original's")
	check(SK.path("estelle", "st_base").begins_with("res://assets/skins/estelle_base/st_base.") and SK.path("estelle", "st_cl") == SK.path("estelle", "st_base"), "its standing picture; a blink it lacks shows the same picture, never the old costume")
	check(SK.path("estelle", "face") == SK.base_path("estelle", "face") and SK.path("estelle", "st_gear") == SK.base_path("estelle", "st_gear"), "face / gear art still the original's")

	# ---- the missing-asset guard ----
	var wip: Array = ["estelle_s2", "aida_s1", "aida_s2", "luce_s1", "luce_s2"] + ([] if e2e else ["estelle_s1"])
	for id in wip:
		check(not SK.is_ready(id), id + " is 준비 중 (no files)")
		check(SK.tex_of(id, "sheet", 0) == SK.load_tex(SK.base_path(SD.get_skin(id)["c"], "sheet", 0)), id + ": nothing of its own to draw, the resolver answers 기본")
	check(S.grant("aida_s1", "drop", true) and S.owns("aida_s1") and not S.can_equip("aida_s1") and not S.equip("aida_s1"), "owned but 준비 중: equip refuses")
	check(SK.worn("aida") == "aida_base" and S.is_worn("aida_base"), "she keeps 기본 on")
	S.equipped["aida"] = "aida_s1"         # a saved choice whose files went missing
	SK.rescan()
	check(SK.worn("aida") == "aida_base" and SK.path("aida", "sheet", 2) == SK.base_path("aida", "sheet", 2), "a worn costume without files draws 기본")
	S.reset()
	arena.shilling = 5000
	check(S.buy("estelle_s2") == "notready", "준비 중 costumes aren't sold")
	check(arena.shilling == 5000 and not S.owns("estelle_s2"), "no shilling spent")
	check(S.roll_chest(4, func(): return 0.0) == "" or e2e, "nothing to drop while no drop costume's art is in")

	# ---- unlock: fame grade ----
	S.reset()
	F.r = 1
	S.sync(true)
	check(not S.owns("estelle_s1"), "grade 1: no grade reward yet")
	F.r = 2
	S.sync()
	check(S.owns("estelle_s1") and S.owned["estelle_s1"] == "fame" and S.fresh.has("estelle_s1"), "grade 2 grants 순례자의 여행복 (NEW)")
	check(not S.owns("luce_s2"), "grade 3's reward waits")
	check(" · ".join(F.FD.funlock(1)).contains("의상 에스텔 「순례자의 여행복」") and not " · ".join(F.FD.funlock(1)).contains("향후"), "grade 2's unlock list names the costume: " + " · ".join(F.FD.funlock(1)))
	check(" · ".join(F.FD.funlock(2)).contains("루체 「여름 휴가 차림」"), "grade 3's unlock list")
	check(" · ".join(F.FD.funlock(0)) == " · ".join(F.FD.FUNLOCK[0]), "grade 1's list unchanged")
	F.rank_up()                              # 2 → 3: the rank-up hands it out
	await frames(2)
	check(F.r == 3 and S.owns("luce_s2"), "the rank-up to grade 3 grants 여름 휴가 차림")
	F.fx.rk = {}
	if arena.ui_root.menu.page != "": arena.ui_root.menu.page = ""

	# ---- unlock: level / memorial ----
	M.T("aida")["lv"] = 11
	M._changed()
	check(not S.owns("aida_s2"), "Lv 11: not yet")
	M.T("aida")["lv"] = 12
	M._changed()
	check(S.owns("aida_s2") and S.owned["aida_s2"] == "level", "Lv 12 (메모리얼 해방) grants 균열 너머의 옷")
	M.T("aida")["lv"] = 1
	M._changed()

	# ---- unlock: story ----
	check(S.grant("luce_s1", "story") and S.owned["luce_s1"] == "story", "story API: grant(id, \"story\")")
	check(not S.grant("luce_s1", "story"), "granting twice does nothing")
	S.owned.erase("luce_s1")
	check(S.story("luce_choir") == 1 and S.owns("luce_s1") and S.story("nothing") == 0, "story(key) grants what is keyed to it")

	# ---- unlock: chest ----
	var asked := [0]
	var rnd := func():
		asked[0] += 1
		return 0.0
	S.reset()
	check(S.roll_chest(0, rnd) == "" and asked[0] == 0, "a 커먼 chest never holds a costume and rolls nothing")
	if not e2e:
		check(S.roll_chest(4, rnd) == "" and asked[0] == 0, "no drop costume ready: the chest's rolls are untouched")
	check(SD.DROP_CHANCE[1] > 0.0 and SD.DROP_CHANCE[4] <= 0.2 and SD.DROP_CHANCE[1] < SD.DROP_CHANCE[4], "a low chance that grows with the grade")
	# the loot hook: a costume token flies out, its pickup grants it with a GET notice
	var LOOT = load("res://scripts/loot.gd")
	var lo = LOOT.new()
	lo.arena = arena
	lo.runes = R
	S.owned.erase("aida_s1")
	lo._collect({"kind": "skin", "v": "aida_s1"})
	check(S.owns("aida_s1") and S.owned["aida_s1"] == "drop", "a collected costume token is hers")
	check(F.fx.feed[-1]["tag"] == "GET" and String(F.fx.feed[-1]["s"]).contains("묘지기의 상복"), "with a GET notice")
	check(lo.summary()["skins"] == ["aida_s1"] and lo.summary()["gear"].is_empty(), "the chest summary lists it apart from gear")
	check(lo._tier({"kind": "skin", "v": "aida_s1"}) == 4, "it flies out as a top-tier item")
	lo.free()

	# ---- the dev key ----
	S.reset()
	var g: int = S.grant_all()
	check(g == 7 and SD.SKINS.all(func(s): return S.owns(s["id"])), "Page Up (dev) grants every costume (%d)" % g)
	var ev := InputEventKey.new()
	ev.keycode = KEY_PAGEUP
	ev.pressed = true
	S.reset()
	R._unhandled_input(ev)
	check(S.owned.size() == 10, "the Page Up key itself (DEV.on in tests)")

	# ---- shop (needs art) and equip, end to end with the copied files ----
	if e2e:
		SK.rescan()
		check(SK.is_ready("estelle_s1"), "e2e: estelle_s1's files are recognised")
		check(SK.own_path("estelle_s1", "sheet", 4) == "res://assets/skins/estelle_s1/sheet_4.png" and SK.own_path("estelle_s1", "st_base").begins_with("res://assets/skins/estelle_s1/st_base."), "e2e: its own sheet and standing art")
		check(SK.path_of("estelle_s1", "estelle", "st_gear") == SK.base_path("estelle", "st_gear"), "e2e: what it lacks (gear art) falls back")
		S.reset()
		check(not S.equip("estelle_s1"), "e2e: not hers: equip refuses")
		check(S.roll_chest(4, func(): return 0.0) == "", "e2e: a fame costume never drops from a chest")
		S.grant("estelle_s1", "fame")
		check(S.equip("estelle_s1") and SK.worn("estelle") == "estelle_s1", "e2e: equip")
		check(SK.sheet("estelle", 2).resource_path == "res://assets/skins/estelle_s1/sheet_2.png", "e2e: her sheets now come from the costume")
		check(SK.face("estelle").resource_path.begins_with("res://assets/skins/estelle_s1/face.") and SK.tex("estelle", "st_base").resource_path.begins_with("res://assets/skins/estelle_s1/"), "e2e: face and standing art too")
		check(SK.tex("estelle", "st_cl").resource_path == SK.own_path("estelle_s1", "st_base") and SK.tex("estelle", "st_gear").resource_path == SK.base_path("estelle", "st_gear"), "e2e: a blink it lacks shows its own st_base; gear art falls back")
		check(SK.sheet_row("estelle", 30) != null and SK.sheet_row("estelle", 30).resource_path == "res://assets/skins/estelle_s1/sheet_4.png", "e2e: a whole costume draws every row itself")
		# the player draws through it
		var P = arena.player
		P.switch_char("estelle")
		P.set_anim("idle")
		P.queue_redraw()
		await frames(2)
		check(SK.ver > 0, "e2e: drawn after the change")
		var snap = arena.pfx.snap_player()
		check(snap != null and (snap["tex"] as Texture2D).resource_path.begins_with("res://assets/skins/estelle_s1/"), "e2e: the afterimage takes the worn sheet")
		# save round trip with it on
		var d: Dictionary = arena.save.snapshot()
		S.reset()
		check(SK.worn("estelle") == "estelle_base", "e2e: reset puts 기본 back")
		arena.save.apply(JSON.parse_string(JSON.stringify(d)))
		check(SK.worn("estelle") == "estelle_s1" and S.owns("estelle_s1"), "e2e: the save keeps it on")
		S.equip("estelle_base")

	# ---- save round trip and migration ----
	S.reset()
	F.r = 1
	S.grant("luce_s1", "story", true)
	S.grant("aida_s1", "drop", true)
	S.seen("aida_s1")
	var d2: Dictionary = arena.save.snapshot()
	check(d2.has("skins") and d2["skins"]["owned"].has("luce_s1") and d2["skins"]["equipped"]["luce"] == "luce_base", "the snapshot carries skins")
	var d3: Dictionary = JSON.parse_string(JSON.stringify(d2))
	S.reset()
	arena.save.apply(d3)
	check(S.owns("luce_s1") and S.owned["luce_s1"] == "story" and S.owns("aida_s1") and S.fresh.has("luce_s1") and not S.fresh.has("aida_s1"), "owned / how / NEW survive JSON")
	check(SK.worn("estelle") == "estelle_base" and SK.worn("aida") == "aida_base" and SK.worn("luce") == "luce_base", "everyone on what they wore")
	# junk in the save
	S.set_state({"owned": {"bogus": "x", "estelle_s2": "shop"}, "equipped": {"estelle": "aida_s1", "luce": "luce_s2", "nobody": "x"}, "fresh": {"bogus": 1}})
	check(not S.owns("bogus") and S.owns("estelle_s2") and S.equipped["estelle"] == "estelle_base" and S.equipped["luce"] == "luce_base" and S.fresh.is_empty(), "unknown ids, someone else's costume and an unowned one are dropped")
	# an old save (before costumes): everyone on 기본; grade and levels already earned come quietly
	var old := d3.duplicate(true)
	old.erase("skins")
	old["fame"]["r"] = 2
	S.grant_all()
	var nf: int = F.fx.feed.size()
	arena.world_started = false               # a load happens before the world starts
	arena.save.apply(old)
	arena.world_started = true
	check(S.owned.size() == 4 and S.owns("estelle_s1") and SK.worn("estelle") == "estelle_base", "old save: 기본 for all, grade 2's costume handed out (%s)" % str(S.owned.keys()))
	check(F.fx.feed.slice(nf).all(func(x): return not String(x["s"]).contains("의상")), "quietly (no costume notice on load)")
	F.r = 1

	# ---- the hall: the 옷장 door and its facility ----
	var HD = load("res://scripts/hall_data.gd")
	var door = null
	for dd in HD.doors():
		if dd["act"] == "wardrobe": door = dd
	check(door != null and door["fl"] == 1 and door["name"] == "옷장", "a 옷장 door on the 2nd floor")
	var FAC: Dictionary = F.FD.fac("wardrobe")
	check(not FAC.is_empty() and FAC["r"] == 2 and not FAC.get("town", false), "옷장 is a hall facility of grade 2")
	check(F.FD.FUNLOCK[1][1].contains("옷장"), "grade 2's list names it")
	F.fac.erase("wardrobe")
	arena.go_hall(1, Vector2(door["x"], door["y"]), 1)
	for i in 6: arena._process(0.016)
	check(arena.level.near_door != null and arena.level.near_door["act"] == "wardrobe", "standing at the door")
	arena.try_interact()
	await frames(2)
	check(arena.ui_root.menu.page == "", "not restored: the door stays shut")
	F.r = 2
	arena.shilling = 500
	check(F.fac_restore("wardrobe") and F.fac_ok("wardrobe") and arena.shilling == 380, "restored for 120 shillings")
	arena.try_interact()
	var U = arena.ui_root
	var n := 0
	while (U.sweep.active or n < 2) and n < 2000:
		await process_frame
		n += 1
	var W = U.menu.wardrobe
	check(U.menu.page == "wardrobe" and W.visible, "restored: the door opens the wardrobe")
	# ---- the wardrobe page ----
	S.reset()
	S.grant_all()
	F.rec = ["estelle", "aida", "luce"]
	W._opened()
	n = 0
	while W.open_t < 1400.0 and n < 20000:
		await process_frame
		n += 1
	check(W.hits.size() >= 6, "the wardrobe draws its hit areas (%d)" % W.hits.size())
	check(W.c == "estelle" and W.cur_id() == "estelle_base", "opens on what she wears")
	key(W, KEY_RIGHT)
	await frames(5)
	check(W.sel == 1 and W.cur_id() == "estelle_misuk" and not S.fresh.has(W.cur_id()), "→ picks the next costume and marks it seen")
	key(W, KEY_DOWN)
	check(W.mv == 1, "↓ changes the mirror's move")
	key(W, KEY_ENTER)
	await frames(2)
	check(SK.worn("estelle") == "estelle_misuk" and SK.sheet_row("estelle", 0).resource_path == "res://assets/chars/estelle/estelle_0.png", "Enter wears 미숙한 결의: the original sheets")
	check((SK.entry("estelle", "run")[1] as Array).size() == 8, "and the original run")
	key(W, KEY_RIGHT)
	key(W, KEY_ENTER)
	await frames(2)
	check(SK.worn("estelle") == "estelle_misuk" or e2e, "a 준비 중 costume can't be worn from the wardrobe")
	S.equip("estelle_base")
	S.reset()
	S.grant("estelle_s1", "fame", true)
	W.c = "estelle"
	W._start_on_worn()
	for i in 3: key(W, KEY_RIGHT)
	check(W.cur_id() == "estelle_s2", "the shop costume")
	arena.shilling = 1000
	key(W, KEY_ENTER)
	key(W, KEY_ENTER)
	check(not S.owns("estelle_s2") and arena.shilling == 1000 or e2e, "준비 중: 구매 refused, nothing spent")
	key(W, KEY_E)
	n = 0
	while W.c == "estelle" and n < 20000:
		await process_frame
		n += 1
	check(W.c != "estelle", "E: the next member's rail (%s)" % W.c)
	for i in 20: await process_frame
	key(W, KEY_ESCAPE)
	n = 0
	while (U.sweep.active or n < 2) and n < 2000:
		await process_frame
		n += 1
	check(U.menu.page == "", "Esc closes it through the sweep")

	# ---- the 의상 tab ----
	U.menu.open_char("estelle")
	await frames(3)
	var C = U.menu.ext["char"]
	C._key(KEY_LEFT)                          # 상세 → 의상 (the tab bar wraps)
	await frames(30)
	check(C.tab == "wear", "의상 is the tab after 기록 (got %s)" % C.tab)
	check(C.TABS[-1][0] == "wear" and C.TABS[-2][0] == "rec", "the tab order")
	S.grant("estelle_misuk", "story", true)
	C._key(KEY_DOWN)
	await frames(10)
	check(C.wr.si == 1 and C.wr.cur_id() == "estelle_misuk", "↓ picks the next costume")
	C._key(KEY_ENTER)
	await frames(10)
	check(SK.worn("estelle") == "estelle_misuk", "Enter wears it")
	C._key(KEY_DOWN)
	C._key(KEY_ENTER)
	await frames(5)
	check(SK.worn("estelle") == ("estelle_s1" if e2e else "estelle_misuk"), "a costume whose art isn't in stays off")
	C._key(KEY_UP)
	C._key(KEY_UP)
	C._key(KEY_ENTER)
	check(SK.worn("estelle") == "estelle_base", "back to 초심")
	C.back()
	await frames(3)
	U.menu.page = ""

	print("skin: %d ok, %d failed" % [ok, bad])
	quit(1 if bad > 0 else 0)
