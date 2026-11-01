extends Control
## Screen-space front end on its own layer: title / hero select, the top-right buttons and the main menu with its
## pages (menu.gd, options.gd), and the menu transition (sweep.gd) over everything.
## Also notes which control device is in hand (settings.gd) and turns the mouse into attack / right-click actions.

const TITLE := preload("res://scripts/title.gd")
const MENU := preload("res://scripts/menu.gd")
const SWEEP := preload("res://scripts/sweep.gd")
const UIA := preload("res://scripts/ui_anim.gd")

var arena
var title
var menu
var sweep
var mouse_held := {}            # button -> action pressed by it


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIA.hook_web()
	var ck = UIA.clock_node()
	if ck != null: add_child(ck)
	menu = Control.new()
	menu.set_script(MENU)
	menu.arena = arena
	menu.ui_root = self
	add_child(menu)
	title = Control.new()
	title.set_script(TITLE)
	title.arena = arena
	title.ui_root = self
	add_child(title)
	sweep = Control.new()
	sweep.set_script(SWEEP)
	add_child(sweep)
	sweep.visible = false
	# test runs (a script-driven SceneTree) skip the title
	if get_tree().get_script() != null:
		title.active = false
		title.visible = false

## the world holds still under the title, a menu page or a transition
func holds() -> bool:
	return title.active or menu.is_open() or sweep.active

func start_game(c: String) -> void:
	var P = arena.player
	if c != P.who:
		P.party.erase(c)
		P.party.push_front(c)
		P.switch_char(c)
	P.hp = P.MAX_HP
	P.hpm[c] = P.MAX_HP
	P.last_hp = P.hp
	arena.fade = 1.0
	arena.fade_dir = -1
	arena.sfx("ready", 0.6)

## padPoll: the left stick steers every menu as the d-pad does (only while a screen covers the world; in play the
## stick is bound to the move actions)
var stick_dir := {0: 0, 1: 0}
func _stick_nav(ev: InputEventJoypadMotion) -> void:
	if ev.axis != JOY_AXIS_LEFT_X and ev.axis != JOY_AXIS_LEFT_Y: return
	var menus: bool = holds() or (arena.sortie != null and arena.sortie.covers()) or (arena.fame != null and arena.fame.holds())
	var th := 0.45 if ev.axis == JOY_AXIS_LEFT_X else 0.6
	var d := 0
	if ev.axis_value < -th: d = -1
	elif ev.axis_value > th: d = 1
	elif absf(ev.axis_value) > th * 0.7: d = stick_dir[ev.axis]    # a little hysteresis
	var was: int = stick_dir[ev.axis]
	if d == was: return
	stick_dir[ev.axis] = d
	if not menus: return
	var btn := {0: {-1: JOY_BUTTON_DPAD_LEFT, 1: JOY_BUTTON_DPAD_RIGHT}, 1: {-1: JOY_BUTTON_DPAD_UP, 1: JOY_BUTTON_DPAD_DOWN}}
	if was != 0: _pad_btn(btn[ev.axis][was], false, ev.device)
	if d != 0: _pad_btn(btn[ev.axis][d], true, ev.device)

func _pad_btn(b: int, down: bool, dev: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = down
	e.device = dev
	Input.parse_input_event(e)

func _input(ev: InputEvent) -> void:
	arena.cfg.note(ev)
	if ev is InputEventJoypadMotion: _stick_nav(ev)
	if ev is InputEventKey and ev.pressed and not ev.echo and not title.active and not menu.capturing():
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		if k == KEY_F and not arena.cfg.kb_uses(KEY_F):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()

func toggle_fullscreen() -> void:
	var m := DisplayServer.window_get_mode()
	if m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

## real mouse buttons that no UI took: left = attack, right = skill (방향키형) or dash (WASD형)
func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton) or ev.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var b: int = ev.button_index
	if ev.pressed:
		if holds() or arena.cfg.act_dev() != "kbm": return
		var a := ""
		if b == MOUSE_BUTTON_LEFT: a = "attack"
		elif b == MOUSE_BUTTON_RIGHT: a = arena.cfg.rmb
		if a == "": return
		mouse_held[b] = a
		Input.action_press(a)
	elif mouse_held.has(b):
		Input.action_release(mouse_held[b])
		mouse_held.erase(b)
