extends Node
## Runes, gear, shillings and the bestiary record (prototype RUNE / GRADE / GEAR / RUNEBAG / GEARBAG / IRON / MEM /
## RUNES IN COMBAT / dropLoot / dunPay / makeGear / gear v3 numbers / BEST). Lives on the arena as `arena.runes`.
##
## Save hook (for the save system):
##   get_state() -> Dictionary   everything this node owns, plain JSON-safe values:
##     {"v": 1, "shilling": int, "mem": int, "mats": {k: int}, "gear": {c: {slot: item | null}}, "runebag": {rune: n},
##      "gearbag": [item...], "seen_r": {rune: 1}, "best_seen": {kind: 1}, "best_kills": {kind: n}, "best_stage": {kind: n},
##      "boss_clears": int, "track": String}
##     item = {"n", "g", "lv", "wt"?, "slot"? (bag only), "cls"? (bag weapons), "r", "seed", "sub": [k, v] | null, "rune": String ("" = none), "rs": int}
##   set_state(d: Dictionary)    restores it (missing keys keep their defaults). Shillings live in arena.shilling.
## Nothing here writes to disk by itself.
##
## Combat hooks used by player.gd / mob.gd: atk_k(c), max_hp(c), out_mul(target), in_mul(), cd_k(), ev(name, target),
## after_hit(target), on_kill(target), tick(dt), has(rune), shield_throw(), clone_start(), clone_hits(atk), aura_start().
## For the ultimate (not ported here): ult_k() = gauge gain / cooldown multiplier from 고요한 기도.

const CH := preload("res://scripts/chars.gd")
const LOOT := preload("res://scripts/loot.gd")
const MEMORY := preload("res://scripts/memory.gd")
const DEV := preload("res://scripts/dev.gd")

const GRADE := {"common": ["일반", Color("#b9b2a3")], "uncommon": ["고급", Color("#7fc77a")], "rare": ["레어", Color("#6aa7ff")], "elite": ["엘리트", Color("#b48cff")],
	"epic": ["에픽", Color("#ff9d4d")], "legend": ["전설", Color("#ffd34d")], "unique": ["고유", Color("#ff6fae")]}
const GORD := ["unique", "legend", "epic", "elite", "rare", "uncommon", "common"]
const SLOTS := [["weapon", "무기"], ["head", "머리"], ["body", "몸통"], ["shoe", "신발"], ["acc1", "장신구 1"], ["acc2", "장신구 2"], ["acc3", "장신구 3"]]
const SLOTN := {"weapon": "무기", "head": "머리", "body": "몸통", "shoe": "신발", "acc1": "장신구 1", "acc2": "장신구 2", "acc3": "장신구 3", "acc": "장신구"}
const CLS := {"estelle": "전사", "aida": "워락", "luce": "사제"}
const ROSTER := ["estelle", "aida", "luce"]
## rune kinds: w = weapon (cls or 공용), a = armor, x = accessory (unique ones are character-locked)
const RUNE := {
	"firmstep": {"n": "굳건한 걸음", "g": "rare", "k": "w", "cls": "전사", "d": "가드로 막을 때마다 공격력 +3% (최대 4중첩, 6초)"},
	"oath": {"n": "잊히지 않는 맹세", "g": "legend", "k": "w", "cls": "전사", "d": "패링 성공 시 5초간 주는 피해 +25%. 대신 가드 피해 감소 −15%."},
	"temper": {"n": "무수한 담금질", "g": "epic", "k": "w", "d": "이 룬이 ★5 이상이면 공격력 +12%, ★7 이상이면 추가 +8%."},
	"thorn": {"n": "가시 덩굴", "g": "epic", "k": "w", "d": "주는 피해 +20%. 대신 받는 피해 +20%."},
	"fang": {"n": "그림자 이빨", "g": "elite", "k": "w", "cls": "워락", "d": "어둠 피해를 받은 적에게 6초간 주는 피해 +12%."},
	"lamp": {"n": "순례자의 등불", "g": "rare", "k": "w", "cls": "사제", "d": "회복할 때마다 6초간 신성 피해 +8% (3중첩)."},
	"giant": {"n": "바위 거인", "g": "elite", "k": "a", "d": "모으기 공격 적중 시 공격력 +3% 중첩. 3중첩이 되면 소모해 5초간 공격력 +20%."},
	"wall": {"n": "철벽", "g": "rare", "k": "a", "d": "체력 50% 이하일 때 받는 피해 −10%."},
	"stone": {"n": "돌 피부", "g": "uncommon", "k": "a", "d": "받는 피해 −5%."},
	"breeze": {"n": "바람 걸음", "g": "rare", "k": "a", "d": "대시 후 2초간 이동 속도 +15%."},
	"backshadow": {"n": "등 뒤의 그림자", "g": "epic", "k": "a", "d": "뒷치기 피해 +20%."},
	"surge": {"n": "마나 격류", "g": "elite", "k": "a", "d": "스킬을 쓸 때마다 5초간 공격력 +3.5% (최대 4중첩)."},
	"prayer": {"n": "고요한 기도", "g": "rare", "k": "a", "d": "궁극기 게이지 획득 +10%, 쿨타임 회복 +10%."},
	"wise": {"n": "지혜로움", "g": "epic", "k": "x", "d": "모든 스킬 재사용 대기시간 −12%."},
	"firstaid": {"n": "응급 처치", "g": "uncommon", "k": "x", "d": "적을 처치하면 체력 +2."},
	"ember": {"n": "불씨", "g": "rare", "k": "x", "d": "일반 공격 적중 시 10% 확률로 화염 피해 추가."},
	"tagbell": {"n": "교대의 종", "g": "elite", "k": "x", "d": "QTE 교대 시 들어오는 동료의 공격력 5초간 +15%."},
	"shieldthrow": {"n": "방패 던지기", "g": "unique", "k": "x", "who": "estelle", "d": "스킬 [방패]가 [방패 던지기]로 바뀐다. 던진 방패는 적을 꿰뚫고 되돌아온다."},
	"clone": {"n": "그림자 분신", "g": "unique", "k": "x", "who": "aida", "d": "스킬 [균열]이 [그림자 분신]으로 바뀐다. 분신이 3초간 일반 공격를 따라 한다."},
	"aura": {"n": "축복 오라", "g": "unique", "k": "x", "who": "luce", "d": "스킬 [힐]이 [축복 오라]로 바뀐다. 8초간 주변 동료가 초당 체력 2 회복."},
}
const RUNE_TAG := {"firmstep": "굳건", "surge": "격류", "lamp": "등불", "oath": "맹세", "giantB": "거인", "tagbell": "종", "breeze": "바람", "aura": "오라", "n_gp": "자동 패링", "n_ls": "성소"}
## rune stars ★1–★8: the effect scales by RSM (★4 = the written value)
const RSM := [1.0, 0.7, 0.8, 0.9, 1.0, 1.1, 1.25, 1.4, 1.6]
const RMAX := 8
const RS_COST := [0, 30, 60, 100, 160, 240, 340, 480]
const RS_RATE := [0, 100, 90, 75, 60, 45, 30, 20]
## fuse: three of a grade → one a grade up; odds by the grade aimed for
const FZG := ["common", "uncommon", "rare", "elite", "epic"]
const FZRATE := {"uncommon": 90, "rare": 70, "elite": 50, "epic": 40, "legend": 10}
const FUSE_COST := 15
const DROP_GEAR := {"weapon": {"전사": ["기사단 롱소드", "브로드소드", "방패병의 한손검"], "워락": ["그을린 삽", "계약의 낫", "흑요석 삽"], "사제": ["순례자의 묵주", "은 성표", "축복받은 홀"]},
	"head": ["케틀햇", "가죽 두건", "사제 베일"], "body": ["사슬 갑옷", "가죽 조끼", "수도복"], "shoe": ["판금 각반", "사냥꾼 장화", "헝겊 신"], "acc": ["구리 반지", "유리 펜던트", "낡은 브로치", "은 귀걸이"]}
