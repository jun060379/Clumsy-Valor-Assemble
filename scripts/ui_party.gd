extends "res://scripts/ui_page.gd"
## 편성 (owner 2026-11-04): three slots, filled from a desk of personnel files.
##   slots  three slanted slabs 01–03 = player.party in order (empty slots trail). A filled slab shows the member's
##          standing art, LEADER on the one in control, name / class / state at the foot; an empty one a dashed frame
##          and "서류 넣기". Tapping a slot picks it (an empty one goes straight to the desk; tapping the picked one
##          again opens the desk too); the bar acts on the pick: 교체 (→ the desk), 리더로, 빼기, 정보.
##   desk   a wooden desk under a lamp: the mission order on the left (the three slots, the one being filled circled in
##          red pencil), every recruited member's file on the right (a manila folder: name tab, clipped photo, class
##          line, an ink stamp on whoever is already sent). Tap a file to lift it, tap it again (or 배정) to send it: it
##          flies onto the order, 배정 is stamped, back to the slots. 비우기 empties the slot, 돌아가기 goes back.
##          A member already in another slot trades places; a member left out takes the slot (the one there steps out;
##          if that was the leader, the newcomer takes control).
## Opened from the hub's 파티, the top bar's 파티, the fountain, the hall's living room and the dungeon select's faces.
## Keys: slots ←→ pick, Enter the desk, ↓ the bar (←→ along it, Enter, ↑ back); desk ←→↑↓ files, Enter lift / send,
## Delete 비우기, Esc back to the slots. Esc on the slots closes the page.

const UIA := preload("res://scripts/ui_anim.gd")
const SHEET := preload("res://scripts/ui_char.gd").SHEET
const SK := preload("res://scripts/skins.gd")       # member art through the worn costume

const WOOD := Color("#5b3a22")
const WOOD_D := Color("#3e2615")
const MANILA := Color("#e0c07e")
const MANILA_D := Color("#c49f5c")
const PAPER := Color("#f3ecdb")
const INK := Color("#2a2420")
const RED_INK := Color("#b8322a")
const PENCIL := Color("#c8392f")

var mode := "slots"              # slots / desk
var slot := 0                    # the slot picked (0..2)
var focus := -1                  # slots: -1 = the slabs, 0.. = a bar button
var dsel := ""                   # desk: the file lifted
var fly := {}                    # desk: the file flying onto the order {c, from, t}
var stamp_t := -1.0              # desk: the 배정 stamp (ms since)
var tr := UIA.Tr.new()
var _L: Array = []               # slots: [{r, poly}] ×3
var _F := {}                     # desk: c -> {p, a, s, poly}
var _rows: Array = []            # desk: the order's three row rects


func _ready() -> void:
	super()
	keys = ["party"]
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED      # the halftone ground tiles
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _opened() -> void:
	mode = "slots"
	var P = arena.player
	slot = maxi(0, P.party.find(P.who))
	focus = -1
	dsel = ""
	fly = {}
	stamp_t = -1.0
	tr.clear()

## ROSTER: the recruited members (player.roster: fame.rec plus whoever is in control)
func roster() -> Array:
	return arena.player.roster()

func party() -> Array:
	return arena.player.party

## who sits in slot i ("" = empty)
func at(i: int) -> String:
	var pa := party()
	return pa[i] if i < pa.size() else ""

func _tick(dt: float) -> void:
	tr.step(dt)
	if not fly.is_empty():
		fly["t"] += dt
		if fly["t"] >= 380.0 and stamp_t < 0.0:
			stamp_t = 0.0
			sfx("slam", 0.5)
	if stamp_t >= 0.0:
		stamp_t += dt
		if stamp_t > 650.0:
			stamp_t = -1.0
			fly = {}
			dsel = ""
			mode = "slots"
			tr.snap("in_desk")


# ---------- actions ----------
func pick(i: int) -> void:
	if i == slot and mode == "slots":
		open_desk()
		return
	slot = clampi(i, 0, 2)
	sfx("ui_move", 0.5)
	if at(slot) == "": open_desk()

func open_desk() -> void:
	if not fly.is_empty(): return
	# an empty slot past the first gap fills the first gap (empty slots trail)
	slot = mini(slot, party().size())
	slot = mini(slot, 2)
	mode = "desk"
	dsel = at(slot)
	focus = -1
	sfx("ui_ok", 0.45)

func close_desk() -> void:
	if not fly.is_empty(): return
	mode = "slots"
	dsel = ""
	sfx("ui_move", 0.45)

