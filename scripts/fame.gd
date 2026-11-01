extends Node
## 길드 명성 + 모험가 레벨 (fame_core.js): two ladders.
##   · 모험가 레벨 (account): EXP from the first boss clear (150), the boss chest on repeat clears (agent B calls gain_exp),
##     monster observation, the 모험 일지 chapters and the 일일 훈련 milestones. No EXP from killing monsters.
##     Level-ups only announce (lvCut); the level rewards wait in the 모험 수첩.
##   · 길드 명성 (guild): town requests reported to Eilin, restored facilities, the seniors joining, finished observations.
##     A full gauge brings a review letter from the 길드 관리국; Eilin hands it over, the trial is done, the report → rankCut.
##
## Public interface (for the other systems):
##   gain_exp(n)            add adventurer EXP (the boss treasure chest's 60 on repeat clears goes through this)
##   finc(key, n)           bump a counter: "fuse" / "enh" (forge), "bestv" (bestiary opened), ... (see FQ / FCH / DPOOL keys)
##   fac_ok(id)             a facility is restored ("fire", "chand", "forge", "hearth", "store", "barn", "library", "bath", "rooms", "yard")
##   dmg_mul(kind)          fDmgK: kitchen hearth in dungeons, training yard, fully observed monster (+5 %)
##   obs_stage(kind)        bestiary observation stage 0..4 (Ⅰ met · Ⅱ first kill · Ⅲ / Ⅳ kill counts)
##   rune_seen(id)          a rune entered the codex (counts for 「룬 수집가」)
##   recruited(c) / rank()  who has joined the guild; the guild rank 1..7
##   bran_gate() -> bool    bran.gd asks before talking: false (and a line) until Eilin has introduced him
##   get_state() -> Dictionary / set_state(d)   everything that should be saved (agent C's save system stores it as is)
## Rewards the port has no home for yet: 기억석 go to arena.mem if it exists (else mem_held), runes go through
## arena.give_rune(grade) if it exists (else runes_held keeps the grades).

const FD := preload("res://scripts/fame_data.gd")
const FX := preload("res://scripts/fame_fx.gd")
const EIL_POR := preload("res://assets/eilin/por.png")
const BRAN_POR := preload("res://assets/bran/por.png")

var arena
var fx                          # fame_fx.gd: notices, lvCut, rankCut, title cards
# ---- state (FAME) ----
var r := 1                      # guild rank 1..7
var pts := 0                    # guild fame
var got := {}                   # quest id -> reported
var c := {}                     # counters
var base := {}                  # quest id -> counter value when it opened
var rec: Array = ["estelle"]    # members who have joined
var seen := {}                  # rune id -> found
var fac := {}                   # facility id -> restored
var alv := 1                    # adventurer level
var aexp := 0
var tgot := {}                  # chapter task claimed
var lvc := {}                   # level reward claimed (level -> 1)
var chc := {}                   # chapter reward claimed
var let := {}                   # rank -> 1 letter arrived, 2 letter taken
var flog: Array = []            # 지나온 길: {t, s, k}
var intro := 0                  # the seniors have been introduced
var bran := 0                   # Bran has joined (forge open)
var day = null                  # {d, pick, b, got, ms, pt}
var bs := {}                    # observation stage paid per monster
var bseen := {}                 # monsters met
var bkill := {}                 # kills per monster (bosses included)
var mem_held := 0
var runes_held: Array = []
# ---- runtime ----
var init := false
var scene := ""
var done_seen := {}             # fameDone
var poll_t := 0.0
var later: Array = []           # [ms, Callable]


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	fx = Control.new()
	fx.set_script(FX)
	fx.fame = self
	fx.arena = arena
	layer.add_child(fx)
	call_deferred("poll", true)
	_js_setup()

## the world holds still while a rank cut or a title card is up
func holds() -> bool:
	return fx != null and fx.blocking()

func _process(delta: float) -> void:
	var dt := minf(delta * 1000.0, 250.0)
	for L in later: L[0] -= dt
	var due := later.filter(func(L): return L[0] <= 0.0)
	later = later.filter(func(L): return L[0] > 0.0)
	for L in due: L[1].call()
	_scan_mobs()
	poll_t += dt
	if poll_t >= 700.0:
		poll(false)

