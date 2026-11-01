extends Node
## Eilin, the receptionist: a person who lives in the world, not a counter fixture.
## She walks between maps on a chain of portals (town <-> hall 1F <-> 2F <-> 3F <-> her room); her place comes from the hour,
## and she keeps walking at real speed even when you are on another map. Ported from hall.js (EIL / EN / eilPlan / eRoute / ewp /
## eportal / eilWorld / hEilUpd / eDraw / hEilSay / eilTalk).
##   07:30 leaves her room · 08-12 counter · 12-13 lunch at the dining table · 13-18 counter · 18-20:30 town (by the lamp) ·
##   20:30-22:30 living room · 22:30 home · 23-07:30 asleep.

const HD := preload("res://scripts/hall_data.gd")
const EILM := {"idleA": [4, 154, 320], "idleB": [4, 152, 320], "idleC": [4, 154, 320], "greet": [4, 158, 320], "talk": [4, 156, 320], "stamp": [5, 160, 320],
	"sew": [6, 178, 320], "sit": [4, 144, 256], "eat": [4, 148, 256], "idleS": [4, 140, 320], "run": [8, 276, 316], "walkL": [8, 210, 316],
	"start": [4, 206, 320], "stop": [4, 204, 320], "turn": [4, 218, 314], "wave": [4, 142, 320], "stretch": [5, 172, 360]}
const EILSPD := {"idleA": 300.0, "idleB": 300.0, "idleC": 300.0, "greet": 190.0, "talk": 170.0, "stamp": 150.0, "sew": 360.0, "idleS": 320.0, "wave": 190.0,
	"stretch": 230.0, "sit": 480.0, "eat": 430.0, "run": 85.0, "walkL": 135.0, "start": 80.0, "stop": 95.0, "turn": 85.0}
const EFRONT := ["idleA", "idleB", "idleC", "greet", "talk", "stamp", "sew", "stretch"]
const EILS := 0.79            # sized by body bulk (head and shoulders close to Estelle's)
const EILS_SIDE := 0.79
const EILSC := {"sit": 1.22, "eat": 1.22}   # seated sheets were drawn smaller: bring the head back to the standing size
const EILX := 2006.0
const EIL_SPD := 0.075
const EMAPS := ["town", "h0", "h1", "h2", "room"]
const HDOOR := 3024.0         # town: the hall's front door (town.gd HDOOR) on the terrace
const TTOP := 235.0
const G := 430.0
const ESPOT := {"room": {"map": "room", "x": 818.0}, "counter": {"map": "h0", "x": EILX}, "table": {"map": "h0", "x": 2655.0, "face": 1, "sink": 6.0, "loop": "eat"},
	"town": {"map": "town", "x": 1640.0, "face": -1, "loop": "idleS"}, "living": {"map": "h0", "x": 626.0, "face": -1, "sink": 14.0, "loop": "sit"}}
const EIL_WORK_HI := ["어서 오세요. 길드 본관 접수처예요.", "오늘은 어떤 용건이세요?", "영웅이 돌아오실 때까지, 길드 관리를 소홀히 할 수는 없어요."]
const EIL_OFF := [["아, 안녕하세요. 저녁 바람이 좋네요.", "…접수는 내일 아침 여덟 시부터예요. 오늘은 저도 쉬는 시간이라서요."], ["이 시간엔 책 읽는 게 제일 좋아요.", "길드장님이 계실 땐, 다 같이 여기서 떠들곤 했는데."], ["어머, 아직 안 주무셨어요?", "저도 이것만 읽고 들어가려고요."]]
const POR := preload("res://assets/eilin/por.png")

