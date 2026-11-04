extends "res://scripts/ui_page.gd"
## 브랜의 대장간 — the prototype's FORGE v2 (#fg2: F2FORGE / F2CSS, goP, upHit, gearPick, engCard, fuseCard, disCard, stampRes),
## laid out as its DOM is and moving on its clock:
##   ground: the station colour, the fire glow (flicker 1.8 s), the slab in her colour (its own angle per station, .7 s),
##   the station shade, dots, the hollow ENHANCE · … word (36 s drift); .ttl 대장간 + .fcash; the rail 01–04 with its
##   striped cursor; the stations: 강화 (Bran, the anvil quad with the piece, the card), 각인 (rune rows, the socket ring),
##   합성 (rune groups, three hex slots → the result), 분해 (sub tabs, tiles); the speech bubble types at 28 ms a letter.
##   Station change: the rail answers at once, a sheet in the next station's colour turns 91° about the bottom-left corner
##   (.5 s), the new station snaps in under it and its parts slide in (70 px, 5°, .5 s --bk, 45 ms apart).
##   A strike: Bran's hammer pose (130 ms), the hit at 150 ms (anvil kick, shake, brightness, sparks, the result banner),
##   back to his portrait at 610 ms; ★6 and up: his cut-in on three bands first (340 ms). Banners: SUCCESS / MISS /
##   ENGRAVED / FUSED / SALVAGED in letters over two bands, sunk at 850 ms.
## Opened from the hub (back = sweep to the hub) or from Bran's choices (back = his choices again).

const ICON := preload("res://scripts/item_icons.gd")
const ACTS := [["up", "강화", "ENHANCE"], ["eng", "각인", "ENGRAVE"], ["fuse", "합성", "FUSE"], ["dis", "분해", "SALVAGE"]]
const FBG := {"up": Color("#2b0f15"), "eng": Color("#1d1240"), "fuse": Color("#08283a"), "dis": Color("#202329")}
const GL := {"up": Color(1.0, 0.47, 0.157, 0.55), "eng": Color(0.588, 0.314, 1.0, 0.6), "fuse": Color(0.157, 0.784, 1.0, 0.5), "dis": Color(1.0, 0.275, 0.196, 0.42)}
## slab per station: [right %, width %, rotation, clip-path]
const SLAB := {"up": [-12.0, 46.0, 10.0, [[0, 0], [100, 0], [100, 100], [0, 100]]], "eng": [-6.0, 30.0, -7.0, [[18, 0], [100, 0], [100, 100], [0, 100]]],
	"fuse": [-16.0, 40.0, 17.0, [[0, 0], [100, 0], [100, 100], [22, 100]]], "dis": [-4.0, 27.0, 3.0, [[0, 0], [100, 0], [100, 100], [8, 100]]]}
## the shade per station: [left %, top %, width %, height %, rotation, opacity, clip-path]
const SHD := {"up": [-30.0, -10.0, 30.0, 130.0, -8.0, 0.0, [[0, 0], [100, 4], [82, 100], [0, 96]]], "eng": [-6.0, -10.0, 42.0, 130.0, -8.0, 1.0, [[0, 0], [100, 4], [82, 100], [0, 96]]],
	"fuse": [20.0, 6.0, 52.0, 96.0, -4.0, 1.0, [[50, 0], [100, 84], [80, 100], [0, 92]]], "dis": [-4.0, 14.0, 64.0, 80.0, -3.0, 1.0, [[0, 4], [100, 0], [96, 100], [2, 94]]]}
const FZRATE := {"uncommon": 90, "rare": 70, "elite": 50, "epic": 40, "legend": 10}
const POR := preload("res://assets/bran/por.png")
const HIT := preload("res://assets/bran/hit.webp")
const AE := preload("res://scripts/ui_anim.gd")
const BK := [0.2, 1.5, 0.4, 1.0]
const EZ := [0.16, 1.0, 0.3, 1.0]
const NDL := [[-5, 58.9, 21.25, 46.1, 70, 26.7, 21.25, 48.6], [20, 51.0, 49.75, 39.8, 105, 22.2, 49.75, 40.6], [8, 57.6, 26.2, 49.8, 60, 42.6, 26.2, 53.9],
	[40, 51.7, 64.5, 45.6, 110, 38.3, 64.5, 46.2], [-5, 63.4, 12.5, 59.2, 45, 54.6, 12.5, 61.0], [30, 60.1, 52.75, 56.7, 95, 52.2, 52.75, 57.7],
	[55, 61.2, 74.95, 56.6, 112, 59.4, 74.95, 61.7], [0, 66.1, 28.0, 65.3, 80, 65.0, 28.0, 65.9], [15, 68.1, 34.25, 67.6, 70, 70.7, 34.25, 69.9],
	[60, 74.1, 78.2, 75.1, 112, 79.5, 78.2, 76.2], [70, 36.0, 84.7, 30.9, 112, 26.7, 84.7, 31.4], [75, 47.4, 87.95, 43.1, 112, 43.4, 87.95, 46.0]]

var c := "estelle"
var slot := "weapon"
var p := "up"                  # the shown station (data-p)
var sp := "up"                 # the slab's station (data-sp: changes at the tap)
var eng := 0
var fz := 0
var dis := {}
var ds := "plain"
var gs := "rune"
var from_dlg := false
var busy := 0                  # F2.busy
var wiping := false
var rvm := {}                  # RVM: the effect box face per screen
var msg := ""
var msg_t := 0.0               # since say()
var clk := {}                  # one-shot clocks: name -> page time it began
var timers: Array = []         # [at, Callable]
var it_off := 0                # --i offset of the shown pane's parts (3 after a station change)
var rc_off := 0                # the rows' --i offset (rows rendered before the change keep k+3)
var in_t := 0.0                # when the pane's .in came off
var stamps: Array = []         # result banners
var sparks: Array = []
var halves: Array = []         # 분해: the cracked tile halves
var gone := {}                 # 분해: tiles already split (hidden)
var fly: Dictionary = {}       # 각인: the gem in flight
var hold := {}                 # shown values frozen until the strike lands: "rs" / "card"
var bran_hit := false          # the hammer pose is up
var bran_back_t := -1.0
var picking := false
var pick_closing := false
var fr_got := ""               # 합성: the result label (…/[name])
var fr_show := false
var sel_t := 9999.0            # rows: the last pick (margin transition)
var prev_sel := -1
var list_off := 0.0
var hb: Array = []
var lift: ColorRect             # the strike's FGE filter: brightness(2.6) contrast(1.2) → none, 380 ms ease-out


func _ready() -> void:
	super()
	keys = ["forge"]
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


## the FGE filter: the page's own pixels through brightness(b) then contrast(c) (CSS filter math, each step clamped)
const FILTER_SH := "shader_type canvas_item;\nrender_mode unshaded;\nuniform sampler2D scr : hint_screen_texture, filter_nearest;\nuniform float br = 1.0;\nuniform float ct = 1.0;\nvoid fragment(){ vec3 c = textureLod(scr, SCREEN_UV, 0.0).rgb; c = clamp(c * br, 0.0, 1.0); c = clamp((c - 0.5) * ct + 0.5, 0.0, 1.0); COLOR = vec4(c, 1.0); }"
func _lift_node() -> void:
	if lift != null: return
	var bb := BackBufferCopy.new()
	bb.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(bb)
	lift = ColorRect.new()
	lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = FILTER_SH
	var m := ShaderMaterial.new()
	m.shader = sh
	lift.material = m
	lift.visible = false
	add_child(lift)

func set_from_dlg(v: bool) -> void:
	from_dlg = v

func R2():
	return arena.runes

func now() -> float:
	return t

func mark(n: String) -> void:
	clk[n] = t

func since(n: String) -> float:
	return t - clk[n] if clk.has(n) else 1e9

func after(ms: float, f: Callable) -> void:
	timers.append([t + ms, f])

## openForge
func _opened() -> void:
	c = arena.player.who
	var G: Dictionary = R().gear[c]
	slot = "weapon"
	if G["weapon"] == null:
		for s in RN.SLOTS:
			if G[s[0]] != null:
				slot = s[0]
				break
	busy = 0
	wiping = false
	picking = false
	stamps.clear()
	sparks.clear()
	halves.clear()
	timers.clear()
	clk.clear()
	hold.clear()
	fly = {}
	bran_hit = false
	sp = p
	it_off = 0
	rc_off = 0
	in_t = 0.0
	_set_shake(Vector2.ZERO)
	_pane_init(p, false)
	if arena.level_kind() == "town" and arena.level.get("bran") != null:
		arena.level.bran.talk_t = 1500.0
		arena.level.bran.play("talk")

func cur():
	return R().gear[c][slot]

## say(): types at 28 ms a letter; the bubble stamps in
func say(s: String) -> void:
	msg = s
	msg_t = 0.0

var _in_proc := false
func _process(delta: float) -> void:
	_in_proc = true
	super(delta)
	_in_proc = false

func _tick(dt: float) -> void:
	if not _in_proc: t += dt        # driven by hand (tests): the page clock still runs
	msg_t += dt
	sel_t += dt
	var due: Array = []
	for tm in timers:
		if tm[0] <= t: due.append(tm)
	for tm in due:
		timers.erase(tm)
		tm[1].call()
	for q in sparks: q["t"] += dt
	sparks = sparks.filter(func(q): return q["t"] < q["d"])
	for h in halves: h["t"] += dt
	halves = halves.filter(func(h): return h["t"] < 460.0)
	stamps = stamps.filter(func(s): return t - s["t0"] < (s["sink"] - s["t0"]) + 420.0 if s["sink"] >= 0.0 else true)
	# the FGE shake (w_shake .4s linear) and filter flashes
	_lift_node()
	var bt := since("bright")
	lift.visible = bt < 380.0 and live()
	if lift.visible:
		# FGE.animate([{filter:'brightness(2.6) contrast(1.2)'},{filter:'none'}],{duration:380,easing:'ease-out'})
		var k := AE.ez("ease-out", bt / 380.0)
		lift.size = get_viewport_rect().size + Vector2(40, 40)
		lift.position = Vector2(-20, -20)
		var m: ShaderMaterial = lift.material
		m.set_shader_parameter("br", lerpf(2.6, 1.0, k))
		m.set_shader_parameter("ct", lerpf(1.2, 1.0, k))
	var sk := since("shake")
	_set_shake(_shake(sk) if sk < 400.0 else Vector2.ZERO)


## the FGE shake moves the whole page: an offset on the canvas item itself (the page stays full-rect)
func _set_shake(o: Vector2) -> void:
	# the page Control is zero-sized: give the canvas item a full-screen rect so the offset never culls it
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, Rect2(Vector2(-100, -100), get_viewport_rect().size + Vector2(200, 200)))
	RenderingServer.canvas_item_set_transform(get_canvas_item(), Transform2D(0.0, o))

static func _shake(ms: float) -> Vector2:
	var K := [Vector2.ZERO, Vector2(-8, 4), Vector2(7, -5), Vector2(-5, 3), Vector2(3, -2), Vector2.ZERO]
	var u := clampf(ms / 400.0, 0.0, 1.0) * 5.0
	var i := mini(int(u), 4)
	return K[i].lerp(K[i + 1], u - i)

func back() -> void:
	if busy > 0: return
	if picking:
		gear_close(Callable())
		return
	menu.close_page()
	stamps.clear()
	if from_dlg and not menu.from_hub:
		from_dlg = false
		menu.open_bran(true)

func _key(k: int) -> void:
	if k == KEY_ESCAPE: back()
	elif picking: return
	elif k in [KEY_Q, KEY_PAGEUP]: go_station(ACTS[(_pi() + 3) % 4][0])
	elif k in [KEY_E, KEY_PAGEDOWN, KEY_TAB]: go_station(ACTS[(_pi() + 1) % 4][0])
	elif k in [KEY_1, KEY_2, KEY_3, KEY_4]: go_station(ACTS[k - KEY_1][0])
	elif k in [KEY_UP, KEY_DOWN]:
		var d := -1 if k == KEY_UP else 1
		if p == "eng": _row_pick(clampi(eng + d, 0, maxi(0, R().eng_list(c, slot).size() - 1)))
		elif p == "fuse": _row_pick(clampi(fz + d, 0, maxi(0, R().fuse_groups().size() - 1)))
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		match p:
			"up": do_up()
			"eng": do_eng()
			"fuse": do_fuse()
			"dis": do_dis()

func _wheel(d: int, _pos: Vector2) -> void:
	list_off = maxf(0.0, list_off + d * 40.0)

func _pi() -> int:
	for i in 4:
		if ACTS[i][0] == p: return i
	return 0

func _ai(k: String) -> int:
	for i in 4:
		if ACTS[i][0] == k: return i
	return 0


# ---------- stations ----------
## paneInit (+ .in when it enters: its parts slide in after two frames)
func _pane_init(np: String, entering := true) -> void:
	eng = mini(eng, maxi(0, R().eng_list(c, slot).size() - 1))
	fz = mini(fz, maxi(0, R().fuse_groups().size() - 1))
	fr_show = false
	fr_got = ""
	gone.clear()
	rc_off = 0
	match np:
		"up":
			var it = cur()
			if it == null: say("올릴 게 없군요. 모루를 눌러 골라 주십쇼.")
			elif not R().has_rune_item(it): say("강화는 룬에 하는 겁니다. 쇠는 그대로 두고요. 흐흐.")
			else: say(["쾅, 쾅. 이번엔 제대로 박아 보지요.", "흐흐, 뭘 손봐 드릴까요?", "엄, 거기 올려 두십쇼. 어디 봅시다."][randi() % 3])
		"eng":
			say("룬 박으러 오셨지요? 화로는 달궈놨습니다." if cur() != null else "모루 쪽에서 장비부터 골라 주십쇼.")
		"fuse":
			mark("slots")
			say("셋을 녹이면 하나가 나옵니다. 운이 좋으면요. 흐흐.")
		"dis":
			var keep := {}
			for i in dis.keys(): if i < R().gearbag.size(): keep[i] = 1
			dis = keep
			say("부술 건 골라만 주십시오. 쇳물은 버리지 않습니다.")
	if entering: in_t = t + 33.0
	sel_t = 9999.0

## goP: the rail answers, the sheet turns in the next colour, the station snaps in under it
func go_station(np: String) -> void:
	if np == p or wiping or busy > 0: return
	wiping = true
	clk["rail_from"] = _ai(sp)
	clk["slab_from"] = sp
	clk["snap_from"] = p
	sp = np
	mark("rail")
	mark("slab")
	mark("wipe")
	clk["wipe_to"] = _ai(np)
	sfx("ui_move", 0.5)
	var op := p
	after(500.0, func():
		p = np
		it_off = 3
		list_off = 0.0
		_pane_init(np)
		rc_off = 3
		mark("snap")
		wiping = false)