func after(ms: float, cb: Callable) -> void:
	later.append([ms, cb])


# ---------- counters, log ----------
func fc(k: String) -> int:
	return int(c.get(k, 0))

func finc(k: String, n := 1) -> void:
	c[k] = fc(k) + n

func log_add(s: String, k := "") -> void:
	flog.append({"t": Time.get_unix_time_from_system() * 1000.0, "s": s, "k": k})
	if flog.size() > 80: flog = flog.slice(flog.size() - 80)

func notice(s: String, tag := "", col := Color.WHITE, big := false, life := 2600.0) -> void:
	if fx != null: fx.notice(s, tag, col, big, life)

func rank() -> int:
	return r

func recruited(ch: String) -> bool:
	return rec.has(ch)

func rune_seen(id: String) -> void:
	seen[id] = 1


# ---------- adventurer EXP (aGain): level-ups only announce; the rewards wait in the book ----------
func gain_exp(n: int) -> void:
	a_gain(n)

func a_gain(n: int) -> void:
	if alv >= FD.AMAX: return
	aexp += n
	var up := false
	var lv0 := alv
	while alv < FD.AMAX and aexp >= FD.a_need(alv):
		aexp -= FD.a_need(alv)
		alv += 1
		up = true
		log_add("모험가 Lv %d 달성" % alv, "lv")
		if alv == 3: log_add("일일 훈련이 열렸다", "day")
	if up:
		if init and fx != null:
			fx.lv_cut(lv0, alv)
		else:
			notice("모험가 Lv %d · 모험 수첩에서 보상 받기" % alv, "LEVEL UP", Color("#7fd0ff"), true, 3600.0)
			arena.sfx("ready", 0.6)

func lv_can() -> Array:
	var L := []
	for i in range(2, alv + 1):
		if not lvc.has(str(i)): L.append(i)
	return L

func lv_claim(i: int) -> bool:
	if i > alv or lvc.has(str(i)) or i < 2: return false
	lvc[str(i)] = 1
	pay_out(FD.a_reward(i), "레벨")
	return true

## payOut: 실링 to the purse, 기억석 and runes to whoever keeps them
func pay_out(R: Dictionary, tag := "보상") -> String:
	var iron: int = R.get("iron", 0)
	if iron: arena.shilling += iron
	if R.get("mem", 0): _add_mem(R["mem"])
	var g := ""
	if R.has("rune"):
		g = R["rune"]
		if arena.has_method("give_rune"):
			var id = arena.give_rune(g)
			if id is String and id != "": seen[id] = 1
		else:
			runes_held.append(g)
		notice("룬 · " + FD.GRADE[g][0] + " 룬", tag, FD.GRADE[g][1], false, 2600.0)
	return g

func _add_mem(n: int) -> void:
	if "mem" in arena: arena.set("mem", int(arena.get("mem")) + n)
	else: mem_held += n

func mem_now() -> int:
	return int(arena.get("mem")) if "mem" in arena else mem_held

func runes_now() -> int:
	if arena.has_method("rune_count"): return int(arena.rune_count())
	return runes_held.size()


# ---------- bestiary observation (Lobotomy Corporation style): each stage opens a part of the page and pays EXP once ----------
func _boss_k(k: String) -> bool:
	return k == "boss"

func b_th(k: String) -> Array:
	var lib := fac_ok("library")
	if _boss_k(k): return [2, 5] if lib else [3, 10]
	return [5, 15] if lib else [10, 30]

func obs_stage(k: String) -> int:
	if not bseen.has(k): return 0
	var n: int = bkill.get(k, 0)
	var t := b_th(k)
	return 4 if n >= t[1] else (3 if n >= t[0] else (2 if n >= 1 else 1))

func b_next(k: String) -> String:
	var st := obs_stage(k)
	var t := b_th(k)
	if st >= 4: return ""
	if st == 0: return "만나면"
	if st == 1: return "처치 1"
	return "처치 %d" % (t[0] if st == 2 else t[1])

func bs_n(n: int) -> int:
	var k := 0
	for m in bseen:
		if obs_stage(m) >= n: k += 1
	return k

