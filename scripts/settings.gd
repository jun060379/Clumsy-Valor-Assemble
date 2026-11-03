extends RefCounted
## Player settings (prototype 설정 panel + sortie.js key rebinding), saved to user://settings.cfg.
## Control device (auto / kbm / pad / touch) with the prototype's TOUCHUI rule: once a keyboard or mouse has been
## used, the touch UI stays hidden until a real touch.
## Volumes ("audio" section: master / bgm / sfx / voice, 0..1): applied as bus volumes (apply_audio) — Master is bus 0,
## "BGM" gets bgm.gd's BUS_DB trim plus the slider, "SFX" (everything that is not music: the Slow bus sends into it)
## and "Voice" (no users yet) their sliders; 0 mutes the bus. The 배경음 on / off toggle (arena.music) is separate.

const PATH := "user://settings.cfg"
const BGM := preload("res://scripts/bgm.gd")      # its BUS_DB: the track trim the 배경음 slider multiplies on top of
const SFX_BUS := &"SFX"
const VOICE_BUS := &"Voice"
const AUDIO_KEYS := ["master", "bgm", "sfx", "voice"]
const AUDIO_DEF := {"master": 1.0, "bgm": 0.8, "sfx": 1.0, "voice": 1.0}
const AUDIO_BUS := {"master": &"Master", "bgm": &"BGM", "sfx": &"SFX", "voice": &"Voice"}
## KB_ACT
const ACTS := [["left", "왼쪽"], ["right", "오른쪽"], ["up", "위 · 계단 · 문"], ["down", "아래"], ["jump", "점프"], ["attack", "공격 · 상호작용"], ["guard", "스킬"], ["dash", "대시"], ["ult", "궁극기"], ["swap", "동료 교대"]]
## a binding is a keycode, plus the side for a modifier (e.code ShiftLeft / ControlRight…): code | side << SIDE_SH
const SIDE_SH := 32
const L_SHIFT := KEY_SHIFT | (KEY_LOCATION_LEFT << SIDE_SH)
const R_SHIFT := KEY_SHIFT | (KEY_LOCATION_RIGHT << SIDE_SH)
const L_CTRL := KEY_CTRL | (KEY_LOCATION_LEFT << SIDE_SH)
const R_CTRL := KEY_CTRL | (KEY_LOCATION_RIGHT << SIDE_SH)
const MODS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
## KB_PRE (each action two slots; 0 = empty)
const PRE := {
	"arrow": {"n": "방향키형", "left": [KEY_LEFT, 0], "right": [KEY_RIGHT, 0], "up": [KEY_UP, 0], "down": [KEY_DOWN, 0], "jump": [KEY_Z, 0], "attack": [KEY_X, 0], "guard": [KEY_A, 0], "dash": [L_SHIFT, 0], "ult": [KEY_D, 0], "swap": [L_CTRL, R_CTRL], "rmb": "guard"},
	"wasd": {"n": "WASD + 마우스형", "left": [KEY_A, 0], "right": [KEY_D, 0], "up": [KEY_W, 0], "down": [KEY_S, 0], "jump": [KEY_SPACE, 0], "attack": [KEY_J, 0], "guard": [KEY_E, 0], "dash": [L_SHIFT, 0], "ult": [KEY_Q, 0], "swap": [KEY_R, 0], "rmb": "dash"},
}
const ARROWS := [[KEY_LEFT, "left"], [KEY_RIGHT, "right"], [KEY_UP, "up"], [KEY_DOWN, "down"]]

var arena
var dev := "auto"          # auto / kbm / pad / touch
var last := "kbm"          # what was used last (auto follows it)
var kbm_seen := false
var kbm_t := -99999
var stick := "float"       # float / fixed
var kb := {}               # action -> [key, key]
var rmb := "guard"
var _touch_auto = null
var qk := 1.0              # QK: render quality (1 → .8 → .6), lowered by qWatch when frames run long; saved
var qw := {"n": 0, "s": 0.0, "cool": 0.0}
var sides := true          # the platform tells left from right modifiers (false once one arrives without a side)
var vol := AUDIO_DEF.duplicate()      # master / bgm / sfx / voice, 0..1 (the 전체 음량 · 배경음 · 효과음 · 보이스 sliders)