func _row_pick(i: int) -> void:
	if p == "eng":
		if i == eng: return
		prev_sel = eng
		eng = i
	elif p == "fuse":
		if i == fz: return
		prev_sel = fz
		fz = i
		mark("slots")
	sel_t = 0.0

## kick: the quad behind a piece swings from far round (.5 s)
func kick(n: String) -> void:
	mark("kick_" + n)

func jolt() -> void:
	mark("shake")

func burst(at: Vector2, n: int, col := Color("#ffd36a")) -> void:
	for i in n:
		var a := randf() * TAU
		var d := 50.0 + randf() * 140.0
		sparks.append({"x": at.x, "y": at.y, "dx": cos(a) * d, "dy": sin(a) * d - 30.0, "t": 0.0, "d": 450.0 + randf() * 300.0, "c": col})

## stampRes: a new banner on top; the ones under it sink
func stamp_res(s: String, fail: bool, sub := "", big := "") -> void:
	for o in stamps:
		if o["sink"] < 0.0 or o["sink"] > t: o["sunk"] = t + 200.0
	var o := {"s": s, "fail": fail, "sub": sub, "big": big, "t0": t, "sink": t + 850.0, "sunk": -1.0}
	stamps.append(o)
	mark("fflash")

func _anvil_c() -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(vs.x * 0.39, vs.y * 0.48)

## upHit
func do_up() -> void:
	var it = cur()
	if it == null or busy > 0: return
	if not R().has_rune_item(it):
		say("각인된 룬이 없습니다. 강화는 룬에 하는 겁니다.")
		return
	var lv := int(it.get("rs", 1))
	if lv >= RN.RMAX:
		say("★%d입니다. 더 올릴 데가 없지요. 흐흐." % RN.RMAX)
		return
	if R().iron < RN.rs_cost(lv):
		say("실링이 모자랍니다. 던전에서 좀 벌어 오십쇼.")
		sfx("guard", 0.4)
		return
	busy = 1
	hold["rs"] = lv
	hold["card"] = lv
	var rn: String = RN.RUNE[it["rune"]]["n"]
	var res: String = R().star_up(c, slot, _bonus())
	var ok := res == "ok"
	if arena.get("fame") != null: arena.fame.finc("enh")
	var strike := func():
		kick("anvil")
		jolt()
		mark("bright")
		sfx("heavy", 0.7)
		hold.erase("rs")
		var st := int(it.get("rs", 1))
		stamp_res("SUCCESS" if ok else "MISS", not ok, ("[%s] ★%d" % [rn, st]) if ok else "룬이 안 받는다… (★ 유지)", ("★%d" % st) if ok else "")
		burst(_anvil_c(), 22)
		say((("★%d. 흐흐, 이건 좀 자랑해도 되겠는데요." % st) if st >= 6 else ("쾅, 쾅. ★%d 됐습니다." % st)) if ok else ["…룬이 안 받는군요. 다시 새겨 보지요.", "흠. 이번 건 망치가 비껴 맞았습니다.", "허, 금이 갈 뻔했습니다. 별은 그대로입니다."][randi() % 3])
		after(420.0, func(): hold.erase("card"))
	if lv >= 6:
		mark("cut")
		_sink_all()
		after(340.0, func():
			mark("cutflash")
			strike.call())
		after(700.0, func(): mark("cutout"))
		after(920.0, func():
			clk.erase("cut")
			_bran_back()
			busy = 0)
		return
	bran_hit = true
	clk.erase("hitout")
	clk.erase("hit2")
	mark("hit")
	_sink_all()
	after(150.0, func():
		strike.call()
		mark("hit2"))
	after(450.0, func(): mark("hitout"))
	after(610.0, func():
		bran_hit = false
		clk.erase("hit")
		_bran_back()
		busy = 0)

## fBonus('enh'): +10 %p once the guild's bellows are restored
func _bonus() -> int:
	return arena.fame.f_bonus("enh") if arena.get("fame") != null else 0

func _bran_back() -> void:
	mark("branback")

func _sink_all() -> void:
	for o in stamps:
		if o["sunk"] < 0.0 and (o["sink"] > t): o["sunk"] = t + 200.0

## the 각인 card's button: the rune flies from its row into the socket
func do_eng() -> void:
	var it = cur()
	var L: Array = R().eng_list(c, slot)
	if busy > 0 or it == null or L.is_empty(): return
	var r: String = L[mini(eng, L.size() - 1)]
	var cost := RN.engrave_cost(RN.RUNE[r]["g"])
	if R().iron < cost:
		say("실링이 모자랍니다.")
		return
	busy = 1
	var vs := get_viewport_rect().size
	var from := _rc_gem(vs, eng)
	var to := _ecirc_c(vs) + Vector2(0, -_ecirc_w(vs) / 2.0)
	fly = {"from": from, "to": to, "g": RN.gcol(RN.RUNE[r]["g"]), "t0": t}
	hold["sock"] = 1
	R().iron -= cost
	after(380.0, func():
		fly = {}
		R().iron += cost
		R().engrave(c, slot, r)
		hold.erase("sock")
		jolt()
		sfx("heavy", 0.6)
		mark("ebright")
		kick("ecirc")
		mark("sock")
		burst(to, 16, RN.gcol(RN.RUNE[r]["g"]))
		_sink_all()
		stamp_res("ENGRAVED", false, "[%s] 각인 완료" % RN.RUNE[r]["n"])
		say("%s, 단단히 박아 뒀습니다. 흐흐, 이 정도면 변명이 좀 되겠지요?" % RN.RUNE[r]["n"])
		rc_off = 0
		eng = mini(eng, maxi(0, R().eng_list(c, slot).size() - 1))
		busy = 0)

## the 합성 card's button: three gems gather, then one comes out (or one is handed back)
func do_fuse() -> void:
	var G: Array = R().fuse_groups()
	if busy > 0 or G.is_empty(): return
	var x: Dictionary = G[mini(fz, G.size() - 1)]
	var up := RN.up_grade(x["g"])
	if x["c"] < 3:
		say("셋은 있어야 녹이지요. 지금은 %d개뿐입니다." % x["c"])
		return
	if R().iron < RN.FUSE_COST:
		say("실링이 모자랍니다.")
		return
	busy = 1
	mark("gather")
	after(420.0, func():
		var res: Dictionary = R().fuse(x["g"])
		jolt()
		if res.is_empty() or not res["ok"]:
			sfx("guard", 0.6)
			kick("fr")
			fr_got = "…"
			_sink_all()
			stamp_res("MISS", true, "[%s] 하나만 남았다" % (RN.RUNE[res["got"]]["n"] if not res.is_empty() else "?"))
			say(["…셋이 하나로 안 붙는군요. 하나는 건졌습니다.", "흠. 이번엔 녹기만 했습니다. 하나는 돌려드리지요."][randi() % 2])
		else:
			if arena.get("fame") != null: arena.fame.finc("fuse")
			sfx("heavy", 0.6)
			mark("fflash8")
			mark("tri")
			kick("fr")
			fr_show = true
			mark("frg")
			fr_got = "[%s]" % RN.RUNE[res["got"]]["n"]
			burst(_fr_c(get_viewport_rect().size), 22, RN.gcol(up))
			_sink_all()
			stamp_res("FUSED", false, "%s [%s]" % [RN.gname(up), RN.RUNE[res["got"]]["n"]])
			say("나왔습니다. [%s]. %s급이군요. 흐흐." % [RN.RUNE[res["got"]]["n"], RN.gname(up)])
		var L: Array = R().fuse_groups()
		fz = 0
		for i in L.size():
			if L[i]["g"] == x["g"]: fz = i
		rc_off = 0
		after(900.0, func():
			clk.erase("gather")
			fr_show = false
			fr_got = ""
			mark("slots")
			busy = 0))

## the 분해 card's button: the picked tiles crack in two, one after another, then the shilling
func do_dis() -> void:
	if busy > 0: return
	if dis.is_empty():
		say("뭘 부술지는 정해 주셔야지요.")
		return
	busy = 1
	var vs := get_viewport_rect().size
	var tiles: Array = []
	var V := _dis_list()
	for k in V.size():
		if dis.has(V[k]): tiles.append([V[k], k])
	for j in tiles.size():
		var bi: int = tiles[j][0]
		var k: int = tiles[j][1]
		after(j * 90.0, func(): mark("dt%d" % bi))
		after(j * 90.0 + 110.0, func():
			gone[bi] = 1
			var r := _dt_rect(vs, k)
			halves.append({"bi": bi, "k": k, "t": 0.0, "s": -1})
			halves.append({"bi": bi, "k": k, "t": 0.0, "s": 1})
			burst(r.get_center(), 10, Color("#ff9d6a"))
			sfx("heavy", 0.35))
	after(tiles.size() * 90.0 + 420.0, func():
		jolt()
		var sil: int = R().salvage(dis.keys())
		dis = {}
		gone.clear()
		_sink_all()
		stamp_res("SALVAGED", false, "실링 +%d" % sil, "+%d" % sil)
		say("실링 %d. 장부에 달아 두지요." % sil)
		busy = 0)

## gearPick
func picking_open() -> void:
	if busy > 0: return
	var it = cur()
	gs = "rune" if p == "up" else ("rune" if it != null and R().has_rune_item(it) else "plain")
	picking = true
	pick_closing = false
	mark("pick")
	sfx("ui_ok", 0.5)

func gear_close(then: Callable) -> void:
	if pick_closing: return
	pick_closing = true
	mark("pickx")
	after(250.0, func():
		picking = false
		pick_closing = false
		if then.is_valid(): then.call())

func picking_close() -> void:
	gear_close(Callable())

func dis_toggle(bi: int) -> void:
	if dis.has(bi): dis.erase(bi)
	else: dis[bi] = 1
	mark("dsel%d" % bi)


# ---------- drawing ----------
func _paint(vs: Vector2) -> void:
	hb.clear()
	var col := tcol()
	draw_rect(Rect2(Vector2.ZERO - Vector2(20, 20), vs + Vector2(40, 40)), FBG[p])
	_fire(vs)
	if not wiping: _slab(vs, col)
	_shd(vs)
	var u := fmod(t / 6000.0, 1.0)
	var off := Vector2(-44.0 * u, 22.0 * u)
	draw_texture_rect(UI.dot_tile(0.104), Rect2(Vector2(fposmod(off.x, 11.0), fposmod(off.y, 11.0)) - Vector2(11, 11), vs + Vector2(22, 22)), true)
	_bigen(vs)
	match p:
		"up": _up(vs, col)
		"eng": _eng(vs, col)
		"fuse": _fuse(vs, col)
		"dis": _dis(vs, col)
	if wiping: _wipe(vs, col)
	if wiping: _slab(vs, col)
	_title(vs)
	_rail(vs, col)
	if picking: _pick(vs, col)
	var ff := since("fflash")
	if ff < 240.0: draw_rect(Rect2(Vector2.ZERO - Vector2(20, 20), vs + Vector2(40, 40)), Color(1, 1, 1, 0.7 * (1.0 - AE.ez("ease-out", ff / 240.0))))
	var f8 := since("fflash8")
	if f8 < 300.0: draw_rect(Rect2(Vector2.ZERO - Vector2(20, 20), vs + Vector2(40, 40)), Color(1, 1, 1, 0.8 * (1.0 - AE.ez("ease-out", f8 / 300.0))))
	for q in sparks:
		var k := UI.bez(0.2, 0.8, 0.4, 1.0, q["t"] / q["d"])
		var pc := Vector2(q["x"] + q["dx"] * k, q["y"] + q["dy"] * k)
		draw_set_transform(pc, PI * k)
		draw_rect(Rect2(-4, -4, 8, 8), Color(q["c"], 1.0 - k))
	draw_set_transform(Vector2.ZERO)
	_halves(vs)
	if not fly.is_empty(): _fly()
	if p == "up": _bran_hit(vs)
	# z order as ZC: the cut-in (raised at the tap) under the banner its hit stamps (raised later)
	if clk.has("cut"): _cut(vs, col)
	for o in stamps: _rbig(vs, col, o)
	close_x(vs, back)
	for h in hb: hit(h[0], h[1])

## the ✕ (right 14, top 12) as the bag's
func close_x(vs: Vector2, cb: Callable) -> void:
	var c0 := Vector2(vs.x - 14.0 - 18.0, 12.0 + 18.0)
	draw_circle(c0 + Vector2(3, 3), 18.0, tcol())
	draw_circle(c0, 18.0, Color.WHITE)
	draw_circle(c0, 16.0, Color.BLACK)
	UI.cross(self, c0, 4.5, Color.WHITE, 2.0)
	hb.append([Rect2(c0 - Vector2(18, 18), Vector2(36, 36)), cb])

## .fire: two radial glows (60 % × 50 % at 46 % 66 % in --gl, 26 % × 18 % warm core), flicker to .75 (1.8 s alternate)
var _glow_tex: GradientTexture2D
func _fire(vs: Vector2) -> void:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	var ph := fmod(t / 1800.0, 2.0)
	var fl := AE.ez("ease-in-out", ph if ph < 1.0 else 2.0 - ph)
	var a := lerpf(1.0, 0.75, fl)
	var gt := since("snap")
	var gc: Color = GL[p]
	var fa := AE.ez(EZ, gt / 460.0) if gt < 460.0 else 1.0
	var c0 := Vector2(vs.x * 0.46, vs.y * 0.66)
	draw_texture_rect(_glow_tex, Rect2(c0 - Vector2(vs.x * 0.6, vs.y * 0.5), Vector2(vs.x * 1.2, vs.y * 1.0)), false, Color(gc, gc.a * a * fa))
	var c1 := Vector2(vs.x * 0.46, vs.y * 0.68)
	draw_texture_rect(_glow_tex, Rect2(c1 - Vector2(vs.x * 0.26, vs.y * 0.18), Vector2(vs.x * 0.52, vs.y * 0.36)), false, Color(1.0, 0.9, 0.627, 0.35 * a * fa))

