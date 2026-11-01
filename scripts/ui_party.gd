extends "res://scripts/ui_page.gd"
## 파티 (prototype PARTY v2 #pt2, ptRender / ptBar / openParty2): one tall slanted column per recruited member with the
## standing art, a hollow 01–03, the LEADER tag on the one in control and name / role / state at the foot. The picked
## column widens (flex 1 → 2.6, .55s --ez) and lights up; the rest stay dimmed (brightness .55 grayscale .5), members
## out of the party darker still (.4 / .8). The ground takes the picked member's colour. The bar: 빼기 / 넣기 (off for
## the leader or a full party), 리더로 (joins if needed, then takes control), 정보 (sweep → the character screen).
## Opened from the hub's 파티, the top bar's 파티, the fountain, the hall's living room and the dungeon select's faces.
## Keys (port only; the prototype has none but Esc): ←→ pick a member, ↓ / Enter to the bar, ←→ along it, Enter press,
## ↑ back to the columns, Esc close.

const UIA := preload("res://scripts/ui_anim.gd")
const SHEET := preload("res://scripts/ui_char.gd").SHEET
const ST := {"estelle": "res://assets/ui/st/estelle_base.webp", "aida": "res://assets/ui/st/aida_base.webp", "luce": "res://assets/ui/st/luce_base.webp"}
## CSS filter: brightness(b) grayscale(g) (in that order; both linear, so one pass)
const FILTER_SH := "shader_type canvas_item;\nuniform float br = 1.0;\nuniform float gs = 0.0;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV) * COLOR; float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722)); c.rgb = mix(c.rgb, vec3(l), gs) * br; COLOR = c; }"

var sel := "estelle"             # ptSel
var focus := -1                  # keyboard: -1 = the columns, 0..2 = a bar button
var tr := UIA.Tr.new()
var cols: Array = []             # one Control per column slot (each with its own filter material)
var top: Control                 # the bar, title, count and ✕ over the columns
var _L := {}                     # this frame's layout: c -> {r, poly, i}
var top_hits: Array = []
static var _sh: Shader


func _ready() -> void:
	super()
	keys = ["party"]
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED      # the halftone ground tiles
	if _sh == null:
		_sh = Shader.new()
		_sh.code = FILTER_SH
	for i in 3:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var m := ShaderMaterial.new()
		m.shader = _sh
		c.material = m
		var ii := i
		c.draw.connect(func(): _draw_col(c, ii))
		add_child(c)
		cols.append(c)
	top = Control.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	top.draw.connect(_draw_top)
	add_child(top)

## openParty2: ptSel = CHAR
func _opened() -> void:
	sel = arena.player.who
	focus = -1
	tr.clear()

## ROSTER: the recruited members (anyone in the party counts, so a save from before recruiting still shows them)
func roster() -> Array:
	var F = arena.get("fame")
	var P = arena.player
	return RN.ROSTER.filter(func(c): return P.party.has(c) or F == null or F.recruited(c))

func _tick(dt: float) -> void:
	tr.step(dt)
	if not roster().has(sel): sel = arena.player.who
	_L = layout(get_viewport_rect().size)

func _process(delta: float) -> void:
	super(delta)
	if visible:
		for c in cols: c.queue_redraw()
		top.queue_redraw()


# ---------- actions ----------
## a column tapped: it becomes ptSel, the ground takes its colour
func pick(c: String) -> void:
	if c == sel: return
	sel = c
	sfx("ready", 0.2)

## the bar's state for the picked member: [[act, label, enabled]...]
func bar() -> Array:
	var P = arena.player
	var inP: bool = P.party.has(sel)
	var lead: bool = sel == P.who
	return [["in", "빼기" if inP else "넣기", not (lead or (not inP and P.party.size() >= 3))], ["lead", "리더로", not lead], ["info", "정보", true]]

