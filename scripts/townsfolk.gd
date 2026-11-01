extends RefCounted
## Townsfolk: whoever of the three is not in the party lives in the guild town. They stroll (or run) between the
## places they like, idle, say a line now and then, and walk up to each other for a short chat. Ported from the
## prototype's NPCS / POI / FAV / SOLO / CHAT / npcGo / pickPOI / npcUpdate / startChat / leaveParty.
## One instance lives on the arena (meta "folk"), so where they are survives leaving and re-entering town.

const CH := preload("res://scripts/chars.gd")
const ROSTER := ["estelle", "aida", "luce"]
const HDOOR := 3024.0         # town.gd HDOOR
## two walkable routes: "top" (streets, terrace) and "bot" (the lower walkway); they meet at both ends
const JUNC := [1750.0, 6650.0]
const POI := [[450.0, "top", "store"], [1050.0, "top", "yard"], [1640.0, "top", "lamp"], [HDOOR - 120.0, "top", "hall"], [HDOOR + 260.0, "top", "hall"], [4300.0, "top", "camp"],
	[5060.0, "top", "wagon"], [5780.0, "top", "barn"], [HDOOR - 60.0, "bot", "fountain"], [HDOOR + 70.0, "bot", "fountain"], [HDOOR - 230.0, "bot", "bench"], [2660.0, "bot", "board"],
	[4650.0, "bot", "lower"], [5550.0, "bot", "lower"], [6880.0, "bot", "bath"], [7190.0, "bot", "well"], [7640.0, "bot", "forge"], [8040.0, "bot", "kiln"], [8300.0, "bot", "river"], [8950.0, "bot", "tree"]]
const FAV := {"estelle": {"yard": 4.0, "forge": 3.0, "store": 2.0, "lamp": 1.0, "hall": 2.0, "camp": 1.0},
	"aida": {"barn": 4.0, "wagon": 3.0, "well": 3.0, "kiln": 1.0, "board": 1.0, "tree": 1.0},
	"luce": {"fountain": 4.0, "bench": 2.0, "river": 3.0, "tree": 3.0, "bath": 1.0, "hall": 1.0}}
const SOLO := {"estelle": ["오늘도 무사히, 아하하.", "의족 나사가 또 헐거워졌나…", "방패 끈 새로 갈아야겠어요.", "훈련장 한 판, 어때요?", "배고프다아…", "라운데라님, 오늘도 지켜봐 주세요.", "다들 다치지 말고 돌아오면 좋겠는데."],
	"aida": ["…흙 냄새 좋네.", "큭큭.", "험.", "…오늘은 다들 조용히 자네.", "묘지 한 바퀴 돌고 올까, 삽 챙겨서.", "…뭐야, 아무것도 없네.", "죽겠다, 진짜."],
	"luce": ["힐해드려요?", "저는 루체에요!", "라운데라님~ 오늘 간식은 뭐예요?", "주여, 오늘도 평화롭게 해주소서~", "심심해써…", "고기 마니 올려서!", "분수에 동전 던지면 소원 들어줄까?"]}
const BYE := {"estelle": "그럼 마을에 있을게요!", "aida": "…그럼 마을에 있을게요.", "luce": "루체는 분수대에 있을게요~"}
## small talk (the prototype marks these as placeholder lines): pair -> scenes of [speaker index into the pair, line]
const CHAT := {
	"estelle|aida": [[[0, "아이다씨! 오늘도 묘지 순찰 가세요?"], [1, "아뇨, 삽 닦는 날이에요."], [0, "아하하, 삽 닦는 날도 있구나."]],
		[[1, "에스텔님, 그 방패 안 무거워요?"], [0, "익숙해지면 괜찮아요! …아마도요."], [1, "큭큭. 삽이 더 가볍겠네."]],
		[[0, "아이다씨는 강할걸요…?"], [1, "험. 제 비교 대상은 션님이었어요."], [0, "그, 그건 너무 높은 데 아닌가요?"]],
		[[1, "참, 에스텔님껜 고마워요."], [0, "네? 뭐가요?"], [1, "…그냥요. 덕분에 살았으니까."]]],
	"estelle|luce": [[[1, "에스텔씨! 힐해드려요?"], [0, "아하하, 저 안 다쳤어요, 루체씨."], [1, "그럼 다치면 바로 불러요!"]],
		[[0, "루체씨, 또 간식 드셨죠?"], [1, "라운데라시여, 제가 안했습니다!"], [0, "입가에 묻었는걸요?"]],
		[[1, "그럼 자기 자신도 지켜서 오세요!"], [0, "…네. 약속할게요."], [1, "따라 해봐요. 나를 함부로 희생시키지 않겠다!"]],
		[[0, "와아- 그 옷 잘 어울려요, 루체씨!"], [1, "헤헤, 라운데라님이 골라주셨어요!"], [0, "…정말요?"]]],
	"luce|aida": [[[0, "아이다씨! 같이 성물 찾으러 가요!"], [1, "…성물이요? 어디에."], [0, "몰라요! 라운데라님이 알려주실 거예요!"]],
		[[1, "안녕하세요, 루체님."], [0, "저는 루체에요! …아, 이미 아시죠?"], [1, "큭큭. 네, 알아요."]],
		[[0, "잉, 아이다씨가 만든 건 이상한 느낌 나요."], [1, "흑주술 조금 섞었어요."], [0, "주여, 이 바보 같은 이를 용서하소서~"]],
		[[1, "루체님, 머리에 잎 붙었어요."], [0, "어? 어디어디?"], [1, "…거기 말고요."]]]}
