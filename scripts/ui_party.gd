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
## Motion (owner 2026-11-04: fun just to look at, the ground never still, every tap and hover answers):
##   the slots' ground turns, drifts and streams paper scraps, its colour easing to the pick; slabs deal in staggered with
##   an overshoot, breathe, lean toward the pointer, lift on hover, squash on a tap; the leader tag swings, the empty
##   frame's dashes march. The desk's lamp sways (the light pool and every shadow follow it), dust drifts in the beam;
##   the order slides in, the files are dealt one by one, lift and tilt under the pointer, the pencil circle draws
##   itself, the 배정 stamp twitches until pressed, the sent file arcs over spinning and the stamp lands with ink flecks.
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
var mode_t := 0.0                # ms since the slots came in
var desk_t := 0.0                # ms since the desk came in (left running while it slides away)
var pops := {}                   # key -> t of its last tap (the squash)
var hov := ""                    # what the pointer is over (for the hover tick)
var col_cur := Color("#ff4d9a")  # the slots' ground colour, easing to the pick
var circ_t := 0.0                # the pencil circle: ms since the slot it rings changed
var _circ_slot := -1


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
	mode_t = 0.0
	pops.clear()
	var c0 := at(slot)
	col_cur = UI.col(c0) if c0 != "" else Color("#6b6f78")

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
	mode_t += dt
	desk_t += dt
	circ_t += dt
	var c0 := at(slot)
	var want: Color = UI.col(c0) if c0 != "" else Color("#6b6f78")
	col_cur = col_cur.lerp(want, minf(1.0, dt / 160.0))
	if not fly.is_empty():
		fly["t"] += dt
		if fly["t"] >= 420.0 and stamp_t < 0.0:
			stamp_t = 0.0
			arena.sfx("ui%d" % (1 + randi() % 3), 0.7)
			arena.sfx("slam", 0.35)
	if stamp_t >= 0.0:
		stamp_t += dt
		if stamp_t > 720.0:
			stamp_t = -1.0
			fly = {}
			dsel = ""
			_set_mode("slots")
			pops["slab%d" % slot] = t


# ---------- actions ----------
func pick(i: int) -> void:
	if i == slot and mode == "slots":
		open_desk()
		return
	slot = clampi(i, 0, 2)
	pops["slab%d" % slot] = t
	arena.sfx("ui_move", 0.5, {"st": 2.0 * slot})
	if at(slot) == "": open_desk()

func open_desk() -> void:
	if not fly.is_empty(): return
	# an empty slot past the first gap fills the first gap (empty slots trail)
	slot = mini(slot, party().size())
	slot = mini(slot, 2)
	_set_mode("desk")
	dsel = at(slot)
	focus = -1
	sfx("ui_ok", 0.45)

func close_desk() -> void:
	if not fly.is_empty(): return
	_set_mode("slots")
	dsel = ""
	sfx("ui_back", 0.45)

func _set_mode(m: String) -> void:
	if mode == m: return
	mode = m
	if m == "desk": desk_t = 0.0
	else: mode_t = 0.0

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
	pops["file_" + c] = t
	if dsel != c:
		dsel = c
		arena.sfx("ui_move", 0.5, {"st": 4.0})
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
var _hov_now := ""
var dealt := {}

## a tap's squash: 1 at the tap, ringing down to 0 over ~0.5 s
func _pop(key: String) -> float:
	var d: float = t - float(pops.get(key, -1.0e9))
	if d > 520.0 or d < 0.0: return 0.0
	return exp(-d / 110.0) * cos(d / 38.0)

## an entrance with an overshoot: 0 → 1 after `delay` ms over `dur` (the slots' clock, or the desk's)
func _ent(delay: float, dur: float, desk := false) -> float:
	return UI.bk(clampf(((desk_t if desk else mode_t) - delay) / dur, 0.0, 1.0))

func _over(poly) -> bool:
	return poly.has_point(hover) if poly is Rect2 else Geometry2D.is_point_in_polygon(hover, poly)

func _hover(key: String, poly) -> bool:
	if _over(poly):
		_hov_now = key
		return true
	return false

static func _xp(m: Transform2D, poly: PackedVector2Array) -> PackedVector2Array:
	var o := PackedVector2Array()
	for p in poly: o.append(m * p)
	return o

static func _rp(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])

func _paint(vs: Vector2) -> void:
	_hov_now = ""
	var k: float = tr.get_v("in_desk", 1.0 if mode == "desk" else 0.0, 460.0, "ez")
	if k < 1.0: _paint_slots(vs, k)
	if k > 0.0: _paint_desk(vs, k)
	if _hov_now != hov:
		if _hov_now != "": arena.sfx("ui_move", 0.16, {"st": 7.0})
		hov = _hov_now

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
		var f: float = tr.get_v("flex_%d" % i, 1.5 if i == slot else 1.0, 450.0, "bk")
		fl.append(f)
		sum += f
	var x := x0
	for i in 3:
		var w: float = aw * fl[i] / sum
		var r := Rect2(x, y0, w, h)
		L.append({"r": r, "poly": UI.clip(r, [[12, 0], [100, 0], [88, 100], [0, 100]])})
		x += w + gap
	return L