func press(a: String) -> void:
	var P = arena.player
	var c := sel
	for b in bar():
		if b[0] == a and not b[2]: return
	match a:
		"in":
			arena.toggle_member(c)          # PARTY ± c; leaveParty / the townsfolk let go of a member who joins
			arena.save_now()
			sfx("ready", 0.4)
		"lead":
			# not along: join (a full party drops its last member, PARTY.pop(), after the hand-over), then take control
			if not P.party.has(c):
				var out = P.party.back() if P.party.size() >= 3 else null
				arena.toggle_member(c)
				_swap(c)
				if out != null and P.party.has(out) and out != P.who: arena.toggle_member(out)
			else:
				_swap(c)
			arena.save_now()
			sfx("ready", 0.5)
		"info":
			# txSweep(() => { PTE.hidden = true; cxOpen(c) })
			menu.ui_root.sweep.run(func():
				menu.ext["char"].want_c = c
				menu._open_page("char", false), UI.col(c))

## partySwap(false, c); swapCd = 0
func _swap(c: String) -> void:
	var P = arena.player
	P.swap_cd = 0.0
	P.swap(false, c)
	P.swap_cd = 0.0


# ---------- input ----------
func _key(k: int) -> void:
	var R2 := roster()
	var i := R2.find(sel)
	if k == KEY_ESCAPE:
		back()
	elif focus < 0:
		if k in [KEY_LEFT, KEY_A]: pick(R2[maxi(0, i - 1)])
		elif k in [KEY_RIGHT, KEY_D]: pick(R2[mini(R2.size() - 1, i + 1)])
		elif k in [KEY_DOWN, KEY_S, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			focus = 0
			sfx("ready", 0.15)
	else:
		if k in [KEY_LEFT, KEY_A]: focus = maxi(0, focus - 1)
		elif k in [KEY_RIGHT, KEY_D]: focus = mini(2, focus + 1)
		elif k in [KEY_UP, KEY_W]: focus = -1
		elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_X]: press(bar()[focus][0])

## the bar and ✕ (drawn by the top layer) take a tap before the columns under them
func _input(ev: InputEvent) -> void:
	if live() and not menu.ui_root.sweep.active and not menu.ui_root.title.active and ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		focus = -1
		for i in range(top_hits.size() - 1, -1, -1):
			var h: Array = top_hits[i]
			if h[0].has_point(ev.position) if h[0] is Rect2 else Geometry2D.is_point_in_polygon(ev.position, h[0]):
				h[1].call()
				get_viewport().set_input_as_handled()
				return
	super(ev)


# ---------- layout ----------
## .pcols: left 4 %, right 4 %, top 15 %, bottom 6 %, gap 12; each .pcol flex 1 (2.6 when on, .55s --ez)
func layout(vs: Vector2) -> Dictionary:
	var R2 := roster()
	var L := {}
	var x0 := vs.x * 0.04
	var aw := vs.x * 0.92 - 12.0 * (R2.size() - 1)
	var y0 := vs.y * 0.15
	var h := vs.y * 0.79
	var fl := []
	var sum := 0.0
	for c in R2:
		var f: float = tr.get_v("flex_" + c, 2.6 if c == sel else 1.0, 550.0, "ez")
		fl.append(f)
		sum += f
	var x := x0
	for i in R2.size():
		var c: String = R2[i]
		var w: float = aw * fl[i] / sum
		var r := Rect2(x, y0, w, h)
		L[c] = {"r": r, "poly": UI.clip(r, [[14, 0], [100, 0], [86, 100], [0, 100]]), "i": i}
		x += w + 12.0
	return L

func _paint(vs: Vector2) -> void:
	var col := UI.col(sel)
	# #pt2 { background: var(--col) }, .burst at the centre (80 s a turn), .dots drifting (w_dotf 6 s)
	draw_rect(Rect2(Vector2.ZERO, vs), col)
	UI.burst(self, vs * 0.5, maxf(vs.x, vs.y) * 1.6, 0.14, t / 80000.0 * TAU)
	var dsc := fmod(t / 6000.0, 1.0)
	# background-position → (-44px, 22px): the grid drifts left and down; no mask, even all over
	draw_texture_rect_region(UI.dot_tile(0.26), Rect2(Vector2.ZERO, vs), Rect2(Vector2(44.0 * dsc, -22.0 * dsc), vs))
	for c in _L:
		var cc: String = c
		hit(_L[c]["poly"], func(): focus = -1; pick(cc))

