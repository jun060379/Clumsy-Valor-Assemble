extends RefCounted
## Costume skins: who owns what, who wears what, and the one resolver every screen draws member art through.
## Lives on the arena as `arena.skins` (created before the player); `Skins.cur` points at it so drawing code without the arena
## (player.draw_frame, the townsfolk, the HUD) can ask too. With no instance everything resolves to 기본.
##
## Resolver (static):
##   tex(c, key, i)      member c's picture for key in the costume she wears ("sheet" 0..4, "st_base", "st_cl", "st_smile", "st_sup",
##                       "st_gear", "st_skill", "st_skill_sil", "st_rec", "st_rec_sil", "st_full", "st_full_sil", "face", "bust", "ult_art", "doll")
##   sheet(c, i) / face(c)            the same for the sheets and the round face
##   path(c, key, i)     its res:// path ("" = none, only for a silhouette the skin leaves out on purpose)
##   tex_of(id, key, i)  a given skin's picture (the wardrobe's preview), whether worn or not
##   bounds(c)           the sheet's per-cell top / bottom rows for 캐릭터 도트화 (assets/skins/<id>/bounds.gd, else 기본's)
## A key the skin folder lacks falls back to 기본. A skin without all of its needed files (five sheets, st_base, face) is
## "준비 중": it can be owned but not worn (equip refuses, and worn() answers 기본 if a saved choice lost its files).
##
## State: owned {id: how it came}, equipped {member: id}, fresh {id: 1} (NEW until looked at).
## Unlocks: grant(id, how) — the one door for fame grade rewards, chest drops, levels / memorial, shop, story and the dev key;
## story code calls grant(id, "story") (or story(key) for every skin keyed to it). sync() hands out what fame grade and
## levels already earn (after a load, a rank-up, a level-up). buy(id) for the wardrobe. roll_chest(...) for loot.gd.
## Save: get_state() / set_state(d) (save_game.gd "skins"); an old save without it starts everyone on 기본.

const SD := preload("res://scripts/skin_data.gd")
const CH := preload("res://scripts/chars.gd")
const CB := preload("res://scripts/char_bounds.gd")
const ROSTER := ["estelle", "aida", "luce", "kenin"]
const TAG := {"fame": "명성", "drop": "GET", "level": "기억", "shop": "옷장", "story": "이야기", "dev": "TEST"}

static var cur = null              # the live instance (arena.skins)
static var ver := 0                # bumps whenever what is worn changes (screens that cache art can watch it)
static var _tex := {}              # path -> Texture2D
static var _own := {}              # "id|key|i" -> the skin folder's file ("" = none)
static var _bnd := {}              # id -> bounds array

var arena
var owned := {}                    # id -> how it came ("default" / "fame" / "drop" / "level" / "shop" / "story" / "dev")
var equipped := {}                 # member -> skin id
var fresh := {}                    # id -> 1: got and not yet looked at in the wardrobe / 의상 tab


func _init(a = null) -> void:
	arena = a
	reset()
	cur = self

func reset() -> void:
	owned = {}
	for c in ROSTER: owned[SD.BASE[c]] = "default"
	equipped = SD.BASE.duplicate()
	fresh = {}
	_changed()


# ---------- the resolver ----------
static func base_path(c: String, key: String, i := 0) -> String:
	if not SD.ASSETS.has(key): return ""
	var p: String = SD.ASSETS[key]["base"]
	var nm: String = (SD.BUST if key == "bust" else SD.DOLL).get(c, "")
	return p.replace("{c}", c).replace("{i}", str(i)).replace("{p}", nm)

## the skin folder's own file for a key ("" when it has none); .png or .webp
static func own_path(id: String, key: String, i := 0) -> String:
	var ck := "%s|%s|%d" % [id, key, i]
	if _own.has(ck): return _own[ck]
	var out := ""
	var s := SD.get_skin(id)
	if not s.is_empty() and String(s["dir"]) != "" and SD.ASSETS.has(key):
		var f: String = String(SD.ASSETS[key]["file"]).replace("{i}", str(i))
		for e in SD.EXT:
			if ResourceLoader.exists(String(s["dir"]) + f + e):
				out = String(s["dir"]) + f + e
				break
	_own[ck] = out
	return out