func best_step(k: String) -> void:
	var st := obs_stage(k)
	var had: int = bs.get(k, 0)
	if st <= had: return
	var x := 0
	for i in range(had + 1, st + 1):
		x += (FD.BSTEPB if _boss_k(k) else FD.BSTEP)[i]
	bs[k] = st
	var ff := 5 if st == 4 and had < 4 and FD.MOBN.has(k) else 0
	if ff and init:
		pts += ff
		notice("관찰 완료 기록 · 길드 명성 +%d" % ff, "명성", Color("#ffd34d"))
	var nm: String = FD.MOBN.get(k, k)
	if init:
		if st == 4: log_add(nm + " 관찰 완료", "best")
		notice("관찰 기록 · %s %s%s · EXP +%d" % [nm, ["", "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ"][st], " 완료" if st == 4 else "", x], "도감", Color("#7fd0ff"), false, 2800.0)
		a_gain(x)

## fDmgK
func dmg_mul(kind := "") -> float:
	var k := 1.0
	if arena.level_kind() == "dungeon" and fac_ok("hearth"): k *= 1.1
	if fac_ok("yard"): k *= 1.05
	if kind != "" and obs_stage(kind) >= 4: k *= 1.05
	return k


# ---------- quests ----------
func q_val(q: Dictionary) -> int:
	return fc(q["k"]) - int(base.get(q["id"], 0))

func fame_next() -> Variant:
	return null if r >= 7 else FD.FRANK[r]

func f_trial() -> Dictionary:
	for q in FD.FQ:
		if q["r"] == r and q.get("t", "") == "trial": return q
	return {}

func f_letter() -> bool:
	var t := f_trial()
	return not t.is_empty() and not got.has(t["id"]) and int(let.get(str(r), 0)) == 1

## fState: got / lock / wait / letter / done / run
func f_state(q: Dictionary) -> String:
	if got.has(q["id"]): return "got"
	if q["r"] > r: return "lock"
	var trial: bool = q.get("t", "") == "trial"
	if trial and pts < FD.FRANK[mini(6, r)]["need"]: return "wait"
	if trial and int(let.get(str(q["r"]), 0)) < 2: return "letter"
	return "done" if maxi(0, q_val(q)) >= q["g"] else "run"

func ready_n() -> int:
	var n := 0
	for q in FD.FQ:
		if q["r"] == r and f_state(q) == "done": n += 1
	return n

## fameObj: the HUD's objective line in town and in the hall
func fame_obj() -> String:
	if f_letter(): return "길드 관리국 서신 · 에일린에게"
	var rd := ready_n()
	if rd: return "에일린에게 의뢰 보고 (%d건)" % rd
	if not intro and not got.has("r1a") and not got.has("r1b"): return "첫 의뢰 · 게시판에서 의뢰 확인"
	var t := f_trial()
	if not t.is_empty() and f_state(t) == "run": return "등급 심사 · " + String(t["n"]).replace("등급 심사 · ", "")
	return ""


# ---------- 모험 일지 ----------
func t_val(t: Dictionary) -> int:
	if t.has("k"): return fc(t["k"])
	match String(t["fn"]):
		"facN": return fac.size()
		"bs2": return bs_n(2)
		"bs4": return bs_n(4)
		"rank": return r
		"seenN": return seen.size()
		"maxStar": return int(arena.max_star()) if arena.has_method("max_star") else 0
		"engraved": return int(arena.engraved()) if arena.has_method("engraved") else 0
		"anyLv3": return 1 if _any_lv(3) else 0
		"anyLv6": return 1 if _any_lv(6) else 0
		"breakthrough": return 1 if arena.has_method("any_breakthrough") and arena.any_breakthrough() else 0
	return 0

## 세계수 levels per member belong to the character system (not in the port yet)
func _any_lv(n: int) -> bool:
	if not arena.has_method("char_level"): return false
	for ch in FD.ALLC:
		if rec.has(ch) and int(arena.char_level(ch)) >= n: return true
	return false

func ch_done(C: Dictionary) -> bool:
	for t in C["t"]:
		if not tgot.has(t["id"]): return false
	return true

func ch_open(i: int) -> bool:
	return i == 0 or chc.has(FD.FCH[i - 1]["id"])

func ch_cur() -> int:
	for i in FD.FCH.size():
		if not chc.has(FD.FCH[i]["id"]): return i
	return -1

func t_can(t: Dictionary, i: int) -> bool:
	return ch_open(i) and not tgot.has(t["id"]) and maxi(0, t_val(t)) >= t["g"]

