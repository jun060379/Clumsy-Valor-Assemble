extends RefCounted
## Bran, the guild blacksmith, at the anvil by the forge: idles, hammers (sparks fly on the impact frame), inspects his work,
## turns to you when you come near, and talks with the attack key. Ported from the prototype's BRAN / updBran / drawBran /
## branTalk / branGreet. Art: bran/px.png, 31 cells of 66x70, 1 art pixel = 2 world px.

const POR := preload("res://assets/bran/por.png")
const TF := preload("res://scripts/townsfolk.gd")
const PX := preload("res://assets/bran/px.png")
const ANVIL := preload("res://assets/town/q_anvil.png")
const CW := 66
const CHH := 70
const AX := 2.5
const FY := 69.5
const S := 2.0
const HX := 112.0
const MID := 25.0
const ANV_S := 0.72
const ANV_FACE := 42.0
const HIT := 6
## [frames, ms per frame (one number or one per frame)]; hammer: wind-up, hold at the top, fast drop, impact held, settle
const ANIM := {"idle": [[0, 1, 2, 3, 4, 5, 6], 190], "hammer": [[7, 8, 9, 10, 11, 12, 13, 14, 15, 16], [150, 130, 110, 100, 170, 60, 170, 110, 120, 140]],
	"inspect": [[17, 18, 19, 20, 21, 22, 23], [170, 160, 220, 240, 220, 160, 170]], "talk": [[24, 25, 26, 27, 28, 29, 30], 160]}
## his walk (tools/make_walk.py bran: the user's 25-frame walk shrunk to his art pixels and snapped to px.png's palette):
## cells of WCW x CHH art px, the body's column at WBX, the sole on row 69 like the forge cells. WALK_MS follows the
## art's spacing (each frame's planted-sole shift / WALK_SPD), so at WALK_SPD (69.9 world px a 1260 ms cycle) the boot
## under him stays put
const WALK := preload("res://assets/bran/walk.png")
const WCW := 59
const WBX := 23
const WALK_MS := [63, 62, 64, 76, 40, 62, 35, 20, 34, 43, 35, 56, 41, 60, 45, 65, 40, 62, 44, 68, 29, 50, 20, 33, 113]
const WALK_STRIDE := 69.9
const WALK_SPD := WALK_STRIDE / 1260.0
## a stroll: now and then, after an idle spell, he wanders STROLL_MIN..STROLL_MAX world px away from the anvil, stands a
## moment (STROLL_REST ms), and walks back to his spot to work again; someone near or talking stops him where he is
## (he turns to them; is_near / talk follow him), and he finishes the stroll once they are gone
const STROLL_P := 0.3
const STROLL_MIN := 40.0
const STROLL_MAX := 90.0
const STROLL_REST := 1400.0
const IDLE := ["흐흐, 오늘도 별일 없고.", "숯이 좀 모자란데… 내일 숯가마 돌려야겠군.", "덜떨어지게 탄 나무… 그게 숯이지요.", "염소 녀석, 또 마당 풀 다 뜯어먹었나.", "흠, 화로 온도 좋고.", "이 철은 쓸 만하겠는데. 흐흐."]
## small talk for the forge menu's "잡담한다" (the menu comes with the forge screen)
const CHAT := [["크흐, 크흐흐… 크흠.", "아, 전 원래 이렇게 웃으니 신경 쓰지 마십쇼."],
	["대장간 마당에 염소 한 마리 있는 거 보셨습니까?", "예전에 누가 염소로 변했던 일이 있었는데… 그 뒤로 그냥 불쌍해서 데려다 키우고 있어요.", "이 염소는 분명 특별하거든요. 잡초 제거도 잘 하고요. 흐흐."],
	["숯은 직접 굽습니다. 숯은 숯이죠. 덜떨어지게 탄 나무요.", "남는 건 바베큐라도 해 먹으면 될 일 아니겠습니까. 흐흐."],
	["다른 공구 없이 모루랑 망치만으로 집게 만드는 게 첫 과제였지요.", "집게가 있어야 쇠를 잡고, 쇠를 잡아야 뭘 만들거든요."],
	["약점을 찌르면 갑옷 입은 상대도 충분히 잡을 수 있어요.", "그러니까 갑옷은 이음매를 잘 덮어야 합니다. 거기가 늘 물렁하거든요."],
	["언젠가 저도 전신 판금 하나 맞춰 입고 다닐 생각입니다.", "…저 같은 놈은 장비 값 때문에 돈이 없지만요. 하하."],
	["원래는 농사도 좀 짓고, 농민병으로 칼이나 창 따위도 썼습니다.", "용병은 비교적 최근 일이고요. 쌓인 건 경험뿐이었죠. 흐흐."],
	["도망치는 건 부끄럽지만 도움이 된다~", "…아, 의뢰 나가서 하는 얘깁니다. 흐흐."],
	["연애 계획이요? 당장은 없습니다. 대장간 일도 바쁘고요.", "그래도 좋은 인연이 생긴다면… 음, 마다할 이유가 없지요. 크흐흐."]]
