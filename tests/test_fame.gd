extends SceneTree
## Guild fame / adventurer level: godot --headless --path . -s tests/test_fame.gd
## EXP curve and level-ups, the daily picker against the prototype's numbers, quest progress from kills and the boss,
## Eilin's report → seniors' introduction, the review letter → trial → rank up, the chapter claim, save state round trip.

var fails := 0

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func kill(arena, kind: String) -> void:
	var m = arena.spawn(kind, arena.player.position.x + 300.0, 0.0)
	m.spawn_t = 0.0
	m.hit(9999.0, 0.0)
	arena.fame._scan_mobs()

## pick every choice by label as the dialog offers them, pressing through lines
func choose(arena, label: String) -> bool:
	var D = arena.dlg
	if not D.active: return false
	for k in D.choices.size():
		if String(D.choices[k][0]).begins_with(label):
			D.i = D.lines.size() - 1
			D._pick(k)
			return true
	return false

func _initialize() -> void:
	var arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var F = arena.fame
	var FD = F.FD
	# ---- EXP curve ----
	check(FD.a_need(1) == 60 and FD.a_need(2) == 100 and FD.a_need(10) == 420, "aNeed = 60 + 40 (lv - 1)")
	F.init = false            # no cut-in for this one
	F.a_gain(700)
	check(F.alv == 6 and F.aexp == 0, "700 EXP from Lv 1 → Lv 6, 0 over (got Lv %d, %d)" % [F.alv, F.aexp])
	check(F.lv_can() == [2, 3, 4, 5, 6], "five level rewards wait in the book")
	var s0: int = arena.shilling
	var m0: int = F.mem_now()
	F.lv_claim(2)
	check(arena.shilling == s0 + 60 and F.mem_now() == m0 + 12, "Lv 2 reward: 실링 60 · 기억석 12")
	check(not F.lv_claim(2), "a level reward is claimed once")
	F.init = true
	F.a_gain(F.FD.a_need(6))
	check(F.alv == 7 and not F.fx.lv.is_empty(), "a level-up after start plays the level cut")
	check(F.d_pick("2026-11-1") == ["kill", "rep", "enter", "boss"] and F.d_pick("2026-1-15") == ["boss", "enh", "bestv", "enter"] and F.d_pick("2027-12-31") == ["enter", "kill", "eil", "boss"], "daily picker matches the prototype")
	# ---- rank 1 requests from play ----
	var lv0: int = F.alv
	var x0: int = F.aexp
	for i in 20: kill(arena, "goblin")
	check(F.fc("kill") == 20 and F.fc("k_goblin") == 20 and F.fc("k_by_estelle") == 20, "kills counted (all / per kind / per member)")
	check(F.alv == lv0 and F.aexp == x0 + 20 + 30 + 40, "no EXP from kills, only goblin observation Ⅰ+Ⅱ+Ⅲ (+90)")
	check(F.f_state(FD.fq("r1a")) == "done", "갱도 입구의 고블린 done")
	check(F.f_state(FD.fq("t1")) == "wait", "the trial waits for fame")
	var xb: int = F.aexp
	var lb: int = F.alv
	kill(arena, "boss")
	var gained: int = (F.alv - lb) * 0 + F.aexp - xb
	check(F.fc("boss") == 1 and F.f_state(FD.fq("r1b")) == "done", "boss down: 버섯 동굴 정찰 done")
	check(F.alv > lb or gained >= 150, "first boss clear pays 150 EXP (+ observation)")
	check(F.fame_obj() == "에일린에게 의뢰 보고 (2건)", "objective line: report to Eilin (got '%s')" % F.fame_obj())
	# ---- Bran's forge is shut until Eilin introduces him ----
	check(not F.bran_gate(), "Bran sends you to Eilin first")
	arena.dlg.active = false
	# ---- report → seniors → join ----
	F.eil_work()
	check(arena.dlg.active and String(arena.dlg.choices[0][0]).begins_with("의뢰 완료 보고 (2)"), "Eilin's desk menu offers the report")
	choose(arena, "의뢰 완료 보고")
	check(F.got.has("r1a") and F.got.has("r1b") and F.pts == 25 and F.fc("report") == 2, "two requests reported, fame 25")
	choose(arena, "누구요?")
	choose(arena, "선배님들?")
	for i in 3: choose(arena, "잘 부탁드려요")
	choose(arena, "네!")
	check(F.intro == 1 and F.bran == 1 and F.rec.has("aida") and F.rec.has("luce") and F.pts == 34, "seniors join, forge open, fame +9 → 34")
	check(F.bran_gate(), "Bran talks now")
	# ---- the review letter ----
	F.poll(true)
	check(int(F.let.get("1", 0)) == 1 and not F.fx.tc.is_empty() and F.fx.tc["kind"] == "letter", "a full gauge brings the bureau's letter (title card)")
	check(F.fame_obj() == "길드 관리국 서신 · 에일린에게", "objective: the letter")
	F.fx.tc = {}
	F.eil_work()
	check(String(arena.dlg.choices[0][0]).begins_with("관리국 서신 받기"), "Eilin holds the letter")
	choose(arena, "관리국 서신 받기")
	choose(arena, "맡겨 주세요")
	F.poll(true)
	check(F.f_state(FD.fq("t1")) == "run" and int(F.base.get("t1", -1)) == 1, "the trial runs from the current boss count")
	kill(arena, "boss")
	check(F.f_state(FD.fq("t1")) == "done", "trial done after one more boss")
	F.report()
	check(F.got.has("t1"), "trial reported")
	choose(arena, "승급!")
	check(F.r == 2 and not F.fx.rk.is_empty(), "rank 2 「동네 소문」, the rank cut plays")
	check(F.holds(), "the world holds under the rank cut")
	F.fx.rk["t"] = 99999.0
	F.fx._rk_close()
	F.fx.rk["t"] += 600.0
	F.fx._rk_events()
	check(F.fx.rk.is_empty() and arena.ui_root.menu.page == "gbk", "closing the rank cut opens the guild book")
	arena.ui_root.menu.page = ""
	F.poll(true)
	check(F.base.has("r2a") and F.f_state(FD.fq("r2a")) == "run", "rank 2 requests open with their bases")
	# ---- 모험 일지 ----
	check(F.t_can(FD.FCH[0]["t"][1], 0) and not F.t_can(FD.FCH[0]["t"][0], 0), "chapter 1: 첫 보고 claimable, 첫 출격 not yet")
	var xc: int = F.aexp + F.FD.a_need(F.alv) * 0
	var lc: int = F.alv
	F.t_claim("c1b")
	check(F.tgot.has("c1b") and (F.alv > lc or F.aexp == xc + 30), "첫 보고 claimed: EXP 30")
	# ---- facility ----
	arena.shilling = 500
	check(F.fac_restore("fire") and F.fac_ok("fire") and arena.shilling == 440, "벽난로 restored for 60")
	check(not F.fac_restore("library"), "도서관 waits for rank 3")
	# ---- save state ----
	var st: Dictionary = F.get_state()
	var r0: int = F.r
	F.r = 1
	F.pts = 0
	F.got = {}
	F.set_state(JSON.parse_string(JSON.stringify(st)))
	check(F.r == r0 and F.got.has("t1") and F.fac_ok("fire") and F.alv == st["alv"], "get_state / set_state round trip (through JSON)")
	F.gain_exp(5)
	check(F.aexp == int(st["aexp"]) + 5, "gain_exp for the boss chest")
	print("FAILS ", fails)
	quit(1 if fails else 0)