const WALKSP := {"estelle": 0.2, "aida": 0.18, "luce": 0.18}

var arena
var town                      # the town while you are in it (null elsewhere)
var npcs := {}


static func of(a) -> RefCounted:
	if not a.has_meta("folk"):
		var f = load("res://scripts/townsfolk.gd").new()
		f.arena = a
		a.set_meta("folk", f)
	return a.get_meta("folk")

func npc(c: String) -> Dictionary:
	if not npcs.has(c):
		npcs[c] = {"c": c, "x": 0.0, "y": 0.0, "r": "top", "dir": 1, "anim": "idle", "f": 0, "ft": 0.0, "mode": "idle", "wait": 800.0 + randf() * 2500.0, "path": [],
			"run": false, "say": "", "say_t": 0.0, "placed": false, "chat_cd": 4000.0 + randf() * 6000.0, "talk_t": 0.0, "chat": null, "partner": null, "seek": null, "wait_t": 0.0}
	return npcs[c]

func folk() -> Array:
	var P = arena.player
	return ROSTER.filter(func(c): return not P.party.has(c) and c != P.who)

func route_y(r: String, x: float) -> float:
	return town.floor_at(x) if r == "top" else town.terr_y(x)

func anim(n: Dictionary, a: String) -> void:
	if n["anim"] != a:
		n["anim"] = a
		n["f"] = 0
		n["ft"] = 0.0

func anim_step(n: Dictionary, dt: float) -> void:
	var e = CH.entry(n["c"], n["anim"])
	if e == null:
		n["anim"] = "idle"
		return
	var fr: Array = e[1]
	n["ft"] += dt
	var d: float = fr[mini(n["f"], fr.size() - 1)]
	if n["ft"] >= d:
		n["ft"] -= d
		n["f"] = (n["f"] + 1) % fr.size()

func say(n: Dictionary, s: String, ms := 2600.0) -> void:
	n["say"] = s
	n["say_t"] = ms

func go(n: Dictionary, x: float, r: String, run = null) -> void:
	var path := []
	var cx: float = n["x"]
	if r != n["r"]:
		var a: float = JUNC[0]
		var b: float = JUNC[1]
		var J := a if absf(n["x"] - a) + absf(a - x) <= absf(n["x"] - b) + absf(b - x) else b
		path.append({"x": J, "r": n["r"]})
		path.append({"x": J, "r": r, "flip": true})
		cx = J
	path.append({"x": x, "r": r})
	n["path"] = path
	var dist := absf(n["x"] - cx) + absf(cx - x)
	if run != null: n["run"] = run
	else: n["run"] = randf() < 0.75 if dist > 2600.0 else (randf() < 0.3 if dist > 900.0 else randf() < 0.08)
	n["mode"] = "move"

func pick_poi(c: String) -> Array:
	var f: Dictionary = FAV[c]
	var n: Dictionary = npc(c)
	var tot := 0.0
	var w := []
	for p in POI:
		var d: float = absf(p[0] - n["x"]) + (1500.0 if p[1] != n["r"] else 0.0) if n["placed"] else 0.0
		var v: float = f.get(p[2], 0.3) * exp(-d / 2200.0)
		tot += v
		w.append(v)
	var u := randf() * tot
	for i in POI.size():
		u -= w[i]
		if u <= 0.0: return POI[i]
	return POI[0]