func _ground(vs: Vector2) -> void:
	var col := col_cur
	draw_rect(Rect2(Vector2(-vs.x, -vs.y), vs * 3.0), col)
	UI.burst(self, vs * 0.5, maxf(vs.x, vs.y) * 1.6, 0.14, t / 24000.0 * TAU)
	UI.burst(self, vs * Vector2(0.15, 0.9), maxf(vs.x, vs.y) * 1.2, 0.05, -t / 15000.0 * TAU)
	# streaks running right to left
	for i in 7:
		var sp := 0.10 + 0.05 * float(i % 3)
		var x := vs.x + 200.0 - fmod(t * sp + i * 337.0, vs.x + 500.0)
		var y := fmod(i * 97.0 + 40.0, vs.y)
		var w := 120.0 + 60.0 * float(i % 4)
		UI.para(self, x, y, w, 3.0 + float(i % 2) * 3.0, -8.0, Color(1, 1, 1, 0.10))
	var dsc := fmod(t / 5000.0, 1.0)
	draw_texture_rect_region(UI.dot_tile(0.24), Rect2(Vector2.ZERO, vs), Rect2(Vector2(44.0 * dsc, -22.0 * dsc), vs))
	# paper scraps drifting up, turning
	for i in 16:
		var hs := float((i * 7919) % 1000) / 1000.0
		var spd := 0.018 + 0.02 * hs
		var y := vs.y + 30.0 - fmod(t * spd + hs * vs.y * 1.3, vs.y + 60.0)
		var x := fmod(hs * vs.x * 1.7 + i * 61.0, vs.x) + sin(t / 900.0 + i) * 18.0
		var a := t / (500.0 + 400.0 * hs) + i
		var sz := Vector2(10.0 + 8.0 * hs, 6.0 + 4.0 * hs) * Vector2(absf(cos(a)) * 0.7 + 0.3, 1.0)
		draw_set_transform(Vector2(x, y), a * 0.6)
		draw_rect(Rect2(-sz / 2.0, sz), Color(1, 1, 1, 0.22 + 0.2 * hs))
		draw_set_transform(Vector2.ZERO)

func _paint_slots(vs: Vector2, k: float) -> void:
	var off := Transform2D(0.0, Vector2(-vs.x * 0.3 * k, 0))
	draw_set_transform_matrix(off)
	_ground(vs)
	_L = _slot_layout(vs)
	var P = arena.player
	var live_ := k <= 0.0
	var pp := ((hover - vs / 2.0) / vs).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5)) if hover.x > -900.0 else Vector2.ZERO
	for i in 3:
		var c := at(i)
		var r: Rect2 = _L[i]["r"]
		var on := i == slot
		var e := _ent(60.0 + i * 80.0, 560.0)
		var hv: float = tr.get_v("hv%d" % i, 1.0 if (live_ and _over(_L[i]["poly"])) else 0.0, 180.0, "ez")
		var sq := 1.0 - 0.06 * _pop("slab%d" % i)
		var piv := Vector2(r.get_center().x, r.end.y)
		var dy := (1.0 - e) * vs.y * 0.7 + sin(t / 1500.0 + i * 1.7) * 3.0 - 7.0 * hv
		var rot := deg_to_rad((1.0 - e) * 9.0 + pp.x * 1.5 * hv)
		var scv := Vector2(1.0 + 0.015 * hv + (1.0 - sq) * 0.6, (1.0 + 0.015 * hv) * sq)
		var m := off * Transform2D(rot, piv + Vector2(0, dy)) * Transform2D().scaled(scv) * Transform2D(0.0, -piv)
		var poly: PackedVector2Array = _L[i]["poly"]
		var wpoly := _xp(m, poly)
		_L[i]["poly"] = wpoly
		_cur_m = m
		draw_set_transform_matrix(m)
		# the drop shadow
		draw_colored_polygon(_xp(Transform2D(0.0, Vector2(8, 10)), poly), Color(0, 0, 0, 0.28))
		if c == "":
			_empty_slab(r, poly, on)
		else:
			_slab(r, poly, c, on, c == P.who, pp)
		# the hollow number (pops when picked)
		var af := UI.anton()
		var ns := "0%d" % (i + 1)
		var npop := 1.0 + 0.25 * maxf(0.0, _pop("slab%d" % i))
		var nw := UI.text_w(af, ns, 50)
		var ncol: Color = (UI.col(c) if c != "" else Color(1, 1, 1, 0.6)) if on else Color(1, 1, 1, 0.35)
		var np := Vector2(r.end.x - r.size.x * 0.16 - nw / 2.0, r.position.y + 6.0 + af.get_ascent(50) * 0.6)
		draw_set_transform_matrix(m * Transform2D(0.0, np) * Transform2D().scaled(Vector2(npop, npop)))
		draw_string_outline(af, Vector2(-nw / 2.0, af.get_ascent(50) * 0.4), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, 4, ncol)
		draw_set_transform_matrix(off)
		var ii := i
		if live_:
			_hover("slab%d" % i, wpoly)
			hit(wpoly, func(): focus = -1; pick(ii))
	# the title, n / 3
	var te := _ent(0.0, 480.0)
	draw_set_transform_matrix(off * Transform2D(deg_to_rad(-6.0 - 10.0 * (1.0 - te)), Vector2(20 - 260.0 * (1.0 - te), 14)))
	draw_string(UI.anton(false, 3), Vector2(0, 11), "FORMATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.7))
	var tfs := 32 if vs.y <= 420.0 else 34
	var tw := UI.text_w(UI.bhs(), "편성", tfs)
	UI.para(self, 0, 15, tw + 24.0, tfs + 4.0, 8.0, Color.BLACK)
	draw_string(UI.bhs(), Vector2(12, 15 + tfs + 2.0 - tfs * 0.12), "편성", HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color.WHITE)
	draw_set_transform_matrix(off)
	var cs := "%d / 3" % party().size()
	var af2 := UI.anton()
	var cw := UI.text_w(af2, cs, 16) + 24.0
	var cy := 22.0 - 60.0 * (1.0 - _ent(120.0, 420.0))
	UI.para(self, 130, cy, cw, 23, 4.0, Color.BLACK)
	draw_string(af2, Vector2(142, cy + 2.0 + (19.0 - (af2.get_ascent(16) + af2.get_descent(16))) / 2.0 + af2.get_ascent(16)), cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	var hint := "칸을 누르면 서류철로" if at(slot) != "" else "빈 칸 · 눌러서 서류 넣기"
	draw_string(UI.noto(), Vector2(vs.x * 0.04, vs.y * 0.85 + 22.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.55 + 0.15 * sin(t / 500.0)))
	_bar(vs, col_cur, live_, off)
	# ✕ (turns on hover)
	var cc := Vector2(vs.x - 14.0 - 18.0, 14.0 + 18.0)
	var xr := Rect2(cc - Vector2(22, 22), Vector2(44, 44))
	var xh: float = tr.get_v("xh", 1.0 if (live_ and _over(xr)) else 0.0, 200.0, "bk")
	draw_circle(cc + Vector2(3, 3), 18.0, col_cur.darkened(0.3))
	draw_circle(cc, 18.0 + 2.0 * xh, Color.BLACK)
	draw_arc(cc, 17.0 + 2.0 * xh, 0, TAU, 32, Color.WHITE, 2.0, true)
	draw_set_transform_matrix(off * Transform2D(xh * PI / 2.0, cc))
	UI.cross(self, Vector2.ZERO, 5.0, Color.WHITE, 2.0)
	draw_set_transform_matrix(off)
	if live_:
		_hover("x", xr)
		hit(xr, back)
	draw_set_transform(Vector2.ZERO)
	if k > 0.0: draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, k * 0.6))

