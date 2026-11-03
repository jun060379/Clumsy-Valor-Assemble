extends RefCounted
## Gear icons (assets/ui/items/<file>.png, Sprite Flow pixel props, trimmed square with a little air): one per item name;
## an item the table doesn't know shows its slot's stand-in (a new drop name, a placeholder piece).
##   path(it, slot) → the icon file for a gear dict ({"n", "wt"...}) worn in slot ("weapon", "head", "acc1"...)

const DIR := "res://assets/ui/items/"
const BY_NAME := {
	"낡은 롱소드": "sword_old", "기사단 롱소드": "sword_knight", "브로드소드": "sword_broad", "방패병의 한손검": "sword_short",
	"손때 묻은 삽": "shovel_worn", "그을린 삽": "shovel_scorched", "계약의 낫": "scythe_pact", "흑요석 삽": "shovel_obsidian",
	"수습 사제의 묵주": "rosary_wood", "순례자의 묵주": "rosary_pilgrim", "은 성표": "holy_symbol",
	"부싯돌 권총": "pistol_flint",
	# class weapon lines (runes.gd WEAPONS)
	"훈련용 목검": "w_war1", "철 롱소드": "w_war2", "강철 브로드소드": "w_war3", "바스타드 소드": "w_war4", "성기사의 장검": "w_war5",
	"녹슨 단검": "w_rog1", "쿠크리": "w_rog2", "스틸레토": "w_rog3", "독날 단검": "w_rog4", "그림자 송곳니": "w_rog5",
	"견습생의 지팡이": "w_mag1", "수정 지팡이": "w_mag2", "룬 지팡이": "w_mag3", "대마법사의 지팡이": "w_mag4", "별빛 지팡이": "w_mag5",
	"순례자의 곤봉": "w_pri1", "철 메이스": "w_pri2", "성휘 메이스": "w_pri3", "축복받은 홀": "w_pri4", "광휘의 홀": "w_pri5",
	"찢어진 계약서": "w_wlk1", "가죽 마도서": "w_wlk2", "사슬 묶인 마도서": "w_wlk3", "응시하는 마도서": "w_wlk4", "심연의 계약서": "w_wlk5",
	"조약돌 부적": "w_ele1", "유리 정령구": "w_ele2", "원소 수정구": "w_ele3", "사원소 오브": "w_ele4", "정령왕의 핵": "w_ele5",
	"잔가지 지팡이": "w_dru1", "참나무 지팡이": "w_dru2", "뿔 장식 지팡이": "w_dru3", "고목의 지팡이": "w_dru4", "세계수 가지": "w_dru5",
	"나무 피리": "w_bar1", "나무 류트": "w_bar2", "만돌린": "w_bar3", "황금 리라": "w_bar4", "천상의 하프": "w_bar5", "놋쇠 단발총": "pistol_brass", "쥐굴 수제 권총": "pistol_scrap",
	"찌그러진 케틀햇": "helm_kettle_dented", "케틀햇": "helm_kettle", "가죽 두건": "hood_leather", "사제 베일": "veil", "놋쇠 고글": "goggles",
	"흰 튜닉과 흉갑": "body_tunic_plate", "사슬 갑옷": "body_chain", "가죽 조끼": "body_vest", "수도복": "body_habit",
	"묘지기 앞치마 원피스": "body_apron", "수습 사제 로브": "body_novice", "올리브색 여행 로브": "body_travel",
	"판금 각반": "shoe_greaves", "흙 묻은 장화": "shoe_muddy", "사냥꾼 장화": "shoe_hunter", "헝겊 신": "shoe_cloth",
	"십자가 목걸이": "acc_cross", "검은 리본": "acc_ribbon", "보라 꽃 머리핀": "acc_hairpin", "성표 귀걸이": "acc_holy_earring",
	"두루마리 배낭": "acc_backpack", "구리 반지": "acc_ring", "유리 펜던트": "acc_pendant", "낡은 브로치": "acc_brooch", "은 귀걸이": "acc_earring",
}
## stand-ins by slot (and by weight for armour)
const BY_SLOT := {"weapon": "w_war1", "head": "helm_kettle", "body": "body_vest", "shoe": "shoe_hunter", "acc": "acc_ring"}

static func file_of(it, slot := "") -> String:
	if it == null: return ""
	var n: String = String(it.get("n", ""))
	if BY_NAME.has(n): return DIR + BY_NAME[n] + ".png"
	var s := slot if slot != "" else String(it.get("slot", ""))
	if s.begins_with("acc"): s = "acc"
	if s == "weapon" and String(it.get("cls", "")) != "":
		s = {"전사": "w_war1", "도적": "w_rog1", "마법사": "w_mag1", "사제": "w_pri1", "워락": "w_wlk1", "정령술사": "w_ele1", "드루이드": "w_dru1", "바드": "w_bar1"}.get(String(it["cls"]), "w_war1")
		return DIR + s + ".png"
	return DIR + String(BY_SLOT.get(s, "acc_ring")) + ".png"

## the texture (cached by the caller's tx()); null when the file is missing
static func tex(it, slot := "") -> Texture2D:
	var p := file_of(it, slot)
	if p == "" or not ResourceLoader.exists(p): return null
	return load(p)
