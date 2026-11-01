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
var choices: Array = []         # [[label, Callable, icon?], ...] offered on the last line (ask)
var ch_i := 0
const POR_BLINK := preload("res://assets/eilin/por_smile.png")
static var auto := false         # 자동 (DLG.auto): stays on from one talk to the next
var auto_t := 0.0                # ms a finished line has waited under 자동
var lock_until := 0              # TALKLOCK (ticks ms): no new talk with the townsfolk / Bran before this
var blk_until := 0               # the closing key is held off the game until this
var bl_t := 2600.0               # her portrait's blink clock (ms; < 0 = eyes shut)
var bl_dbl := false
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
	auto_t = 0.0
	press_at = Vector2.INF
	moved = false
	active = true
	var col := UI.col(arena.player.who) if arena != null and arena.get("player") != null else Color("#ff3d7f")
	talk.reset(w, p, n, r, col)
	queue_redraw()

## called by the arena every frame while open
func step(dt: float) -> void:
	t += dt
	talk.step(dt)
	_blink_step(dt)
	var full := line()
	if shown < full.length():
		var n0 := int(shown)
		shown = minf(full.length(), shown + dt / _voice()[5])
		if int(shown) > n0 and not QUIET.contains(full[int(shown) - 1]): _blip()
		talk.show(full, int(shown))
		auto_t = 0.0
		queue_redraw()
		return
	talk.show(full, full.length(), true)
	# 자동: a finished line that is not the last turns by itself after 1.5 s (dlgDone)
	if auto and i < lines.size() - 1:
		auto_t += dt
		if auto_t >= 1500.0: advance()
	queue_redraw()

## next line, or close after the last (a key, or a tap / click on the box: dlgEl click)
func advance() -> void:
	if typing():
		shown = line().length()
		t = 0.0
		talk.show(line(), line().length(), true)
		queue_redraw()
		return
	if not choices.is_empty() and i >= lines.size() - 1: return     # the last line waits on a choice
	i += 1
	t = 0.0
	shown = 0.0
	auto_t = 0.0
	talk.new_line()
	arena.sfx("step", 0.3)
	if i >= lines.size():
		_close()
		var cb = on_close
		on_close = null
		if cb != null: cb.call()
	queue_redraw()

## 건너뛰기 ≫: straight to the last line, typed out (its choices come up)
func skip() -> void:
	if lines.is_empty(): return
	i = maxi(0, lines.size() - 1)
	t = 0.0
	auto_t = 0.0
	talk.new_line()
	shown = line().length()
	talk.show(line(), line().length(), true)
	queue_redraw()

## 자동 on / off; turning it on over a finished line turns the page at once
func toggle_auto() -> void:
	auto = not auto
	auto_t = 0.0
	if auto and not typing() and i < lines.size() - 1: advance()

## the talk box goes away: a breather before the next talk (TALKLOCK 0.7 s), the closing key held off the game (350 ms)
func _close() -> void:
	active = false
	who = ""
	var now := Time.get_ticks_msec()
	lock_until = maxi(lock_until, now + 700)
	blk_until = now + 350

## TALKLOCK: the townsfolk and Bran won't start a talk until it runs out
func locked() -> bool:
	return Time.get_ticks_msec() < lock_until

## the key that closed the box must not reach the game (the prototype's key release block)
func hold_keys() -> void:
	if Time.get_ticks_msec() < blk_until:
		for a in ["attack", "jump"]:
			if InputMap.has_action(a): Input.action_release(a)

## her portrait blinks on its own clock (eilin_por_smile is the closed-eye picture; one time in four a double blink)
func _blink_step(dt: float) -> void:
	if who != "eilin":
		bl_t = maxf(bl_t, 900.0)
		return
	bl_t -= minf(100.0, dt)
	if bl_t < -150.0:
		if bl_dbl:
			bl_dbl = false
			bl_t = 2200.0 + randf() * 2800.0
		elif randf() < 0.25:
			bl_dbl = true
			bl_t = 120.0
		else: bl_t = 2200.0 + randf() * 2800.0
	talk.por = POR_BLINK if bl_t < 0.0 and por != null else por

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
			talk.auto_on = auto
			talk.draw_front(c, vs)
			talk.draw_top(c, vs)
			box = talk.box


# ---------- choices (the prototype's dlgOpen buttons) ----------
## like open, but the last line waits on a choice: C = [[label, Callable, icon?], ...] (icon "hammer" / "talk" / "leave")
func ask(w: String, p: Texture2D, n: String, r: String, L: Array, C: Array) -> void:
	open(w, p, n, r, L, null)
	choices = C
	ch_i = -1                    # nothing chosen until a key, a hover or a tap picks one (붕스 style)
	talk.scroll = 0.0