func _slab(r: Rect2, poly: PackedVector2Array, c: String, on: bool, lead: bool, pp: Vector2) -> void:
	draw_colored_polygon(poly, Color.BLACK)
	var st: Texture2D = tx(SK.path(c, "st_base"))
	var ih := r.size.y * 1.45
	var iw := ih * st.get_width() / st.get_height()
	var kk: float = tr.get_v("img_" + c, 1.0 if on else 0.0, 450.0, "ez")
	var par := -pp * Vector2(14.0, 8.0) * (0.4 + 0.6 * kk)
	var ir := Rect2(r.position.x + r.size.x / 2.0 - iw * (0.5 - 0.03 * kk) + par.x, r.position.y + r.size.y * 0.04 + par.y + sin(t / 2100.0) * 2.0, iw, ih)
	var dim := lerpf(0.5, 1.0, kk)
	var clipped := Geometry2D.intersect_polygons(poly, _rp(ir))
	for pg in clipped:
		var uv := PackedVector2Array()
		for p in pg: uv.append((p - ir.position) / ir.size)
		draw_colored_polygon(pg, Color(dim, dim, dim), uv, st)
	if on:
		# a sheen sweeping across every 2.6 s
		var u := fmod(t / 2600.0, 1.0)
		var bx := r.position.x - r.size.x * 0.6 + u * r.size.x * 2.2
		var band := PackedVector2Array([Vector2(bx, r.position.y), Vector2(bx + 40.0, r.position.y), Vector2(bx - 30.0, r.end.y), Vector2(bx - 70.0, r.end.y)])
		for pg in Geometry2D.intersect_polygons(poly, band):
			draw_colored_polygon(pg, Color(1, 1, 1, 0.12))
		draw_polyline(poly + PackedVector2Array([poly[0]]), UI.col(c), 4.0 + sin(t / 300.0))
	var bf := UI.bhs()
	var nf := UI.noto()
	if lead:
		# the tag hangs and swings
		var lw := UI.text_w(bf, "LEADER", 14) + 16.0
		var lp := Vector2(r.position.x + r.size.x * 0.2, r.position.y + r.size.y * 0.05)
		var sw := deg_to_rad(-8.0 + sin(t / 650.0) * 4.0)
		draw_set_transform_matrix(_cur_m * Transform2D(sw, lp))
		draw_line(Vector2(lw / 2.0, -10), Vector2(lw / 2.0, 0), Color.WHITE, 1.5)
		draw_rect(Rect2(0, 0, lw, 20), Color.WHITE)
		draw_string(bf, Vector2(8, 16), "LEADER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		draw_set_transform_matrix(_cur_m)
	# the name tag
	var name_s: String = CH.NAME[c]
	var role: String = SHEET[c][1]
	var o := Vector2(r.position.x + r.size.x * 0.08, r.end.y - r.size.y * 0.1)
	var fs := 26 if r.size.x > 200.0 else 20
	var ne: float = tr.get_v("tag_" + c, 1.0 if on else 0.0, 380.0, "bk")
	draw_set_transform_matrix(_cur_m * Transform2D(deg_to_rad(-6.0 - 3.0 * ne), o) * Transform2D().scaled(Vector2.ONE * (1.0 + 0.08 * ne)))
	var bw := UI.text_w(bf, name_s, fs) + 18.0
	draw_rect(Rect2(0, -fs - 10.0, bw, fs + 8.0), Color.BLACK)
	draw_string(bf, Vector2(9, -8.0), name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var rw := UI.text_w(nf, role, 10) + 12.0
	draw_rect(Rect2(0, 2, rw * (0.4 + 0.6 * ne) if not on else rw, 16), UI.col(c))
	draw_string(nf, Vector2(6, 14), role, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.BLACK)
	draw_set_transform_matrix(_cur_m)

func _empty_slab(r: Rect2, poly: PackedVector2Array, on: bool) -> void:
	draw_colored_polygon(poly, Color(0, 0, 0, 0.42 if on else 0.28))
	var ctr := r.get_center()
	var inset := PackedVector2Array()
	for p in poly: inset.append(ctr + (p - ctr) * 0.92)
	inset.append(inset[0])
	# marching dashes
	var ph := fmod(t * 0.03, 18.0)
	var dc := Color(1, 1, 1, 0.8 if on else 0.45)
	for j in 4:
		var a: Vector2 = inset[j]
		var b: Vector2 = inset[j + 1]
		var L := a.distance_to(b)
		var dv := (b - a) / L
		var s := -ph
		while s < L:
			var s0 := maxf(0.0, s)
			var s1 := minf(L, s + 10.0)
			if s1 > s0: draw_line(a + dv * s0, a + dv * s1, dc, 2.0)
			s += 18.0
	var pl := 1.0 + (0.08 * sin(t / 260.0) if on else 0.03 * sin(t / 600.0))
	var c := ctr + Vector2(0, -14)
	draw_set_transform_matrix(_cur_m * Transform2D(sin(t / 900.0) * 0.08, c) * Transform2D().scaled(Vector2(pl, pl)))
	draw_rect(Rect2(-16, -3, 32, 6), Color(1, 1, 1, 0.9 if on else 0.5))
	draw_rect(Rect2(-3, -16, 6, 32), Color(1, 1, 1, 0.9 if on else 0.5))
	draw_set_transform_matrix(_cur_m)
	var s2 := "서류 넣기"
	var nf := UI.bhs()
	draw_string(nf, Vector2(ctr.x - UI.text_w(nf, s2, 16) / 2.0, ctr.y + 30.0), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9 if on else 0.5))
	draw_string(UI.noto(), Vector2(ctr.x - UI.text_w(UI.noto(), "비어 있음", 11) / 2.0, ctr.y + 48.0), "비어 있음", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55))

