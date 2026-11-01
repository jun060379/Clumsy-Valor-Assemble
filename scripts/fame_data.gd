extends RefCounted
## Guild fame + adventurer level data, as in fame_core.js (FRANK, FUNLOCK, AMAX / aNeed / aReward, FQ, FBASEK, FCH,
## DPOOL / DLOGIN / DMS, FAC, FPEOPLE, BSTEP, OBSNOTE, DUNRANK) and the cave's entry in DUNGEONS / GRADE for the book.
## Quest progress: v = counter(k) - base(id) (FBASEK gives a base to every quest that opens after the first rank).
## Chapter tasks use either a counter (k) or a named function (fn) that fame.gd evaluates.

const SD := preload("res://scripts/skin_data.gd")
const CHN := {"estelle": "에스텔", "aida": "아이다", "luce": "루체"}
const FRANK := [{"n": "무명 길드", "need": 0}, {"n": "동네 소문", "need": 30}, {"n": "마을의 소문", "need": 130}, {"n": "마을의 자랑", "need": 330}, {"n": "영지의 용병단", "need": 630}, {"n": "이름난 길드", "need": 1030}, {"n": "전설의 시작", "need": 1530}]
const FUNLOCK := [
	["버섯 동굴 의뢰", "시설 복구 · 벽난로 · 샹들리에 · 대장간 풀무"],
	["새 의뢰 6건", "시설 복구 · 부엌 화덕 · 창고 · 헛간 · 옷장", "등급 보상 (향후 추가 예정)"],
	["새 의뢰 7건", "시설 복구 · 도서관 · 객실 · 목욕집 · 훈련장", "등급 보상 (향후 추가 예정)"],
	["다음 장 (향후 추가 예정)"], ["다음 장 (향후 추가 예정)"], ["다음 장 (향후 추가 예정)"], ["다음 장 (향후 추가 예정)"]]
const AMAX := 30
const ALLC := ["estelle", "aida", "luce"]

## town requests (r = the rank they belong to, t = "trial" for the bureau's review), progress counter k
const FQ := [
	{"id": "r1a", "r": 1, "from": "광산 조합", "n": "갱도 입구의 고블린", "d": "갱도 입구에 고블린이 들끓어 광부들이 들어가질 못한다. 20마리만 쫓아 달라.", "f": 15, "g": 20, "k": "kill"},
	{"id": "r1b", "r": 1, "from": "광산 조합", "n": "버섯 동굴 정찰", "d": "폐광 안쪽이 어떻게 됐는지 아무도 모른다. 가장 깊은 곳까지 다녀와 달라.", "f": 10, "g": 1, "k": "boss"},
	{"id": "t1", "r": 1, "t": "trial", "from": "길드 관리국", "n": "등급 심사 · 동굴 탈환", "d": "광부들을 쫓아낸 감독관 해골을 다시 쓰러뜨려, 동굴을 되찾았음을 증명할 것.", "f": 0, "g": 1, "k": "boss"},
	{"id": "r2a", "r": 2, "from": "약초상", "n": "독버섯 포자 채집", "d": "해독제를 만들 독버섯 포자가 필요하다. 독버섯 12마리를 쓰러뜨려 달라.", "f": 15, "g": 12, "k": "k_mush"},
	{"id": "r2b", "r": 2, "from": "광산 조합", "n": "갱도 안전 확보", "d": "감독관 해골이 또 나타났다. 세 번 더 쓰러뜨려 갱도를 지켜 달라.", "f": 20, "g": 3, "k": "boss"},
	{"id": "r2c", "r": 2, "from": "광부의 가족", "n": "해골이 된 광부들", "d": "돌아오지 못한 광부들이 해골이 되어 갱도를 헤맨다. 15명을 잠재워 달라.", "f": 20, "g": 15, "k": "k_skel"},
	{"id": "r2d", "r": 2, "from": "수도원", "n": "다치지 않기를", "d": "체력 절반 이상을 지킨 채 감독관 해골을 쓰러뜨려 달라. 수도원이 길드의 몸가짐을 지켜본다.", "f": 15, "g": 1, "k": "bossSafe"},
	{"id": "r2e", "r": 2, "from": "마을 경비대", "n": "출격 마차 호위", "d": "마차가 오가는 길이 아직 위험하다. 다섯 번 출격해 길을 익혀 두어 달라.", "f": 15, "g": 5, "k": "enter"},
	{"id": "r2f", "r": 2, "from": "광산 조합", "n": "고블린 재출몰", "d": "쫓아낸 고블린이 다시 모여든다. 25마리.", "f": 15, "g": 25, "k": "k_goblin"},
	{"id": "t2", "r": 2, "t": "trial", "from": "길드 관리국", "n": "등급 심사 · 무사 귀환", "d": "둘 이상의 파티로, 아무도 쓰러지지 않고 감독관 해골을 쓰러뜨릴 것.", "f": 0, "g": 1, "k": "bossParty"},
	{"id": "r3a", "r": 3, "from": "마을 경비대", "n": "동굴 눈알 감시", "d": "동굴 눈알이 마을 쪽을 엿본다는 소문. 20마리를 쓰러뜨려 달라.", "f": 30, "g": 20, "k": "k_eye"},
	{"id": "r3b", "r": 3, "from": "광산 조합", "n": "채굴 재개", "d": "광부들이 돌아갈 수 있게 감독관 해골을 다섯 번 더 쓰러뜨려 달라.", "f": 40, "g": 5, "k": "boss"},
	{"id": "r3c", "r": 3, "from": "고블린 사냥꾼", "n": "고블린 소탕전", "d": "고블린 40마리. 사냥꾼 조합이 길드에 일을 넘겼다.", "f": 30, "g": 40, "k": "k_goblin"},
	{"id": "r3d", "r": 3, "from": "광부의 가족", "n": "함께 돌아오기", "d": "둘 이상이 함께, 아무도 쓰러지지 않고 감독관 해골을 두 번 쓰러뜨려 달라.", "f": 30, "g": 2, "k": "bossParty"},
	{"id": "r3e", "r": 3, "from": "약초상", "n": "버섯 군락 정리", "d": "갱도 안쪽 버섯 군락이 다시 번진다. 독버섯 30마리.", "f": 20, "g": 30, "k": "k_mush"},
	{"id": "r3f", "r": 3, "from": "수도원", "n": "상처 없는 귀환", "d": "체력 절반 이상을 지킨 채 감독관 해골을 세 번 쓰러뜨려 달라.", "f": 30, "g": 3, "k": "bossSafe"},
	{"id": "r3g", "r": 3, "from": "광부의 가족", "n": "잠들지 못한 광부들", "d": "아직 갱도를 헤매는 해골 광부 30명을 잠재워 달라.", "f": 30, "g": 30, "k": "k_skel"},
	{"id": "t3", "r": 3, "t": "trial", "from": "길드 관리국", "n": "등급 심사 · 길드의 이름으로", "d": "셋이 함께, 아무도 쓰러지지 않고 감독관 해골을 쓰러뜨릴 것.", "f": 0, "g": 1, "k": "bossFull"}]
