extends SceneTree
## Recruitment and the fresh start (audit2 package A): godot --headless --path . -s tests/test_pa.gd
## A fresh game is solo with 12 shillings; Eilin's introduction (fameIntro → fameJoin) brings Aida and Luce into the
## guild, where they live in town until the party screen takes them along; the save keeps all of it, and a save from
## before recruiting was gated (all three along) loads with both recruited. Also: the wallet's rune count, the party
## wipe (heals everyone who has joined, back to x 380 outside the cave), the 회복 room reward and per-member run speed.

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

## press through the open dialog: finish each line, take the only choice; returns [speaker, lines] per box
func run_dialog(arena) -> Array:
	var D = arena.dlg
	var seen: Array = []
	var guard := 0
	while D.active and guard < 200:
		guard += 1
		if seen.is_empty() or seen.back()[1] != D.lines:
			seen.append([D.nm, D.lines.duplicate(), D.choices.map(func(c): return c[0])])
		if D.choosing():
			D._pick(0)
		else:
			D.advance()
	return seen

func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_test.json"))
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	for i in 3: arena._process(0.016)
	if arena.ui_root != null and arena.ui_root.title.active: arena.ui_root.title.active = false
	var P = arena.player
	var F = arena.fame
	var R = arena.runes
	var FOLK = arena.FOLK.of(arena)

	print("fresh start")
	check(P.party == ["estelle"], "a fresh game starts alone (%s)" % str(P.party))
	check(P.roster() == ["estelle"] and F.rec == ["estelle"] and F.intro == 0, "ROSTER / FAME.rec hold only the leader")
	check(FOLK.folk().is_empty(), "nobody else walks around town")
	check(arena.shilling == 12, "IRON = 12 at the start (%d)" % arena.shilling)
	check(F.runes_now() == R.rune_count() and F.runes_now() == 18, "the book wallet counts RUNEBAG (%d)" % F.runes_now())
	arena.toggle_member("luce")
	check(P.party == ["estelle"], "Luce can't be taken along before she joins")
	# the start screen: choosing a member on a fresh game makes her the only one
	arena.ui_root.start_game("luce")
	check(P.party == ["luce"] and P.who == "luce", "start screen on a fresh game: PARTY = [chosen] (%s)" % str(P.party))
	F.poll(true)
	check(F.rec.has("luce") and P.roster() == ["estelle", "luce"], "the one in control joins the roster (%s)" % str(P.roster()))
	# back to Estelle alone for the rest
	F.rec = ["estelle"]
	arena.ui_root.start_game("estelle")
	P.party = ["estelle"]
	check(P.who == "estelle" and P.roster() == ["estelle"], "reset to Estelle alone")

	print("Eilin's introduction")
	var pts0: int = F.pts
	F.intro_seniors(false)
	var boxes := run_dialog(arena)
	var who: Array = boxes.map(func(b): return b[0])
	check(who == ["에일린", "아이다", "루체", "브랜", "에일린"], "the introduction's speakers (%s)" % str(who))
	if boxes.size() == 5:
		check(boxes[0][1] == ["우리 길드를 지금까지 지켜 온 선배님들이에요. 마침 다들 계시네요."] and boxes[0][2] == ["선배님들?"], "Eilin: 선배님들?")
		check(boxes[1][1] == ["…신입이구나. 아이다. 길드 일 말고는 묘지기를 해.", "동굴의 해골 광부들, 원래는 이 마을 사람들이었어. 그건 알아 둬."] and boxes[1][2] == ["잘 부탁드려요"], "Aida's lines")
		check(boxes[2][1] == ["안녕하세요, 루체예요! 다치면 꼭 저한테 먼저 오세요.", "…아, 물론 안 다치는 게 제일 좋지만요!"], "Luce's lines")
		check(boxes[3][1] == ["브랜이오. 길드 대장간을 맡고 있지. 흐흐.", "장비든 룬이든 가져오쇼. 오늘부터 대장간 문은 열어 두겠소."], "Bran's lines")
		check(boxes[4][1] == ["아이다 씨와 루체 씨는 오늘부터 파티에 함께할 수 있어요. 분수대에서 편성해 보세요.", "대장간도 열렸으니까, 마을에 가면 브랜 씨한테 장비를 맡겨 보세요!"] and boxes[4][2] == ["네!"], "Eilin: 분수대에서 편성해 보세요 · 네!")
	check(F.intro == 1 and F.bran == 1 and F.pts == pts0 + 9, "fameJoin: intro, forge open, fame +9")
	check(F.rec == ["estelle", "aida", "luce"] and P.roster() == ["estelle", "aida", "luce"], "Aida and Luce join the roster (%s)" % str(P.roster()))
	check(P.party == ["estelle"], "…but not the party (%s)" % str(P.party))
	check(FOLK.folk() == ["aida", "luce"], "they live in town (%s)" % str(FOLK.folk()))
	FOLK.place()
	check(FOLK.npc("aida")["placed"] and FOLK.npc("luce")["placed"], "both placed in town")

	print("party screen")
	arena.sortie.party_ui.show_it()
	arena.sortie.party_ui.press("aida", "in")
	check(P.party == ["estelle", "aida"], "넣기: Aida comes along (%s)" % str(P.party))
	check(FOLK.folk() == ["luce"], "only Luce stays in town")
	arena.sortie.party_ui.close()

	print("save round trip")
	P.hpm["luce"] = 20.0
	var snap: Dictionary = arena.save.snapshot()
	check(arena.save.save(), "saved")
	P.party = ["estelle"]
	F.rec = ["estelle"]
	F.intro = 0
	F.bran = 0
	var d0 = arena.save.read()
	check(d0 is Dictionary, "read back")
	arena.save.apply(d0)
	check(P.party == ["estelle", "aida"] and F.rec == ["estelle", "aida", "luce"] and F.intro == 1 and F.bran == 1, "party, roster and intro restored (%s %s)" % [str(P.party), str(F.rec)])
	check(is_equal_approx(P.hpm["luce"], 20.0), "Luce's HP in town restored")
	# a solo save stays solo (no recruiting from nothing)
	var solo: Dictionary = snap.duplicate(true)
	solo["party"] = ["estelle"]
	solo["fame"]["rec"] = ["estelle"]
	solo["fame"]["intro"] = 0
	solo["fame"]["bran"] = 0
	solo["fame"]["got"] = {}
	arena.save.apply(solo)
	check(P.party == ["estelle"] and F.rec == ["estelle"] and F.intro == 0 and P.roster() == ["estelle"], "a solo save loads solo")
	# an old save: all three along, nobody recruited, no introduction
	var old: Dictionary = solo.duplicate(true)
	old["party"] = ["estelle", "aida", "luce"]
	arena.save.apply(old)
	check(P.party == ["estelle", "aida", "luce"], "old save: the party of three loads (%s)" % str(P.party))
	check(F.rec == ["estelle", "aida", "luce"] and F.intro == 1 and F.bran == 1, "old save: Aida and Luce count as recruited, introduced, forge open")
	# an old save without a fame block at all
	var older: Dictionary = old.duplicate(true)
	older.erase("fame")
	F.rec = ["estelle"]
	F.intro = 0
	arena.save.apply(older)
	check(F.rec == ["estelle", "aida", "luce"] and F.intro == 1, "old save without fame: recruited too")

	print("party wipe, healing, run speed")
	P.party = ["estelle"]
	P.hpm["luce"] = 5.0
	P.hpm["aida"] = 5.0
	P.position.x = 2400.0
	arena.fx.clear()
	P.party_down = false
	P.die()
	for i in 160: P.party_step(16.0)
	check(P.anim != "death" and P.hp == P.MAX_HP, "the wipe brings her back")
	check(P.hpm["luce"] == P._mhp("luce") and P.hpm["aida"] == P._mhp("aida"), "the wipe heals everyone who has joined, in town too")
	check(absf(P.position.x - 380.0) < 40.0, "outside the cave she is back at x 380 (%.0f)" % P.position.x)
	check(not arena.fx.any(func(t): return String(t.get("s", "")).contains("파티 전멸")), "no 파티 전멸 line outside the cave")
	P.hpm["luce"] = 5.0
	R.pay("heal")
	check(P.hpm["luce"] > 5.0, "the 회복 reward heals members in town as well (%.0f)" % P.hpm["luce"])
	for c in ["estelle", "aida"]:
		if not P.party.has(c): arena.toggle_member(c)
		P.switch_char(c)
		R.tick(16.0)
		var T: Dictionary = R.gear_tot(c)
		var exp_run: float = 0.36 * R.BASE_MS[c] * (1.0 + T["ms"] / 100.0 - 0.02 * T["heavy"])
		if R.memory != null: exp_run *= R.memory.spd()
		check(is_equal_approx(P.RUN, exp_run), "%s: RUN = 0.36 × STATS.ms %.2f × gear (%.4f vs %.4f)" % [c, R.BASE_MS[c], P.RUN, exp_run])
	print("FAILS: %d" % fails)
	quit(1 if fails > 0 else 0)