## gear v3 numbers
const GMUL := {"common": 1.0, "uncommon": 1.15, "rare": 1.3, "elite": 1.45, "epic": 1.65, "legend": 1.9, "unique": 2.1}
const SUBN := {"atk": ["공격력", "%"], "crit": ["치명", "%"], "hp": ["체력", ""], "ms": ["이속", "%"], "heal": ["회복량", "%"], "ult": ["기력 획득", "%"]}
const GMAIN := {"weapon": 3.7, "천옷": 1.6, "경갑": 3.2, "중갑": 5.3}
const GSUBMAX := {"atk": 5.8, "crit": 3.9, "hp": 7.0, "ms": 2.4, "heal": 5.8, "ult": 6.5}
const NSUB := {"common": 1, "uncommon": 1, "rare": 2, "elite": 2, "epic": 3, "legend": 3, "unique": 4}
## base move speed per member (prototype STATS.ms): RUN = 0.36 × this × gear × 바람 걸음 (runeTick / switchChar)
const BASE_MS := {"estelle": 0.95, "aida": 1.1, "luce": 1.0}
## the dungeon caps what can drop (DUNGEONS[0] = 버섯 동굴)
const DUN := {"id": "cave", "name": "버섯 동굴", "cap": "rare", "chest_cap": 2, "bonus": "elite", "mul": 1.0, "glv": [1, 6], "rank": 1}
const REWARD := {"rune": ["룬", Color("#c58cff")], "iron": ["실링", Color("#ffd34d")], "gear": ["장비", Color("#ffd34d")], "heal": ["회복", Color("#9fe3a0")]}
## breakthrough materials (boss / boss chest / treasure room)
const MATN := {"lamp": ["광부의 등잔", Color("#ffb04a"), "버섯 동굴 · 감독관 해골"]}
const SHC := Color("#ffd34d")
const MEMC := Color("#8ff0e0")

# ---------- bestiary data (ENEMY / BEST_INFO / OBSNOTE, MOBDEF descriptions) ----------
const ELN := {"phys": "물리", "fire": "화염", "ice": "냉기", "elec": "전기", "earth": "대지", "water": "수류", "wind": "바람", "holy": "신성", "dark": "어둠", "plant": "초목"}
const EFF := {"fire": {"ice": 1.5, "plant": 1.5, "fire": 0.5, "water": 0.5, "earth": 0.5}, "ice": {"plant": 1.5, "wind": 1.5, "earth": 1.5, "fire": 0.5, "ice": 0.5, "water": 0.5},
	"elec": {"water": 1.5, "wind": 1.5, "earth": 0.5, "elec": 0.5, "plant": 0.5}, "earth": {"fire": 1.5, "elec": 1.5, "wind": 0.5, "plant": 0.5},
	"water": {"fire": 1.5, "earth": 1.5, "water": 0.5, "plant": 0.5}, "wind": {"plant": 1.5, "elec": 0.5, "earth": 0.5},
	"plant": {"water": 1.5, "earth": 1.5, "fire": 0.5, "plant": 0.5, "wind": 0.5}, "dark": {"holy": 1.5, "dark": 0.5}, "phys": {}, "holy": {}}
const ATKEL := {"estelle": ["phys"], "aida": ["dark", "phys"], "luce": ["holy"]}
const ENEMY := {
	"dummy": {"name": "허수아비", "hp": 60, "atk": 0, "ms": 0.0, "atkEl": "phys", "defEl": ["phys"], "where": "훈련장", "desc": "훈련장에 줄지어 선 짚 허수아비. 맞아도 화내지 않고, 부서지면 잠시 뒤 누군가 다시 세워 둔다. 기술 연습용."},
	"ghost": {"name": "유령", "hp": 30, "atk": 10, "ms": 0.09, "atkEl": "dark", "defEl": ["dark"], "where": "훈련장", "desc": "훈련장 구석을 떠도는 작은 유령. 가까이 오면 몸으로 부딪혀 온다. 어둠 그 자체라 신성한 빛에 크게 다친다."},
	"goblin": {"name": "고블린", "hp": 50, "atk": 8, "ms": 0.15, "atkEl": "phys", "defEl": ["phys"], "where": "버섯 동굴", "mob": true, "desc": "동굴 입구를 차지한 고블린. 겁이 많지만 무리를 지으면 대담해진다. 단검을 크게 휘두른다."},
	"mush": {"name": "독버섯", "hp": 60, "atk": 7, "ms": 0.07, "atkEl": "plant", "defEl": ["plant"], "where": "버섯 동굴", "mob": true, "desc": "축축한 동굴 바닥에서 걸어 다니는 버섯. 가까이 붙으면 갓을 부풀려 포자를 터뜨린다. 초목이라 불에 약하다."},
	"skel": {"name": "해골 광부", "hp": 80, "atk": 12, "ms": 0.08, "atkEl": "phys", "defEl": ["dark", "phys"], "where": "버섯 동굴", "mob": true, "desc": "폐광에서 일하다 쓰러진 광부의 유해. 아직도 녹슨 방패를 들고 앞을 막는다. 리빙 데드라 신성한 빛에 크게 다친다."},
	"eye": {"name": "동굴 눈알", "hp": 35, "atk": 6, "ms": 0.11, "atkEl": "dark", "defEl": ["dark"], "where": "버섯 동굴", "mob": true, "desc": "천장에 매달려 있다가 날아오르는 눈알 박쥐. 멀리서 어둠 덩어리를 뱉는다. 높이 떠 있어 상단 공격이 잘 맞는다."},
	"boss": {"name": "감독관 해골", "hp": 620, "atk": 18, "ms": 0.07, "atkEl": "dark", "defEl": ["dark", "earth"], "where": "버섯 동굴", "mob": true, "boss": true, "desc": "버섯 동굴 가장 깊은 곳, 무너진 갱도를 지키는 커다란 해골. 광부들을 부리던 감독관이었다고 한다. 검을 휘둘러 검기를 날린다."},
}
const OBSNOTE := {"dummy": "허수아비를 다시 세우는 사람을 본 길드원은 없다. 아침이면 늘 서 있다.", "ghost": "유령은 언제나 훈련장 동쪽 구석, 메워진 우물 쪽으로만 사라진다.",
	"goblin": "갱도 입구의 무리는 늘 동쪽 산맥 쪽에서 내려온다. 무언가에 쫓겨 오는 것처럼.", "mush": "광산 조합 장부에 따르면, 폐광 전에는 이 동굴에 버섯이 한 포기도 없었다.",
	"skel": "곡괭이 자루마다 이름이 새겨져 있다. 마을 묘지 명부와 맞춰 보는 중. — 아이다", "eye": "쓰러뜨려도 눈꺼풀을 닫지 않는다. 마지막까지 무언가를 지켜보는 듯하다.",
	"boss": "허리춤 열쇠꾸러미 중 하나는 동굴의 어느 문에도 맞지 않는다."}
## observation stage EXP (Ⅰ met · Ⅱ first kill · Ⅲ 10 kills · Ⅳ 30 kills; bosses 1 / 3 / 10)
const BSTEP := [0, 20, 30, 40, 60]
const BSTEPB := [0, 30, 100, 60, 100]

var arena
var rng := RandomNumberGenerator.new()
var gear := {}
var runebag := {}
var gearbag: Array = []
var mem := 0
var mats := {"lamp": 0}
var seen_r := {}
var best_seen := {}
var best_kills := {}
var best_stage := {}
var boss_clears := 0
var track := ""
# combat state
var rb := {}                 # timed buffs: key -> {t, n}
var shields: Array = []      # thrown shields
var shield_cd := 0.0
var clone := {"t": 0.0, "x": 0.0, "y": 0.0, "dir": 1}
var aura_acc := 0.0
var seen_t := 0.0
var loot                     # the boss chest of this run (loot.gd), or null
var _tot := {}               # gear totals cache per member
var fx_node: Node2D
var hud_node: Control
var memory                   # memory.gd: character levels and the memory tree (its combat hooks are called from here)