## skin id's file for member c's key: its own, else the original art's; "" for a silhouette when the skin brings the
## picture without it; a face of the standing picture (blink, smile, surprise) it lacks shows its own st_base
static func path_of(id: String, c: String, key: String, i := 0) -> String:
	if id != "" and own_dir(id) != "":
		var p := own_path(id, key, i)
		if p != "": return p
		var A: Dictionary = SD.ASSETS.get(key, {})
		if A.has("pair") and own_path(id, String(A["pair"]), i) != "": return ""
		if A.has("alt"):
			var q := own_path(id, String(A["alt"]), i)
			if q != "": return q
	var bp := base_path(c, key, i)
	# a member whose original art lacks a face of the standing picture (blink, smile, surprise) shows her st_base
	var A2: Dictionary = SD.ASSETS.get(key, {})
	if A2.has("alt") and bp != "" and not ResourceLoader.exists(bp): return base_path(c, String(A2["alt"]), i)
	return bp

## the skin's own folder ("" = it is the original art)
static func own_dir(id: String) -> String:
	return String(SD.get_skin(id).get("dir", ""))

## every needed file is in: it can be worn; otherwise "준비 중". A member's default is always wearable (what it lacks
## comes from the original art); a costume drawn in parts needs the sheets holding its rows; a whole one needs its five
## sheets, st_base and face.
static func is_ready(id: String) -> bool:
	var s := SD.get_skin(id)
	if s.is_empty(): return false
	if SD.is_base(id) or own_dir(id) == "": return true
	if s.has("rows"):
		var need := {}
		for r in s["rows"]: need[int(r) / CH.ROWS_PER_SHEET] = 1
		for si in need:
			if own_path(id, "sheet", si) == "": return false
		return true
	for k in SD.ASSETS:
		var A: Dictionary = SD.ASSETS[k]
		if not A.get("need", false): continue
		for i in int(A.get("n", 1)):
			if own_path(id, k, i) == "": return false
	return true

## does skin id draw this sheet row itself (else the original art's row stands in)
static func has_row(id: String, row: int) -> bool:
	var s := SD.get_skin(id)
	if s.is_empty() or own_dir(id) == "": return false
	if s.has("rows"): return (s["rows"] as Array).has(row)
	return row < 5 * CH.ROWS_PER_SHEET

## the sheet that holds `row` for skin id: its own sheet if it draws that row, else the original art's (null past them)
static func sheet_row_of(id: String, c: String, row: int) -> Texture2D:
	var si := row / CH.ROWS_PER_SHEET
	if has_row(id, row):
		var p := own_path(id, "sheet", si)
		if p != "": return load_tex(p)
	return load_tex(base_path(c, "sheet", si)) if si < 5 else null

static func sheet_row(c: String, row: int) -> Texture2D:
	return sheet_row_of(worn(c), c, row)

## the costume's own animations, stride bob, footfalls and breathing line (skin_data.gd); {} / [] / defaults otherwise
static func anims_of(id: String) -> Dictionary:
	return SD.get_skin(id).get("anims", {})

static func anims(c: String) -> Dictionary:
	return anims_of(worn(c))

static func entry(c: String, an: String) -> Variant:
	return CH.entry(c, an, anims(c))

static func resolve(c: String, an: String, f: int, variant := "") -> Array:
	return CH.resolve(c, an, f, variant, anims(c))

static func bob(c: String, an: String) -> Array:
	var b: Dictionary = SD.get_skin(worn(c)).get("bob", {})
	return b[an] if b.has(an) else CH.BOB[c].get(an, [])

static func steps(c: String, an := "run") -> Array:
	var b: Dictionary = SD.get_skin(worn(c)).get("steps", {})
	return b[an] if b.has(an) else [1, 5]

## the ground (world px) one cycle of the worn costume's `an` covers, from its art (skin_data.gd "stride"); -1 = unknown
static func stride(c: String, an := "walk") -> float:
	return float(SD.get_skin(worn(c)).get("stride", {}).get(an, -1.0))

static func breath_top(c: String) -> float:
	return float(SD.get_skin(worn(c)).get("breath_top", CH.BREATH_TOP[c]))

