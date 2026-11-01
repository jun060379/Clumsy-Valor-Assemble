extends Control
## A simple talk box: portrait on the left, name and role, one line at a time. Attack / jump = next; the last line closes it.
## The world holds still while it is open (as in the prototype, where the game loop pauses under a dialogue).
## Lines type out a letter at a time with the speaker's voice blip (dlgTick / voiceBlip); the first press shows the
## whole line, the next turns the page.

const AMB := preload("res://scripts/ambience.gd")
const UI := preload("res://scripts/ui_kit.gd")
const TALK := preload("res://scripts/talk_fx.gd")
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
var talk = TALK.new()            # the v3 talk scene (cut-in, bust, balloon, ransom name, tumbling letters, choices)
var _lay: Array = []             # canvas items: cut-in shards, art silhouettes (solid), the rest


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	voice_ap = AudioStreamPlayer.new()
	add_child(voice_ap)
	for i in 3:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if i == 1: c.material = UI.solid_mat()
		var k := i
		c.draw.connect(func(): _draw_layer(k, c))
		add_child(c)
		_lay.append(c)

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
	var col := UI.col(arena.player.who) if arena != null and arena.get("player") != null else Color("#ff3d7f")
	talk.reset(w, p, n, r, col)
	queue_redraw()

## called by the arena every frame while open
func step(dt: float) -> void:
	t += dt
	talk.step(dt)
	var full := line()
	if shown < full.length():
		var n0 := int(shown)
		shown = minf(full.length(), shown + dt / _voice()[5])
		if int(shown) > n0 and not QUIET.contains(full[int(shown) - 1]): _blip()
		talk.show(full, int(shown))
		if t > 150.0 and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump")):
			shown = full.length()          # the first press shows the whole line (dlgDone)
			t = 0.0
			talk.show(full, full.length(), true)
		queue_redraw()
		return
	talk.show(full, full.length(), true)
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
		talk.show(line(), line().length(), true)
		queue_redraw()
		return
	i += 1
	t = 0.0
	shown = 0.0
	talk.new_line()
	arena.sfx("step", 0.3)
	if i >= lines.size():
		active = false
		who = ""
		var cb = on_close
		on_close = null
		if cb != null: cb.call()
	queue_redraw()

func _draw() -> void:
	for c in _lay: c.queue_redraw()

func _draw_layer(k: int, c: Control) -> void:
	if not active: return
	var vs := get_viewport_rect().size
	match k:
		0: talk.draw_back(c, vs)
		1: talk.draw_sil(c, vs)
		2:
			var on_last := not choices.is_empty() and i >= lines.size() - 1 and not typing()
			talk.set_choices(choices.map(func(x): return String(x[0])) if on_last else [], ch_i)
			talk.draw_front(c, vs)
			box = talk.box


# ---------- choices (the prototype's dlgOpen buttons) ----------
## like open, but the last line waits on a choice: C = [[label, Callable], ...]; Esc takes the last one
func ask(w: String, p: Texture2D, n: String, r: String, L: Array, C: Array) -> void:
	open(w, p, n, r, L, null)
	choices = C
	ch_i = -1                    # nothing chosen until a key, a hover or a tap picks one (붕스 style)

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
		ch_i = 0 if ch_i < 0 else (ch_i + 1) % choices.size()
		arena.sfx("step", 0.2)
	elif Input.is_action_just_pressed("up"):
		ch_i = choices.size() - 1 if ch_i < 0 else (ch_i + choices.size() - 1) % choices.size()
		arena.sfx("step", 0.2)
	elif Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump"):
		# the first press only picks the top one; a press on a chosen one confirms
		if ch_i < 0:
			ch_i = 0
			arena.sfx("ready", 0.15)
		else: _pick(ch_i)

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
		var k0: int = talk.choice_at(ev.position)
		if k0 >= 0 and k0 != ch_i:
			ch_i = k0
			arena.sfx("ready", 0.15)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var k1: int = talk.choice_at(ev.position)
		if k1 >= 0:
			get_viewport().set_input_as_handled()
			# a tap picks, a second tap on the picked one confirms; the mouse already picked it by hovering
			if k1 != ch_i and ev.device == InputEvent.DEVICE_ID_EMULATION:
				ch_i = k1
				arena.sfx("ready", 0.15)
				return
			_pick(k1)
			return
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode >= KEY_1 and ev.keycode <= KEY_9 and ev.keycode - KEY_1 < choices.size():
		get_viewport().set_input_as_handled()
		ch_i = ev.keycode - KEY_1
		_pick(ch_i)
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_pick(choices.size() - 1)
