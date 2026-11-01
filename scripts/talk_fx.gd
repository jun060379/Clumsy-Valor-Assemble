extends RefCounted
## The talk scene in the prototype's v3 dialogue look (hud3.js #dlg): the speaker's cut-in shards (h3sh) behind the
## standing art (dlgBust, white rim and black drop), the balloon with its tail that pops from its corner (h3bal), the
## ransom-note name whose letters drop in one by one (h3rn) with the role tag, the line typed letter by letter, each
## letter tumbling into place (h3ch), and the formal numbered choices that swing in from the right (h3chIn) and lean
## out when chosen (transition .25s).
## Shared by dialog.gd (talks in the world) and ui_choice.gd (Bran's choices page). The owner keeps the clocks and
## calls draw_back / draw_sil / draw_front from three canvas items (the silhouette one with UI.solid_mat()).

const UI := preload("res://scripts/ui_kit.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const BK6 := [0.2, 1.6, 0.4, 1.0]
const BK5 := [0.2, 1.5, 0.4, 1.0]
## DC: the cut-in colour per speaker (others take the leader's colour)
const DC := {"bran": Color("#ff7a2f")}
## CHS: per choice row: lean when chosen (deg), indent (px), its cut when chosen (clip %)
const CHS := [[-5.0, 0.0, [[3, 12], [100, 0], [97, 100], [0, 86]]], [3.0, -8.0, [[0, 0], [96, 10], [100, 92], [4, 100]]],
	[-4.0, -16.0, [[2, 6], [100, 0], [95, 88], [0, 100]]], [4.0, -24.0, [[0, 8], [98, 0], [100, 100], [3, 90]]]]
const BOX_CLIP := [[0, 0], [15, 22], [44, 15], [99, 10], [100, 80], [95, 100], [9, 96], [6, 54], [9, 32]]
const BOX_IN := [[2.2, 4], [15.6, 25.5], [44.2, 18.6], [98.3, 14], [99, 79], [94.4, 96], [9.8, 92.4], [7, 54], [9.8, 33]]

var who := ""
var por: Texture2D
var nm := ""
var role := ""
var tc := Color("#ff3d7f")       # the leader's colour (--tc)
var open_t := 0.0                # ms since the talk opened (cut-in, bust, balloon, name)
var line_t := 0.0                # ms since this line began
var letters: Array = []          # [char, appear time in line_t] for the letters on show
var ch_t := 0.0                  # ms since the choices came up
var choices: Array = []          # labels
var sel := -1
var tr := UIA.Tr.new()
var box := Rect2()
var ch_polys: Array = []         # hit polygons (screen) per choice


func reset(w: String, p: Texture2D, n: String, r: String, col: Color) -> void:
	who = w
	por = p
	nm = n
	role = r
	tc = col
	open_t = 0.0
	line_t = 0.0
	letters = []
	choices = []
	ch_t = 0.0
	sel = -1
	tr.clear()

func step(dt: float) -> void:
	open_t += dt
	line_t += dt
	ch_t += dt
	tr.step(dt)

## a new line: no letters yet
func new_line() -> void:
	line_t = 0.0
	letters = []

## show text up to n letters; letters that arrive now get this moment as their start (instant = no tumble)
func show(text: String, n: int, instant := false) -> void:
	while letters.size() < mini(n, text.length()):
		letters.append([text[letters.size()], -1e9 if instant else line_t])

func set_choices(L: Array, s: int) -> void:
	if L != choices:
		choices = L.duplicate()
		ch_t = 0.0
	sel = s

static func dk(vs: Vector2) -> float:
	return clampf(minf(vs.x, vs.y) / 400.0 * 0.82, 1.0, 1.75)

func dc() -> Color:
	return DC.get(who, tc)

## the balloon's rect (.dbox: left max(22%,170px), right 3%, bottom 4%, min-height 34%)
func box_rect(vs: Vector2) -> Rect2:
	var x0 := maxf(vs.x * 0.22, 170.0)
	var x1 := vs.x * 0.97
	var h := vs.y * 0.34
	return Rect2(x0, vs.y * 0.96 - h, x1 - x0, h)


# ---------- behind the art: the cut-in shards ----------
func draw_back(ci: CanvasItem, vs: Vector2) -> void:
	var cr := Rect2(-0.04 * vs.x, vs.y * 0.02, vs.x * 0.4, vs.y * 1.04)      # left -4%, bottom -6%, 40% x 104%
	var shards := [[Rect2(cr.position.x, cr.position.y + cr.size.y * 0.08, cr.size.x * 0.96, cr.size.y * 0.92), dc(), 0.0,
		[[8, 18], [40, 2], [52, 14], [88, 6], [76, 34], [100, 52], [80, 66], [92, 100], [0, 100], [4, 60], [0, 40]]],
		[Rect2(cr.position.x - cr.size.x * 0.06, cr.position.y + cr.size.y * 0.18, cr.size.x * 0.88, cr.size.y * 0.82), Color.BLACK, 60.0,
		[[14, 10], [62, 0], [72, 22], [100, 30], [84, 58], [96, 100], [0, 100], [6, 44]]]]
	for S in shards:
		var r: Rect2 = S[0]
		var u := UIA.p(open_t, S[2], 500.0, BK6)
		var m := UIA.xf(r.get_center(), Vector2(-0.6 * r.size.x * (1.0 - u), 0), deg_to_rad(-8.0) * (1.0 - u))
		ci.draw_colored_polygon(m * UI.clip(r, S[3]), S[1])


# ---------- the standing art (dlgBust: in from the left with the overshoot) ----------
func _art_rect(vs: Vector2) -> Rect2:
	if por == null: return Rect2()
	var h := vs.y
	var w := por.get_width() * h / por.get_height()
	return Rect2(0, vs.y * 0.04, w, h)

func _art_xf(vs: Vector2) -> Array:
	var u := UIA.p(open_t, 0.0, 450.0, BK5)
	var r := _art_rect(vs)
	return [Vector2(-0.4 * r.size.x * (1.0 - u), 0), clampf(open_t / 450.0 * 2.0, 0.0, 1.0)]

## silhouettes behind the art (drop-shadow(-3px 0 0 #fff) drop-shadow(10px 4px 0 #000)); ci carries UI.solid_mat()
func draw_sil(ci: CanvasItem, vs: Vector2) -> void:
	if por == null: return
	var r := _art_rect(vs)
	var X := _art_xf(vs)
	var o: Vector2 = X[0]
	var a: float = X[1]
	ci.draw_texture_rect(por, Rect2(r.position + o + Vector2(10, 4), r.size), false, Color(0, 0, 0, a))
	ci.draw_texture_rect(por, Rect2(r.position + o + Vector2(7, 4), r.size), false, Color(0, 0, 0, a))
	ci.draw_texture_rect(por, Rect2(r.position + o + Vector2(-3, 0), r.size), false, Color(1, 1, 1, a))


# ---------- the art, the balloon, the name, the line, the choices ----------
func draw_front(ci: CanvasItem, vs: Vector2) -> void:
	var k := dk(vs)
	if por != null:
		var r := _art_rect(vs)
		var X := _art_xf(vs)
		ci.draw_texture_rect(por, Rect2(r.position + X[0], r.size), false, Color(1, 1, 1, X[1]))
	box = box_rect(vs)
	var bu := UIA.p(open_t, 120.0, 450.0, BK6)
	var ba := clampf((open_t - 120.0) / 120.0, 0.0, 1.0)
	var piv := box.position + box.size * Vector2(0.04, 0.06)
	var bm := UIA.xf(piv, Vector2.ZERO, deg_to_rad(-8.0) * (1.0 - bu), Vector2.ONE * lerpf(0.2, 1.0, bu))
	if ba > 0.0:
		ci.draw_set_transform_matrix(bm)
		ci.draw_colored_polygon(UI.clip(Rect2(box.position + Vector2(9, 8), box.size), BOX_CLIP), Color(tc, ba))
		ci.draw_colored_polygon(UI.clip(box, BOX_CLIP), Color(1, 1, 1, ba))
		ci.draw_colored_polygon(UI.clip(box, BOX_IN), Color(0, 0, 0, ba))
		# the tail toward the speaker
		ci.draw_colored_polygon(PackedVector2Array([box.position + Vector2(box.size.x * 0.09, box.size.y * 0.32), box.position + Vector2(-box.size.x * 0.06, box.size.y * 0.02), box.position + Vector2(box.size.x * 0.15, box.size.y * 0.22)]), Color(1, 1, 1, ba))
		ci.draw_colored_polygon(PackedVector2Array([box.position + Vector2(box.size.x * 0.098, box.size.y * 0.30), box.position + Vector2(-box.size.x * 0.035, box.size.y * 0.06), box.position + Vector2(box.size.x * 0.15, box.size.y * 0.25)]), Color(0, 0, 0, ba))
		_draw_text(ci, k, ba)
		ci.draw_set_transform(Vector2.ZERO)
	_draw_name(ci, k)
	_draw_choices(ci, vs, k)

func _draw_text(ci: CanvasItem, k: float, a: float) -> void:
	var f := UI.noto()
	var fs := int(round(15.5 * k))
	var lh := fs * 1.6
	var x0 := box.position.x + box.size.x * 0.12
	var x1 := box.end.x - box.size.x * 0.06
	var y := box.position.y + box.size.y * 0.32 + fs
	var x := x0
	# wrap at spaces where possible
	var i := 0
	while i < letters.size():
		var ch: String = letters[i][0]
		if ch == "\n":
			x = x0
			y += lh
			i += 1
			continue
		if ch == " " and x > x0:
			var j := i + 1
			var ww := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			while j < letters.size() and letters[j][0] != " " and letters[j][0] != "\n":
				ww += f.get_string_size(letters[j][0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				j += 1
			if x + ww > x1:
				x = x0
				y += lh
				i += 1
				continue
		var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if x + cw > x1:
			x = x0
			y += lh
		var age: float = line_t - letters[i][1]
		var u := UIA.p(age, 0.0, 280.0, BK6)
		var la := clampf(age / 140.0, 0.0, 1.0) * a
		if la > 0.0 and ch != " ":
			var c := Vector2(x + cw / 2.0, y - fs * 0.35)
			var m := UIA.xf(c, Vector2(0, -10.0 * (1.0 - u)), deg_to_rad(-12.0) * (1.0 - u), Vector2.ONE * lerpf(1.6, 1.0, u))
			ci.draw_set_transform_matrix(m)
			ci.draw_string(f, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, la))
		x += cw
		i += 1

## the ransom-note name (letters on white / black / colour chips, each turned and nudged), then the role tag
func _draw_name(ci: CanvasItem, k: float) -> void:
	if nm == "": return
	var K := ["a", "b", "c", "b"]
	var n := nm.length()
	var org := box.position + Vector2(box.size.x * 0.10, -34.0)
	var base := Transform2D(deg_to_rad(-6.0), org)
	var x := 0.0
	var bottom := 34.0
	for i in n:
		var ch := nm[i]
		var h := (i * 7919 + n * 31) % 997
		var r := ((h % 13) - 6) * 1.2
		var yy := float(((h >> 3) % 5) - 2)
		var s := 1.0 + (((h >> 2) % 5) - 2) * 0.09
		var fs := int(round(26.0 * s * k))
		var f: Font = UI.noto_k() if h % 3 == 0 else UI.bhs()
		var cls: String = K[(i + n) % 4]
		var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + fs * 0.24
		var hh := fs * 1.08
		var age := open_t - i * 55.0
		var u := UIA.p(age, 0.0, 500.0, BK6)
		var la := clampf(age / 150.0, 0.0, 1.0)
		if la > 0.0:
			var c := Vector2(x + w / 2.0, bottom - hh / 2.0 + yy)
			var m := base * UIA.xf(c, Vector2(0, -40.0 * (1.0 - u)), deg_to_rad(r + (-3.0 * r - r) * (1.0 - u)), Vector2.ONE * lerpf(1.8, 1.0, u))
			ci.draw_set_transform_matrix(m)
			var rr := Rect2(x, bottom - hh + yy, w, hh)
			var bg := Color.WHITE if cls == "a" else (Color.BLACK if cls == "b" else tc)
			var fg := Color.WHITE if cls == "b" else Color.BLACK
			var sh := tc if cls == "b" else Color.BLACK
			ci.draw_rect(Rect2(rr.position + Vector2(3, 3), rr.size), Color(sh, la))
			ci.draw_rect(rr, Color(bg, la))
			ci.draw_string(f, Vector2(x + fs * 0.12, rr.end.y - hh * 0.2), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fg, la))
		x += w + 1.0
	if role != "":
		var rf := UI.noto_k()
		var rs := int(round(10.5 * k))
		var rw := rf.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, rs).x + 16.0
		var ra := clampf((open_t - n * 55.0) / 200.0, 0.0, 1.0)
		ci.draw_set_transform_matrix(base)
		var rr2 := Rect2(x + 8.0, bottom - 4.0 - rs * 1.5, rw, rs * 1.5)
		var sk := tan(deg_to_rad(14.0)) * rr2.size.y
		ci.draw_colored_polygon(PackedVector2Array([rr2.position + Vector2(sk, 0), Vector2(rr2.end.x + sk, rr2.position.y), rr2.end, Vector2(rr2.position.x, rr2.end.y)]), Color(1, 1, 1, ra))
		ci.draw_string(rf, Vector2(rr2.position.x + 8.0 + sk * 0.5, rr2.end.y - rs * 0.35), role, HORIZONTAL_ALIGNMENT_LEFT, -1, rs, Color(0, 0, 0, ra))
	ci.draw_set_transform(Vector2.ZERO)

