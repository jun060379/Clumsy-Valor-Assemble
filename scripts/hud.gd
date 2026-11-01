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
	if arena.level != null and not arena.level.has_method("land"):
		draw_dungeon_ui(vs)
	elif arena.level != null:
		var hh := int(arena.level.tod_h)
		var mm := int((arena.level.tod_h - hh) * 60.0)
		draw_string(arena.font_bold, Vector2(18, 92), "길드 마을  %02d:%02d" % [hh, mm], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.75))
	# wave counter, top right
	if arena.wave > 0 and arena.level == null:
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


## dungeon: room banner, minimap, boss bar, shilling
func draw_dungeon_ui(vs: Vector2) -> void:
	var D = arena.level
	var fb: Font = arena.font_black
	if D.msg_t > 0.0:
		var a := minf(1.0, D.msg_t / 400.0) * minf(1.0, (2600.0 - D.msg_t) / 200.0 + 0.3)
		var tw := fb.get_string_size(D.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var y := vs.y * 0.24
		draw_rect(Rect2(vs.x / 2.0 - tw / 2.0 - 30.0, y - 28.0, tw + 60.0, 40.0), Color(0.04, 0.03, 0.06, 0.7 * a))
		draw_rect(Rect2(vs.x / 2.0 - tw / 2.0 - 30.0, y - 28.0, 4.0, 40.0), Color(1, 0.83, 0.3, a))
		draw_string(fb, Vector2(vs.x / 2.0 - tw / 2.0, y), D.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.85, a))
	# minimap, left of the party column
	var R: Dictionary = D.rooms
	var seen: Array = R.values().filter(func(r): return r["seen"])
	if not seen.is_empty():
		var gx0: int = seen.map(func(r): return r["x"]).min()
		var gx1: int = seen.map(func(r): return r["x"]).max()
		var gy0: int = seen.map(func(r): return r["y"]).min()
		var gy1: int = seen.map(func(r): return r["y"]).max()
		var cw := 24.0
		var chh := 15.0
		var gap := 5.0
		var bw := (gx1 - gx0 + 1) * (cw + gap) + 8.0
		var bh := (gy1 - gy0 + 1) * (chh + gap) + 8.0
		var x0 := vs.x - 96.0 - bw
		var y0 := 16.0
		draw_rect(Rect2(x0 - 6.0, y0 - 6.0, bw, bh), Color(0.04, 0.03, 0.06, 0.55))
		draw_rect(Rect2(x0 - 6.0, y0 - 6.0, bw, bh), Color(0.91, 0.83, 0.63, 0.35), false, 1.0)
		for r in seen:
			var px: float = x0 + (r["x"] - gx0) * (cw + gap)
			var py: float = y0 + (r["y"] - gy0) * (chh + gap)
			for d in ["R", "D"]:
				if r["doors"].has(d):
					var nb = R.get(D.rkey(r["x"] + D.DIRS[d][0], r["y"] + D.DIRS[d][1]))
					if nb != null and (r["visited"] or nb["visited"]):
						if d == "R": draw_line(Vector2(px + cw, py + chh / 2.0), Vector2(px + cw + gap, py + chh / 2.0), Color(0.91, 0.83, 0.63, 0.5), 2.0)
						else: draw_line(Vector2(px + cw / 2.0, py + chh), Vector2(px + cw / 2.0, py + chh + gap), Color(0.91, 0.83, 0.63, 0.5), 2.0)
		for r in seen:
			var px2: float = x0 + (r["x"] - gx0) * (cw + gap)
			var py2: float = y0 + (r["y"] - gy0) * (chh + gap)
			var col := Color("#f3dfae") if r["k"] == D.cur else (Color(0.63, 0.57, 0.7, 0.85) if r["visited"] else Color(0.27, 0.24, 0.33, 0.8))
			draw_rect(Rect2(px2, py2, cw, chh), col)
			var ic = {"boss": Color("#ff5a6a"), "camp": Color("#ffa04a"), "vault": Color("#ffd34d"), "start": Color("#9fe3a0")}.get(r["type"])
			if ic != null and (r["visited"] or r["type"] == "boss"):
				draw_circle(Vector2(px2 + cw / 2.0, py2 + chh / 2.0), 3.5, ic)
			if r["visited"] and r["type"] == "fight" and not r["cleared"]:
				draw_rect(Rect2(px2 + cw / 2.0 - 2.0, py2 + chh / 2.0 - 2.0, 4, 4), Color("#ff6f6f"))
	# boss bar
	for m in arena.mobs:
		if m.M.has("boss") and not m.is_dead() and m.spawn_t <= 0.0:
			var bw2 := minf(420.0, vs.x * 0.46)
			var bx := (vs.x - bw2) / 2.0
			var by := vs.y - 60.0
			draw_string(fb, Vector2(bx, by - 8.0), m.M["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ffd1d8"))
			draw_rect(Rect2(bx - 2.0, by - 2.0, bw2 + 4.0, 12.0), Color(0.04, 0.02, 0.05, 0.85))
			draw_rect(Rect2(bx, by, bw2 * clampf(m.hp / m.max_hp, 0.0, 1.0), 8.0), Color("#ff3d5a"))
			if m.phase == 1:
				draw_string(arena.font_bold, Vector2(bx + bw2 - 60.0, by - 8.0), "격노", HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Color("#ff9d9d"))
	# shilling
	draw_string(arena.font_bold, Vector2(18, 92), "실링 %d" % arena.shilling, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#ffd34d"))
