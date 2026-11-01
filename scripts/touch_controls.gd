extends Control
## On-screen controls for phones: a stick on the left half (follows the thumb, or fixed: settings), four buttons on the right.
## Each finger is tracked on its own, so moving and attacking at the same time works.
## Shown by the prototype's TOUCHUI rule (settings.gd touch_ui): on touch-first devices, or when forced in 설정;
## once a keyboard or mouse is used they hide until a real touch.

const BTN := [
	{"a": "attack", "label": "공격", "pos": Vector2(-96, -96), "r": 46.0},
	{"a": "jump", "label": "점프", "pos": Vector2(-196, -62), "r": 36.0},
	{"a": "dash", "label": "대시", "pos": Vector2(-206, -158), "r": 32.0},
	{"a": "guard", "label": "스킬", "pos": Vector2(-104, -200), "r": 32.0},
]
const DEAD := 18.0
const FONT := preload("res://assets/fonts/NotoSansKR-Black.otf")
const STICK_R := 60.0

var stick_id := -1
var stick_o := Vector2.ZERO
var stick_p := Vector2.ZERO
var held := {}            # finger index -> action
var shown := false
var arena


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(_delta: float) -> void:
	var on: bool = arena.cfg.touch_ui() and (arena.ui_root == null or not arena.ui_root.holds())
	if on != shown:
		shown = on
		visible = on
		if not on: _release_all()
	if shown: queue_redraw()

func _release_all() -> void:
	for i in held:
		Input.action_release(held[i])
	held.clear()
	if stick_id >= 0:
		stick_id = -1
		_apply_stick()

## where the stick rests (and stays, in fixed mode)
func _home() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(110.0, s.y - 110.0)


func _btn_center(b: Dictionary) -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(s.x, s.y) + b["pos"]


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if not shown:
			return
		if ev.pressed:
			for b in BTN:
				if ev.position.distance_to(_btn_center(b)) < b["r"] + 14.0:
					held[ev.index] = b["a"]
					Input.action_press(b["a"])
					queue_redraw()
					return
			if ev.position.x < get_viewport_rect().size.x * 0.5 and stick_id < 0:
				stick_id = ev.index
				stick_o = ev.position if arena.cfg.stick == "float" else _home()
				stick_p = ev.position
				_apply_stick()
		else:
			if held.has(ev.index):
				var a: String = held[ev.index]
				held.erase(ev.index)
				if not held.values().has(a):
					Input.action_release(a)
			if ev.index == stick_id:
				stick_id = -1
				_apply_stick()
		queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == stick_id:
		stick_p = ev.position
		var d := stick_p - stick_o
		if d.length() > STICK_R and arena.cfg.stick == "float":   # the base follows the thumb when it drags too far
			stick_o = stick_p - d.normalized() * STICK_R
		_apply_stick()
		queue_redraw()


func _apply_stick() -> void:
	var d := stick_p - stick_o if stick_id >= 0 else Vector2.ZERO
	set_act("left", d.x < -DEAD)
	set_act("right", d.x > DEAD)
	set_act("up", d.y < -DEAD * 1.6)
	set_act("down", d.y > DEAD * 1.6)


func set_act(a: String, on: bool) -> void:
	if on and not Input.is_action_pressed(a):
		Input.action_press(a)
	elif not on and Input.is_action_pressed(a):
		Input.action_release(a)


func _draw() -> void:
	if not shown:
		return
	var font: Font = FONT
	for b in BTN:
		var c := _btn_center(b)
		var on: bool = held.values().has(b["a"])
		# glass circles with a thin rim (hud3)
		draw_circle(c, b["r"], Color(1, 1, 1, 0.28) if on else Color(0, 0, 0, 0.35))
		draw_arc(c, b["r"], 0, TAU, 40, Color(1, 1, 1, 0.75), 2.0, true)
		var fs := 13 if b["r"] > 40.0 else 11
		var w := font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w / 2.0, fs * 0.36), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
	if stick_id >= 0:
		draw_arc(stick_o, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(stick_o + (stick_p - stick_o).limit_length(STICK_R), 24.0, Color(1, 1, 1, 0.35))
	else:
		var a := 0.35 if arena.cfg.stick == "fixed" else 0.15
		draw_arc(_home(), STICK_R, 0, TAU, 40, Color(1, 1, 1, a), 2.0)
		draw_circle(_home(), 24.0, Color(1, 1, 1, a))
