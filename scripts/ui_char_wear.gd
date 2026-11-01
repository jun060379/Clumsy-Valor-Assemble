extends RefCounted
## The character page's 의상 tab (after 기록): quick switching between the costumes this member owns, and a look at the
## ones still to get. Drawn into the ui_char page (p) on the shared tab ground (ui_char_mem.gd SPEC "wear"):
## the picked costume's standing art slams in on the left (cx_slam, as on 상세), its name stamps low left, the costumes run
## down the black shard on the right as slanted blades (white = picked, a tag for 착용 중 / 보유 / 잠김 / 준비 중, a NEW dot),
## and the picked one's card pops under them (cx_gdpop) with its idle animation in a slanted window and the 입기 button.
## Keys: ↑↓ pick · Enter / Space wear (←→ stay the page's tab keys). A costume whose art isn't in yet is never drawn with
## stand-in art: its place shows the empty hanger and "준비 중".
## The static helpers (sprite, hanger, status) are shared with the wardrobe (ui_wardrobe.gd).

const UI := preload("res://scripts/ui_kit.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const CH := preload("res://scripts/chars.gd")
const SD := preload("res://scripts/skin_data.gd")
const SK := preload("res://scripts/skins.gd")
const FD := preload("res://scripts/fame_data.gd")
const ST_N := {"worn": "착용 중", "owned": "보유", "locked": "잠김", "wip": "준비 중", "wip_own": "보유 · 준비 중"}

var p                         # ui_char.gd
var si := 0                   # the costume picked in the list
var pick_t := 1e9             # since it was picked (blade flash, card pop)
var wore_t := 1e9             # since 입기 (the flash over the art, the stamp)
var shown := ""               # the costume whose art is on the left


func _init(page) -> void:
	p = page

func S():
	return p.arena.skins

func list() -> Array:
	return SD.of(p.c)

func cur_id() -> String:
	var L := list()
	return L[clampi(si, 0, L.size() - 1)]["id"] if not L.is_empty() else ""

## on entering the tab or changing member: start on what she wears
func reset() -> void:
	var L := list()
	si = 0
	for i in L.size():
		if SK.worn(p.c) == L[i]["id"]: si = i
	pick_t = 1e9
	wore_t = 1e9
	shown = cur_id()
	if S() != null: S().seen(shown)

func tick(dt: float) -> void:
	pick_t += dt
	wore_t += dt

func key(k: int) -> bool:
	if k in [KEY_UP, KEY_DOWN]:
		var n := list().size()
		var j := clampi(si + (-1 if k == KEY_UP else 1), 0, n - 1)
		if j != si: _pick(j)
		return true
	if k in [KEY_ENTER, KEY_SPACE]:
		wear()
		return true
	return false

func _pick(j: int) -> void:
	si = j
	pick_t = 0.0
	shown = cur_id()
	p.slam_t = 0.0                    # the art slams in again (cx_slam), as on a member change
	p.name_t = 0.0
	if S() != null: S().seen(shown)
	p.sfx("ready", 0.15)

func wear() -> void:
	var id := cur_id()
	if S() == null or id == "": return
	if S().is_worn(id):
		p.sfx("guard", 0.25)
		return
	if not S().equip(id):
		p.sfx("guard", 0.35)
		return
	wore_t = 0.0
	p.sfx("ready", 0.6)
	p.sfx("heavy", 0.35)


# ---------- shared helpers ----------
## "worn" / "owned" / "locked" / "wip" / "wip_own"
static func status(skins, id: String) -> String:
	var own: bool = skins != null and skins.owns(id)
	if not SK.is_ready(id): return "wip_own" if own else "wip"
	if skins != null and skins.is_worn(id): return "worn"
	return "owned" if own else "locked"

static func st_col(st: String, col: Color) -> Color:
	match st:
		"worn": return col
		"owned": return Color.WHITE
		"locked": return Color(0.55, 0.55, 0.58)
	return Color("#ffd34d")

## the frame of animation `an` at ms (looping its row's timings)
static func frame_at(c: String, an: String, ms: float, ov: Dictionary = {}) -> int:
	var e = CH.entry(c, an, ov)
	if e == null: return 0
	var tim: Array = e[1]
	var tot := 0.0
	for v in tim: tot += minf(float(v), 2000.0)
	var tm := fmod(ms, maxf(1.0, tot))
	for i in tim.size():
		var d := minf(float(tim[i]), 2000.0)
		if tm < d: return i
		tm -= d
	return 0

## one frame of skin `id` drawn with its feet at `feet`; `s` = pixels per source pixel (the sheet cell is 448 x 352,
## the feet line at row 340); `d` = facing. Draws nothing for a skin whose sheets aren't in.
static func sprite(ci: CanvasItem, id: String, an: String, ms: float, feet: Vector2, s: float, col := Color.WHITE, d := 1) -> void:
	var sk := SD.get_skin(id)
	if sk.is_empty() or not SK.is_ready(id): return
	var c: String = sk["c"]
	var ov := SK.anims_of(id)
	var rf: Array = CH.resolve(c, an, frame_at(c, an, ms, ov), "", ov)
	var row: int = rf[0]
	var tex: Texture2D = SK.sheet_row_of(id, c, row)
	if tex == null: return
	var k: float = s * CH.SCALE[c] / CH.SCALE["estelle"] * (CH.ROWFIX_AIDA.get(row, 1.0) if c == "aida" else 1.0)
	var src := Rect2(rf[1] * CH.CELL_W, (row % CH.ROWS_PER_SHEET) * CH.CELL_H, CH.CELL_W, CH.CELL_H)
	ci.draw_set_transform(feet, 0.0, Vector2(d, 1))
	ci.draw_texture_rect_region(tex, Rect2(-CH.CELL_W * k / 2.0, -340.0 * k, CH.CELL_W * k, CH.CELL_H * k), src, col)
	ci.draw_set_transform(Vector2.ZERO)

## the empty hanger: where a costume's art will hang once it is drawn (never stand-in art)
static func hanger(ci: CanvasItem, c: Vector2, w: float, col: Color, a := 1.0) -> void:
	var h := w * 0.42
	var hook := c + Vector2(0, -h * 0.9)
	ci.draw_arc(hook + Vector2(0, -w * 0.07), w * 0.07, PI * 0.15, PI * 1.55, 12, Color(col, a), maxf(2.0, w * 0.025), true)
	var pts := PackedVector2Array([hook, c + Vector2(-w / 2.0, 0), c + Vector2(w / 2.0, 0), hook])
	ci.draw_polyline(pts, Color(col, a), maxf(2.0, w * 0.03), true)
	ci.draw_line(c + Vector2(-w / 2.0 + 6.0, 0), c + Vector2(w / 2.0 - 6.0, 0), Color(col, a), maxf(3.0, w * 0.04), true)

static func how_line(id: String) -> String:
	return SD.how(id, FD.FRANK)

const ANIM_N := {"idle": "대기", "start": "출발", "stop": "멈춤", "turn": "돌아서기", "jump": "점프", "runjump": "달려 점프", "run": "달리기", "walk": "걷기"}
## "부분 완성 · 새 그림: 대기 · 걷기 …" for a costume drawn in parts ("" otherwise)
static func partial_line(id: String) -> String:
	var s := SD.get_skin(id)
	if not s.get("partial", false): return ""
	var L: Array = []
	for a in s.get("done", []): L.append(ANIM_N.get(a, a))
	return "부분 완성 · 새 그림: " + " · ".join(L) + " (나머지 동작은 이전 그림)"


# ---------- drawing ----------
func paint(vs: Vector2, col: Color) -> void:
	p.mx.ground(vs, col, "wear")
	var L := list()
	if L.is_empty(): return
	if shown == "" or SD.get_skin(shown).get("c", "") != p.c: reset()
	var id := cur_id()
	var sk := SD.get_skin(id)
	var st := status(S(), id)
	# the standing art of the picked costume (or the empty hanger)
	if SK.is_ready(id):
		var path := SK.path_of(id, p.c, "st_base")
		var t0: Texture2D = p.tx(path)
		var h := vs.y
		var w := h * t0.get_width() / t0.get_height()
		p._art(vs, path, Rect2(vs.x * 0.04, vs.y * 0.04, w, h), "slam")
		if wore_t < 520.0:
			# 입기: the new costume flashes white and settles (the big element carried through)
			var fk := 1.0 - UIA.p(wore_t, 0.0, 520.0, "ez")
			var r := Rect2(vs.x * 0.04, vs.y * 0.04, w, h)
			p.draw_set_transform(Vector2(r.get_center().x, r.end.y), 0.0, Vector2.ONE * (1.0 + 0.04 * fk))
			p.draw_texture_rect(t0, Rect2(-w / 2.0, -h, w, h), false, Color(3, 3, 3, 0.75 * fk))
			p.draw_set_transform(Vector2.ZERO)
	else:
		_wip_art(vs, col)
	p._name(Vector2(vs.x * 0.05, vs.y * 0.83))
	_blades(vs, col, L)
	_card(vs, col, id, sk, st)
	if wore_t < 900.0: _stamp(vs, col)

## the empty-hanger plate where the art will go
func _wip_art(vs: Vector2, col: Color) -> void:
	var u := UIA.p(p.slam_t, 0.0, 620.0, "bk")
	var c := Vector2(vs.x * 0.24 + 0.3 * vs.x * (1.0 - u), vs.y * 0.46)
	var r := Rect2(-vs.x * 0.15, -vs.y * 0.3, vs.x * 0.3, vs.y * 0.6)
	p.draw_set_transform(c, deg_to_rad(-4.0 - 10.0 * (1.0 - u)), Vector2.ONE * lerpf(1.15, 1.0, u))
	var a := clampf(p.slam_t / 200.0, 0.0, 1.0)
	p.draw_colored_polygon(UI.clip(Rect2(r.position + Vector2(10, 10), r.size), [[6, 0], [100, 3], [94, 100], [0, 97]]), Color(0, 0, 0, 0.45 * a))
	p.draw_colored_polygon(UI.clip(r, [[6, 0], [100, 3], [94, 100], [0, 97]]), Color(0.06, 0.05, 0.08, a))
	p.draw_polyline(UI.clip(r.grow(-8), [[6, 0], [100, 3], [94, 100], [0, 97], [6, 0]]), Color(UI.col2(p.c), 0.5 * a), 2.0, true)
	hanger(p, Vector2(0, -r.size.y * 0.08 + sin(p.t / 700.0) * 3.0), r.size.x * 0.5, Color(1, 1, 1, 0.85), a)
	var s := "준비 중"
	p.draw_string(UI.bhs(), Vector2(-UI.text_w(UI.bhs(), s, 34) / 2.0, r.size.y * 0.22), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(1, 1, 1, a))
	var s2 := "이 의상의 그림이 아직 없다"
	p.draw_string(UI.noto(), Vector2(-UI.text_w(UI.noto(), s2, 12) / 2.0, r.size.y * 0.22 + 24.0), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8, a))
	p.draw_set_transform(Vector2.ZERO)