func t_claim(id: String) -> void:
	for i in FD.FCH.size():
		for t in FD.FCH[i]["t"]:
			if t["id"] == id:
				if not t_can(t, i): return
				tgot[id] = 1
				pay_out(t["rw"], "일지")
				a_gain(t["rw"].get("x", 0))
				return

func ch_claim(id: String) -> void:
	var i := -1
	for j in FD.FCH.size():
		if FD.FCH[j]["id"] == id: i = j
	if i < 0: return
	var C: Dictionary = FD.FCH[i]
	if chc.has(id) or not ch_open(i) or not ch_done(C): return
	chc[id] = 1
	pay_out(C["rw"], "일지")
	log_add("모험 일지 「%s」 완료" % C["n"], "ch")
	a_gain(C["rw"].get("x", 0))
	var nx: Variant = FD.FCH[i + 1] if i + 1 < FD.FCH.size() else null
	notice("「%s」 완료" % C["n"] + (" · 다음 장 「%s」" % nx["n"] if nx != null else ""), "일지", Color("#7fd0ff"), true, 3400.0)
	if nx != null:
		after(900.0, func(): fx.title_card("ch", {"no": i + 2, "n": nx["n"], "d": nx["d"]}))

func ch_badges() -> int:
	var n := 0
	for i in FD.FCH.size():
		var C: Dictionary = FD.FCH[i]
		for t in C["t"]:
			if t_can(t, i): n += 1
		if ch_open(i) and not chc.has(C["id"]) and ch_done(C): n += 1
	return n


# ---------- 일일 훈련 (Star Rail): login + four tasks picked by the date; milestones 100 … 500; opens at Lv 3 ----------
static func d_today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%d-%d-%d" % [d["year"], d["month"], d["day"]]

## the prototype's picker, double arithmetic and all (s*1103515245 overflows 2^53 in JS the same way)
static func d_pick(td: String) -> Array:
	var s := 0
	for ch in td:
		s = (s * 31 + ch.unicode_at(0)) % 4294967296
	var P: Array = FD.DPOOL.map(func(t): return t["id"])
	var pick := []
	while pick.size() < 4 and P.size() > 0:
		s = int(fposmod(floorf(float(s) * 1103515245.0 + 12345.0), 4294967296.0))
		pick.append(P[s % P.size()])
		P.remove_at(s % P.size())
	return pick

func d_day() -> Dictionary:
	var td := d_today()
	if day == null or day.get("d", "") != td:
		var b := {}
		for t in FD.DPOOL: b[t["k"]] = fc(t["k"])
		day = {"d": td, "pick": d_pick(td), "b": b, "got": {}, "ms": {}, "pt": 0}
	return day

func d_tasks() -> Array:
	var D := d_day()
	var L := [FD.DLOGIN]
	for id in D["pick"]:
		for t in FD.DPOOL:
			if t["id"] == id: L.append(t)
	return L

func d_val(t: Dictionary) -> int:
	if t["k"] == "": return 1
	return maxi(0, fc(t["k"]) - int(day["b"].get(t["k"], 0)))

func d_can(t: Dictionary) -> bool:
	return alv >= FD.DAYLV and not day["got"].has(t["id"]) and d_val(t) >= t["g"]

func d_claim(id: String) -> void:
	d_day()
	for t in d_tasks():
		if t["id"] == id and d_can(t):
			day["got"][id] = 1
			day["pt"] = int(day["pt"]) + int(t["p"])

func d_ms_rw(i: int) -> Dictionary:
	var R: Dictionary = FD.DMS[i]["rw"].duplicate()
	if R.has("iron") and fac_ok("chand"): R["iron"] = roundi(R["iron"] * 1.2)
	return R

func d_ms(i: int) -> void:
	var D := d_day()
	if i < 0 or i >= FD.DMS.size() or D["ms"].has(str(i)) or int(D["pt"]) < FD.DMS[i]["p"] or alv < FD.DAYLV: return
	D["ms"][str(i)] = 1
	var R := d_ms_rw(i)
	pay_out(R, "훈련")
	a_gain(R.get("x", 0))
	if i == 4: log_add("일일 훈련 완수", "day")