## the bar under the slots: [[act, label, enabled]...]
func bar() -> Array:
	var c := at(slot)
	if c == "": return [["swap", "서류 넣기", true]]
	var P = arena.player
	return [["swap", "교체", true], ["lead", "리더로", c != P.who], ["out", "빼기", party().size() > 1 and c != P.who], ["info", "정보", true]]

func press(a: String) -> void:
	for b in bar():
		if b[0] == a and not b[2]: return
	var c := at(slot)
	match a:
		"swap": open_desk()
		"lead":
			_swap(c)
			arena.save_now()
			sfx("ui_ok", 0.5)
		"out": empty_slot(slot)
		"info":
			menu.ui_root.sweep.run(func():
				menu.ext["char"].want_c = c
				menu._open_page("char", false), UI.col(c))

## partySwap(false, c); swapCd = 0
func _swap(c: String) -> void:
	var P = arena.player
	if P.who == c: return
	P.swap_cd = 0.0
	P.swap(false, c)
	P.swap_cd = 0.0

## member c into slot i (see the header for trades and replacements); the party order follows the slots
func assign(i: int, c: String) -> void:
	var P = arena.player
	var pa: Array = P.party.duplicate()
	i = mini(i, pa.size())
	if pa.has(c):
		var j := pa.find(c)
		if i >= pa.size() or j == i: return
		pa[j] = pa[i]
		pa[i] = c
		P.party = pa
	else:
		var old := at(i)
		arena.toggle_member(c)                      # joins (the townsfolk let go of him / her)
		if not P.party.has(c): return
		if old != "":
			if old == P.who: _swap(c)
			arena.toggle_member(old)
		var nw: Array = P.party.duplicate()
		nw.erase(c)
		nw.insert(mini(i, nw.size()), c)
		P.party = nw
	arena.save_now()

## slot i out (never the last member, never the one in control — 교체 swaps the leader out)
func empty_slot(i: int) -> void:
	var c := at(i)
	if c == "" or party().size() <= 1 or c == arena.player.who: return
	arena.toggle_member(c)
	arena.save_now()
	slot = mini(slot, party().size() - 1)
	sfx("ui_ok", 0.5)

## desk: a file tapped — lift it, or send the lifted one
func file_tap(c: String) -> void:
	if not fly.is_empty(): return
	if dsel != c:
		dsel = c
		sfx("ui_move", 0.5)
		return
	send()

func send() -> void:
	if dsel == "" or not fly.is_empty(): return
	var c := dsel
	var from: Vector2 = _F[c]["p"] if _F.has(c) else get_viewport_rect().size * 0.7
	if at(slot) != c: assign(slot, c)
	slot = maxi(0, party().find(c))
	fly = {"c": c, "from": from, "t": 0.0}
	sfx("ui_ok", 0.55)


# ---------- input ----------
func _key(k: int) -> void:
	if mode == "desk":
		if k in [KEY_ESCAPE, KEY_BACKSPACE]: close_desk()
		elif k == KEY_DELETE:
			empty_slot(slot)
			close_desk()
		elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_X]:
			if dsel == "": dsel = roster()[0]
			else: send()
		else:
			var R2 := roster()
			var g := _grid(R2.size())
			var i := maxi(0, R2.find(dsel))
			if k in [KEY_LEFT, KEY_A]: i -= 1
			elif k in [KEY_RIGHT, KEY_D]: i += 1
			elif k in [KEY_UP, KEY_W]: i -= g.x
			elif k in [KEY_DOWN, KEY_S]: i += g.x
			else: return
			dsel = R2[clampi(i, 0, R2.size() - 1)]
			sfx("ui_move", 0.4)
		return
	if k == KEY_ESCAPE:
		back()
	elif focus < 0:
		if k in [KEY_LEFT, KEY_A]:
			slot = maxi(0, slot - 1)
			sfx("ui_move", 0.5)
		elif k in [KEY_RIGHT, KEY_D]:
			slot = mini(2, slot + 1)
			sfx("ui_move", 0.5)
		elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_X]: open_desk()
		elif k in [KEY_DOWN, KEY_S]:
			focus = 0
			sfx("ui_move", 0.5)
	else:
		var B := bar()
		if k in [KEY_LEFT, KEY_A]: focus = maxi(0, focus - 1)
		elif k in [KEY_RIGHT, KEY_D]: focus = mini(B.size() - 1, focus + 1)
		elif k in [KEY_UP, KEY_W]: focus = -1
		elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_X]: press(B[mini(focus, B.size() - 1)][0])


# ---------- drawing ----------
func _paint(vs: Vector2) -> void:
	var k: float = tr.get_v("in_desk", 1.0 if mode == "desk" else 0.0, 420.0, "ez")
	if k < 1.0: _paint_slots(vs, k)
	if k > 0.0: _paint_desk(vs, k)

