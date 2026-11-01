extends Control
## Menu transition (sortie.js txSweep2, class 'mn'): a colour band leads in from the right, a black band follows at its
## own pace and covers the screen; the page swaps underneath (mid); then black leaves first and the colour trails it.
## "NOW LOADING" only shows if the swap takes longer than 600 ms.

const UI := preload("res://scripts/ui_kit.gd")
const SK := 12.0                 # skewX(12deg)
const BLACK := Color("#0d0b10")

var active := false
var col := Color("#ff3d7f")
var t := 0.0                     # ms in the current phase
var phase := ""                  # in / cover / out
var mid = null                   # Callable run while covered
var done = null                  # Callable after the reveal
var hold := 0.0                  # extra cover time asked by mid
var frames := 0
var lt := 0.0                    # NOW LOADING opacity
var _mid_ran := false
var dots_t := 0.0
var speed := 1.0                 # test hook: ?slowtx in the page URL plays it at 1/10 speed (screenshots)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search", true)
		if q is String and q.contains("slowtx"): speed = 0.1

## txSweep2(mid, col): when one is already running, mid just runs now
func run(m: Callable, c: Color, d = null) -> void:
	if active:
		m.call()
		if d != null: d.call()
		return
	active = true
	col = c
	mid = m
	done = d
	phase = "in"
	t = 0.0
	lt = 0.0
	hold = 0.0
	_mid_ran = false
	visible = true
	queue_redraw()

func _input(ev: InputEvent) -> void:
	if active and (ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventJoypadButton):
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active:
		return
	var dt := minf(delta * 1000.0, 250.0) * speed   # real time, like the prototype's CSS / rAF clocks
	t += dt
	dots_t += dt
	if phase == "in" and t >= 590.0:
		phase = "cover"
		t = 0.0
		frames = 0
	elif phase == "cover":
		frames += 1
		if frames == 2 and not _mid_ran:
			_mid_ran = true
			var r = mid.call() if mid != null else null
			if r is float or r is int: hold = float(r)
		if t >= 600.0: lt = minf(1.0, lt + dt / 300.0)
		if _mid_ran and frames >= 4 and t >= maxf(200.0, hold):
			phase = "out"
			t = 0.0
	elif phase == "out":
		lt = maxf(0.0, lt - dt / 140.0)
		if t >= 700.0:
			active = false
			phase = ""
			visible = false
			var d = done
			done = null
			mid = null
			if d != null: d.call()
	queue_redraw()

## band position in percent of the band's own width (X(140) .. X(0) .. X(-140))
func _pos() -> Array:
	match phase:
		"in":
			var c := 140.0 * (1.0 - UI.bez(0.3, 0.6, 0.3, 1.0, t / 380.0))
			var k := 140.0 * (1.0 - UI.bez(0.7, 0.0, 0.3, 1.0, (t - 30.0) / 560.0))
			return [c, k]
		"cover":
			return [0.0, 0.0]
		"out":
			var k2 := -140.0 * UI.bez(0.6, 0.0, 0.4, 1.0, t / 420.0)
			var c2 := -140.0 * UI.bez(0.5, 0.0, 0.2, 1.0, (t - 60.0) / 640.0)
			return [c2, k2]
	return [140.0, 140.0]

func _band(p: float, c: Color, vs: Vector2) -> void:
	var w := vs.x * 1.6
	var cx := vs.x * 0.5 + p / 100.0 * w
	var top := -0.2 * vs.y
	var bot := 1.2 * vs.y
	var cy := vs.y * 0.5
	var tk := tan(deg_to_rad(SK))
	var pts := PackedVector2Array([
		Vector2(cx - w / 2.0 + tk * (top - cy), top), Vector2(cx + w / 2.0 + tk * (top - cy), top),
		Vector2(cx + w / 2.0 + tk * (bot - cy), bot), Vector2(cx - w / 2.0 + tk * (bot - cy), bot)])
	draw_colored_polygon(pts, c)

func _draw() -> void:
	if not active:
		return
	var vs := get_viewport_rect().size
	var p := _pos()
	_band(p[0], col, vs)
	_band(p[1], BLACK, vs)
	if lt > 0.0:
		var f := UI.anton(false, 6)
		var s := "NOW LOADING"
		var w := UI.text_w(f, s, 13)
		draw_set_transform(vs / 2.0, deg_to_rad(-6.0))
		draw_string(f, Vector2(-w / 2.0, 5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, lt))
		# txdots: "", ".", "..", "..." on steps(4) over 1 s
		var nd := int(fmod(dots_t / 1000.0, 1.0) * 4.0)
		draw_string(f, Vector2(w / 2.0 + 2.0, 5), ".".repeat(nd), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, lt))
		draw_set_transform(Vector2.ZERO)