func d_ready() -> int:
	if alv < FD.DAYLV: return 0
	var n := 0
	for t in d_tasks():
		if d_can(t): n += 1
	for i in FD.DMS.size():
		if not day["ms"].has(str(i)) and int(day["pt"]) >= FD.DMS[i]["p"]: n += 1
	return n


# ---------- facilities ----------
func fac_ok(id: String) -> bool:
	return fac.has(id)

func fac_lock(F: Dictionary) -> String:
	if F["r"] > r: return "%d등급" % F["r"]
	if F.get("need", "") == "bran" and not bran: return "브랜 합류"
	return ""

## fBonus: forge success +10 %p once the bellows turn
func f_bonus(k: String) -> int:
	return 10 if k == "enh" and fac_ok("forge") else 0

func fac_restore(id: String) -> bool:
	var F := FD.fac(id)
	if F.is_empty() or fac_ok(id): return false
	if fac_lock(F) != "":
		arena.sfx("guard", 0.4)
		return false
	if arena.shilling < F["cost"]:
		notice("실링이 모자라다 · %d 필요" % F["cost"], "시설", Color("#ffd34d"))
		arena.sfx("guard", 0.4)
		return false
	arena.shilling -= F["cost"]
	fac[id] = 1
	pts += F["f"]
	log_add(F["n"] + " 복구", "fac")
	arena.sfx("heavy", 0.7)
	notice("%s 복구 · 명성 +%d" % [F["n"], F["f"]], "시설", Color("#ffd34d"), true, 3400.0)
	poll(true)
	return true


# ---------- events from play ----------
## mobDie / bestSeen: every frame, monsters that came into view or fell
func _scan_mobs() -> void:
	if arena == null or arena.player == null: return
	var vr: Rect2 = arena.view_rect() if arena.cam != null else Rect2()
	for m in arena.mobs:
		if not is_instance_valid(m): continue
		if m.is_dead():
			if not m.has_meta("fame_k"):
				m.set_meta("fame_k", true)
				on_kill(m)
		elif not bseen.has(m.kind) and m.spawn_t <= 0.0 and vr.grow(-20.0).has_point(m.position + Vector2(0, -40)):
			bseen[m.kind] = 1
			best_step(m.kind)

func on_kill(m) -> void:
	var k: String = m.kind
	bseen[k] = 1
	bkill[k] = int(bkill.get(k, 0)) + 1
	var P = arena.player
	if not m.M.has("boss"):
		finc("kill")
		finc("k_" + k)
		finc("k_by_" + String(P.who))
	else:
		finc("boss")
		var first := fc("boss") == 1
		if first:
			a_gain(150)      # repeat-clear EXP comes from opening the chest with fatigue
			log_add("감독관 해골 첫 토벌", "boss")
		var alive := true
		for ch in P.party:
			if ch == P.who:
				if P.hp <= 0.0: alive = false
			elif float(P.hpm.get(ch, 1.0)) <= 0.0: alive = false
		if P.hp >= P.MAX_HP * 0.5: finc("bossSafe")
		if P.party.size() >= 2 and alive: finc("bossParty")
		if P.party.size() >= 3 and alive: finc("bossFull")
		var ex: Array[String] = []
		if fac_ok("store"):
			arena.shilling += 40
			pay_out({"rune": "rare"}, "창고")
			ex.append("창고 · 실링 40")
		if fac_ok("bath"):
			_add_mem(10)
			ex.append("목욕집 · 기억석 10")
		if ex.size():
			var s := " / ".join(ex)
			after(1200.0, func(): notice(s, "시설", Color("#ffd34d"), false, 3200.0))
	best_step(k)
	poll(true)

## the forge belongs to the guild: Bran keeps it shut until he has met the newcomer through Eilin
func bran_gate() -> bool:
	if not bran:
		arena.dlg.ask("bran", BRAN_POR, "브랜", "길드 대장장이", ["…길드 쪽 사람이오? 처음 보는 얼굴인데.", "접수대의 에일린한테 먼저 인사부터 하고 오쇼. 일 하나 끝내고 오면, 그때 얘기합시다. 흐흐."], [["알겠어요", null]])
		return false
	finc("bran")
	return true