const FBASEK := {"t1": "boss", "t2": "bossParty", "t3": "bossFull", "r2a": "k_mush", "r2b": "boss", "r2c": "k_skel", "r2d": "bossSafe", "r3a": "k_eye", "r3b": "boss", "r3c": "k_goblin", "r3d": "bossParty", "r3e": "k_mush", "r2e": "enter", "r2f": "k_goblin", "r3f": "bossSafe", "r3g": "k_skel"}

## 모험 일지 (chapters). rw: x = EXP, iron = 실링, mem = 기억석, rune = grade
const FCH := [
	{"id": "c1", "n": "길드의 문을 두드리다", "d": "막 들어온 신입의 첫 걸음.", "rw": {"x": 80, "iron": 150, "mem": 20}, "t": [
		{"id": "c1a", "n": "첫 출격", "d": "마을의 출격 마차를 타고 던전에 들어간다.", "g": 1, "k": "enter", "rw": {"x": 30, "iron": 30}},
		{"id": "c1b", "n": "첫 보고", "d": "의뢰를 끝내고 접수대의 에일린에게 보고한다.", "g": 1, "k": "report", "rw": {"x": 30, "iron": 30}},
		{"id": "c1c", "n": "불을 밝히다", "d": "길드나 마을의 시설 하나를 복구한다.", "g": 1, "fn": "facN", "rw": {"x": 30, "iron": 40}},
		{"id": "c1d", "n": "관찰의 시작", "d": "몬스터 하나의 관찰 등급을 Ⅱ까지 올린다.", "g": 1, "fn": "bs2", "rw": {"x": 30, "mem": 10}}]},
	{"id": "c2", "n": "선배들과 함께", "d": "길드를 지켜 온 사람들과 발을 맞춘다.", "rw": {"x": 100, "iron": 100, "rune": "rare"}, "t": [
		{"id": "c2a", "n": "대장장이에게 인사", "d": "마을 대장간의 브랜과 이야기한다.", "g": 1, "k": "bran", "rw": {"x": 30, "iron": 30}},
		{"id": "c2b", "n": "둘이서", "d": "둘 이상의 파티로 출격한다.", "g": 1, "k": "enterParty", "rw": {"x": 40, "iron": 40}},
		{"id": "c2c", "n": "균열 너머에서", "d": "아이다로 몬스터 15마리를 쓰러뜨린다.", "g": 15, "k": "k_by_aida", "rw": {"x": 40, "mem": 10}},
		{"id": "c2d", "n": "빛의 순례", "d": "루체로 몬스터 15마리를 쓰러뜨린다.", "g": 15, "k": "k_by_luce", "rw": {"x": 40, "mem": 10}},
		{"id": "c2e", "n": "기억을 쌓다", "d": "누구든 세계수에서 Lv3에 오른다.", "g": 1, "fn": "anyLv3", "rw": {"x": 60, "mem": 10}}]},
	{"id": "c3", "n": "대장간의 불", "d": "룬은 맞을수록 단단해진다. 브랜의 말이다.", "rw": {"x": 120, "iron": 300}, "t": [
		{"id": "c3a", "n": "룬을 갈고닦다", "d": "룬 하나를 ★2까지 강화한다.", "g": 2, "fn": "maxStar", "rw": {"x": 40, "iron": 50}},
		{"id": "c3b", "n": "룬 새기기", "d": "룬이 각인된 장비를 셋 갖춘다.", "g": 3, "fn": "engraved", "rw": {"x": 60, "iron": 60}},
		{"id": "c3c", "n": "한 단계 더", "d": "룬 하나를 ★3까지 강화한다.", "g": 3, "fn": "maxStar", "rw": {"x": 60, "iron": 80}},
		{"id": "c3d", "n": "셋이 하나로", "d": "룬 합성에 한 번 성공한다.", "g": 1, "k": "fuse", "rw": {"x": 80, "iron": 80}}]},
	{"id": "c4", "n": "첫 돌파", "d": "한계 너머의 힘.", "rw": {"x": 150, "rune": "elite"}, "t": [
		{"id": "c4a", "n": "광부의 등잔", "d": "광부의 등잔으로 누군가의 레벨 한계를 돌파한다.", "g": 1, "fn": "breakthrough", "rw": {"x": 100, "rune": "rare"}},
		{"id": "c4b", "n": "방패 너머", "d": "에스텔로 몬스터 30마리를 쓰러뜨린다.", "g": 30, "k": "k_by_estelle", "rw": {"x": 60, "mem": 10}},
		{"id": "c4c", "n": "관찰 완료", "d": "몬스터 하나의 관찰 등급을 Ⅳ까지 올린다.", "g": 1, "fn": "bs4", "rw": {"x": 60, "mem": 15}},
		{"id": "c4d", "n": "동굴의 끝까지", "d": "누구든 Lv6에 오른다.", "g": 1, "fn": "anyLv6", "rw": {"x": 100, "iron": 120}}]},
	{"id": "c5", "n": "길드의 이름", "d": "마을이 길드의 이름을 기억하기 시작한다.", "rw": {"x": 200, "mem": 40, "rune": "epic"}, "t": [
		{"id": "c5a", "n": "마을의 소문", "d": "길드 명성 3등급에 오른다.", "g": 3, "fn": "rank", "rw": {"x": 80, "iron": 100}},
		{"id": "c5b", "n": "다시 불을 지피다", "d": "시설 다섯 곳을 복구한다.", "g": 5, "fn": "facN", "rw": {"x": 80, "iron": 100}},
		{"id": "c5c", "n": "감독관의 천적", "d": "감독관 해골을 10번 쓰러뜨린다.", "g": 10, "k": "boss", "rw": {"x": 80, "mem": 20}},
		{"id": "c5d", "n": "룬 수집가", "d": "룬 도감에서 20종을 발견한다.", "g": 20, "fn": "seenN", "rw": {"x": 80, "rune": "rare"}}]}]

