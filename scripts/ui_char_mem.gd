extends RefCounted
## The character page's 스킬 · 기억 · 기록 tabs (prototype CHARACTER SCREEN v2: zoneHTML skill / memHTML / recHTML, shout, say /
## talk / memTalk / react, memFlag "memo" (메모리얼 해방), "clean" (감상), the per-tab .shard / .edge / .slash / .bigen ground and
## the .xa art: st_*_skill, st_*_rec on 기억, st_*_mem (+ _c blink) on 기록 once Lv 12, the old standing art on 기록).
## Drawn into the ui_char page (p); its hit areas go through p.hit(). Keys: see key().

const UI := preload("res://scripts/ui_kit.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const MD := preload("res://scripts/memory_data.gd")
const ST := "res://assets/ui/st/"
const SK := preload("res://scripts/skins.gd")       # the skill / record art of the worn costume (the memorial and old art stay)
const SPEC := {
	"attr": {"shard": [[-6, -12, 66, 130], -7, [[18, 0], [100, 6], [84, 38], [96, 52], [70, 100], [0, 92], [10, 60], [0, 40]]], "edge": [[4, -8, 56, 120], -7, [[30, 0], [36, 0], [14, 100], [8, 100]]],
		"slash": [[44, 31, 70], -14], "bigen": [56, 68, -8], "burst": [30, 58]},
	"gear": {"shard": [[46, -15, 64, 135], 6, [[8, 0], [100, 0], [100, 100], [22, 100], [0, 64], [14, 48], [2, 30]]], "edge": [[50, -10, 30, 125], 6, [[0, 0], [6, 0], [-2, 64], [4, 100], [-2, 100], [-8, 64]]],
		"slash": [[-10, 84, 60], -8], "bigen": [-2, -4, -6], "burst": [76, 50]},
	# CSS: [rect %, rotation, clip-path %] for shard (black) / edge (col2) / slash (white, 20 px); bigen spot and turn; burst centre
	"skill": {"shard": [[-10, 30, 120, 46], -14, [[0, 18], [30, 0], [100, 8], [100, 76], [64, 100], [0, 86]]], "edge": [[-10, 26, 120, 8], -14, [[0, 60], [100, 0], [100, 30], [0, 100]]],
		"slash": [[-5, 78, 110], -14], "bigen": [38, -6, -14], "burst": [22, 62]},
	"match": {"shard": [[-8, 18, 76, 70], -8, [[0, 10], [40, 0], [100, 14], [92, 60], [100, 100], [30, 92], [0, 100]]], "edge": [[-8, 86, 76, 3], -8, [[0, 0], [100, 0], [100, 100], [0, 100]]],
		"slash": [[30, 10, 60], -20], "bigen": [-2, -6, -8], "burst": [78, 40]},
	"rec": {"shard": [[-8, -14, 62, 130], 9, [[0, 0], [82, 0], [100, 30], [86, 46], [96, 100], [0, 100]]], "edge": [[46, -10, 6, 125], 9, [[40, 0], [100, 0], [60, 100], [0, 100]]],
		"slash": [[-10, 12, 50], 10], "bigen": [40, 66, -6], "burst": [72, 45]},
	# 의상 (ui_char_wear.gd): her colour on the left for the standing art, the shard on the right for the list
	"wear": {"shard": [[50, -15, 62, 135], -6, [[8, 0], [100, 0], [100, 100], [22, 100], [0, 64], [14, 48], [2, 30]]], "edge": [[47, -10, 30, 125], -6, [[0, 0], [6, 0], [-2, 64], [4, 100], [-2, 100], [-8, 64]]],
		"slash": [[-10, 90, 62], -6], "bigen": [-3, 60, -6], "burst": [26, 50]}}
## node positions in the tree (% of its box): columns of a branch, rows A / B / C, the cross column
const NX := [20, 27, 34, 45, 52, 62, 72]
const NY := [28, 52, 76]
const XPOS := [[85, 22], [85, 40], [85, 58], [85, 76]]

var p                       # ui_char.gd
var sel := "A0"             # 기억: the node picked (or "LV" = the level button, "RST" = 초기화 for keys)
var si := 0                 # 스킬: the move picked
var shout_t := 9999.0       # its card popped
var li := 0                 # 기록: the line picked (-1 = ◎ 감상)
var top := 0                # 기록: first line shown
var clean := false          # 감상: everything but the art hidden
var memo_t := 0.0           # since the memorial art came in
var pop := ""               # the node / "lv" that just changed, and since when
var pop_t := 9999.0
# say / react (prototype S.say / S.react)
var say_l: Array = []
var say_t := 0.0            # ms the line has been up; 0 = none
var react := ""
var react_t := 0.0
var jolt := ""              # "hop" / "shake"
var jolt_t := 9999.0
var taps: Array = []
var ti := 0
var mi := -1
var hold := 0.0             # the memorial blink held (smile line / tap)
var blink := 0.0            # ms left of a blink
var blink_next := 2600.0
var blink2 := 0.0           # ms until the double blink's second shut
var xf := Transform2D.IDENTITY


func _init(page) -> void:
	p = page

func M():
	return p.arena.runes.memory

func R():
	return p.arena.runes

func memo() -> bool:
	return p.tab == "rec" and M().unlocked(p.c)

func opened() -> void:
	sel = "A0"
	si = 0
	li = 0
	top = 0
	clean = false
	hush()

func tab_changed() -> void:
	hush()
	clean = false
	memo_t = 0.0
	shout_t = 9999.0
	if p.tab == "rec": li = -1 if memo() else 0

func member_changed() -> void:
	hush()
	si = 0
	li = -1 if memo() else 0
	top = 0
	memo_t = 0.0
	pop = ""

## leaving the record tab (or the member, or the page) ends whatever line was being said
func hush() -> void:
	say_l = []
	say_t = 0.0
	react = ""
	hold = 0.0

func tick(dt: float) -> void:
	shout_t += dt
	pop_t += dt
	memo_t += dt
	jolt_t += dt
	if say_t > 0.0:
		say_t += dt
		var life: float = String(say_l[1]).length() * 34.0 + 2600.0
		if say_t > life:
			say_t = 0.0
			react = ""
			hold = 0.0
	if react_t > 0.0:
		react_t -= dt
		if react_t <= 0.0 and say_t <= 0.0: react = ""
	if hold > 0.0: hold -= dt
	if blink > 0.0: blink -= dt
	blink_next -= dt
	if blink_next <= 0.0:
		blink_next = 2600.0 + randf() * 2600.0
		blink = 130.0
		if randf() < 0.25: blink2 = 260.0          # one time in four a second blink 260 ms on (110 ms)
	if blink2 > 0.0:
		blink2 -= dt
		if blink2 <= 0.0: blink = 110.0


# ---------- input ----------
## keys for the three tabs; true when used
func key(k: int) -> bool:
	if clean:
		if k == KEY_ESCAPE:
			_unclean()
		elif k in [KEY_ENTER, KEY_SPACE, KEY_X]:
			mem_talk()
		return true
	match p.tab:
		"skill":
			if k in [KEY_UP, KEY_DOWN]:
				var n := _moves().size()
				var j := clampi(si + (-1 if k == KEY_UP else 1), 0, n - 1)
				if j != si: _pick_move(j)
				return true
		"match":
			return _mem_key(k)
		"rec":
			var L: Array = MD.LINES.get(p.c, [])
			var lo := -1 if memo() else 0
			if k in [KEY_UP, KEY_DOWN]:
				li = clampi(li + (-1 if k == KEY_UP else 1), lo, L.size() - 1)
				if li >= 0 and li < top: top = li
				if li >= 0 and li > top + _rows_fit - 1: top = li - _rows_fit + 1
				p.sfx("ready", 0.12)
				return true
			if k in [KEY_ENTER, KEY_SPACE]:
				if li == -1: _look()
				elif li >= 0 and li < L.size(): _line(li)
				return true
	return false

func wheel(d: int) -> void:
	if p.tab == "rec" and not clean:
		var n: int = MD.LINES.get(p.c, []).size()
		top = clampi(top + d, 0, maxi(0, n - _rows_fit))

## 기억 keys: arrows walk the tree (up from the top row = the level button, down from the bottom row = 초기화), Enter acts, Q / E tabs
func _mem_key(k: int) -> bool:
	var c: String = p.c
	if k in [KEY_ENTER, KEY_SPACE]:
		if sel == "LV": _level()
		elif sel == "RST": _reset()
		elif M().T(c)["on"].has(sel): _drop()
		else: _take()
		return true
	if not k in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]: return false
	if sel in ["LV", "RST"] and k in [KEY_LEFT, KEY_RIGHT]: return false      # the level row: ←→ change tabs as elsewhere
	var nx := sel
	if sel == "LV":
		if k == KEY_DOWN: nx = "A0"
	elif sel == "RST":
		if k == KEY_UP: nx = "C0"
	elif sel[0] == "X":
		var i := int(sel.substr(1))
		if k == KEY_UP:
			nx = "LV" if i == 0 else "X" + str(i - 1)
		elif k == KEY_DOWN:
			nx = "RST" if i == 3 else "X" + str(i + 1)
		elif k == KEY_LEFT:
			nx = ["A6", "B6", "B6", "C6"][i]
	else:
		var r := "ABC".find(sel[0])
		var i := int(sel.substr(1))
		if k == KEY_LEFT:
			if i > 0: nx = sel[0] + str(i - 1)
		elif k == KEY_RIGHT:
			nx = sel[0] + str(i + 1) if i < 6 else "X" + str([0, 1, 3][r])
		elif k == KEY_UP:
			nx = "LV" if r == 0 else "ABC".substr(r - 1, 1) + str(i)
		elif k == KEY_DOWN:
			nx = "RST" if r == 2 else "ABC".substr(r + 1, 1) + str(i)
	if nx != sel:
		sel = nx
		p.sfx("ready", 0.12)
	return true