# ---- the slots ----
func _slot_layout(vs: Vector2) -> Array:
	var L: Array = []
	var x0 := vs.x * 0.04
	var gap := 14.0
	var aw := vs.x * 0.92 - gap * 2.0
	var y0 := vs.y * 0.15
	var h := vs.y * 0.70
	var fl: Array = []
	var sum := 0.0
	for i in 3:
		var f: float = tr.get_v("flex_%d" % i, 1.5 if i == slot else 1.0, 450.0, "ez")
		fl.append(f)
		sum += f
	var x := x0
	for i in 3:
		var w: float = aw * fl[i] / sum
		var r := Rect2(x, y0, w, h)
		L.append({"r": r, "poly": UI.clip(r, [[12, 0], [100, 0], [88, 100], [0, 100]])})
		x += w + gap
	return L

func _paint_slots(vs: Vector2, k: float) -> void:
	var c0 := at(slot)
	var col: Color = UI.col(c0) if c0 != "" else Color("#6b6f78")
	var a := 1.0 - k
	draw_set_transform(Vector2(-vs.x * 0.25 * k, 0))
	draw_rect(Rect2(Vector2(-vs.x, 0), vs * Vector2(3, 1)), col)
	UI.burst(self, vs * 0.5, maxf(vs.x, vs.y) * 1.6, 0.14, t / 80000.0 * TAU)
	var dsc := fmod(t / 6000.0, 1.0)
	draw_texture_rect_region(UI.dot_tile(0.26), Rect2(Vector2.ZERO, vs), Rect2(Vector2(44.0 * dsc, -22.0 * dsc), vs))
	_L = _slot_layout(vs)
	var P = arena.player
	for i in 3:
		var c := at(i)
		var r: Rect2 = _L[i]["r"]
		var poly: PackedVector2Array = _L[i]["poly"]
		var on := i == slot
		var ii := i
		if k <= 0.0: hit(poly, func(): focus = -1; pick(ii))
		if c == "":
			_empty_slab(r, poly, on)
		else:
			_slab(r, poly, c, on, c == P.who)
		# the hollow number
		var af := UI.anton()
		var ns := "0%d" % (i + 1)
		var nw := UI.text_w(af, ns, 50)
		var ncol: Color = (UI.col(c) if c != "" else Color(1, 1, 1, 0.5)) if on else Color(1, 1, 1, 0.35)
		draw_string_outline(af, Vector2(r.end.x - r.size.x * 0.16 - nw, r.position.y + 6.0 + af.get_ascent(50)), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, 4, ncol)
	# the title, n / 3, the bar, ✕
	draw_set_transform(Vector2(20, 14) + Vector2(-vs.x * 0.25 * k, 0), deg_to_rad(-6.0))
	draw_string(UI.anton(false, 3), Vector2(0, 11), "FORMATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	var tfs := 32 if vs.y <= 420.0 else 34
	var tw := UI.text_w(UI.bhs(), "편성", tfs)
	UI.para(self, 0, 15, tw + 24.0, tfs + 4.0, 8.0, Color.BLACK)
	draw_string(UI.bhs(), Vector2(12, 15 + tfs + 2.0 - tfs * 0.12), "편성", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color.WHITE)
	draw_set_transform(Vector2(-vs.x * 0.25 * k, 0))
	var cs := "%d / 3" % party().size()
	var af2 := UI.anton()
	var cw := UI.text_w(af2, cs, 16) + 24.0
	UI.para(self, 130, 22, cw, 23, 4.0, Color.BLACK)
	draw_string(af2, Vector2(142, 22 + 2.0 + (19.0 - (af2.get_ascent(16) + af2.get_descent(16))) / 2.0 + af2.get_ascent(16)), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	draw_string(UI.noto(), Vector2(vs.x * 0.04, vs.y * 0.15 + vs.y * 0.70 + 22.0), "칸을 눌러 서류를 넣거나 바꾼다", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.6))
	_bar(vs, col, k <= 0.0)
	var cc := Vector2(vs.x - 14.0 - 18.0, 14.0 + 18.0)
	draw_circle(cc + Vector2(3, 3), 18.0, col.darkened(0.3))
	draw_circle(cc, 18.0, Color.BLACK)
	draw_arc(cc, 17.0, 0, TAU, 32, Color.WHITE, 2.0, true)
	UI.cross(self, cc, 5.0, Color.WHITE, 2.0)
	if k <= 0.0: hit(Rect2(cc - Vector2(22, 22), Vector2(44, 44)), back)
	draw_set_transform(Vector2.ZERO)
	if a < 1.0: draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, (1.0 - a) * 0.6))