## 일일 훈련
const DPOOL := [{"id": "enter", "n": "출격", "d": "던전에 1번 들어간다.", "p": 100, "g": 1, "k": "enter"}, {"id": "kill", "n": "몬스터 소탕", "d": "몬스터 20마리를 쓰러뜨린다.", "p": 100, "g": 20, "k": "kill"},
	{"id": "boss", "n": "감독관 퇴치", "d": "감독관 해골을 1번 쓰러뜨린다.", "p": 200, "g": 1, "k": "boss"}, {"id": "enh", "n": "룬 손질", "d": "대장간에서 룬 강화를 1번 시도한다.", "p": 100, "g": 1, "k": "enh"},
	{"id": "eil", "n": "접수대 들르기", "d": "에일린과 이야기한다.", "p": 100, "g": 1, "k": "eil"}, {"id": "rep", "n": "의뢰 처리", "d": "의뢰 1건을 보고한다.", "p": 200, "g": 1, "k": "report"}, {"id": "bestv", "n": "도감 펼치기", "d": "적 도감을 1번 펼쳐 본다.", "p": 100, "g": 1, "k": "bestv"}]
const DLOGIN := {"id": "login", "n": "길드에 출근", "d": "오늘 길드에 들른다.", "p": 100, "g": 1, "k": ""}
const DMS := [{"p": 100, "rw": {"x": 30, "iron": 30}}, {"p": 200, "rw": {"x": 40, "iron": 40}}, {"p": 300, "rw": {"x": 50, "iron": 50}}, {"p": 400, "rw": {"x": 60, "mem": 10}}, {"p": 500, "rw": {"x": 80, "mem": 20}}]
const DAYLV := 3