## .slab: her colour; per station its right / width / angle / clip, .7 s --ez from the tap
func _slab(vs: Vector2, col: Color) -> void:
	var k := AE.ez(EZ, since("slab") / 700.0) if clk.has("slab") else 1.0
	var a: Array = SLAB[clk.get("slab_from", sp)] if k < 1.0 else SLAB[sp]
	var b: Array = SLAB[sp]
	var right := lerpf(a[0], b[0], k)
	var w := lerpf(a[1], b[1], k) * vs.x / 100.0
	var rot := lerpf(a[2], b[2], k)
	var pct: Array = []
	for i in 4: pct.append([lerpf(a[3][i][0], b[3][i][0], k), lerpf(a[3][i][1], b[3][i][1], k)])
	var r := Rect2(vs.x - right * vs.x / 100.0 - w, -vs.y * 0.2, w, vs.y * 1.5)
	draw_colored_polygon(poly(Rect2(Vector2.ZERO, r.size), pct, xf(r.position, r.size / 2.0, rot)), col)

## .shd: the station's shade; it snaps with the station and slides in from -40 % (460 ms, 70 ms late)
func _shd(vs: Vector2) -> void:
	var s: Array = SHD[p]
	var r := Rect2(vs.x * s[0] / 100.0, vs.y * s[1] / 100.0, vs.x * s[2] / 100.0, vs.y * s[3] / 100.0)
	var gt := since("snap")
	var k := AE.ez(EZ, (gt - 70.0) / 460.0) if gt < 530.0 else 1.0
	var op: float = s[5] * k
	if op <= 0.0: return
	var m := xf(r.position + Vector2(-0.4 * r.size.x * (1.0 - k), 0), r.size / 2.0, s[4])
	draw_colored_polygon(poly(Rect2(Vector2.ZERO, r.size), s[6], m), Color(0, 0, 0, 0.6 * op))

## .bigen: ENHANCE · ×4, 150 px Anton italic, hollow (2 px white .1), -8° about its bottom-left, drifting -50 % in 36 s
func _bigen(vs: Vector2) -> void:
	var f := UI.anton(true)
	var s: String = (ACTS[_pi()][2] + " · ").repeat(4)
	var w := tw(f, s, 150)
	var gt := since("snap")
	var k := AE.ez(EZ, (gt - 130.0) / 460.0) if gt < 590.0 else 1.0
	var dx := -fmod(t / 36000.0, 1.0) * w * 0.5 - 0.3 * w * (1.0 - k)
	var m := xf(Vector2(-vs.x * 0.02 + dx, vs.y * 1.06 - 150.0), Vector2(0, 150), -8.0)
	draw_set_transform_matrix(m)
	draw_string_outline(f, Vector2(0, f.get_ascent(150)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 150, 2, Color(1, 1, 1, 0.1 * k))
	draw_set_transform(Vector2.ZERO)

## .fwipe .wm: a 250vmax square in the next colour turning 0 → 91° about the bottom-left corner (500 ms)
func _wipe(vs: Vector2, _col: Color) -> void:
	var k := UI.bez(0.6, 0.02, 0.3, 1.0, clampf(since("wipe") / 500.0, 0.0, 1.0))
	var S := maxf(vs.x, vs.y) * 2.5
	var piv := Vector2(0, vs.y)
	var a := deg_to_rad(91.0 * k)
	var pts := PackedVector2Array()
	for q in [Vector2(-S, -S), Vector2(0, -S), Vector2(0, 0), Vector2(-S, 0)]: pts.append(piv + q.rotated(a))
	draw_colored_polygon(pts, FBG[sp])

## .ttl + .fcash
func _title(vs: Vector2) -> void:
	var bf := UI.bhs()
	var tm := xf(Vector2(20, 14), Vector2.ZERO, -6.0)
	draw_set_transform_matrix(tm)
	txt(self, UI.anton(false, 3), 0, 0, "BRAN'S FORGE", 11, Color(1.0, 0.69, 0.44, 0.7), 12.0)
	var tw0 := tw(bf, "대장간", 34) + 24.0
	var bm := tm * xf(Vector2(0, 12), Vector2(tw0 / 2.0, 21.0), 0, 1, -12.0)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(poly(Rect2(0, 0, tw0, 42), SQ, bm), Color.BLACK)
	draw_set_transform_matrix(bm)
	txt(self, bf, 10, 2, "대장간", 34, Color.WHITE, 35.7)
	# .fcash (22, 62): rotate(-6°) skewX(-8°), 실링 + the number in Anton
	var f := UI.noto()
	var n := loc(R().iron)
	var w := 10.0 + tw(f, "실링", 12) + 4.0 + tw(UI.anton(), n, 15) + 10.0
	var cm := xf(Vector2(22, 62), Vector2(w / 2.0, 10.0), -6.0, 1.0, -8.0)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(poly(Rect2(0, 0, w, 20), SQ, cm), Color.BLACK)
	draw_set_transform_matrix(cm)
	var x := 10.0 + txt(self, f, 10, 1, "실링", 12, Color(0.867, 0.867, 0.867), 18.0) + 4.0
	txt(self, UI.anton(), x, 1, n, 15, Color("#ffd34d"), 18.0)
	draw_set_transform(Vector2.ZERO)

static func loc(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

## .frail: right 14, 148 wide, centred between 58 and 44 from the bottom; .fb shifted 7 px a step, the picked one
## white, 28 px further left and ×1.1 (.4 s --bk); .fcur, striped, trails it (.45 s --bk)
func _rail(vs: Vector2, col: Color) -> void:
	var x0 := vs.x - 14.0 - 148.0
	var bh := 44.0
	var y0 := 58.0 + ((vs.y - 58.0 - 44.0) - (4.0 * bh + 27.0)) / 2.0
	var cur_i := _ai(sp)
	var prev_i: int = clk.get("rail_from", cur_i)
	var k := UI.bk(clampf(since("rail") / 400.0, 0.0, 1.0)) if clk.has("rail") else 1.0
	var kc := UI.bk(clampf(since("rail") / 450.0, 0.0, 1.0)) if clk.has("rail") else 1.0
	var kb := clampf(since("rail") / 150.0, 0.0, 1.0) if clk.has("rail") else 1.0
	# the cursor
	var cy := lerpf(y0 + prev_i * (bh + 9.0), y0 + cur_i * (bh + 9.0), kc) + 7.0
	var cx := x0 + lerpf(prev_i * -7.0 - 28.0 + 9.0, cur_i * -7.0 - 28.0 + 9.0, kc)
	var cr := Rect2(cx, cy, 148, bh)
	var cpol := poly(cr, [[7, 0], [100, 0], [93, 100], [0, 100]], Transform2D.IDENTITY)
	draw_colored_polygon(cpol, Color.BLACK)
	var sx := cx - bh
	while sx < cx + 148.0:
		var sp2 := Geometry2D.intersect_polygons(cpol, PackedVector2Array([Vector2(sx + 7, cy + bh), Vector2(sx + 9, cy + bh), Vector2(sx + 9 + bh * 0.466, cy), Vector2(sx + 7 + bh * 0.466, cy)]))
		for q in sp2: draw_colored_polygon(q, Color(1, 1, 1, 0.22))
		sx += 9.0 / 0.906
	for i in 4:
		var on := i == cur_i
		var amt := k if on else ((1.0 - k) if i == prev_i and prev_i != cur_i else 0.0)
		var bgk := kb if on else ((1.0 - kb) if i == prev_i and prev_i != cur_i else 0.0)
		var y := y0 + i * (bh + 9.0)
		var m := xf(Vector2(x0 + i * -7.0 - 28.0 * amt, y), Vector2(74, bh / 2.0), 0.0, lerpf(1.0, 1.1, amt))
		var pts := poly(Rect2(0, 0, 148, bh), [[7, 0], [100, 0], [93, 100], [0, 100]], m)
		draw_colored_polygon(pts, Color.BLACK.lerp(Color.WHITE, bgk))
		var fc := Color.WHITE.lerp(Color.BLACK, bgk)
		draw_set_transform_matrix(m * xf(Vector2(13, bh / 2.0 - 12.0), Vector2(12, 12), 0, 1, -8.0))
		txt(self, UI.anton(), 0, 0, "0%d" % (i + 1), 24, col.lerp(Color.BLACK, bgk), 24.0)
		draw_set_transform_matrix(m)
		txt(self, UI.anton(false, 2), 46, 5, ACTS[i][2], 9, Color(1.0, 0.69, 0.44).lerp(Color(0, 0, 0, 0.55), bgk), 10.0)
		txt(self, UI.bhs(), 46, 15, ACTS[i][1], 22, fc, 23.1)
		draw_set_transform(Vector2.ZERO)
		var np: String = ACTS[i][0]
		hb.append([pts, func(): go_station(np)])

## the parts' entrance (.fp.in .it → none): 70 px, 5°, .5 s --bk; opacity .3 s; 45 ms × --i late
func _it(i: int) -> Dictionary:
	var e := t - in_t - (i + it_off) * 45.0
	if t < in_t: e = -1.0
	var k := UI.bk(clampf(e / 500.0, 0.0, 1.0))
	return {"x": 70.0 * (1.0 - k), "r": 5.0 * (1.0 - k), "a": AE.ez("ease", clampf(e / 300.0, 0.0, 1.0))}

func _itm(m: Transform2D, pivot: Vector2, e: Dictionary) -> Transform2D:
	# CSS translate / rotate (individual properties) go before the element's own transform, about its origin
	return Transform2D(0.0, Vector2(e["x"], 0)) * Transform2D(0.0, pivot) * Transform2D(deg_to_rad(e["r"]), Vector2.ZERO) * Transform2D(0.0, -pivot) * m

## the speech bubble: Bran over the anvil (up) or the portrait chip top right (b2)
func _bub(vs: Vector2, idx: int) -> void:
	var f := UI.noto()
	var b2 := p != "up"
	var maxw := vs.x * (0.34 if b2 else 0.26)
	var padl := 52.0 if b2 else 18.0
	var padr := 16.0 if b2 else 18.0
	var padt := 9.0 if b2 else 12.0
	var padb := 10.0 if b2 else 12.0
	var shown := msg.substr(0, mini(msg.length(), 1 + int(msg_t / 28.0)))
	var full: Array = flow([[msg, f, 13, Color.BLACK]], maxw - padl - padr)
	var lines: Array = flow([[shown, f, 13, Color.BLACK]], maxw - padl - padr)
	var w := minf(maxw, flow_w(lines) + padl + padr)
	var h := padt + maxf(1, lines.size()) * 19.5 + padb
	var pos := Vector2(vs.x - 14.0 - 178.0 - w, 12.0) if b2 else Vector2(vs.x * 0.24, vs.y * 0.12)
	# .stamp (.5 s --bk): from ×2.2, -12°, clear
	var ks := UI.bk(clampf(msg_t / 500.0, 0.0, 1.0))
	var e := _it(idx)
	var m := xf(pos, Vector2(w, h) / 2.0, lerpf(-12.0, -4.0, ks), lerpf(2.2, 1.0, ks))
	m = _itm(m, pos + Vector2(w, h) / 2.0, e)
	var a: float = clampf(ks, 0.0, 1.0) * e["a"]
	draw_colored_polygon(poly(Rect2(0, 0, w, h), [[0, 6], [100, 0], [96, 88], [30, 92], [18, 100], [20, 92], [3, 96]], m), Color(1, 1, 1, a))
	if b2:
		var pc := m * Vector2(8 + 18, h / 2.0)
		draw_circle(pc, 20.0, Color(0, 0, 0, a))
		draw_circle(pc, 18.0, Color(0.133, 0.133, 0.133, a))
		var ts := POR.get_size()
		var sw := 86.4
		var sh2 := ts.y * sw / ts.x
		var ox := (sw - 36.0) * 0.46
		var oy := (sh2 - 36.0) * 0.06
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 24:
			var an := TAU * i / 24.0
			var lp := Vector2(18, 18) + Vector2.from_angle(an) * 18.0
			pts.append(pc + Vector2.from_angle(an) * 18.0)
			uvs.append(Vector2((ox + lp.x) / sw, (oy + lp.y) / sh2))
		draw_colored_polygon(pts, Color(1, 1, 1, a), uvs, POR)
	draw_set_transform_matrix(m)
	draw_flow(self, lines, padl, padt, 19.5, a)
	draw_set_transform(Vector2.ZERO)

## .qd: three tilted quads behind a piece (white, her colour, black with hatching), each swaying on its own clock;
## kick: they swing in from far round (.5 s)
func _qd(r: Rect2, col: Color, kick_ms: float, a := 1.0) -> void:
	var kk := UI.bez(0.2, 1.4, 0.4, 1.0, clampf(kick_ms / 500.0, 0.0, 1.0))
	var sw := func(per: float) -> float:
		var u := fmod(t / per, 2.0)
		return AE.ez("ease-in-out", u if u < 1.0 else 2.0 - u)
	var qa := lerpf(-9.0, -4.0, sw.call(3400.0))
	var qas := lerpf(1.0, 1.02, sw.call(3400.0))
	var qb := lerpf(7.0, 13.0, sw.call(2800.0))
	var qbs := lerpf(1.0, 0.97, sw.call(2800.0))
	var qc := lerpf(-2.0, 3.0, sw.call(3000.0))
	if kick_ms < 500.0:
		qa = lerpf(-40.0, qa, kk)
		qas = lerpf(1.3, qas, kk)
		qb = lerpf(50.0, qb, kk)
		qbs = lerpf(1.25, qbs, kk)
	var ra := r
	draw_colored_polygon(poly(Rect2(Vector2.ZERO, ra.size), [[3, 12], [97, 0], [100, 86], [0, 100]], xf(ra.position, ra.size / 2.0, qa, qas)), Color(1, 1, 1, a))
	var rb := r.grow(-r.size.x * 0.05)
	draw_colored_polygon(poly(Rect2(Vector2.ZERO, rb.size), [[0, 3], [100, 15], [93, 100], [7, 89]], xf(rb.position, rb.size / 2.0, qb, qbs)), Color(col, a))
	var rc := r.grow(-r.size.x * 0.17)
	var mc := xf(rc.position, rc.size / 2.0, qc)
	var pc := poly(Rect2(Vector2.ZERO, rc.size), [[9, 0], [100, 7], [90, 95], [0, 100]], mc)
	draw_colored_polygon(pc, Color(0, 0, 0, a))
	var s := -rc.size.y
	while s < rc.size.x + rc.size.y:
		var band := PackedVector2Array([mc * Vector2(s + 9, 0), mc * Vector2(s + 11, 0), mc * Vector2(s + 11 + rc.size.y * 0.577, rc.size.y), mc * Vector2(s + 9 + rc.size.y * 0.577, rc.size.y)])
		for q in Geometry2D.intersect_polygons(pc, band): draw_colored_polygon(q, Color(1, 1, 1, 0.07 * a))
		s += 11.0 / 0.866

## Bran: his portrait (drop shadows 10 px black, -3 px white), the hammer pose over it on a strike
func _bran(vs: Vector2, e: Dictionary) -> void:
	var h := vs.y * 0.98
	var w := h * POR.get_width() / POR.get_height()
	var r := Rect2(-vs.x * 0.02, vs.y + vs.y * 0.06 - h, w, h)
	var bk := since("branback")
	var a: float = e["a"]
	var bx := 0.0
	if bran_hit or clk.has("cut"): a = 0.0
	elif bk < 220.0:
		var kk := UI.bez(0.16, 1.0, 0.3, 1.0, bk / 220.0)
		a *= kk
		bx = -0.05 * w * (1.0 - kk)
	if a > 0.0:
		var m := _itm(Transform2D(0.0, r.position + Vector2(bx, 0)), r.position + r.size / 2.0, e)
		_sil(POR, m, r.size, a)

## .bran.bh: the hammer pose, raised (zIndex = ++ZC) over the white .fflash, under the banners
func _bran_hit(vs: Vector2) -> void:
	if bran_hit:
		var h2 := vs.y * 1.04
		var w2 := h2 * HIT.get_width() / HIT.get_height()
		var r2 := Rect2(-vs.x * 0.06, vs.y + vs.y * 0.08 - h2, w2, h2)
		var ht := since("hit")
		var tr := Vector2.ZERO
		var sc := 1.0
		var bri := 1.0
		var ha := 1.0
		if ht < 150.0:
			var kk := UI.bez(0.2, 0.9, 0.3, 1.0, clampf(ht / 130.0, 0.0, 1.0))
			tr = Vector2(-0.03 * w2, 0.03 * h2).lerp(Vector2(0.01 * w2, -0.02 * h2), kk)
			sc = lerpf(1.04, 0.99, kk)
		else:
			var h2t := since("hit2")
			if h2t < 90.0:
				var kk := AE.ez("ease-out", h2t / 90.0)
				tr = Vector2(0.02 * w2, 0.04 * h2).lerp(Vector2.ZERO, kk)
				sc = lerpf(1.07, 1.0, kk)
				bri = lerpf(5.0, 1.0, kk)
		var ho := since("hitout")
		if ho < 1e8: ha = 1.0 - clampf(ho / 160.0, 0.0, 1.0)
		var m2 := Transform2D(0.0, r2.position + r2.size / 2.0 + tr) * Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO) * Transform2D(0.0, -r2.size / 2.0)
		if bri > 1.0:
			# b1.animate filter brightness(5) saturate(0) → none (90 ms): the animated filter replaces the drop shadows
			draw_set_transform_matrix(m2)
			draw_texture_rect(HIT, Rect2(Vector2.ZERO, r2.size), false, Color(bri, bri, bri, ha))
			draw_set_transform(Vector2.ZERO)
		else:
			_sil(HIT, m2, r2.size, ha, bri)

## an image with the CSS drop-shadow(10px 0 0 #000) drop-shadow(-3px 0 0 #fff) pair
func _sil(tex: Texture2D, m: Transform2D, size: Vector2, a: float, bri := 1.0) -> void:
	draw_set_transform_matrix(Transform2D(0.0, Vector2(-3, 0)) * m)
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(60, 60, 60, a))
	draw_set_transform_matrix(Transform2D(0.0, Vector2(7, 0)) * m)
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(60, 60, 60, a))
	draw_set_transform_matrix(Transform2D(0.0, Vector2(10, 0)) * m)
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(0, 0, 0, a))
	draw_set_transform_matrix(m)
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false, Color(bri, bri, bri, a))
	draw_set_transform(Vector2.ZERO)