# ---------- polling (famePoll): finished quests get a notice; review letters arrive; trial bases are set ----------
func poll(force := false) -> void:
	poll_t = 0.0
	if arena == null or arena.player == null: return
	d_day()
	var lk: String = arena.level_kind()
	if lk != scene:
		var P = arena.player
		if lk == "dungeon":
			finc("enter")
			if P.party.size() >= 2: finc("enterParty")
		if scene == "dungeon" and lk != "dungeon" and fac_ok("fire"):
			for ch in P.party:
				if ch != P.who: P.hpm[ch] = P.CH.STATS[ch]["hp"]
		scene = lk
	if not rec.has(arena.player.who): rec.append(arena.player.who)
	var tr := f_trial()
	if not tr.is_empty() and not got.has(tr["id"]) and not let.has(str(r)) and pts >= FD.FRANK[mini(6, r)]["need"]:
		let[str(r)] = 1
		if init:
			fx.title_card("letter", {})
			notice("길드 관리국에서 서신이 왔다 · 에일린에게", "서신", Color("#ff5a5a"), true, 3800.0)
			arena.sfx("ready", 0.5)
	for q in FD.FQ:
		if q["r"] != r or got.has(q["id"]): continue
		var st := f_state(q)
		if FD.FBASEK.has(q["id"]) and not base.has(q["id"]) and st != "wait" and st != "letter":
			base[q["id"]] = fc(FD.FBASEK[q["id"]])
		if f_state(q) == "done" and not done_seen.has(q["id"]):
			done_seen[q["id"]] = 1
			var trial: bool = q.get("t", "") == "trial"
			if init: notice(q["n"] + " 완료 · 에일린에게 보고", "심사" if trial else "의뢰", Color("#ff5a5a") if trial else Color("#ffd34d"), false, 3400.0)
	for i in FD.FCH.size():
		for t in FD.FCH[i]["t"]:
			if t_can(t, i) and not done_seen.has("t_" + t["id"]):
				done_seen["t_" + t["id"]] = 1
				if init: notice(t["n"] + " · 모험 수첩에서 받기", "일지", Color("#7fd0ff"), false, 3000.0)
	init = true


# ---------- the counter: review letters, reports, the seniors' introduction ----------
func _say(w: String, L: Array, C: Array) -> void:
	var who := {"eilin": [EIL_POR, "에일린", "길드 접수원"], "bran": [BRAN_POR, "브랜", "길드 대장장이"],
		"aida": [load("res://assets/fame/por_aida.png"), "아이다", "길드 선배 · 묘지기"], "luce": [load("res://assets/fame/por_luce.png"), "루체", "길드 선배 · 성녀 후보"]}
	var W: Array = who[w]
	arena.dlg.ask(w, W[0], W[1], W[2], L, C)

func _eil_bye() -> void:
	arena.eil.talk_t = 0.0

func _eil_stamp() -> void:
	if arena.eil.at_desk(): arena.eil.play("stamp", "stamp")

func open_book(book: String, tab := "") -> void:
	var M = arena.ui_root.menu if arena.ui_root != null else null
	if M == null: return
	if M.has_method("open_book"): M.open_book(book, tab)

## eilWork: the desk menu
func eil_work(lead: Array = []) -> void:
	arena.eil.talk_t = 999999.0
	var rd := ready_n()
	var lt := f_letter()
	var C := [
		["관리국 서신 받기" if lt else "의뢰 완료 보고" + (" (%d)" % rd if rd else ""), func(): report()],
		["길드 수첩 (의뢰 · 시설)", func():
			_eil_bye()
			open_book("gbk", "quest")],
		["모험 수첩", func():
			_eil_bye()
			open_book("abk", "home")],
		["그만 가볼게요", func():
			_eil_bye()
			arena.eil.greet_cd = 6000.0]]
	var hi: Array = arena.eil.EIL_WORK_HI
	var L: Array = lead if lead.size() else [("아, 마침 잘 오셨어요! 길드 관리국에서 서신이 와 있어요." if lt else ("의뢰를 끝내고 오셨네요! 확인해 드릴까요?" if rd else hi[randi() % hi.size()]))]
	_say("eilin", L, C)

