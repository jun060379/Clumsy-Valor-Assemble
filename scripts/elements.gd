extends RefCounted
## Elements (prototype ELN / ELC / EFF / effMul / ATKEL / DEFEL / elemDamage / effTag / elTag).
## A hybrid attacker splits its damage evenly between its elements; each part meets the target's own (defensive) elements.
## Holy is special: x1.75 on anything that has dark, x0.25 on everything else.

const ELN := {"phys": "물리", "fire": "화염", "ice": "냉기", "elec": "전기", "earth": "대지", "water": "수류", "wind": "바람", "holy": "신성", "dark": "어둠", "plant": "초목"}
const ELC := {"phys": Color("#c9c2b4"), "fire": Color("#ff7a45"), "ice": Color("#8fdcff"), "elec": Color("#ffe14d"), "earth": Color("#c79a5b"), "water": Color("#4da3ff"), "wind": Color("#9fe6b8"), "holy": Color("#fff1b0"), "dark": Color("#b48cff"), "plant": Color("#7fcf5a")}
## dungeon select chip colours (SORTIE v2 ECOL)
const ECOL := {"phys": Color("#e6dfcf"), "plant": Color("#8fe08a"), "dark": Color("#b9a0ff"), "fire": Color("#ff9d6a"), "ice": Color("#9fe0ff"), "elec": Color("#ffe066"), "earth": Color("#d9b07a"), "water": Color("#7fb4ff"), "wind": Color("#a8f0d0"), "holy": Color("#fff3b0")}
const EFF := {
	"fire": {"ice": 1.5, "plant": 1.5, "fire": 0.5, "water": 0.5, "earth": 0.5},
	"ice": {"plant": 1.5, "wind": 1.5, "earth": 1.5, "fire": 0.5, "ice": 0.5, "water": 0.5},
	"elec": {"water": 1.5, "wind": 1.5, "earth": 0.5, "elec": 0.5, "plant": 0.5},
	"earth": {"fire": 1.5, "elec": 1.5, "wind": 0.5, "plant": 0.5},
	"water": {"fire": 1.5, "earth": 1.5, "water": 0.5, "plant": 0.5},
	"wind": {"plant": 1.5, "elec": 0.5, "earth": 0.5},
	"plant": {"water": 1.5, "earth": 1.5, "fire": 0.5, "plant": 0.5, "wind": 0.5},
	"dark": {"holy": 1.5, "dark": 0.5},
	"phys": {}, "holy": {},
}
## party members: attack elements and own elements (the prototype calls Aida "shovel")
const ATKEL := {"estelle": ["phys"], "aida": ["dark", "phys"], "luce": ["holy"], "kenin": ["phys"]}
const DEFEL := {"estelle": ["phys"], "aida": ["dark", "earth"], "luce": ["holy"], "kenin": ["phys"]}

static var _icons := {}


## 신성 (owner 2026-11-04): weak on most things, ×2 on a foe weak to it (리빙데드 · 악마 · 흑마법사: their "weak" list)
const HOLY_WEAK := 2.0
const HOLY_BASE := 0.25

static func eff_mul(atk: String, defs: Array, weak: Array = []) -> float:
	if atk == "holy":
		return HOLY_WEAK if weak.has("holy") else HOLY_BASE
	var m := 1.0
	var row: Dictionary = EFF.get(atk, {})
	for d in defs:
		m *= float(row.get(d, 1.0))
	return m

## elemDamage: base damage from member `who` against a target with elements `defs` -> {dmg, mul, parts}
static func damage(base: float, who: String, defs: Array, weak: Array = []) -> Dictionary:
	var els: Array = ATKEL.get(who, ["phys"])
	var tot := 0.0
	var parts: Array = []
	for e in els:
		var m := eff_mul(e, defs, weak)
		var v := maxf(1.0, roundf(base / els.size() * m))
		parts.append({"el": e, "dmg": v, "mul": m})
		tot += v
	return {"dmg": tot, "mul": tot / maxf(0.001, base), "parts": parts}

## hurtAmt's element part: a mob's attack element against the member's own elements
static func taken_mul(atk_el: String, who: String) -> float:
	return eff_mul(atk_el, DEFEL.get(who, ["phys"]))

## effTag: "약점!" / "저항" over the target
static func tag(arena, p: Vector2, mul: float) -> void:
	if mul >= 1.3: arena.text(p + Vector2(0, -18), "약점!", Color("#ffd34d"))
	elif mul <= 0.6: arena.text(p + Vector2(0, -18), "저항", Color("#9aa3b8"))

static func icon(e: String) -> Texture2D:
	if not _icons.has(e):
		var p := "res://assets/ui/el/el_%s.png" % e
		_icons[e] = load(p) if ResourceLoader.exists(p) else null
	return _icons[e]

## elTag: the element icons in a row, centred on x, bottom at y (15 px each, 2 px apart)
static func draw_tag(ci: CanvasItem, x: float, y: float, els: Array) -> void:
	var S := 15.0
	var n := els.size()
	for i in n:
		var t := icon(els[i])
		if t == null: continue
		ci.draw_texture_rect(t, Rect2(x + (i - (n - 1) / 2.0) * (S + 2.0) - S / 2.0, y - S + 2.0, S, S), false)