## a diamond piece (.wpn / .item): gradient, 5 px white rim, 8 px shadow, bobbing 8 px (2.4 s)
func _piece(c0: Vector2, s: float, g0: Color, g1: Color, a: float, drop_ms := 1e9) -> void:
	var u := fmod(t / 2400.0, 1.0)
	var bob := -8.0 * (AE.ez("ease-in-out", u * 2.0) if u < 0.5 else 1.0 - AE.ez("ease-in-out", (u - 0.5) * 2.0))
	var rot := 45.0
	var sc := 1.0
	var dy := bob
	var aa := a
	if drop_ms < 420.0:
		var kk := UI.bez(0.2, 0.9, 0.3, 1.0, drop_ms / 420.0)
		if kk < 0.7:
			var q := kk / 0.7
			dy = lerpf(-60.0, 6.0, q)
			rot = lerpf(225.0, 45.0, q)
			sc = lerpf(0.4, 1.1, q)
			aa = a * q
		else:
			var q := (kk - 0.7) / 0.3
			dy = lerpf(6.0, 0.0, q)
			sc = lerpf(1.1, 1.0, q)
	var m := Transform2D(deg_to_rad(rot), Vector2(sc, sc), 0.0, c0 + Vector2(0, dy))
	var hs := s / 2.0
	var sq := func(r: float, o := Vector2.ZERO) -> PackedVector2Array:
		return PackedVector2Array([m * (Vector2(-r, -r) + o), m * (Vector2(r, -r) + o), m * (Vector2(r, r) + o), m * (Vector2(-r, r) + o)])
	draw_colored_polygon(sq.call(hs, Vector2(8, 8)), Color(0, 0, 0, aa))
	draw_colored_polygon(sq.call(hs), Color(1, 1, 1, aa))
	var inner: PackedVector2Array = sq.call(hs - 5.0)
	# linear-gradient(135deg, g0 → g1 70 %): along the square's diagonal
	draw_polygon(inner, PackedColorArray([Color(g0, aa), Color(g0.lerp(g1, 0.71), aa), Color(g1, aa), Color(g0.lerp(g1, 0.71), aa)]))

## 강화
func _up(vs: Vector2, col: Color) -> void:
	var it = cur()
	_bran(vs, _it(0))
	_bub(vs, 1)
	# .anvil: left 39 %, top 48 %, 150 px; .qd inset 6 %; .wpn inset 30 %; .lv ★n above; .anm name + TAP below
	var e := _it(2)
	var aw := minf(vs.y * 0.36, 150.0)
	var ac := _anvil_c()
	var ar := Rect2(ac - Vector2(aw, aw) / 2.0, Vector2(aw, aw))
	var m := _itm(Transform2D.IDENTITY, ac, e)
	draw_set_transform_matrix(m)
	_qd(ar.grow(-aw * 0.06), col, since("kick_anvil"), e["a"])
	var hr: bool = it != null and R().has_rune_item(it)
	var g := Color("#9aa3b5")
	if it != null: g = RN.gcol(RN.RUNE[it["rune"]]["g"] if hr else it["g"])
	draw_set_transform_matrix(m)
	_piece(ac, aw * 0.4, Color.WHITE, g, e["a"], since("drop"))
	var st := int(hold.get("rs", int(it.get("rs", 1)) if it != null else 1))
	var lv := ("★%d" % st) if hr else ("—" if it != null else "")
	var f := UI.anton(true)
	var lm := m * xf(Vector2(ac.x - tw(f, lv, 46) / 2.0, ar.position.y - aw * 0.06), Vector2(tw(f, lv, 46) / 2.0, 23.0), -6.0)
	draw_set_transform_matrix(lm * Transform2D(0.0, Vector2(4, 4)))
	txt(self, f, 0, 0, lv, 46, Color(0, 0, 0, e["a"]), 46.0)
	draw_set_transform_matrix(lm)
	txt(self, f, 0, 0, lv, 46, Color(1, 1, 1, e["a"]), 46.0)
	var nm: String = (RN.RUNE[it["rune"]]["n"] if hr else it["n"] + " · 룬 없음") if it != null else "장비 없음"
	var bf := UI.bhs()
	var nw := tw(bf, nm, 15) + 24.0 + (8.0 + tw(UI.anton(false, 2), "TAP", 9) if it != null else 0.0)
	var nmm := m * xf(Vector2(ac.x - nw / 2.0, ar.end.y), Vector2(nw / 2.0, 12.0), -4.0)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(poly(Rect2(4, 4, nw, 24), SQ, nmm), Color(col, e["a"]))
	draw_colored_polygon(poly(Rect2(0, 0, nw, 24), SQ, nmm), Color(0, 0, 0, e["a"]))
	draw_set_transform_matrix(nmm)
	var x := 12.0 + txt(self, bf, 12, 2, nm, 15, Color(1, 1, 1, e["a"]), 19.0)
	if it != null: txt(self, UI.anton(false, 2), x + 8.0, 5, "TAP", 9, Color(1.0, 0.69, 0.44, e["a"]), 12.0)
	draw_set_transform(Vector2.ZERO)
	hb.append([poly(Rect2(ar.position - Vector2(0, aw * 0.1), Vector2(aw, aw * 1.3)), SQ, Transform2D.IDENTITY), picking_open])
	_card(vs, col, _up_card(it), 3)

## the 강화 card's content
func _up_card(it) -> Dictionary:
	var f := UI.noto()
	var D := Color(0.867, 0.867, 0.867)
	if it == null:
		return {"ttl": "빈 칸", "runs": [[RN.SLOTN[slot] + " 칸이 비어 있습니다.\n모루를 눌러 장비를 고르세요.", f, 12, D]]}
	if not R().has_rune_item(it):
		return {"ttl": it["n"], "runs": [["각인된 룬이 없습니다.\n강화는 룬에 합니다. 각인부터 해 주십쇼.", f, 12, D]], "box": _box(it, RN.slot_kind(slot), "up", [], ""), "btn": "각인으로", "act": func(): go_station("eng")}
	var st := int(hold.get("card", int(it.get("rs", 1))))
	var mx := st >= RN.RMAX
	var cost := RN.rs_cost(st)
	var nx := 0 if mx else st + 1
	var head := ("★%d · 최대 성급" % RN.RMAX) if mx else ("★%d → ★%d · 성공 확률 %d%%" % [st, nx, mini(100, RN.rs_rate(st) + _bonus())])
	return {"ttl": RN.RUNE[it["rune"]]["n"], "runs": [[head, f, 12, D]], "box": _box(it, RN.slot_kind(slot), "up", _rune_line(it["rune"], st, nx), ("룬 ★%d" % st) + ("" if mx else " → ★%d" % nx)),
		"tail": [[RN.pname(c) + " · " + RN.SLOTN[slot] + ("" if mx else " · 실패해도 성급은 그대로"), f, 12, Color(0.6, 0.6, 0.6)]],
		"cost": "" if mx else ("실링 %d%s" % [cost, " · 모자랍니다" if R().iron < cost else ""]), "btn": "MAX" if mx else "때린다!", "dis": mx or R().iron < cost, "act": do_up}

## runeLine: [name] in its grade colour, "grade · ★st ×m (→ ★nx ×m)" dimmed, the scaled text, ▶ next in yellow
func _rune_line(r: String, st: int, nx := 0, fs := 11) -> Array:
	var f := UI.noto()
	var Rd: Dictionary = RN.RUNE[r]
	var out: Array = [["[" + Rd["n"] + "]", f, fs, RN.gcol(Rd["g"])], [" " + RN.gname(Rd["g"]) + " · ★%d ×%s" % [st, RN.fmt(RN.RSM[st])] + ((" → ★%d ×%s" % [nx, RN.fmt(RN.RSM[nx])]) if nx > 0 else ""), f, fs - 1, Color(0.867, 0.867, 0.867, 0.72)],
		["\n" + RN.rune_scaled(r, st), f, fs, Color(0.867, 0.867, 0.867)]]
	if nx > 0: out.append(["\n▶ " + RN.rune_scaled(r, nx), f, fs, Color("#ffd34d")])
	return out

## effBox(it, kind, ctx, runeHtml, label): two faces when a rune is set (or a comparison is given)
func _box(it: Dictionary, kind: String, ctx: String, rune_runs: Array, label: String) -> Dictionary:
	var f := UI.noto()
	var D := Color(0.867, 0.867, 0.867)
	var g: Array = [[it["n"] + " · " + RN.gname(it["g"]) + " · Lv %d" % int(it.get("lv", 0)), f, 10, Color(D, 0.72)], ["\n" + R().gear_text(it, kind), f, 11, D]]
	var has: bool = R().has_rune_item(it) or not rune_runs.is_empty()
	var rr := rune_runs
	if rr.is_empty() and R().has_rune_item(it): rr = _rune_line(it["rune"], int(it.get("rs", 1)))
	if label == "" and R().has_rune_item(it): label = "룬 효과 ★%d" % int(it.get("rs", 1))
	return {"ctx": ctx, "tabs": has, "g": g, "r": rr, "lab": label}

func _face(b: Dictionary) -> String:
	if not b["tabs"]: return "g"
	return rvm.get(b["ctx"], "g" if b["ctx"] == "bag" else "r")

