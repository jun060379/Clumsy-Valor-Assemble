extends Control
## Screen HUD: Estelle's HP plate (top left), dash charges, wave count, slow-motion frame, screen-centre words.

var arena
var shown_hp := 70.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	draw_rect(Rect2(x0, y0, 4, h), Color("#ff4d9a"))
	draw_string(fb, Vector2(x0 + 14, y0 + 21), "에스텔", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(fa, Vector2(x0 + 74, y0 + 21), "ESTELLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.6, 0.8, 0.8))
	var hs := str(roundi(maxf(0.0, P.hp)))
	draw_string(fa, Vector2(x0 + w - 74, y0 + 25), hs, HORIZONTAL_ALIGNMENT_RIGHT, 40, 24, Color.WHITE)
	draw_string(fa, Vector2(x0 + w - 32, y0 + 25), "/" + str(int(P.MAX_HP)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))
	# bar: lag (white) behind the real value (pink)
	var bx := x0 + 14.0
	var by := y0 + 31.0
	var bw := w - 44.0
	draw_rect(Rect2(bx, by, bw, 8), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(bx, by, bw * clampf(shown_hp / P.MAX_HP, 0, 1), 8), Color(1, 1, 1, 0.75))
	draw_rect(Rect2(bx, by, bw * clampf(P.hp / P.MAX_HP, 0, 1), 8), Color("#ff4d9a") if P.hp > P.MAX_HP * 0.3 else Color("#ff3d5a"))
	# dash charges
	for i in 2:
		var c := Vector2(bx + 6 + i * 16, by + 18)
		var full: bool = i < P.charges
		draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -3), c + Vector2(6, -3), c + Vector2(4, 3), c + Vector2(-6, 3)]), Color("#5fd4ff") if full else Color(1, 1, 1, 0.18))
	draw_string(arena.font_bold, Vector2(bx + 40, by + 22), "대시", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))
	# wave counter, top right
	var vs := get_viewport_rect().size
	if arena.wave > 0:
		var alive := 0
		for m in arena.mobs:
			if not m.is_dead(): alive += 1
		var s := "WAVE %d" % arena.wave
		draw_string(fa, Vector2(vs.x - 150, 36), s, HORIZONTAL_ALIGNMENT_RIGHT, 136, 22, Color.WHITE)
		draw_string(arena.font_bold, Vector2(vs.x - 150, 54), "남은 적 %d" % alive, HORIZONTAL_ALIGNMENT_RIGHT, 136, 11, Color(1, 1, 1, 0.6))
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