## the skin member c shows: her choice if its art is in, else 기본
static func worn(c: String) -> String:
	var base: String = SD.BASE.get(c, "")
	if cur == null: return base
	var id: String = cur.equipped.get(c, base)
	return id if is_ready(id) else base

static func path(c: String, key: String, i := 0) -> String:
	return path_of(worn(c), c, key, i)

static func load_tex(p: String) -> Texture2D:
	if p == "": return null
	if not _tex.has(p): _tex[p] = load(p) if ResourceLoader.exists(p) else null
	return _tex[p]

## does the worn costume have this picture of its own (the original art has them all)? A face it lacks falls back to its
## st_base, so screens that animate faces (the blink) skip the animation instead of showing the same picture twice
static func has_face(c: String, key: String) -> bool:
	var id := worn(c)
	return own_dir(id) == "" or own_path(id, key) != ""

static func tex(c: String, key: String, i := 0) -> Texture2D:
	return load_tex(path(c, key, i))

static func sheet(c: String, i: int) -> Texture2D:
	return tex(c, "sheet", i)

static func face(c: String) -> Texture2D:
	return tex(c, "face")

## a given skin's picture (fallbacks as worn)
static func tex_of(id: String, key: String, i := 0) -> Texture2D:
	var s := SD.get_skin(id)
	if s.is_empty(): return null
	return load_tex(path_of(id, s["c"], key, i))

## per-cell [top, bottom] rows of the sheet member c wears (char_bounds.gd layout) for 캐릭터 도트화: the original art's,
## with the rows a costume draws itself replaced from its bounds.gd ({row: [top, bottom] × 9}; tools/make_skin_chosim.py)
static func bounds(c: String) -> Array:
	var id := worn(c)
	if own_dir(id) == "": return CB.B[c]
	if not _bnd.has(id):
		var bp := own_dir(id) + "bounds.gd"
		var D = load(bp).get("B") if ResourceLoader.exists(bp) else null
		var out: Array = (CB.B[c] as Array).duplicate()
		if D is Dictionary:
			for r in D:
				var row: int = int(r)
				if out.size() < (row + 1) * 18: out.resize((row + 1) * 18)
				for j in 18: out[row * 18 + j] = int(D[r][j]) if D[r][j] != null else -1
			for j in out.size():
				if out[j] == null: out[j] = -1
		_bnd[id] = out
	return _bnd[id]

## files changed on disk (tests): look again
static func rescan() -> void:
	_own.clear()
	_bnd.clear()
	_tex.clear()
	ver += 1

## let go of sheets nobody wears (each costume is five 4032x2464 sheets); the next draw that needs one loads it again
static func trim(keep: Array = []) -> void:
	var live := {}
	for c in ROSTER:
		for i in 6:
			for p in [path(c, "sheet", i), base_path(c, "sheet", i)]: live[p] = 1
	for p in keep: live[p] = 1
	for p in _tex.keys():
		if String(p).get_file().begins_with("sheet_") or String(p).begins_with("res://assets/chars/"):
			if not live.has(p): _tex.erase(p)


# ---------- state ----------
func owns(id: String) -> bool:
	return owned.has(id)

func can_equip(id: String) -> bool:
	return owns(id) and is_ready(id)

## "착용 중" on a screen means this
func is_worn(id: String) -> bool:
	var s := SD.get_skin(id)
	return not s.is_empty() and worn(s["c"]) == id

func equip(id: String) -> bool:
	var s := SD.get_skin(id)
	if s.is_empty() or not can_equip(id): return false
	equipped[s["c"]] = id
	fresh.erase(id)
	_changed()
	return true

func _changed() -> void:
	ver += 1
	trim()

func _notice(s: String, tag: String, col: Color) -> void:
	if arena != null and arena.get("fame") != null: arena.fame.notice(s, tag, col, tag != "GET", 3400.0)

## the one door every unlock goes through; false if unknown or already owned
func grant(id: String, how := "", quiet := false) -> bool:
	var s := SD.get_skin(id)
	if s.is_empty() or owns(id): return false
	owned[id] = how if how != "" else String(s["unlock"]["kind"])
	fresh[id] = 1
	if not quiet and not (arena != null and arena.get("world_started") == false):
		var nm := "의상 · %s 「%s」" % [CH.NAME[s["c"]], s["n"]] + ("" if is_ready(id) else " · 그림 준비 중")
		_notice(nm, TAG.get(how, "의상"), Color("#ff6fae"))
		if arena != null and arena.has_method("sfx"): arena.sfx("ui_ok", 0.6)
	return true

