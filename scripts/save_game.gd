extends RefCounted
## The save files: the autosave user://save.json (the prototype kept these in localStorage: party2, todH, tcSeen, ...),
## written on every scene change (town / hall / training ground / cave), every 30 s and when the party changes, and three
## manual slots user://save_1.json … save_3.json, written only from the hub's 저장 (menu.gd, town / hall / training).
## All four share one format; `save(p)` / `read(p)` take the file, `header(p)` reads a file's summary (place, in-game
## day and time, adventurer level, party, real timestamp) for the title's 불러오기 list and the 저장 picker without
## touching the world. Test runs use user://save_test.json and save_test_1.json … (arena.gd).
## Settings (user://settings.cfg) and 피로도 (user://fatigue.cfg) keep their own files.
##
## Format (JSON object, "v": 1):
##   v          int     format version (1)
##   t          float   unix seconds when written
##   party      [str]   members in the party, in order ("estelle" / "aida" / "luce"); a save from before recruiting was
##                      gated (all three along) loads with Aida and Luce recruited (fame.settle_rec)
##   who        str     the one in control
##   hp         float   her HP;  hpm {member: float} everyone's HP
##   scene      str     "town" / "hall" / "training" (a save made in the cave loads at the sortie wagon)
##   where      {kind, fl, room}   where it was really made, for the header: kind "town" / "hall" / "training" / "cave",
##                      fl the hall floor, room the cave room's name ("" elsewhere)
##   day        int     the in-game day (arena.day_n: +1 each time the world clock passes midnight)
##   x, y, dir  float, float, int   where she stands;  fl int   hall floor (scene "hall")
##   tod_h      float   the world clock (hours)
##   shilling   int     arena.shilling
##   ult        {"v": {member: float}, "cd": {member: ms}}   기력 gauges and cooldowns
##   tc_seen    {key: 1}  title cards already seen (tcSeen)
##   town_x     float   where she last left the village
##   fame       any     fame.get_state() when that system exists (restored with fame.set_state(...))
##   inventory  any     inventory.get_state() when that system exists (restored with inventory.set_state(...))
##   memory     any     runes.memory.get_state(): character levels and memory trees (restored with set_state, before HP)
##   bran_met   bool    Bran has introduced himself (branGreet's localStorage bran_met): his first-meeting lines play once
##   skins      any     skins.get_state(): {"v": 1, "owned": {id: how}, "equipped": {member: id}, "fresh": {id: 1}} (costumes);
##                      a save without it (before costumes) loads with everyone on 기본, then what fame grade and levels
##                      already earn is handed out quietly (skins.sync)

const VERSION := 1
const SLOTS := 3
const NAMES := {"estelle": "에스텔", "aida": "아이다", "luce": "루체"}

var arena
var path := "user://save.json"      # the autosave
var loaded := false
var loaded_from := ""               # the file the world was last loaded from ("" = a new game)


func _init(a) -> void:
	arena = a

func snapshot() -> Dictionary:
	var P = arena.player
	var lk: String = arena.level_kind()
	var scene := "town"
	var at: Vector2 = P.position
	var fl := 0
	if lk == "hall":
		scene = "hall"
		fl = int(arena.level.fl)
	elif lk == "":
		scene = "training"
	elif lk == "dungeon":
		at = Vector2(5107.0, arena.ground_y)
	var where := {"kind": "town" if lk == "town" else ("hall" if lk == "hall" else ("cave" if lk == "dungeon" else "training")), "fl": fl, "room": ""}
	if lk == "dungeon" and arena.level.get("tpl") is Dictionary: where["room"] = String(arena.level.tpl.get("name", ""))
	var d := {
		"v": VERSION, "t": Time.get_unix_time_from_system(),
		"party": P.party.duplicate(), "who": P.who, "hp": P.hp, "hpm": P.hpm.duplicate(),
		"scene": scene, "x": at.x, "y": at.y, "dir": P.dir, "fl": fl,
		"tod_h": arena.tod_h, "shilling": arena.shilling,
		"bran_met": arena.has_meta("bran_met"),
		"where": where, "day": int(arena.get("day_n")) if arena.get("day_n") != null else 1,
	}
	if arena.ult != null:
		d["ult"] = {"v": arena.ult.v.duplicate(), "cd": arena.ult.cd.duplicate()}
	if arena.sortie != null:
		d["tc_seen"] = arena.sortie.tc.seen.duplicate()
		d["town_x"] = arena.sortie.town_x
	var F = arena.get("fame")
	if F != null and F.has_method("get_state"): d["fame"] = F.get_state()
	var I = arena.get("runes")
	if I != null and I.has_method("get_state"): d["inventory"] = I.get_state()
	if I != null and I.get("memory") != null: d["memory"] = I.memory.get_state()
	if arena.get("skins") != null: d["skins"] = arena.skins.get_state()
	return d

## manual slot k's file (1..SLOTS), next to the autosave: save.json → save_1.json, save_test.json → save_test_1.json
func slot_path(k: int) -> String:
	return path.get_basename() + "_%d.json" % k

## every file the title can load, in the 불러오기 list's order: [[key, label, file], …] — the autosave, then the slots
func files() -> Array:
	var out: Array = [["auto", "자동 저장", path]]
	for k in range(1, SLOTS + 1): out.append([str(k), "슬롯 %d" % k, slot_path(k)])
	return out

## write the world to `p` (the autosave when empty)
func save(p := "") -> bool:
	var f := FileAccess.open(p if p != "" else path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(snapshot()))
	f.close()
	return true

