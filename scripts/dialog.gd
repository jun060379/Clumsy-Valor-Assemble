extends Control
## A simple talk box: portrait on the left, name and role, one line at a time. Attack / jump = next; the last line closes it.
## The world holds still while it is open (as in the prototype, where the game loop pauses under a dialogue).
## Lines type out a letter at a time with the speaker's voice blip (dlgTick / voiceBlip); the first press shows the
## whole line, the next turns the page.

const AMB := preload("res://scripts/ambience.gd")
## VOICE: base pitch, wave, low-pass, blip length (s), volume, ms per letter
const VOICE := {"bran": [131.0, "square", 1400.0, 0.055, 0.045, 42.0], "estelle": [392.0, "square", 3000.0, 0.04, 0.035, 30.0],
	"aida": [294.0, "square", 2200.0, 0.035, 0.03, 28.0], "luce": [523.0, "triangle", 4000.0, 0.04, 0.06, 28.0], "def": [262.0, "square", 2400.0, 0.04, 0.035, 32.0]}
const QUIET := " \t\n.,…?!~'\"·"
static var _blips := {}
var shown := 0.0                # letters of the current line on show
var voice_ap: AudioStreamPlayer

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
	voice_ap = AudioStreamPlayer.new()
	add_child(voice_ap)

func _voice() -> Array:
	return VOICE.get(who, VOICE["def"])

## voiceBlip: a short filtered square / triangle, one per letter (a new one cuts the last)
func _blip() -> void:
	var v := _voice()
	var key: String = "%s_%d" % [v[1], int(v[0])]
	if not _blips.has(key):
		var rate := AMB.RATE
		var n := int(rate * (v[3] + 0.01))
		var s := PackedFloat32Array()
		s.resize(n)
		var ph := 0.0
		for k in n:
			var tt := float(k) / rate
			ph = fposmod(ph + v[0] / rate, 1.0)
			var w: float = (1.0 if ph < 0.5 else -1.0) if v[1] == "square" else 1.0 - 4.0 * absf(ph - 0.5)
			var env: float = tt / 0.003 if tt < 0.003 else (1.0 if tt < v[3] * 0.7 else maxf(0.0, 1.0 - (tt - v[3] * 0.7) / (v[3] * 0.3)))
			s[k] = w * env
		_blips[key] = AMB._wav(AMB._filter(s, "lowpass", v[2], 0.5))
	voice_ap.stream = _blips[key]
	voice_ap.volume_db = linear_to_db(v[4] * 1.4)
	voice_ap.play()

func line() -> String:
	return String(lines[mini(i, lines.size() - 1)]) if not lines.is_empty() else ""

func typing() -> bool:
	return active and shown < line().length()

func open(w: String, p: Texture2D, n: String, r: String, L: Array, cb) -> void:
	who = w
	por = p
	nm = n
	role = r
	lines = L
	i = 0
	t = 0.0
	shown = 0.0
	on_close = cb
	choices = []
	active = true
	queue_redraw()

## called by the arena every frame while open
func step(dt: float) -> void:
	t += dt
	var full := line()
	if shown < full.length():
		var n0 := int(shown)
		shown = minf(full.length(), shown + dt / _voice()[5])
		if int(shown) > n0 and not QUIET.contains(full[int(shown) - 1]): _blip()
		if t > 150.0 and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump")):
			shown = full.length()          # the first press shows the whole line (dlgDone)
			t = 0.0
		queue_redraw()
		return
	if not choices.is_empty() and i >= lines.size() - 1:
		_step_choices()
		queue_redraw()
		return
	if t > 150.0 and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump")):
		advance()
	queue_redraw()

## next line, or close after the last (a key, or a tap / click on the box: dlgEl click)
func advance() -> void:
	if typing():
		shown = line().length()
		t = 0.0
		queue_redraw()
		return
	i += 1
	t = 0.0
	shown = 0.0
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
	box = Rect2(bx, by, bw, bh)
	draw_rect(Rect2(bx, by, bw, bh), Color(0.06, 0.05, 0.07, 0.9))
	draw_rect(Rect2(bx, by, bw, bh), Color(1.0, 0.91, 0.66, 0.5), false, 2.0)
	draw_rect(Rect2(bx, by, 4.0, bh), Color("#8fcf8a"))
	var fb: Font = arena.font_black
	var fr: Font = arena.font_bold
	draw_string(fb, Vector2(px, by + 28.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffe9a8"))
	var nw := fb.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	draw_string(fr, Vector2(px + nw + 10.0, by + 28.0), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
	var s: String = line().substr(0, int(shown))
	draw_multiline_string(fr, Vector2(px, by + 58.0), s, HORIZONTAL_ALIGNMENT_LEFT, bx + bw - px - 20.0, 16, 3, Color("#fff6df"))
	if typing(): return
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

var box := Rect2()
func _input(ev: InputEvent) -> void:
	if not active: return
	if (choices.is_empty() or i < lines.size() - 1 or typing()) and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		# a tap or click on the box turns the page (t resets, so the 공격 button under the same finger can't turn two)
		if box.grow(8.0).has_point(ev.position):
			get_viewport().set_input_as_handled()
			if t > 150.0: advance()
		return
	if choices.is_empty() or i < lines.size() - 1 or t <= 150.0 or typing(): return
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
