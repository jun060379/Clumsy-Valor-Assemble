extends Control
## Party screen at the fountain (prototype #party openParty / renderParty): a card per member with the portrait,
## the status (조작 중 / 파티 / 마을) and 빼기·넣기 / 조작 / 정보. Up to 3 in the party, never fewer than 1 (the one in
## control can't be taken out). A member taken out waits by the fountain (townsfolk.leave_party). Saved at once.
## ←/→ move between buttons, Enter presses, Esc or 닫기 closes.

const UI := preload("res://scripts/ui_kit.gd")
const CH := preload("res://scripts/chars.gd")
const ROSTER := ["estelle", "aida", "luce"]
const G1 := Color("#d9b878")
const GL := Color(194 / 255.0, 161 / 255.0, 96 / 255.0, 0.55)

var arena
var sortie
var open := false
var t := 0.0
var por := {}
var btns: Array = []             # [{rect, c, act, on}]
var r_close := Rect2()
var focus := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	for c in ROSTER:
		por[c] = load("res://assets/ui/st/%s_base.webp" % c)

func show_it() -> void:
	open = true
	visible = true
	t = 0.0
	focus = 0
	for a in ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "ult", "swap"]:
		if InputMap.has_action(a): Input.action_release(a)
	arena.sfx("ready", 0.5)

func close() -> void:
	open = false
	visible = false
	arena.sfx("ready", 0.25)

func press(c: String, act: String) -> void:
	var P = arena.player
	var lead: bool = c == P.who
	match act:
		"out":
			if lead or not P.party.has(c) or P.party.size() < 2: return
			arena.toggle_member(c)
		"in":
			if P.party.has(c) or P.party.size() >= 3: return
			arena.toggle_member(c)
		"ctl":
			if lead: return
			if not P.party.has(c):
				if P.party.size() >= 3:
					var out: String = P.party.filter(func(x): return x != P.who).back()
					arena.toggle_member(out)
				arena.toggle_member(c)
			P.swap_cd = 0.0
			P.swap(false, c)
			P.swap_cd = 0.0
		"info":
			return
	arena.sfx("ready", 0.4)
	arena.save_now()

func _input(ev: InputEvent) -> void:
	if not open: return
	var handled := ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton or ev is InputEventScreenTouch
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if r_close.grow(4).has_point(ev.position):
			close()
		else:
			for b in btns:
				if b["rect"].has_point(ev.position) and b["on"]:
					press(b["c"], b["act"])
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		if k == KEY_ESCAPE: close()
		elif k == KEY_LEFT: focus = maxi(0, focus - 1)
		elif k == KEY_RIGHT: focus = mini(btns.size(), focus + 1)
		elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_X]: _press_focus()
	elif ev is InputEventJoypadButton and ev.pressed:
		if ev.button_index == JOY_BUTTON_B: close()
		elif ev.button_index == JOY_BUTTON_DPAD_LEFT: focus = maxi(0, focus - 1)
		elif ev.button_index == JOY_BUTTON_DPAD_RIGHT: focus = mini(btns.size(), focus + 1)
		elif ev.button_index == JOY_BUTTON_A: _press_focus()
	if handled: get_viewport().set_input_as_handled()

func _press_focus() -> void:
	if focus >= btns.size(): close()
	elif btns[focus]["on"]: press(btns[focus]["c"], btns[focus]["act"])

func _process(delta: float) -> void:
	if not open: return
	t += minf(delta * 1000.0, 100.0)
	queue_redraw()