var arena
# animation (EIL)
var a := "idleA"
var f := 0
var t := 0.0
var mode := "idle"
var near := false
var greet_cd := 0.0
var say_t := 0.0
var line := ""
var sew_t := 26000.0
var var_t := 9000.0
var hold := 0.0
var fdir := 1
var was_w := false
var face0 := 1
var turn_from := 1
var idle_v := ""
# where she is (EN)
var map := "h2"
var x := 818.0
var y := G
var spot := "room"
var path: Array = []
var wait := 0.0
var face := 1
var talk_t := 0.0
var hide := false
var lunch_cut := false
var inited := false
var sheets := {}


# ---------- art: each sheet scaled down once to the size she is drawn at ----------
func scale_of(k: String) -> float:
	return (EILS if EFRONT.has(k) else EILS_SIDE) / 2.0 * EILSC.get(k, 1.0)

func sheet(k: String) -> Dictionary:
	if sheets.has(k): return sheets[k]
	var M: Array = EILM[k]
	var n: int = M[0]
	var cw: int = M[1]
	var ch: int = M[2]
	var s := scale_of(k)
	var src: Image = load("res://assets/eilin/%s.png" % k).get_image()
	if src.is_compressed(): src.decompress()
	src.convert(Image.FORMAT_RGBA8)
	var w := maxi(1, roundi(cw * s))
	var h := maxi(1, roundi(ch * s))
	var out := Image.create(w * n, h, false, Image.FORMAT_RGBA8)
	for i in n:
		var fr := src.get_region(Rect2i(i * cw, 0, cw, ch))
		fr.resize(w, h, Image.INTERPOLATE_LANCZOS)
		out.blit_rect(fr, Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	var d := {"tex": ImageTexture.create_from_image(out), "w": w, "h": h, "n": n}
	sheets[k] = d
	return d


# ---------- the day plan ----------
func hour() -> float:
	return fposmod(arena.tod_h, 24.0)

func plan() -> String:
	var h := hour()
	if h < 7.5 or h >= 23.0: return "room"
	if h >= 12.0 and h < 13.0: return "counter" if lunch_cut else "table"
	if h >= 7.5 and h < 18.0: return "counter"
	if h >= 18.0 and h < 20.5: return "town"
	if h >= 20.5 and h < 22.5: return "living"
	return "room"

## where each portal sits on each side: [map i <-> i+1] -> [point on map i, point on map i+1]
func portal(i: int) -> Array:
	match i:
		0: return [Vector2(HDOOR, TTOP), Vector2(1800.0, G)]
		1: return [Vector2(HD.arch_x(0), HD.LANDY), Vector2(1300.0, G)]
		2: return [Vector2(HD.arch_x(1), HD.LANDY), Vector2(1150.0, G)]
	return [Vector2(818.0, G), Vector2(818.0, G)]

## walk points inside one map: hall floors with a staircase go by the ramp when one end is on the landing
func wp(m: String, pa: Vector2, pb: Vector2) -> Array:
	var L := []
	if m.begins_with("h"):
		var F: Dictionary = HD.floors()[int(m.substr(1))]
		if F.has("stair"):
			var s: float = F["stair"]
			var up_a := absf(pa.y - HD.LANDY) < 4.0
			var up_b := absf(pb.y - HD.LANDY) < 4.0
			if up_a and not up_b:
				L.append(Vector2(s + HD.SR[0], HD.LANDY))
				L.append(Vector2(s + HD.SR[1], G))
			elif not up_a and up_b:
				L.append(Vector2(s + HD.SR[1], G))
				L.append(Vector2(s + HD.SR[0], HD.LANDY))
	L.append(pb)
	var out := []
	for p in L:
		out.append({"t": "walk", "map": m, "x": p.x, "y": p.y})
	return out

func route(to: String) -> Array:
	var T: Dictionary = ESPOT[to]
	var out := []
	var mi := EMAPS.find(map)
	var pos := Vector2(x, y)
	var ti := EMAPS.find(T["map"])
	while mi != ti:
		var up := ti > mi
		var P2 := portal(mi if up else mi - 1)
		var o: Vector2 = P2[0] if up else P2[1]
		var inn: Vector2 = P2[1] if up else P2[0]
		var m: String = EMAPS[mi]
		var nm: String = EMAPS[mi + 1 if up else mi - 1]
		if m != "room": out.append_array(wp(m, pos, o))
		out.append({"t": "warp", "map": nm, "x": inn.x, "y": inn.y, "wait": 700.0})
		mi = EMAPS.find(nm)
		pos = inn
	if T["map"] != "room": out.append_array(wp(T["map"], pos, Vector2(T["x"], G)))
	out.append({"t": "arrive", "spot": to})
	return out

func walking() -> bool:
	return path.size() > 0 and talk_t <= 0.0

func talking() -> bool:
	return arena.dlg != null and arena.dlg.active and arena.dlg.who == "eilin"

## she is on the map you are looking at
func here() -> bool:
	var L = arena.level
	if L == null: return false
	if L.kind == "hall": return map == "h%d" % L.fl
	if L.kind == "town": return map == "town"
	return false

func at_desk() -> bool:
	return spot == "counter" and map == "h0" and not walking()


# ---------- moving through the world (runs on every map) ----------
func world(dt: float) -> void:
	dt = minf(dt, 200.0)
	if not inited:
		inited = true
		var s0 := plan()
		var T0: Dictionary = ESPOT[s0]
		map = T0["map"]
		x = T0["x"]
		y = G
		spot = s0
	var h := hour()
	if h < 12.0 or h >= 13.0: lunch_cut = false
	if talk_t > 0.0 and not talking(): talk_t = 0.0
	var want := plan()
	if want != spot and path.is_empty() and talk_t <= 0.0:
		var off := spot == "counter" and want in ["town", "living", "room"] and here()
		path = route(want)
		spot = "walking"
		if off:
			play("stretch", "one")
			wait = EILM["stretch"][0] * EILSPD["stretch"] + 500.0
	if talk_t > 0.0:
		talk_t -= dt
		return
	if wait > 0.0:
		wait -= dt
		return
	hide = false
	if path.is_empty(): return
	var s: Dictionary = path[0]
	if s["t"] == "warp":
		map = s["map"]
		x = s["x"]
		y = s["y"]
		wait = s["wait"]
		hide = true
		path.pop_front()
		if here(): arena.sfx("ready", 0.12)
		return
	if s["t"] == "arrive":
		spot = s["spot"]
		path.pop_front()
		var T: Dictionary = ESPOT.get(spot, {})
		if T.has("face"): face = T["face"]
		return
	var st := EIL_SPD * dt
	var sx: float = s["x"]
	var sy: float = s["y"]
	if map == "town":    # the street's height is looked up when she is drawn
		var dx := sx - x
		if absf(dx) <= st:
			x = sx
			path.pop_front()
		else:
			x += signf(dx) * st
			face = -1 if dx < 0.0 else 1
		return
	var dv := Vector2(sx - x, sy - y)
	var d := dv.length()
	if d <= st:
		x = sx
		y = sy
		path.pop_front()
	else:
		x += dv.x / d * st
		y += dv.y / d * st
		face = -1 if dv.x < 0.0 else 1


## test key: skip her walk and put her where the hour says
func snap() -> void:
	var s0 := plan()
	var T0: Dictionary = ESPOT[s0]
	path = []
	wait = 0.0
	talk_t = 0.0
	hide = false
	map = T0["map"]
	x = T0["x"]
	y = G
	spot = s0
	if T0.has("face"): face = T0["face"]
	play(T0.get("loop", "idleA"))
	mode = "loop"


# ---------- animation (only while she is on screen's map) ----------
func play(k: String, m := "") -> void:
	a = k
	mode = k if m == "" else m
	f = 0
	t = 0.0
	hold = 0.0
	fdir = 1

func upd(dt: float) -> void:
	var desk := at_desk()
	var P = arena.player
	var nr := here() and absf(P.position.x - x) < 230.0
	var walk := walking() and wait <= 0.0
	greet_cd -= dt
	if say_t > 0.0: say_t -= dt
	t += dt
	var tk := talking()
	# one-shots play through, then fall back to the loop
	if mode in ["one", "greet", "stamp", "sew"]:
		var last: int = EILM.get(a, EILM["idleA"])[0] - 1
		if f < last:
			if t > EILSPD[a]:
				t = 0.0
				f += 1
			return
		hold += dt
		var need := 1100.0 if a == "stamp" else (0.0 if a in ["stop", "start", "turn"] else 500.0)
		if hold < need: return
		mode = "loop"
		a = ""
	# transitions while walking
	if walk != was_w:
		was_w = walk
		face0 = face
		if walk:
			play("start", "one")
			return
		elif spot != "counter":
			play("stop", "one")
			return
	if walk and face != face0:
		turn_from = face0
		face0 = face
		play("turn", "one")
		return
	var loop: String
	if walk: loop = "run"     # one gait for the whole cast: the hurried trot
	elif desk: loop = "talk" if tk else (idle_v if idle_v != "" else "idleA")
	else:
		var T: Dictionary = ESPOT.get(spot, {})
		loop = T.get("loop", "idleS")
	if a != loop:
		a = loop
		f = 0
		t = 0.0
		fdir = 1
		mode = "loop"
	var n: int = EILM[loop][0]
	var sp: float = EILSPD.get(loop, 300.0)
	if t > sp:
		t = 0.0
		if loop.contains("idle") or loop == "sit" or loop == "eat":
			f += fdir
			if f >= n - 1 or f <= 0: fdir *= -1
			f = clampi(f, 0, n - 1)
		else:
			f = (f + 1) % n
	if desk and not tk:
		var_t -= dt
		if var_t <= 0.0:
			var_t = 7000.0 + randf() * 7000.0
			var r := randf()
			idle_v = "idleA" if r < 0.5 else ("idleB" if r < 0.8 else "idleC")
		if nr and not near and greet_cd <= 0.0:
			greet_cd = 20000.0
			play("greet")
			say(EIL_WORK_HI[0], 2400.0)
		elif not nr:
			sew_t -= dt
			if sew_t <= 0.0:
				sew_t = 30000.0 + randf() * 20000.0
				play("sew")
	elif not walk and spot == "town" and nr and not near and greet_cd <= 0.0 and not tk:
		greet_cd = 20000.0
		face = -1 if P.position.x < x else 1
		play("wave", "one")
		say(EIL_OFF[0][0], 2400.0)
	near = nr

func say(s: String, ms := 3600.0) -> void:
	line = s
	say_t = ms


# ---------- drawing ----------
## behind the counter / in front of the table's chair / free among the props
func layer() -> String:
	if a == "stretch": return "counter"
	if walking(): return "free"
	if spot == "counter": return "counter"
	if spot == "table": return "table"
	return "free"

func draw_on(ci: CanvasItem, cx: float, cy: float) -> void:
	var k := a if a != "" else "idleA"
	if not EILM.has(k): return
	var S := sheet(k)
	var fi := mini(f, S["n"] - 1)
	var flip := false
	if not EFRONT.has(k):
		flip = turn_from < 0 if k == "turn" else face < 0
	var T: Dictionary = ESPOT.get(spot, {})
	if not walking() and T.has("sink"): cy += T["sink"]
	var w: float = S["w"]
	var h: float = S["h"]
	var src := Rect2(fi * w, 0, w, h)
	if flip:
		ci.draw_set_transform(Vector2(roundf(cx), 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect_region(S["tex"], Rect2(-roundf(w / 2.0), roundf(cy - h + 1.0), w, h), src)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect_region(S["tex"], Rect2(roundf(cx - w / 2.0), roundf(cy - h + 1.0), w, h), src)

## the speech bubble over her head
func draw_say(ci: CanvasItem, cy: float) -> void:
	if say_t <= 0.0 or line == "" or not here(): return
	var al := clampf(minf(minf(1.0, say_t / 300.0), (3600.0 - say_t) / 200.0 + 0.2), 0.0, 1.0)
	var fnt: Font = arena.font_bold
	var yy := cy - 148.0
	var w := fnt.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 26.0
	ci.draw_rect(Rect2(roundf(x - w / 2.0), yy - 20.0, roundf(w), 30.0), Color(12 / 255.0, 10 / 255.0, 14 / 255.0, 0.82 * al))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 6, yy + 10), Vector2(x + 6, yy + 10), Vector2(x, yy + 18)]), Color(12 / 255.0, 10 / 255.0, 14 / 255.0, 0.82 * al))
	ci.draw_rect(Rect2(roundf(x - w / 2.0), yy - 20.0, 4.0, 30.0), Color(0x8f / 255.0, 0xcf / 255.0, 0x8a / 255.0, al))
	ci.draw_string(fnt, Vector2(roundf(x - w / 2.0 + 15.0), yy), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.965, 0.875, al))