const CHAT_C := {"estelle": [["방패는 막는 거지 버티는 게 아니라고들 하는데.", "벨라시타는 버티는 쪽이지요. 그래서 테두리는 늘 두껍게 해 둡니다. 흐흐."]],
	"aida": [["아이다 씨 삽은 이상하게 날이 잘 안 상합니다.", "…흑주술 같은 거 묻혀서 쓰는 건 아니지요? 그럼 제 손엔 안 맞을 텐데. 흐흐."]],
	"kenin": [["(임시) 케닌 씨 총은 부싯돌을 자주 갈아야 합니다.", "(임시) 화약은… 대장간 안에선 꺼내지 말아 주세요. 흐흐."]],     # PLACEHOLDER lines
	"luce": [["성물도 쇠로 만드는 게 많습니다. 손잡이 감는 정도는 저도 하지요.", "기도는… 그쪽 담당이고요. 저는 사제도 아니고 판관도 아닌걸요."]]}

var town
var arena
var anim := "idle"
var f := 0
var ft := 0.0
var loops := 0
var swings := 0
var dir := 1
var say := ""
var say_t := 0.0
var talk_t := 0.0
var x := 0.0
var y := 0.0
var anvil_left := 0.0
var home := 0.0               # his spot at the anvil
var goal := NAN               # where the stroll is headed (NAN = not strolling)
var rest := 0.0               # the stroll's pause at its far end (ms)
var strolls := 0              # strolls begun (tests)


func _init(tn) -> void:
	town = tn
	arena = tn.arena
	# the anvil where the prototype puts it (BM('g_anvil', 7695, LOWF)); his spot: the hammer head lands on its face
	var aw: float = town.tex["g_anvil"].get_width()
	var ax := 7695.0 + aw / 2.0
	anvil_left = roundf(ax + (7695.0 - ax) * town.BS)
	x = anvil_left + roundf(ANV_FACE * ANV_S) - HX
	home = x
	y = town.LOWF

func play(a: String) -> void:
	if anim != a:
		anim = a
		f = 0
		ft = 0.0
		loops = 0

func _dur(i: int) -> float:
	if anim == "walk": return float(WALK_MS[i])
	var d = ANIM[anim][1]
	return float(d[i]) if d is Array else float(d)

func _frames() -> Array:
	return range(WALK_MS.size()) if anim == "walk" else ANIM[anim][0]

## out for a stroll (walking, or resting at its far end, or on the way back)
func strolling() -> bool:
	return not is_nan(goal)

## begin a stroll: out, away from the anvil (to the left, the way his back faces), then back home
func stroll(d := -1.0) -> void:
	goal = home + signf(d) * (STROLL_MIN + randf() * (STROLL_MAX - STROLL_MIN))
	rest = STROLL_REST
	strolls += 1
	play("walk")

func is_near(P) -> bool:
	return absf(P.position.x - x - MID) < 95.0 and absf(P.position.y - y) < 30.0

