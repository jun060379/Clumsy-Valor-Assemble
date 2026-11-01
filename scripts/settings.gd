extends RefCounted
## Player settings (prototype 설정 panel + sortie.js key rebinding), saved to user://settings.cfg.
## Control device (auto / kbm / pad / touch) with the prototype's TOUCHUI rule: once a keyboard or mouse has been
## used, the touch UI stays hidden until a real touch.

const PATH := "user://settings.cfg"
## KB_ACT
const ACTS := [["left", "왼쪽"], ["right", "오른쪽"], ["up", "위 · 계단 · 문"], ["down", "아래"], ["jump", "점프"], ["attack", "공격 · 상호작용"], ["guard", "스킬"], ["dash", "대시"], ["ult", "궁극기"], ["swap", "동료 교대"]]
## KB_PRE (each action two slots; 0 = empty). Godot can't tell left/right modifiers apart, so Shift / Ctrl are one key each.
const PRE := {
	"arrow": {"n": "방향키형", "left": [KEY_LEFT, 0], "right": [KEY_RIGHT, 0], "up": [KEY_UP, 0], "down": [KEY_DOWN, 0], "jump": [KEY_Z, 0], "attack": [KEY_X, 0], "guard": [KEY_A, 0], "dash": [KEY_SHIFT, 0], "ult": [KEY_D, 0], "swap": [KEY_CTRL, KEY_C], "rmb": "guard"},
	"wasd": {"n": "WASD + 마우스형", "left": [KEY_A, 0], "right": [KEY_D, 0], "up": [KEY_W, 0], "down": [KEY_S, 0], "jump": [KEY_SPACE, 0], "attack": [KEY_J, 0], "guard": [KEY_E, 0], "dash": [KEY_SHIFT, 0], "ult": [KEY_Q, 0], "swap": [KEY_R, 0], "rmb": "dash"},
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


func _init(a) -> void:
	arena = a
	kb = preset("arrow")
	rmb = "guard"
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	dev = String(cf.get_value("ui", "dev", dev))
	stick = String(cf.get_value("ui", "stick", stick))
	arena.screen_fx = bool(cf.get_value("ui", "pfx", true))
	arena.tod_auto = bool(cf.get_value("ui", "tod_auto", true))
	arena.weather = String(cf.get_value("ui", "weather", "clear"))
	arena.ambient = bool(cf.get_value("ui", "ambient", true))
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
	cf.set_value("ui", "tod_auto", arena.tod_auto)
	cf.set_value("ui", "weather", arena.weather)
	cf.set_value("ui", "ambient", arena.ambient)
	cf.set_value("keys", "rmb", rmb)
	for a in ACTS:
		cf.set_value("keys", a[0], kb[a[0]])
	cf.save(PATH)


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
	var e := InputEventKey.new()
	e.physical_keycode = k
	InputMap.action_add_event(act, e)
	var e2 := InputEventKey.new()   # some browsers report modifier keys only by key label
	e2.keycode = k
	InputMap.action_add_event(act, e2)

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
			t = r == true
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

## devUsed: every real input says which device is in hand (a touch right after keys is ignored; emulated mouse = touch)
func note(ev: InputEvent) -> void:
	var now := Time.get_ticks_msec()
	if ev is InputEventKey and ev.pressed:
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