## one .pcol: black slab, the art (150 % tall, from 4 %), the hollow number, LEADER, the name tag; all under its filter
func _draw_col(ci: Control, slot: int) -> void:
	var R2 := roster()
	if slot >= R2.size() or _L.is_empty(): return
	var c: String = R2[slot]
	if not _L.has(c): return
	var P = arena.player
	var on := c == sel
	var inP: bool = P.party.has(c)
	var lead: bool = c == P.who
	var r: Rect2 = _L[c]["r"]
	var poly: PackedVector2Array = _L[c]["poly"]
	var cc := UI.col(c)
	# filter: none when on, brightness(.55) grayscale(.5), out of the party (.4 / .8); .3s
	var fb: float = tr.get_v("br_" + c, 1.0 if on else (0.55 if inP else 0.4), 300.0, "ease")
	var fg: float = tr.get_v("gs_" + c, 0.0 if on else (0.5 if inP else 0.8), 300.0, "ease")
	ci.material.set_shader_parameter("br", fb)
	ci.material.set_shader_parameter("gs", fg)
	ci.draw_colored_polygon(poly, Color.BLACK)
	# img: left 50 %, top 4 %, height 150 %, translateX(-50 %) → on: translateX(-46 %) scale(1.04); .55s --ez
	var st: Texture2D = tx(ST[c])
	var ih := r.size.y * 1.5
	var iw := ih * st.get_width() / st.get_height()
	var k: float = tr.get_v("img_" + c, 1.0 if on else 0.0, 550.0, "ez")
	var tx0 := -0.5 + 0.04 * k
	var sc := 1.0 + 0.04 * k
	var ir := Rect2(r.position.x + r.size.x / 2.0 + tx0 * iw, r.position.y + r.size.y * 0.04, iw, ih)
	var ctr := ir.get_center()
	ir = Rect2(ctr - ir.size * sc / 2.0, ir.size * sc)
	var clipped := Geometry2D.intersect_polygons(poly, PackedVector2Array([ir.position, Vector2(ir.end.x, ir.position.y), ir.end, Vector2(ir.position.x, ir.end.y)]))
	for pg in clipped:
		var uv := PackedVector2Array()
		for p in pg: uv.append((p - ir.position) / ir.size)
		ci.draw_colored_polygon(pg, Color.WHITE, uv, st)
	# .no (the hollow number) is drawn by the top layer: outline glyphs don't survive the filter shader
	# .lead: left 24 %, top 6 %, white, BHS 14, rotate(-8deg); shown on the one in control
	var bf := UI.bhs()
	var nf := UI.noto()
	if lead:
		var lw := UI.text_w(bf, "LEADER", 14) + 16.0
		var lhh := 14.0 * 1.25 + 2.0
		var lp := Vector2(r.position.x + r.size.x * 0.24, r.position.y + r.size.y * 0.06)
		ci.draw_set_transform_matrix(Transform2D(deg_to_rad(-8.0), lp + Vector2(lw, lhh) / 2.0) * Transform2D(0.0, -Vector2(lw, lhh) / 2.0))
		ci.draw_rect(Rect2(0, 0, lw, lhh), Color.WHITE)
		ci.draw_string(bf, Vector2(8, 1 + (lhh - 2.0 - (bf.get_ascent(14) + bf.get_descent(14))) / 2.0 + bf.get_ascent(14)), "LEADER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		ci.draw_set_transform(Vector2.ZERO)
	# .tag: left 12 %, bottom 8 %, rotate(-8deg) about its bottom-left; b (name), span (role, wraps under a narrow
	# column), em (state)
	var name_s: String = CH.NAME[c]
	var role: String = SHEET[c][1]
	var state := "조작 중" if lead else ("파티" if inP else "마을에 있음")
	var bw := UI.text_w(bf, name_s, 28) + 20.0
	var bh := 28.0 * 1.05 + 4.0
	var sw := UI.text_w(nf, role, 11) + 16.0
	var sh := 11.0 * 1.45 + 2.0
	var avail := r.size.x * 0.88
	var wrap := bw + sw > avail
	# baselines: b's text and span's text share one when on a line
	var b_base := 1.0 + (28.0 * 1.05 - (bf.get_ascent(28) + bf.get_descent(28))) / 2.0 + bf.get_ascent(28)
	var s_base := 1.0 + (11.0 * 1.45 - (nf.get_ascent(11) + nf.get_descent(11))) / 2.0 + nf.get_ascent(11)
	var b_y := 0.0
	var s_pos := Vector2.ZERO
	var line1 := 0.0
	if wrap:
		s_pos = Vector2(0, bh + 4.0)
		line1 = bh + 4.0 + sh
	else:
		var base := maxf(b_base, 4.0 + s_base)
		b_y = base - b_base
		s_pos = Vector2(bw, base - s_base)
		line1 = maxf(b_y + bh, s_pos.y + sh)
	var eh := 10.5 * 1.45
	var th := line1 + 3.0 + eh
	var o := Vector2(r.position.x + r.size.x * 0.12, r.end.y - r.size.y * 0.08)
	var m := Transform2D(deg_to_rad(-8.0), o) * Transform2D(0.0, Vector2(0, -th))
	ci.draw_set_transform_matrix(m * _skew(Vector2(bw / 2.0, b_y + bh / 2.0), -12.0))
	ci.draw_rect(Rect2(0, b_y, bw, bh), Color.BLACK)
	ci.draw_string(bf, Vector2(8, b_y + b_base), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	ci.draw_set_transform_matrix(m * _skew(s_pos + Vector2(sw, sh) / 2.0, -10.0))
	ci.draw_rect(Rect2(s_pos, Vector2(sw, sh)), cc)
	ci.draw_string(nf, s_pos + Vector2(8, s_base), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
	ci.draw_set_transform_matrix(m)
	var ep := Vector2(0, line1 + 3.0 + (eh - (nf.get_ascent(10) + nf.get_descent(10))) / 2.0 + nf.get_ascent(10))
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1)]:
		ci.draw_string(nf, ep + d, state, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.45))
	ci.draw_string(nf, ep, state, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO)