## facilities in the hall and in town
const FAC := [
	{"id": "fire", "n": "리빙 룸 벽난로", "r": 1, "cost": 60, "f": 5, "eff": "출격에서 돌아오면 대기 중이던 동료의 체력이 다 찬다.", "where": "본관 1층 리빙 룸"},
	{"id": "chand", "n": "로비 샹들리에", "r": 1, "cost": 80, "f": 5, "eff": "로비가 밝아지고, 일일 훈련 보상 실링 +20%.", "where": "본관 1층 로비"},
	{"id": "forge", "n": "대장간 풀무", "r": 1, "cost": 100, "f": 5, "eff": "풀무에 바람이 돈다. 룬 강화 성공률 +10%p.", "where": "마을 대장간", "town": true, "need": "bran"},
	{"id": "hearth", "n": "부엌 화덕", "r": 2, "cost": 140, "f": 10, "eff": "출격 전 든든한 한 끼. 던전에서 공격력 +10%.", "where": "본관 1층 부엌"},
	{"id": "store", "n": "창고", "r": 2, "cost": 150, "f": 10, "eff": "짐을 넉넉히 꾸려 간다. 보스를 쓰러뜨리면 실링 +40, 레어 룬 +1.", "where": "마을 서쪽 창고", "town": true},
	{"id": "barn", "n": "헛간 · 마차 정비", "r": 2, "cost": 170, "f": 10, "eff": "말이 쉬고 마차가 고쳐진다. 출격하면 파티 전원 기력 40%에서 시작.", "where": "마을 헛간", "town": true},
	{"id": "wardrobe", "n": "옷장", "r": 2, "cost": 120, "f": 10, "eff": "2층 복도 끝 방의 옷장이 열린다. 모든 의상을 둘러보고, 입어 보고, 실링으로 산다.", "where": "본관 2층 복도"},
	{"id": "library", "n": "도서관 서가", "r": 3, "cost": 210, "f": 15, "eff": "룬 도감에 미발견 룬의 효과가 보이고, 몬스터 관찰에 필요한 처치 수가 절반.", "where": "본관 2층 도서관"},
	{"id": "bath", "n": "목욕집", "r": 3, "cost": 220, "f": 10, "eff": "개운하게 머리를 비운다. 보스를 쓰러뜨리면 기억석 +10.", "where": "마을 목욕집", "town": true},
	{"id": "rooms", "n": "길드원 객실", "r": 3, "cost": 240, "f": 15, "eff": "3층 객실이 열린다. 동료들이 밤에 자기 방으로 간다.", "where": "본관 3층"},
	{"id": "yard", "n": "훈련장", "r": 3, "cost": 270, "f": 10, "eff": "허수아비가 고쳐지고, 파티 전원 공격력 +5%.", "where": "마을 훈련장", "town": true}]

## people: the guild's seniors are introduced after the first request; later faces come with the guild's name
const FPEOPLE := [{"c": "estelle", "n": "에스텔", "role": "길드원 · 방패", "por": "res://assets/fame/por_est.png"},
	{"c": "aida", "n": "아이다", "role": "선배 · 묘지기", "por": "res://assets/fame/por_aida.png", "sr": true},
	{"c": "luce", "n": "루체", "role": "선배 · 성녀 후보", "por": "res://assets/fame/por_luce.png", "sr": true},
	{"b": true, "n": "브랜", "role": "선배 · 길드 대장장이", "por": "res://assets/bran/por.png", "sr": true},
	{"n": "???", "role": "언젠가 길드를 찾아올 사람", "r": 4, "hint": "명성 4등급 즈음"}, {"n": "???", "role": "언젠가 길드를 찾아올 사람", "r": 5, "hint": "명성 5등급 즈음"}]