## fameLetter: Eilin opens the bureau's letter; the trial goes up on the board
func letter() -> void:
	var t := f_trial()
	let[str(r)] = 2
	log_add("길드 관리국 등급 심사 의뢰 접수", "rank")
	poll(true)
	_eil_stamp()
	_say("eilin", ["아, 잠깐만요! 길드 관리국에서 서신이 왔어요.", "(붉은 봉랍이 찍힌 두꺼운 봉투. 에일린이 조심스럽게 뜯는다)", "「귀 길드의 등급 심사를 아래 과제로 진행함. 수행 후 보고 바람.」 …등급 심사예요!", "과제는 「%s」래요. 이건 길드원 여러분께 넘길게요. 게시판에도 붙여 둘게요!" % t["d"]],
		[["게시판 보기", func():
			_eil_bye()
			open_book("gbk", "quest")], ["맡겨 주세요", func(): _eil_bye()]])

## fameReport
func report() -> void:
	if f_letter():
		letter()
		return
	var L: Array = FD.FQ.filter(func(q): return q["r"] == r and f_state(q) == "done")
	if L.is_empty():
		var o := fame_obj()
		_say("eilin", ["지금 보고하실 의뢰는 없네요.", "(" + o + ")" if o != "" else "게시판에서 의뢰를 골라 보세요. 해 두시면 제가 확인해 둘게요."],
			[["게시판 보기", func():
				_eil_bye()
				open_book("gbk", "quest")], ["알겠어요", func(): _eil_bye()]])
		return
	var gain := 0
	var n := 0
	var lines := []
	var up := false
	for q in L:
		got[q["id"]] = 1
		gain += int(q["f"])
		if q.get("t", "") == "trial": up = true
		else:
			n += 1
			log_add("의뢰 「%s」 보고 · 명성 +%d" % [q["n"], q["f"]], "quest")
	if n: finc("report", n)
	pts += gain
	if n: lines.append("의뢰 %d건, 확인했어요. %s (누적 %d)" % [n, "명성 +%d!" % gain if gain else "", pts])
	var nx: Variant = fame_next()
	var first := not intro and n > 0
	if not up and nx != null and pts >= nx["need"] and not f_trial().is_empty(): lines.append("명성이 다 찼어요. 곧 길드 관리국에서 연락이 올 거예요.")
	if up: lines.append_array(["…그리고 등급 심사 결과 보고서. 관리국에 보냈더니, 방금 답장이 왔어요.", "승인 도장이 찍혀 있어요. 통과예요!"])
	if first: lines.append("아, 그리고… 첫 의뢰를 마치셨으니, 소개해 드릴 분들이 있어요.")
	_eil_stamp()
	arena.sfx("guard", 0.4)
	_say("eilin", lines, [["승급!" if up else ("누구요?" if first else "좋아요"), func():
		_eil_bye()
		if first: intro_seniors(up)
		elif up: rank_up()]])

## fameIntro (placeholder lines in the prototype): the guild's seniors meet the newcomer
func intro_seniors(up: bool) -> void:
	var s4 := func(): _say("eilin", ["아이다 씨와 루체 씨는 오늘부터 파티에 함께할 수 있어요. 분수대에서 편성해 보세요.", "대장간도 열렸으니까, 마을에 가면 브랜 씨한테 장비를 맡겨 보세요!"], [["네!", func():
		_eil_bye()
		join()
		if up: rank_up()]])
	var s3 := func(): _say("bran", ["브랜이오. 길드 대장간을 맡고 있지. 흐흐.", "장비든 룬이든 가져오쇼. 오늘부터 대장간 문은 열어 두겠소."], [["잘 부탁드려요", s4]])
	var s2 := func(): _say("luce", ["안녕하세요, 루체예요! 다치면 꼭 저한테 먼저 오세요.", "…아, 물론 안 다치는 게 제일 좋지만요!"], [["잘 부탁드려요", s3]])
	var s1 := func(): _say("aida", ["…신입이구나. 아이다. 길드 일 말고는 묘지기를 해.", "동굴의 해골 광부들, 원래는 이 마을 사람들이었어. 그건 알아 둬."], [["잘 부탁드려요", s2]])
	_say("eilin", ["우리 길드를 지금까지 지켜 온 선배님들이에요. 마침 다들 계시네요."], [["선배님들?", s1]])