func talking() -> bool:
	return arena.dlg != null and arena.dlg.active and arena.dlg.who == "bran"

func step(dt: float) -> void:
	var P = arena.player
	say_t = maxf(0.0, say_t - dt)
	if talk_t > 0.0: talk_t -= dt
	var busy := is_near(P) or talk_t > 0.0 or talking()
	# the hammer only swings at his spot, facing the anvil; anyone near and he stops and turns to them
	if busy:
		if anim == "hammer" or anim == "inspect" or anim == "walk": play("talk")
		dir = -1 if P.position.x < x + MID else 1
	elif strolling():
		# the stroll: walk to the goal at the art's pace, rest there, walk home; then back to work
		if absf(goal - x) > 0.5:
			play("walk")
			dir = 1 if goal > x else -1
			x = move_toward(x, goal, WALK_SPD * dt)
		elif goal != home:
			if anim != "idle": play("idle")
			rest -= dt
			if rest <= 0.0: goal = home
		else:
			x = home
			goal = NAN
			dir = 1
			play("idle")
	elif anim == "idle" and f == 0:
		dir = 1
	var frames: Array = _frames()
	ft += dt
	while ft >= _dur(f):
		ft -= _dur(f)
		f += 1
		if anim == "hammer" and f == HIT:
			var fxp := anvil_left + ANV_FACE * ANV_S
			var v := maxf(0.0, 1.0 - absf(P.position.x - x) / 700.0)
			if v > 0.05: arena.sfx("hit", 0.25 * v)
			for i in 8:
				town.tfx.append({"k": "spark", "x": fxp + (randf() - 0.5) * 10.0, "y": y - 19.0, "vx": (randf() - 0.35) * 0.28, "vy": -0.08 - randf() * 0.16, "t": 0.0, "life": 420.0})
		frames = _frames()
		if f >= frames.size():
			f = 0
			loops += 1
			var B := anim
			if B == "talk":
				play("idle")
			elif B == "walk" or strolling():
				pass                                   # the stroll steers itself (above)
			elif B == "idle" and loops >= 2 and not busy and randf() < STROLL_P:
				stroll()
			elif B == "idle" and loops >= 2 and not busy:
				dir = 1
				swings = 3 + randi() % 3
				play("hammer")
			elif B == "hammer" and loops >= swings:
				play("inspect" if randf() < 0.45 else "idle")
				if randf() < 0.3 and say_t <= 0.0:
					say = IDLE[randi() % IDLE.size()]
					say_t = 2600.0
			elif B == "inspect":
				play("idle")

func draw(ci: CanvasItem) -> void:
	var vr: Rect2 = arena.view_rect()
	if x < vr.position.x - 250.0 or x > vr.end.x + 250.0: return
	# the anvil behind him: the hammer head reads as landing on its face
	var aw := roundf(ANVIL.get_width() * ANV_S)
	var ah := roundf(ANVIL.get_height() * ANV_S)
	ci.draw_texture_rect(ANVIL, Rect2(anvil_left, town.LOWF - ah, aw, ah), false)
	if anim == "walk":
		# the walk's cells: the body's column on his body line (x + MID), mirrored about it walking left
		ci.draw_set_transform(Vector2(roundf(x) + MID, roundf(y)), 0.0, Vector2(S * dir, S))
		ci.draw_texture_rect_region(WALK, Rect2(-WBX, -FY, WCW, CHH), Rect2(mini(f, WALK_MS.size() - 1) * WCW, 0, WCW, CHH))
		ci.draw_set_transform(Vector2.ZERO)
		return
	var frames: Array = ANIM[anim][0]
	var fi: int = frames[mini(f, frames.size() - 1)]
	ci.draw_set_transform(Vector2(roundf(x) + (2.0 * MID if dir < 0 else 0.0), roundf(y)), 0.0, Vector2(S * dir, S))
	ci.draw_texture_rect_region(PX, Rect2(-AX, -FY, CW, CHH), Rect2(fi * CW, 0, CW, CHH))
	ci.draw_set_transform(Vector2.ZERO)