## .fcard: right 192 (176 without a box), bottom 7 %, 300 / 212 wide, -3°; b 19 px, p 12 px/1.5, the box, the cost
## line, .hit (skewX(-12°), 5 px white shadow, .4 when it can't)
func _card(vs: Vector2, col: Color, d: Dictionary, idx: int) -> void:
	var f := UI.noto()
	var box = d.get("box")
	var wide: bool = box != null
	var W := 300.0 if wide else 212.0
	var x0 := vs.x - (14.0 + 178.0 if wide else 176.0) - W
	var cw := W - 32.0 - 6.0
	var ops: Array = []        # [kind, y, data]
	var y := 12.0
	var bl: Array = flow([[d["ttl"], UI.bhs(), 19, Color.WHITE]], cw)
	ops.append(["flow", y, bl, 21.85])
	y += bl.size() * 21.85 + 2.0
	var pl: Array = flow(d.get("runs", []), cw) if not d.get("runs", []).is_empty() else []
	ops.append(["flow", y, pl, 18.0])
	y += pl.size() * 18.0
	if box != null:
		y += 5.0
		var fc := _face(box)
		if box["tabs"]:
			ops.append(["tabs", y, box, fc])
			y += 25.0
		var lines: Array = []
		if fc == "r" and box["r"] is Dictionary:
			ops.append(["cmp", y, box["r"], cw])
			y += _cmp_h(box["r"], cw)
		else:
			lines = flow(box[fc], cw)
			ops.append(["flow", y, lines, 16.7])
			y += lines.size() * 16.7
		ops.append(["boxhit", y, box])
	for k in ["warn", "tail"]:
		if d.has(k):
			var tl: Array = flow(d[k], cw)
			ops.append(["flow", y, tl, 17.0])
			y += tl.size() * 17.0
	if d.get("cost", "") != "":
		var cl: Array = flow([[d["cost"], f, 12, Color("#ffb070")]], cw)
		ops.append(["flow", y, cl, 18.0])
		y += 18.0
	y += 8.0
	if d.get("btn", "") != "":
		ops.append(["btn", y])
		y += 42.0
	var H := y + 12.0
	var R0 := Rect2(x0, vs.y * 0.93 - H, W, H)
	var e := _it(idx)
	var m := _itm(xf(R0.position, R0.size / 2.0, -3.0), R0.position + R0.size / 2.0, e)
	var a: float = e["a"]
	var clip := [[0, 0], [100, 5], [97, 100], [2, 95]]
	draw_colored_polygon(poly(Rect2(Vector2.ZERO, R0.size), clip, m), Color(0, 0, 0, a))
	for q in Geometry2D.intersect_polygons(poly(Rect2(Vector2.ZERO, R0.size), clip, m), poly(Rect2(0, 0, 6, H), SQ, m)): draw_colored_polygon(q, Color(col, a))
	for op in ops:
		match op[0]:
			"flow":
				draw_set_transform_matrix(m)
				draw_flow(self, op[2], 16, op[1], op[3], a)
			"tabs":
				var x := 16.0
				for tb in [["g", "장비 효과"], ["r", op[2]["lab"]]]:
					var on: bool = op[3] == tb[0]
					var w := tw(f, tb[1], 10) + 20.0
					var tr := Rect2(x, op[1], w, 20)
					draw_set_transform(Vector2.ZERO)
					draw_colored_polygon(poly(Rect2(Vector2.ZERO, tr.size), SQ, m * xf(tr.position, tr.size / 2.0, 0, 1, -10.0)), Color(1, 1, 1, a) if on else Color(0.165, 0.165, 0.165, a))
					draw_set_transform_matrix(m)
					txt(self, f, x + 10, op[1] + 2, tb[1], 10, Color(0, 0, 0, a) if on else Color(0.604, 0.604, 0.604, a), 16.0)
					x += w + 5.0
			"cmp": _draw_cmp(m, op[1], op[2], op[3], a)
			"boxhit":
				var bx: Dictionary = op[2]
				if bx["tabs"]:
					hb.append([poly(Rect2(16, 30, cw, op[1] - 30), SQ, m), func():
						rvm[bx["ctx"]] = "r" if _face(bx) == "g" else "g"
						mark("flip")
						sfx("ui_ok", 0.5)])
			"btn":
				var bf := UI.bhs()
				var bw := tw(bf, d["btn"], 22) + 44.0
				var br := Rect2(16, op[1], bw, 42)
				var bm := m * xf(br.position, br.size / 2.0, 0, 1, -12.0)
				var ba := a * (0.4 if d.get("dis", false) else 1.0)
				draw_set_transform(Vector2.ZERO)
				draw_colored_polygon(poly(Rect2(5, 5, bw, 42), SQ, bm), Color(1, 1, 1, ba))
				var bp := poly(Rect2(0, 0, bw, 42), SQ, bm)
				draw_colored_polygon(bp, Color(col, ba))
				draw_set_transform_matrix(bm)
				txt(self, bf, 22, 6, d["btn"], 22, Color(0, 0, 0, ba), 30.0)
				if d.has("act"): hb.append([bp, d["act"]])
	draw_set_transform(Vector2.ZERO)

## 각인's comparison face: 지금 / 새로 blocks
func _cmp_h(cm: Dictionary, cw: float) -> float:
	var h := 0.0
	var f := UI.noto()
	for blk in cm["blocks"]:
		h += flow(blk["runs"], cw - tw(f, blk["tag"], 10) - 17.0).size() * 16.7 + 2.0
	return h + 6.0 * (cm["blocks"].size() - 1)

func _draw_cmp(m: Transform2D, y: float, cm: Dictionary, cw: float, a: float) -> void:
	var f := UI.noto()
	var yy := y
	var first := true
	for blk in cm["blocks"]:
		if not first:
			yy += 6.0
			var x := 16.0
			while x < 16.0 + cw:
				draw_set_transform_matrix(m)
				draw_line(Vector2(x, yy - 3), Vector2(minf(x + 3, 16 + cw), yy - 3), Color(1, 1, 1, 0.28 * a), 1.0)
				x += 6.0
		first = false
		var tag: String = blk["tag"]
		var tw0 := tw(f, tag, 10) + 12.0
		var tm := m * xf(Vector2(16, yy + 1), Vector2(tw0 / 2.0, 8.0), 0, 1, -10.0)
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(poly(Rect2(0, 0, tw0, 16), SQ, tm), Color(blk["tc"], a))
		draw_set_transform_matrix(tm)
		txt(self, f, 6, 0, tag, 10, Color(0, 0, 0, a), 16.0)
		var lines: Array = flow(blk["runs"], cw - tw0 - 5.0)
		draw_set_transform_matrix(m)
		draw_flow(self, lines, 16 + tw0 + 5.0, yy, 16.7, a)
		yy += lines.size() * 16.7 + 2.0
	draw_set_transform(Vector2.ZERO)


# ---------- 각인 ----------
func _rlist_rows() -> Array:
	var out: Array = []
	if p == "eng":
		for r in R().eng_list(c, slot):
			var Rd: Dictionary = RN.RUNE[r]
			out.append({"n": Rd["n"], "g": Rd["g"], "c": "×%d" % int(R().runebag[r]), "e": Rd["d"], "rk": r})
	elif p == "fuse":
		for x in R().fuse_groups():
			var up := RN.up_grade(x["g"])
			out.append({"n": RN.gname(x["g"]) + " 룬", "g": x["g"], "c": "×%d" % x["c"], "e": "3개 → %s 룬 1개 · 성공 %d%%" % [RN.gname(up), FZRATE[up]], "dim": x["c"] < 3})
	return out

## .rlist (16, 86), 276 wide: .rc rows, 6 apart, each indented 9 px × its --i, the picked one white and 16 px further
func _rlist(vs: Vector2, col: Color, rows: Array, sel: int) -> void:
	var f := UI.noto()
	var bf := UI.bhs()
	var y := 86.0 - list_off
	if rows.is_empty():
		var e := {"x": 0.0, "r": 0.0, "a": 1.0}
		var s := "맞는 룬이 없습니다."
		var w := tw(f, s, 12) + 28.0
		var m := _itm(Transform2D(0.0, Vector2(16, y)), Vector2(16 + w / 2.0, y + 19.0), e)
		draw_colored_polygon(poly(Rect2(0, 0, w, 38), SQ, m), Color(0, 0, 0, e["a"]))
		draw_set_transform_matrix(m)
		txt(self, f, 14, 10, s, 12, Color(0.667, 0.667, 0.667, e["a"]), 18.0)
		draw_set_transform(Vector2.ZERO)
		return
	for i in rows.size():
		var o: Dictionary = rows[i]
		var on := i == sel
		var ii := i + rc_off
		var km := UI.bk(clampf(sel_t / 300.0, 0.0, 1.0))
		var ml := ii * 9.0 + 16.0 * (km if on else ((1.0 - km) if i == prev_sel else 0.0))
		var bgk := clampf(sel_t / 150.0, 0.0, 1.0)
		var white := (bgk if on else ((1.0 - bgk) if i == prev_sel else 0.0)) if prev_sel >= 0 and sel_t < 9000.0 else (1.0 if on else 0.0)
		var w := 274.0 - ml
		var pl: Array = flow([[o["e"], f, 10, Color.WHITE]], w - 42.0 - 14.0)
		var h := 6.0 + 17.25 + 1.0 + pl.size() * 13.5 + 7.0
		var e := _it(i)
		var m := _itm(Transform2D(0.0, Vector2(16.0 + ml, y)), Vector2(16.0 + ml + w / 2.0, y + h / 2.0), e)
		var a: float = e["a"] * (0.45 if o.get("dim", false) else 1.0)
		var gc := RN.gcol(o["g"])
		var pts := poly(Rect2(0, 0, w, h), [[0, 0], [100, 0], [95, 100], [0, 100]], m)
		draw_colored_polygon(pts, Color(Color.BLACK.lerp(Color.WHITE, white), a))
		for q in Geometry2D.intersect_polygons(pts, poly(Rect2(0, 0, 5, h), SQ, m)): draw_colored_polygon(q, Color(gc, a))
		draw_set_transform_matrix(m)
		var rip: String = ICON.rune_file(String(o["rk"]), String(o["g"])) if o.has("rk") else ""
		if rip != "" and ResourceLoader.exists(rip):
			draw_texture_rect(UI.glow(), Rect2(Vector2(26, 17) - Vector2(20, 20), Vector2(40, 40)), false, Color(gc.lightened(0.3), 0.6 * a))
			draw_texture_rect(tx(rip), Rect2(Vector2(26, 17) - Vector2(15, 15), Vector2(30, 30)), false, Color(1, 1, 1, a))
		else:
			gem(self, Vector2(5 + 10 + 11, 8 + 9), 7.0, Color(gc, a))
		var fc := Color(Color.WHITE.lerp(Color.BLACK, white), a)
		var nx := 42.0 + txt(self, bf, 42, 6, o["n"], 15, fc, 17.25)
		txt(self, bf, nx + 6.0, 9, RN.gname(o["g"]), 10, Color(gc, a), 11.5)
		var uw := tw(UI.anton(true), o["c"], 18)
		txt(self, UI.anton(true), w - 14.0 - uw, 6, o["c"], 18, fc, 18.0)
		draw_flow(self, pl, 42, 6 + 17.25 + 1.0, 13.5, a)
		draw_set_transform(Vector2.ZERO)
		var i2 := i
		hb.append([pts, func():
			if busy > 0: return
			_row_pick(i2)
			sfx("ui_move", 0.5)])
		y += h + 6.0

func _rc_gem(vs: Vector2, i: int) -> Vector2:
	var y := 86.0 - list_off
	var rows := _rlist_rows()
	for k in i:
		var w := 274.0 - (k + rc_off) * 9.0
		y += 6.0 + 17.25 + 1.0 + flow([[rows[k]["e"], UI.noto(), 10, Color.WHITE]], w - 56.0).size() * 13.5 + 7.0 + 6.0
	return Vector2(16.0 + (i + rc_off) * 9.0 + 16.0 + 26.0, y + 17.0)

func _ecirc_c(vs: Vector2) -> Vector2:
	return Vector2(vs.x * 0.42, vs.y * 0.53)

func _ecirc_w(vs: Vector2) -> float:
	return minf(vs.y * 0.53, 206.0)

func _eng(vs: Vector2, col: Color) -> void:
	var it = cur()
	var L: Array = R().eng_list(c, slot)
	if eng >= L.size(): eng = 0
	var rows := _rlist_rows()
	_rlist(vs, col, rows, eng)
	var n := rows.size()
	# .ecirc: the tick ring (30 s a turn), .qd inset 17 %, the piece inset 36 %, the name below, the socket on top
	var e := _it(n)
	var cc := _ecirc_c(vs)
	var W := _ecirc_w(vs)
	var m := _itm(Transform2D.IDENTITY, cc, e)
	var a: float = e["a"]
	var eb := since("ebright")
	draw_set_transform_matrix(m)
	var rot := t / 30000.0 * TAU
	var nt := int(360.0 / 7.5)
	for i in nt:
		var a0 := -PI / 2.0 + rot + deg_to_rad(i * 7.5)
		var a1 := a0 + deg_to_rad(1.2)
		draw_colored_polygon(PackedVector2Array([cc + Vector2.from_angle(a0) * W * 0.44, cc + Vector2.from_angle(a0) * W / 2.0, cc + Vector2.from_angle(a1) * W / 2.0, cc + Vector2.from_angle(a1) * W * 0.44]), Color(1, 1, 1, 0.6 * a))
	var qr := Rect2(cc - Vector2(W, W) / 2.0, Vector2(W, W)).grow(-W * 0.17)
	_qd(qr, col, since("kick_ecirc"), a)
	draw_set_transform_matrix(m)
	_piece(cc, W * 0.28, Color("#d8dce6"), Color("#7d8597"), a)
	var bf := UI.bhs()
	var nm: String = ("%s Lv %d" % [it["n"], int(it.get("lv", 0))]) if it != null else "장비 없음"
	var nw := tw(bf, nm, 15) + 24.0
	var nmm := m * xf(Vector2(cc.x - nw / 2.0, cc.y + W / 2.0 + W * 0.06 - 23.0), Vector2(nw / 2.0, 11.5), -4.0)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(poly(Rect2(4, 4, nw, 23), SQ, nmm), Color(col, a))
	draw_colored_polygon(poly(Rect2(0, 0, nw, 23), SQ, nmm), Color(0, 0, 0, a))
	draw_set_transform_matrix(nmm)
	txt(self, bf, 12, 2, nm, 15, Color(1, 1, 1, a), 19.0)
	# the socket: full (the rune's colour, glowing) or cur (blinking outline in her colour)
	var sk := cc + Vector2(0, -W / 2.0)
	var full: bool = it != null and R().has_rune_item(it) and not hold.has("sock")
	var sks := 1.0
	var st := since("sock")
	if st < 300.0: sks = lerpf(2.0, 1.0, UI.bez(0.2, 1.6, 0.4, 1.0, st / 300.0))
	var smm := m * Transform2D(PI / 4.0, Vector2(sks, sks), 0.0, sk)
	var sq := func(r: float, o := Vector2.ZERO) -> PackedVector2Array:
		return PackedVector2Array([smm * (Vector2(-r, -r) + o), smm * (Vector2(r, -r) + o), smm * (Vector2(r, r) + o), smm * (Vector2(-r, r) + o)])
	draw_set_transform(Vector2.ZERO)
	var gcl: Color = RN.gcol(RN.RUNE[it["rune"]]["g"]) if full else Color(0.067, 0.067, 0.067)
	if full:
		for gl in [[30.0, 0.12], [24.0, 0.2]]: draw_colored_polygon(sq.call(gl[0]), Color(gcl, gl[1] * a))
	else:
		var u := fmod(t / 1000.0, 1.0)
		var bl := AE.ez("ease-in-out", u * 2.0) if u < 0.5 else 1.0 - AE.ez("ease-in-out", (u - 0.5) * 2.0)
		var ol: PackedVector2Array = sq.call(27.0)
		ol.append(ol[0])
		draw_polyline(ol, Color(col, a * (1.0 - bl)), 3.0)
	draw_colored_polygon(sq.call(18.0, Vector2(4, 4).rotated(-PI / 4.0)), Color(0, 0, 0, a))
	draw_colored_polygon(sq.call(18.0), Color(1, 1, 1, a))
	draw_colored_polygon(sq.call(15.0), Color(gcl, a))
	if eb < 320.0: draw_circle(cc, W / 2.0, Color(1, 1, 1, 0.5 * (1.0 - AE.ez("ease-out", eb / 320.0)) * a))
	hb.append([Rect2(cc - Vector2(W, W) / 2.0, Vector2(W, W)), picking_open])
	# the card
	var f := UI.noto()
	var D := Color(0.867, 0.867, 0.867)
	var cd: Dictionary
	if it == null: cd = {"ttl": "빈 칸", "runs": [["각인할 장비가 없습니다.", f, 12, D]]}
	elif L.is_empty(): cd = {"ttl": "룬 없음", "runs": [["이 칸에 맞는 룬이 가방에 없습니다.", f, 12, D]], "box": _box(it, RN.slot_kind(slot), "eng", [], "")}
	else:
		var r: String = L[eng]
		var Rd: Dictionary = RN.RUNE[r]
		var cost := RN.engrave_cost(Rd["g"])
		var has_old: bool = R().has_rune_item(it)
		var blocks: Array = [{"tag": "지금", "tc": Color.WHITE, "runs": _rune_line(it["rune"], int(it.get("rs", 1))) if has_old else [["빈 홈", f, 11, D]]}, {"tag": "새로", "tc": Color("#ffd34d"), "runs": _rune_line(r, 1)}]
		var bx := _box(it, RN.slot_kind(slot), "eng", [], "룬 비교")
		bx["tabs"] = true
		bx["r"] = {"blocks": blocks}
		cd = {"ttl": "[%s]" % Rd["n"], "runs": [], "box": bx, "cost": "실링 %d%s" % [cost, " · 모자랍니다" if R().iron < cost else ""], "btn": "새긴다!", "dis": R().iron < cost, "act": do_eng}
		if has_old:
			var rs := int(it.get("rs", 1))
			cd["warn"] = [["기존 룬 [%s%s 파괴됩니다" % [RN.RUNE[it["rune"]]["n"], ("] ★%d은(는) 성급째" % rs) if rs > 1 else "]은(는)"], f, 11, Color("#ff6a6a")]]
	_card(vs, col, cd, n + 1)
	_bub(vs, n + 2)