## fameJoin
func join() -> void:
	intro = 1
	bran = 1
	for ch in ["aida", "luce"]:
		if not rec.has(ch): rec.append(ch)
	log_add("선배 아이다 · 루체 · 브랜과 인사", "people")
	log_add("대장간 개방", "fac")
	pts += 9
	notice("아이다 · 루체 합류 · 대장간 개방 · 명성 +9", "길드", Color("#57d3c2"), true, 3800.0)

## fameRankUp → rankCut
func rank_up() -> void:
	if r >= 7: return
	r += 1
	log_add("길드 등급 %d 「%s」 승인 · 길드 관리국" % [r, FD.FRANK[r - 1]["n"]], "rank")
	fx.rank_cut()

## after the rank cut: Eilin stamps and congratulates (hEilUpd), the guild book opens on the quests
func rank_cut_done() -> void:
	if arena.eil.has_method("on_rank_up"): arena.eil.on_rank_up()
	open_book("gbk", "quest")


# ---------- saving ----------
const KEYS := ["r", "pts", "got", "c", "base", "rec", "seen", "fac", "alv", "aexp", "tgot", "lvc", "chc", "let", "flog", "intro", "bran", "day", "bs", "bseen", "bkill", "mem_held", "runes_held"]

func get_state() -> Dictionary:
	var d := {}
	for k in KEYS:
		var v = get(k)
		d[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	return d

func set_state(d: Dictionary) -> void:
	for k in KEYS:
		if not d.has(k): continue
		var v = d[k]
		var cur = get(k)
		if cur is int: v = int(v)
		elif cur is Dictionary and not (v is Dictionary): continue
		elif cur is Array and not (v is Array): continue
		set(k, v.duplicate(true) if (v is Dictionary or v is Array) else v)
	init = false
	done_seen = {}
	scene = arena.level_kind() if arena != null else ""
	poll(true)


# ---------- test keys: F12 = +100 EXP and finish one running request; Shift+F12 = guild fame +30;
# Ctrl+F12 = the current chapter's title card; Alt+F12 = the rank cut for the current rank (preview) ----------
func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo or ev.keycode != KEY_F12: return
	if ev.alt_pressed:
		fx.rank_cut()          # preview of the current rank's approval (no state change)
		return
	if ev.ctrl_pressed:
		var i: int = maxi(0, ch_cur())
		fx.title_card("ch", {"no": i + 1, "n": FD.FCH[i]["n"], "d": FD.FCH[i]["d"]})
		return
	if ev.shift_pressed:
		pts += 30
		notice("시험 · 길드 명성 +30", "TEST", Color("#ffd34d"))
	else:
		a_gain(100)
		test_finish_one()
	poll(true)

func test_finish_one() -> void:
	for q in FD.FQ:
		if q["r"] == r and f_state(q) == "run":
			finc(q["k"], q["g"] - maxi(0, q_val(q)))
			return


# ---------- web test hook (headless browser checks): window.cvFame("eil" | "adv" | "pick N" | "exp N" | "fame N" | "boss" | "state") ----------
var _js_cb
func _js_setup() -> void:
	if not OS.has_feature("web"): return
	_js_cb = JavaScriptBridge.create_callback(_js)
	var w = JavaScriptBridge.get_interface("window")
	if w != null: w.cvFame = _js_cb

func _js(args: Array) -> void:
	var cmd := String(args[0]) if args.size() > 0 else ""
	var p := cmd.split(" ")
	match p[0]:
		"eil": eil_work()
		"adv":
			if arena.dlg.active and arena.dlg.i < arena.dlg.lines.size() - 1: arena.dlg.i += 1
		"pick":
			if arena.dlg.active and not arena.dlg.choices.is_empty():
				arena.dlg.i = arena.dlg.lines.size() - 1
				arena.dlg._pick(int(p[1]) if p.size() > 1 else 0)
		"exp": a_gain(int(p[1]) if p.size() > 1 else 100)
		"fame": pts += int(p[1]) if p.size() > 1 else 30
		"boss": finc("boss")
	poll(true)
	var w = JavaScriptBridge.get_interface("window")
	if w != null: w.cvFameState = JSON.stringify({"r": r, "pts": pts, "alv": alv, "aexp": aexp, "dlg": arena.dlg.active, "line": arena.dlg.i, "lines": arena.dlg.lines.size(), "choices": arena.dlg.choices.map(func(c): return c[0]), "let": let, "got": got.keys()})
