extends "res://scripts/ui_page.gd"
## 옷장 (the hall's wardrobe, fame_data FAC "wardrobe"; skins.gd / skin_data.gd): every costume of a member, owned or not.
## The selected one stands large in a tall slanted mirror playing its idle animation (tap the mirror or ↑↓ for other moves),
## its card on the black shard says what it is, whether it is hers and how to get it, with 입기 / 구매 · N 실링; the costumes
## hang below on a rail as slanted tags that sway, the picked one lifted. The member faces top right switch the rail.
## Motion (the character page's kit): the black wipe on open and on a member change, the mirror slamming in (cx_slam), the
## rail sliding in and the tags dropping 70 ms apart (--bk), the outgoing figure carried off left while the new one flashes in
## from the right, the card popping (cx_gdpop), CHANGE! / GET! stamps. A costume whose art isn't in yet shows the empty
## hanger and "준비 중" — never stand-in art — and can't be worn or bought.
## Keys: ←→ pick · Q/E (LB/RB) member · ↑↓ the mirror's move · Enter 입기 / 구매 (twice: arm, then buy) · Esc back.

const UIA := preload("res://scripts/ui_anim.gd")
const SD := preload("res://scripts/skin_data.gd")
const SK := preload("res://scripts/skins.gd")
const WEAR := preload("res://scripts/ui_char_wear.gd")
const BAGP := preload("res://scripts/ui_bag.gd")
const MOVES := {"estelle": [["idle", "대기"], ["walk", "걷기"], ["attack1", "베기"], ["guard", "방패"]],
	"aida": [["idle", "대기"], ["walk", "걷기"], ["attack1", "삽질"], ["mark", "균열"]],
	"luce": [["idle", "대기"], ["walk", "걷기"], ["attack1", "빛"], ["heal", "치유"]]}

var want_c := ""
var c := "estelle"
var sel := 0
var trn := UIA.Tr.new()
var open_t := 0.0
var pick_t := 1e9            # since the costume changed (figure in, card pop)
var prev_id := ""            # the costume being carried out of the mirror
var mv := 0                  # the mirror's move (MOVES)
var mv_t := 0.0              # its clock
var mv_chg := 1e9            # since the move changed (its chip pops)
var wipe_t := -1.0           # the black wipe: open / member
var wipe_kind := ""
var pend_c := ""
var arm_t := 1e9             # 구매 armed (press again within 2.6 s)
var stamp := ""              # "CHANGE!" / "GET!" / ""
var stamp_t := 1e9
var deny_t := 1e9            # a refused press shakes the button
var rail_t := 0.0            # the rail's own clock (resets on a member change: the tags drop in again)


func _ready() -> void:
	super()
	keys = ["wardrobe"]

func S():
	return arena.skins

func list() -> Array:
	return SD.of(c)

func cur_id() -> String:
	var L := list()
	return L[clampi(sel, 0, L.size() - 1)]["id"] if not L.is_empty() else ""

func roster() -> Array:
	return arena.player.roster()

func _opened() -> void:
	c = want_c if want_c != "" else arena.player.who
	want_c = ""
	open_t = 0.0
	rail_t = 0.0
	wipe_t = 0.0
	wipe_kind = "open"
	pend_c = ""
	trn.clear()
	_start_on_worn()

func _start_on_worn() -> void:
	var L := list()
	sel = 0
	for i in L.size():
		if SK.worn(c) == L[i]["id"]: sel = i
	prev_id = ""
	pick_t = 1e9
	mv = 0
	mv_t = 0.0
	mv_chg = 1e9
	arm_t = 1e9
	stamp_t = 1e9
	if S() != null: S().seen(cur_id())

func _tick(dt: float) -> void:
	trn.step(dt)
	open_t += dt
	rail_t += dt
	pick_t += dt
	mv_t += dt
	mv_chg += dt
	arm_t += dt
	stamp_t += dt
	deny_t += dt
	if wipe_t >= 0.0:
		wipe_t += dt
		if wipe_kind == "member" and pend_c != "" and wipe_t >= 190.0:
			c = pend_c
			pend_c = ""
			rail_t = 0.0
			trn.clear()
			_start_on_worn()
		if wipe_t >= (540.0 if wipe_kind == "open" else 490.0): wipe_t = -1.0

func _key(k: int) -> void:
	match k:
		KEY_ESCAPE: back()
		KEY_LEFT, KEY_RIGHT:
			var n := list().size()
			var j := clampi(sel + (-1 if k == KEY_LEFT else 1), 0, n - 1)
			if j != sel: _pick(j)
		KEY_Q, KEY_E:
			var R := roster()
			var i := R.find(c)
			_member(R[(i + (R.size() - 1 if k == KEY_Q else 1)) % R.size()])
		KEY_UP, KEY_DOWN:
			_move(1 if k == KEY_DOWN else -1)
		KEY_ENTER, KEY_SPACE:
			_act()

