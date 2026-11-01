extends Control
## A simple talk box: portrait on the left, name and role, one line at a time. Attack / jump = next; the last line closes it.
## The world holds still while it is open (as in the prototype, where the game loop pauses under a dialogue).

var arena
var active := false
var who := ""
var por: Texture2D
var nm := ""
var role := ""
var lines: Array = []
var i := 0
var t := 0.0
var on_close = null
var choices: Array = []         # [[label, Callable], ...] offered on the last line (ask)
var ch_i := 0
var ch_rects: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func open(w: String, p: Texture2D, n: String, r: String, L: Array, cb) -> void:
	who = w
	por = p
	nm = n
	role = r
	lines = L
	i = 0
	t = 0.0
	on_close = cb
	choices = []
	active = true
	queue_redraw()

## called by the arena every frame while open
func step(dt: float) -> void:
	t += dt
	if not choices.is_empty() and i >= lines.size() - 1:
		_step_choices()
		queue_redraw()
		return
	if t > 150.0 and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump")):
		i += 1
		t = 0.0
		arena.sfx("step", 0.3)
		if i >= lines.size():
			active = false
			who = ""
			var cb = on_close
			on_close = null
			if cb != null: cb.call()
	queue_redraw()

func _draw() -> void:
	if not active: return
	var vs := get_viewport_rect().size
	var bh := 118.0
	var bx := 16.0
	var bw := vs.x - 32.0
	var by := vs.y - bh - 16.0
	# portrait stands on the box's left end
	if por != null:
		var ph := minf(250.0, vs.y * 0.52)
		var pw := por.get_width() * ph / por.get_height()
		draw_texture_rect(por, Rect2(bx + 6.0, by - ph + 30.0, pw, ph), false)
	var px := bx + 170.0 if vs.x > 560.0 else bx + 12.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.06, 0.05, 0.07, 0.9))
	draw_rect(Rect2(bx, by, bw, bh), Color(1.0, 0.91, 0.66, 0.5), false, 2.0)
	draw_rect(Rect2(bx, by, 4.0, bh), Color("#8fcf8a"))
	var fb: Font = arena.font_black
	var fr: Font = arena.font_bold
	draw_string(fb, Vector2(px, by + 28.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffe9a8"))
	var nw := fb.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string(fr, Vector2(px + nw + 10.0, by + 28.0), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
	var s: String = lines[mini(i, lines.size() - 1)]
	draw_multiline_string(fr, Vector2(px, by + 58.0), s, HORIZONTAL_ALIGNMENT_LEFT, bx + bw - px - 20.0, 16, 3, Color("#fff6df"))
	if not choices.is_empty() and i >= lines.size() - 1:
		_draw_choices(vs, by, fr)
		return
	var hint := "▶ 공격 키" if i < lines.size() - 1 else "■ 공격 키로 닫기"
	var hw := fr.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	var bob := sin(Time.get_ticks_msec() / 200.0) * 2.0
	draw_string(fr, Vector2(bx + bw - hw - 16.0, by + bh - 12.0 + bob), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.6))


# ---------- choices (the prototype's dlgOpen buttons) ----------
## like open, but the last line waits on a choice: C = [[label, Callable], ...]; Esc takes the last one
func ask(w: String, p: Texture2D, n: String, r: String, L: Array, C: Array) -> void:
	open(w, p, n, r, L, null)
	choices = C
	ch_i = 0

func _pick(k: int) -> void:
	var C: Array = choices
	active = false
	who = ""
	choices = []
	queue_redraw()
	arena.sfx("step", 0.35)
	var cb = C[k][1]
	if cb != null: cb.call()

func _step_choices() -> void:
	if t <= 150.0: return
	if Input.is_action_just_pressed("down"):
		ch_i = (ch_i + 1) % choices.size()
		arena.sfx("step", 0.2)
	elif Input.is_action_just_pressed("up"):
		ch_i = (ch_i + choices.size() - 1) % choices.size()
		arena.sfx("step", 0.2)
	elif Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump"):
		_pick(ch_i)

func _input(ev: InputEvent) -> void:
	if not active or choices.is_empty() or i < lines.size() - 1 or t <= 150.0: return
	if ev is InputEventMouseMotion:
		for k in ch_rects.size():
			if ch_rects[k].has_point(ev.position): ch_i = k
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for k in ch_rects.size():
			if ch_rects[k].has_point(ev.position):
				get_viewport().set_input_as_handled()
				_pick(k)
				return
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_pick(choices.size() - 1)

## the choice buttons stack up on the right over the box
func _draw_choices(vs: Vector2, by: float, fr: Font) -> void:
	ch_rects.clear()
	var n := choices.size()
	var w := 0.0
	for c in choices: w = maxf(w, fr.get_string_size(String(c[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	w += 46.0
	var h := 30.0
	var x0 := vs.x - 30.0 - w
	var y0 := by - 10.0 - n * (h + 6.0)
	for k in n:
		var r := Rect2(x0 + (6.0 if k == ch_i else 0.0), y0 + k * (h + 6.0), w, h)
		ch_rects.append(r)
		var on := k == ch_i
		draw_colored_polygon(PackedVector2Array([r.position + Vector2(8, 0), Vector2(r.end.x, r.position.y), r.end - Vector2(8, 0), Vector2(r.position.x, r.end.y)]), Color("#fff6df") if on else Color(0.06, 0.05, 0.07, 0.92))
		draw_rect(Rect2(r.position + Vector2(10, 6), Vector2(4, h - 12)), Color("#8fcf8a"))
		draw_string(fr, Vector2(r.position.x + 24.0, r.position.y + 20.0), String(choices[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.08, 0.06, 0.08) if on else Color("#fff6df"))