## the costumes as slanted blades down the shard (as the gear tab's), 40 ms apart on entry
func _blades(vs: Vector2, col: Color, L: Array) -> void:
	var f := UI.spaced(UI.anton(), 2)
	var hx := vs.x * 0.56
	var hy := vs.y * 0.17
	p.draw_set_transform(Vector2(hx, hy), deg_to_rad(-4.0))
	var hd := "COSTUME  %d / %d" % [L.filter(func(s): return S() != null and S().owns(s["id"])).size(), L.size()]
	p.draw_string(f, Vector2(0, 0), hd, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col, 0.95))
	p.draw_set_transform(Vector2.ZERO)
	var y := vs.y * 0.21
	for i in L.size():
		var s: Dictionary = L[i]
		var id: String = s["id"]
		var on := i == si
		var st := status(S(), id)
		var e := UI.bk(clampf((p.tab_t - i * 40.0) / 500.0, 0.0, 1.0))
		var x := vs.x * 0.56 + (i % 2) * -10.0 + (14.0 if on else 0.0) + 60.0 * (1.0 - e)
		var fb := 0.0
		if on and pick_t < 450.0:
			var fu := UIA.p(pick_t, 0.0, 450.0, "bk")
			x += 36.0 * (1.0 - fu)
			fb = 1.0 - fu
		var bw := vs.x * 0.38
		var bh := 34.0
		var poly := PackedVector2Array([Vector2(x, y), Vector2(x + bw, y - 3.0), Vector2(x + bw - 8.0, y + bh - 3.0), Vector2(x - 6.0, y + bh)])
		if on: p.draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(4, 4), poly[1] + Vector2(4, 4), poly[2] + Vector2(4, 4), poly[3] + Vector2(4, 4)]), Color(col, e))
		p.draw_colored_polygon(poly, Color(1, 1, 1, e) if on else Color(0, 0, 0, 0.92 * e))
		if fb > 0.0: p.draw_colored_polygon(poly, Color(1, 1, 1, 0.8 * fb))
		var sc := st_col(st, col)
		p.draw_rect(Rect2(x - 2, y, 5, bh - 2), Color(sc, e))
		# the round face of the costume (its own face once its art is in, else the hanger)
		var fc := Vector2(x + 24, y + bh / 2.0 - 1.0)
		if SK.is_ready(id):
			var ft: Texture2D = SK.tex_of(id, "face")
			if ft != null: p.draw_texture_rect(ft, Rect2(fc - Vector2(13, 13), Vector2(26, 26)), false, Color(1, 1, 1, e) if st != "locked" else Color(0.35, 0.35, 0.38, e))
		else:
			hanger(p, fc + Vector2(0, 4), 22.0, Color.BLACK if on else Color(0.85, 0.85, 0.85), e)
		var nm: String = s["n"]
		p.draw_string(UI.noto_k(), Vector2(x + 46, y + 22), nm, HORIZONTAL_ALIGNMENT_LEFT, bw - 150.0, 13, Color(0, 0, 0, e) if on else Color(1, 1, 1, e))
		var tag: String = ST_N[st]
		var tf := UI.noto_k()
		var tw := UI.text_w(tf, tag, 10) + 12.0
		var tr := Rect2(x + bw - tw - 16.0, y + 8.0, tw, 17.0)
		UI.para(p, tr.position.x, tr.position.y, tr.size.x, tr.size.y, 3.0, Color(sc, e) if st in ["worn", "wip", "wip_own"] else (Color(0, 0, 0, e) if on else Color(1, 1, 1, 0.14 * e)))
		var tc := Color.BLACK if st in ["worn", "wip", "wip_own"] else (Color.WHITE if on or st == "owned" else Color(0.7, 0.7, 0.72))
		p.draw_string(tf, tr.position + Vector2(7, 13), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(tc, e))
		if S() != null and S().fresh.has(id):
			UI.star4(p, Vector2(x + bw - 6.0, y + 2.0), 7.0 + sin(p.t / 160.0) * 1.5, Color(1, 0.85, 0.3, e))
		var ii := i
		p.hit(poly, func():
			if si != ii: _pick(ii)
			else: wear())
		y += bh + 7.0