func _wheel(d: int, _p: Vector2) -> void:
	var j := clampi(sel + d, 0, list().size() - 1)
	if j != sel: _pick(j)

func back() -> void:
	arena.sfx("ready", 0.25)
	menu.ui_root.sweep.run(func(): menu.close_page(), UI.col(c))

func _pick(j: int) -> void:
	prev_id = cur_id()
	sel = j
	pick_t = 0.0
	arm_t = 1e9
	mv_t = 0.0
	if S() != null: S().seen(cur_id())
	sfx("ready", 0.18)

func _member(cc: String) -> void:
	if cc == c or wipe_t >= 0.0: return
	pend_c = cc
	wipe_t = 0.0
	wipe_kind = "member"
	sfx("ready", 0.3)

func _move(d: int) -> void:
	var n: int = MOVES[c].size()
	mv = (mv + d + n) % n
	mv_t = 0.0
	mv_chg = 0.0
	sfx("ready", 0.12)

## Enter / the main button: 입기, or 구매 (armed on the first press, bought on the second)
func _act() -> void:
	var id := cur_id()
	if S() == null or id == "": return
	var st := WEAR.status(S(), id)
	if st == "owned":
		if S().equip(id):
			_stamp("CHANGE!")
			sfx("ready", 0.6)
			sfx("heavy", 0.35)
		return
	if st == "locked" and SD.kind(id) == "shop":
		if arm_t > 2600.0:
			arm_t = 0.0
			sfx("ready", 0.3)
			return
		var r: String = S().buy(id)
		arm_t = 1e9
		if r == "ok":
			_stamp("GET!")
			sfx("heavy", 0.6)
		else:
			_deny("실링이 모자라다 · %d 필요" % int(SD.get_skin(id)["unlock"]["value"]) if r == "nomoney" else "살 수 없다")
		return
	_deny("")

func _deny(msg: String) -> void:
	deny_t = 0.0
	sfx("guard", 0.35)
	if msg != "" and arena.get("fame") != null: arena.fame.notice(msg, "옷장", Color("#ffd34d"))

func _stamp(s: String) -> void:
	stamp = s
	stamp_t = 0.0


# ---------- drawing ----------
func _paint(vs: Vector2) -> void:
	var col := UI.col(c)
	_ground(vs, col)
	var L := list()
	var id := cur_id()
	_mirror(vs, col, id)
	_card(vs, col, id)
	_rail(vs, col, L)
	_title(vs, col)
	_faces(vs)
	_purse(vs, col)
	close_x(vs, func(): back())
	if stamp_t < 1000.0: _stamp_draw(vs, col)
	_wipe(vs)