func _init() -> void:
	rng.randomize()
	memory = MEMORY.new()
	add_child(memory)
	reset()

func reset() -> void:
	gear = _default_gear()
	runebag = {"oath": 1, "temper": 1, "thorn": 1, "giant": 1, "wall": 2, "surge": 1, "backshadow": 1, "wise": 1, "ember": 2, "tagbell": 1, "shieldthrow": 1, "clone": 1, "aura": 1, "stone": 1, "firstaid": 1, "breeze": 1}
	gearbag = []
	iron = 12            # IRON = 12
	mem = 0
	mats = {"lamp": 0}
	seen_r = {}
	for r in runebag: seen_r[r] = 1
	for c in gear:
		for s in gear[c]:
			var it = gear[c][s]
			if it != null and it["rune"] != "": seen_r[it["rune"]] = 1
	best_seen = {}
	best_kills = {}
	best_stage = {}
	boss_clears = 0
	track = ""
	rb = {}
	changed()

## the prototype's starting gear (old items' numbers read back out of their text, as gearNorm does)
static func _default_gear() -> Dictionary:
	var I := func(n: String, g: String, lv: int, wt: String, sub, rune: String, seed: int) -> Dictionary:
		var d := {"n": n, "g": g, "lv": lv, "r": 1, "seed": seed, "sub": sub, "rune": rune, "rs": 1}
		if wt != "": d["wt"] = wt
		return d
	return {
		"estelle": {"weapon": I.call("낡은 롱소드", "rare", 7, "", ["crit", 3], "firmstep", 1101), "head": I.call("찌그러진 케틀햇", "uncommon", 3, "중갑", null, "stone", 1102),
			"body": I.call("흰 튜닉과 흉갑", "rare", 5, "중갑", null, "", 1103), "shoe": I.call("판금 각반", "common", 2, "중갑", null, "", 1104),
			"acc1": I.call("십자가 목걸이", "elite", 4, "", ["hp", 6], "firstaid", 1105), "acc2": I.call("검은 리본", "uncommon", 1, "", ["ult", 5], "", 1106), "acc3": null},
		"aida": {"weapon": I.call("손때 묻은 삽", "elite", 6, "", ["atk", 3], "fang", 2101), "head": null, "body": I.call("묘지기 앞치마 원피스", "uncommon", 3, "천옷", null, "", 2103),
			"shoe": I.call("흙 묻은 장화", "rare", 4, "경갑", ["ms", 3], "breeze", 2104), "acc1": I.call("보라 꽃 머리핀", "rare", 3, "", ["crit", 2], "", 2105), "acc2": null, "acc3": null},
		"luce": {"weapon": I.call("수습 사제의 묵주", "rare", 5, "", ["heal", 5], "lamp", 3101), "head": null, "body": I.call("수습 사제 로브", "rare", 4, "천옷", null, "prayer", 3103),
			"shoe": I.call("헝겊 신", "common", 1, "천옷", null, "", 3104), "acc1": I.call("성표 귀걸이", "uncommon", 2, "", ["ult", 5], "", 3105), "acc2": null, "acc3": null},
	}


func setup(a) -> void:
	arena = a
	name = "Runes"
	fx_node = Node2D.new()
	fx_node.z_index = 9
	fx_node.draw.connect(_draw_fx)
	arena.add_child(fx_node)
	var layer := CanvasLayer.new()
	layer.layer = 1
	arena.add_child(layer)
	hud_node = Control.new()
	hud_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_node.draw.connect(_draw_hud)
	layer.add_child(hud_node)
	memory.setup(self)
	changed()


# ---------- shillings ----------
var iron: int:
	get: return int(arena.shilling) if arena != null else _iron
	set(v):
		if arena != null: arena.shilling = v
		else: _iron = v
var _iron := 0


# ---------- small helpers ----------
static func gname(g: String) -> String:
	return GRADE[g][0]

static func gcol(g: String) -> Color:
	return GRADE[g][1]

static func slot_kind(s: String) -> String:
	return "acc" if s.begins_with("acc") else s

static func pname(c: String) -> String:
	return CH.NAME.get(c, c)

var force_roll := -1.0        # tests / captures: every roll returns this (0..1) while >= 0

func rand() -> float:
	if force_roll >= 0.0: return force_roll
	return rng.randf()

func pick(a: Array):
	return a[rng.randi() % a.size()]

func changed() -> void:
	_tot.clear()
	if arena != null and arena.player != null:
		var P = arena.player
		var m: float = max_hp(P.who)
		P.MAX_HP = m
		if P.hp > m: P.hp = m

func has_rune_item(it) -> bool:
	return it != null and String(it.get("rune", "")) != "" and RUNE.has(it["rune"])