## the picked costume's card: name, line, how to get it, the idle window, 입기
func _card(vs: Vector2, col: Color, id: String, sk: Dictionary, st: String) -> void:
	var L := list()
	var x := vs.x * 0.58
	var y := vs.y * 0.21 + L.size() * 41.0 + 14.0
	var w := vs.x * 0.36
	var ps: Array = [[String(sk["d"]), 12, Color(0.15, 0.15, 0.15)], ["얻는 법 · " + how_line(id), 11, Color(0.35, 0.3, 0.32)]]
	if partial_line(id) != "": ps.append([partial_line(id), 10, Color(0.75, 0.35, 0.1)])
	var h: float = 64.0 + p.paras_h(w - 120.0, ps) + 44.0
	h = maxf(h, 150.0)
	h = minf(h, vs.y - y - 12.0)
	var gc := Vector2(x + w / 2.0, y + 60.0)
	var e := UIA.p(minf(pick_t, p.tab_t), 0.0, 420.0, "bk")
	var m := UIA.xf(gc, Vector2(-30.0 * (1.0 - e), 0), deg_to_rad(12.0 * (1.0 - e)), Vector2.ONE * lerpf(0.6, 1.0, e)) * Transform2D(deg_to_rad(-3.0), Vector2(x, y))
	var a := clampf(minf(pick_t, p.tab_t) / 150.0, 0.0, 1.0)
	p.draw_set_transform_matrix(m)
	p.draw_rect(Rect2(6, 6, w, h), Color(0, 0, 0, 0.5 * a))
	p.draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, a))
	# the idle window: a slanted black pane with the costume breathing in it
	var win := Rect2(w - 104, 10, 94, 112)
	var wp := UI.clip(win, [[10, 0], [100, 0], [90, 100], [0, 100]])
	p.draw_colored_polygon(wp, Color(0.07, 0.06, 0.09, a))
	if SK.is_ready(id):
		p.draw_colored_polygon(UI.clip(Rect2(win.position + Vector2(0, win.size.y * 0.7), Vector2(win.size.x, win.size.y * 0.3)), [[3, 0], [97, 0], [90, 100], [0, 100]]), Color(col, 0.35 * a))
		var mm := m * Transform2D(0.0, Vector2.ZERO)
		p.draw_set_transform(Vector2.ZERO)
		var feet := m * Vector2(win.get_center().x, win.end.y - 8.0)
		sprite(p, id, "idle", p.t, feet, 0.55, Color(1, 1, 1, a) if st != "locked" else Color(0.25, 0.25, 0.28, a))
		p.draw_set_transform_matrix(mm)
	else:
		hanger(p, win.get_center() + Vector2(0, 6), 56.0, Color(1, 1, 1, 0.8), a)
	p.draw_polyline(UI.clip(win, [[10, 0], [100, 0], [90, 100], [0, 100], [10, 0]]), Color(col, a), 2.0, true)
	var tag: String = ST_N[st]
	var sc := st_col(st, col)
	UI.para(p, 12, 6, UI.text_w(UI.anton(), "COSTUME", 11) + 18.0, 16, 3.0, Color(sc if sc != Color.WHITE else Color(0.2, 0.2, 0.2), a))
	p.draw_string(UI.spaced(UI.anton(), 1), Vector2(20, 19), "COSTUME", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Color.BLACK if sc != Color.WHITE else Color.WHITE, a))
	p.draw_string(UI.bhs(), Vector2(12, 48), String(sk["n"]), HORIZONTAL_ALIGNMENT_LEFT, w - 130.0, 21, Color(0, 0, 0, a))
	p.paras(p, 12, 58, w - 124.0, ps)
	var btn := Rect2(12, h - 36, 92, 26)
	var can: bool = S() != null and S().can_equip(id) and st != "worn"
	var lbl: String = "입기" if can else tag
	UI.para(p, btn.position.x, btn.position.y, btn.size.x, 26, 4.0, Color(0, 0, 0, a) if can else Color(0.8, 0.8, 0.8, a))
	p.draw_string(UI.noto_k(), btn.position + Vector2(btn.size.x / 2.0 - UI.text_w(UI.noto_k(), lbl, 13) / 2.0, 18), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, a) if can else Color(0.3, 0.3, 0.3, a))
	if st == "locked" and SD.kind(id) == "shop":
		p.draw_string(UI.noto(), btn.position + Vector2(btn.size.x + 10.0, 18), "옷장에서 살 수 있다", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.35, 0.3, 0.32, a))
	p.draw_set_transform(Vector2.ZERO)
	p.hit(PackedVector2Array([m * btn.position, m * Vector2(btn.end.x, btn.position.y), m * btn.end, m * Vector2(btn.position.x, btn.end.y)]), func(): wear())

## 입기: the stamp slams over the art
func _stamp(vs: Vector2, col: Color) -> void:
	var u := UIA.p(wore_t, 0.0, 380.0, "bk")
	var a := clampf(wore_t / 80.0, 0.0, 1.0) * (1.0 - clampf((wore_t - 650.0) / 250.0, 0.0, 1.0))
	var c := Vector2(vs.x * 0.27, vs.y * 0.62)
	p.draw_set_transform(c, deg_to_rad(-8.0 - 14.0 * (1.0 - u)), Vector2.ONE * lerpf(2.2, 1.0, u))
	var s := "CHANGE!"
	var f := UI.anton(true, 2)
	var w := UI.text_w(f, s, 38) + 34.0
	UI.para(p, -w / 2.0 + 6.0, -26.0 + 6.0, w, 52, 10.0, Color(0, 0, 0, a))
	UI.para(p, -w / 2.0, -26.0, w, 52, 10.0, Color(col, a))
	p.draw_string(f, Vector2(-w / 2.0 + 18.0, 15.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color(1, 1, 1, a))
	p.draw_set_transform(Vector2.ZERO)