func _init(a) -> void:
	arena = a
	kb = preset("arrow")
	rmb = "guard"
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in AUDIO_KEYS:
		vol[k] = clampf(float(cf.get_value("audio", k, AUDIO_DEF[k])), 0.0, 1.0)
	dev = String(cf.get_value("ui", "dev", dev))
	stick = String(cf.get_value("ui", "stick", stick))
	arena.screen_fx = bool(cf.get_value("ui", "pfx", true))
	arena.pix = String(cf.get_value("ui", "pix2", "shade"))
	arena.tod_auto = bool(cf.get_value("ui", "tod_auto", true))
	arena.weather = String(cf.get_value("ui", "weather", "clear"))
	arena.ambient = bool(cf.get_value("ui", "ambient", true))
	arena.music = bool(cf.get_value("ui", "bgm", true))
	qk = clampf(float(cf.get_value("ui", "qk", 1.0)), 0.6, 1.0)
	rmb = String(cf.get_value("keys", "rmb", "guard"))
	for a2 in ACTS:
		var v = cf.get_value("keys", a2[0], null)
		if v is Array and v.size() == 2:
			kb[a2[0]] = [int(v[0]), int(v[1])]


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ui", "dev", dev)
	cf.set_value("ui", "stick", stick)
	cf.set_value("ui", "pfx", arena.screen_fx)
	cf.set_value("ui", "pix2", arena.pix)
	cf.set_value("ui", "tod_auto", arena.tod_auto)
	cf.set_value("ui", "weather", arena.weather)
	cf.set_value("ui", "ambient", arena.ambient)
	cf.set_value("ui", "bgm", arena.music)
	cf.set_value("ui", "qk", qk)
	for k in AUDIO_KEYS:
		cf.set_value("audio", k, vol[k])
	cf.set_value("keys", "rmb", rmb)
	for a in ACTS:
		cf.set_value("keys", a[0], kb[a[0]])
	cf.save(PATH)


# ---------- volumes ----------
## the "SFX" and "Voice" buses (default_bus_layout.tres; made here if the layout is missing): SFX right after Master so
## the Slow bus can send into it (a bus only sends to one before it), Voice after that
static func ensure_buses() -> void:
	for b in [SFX_BUS, VOICE_BUS]:
		if AudioServer.get_bus_index(b) >= 0: continue
		var at := 1 if b == SFX_BUS else mini(AudioServer.bus_count, AudioServer.get_bus_index(SFX_BUS) + 1)
		AudioServer.add_bus(at)
		AudioServer.set_bus_name(at, b)
		AudioServer.set_bus_send(at, &"Master")

## the slider value as a bus volume: linear_to_db(v), and 0 mutes the bus outright. "bgm" rides bgm.gd's BUS_DB trim.
static func bus_db(k: String, v: float) -> float:
	var trim: float = BGM.BUS_DB if k == "bgm" else 0.0
	return trim + linear_to_db(maxf(0.0001, v))

func set_vol(k: String, v: float) -> void:
	vol[k] = clampf(v, 0.0, 1.0)
	apply_audio()

func get_vol(k: String) -> float:
	return float(vol.get(k, 1.0))

## every slider onto its bus (at startup from the saved values, and whenever a slider moves)
func apply_audio() -> void:
	ensure_buses()
	for k in AUDIO_KEYS:
		var i := AudioServer.get_bus_index(AUDIO_BUS[k])
		if i < 0: continue
		var v := float(vol[k])
		AudioServer.set_bus_mute(i, v <= 0.0)
		AudioServer.set_bus_volume_db(i, bus_db(k, v))


static func preset(k: String) -> Dictionary:
	var o := {}
	for a in ACTS:
		var v: Array = PRE[k][a[0]]
		o[a[0]] = [v[0], v[1]]
	return o

func use_preset(k: String) -> void:
	kb = preset(k)
	rmb = String(PRE[k]["rmb"])
	apply_keys()

## kbApply: rebuild the keyboard events of every action (pad events stay). Arrow keys always move unless given to something else.
func apply_keys() -> void:
	for a in ACTS:
		var act: String = a[0]
		if not InputMap.has_action(act):
			InputMap.add_action(act, 0.3)
		for e in InputMap.action_get_events(act):
			if e is InputEventKey:
				InputMap.action_erase_event(act, e)
	var used := {}
	for a in ACTS:
		for k in kb[a[0]]:
			if int(k) != 0:
				_add_key(a[0], int(k))
				used[int(k)] = true
	for ar in ARROWS:
		if not used.has(ar[0]):
			_add_key(ar[1], ar[0])
	save()

func _add_key(act: String, k: int) -> void:
	var code := k & 0xFFFFFFFF
	var side: int = (k >> SIDE_SH) if sides else 0
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.location = side
	InputMap.action_add_event(act, e)
	if side != 0:
		return      # a label-only match would ignore the side (a browser that sends no code sends no side either: see note())
	var e2 := InputEventKey.new()   # some browsers report modifier keys only by key label
	e2.keycode = code
	InputMap.action_add_event(act, e2)