## bestiary observation: Ⅰ met · Ⅱ first kill · Ⅲ 10 kills · Ⅳ 30 kills (bosses 3 / 10); EXP per stage
const BSTEP := [0, 20, 30, 40, 60]
const BSTEPB := [0, 30, 100, 60, 100]
const OBSNOTE := {
	"goblin": "갱도 입구의 무리는 늘 동쪽 산맥 쪽에서 내려온다. 무언가에 쫓겨 오는 것처럼.",
	"mush": "광산 조합 장부에 따르면, 폐광 전에는 이 동굴에 버섯이 한 포기도 없었다.",
	"skel": "곡괭이 자루마다 이름이 새겨져 있다. 마을 묘지 명부와 맞춰 보는 중. — 아이다",
	"eye": "쓰러뜨려도 눈꺼풀을 닫지 않는다. 마지막까지 무언가를 지켜보는 듯하다.",
	"boss": "허리춤 열쇠꾸러미 중 하나는 동굴의 어느 문에도 맞지 않는다."}

## dungeons as the book shows them (prototype DUNGEONS / GRADE / MATN)
const DUNRANK := {"cave": 1}
const GRADE := {"common": ["일반", Color("#b9b2a3")], "uncommon": ["고급", Color("#7fc77a")], "rare": ["레어", Color("#6aa7ff")], "elite": ["엘리트", Color("#b48cff")], "epic": ["에픽", Color("#ff9d4d")], "legend": ["전설", Color("#ffd34d")], "unique": ["고유", Color("#ff6fae")]}
const GORD := ["unique", "legend", "epic", "elite", "rare", "uncommon", "common"]
const DUNGEONS := [
	{"id": "cave", "rec": [1, 6], "glv": [1, 6], "cap": "rare", "bonus": "elite", "mul": 1, "name": "버섯 동굴", "lv": "★", "ok": true, "mobs": ["goblin", "mush", "skel", "eye"]},
	{"id": "x1", "rec": [7, 9], "glv": [7, 13], "cap": "elite", "bonus": "epic", "mul": 2.4, "name": "???", "lv": "★★", "ok": false},
	{"id": "x2", "rec": [10, 12], "glv": [14, 20], "cap": "epic", "bonus": "legend", "mul": 4.5, "name": "???", "lv": "★★★", "ok": false}]
const LAMP := {"n": "광부의 등잔", "src": "버섯 동굴 · 감독관 해골"}
const MOBN := {"goblin": "고블린", "mush": "독버섯", "skel": "해골 광부", "eye": "동굴 눈알", "boss": "감독관 해골"}


## FUNLOCK[i] (what grade i + 1 opens) with the grade's costume rewards from skin_data.gd in the "등급 보상" slot
static func funlock(i: int) -> Array:
	var L: Array = FUNLOCK[i].duplicate()
	var sk := SD.fame_rewards(i + 1)
	if sk.is_empty(): return L
	var line := "등급 보상 · 의상 " + " · ".join(sk.map(func(s): return "%s 「%s」" % [CHN[s["c"]], s["n"]]))
	var j := L.find("등급 보상 (향후 추가 예정)")
	if j >= 0: L[j] = line
	else: L.append(line)
	return L

static func a_need(lv: int) -> int:
	return 60 + 40 * (lv - 1)

static func a_reward(lv: int) -> Dictionary:
	var R := {"iron": 40 + 10 * lv}
	if lv % 2 == 0: R["mem"] = 10 + lv
	if lv % 5 == 0: R["rune"] = "epic" if lv >= 20 else ("elite" if lv >= 10 else "rare")
	return R

## rwTxt / rwSpans: "EXP 30 · 실링 30"
static func rw_txt(R: Dictionary) -> String:
	var L: Array[String] = []
	if R.get("x", 0): L.append("EXP %d" % R["x"])
	if R.get("iron", 0): L.append("실링 %d" % R["iron"])
	if R.get("mem", 0): L.append("기억석 %d" % R["mem"])
	if R.has("rune"): L.append(GRADE[R["rune"]][0] + " 룬")
	if R.get("pt", 0): L.append("활동도 +%d" % R["pt"])
	if R.get("f", 0): L.append("명성 +%d" % R["f"])
	return " · ".join(L)

static func fq(id: String) -> Dictionary:
	for q in FQ:
		if q["id"] == id: return q
	return {}

static func fac(id: String) -> Dictionary:
	for F in FAC:
		if F["id"] == id: return F
	return {}