# ---------- talking to her ----------
## a door you can talk at, wherever she happens to be standing (not at the desk: the counter is its own door)
func door_near(P) -> Variant:
	if not here() or at_desk() or wait > 0.0 or map == "room" or hide: return null
	var fy: float = y
	if map == "town" and arena.level.has_method("floor_at"): fy = arena.level.floor_at(x)
	if absf(P.position.x - x) < 70.0 and absf(P.position.y - fy) < 6.0:
		return {"x": x, "y": fy, "name": "에일린", "k": "대화", "act": "eilin"}
	return null

func talk() -> void:
	talk_t = 999999.0
	var F = arena.fame
	if F != null: F.finc("eil")
	if spot == "counter":
		if F != null:
			F.eil_work()      # eilWork: quest report / review letter / the two books (fame.gd)
			return
		arena.open_dialog("eilin", POR, "에일린", "길드 접수원", [EIL_WORK_HI[randi() % EIL_WORK_HI.size()]], func():
			talk_t = 0.0
			greet_cd = 6000.0)
	elif spot == "table":
		if F != null:
			arena.dlg.ask("eilin", POR, "에일린", "길드 접수원", ["아, 앗…! 지금은 식사 중인데…"], [
				["길드 용건이에요", func():
					talk_t = 0.0
					lunch_cut = true
					F.eil_work(["…네! 바로 볼게요.", "(에일린이 수저를 내려놓고 서류를 집어 든다)", "말씀하세요. 어떤 용건이세요?"])],
				["나중에 올게요", func():
					talk_t = 0.0
					say("천천히 다녀오세요!", 1800.0)]])
			return
		arena.open_dialog("eilin", POR, "에일린", "길드 접수원", ["아, 앗…! 지금은 식사 중인데…"], func():
			talk_t = 0.0
			say("천천히 다녀오세요!", 1800.0))
	else:
		var L: Array = EIL_OFF[randi() % EIL_OFF.size()]
		arena.open_dialog("eilin", POR, "에일린", "길드 접수원", L, func(): talk_t = 0.0)

## the counter when she is not behind it
func desk_away() -> String:
	match spot:
		"table": return "점심 식사 중이에요. 식당 쪽에 계세요."
		"town": return "퇴근하셨어요. 마을 어딘가에 계실 거예요."
		"living": return "퇴근하셨어요. 리빙 룸에 계신 것 같아요."
		"room": return "주무시는 시간이에요."
	return "자리를 비웠어요."

## hEilUpd's rank check: at the desk she stamps and congratulates when the guild goes up a rank
func on_rank_up() -> void:
	if at_desk():
		play("stamp", "stamp")
		say("승급 축하드려요! 길드가 한 단계 컸네요.", 3600.0)
		arena.sfx("guard", 0.4)