## the binding a real key press stands for (what the key screen stores): a modifier keeps its side
static func code_of(ev: InputEventKey) -> int:
	var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	if MODS.has(k) and ev.location != KEY_LOCATION_UNSPECIFIED:
		k |= ev.location << SIDE_SH
	return k

## put key k into slot i of action a; it leaves wherever else it was. k = 0 clears the slot.
func bind(a: String, i: int, k: int) -> void:
	if k != 0:
		for b in kb:
			var s: Array = kb[b]
			for j in 2:
				if int(s[j]) == k: s[j] = 0
	kb[a][i] = k
	apply_keys()

func kb_uses(k: int) -> bool:
	for a in kb:
		if kb[a].has(k): return true
	return false

## kbName
static func key_name(k: int) -> String:
	if k == 0: return "—"
	var side: int = k >> SIDE_SH
	k &= 0xFFFFFFFF
	if side != 0 and MODS.has(k):
		return ("L-" if side == KEY_LOCATION_LEFT else "R-") + {KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_META: "Meta"}[k]
	match k:
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_SPACE: return "Space"
	return OS.get_keycode_string(k)


# ---------- control device ----------
func touch_auto() -> bool:
	if _touch_auto == null:
		var t := false
		if OS.has_feature("web"):
			var r = JavaScriptBridge.eval("(function(){try{return matchMedia('(pointer:coarse)').matches||(navigator.maxTouchPoints>0&&!matchMedia('(any-pointer:fine)').matches);}catch(e){return false;}})()", true)
			t = bool(r) if (r is bool or r is int) else false     # the bridge hands JS booleans back as int
		else:
			t = DisplayServer.is_touchscreen_available()
		_touch_auto = t
	return _touch_auto

## TOUCHUI
func touch_ui() -> bool:
	if dev == "touch": return true
	if dev != "auto": return false
	if last == "pad": return false
	if last == "kbm" and kbm_seen: return false
	return touch_auto() or last == "touch"

## ACTDEV
func act_dev() -> String:
	if dev != "auto": return dev
	return "touch" if touch_ui() else last

## KH: the key glyph in front of a prompt: "X " on keyboard, "Ⓧ " on a pad, nothing on touch
func kh() -> String:
	var d := act_dev()
	return "" if d == "touch" else ("Ⓧ " if d == "pad" else "X ")

## qWatch: 150 frames averaging over 24 ms lower QK by .2 (to .6), then 3 s before it looks again (menus and the title
## don't count). Returns true when QK dropped.
func qwatch(dt: float, skip: bool) -> bool:
	if skip:
		qw["n"] = 0
		qw["s"] = 0.0
		return false
	if qw["cool"] > 0.0:
		qw["cool"] -= dt
		return false
	qw["n"] += 1
	qw["s"] += dt
	if qw["n"] < 150: return false
	var avg: float = qw["s"] / qw["n"]
	qw["n"] = 0
	qw["s"] = 0.0
	if avg > 24.0 and qk > 0.6:
		qk = maxf(0.6, snappedf(qk - 0.2, 0.01))
		save()
		apply_qk()
		qw["cool"] = 3000.0
		return true
	return false

## fit(): the prototype caps its canvas at 1600·QK pixels. Here the drop never touches the resolution: drawing the
## game at its own size (stretch viewport) made the HUD, menus and text blocky on phones, which already run the
## low_end path (half-res bloom source, slower bloom refresh, cheaper shade). QK is kept and saved, but 2D stays at
## the window's pixels.
func apply_qk() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null: return
	var w: Window = tree.root
	if w.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS: w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS

## devUsed: every real input says which device is in hand (a touch right after keys is ignored; emulated mouse = touch)
func note(ev: InputEvent) -> void:
	var now := Time.get_ticks_msec()
	if ev is InputEventKey and ev.pressed:
		if sides and ev.location == KEY_LOCATION_UNSPECIFIED and MODS.has(ev.keycode if ev.keycode != 0 else ev.physical_keycode):
			sides = false            # this platform doesn't say which Shift / Ctrl: bind both sides from now on
			apply_keys()
		kbm_seen = true
		kbm_t = now
		last = "kbm"
	elif ev is InputEventMouseButton and ev.pressed and ev.device != InputEvent.DEVICE_ID_EMULATION:
		kbm_seen = true
		kbm_t = now
		last = "kbm"
	elif ev is InputEventScreenTouch and ev.pressed:
		if now - kbm_t >= 1500:
			last = "touch"
	elif ev is InputEventJoypadButton and ev.pressed:
		last = "pad"
	elif ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.6:
		last = "pad"