## the choices: stacked on the right above the balloon, the chosen one leans out white over a colour drop
func _draw_choices(ci: CanvasItem, vs: Vector2, k: float) -> void:
	ch_polys.clear()
	var n := choices.size()
	if n == 0: return
	var bf := UI.bhs()
	var h := 40.0 * k
	var gap := 10.0
	var right := vs.x * 0.98 - 18.0
	var bottom := vs.y - (vs.y * 0.38 + 10.0) - 8.0
	var top := bottom - n * h - (n - 1) * gap
	for i in n:
		var C: Array = CHS[i % CHS.size()]
		var on := i == sel
		var lab: String = choices[i]
		var ts := int(round((18.0 if on else 16.0) * k))
		var ts_v: float = tr.get_v("fs%d" % i, 18.0 if on else 16.0, 200.0, "ease") * k
		var w := 12.0 + 22.0 * k + 10.0 + bf.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x + 24.0
		var r := Rect2(right - w, top + i * (h + gap), w, h)
		var onk: float = tr.get_v("on%d" % i, 1.0 if on else 0.0, 250.0, BK6)
		var rot: float = lerpf(-2.0, C[0], onk)
		var tx: float = C[1] - 22.0 * onk
		var sc := lerpf(1.0, 1.1, onk)
		var age := ch_t - i * 80.0
		var u := UIA.p(age, 0.0, 450.0, BK6)
		var a := clampf(age / 200.0, 0.0, 1.0)
		if a <= 0.0:
			ch_polys.append(PackedVector2Array())
			continue
		tx += 140.0 * (1.0 - u)
		if u < 1.0: rot = lerpf(-2.0, rot, u)
		var m := UIA.xf(r.get_center(), Vector2(tx, 0), deg_to_rad(rot), Vector2(sc, sc))
		ci.draw_set_transform_matrix(m)
		var cl: Array = C[2] if onk > 0.5 else [[2, 0], [100, 0], [98, 100], [0, 100]]
		if onk > 0.5:
			ci.draw_colored_polygon(UI.clip(Rect2(r.position + Vector2(6, 6), r.size), cl), Color(tc, a))
		else:
			ci.draw_colored_polygon(UI.clip(r.grow(2.0), cl), Color(1, 1, 1, 0.7 * a))
		var face := Color.BLACK.lerp(Color.WHITE, onk)
		ci.draw_colored_polygon(UI.clip(r, cl), Color(face, a))
		# the number diamond
		var dcn := Vector2(r.position.x + 12.0 + 11.0 * k, r.get_center().y)
		var ds := 11.0 * k * 1.414
		var nb := Color(1, 1, 1, 0.85).lerp(Color.BLACK, onk)
		ci.draw_colored_polygon(PackedVector2Array([dcn + Vector2(0, -ds), dcn + Vector2(ds, 0), dcn + Vector2(0, ds), dcn + Vector2(-ds, 0)]), Color(nb, nb.a * a))
		var ns := "0%d" % (i + 1)
		var af := UI.anton(true)
		var nfs := int(round(13.0 * k))
		var nw := af.get_string_size(ns, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x
		ci.draw_string(af, dcn + Vector2(-nw / 2.0, nfs * 0.36), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs, Color(Color.BLACK.lerp(Color.WHITE, onk), a))
		var tcx := Color.WHITE.lerp(Color.BLACK, onk)
		ci.draw_string(bf, Vector2(dcn.x + 11.0 * k + 10.0, r.get_center().y + ts_v * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(ts_v)), Color(tcx, a))
		ch_polys.append(m * PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	ci.draw_set_transform(Vector2.ZERO)

## which choice is under p (screen), -1 if none
func choice_at(p: Vector2) -> int:
	for i in ch_polys.size():
		if ch_polys[i].size() > 2 and Geometry2D.is_point_in_polygon(p, ch_polys[i]): return i
	return -1