## the ground: her colour, slow rays, drifting dots, the black shard on the right with its light edge and moving stripes,
## the white slash low left, the big outlined WARDROBE drifting
func _ground(vs: Vector2, col: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), col)
	UI.burst(self, Vector2(vs.x * 0.25, vs.y * 0.55), maxf(vs.x, vs.y) * 1.4, 0.14, t / 70000.0 * TAU)
	var sc := Vector2(-fmod(t / 6000.0, 1.0) * 44.0, fmod(t / 6000.0, 1.0) * 22.0)
	UI.dots(self, Rect2(Vector2.ZERO, Vector2(vs.x * 0.5, vs.y)), 0.28, 1.0, sc)
	var sh := Rect2(vs.x * 0.46, -vs.y * 0.15, vs.x * 0.7, vs.y * 1.3)
	var sk := UIA.p(open_t, 0.0, 700.0, "mv")
	sh.position.x += vs.x * 0.25 * (1.0 - sk)
	var shp := UI.rot(UI.clip(sh, [[8, 0], [100, 0], [100, 100], [20, 100], [0, 62], [12, 47], [3, 30]]), sh.get_center(), deg_to_rad(-6.0))
	var edge := UI.rot(UI.clip(Rect2(sh.position - Vector2(18, 0), Vector2(40, sh.size.y)), [[40, 0], [60, 0], [10, 62], [40, 100], [20, 100], [-10, 62]]), sh.get_center(), deg_to_rad(-6.0))
	draw_colored_polygon(edge, UI.col2(c))
	draw_colored_polygon(shp, Color.BLACK)
	# stripes sliding down the shard
	var gd := Vector2(0.5, 0.866)
	var along := Vector2(-gd.y, gd.x) * 900.0
	var shift := fmod(t / 40.0, 28.0)
	var o0 := Vector2(vs.x * 0.5, -vs.y * 0.6)
	var k := -20.0
	while k < 70.0:
		var o := o0 + gd * (k * 28.0 + shift)
		var band := PackedVector2Array([o - along, o + along, o + gd * 9.0 + along, o + gd * 9.0 - along])
		for piece in Geometry2D.intersect_polygons(band, shp): _poly(piece, Color(1, 1, 1, 0.035))
		k += 1.0
	var sl := Rect2(-vs.x * 0.06, vs.y * 0.9, vs.x * 0.62, 20.0)
	draw_colored_polygon(UI.rot(UI.clip(sl, [[0, 40], [100, 0], [100, 30], [3, 100]]), sl.get_center(), deg_to_rad(-5.0)), Color.WHITE)
	var fs := int(vs.y * 0.3)
	var drift := sin(t / 9000.0) * 20.0
	draw_set_transform(Vector2(vs.x * 0.5 + drift, vs.y * 0.98), deg_to_rad(-6.0))
	draw_string_outline(UI.anton(), Vector2.ZERO, "WARDROBE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(1, 1, 1, 0.1))
	draw_set_transform(Vector2.ZERO)

## WARDROBE / 옷장 on a black slab, top left (drops in)
func _title(vs: Vector2, col: Color) -> void:
	var u := UIA.p(open_t, 120.0, 500.0, "bk")
	var a := clampf((open_t - 120.0) / 150.0, 0.0, 1.0)
	draw_set_transform(Vector2(20, 14 - 40.0 * (1.0 - u)), deg_to_rad(-6.0 - 10.0 * (1.0 - u)))
	draw_string(UI.anton(false, 3), Vector2(0, 11), "WARDROBE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, 0.75 * a))
	var s := "옷장"
	var w := UI.text_w(UI.bhs(), s, 34)
	UI.para(self, 6, 21, w + 24.0, 38, 8.0, Color(UI.col2(c), a))
	UI.para(self, 0, 15, w + 24.0, 38, 8.0, Color(0, 0, 0, a))
	draw_string(UI.bhs(), Vector2(12, 46), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, a))
	var n := 0
	for sk in SD.SKINS: if S() != null and S().owns(sk["id"]): n += 1
	var cnt := "%d / %d" % [n, SD.SKINS.size()]
	draw_string(UI.anton(true), Vector2(w + 34.0, 46), cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, 0.7 * a))
	draw_set_transform(Vector2.ZERO)