## the story system's hook: every skin whose unlock is story `key`
func story(key: String) -> int:
	var n := 0
	for s in SD.SKINS:
		if s["unlock"]["kind"] == "story" and String(s["unlock"]["value"]) == key and grant(s["id"], "story"): n += 1
	return n

## what fame grade and levels have already earned
func sync(quiet := false) -> void:
	if arena == null: return
	var F = arena.get("fame")
	var R = arena.get("runes")
	for s in SD.SKINS:
		var id: String = s["id"]
		if owns(id): continue
		var u: Dictionary = s["unlock"]
		match String(u["kind"]):
			"fame":
				if F != null and int(F.r) >= int(u["value"]): grant(id, "fame", quiet)
			"level":
				if R != null and R.get("memory") != null and R.memory.lv(s["c"]) >= int(u["value"]): grant(id, "level", quiet)

## the wardrobe's 구매: "ok" / "owned" / "notsale" / "notready" / "nomoney"
func buy(id: String) -> String:
	var s := SD.get_skin(id)
	if s.is_empty() or s["unlock"]["kind"] != "shop": return "notsale"
	if owns(id): return "owned"
	if not is_ready(id): return "notready"
	var price := int(s["unlock"]["value"])
	if arena == null or int(arena.shilling) < price: return "nomoney"
	arena.shilling -= price
	grant(id, "shop")
	return "ok"

## the costumes a boss chest of grade gi (0 커먼 .. 4 레전더리) could hold: drop costumes allowed at that grade, not owned,
## whose art is in
func chest_pool(gi: int) -> Array:
	var L: Array = []
	for s in SD.SKINS:
		if s["unlock"]["kind"] == "drop" and int(s["unlock"]["value"]) <= gi and not owns(s["id"]) and is_ready(s["id"]): L.append(s["id"])
	return L

## the chest's roll: `rnd` (0..1) is asked only when something could drop (so the chest's own rolls stay as they were);
## the chance by grade (DROP_CHANCE), then which one
func roll_chest(gi: int, rnd: Callable) -> String:
	var ch := float(SD.DROP_CHANCE[clampi(gi, 0, 4)])
	var L := chest_pool(gi)
	if ch <= 0.0 or L.is_empty(): return ""
	if float(rnd.call()) >= ch: return ""
	return L[mini(L.size() - 1, int(float(rnd.call()) * L.size()))]

## the dev key: everything, quietly but for one line
func grant_all() -> int:
	var n := 0
	for s in SD.SKINS:
		if grant(s["id"], "dev", true): n += 1
	_notice("시험 · 의상 %d벌 지급 (전부)" % n, "TEST", Color("#ff6fae"))
	return n

func seen(id: String) -> void:
	fresh.erase(id)

func fresh_n(c := "") -> int:
	var n := 0
	for id in fresh:
		if c == "" or SD.get_skin(id).get("c", "") == c: n += 1
	return n


# ---------- save ----------
func get_state() -> Dictionary:
	return {"v": 1, "owned": owned.duplicate(), "equipped": equipped.duplicate(), "fresh": fresh.duplicate()}

## unknown ids are dropped; a member wears only what she owns (a choice whose art went missing still loads, worn() shows 기본)
func set_state(d) -> void:
	reset()
	if not (d is Dictionary): return
	if d.get("owned") is Dictionary:
		for id in d["owned"]:
			if not SD.get_skin(String(id)).is_empty(): owned[String(id)] = String(d["owned"][id])
	if d.get("fresh") is Dictionary:
		for id in d["fresh"]:
			if owned.has(String(id)): fresh[String(id)] = 1
	if d.get("equipped") is Dictionary:
		for c in d["equipped"]:
			var id := String(d["equipped"][c])
			var s := SD.get_skin(id)
			if ROSTER.has(String(c)) and not s.is_empty() and s["c"] == String(c) and owned.has(id): equipped[String(c)] = id
	_changed()