## isLeave: the goodbye choice (its icon, or 그만 / 나간 / 안녕 in the label)
static func is_leave(c: Array) -> bool:
	if c.size() > 2 and String(c[2]) == "leave": return true
	var lab := String(c[0])
	return lab.contains("그만") or lab.contains("나간") or lab.contains("안녕")

func leave_index() -> int:
	for k in choices.size():
		if is_leave(choices[k]): return k
	return -1

func choosing() -> bool:
	return active and not choices.is_empty() and i >= lines.size() - 1 and not typing()

func _pick(k: int) -> void:
	var C: Array = choices
	if is_leave(C[k]): lock_until = Time.get_ticks_msec() + 5000      # after a goodbye, 5 s before the next talk
	_close()
	choices = []
	queue_redraw()
	arena.sfx("ready", 0.3)
	var cb = C[k][1]
	if cb != null: cb.call()

## a key picks a choice: it lights up and scrolls into view
func _select(k: int) -> void:
	if k == ch_i: return
	ch_i = k
	talk.reveal(k)
	arena.sfx("ready", 0.15)

var box := Rect2()
var press_at := Vector2.INF      # where a press on the choices began (a drag scrolls, a tap picks)
var press_scroll := 0.0
var moved := false

const GO_KEYS := [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_X, KEY_J, KEY_E]

func _input(ev: InputEvent) -> void:
	if not active: return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var tb: int = talk.top_at(ev.position)
			if tb >= 0:
				get_viewport().set_input_as_handled()
				if tb == 0: toggle_auto()
				else: skip()
				return
			if choosing() and talk.in_choices(ev.position):
				get_viewport().set_input_as_handled()
				press_at = ev.position
				press_scroll = talk.scroll
				moved = false
				return
			if choosing(): return
			# a tap anywhere turns the page (t resets, so the 공격 button under the same finger can't turn two)
			get_viewport().set_input_as_handled()
			if t > 150.0: advance()
			return
		# released: a drag never counts as a tap; first tap selects, a second on the selected one confirms
		if press_at == Vector2.INF: return
		get_viewport().set_input_as_handled()
		var was := moved
		press_at = Vector2.INF
		moved = false
		if was or not choosing() or t <= 150.0: return
		var k1: int = talk.choice_at(ev.position)
		if k1 < 0: return
		if k1 != ch_i:
			_select(k1)
			return
		_pick(k1)
		return
	if ev is InputEventMouseMotion:
		if press_at != Vector2.INF:
			var d: float = ev.position.y - press_at.y
			if absf(d) > 6.0: moved = true
			if moved: talk.set_scroll(press_scroll - d)
			return
		# the mouse picks by hovering (a finger does not)
		if choosing() and t > 150.0 and ev.device != InputEvent.DEVICE_ID_EMULATION:
			var k0: int = talk.choice_at(ev.position)
			if k0 >= 0 and k0 != ch_i:
				ch_i = k0
				arena.sfx("ready", 0.15)
		return
	if ev is InputEventMouseButton and ev.pressed and choosing() and talk.in_choices(ev.position):
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: talk.set_scroll(talk.scroll + 30.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_UP: talk.set_scroll(talk.scroll - 30.0)
		get_viewport().set_input_as_handled()
		return
	var key := -1
	if ev is InputEventKey and ev.pressed:
		key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		if key == KEY_F: return
		get_viewport().set_input_as_handled()      # game keys never leak through while talking
	var echo: bool = ev is InputEventKey and ev.echo
	var go: bool = (key in GO_KEYS and not echo) or (ev.is_action_pressed("attack") and not echo) or (ev is InputEventJoypadButton and ev.is_action_pressed("jump"))
	if key < 0 and not go and not (ev is InputEventJoypadButton or ev is InputEventJoypadMotion): return
	if ev is InputEventJoypadButton or ev is InputEventJoypadMotion: get_viewport().set_input_as_handled()
	if choosing():
		var n := choices.size()
		var num := -1
		if key >= KEY_1 and key <= KEY_9: num = key - KEY_1
		elif key >= KEY_KP_1 and key <= KEY_KP_9: num = key - KEY_KP_1
		if num >= 0 and num < n:
			ch_i = num
			_pick(num)
		elif key in [KEY_DOWN, KEY_S] or (key < 0 and ev.is_action_pressed("down")):
			_select(0 if ch_i < 0 else (ch_i + 1) % n)
		elif key in [KEY_UP, KEY_W] or (key < 0 and ev.is_action_pressed("up")):
			_select(n - 1 if ch_i < 0 else (ch_i + n - 1) % n)
		elif go and t > 150.0:
			if ch_i >= 0: _pick(ch_i)
			else: _select(0)
		elif key == KEY_ESCAPE or (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_B):
			var li := leave_index()
			if li >= 0:
				ch_i = li
				_pick(li)
		return
	if (go or (key == KEY_ESCAPE and not echo)) and t > 150.0: advance()
