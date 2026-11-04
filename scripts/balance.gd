extends RefCounted
## Every damage coefficient in one place, in % of 공격력 (the status screen's number: 10 × base atk × level × gear).
## A hit deals 공격력 × % (then elements, runes, memory nodes, crits). The skill tab's texts read these numbers
## ({c.key} tokens, fmt()), so a change here shows there too. Owner 2026-11-04: % notation, exact numbers like Star Rail /
## Genshin; target sustained output Aida 100 · Kenin 90 (higher in bursts) · Luce 75 (딜포터) · Estelle 70.
## Numbers are a first pass (PLACEHOLDER) for the owner to tune.

const C := {
	"estelle": {
		"attack1": 110, "attack2": 110, "attack3": 220,          # 평타 1·2·3타
		"attack_high": 200, "kneel_attack": 200,                  # 위 · 아래 공격
		"air1": 100, "air2": 100, "air3": 200, "dive": 200, "dive_slam": 200,
		"cthrust": 300, "cthrust_part": 200,                      # 차징 찌르기 (끝까지 모음 / 덜 모음)
		"parry_bash": 200,                                        # 패링 반격
		"shieldthrow": 200,                                       # 고유 룬 [방패 던지기] (적중마다)
		"tag": 200,                                               # 교대 등장 일격 (주변도 같은 피해)
		"ult": 500,                                               # 궁극기 [수호의 맹세] 주변 피해
	},
	"aida": {
		"attack1": 110, "attack2": 110, "attack3": 230,
		"attack_high": 220, "kneel_attack": 220,
		"air1": 110, "air2": 110, "air3": 230, "dive": 220, "dive_slam": 220,
		"rift_min": 200, "rift_max": 400,                         # 차징 [균열 베기]: 모은 만큼 200 → 400
		"clone": 50,                                              # 고유 룬 [그림자 분신]: 아이다 공격의 50%
		"tag": 220,                                               # 교대 등장 일격 (기습: 2배)
		"ult_pass": 220, "ult_burst": 450,                        # 궁극기 [땅 밑의 문]: 균열이 지날 때 / 마지막 폭발(징표마다)
	},
	"luce": {
		"bolt": 95,                                               # 평타 빛 화살 (2타는 2발)
		"attack3": 190,                                           # 3타 빛 기둥
		"attack_high": 190,                                       # 위 공격 번개
		"air1": 95, "air2": 95, "air3": 105, "dive": 190, "dive_slam": 190,
		"lfinisher_min": 200, "lfinisher_max": 400,               # 차징 [심판의 번개]: 모은 만큼 200 → 400
		"tag": 170,
		"ult": 900,                                               # 궁극기 [루체 펀치] 일직선
	},
	"kenin": {
		"attack1": 150, "attack2": 150, "attack3": 330,           # 한 번 당길 때(3발 합계). 3타는 25 · 25 · 50%로 나뉨
		"kneel_attack": 180, "attack_high": 200, "air_combo": 130, "dive": 200,
		"bomb": 300, "bomb_head": 150,                            # 점착 폭탄 / 붙은 적에게 총알이 맞으면 ×150%
		"mark": 80,                                               # 표식 하나가 터질 때
		"chain_bomb": 100,                                        # 연쇄 기폭에서 터지는 폭탄 (폭탄 피해의 ×100%)
		"dud": 150,                                               # 터뜨릴 게 없을 때 상자 폭발
		"headshot": 450,                                          # QTE 원호
		"ult_shot": 15,                                           # 궁극기: 순간이동 사격 1발 (24발)
		"ult_mark": 15,                                           # 궁극기 연쇄에서 표식 하나
		"ult_bomb": 60,                                           # 궁극기에서 붙인 폭탄 하나 (6개)
		"tag": 0,                                                 # (원호는 교대하지 않음)
	},
}
const COMMON := {"dive_slam": 200, "tag": 200}

## the coefficient as a multiplier of 공격력 ÷ 10 (what mob.hit takes: hit(1.0) = 공격력 × 100%)
static func p(c: String, key: String, fallback := -1.0) -> float:
	var T: Dictionary = C.get(c, {})
	if T.has(key): return float(T[key]) / 100.0
	if COMMON.has(key): return float(COMMON[key]) / 100.0
	return fallback if fallback >= 0.0 else 1.0

static func pct(c: String, key: String) -> int:
	return int(round(p(c, key) * 100.0))

## "{kenin.bomb}" → "250%" in a skill text
static func fmt(s: String) -> String:
	var out := s
	var rx := RegEx.new()
	rx.compile("\\{(\\w+)\\.(\\w+)\\}")
	for m in rx.search_all(s):
		out = out.replace(m.get_string(0), "%d%%" % pct(m.get_string(1), m.get_string(2)))
	return out
