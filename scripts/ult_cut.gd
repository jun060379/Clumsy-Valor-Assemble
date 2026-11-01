extends Control
## Ult cut-in (prototype ultCutStart / drawUltCut2, Honkai: Star Rail style): a white "쨍" flash, then the splash — a dim
## in the member's colour, a slanted colour panel slides in, the splash art (ult_art_*.png) pops in, the skill name
## strikes in with its underline — holds a beat, a white cut, the clip (ult_*.ogv, letterboxed), a white cut back.
## Without a clip the splash goes straight to the closing white cut.

const UI := preload("res://scripts/ui_kit.gd")
const ULT := preload("res://scripts/ult.gd")
## UC and ULTVID durations (ms)
const PING := 110.0
const SPLASH := 820.0
const OUT := 150.0
const VID := {"estelle": 2050.0, "aida": 1380.0, "luce": 2480.0}

var arena
var sortie
var on := false
var who := "estelle"
var arts := {}
var vids := {}
var vp: VideoStreamPlayer
var started := false
var bad := {}                   # members whose clip never produced a frame here (falls back to the splash only)
var art_node: Control
var front: Control
var art_sil: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	for c in ["estelle", "aida", "luce"]:
		arts[c] = load("res://assets/ult/ult_art_%s.png" % c)
		var p := "res://assets/ult/ult_%s.ogv" % c
		if ResourceLoader.exists(p):
			var s = load(p)
			if s is VideoStream: vids[c] = s
	art_node = _layer(_draw_art)
	vp = VideoStreamPlayer.new()
	vp.expand = true
	vp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.volume_db = -80.0
	vp.visible = false
	add_child(vp)
	front = _layer(_draw_front)

