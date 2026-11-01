extends Control
## Title cards (sortie.js tcPlay, Eva / anime-trailer cuts): hard cuts on black, one big word each, glitch assembly, flicker.
## 'dun' (dungeon entry: three place words on the first visit, then AREA 01 and the name glitching together) and
## 'boss' (an uncleared boss room: red strobe, WARNING, the boss name, one line, 개전). The world holds while a card runs;
## a tap, Esc, Enter or Space skips it. Cards seen are remembered (tcSeen, kept in the save file).

const UI := preload("res://scripts/ui_kit.gd")
## TC_DUN / TC_BOSS: the source marks these lines as placeholder text
const TC_DUN := {"cave": ["폐광", "버섯 군락", "감독관"]}
const TC_BOSS := {"boss": "광부들을 부리던 자"}
const GLY := "▓▒░█■□◆◇╳#%&ㄱㄴㄷㄹㅁㅂㅅㅇ"
const OR := Color("#ff6a1a")
const RD := Color("#e8243c")
const YL := Color("#ffd34d")

var arena
var sortie
var active := false
var kind := ""
var t := 0.0
var ev: Array = []               # [ms, Callable] still to fire
var cut := {"bg": Color(0, 0, 0, 0), "items": [], "hide": false}
var fl := 0.0                    # white flash alpha
var fl_ms := 150.0
var on_end = null
var on_swp := false              # over the sweep's black band: no black of its own
var ending := -1.0               # the leave animation (ms), -1 = not leaving
var seen := {}                   # tcSeen
var glyphs: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var f := UI.bhs()
	for ch in GLY:
		if UI.noto_k().has_char(ch.unicode_at(0)) or f.has_char(ch.unicode_at(0)): glyphs.append(ch)
	if glyphs.is_empty(): glyphs = ["#", "%", "&"]

## tcPlay(kind, {onEnd, on:'swp'})
func play(k: String, end_cb = null, over_swp := false) -> void:
	kind = k
	active = true
	t = 0.0
	ev = []
	ending = -1.0
	fl = 0.0
	on_end = end_cb
	on_swp = over_swp
	cut = {"bg": Color(0, 0, 0, 0), "items": [], "hide": false}
	for a in ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "ult", "swap"]:
		if InputMap.has_action(a): Input.action_release(a)
	if k == "dun": _dun()
	elif k == "boss": _boss()
	visible = true
	queue_redraw()

func at(ms: float, fn: Callable) -> void:
	ev.append([t + ms, fn])

func _cut(items: Array, bg := Color(0, 0, 0, 0)) -> void:
	cut = {"bg": bg, "items": items, "hide": false}
	fl = 0.0

func _thit() -> void:
	arena.sfx("slam", 0.9)

func _flash(ms: float) -> void:
	fl = 0.9
	fl_ms = ms

## tflick: hidden / shown n times, gap ms apart
func _flick(n: int, gap: float) -> void:
	for i in n:
		at(i * gap, func(): cut["hide"] = true)
		at(i * gap + gap / 2.0, func(): cut["hide"] = false)

## tglitch: random glyphs settle into the word letter by letter, then cb
func _glitch(item: Dictionary, word: String, dur: float, cb: Callable) -> void:
	item["word"] = word
	item["g0"] = t
	item["gdur"] = dur
	item["gcb"] = cb
	item["s"] = word


func _dun() -> void:
	var id := "cave"
	var nm := "버섯 동굴"
	var sub := "권장 Lv 1–6"
	var first: bool = not seen.has("dun_" + id)
	seen["dun_" + id] = 1
	var tt := 0.0
	if first:
		for w in TC_DUN[id]:
			var ww: String = w
			at(tt, func():
				_cut([{"k": "T", "s": ww, "c": OR}])
				sortie.beep(220, 0.06, 0.06))
			tt += 620.0
	else:
		at(0, func():
			_cut([{"k": "E", "s": "SORTIE", "c": OR}])
			sortie.beep(220, 0.06, 0.06))
		tt = 520.0
	at(tt, func():
		var g := {"k": "T", "s": "", "c": Color.WHITE, "h": 0.32}
		_cut([{"k": "E", "s": "AREA 01", "c": OR}, g, {"k": "S", "s": sub, "c": Color.WHITE}])
		_glitch(g, nm, 520.0 if first else 420.0, func():
			_thit()
			_flash(160.0)))
	tt += 1900.0 if first else 1500.0
	at(tt, func():
		_cut([{"k": "T", "s": nm, "c": Color.WHITE, "h": 0.32}])
		_flick(3, 90.0))
	at(tt + 600.0, finish)

func _boss() -> void:
	var nm := "감독관 해골"
	at(0, func():
		_cut([], RD)
		sortie.beep(110, 0.09, 0.1, "saw"))
	at(70, func(): _cut([]))
	at(140, func():
		_cut([], RD)
		sortie.beep(110, 0.09, 0.1, "saw"))
	at(210, func(): _cut([]))
	at(320, func(): _cut([{"k": "T", "s": "WARNING", "c": RD, "h": 0.24}]))
	at(760, func():
		var g := {"k": "T", "s": "", "c": Color.WHITE, "h": 0.32}
		_cut([{"k": "E", "s": "BOSS", "c": RD}, g])
		_glitch(g, nm, 320.0, func():
			_thit()
			_flash(120.0)))
	at(1560, func(): _cut([{"k": "bar", "y": 0.26}, {"k": "bar", "y": 0.74}, {"k": "T", "s": nm, "c": Color.WHITE, "h": 0.32}, {"k": "S", "s": TC_BOSS["boss"], "c": RD}]))
	at(2400, func():
		_cut([], RD)
		_thit())
	at(2480, func(): _cut([{"k": "T", "s": "개전", "c": RD, "h": 0.4}]))
	at(2980, finish)

