extends RefCounted
## One save file, user://save.json (the prototype kept these in localStorage: party2, todH, tcSeen, ...).
## Written on every scene change (town / hall / training ground / cave) and when the party changes; read once at start.
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

var arena
var path := "user://save.json"
var loaded := false


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
	var d := {
		"v": VERSION, "t": Time.get_unix_time_from_system(),
		"party": P.party.duplicate(), "who": P.who, "hp": P.hp, "hpm": P.hpm.duplicate(),
		"scene": scene, "x": at.x, "y": at.y, "dir": P.dir, "fl": fl,
		"tod_h": arena.tod_h, "shilling": arena.shilling,
		"bran_met": arena.has_meta("bran_met"),
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

func save() -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(snapshot()))
	f.close()
	return true

func read() -> Variant:
	if not FileAccess.file_exists(path): return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return null
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary and int(d.get("v", 0)) >= 1 else null

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
	loaded = true
	return [String(d.get("scene", "town")), Vector2(float(d.get("x", 700.0)), float(d.get("y", arena.ground_y))), int(d.get("dir", 1)), int(d.get("fl", 0))]