## .no: right 16 %, top 4 %, Anton 54 / 1, hollow (a 2 px stroke in --c), under its column's filter
func _draw_no(ci: CanvasItem, c: String, slot: int) -> void:
	var r: Rect2 = _L[c]["r"]
	var on := c == sel
	var inP: bool = arena.player.party.has(c)
	var fb: float = tr.get_v("br_" + c, 1.0 if on else (0.55 if inP else 0.4), 300.0, "ease")
	var fg: float = tr.get_v("gs_" + c, 0.0 if on else (0.5 if inP else 0.8), 300.0, "ease")
	var cc := UI.col(c)
	var l := cc.r * 0.2126 + cc.g * 0.7152 + cc.b * 0.0722
	cc = Color(lerpf(cc.r, l, fg) * fb, lerpf(cc.g, l, fg) * fb, lerpf(cc.b, l, fg) * fb)
	var af := UI.anton()
	var ns := "0%d" % (slot + 1)
	var nw := UI.text_w(af, ns, 54)
	var asc := af.get_ascent(54)
	var pad := (54.0 - (asc + af.get_descent(54))) / 2.0
	ci.draw_string_outline(af, Vector2(r.end.x - r.size.x * 0.16 - nw, r.position.y + r.size.y * 0.04 + pad + asc), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 4, cc)

## CSS skewX(deg) about a point
static func _skew(pivot: Vector2, deg: float) -> Transform2D:
	var m := Transform2D(Vector2(1, 0), Vector2(tan(deg_to_rad(deg)), 1), pivot)
	return m * Transform2D(0.0, -pivot)