## the rune in flight (380 ms, ease .5,0,.6,1): up and over, three turns, ×2 then ×1.4
func _fly() -> void:
	var k := UI.bez(0.5, 0.0, 0.6, 1.0, clampf((t - fly["t0"]) / 380.0, 0.0, 1.0))
	var d: Vector2 = fly["to"] - fly["from"]
	var pos: Vector2
	var rot: float
	var sc: float
	if k < 0.55:
		var q := k / 0.55
		pos = fly["from"] + Vector2(d.x * 0.5, d.y * 0.5 - 70.0) * q
		rot = lerpf(45.0, 225.0, q)
		sc = lerpf(1.0, 2.0, q)
	else:
		var q := (k - 0.55) / 0.45
		pos = fly["from"] + Vector2(d.x * 0.5, d.y * 0.5 - 70.0).lerp(d, q)
		rot = lerpf(225.0, 405.0, q)
		sc = lerpf(2.0, 1.4, q)
	draw_set_transform(pos, deg_to_rad(rot - 45.0), Vector2(sc, sc))
	gem(self, Vector2.ZERO, 7.0, fly["g"])
	draw_set_transform(Vector2.ZERO)


# ---------- 합성 ----------
func _fr_c(vs: Vector2) -> Vector2:
	var W := minf(vs.y * 0.58, 224.0)
	return Vector2(vs.x * 0.42, vs.y * 0.53) + Vector2(0, W * 0.06)

func _fuse(vs: Vector2, col: Color) -> void:
	var G: Array = R().fuse_groups()
	if fz >= G.size(): fz = 0
	var rows := _rlist_rows()
	_rlist(vs, col, rows, fz)
	var n := rows.size()
	var x0 = G[fz] if not G.is_empty() else null
	# .ftri: 224 px at 42 % / 53 %; dashed lines from the three slots to the result
	var e := _it(n)
	var W := minf(vs.y * 0.58, 224.0)
	var cc := Vector2(vs.x * 0.42, vs.y * 0.53)
	var org := cc - Vector2(W, W) / 2.0
	var at := func(px: float, py: float) -> Vector2: return org + Vector2(W * px, W * py)
	var m := _itm(Transform2D.IDENTITY, cc, e)
	var a: float = e["a"]
	var tb := since("tri")
	var tri_b := 1.0 + 2.0 * (1.0 - clampf(tb / 400.0, 0.0, 1.0)) if tb < 400.0 else 1.0
	draw_set_transform_matrix(m)
	var dash := fmod(t / 1000.0, 1.0) * 22.0
	var centre: Vector2 = at.call(0.5, 0.56)
	for q in [at.call(0.5, 0.08), at.call(0.18, 0.86), at.call(0.82, 0.86)]:
		var L := centre.distance_to(q)
		var dirv: Vector2 = (centre - q) / L
		var s := -dash
		while s < L:
			var s0 := maxf(0.0, s)
			var s1 := minf(L, s + 5.0)
			if s1 > s0: draw_line(q + dirv * s0, q + dirv * s1, Color(1, 1, 1, minf(1.0, 0.45 * tri_b) * a), 2.0)
			s += 11.0
	# the slots: 58 px hexes, white 3 px; their gems pop (320 ms, 60 ms apart) and gather on a fuse
	var gc: Color = RN.gcol(x0["g"]) if x0 != null else Color(0.3, 0.3, 0.3)
	var pts3 := [at.call(0.5, 0.08), at.call(0.18, 0.86), at.call(0.82, 0.86)]
	for k in 3:
		var q: Vector2 = pts3[k]
		var hexo := PackedVector2Array()
		var hexi := PackedVector2Array()
		for hp in [[50, 0], [100, 25], [100, 75], [50, 100], [0, 75], [0, 25]]:
			hexo.append(q + Vector2((hp[0] - 50) * 0.58, (hp[1] - 50) * 0.58))
			hexi.append(q + Vector2((hp[0] - 50) * 0.52, (hp[1] - 50) * 0.52))
		draw_colored_polygon(hexo, Color(1, 1, 1, a))
		draw_colored_polygon(hexi, Color(0, 0, 0, a))
		var have: bool = x0 != null and k < x0["c"]
		var pk := UI.bez(0.2, 1.6, 0.4, 1.0, clampf((since("slots") - k * 60.0) / 320.0, 0.0, 1.0))
		var gpos := q
		var gs2 := pk
		var ga := a
		var grot := 0.0
		var gt := since("gather") - k * 35.0
		if clk.has("gather") and gt > 0.0:
			var kk := UI.bez(0.6, 0.0, 0.8, 0.6, clampf(gt / 340.0, 0.0, 1.0))
			var dv := centre - q
			if kk < 0.4:
				gpos = q + dv * 0.7 * (kk / 0.4)
				gs2 = lerpf(1.0, 1.3, kk / 0.4)
			else:
				var qq := (kk - 0.4) / 0.6
				gpos = q + dv * lerpf(0.7, 1.0, qq)
				gs2 = lerpf(1.3, 0.2, qq)
				grot = TAU * qq
				ga = a * lerpf(1.0, 0.4, qq)
		if have and gs2 > 0.01:
			draw_set_transform(gpos, grot, Vector2(gs2, gs2))
			for gl in [[18.0, 0.12], [14.0, 0.2]]:
				draw_colored_polygon(PackedVector2Array([Vector2(0, -gl[0]), Vector2(gl[0], 0), Vector2(0, gl[0]), Vector2(-gl[0], 0)]), Color(gc, gl[1] * ga))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -15.5), Vector2(15.5, 0), Vector2(0, 15.5), Vector2(-15.5, 0)]), Color(gc, ga))
			draw_polyline(PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0), Vector2(0, -12)]), Color(1, 1, 1, 0.4 * ga), 3.0)
			draw_set_transform_matrix(m)
		elif not have:
			draw_polyline(PackedVector2Array([q + Vector2(0, -14.5), q + Vector2(14.5, 0), q + Vector2(0, 14.5), q + Vector2(-14.5, 0), q + Vector2(0, -14.5)]), Color(1, 1, 1, 0.25 * a), 2.0)
	# the result: 104 px .qd, its gem (shown on a win: from ×3, bright, 420 ms --bk), the label above
	draw_set_transform_matrix(m)
	var fr := Rect2(centre - Vector2(52, 52), Vector2(104, 104))
	_qd(fr, col, since("kick_fr"), a)
	draw_set_transform_matrix(m)
	if fr_show:
		var up := RN.up_grade(x0["g"]) if x0 != null else "rare"
		var fg := since("frg")
		var s3 := lerpf(3.0, 1.0, UI.bk(clampf(fg / 420.0, 0.0, 1.0)))
		var gcol := RN.gcol(up) if fr_got != "" else gc
		draw_set_transform(centre, 0.0, Vector2(s3, s3))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -21), Vector2(21, 0), Vector2(0, 21), Vector2(-21, 0)]), Color(gcol.lightened(clampf(1.0 - fg / 420.0, 0.0, 1.0) * 0.8), a))
		draw_set_transform_matrix(m)
	var lab := fr_got if fr_got != "" else ((RN.gname(RN.up_grade(x0["g"])) + " ?") if x0 != null else "?")
	var bf := UI.bhs()
	var lw := tw(bf, lab, 13) + 20.0
	var lm := m * xf(Vector2(centre.x - lw / 2.0, fr.position.y - 20.0), Vector2(lw / 2.0, 10.0), -4.0)
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(poly(Rect2(3, 3, lw, 20), SQ, lm), Color(col, a))
	draw_colored_polygon(poly(Rect2(0, 0, lw, 20), SQ, lm), Color(0, 0, 0, a))
	draw_set_transform_matrix(lm)
	txt(self, bf, 10, 1, lab, 13, Color(1, 1, 1, a), 18.0)
	draw_set_transform(Vector2.ZERO)
	# the card
	var f := UI.noto()
	var D := Color(0.867, 0.867, 0.867)
	var cd: Dictionary
	if x0 == null: cd = {"ttl": "룬 없음", "runs": [["합성할 룬이 없습니다.\n고유·전설 룬은 합성할 수 없습니다.", f, 12, D]]}
	else:
		var up2 := RN.up_grade(x0["g"])
		cd = {"ttl": "%s 룬 ×3" % RN.gname(x0["g"]), "runs": [["%s 3개 → %s 1개 (무작위)\n성공 %d%% · 실패 시 1개 반환\n보유 %d개" % [RN.gname(x0["g"]), RN.gname(up2), FZRATE[up2], x0["c"]], f, 12, D]],
			"cost": "실링 %d%s" % [RN.FUSE_COST, " · 모자랍니다" if R().iron < RN.FUSE_COST else ""], "btn": "녹인다!", "dis": x0["c"] < 3 or R().iron < RN.FUSE_COST, "act": do_fuse}
	_card(vs, col, cd, n + 1)
	_bub(vs, n + 2)


# ---------- 분해 ----------
func _dis_list() -> Array:
	var V: Array = []
	var bag: Array = R().gearbag
	for i in bag.size():
		if (ds == "rune") == R().has_rune_item(bag[i]): V.append(i)
	return V

## .dgrid (16, 146): three columns 120 × 100, 12 / 10 apart
func _dt_rect(vs: Vector2, k: int) -> Rect2:
	return Rect2(16.0 + (k % 3) * 130.0, 146.0 + int(k / 3) * 112.0 - list_off, 120, 100)

func _dis(vs: Vector2, col: Color) -> void:
	var bag: Array = R().gearbag
	var f := UI.noto()
	var bf := UI.bhs()
	# .dsub (16, 104) -3°: 장비 / 룬 각인 장비
	var nr := 0
	for d in bag: if R().has_rune_item(d): nr += 1
	var A := [["plain", "장비", bag.size() - nr], ["rune", "룬 각인 장비", nr]]
	var ws: Array = []
	var tot := 0.0
	for q in A:
		var w: float = tw(f, q[1], 13) + 5.0 + tw(f, str(q[2]), 13) + 28.0
		ws.append(w)
		tot += w + 6.0
	var nm := xf(Vector2(16, 104), Vector2((tot - 6.0) / 2.0, 14.0), -3.0)
	var x := 0.0
	for i in 2:
		var q: Array = A[i]
		var on: bool = q[0] == ds
		var w: float = ws[i]
		var bm := nm * xf(Vector2(x, 0), Vector2(w / 2.0, 14.0), 0, 1, -12.0)
		if on: draw_colored_polygon(poly(Rect2(3, 3, w, 28), SQ, bm), col)
		var pts := poly(Rect2(0, 0, w, 28), SQ, bm)
		draw_colored_polygon(pts, Color.WHITE)
		if not on: draw_colored_polygon(poly(Rect2(2, 2, w - 4, 24), SQ, bm), Color.BLACK)
		draw_set_transform_matrix(bm)
		var t0 := txt(self, f, 14, 5, q[1], 13, Color.BLACK if on else Color(0.667, 0.667, 0.667), 18.2)
		txt(self, f, 14 + t0 + 5.0, 5, str(q[2]), 13, Color(0, 0, 0, 0.55) if on else Color(0.667, 0.667, 0.667, 0.55), 18.2)
		draw_set_transform(Vector2.ZERO)
		var key: String = q[0]
		hb.append([pts, func():
			if ds == key or busy > 0: return
			ds = key
			sfx("ui_move", 0.5)])
		x += w + 6.0
	var V := _dis_list()
	if V.is_empty():
		var e := _it(0)
		var s: String = (("룬을 박은 장비가 가방에 없습니다." if ds == "rune" else "룬 없는 장비가 가방에 없습니다.") if not bag.is_empty() else "가방에 분해할 장비가 없습니다.")
		var m := _itm(Transform2D(0.0, Vector2(16, 146)), Vector2(16 + 190, 146 + 40), e)
		draw_set_transform_matrix(m)
		txt(self, bf, 0, 30, s, 18, Color(0.667, 0.667, 0.667, e["a"]), 22.0)
		if bag.is_empty(): txt(self, bf, 0, 52, "던전에서 얻은 장비가 여기 쌓입니다.", 15, Color(0.667, 0.667, 0.667, e["a"]), 18.0)
		draw_set_transform(Vector2.ZERO)
	for k in V.size():
		var bi: int = V[k]
		if gone.has(bi): continue
		var d: Dictionary = bag[bi]
		var r := _dt_rect(vs, k)
		if r.position.y > vs.y: continue
		var sel := dis.has(bi)
		var e := _it(k)
		var dk := since("dsel%d" % bi)
		var sk := UI.bk(clampf(dk / 250.0, 0.0, 1.0))
		var scl := lerpf(1.0, 0.95, sk if sel else 1.0 - sk) if dk < 250.0 else (0.95 if sel else 1.0)
		var dtk := since("dt%d" % bi)
		var shx := 0.0
		var flash := 0.0
		if dtk < 110.0:
			var u := dtk / 110.0
			shx = (-4.0 + 16.0 * u) if u < 0.5 else (4.0 - 8.0 * (u - 0.5) * 2.0)
			flash = 1.0 - u
		var rot := 1.5 if k % 2 else -2.0
		var m := _itm(xf(r.position + Vector2(shx, 0), r.size / 2.0, rot, scl), r.position + r.size / 2.0, e)
		_tile(m, r.size, d, sel, col, e["a"], dk, flash)
		var b2 := bi
		hb.append([poly(Rect2(Vector2.ZERO, r.size), SQ, m), func():
			if busy > 0: return
			dis_toggle(b2)])
	# the card
	var S: Array = []
	var sil := 0
	for i in dis.keys():
		if i < bag.size():
			S.append(bag[i])
			sil += RN.melt_val(bag[i])
	var cd: Dictionary
	var D := Color(0.867, 0.867, 0.867)
	if S.is_empty():
		cd = {"ttl": "분해", "runs": [["부술 장비를 골라 주세요.\n등급과 강화 수치가 높을수록 많이 나옵니다.", f, 12, D]], "btn": "부순다!", "dis": true, "act": do_dis}
	else:
		var tx := "획득: 실링 +%d" % sil
		if S.any(func(q): return R().has_rune_item(q)): tx += "\n박힌 룬은 가방으로 돌아갑니다 (성급은 초기화)"
		cd = {"ttl": "%d개 선택" % S.size(), "runs": [[tx, f, 12, D]], "btn": "부순다!", "dis": false, "act": do_dis}
		if S.size() == 1: cd["box"] = _box(S[0], S[0].get("slot", "weapon"), "dis", [], "")
	_card(vs, col, cd, V.size() + (0 if not V.is_empty() else 1))
	_bub(vs, V.size() + (1 if not V.is_empty() else 2))