## the mirror: a tall slanted glass, the costume standing in it
func _mirror(vs: Vector2, col: Color, id: String) -> void:
	var mw := minf(vs.x * 0.34, 330.0)
	var mh := vs.y * 0.78
	var mc := Vector2(vs.x * 0.255, vs.y * 0.13 + mh / 2.0)
	# cx_slam: from 40 % right, turned, 1.15×, dark until 45 %, lit by 60 %; then a slow breath
	var u := UIA.p(open_t, 60.0, 620.0, "bk")
	var lit: float = UIA.kf(open_t - 60.0, [[0.0, 0.0], [0.45, 0.0], [0.6, 1.0], [1.0, 1.0]], 620.0)
	var br := 0.5 - 0.5 * cos(t / 4200.0 * TAU)
	var m := UIA.xf(mc, Vector2(0.4 * vs.x * (1.0 - u), -3.0 * br), deg_to_rad(-2.0 - 12.0 * (1.0 - u)), Vector2.ONE * lerpf(1.15, 1.0, u))
	var r := Rect2(mc - Vector2(mw, mh) / 2.0, Vector2(mw, mh))
	var shape := [[7, 0], [100, 2], [93, 100], [0, 98]]
	var a := clampf((open_t - 60.0) / 180.0, 0.0, 1.0)
	draw_set_transform_matrix(m)
	draw_colored_polygon(UI.clip(Rect2(r.position + Vector2(12, 10), r.size), shape), Color(0, 0, 0, 0.55 * a))
	draw_colored_polygon(UI.clip(r.grow(8), shape), Color(UI.col2(c), a))
	draw_colored_polygon(UI.clip(r.grow(4), shape), Color(0, 0, 0, a))
	var glass := UI.clip(r, shape)
	draw_colored_polygon(glass, Color(0.07, 0.06, 0.1, a))
	# the light behind her and the floor she stands on
	var feet := Vector2(mc.x, r.end.y - mh * 0.09)
	draw_texture_rect(UI.glow(), Rect2(mc - Vector2(mw, mh) * 0.55, Vector2(mw, mh) * 1.1), false, Color(col, 0.55 * a))
	draw_colored_polygon(UI.clip(Rect2(r.position.x, feet.y - 6.0, r.size.x, r.end.y - feet.y + 6.0), [[1, 0], [99, 0], [93, 100], [0, 100]]), Color(col.darkened(0.55), 0.8 * a))
	draw_set_transform_matrix(m * Transform2D(0.0, Vector2(1.0, 0.22), 0.0, feet))
	draw_circle(Vector2.ZERO, mw * 0.24, Color(0, 0, 0, 0.45 * a))
	draw_set_transform_matrix(m)
	# the figure: the outgoing one carried off left, the new one flashing in from the right
	var s := mh * 0.0036
	var an: String = MOVES[c][mv][0]
	var k := lit
	if prev_id != "" and pick_t < 300.0:
		var o := UIA.p(pick_t, 0.0, 300.0, "in")
		_figure(prev_id, an, feet + Vector2(-mw * 0.5 * o, 0), s, Color(1, 1, 1, (1.0 - o) * a), m, deg_to_rad(-8.0 * o))
	var iu := UIA.p(pick_t, 80.0, 460.0, "bk") if pick_t < 1e8 else 1.0
	var ia := clampf((pick_t - 80.0) / 120.0, 0.0, 1.0) if pick_t < 1e8 else 1.0
	if SK.is_ready(id):
		var st := WEAR.status(S(), id)
		var dim := 1.0 if st != "locked" else 0.9
		_figure(id, an, feet + Vector2(mw * 0.45 * (1.0 - iu), 0), s, Color(k * dim, k * dim, k * dim, a * ia), m, deg_to_rad(6.0 * (1.0 - iu)))
		var fl := 1.0 - clampf((pick_t - 80.0) / 380.0, 0.0, 1.0) if pick_t < 1e8 else 0.0
		if stamp_t < 500.0 and stamp == "CHANGE!": fl = maxf(fl, 1.0 - stamp_t / 500.0)
		if fl > 0.0: _figure(id, an, feet + Vector2(mw * 0.45 * (1.0 - iu), 0), s, Color(3, 3, 3, 0.8 * fl * a * ia), m, deg_to_rad(6.0 * (1.0 - iu)))
	else:
		draw_set_transform_matrix(m)
		var hc := Vector2(mc.x, mc.y - mh * 0.08 + sin(t / 700.0) * 4.0)
		WEAR.hanger(self, hc, mw * 0.5, Color(1, 1, 1, 0.9), a * ia)
		var t1 := "준비 중"
		draw_string(UI.bhs(), hc + Vector2(-UI.text_w(UI.bhs(), t1, 38) / 2.0, mh * 0.2), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, a * ia))
		var t2 := "이 의상의 그림이 아직 없다"
		draw_string(UI.noto(), hc + Vector2(-UI.text_w(UI.noto(), t2, 12) / 2.0, mh * 0.2 + 24.0), t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.85, a * ia))
	draw_set_transform_matrix(m)
	# the glass: two light streaks drifting across
	for j in 2:
		var ph := fmod(t / (5200.0 + j * 1700.0) + j * 0.43, 1.0)
		var sx := lerpf(-0.4, 1.3, ph) * mw
		var band := PackedVector2Array([r.position + Vector2(sx, 0), r.position + Vector2(sx + 26.0 + j * 18.0, 0), r.position + Vector2(sx - 70.0 + j * 18.0, mh), r.position + Vector2(sx - 96.0, mh)])
		for piece in Geometry2D.intersect_polygons(band, glass): _poly(piece, Color(1, 1, 1, 0.05 * a))
	# not hers yet: a band across the glass
	var st2 := WEAR.status(S(), id)
	if st2 == "locked":
		var br2 := Rect2(r.position.x - 6.0, r.position.y + mh * 0.06, mw + 12.0, 26.0)
		draw_colored_polygon(UI.clip(br2, [[0, 0], [100, 0], [98, 100], [2, 100]]), Color(0, 0, 0, 0.85 * a))
		var lt := "미리보기 · 아직 없는 의상"
		draw_string(UI.noto_k(), Vector2(mc.x - UI.text_w(UI.noto_k(), lt, 12) / 2.0, br2.position.y + 18.0), lt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col.lightened(0.3), a))
	# the move chip (tap the mirror for the next)
	if SK.is_ready(id):
		var mvn: String = MOVES[c][mv][1]
		var cu := UIA.p(mv_chg, 0.0, 300.0, "bk") if mv_chg < 1e8 else 1.0
		var ct := "▶ " + mvn
		var cw := UI.text_w(UI.noto_k(), ct, 12) + 22.0
		var cp := Vector2(r.position.x + 18.0, r.end.y - 40.0)
		draw_set_transform_matrix(m * Transform2D(deg_to_rad(-4.0 + 10.0 * (1.0 - cu)), Vector2.ONE * lerpf(1.3, 1.0, cu), 0.0, cp))
		UI.para(self, 0, 0, cw, 22, 4.0, Color(1, 1, 1, a))
		draw_string(UI.noto_k(), Vector2(10, 16), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, a))
		draw_set_transform(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	hit(m * glass, func(): _move(1))

## a clipped sliver: skip it when it has next to no area (the triangulator refuses those)
func _poly(pts: PackedVector2Array, col: Color) -> void:
	var ar := 0.0
	for i in pts.size(): ar += pts[i].cross(pts[(i + 1) % pts.size()])
	if absf(ar) > 4.0 and not Geometry2D.triangulate_polygon(pts).is_empty(): draw_colored_polygon(pts, col)

func _figure(id: String, an: String, feet: Vector2, s: float, col: Color, m: Transform2D, rot := 0.0) -> void:
	# sprite() draws in screen space: carry the mirror's transform by placing the feet through it (turn kept small)
	var w := m * Transform2D(rot, feet)
	var fp := w.origin
	WEAR.sprite(self, id, an, mv_t, fp, s * m.get_scale().x, col)

## the picked costume's card on the shard
func _card(vs: Vector2, col: Color, id: String) -> void:
	var sk := SD.get_skin(id)
	if sk.is_empty(): return
	var st := WEAR.status(S(), id)
	var x := vs.x * 0.515
	var y := vs.y * 0.14
	var w := minf(vs.x * 0.44, vs.x - x - 70.0)
	# the card grows with its text: description (+ the 부분 완성 line), then 얻는 법, then the button
	var ps: Array = [[String(sk["d"]), 12, Color(0.18, 0.16, 0.2)]]
	if WEAR.partial_line(id) != "": ps.append([WEAR.partial_line(id), 10, Color(0.75, 0.35, 0.1)])
	var ph: float = paras_h(w - 28.0, ps)
	var h := maxf(vs.y * 0.4, 82.0 + ph + 76.0)
	var T := minf(open_t - 250.0, pick_t)
	var e := UIA.p(T, 0.0, 420.0, "bk")
	var a := clampf(T / 140.0, 0.0, 1.0)
	var piv := Vector2(x + w / 2.0, y + h / 2.0)
	var m := UIA.xf(piv, Vector2(-30.0 * (1.0 - e), 0), deg_to_rad(10.0 * (1.0 - e)), Vector2.ONE * lerpf(0.7, 1.0, e)) * Transform2D(deg_to_rad(-3.0), Vector2(x, y))
	draw_set_transform_matrix(m)
	var R := Rect2(0, 0, w, h)
	draw_colored_polygon(UI.clip(Rect2(R.position + Vector2(7, 7), R.size), [[2, 0], [100, 0], [98, 100], [0, 100]]), Color(col, a))
	draw_colored_polygon(UI.clip(R, [[2, 0], [100, 0], [98, 100], [0, 100]]), Color(1, 1, 1, a))
	# kind chip, name, status
	var kn: String = SD.KIND_N.get(SD.kind(id), "")
	var kf := UI.spaced(UI.noto_k(), 1)
	var kw := UI.text_w(kf, kn, 11) + 18.0
	UI.para(self, 14, 10, kw, 18, 3.0, Color(0, 0, 0, a))
	draw_string(kf, Vector2(22, 24), kn, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col.lightened(0.2), a))
	var tag: String = WEAR.ST_N[st]
	var tcol := WEAR.st_col(st, col)
	var tw2 := UI.text_w(UI.noto_k(), tag, 12) + 20.0
	var shk := sin(deny_t / 22.0) * 5.0 * (1.0 - deny_t / 300.0) if deny_t < 300.0 else 0.0
	UI.para(self, w - tw2 - 16.0, 10, tw2, 20, 3.0, Color(tcol if st != "owned" else Color.BLACK, a))
	draw_string(UI.noto_k(), Vector2(w - tw2 - 6.0, 25), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Color.WHITE if st == "owned" else Color.BLACK, a))
	var nfs := 28
	draw_string(UI.bhs(), Vector2(14, 64), String(sk["n"]), HORIZONTAL_ALIGNMENT_LEFT, w - 28.0, nfs, Color(0, 0, 0, a))
	draw_rect(Rect2(14, 72, minf(w - 28.0, UI.text_w(UI.bhs(), String(sk["n"]), nfs)), 4), Color(col, a))
	for q in ps: q[2] = Color(q[2], a)
	paras(self, 14, 82, w - 28.0, ps)
	# how to get it
	var hy := h - 72.0
	gem(self, Vector2(22, hy + 9.0), 6.0, Color(col, a))
	draw_string(UI.noto_k(), Vector2(34, hy + 14.0), "얻는 법", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.4, 0.36, 0.4, a))
	draw_string(UI.noto(), Vector2(84, hy + 14.0), WEAR.how_line(id), HORIZONTAL_ALIGNMENT_LEFT, w - 100.0, 12, Color(0.1, 0.1, 0.12, a))
	# the button
	var lbl := ""
	var can := false
	match st:
		"owned":
			lbl = "입기"
			can = true
		"worn": lbl = "착용 중"
		"wip", "wip_own": lbl = "그림 준비 중"
		"locked":
			if SD.kind(id) == "shop":
				var price := int(sk["unlock"]["value"])
				can = int(arena.shilling) >= price
				lbl = ("한 번 더 · 구매 확정 %s 실링" if arm_t < 2600.0 else "구매 · %s 실링") % BAGP.loc(price)
			else: lbl = "잠김"
	var bf := UI.noto_k()
	var bw := UI.text_w(bf, lbl, 14) + 40.0
	var b := Rect2(14 + shk, h - 40.0, bw, 30)
	var pulse := UIA.pulse(t, 900.0) if arm_t < 2600.0 else 0.0
	if can: UI.para(self, b.position.x + 5.0, b.position.y + 5.0, b.size.x, 30, 6.0, Color(col, a))
	UI.para(self, b.position.x, b.position.y, b.size.x, 30, 6.0, Color(0, 0, 0, a).lerp(Color(col.darkened(0.3), a), pulse * 0.5) if can else Color(0.82, 0.82, 0.84, a))
	draw_string(bf, b.position + Vector2(20, 21), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a) if can else Color(0.35, 0.35, 0.4, a))
	if st == "locked" and SD.kind(id) == "shop" and not can:
		draw_string(UI.noto(), b.position + Vector2(b.size.x + 10.0, 20), "실링이 모자라다", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.2, 0.25, a))
	draw_set_transform(Vector2.ZERO)
	hit(PackedVector2Array([m * b.position, m * Vector2(b.end.x, b.position.y), m * b.end, m * Vector2(b.position.x, b.end.y)]), func(): _act())

