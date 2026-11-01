extends Control
## Screen HUD: the current member's HP plate (top left), dash charges, the party column (right: tap = switch,
## glowing = tag-in chance), wave count, slow-motion frame, screen-centre words.

const CH = preload("res://scripts/chars.gd")
var arena
var shown_hp := 70.0
var faces := {}
var slots: Array = []        # [{c, rect}]

func _input(ev: InputEvent) -> void:
	var p := Vector2.INF
	if ev is InputEventScreenTouch and ev.pressed:
		p = ev.position
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		p = ev.position
	if p == Vector2.INF:
		return
	for sl in slots:
		if sl["rect"].grow(6).has_point(p):
			arena.player.party_input(sl["c"])
			get_viewport().set_input_as_handled()
			return

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in ["estelle", "aida", "luce"]:
		faces[c] = load("res://assets/ui/faces/%s.png" % c)

func _process(delta: float) -> void:
	var P = arena.player
	shown_hp += (P.hp - shown_hp) * minf(1.0, delta * 4.0)
	queue_redraw()

func _draw() -> void:
	var P = arena.player
	var fb: Font = arena.font_black
	var fa: Font = arena.font_anton
	var x0 := 14.0
	var y0 := 14.0
	# plate: dark slanted panel with a pink spine, Persona-ish
	var w := 250.0
	var h := 50.0
	draw_colored_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x0 + w, y0), Vector2(x0 + w - 12, y0 + h), Vector2(x0, y0 + h)]), Color(0.05, 0.04, 0.07, 0.86))
	var cc: Color = CH.COLOR[P.who]
	draw_rect(Rect2(x0, y0, 4, h), cc)
	draw_string(fb, Vector2(x0 + 14, y0 + 21), CH.NAME[P.who], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(fa, Vector2(x0 + 18 + fb.get_string_size(CH.NAME[P.who], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, y0 + 21), CH.LATIN[P.who], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(cc, 0.85))
	var hs := str(roundi(maxf(0.0, P.hp)))
	draw_string(fa, Vector2(x0 + w - 74, y0 + 25), hs, HORIZONTAL_ALIGNMENT_RIGHT, 40, 24, Color.WHITE)
	draw_string(fa, Vector2(x0 + w - 32, y0 + 25), "/" + str(int(P.MAX_HP)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))
	# bar: lag (white) behind the real value (pink)
	var bx := x0 + 14.0
	var by := y0 + 31.0
	var bw := w - 44.0
	draw_rect(Rect2(bx, by, bw, 8), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(bx, by, bw * clampf(shown_hp / P.MAX_HP, 0, 1), 8), Color(1, 1, 1, 0.75))
	draw_rect(Rect2(bx, by, bw * clampf(P.hp / P.MAX_HP, 0, 1), 8), cc if P.hp > P.MAX_HP * 0.3 else Color("#ff3d5a"))
	# dash charges
	for i in 2:
		var c := Vector2(bx + 6 + i * 16, by + 18)
		var full: bool = i < P.charges
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -3), c + Vector2(6, -3), c + Vector2(4, 3), c + Vector2(-6, 3)]), Color("#5fd4ff") if full else Color(1, 1, 1, 0.18))
	draw_string(arena.font_bold, Vector2(bx + 40, by + 22), "대시", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))
	# skill cooldown next to the dash chips
	var cdk := 0.0
	if P.who == "aida": cdk = P.tp_cd / 3000.0
	elif P.who == "luce": cdk = P.heal_cd / 9000.0
	draw_string(arena.font_bold, Vector2(bx + 76, by + 22), CH.SKILL[P.who] + ("" if cdk <= 0.0 else " %.0f" % ceil(cdk * (3.0 if P.who == "aida" else 9.0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5 if cdk > 0.0 else 0.85))
	var vs := get_viewport_rect().size
	draw_party(P, vs)
	# wave counter, top right
	if arena.wave > 0:
		var alive := 0
		for m in arena.mobs:
			if not m.is_dead(): alive += 1
		var s := "WAVE %d" % arena.wave
		draw_string(fa, Vector2(vs.x - 236, 36), s, HORIZONTAL_ALIGNMENT_RIGHT, 136, 22, Color.WHITE)
		draw_string(arena.font_bold, Vector2(vs.x - 236, 54), "남은 적 %d" % alive, HORIZONTAL_ALIGNMENT_RIGHT, 136, 11, Color(1, 1, 1, 0.6))
	# slow motion: thin frame lines at the edge
	if arena.witch > 0.0:
		var k: float = minf(1.0, arena.witch / 300.0)
		draw_rect(Rect2(14, 14, vs.x - 28, vs.y - 28), Color(0.67, 0.9, 1.0, 0.3 * k), false, 2.0)
	# screen words (WAVE n): slam in, hold, slide out
	for wd in arena.big_words:
		if not wd["screen"]:
			continue
		var u: float = wd["t"] / wd["life"]
		var a := 1.0 - maxf(0.0, (u - 0.7) / 0.3)
		var fs := 64
		var tw := fa.get_string_size(wd["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var slide := (1.0 - minf(1.0, u * 6.0)) * 120.0
		var pos := Vector2(vs.x / 2.0 - tw / 2.0 - slide, vs.y * 0.38)
		draw_rect(Rect2(0, pos.y - 52, vs.x, 66), Color(0.05, 0.04, 0.07, 0.55 * a))
		draw_string(fa, pos, wd["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(wd["col"], a))


## standby members, right edge: face, HP, swap cooldown sweep; a tag-in chance glows with its label and a shrinking bar
func draw_party(P, vs: Vector2) -> void:
	slots.clear()
	var bench: Array = P.party.filter(func(c): return c != P.who)
	var y := 72.0
	for c in bench:
		var r := Rect2(vs.x - 70.0, y, 56.0, 56.0)
		slots.append({"c": c, "rect": r})
		var col: Color = CH.COLOR[c]
		var on: bool = P.qte["t"] > 0.0 and P.qte["who"].has(c)
		var down: bool = P.hpm[c] <= 0.0
		var poly := PackedVector2Array([r.position + Vector2(8, 0), r.position + Vector2(r.size.x, 0), r.position + Vector2(r.size.x - 8, r.size.y), r.position + Vector2(0, r.size.y)])
		draw_colored_polygon(poly, Color(0.05, 0.04, 0.07, 0.85))
		draw_texture_rect(faces[c], r.grow(-4), false, Color(0.35, 0.35, 0.35) if down else Color.WHITE)
		if on:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(col, 0.6 + 0.4 * pulse), 3.0)
			var lbl: String = CH.QTE_LBL[c]
			draw_string_outline(arena.font_black, Vector2(r.position.x - 44, r.position.y + 34), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0.05, 0.02, 0.06))
			draw_string(arena.font_black, Vector2(r.position.x - 44, r.position.y + 34), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
			draw_rect(Rect2(r.position.x, r.end.y + 2, r.size.x * P.qte["t"] / P.QTE_T, 3), col)
		elif P.swap_cd > 0.0 and not down:
			var k: float = P.swap_cd / 2200.0
			draw_rect(Rect2(r.position.x + 4, r.position.y + 4, r.size.x - 8, (r.size.y - 8) * k), Color(0, 0, 0, 0.5))
		# HP strip
		var hk: float = clampf(P.hpm[c] / CH.STATS[c]["hp"], 0.0, 1.0)
		draw_rect(Rect2(r.position.x, r.end.y + 6, r.size.x, 4), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(r.position.x, r.end.y + 6, r.size.x * hk, 4), col)
		draw_string(arena.font_bold, Vector2(r.position.x + 2, r.end.y + 22), CH.NAME[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.7))
		y += 90.0