## tcEnd: with a follow-up the last word leaves the way the bands will go; otherwise it fades
func finish() -> void:
	if not active or ending >= 0.0: return
	ev = []
	ending = 0.0
	for a in ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "ult", "swap"]:
		if InputMap.has_action(a): Input.action_release(a)


func _input(e: InputEvent) -> void:
	if not active: return
	var skip := false
	if e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]: skip = true
	elif e is InputEventMouseButton and e.pressed: skip = true
	elif e is InputEventScreenTouch and e.pressed: skip = true
	elif e is InputEventJoypadButton and e.pressed and e.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]: skip = true
	if skip: finish()
	if e is InputEventKey or e is InputEventMouseButton or e is InputEventScreenTouch or e is InputEventJoypadButton:
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active: return
	var dt: float = minf(delta * 1000.0, 100.0) * sortie.speed
	t += dt
	if fl > 0.0: fl = maxf(0.0, fl - dt / fl_ms * 0.9)
	var due := ev.filter(func(x): return x[0] <= t)
	ev = ev.filter(func(x): return x[0] > t)
	for x in due:
		if active and ending < 0.0: x[1].call()
	# glitch words
	for it in cut["items"]:
		if it.has("g0"):
			var k := clampf((t - it["g0"]) / it["gdur"], 0.0, 1.0)
			var word: String = it["word"]
			var fx := int(k * word.length() * 1.15)
			var s := ""
			for i in word.length():
				var ch := word[i]
				s += ch if ch == " " or i < fx else (" " if randf() < 0.3 else glyphs[randi() % glyphs.size()])
			it["s"] = s
			if randf() < 0.4: sortie.beep(700 + randf() * 900, 0.02, 0.025)
			if k >= 1.0:
				it["s"] = word
				it.erase("g0")
				var cb: Callable = it["gcb"]
				cb.call()
	if ending >= 0.0:
		ending += dt
		var lim := 170.0 if on_end != null else 220.0
		if ending >= lim:
			active = false
			visible = false
			var cb = on_end
			on_end = null
			if cb != null: cb.call()
	queue_redraw()


## fit: the word fills up to ~88% of the width and hk (30%) of the height
func _fit(s: String, hk: float, vs: Vector2) -> int:
	var n := maxi(1, s.length())
	return int(floorf(minf(vs.y * (hk if hk > 0.0 else 0.3), vs.x * 0.88 / (n * 0.98))))

func _draw() -> void:
	if not active: return
	var vs := get_viewport_rect().size
	var a := 1.0
	var ox := 0.0
	if ending >= 0.0:
		if on_end != null:
			var k := UI.bez(0.6, 0.0, 0.9, 0.4, ending / 200.0)
			ox = vs.x * 0.18 * k
			a = 1.0 - k
		else:
			a = 1.0 - ending / 220.0
	if not on_swp:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 1.0 if on_end != null else a))
	var bg: Color = cut["bg"]
	if bg.a > 0.0: draw_rect(Rect2(Vector2.ZERO, vs), Color(bg, a))
	if not cut["hide"]:
		# lay the column out: T / E / S, 2.4vh apart, centred
		var items: Array = cut["items"].filter(func(it): return it["k"] in ["T", "E", "S"])
		var gap := vs.y * 0.024
		var hs: Array = []
		var tot := 0.0
		for it in items:
			var h := _item_h(it, vs)
			hs.append(h)
			tot += h
		tot += gap * maxi(0, items.size() - 1)
		var y := vs.y / 2.0 - tot / 2.0
		for i in items.size():
			_draw_item(items[i], Vector2(vs.x / 2.0 + ox, y), hs[i], vs, a)
			y += hs[i] + gap
		for it in cut["items"]:
			if it["k"] == "bar":
				draw_rect(Rect2(0, vs.y * it["y"] - 1.5, vs.x, 3.0), Color(RD, a))
	if fl > 0.0: draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, fl * a))
	var sk := UI.anton(false, 3)
	draw_string(sk, Vector2(vs.x - 14.0 - UI.text_w(sk, "TAP TO SKIP", 10), vs.y - 10.0), "TAP TO SKIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.53, 0.53, 0.53, a))

func _font(it: Dictionary, vs: Vector2) -> Array:
	match it["k"]:
		"T":
			var w: String = it.get("word", it["s"])
			return [UI.bhs(), _fit(w, it.get("h", 0.0), vs)]
		"E":
			return [UI.anton(false, int(clampf(vs.y * 0.038, 14, 28) * 0.55)), int(clampf(vs.y * 0.038, 14, 28))]
	return [UI.spaced(UI.noto(), int(clampf(vs.y * 0.036, 14, 26) * 0.2)), int(clampf(vs.y * 0.036, 14, 26))]

func _item_h(it: Dictionary, vs: Vector2) -> float:
	var f: Array = _font(it, vs)
	return float(f[1]) * (1.0 if it["k"] == "T" else 1.2)

func _draw_item(it: Dictionary, top_c: Vector2, h: float, vs: Vector2, a: float) -> void:
	var f: Array = _font(it, vs)
	var fnt: Font = f[0]
	var fs: int = f[1]
	var s: String = it["s"]
	var w := UI.text_w(fnt, s, fs)
	var base := top_c.y + h / 2.0 + (fnt.get_ascent(fs) - fnt.get_descent(fs)) / 2.0
	draw_string(fnt, Vector2(top_c.x - w / 2.0, base), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(it["c"], a))