func _layer(fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	c.draw.connect(fn)
	add_child(c)
	return c

func has_video(c: String) -> bool:
	return vids.has(c) and not bad.has(c)

func length(c: String) -> float:
	return PING + SPLASH + (VID[c] + OUT if has_video(c) else OUT)

func start(c: String) -> void:
	who = c
	on = true
	visible = true
	started = false
	vp.visible = false
	vp.stop()
	if has_video(c):
		vp.stream = vids[c]

func stop() -> void:
	on = false
	visible = false
	vp.stop()
	vp.visible = false

func _t() -> float:
	return arena.ult.t

func _process(_delta: float) -> void:
	if not on: return
	var t := _t()
	var t2 := PING + SPLASH
	var vs := get_viewport_rect().size
	if has_video(who) and t >= t2:
		if not started:
			started = true
			vp.visible = true
			vp.play()
		elif t >= t2 + 250.0:
			var tex := vp.get_video_texture()
			if not vp.is_playing() or tex == null or tex.get_width() < 2:
				bad[who] = true          # no decoder output: skip to the closing white cut
				vp.stop()
				vp.visible = false
		# object-fit: cover
		var k := maxf(vs.x / 16.0, vs.y / 9.0)
		var sz := Vector2(16.0 * k, 9.0 * k)
		vp.position = (vs - sz) / 2.0
		vp.size = sz
	queue_redraw()
	art_node.queue_redraw()
	front.queue_redraw()

static func _uE(v: float) -> float:
	var x := clampf(v, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

static func _uB(v: float) -> float:
	var x := clampf(v, 0.0, 1.0)
	var c := 1.7
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)

## dim + shard + panel (under the art)
func _draw() -> void:
	if not on: return
	var vs := get_viewport_rect().size
	var t := _t()
	var I: Dictionary = ULT.INFO[who]
	var uc: Color = I["col"]
	var t2 := PING + SPLASH
	var sp := t < t2 + 60.0
	if not sp: return
	var u := t - PING * 0.4
	# uv-dim: radial colour glow fading into near black
	draw_rect(Rect2(Vector2.ZERO, vs), Color(6 / 255.0, 4 / 255.0, 14 / 255.0, 0.92 * minf(1.0, t / 90.0)))
	var gc := Vector2(vs.x * 0.3, vs.y * 0.5)
	for i in 10:
		var k := 1.0 - i / 10.0
		draw_circle(gc, vs.x * 0.85 * k, Color(uc, 0.05 * minf(1.0, t / 90.0)))
	# uv-shard: a diagonal colour stripe drifting right
	var sa := minf(1.0, u / 120.0) * (1.0 if t < t2 else 0.0)
	if sa > 0.0:
		var sx := (-30.0 + _uE(u / 260.0) * 30.0 + u * 0.004) / 100.0 * vs.x * 1.2
		var dx := vs.y * 1.2 * tan(deg_to_rad(10.0))
		for b in [[0.30, 0.33, Color(uc, 0.85)], [0.36, 0.37, Color(I["col2"], 0.5)]]:
			var x0: float = -0.1 * vs.x + b[0] * vs.x * 1.2 + sx
			var x1: float = -0.1 * vs.x + b[1] * vs.x * 1.2 + sx
			draw_colored_polygon(PackedVector2Array([Vector2(x0 + dx, -0.1 * vs.y), Vector2(x1 + dx, -0.1 * vs.y), Vector2(x1 - dx, 1.1 * vs.y), Vector2(x0 - dx, 1.1 * vs.y)]), Color(b[2], b[2].a * sa))
	# uv-panel: slanted colour panel, gradient, fine stripes
	var px := (-110.0 + _uE(u / 200.0) * 110.0) / 100.0
	var pw := vs.x * 0.58
	var r := Rect2(-0.04 * vs.x + px * pw, 0, pw, vs.y)
	var pts := UI.clip(r, [[0, 0], [100, 0], [78, 100], [0, 100]])
	var top := Color(uc, 0.95)
	var bot := Color(20 / 255.0, 8 / 255.0, 30 / 255.0, 0.85)
	draw_polygon(pts, PackedColorArray([top, Color(uc, 0.75), bot.lerp(Color(uc, 0.45), 0.4), bot]))
	var x := r.position.x
	while x < r.end.x:
		draw_line(Vector2(x, 0), Vector2(x - vs.y * 0.18, vs.y), Color(1, 1, 1, 0.1), 2.0)
		x += 22.0
	# the art's glow
	if t > PING * 0.6:
		draw_circle(Vector2(vs.x * 0.27, vs.y * 0.5), vs.y * 0.5, Color(uc, 0.18))

## the splash art (pops in with an overshoot, drifts)
func _draw_art() -> void:
	if not on: return
	var t := _t()
	var t2 := PING + SPLASH
	if not (t < t2 + 60.0 and t > PING * 0.6): return
	var vs := get_viewport_rect().size
	var tex: Texture2D = arts[who]
	var ak := _uB((t - PING * 0.6) / 240.0)
	var h := vs.y * 1.08
	var w := h * tex.get_width() / tex.get_height()
	var tx := (1.0 - ak) * -60.0 + (t - PING) * 0.012
	var sc := 1.14 - 0.14 * ak + (t - PING) * 0.00003
	var pos := Vector2(vs.x * 0.01 + tx, -vs.y * 0.04)
	var piv := pos + Vector2(w * 0.5, h * 0.8)
	art_node.draw_set_transform(piv, 0.0, Vector2(sc, sc))
	art_node.draw_texture_rect(tex, Rect2(pos - piv, Vector2(w, h)), false)
	art_node.draw_set_transform(Vector2.ZERO)

## the name, letterbox bars (over the clip) and the white cuts
func _draw_front() -> void:
	if not on: return
	var vs := get_viewport_rect().size
	var t := _t()
	var I: Dictionary = ULT.INFO[who]
	var uc: Color = I["col"]
	var vid := has_video(who)
	var t2 := PING + SPLASH
	var L := length(who)
	if t < t2 + 60.0:
		var nk := _uE((t - PING - 170.0) / 220.0)
		if nk > 0.0:
			var bf := UI.bhs()
			var fs := int(clampf(vs.y * 0.072, 30.0, 64.0))
			var nm: String = I["name"]
			var nw := UI.text_w(bf, nm, fs)
			var rx := vs.x * 0.95 + (1.0 - nk) * 80.0
			var cy := vs.y * 0.5
			front.draw_string(bf, Vector2(rx - nw, cy - 4.0 + 3.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(20 / 255.0, 8 / 255.0, 30 / 255.0, 0.9 * nk))
			for gi in 3:
				front.draw_string_outline(bf, Vector2(rx - nw, cy - 4.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6 + gi * 6, Color(uc, 0.18 * nk))
			front.draw_string(bf, Vector2(rx - nw, cy - 4.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, nk))
			var sf := UI.anton(false, 5)
			var sub: String = I["sub"]
			var sfs := int(clampf(vs.y * 0.026, 11.0, 18.0))
			front.draw_string(sf, Vector2(rx - UI.text_w(sf, sub, sfs), cy + 22.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, sfs, Color(I["col2"], nk))
			var lw := _uE((t - PING - 260.0) / 260.0) * nw
			if lw > 0.0:
				var y := cy + 32.0
				front.draw_polygon(PackedVector2Array([Vector2(rx - lw, y), Vector2(rx, y), Vector2(rx, y + 3), Vector2(rx - lw, y + 3)]), PackedColorArray([Color(uc, 0.0), Color.WHITE, Color.WHITE, Color(uc, 0.0)]))
	if vid and t >= t2:
		var bk := _uE((t - t2) / 180.0)
		var bh := vs.y * 0.075 * bk
		front.draw_rect(Rect2(0, 0, vs.x, bh), Color(8 / 255.0, 4 / 255.0, 16 / 255.0, 0.95))
		front.draw_rect(Rect2(0, bh - 2.0, vs.x, 2.0), uc)
		front.draw_rect(Rect2(0, vs.y - bh, vs.x, bh), Color(8 / 255.0, 4 / 255.0, 16 / 255.0, 0.95))
		front.draw_rect(Rect2(0, vs.y - bh, vs.x, 2.0), uc)
	# white cuts
	var fl := 0.0
	if t < PING: fl = 1.0 - t / PING * 0.75
	elif vid and t >= t2 - 70.0 and t < t2 + 110.0: fl = (t - (t2 - 70.0)) / 70.0 if t < t2 else 1.0 - (t - t2) / 110.0
	if t > L - OUT: fl = maxf(fl, (t - (L - OUT)) / OUT)
	if fl > 0.0: front.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, clampf(fl, 0.0, 1.0)))