# ---------- actions ----------
func _moves() -> Array:
	return MD.MOVES[p.c].filter(func(m): return not (String(m[0]).begins_with("상단") or String(m[0]).begins_with("공중")))

func _pick_move(j: int) -> void:
	si = j
	shout_t = 0.0
	p.sfx("ready", 0.15)

func _node(id: String) -> void:
	sel = id
	p.sfx("ready", 0.18)

func _take() -> void:
	var id := sel if not sel in ["LV", "RST"] else "A0"
	if not M().take(p.c, id):
		p.sfx("hit", 0.3)
		return
	p.sfx("heavy", 0.5)
	pop = id
	pop_t = 0.0

func _drop() -> void:
	if M().drop(p.c, sel): p.sfx("ready", 0.3)

func _reset() -> void:
	if M().clear_nodes(p.c): p.sfx("ready", 0.4)

func _level() -> void:
	var c: String = p.c
	var A = p.arena
	var P = A.player
	var nb: Dictionary = M().brk_need(c)
	var r: String = M().level_up(c)
	var sh: String = MD.SHORT[c]
	match r:
		"nomat":
			p.sfx("hit", 0.3)
			var mn: Dictionary = MD.MATN[nb["m"]]
			_notice("%s %d개 · %s에서" % [mn["n"], nb["n"], mn["src"]], "돌파", Color(mn["c"]), false, 3600.0)
		"brk":
			p.sfx("heavy", 0.8)
			A.text(P.position + Vector2(0, -170.0 * P.CSCALE), "%s 돌파! 이제 Lv %d로" % [sh, M().lv(c) + 1], Color("#ffe066"))
			_notice(sh + " 돌파", "BREAK", Color("#ffe066"), true, 3200.0)
			pop = "lv"
			pop_t = 0.0
			A.save_now()
		"lv":
			p.sfx("heavy", 0.6)
			var l: int = M().lv(c)
			A.text(P.position + Vector2(0, -170.0 * P.CSCALE), "%s Lv %d%s" % [sh, l, " · 메모리얼 해방!" if l >= MD.MAXLV else ""], Color("#ffe9a8"))
			pop = "lv"
			pop_t = 0.0
			A.save_now()
		_:
			p.sfx("hit", 0.3)

func _notice(s: String, tag: String, col: Color, big: bool, life: float) -> void:
	var F = p.arena.get("fame")
	if F != null and F.has_method("notice"): F.notice(s, tag, col, big, life)
	else: p.arena.text(p.arena.player.position + Vector2(0, -200), s, col)

func say(l: Array) -> void:
	if l.is_empty(): return
	say_l = l
	say_t = 1.0
	if memo():
		hold = 1e9 if l[2] == "smile" else 0.0
	else:
		react = l[2]
		react_t = 0.0
		jolt = "shake" if l[2] == "sup" else "hop"
		jolt_t = 0.0

func _line(i: int) -> void:
	var L: Array = MD.LINES.get(p.c, [])
	if i < 0 or i >= L.size(): return
	var l: Array = L[i]
	var lk: bool = l.size() > 3 and l[3] and not M().unlocked(p.c)
	if lk: return
	li = i
	if l.size() > 3 and l[3]: clean = true
	say(l)

## tapping the standing art on 기록 (talk): the lines in turn; three quick taps = 연타
func talk() -> void:
	var all: Array = MD.LINES.get(p.c, [])
	var L: Array = all.filter(func(l): return not (l.size() > 3 and l[3]) and l[0] != "전투" and l[0] != "연타")
	var now := Time.get_ticks_msec()
	taps = taps.filter(func(x): return now - x < 1300)
	taps.append(now)
	if taps.size() >= 3:
		taps = []
		for l in all:
			if l[0] == "연타":
				say(l)
				return
	if not L.is_empty():
		ti += 1
		say(L[ti % L.size()])

func mem_talk() -> void:
	var L: Array = MD.LINES.get(p.c, []).filter(func(l): return l.size() > 3 and l[3])
	if L.is_empty(): return
	mi += 1
	say(L[mi % L.size()])

func _look() -> void:
	clean = true
	p.sfx("ready", 0.2)

func _unclean() -> void:
	clean = false
	say_t = 0.0
	hold = 0.0


# ---------- drawing helpers ----------
func use(x: Transform2D) -> void:
	xf = x
	p.draw_set_transform_matrix(x)

func reset_xf() -> void:
	xf = Transform2D.IDENTITY
	p.draw_set_transform(Vector2.ZERO)

func hitr(r: Rect2, cb: Callable) -> void:
	p.hit(PackedVector2Array([xf * r.position, xf * Vector2(r.end.x, r.position.y), xf * r.end, xf * Vector2(r.position.x, r.end.y)]), cb)

func hitp(poly: PackedVector2Array, cb: Callable) -> void:
	p.hit(xf * poly, cb)

## a box turned about its centre (CSS rotate), as a transform whose origin is the box's top-left
static func box_xf(r: Rect2, deg: float, sc := Vector2.ONE) -> Transform2D:
	var c := r.get_center()
	return Transform2D(0.0, Vector2.ONE, 0.0, c) * Transform2D(deg_to_rad(deg), sc, 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2.ONE, 0.0, -r.size / 2.0)

static func pct(vs: Vector2, a: Array) -> Rect2:
	return Rect2(vs.x * a[0] / 100.0, vs.y * a[1] / 100.0, vs.x * a[2] / 100.0, vs.y * a[3] / 100.0 if a.size() > 3 else 20.0)

func tw(f: Font, s: String, fs: int) -> float:
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

