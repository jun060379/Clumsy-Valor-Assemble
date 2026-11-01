extends SceneTree
## W3: the talk box's behaviour (keys, taps, drag, TALKLOCK, 자동 / 건너뛰기, Eilin's blink), the character screen's
## presence on 상세 (react, sblink, pointer), the hall's facility states, bran_met in the save, the town objective while
## alone, the key glyph in prompts (KH), qWatch, and the level road's spring.
## godot --headless --path . -s tests/test_w3.gd

const HUD := preload("res://scripts/hud.gd")
const HALL := preload("res://scripts/hall.gd")
const DLG := preload("res://scripts/dialog.gd")

var fails := 0
var arena

func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	if not ok: fails += 1

func key(k: int) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	root.push_input(e, true)
	var e2 := e.duplicate()
	e2.pressed = false
	root.push_input(e2, true)

func mouse(p: Vector2, down: bool, touch := true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p
	e.device = InputEvent.DEVICE_ID_EMULATION if touch else 0
	root.push_input(e, true)

func motion(p: Vector2, held: bool, touch := true) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	e.device = InputEvent.DEVICE_ID_EMULATION if touch else 0
	root.push_input(e, true)

## open a choice talk and get it to the choosing state, its choices laid out
func ask(C: Array, L := ["한 줄"]) -> void:
	arena.dlg.ask("eilin", load("res://assets/eilin/por.png"), "에일린", "길드 접수원", L, C)
	arena.dlg.i = L.size() - 1
	arena.dlg.shown = 999.0
	arena.dlg.t = 500.0
	arena.dlg.talk.open_t = 5000.0
	arena.dlg.queue_redraw()
	await process_frame
	await process_frame
	arena.dlg.talk.ch_t = 5000.0          # the choices have swung in
	arena.dlg.queue_redraw()
	await process_frame
	await process_frame

func _initialize() -> void:
	arena = load("res://scenes/main.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	for i in 3: arena._process(0.016)
	var D = arena.dlg
	var got := [-1]

	# ---------- WP3: keys ----------
	var C := [["하나", func(): got[0] = 0], ["둘", func(): got[0] = 1], ["셋", func(): got[0] = 2], ["그만 가볼게요", func(): got[0] = 3]]
	await ask(C)
	check(D.choosing() and D.ch_i == -1, "the choices come up with nothing chosen")
	key(KEY_DOWN)
	await process_frame
	check(D.ch_i == 0 and D.active, "↓ picks the first, nothing fires")
	key(KEY_DOWN)
	key(KEY_UP)
	await process_frame
	check(D.ch_i == 0, "↓ then ↑ comes back")
	key(KEY_W)
	await process_frame
	check(D.ch_i == 3, "W wraps to the last")
	key(KEY_3)
	await process_frame
	check(got[0] == 2 and not D.active, "3 picks and confirms the third")
	check(D.locked() and D.lock_until - Time.get_ticks_msec() <= 700, "any talk leaves a 0.7 s breather")
	await ask(C)
	key(KEY_ENTER)
	await process_frame
	check(D.active and D.ch_i == 0, "Enter with nothing chosen only picks the first")
	key(KEY_SPACE)
	await process_frame
	check(got[0] == 0 and not D.active, "Space confirms the chosen one")
	await ask(C)
	key(KEY_ESCAPE)
	await process_frame
	check(got[0] == 3 and not D.active, "Esc takes the goodbye (그만 가볼게요)")
	check(D.lock_until - Time.get_ticks_msec() > 4000, "after a goodbye, 5 s before the next talk")
	await ask([["좋은 저녁 보내요", func(): got[0] = 7, "leave"], ["다른 것", func(): got[0] = 8]])
	key(KEY_ESCAPE)
	await process_frame
	check(got[0] == 7, "Esc finds the choice with the leave icon")
	await ask([["하나", func(): got[0] = 9]])
	got[0] = -1
	key(KEY_ESCAPE)
	await process_frame
	check(got[0] == -1 and D.active, "no goodbye: Esc does nothing")
	D._pick(0)
	check(DLG.is_leave(["나중에 올게요", null, "leave"]) and DLG.is_leave(["그만 가볼게요", null]) and not DLG.is_leave(["좋아요", null]), "isLeave: the icon or 그만 / 나간 / 안녕")

	# ---------- WP3: taps, hover, drag ----------
	await ask(C)
	var p1: Vector2 = (D.talk.ch_polys[1] as PackedVector2Array)[0].lerp((D.talk.ch_polys[1] as PackedVector2Array)[2], 0.5)
	mouse(p1, true)
	mouse(p1, false)
	await process_frame
	check(D.active and D.ch_i == 1, "a first tap selects")
	mouse(p1, true)
	mouse(p1, false)
	await process_frame
	check(not D.active and got[0] == 1, "a second tap on it confirms")
	await ask(C)
	motion(p1, false, false)
	await process_frame
	check(D.ch_i == 1, "the mouse selects by hovering")
	mouse(p1, true, false)
	mouse(p1, false, false)
	await process_frame
	check(not D.active and got[0] == 1, "a click on the hovered one confirms")
	var C6: Array = []
	for k in 7: C6.append(["선택지 %d" % (k + 1), func(): got[0] = 100 + k])
	await ask(C6)
	check(D.talk.ch_max > 0.0, "seven choices outgrow the box (it scrolls: %.0f px)" % D.talk.ch_max)
	var pc: Vector2 = (D.talk.ch_polys[0] as PackedVector2Array)[0].lerp((D.talk.ch_polys[0] as PackedVector2Array)[2], 0.5)
	got[0] = -1
	mouse(pc, true)
	motion(pc + Vector2(0, -40), true)
	motion(pc + Vector2(0, -90), true)
	mouse(pc + Vector2(0, -90), false)
	await process_frame
	check(D.talk.scroll > 30.0 and D.active and got[0] == -1 and D.ch_i == -1, "a drag scrolls (%.0f px) and never counts as a tap" % D.talk.scroll)
	D.talk.scroll = 0.0
	D.ch_i = -1
	key(KEY_UP)
	await process_frame
	D.queue_redraw()
	await process_frame
	check(D.ch_i == 6 and D.talk.scroll >= D.talk.ch_max - 1.0, "a key on a row out of view scrolls it in")
	D._pick(0)

	# ---------- WP3: lines, 자동, 건너뛰기, a tap anywhere, the key held off the game ----------
	arena.open_dialog("eilin", null, "에일린", "길드 접수원", ["하나", "둘", "셋"])
	DLG.auto = false
	D.step(16.0)
	D.shown = 99.0
	D.t = 500.0
	key(KEY_E)
	await process_frame
	check(D.i == 1, "E turns the page")
	D.shown = 99.0
	D.t = 500.0
	mouse(Vector2(40, 40), true)
	await process_frame
	check(D.i == 2, "a tap anywhere turns the page")
	D.i = 0
	D.shown = 99.0
	D.toggle_auto()
	check(DLG.auto and D.i == 1, "자동 on over a finished line turns it at once")
	D.shown = 99.0
	for k in 10: D.step(160.0)
	check(D.i == 2, "자동: the next line turns by itself after 1.5 s")
	D.toggle_auto()
	D.i = 0
	D.shown = 0.0
	D.skip()
	check(D.i == 2 and not D.typing(), "건너뛰기: straight to the last line, written out")
	D.t = 500.0
	key(KEY_X)
	await process_frame
	check(not D.active and D.blk_until > Time.get_ticks_msec(), "the last line closes; the closing key is held off the game")
	D.queue_redraw()
	await ask(C)
	check(D.talk.top_rects.size() == 2, "자동 · 건너뛰기 are drawn")
	var tr0: Rect2 = D.talk.top_rects[0]
	mouse(tr0.get_center(), true)
	await process_frame
	check(DLG.auto and D.active, "a tap on 자동 toggles it")
	DLG.auto = false
	D._pick(0)

	# ---------- WP3: her blink, the PC scale ----------
	arena.open_dialog("eilin", load("res://assets/eilin/por.png"), "에일린", "길드 접수원", ["하나"])
	D.bl_t = 10.0
	D.step(40.0)
	check(D.talk.por == D.POR_BLINK, "her portrait shuts its eyes on its own clock")
	D.bl_t = 2000.0
	D.step(16.0)
	check(D.talk.por == D.por, "…and opens them")
	D.advance()
	D.advance()
	check(is_equal_approx(D.talk.dk(Vector2(360, 640)), 1.0) and is_equal_approx(D.talk.dk(Vector2(1920, 1080)), 1.75), "--dk: phones 1×, PC up to 1.75×")

	# ---------- TALKLOCK on Bran ----------
	arena.go_town(Vector2(640, arena.ground_y), 1)
	for i in 5: arena._process(0.016)
	D.lock_until = Time.get_ticks_msec() + 5000
	arena.level.bran.talk()
	check(not D.active, "Bran won't talk inside the TALKLOCK")
	var B = arena.level.bran
	arena.player.position = Vector2(B.x + B.MID, B.y)
	arena.level.step(16.0)
	check(arena.level.near_door == null or arena.level.near_door.get("act", "") != "bran", "…and offers no talk prompt")
	D.lock_until = 0
	arena.level.bran.talk()
	var M = arena.ui_root.menu
	check(D.active or M.page == "bran", "after it, he does")
	if D.active: D._close()
	if M.page == "bran": M.page = ""

	# ---------- WP15: the town objective while alone ----------
	var hud = null
	for c in arena.find_children("*", "Control", true, false):
		if c.get_script() == HUD: hud = c
	var party: Array = arena.player.party.duplicate()
	arena.player.party = [arena.player.who]
	var fo: String = arena.fame.fame_obj()
	check(fo != "" or hud._objective() == "분수대에서 파티를 꾸리자", "alone with nothing else to do: 분수대에서 파티를 꾸리자")
	arena.player.party = party
	var keep: Array = [arena.fame.intro, arena.fame.got.duplicate()]
	arena.fame.intro = 1
	arena.fame.got["r1a"] = 1
	arena.player.party = [arena.player.who]
	var rec0: Array = arena.fame.rec.duplicate()
	arena.fame.rec = ["estelle"]
	if arena.fame.fame_obj() == "": check(hud._objective() == "", "no fallback while nobody else has joined (ROSTER.length>1)")
	arena.fame.rec = ["estelle", "aida"]
	if arena.fame.fame_obj() == "": check(hud._objective() == "분수대에서 파티를 꾸리자", "the fallback shows when fameObj has nothing")
	arena.fame.rec = rec0
	arena.player.party = ["estelle", "aida"]
	if arena.fame.fame_obj() == "": check(hud._objective() == "", "with a party, no fallback")
	arena.player.party = party
	arena.fame.intro = keep[0]
	arena.fame.got = keep[1]

	# ---------- WP15: bran_met in the save ----------
	var SG = arena.save_game if arena.get("save_game") != null else null
	if SG == null:
		SG = load("res://scripts/save_game.gd").new(arena)
	arena.set_meta("bran_met", true)
	var snap: Dictionary = SG.snapshot()
	check(snap.get("bran_met", false) == true, "the save keeps bran_met")
	arena.remove_meta("bran_met")
	SG.apply(JSON.parse_string(JSON.stringify(snap)))
	check(arena.has_meta("bran_met"), "…and a reload restores it (his first lines don't replay)")
	var g2: Array = arena.level.bran.greet()
	check(g2[0] != "엄, 브랜입니다. 그냥 브랜이에요. 브랜드 할 때처럼요.", "the second greeting differs")

	# ---------- WP15: the chandelier's filter ----------
	var im := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	im.set_pixel(0, 0, Color(1, 0, 0, 1))
	var o: Color = HALL.dim_image(im, 0.45, 0.6).get_pixel(0, 0)
	check(absf(o.r - 0.45 * (0.213 + 0.787 * 0.6)) < 0.01 and absf(o.g - 0.45 * 0.213 * 0.4) < 0.01, "brightness(.45) saturate(.6) as CSS (%.3f %.3f %.3f)" % [o.r, o.g, o.b])

	# ---------- WP17: KH, qWatch ----------
	var cfg = arena.cfg
	var dev0: String = cfg.dev
	cfg.dev = "kbm"
	check(cfg.kh() == "X ", "KH on keyboard: X")
	cfg.dev = "pad"
	check(cfg.kh() == "Ⓧ ", "KH on a pad: Ⓧ")
	cfg.dev = "touch"
	check(cfg.kh() == "", "KH on touch: nothing")
	cfg.dev = dev0
	var qk0: float = cfg.qk
	cfg.qk = 1.0
	var dropped := false
	for i in 150: dropped = cfg.qwatch(16.0, false) or dropped
	check(not dropped and cfg.qk == 1.0, "qWatch: quick frames leave QK alone")
	for i in 150: dropped = cfg.qwatch(30.0, false) or dropped
	check(dropped and is_equal_approx(cfg.qk, 0.8), "qWatch: 150 long frames lower QK to 0.8")
	for i in 150: cfg.qwatch(30.0, false)
	check(is_equal_approx(cfg.qk, 0.8), "…then 3 s before it looks again")
	for i in 400: cfg.qwatch(30.0, false)
	check(cfg.qk >= 0.6 - 0.001, "it never goes below 0.6 (%.2f)" % cfg.qk)
	cfg.qk = qk0
	cfg.qw = {"n": 0, "s": 0.0, "cool": 0.0}
	cfg.save()
	cfg.apply_qk()

	# ---------- WP17: the level road ----------
	var BK = arena.ui_root.menu.book
	var mx: float = BK._road_max()
	check(BK.road_rb(-100.0) > -100.0 and BK.road_rb(-100.0) < 0.0 and BK.road_rb(mx + 100.0) < mx + 100.0, "rubber band past the ends")
	BK.scroll["lv"] = 0.0
	BK.road_fling([[0.0, 500.0], [100.0, 200.0]])
	check(BK.road_sp != null and fmod(BK.road_sp.t, BK.ROAD_STEP) == 0.0 or is_equal_approx(BK.road_sp.t, mx), "a flick snaps to a card (target %.0f)" % BK.road_sp.t)
	check(BK.road_sp.t > 128.0, "a flick to the left carries on past the finger")
	for i in 200: BK.road_sp.step(16.0)
	check(absf(BK.road_sp.x - BK.road_sp.t) < 1.0, "the spring settles on it")
	BK.road_sp = null

	# ---------- WP14: 상세 presence ----------
	var CH = arena.ui_root.menu.ext["char"]
	CH.c = "estelle"
	CH.tab = "attr"
	CH.react_tap()
	check(CH.react == "smile" and CH.jolt == "hop" and CH.face_path().ends_with("estelle_smile.webp"), "a tap: smile, hop, ♪")
	CH._tick(1800.0)
	check(CH.react == "", "the smile fades after 1.7 s")
	CH.t += 2000.0
	CH.react_tap()
	CH.react_tap()
	CH.react_tap()
	check(CH.react == "sup" and CH.jolt == "shake" and CH.taps.is_empty(), "three quick taps: surprise, shake, !!")
	CH._tick(1600.0)
	CH.blk_next = 1.0
	CH._tick(2.0)
	check(CH.blk > 0.0 and CH.face_path().ends_with("estelle_cl.webp"), "the art blinks on its base face")
	for f in ["estelle", "aida", "luce"]:
		check(ResourceLoader.exists("res://assets/ui/st/%s_smile.webp" % f) and ResourceLoader.exists("res://assets/ui/st/%s_ser.webp" % f), "%s has smile / ser faces" % f)
	CH.hover = Vector2(-999, -999)
	check(CH.ptr(Vector2(900, 500)) == Vector2.ZERO, "no pointer yet: no parallax")
	CH.hover = Vector2(900, 0)
	check(CH.ptr(Vector2(900, 500)) == Vector2(1, -1), "--px / --py from the pointer")

	print("FAILS: %d" % fails)
	quit()