var _cur_m := Transform2D()             # the slab being drawn (its pieces draw relative to it)

func _bar(vs: Vector2, col: Color, live_: bool, off: Transform2D) -> void:
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
		var act: String = B[j][0]
		var e := _ent(260.0 + j * 60.0, 420.0)
		var hv: float = tr.get_v("bh_" + act, 1.0 if (live_ and en and _over(br)) else 0.0, 160.0, "ez")
		var sq := 1.0 - 0.1 * _pop("btn_" + act)
		var piv := br.get_center()
		var m := off * Transform2D(0.0, piv + Vector2((1.0 - e) * 160.0, -4.0 * hv)) * Transform2D().scaled(Vector2(1.0 + 0.05 * hv, (1.0 + 0.05 * hv) * sq)) * Transform2D(0.0, -piv)
		draw_set_transform_matrix(m)
		UI.para(self, br.position.x + 4 + 2.0 * hv, br.position.y + 4 + 2.0 * hv, br.size.x, br.size.y, 6.0, Color(col.darkened(0.3), a))
		UI.para(self, br.position.x, br.position.y, br.size.x, br.size.y, 6.0, Color(1, 1, 1, a))
		var lit := fo or hv > 0.5
		UI.para(self, br.position.x + 2, br.position.y + 2, br.size.x - 4, br.size.y - 4, 6.0, Color(1, 1, 1, a) if lit else Color(0, 0, 0, a))
		var lw := UI.text_w(bf, B[j][1], 16)
		draw_string(bf, Vector2(br.get_center().x - lw / 2.0 + 3.0, br.position.y + 23.0), B[j][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, a) if lit else Color(1, 1, 1, a))
		draw_set_transform_matrix(off)
		if live_:
			_hover("btn_" + act, br)
			hit(br, func(): focus = -1; pops["btn_" + act] = t; press(act))

# ---- the desk ----
## files per row / rows for n files
func _grid(n: int) -> Vector2i:
	var cols := 2 if n <= 4 else (3 if n <= 9 else 4)
	return Vector2i(cols, maxi(1, ceili(float(n) / cols)))

## the lamp over the desk swings a little: where its light falls (desk coords)
func _lamp(vs: Vector2) -> Vector2:
	return Vector2(vs.x * (0.34 + 0.06 * sin(t / 2300.0)), vs.y * 0.18 + 6.0 * sin(t / 1700.0))

## a shadow's offset for something at p lifted by `lift` (away from the lamp)
func _shoff(vs: Vector2, p: Vector2, lift: float) -> Vector2:
	var d := (p - _lamp(vs))
	return d.normalized() * (5.0 + 14.0 * lift) + Vector2(0, 3)

## the desk's slide-in as a transform; the stamp's thump shakes it
func _cur_off() -> Transform2D:
	var vs := get_viewport_rect().size
	var k: float = tr.get_v("in_desk", 1.0 if mode == "desk" else 0.0, 460.0, "ez")
	var sh := Vector2.ZERO
	if stamp_t >= 0.0 and stamp_t < 200.0:
		var f := (1.0 - stamp_t / 200.0) * 5.0
		sh = Vector2(sin(stamp_t / 11.0) * f, cos(stamp_t / 9.0) * f * 0.6)
	return Transform2D(0.0, Vector2(vs.x * (1.0 - k) * 0.6, 0) + sh)

func _xf_rect(r: Rect2, m: Transform2D) -> PackedVector2Array:
	return _xp(_cur_off() * m, _rp(r))

func _paint_desk(vs: Vector2, k: float) -> void:
	var off := _cur_off()
	draw_set_transform_matrix(off)
	_wood(vs)
	var live_ := k >= 1.0 and fly.is_empty()
	_order(vs, live_)
	_files(vs, live_)
	_motes(vs)
	draw_set_transform_matrix(off)
	var y := vs.y - 46.0
	var bx := 18.0
	bx += _slip(Vector2(bx, y), "돌아가기", PAPER, INK, live_, close_desk, 0) + 10.0
	if at(slot) != "" and party().size() > 1 and at(slot) != arena.player.who:
		_slip(Vector2(bx, y), "비우기", Color("#e9d6d0"), RED_INK, live_, func(): empty_slot(slot); close_desk(), 1)
	draw_set_transform(Vector2.ZERO)