func _draw() -> void:
	if not open: return
	var vs := get_viewport_rect().size
	var P = arena.player
	draw_rect(Rect2(Vector2.ZERO, vs), Color(4 / 255.0, 3 / 255.0, 8 / 255.0, 0.72))
	var cw := 118.0
	var gap := 10.0
	var bw := ROSTER.size() * cw + (ROSTER.size() - 1) * gap + 32.0
	var bh := 290.0
	var box := Rect2((vs.x - bw) / 2.0, (vs.y - bh) / 2.0, bw, bh)
	draw_rect(box, Color("#1c1624"))
	draw_rect(Rect2(box.position, Vector2(box.size.x, box.size.y * 0.5)), Color("#221b2c"))
	draw_rect(box, Color("#c2a160"), false, 1.0)
	draw_rect(box.grow(4), Color(194 / 255.0, 161 / 255.0, 96 / 255.0, 0.25), false, 1.0)
	# title with the hairlines
	var f := UI.spaced(UI.noto(), 6)
	var title := "파티 편성"
	var tw := UI.text_w(f, title, 15)
	var cnt := "%d / 3" % P.party.size()
	var cntw := UI.text_w(UI.noto(), cnt, 13)
	var tx := box.get_center().x - (tw + 10.0 + cntw) / 2.0
	var ty := box.position.y + 28.0
	draw_string(f, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, G1)
	draw_string(UI.noto(), Vector2(tx + tw + 10.0, ty), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e2d2a8"))
	draw_line(Vector2(tx - 132.0, ty - 5.0), Vector2(tx - 12.0, ty - 5.0), GL, 1.0)
	draw_line(Vector2(tx + tw + cntw + 22.0, ty - 5.0), Vector2(tx + tw + cntw + 142.0, ty - 5.0), GL, 1.0)
	btns.clear()
	var x := box.position.x + 16.0
	var y := box.position.y + 42.0
	for c in ROSTER:
		var inP: bool = P.party.has(c)
		var lead: bool = c == P.who
		var card := Rect2(x, y, cw, 196.0)
		var a := 1.0 if inP else 0.72
		draw_rect(card, Color(1, 1, 1, 0.04 * a))
		draw_rect(card, Color(G1, a) if lead else (GL if inP else Color(194 / 255.0, 161 / 255.0, 96 / 255.0, 0.3)), false, 1.0)
		if lead: draw_rect(card, Color(194 / 255.0, 161 / 255.0, 96 / 255.0, 0.14))
		# portrait: cover, 50% 12%, fading out at the bottom
		var tex: Texture2D = por[c]
		var pr := Rect2(x + 6.0, y + 6.0, cw - 12.0, 96.0)
		var sw: float = tex.get_width()
		var shh: float = sw * pr.size.y / pr.size.x
		var src := Rect2(0, (tex.get_height() - shh) * 0.12, sw, shh)
		var steps := 8
		for i in steps:
			var k0 := float(i) / steps
			var fade := 1.0 if k0 < 0.7 else 1.0 - (k0 - 0.7) / 0.3
			draw_texture_rect_region(tex, Rect2(pr.position.x, pr.position.y + pr.size.y * k0, pr.size.x, pr.size.y / steps + 0.5), Rect2(src.position.x, src.position.y + src.size.y * k0, src.size.x, src.size.y / steps), Color(1, 1, 1, a * fade))
		var nm: String = CH.NAME[c] + (" ★" if lead else "")
		var bf := UI.noto_k()
		var nw := UI.text_w(bf, nm, 15)
		draw_string(bf, Vector2(card.get_center().x - nw / 2.0, y + 124.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Color("#f3e3b6"), a))
		var stt := "조작 중" if lead else ("파티" if inP else "마을")
		var sw2 := UI.text_w(UI.noto(), stt, 12)
		draw_string(UI.noto(), Vector2(card.get_center().x - sw2 / 2.0, y + 144.0), stt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Color("#e2d2a8"), a))
		var acts := [["out" if inP else "in", "빼기" if inP else "넣기", not lead and (inP or P.party.size() < 3) and not (inP and P.party.size() < 2)], ["ctl", "조작", not lead], ["info", "정보", false]]
		var bx := x + 6.0
		var bws := [36.0, 36.0, 36.0]
		for i in acts.size():
			var A: Array = acts[i]
			var r := Rect2(bx, y + 158.0, bws[i], 24.0)
			var on: bool = A[2]
			var fo := btns.size() == focus
			btns.append({"rect": r, "c": c, "act": A[0], "on": on})
			if fo: draw_rect(r, Color(G1, 0.25))
			draw_rect(r, Color(GL, 1.0 if on else 0.35), false, 1.0)
			var lw := UI.text_w(UI.noto(), A[1], 13)
			draw_string(UI.noto(), Vector2(r.get_center().x - lw / 2.0, r.position.y + 17.0), A[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(G1, 1.0 if on else 0.35))
			bx += bws[i] + 4.0
		x += cw + gap
	var note := "최대 3명 · ★ 조작 중 · 전투 중 ←→ = 교대 (빛날 때 누르면 교대 공격)"
	var nfw := UI.text_w(UI.noto(), note, 11)
	draw_string(UI.noto(), Vector2(box.get_center().x - nfw / 2.0, box.position.y + 258.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e2d2a8"))
	# 닫기
	var cl := "닫기"
	var clw := UI.text_w(UI.noto(), cl, 14) + 44.0
	r_close = Rect2(box.get_center().x - clw / 2.0, box.end.y + 8.0, clw, 28.0)
	draw_rect(r_close, Color("#c2a160"))
	if focus >= btns.size(): draw_rect(r_close.grow(2), Color.WHITE, false, 1.0)
	draw_string(UI.noto(), Vector2(r_close.position.x + 22.0, r_close.position.y + 19.0), cl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#1a1420"))