## entering town: anyone not yet placed goes to one of their places; a chat cut short by leaving is dropped
func place() -> void:
	for c in folk():
		var n := npc(c)
		if not n["placed"]:
			var p := pick_poi(c)
			n["x"] = p[0] + (randf() - 0.5) * 80.0
			n["r"] = p[1]
			n["placed"] = true
		n["y"] = route_y(n["r"], n["x"])
		if n["mode"] == "chat" or n["mode"] == "wait":
			n["mode"] = "idle"
			n["chat"] = null

## a member leaves the party: they wait by the fountain in the lower plaza
func leave_party(c: String) -> void:
	var n := npc(c)
	n["placed"] = true
	n["r"] = "bot"
	n["x"] = HDOOR + (-1.0 if randf() < 0.5 else 1.0) * (50.0 + randf() * 60.0)
	if town != null: n["y"] = route_y("bot", n["x"])
	n["mode"] = "idle"
	n["path"] = []
	n["wait"] = 1500.0
	say(n, BYE.get(c, "그럼 마을에 있을게요!"))

func join_party(c: String) -> void:
	var n := npc(c)
	if n["chat"] != null:
		for m in n["chat"]["who"]:
			m["mode"] = "idle"
			m["chat"] = null
			m["wait"] = 1500.0
	for o in npcs.values():
		if is_same(o["partner"], n) or is_same(o["seek"], n):
			o["partner"] = null
			o["seek"] = null
			if o["mode"] == "wait": o["mode"] = "idle"
	n["mode"] = "idle"
	n["path"] = []
	n["say_t"] = 0.0

func _start_chat(a: Dictionary, b: Dictionary) -> void:
	var key: String = a["c"] + "|" + b["c"]
	var who := [a, b]
	if not CHAT.has(key):
		key = b["c"] + "|" + a["c"]
		who = [b, a]
		if not CHAT.has(key): return
	var pool: Array = CHAT[key]
	var ch := {"who": who, "lines": pool[randi() % pool.size()], "i": -1, "t": 0.0}
	a["mode"] = "chat"
	b["mode"] = "chat"
	a["chat"] = ch
	b["chat"] = ch
	a["dir"] = 1 if b["x"] > a["x"] else -1
	b["dir"] = -a["dir"]
	anim(a, "idle")
	anim(b, "idle")


# ---------- update ----------
func step(dt: float) -> void:
	for n in npcs.values():
		if n["say_t"] > 0.0: n["say_t"] -= dt
	if town == null: return
	for c in folk():
		var n := npc(c)
		if not n["placed"]: place()
		_upd(n, dt)

func _upd(n: Dictionary, dt: float) -> void:
	var P = arena.player
	n["y"] = route_y(n["r"], n["x"])
	if n["talk_t"] > 0.0:
		n["talk_t"] -= dt
		anim(n, "idle")
		anim_step(n, dt)
		n["dir"] = -1 if P.position.x < n["x"] else 1
		return
	if n["chat_cd"] > 0.0: n["chat_cd"] -= dt
	match n["mode"]:
		"chat":
			var ch: Dictionary = n["chat"]
			anim(n, "idle")
			anim_step(n, dt)
			if not is_same(ch["who"][0], n): return       # the first of the pair runs the script
			ch["t"] -= dt
			if ch["t"] <= 0.0:
				ch["i"] += 1
				if ch["i"] >= ch["lines"].size():
					for m in ch["who"]:
						m["mode"] = "idle"
						m["wait"] = 1200.0 + randf() * 2500.0
						m["chat_cd"] = 22000.0 + randf() * 15000.0
						m["chat"] = null
					return
				var L: Array = ch["lines"][ch["i"]]
				say(ch["who"][L[0]], L[1], 2300.0)
				ch["t"] = 2400.0
		"wait":
			anim(n, "idle")
			anim_step(n, dt)
			n["wait_t"] -= dt
			var o = n["partner"]
			if o != null and o["mode"] == "move": n["dir"] = 1 if o["x"] > n["x"] else -1
			if n["wait_t"] <= 0.0 or o == null or o["mode"] != "move":
				n["mode"] = "idle"
				n["wait"] = 1000.0
		"idle":
			anim(n, "idle")
			anim_step(n, dt)
			n["wait"] -= dt
			if n["wait"] > 0.0: return
			var others := []
			for c in folk():
				if c == n["c"]: continue
				var o: Dictionary = npc(c)
				if o["placed"] and (o["mode"] == "idle" or o["mode"] == "move") and o["chat_cd"] <= 0.0: others.append(o)
			if n["chat_cd"] <= 0.0 and others.size() > 0 and randf() < 0.45:
				var o: Dictionary = others[randi() % others.size()]
				o["mode"] = "wait"
				o["wait_t"] = 14000.0
				o["partner"] = n
				o["path"] = []
				n["partner"] = o
				n["seek"] = o
				var side := -1.0 if n["x"] < o["x"] else 1.0
				go(n, o["x"] + side * 62.0, o["r"], absf(o["x"] - n["x"]) > 500.0)
				return
			if randf() < 0.25 and n["say_t"] <= 0.0:
				var L: Array = SOLO[n["c"]]
				say(n, L[randi() % L.size()])
			var p: Array
			if randf() < 0.7:
				p = pick_poi(n["c"])
			else:
				var same := POI.filter(func(q): return q[1] == n["r"])
				p = same[randi() % same.size()]
			go(n, p[0] + (randf() - 0.5) * 90.0, p[1])
		"move":
			if n["path"].is_empty():
				n["mode"] = "idle"
				n["wait"] = 2000.0 + randf() * 5000.0
				return
			var wp: Dictionary = n["path"][0]
			if wp.get("flip", false):
				n["r"] = wp["r"]
				n["path"].pop_front()
				return
			var dx: float = wp["x"] - n["x"]
			var sp: float = 0.34 if n["run"] else WALKSP.get(n["c"], 0.085)
			if absf(dx) < 3.0:
				n["path"].pop_front()
				if n["path"].is_empty():
					n["mode"] = "idle"
					n["wait"] = 2000.0 + randf() * 5000.0
					if randf() < 0.4: n["dir"] = -n["dir"]
					var o = n["seek"]
					if o != null:
						n["seek"] = null
						if o["mode"] == "wait" and is_same(o["partner"], n) and absf(o["x"] - n["x"]) < 120.0 and o["r"] == n["r"]:
							_start_chat(n, o)
				return
			n["x"] += signf(dx) * minf(absf(dx), sp * dt)
			n["dir"] = int(signf(dx))
			anim(n, "run" if n["run"] else "walk")
			anim_step(n, dt)
	n["y"] = route_y(n["r"], n["x"])