## a file's contents (the autosave when `p` is empty), null when it is missing or not a save
func read(p := "") -> Variant:
	var fp := p if p != "" else path
	if not FileAccess.file_exists(fp): return null
	var f := FileAccess.open(fp, FileAccess.READ)
	if f == null: return null
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary and int(d.get("v", 0)) >= 1 else null

## a file's summary without touching the world ({} when there is no save there):
##   place "마을" / "본관 2층" / "훈련장" / "동굴 · 계단 갱도"; day int; time "18:30"; lv the adventurer level (fame.alv);
##   party [names]; t unix seconds; when "2026-11-03 15:42" (local)
func header(p := "") -> Dictionary:
	var d = read(p)
	if d == null: return {}
	var w: Dictionary = d.get("where", {}) if d.get("where") is Dictionary else {}
	var kind := String(w.get("kind", d.get("scene", "town")))
	var fl := int(w.get("fl", d.get("fl", 0)))
	var place := "마을"
	match kind:
		"hall": place = "본관 " + ["1층", "2층", "3층", "다락"][clampi(fl, 0, 3)]
		"training": place = "훈련장"
		"cave":
			place = "동굴"
			if String(w.get("room", "")) != "": place += " · " + String(w["room"])
	var th := fposmod(float(d.get("tod_h", 0.0)), 24.0)
	var hh := int(th)
	var mm := int((th - hh) * 60.0) % 60
	var names: Array = []
	for c in d.get("party", []):
		names.append(String(NAMES.get(String(c), String(c))))
	var lv := 1
	if d.get("fame") is Dictionary: lv = int(d["fame"].get("alv", 1))
	var t := float(d.get("t", 0.0))
	var lt := Time.get_datetime_dict_from_unix_time(int(t + _tz_bias()))
	return {"place": place, "day": maxi(1, int(d.get("day", 1))), "time": "%02d:%02d" % [hh, mm], "lv": lv, "party": names, "t": t,
		"when": "%04d-%02d-%02d %02d:%02d" % [lt["year"], lt["month"], lt["day"], lt["hour"], lt["minute"]]}

## the local time zone's offset (s) for the header's timestamp
static func _tz_bias() -> float:
	return float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0

## the newest of the files that hold a save ("" when none): what 시작 continues when there is no autosave
func newest() -> String:
	var best := ""
	var bt := -1.0
	for e in files():
		var h := header(e[2])
		if h.is_empty(): continue
		if float(h["t"]) > bt:
			bt = float(h["t"])
			best = e[2]
	return best

## restore everything but the scene; returns the scene to go to [kind, Vector2, dir, floor] or [] when there is no save
func apply(d: Dictionary) -> Array:
	var P = arena.player
	var roster := ["estelle", "aida", "luce"]
	var party: Array = []
	for c in d.get("party", []):
		if roster.has(c) and not party.has(c): party.append(String(c))
	if party.is_empty(): party = ["estelle"]
	var who := String(d.get("who", party[0]))
	if not party.has(who): who = party[0]
	P.party = party
	# levels and gear first: they set everyone's max HP
	var I0 = arena.get("runes")
	if I0 != null and I0.get("memory") != null and d.get("memory") is Dictionary: I0.memory.set_state(d["memory"])
	if I0 != null and I0.has_method("set_state") and d.has("inventory"): I0.set_state(d["inventory"])
	var hpm: Dictionary = d.get("hpm", {})
	for c in roster:
		if hpm.has(c): P.hpm[c] = clampf(float(hpm[c]), 0.0, I0.max_hp(c) if I0 != null else P.CH.STATS[c]["hp"])
	if who != P.who: P.switch_char(who)
	P.hp = clampf(float(d.get("hp", P.MAX_HP)), 1.0, P.MAX_HP)
	P.last_hp = P.hp
	arena.tod_h = fposmod(float(d.get("tod_h", arena.tod_h)), 24.0)
	arena.shilling = int(d.get("shilling", arena.shilling))
	if bool(d.get("bran_met", false)): arena.set_meta("bran_met", true)
	if arena.ult != null and d.has("ult"):
		var U: Dictionary = d["ult"]
		for c in roster:
			if U.get("v", {}).has(c): arena.ult.v[c] = clampf(float(U["v"][c]), 0.0, arena.ult.ULTMAX[c])
			if U.get("cd", {}).has(c): arena.ult.cd[c] = maxf(0.0, float(U["cd"][c]))
	if arena.sortie != null:
		if d.has("tc_seen") and d["tc_seen"] is Dictionary: arena.sortie.tc.seen = d["tc_seen"].duplicate()
		arena.sortie.town_x = float(d.get("town_x", arena.sortie.town_x))
	var F = arena.get("fame")
	if F != null and F.has_method("set_state") and d.has("fame"): F.set_state(d["fame"])
	if F != null and F.has_method("settle_rec"): F.settle_rec(party)
	var SKN = arena.get("skins")
	if SKN != null:
		SKN.set_state(d.get("skins"))     # missing (an old save): everyone on 기본
		SKN.sync(true)                    # then what grade and levels already earned, without notices
	if arena.get("day_n") != null: arena.day_n = maxi(1, int(d.get("day", 1)))
	loaded = true
	return [String(d.get("scene", "town")), Vector2(float(d.get("x", 700.0)), float(d.get("y", arena.ground_y))), int(d.get("dir", 1)), int(d.get("fl", 0))]