# ---------- gear numbers (gear v3) ----------
## mulberry32, as the prototype's srng (32-bit maths kept in range)
static func _imul(a: int, b: int) -> int:
	a &= 0xFFFFFFFF
	b &= 0xFFFFFFFF
	return ((a * (b & 0xFFFF)) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF

class SRng:
	var a := 1
	func _init(seed: int) -> void:
		a = seed & 0xFFFFFFFF
		if a == 0: a = 1
	func next() -> float:
		a = (a + 0x6D2B79F5) & 0xFFFFFFFF
		var t: int = _imul_s(a ^ (a >> 15), 1 | a)
		t = ((t + _imul_s(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0
	static func _imul_s(x: int, y: int) -> int:
		x &= 0xFFFFFFFF
		y &= 0xFFFFFFFF
		return ((x * (y & 0xFFFF)) + (((x * (y >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF

static func round1(v: float) -> float:
	return roundf(v * 10.0) / 10.0

static func grar(g: String) -> float:
	return GMUL.get(g, 1.0) / 1.9

## sub stats: grade sets how many it starts with; one event every 4 levels (new sub under 4, else a roll-up)
static func subs_of(it: Dictionary, kind: String) -> Array:
	if not it.has("seed") or it["seed"] == null: it["seed"] = randi() % 2147483647
	var R := SRng.new(int(it["seed"]))
	var pool: Array = ["crit", "ult", "heal", "hp"] if kind == "weapon" else (["atk", "crit", "hp", "ms", "ult", "heal"] if kind == "acc" else ["hp", "crit", "ms", "atk", "ult"])
	var g: String = it["g"]
	var roll := func(k: String) -> float: return GSUBMAX[k] * grar(g) * [0.7, 0.8, 0.9, 1.0][int(R.next() * 4.0)]
	var subs: Array = []
	var sb = it.get("sub")
	if sb is Array and sb.size() == 2 and GSUBMAX.has(sb[0]) and pool.has(sb[0]):
		subs.append([sb[0], roll.call(sb[0])])
	var add := func() -> void:
		var left: Array = pool.filter(func(k): return not subs.any(func(x): return x[0] == k))
		if left.is_empty(): return
		var k: String = left[int(R.next() * left.size())]
		subs.append([k, roll.call(k)])
	while subs.size() < NSUB.get(g, 1):
		add.call()
	var k4 := 4
	while k4 <= int(it.get("lv", 0)):
		if subs.size() < 4: add.call()
		else:
			var x: Array = subs[int(R.next() * subs.size())]
			x[1] = x[1] + roll.call(x[0])
		k4 += 4
	for x in subs:
		x[1] = roundf(x[1]) if x[0] == "hp" else round1(x[1])
	return subs

static func main_grow(lv: int) -> float:
	return 1.0 + 0.28 * lv

## main stat: weapons attack %, armour defence, accessories none
static func gear_main(it: Dictionary, kind: String) -> Variant:
	var g: float = GMUL.get(it["g"], 1.0)
	var lv := int(it.get("lv", 0))
	var r := 1.0 + 0.04 * int(it.get("r", 0))
	if kind == "weapon": return ["atk", round1(GMAIN["weapon"] * g * r * main_grow(lv))]
	if kind == "acc": return null
	return ["def", roundf(GMAIN.get(String(it.get("wt", "")), 3.2) * g * r * main_grow(lv))]

static func fmt(v: float) -> String:
	return str(int(v)) if v == roundf(v) else str(v)

static func gear_text(it: Dictionary, kind: String) -> String:
	var out: Array = []
	var m = gear_main(it, kind)
	if m != null: out.append(("공격력 +%s%%" % fmt(m[1])) if m[0] == "atk" else ("방어 %s" % fmt(m[1])))
	for x in subs_of(it, kind):
		out.append(SUBN[x[0]][0] + " +" + fmt(x[1]) + SUBN[x[0]][1])
	if it.get("wt", "") == "중갑": out.append("이속 −2%")
	return " · ".join(out)

func gear_tot(c: String) -> Dictionary:
	if _tot.has(c): return _tot[c]
	var T := {"atk": 0.0, "def": 0.0, "hp": 0.0, "crit": 0.0, "ms": 0.0, "heal": 0.0, "ult": 0.0, "heavy": 0}
	var G: Dictionary = gear.get(c, {})
	for s in G:
		var it = G[s]
		if it == null: continue
		var k := slot_kind(s)
		var m = gear_main(it, k)
		if m != null: T[m[0]] += m[1]
		for x in subs_of(it, k): T[x[0]] += x[1]
		if it.get("wt", "") == "중갑": T["heavy"] += 1
	for k in T:
		if k != "heavy": T[k] = round1(T[k])
	if memory != null:
		var M: Dictionary = memory.stat_add(c)          # stat nodes (최대 체력, 회복량) count like gear
		for k in M: T[k] = round1(T.get(k, 0.0) + M[k])
	_tot[c] = T
	return T

## level multiplier (LVM): LVCURVE by the member's level (memory.gd)
func lvm(c: String) -> float:
	return memory.lvm(c) if memory != null else 1.0

## the member's numbers with gear on (gearApply)
func stats(c: String) -> Dictionary:
	var T := gear_tot(c)
	var B: Dictionary = CH.STATS[c]
	var hp: float = roundf(B["hp"] * lvm(c)) + T["hp"]
	return {"hp": hp, "base_hp": B["hp"], "atk": B["atk"] * lvm(c) * (1.0 + T["atk"] / 100.0), "base_atk": B["atk"], "def": T["def"], "crit": T["crit"],
		"ms": BASE_MS[c] * (1.0 + T["ms"] / 100.0 - 0.02 * T["heavy"]), "base_ms": BASE_MS[c], "as": B.get("as", 1.0), "heal": T["heal"], "ult": T["ult"]}

func max_hp(c: String) -> float:
	return stats(c)["hp"]

func atk_k(c: String) -> float:
	return (1.0 + gear_tot(c)["atk"] / 100.0) * lvm(c)

static func melt_val(it: Dictionary) -> int:
	return roundi(6.0 * GMUL.get(it["g"], 1.0)) + int(it.get("lv", 0)) * 3

static func engrave_cost(g: String) -> int:
	return (GORD.size() - GORD.find(g)) * 8

static func rs_cost(st: int) -> int:
	return RS_COST[st] if st < RS_COST.size() else 999

static func rs_rate(st: int) -> int:
	return RS_RATE[st] if st < RS_RATE.size() else 0

static func up_grade(g: String) -> String:
	var i := GORD.find(g)
	return GORD[i - 1] if i > 0 else g

## rune text at a star: the numbers before "대신" scale by RSM
static func rune_scaled(r: String, st: int) -> String:
	if not RUNE.has(r): return ""
	var R: Dictionary = RUNE[r]
	var m: float = RSM[clampi(st, 1, RMAX)]
	var d: String = R["d"]
	if R["g"] == "unique" or absf(m - 1.0) < 0.000001: return d
	var i := d.find("대신")
	var a := d if i < 0 else d.substr(0, i)
	var b := "" if i < 0 else d.substr(i)
	var re := RegEx.new()
	re.compile("([+−])(\\d+(?:\\.\\d+)?)")
	var out := ""
	var last := 0
	for mt in re.search_all(a):
		out += a.substr(last, mt.get_start() - last) + mt.get_string(1) + fmt(roundf(float(mt.get_string(2)) * m * 10.0) / 10.0)
		last = mt.get_end()
	return out + a.substr(last) + b

## which slot a rune fits
static func fits(r: String, c: String, slot: String, it) -> bool:
	if not RUNE.has(r) or it == null: return false
	var R: Dictionary = RUNE[r]
	if slot == "weapon": return R["k"] == "w" and (not R.has("cls") or R["cls"] == CLS[c])
	if slot.begins_with("acc"): return R["k"] == "x" and (not R.has("who") or R["who"] == c)
	return R["k"] == "a"

static func gear_fits(it, c: String, s: String) -> bool:
	if it == null: return false
	var k := slot_kind(s)
	if String(it.get("slot", "")) != k: return false
	return k != "weapon" or it.get("cls", "") == CLS[c]

static func slots_for(it: Dictionary) -> Array:
	return ["acc1", "acc2", "acc3"] if it.get("slot", "") == "acc" else [it.get("slot", "")]


# ---------- moving gear ----------
func gear_off(c: String, s: String) -> void:
	var it = gear[c][s]
	if it == null: return
	it["slot"] = slot_kind(s)
	if it["slot"] == "weapon": it["cls"] = CLS[c]
	gearbag.append(it)
	gear[c][s] = null
	changed()

func gear_on(c: String, s: String, bi: int) -> bool:
	if bi < 0 or bi >= gearbag.size(): return false
	var it: Dictionary = gearbag[bi]
	if not gear_fits(it, c, s): return false
	gearbag.remove_at(bi)
	gear_off(c, s)
	var o := it.duplicate(true)
	o.erase("slot")
	o.erase("cls")
	gear[c][s] = o
	changed()
	return true

## melt one bag piece: its rune goes back to the bag
func melt(bi: int) -> int:
	if bi < 0 or bi >= gearbag.size(): return 0
	var it: Dictionary = gearbag[bi]
	if has_rune_item(it): add_rune(it["rune"])
	var v := melt_val(it)
	iron += v
	gearbag.remove_at(bi)
	changed()
	return v

## stat difference if `it` went into c's slot s: [[name, delta, unit]...]
func gear_cmp(it: Dictionary, c: String, s: String) -> Array:
	var a := gear_tot(c).duplicate()
	var save = gear[c][s]
	gear[c][s] = it.duplicate(true)
	_tot.erase(c)
	var b := gear_tot(c).duplicate()
	gear[c][s] = save
	_tot.erase(c)
	var out: Array = []
	for row in [["atk", "공격력", "%"], ["def", "방어", ""], ["hp", "체력", ""], ["crit", "치명", "%"], ["ms", "이속", "%"], ["heal", "회복량", "%"], ["ult", "기력 획득", "%"]]:
		var d: float = b[row[0]] - a[row[0]]
		if row[0] == "ms": d -= 2.0 * (b["heavy"] - a["heavy"])
		d = round1(d)
		if d != 0.0: out.append([row[1], d, row[2]])
	return out


# ---------- runes in the bag ----------
func add_rune(r: String, n := 1) -> void:
	runebag[r] = int(runebag.get(r, 0)) + n
	if not seen_r.has(r):
		seen_r[r] = 1
	if track == r and arena != null:
		arena.text(arena.player.position + Vector2(0, -190), "추적한 룬 손에 넣음 · " + RUNE[r]["n"], GRADE[RUNE[r]["g"]][1])

func rune_count() -> int:
	var n := 0
	for r in runebag: n += maxi(0, int(runebag[r]))
	return n


# ---------- grades & drops ----------
func cap_grade(g: String) -> String:
	if arena == null or arena.level_kind() != "dungeon": return g
	return DUN["cap"] if GORD.find(g) < GORD.find(DUN["cap"]) else g

func roll_grade0(luck: float) -> String:
	var r := rand() * (1.0 - luck * 0.4)
	return "legend" if r < 0.02 else ("epic" if r < 0.07 else ("elite" if r < 0.17 else ("rare" if r < 0.37 else ("uncommon" if r < 0.65 else "common"))))

func roll_grade(luck: float) -> String:
	return cap_grade(roll_grade0(luck))

func dmul(v: float) -> int:
	return maxi(1, roundi(v * DUN["mul"]))

func gear_lv() -> int:
	return DUN["glv"][0] + rng.randi() % (DUN["glv"][1] - DUN["glv"][0] + 1)

## a new drop: base roll plus one sub stat (weapons/armour only sometimes)
func make_gear(g: String) -> Dictionary:
	var slot: String = pick(["weapon", "head", "body", "shoe", "acc"])
	var gm: float = GMUL.get(g, 1.0)
	var ilv := gear_lv()
	var sub := func(k: String) -> Array:
		var b: float = {"atk": 3.0, "crit": 3.0, "hp": 6.0, "ms": 3.0, "heal": 6.0, "ult": 6.0}[k]
		return [k, maxi(1, roundi((b + rand() * b * 0.6) * gm))]
	var it: Dictionary
	if slot == "weapon":
		var cl: String = pick(CLS.values())
		it = {"slot": slot, "cls": cl, "n": pick(DROP_GEAR["weapon"][cl]), "g": g, "lv": ilv, "sub": (sub.call(pick(["heal", "ult", "crit"]) if cl == "사제" else pick(["crit", "ult"]))) if rand() < 0.6 else null}
	elif slot == "acc":
		it = {"slot": slot, "n": pick(DROP_GEAR["acc"]), "g": g, "lv": ilv, "sub": sub.call(pick(["hp", "crit", "ms", "ult", "atk"]))}
	else:
		var wi := rng.randi() % 3
		it = {"slot": slot, "n": DROP_GEAR[slot][wi], "g": g, "wt": ["중갑", "경갑", "천옷"][wi], "lv": ilv, "sub": sub.call(pick(["hp", "ms"])) if rand() < 0.35 else null}
	it["r"] = rng.randi() % 3
	it["seed"] = rng.randi() % 2147483647
	it["rune"] = ""
	it["rs"] = 1
	return it

func rand_rune(g: String) -> String:
	var pool: Array = RUNE.keys().filter(func(r): return RUNE[r]["g"] == g and g != "unique")
	return pick(pool) if not pool.is_empty() else "ember"

## a kill: shilling always, sometimes 기억석 (random runes / gear from mobs are off in the prototype: they come from the chest)
func drop_loot(p: Vector2, big: bool) -> void:
	var got := dmul(1.0 + (2.0 if big else 0.0) + (1.0 if rand() < 0.5 else 0.0))
	iron += got
	arena.text(p + Vector2(0, -120), "실링 +%d" % got, SHC)
	var m0 := (1 + (1 if rand() < 0.5 else 0)) if big else (1 if rand() < 0.25 else 0)
	if m0 > 0:
		var m := maxi(1, roundi(dmul(m0) * mem_decay()))
		mem += m
		arena.text(p + Vector2(0, -150), "기억석 +%d" % m, MEMC)

## a cleared room's reward (dunPay)
func pay(rw: String) -> void:
	var P = arena.player
	var p: Vector2 = P.position
	arena.text(p + Vector2(0, -190), "보상 · " + REWARD[rw][0], REWARD[rw][1])
	arena.ring(p + Vector2(0, -60), 40.0, Color("#ffd34d"))
	if rw == "heal":
		for c in P.roster():
			P.hpm[c] = minf(max_hp(c), P.hpm[c] + max_hp(c) * 0.35)
		P.hp = minf(P.MAX_HP, P.hp + P.MAX_HP * 0.35)
	elif rw == "iron":
		var v := dmul(6.0)
		iron += v
		arena.text(p + Vector2(0, -160), "실링 +%d" % v, SHC)
	elif rw == "rune":
		var r := rand_rune(roll_grade(1.0))
		add_rune(r)
		arena.text(p + Vector2(0, -160), "룬 · " + RUNE[r]["n"], GRADE[RUNE[r]["g"]][1])
	elif rw == "gear":
		var it := make_gear(roll_grade(0.5))
		gearbag.append(it)
		arena.text(p + Vector2(0, -160), "장비 · " + it["n"], GRADE[it["g"]][1])

## memDecay: 기억석 from the dungeon thins out when the party is over its recommended top level
func mem_decay() -> float:
	return memory.mem_decay(6) if memory != null else 1.0

## the chapter tasks' counts: the highest rune star anywhere, runes engraved on worn gear
func max_star() -> int:
	var m := 0
	for c in gear:
		for s in gear[c]:
			if has_rune_item(gear[c][s]): m = maxi(m, int(gear[c][s].get("rs", 1)))
	for it in gearbag:
		if has_rune_item(it): m = maxi(m, int(it.get("rs", 1)))
	return m

func engraved() -> int:
	var n := 0
	for c in gear:
		for s in gear[c]:
			if has_rune_item(gear[c][s]): n += 1
	return n

func mat_get(k: String, n: int) -> void:
	mats[k] = int(mats.get(k, 0)) + n
	if arena != null:
		arena.text(arena.player.position + Vector2(0, -210), "%s +%d  (%d개)" % [MATN[k][0], n, mats[k]], MATN[k][1])

## the treasure room: shilling 12~19, sometimes a lamp
func vault(p: Vector2) -> void:
	var g := dmul(12.0 + rng.randi() % 8)
	iron += g
	arena.text(p + Vector2(0, -190), "보물방 · 실링 +%d" % g, SHC)
	if rand() < 0.3: mat_get("lamp", 1)


# ---------- bestiary ----------
func best_see(k: String) -> void:
	if not ENEMY.has(k) or best_seen.has(k): return
	best_seen[k] = 1
	if arena != null:
		arena.text(arena.player.position + Vector2(0, -170.0 * arena.player.CSCALE), "도감 등록: " + ENEMY[k]["name"], Color("#cfe8ff"))
	_best_step(k)

func best_kill(k: String) -> void:
	if not ENEMY.has(k): return
	best_kills[k] = int(best_kills.get(k, 0)) + 1
	best_seen[k] = 1
	_best_step(k)

static func is_boss(k: String) -> bool:
	return ENEMY.has(k) and ENEMY[k].get("boss", false)

func best_th(k: String) -> Array:
	return [3, 10] if is_boss(k) else [10, 30]

func best_stage_of(k: String) -> int:
	if not best_seen.has(k): return 0
	var n := int(best_kills.get(k, 0))
	var t := best_th(k)
	return 4 if n >= t[1] else (3 if n >= t[0] else (2 if n >= 1 else 1))

## each stage pays adventurer EXP once
func _best_step(k: String) -> void:
	var st := best_stage_of(k)
	var had := int(best_stage.get(k, 0))
	if st <= had: return
	var x := 0
	for i in range(had + 1, st + 1):
		x += (BSTEPB if is_boss(k) else BSTEP)[i]
	best_stage[k] = st
	# the observation EXP itself is paid by fame.gd (its own obs stages); paying it here too would double it
	if arena != null and arena.get("fame") != null:
		return

## damage multiplier of an attack element vs a target's elements
static func eff_mul(atk: String, defs: Array) -> float:
	if atk == "holy": return 1.75 if defs.has("dark") else 0.25
	var m := 1.0
	for d in defs: m *= EFF.get(atk, {}).get(d, 1.0)
	return m


# ---------- runes in combat ----------
func has(r: String, c := "") -> bool:
	if c == "": c = arena.player.who if arena != null else "estelle"
	var G: Dictionary = gear.get(c, {})
	for s in G:
		var it = G[s]
		if it != null and it["rune"] == r: return true
	return false

func star(r: String, c := "") -> int:
	if c == "": c = arena.player.who
	var st := 0
	for s in gear.get(c, {}):
		var it = gear[c][s]
		if it != null and it["rune"] == r: st = maxi(st, int(it.get("rs", 1)))
	return st

func RV(r: String, c := "") -> float:
	var s := star(r, c)
	return RSM[s] if s > 0 and s < RSM.size() else 1.0

func rb_on(k: String, ms: float, mx := 1) -> Dictionary:
	if not rb.has(k): rb[k] = {"t": 0.0, "n": 0}
	var b: Dictionary = rb[k]
	b["t"] = ms
	b["n"] = mini(mx, int(b["n"]) + 1)
	return b

func rbn(k: String) -> int:
	return int(rb[k]["n"]) if rb.has(k) and rb[k]["t"] > 0.0 else 0

## outgoing damage multiplier against target e (runeOut + crits)
func out_mul(e) -> float:
	var P = arena.player
	var c: String = P.who
	var m := 1.0
	if has("thorn", c): m *= 1.0 + 0.2 * RV("thorn", c)
	if has("temper", c):
		var st := star("temper", c)
		if st >= 5: m *= 1.12
		if st >= 7: m *= 1.08
	if has("fang", c) and e != null and e.has_meta("dark_t") and Time.get_ticks_msec() < int(e.get_meta("dark_t")): m *= 1.0 + 0.12 * RV("fang", c)
	m *= 1.0 + 0.03 * rbn("firmstep") * RV("firmstep") + 0.035 * rbn("surge") * RV("surge") + 0.08 * rbn("lamp") * RV("lamp")
	if rbn("oath") > 0: m *= 1.0 + 0.25 * RV("oath")
	if rbn("giantB") > 0: m *= 1.0 + 0.2 * RV("giant")
	if rbn("tagbell") > 0: m *= 1.0 + 0.15 * RV("tagbell")
	# 등 뒤의 그림자: Aida striking a foe that faces away
	if c == "aida" and has("backshadow", c) and e != null and e.get("dir") != null and int(e.dir) == int(P.dir):
		m *= 1.0 + 0.2 * RV("backshadow", c)
	var cr: float = gear_tot(c)["crit"]
	if cr > 0.0 and rand() * 100.0 < cr:
		m *= 1.5
		if e != null: arena.text(e.position + Vector2(24, -130), "치명!", Color("#ffd34d"))
	if memory != null: m *= memory.out_mul(c, e)
	return m

## incoming damage multiplier for the member in play (runeIn + defence)
func in_mul() -> float:
	var P = arena.player
	var m := 1.0
	if has("thorn"): m *= 1.2
	if has("stone"): m *= 1.0 - 0.05 * RV("stone")
	if has("wall") and P.hp < P.MAX_HP * 0.5: m *= 1.0 - 0.1 * RV("wall")
	if has("oath") and (P.anim == "guard" or P.anim == "parry"): m *= 1.15
	if memory != null: m *= memory.in_mul()
	return m * 150.0 / (150.0 + gear_tot(P.who)["def"])

## skill cooldown multiplier (지혜로움)
func cd_k() -> float:
	var k := 1.0 - 0.12 * RV("wise") if has("wise") else 1.0
	return k * (memory.mul(arena.player.who, "cd") if memory != null and arena != null else 1.0)

## the ultimate's gauge / cooldown multiplier (고요한 기도), for the ultimate when it comes
func ult_k() -> float:
	var k := 1.0 + 0.1 * RV("prayer") if has("prayer") else 1.0
	return k * (1.0 + gear_tot(arena.player.who)["ult"] / 100.0) * (memory.mul(arena.player.who, "ult") if memory != null else 1.0)

func ev(e: String, tg = null) -> void:
	var P = arena.player
	if e == "block" and has("firmstep"): rb_on("firmstep", 6000.0, 4)
	if e == "parry" and has("oath"): rb_on("oath", 5000.0, 1)
	if e == "heavy" and has("giant"):
		var b := rb_on("giant", 8000.0, 3)
		if b["n"] >= 3:
			b["n"] = 0
			b["t"] = 0.0
			rb_on("giantB", 5000.0, 1)
			arena.text(P.position + Vector2(0, -150.0 * P.CSCALE), "바위 거인!", Color("#ffd34d"))
	if e == "skill" and has("surge"): rb_on("surge", 5000.0, 4)
	if e == "heal" and has("lamp"): rb_on("lamp", 6000.0, 3)
	if e == "dash" and has("breeze"): rb_on("breeze", 2000.0, 1)
	if e == "tag" and has("tagbell"): rb_on("tagbell", 5000.0, 1)
	if e == "kill" and has("firstaid") and P.hp > 0.0:
		var fa := roundi(3.0 * lvm(P.who) * RV("firstaid"))
		P.hp = minf(P.MAX_HP, P.hp + fa)
		arena.text(P.position + Vector2(0, -130.0 * P.CSCALE), "+%d" % fa, Color("#9fe3a0"))
	if e == "hit" and tg != null and ATKEL[P.who].has("dark"):
		tg.set_meta("dark_t", Time.get_ticks_msec() + 6000)
	if memory != null and e != "hit": memory.ev(e)

## after a blow lands: 불씨's fire, the hit event; returns extra damage to take off the target
func after_hit(e) -> float:
	ev("hit", e)
	var P = arena.player
	var c: String = P.who
	if not has("ember", c) or rand() >= 0.1 * RV("ember", c): return 0.0
	var defs: Array = ENEMY.get(String(e.get("kind")) if e.get("kind") != null else "", {}).get("defEl", ["phys"])
	var v := maxi(1, roundi(0.5 * 10.0 * stats(c)["atk"] * eff_mul("fire", defs)))
	arena.text(e.position + Vector2(18, -110), "-%d" % v, Color("#ff9d4d"))
	arena.spark(e.position + Vector2(0, -60), 6)
	return float(v)

func on_kill(e) -> void:
	ev("kill", e)
	var k: String = String(e.get("kind")) if e.get("kind") != null else ""
	best_kill(k)
	var big: bool = e.get("elite") == true
	drop_loot(e.position, big)
	if ENEMY.get(k, {}).get("boss", false):
		for i in 3: drop_loot(e.position + Vector2((i - 1) * 40.0, 0), true)
		get_tree().create_timer(0.9).timeout.connect(func(): mat_get("lamp", 1))

## per frame while the world runs (runeTick)
func tick(dt: float) -> void:
	for k in rb:
		var b: Dictionary = rb[k]
		if b["t"] > 0.0:
			b["t"] -= dt
			if b["t"] <= 0.0: b["n"] = 0
	var P = arena.player
	var T := gear_tot(P.who)
	P.RUN = 0.36 * BASE_MS.get(P.who, 1.0) * (1.0 + T["ms"] / 100.0 - 0.02 * T["heavy"]) * ((1.0 + 0.15 * RV("breeze")) if rbn("breeze") > 0 else 1.0)
	if memory != null:
		memory.tick(dt)
		P.RUN *= memory.spd()
	if rb.has("aura") and rb["aura"]["t"] > 0.0:
		aura_acc += dt
		while aura_acc >= 1000.0:
			aura_acc -= 1000.0
			var av := roundi(2.0 * lvm("luce") * RV("aura", "luce"))
			if P.hp > 0.0 and P.hp < P.MAX_HP:
				P.hp = minf(P.MAX_HP, P.hp + av)
				arena.text(P.position + Vector2(0, -120.0 * P.CSCALE), "+%d" % av, Color("#fff1b0"))
			for c in P.party:
				if c != P.who and P.hpm[c] > 0.0: P.hpm[c] = minf(max_hp(c), P.hpm[c] + roundi(2.0 * lvm("luce")))
	if clone["t"] > 0.0: clone["t"] -= dt
	if shield_cd > 0.0: shield_cd -= dt
	_step_shields(dt)
	seen_t -= dt
	if seen_t <= 0.0:
		seen_t = 250.0
		var vw: float = arena.get_viewport_rect().size.x * 0.6
		for m in arena.mobs:
			if m.alive() and absf(m.position.x - P.position.x) < vw: best_see(m.kind)
		if arena.level == null:
			for d in arena.dummies:
				if absf(d.position.x - P.position.x) < vw: best_see("dummy")
	fx_node.queue_redraw()
	hud_node.queue_redraw()

## 방패 던지기: the shield flies out, pierces, comes back
func shield_throw() -> void:
	var P = arena.player
	shield_cd = 1100.0 * cd_k()
	shields.append({"x": P.position.x + P.dir * 30.0 * P.CSCALE, "y": P.position.y - 62.0 * P.CSCALE, "dir": P.dir, "t": 0.0, "life": 1400.0, "hits": [], "back": false})
	arena.sfx("swing", 0.8)
	ev("skill")

func _step_shields(dt: float) -> void:
	var P = arena.player
	for f in shields:
		f["t"] += dt
		var sp := 0.85
		if not f["back"] and f["t"] > 380.0:
			f["back"] = true
			f["hits"] = []
		if not f["back"]:
			f["x"] += f["dir"] * sp * dt
		else:
			var to := Vector2(P.position.x, P.position.y - 62.0 * P.CSCALE) - Vector2(f["x"], f["y"])
			var d := maxf(1.0, to.length())
			f["x"] += to.x / d * sp * dt
			f["y"] += to.y / d * sp * dt
			if d < 26.0:
				f["t"] = f["life"] + 1.0
				arena.sfx("guard", 0.4)
				continue
		for e in arena.foes():
			if f["hits"].has(e): continue
			if absf(e.position.x - f["x"]) < 34.0 and e.position.y - 95.0 < f["y"] + 16.0 and e.position.y > f["y"] - 16.0:
				f["hits"].append(e)
				e.hit(2.0, f["dir"] * 5.0, P.atk_mul())
				arena.spark(Vector2(f["x"], f["y"]), 10)
				arena.sfx("hit1", 0.7)
	shields = shields.filter(func(f): return f["t"] < f["life"])

## 그림자 분신: stays where she left and repeats her melee hits at half power
func clone_start() -> void:
	var P = arena.player
	clone = {"t": 3000.0, "x": P.position.x, "y": P.position.y, "dir": P.dir}

func clone_hits(atk) -> void:
	if clone["t"] <= 0.0 or atk == null: return
	var P = arena.player
	for e in arena.foes():
		if absf(e.position.x - clone["x"]) < 95.0 and absf(e.position.y - clone["y"]) < 70.0:
			e.hit(atk["dmg"] * 0.5, clone["dir"] * atk["kb"], P.atk_mul())
			arena.spark(e.position + Vector2(0, -50), 6)

## 축복 오라: 8 s of 2 HP a second for the party
func aura_start() -> void:
	var P = arena.player
	rb_on("aura", 8000.0, 1)
	aura_acc = 0.0
	arena.text(P.position + Vector2(0, -150.0 * P.CSCALE), "축복 오라", Color("#fff1b0"))


# ---------- the boss chest ----------
func boss_cleared(level: Node) -> void:
	boss_clears += 1
	loot = LOOT.new()
	loot.arena = arena
	loot.runes = self
	level.add_child(loot)

## the town door in the boss room waits for the chest (lootTownGate + the fatigue rule)
func town_gate() -> bool:
	if loot == null or not is_instance_valid(loot): return false
	return loot.town_gate()

## boss clears so far (fame's count when it exists)
func boss_count() -> int:
	if arena != null and arena.get("fame") != null and arena.fame.has_method("fc"):
		return int(arena.fame.fc("boss"))
	return boss_clears


# ---------- forge operations (the four stations) ----------
## 강화: a rune's star; returns "" when it cannot run, else "ok" / "miss"
func star_up(c: String, s: String, bonus := 0) -> String:
	var it = gear[c][s]
	if it == null or not has_rune_item(it): return ""
	var lv := int(it.get("rs", 1))
	if lv >= RMAX: return ""
	var cost := rs_cost(lv)
	if iron < cost: return ""
	iron -= cost
	var ok := rand() * 100.0 < minf(100.0, rs_rate(lv) + bonus)
	if ok: it["rs"] = lv + 1
	changed()
	return "ok" if ok else "miss"

## 각인: the old rune is destroyed
func engrave(c: String, s: String, r: String) -> bool:
	var it = gear[c][s]
	if it == null or int(runebag.get(r, 0)) <= 0 or not fits(r, c, s, it): return false
	var cost := engrave_cost(RUNE[r]["g"])
	if iron < cost: return false
	iron -= cost
	runebag[r] = int(runebag[r]) - 1
	it["rune"] = r
	it["rs"] = 1
	changed()
	return true

func eng_list(c: String, s: String) -> Array:
	var it = gear[c][s]
	if it == null: return []
	var L: Array = runebag.keys().filter(func(r): return int(runebag[r]) > 0 and fits(r, c, s, it))
	L.sort_custom(func(a, b): return GORD.find(RUNE[a]["g"]) < GORD.find(RUNE[b]["g"]))
	return L

func fuse_groups() -> Array:
	var g := {}
	for r in runebag:
		if int(runebag[r]) > 0 and RUNE.has(r) and FZG.has(RUNE[r]["g"]): g[RUNE[r]["g"]] = int(g.get(RUNE[r]["g"], 0)) + int(runebag[r])
	var out: Array = []
	for k in FZG:
		if g.has(k): out.append({"g": k, "c": g[k]})
	return out

## 합성: {ok, got} or {} when it cannot run; a miss eats the three and hands one back
func fuse(g: String) -> Dictionary:
	var n := 0
	for r in runebag:
		if RUNE.has(r) and RUNE[r]["g"] == g: n += int(runebag[r])
	if n < 3 or iron < FUSE_COST or not FZG.has(g): return {}
	iron -= FUSE_COST
	var need := 3
	var used: Array = []
	for r in runebag.keys():
		if not RUNE.has(r) or RUNE[r]["g"] != g: continue
		while need > 0 and int(runebag[r]) > 0:
			runebag[r] = int(runebag[r]) - 1
			need -= 1
			used.append(r)
	var up := up_grade(g)
	if rand() * 100.0 >= FZRATE[up]:
		var back: String = pick(used)
		runebag[back] = int(runebag.get(back, 0)) + 1
		return {"ok": false, "got": back}
	var pool: Array = RUNE.keys().filter(func(r): return RUNE[r]["g"] == up)
	var got: String = pick(pool)
	add_rune(got)
	return {"ok": true, "got": got}

## 분해: bag pieces → shilling; their runes go back to the bag
func salvage(idx: Array) -> int:
	var sil := 0
	var ix: Array = idx.duplicate()
	ix.sort()
	ix.reverse()
	for i in ix:
		if i < 0 or i >= gearbag.size(): continue
		var d: Dictionary = gearbag[i]
		if has_rune_item(d): add_rune(d["rune"])
		sil += melt_val(d)
		gearbag.remove_at(i)
	iron += sil
	changed()
	return sil


# ---------- test kit (Home) ----------
func test_fill() -> void:
	for r in RUNE: add_rune(r, 2)
	for i in 6: gearbag.append(make_gear(roll_grade0(0.6)))
	iron += 1000
	mem += 150
	if arena != null and arena.fatigue != null:
		arena.fatigue.v = arena.fatigue.MAX
		arena.fatigue.t = arena.fatigue.now()
		arena.fatigue.save()
	changed()

## web test hook (screenshots): window.cvaTest("page forge") / ("close") / ("menu eval-free commands below")
var _js_cb
func _ready() -> void:
	if DEV.on and OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(func(a: Array): test_cmd(str(a[0]) if a.size() > 0 else ""))
		JavaScriptBridge.get_interface("window").cvaTest = _js_cb

## "page <key>" opens a menu page · "close" shuts it · "station <up|eng|fuse|dis>" · "fill" · "memlv <n>" · "lowfat" · "kill" · "chesthit <n>"
## · "skins" (every costume; "page wardrobe" opens the 옷장)
func test_cmd(cmd: String) -> void:
	var w := cmd.split(" ")
	var M = arena.ui_root.menu if arena != null and arena.ui_root != null else null
	match w[0]:
		"page":
			if M != null:
				M.page = ""
				M.open_page(w[1])
		"close":
			if M != null: M.page = ""
		"station":
			if M != null: M.forge.go_station(w[1])
		"fill": test_fill()
		"skins":                 # every costume (as Page Up)
			if arena.get("skins") != null: arena.skins.grant_all()
		"memlv":                 # screenshots: everyone's memory level (and lamps for the breakthrough)
			for c in ROSTER: memory.T(c)["lv"] = clampi(int(w[1]) if w.size() > 1 else 12, 1, 12)
			mats["lamp"] = int(mats.get("lamp", 0)) + 3
			memory._changed()
		"start":
			if arena.ui_root != null and arena.ui_root.title.active: arena.ui_root.title._go()
		"lowfat":
			arena.fatigue.v = 10
			arena.fatigue.t = arena.fatigue.now()
		"kill":
			for m in arena.mobs:
				if not m.is_dead():
					m.spawn_t = 0.0
					m.hit(9999.0, 0.0)
		"chesthit":
			if loot != null and is_instance_valid(loot):
				if loot.chest != null: loot.chest["hintT"] = 0.0
				for i in int(w[1]) if w.size() > 1 else 1:
					if loot.chest != null and loot.chest["hintT"] > 0.0 and not loot.paid: break
					loot.hit_chest()

func _unhandled_input(ev_: InputEvent) -> void:
	# Home = test kit, End = rune book, Page Down = boss room (moved off F12, which the fame test keys use),
	# Page Up = every costume (skins.gd); debug builds only
	if not DEV.on: return
	if ev_ is InputEventKey and ev_.pressed and not ev_.echo and ev_.keycode == KEY_PAGEUP:
		if arena != null and arena.get("skins") != null:
			arena.skins.grant_all()
			arena.sfx("ui_ok", 0.6)
		return
	if ev_ is InputEventKey and ev_.pressed and not ev_.echo and ev_.keycode in [KEY_HOME, KEY_END, KEY_PAGEDOWN]:
		if ev_.keycode == KEY_HOME:
			test_fill()
			arena.text(arena.player.position + Vector2(0, -170), "실링 +1000 · 기억석 +150 · 룬 · 장비 6개 · 피로도 가득", SHC)
			arena.sfx("ui_ok", 0.6)
		elif ev_.keycode == KEY_END and arena.ui_root != null:
			arena.ui_root.menu.open_page("codex_rune")
		elif ev_.keycode == KEY_PAGEDOWN:
			# straight to the cave's boss room (the prototype's 보스방 바로가기); with Shift the fatigue drops to 10
			if ev_.shift_pressed and arena.fatigue != null:
				arena.fatigue.v = 10
				arena.fatigue.t = arena.fatigue.now()
				arena.fatigue.save()
			arena.fade_then(func():
				arena.enter_dungeon()
				var D = arena.level
				for k in D.rooms:
					if D.rooms[k]["type"] == "boss": D.cur = k
				D.from = "L"
				D.enter())


# ---------- save ----------
func get_state() -> Dictionary:
	return {"v": 1, "shilling": iron, "mem": mem, "mats": mats.duplicate(), "gear": gear.duplicate(true), "runebag": runebag.duplicate(),
		"gearbag": gearbag.duplicate(true), "seen_r": seen_r.duplicate(), "best_seen": best_seen.duplicate(), "best_kills": best_kills.duplicate(),
		"best_stage": best_stage.duplicate(), "boss_clears": boss_clears, "track": track}

func set_state(d: Dictionary) -> void:
	if d.has("shilling"): iron = int(d["shilling"])
	if d.has("mem"): mem = int(d["mem"])
	if d.has("mats"):
		for k in d["mats"]: mats[k] = int(d["mats"][k])
	if d.has("gear"):
		for c in d["gear"]:
			if not gear.has(c): continue
			for s in d["gear"][c]:
				var it = d["gear"][c][s]
				gear[c][s] = _norm(it) if it is Dictionary else null
	if d.has("runebag"):
		runebag = {}
		for r in d["runebag"]:
			if RUNE.has(r): runebag[r] = int(d["runebag"][r])
	if d.has("gearbag"):
		gearbag = []
		for it in d["gearbag"]:
			if it is Dictionary: gearbag.append(_norm(it))
	for key in ["seen_r", "best_seen", "best_kills", "best_stage"]:
		if d.has(key):
			var o := {}
			for k in d[key]: o[k] = int(d[key][k])
			set(key, o)
	if d.has("boss_clears"): boss_clears = int(d["boss_clears"])
	if d.has("track"): track = String(d["track"])
	changed()

## JSON round trips turn ints into floats and null runes into ""
static func _norm(it: Dictionary) -> Dictionary:
	var o := it.duplicate(true)
	o["lv"] = int(o.get("lv", 1))
	o["r"] = int(o.get("r", 0))
	o["seed"] = int(o.get("seed", 1))
	o["rs"] = int(o.get("rs", 1))
	var r = o.get("rune")
	o["rune"] = String(r) if r != null else ""
	var sb = o.get("sub")
	o["sub"] = [String(sb[0]), float(sb[1])] if sb is Array and sb.size() == 2 else null
	return o


# ---------- drawing: thrown shields, the clone, buff tags ----------
func _draw_fx() -> void:
	var ci := fx_node
	for f in shields:
		ci.draw_set_transform(Vector2(f["x"], f["y"]), f["t"] / 40.0, Vector2(1.0, 0.55))
		ci.draw_circle(Vector2.ZERO, 17.0, Color("#c9c6cf"))
		ci.draw_arc(Vector2.ZERO, 17.0, 0, TAU, 24, Color("#7a6a5a"), 3.0)
		ci.draw_circle(Vector2.ZERO, 6.0, Color("#e9d3a0"))
		ci.draw_set_transform(Vector2.ZERO)
	if clone["t"] > 0.0:
		var P = arena.player
		P.draw_frame(P.who, P.anim, P.f, Vector2(clone["x"], clone["y"]), clone["dir"], Color(0.55, 0.4, 0.85, 0.42 * minf(1.0, clone["t"] / 400.0)), "", ci)

func _draw_hud() -> void:
	if arena.ui_root != null and arena.ui_root.holds(): return
	var on: Array = RUNE_TAG.keys().filter(func(k): return rbn(k) > 0)
	if on.is_empty(): return
	var f: Font = arena.font_bold
	var x := 16.0
	var y: float = hud_node.get_viewport_rect().size.y - 226.0
	for k in on:
		var s: String = RUNE_TAG[k] + (" ×%d" % rb[k]["n"] if rb[k]["n"] > 1 else "")
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 12.0
		hud_node.draw_rect(Rect2(x, y, w, 17), Color(12 / 255.0, 10 / 255.0, 20 / 255.0, 0.7))
		hud_node.draw_string(f, Vector2(x + 6.0, y + 13.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f3dfae"))
		x += w + 4.0