## one .dt tile (and the halves reuse it): border-top 5 px grade, gem 24, name, small, Lv / ★ top right; .sel: black,
## hatched, the 분해 tag
func _tile(m: Transform2D, size: Vector2, d: Dictionary, sel: bool, col: Color, a: float, dk: float, flash := 0.0) -> void:
	var f := UI.noto()
	var bf := UI.bhs()
	var g := RN.gcol(d["g"])
	var shape := poly(Rect2(Vector2.ZERO, size), [[0, 0], [100, 3], [97, 100], [2, 97]], m)
	var bg := Color(0, 0, 0) if sel else Color(0.067, 0.067, 0.067)
	var draw_poly := func(pts: PackedVector2Array, cc: Color): draw_colored_polygon(pts, cc)
	draw_poly.call(shape, Color(bg, a))
	if sel:
		var s := -size.y
		while s < size.x + size.y:
			var band := PackedVector2Array([m * Vector2(s, 0), m * Vector2(s + 6, 0), m * Vector2(s + 6 - size.y, size.y), m * Vector2(s - size.y, size.y)])
			for q in Geometry2D.intersect_polygons(shape, band): draw_poly.call(q, Color(1, 1, 1, 0.08 * a))
			s += 12.0 / 0.707
	for q in Geometry2D.intersect_polygons(shape, poly(Rect2(0, 0, size.x, 5), SQ, m)): draw_poly.call(q, Color(g, a))
	draw_set_transform_matrix(m)
	gem(self, Vector2(10 + 4 + 12, 10 + 4 + 12 + 3), 11.0, Color(g, a))
	var hr: bool = R().has_rune_item(d)
	var u := ("★%d" % int(d.get("rs", 1))) if hr else (("Lv %d" % int(d["lv"])) if int(d.get("lv", 0)) > 0 else "")
	if u != "": txt(self, UI.anton(true), size.x - 8.0 - tw(UI.anton(true), u, 20), 8, u, 20, Color(1, 1, 1, a), 20.0)
	txt(self, bf, 10, 51, d["n"], 14, Color(1, 1, 1, a), 16.1)
	var sub: String = ("[%s]" % RN.RUNE[d["rune"]]["n"]) if hr else (RN.gname(d["g"]) + " · " + RN.SLOTN.get("acc1" if d.get("slot", "") == "acc" else d.get("slot", ""), "").replace(" 1", ""))
	txt(self, f, 10, 69, sub, 10, Color(0.6, 0.6, 0.6, a), 13.0)
	# ::after 분해: from ×2 to ×1 (.25 s --bk), opacity .15 s
	var ka := clampf(dk / 150.0, 0.0, 1.0) if dk < 250.0 else 1.0
	var kt := UI.bk(clampf(dk / 250.0, 0.0, 1.0)) if dk < 250.0 else 1.0
	var ta := (ka if sel else 1.0 - ka)
	var ts := lerpf(2.0, 1.0, kt if sel else 1.0 - kt)
	if ta > 0.0:
		var tw0 := tw(bf, "분해", 16) + 28.0
		var tr := Rect2(size.x + 8.0 - tw0, size.y - 12.0 - 22.0, tw0, 22)
		var tm := m * xf(tr.position, tr.size / 2.0, -12.0, ts)
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(poly(Rect2(Vector2.ZERO, tr.size), SQ, tm), Color(col, ta * a))
		draw_set_transform_matrix(tm)
		txt(self, bf, 14, 1, "분해", 16, Color(0, 0, 0, ta * a), 20.0)
	if flash > 0.0:
		draw_set_transform(Vector2.ZERO)
		draw_colored_polygon(shape, Color(1, 1, 1, 0.6 * flash * a))
	draw_set_transform(Vector2.ZERO)

## the cracked tiles: two halves (62 % / 38 % slant) falling apart (460 ms)
func _halves(vs: Vector2) -> void:
	var V := _dis_list()
	for h in halves:
		var k := UI.bez(0.3, 0.0, 0.8, 0.6, clampf(h["t"] / 460.0, 0.0, 1.0))
		var r := _dt_rect(vs, h["k"])
		var s: int = h["s"]
		var rot := 1.5 if int(h["k"]) % 2 else -2.0
		var m := Transform2D(0.0, Vector2(s * 34.0, 60.0) * k) * Transform2D(0.0, r.get_center()) * Transform2D(deg_to_rad(s * 16.0 * k), Vector2.ZERO) * Transform2D(0.0, -r.get_center()) * xf(r.position, r.size / 2.0, rot, 0.95)
		var bi: int = h["bi"]
		if bi >= R().gearbag.size(): continue
		var cutp := [[0, 0], [62, 0], [38, 100], [0, 100]] if s < 0 else [[62, 0], [100, 0], [100, 100], [38, 100]]
		var part := poly(Rect2(Vector2.ZERO, r.size), cutp, m)
		var shape := poly(Rect2(Vector2.ZERO, r.size), [[0, 0], [100, 3], [97, 100], [2, 97]], m)
		for q in Geometry2D.intersect_polygons(shape, part): draw_colored_polygon(q, Color(0.05, 0.05, 0.05, 1.0 - k))
		var top := Geometry2D.intersect_polygons(poly(Rect2(0, 0, r.size.x, 5), SQ, m), part)
		for q in top: draw_colored_polygon(q, Color(RN.gcol(R().gearbag[bi]["g"]), 1.0 - k))


# ---------- the gear pick (anvil tap) ----------
func _pick(vs: Vector2, col: Color) -> void:
	var f := UI.noto()
	var bf := UI.bhs()
	var pt := since("pick")
	var xt := since("pickx")
	var closing := pick_closing
	var bga := (1.0 - AE.ez("linear", xt / 240.0)) if closing else clampf(pt / 200.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO - Vector2(20, 20), vs + Vector2(40, 40)), Color(0, 0, 0, 0.55 * bga))
	hb.append([Rect2(Vector2.ZERO, vs), picking_close])
	var W := minf(vs.x * 0.5, 410.0)
	var slide := func(k: int) -> float:
		if closing: return -1.15 * W * UI.bez(0.6, 0.0, 0.9, 0.5, clampf((xt - k * 30.0) / 220.0, 0.0, 1.0))
		return -1.1 * W * (1.0 - UI.bez(0.16, 1.0, 0.3, 1.0, clampf((pt - k * 40.0) / 340.0, 0.0, 1.0)))
	# .gps (her colour, 16 px right) then .gpl (black) — gps animates first (k 0), gpl 40 ms later
	var gx: float = slide.call(0)
	draw_colored_polygon(poly(Rect2(0, 0, W, vs.y), [[0, 0], [100, 0], [84, 100], [0, 100]], Transform2D(0.0, Vector2(16.0 + gx, 0))), col)
	var lx: float = slide.call(1)
	var lp := poly(Rect2(0, 0, W, vs.y), [[0, 0], [96, 0], [80, 100], [0, 100]], Transform2D(0.0, Vector2(lx, 0)))
	draw_colored_polygon(lp, Color.BLACK)
	hb.append([lp, func(): pass])
	draw_set_transform(Vector2(lx, 0))
	txt(self, UI.anton(false, 3), 18, 16, "SELECT GEAR", 11, Color("#ffb070"), 12.0)
	txt(self, bf, 18, 28, "모루에 올릴 장비", 30, Color.WHITE, 33.0)
	draw_set_transform(Vector2.ZERO)
	var L: Array = []
	for cc in arena.player.roster():
		for s in RN.SLOTS:
			var it = R().gear[cc][s[0]]
			if it != null: L.append([cc, s[0], it])
	var nr := L.filter(func(q): return R().has_rune_item(q[2])).size()
	var A := [["rune", "룬 각인", nr], ["plain", "룬 없음", L.size() - nr]]
	var x := 18.0
	for q in A:
		var on: bool = q[0] == gs
		var w: float = tw(f, q[1], 13) + 5.0 + tw(f, str(q[2]), 13) + 28.0
		var bm := Transform2D(0.0, Vector2(lx, 0)) * xf(Vector2(x, 71), Vector2(w / 2.0, 14.0), 0, 1, -12.0)
		if on: draw_colored_polygon(poly(Rect2(3, 3, w, 28), SQ, bm), col)
		var pts := poly(Rect2(0, 0, w, 28), SQ, bm)
		draw_colored_polygon(pts, Color.WHITE if on else Color(0.333, 0.333, 0.333))
		if not on: draw_colored_polygon(poly(Rect2(2, 2, w - 4, 24), SQ, bm), Color.BLACK)
		draw_set_transform_matrix(bm)
		var t0 := txt(self, f, 14, 5, q[1], 13, Color.BLACK if on else Color(0.667, 0.667, 0.667), 18.2)
		txt(self, f, 14 + t0 + 5.0, 5, str(q[2]), 13, Color(0, 0, 0, 0.55) if on else Color(0.667, 0.667, 0.667, 0.55), 18.2)
		draw_set_transform(Vector2.ZERO)
		var key: String = q[0]
		hb.append([pts, func():
			if gs == key: return
			gs = key
			mark("pickrows")
			sfx("ui_move", 0.5)])
		x += w + 6.0
	var V := L.filter(func(q): return (gs == "rune") == R().has_rune_item(q[2]))
	var y := 109.0
	var rw := (W - 18.0) * 0.88
	if V.is_empty():
		var s: String = "룬을 박은 장비가 없습니다." if gs == "rune" else "모든 장비에 룬이 박혀 있습니다."
		draw_colored_polygon(poly(Rect2(18, y, tw(f, s, 12) + 28.0, 38), SQ, Transform2D(0.0, Vector2(lx, 0))), Color.BLACK)
		txt(self, f, lx + 32, y + 10, s, 12, Color(0.667, 0.667, 0.667), 18.0)
	var rt := since("pickrows") if since("pickrows") < pt else pt - 120.0
	for i in V.size():
		var q: Array = V[i]
		var it: Dictionary = q[2]
		var on: bool = q[0] == c and q[1] == slot
		var hr: bool = R().has_rune_item(it)
		var e := UI.bez(0.2, 1.4, 0.4, 1.0, clampf((rt - mini(i, 8) * 35.0) / 380.0, 0.0, 1.0))
		var ea := clampf((rt - mini(i, 8) * 35.0) / 380.0, 0.0, 1.0)
		var h := 44.0
		if y + h > vs.y: break
		var rx := lx + 18.0 + (16.0 if on else 0.0) - 60.0 * (1.0 - e)
		var w := rw - (16.0 if on else 0.0)
		var gcl := RN.gcol(RN.RUNE[it["rune"]]["g"] if hr else it["g"])
		var m := Transform2D(0.0, Vector2(rx, y))
		var pts := poly(Rect2(0, 0, w, h), [[0, 0], [100, 0], [95, 100], [0, 100]], m)
		draw_colored_polygon(pts, Color(1, 1, 1, ea) if on else Color(0.078, 0.078, 0.078, ea))
		for q2 in Geometry2D.intersect_polygons(pts, poly(Rect2(0, 0, 5, h), SQ, m)): draw_colored_polygon(q2, Color(gcl, ea))
		draw_set_transform_matrix(m)
		gem(self, Vector2(5 + 10 + 11, 4 + 10), 7.0, Color(RN.gcol(it["g"]), ea))
		var fc := Color(0, 0, 0, ea) if on else Color(1, 1, 1, ea)
		var nx := 42.0 + txt(self, bf, 42, 4, it["n"], 15, fc, 17.25)
		txt(self, bf, nx + 6.0, 7, RN.gname(it["g"]), 10, Color(RN.gcol(it["g"]), ea), 11.5)
		var u := ("★%d" % int(it.get("rs", 1))) if hr else ("Lv %d" % int(it.get("lv", 0)))
		txt(self, UI.anton(true), w - 14.0 - tw(UI.anton(true), u, 20), 4, u, 20, fc, 20.0)
		var sub: String = RN.pname(q[0]) + " · " + RN.SLOTN[q[1]] + ((" · [%s]" % RN.RUNE[it["rune"]]["n"]) if hr else (" · Lv %d" % int(it.get("lv", 0))))
		txt(self, f, 42, 25, sub, 10, Color(0.267, 0.267, 0.267, ea) if on else Color(0.667, 0.667, 0.667, ea), 13.5)
		draw_set_transform(Vector2.ZERO)
		var c2: String = q[0]
		var s2: String = q[1]
		hb.append([pts, func():
			gear_close(func():
				if c2 == c and s2 == slot: return
				c = c2
				slot = s2
				eng = 0
				_pane_init(p, false)
				kick("anvil")
				mark("drop")
				jolt()
				say("[%s]이요? 좋지요. 올려 보지요." % R().gear[c][slot]["n"]))])
		y += h + 4.0