## skewed black tag (the .mhd spans, .role)
func tag(x: float, y: float, s: String, fs: int, bg: Color, fg: Color, f: Font = null) -> float:
	if f == null: f = UI.bhs()
	var w := tw(f, s, fs) + 16.0
	UI.para(p, x, y, w, fs + 6.0, -(fs + 6.0) * 0.18, bg)
	p.draw_string(f, Vector2(x + 8.0, y + fs + 1.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
	return w

## art with the CSS drop-shadow look: a black offset silhouette, a 3 px white rim, the picture (object-fit: contain, bottom)
func cutout(path: String, sil: String, box: Rect2, deg: float, sh := Vector2(14, 10), a := 1.0, xx := Transform2D.IDENTITY, flash := 0.0) -> Rect2:
	var t: Texture2D = p.tx(path)
	var s: float = minf(box.size.x / t.get_width(), box.size.y / t.get_height())
	var sz := Vector2(t.get_width(), t.get_height()) * s
	var r := Rect2(box.position.x + (box.size.x - sz.x) / 2.0, box.end.y - sz.y, sz.x, sz.y)
	use(xx * box_xf(box, deg))
	var lr := Rect2(r.position - box.position, r.size)
	var st: Texture2D = p.tx(sil) if sil != "" else null
	if st != null:
		p.draw_texture_rect(st, Rect2(lr.position + sh, lr.size), false, Color(0, 0, 0, a))
		for o in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
			p.draw_texture_rect(st, Rect2(lr.position + o, lr.size), false, Color(1, 1, 1, a))
	else:
		p.draw_texture_rect(t, Rect2(lr.position + sh, lr.size), false, Color(0, 0, 0, a))
	p.draw_texture_rect(t, lr, false, Color(1, 1, 1, a))
	if flash > 0.0 and st != null: p.draw_texture_rect(st, lr, false, Color(1, 1, 1, flash))
	reset_xf()
	return r

## the ground of a tab: theme colour, rays, dots, the black shard, the light edge, the white slash, the big outlined name
func ground(vs: Vector2, col: Color, k: String) -> void:
	var S: Dictionary = SPEC[k]
	var T = p.trn
	# every piece glides to the tab's place (.shard / .edge / .slash .7s --mv, .bigen .8s, the burst centre .7s); clip-paths
	# with the same number of points morph, others snap (as CSS does)
	p.draw_rect(Rect2(Vector2.ZERO, vs), col)
	var bu: Array = T.get_v("g_burst", [float(S["burst"][0]), float(S["burst"][1])], 700.0, "mv")
	UI.burst(p, Vector2(vs.x * bu[0] / 100.0, vs.y * bu[1] / 100.0), maxf(vs.x, vs.y) * 1.3, 0.15, p.t / 70000.0 * TAU)
	# .dots follow the pointer a little (translate(--px·6px, --py·4px))
	var pp: Vector2 = p.ptr(vs)
	use(Transform2D(0.0, Vector2(pp.x * 6.0, pp.y * 4.0)))
	UI.dots(p, Rect2(-8, -6, vs.x * 0.45 + 8.0, vs.y + 12.0), 0.3, 1.0)
	_dots_in(Rect2(vs.x * 0.7, -6, vs.x * 0.3 + 8.0, vs.y + 12.0))
	reset_xf()
	for part in [["shard", Color.BLACK], ["edge", UI.col2(p.c)]]:
		var sd: Array = S[part[0]]
		var rr: Array = T.get_v("g_" + part[0], (sd[0] as Array).map(func(v): return float(v)) + [float(sd[1])], 700.0, "mv")
		var cl: Array = []
		for q in sd[2]: cl += [float(q[0]), float(q[1])]
		var cv: Array = T.get_v("g_%s_clip%d" % [part[0], cl.size()], cl, 700.0, "mv")
		var pts: Array = []
		for i in range(0, cv.size(), 2): pts.append([cv[i], cv[i + 1]])
		var r := pct(vs, [rr[0], rr[1], rr[2], rr[3]])
		p.draw_colored_polygon(UI.rot(UI.clip(r, pts), r.get_center(), deg_to_rad(rr[4])), part[1])
	var sl: Array = S["slash"]
	var sv: Array = T.get_v("g_slash", (sl[0] as Array).map(func(v): return float(v)) + [float(sl[1])], 700.0, "mv")
	var r2 := pct(vs, [sv[0], sv[1], sv[2]])
	p.draw_colored_polygon(UI.rot(UI.clip(r2, [[0, 40], [100, 0], [100, 30], [3, 100]]), r2.get_center(), deg_to_rad(sv[3])), Color.WHITE)
	var bg: Array = T.get_v("g_bigen", (S["bigen"] as Array).map(func(v): return float(v)), 800.0, "mv")
	var fs := int(vs.y * 0.34)
	use(Transform2D(deg_to_rad(bg[2]), Vector2(vs.x * bg[0] / 100.0, vs.y * bg[1] / 100.0)))
	p.draw_string_outline(UI.anton(), Vector2(0, fs * 0.8), UI.EN[p.c], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0, 0, 0, 0.26))
	reset_xf()

## dots fading in towards the right edge (the other end of the CSS mask)
func _dots_in(r: Rect2) -> void:
	var tex := UI.dot_tile(0.3)
	var n := 10
	for i in n:
		var x0 := r.position.x + r.size.x * i / n
		p.draw_texture_rect_region(tex, Rect2(x0, r.position.y, r.size.x / n + 1.0, r.size.y), Rect2(x0, r.position.y, r.size.x / n + 1.0, r.size.y), Color(1, 1, 1, float(i + 1) / n))

## enter ease of the panes' items (.it, staggered)
func ease_in(i: int) -> float:
	# .pane.in .it: translateX(60px) rotate(6deg), opacity 0 → .5s --bk, 40 ms apart
	return UI.bk(clampf((p.tab_t - i * 40.0) / 500.0, 0.0, 1.0))


# ---------- the three tabs ----------
func paint(vs: Vector2, col: Color) -> void:
	match p.tab:
		"skill": _skill(vs, col)
		"match": _mem(vs, col)
		"rec": _rec(vs, col)
	_sub(vs, col)

## 스킬: the skill art sweeping in from the left, the moves as slanted blades, the picked one shouted on a torn card
func _skill(vs: Vector2, col: Color) -> void:
	ground(vs, col, "skill")
	var c: String = p.c
	var t: Texture2D = p.tx(SK.path(c, "st_skill"))
	var u := clampf(p.tab_t / 500.0, 0.0, 1.0)
	if p.slam_t < p.tab_t: u = clampf(p.slam_t / 500.0, 0.0, 1.0)
	var e := UI.bez(0.1, 1.4, 0.3, 1.0, u)
	var box: Rect2
	var deg := 0.0
	if c == "aida":
		box = Rect2(vs.x * -0.25, vs.y * 0.1, vs.x * 0.84, vs.x * 0.84 * t.get_height() / t.get_width())
		deg = -5.0
	else:
		box = Rect2(vs.x * -0.04, 0, vs.y * t.get_width() / t.get_height(), vs.y)
		deg = -5.0 * (1.0 - e)
	var bc := box.get_center()
	var sk := Transform2D(0.0, Vector2(-0.7 * box.size.x * (1.0 - e), 0) + bc) * Transform2D(Vector2(1, 0), Vector2(tan(deg_to_rad(-26.0 * (1.0 - e))), 1), Vector2.ZERO) * Transform2D(0.0, -bc)
	cutout(SK.path(c, "st_skill"), SK.path(c, "st_skill_sil"), box, deg, Vector2(14, 10), 1.0, sk, clampf(1.0 - u / 0.35, 0.0, 1.0) * 0.6)
	# speed lines racing across as it lands
	var su := clampf(p.tab_t / 550.0, 0.0, 1.0)
	if su < 1.0:
		var a := 1.0 - su
		var off := box.size.x * (0.3 - 0.6 * su)
		use(Transform2D(deg_to_rad(-14.0), box.get_center() + Vector2(off, 0)))
		var y := -box.size.y
		while y < box.size.y:
			for xi in 6:
				var x0 := -box.size.x * 0.5 + box.size.x * xi / 6.0
				var m := clampf(1.0 - absf(float(xi) / 5.0 - 0.45) * 2.4, 0.0, 1.0)
				p.draw_rect(Rect2(x0, y + 22.0, box.size.x / 6.0 + 1.0, 2.0), Color(1, 1, 1, 0.75 * a * m))
			y += 60.0
		reset_xf()
	p._name(Vector2(vs.x * 0.03, vs.y * 0.8 + 34.0))
	# the zone: blades and the shout
	var z := Rect2(vs.x * 0.54, vs.y * 0.14, minf(vs.x * 0.44, 420.0), vs.y * 0.84)
	var L := _moves()
	si = clampi(si, 0, L.size() - 1)
	var sh := z.size.y * 0.54
	for k in L.size():
		var on := k == si
		var ult: bool = String(L[k][0]).find("궁극기") >= 0
		var e2 := ease_in(k)
		var r := Rect2(z.position.x + z.size.x * 0.03 * k + 40.0 * (1.0 - e2), z.position.y + sh * 0.19 * k, z.size.x * (0.92 - 0.01 * k), sh * 0.22)
		var sc := 1.05 if on else 1.0
		use(Transform2D(0.0, r.get_center() + Vector2(-18.0 if on else 0.0, 0)) * Transform2D(deg_to_rad(k * 1.4 - 3.0), Vector2(sc, sc), 0.0, -r.size / 2.0))
		var lr := Rect2(Vector2.ZERO, r.size)
		var poly := UI.clip(lr, [[0, 8], [100, 0], [98, 100], [2, 92]])
		var bgc: Color = Color.WHITE if on else (col if ult else Color.BLACK)
		p.draw_colored_polygon(poly, Color(bgc, e2))
		var num := "0%d" % (k + 1)
		var nc: Color = col if on else (Color.BLACK if ult else col)
		p.draw_string(UI.anton(), Vector2(14, lr.size.y * 0.5 + 6.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(nc, e2))
		p.draw_string(UI.bhs(), Vector2(22.0 + tw(UI.anton(), num, 13), lr.size.y * 0.5 + 7.0), L[k][0], HORIZONTAL_ALIGNMENT_LEFT, lr.size.x - 60.0, 17, Color(Color.BLACK if on or ult else Color.WHITE, e2))
		var kk := k
		hitp(poly, func(): if si != kk: _pick_move(kk))
		reset_xf()
	# the shout
	var mv: Array = L[si]
	var sr := Rect2(z.position.x + z.size.x * 0.04, z.position.y + z.size.y * 0.6, z.size.x * 0.94, 0.0)
	var tw2 := sr.size.x - 44.0
	var ph := UI.bhs().get_multiline_string_size(mv[0], HORIZONTAL_ALIGNMENT_LEFT, tw2, 22).y + 4.0 + UI.noto().get_multiline_string_size(mv[1], HORIZONTAL_ALIGNMENT_LEFT, tw2, 12).y * 1.1 + 34.0
	sr.size.y = maxf(z.size.y * 0.3, ph)
	if sr.end.y > vs.y - 6.0: sr.position.y = vs.y - 6.0 - sr.size.y
	var pu := UI.bk(clampf(shout_t / 450.0, 0.0, 1.0)) if shout_t < 450.0 else 1.0
	var pe := ease_in(L.size())
	var a2 := minf(pu, pe) if shout_t < 450.0 else pe
	use(box_xf(sr, -2.0 - 12.0 * (1.0 - pu), Vector2.ONE * (0.5 + 0.5 * pu)))
	var spoly := UI.clip(Rect2(Vector2.ZERO, sr.size), [[0, 12], [8, 0], [40, 6], [72, 0], [100, 10], [97, 52], [100, 92], [62, 100], [24, 94], [2, 100], [3, 52]])
	p.draw_colored_polygon(spoly, Color(1, 1, 1, a2))
	var hy := 16.0 + UI.bhs().get_multiline_string_size(mv[0], HORIZONTAL_ALIGNMENT_LEFT, tw2, 22).y
	p.draw_multiline_string(UI.bhs(), Vector2(22, 16.0 + UI.bhs().get_ascent(22)), mv[0], HORIZONTAL_ALIGNMENT_LEFT, tw2, 22, -1, Color(0, 0, 0, a2))
	p.draw_multiline_string(UI.noto(), Vector2(22, hy + 4.0 + UI.noto().get_ascent(12)), mv[1], HORIZONTAL_ALIGNMENT_LEFT, tw2, 12, -1, Color(0, 0, 0, a2))
	reset_xf()

## 기억: the rec art at the right, the level row, the tree (three branches + cross column), the picked node's card
func _mem(vs: Vector2, col: Color) -> void:
	ground(vs, col, "match")
	var c: String = p.c
	var Mm = M()
	# the art (cx_xrec: swings in from the right, then breathes)
	var u := clampf(minf(p.tab_t, p.slam_t) / 750.0, 0.0, 1.0)
	var e := UI.bk(u)
	var hh := vs.y * 0.96
	var box := Rect2(vs.x * 0.98 - hh, vs.y * 0.06, hh, hh)
	var br := sin(p.t / 4600.0 * TAU) * 0.5 + 0.5
	var xx := Transform2D(0.0, Vector2(0.35 * hh * (1.0 - e), -6.0 * br))
	var scx := lerpf(0.34 * 0.85, 1.0, e)
	var scy := lerpf(0.85, 1.0, e)
	xx = xx * Transform2D(0.0, box.get_center()) * Transform2D(0.0, Vector2(scx, scy), 0.0, Vector2.ZERO) * Transform2D(0.0, -box.get_center())
	cutout(SK.path(c, "st_rec"), SK.path(c, "st_rec_sil"), box, lerpf(10.0, -2.0, e), Vector2(14, 10), clampf(e, 0.0, 1.0), xx)
	p._name(Vector2(vs.x * 0.04, vs.y * 0.84 + 34.0))
	# the zone, turned −4°
	var z := Rect2(vs.x * 0.02, vs.y * 0.17, vs.x * 0.55, vs.y * 0.8)
	var T: Dictionary = Mm.T(c)
	var on: Array = T["on"]
	var pts: int = Mm.pts_left(c)
	if not sel in ["LV", "RST"] and Mm.node_def(c, sel) == null: sel = "A0"
	var Z := box_xf(z, -4.0)
	# the tree
	var tr := Rect2(z.size.x * 0.02, z.size.y * 0.13, z.size.x * 0.96, z.size.y * 0.52)
	use(Z)
	var tp := func(x: float, y: float) -> Vector2: return tr.position + Vector2(tr.size.x * x / 100.0, tr.size.y * y / 100.0)
	# gate labels
	var gates := [[NX[3], "II·Lv4", false], [NX[5], "III·Lv7", false], [NX[6], "KEY·Lv10", false], [85, "혼합·Lv5", true]]
	for g in gates:
		var gp: Vector2 = tp.call(g[0], 6)
		var f := UI.anton(true)
		var w := tw(f, g[1], 9) + 8.0
		UI.para(p, gp.x - w / 2.0, gp.y - 7.0, w, 13, -2.0, Color.BLACK)
		p.draw_rect(Rect2(gp.x - w / 2.0 - 2.0, gp.y + 6.0, w, 2), Color.WHITE if g[2] else col)
		p.draw_string(f, Vector2(gp.x - w / 2.0 + 4.0, gp.y + 3.5), g[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
	# branch labels with their five pips (2, 3, 5 are the gates)
	for b in 3:
		var k: int = Mm.br_count(on, "ABC"[b])
		var gp: Vector2 = tp.call(0, NY[b])
		var nm: String = MD.BR[c][b]
		var w := maxf(tw(UI.bhs(), nm, 12), 5 * 9.0) + 16.0
		var e2 := ease_in(b)
		UI.para(p, gp.x - 30.0 * (1.0 - e2), gp.y - 17.0, w, 30, -5.0, Color(UI.col2(c), e2))
		p.draw_string(UI.bhs(), Vector2(gp.x + 8.0, gp.y - 3.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, e2))
		for q in 5:
			var ph := 8.0 if q in [1, 2, 4] else 6.0
			UI.para(p, gp.x + 6.0 + q * 9.0, gp.y + 3.0 + (8.0 - ph), 7, ph, -1.0, Color(col, e2) if k >= q + 1 else Color(0, 0, 0, 0.25 * e2))
	# nodes
	var pulse := sin(p.t / 1200.0 * TAU) * 0.5 + 0.5
	var i := 0
	for id in Mm.node_ids():
		var pos: Vector2
		var t0 := int(id.substr(1))
		if id[0] == "X": pos = tp.call(XPOS[t0][0], XPOS[t0][1])
		else: pos = tp.call(NX[t0], NY["ABC".find(id[0])])
		var got: bool = on.has(id)
		var can: bool = Mm.can_take(c, id)
		var lock: bool = not got and not can and Mm.node_need(c, id, on + [id]) != ""
		var hx: bool = id[0] == "X"
		var sz := 26.0 if hx else (34.0 if t0 == 6 else (30.0 if t0 >= 3 else 24.0))
		var e3 := ease_in(3 + i / 3)
		var s := sz / 2.0 * e3
		if pop == id and pop_t < 600.0: s *= 1.0 + 1.2 * (1.0 - UI.bk(pop_t / 600.0))
		var a := 0.38 if lock else 1.0
		var dia := func(rr: float) -> PackedVector2Array: return PackedVector2Array([pos + Vector2(0, -rr), pos + Vector2(rr, 0), pos + Vector2(0, rr), pos + Vector2(-rr, 0)])
		var rim := Color("#555")
		var fill := Color("#222")
		var inner := Color("#333")
		if got:
			rim = Color.BLACK
			fill = Color.WHITE
			inner = col
		elif can:
			rim = Color.WHITE
			fill = Color.BLACK
			inner = Color.WHITE
		elif hx:
			rim = Color.WHITE
			fill = Color("#111")
		if t0 == 6 and not hx and not got and not can: rim = col
		if t0 == 6 and not hx and got: rim = col
		if lock and not hx: fill = Color.BLACK          # .mn.lock: black, its left border 4 px in her colour
		var k2 := 1.4142
		if can: p.draw_colored_polygon(dia.call(s * k2 + 7.0 * pulse), Color(col, 0.6 * (1.0 - pulse) * a))
		if id == sel: p.draw_polyline(_closed(dia.call(s * k2 + 6.0)), Color.WHITE, 3.0)
		p.draw_colored_polygon(dia.call(s * k2), Color(rim, a))
		if lock and s * k2 > 6.0 * k2:
			# the element's left side, turned 45°: the top-left edge, 4 px deep
			var o: PackedVector2Array = dia.call(s * k2)
			var n: PackedVector2Array = dia.call(s * k2 - 4.0 * k2)
			p.draw_colored_polygon(PackedVector2Array([o[3], o[0], n[0], n[3]]), Color(col, a))
		p.draw_colored_polygon(dia.call(s * k2 - 3.0 * k2), Color(fill, a))
		var ri := maxf(1.0, s * k2 - 8.0 * k2)
		if hx and not got:
			var d: PackedVector2Array = dia.call(ri)
			p.draw_colored_polygon(PackedVector2Array([d[0], d[1], d[3]]), Color(col, a))
			p.draw_colored_polygon(PackedVector2Array([d[1], d[2], d[3]]), Color(1, 1, 1, a))
		else:
			p.draw_colored_polygon(dia.call(ri), Color(inner, a))
		var idc: String = id
		hitp(dia.call(maxf(s * k2, 16.0) + 4.0), func(): _node(idc))
		i += 1
	# the head row: MEMORY · Lv · 포인트 · 기억석 · level button (wraps)
	var x := 0.0
	var y := -z.size.y * 0.02
	p.draw_string(UI.anton(), Vector2(x, y + 28.0), "MEMORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
	x += tw(UI.anton(), "MEMORY", 30) + 10.0
	var heads := [["Lv ", str(T["lv"]), "/%d · 누적 %d/%d" % [MD.MAXLV, MD.LVCUM[T["lv"]], MD.LVCUM[MD.MAXLV]]], ["포인트 ", str(pts), ""], ["기억석 ", str(R().mem), ""]]
	for hd in heads:
		var w := tw(UI.bhs(), hd[0], 13) + tw(UI.bhs(), hd[1], 16) + tw(UI.bhs(), hd[2], 13) + 16.0
		if x + w > z.size.x:
			x = 0.0
			y += 30.0
		var sc2 := 1.0
		if hd[0] == "Lv " and pop == "lv" and pop_t < 600.0: sc2 = 1.0 + 0.6 * (1.0 - UI.bk(pop_t / 600.0))
		var hp0 := Vector2(x, y + 10.0)
		use(Z * Transform2D(0.0, Vector2(sc2, sc2), 0.0, hp0))
		UI.para(p, 0, 0, w, 20, -3.6, Color.BLACK)
		var xx2 := 8.0
		p.draw_string(UI.bhs(), Vector2(xx2, 16), hd[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		xx2 += tw(UI.bhs(), hd[0], 13)
		p.draw_string(UI.bhs(), Vector2(xx2, 17), hd[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		xx2 += tw(UI.bhs(), hd[1], 16)
		p.draw_string(UI.bhs(), Vector2(xx2, 16), hd[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		use(Z)
		x += w + 10.0
	# the level / 돌파 button
	var nb: Dictionary = Mm.brk_need(c)
	var label := ""
	var bgc := col
	var fgc := Color.BLACK
	var small := ""
	if int(T["lv"]) >= MD.MAXLV:
		label = "MAX · 메모리얼 해방"
		bgc = Color.BLACK
		fgc = Color.WHITE
	elif not nb.is_empty():
		var have: int = Mm.mat_have(nb["m"])
		label = "돌파 · %s %d/%d" % [Mm.mat_name(nb["m"]), have, nb["n"]]
		small = Mm.lv_preview(c)
		bgc = Color("#ffe066") if have >= int(nb["n"]) else Color("#3a3a3a")
		fgc = Color.BLACK if have >= int(nb["n"]) else Color("#ffe066")
	else:
		var cost: int = Mm.lv_cost(int(T["lv"]))
		label = "레벨 업 · 기억석 %d" % cost
		small = Mm.lv_preview(c)
		if R().mem < cost: bgc = Color("#777")
	var bw := maxf(tw(UI.bhs(), label, 14), tw(UI.bhs(), small, 10)) + 24.0
	var bh := 36.0 if small != "" else 22.0
	if x + bw > z.size.x:
		x = 0.0
		y += 30.0
	var brc := Rect2(x, y + 6.0, bw, bh)
	var skx := -bh * 0.18
	if small != "": UI.para(p, brc.position.x + 3.0, brc.position.y + 3.0, bw, bh, skx, Color.BLACK)
	UI.para(p, brc.position.x, brc.position.y, bw, bh, skx, bgc)
	if sel == "LV": p.draw_polyline(_closed(PackedVector2Array([brc.position + Vector2(skx - 3, -3), Vector2(brc.end.x + skx + 3, brc.position.y - 3), brc.end + Vector2(3, 3), Vector2(brc.position.x - 3, brc.end.y + 3)])), Color.WHITE, 2.0)
	p.draw_string(UI.bhs(), brc.position + Vector2(12, 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fgc)
	if small != "": p.draw_string(UI.bhs(), brc.position + Vector2(12, 31), small, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(fgc, 0.8))
	if int(T["lv"]) < MD.MAXLV: hitr(brc.grow(3), func():
		sel = "LV"
		_level())
	# the card of the picked node
	reset_xf()
	_mcard(z, Z, col)

static func _closed(a: PackedVector2Array) -> PackedVector2Array:
	var b := a.duplicate()
	b.append(a[0])
	return b

func _mcard(z: Rect2, Z: Transform2D, col: Color) -> void:
	var c: String = p.c
	var Mm = M()
	var id := sel if not sel in ["LV", "RST"] else "A0"
	var d: Dictionary = Mm.node_def(c, id)
	var on: Array = Mm.T(c)["on"]
	var has: bool = on.has(id)
	var why: String = Mm.node_need(c, id, on + [id])
	var brk: bool = has and Mm.held(c, id)
	var st := "활성화됨" if has else (why if why != "" else ("포인트 부족" if Mm.pts_left(c) <= 0 else "활성화 가능"))
	var w := z.size.x * 0.54
	var tw2 := w - 24.0
	var dh := UI.noto().get_multiline_string_size(d["d"], HORIZONTAL_ALIGNMENT_LEFT, tw2, 12).y
	var h := 8.0 + 14.0 + 26.0 + dh + 8.0 + 26.0 + 10.0
	var r := Rect2(z.size.x - w, z.size.y * 0.96 - h, w, h)
	var e := ease_in(12)
	use(Z * box_xf(Rect2(r.position + Vector2(30.0 * (1.0 - e), 0), r.size), 6.0))
	var lr := Rect2(Vector2.ZERO, r.size)
	p.draw_colored_polygon(UI.clip(lr, [[0, 6], [100, 0], [96, 100], [3, 94]]), Color(1, 1, 1, e))
	p.draw_string(UI.spaced(UI.noto_k(), 1), Vector2(12, 20), st, HORIZONTAL_ALIGNMENT_LEFT, tw2, 11, Color(col.darkened(0.15), e))
	p.draw_string(UI.bhs(), Vector2(12, 46), d["n"], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color(0, 0, 0, e))
	var tg: String = Mm.tier_name(c, id)
	var tx0 := 12.0 + tw(UI.bhs(), d["n"], 21) + 8.0
	var tgw := tw(UI.bhs(), tg, 11) + 12.0
	if tx0 + tgw > w - 8.0: tx0 = w - 8.0 - tgw
	UI.para(p, tx0, 30, tgw, 17, -3.0, Color(0, 0, 0, e))
	p.draw_string(UI.bhs(), Vector2(tx0 + 6.0, 43), tg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, e))
	p.draw_multiline_string(UI.noto(), Vector2(12, 54 + UI.noto().get_ascent(12)), d["d"], HORIZONTAL_ALIGNMENT_LEFT, tw2, 12, -1, Color(0.2, 0.2, 0.2, e))
	var by := 54.0 + dh + 8.0
	var bx := 12.0
	var go: String
	var no := false
	if has:
		go = "다른 노드가 기대고 있음" if brk else "해제"
		no = brk
	else:
		go = "활성화"
		no = not Mm.can_take(c, id)
	var gw := tw(UI.bhs(), go, 15) + 28.0
	UI.para(p, bx, by, gw, 24, -4.0, Color(Color("#888") if no else Color.BLACK, e))
	p.draw_string(UI.bhs(), Vector2(bx + 14.0, by + 18.0), go, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, e))
	hitr(Rect2(bx, by, gw, 24), func():
		if has: _drop()
		elif no: p.sfx("hit", 0.3)
		else: _take())
	bx += gw + 6.0
	var rw := tw(UI.bhs(), "초기화", 12) + 18.0
	var rr := Rect2(bx, by + 2.0, rw, 20)
	var rp := PackedVector2Array([rr.position + Vector2(3, 0), Vector2(rr.end.x + 3.0, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)])
	p.draw_polyline(_closed(rp), Color(0, 0, 0, e), 2.0)
	if sel == "RST": p.draw_colored_polygon(rp, Color(col, 0.35 * e))
	p.draw_string(UI.bhs(), Vector2(bx + 9.0, by + 17.0), "초기화", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, e))
	hitr(rr, func(): _reset())
	reset_xf()

## 기록: the dossier, the memorial lock, the lines; at Lv 12 the memorial art fills the page
var _rows_fit := 6

func _rec(vs: Vector2, col: Color) -> void:
	var c: String = p.c
	var un: bool = M().unlocked(c)
	if un:
		_memo_art(vs, col)
		if clean:
			_clean_x(vs)
			return
	else:
		ground(vs, col, "rec")
		_stand(vs)
	p._name(Vector2(vs.x * 0.04, vs.y * (0.15 if un else 0.17) + 34.0))
	var z := Rect2(vs.x * 0.03, vs.y * (0.34 if un else 0.33), vs.x * (0.38 if un else 0.52), vs.y * (0.64 if un else 0.65))
	var Z := box_xf(z, -2.0 if un else 4.0)
	use(Z)
	var y := 0.0
	var e := ease_in(0)
	# RECORD No.0n
	var rfs := 36 if un else 34
	if un: p.draw_string(UI.anton(), Vector2(3, y + rfs * 0.92 + 3.0), "RECORD", HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(col, e))
	p.draw_string(UI.anton(), Vector2(0, y + rfs * 0.92), "RECORD", HORIZONTAL_ALIGNMENT_LEFT, -1, rfs, Color(Color.WHITE if un else col, e))
	var no := "No.0%d" % (["estelle", "aida", "luce"].find(c) + 1)
	p.draw_string(UI.spaced(UI.anton(), 3), Vector2(tw(UI.anton(), "RECORD", rfs) + 8.0, y + rfs * 0.92), no, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, e))
	if un:
		var lw := tw(UI.bhs(), "감상", 14) + 40.0
		var lr := Rect2(z.size.x * 0.96 - lw, 4.0, lw, 24)
		UI.para(p, lr.position.x - 2.0, lr.position.y - 2.0, lw + 4.0, 28, -4.0, Color.WHITE)
		UI.para(p, lr.position.x, lr.position.y, lw, 24, -4.0, Color.BLACK)
		if li == -1: p.draw_rect(Rect2(lr.position.x - 4.0, lr.end.y + 4.0, lw + 4.0, 3), col)
		var oc := lr.position + Vector2(19, 12)            # ◎ (the fonts lack it)
		p.draw_arc(oc, 6.0, 0, TAU, 20, Color.WHITE, 1.6, true)
		p.draw_circle(oc, 2.6, Color.WHITE)
		p.draw_string(UI.bhs(), lr.position + Vector2(30, 18), "감상", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		hitr(lr, func(): _look())
	y += rfs + 8.0
	# the dossier
	var prof: String = MD.PROF.get(c, {}).get("one", "— 작성 예정")
	var dos := [["이명", "— 작성 예정"], ["소속", "길드 《어설픈 용맹》"], ["입단", "— 작성 예정"], ["한마디", prof]]
	var cols := 2 if un else 4
	var cw := (z.size.x - 4.0 * (cols - 1)) / cols
	var rowh := 0.0
	for j in dos.size():
		var dh := UI.noto().get_multiline_string_size(dos[j][1], HORIZONTAL_ALIGNMENT_LEFT, cw - 16.0, 11).y + 20.0
		rowh = maxf(rowh, dh)
	for j in dos.size():
		var cx := (j % cols) * (cw + 4.0)
		var cy := y + (j / cols) * (rowh + 4.0)
		var e2 := ease_in(1 + j)
		var rr := Rect2(cx, cy, cw, rowh)
		if un:
			p.draw_rect(rr, Color(12 / 255.0, 10 / 255.0, 30 / 255.0, 0.55 * e2))
			p.draw_rect(Rect2(rr.position, Vector2(3, rr.size.y)), Color(col, e2))
		else:
			var odd := j % 2 == 1
			if odd: use(Z * box_xf(Rect2(rr.position + Vector2(0, 5), rr.size), 1.5))
			var lr := Rect2(rr.position + (Vector2(0, 5) if odd else Vector2.ZERO), rr.size) if not odd else Rect2(Vector2.ZERO, rr.size)
			p.draw_colored_polygon(UI.clip(lr, [[0, 0], [100, 6], [97, 100], [2, 94]]), Color(1, 1, 1, e2))
			rr = lr
		var tcol := Color.WHITE if un else Color.BLACK
		p.draw_string(UI.spaced(UI.noto_k(), 2), rr.position + Vector2(9, 13), dos[j][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col.darkened(0.15) if not un else col, e2))
		p.draw_multiline_string(UI.noto(), rr.position + Vector2(9, 17.0 + UI.noto().get_ascent(11)), dos[j][1], HORIZONTAL_ALIGNMENT_LEFT, cw - 16.0, 11, -1, Color(tcol, e2))
		use(Z)
	y += ceil(dos.size() / float(cols)) * (rowh + 4.0) + (6.0 if not un else 2.0)
	# the memorial lock
	if not un:
		var e3 := ease_in(5)
		p.draw_rect(Rect2(0, y, z.size.x, 26), Color(0, 0, 0, e3))
		p.draw_rect(Rect2(0, y, 4, 26), Color(col, e3))
		p.draw_string(UI.spaced(UI.anton(), 3), Vector2(12, y + 19), "MEMORIAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col, e3))
		p.draw_string(UI.noto(), Vector2(24.0 + tw(UI.spaced(UI.anton(), 3), "MEMORIAL", 14), y + 18), "기억 탭에서 Lv 12에 도달하면 열립니다.", HORIZONTAL_ALIGNMENT_LEFT, z.size.x - 140.0, 11, Color(0.8, 0.8, 0.8, e3))
		y += 32.0
	# the lines
	var L: Array = MD.LINES.get(c, [])
	var open_n := 0
	for l in L:
		if not (l.size() > 3 and l[3]) or un: open_n += 1
	var e4 := ease_in(6)
	var vr := Rect2(0, y, z.size.x, z.size.y - y)
	p.draw_rect(vr, Color(12 / 255.0, 10 / 255.0, 30 / 255.0, 0.45 * e4) if un else Color(0, 0, 0, 0.35 * e4))
	p.draw_rect(Rect2(0, y, z.size.x, 24), Color(0, 0, 0, 0.75 * e4))
	p.draw_string(UI.bhs(), Vector2(10, y + 18), "대사집", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, e4))
	p.draw_string(UI.anton(), Vector2(18.0 + tw(UI.bhs(), "대사집", 14), y + 18), "%d / %d" % [open_n, L.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, e4))
	var yy := y + 28.0
	var iw := z.size.x - 78.0
	var fit := 0
	top = clampi(top, 0, maxi(0, L.size() - 1))
	for j in range(top, L.size()):
		var l: Array = L[j]
		var lk: bool = l.size() > 3 and l[3] and not un
		var s: String = "🔒 메모리얼을 열면 들을 수 있습니다" if lk else l[1]
		var h := UI.noto().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, iw, 12).y + 10.0
		if yy + h > vr.end.y - 2.0 and fit > 0: break
		var rr := Rect2(0, yy - 2.0, z.size.x - 18.0, h)
		if j == li: p.draw_rect(rr, Color(1, 1, 1, 0.1 * e4))
		if say_t > 0.0 and say_l == l: p.draw_rect(Rect2(0, rr.position.y, 3, rr.size.y), col)
		p.draw_string(UI.bhs(), Vector2(10, yy + 14), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(col, e4))
		if lk:                                                  # 🔒 (no font has it): a small padlock, then the words
			var lc := Vector2(72, yy + 9.0)
			p.draw_arc(lc + Vector2(0, -1), 3.2, PI, TAU, 10, Color(0.53, 0.53, 0.53, e4), 1.6, true)
			p.draw_rect(Rect2(lc.x - 4.5, lc.y - 1.0, 9, 7), Color(0.53, 0.53, 0.53, e4))
			p.draw_multiline_string(UI.noto(), Vector2(82, yy + 1.0 + UI.noto().get_ascent(12)), s.substr(2), HORIZONTAL_ALIGNMENT_LEFT, iw - 16.0, 12, -1, Color(Color("#888"), e4))
		else:
			p.draw_multiline_string(UI.noto(), Vector2(66, yy + 1.0 + UI.noto().get_ascent(12)), s, HORIZONTAL_ALIGNMENT_LEFT, iw, 12, -1, Color(Color("#eee"), e4))
		p.draw_rect(Rect2(0, rr.end.y - 1.0, rr.size.x, 1), Color(1, 1, 1, 0.08 * e4))
		var jj := j
		hitr(rr, func(): _line(jj))
		yy += h
		fit += 1
	_rows_fit = maxi(1, fit)
	# scroll arrows (touch has no wheel)
	if top > 0 or top + fit < L.size():
		var ax := z.size.x - 14.0
		var up_r := Rect2(ax - 8.0, y + 26.0, 20, 22)
		var dn_r := Rect2(ax - 8.0, vr.end.y - 24.0, 20, 22)
		p.draw_colored_polygon(PackedVector2Array([up_r.get_center() + Vector2(0, -6), up_r.get_center() + Vector2(6, 4), up_r.get_center() + Vector2(-6, 4)]), Color(col, e4 * (1.0 if top > 0 else 0.25)))
		p.draw_colored_polygon(PackedVector2Array([dn_r.get_center() + Vector2(0, 6), dn_r.get_center() + Vector2(6, -4), dn_r.get_center() + Vector2(-6, -4)]), Color(col, e4 * (1.0 if top + fit < L.size() else 0.25)))
		hitr(up_r.grow(4), func(): wheel(-1))
		hitr(dn_r.grow(4), func(): wheel(1))
	reset_xf()

## the old standing art (the record keeps it), its face following the line said
func _stand(vs: Vector2) -> void:
	var c: String = p.c
	var face := react if react in ["smile", "sup", "ser"] else "base"
	var box := Rect2(vs.x * 0.56, vs.y * 0.04, vs.y * 1.04 * 2.0 / 3.0, vs.y * 1.04)
	var e := UI.bk(clampf(minf(p.slam_t, p.tab_t) / 600.0, 0.0, 1.0))
	var br := sin(p.t / 4200.0 * TAU) * 0.5 + 0.5
	var j := Vector2(0, -6.0 * br)
	var jr := 0.0
	if jolt_t < 550.0 and jolt == "hop":
		# cx_hop: 30 % up 16 px turned −1.5°, 65 % down 3 px (.55s --bk)
		var k: Array = UIA.kf(jolt_t, [[0.0, [0.0, 0.0]], [0.3, [-16.0, -1.5]], [0.65, [3.0, 0.0]], [1.0, [0.0, 0.0]]], 550.0, 0.0, "bk")
		j.y += k[0]
		jr = k[1]
	if jolt_t < 420.0 and jolt == "shake":
		# cx_shake: −9 / 8 / −5 / 3 px with ∓2° (linear .42s)
		var k2: Array = UIA.kf(jolt_t, [[0.0, [0.0, 0.0]], [0.2, [-9.0, -2.0]], [0.4, [8.0, 2.0]], [0.6, [-5.0, 0.0]], [0.8, [3.0, 0.0]], [1.0, [0.0, 0.0]]], 420.0)
		j.x += k2[0]
		jr = k2[1]
	var xx := Transform2D(0.0, j + Vector2(0.2 * box.size.x * (1.0 - e), 0)) * UIA.xf(box.get_center() + Vector2(0, box.size.y / 2.0), Vector2.ZERO, deg_to_rad(jr))
	# a costume with its own full-body shot (초심's st_full) shows it on 기록; 기억 keeps the square st_rec; the original art keeps the old talking faces
	var own_rec: String = SK.path(c, "st_full")
	var r: Rect2
	if own_rec != "":
		r = cutout(own_rec, SK.path(c, "st_full_sil"), box, 2.0 + 8.0 * (1.0 - e), Vector2(18, 10), clampf(e, 0.0, 1.0), xx)
	else:
		r = cutout(ST + c + "_old_" + face + ".webp", ST + c + "_old_base_sil.webp", box, 2.0 + 8.0 * (1.0 - e), Vector2(18, 10), clampf(e, 0.0, 1.0), xx)
	p.hit(Rect2(r.position.x + r.size.x * 0.15, r.position.y, r.size.x * 0.7, r.size.y), func(): talk())
	# cx_emo: a white star with ♪ (or !! after three quick taps) pops off her head (1.2s --bk)
	if jolt_t < 1200.0:
		var hd := r.position + Vector2(r.size.x * 0.55, r.size.y * 0.12)
		var ek: Array = UIA.kf(jolt_t, [[0.0, [0.0, 10.0, 10.0, 0.2, -30.0]], [0.22, [1.0, 40.0, -40.0, 1.15, 10.0]], [0.75, [1.0, 44.0, -46.0, 1.0, 4.0]], [1.0, [0.0, 46.0, -56.0, 0.9, 4.0]]], 1200.0, 0.0, "bk")
		var ec := hd + Vector2(ek[1] + 26.0, ek[2])
		use(UIA.xf(ec, Vector2.ZERO, deg_to_rad(ek[4]), Vector2.ONE * ek[3]))
		var er := Rect2(ec - Vector2(36, 30), Vector2(72, 60))
		p.draw_colored_polygon(UI.clip(er, [[50, 0], [62, 26], [96, 12], [76, 42], [100, 60], [70, 66], [74, 100], [50, 76], [24, 98], [28, 66], [0, 58], [24, 42], [6, 12], [38, 26]]), Color(1, 1, 1, clampf(ek[0], 0.0, 1.0)))
		var es := "!!" if jolt == "shake" else "♪"
		var ef: Font = UI.bhs()
		p.draw_string(ef, ec + Vector2(-tw(ef, es, 30) / 2.0, 11), es, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, clampf(ek[0], 0.0, 1.0)))
		reset_xf()

## the memorial: the mem art over the whole page (zoom-in on arrival, slow drift, stars, a blink now and then)
func _memo_art(vs: Vector2, col: Color) -> void:
	var c: String = p.c
	var t: Texture2D = p.tx(ST + c + "_mem.webp")
	var u := clampf(memo_t / 1600.0, 0.0, 1.0)
	var e := UI.bez(0.2, 0.7, 0.2, 1.0, u)
	var dr := (sin(p.t / 14000.0 * PI) * 0.5 + 0.5)
	var sc := lerpf(1.18, 1.0, e) * (1.0 + 0.05 * dr) * 1.08
	var s: float = maxf(vs.x / t.get_width(), vs.y / t.get_height()) * sc
	var sz := Vector2(t.get_width(), t.get_height()) * s
	var pp: Vector2 = p.ptr(vs)
	var pos := Vector2((vs.x - sz.x) * 0.6, (vs.y - sz.y) * 0.4) - Vector2(vs.x * 0.01 * dr, -vs.y * 0.005 * dr) + Vector2(pp.x * -8.0, pp.y * -5.0)
	p.draw_rect(Rect2(Vector2.ZERO, vs), Color.BLACK)
	p.draw_texture_rect(t, Rect2(pos, sz), false)
	if (blink > 0.0 or hold > 0.0) and u >= 1.0:
		p.draw_texture_rect(p.tx(ST + c + "_mem_c.webp"), Rect2(pos, sz), false)
	# stars
	var tw3 := 0.25 + 0.75 * (sin(p.t / 3200.0 * PI) * 0.5 + 0.5)
	for st in [[12, 18, 1.6], [28, 8, 1.2], [40, 26, 2.0], [72, 12, 1.4], [88, 30, 1.8], [8, 40, 1.2], [94, 6, 1.6]]:
		p.draw_circle(Vector2(vs.x * st[0] / 100.0, vs.y * 0.6 * st[1] / 100.0 / 0.6), st[2], Color(1, 1, 1, tw3))
	# bloom on arrival
	if memo_t < 1400.0:
		var a := 1.0 - memo_t / 1400.0
		p.draw_texture_rect(UI.glow(), Rect2(vs.x * 0.6 - vs.x * 0.75, vs.y * 0.4 - vs.x * 0.75, vs.x * 1.5, vs.x * 1.5), false, Color(1, 1, 1, a))
	var cb := func():
		if clean: mem_talk()
		else: hold = 1400.0
	p.hit(Rect2(Vector2.ZERO, vs), cb)

## 감상: the round ✕ that brings the page back
func _clean_x(vs: Vector2) -> void:
	var c := Vector2(vs.x - 14.0 - 19.0, 10.0 + 19.0)
	p.draw_circle(c, 19.0, Color(0, 0, 0, 0.55))
	p.draw_arc(c, 18.0, 0, TAU, 32, Color(1, 1, 1, 0.7), 2.0, true)
	UI.cross(p, c, 5.0, Color.WHITE, 2.0)
	p.hit(Rect2(c - Vector2(22, 22), Vector2(44, 44)), func(): _unclean())

## the subtitle: who speaks and the line typing out (34 ms a letter)
func _sub(vs: Vector2, col: Color) -> void:
	if say_t <= 0.0 or say_l.is_empty(): return
	var s: String = say_l[1]
	var n := mini(s.length(), int(say_t / 34.0) + 1)
	var txt := s.substr(0, n)
	var life: float = s.length() * 34.0 + 2600.0
	var a := clampf(say_t / 250.0, 0.0, 1.0) * clampf((life - say_t) / 250.0, 0.0, 1.0)
	var rise := 20.0 * (1.0 - UI.bk(clampf(say_t / 350.0, 0.0, 1.0)))
	if clean:
		var w := minf(vs.x * 0.8, 760.0)
		var hh := UI.noto().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, w, 16).y
		var y := vs.y - 22.0 - hh + rise * 0.5
		var pos := Vector2((vs.x - w) / 2.0, y + UI.noto().get_ascent(16))
		p.draw_multiline_string(UI.noto(), pos + Vector2(0, 1), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 16, -1, Color(0, 0, 0, 0.75 * a))
		p.draw_multiline_string(UI.noto(), pos, txt, HORIZONTAL_ALIGNMENT_CENTER, w, 16, -1, Color(1, 1, 1, a))
		return
	var w2 := minf(vs.x * 0.7, 620.0)
	var cx := vs.x * 0.5
	if p.tab == "rec":
		w2 = vs.x * 0.44
		cx = vs.x * 0.76
	var tw4 := w2 - 36.0
	var hh2 := UI.noto().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, tw4, 14).y
	var h := hh2 + 22.0
	var r := Rect2(cx - w2 / 2.0, vs.y - 14.0 - h + rise, w2, h)
	use(Transform2D(Vector2(1, 0), Vector2(tan(deg_to_rad(-6.0)), 1), r.position + Vector2(0, h)) * Transform2D(0.0, Vector2(0, -h)))
	p.draw_rect(Rect2(Vector2.ZERO, r.size), Color(10 / 255.0, 8 / 255.0, 22 / 255.0, 0.82 * a))
	p.draw_rect(Rect2(0, 0, r.size.x, 3), Color(col, a))
	use(Transform2D(0.0, r.position))
	var nm: String = MD.SHORT[p.c]
	var nw := tw(UI.bhs(), nm, 15) + 24.0
	p.draw_rect(Rect2(12, -16, nw, 22), Color(col, a))
	p.draw_string(UI.bhs(), Vector2(24, 1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, a))
	p.draw_multiline_string(UI.noto(), Vector2(18, 12.0 + UI.noto().get_ascent(14)), txt, HORIZONTAL_ALIGNMENT_LEFT, tw4, 14, -1, Color(1, 1, 1, a))
	reset_xf()