# ---------- talking ----------
## someone standing near you (not mid-chat)
func near(P) -> Variant:
	for c in folk():
		var n := npc(c)
		if not n["placed"] or n["mode"] == "chat": continue
		if absf(n["x"] - P.position.x) < 80.0 and absf(n["y"] - P.position.y) < 30.0:
			return n
	return null

## the attack key near someone: they turn to you and say one of their lines
func talk(c: String) -> void:
	var n := npc(c)
	var L: Array = SOLO[c]
	n["talk_t"] = 2600.0
	say(n, L[randi() % L.size()])
	arena.sfx("ready", 0.35)


# ---------- drawing ----------
func draw(ci: CanvasItem) -> void:
	var vr: Rect2 = arena.view_rect()
	var P = arena.player
	for c in folk():
		var n := npc(c)
		if not n["placed"] or n["x"] < vr.position.x - 200.0 or n["x"] > vr.end.x + 200.0: continue
		P.draw_frame(c, n["anim"], n["f"], Vector2(roundf(n["x"]), roundf(n["y"])), n["dir"], Color.WHITE, "", ci)

func draw_bubbles(ci: CanvasItem, fnt: Font) -> void:
	var vr: Rect2 = arena.view_rect()
	for c in folk():
		var n := npc(c)
		if n["say_t"] <= 0.0 or n["x"] < vr.position.x - 100.0 or n["x"] > vr.end.x + 100.0: continue
		bubble(ci, fnt, vr, n["x"], n["y"] - 150.0 * CH.SCALE[c], n["say"], n["say_t"])

## the prototype's speech bubble: cream box, dark text, a little tail; kept inside the screen
static func bubble(ci: CanvasItem, fnt: Font, vr: Rect2, x: float, y: float, s: String, say_t: float) -> void:
	var a := clampf(minf(minf(1.0, say_t / 300.0), (2600.0 - say_t + 300.0) / 300.0), 0.0, 1.0)
	var fs := 14
	var w := fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18.0
	var bx := clampf(x, vr.position.x + w / 2.0 + 8.0, vr.end.x - w / 2.0 - 8.0)
	var bg := Color(250 / 255.0, 244 / 255.0, 228 / 255.0, 0.95 * a)
	ci.draw_rect(Rect2(roundf(bx - w / 2.0), roundf(y - 17.0), roundf(w), 24.0), bg)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 5, y + 7), Vector2(x + 5, y + 7), Vector2(x, y + 13)]), bg)
	ci.draw_string(fnt, Vector2(roundf(bx - w / 2.0 + 9.0), roundf(y + 1.0)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(42 / 255.0, 32 / 255.0, 48 / 255.0, a))