func pick_row(i: int) -> void:
	# script hook: tap row i of the gear pick
	var L: Array = []
	for cc in arena.player.roster():
		for s in RN.SLOTS:
			var it = R().gear[cc][s[0]]
			if it != null and (gs == "rune") == R().has_rune_item(it): L.append([cc, s[0]])
	if i >= L.size(): return
	var q: Array = L[i]
	gear_close(func():
		if q[0] == c and q[1] == slot: return
		c = q[0]
		slot = q[1]
		eng = 0
		_pane_init(p, false)
		kick("anvil")
		mark("drop")
		jolt()
		say("[%s]이요? 좋지요. 올려 보지요." % R().gear[c][slot]["n"]))


# ---------- result banners and the cut-in ----------
## .rbig: the colour band from the left, the black band from the right (220 ms), the big number, the letters (stamped
## from ×2.8 on a win, dropped on a miss; 110 ms + 34 ms each), the white sub tag (360 ms); sunk at 850 ms
func _rbig(vs: Vector2, col: Color, o: Dictionary) -> void:
	var k: float = t - o["t0"]
	var fail: bool = o["fail"]
	var sink: float = t - o["sink"]
	var gone_a := 1.0
	if o["sunk"] >= 0.0 and t > o["sunk"]: gone_a = 1.0 - clampf((t - o["sunk"]) / 220.0, 0.0, 1.0)
	var bandc: Color = Color("#6f7dff") if fail else col
	var E := EZ
	var IN := [0.6, 0.0, 0.9, 0.4]
	var c0 := vs / 2.0
	var bw := vs.x * 1.2
	# .rb2
	var x2 := -1.1 * bw * (1.0 - UI.bez(E[0], E[1], E[2], E[3], clampf(k / 220.0, 0.0, 1.0)))
	if sink > 0.0: x2 = 1.1 * bw * UI.bez(IN[0], IN[1], IN[2], IN[3], clampf(sink / 230.0, 0.0, 1.0))
	var r2 := Rect2(-vs.x * 0.1, vs.y * 0.25, bw, vs.y * 0.5)
	draw_colored_polygon(poly(Rect2(Vector2.ZERO, r2.size), [[0, 22], [64, 6], [100, 0], [100, 84], [40, 92], [0, 100]], Transform2D(0.0, Vector2(x2, 0)) * xf(r2.position, r2.size / 2.0, -7.0)), Color(bandc, gone_a))
	var x1 := 1.1 * bw * (1.0 - UI.bez(E[0], E[1], E[2], E[3], clampf((k - 40.0) / 220.0, 0.0, 1.0)))
	if sink > 30.0: x1 = -1.1 * bw * UI.bez(IN[0], IN[1], IN[2], IN[3], clampf((sink - 30.0) / 230.0, 0.0, 1.0))
	var r1 := Rect2(-vs.x * 0.1, vs.y * 0.31, bw, vs.y * 0.38)
	var m1 := Transform2D(0.0, Vector2(x1, 0)) * xf(r1.position, r1.size / 2.0, -7.0)
	var rb := poly(Rect2(Vector2.ZERO, r1.size), [[0, 8], [100, 0], [100, 100], [0, 90]], m1)
	draw_colored_polygon(rb, Color(0, 0, 0, gone_a))
	var sx := 60.0
	while sx < r1.size.x:
		for q in Geometry2D.intersect_polygons(rb, poly(Rect2(sx, 0, 2, r1.size.y), SQ, m1)): draw_colored_polygon(q, Color(1, 1, 1, 0.06 * gone_a))
		sx += 62.0
	# .rn: 92vh hollow Anton italic
	if o["big"] != "":
		var ba := AE.ez(E, clampf((k - 60.0) / 380.0, 0.0, 1.0))
		var bs := lerpf(1.5, 1.0, ba)
		if sink > 0.0:
			var kk := clampf(sink / 260.0, 0.0, 1.0)
			ba = 1.0 - kk
			bs = lerpf(1.0, 1.15, kk)
		var f := UI.anton(true)
		var fs := int(vs.y * 0.92)
		var w := tw(f, o["big"], fs)
		draw_set_transform_matrix(xf(c0 - Vector2(w / 2.0, fs * 0.8 * 0.54), Vector2(w / 2.0, fs * 0.8 * 0.54), -7.0, bs))
		draw_string_outline(f, Vector2(0, f.get_ascent(fs) - fs * 0.1), o["big"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(1, 1, 1, 0.55 * ba * gone_a))
	# .rw letters
	var lf := UI.anton(true)
	var fs2 := int(minf(vs.y * 0.31, vs.x * 0.17))
	var s: String = o["s"]
	var ws: Array = []
	var tot := 0.0
	for i in s.length():
		var sz := int(fs2 * 1.22) if i == 0 else fs2
		var ww := tw(lf, s[i], sz)
		ws.append(ww)
		tot += ww
	var lm := xf(c0 - Vector2(tot / 2.0, fs2 * 0.52), Vector2(tot / 2.0, fs2 * 0.52), -7.0)
	var x := 0.0
	for i in s.length():
		var sz := int(fs2 * 1.22) if i == 0 else fs2
		var d := k - 110.0 - i * 34.0
		var la := 0.0
		var ls := 1.0
		var blur := 0.0
		var ly := (-0.05 if i % 2 else 0.04) * fs2
		var lx := 0.0
		var lr := 0.0
		if fail:
			var u := clampf(d / 260.0, 0.0, 1.0)
			var e := UI.bez(0.3, 1.6, 0.5, 1.0, u)
			la = clampf(e, 0.0, 1.0) if d > 0.0 else 0.0
			ly = lerpf(-0.6 * fs2, ly, e)
		else:
			var u := clampf(d / 200.0, 0.0, 1.0)
			var e := UI.bez(0.2, 1.3, 0.4, 1.0, u)
			la = clampf(e, 0.0, 1.0) if d > 0.0 else 0.0
			ls = lerpf(2.8, 1.0, e)
			blur = 6.0 * (1.0 - clampf(e, 0.0, 1.0)) if d > 0.0 else 0.0
		if sink > 0.0:
			var kk := AE.ez("ease-in", clampf((sink - i * 14.0) / 200.0, 0.0, 1.0))
			la *= 1.0 - kk
			if fail:
				ly += 1.2 * fs2 * kk
				lr = (14.0 if i % 2 else -10.0) * kk
			else:
				lx = 1.4 * fs2 * kk
		var lc: Color = (Color("#6f7dff") if fail else col) if i == 0 else (Color("#c9d0ff") if fail else Color.WHITE)
		if la > 0.0:
			var w: float = ws[i]
			var m := lm * xf(Vector2(x + lx, ly + (0.06 * fs2 if i == 0 else 0.0) - (sz - fs2) * 0.8), Vector2(w / 2.0, sz / 2.0), lr, ls)
			draw_set_transform_matrix(m)
			var bp := Vector2(0, lf.get_ascent(sz) * 0.92)
			if blur > 0.4:
				# filter: blur(6px → 0): the letter spread into a soft glow (taps on two rings around it), scaled with the letter
				var rbl := blur / ls
				var ta := la * gone_a / 13.0 * 2.2
				draw_string(lf, bp, s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(lc, minf(1.0, ta * 1.6)))
				for kq in 12:
					var go := Vector2.from_angle(TAU * kq / 12.0) * rbl * (1.0 if kq % 2 else 0.5) * 1.6
					draw_string(lf, bp + go, s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(lc, minf(1.0, ta)))
			else:
				draw_string(lf, bp, s[i], HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(lc, la * gone_a))
		x += ws[i]
	draw_set_transform(Vector2.ZERO)
	# .rs: the sub tag
	if o["sub"] != "":
		var d := k - 360.0
		var u := clampf(d / 300.0, 0.0, 1.0)
		var e := UI.bk(u)
		var sa := clampf(e, 0.0, 1.0) if d > 0.0 else 0.0
		var ss := lerpf(2.0, 1.0, e)
		var sr := lerpf(-10.0, 0.0, e)
		var sxo := 0.0
		var syo := 0.0
		if sink > 0.0:
			var kk := AE.ez("ease-in", clampf((sink - s.length() * 14.0) / 200.0, 0.0, 1.0))
			sa *= 1.0 - kk
			if fail: syo = 1.2 * 22.0 * kk
			else: sxo = 1.4 * 22.0 * kk
		if sa > 0.0:
			var bf := UI.bhs()
			var w := tw(bf, o["sub"], 22) + 36.0
			var r := Rect2(vs.x / 2.0 - w / 2.0 + sxo, vs.y * 0.76 + syo, w, 33)
			var m := xf(r.position, r.size / 2.0, -7.0 + sr, ss)
			draw_colored_polygon(poly(Rect2(6, 6, w, 33), SQ, m), Color(0, 0, 0, sa * gone_a))
			draw_colored_polygon(poly(Rect2(0, 0, w, 33), SQ, m), Color(1, 1, 1, sa * gone_a))
			draw_set_transform_matrix(m)
			txt(self, bf, 18, 3, o["sub"], 22, Color(0, 0, 0, sa * gone_a), 26.0)
	draw_set_transform(Vector2.ZERO)

## .cut: three bands (black, her colour, the needle lines) and Bran's hammer pose slide in (340 ms), a flash, then out
func _cut(vs: Vector2, col: Color) -> void:
	var k := since("cut")
	var out := since("cutout")
	var ca := 1.0 - clampf(out / 220.0, 0.0, 1.0) if out < 1e8 else 1.0
	var cf := since("cutflash")
	var bri := 1.0
	var sat := 1.0
	if cf < 180.0:
		# cut.animate: brightness(1) → [35 %] brightness(6) saturate(0) → none, 180 ms ease-out over the whole run
		var u := AE.ez("ease-out", cf / 180.0)
		if u < 0.35:
			bri = lerpf(1.0, 6.0, u / 0.35)
			sat = lerpf(1.0, 0.0, u / 0.35)
		else:
			bri = lerpf(6.0, 1.0, (u - 0.35) / 0.65)
			sat = lerpf(0.0, 1.0, (u - 0.35) / 0.65)
	var E := [0.2, 0.8, 0.3, 1.0]
	var box := Rect2(-vs.x * 0.2, vs.y * 0.12, vs.x * 1.4, vs.y * 0.76)
	var band := func(kk: int) -> Array:
		var u := clampf((k - kk * 15.0) / 340.0, 0.0, 1.0)
		var e := UI.bez(E[0], E[1], E[2], E[3], u)
		var tx := 0.0
		var a := 0.0
		if e < 0.45:
			tx = lerpf(0.3, 0.0, e / 0.45)
			a = e / 0.45
		else:
			tx = lerpf(0.0, -0.02, (e - 0.45) / 0.55)
			a = 1.0
		return [Transform2D(0.0, Vector2(tx * box.size.x, 0)) * xf(box.position, box.size / 2.0, -8.0), a * ca]
	var b0: Array = band.call(0)
	var lift := func(cc: Color) -> Color:
		var r := minf(1.0, cc.r * bri)
		var g := minf(1.0, cc.g * bri)
		var b := minf(1.0, cc.b * bri)
		var l := 0.2126 * r + 0.7152 * g + 0.0722 * b
		return Color(lerpf(l, r, sat), lerpf(l, g, sat), lerpf(l, b, sat), cc.a)
	draw_colored_polygon(poly(Rect2(Vector2.ZERO, box.size), [[0, 10], [100, 0], [100, 90], [0, 100]], b0[0]), lift.call(Color(0.0, 0.0, 0.0, b0[1])))
	var cl := [[0, 55], [38, 40], [100, 4], [100, 86], [62, 70], [0, 70]]
	var b1: Array = band.call(1)
	var cwp := poly(Rect2(Vector2.ZERO, box.size), cl, b1[0])
	draw_colored_polygon(cwp, lift.call(Color(col, b1[1])))
	var b2: Array = band.call(2)
	var clp := poly(Rect2(Vector2.ZERO, box.size), cl, b2[0])
	var nd := clampf(k / 500.0, 0.0, 1.0)
	var ndx := lerpf(0.12, -0.06, UI.bez(0.2, 0.7, 0.4, 1.0, nd))
	var sw := box.size.x * 1.2
	for n in NDL:
		var pts := PackedVector2Array()
		for j in 4:
			pts.append(b2[0] * Vector2(-box.size.x * 0.1 + sw * ndx + n[j * 2] / 100.0 * sw, n[j * 2 + 1] / 100.0 * box.size.y))
		for q in Geometry2D.intersect_polygons(pts, clp): draw_colored_polygon(q, lift.call(Color(0, 0, 0, b2[1])))
	# the hammer pose: 150 % tall, centred, -4°
	var u := clampf(k / 340.0, 0.0, 1.0)
	var e := UI.bez(E[0], E[1], E[2], E[3], u)
	var h := vs.y * 1.5
	var w := h * HIT.get_width() / HIT.get_height()
	var tr: Vector2
	var rot: float
	var sc: float
	var ia: float
	if e < 0.45:
		var q := e / 0.45
		tr = Vector2(lerpf(-0.4, -0.5, q) * w, lerpf(-0.3, -0.44, q) * h)
		rot = lerpf(-1.0, -4.0, q)
		sc = lerpf(1.08, 1.0, q)
		ia = q
	else:
		var q := (e - 0.45) / 0.55
		tr = Vector2(lerpf(-0.5, -0.51, q) * w, lerpf(-0.44, -0.45, q) * h)
		rot = lerpf(-4.0, -4.5, q)
		sc = lerpf(1.0, 1.02, q)
		ia = 1.0
	var m := Transform2D(0.0, vs / 2.0 + tr + Vector2(w, h) / 2.0) * Transform2D(deg_to_rad(rot), Vector2(sc, sc), 0.0, Vector2.ZERO) * Transform2D(0.0, -Vector2(w, h) / 2.0)
	_sil(HIT, m, Vector2(w, h), ia * ca, bri)