func _slab(r: Rect2, poly: PackedVector2Array, c: String, on: bool, lead: bool) -> void:
	draw_colored_polygon(poly, Color.BLACK)
	var st: Texture2D = tx(SK.path(c, "st_base"))
	var ih := r.size.y * 1.45
	var iw := ih * st.get_width() / st.get_height()
	var kk: float = tr.get_v("img_" + c, 1.0 if on else 0.0, 450.0, "ez")
	var ir := Rect2(r.position.x + r.size.x / 2.0 - iw * (0.5 - 0.03 * kk), r.position.y + r.size.y * 0.04, iw, ih)
	var dim := lerpf(0.55, 1.0, kk)
	var clipped := Geometry2D.intersect_polygons(poly, PackedVector2Array([ir.position, Vector2(ir.end.x, ir.position.y), ir.end, Vector2(ir.position.x, ir.end.y)]))
	for pg in clipped:
		var uv := PackedVector2Array()
		for p in pg: uv.append((p - ir.position) / ir.size)
		draw_colored_polygon(pg, Color(dim, dim, dim), uv, st)
	if on:
		draw_polyline(poly + PackedVector2Array([poly[0]]), UI.col(c), 4.0)
	var bf := UI.bhs()
	var nf := UI.noto()
	if lead:
		var lw := UI.text_w(bf, "LEADER", 14) + 16.0
		var lp := Vector2(r.position.x + r.size.x * 0.2, r.position.y + r.size.y * 0.06)
		draw_set_transform(lp, deg_to_rad(-8.0))
		draw_rect(Rect2(0, 0, lw, 20), Color.WHITE)
		draw_string(bf, Vector2(8, 16), "LEADER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		draw_set_transform(Vector2.ZERO)
	# the name tag
	var name_s: String = CH.NAME[c]
	var role: String = SHEET[c][1]
	var o := Vector2(r.position.x + r.size.x * 0.08, r.end.y - r.size.y * 0.1)
	draw_set_transform(o, deg_to_rad(-6.0))
	var fs := 26 if r.size.x > 200.0 else 20
	var bw := UI.text_w(bf, name_s, fs) + 18.0
	draw_rect(Rect2(0, -fs - 10.0, bw, fs + 8.0), Color.BLACK)
	draw_string(bf, Vector2(9, -8.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var rw := UI.text_w(nf, role, 10) + 12.0
	draw_rect(Rect2(0, 2, rw, 16), UI.col(c))
	draw_string(nf, Vector2(6, 14), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
	draw_set_transform(Vector2.ZERO)

func _empty_slab(r: Rect2, poly: PackedVector2Array, on: bool) -> void:
	draw_colored_polygon(poly, Color(0, 0, 0, 0.42 if on else 0.28))
	var inset := PackedVector2Array()
	var ctr := r.get_center()
	for p in poly: inset.append(ctr + (p - ctr) * 0.92)
	inset.append(inset[0])
	for j in 4:
		draw_dashed_line(inset[j], inset[j + 1], Color(1, 1, 1, 0.75 if on else 0.4), 2.0, 10.0)
	var pl := 1.0 + 0.06 * sin(t / 300.0) if on else 1.0
	var c := ctr + Vector2(0, -14)
	draw_rect(Rect2(c - Vector2(16, 3) * pl, Vector2(32, 6) * pl), Color(1, 1, 1, 0.9 if on else 0.5))
	draw_rect(Rect2(c - Vector2(3, 16) * pl, Vector2(6, 32) * pl), Color(1, 1, 1, 0.9 if on else 0.5))
	var s := "서류 넣기"
	var nf := UI.bhs()
	draw_string(nf, Vector2(ctr.x - UI.text_w(nf, s, 16) / 2.0, ctr.y + 30.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9 if on else 0.5))
	draw_string(UI.noto(), Vector2(ctr.x - UI.text_w(UI.noto(), "비어 있음", 11) / 2.0, ctr.y + 48.0), "비어 있음", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))

func _bar(vs: Vector2, col: Color, live_: bool) -> void:
	var B := bar()
	var bf := UI.bhs()
	var bh := 34.0
	var x := vs.x - 16.0
	var rects: Array = []
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
		UI.para(self, br.position.x + 4, br.position.y + 4, br.size.x, br.size.y, 6.0, Color(col.darkened(0.25), a))
		UI.para(self, br.position.x, br.position.y, br.size.x, br.size.y, 6.0, Color(1, 1, 1, a))
		UI.para(self, br.position.x + 2, br.position.y + 2, br.size.x - 4, br.size.y - 4, 6.0, Color(1, 1, 1, a) if fo else Color(0, 0, 0, a))
		var lw := UI.text_w(bf, B[j][1], 16)
		draw_string(bf, Vector2(br.get_center().x - lw / 2.0 + 3.0, br.position.y + 23.0), B[j][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, a) if fo else Color(1, 1, 1, a))
		var act: String = B[j][0]
		if live_: hit(br, func(): focus = -1; press(act))

# ---- the desk ----
## files per row / rows for n files
func _grid(n: int) -> Vector2i:
	var cols := 2 if n <= 4 else (3 if n <= 9 else 4)
	return Vector2i(cols, maxi(1, ceili(float(n) / cols)))

func _paint_desk(vs: Vector2, k: float) -> void:
	var off := Vector2(vs.x * (1.0 - k) * 0.6, 0)
	draw_set_transform(off)
	_wood(vs)
	var live_ := k >= 1.0 and fly.is_empty()
	_order(vs, live_)
	_files(vs, live_)
	draw_set_transform(off)
	# 돌아가기 · 비우기 as slips of paper on the desk
	var y := vs.y - 46.0
	var bx := 18.0
	bx += _slip(Vector2(bx, y), "돌아가기", PAPER, INK, live_, close_desk) + 10.0
	if at(slot) != "" and party().size() > 1 and at(slot) != arena.player.who:
		_slip(Vector2(bx, y), "비우기", Color("#e9d6d0"), RED_INK, live_, func(): empty_slot(slot); close_desk())
	draw_set_transform(Vector2.ZERO)
	if k < 1.0: draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, (1.0 - k) * 0.5))

func _wood(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2(-vs.x, 0), vs * Vector2(3, 1)), WOOD)
	# planks and grain
	var ph := vs.y / 3.0
	for p in 3:
		var y0 := p * ph
		var tint := 0.04 * float((p * 7) % 3 - 1)
		draw_rect(Rect2(-vs.x, y0, vs.x * 3.0, ph), Color(tint + 0.5, tint + 0.5, tint + 0.5, 0.06) if tint > 0.0 else Color(0, 0, 0, absf(tint) * 1.5))
		for g in 9:
			var gy := y0 + 8.0 + g * ph / 9.0
			var pts := PackedVector2Array()
			for s in 25:
				var x := s * vs.x / 24.0
				pts.append(Vector2(x, gy + sin(x / (60.0 + g * 9.0) + p * 2.0 + g) * (2.0 + g % 3) + sin(x / 23.0 + g) * 0.8))
			draw_polyline(pts, Color(WOOD_D, 0.35 if g % 3 == 0 else 0.18), 1.0 + float(g % 2))
		draw_line(Vector2(-vs.x, y0), Vector2(vs.x * 2.0, y0), Color(0, 0, 0, 0.45), 2.0)
		draw_line(Vector2(-vs.x, y0 + 2.0), Vector2(vs.x * 2.0, y0 + 2.0), Color(1, 0.85, 0.6, 0.06), 1.0)
	# the lamp: a warm pool top-left, the corners dark
	draw_texture_rect(UI.glow(), Rect2(Vector2(-vs.x * 0.35, -vs.y * 0.75), Vector2(vs.x * 1.3, vs.x * 1.3)), false, Color(1.0, 0.82, 0.5, 0.35))
	var dk := Color(0, 0, 0, 0.55)
	var cl := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2(0, vs.y * 0.7), Vector2(vs.x, vs.y * 0.7), vs, Vector2(0, vs.y)]), PackedColorArray([cl, cl, dk, dk]))
	draw_polygon(PackedVector2Array([Vector2(vs.x * 0.8, 0), Vector2(vs.x, 0), vs, Vector2(vs.x * 0.8, vs.y)]), PackedColorArray([cl, dk, dk, cl]))
	# the desk's title, burnt into a brass plate
	var bf := UI.bhs()
	var s := "인사 서류함"
	var w := UI.text_w(bf, s, 15) + 24.0
	var pr := Rect2(vs.x - w - 64.0, 16.0, w, 26.0)
	draw_rect(Rect2(pr.position + Vector2(2, 3), pr.size), Color(0, 0, 0, 0.4))
	draw_rect(pr, Color("#b8924a"))
	draw_rect(pr.grow(-2.0), Color("#d4ae62"))
	draw_string(bf, pr.position + Vector2(12, 19), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#4a3415"))

## the mission order (left): three numbered lines, the slot being filled circled
func _order(vs: Vector2, live_: bool) -> void:
	var w := minf(vs.x * 0.34, 320.0)
	var h := minf(vs.y * 0.80, w * 1.32)
	var r := Rect2(vs.x * 0.04, vs.y * 0.08, w, h)
	var piv := r.get_center()
	var m := Transform2D(deg_to_rad(-2.5), piv) * Transform2D(0.0, -piv)
	draw_set_transform_matrix(_cur_off() * m)
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, PAPER)
	# ruled lines, a red margin
	for i in int(h / 18.0):
		var ly := r.position.y + 70.0 + i * 18.0
		if ly > r.end.y - 10.0: break
		draw_line(Vector2(r.position.x + 8, ly), Vector2(r.end.x - 8, ly), Color(0.45, 0.6, 0.8, 0.18), 1.0)
	draw_line(Vector2(r.position.x + 30, r.position.y + 6), Vector2(r.position.x + 30, r.end.y - 6), Color(0.85, 0.3, 0.3, 0.3), 1.0)
	var sf: Font = UI.serif_b()
	var nf := UI.noto()
	draw_string(UI.anton(false, 2), Vector2(r.position.x + 38, r.position.y + 22), "DISPATCH ORDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(INK, 0.55))
	draw_string(sf, Vector2(r.position.x + 38, r.position.y + 48), "임무 파견 명령서", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
	draw_line(Vector2(r.position.x + 38, r.position.y + 56), Vector2(r.end.x - 14, r.position.y + 56), INK, 1.5)
	_rows.clear()
	var rh := minf(58.0, (h - 150.0) / 3.0)
	for i in 3:
		var y := r.position.y + 70.0 + i * (rh + 6.0)
		var rr := Rect2(r.position.x + 36, y, w - 50, rh)
		_rows.append(rr)
		var c := at(i)
		draw_string(UI.anton(), Vector2(rr.position.x, rr.position.y + rh * 0.62), "0%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(INK, 0.7))
		var hidden: bool = not fly.is_empty() and fly["c"] == c and fly["t"] < 380.0
		if c != "" and not hidden:
			var ph := rh - 8.0
			var fr := Rect2(rr.position.x + 34, rr.position.y + 4, ph, ph)
			draw_rect(fr.grow(2.0), Color.WHITE)
			draw_texture_rect(tx(SK.path(c, "face")), fr, false)
			draw_string(sf, Vector2(fr.end.x + 8, rr.position.y + rh * 0.48), CH.NAME[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
			draw_string(nf, Vector2(fr.end.x + 8, rr.position.y + rh * 0.48 + 16), SHEET[c][1], HORIZONTAL_ALIGNMENT_LEFT, rr.end.x - fr.end.x - 10, 9, Color(INK, 0.7))
			if c == arena.player.who:
				draw_string(UI.anton(), Vector2(rr.end.x - 40, rr.position.y + 14), "LEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RED_INK)
		elif c == "":
			draw_string(nf, Vector2(rr.position.x + 34, rr.position.y + rh * 0.6), "— 공석 —", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK, 0.4))
		if i == slot:
			# red pencil: a loose double loop round the line
			for lp in 2:
				var pts := PackedVector2Array()
				for s in 33:
					var a := float(s) / 32.0 * TAU * 1.05 + lp * 0.4
					var wob := 1.0 + 0.04 * sin(a * 3.0 + lp)
					pts.append(rr.get_center() + Vector2(cos(a) * rr.size.x * 0.54 * wob, sin(a) * rr.size.y * 0.62 * wob))
				draw_polyline(pts, Color(PENCIL, 0.75), 2.0 - lp * 0.6)
		var ii := i
		if live_: hit(_xf_rect(rr, m), func(): slot = mini(ii, party().size()); dsel = at(slot); sfx("ui_move", 0.4))
	# the instruction, the signature line
	var hint := "오른쪽에서 서류를 골라 0%d번 칸에 넣는다" % (slot + 1) if dsel == "" else "「%s」 서류를 한 번 더 누르면 배정" % CH.NAME[dsel]
	draw_string(nf, Vector2(r.position.x + 38, r.end.y - 52), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 10, Color(INK, 0.75))
	draw_line(Vector2(r.position.x + 38, r.end.y - 22), Vector2(r.end.x - 70, r.end.y - 22), Color(INK, 0.5), 1.0)
	draw_string(nf, Vector2(r.position.x + 38, r.end.y - 9), "길드 《어설픈 용맹》", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(INK, 0.55))
	# 배정 button: an ink stamp waiting at the corner
	if dsel != "" and fly.is_empty():
		var sr := Rect2(r.end.x - 66, r.end.y - 46, 56, 30)
		draw_rect(sr, Color(RED_INK, 0.9), false, 2.5)
		draw_string(UI.bhs(), sr.position + Vector2(10, 22), "배정", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, RED_INK)
		if live_: hit(_xf_rect(sr, m), send)
	# the stamp landing
	if stamp_t >= 0.0 and slot < _rows.size():
		var u := clampf(stamp_t / 120.0, 0.0, 1.0)
		var sc := lerpf(1.8, 1.0, UI.bk(u))
		var rr2: Rect2 = _rows[slot]
		var sp := Vector2(rr2.end.x - 44, rr2.get_center().y)
		draw_set_transform_matrix(_cur_off() * m * Transform2D(deg_to_rad(-12.0), sp) * Transform2D(0.0, Vector2.ZERO).scaled(Vector2(sc, sc)))
		var a := clampf(u * 2.0, 0.0, 1.0) * 0.85
		draw_rect(Rect2(-30, -15, 60, 30), Color(RED_INK, a), false, 3.0)
		draw_string(UI.bhs(), Vector2(-21, 8), "배정", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(RED_INK, a))
	draw_set_transform_matrix(_cur_off())

## the desk view's slide offset as a transform (every desk drawing sits on it)
func _cur_off() -> Transform2D:
	var k: float = tr.get_v("in_desk", 1.0 if mode == "desk" else 0.0, 420.0, "ez")
	return Transform2D(0.0, Vector2(get_viewport_rect().size.x * (1.0 - k) * 0.6, 0))

func _xf_rect(r: Rect2, m: Transform2D) -> PackedVector2Array:
	var o := _cur_off() * m
	return PackedVector2Array([o * r.position, o * Vector2(r.end.x, r.position.y), o * r.end, o * Vector2(r.position.x, r.end.y)])

## the files (right): manila folders in a loose grid
func _files(vs: Vector2, live_: bool) -> void:
	var R2 := roster()
	var g := _grid(R2.size())
	var area := Rect2(vs.x * 0.42, vs.y * 0.12, vs.x * 0.55, vs.y * 0.74)
	var cell := Vector2(area.size.x / g.x, area.size.y / g.y)
	var fw := minf(cell.x * 0.84, cell.y * 0.84 * 1.38)
	var fh := fw / 1.38
	_F.clear()
	var order: Array = []
	for i in R2.size():
		var c: String = R2[i]
		var cx := area.position.x + (i % g.x + 0.5) * cell.x
		var cy := area.position.y + (i / g.x + 0.5) * cell.y
		var hsh := float(absi(hash(c)) % 1000) / 1000.0
		var lift: float = tr.get_v("lift_" + c, 1.0 if dsel == c else 0.0, 260.0, "ez")
		var a := deg_to_rad(lerpf(-7.0 + 14.0 * hsh, 0.0, lift))
		var p := Vector2(cx + (hsh - 0.5) * cell.x * 0.08, cy + (fmod(hsh * 7.0, 1.0) - 0.5) * cell.y * 0.06 - 10.0 * lift)
		_F[c] = {"p": p, "a": a, "s": 1.0 + 0.08 * lift, "lift": lift}
		order.append(c)
	order.sort_custom(func(x, y): return _F[x]["lift"] < _F[y]["lift"])     # the lifted one on top
	for c in order:
		if not fly.is_empty() and fly["c"] == c: continue
		var F: Dictionary = _F[c]
		var poly := _folder(c, F["p"], F["a"], F["s"], fw, fh, F["lift"])
		var cc: String = c
		if live_: hit(poly, func(): file_tap(cc))
	# the one flying onto the order
	if not fly.is_empty() and fly["t"] < 380.0 and slot < _rows.size():
		var u := UI.bez(0.3, 0.0, 0.2, 1.0, clampf(fly["t"] / 380.0, 0.0, 1.0))
		var to: Vector2 = (_rows[slot] as Rect2).get_center()
		var p: Vector2 = (fly["from"] as Vector2).lerp(to, u) + Vector2(0, -60.0 * sin(u * PI))
		_folder(fly["c"], p, lerpf(0.0, -0.3, u), lerpf(1.08, 0.35, u), fw, fh, 1.0)

## one manila folder centred on p; returns its outline (for the tap)
func _folder(c: String, p: Vector2, a: float, s: float, fw: float, fh: float, lift: float) -> PackedVector2Array:
	var m := _cur_off() * Transform2D(a, p) * Transform2D().scaled(Vector2(s, s))
	draw_set_transform_matrix(m)
	var hw := fw / 2.0
	var hh := fh / 2.0
	var P = arena.player
	var slot_i: int = P.party.find(c)
	var tabw := fw * 0.42
	# shadow (longer when lifted)
	var so := Vector2(4, 6) + Vector2(6, 10) * lift
	draw_rect(Rect2(Vector2(-hw, -hh) + so, Vector2(fw, fh)), Color(0, 0, 0, 0.32 + 0.1 * lift))
	# back flap with the name tab
	draw_colored_polygon(PackedVector2Array([Vector2(-hw, -hh), Vector2(-hw + 8, -hh - 18), Vector2(-hw + tabw - 8, -hh - 18), Vector2(-hw + tabw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]), MANILA_D)
	var sf: Font = UI.serif_b()
	draw_string(sf, Vector2(-hw + 12, -hh - 4), CH.NAME[c], HORIZONTAL_ALIGNMENT_LEFT, tabw - 16, 13, INK)
	# the sheet peeking out
	draw_rect(Rect2(-hw + 10, -hh + 4, fw - 22, fh * 0.4), PAPER)
	for i in 3: draw_line(Vector2(-hw + 18, -hh + 12 + i * 6), Vector2(hw - 30 - i * 10, -hh + 12 + i * 6), Color(INK, 0.25), 1.0)
	# the front cover
	var top := -hh + fh * 0.16
	draw_rect(Rect2(-hw, top, fw, hh - top), MANILA)
	draw_line(Vector2(-hw, top), Vector2(hw, top), Color(MANILA_D.darkened(0.2), 0.8), 1.5)
	# the photo, clipped on
	var ph := fh * 0.52
	var pr := Rect2(-hw + 12, top + 10, ph * 0.86, ph)
	draw_rect(Rect2(pr.position + Vector2(2, 2), pr.size), Color(0, 0, 0, 0.2))
	draw_rect(pr, Color("#faf7f0"))
	var ir := pr.grow(-4.0)
	ir.size.y -= 6.0
	draw_texture_rect(tx(SK.path(c, "face")), ir, false)
	var clip_x := pr.position.x + pr.size.x * 0.5
	draw_rect(Rect2(clip_x - 4, pr.position.y - 8, 8, 18), Color(0.55, 0.57, 0.6), false, 2.0)
	# typed fields
	var nf := UI.noto()
	var tx0 := pr.end.x + 10
	var tw := hw - tx0 - 8
	draw_string(nf, Vector2(tx0, top + 20), "성명", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, 0.55))
	draw_string(sf, Vector2(tx0, top + 38), CH.NAME[c], HORIZONTAL_ALIGNMENT_LEFT, tw, 17, INK)
	draw_line(Vector2(tx0, top + 42), Vector2(hw - 8, top + 42), Color(INK, 0.3), 1.0)
	draw_string(nf, Vector2(tx0, top + 56), "분류", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, 0.55))
	var cls: String = SHEET[c][1]
	var parts := cls.split(" · ")
	var line1 := " · ".join(parts.slice(0, 2)) if parts.size() >= 2 else cls
	var line2 := " · ".join(parts.slice(2)) if parts.size() > 2 else ""
	draw_string(nf, Vector2(tx0, top + 70), line1, HORIZONTAL_ALIGNMENT_LEFT, tw, 10, INK)
	if line2 != "": draw_string(nf, Vector2(tx0, top + 83), line2, HORIZONTAL_ALIGNMENT_LEFT, tw, 10, INK)
	# a colour tab on the edge
	draw_rect(Rect2(hw - 6, top + 8, 6, 22), UI.col(c))
	# the ink stamp: sent already
	if slot_i >= 0:
		var stp := Vector2(hw - fw * 0.26, hh - fh * 0.2)
		draw_set_transform_matrix(m * Transform2D(deg_to_rad(-14.0), stp))
		var lab := "파견 0%d" % (slot_i + 1) + (" · 리더" if c == P.who else "")
		var lw := UI.text_w(UI.bhs(), lab, 12) + 14.0
		draw_rect(Rect2(-lw / 2.0, -11, lw, 22), Color(RED_INK, 0.8), false, 2.0)
		draw_string(UI.bhs(), Vector2(-lw / 2.0 + 7, 5), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(RED_INK, 0.85))
		draw_set_transform_matrix(m)
	if lift > 0.01:
		draw_rect(Rect2(-hw - 3, -hh - 21, fw + 6, fh + 24), Color(1, 0.92, 0.6, 0.7 * lift), false, 2.0)
	draw_set_transform_matrix(_cur_off())
	var out := PackedVector2Array()
	for q in [Vector2(-hw, -hh - 18), Vector2(hw, -hh - 18), Vector2(hw, hh), Vector2(-hw, hh)]:
		out.append(m * q)
	return out

## a paper slip button on the desk; returns its width
func _slip(p: Vector2, s: String, bg: Color, fg: Color, live_: bool, cb: Callable) -> float:
	var bf := UI.bhs()
	var w := UI.text_w(bf, s, 15) + 28.0
	var r := Rect2(p, Vector2(w, 32))
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, bg)
	draw_string(bf, r.position + Vector2(14, 22), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, fg)
	if live_: hit(_xf_rect(r, Transform2D.IDENTITY), cb)
	return w