func _wood(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2(0, -vs.y), vs * Vector2(2, 3)), WOOD)     # from x 0: sliding away, it uncovers the slots
	draw_rect(Rect2(-12, -vs.y, 12, vs.y * 3.0), Color(0, 0, 0, 0.35))
	var ph := vs.y / 3.0
	for p in 3:
		var y0 := p * ph
		var tint := 0.04 * float((p * 7) % 3 - 1)
		draw_rect(Rect2(0, y0, vs.x * 2.0, ph), Color(1, 1, 1, tint) if tint > 0.0 else Color(0, 0, 0, absf(tint) * 1.5))
		for g in 9:
			var gy := y0 + 8.0 + g * ph / 9.0
			var pts := PackedVector2Array()
			for s in 25:
				var x := s * vs.x / 24.0
				pts.append(Vector2(x, gy + sin(x / (60.0 + g * 9.0) + p * 2.0 + g) * (2.0 + g % 3) + sin(x / 23.0 + g) * 0.8))
			draw_polyline(pts, Color(WOOD_D, 0.35 if g % 3 == 0 else 0.18), 1.0 + float(g % 2))
		draw_line(Vector2(0, y0), Vector2(vs.x * 2.0, y0), Color(0, 0, 0, 0.45), 2.0)
		draw_line(Vector2(0, y0 + 2.0), Vector2(vs.x * 2.0, y0 + 2.0), Color(1, 0.85, 0.6, 0.06), 1.0)
	# the lamp's pool (sways; a faint flicker) and its cone from above
	var L := _lamp(vs)
	var fl := 1.0 - 0.05 * maxf(0.0, sin(t / 83.0) * sin(t / 131.0) - 0.6) * 2.5
	draw_texture_rect(UI.glow(), Rect2(L - Vector2(vs.x, vs.x) * 0.62, Vector2(vs.x, vs.x) * 1.24), false, Color(1.0, 0.82, 0.5, 0.36 * fl))
	var top := Vector2(L.x - vs.x * 0.08, -vs.y * 0.3)
	var cl := Color(1.0, 0.85, 0.55, 0.0)
	draw_polygon(PackedVector2Array([top, top + Vector2(vs.x * 0.16, 0), L + Vector2(vs.x * 0.3, vs.y * 0.4), L + Vector2(-vs.x * 0.3, vs.y * 0.4)]), PackedColorArray([Color(1, 0.85, 0.55, 0.10 * fl), Color(1, 0.85, 0.55, 0.10 * fl), cl, cl]))
	var dk := Color(0, 0, 0, 0.55)
	var cl2 := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2(0, vs.y * 0.7), Vector2(vs.x * 2.0, vs.y * 0.7), Vector2(vs.x * 2.0, vs.y), Vector2(0, vs.y)]), PackedColorArray([cl2, cl2, dk, dk]))
	draw_polygon(PackedVector2Array([Vector2(vs.x * 0.8, 0), Vector2(vs.x, 0), vs, Vector2(vs.x * 0.8, vs.y)]), PackedColorArray([cl2, dk, dk, cl2]))
	# the brass plate
	var bf := UI.bhs()
	var s := "인사 서류함"
	var w := UI.text_w(bf, s, 15) + 24.0
	var pr := Rect2(vs.x - w - 64.0, 16.0 - 60.0 * (1.0 - _ent(200.0, 400.0, true)), w, 26.0)
	draw_rect(Rect2(pr.position + Vector2(2, 3), pr.size), Color(0, 0, 0, 0.4))
	draw_rect(pr, Color("#b8924a"))
	draw_rect(pr.grow(-2.0), Color("#d4ae62"))
	var gl := fmod(t / 3200.0, 1.0)
	draw_rect(Rect2(pr.position.x + pr.size.x * gl - 8.0, pr.position.y + 2, 10, pr.size.y - 4), Color(1, 1, 0.9, 0.25))
	draw_string(bf, pr.position + Vector2(12, 19), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#4a3415"))

## dust in the lamp's beam
func _motes(vs: Vector2) -> void:
	var L := _lamp(vs)
	for i in 34:
		var h1 := float((i * 7919) % 1000) / 1000.0
		var h2 := float((i * 104729) % 1000) / 1000.0
		var x := fmod(h1 * vs.x * 1.3 + t * (0.004 + 0.006 * h2), vs.x)
		var y := vs.y - fmod(h2 * vs.y + t * (0.006 + 0.008 * h1), vs.y * 1.1)
		x += sin(t / (700.0 + 500.0 * h2) + i) * 10.0
		var bx := L.x + (y - L.y) * 0.15
		var a := clampf(1.0 - absf(x - bx) / (vs.x * 0.3), 0.0, 1.0) * (0.25 + 0.35 * h1) * (0.6 + 0.4 * sin(t / 400.0 + i))
		if a > 0.02: draw_circle(Vector2(x, y), 1.0 + 1.4 * h2, Color(1.0, 0.92, 0.7, a))

## the mission order (left): three numbered lines, the slot being filled circled
func _order(vs: Vector2, live_: bool) -> void:
	var w := minf(vs.x * 0.34, 320.0)
	var h := minf(vs.y * 0.80, w * 1.32)
	var r := Rect2(vs.x * 0.04, vs.y * 0.08, w, h)
	var piv := r.get_center()
	var e := _ent(40.0, 540.0, true)
	var m := Transform2D(deg_to_rad(-2.5 - 14.0 * (1.0 - e) + sin(t / 2600.0) * 0.4), piv + Vector2(-vs.x * 0.55 * (1.0 - e), 0)) * Transform2D(0.0, -piv)
	draw_set_transform_matrix(_cur_off() * m)
	draw_rect(Rect2(r.position + _shoff(vs, piv, 0.1), r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, PAPER)
	for i in int(h / 18.0):
		var ly := r.position.y + 70.0 + i * 18.0
		if ly > r.end.y - 10.0: break
		draw_line(Vector2(r.position.x + 8, ly), Vector2(r.end.x - 8, ly), Color(0.45, 0.6, 0.8, 0.18), 1.0)
	draw_line(Vector2(r.position.x + 30, r.position.y + 6), Vector2(r.position.x + 30, r.end.y - 6), Color(0.85, 0.3, 0.3, 0.3), 1.0)
	# a pin at the top
	draw_circle(Vector2(piv.x, r.position.y + 10), 5.0, Color("#c0392b"))
	draw_circle(Vector2(piv.x - 1.5, r.position.y + 8.5), 1.6, Color(1, 1, 1, 0.6))
	var sf: Font = UI.serif_b()
	var nf := UI.noto()
	draw_string(UI.anton(false, 2), Vector2(r.position.x + 38, r.position.y + 24), "DISPATCH ORDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(INK, 0.55))
	draw_string(sf, Vector2(r.position.x + 38, r.position.y + 48), "임무 파견 명령서", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
	draw_line(Vector2(r.position.x + 38, r.position.y + 56), Vector2(r.end.x - 14, r.position.y + 56), INK, 1.5)
	_rows.clear()
	if _circ_slot != slot:
		_circ_slot = slot
		circ_t = 0.0
	var rh := minf(58.0, (h - 150.0) / 3.0)
	for i in 3:
		var y := r.position.y + 70.0 + i * (rh + 6.0)
		var rr := Rect2(r.position.x + 36, y, w - 50, rh)
		_rows.append(rr)
		var c := at(i)
		draw_string(UI.anton(), Vector2(rr.position.x, rr.position.y + rh * 0.62), "0%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(INK, 0.7))
		var hidden: bool = not fly.is_empty() and fly["c"] == c and stamp_t < 0.0
		if c != "" and not hidden:
			var ph := rh - 8.0
			var fr := Rect2(rr.position.x + 34, rr.position.y + 4, ph, ph)
			var pk := 1.0
			if i == slot and stamp_t >= 0.0: pk = 1.0 + 0.3 * maxf(0.0, exp(-stamp_t / 120.0) * cos(stamp_t / 40.0))
			var fc := fr.get_center()
			draw_set_transform_matrix(_cur_off() * m * Transform2D(0.0, fc) * Transform2D().scaled(Vector2(pk, pk)) * Transform2D(0.0, -fc))
			draw_rect(fr.grow(2.0), Color.WHITE)
			draw_texture_rect(tx(SK.path(c, "face")), fr, false)
			draw_set_transform_matrix(_cur_off() * m)
			draw_string(sf, Vector2(fr.end.x + 8, rr.position.y + rh * 0.48), CH.NAME[c], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
			draw_string(nf, Vector2(fr.end.x + 8, rr.position.y + rh * 0.48 + 16), SHEET[c][1], HORIZONTAL_ALIGNMENT_LEFT, rr.end.x - fr.end.x - 10, 9, Color(INK, 0.7))
			if c == arena.player.who:
				draw_string(UI.anton(), Vector2(rr.end.x - 40, rr.position.y + 14), "LEAD", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, RED_INK)
		elif c == "":
			draw_string(nf, Vector2(rr.position.x + 34, rr.position.y + rh * 0.6), "— 공석 —", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK, 0.4))
		if i == slot:
			# red pencil: a loose double loop drawing itself
			var prog := clampf(circ_t / 420.0, 0.0, 1.0)
			for lp in 2:
				var pts := PackedVector2Array()
				var n := int(2.0 + 46.0 * clampf(prog * 1.3 - lp * 0.3, 0.0, 1.0))
				for s in n:
					var a := float(s) / 46.0 * TAU * 1.08 + lp * 0.5 - 2.2
					var wob := 1.0 + 0.04 * sin(a * 3.0 + lp)
					pts.append(rr.get_center() + Vector2(cos(a) * rr.size.x * 0.54 * wob, sin(a) * rr.size.y * 0.62 * wob))
				if pts.size() >= 2: draw_polyline(pts, Color(PENCIL, 0.8), 2.2 - lp * 0.7)
		var ii := i
		if live_:
			var rp := _xf_rect(rr, m)
			_hover("row%d" % i, rp)
			hit(rp, func(): slot = mini(ii, party().size()); dsel = at(slot); arena.sfx("ui_move", 0.4, {"st": 2.0 * ii}))
	var hint := "오른쪽에서 서류를 골라 0%d번 칸에 넣는다" % (slot + 1) if dsel == "" else "「%s」 서류를 한 번 더 누르면 배정" % CH.NAME[dsel]
	draw_string(nf, Vector2(r.position.x + 38, r.end.y - 52), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 50, 10, Color(INK, 0.75))
	draw_line(Vector2(r.position.x + 38, r.end.y - 22), Vector2(r.end.x - 70, r.end.y - 22), Color(INK, 0.5), 1.0)
	draw_string(nf, Vector2(r.position.x + 38, r.end.y - 9), "길드 《어설픈 용맹》", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(INK, 0.55))
	# 배정: an ink stamp waiting at the corner, twitching for attention
	if dsel != "" and fly.is_empty():
		var sr := Rect2(r.end.x - 66, r.end.y - 46, 56, 30)
		var sh_hv: float = tr.get_v("st_hv", 1.0 if (live_ and _over(_xf_rect(sr, m))) else 0.0, 160.0, "bk")
		var tw := fmod(t, 1600.0)
		var wig := sin(tw / 30.0) * 0.12 * maxf(0.0, 1.0 - tw / 260.0)
		var sc := sr.get_center()
		var sm := m * Transform2D(wig - 0.06, sc) * Transform2D().scaled(Vector2.ONE * (1.0 + 0.15 * sh_hv)) * Transform2D(0.0, -sc)
		draw_set_transform_matrix(_cur_off() * sm)
		draw_rect(sr, Color(RED_INK, 0.12 + 0.1 * sh_hv))
		draw_rect(sr, Color(RED_INK, 0.9), false, 2.5)
		draw_string(UI.bhs(), sr.position + Vector2(10, 22), "배정", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, RED_INK)
		draw_set_transform_matrix(_cur_off() * m)
		if live_:
			_hover("stamp", _xf_rect(sr, m))
			hit(_xf_rect(sr, m), send)
	# the stamp landing, ink flecks
	if stamp_t >= 0.0 and slot < _rows.size():
		var u := clampf(stamp_t / 130.0, 0.0, 1.0)
		var scl := lerpf(2.4, 1.0, UI.bk(u))
		var rr2: Rect2 = _rows[slot]
		var sp := Vector2(rr2.end.x - 40, rr2.get_center().y)
		var a := clampf(u * 2.0, 0.0, 1.0) * 0.85
		draw_set_transform_matrix(_cur_off() * m * Transform2D(deg_to_rad(-12.0), sp) * Transform2D().scaled(Vector2(scl, scl)))
		draw_rect(Rect2(-30, -15, 60, 30), Color(RED_INK, a), false, 3.0)
		draw_string(UI.bhs(), Vector2(-21, 8), "배정", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(RED_INK, a))
		if u >= 1.0:
			var fk := clampf((stamp_t - 130.0) / 380.0, 0.0, 1.0)
			for f in 12:
				var ang := f * TAU / 12.0 + 0.3 * sin(f * 3.1)
				var dist := 30.0 + 26.0 * fk * (0.6 + 0.4 * float((f * 37) % 10) / 10.0)
				draw_circle(Vector2(cos(ang), sin(ang)) * dist * Vector2(1.3, 0.8), 2.2 * (1.0 - fk) + 0.6, Color(RED_INK, 0.8 * (1.0 - fk)))
	draw_set_transform_matrix(_cur_off())

## the files (right): dealt onto the desk, a loose grid
func _files(vs: Vector2, live_: bool) -> void:
	var R2 := roster()
	var g := _grid(R2.size())
	var area := Rect2(vs.x * 0.42, vs.y * 0.12, vs.x * 0.55, vs.y * 0.74)
	var cell := Vector2(area.size.x / g.x, area.size.y / g.y)
	var fw := minf(cell.x * 0.84, cell.y * 0.84 * 1.38)
	var fh := fw / 1.38
	_F.clear()
	var order: Array = []
	if desk_t < 50.0: dealt.clear()
	for i in R2.size():
		var c: String = R2[i]
		var cx := area.position.x + (i % g.x + 0.5) * cell.x
		var cy := area.position.y + (i / g.x + 0.5) * cell.y
		var hsh := float(absi(hash(c)) % 1000) / 1000.0
		var de := _ent(160.0 + i * 95.0, 460.0, true)
		if de >= 0.98 and not dealt.has(c):
			dealt[c] = true
			arena.sfx("ui_move", 0.3, {"st": -3.0 + i * 1.5})
		var p0 := Vector2(cx + (hsh - 0.5) * cell.x * 0.08, cy + (fmod(hsh * 7.0, 1.0) - 0.5) * cell.y * 0.06)
		var hv: float = tr.get_v("fh_" + c, 1.0 if (live_ and _F_poly.has(c) and _over(_F_poly[c])) else 0.0, 160.0, "ez")
		var lift: float = tr.get_v("lift_" + c, 1.0 if dsel == c else 0.0, 300.0, "bk")
		var lv := maxf(lift, 0.35 * hv)
		var tilt := 0.0
		if hv > 0.0 and hover.x > -900.0: tilt = clampf((hover.x - p0.x) / fw, -0.5, 0.5) * 0.08 * hv
		var a := deg_to_rad(lerpf(-7.0 + 14.0 * hsh, 0.0, lift)) + tilt + deg_to_rad((1.0 - de) * (40.0 + 60.0 * hsh))
		var p := p0 + Vector2(0, -10.0 * lv + sin(t / 1300.0 + i * 2.0) * 1.2 * (1.0 - lift)) + Vector2(vs.x * 0.7, -vs.y * 0.5) * (1.0 - de)
		var sq := 1.0 - 0.07 * _pop("file_" + c)
		_F[c] = {"p": p, "a": a, "s": (1.0 + 0.07 * lv) * sq, "lift": lv, "open": lift}
		order.append(c)
	order.sort_custom(func(x, y): return _F[x]["lift"] < _F[y]["lift"])     # the lifted one on top
	_F_poly.clear()
	for c in order:
		if not fly.is_empty() and fly["c"] == c: continue
		var F: Dictionary = _F[c]
		var dimf := 0.0 if (dsel == "" or dsel == c) else 0.18
		var poly := _folder(vs, c, F["p"], F["a"], F["s"], fw, fh, F["lift"], F["open"], dimf)
		_F_poly[c] = poly
		var cc: String = c
		if live_:
			_hover("file_" + c, poly)
			hit(poly, func(): file_tap(cc))
	# the one flying onto the order: an arc, a spin, a short trail
	if not fly.is_empty() and stamp_t < 0.0 and slot < _rows.size():
		var to: Vector2 = (_rows[slot] as Rect2).get_center()
		for tr_i in [2, 1, 0]:
			var u := UI.bez(0.3, 0.0, 0.2, 1.0, clampf((fly["t"] - tr_i * 28.0) / 420.0, 0.0, 1.0))
			var p: Vector2 = (fly["from"] as Vector2).lerp(to, u) + Vector2(0, -90.0 * sin(u * PI))
			var spin := -u * TAU * 0.75 - 0.3 * u
			var sc := lerpf(1.08, 0.3, u)
			if tr_i > 0:
				draw_set_transform_matrix(_cur_off() * Transform2D(spin, p) * Transform2D().scaled(Vector2(sc, sc)))
				draw_rect(Rect2(-fw / 2.0, -fh / 2.0, fw, fh), Color(MANILA, 0.25 / tr_i))
			else:
				_folder(vs, fly["c"], p, spin, sc, fw, fh, 1.0, 0.0, 0.0)
	draw_set_transform_matrix(_cur_off())

var _F_poly := {}

## one manila folder centred on p; returns its outline (for the tap)
func _folder(vs: Vector2, c: String, p: Vector2, a: float, s: float, fw: float, fh: float, lift: float, opn: float, dimf: float) -> PackedVector2Array:
	var m := _cur_off() * Transform2D(a, p) * Transform2D().scaled(Vector2(s, s))
	var hw := fw / 2.0
	var hh := fh / 2.0
	var P = arena.player
	var slot_i: int = P.party.find(c)
	var tabw := fw * 0.42
	# shadow (away from the lamp, longer when lifted) — drawn unrotated by the lift
	var so := _shoff(vs, p, lift)
	draw_set_transform_matrix(_cur_off() * Transform2D(a, p + so) * Transform2D().scaled(Vector2(s, s)))
	draw_colored_polygon(PackedVector2Array([Vector2(-hw, -hh - 18), Vector2(-hw + tabw, -hh - 18), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]), Color(0, 0, 0, 0.30 + 0.12 * lift))
	draw_set_transform_matrix(m)
	# back flap with the name tab
	draw_colored_polygon(PackedVector2Array([Vector2(-hw, -hh), Vector2(-hw + 8, -hh - 18), Vector2(-hw + tabw - 8, -hh - 18), Vector2(-hw + tabw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]), MANILA_D)
	var sf: Font = UI.serif_b()
	draw_string(sf, Vector2(-hw + 12, -hh - 4), CH.NAME[c], HORIZONTAL_ALIGNMENT_LEFT, tabw - 16, 13, INK)
	# the sheet (slides up when the file is opened)
	var sy := -hh + 4 - 16.0 * opn
	draw_rect(Rect2(-hw + 10, sy, fw - 22, fh * 0.45), PAPER)
	for i in 3: draw_line(Vector2(-hw + 18, sy + 8 + i * 6), Vector2(hw - 30 - i * 10, sy + 8 + i * 6), Color(INK, 0.25), 1.0)
	if opn > 0.05:
		draw_string(UI.noto(), Vector2(hw - 64, sy + 12), "인사 기록", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(INK, 0.5 * opn))
	# the front cover (drops open a touch when lifted)
	var top := -hh + fh * 0.16 + fh * 0.06 * opn
	draw_colored_polygon(PackedVector2Array([Vector2(-hw - 2.0 * opn, top), Vector2(hw + 2.0 * opn, top), Vector2(hw, hh), Vector2(-hw, hh)]), MANILA)
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
	if opn > 0.01:
		draw_rect(Rect2(-hw - 3, -hh - 21 - 16.0 * opn, fw + 6, fh + 24 + 16.0 * opn), Color(1, 0.92, 0.6, (0.55 + 0.25 * sin(t / 260.0)) * clampf(opn, 0.0, 1.0)), false, 2.0)
	if dimf > 0.0:
		draw_colored_polygon(PackedVector2Array([Vector2(-hw, -hh - 18), Vector2(-hw + tabw, -hh - 18), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)]), Color(0, 0, 0, dimf))
	draw_set_transform_matrix(_cur_off())
	return _xp(m, PackedVector2Array([Vector2(-hw, -hh - 18), Vector2(hw, -hh - 18), Vector2(hw, hh), Vector2(-hw, hh)]))

## a paper slip button on the desk (lifts on hover, squashes on a tap); returns its width
func _slip(p: Vector2, s: String, bg: Color, fg: Color, live_: bool, cb: Callable, i: int) -> float:
	var bf := UI.bhs()
	var w := UI.text_w(bf, s, 15) + 28.0
	var r := Rect2(p, Vector2(w, 32))
	var key := "slip_" + s
	var e := _ent(320.0 + i * 70.0, 420.0, true)
	var hv: float = tr.get_v(key, 1.0 if (live_ and _over(_xf_rect(r, Transform2D.IDENTITY))) else 0.0, 160.0, "ez")
	var sq := 1.0 - 0.1 * _pop(key)
	var c := r.get_center()
	var m := Transform2D(deg_to_rad(-2.0 + 2.0 * i - 3.0 * hv), c + Vector2(0, 80.0 * (1.0 - e) - 4.0 * hv)) * Transform2D().scaled(Vector2(1.0 + 0.04 * hv, (1.0 + 0.04 * hv) * sq)) * Transform2D(0.0, -c)
	draw_set_transform_matrix(_cur_off() * m)
	draw_rect(Rect2(r.position + Vector2(3, 4) + Vector2(2, 3) * hv, r.size), Color(0, 0, 0, 0.35))
	draw_rect(r, bg)
	draw_string(bf, r.position + Vector2(14, 22), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, fg)
	draw_set_transform_matrix(_cur_off())
	if live_:
		var rp := _xf_rect(r, Transform2D.IDENTITY)
		_hover(key, rp)
		hit(rp, func(): pops[key] = t; cb.call())
	return w