## the rail: a brass rod across the shard, the costumes hanging from it as slanted tags that sway
func _rail(vs: Vector2, col: Color, L: Array) -> void:
	var y := vs.y * 0.665
	var x0 := vs.x * 0.5
	var x1 := vs.x - 14.0
	var ru := UIA.p(open_t, 200.0, 520.0, "bk")
	var rx := (x1 - x0) * 0.6 * (1.0 - ru)
	# the rod
	draw_set_transform(Vector2(rx, 0), deg_to_rad(-1.5))
	draw_rect(Rect2(x0 - 10.0, y - 2.0, x1 - x0 + 20.0, 8.0), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(x0 - 10.0, y - 5.0, x1 - x0 + 20.0, 7.0), Color("#c9a24a"))
	draw_rect(Rect2(x0 - 10.0, y - 5.0, x1 - x0 + 20.0, 2.0), Color("#f3dc94"))
	draw_circle(Vector2(x0 - 12.0, y - 1.0), 7.0, Color("#8a6a2a"))
	draw_circle(Vector2(x1 + 12.0, y - 1.0), 7.0, Color("#8a6a2a"))
	draw_set_transform(Vector2.ZERO)
	var cw := 124.0
	var gap := 14.0
	var span := L.size() * (cw + gap) - gap
	var avail := x1 - x0 - 30.0
	# keep the picked tag in view
	var want := 0.0
	if span > avail:
		var cx_sel := sel * (cw + gap) + cw / 2.0
		want = clampf(cx_sel - avail / 2.0, 0.0, span - avail)
	var scroll: float = trn.get_v("scroll", want, 420.0, "ez")
	var sx := x0 + 20.0 + maxf(0.0, (avail - span) / 2.0) - scroll
	for i in L.size():
		var s: Dictionary = L[i]
		var id: String = s["id"]
		var on := i == sel
		var st := WEAR.status(S(), id)
		var hx := sx + i * (cw + gap) + cw / 2.0 + rx
		if hx < x0 - cw or hx > vs.x + cw: continue
		var hook := Vector2(hx, y - 2.0 + (hx - x0) * -tan(deg_to_rad(1.5)))
		# drop in: 70 ms apart, from above, with a bounce
		var du := UIA.p(rail_t, 380.0 + i * 70.0, 560.0, "bk")
		var da := clampf((rail_t - 380.0 - i * 70.0) / 140.0, 0.0, 1.0)
		if da <= 0.0: continue
		var lift: float = trn.get_v("lift%d" % i, -12.0 if on else 0.0, 380.0, "bk")
		var scl: float = trn.get_v("scl%d" % i, 1.08 if on else 1.0, 380.0, "bk")
		var sway := sin(t / 900.0 + i * 1.3) * 1.6 + (sin(pick_t / 70.0) * 7.0 * (1.0 - pick_t / 600.0) if on and pick_t < 600.0 else 0.0)
		var m := Transform2D(deg_to_rad(sway), Vector2(scl, scl), 0.0, hook + Vector2(0, -120.0 * (1.0 - du)))
		draw_set_transform_matrix(m)
		# the hook and the hanger shoulders
		draw_arc(Vector2(0, -2), 6.0, PI * 1.1, PI * 2.2, 10, Color(0.15, 0.15, 0.17, da), 2.5, true)
		draw_polyline(PackedVector2Array([Vector2(0, 4), Vector2(-cw * 0.42, 24.0 + lift), Vector2(cw * 0.42, 24.0 + lift), Vector2(0, 4)]), Color(0.15, 0.15, 0.17, da), 2.5, true)
		var card := Rect2(-cw / 2.0, 24.0 + lift, cw, 104.0)
		var shape := [[8, 0], [100, 0], [92, 100], [0, 100]]
		draw_colored_polygon(UI.clip(Rect2(card.position + Vector2(6, 6), card.size), shape), Color(col if on else Color(0, 0, 0, 0.5), da))
		draw_colored_polygon(UI.clip(card, shape), Color(1, 1, 1, da) if on else Color(0.1, 0.09, 0.12, da))
		var sc := WEAR.st_col(st, col)
		draw_rect(Rect2(card.position.x + 10.0, card.position.y, 5.0, card.size.y), Color(sc, da))
		# its face, or the hanger
		var fc := card.position + Vector2(cw / 2.0, 36.0)
		if SK.is_ready(id):
			var ft: Texture2D = SK.tex_of(id, "face")
			var g := 1.0 if st != "locked" else 0.35
			draw_circle(fc, 25.0, Color(0, 0, 0, da))
			if ft != null: draw_texture_rect(ft, Rect2(fc - Vector2(22, 22), Vector2(44, 44)), false, Color(g, g, g, da))
		else:
			WEAR.hanger(self, fc + Vector2(0, 8), 44.0, Color.BLACK if on else Color(0.85, 0.85, 0.88), da)
		var nf := UI.noto_k()
		var nm: String = s["n"]
		draw_string(nf, Vector2(card.position.x + 18.0, card.end.y - 26.0), nm, HORIZONTAL_ALIGNMENT_LEFT, cw - 26.0, 12, Color(0, 0, 0, da) if on else Color(1, 1, 1, da))
		var tag: String = WEAR.ST_N[st]
		if st == "locked" and SD.kind(id) == "shop": tag = "%s 실링" % BAGP.loc(int(s["unlock"]["value"]))
		draw_string(UI.noto(), Vector2(card.position.x + 18.0, card.end.y - 9.0), tag, HORIZONTAL_ALIGNMENT_LEFT, cw - 26.0, 10, Color(sc.darkened(0.35) if on and sc != Color.WHITE else (Color(0.3, 0.3, 0.3) if on else sc), da))
		if st == "worn":
			UI.star4(self, card.position + Vector2(cw - 18.0, 14.0), 8.0, Color(col, da))
		if S() != null and S().fresh.has(id):
			var nw := UI.text_w(UI.anton(), "NEW", 11) + 10.0
			UI.para(self, card.end.x - nw - 8.0, card.position.y - 8.0, nw, 15, 3.0, Color("#ffd34d"))
			draw_string(UI.anton(), Vector2(card.end.x - nw - 3.0, card.position.y + 4.0), "NEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.BLACK)
		draw_set_transform(Vector2.ZERO)
		var ii := i
		hit(m * UI.clip(Rect2(card.position.x, card.position.y - 20.0, card.size.x, card.size.y + 20.0), shape), func():
			if sel != ii: _pick(ii)
			else: _act())
	# the hint line under the rail
	var hint := "←→ 고르기 · Q/E 동료 · ↑↓ 동작 · Enter 입기/구매"
	draw_string(UI.noto(), Vector2(x0 + 6.0, vs.y - 12.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.55 * clampf((open_t - 600.0) / 300.0, 0.0, 1.0)))

## the members (top right, as on the character page): tap = that member's rail; a NEW count on a face
func _faces(vs: Vector2) -> void:
	var L := roster()
	var fx := vs.x - 60.0 - L.size() * 50.0
	for i in L.size():
		var cc: String = L[i]
		var on: bool = cc == c
		var r := Rect2(fx, 12, 44, 44)
		var rot: float = trn.get_v("fr%d" % i, -8.0 if on else (5.0 if i == 1 else -6.0), 300.0, "bk")
		var sc: float = trn.get_v("fs%d" % i, 1.1 if on else 0.84, 300.0, "bk")
		var u := UIA.p(open_t, 300.0 + i * 60.0, 500.0, "bk")
		var a := clampf((open_t - 300.0 - i * 60.0) / 150.0, 0.0, 1.0)
		if a > 0.0:
			draw_set_transform_matrix(Transform2D(0.0, Vector2(0, -60.0 * (1.0 - u))) * Transform2D(deg_to_rad(rot + 30.0 * (1.0 - u)), Vector2(sc, sc), 0.0, r.get_center()))
			var lr := Rect2(-22, -22, 44, 44)
			if on: draw_rect(Rect2(lr.position + Vector2(5, 5), lr.size), Color(UI.col(cc), a))
			draw_rect(lr, Color(Color.BLACK if on else Color.WHITE, a))
			var g := 1.0 if on else 0.45
			draw_texture_rect(SK.face(cc), lr.grow(-3), false, Color(g, g, g, a))
			var nn: int = S().fresh_n(cc) if S() != null else 0
			if nn > 0:
				draw_circle(Vector2(18, -18), 8.0, Color("#ffd34d", a))
				draw_string(UI.anton(), Vector2(14.5, -13), str(nn), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0, 0, 0, a))
			draw_set_transform(Vector2.ZERO)
		var c2: String = cc
		hit(r, func(): _member(c2))
		fx += 50.0