func draw_bubble(ci: CanvasItem, fnt: Font) -> void:
	var vr: Rect2 = arena.view_rect()
	if say_t <= 0.0 or x + MID < vr.position.x - 100.0 or x + MID > vr.end.x + 100.0: return
	TF.bubble(ci, fnt, vr, x + MID, y - 150.0, say, say_t)


# ---------- talking ----------
func greet() -> Array:
	if not arena.has_meta("bran_met"):
		arena.set_meta("bran_met", true)
		return ["엄, 브랜입니다. 그냥 브랜이에요. 브랜드 할 때처럼요.", "여기 대장간 빌려서 일하고 있습니다. 찌그러진 거 있으면 가져오십쇼. 흐흐."]
	var hr: float = fposmod(arena.tod_h, 24.0)
	var pool := []
	var R = arena.get("runes")
	if R != null and R.runebag.keys().any(func(r): return int(R.runebag[r]) > 0 and R.RUNE.has(r) and R.RUNE[r]["g"] in ["legend", "unique"]):
		pool.append(["…잠깐, 그 가방에 든 거. 그거 보통 룬이 아니지요?", "박을 거면 지금 하시죠. 화로는 달궈놨습니다. 흐흐."])
	if arena.shilling < 3: pool.append(["실링이 바닥났군요.", "돈만 있다면야 못 할 게 없는데… 훈련장 유령들이 꽤 떨군다던데요. 흐흐."])
	if hr >= 21.0 or hr < 5.0: pool.append(["이 시간까지 안 자고 뭐 합니까.", "…뭐, 저도 마찬가지지만요. 크흐흐."])
	match arena.player.who:
		"estelle":
			pool.append(["오, 벨라시타. 방패 또 찌그러뜨린 건 아니지요?"])
			pool.append(["의족은 괜찮습니까? 삐걱거리면 바로 가져오십쇼. 그쪽이 더 급합니다."])
		"aida":
			pool.append(["아이다 씨. 삽 날 좀 세워 드릴까요? 흙이 잔뜩 꼈는데. 흐흐."])
		"kenin":
			pool.append(["(임시) 케닌 씨, 화약 냄새가 대장간까지 납니다. 흐흐."])     # PLACEHOLDER
		"luce":
			pool.append(["루체 씨, 불똥 튑니다. 너무 가까이 오진 마십쇼."])
			pool.append(["루체 씨 몇 살이랬지요? …아뇨, 그냥 망치 들기엔 아직 이른가 싶어서."])
	pool.append(["흐흐, 왔습니까."])
	pool.append(["예, 브랜입니다. 뭐 도와 드릴까요?"])
	pool.append(["엄, 무슨 일이시지요?"])
	return pool[randi() % pool.size()]

func talk() -> void:
	if arena.dlg != null and arena.dlg.locked(): return     # branTalk: TALKLOCK
	talk_t = 2000.0
	play("talk")
	var M = arena.ui_root.menu if arena.ui_root != null else null
	# before he joins the guild (fame.bran): only a word, then off to Eilin
	if M != null and not M.bran_page.joined():
		arena.open_dialog("bran", POR, "브랜", "길드 대장장이", ["…길드 쪽 사람이오? 처음 보는 얼굴인데."], func():
			talk_t = 600.0
			M.open_bran(false, "접수대의 에일린한테 먼저 인사부터 하고 오쇼. 일 하나 끝내고 오면, 그때 얘기합시다. 흐흐."))
		return
	if arena.fame != null: arena.fame.finc("bran")     # counts toward the guild requests (fame.gd)
	var L := greet()
	# his last line stays up with the choices (branTalk): 장비를 맡기고 싶어요 · 잡담한다 · 그만 가볼게요
	var head: Array = L.slice(0, L.size() - 1)
	var last: String = L[L.size() - 1]
	var go := func():
		talk_t = 600.0
		if M != null: M.open_bran(false, last)
	if head.is_empty(): go.call()
	else: arena.open_dialog("bran", POR, "브랜", "길드 대장장이", head, go)