## over the columns: the title, n / 3, the bar, ✕
func _draw_top() -> void:
	top_hits.clear()
	if not live(): return
	var vs := get_viewport_rect().size
	var ci := top
	var col := UI.col(sel)
	var P = arena.player
	var R2 := roster()
	for i in R2.size():
		if _L.has(R2[i]): _draw_no(ci, R2[i], i)
	# .ttl: left 20, top 14, rotate(-6deg) about its corner; small PARTY (Anton 11, .3em, black .7) over the black plate
	var tfs := 32 if vs.y <= 420.0 else 34
	ci.draw_set_transform(Vector2(20, 14), deg_to_rad(-6.0))
	ci.draw_string(UI.anton(false, 3), Vector2(0, 11), "PARTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	var tw := UI.text_w(UI.bhs(), "파티", tfs)
	UI.para(ci, 0, 15, tw + 24.0, tfs + 4.0, 8.0, Color.BLACK)
	ci.draw_string(UI.bhs(), Vector2(12, 15 + tfs + 2.0 - tfs * 0.12), "파티", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO)
	# .pcount: left 150, top 22, Anton 16 on black, skewX(-10deg)
	var cs := "%d / 3" % P.party.size()
	var af := UI.anton()
	var cw := UI.text_w(af, cs, 16) + 24.0
	var chh := 23.0
	ci.draw_set_transform_matrix(_skew(Vector2(150 + cw / 2.0, 22 + chh / 2.0), -10.0))
	ci.draw_rect(Rect2(150, 22, cw, chh), Color.BLACK)
	ci.draw_string(af, Vector2(162, 22 + 2.0 + (chh - 4.0 - (af.get_ascent(16) + af.get_descent(16))) / 2.0 + af.get_ascent(16)), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO)
	# .pbar: right 16, bottom 10, gap 8; black, white 2 px rim, BHS 16, skewX(-12deg), 4 px colour drop; disabled .35
	var B := bar()
	var bf := UI.bhs()
	var bh := 16.0 * 1.25 + 14.0
	var x := vs.x - 16.0
	var rects := []
	for j in range(B.size() - 1, -1, -1):
		var w := UI.text_w(bf, B[j][1], 16) + 36.0
		x -= w
		rects.push_front(Rect2(x, vs.y - 10.0 - bh, w, bh))
		x -= 8.0
	for j in B.size():
		var br: Rect2 = rects[j]
		var en: bool = B[j][2]
		var a := 1.0 if en else 0.35
		var fo := focus == j
		ci.draw_set_transform_matrix(_skew(br.get_center(), -12.0))
		ci.draw_rect(Rect2(br.position + Vector2(4, 4), br.size), Color(col, a))
		ci.draw_rect(br, Color(1, 1, 1, a))
		ci.draw_rect(br.grow(-2.0), Color(1, 1, 1, a) if fo else Color(0, 0, 0, a))
		var lw := UI.text_w(bf, B[j][1], 16)
		ci.draw_string(bf, Vector2(br.get_center().x - lw / 2.0, br.position.y + 2.0 + 5.0 + (20.0 - (bf.get_ascent(16) + bf.get_descent(16))) / 2.0 + bf.get_ascent(16)), B[j][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, a) if fo else Color(1, 1, 1, a))
		ci.draw_set_transform(Vector2.ZERO)
		var act: String = B[j][0]
		top_hits.append([PackedVector2Array([br.position + Vector2(br.size.y * 0.2126 / 2.0, 0), Vector2(br.end.x + br.size.y * 0.2126 / 2.0, br.position.y), br.end - Vector2(br.size.y * 0.2126 / 2.0, 0), Vector2(br.position.x - br.size.y * 0.2126 / 2.0, br.end.y)]), func(): press(act)])
	# ✕
	var c := Vector2(vs.x - 14.0 - 18.0, 14.0 + 18.0)
	ci.draw_circle(c + Vector2(3, 3), 18.0, col)
	ci.draw_circle(c, 18.0, Color.BLACK)
	ci.draw_arc(c, 17.0, 0, TAU, 32, Color.WHITE, 2.0, true)
	UI.cross(ci, c, 5.0, Color.WHITE, 2.0)
	top_hits.append([Rect2(c - Vector2(22, 22), Vector2(44, 44)), back])