## shillings, low right over the shard (the hub's money slab)
func _purse(vs: Vector2, col: Color) -> void:
	var bf := UI.noto_k()
	var p0 := "실링 "
	var p1: String = BAGP.loc(int(arena.shilling))
	var w0 := UI.text_w(bf, p0, 14)
	var w1 := UI.text_w(bf, p1, 14)
	var a := clampf((open_t - 500.0) / 300.0, 0.0, 1.0)
	draw_set_transform(Vector2(vs.x - w0 - w1 - 44.0, vs.y - 30.0), deg_to_rad(-3.0))
	UI.para(self, 0, -10, w0 + w1 + 20.0, 22, 3.9, Color(1, 1, 1, a))
	draw_string(bf, Vector2(10.0, 6), p0, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, a))
	draw_string(bf, Vector2(10.0 + w0, 6), p1, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col.darkened(0.25), a))
	draw_set_transform(Vector2.ZERO)

## CHANGE! / GET!: a slab slamming over the mirror
func _stamp_draw(vs: Vector2, col: Color) -> void:
	var u := UIA.p(stamp_t, 0.0, 380.0, "bk")
	var a := clampf(stamp_t / 80.0, 0.0, 1.0) * (1.0 - clampf((stamp_t - 700.0) / 300.0, 0.0, 1.0))
	var cpos := Vector2(vs.x * 0.26, vs.y * 0.7)
	draw_set_transform(cpos, deg_to_rad(-8.0 - 16.0 * (1.0 - u)), Vector2.ONE * lerpf(2.4, 1.0, u))
	var f := UI.anton(true, 2)
	var w := UI.text_w(f, stamp, 44) + 40.0
	UI.para(self, -w / 2.0 + 7.0, -30.0 + 7.0, w, 60, 12.0, Color(0, 0, 0, a))
	UI.para(self, -w / 2.0, -30.0, w, 60, 12.0, Color(1, 1, 1, a))
	draw_string(f, Vector2(-w / 2.0 + 22.0, 18.0), stamp, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(col.darkened(0.1), a))
	draw_set_transform(Vector2.ZERO)

## the black wipe with a light lightning edge (as the character page's)
func _wipe(vs: Vector2) -> void:
	if wipe_t < 0.0: return
	var x := 0.0
	if wipe_kind == "open":
		x = lerpf(-0.08, -1.4, UIA.p(wipe_t, 60.0, 480.0, [0.2, 0.7, 0.3, 1.0]))
	elif wipe_t < 190.0:
		x = lerpf(1.3, -0.08, UIA.p(wipe_t, 0.0, 190.0, [0.6, 0.0, 0.9, 0.5]))
	else:
		x = lerpf(-0.08, -1.4, UIA.p(wipe_t, 190.0, 300.0, [0.2, 0.7, 0.3, 1.0]))
	var r := Rect2(-0.3 * vs.x, -0.1 * vs.y, vs.x * 1.6, vs.y * 1.2)
	r.position.x += x * r.size.x
	draw_colored_polygon(UI.clip(r, [[18, 0], [100, 0], [100, 100], [0, 100], [10, 62], [4, 58]]), Color.BLACK)
	draw_colored_polygon(UI.clip(r, [[14, 0], [18, 0], [4, 58], [10, 62], [0, 100], [-4, 100], [6, 64], [0, 60]]), UI.col2(c))
