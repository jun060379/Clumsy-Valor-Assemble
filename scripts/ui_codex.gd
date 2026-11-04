extends "res://scripts/ui_page.gd"
## The codex books, 룬 도감 and 적 도감 (prototype codex.js): the book drops onto the desk with a thud, is picked up to fill
## the screen and opens (cover turns over to the endpaper and the shelf plate; the index is on the right page), one spread
## per entry, page turns riffle a few sheets, a red ribbon on the left goes back to the index, page corners step through,
## ✕ closes it: the entry page turns back, the cover shuts, and the book is tossed away.
## Each page face is drawn into its own SubViewport; turning leaves are those textures projected with CSS-like perspective.

const ICON := preload("res://scripts/item_icons.gd")
const COVER := preload("res://assets/codex/cdx_cover.webp")
const EMBLEM := preload("res://assets/codex/cdx_emblem.webp")
const ENDPAPER := preload("res://assets/codex/cdx_endpaper.webp")
const EDGE := preload("res://assets/codex/cdx_edge.webp")
const SERIF := preload("res://assets/fonts/NotoSerifKR-Bold.woff2")     # Noto Serif KR Bold; its fallbacks are set in ui_kit.gd
const DUMMY := preload("res://assets/props/dummy.png")
const PAPER := Color("#efe3c6")
const PAPER2 := Color("#e6d6b2")
const INK := Color("#2e2116")
const INK2 := Color("#5a4632")
const INK3 := Color("#8a7458")
const RED := Color("#9a2a22")
const SLOT := {"w": "무기", "a": "방어구", "x": "장신구"}
## mob idle strips for the bestiary pages: [file, frames, ms]
const SPR := {"goblin": ["goblin_idle", 4, 140], "mush": ["mush_idle", 4, 160], "skel": ["skel_idle", 4, 160], "eye": ["eye_flight", 8, 80], "boss": ["skel_idle", 4, 170]}
const BOOK := {"rune": {"n": "룬 도감", "en": "RUNES", "col": Color("#e8b25a")}, "enemy": {"n": "적 도감", "en": "BESTIARY", "col": Color("#e8243c")}}
const DESK := [Vector2(0, 0.09), -3.0, Vector2(0.56, 0.56)]
const HELD := [Vector2(0, 0), -0.6, Vector2(1, 1)]

var book := "rune"
var list: Array = []
var cur := -1
var busy := false
var from_hub := false
var go_to := ""
# geometry
var pw := 418.0
var ph := 456.0
var em := 15.0
# viewports (page faces)
var vps := {}
var paint := {}                 # vp name -> [kind, arg]
var page_hits := {}             # vp name -> [[Rect2, Callable]]
var ix_scroll := 0.0
# animation clocks (ms); -1 = not running
var phase := ""                 # "drop" / "lift" / "open" / "idle" / "close_flip" / "shut" / "toss"
var ph_t := 0.0
var open_k := 0.0               # 0 closed … 1 open (cover angle and book shift follow it)
var open_from := 0.0
var open_to := 0.0
var open_t := -1.0
var sheets: Array = []          # {a0, a1, t, delay, front, back}
var flip_done: Callable
var flip_t := -1.0
var flip_len := 0.0
var rib_k := 0.0
var x_k := 0.0
var scrim := 0.0
var ttl_k := 0.0
var slash_y := 0.0
var shake_y := 0.0
var thud_done := false


func _ready() -> void:
	super()
	keys = ["best", "codex_rune"]
	UI.chains()
	for n in ["pl", "pr", "fa", "fb", "cf", "cb"]:
		var v := SubViewport.new()
		v.transparent_bg = true
		v.disable_3d = true
		v.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var p := Control.new()
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if n in ["pl", "pr", "fa", "fb"] else CanvasItem.TEXTURE_FILTER_LINEAR
		var nn: String = n
		p.draw.connect(func(): _paint_face(nn, p))
		v.add_child(p)
		add_child(v)
		vps[n] = v
		paint[n] = ["blank", null]
		page_hits[n] = []
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float hue = 0.0; uniform float sat = 1.0; uniform float bri = 1.0;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV) * COLOR; float a = hue; mat3 toY = mat3(vec3(0.299,0.596,0.211), vec3(0.587,-0.274,-0.523), vec3(0.114,-0.322,0.312)); mat3 toR = mat3(vec3(1.0,1.0,1.0), vec3(0.956,-0.272,-1.106), vec3(0.621,-0.647,1.703)); vec3 yiq = toY * c.rgb; float h = atan(yiq.z, yiq.y) + a; float ch = length(yiq.yz) * sat; yiq = vec3(yiq.x, ch * cos(h), ch * sin(h)); c.rgb = clamp(toR * yiq, 0.0, 1.0) * bri; COLOR = c; }"
	var m := ShaderMaterial.new()
	m.shader = sh
	vps["cf"].get_child(0).material = m

func _opened() -> void:
	book = "enemy" if key == "best" else "rune"
	from_hub = menu.from_hub
	list = book_list()
	cur = -1
	ix_scroll = 0.0
	_size()
	_setp("pr", "index")
	_setp("pl", "blank")
	_setp("cf", "cover")
	_setp("cb", "plate")
	var m: ShaderMaterial = vps["cf"].get_child(0).material
	m.set_shader_parameter("hue", deg_to_rad(28.0) if book == "enemy" else 0.0)
	m.set_shader_parameter("sat", 1.15 if book == "enemy" else 1.0)
	m.set_shader_parameter("bri", 0.82 if book == "enemy" else 1.0)
	sheets.clear()
	open_k = 0.0
	open_t = -1.0
	rib_k = 0.0
	x_k = 0.0
	scrim = 0.0
	slash_y = 0.0
	shake_y = 0.0
	thud_done = false
	busy = true
	phase = "drop"
	ph_t = 0.0
	for n in vps: vps[n].render_target_update_mode = SubViewport.UPDATE_ALWAYS

## open straight at an entry (a rune key or an enemy kind)
func open_at(k: String) -> void:
	go_to = k

func _size() -> void:
	var vs := get_viewport_rect().size
	var top := 40.0
	var w := vs.x - 64.0
	var h := vs.y - top - 4.0
	ph = minf(h, minf(w / 2.0 / 0.74, 980.0))
	pw = floorf(minf(w / 2.0, ph * 0.95))
	ph = floorf(ph)
	em = ph / 30.0
	var page := Vector2i(int(pw * 2.0 * 0.474), int(ph * 0.956))
	for n in ["pl", "pr", "fa", "fb"]: vps[n].size = page
	vps["cf"].size = Vector2i(int(pw), int(ph))
	vps["cb"].size = Vector2i(int(pw), int(ph))

func _setp(n: String, kind: String, arg = null) -> void:
	paint[n] = [kind, arg]
	vps[n].get_child(0).queue_redraw()


# ---------- books ----------
func book_list() -> Array:
	if book == "rune":
		var out: Array = []
		for g in RN.GORD:
			for r in RN.RUNE:
				if RN.RUNE[r]["g"] == g: out.append(r)
		return out
	return RN.ENEMY.keys()

func seen(k: String) -> bool:
	return R().seen_r.has(k) if book == "rune" else R().best_seen.has(k)

func grp(k: String) -> String:
	if book == "rune": return RN.RUNE[k]["g"]
	if RN.is_boss(k): return "boss"
	return "train" if not RN.ENEMY[k].get("mob", false) else "dun"

func gname(g: String) -> String:
	return RN.gname(g) if book == "rune" else {"train": "훈련장", "dun": "버섯 동굴", "boss": "보스"}[g]

func gcol(g: String) -> Color:
	return RN.gcol(g) if book == "rune" else {"train": Color("#8a7458"), "dun": Color("#3f8a4a"), "boss": Color("#c2336f")}[g]

func label(k: String) -> String:
	return RN.RUNE[k]["n"] if book == "rune" else RN.ENEMY[k]["name"]

func badge(k: String) -> String:
	if book == "rune": return ("×%d" % R().runebag[k]) if int(R().runebag.get(k, 0)) > 0 else ""
	var s: int = R().best_stage_of(k)
	return ["", "Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ"][s]

func groups() -> Array:
	if book == "enemy": return ["train", "dun", "boss"]
	var out: Array = []
	for k in list:
		if not out.has(grp(k)): out.append(grp(k))
	return out

## where a rune comes from (runeSrc): the cave's caps, the fuse
func rune_src(r: String) -> Array:
	var g: String = RN.RUNE[r]["g"]
	var gi := RN.GORD.find(g)
	if g == "unique": return [["동료 개인 의뢰", "고유 룬은 드롭되지 않는다 · 동료 개인 의뢰 보상 (준비 중)", true]]
	var L: Array = []
	var cap := RN.GORD.find(RN.DUN["cap"])
	var bon := RN.GORD.find(RN.DUN["bonus"])
	if gi >= cap: L.append([RN.DUN["name"], "몬스터 · 보물방 · 보스 상자", false])
	elif gi == bon: L.append([RN.DUN["name"], "보스 상자 대박 (등급 상한 +1)", false])
	if gi + 1 < RN.GORD.size() and g != "common":
		var lo: String = RN.GORD[gi + 1]
		var joined: bool = menu.bran_page.joined()
		L.append(["대장간 합성", RN.gname(lo) + " 룬 3개 → " + RN.gname(g) + " 1개" + ("" if joined else " · 브랜 합류 후"), not joined])
	return L


# ---------- input ----------
func _key(k: int) -> void:
	if k == KEY_ESCAPE: close_book()
	elif busy: return
	elif k == KEY_RIGHT: go(0 if cur < 0 else cur + 1)
	elif k == KEY_LEFT:
		if cur <= 0: go_back()
		else: go(cur - 1)
	elif k in [KEY_UP, KEY_DOWN] and cur < 0:
		ix_scroll = maxf(0.0, ix_scroll + (-1.0 if k == KEY_UP else 1.0) * em * 2.0)
		vps["pr"].get_child(0).queue_redraw()

func _wheel(d: int, _p: Vector2) -> void:
	if cur < 0 and not busy:
		ix_scroll = maxf(0.0, ix_scroll + d * em * 2.0)
		vps["pr"].get_child(0).queue_redraw()

func back() -> void:
	close_book()

## taps on the open book land on the flat pages
func _tap_book(p: Vector2) -> void:
	if busy: return
	var inv := _book_xf().affine_inverse()
	var lp := inv * p
	var W := pw * 2.0
	var rects := {"pl": Rect2(W * 0.026, ph * 0.022, W * 0.474, ph * 0.956), "pr": Rect2(W * 0.5, ph * 0.022, W * 0.474, ph * 0.956)}
	for n in rects:
		if n == "pl" and cur < 0: continue
		var r: Rect2 = rects[n]
		if r.has_point(lp):
			var q: Vector2 = lp - r.position
			for h in page_hits[n]:
				if h[0].has_point(q):
					h[1].call()
					return


# ---------- page turning ----------
func go(i: int) -> void:
	if busy or i == cur or i < 0 or i >= list.size(): return
	var from := cur
	var n := mini(5, 2 + int(i / 3)) if from < 0 else mini(5, 1 + int(absi(i - from) / 2))
	var dir := 1 if from < 0 or i > from else -1
	cur = i
	riffle(dir, n, ["left", i], ["right", i])

func go_back() -> void:
	if busy or cur < 0: return
	var n := mini(5, 2 + int(cur / 3))
	cur = -1
	riffle(-1, n, null, ["index", null])

## riffle: n sheets turn one after another (520 ms each, 70 ms apart); the first carries the old page, the last the new
func riffle(dir: int, n: int, new_l, new_r) -> void:
	busy = true
	var old_r: Array = paint["pr"].duplicate()
	var old_l: Array = paint["pl"].duplicate()
	_copy("fa", old_r if dir > 0 else (new_r if new_r != null else ["blank", null]))
	_copy("fb", new_l if dir > 0 else old_l)
	sheets.clear()
	for k in n:
		var first := k == 0
		var last := k == n - 1
		var front := ""
		var back_ := ""
		if dir > 0:
			front = "fa" if first else ""
			back_ = "fb" if last else ""
		else:
			front = "fa" if last else ""
			back_ = "fb" if first else ""
		sheets.append({"a0": 0.0 if dir > 0 else 180.0, "a1": 180.0 if dir > 0 else 0.0, "delay": k * 70.0, "front": front, "back": back_})
	if dir > 0: _copy("pr", new_r)
	else:
		_setp("pl", "blank")
	flip_len = 520.0 + (n - 1) * 70.0
	flip_t = 0.0
	var nl = new_l
	var nr = new_r
	flip_done = func():
		if dir > 0: _copy("pl", nl)
		else:
			_copy("pr", nr)
			if nl != null: _copy("pl", nl)
		busy = false
	sfx("step", 0.25)

func _copy(n: String, what) -> void:
	if what == null: _setp(n, "blank")
	else: _setp(n, what[0], what[1])


# ---------- close ----------
func close_book() -> void:
	if busy or phase != "idle": return
	busy = true
	sfx("ui_back", 0.5)
	if cur >= 0:
		# the entry page turns back to the index, then the cover shuts
		_copy("fb", paint["pl"])
		_setp("fa", "blank")
		sheets = [{"a0": 180.0, "a1": 0.0, "delay": 0.0, "front": "fa", "back": "fb", "ease": [0.5, 0.0, 0.3, 1.0], "dur": 620.0}]
		_setp("pl", "blank")
		cur = -1
		flip_len = 620.0
		flip_t = 0.0
		phase = "close_flip"
		flip_done = func():
			_setp("pr", "index")
			_shut()
	else:
		_shut()

func _shut() -> void:
	phase = "shut"
	ph_t = 0.0
	open_from = open_k
	open_to = 0.0
	open_t = 0.0
	sfx("step", 0.3)

func _finish() -> void:
	busy = false
	phase = ""
	for n in vps: vps[n].render_target_update_mode = SubViewport.UPDATE_DISABLED
	menu.close_page()


# ---------- clock ----------
func _tick(dt: float) -> void:
	ph_t += dt
	match phase:
		"drop":
			scrim = clampf(ph_t / 260.0, 0.0, 1.0)
			ttl_k = clampf((ph_t - 120.0) / 380.0, 0.0, 1.0)
			if ph_t >= 470.0 and not thud_done:
				thud_done = true
				sfx("slam", 0.5)
				slash_y = -26.0
				shake_y = 4.0
			if ph_t >= 1000.0:
				phase = "lift"
				ph_t = 0.0
				slash_y = 0.0
				sfx("step", 0.25)
		"lift":
			if ph_t >= 520.0 and open_t < 0.0 and open_k < 1.0:
				open_from = 0.0
				open_to = 1.0
				open_t = 0.0
				sfx("step", 0.3)
			if ph_t >= 1520.0:
				phase = "idle"
				busy = false
				if go_to != "":
					var i := list.find(go_to)
					go_to = ""
					if i >= 0: go(i)
		"shut":
			if ph_t >= 1050.0:
				phase = "toss"
				ph_t = 0.0
				sfx("slam", 0.45)
		"toss":
			scrim = 1.0 - clampf((ph_t - 200.0) / 520.0, 0.0, 1.0)
			ttl_k = 1.0 - clampf(ph_t / 260.0, 0.0, 1.0)
			if ph_t >= 720.0: _finish()
	shake_y = maxf(0.0, shake_y - dt * 4.0 / 180.0)
	if open_t >= 0.0:
		open_t += dt
		var u := clampf(open_t / 1000.0, 0.0, 1.0)
		open_k = lerpf(open_from, open_to, UI.bez(0.55, 0.0, 0.25, 1.0, u))
		if u >= 1.0: open_t = -1.0
	if flip_t >= 0.0:
		flip_t += dt
		if flip_t >= flip_len + 20.0:
			flip_t = -1.0
			sheets.clear()
			var f := flip_done
			flip_done = Callable()
			if f.is_valid(): f.call()
	if book == "enemy" and phase == "idle":
		for n in ["pl", "fa", "fb"]:
			if paint[n][0] == "left": vps[n].get_child(0).queue_redraw()
	rib_k = move_toward(rib_k, 1.0 if cur >= 0 and phase == "idle" else 0.0, dt / 450.0)
	x_k = move_toward(x_k, 1.0 if phase == "idle" and not busy or (phase == "idle" and flip_t >= 0.0) else 0.0, dt / 350.0)


# ---------- the book's transform ----------
## drop / lift / toss keyframes → (offset in drop-size fractions or px, rotation, scale)
func _drop_pose() -> Array:
	var vs := get_viewport_rect().size
	var S := Vector2(pw * 2.0, ph)
	match phase:
		"drop":
			var g := UI.bez(0.55, 0.0, 0.75, 0.35, clampf(ph_t / 760.0, 0.0, 1.0))
			var K := [[0.0, Vector2(vs.x * 0.34, -vs.y * 1.2), -28.0, Vector2(0.66, 0.66)], [0.62, Vector2(0, S.y * 0.08), -4.0, Vector2(0.57, 0.57)],
				[0.72, Vector2(0, S.y * 0.09), -2.5, Vector2(0.58, 0.54)], [0.84, Vector2(0, S.y * 0.076), -3.5, Vector2(0.56, 0.56)], [1.0, Vector2(0, S.y * 0.09), -3.0, Vector2(0.56, 0.56)]]
			return _kf(K, g, [[0.3, 0.0, 0.6, 1.0]])
		"lift":
			var g2 := UI.bez(0.3, 0.0, 0.25, 1.0, clampf(ph_t / 620.0, 0.0, 1.0))
			var K2 := [[0.0, Vector2(0, S.y * 0.09), -3.0, Vector2(0.56, 0.56)], [0.62, Vector2(-S.x * 0.01, -S.y * 0.02), 1.8, Vector2(1.04, 1.04)],
				[0.84, Vector2(0, S.y * 0.004), -1.0, Vector2(0.995, 0.995)], [1.0, Vector2.ZERO, -0.6, Vector2.ONE]]
			return _kf(K2, g2, [])
		"toss":
			var g3 := UI.bez(0.5, 0.0, 0.8, 0.4, clampf((ph_t) / 640.0, 0.0, 1.0))
			var K3 := [[0.0, Vector2.ZERO, -0.6, Vector2.ONE], [0.28, Vector2(-vs.x * 0.04, -S.y * 0.03), -6.0, Vector2(0.96, 0.96)], [1.0, Vector2(-vs.x * 0.64, vs.y * 1.1), -30.0, Vector2(0.7, 0.7)]]
			return _kf(K3, g3, [])
	return [Vector2.ZERO, -0.6, Vector2.ONE]

static func _kf(K: Array, g: float, eases: Array) -> Array:
	var i := 0
	while i < K.size() - 2 and g > K[i + 1][0]: i += 1
	var a: Array = K[i]
	var b: Array = K[i + 1]
	var u := clampf((g - a[0]) / maxf(0.0001, b[0] - a[0]), 0.0, 1.0)
	if i < eases.size(): u = UI.bez(eases[i][0], eases[i][1], eases[i][2], eases[i][3], u)
	return [a[1].lerp(b[1], u), lerpf(a[2], b[2], u), a[3].lerp(b[3], u)]

## book-local (top-left of the two-page spread) → screen
func _book_xf() -> Transform2D:
	var vs := get_viewport_rect().size
	var S := Vector2(pw * 2.0, ph)
	var centre := Vector2(vs.x / 2.0, 40.0 + (vs.y - 44.0) / 2.0 + shake_y)
	var pose := _drop_pose()
	var shift := -0.25 * S.x * (1.0 - _shift_k())
	return Transform2D(deg_to_rad(pose[1]), pose[2], 0.0, centre + pose[0]) * Transform2D(0.0, Vector2(shift, 0) - S / 2.0)

## the book slides from closed (−25%) to open with its own timing (.9 s) — follow open_k closely
func _shift_k() -> float:
	return open_k


# ---------- drawing ----------
func _paint(vs: Vector2) -> void:
	var col: Color = BOOK[book]["col"]
	# scrim: dark with a faint dot grid
	draw_rect(Rect2(Vector2.ZERO, vs), Color(10 / 255.0, 8 / 255.0, 14 / 255.0, 0.93 * scrim))
	if scrim > 0.0:
		var dt := UI.dot_tile(0.05)
		draw_texture_rect(dt, Rect2(Vector2.ZERO, vs), true, Color(-1, -1, -1, scrim))
	# the slash and the huge hollow word
	var sk := UI.bez(0.2, 0.9, 0.25, 1.0, clampf(t / 420.0, 0.0, 1.0)) if phase == "drop" else 1.0
	var sl_a := 0.85 * scrim
	draw_set_transform(Vector2(-vs.x * 0.1 + (-1.1 * vs.x * 0.8) * (1.0 - sk), vs.y * 0.68 + slash_y), deg_to_rad(-7.0))
	draw_rect(Rect2(0, 0, vs.x * 0.8, 9), Color(1, 1, 1, sl_a))
	draw_set_transform(Vector2(-vs.x * 0.02, vs.y * 1.06), deg_to_rad(-8.0))
	draw_string_outline(UI.anton(), Vector2.ZERO, BOOK[book]["en"], HORIZONTAL_ALIGNMENT_LEFT, -1, int(minf(vs.x * 0.28, 260.0)), 2, Color(1, 1, 1, 0.07 * scrim))
	draw_set_transform(Vector2.ZERO)
	_draw_book(vs)
	# title
	var tk := UI.bk(ttl_k)
	draw_set_transform(Vector2(maxf(16.0, 16.0) - 60.0 * (1.0 - tk), 12.0), deg_to_rad(-3.0))
	var a := clampf(ttl_k * 1.5, 0.0, 1.0)
	draw_string(UI.spaced(UI.anton(), 3), Vector2(0, 10), BOOK[book]["en"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(col, a))
	var bw := tw(UI.bhs(), BOOK[book]["n"], 24) + 24.0
	draw_colored_polygon(UI.clip(Rect2(0, 14, bw, 34), [[0, 6], [100, 0], [97, 100], [2, 92]]), Color(0, 0, 0, a))
	draw_rect(Rect2(2, 44, bw - 4, 4), Color(col, a))
	draw_string(UI.bhs(), Vector2(12, 40), BOOK[book]["n"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, a))
	draw_set_transform(Vector2.ZERO)
	# ✕ (shuts the book)
	if x_k > 0.0:
		var c := Vector2(vs.x - 14.0 - 21.0, 12.0 + 21.0)
		var s := UI.bk(x_k)
		draw_set_transform(c, deg_to_rad(-90.0 * (1.0 - s)), Vector2(s, s))
		draw_circle(Vector2.ZERO, 21.0, Color.BLACK)
		draw_arc(Vector2.ZERO, 19.5, 0, TAU, 32, Color.WHITE, 3.0, true)
		UI.cross(self, Vector2.ZERO, 6.0, Color.WHITE, 2.5)
		draw_set_transform(Vector2.ZERO)
		hit(Rect2(c - Vector2(22, 22), Vector2(44, 44)), close_book)
	# taps on the book itself (registered first so ✕ and the ribbon win)
	hits.push_front([Rect2(Vector2.ZERO, vs), func(): _tap_book(get_local_mouse_position())])

func _draw_book(vs: Vector2) -> void:
	var xf := _book_xf()
	var W := pw * 2.0
	var H := ph
	var held := clampf((_drop_pose()[2] as Vector2).x, 0.0, 1.0)
	# the shadow under it: grows and softens when it's picked up
	var shl := lerpf(0.27, 0.04, open_k)
	var shr := lerpf(0.25, 0.0, open_k)
	var lift := clampf((held - 0.56) / 0.44, 0.0, 1.0) if phase != "drop" else 0.0
	draw_set_transform_matrix(xf)
	var shoff := Vector2(14, 8).lerp(Vector2(46, 52), lift)
	var srect := Rect2(W * shl + shoff.x, H * 0.06 + shoff.y, W * (1.0 - shl - shr), H * 0.98)
	for i in 5:
		var g := float(i) * (3.0 + lift * 4.0)
		draw_rect(srect.grow(g), Color(0, 0, 0, (0.6 - lift * 0.05) * 0.22 * scrim))
	# back board + right page
	var R2 := Rect2(W * 0.5, 0, W * 0.5, H)
	draw_rect(R2, Color("#3b2414"))
	draw_rect(R2, Color("#24150b"), false, 2.0)
	draw_texture_rect(EDGE, Rect2(W * (1.0 - 0.028), H * 0.026, W * 0.014, H * 0.948), false)
	var pr := Rect2(W * 0.5, H * 0.022, W * 0.474, H * 0.956)
	draw_texture_rect(vps["pr"].get_texture(), pr, false)
	_spine_shade(pr, true)
	# left page (once a spread is open)
	var pl := Rect2(W * 0.026, H * 0.022, W * 0.474, H * 0.956)
	var cover_a := open_k * 180.0
	if open_k > 0.5:
		draw_texture_rect(EDGE, Rect2(W * 0.014, H * 0.026, W * 0.014, H * 0.948), false)
		# the cover's back (endpaper + plate) lies under the left page
	# the cover leaf
	if cover_a < 90.0: _leaf(vps["cf"].get_texture(), cover_a, Rect2(W * 0.5, 0, W * 0.5, H), false, 0.0)
	else: _leaf(vps["cb"].get_texture(), cover_a, Rect2(W * 0.5, 0, W * 0.5, H), true, 0.0)
	if cur >= 0 or paint["pl"][0] != "blank" or sheets.size() > 0:
		if open_k >= 0.99 and (cur >= 0 or paint["pl"][0] != "blank"):
			draw_texture_rect(vps["pl"].get_texture(), pl, false)
			_spine_shade(pl, false)
	# turning sheets
	for s in sheets:
		var dur: float = s.get("dur", 520.0)
		var u := clampf((flip_t - s["delay"]) / dur, 0.0, 1.0)
		var e: Array = s.get("ease", [0.45, 0.05, 0.3, 1.0])
		var a: float = lerpf(s["a0"], s["a1"], UI.bez(e[0], e[1], e[2], e[3], u))
		var z := 6.0 * sin(PI * u)
		var showing_back := a > 90.0
		var face: String = s["back"] if showing_back else s["front"]
		var shade := 0.9 * sin(PI * u)
		_leaf(vps[face].get_texture() if face != "" else null, a, Rect2(W * 0.5, 0, W * 0.5, H), showing_back, shade, z)
	# the ribbon: red bookmark on the left, back to the index
	if rib_k > 0.0:
		var rr := Rect2(-em * 2.4 + em * 0.8, H * 0.14, em * 2.6, em * 9.0)
		var k := UI.bk(rib_k)
		var x0 := rr.position.x + rr.size.x * 1.1 * (1.0 - k)
		var poly := PackedVector2Array([Vector2(x0, rr.position.y), Vector2(x0 + rr.size.x, rr.position.y), Vector2(x0 + rr.size.x, rr.end.y), Vector2(x0, rr.end.y), Vector2(x0 + rr.size.x * 0.22, rr.get_center().y)])
		draw_colored_polygon(poly, RED)
		draw_rect(Rect2(x0 + rr.size.x - 4.0, rr.position.y, 4, rr.size.y), Color(0, 0, 0, 0.25))
		var ys := rr.position.y + em * 1.2
		for ch in "돌아가기":
			ctext(self, UI.noto(), Vector2(x0 + rr.size.x * 0.6, ys), ch, int(em * 0.78), Color("#fbe7c8"))
			ys += em * 1.2
		draw_set_transform(Vector2.ZERO)
		var sp := PackedVector2Array()
		for q in poly: sp.append(xf * q)
		hit(sp, go_back)
	draw_set_transform(Vector2.ZERO)

## the inset shadow along the spine
func _spine_shade(r: Rect2, left_side: bool) -> void:
	var n := 8
	for i in n:
		var w := r.size.x * 0.06 * (1.0 - float(i) / n)
		var x := r.position.x if left_side else r.end.x - w
		draw_rect(Rect2(x, r.position.y, w, r.size.y), Color(60 / 255.0, 35 / 255.0, 10 / 255.0, 0.07))

## a leaf hinged at the spine, turned `a` degrees (0 = lying right, 180 = lying left), seen through the perspective
func _leaf(tex_: Texture2D, a: float, r: Rect2, back: bool, shade: float, z := 0.0) -> void:
	var W := pw * 2.0
	var P := ph * 4.2
	var o := Vector2(W * 0.5, ph * 0.4)
	var th := deg_to_rad(a)
	var N := 10
	var spine: float = r.position.x
	var Wl: float = r.size.x
	var pts_at := func(u: float, v: float) -> Vector2:
		var X := spine + u * Wl * cos(th)
		var Z := u * Wl * sin(th) + z
		var s := P / (P - Z)
		return Vector2(o.x + (X - o.x) * s, o.y + (v - o.y) * s)
	var col := Color(1, 1, 1).darkened(0.35 * shade)
	for i in N:
		var u0 := float(i) / N
		var u1 := float(i + 1) / N
		var q := PackedVector2Array([pts_at.call(u0, r.position.y), pts_at.call(u1, r.position.y), pts_at.call(u1, r.end.y), pts_at.call(u0, r.end.y)])
		var tu0 := 1.0 - u0 if back else u0
		var tu1 := 1.0 - u1 if back else u1
		if tex_ != null:
			draw_polygon(q, PackedColorArray([col, col, col, col]), PackedVector2Array([Vector2(tu0, 0), Vector2(tu1, 0), Vector2(tu1, 1), Vector2(tu0, 1)]), tex_)
		else:
			draw_colored_polygon(q, PAPER.darkened(0.35 * shade))


# ---------- page faces (drawn inside the viewports) ----------
func _paint_face(n: String, ci: Control) -> void:
	page_hits[n] = []
	var sz := Vector2(vps[n].size)
	var kind: String = paint[n][0]
	var arg = paint[n][1]
	match kind:
		"cover": _face_cover(ci, sz)
		"plate": _face_plate(ci, sz)
		_:
			ci.draw_rect(Rect2(Vector2.ZERO, sz), PAPER)
			# paper light: a soft highlight top-left, warm dark bottom-right
			ci.draw_texture_rect(UI.glow(), Rect2(-sz.x * 0.3, -sz.y * 0.3, sz.x * 1.2, sz.y * 0.9), false, Color(1, 1, 1, 0.25))
			ci.draw_texture_rect(UI.glow(), Rect2(sz.x * 0.4, sz.y * 0.55, sz.x * 0.9, sz.y * 0.8), false, Color(120 / 255.0, 80 / 255.0, 30 / 255.0, 0.12))
			match kind:
				"index": _face_index(ci, sz, n)
				"left": _face_left(ci, sz, int(arg), n)
				"right": _face_right(ci, sz, int(arg), n)

func _ph(n: String, r: Rect2, cb: Callable) -> void:
	page_hits[n].append([r, cb])

func _face_cover(ci: Control, sz: Vector2) -> void:
	# border-image 84 fill, stretched; rounded spine side
	var b := ph * 84.0 / 915.0
	var S := Vector2(COVER.get_width(), COVER.get_height())
	var s := 84.0
	var xs := [0.0, b, sz.x - b, sz.x]
	var ys := [0.0, b, sz.y - b, sz.y]
	var us := [0.0, s, S.x - s, S.x]
	var vs := [0.0, s, S.y - s, S.y]
	for i in 3:
		for j in 3:
			ci.draw_texture_rect_region(COVER, Rect2(xs[i], ys[j], xs[i + 1] - xs[i], ys[j + 1] - ys[j]), Rect2(us[i], vs[j], us[i + 1] - us[i], vs[j + 1] - vs[j]))
	var eh := ph * 500.0 / 915.0
	var ew := eh * 300.0 / 500.0
	ci.draw_texture_rect(EMBLEM, Rect2(sz / 2.0 - Vector2(ew, eh) / 2.0, Vector2(ew, eh)), false)
	for i in 10:
		ci.draw_rect(Rect2(i * sz.x * 0.007, 0, sz.x * 0.007, sz.y), Color(0, 0, 0, 0.45 * (1.0 - i / 10.0)))
	var fs := int(ph / 17.0)
	var title: String = BOOK[book]["n"]
	var tf := UI.spaced(SERIF, int(fs * 0.12))
	ctext(ci, tf, Vector2(sz.x / 2.0, sz.y * 0.12 + fs + 2.0), title, fs, Color("#2a170a"))
	ctext(ci, tf, Vector2(sz.x / 2.0, sz.y * 0.12 + fs), title, fs, Color("#e9c27a"))
	var sf := UI.spaced(UI.anton(), int(ph / 40.0 * 0.4))
	ctext(ci, sf, Vector2(sz.x / 2.0, sz.y * 0.88), BOOK[book]["en"], int(ph / 40.0), Color("#c9a160", 0.85))

func _face_plate(ci: Control, sz: Vector2) -> void:
	# the cover's inside: board, endpaper, the shelf plate
	ci.draw_rect(Rect2(Vector2.ZERO, sz), Color("#3b2414"))
	var ep := Rect2(0, sz.y * 0.022, sz.x * 0.95, sz.y * 0.956)
	var tile := ep.size.x * 0.62
	var k := tile / ENDPAPER.get_width()
	ci.draw_set_transform(ep.position, 0.0, Vector2(k, k))
	ci.draw_texture_rect(ENDPAPER, Rect2(Vector2.ZERO, ep.size / k), true)
	ci.draw_set_transform(Vector2.ZERO)
	for i in 8:
		ci.draw_rect(Rect2(ep.end.x - (i + 1) * 5.0, ep.position.y, 5.0, ep.size.y), Color(0, 0, 0, 0.06))
	var pr := Rect2(sz.x * 0.16, sz.y * 0.2, sz.x * 0.72, 0)
	var L := book_list()
	var nseen := L.filter(func(q): return seen(q)).size()
	var lines: Array = [["수록 %d · %s %d" % [L.size(), "발견" if book == "rune" else "만남", nseen], em * 0.82], ["어설픈 용맹 길드 서고", em * 0.82]]
	pr.size.y = em * 10.0
	ci.draw_set_transform(pr.get_center(), deg_to_rad(-1.5))
	var lr := Rect2(-pr.size / 2.0, pr.size)
	ci.draw_rect(Rect2(lr.position + Vector2(0, 3), lr.size), Color(0, 0, 0, 0.35))
	ci.draw_rect(lr, PAPER)
	ci.draw_rect(lr, Color("#b89c6c"), false, 1.0)
	ci.draw_rect(lr.grow(-5), Color("#b89c6c"), false, 1.0)
	ci.draw_rect(lr.grow(-8), Color("#b89c6c"), false, 1.0)
	var y := lr.position.y + em * 1.6
	ctext(ci, UI.spaced(UI.anton(), int(em * 0.2)), Vector2(0, y), BOOK[book]["en"], int(em * 0.62), INK3)
	y += em * 2.2
	ctext(ci, SERIF, Vector2(0, y), BOOK[book]["n"], int(em * 1.9), INK)
	y += em * 1.6
	for l in lines:
		ctext(ci, SERIF, Vector2(0, y), l[0], int(l[1]), INK2)
		y += em * 1.35
	var st := "관리국 열람 허가"
	var sw := tw(UI.noto(), st, int(em * 0.7)) + em
	ci.draw_set_transform(pr.get_center() + Vector2(0, y - lr.position.y - pr.size.y / 2.0 + em * 0.2).rotated(deg_to_rad(-1.5)), deg_to_rad(-7.5))
	ci.draw_rect(Rect2(-sw / 2.0, -em * 0.8, sw, em * 1.3), RED, false, 2.0)
	ctext(ci, UI.noto(), Vector2(0, em * 0.2), st, int(em * 0.7), RED)
	ci.draw_set_transform(Vector2.ZERO)

func _run(ci: Control, sz: Vector2, s: String, right: bool) -> void:
	var f := UI.spaced(UI.anton(), int(em * 0.15))
	var fs := int(em * 0.55)
	var x := sz.x - em * 1.8 - tw(f, s, fs) if right else em * 1.8
	ci.draw_string(f, Vector2(x, em * 1.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK3)

func _folio(ci: Control, sz: Vector2, n: int, right: bool) -> void:
	var s := str(n)
	var fs := int(em * 0.7)
	var x := sz.x - em * 1.8 - tw(SERIF, s, fs) if right else em * 1.8
	ci.draw_string(SERIF, Vector2(x, sz.y - em * 0.9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, INK3)

## page curl corners: next (right page) / previous (left page)
func _corner(ci: Control, sz: Vector2, nxt: bool, n: String) -> void:
	var s := em * 2.6
	var c0 := Vector2(sz.x, sz.y) if nxt else Vector2(0, sz.y)
	var d := -1.0 if nxt else 1.0
	ci.draw_colored_polygon(PackedVector2Array([c0 + Vector2(d * s * 0.52, 0), c0 + Vector2(d * s * 0.64, 0), c0 + Vector2(0, -s * 0.64), c0 + Vector2(0, -s * 0.52)]), PAPER2)
	ci.draw_line(c0 + Vector2(d * s * 0.5, 0), c0 + Vector2(0, -s * 0.5), Color(120 / 255.0, 90 / 255.0, 50 / 255.0, 0.25), 1.0)
	var step := 1 if nxt else -1
	_ph(n, Rect2(c0 - Vector2(s if nxt else 0.0, s), Vector2(s, s)), func(): go(cur + step))

func _face_index(ci: Control, sz: Vector2, n: String) -> void:
	_run(ci, sz, "INDEX", true)
	var x := em * 2.2
	var y := em * 3.4
	ci.draw_string(SERIF, Vector2(x, y), "색인", HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 1.5), INK)
	ci.draw_string(UI.spaced(UI.anton(), int(em * 0.2)), Vector2(x + tw(SERIF, "색인", int(em * 1.5)) + em * 0.6, y - em * 0.1), "CONTENTS", HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.62), INK3)
	var top := y + em * 0.6
	var bottom := sz.y - em * 2.4
	var yy := top + em * 0.4 - ix_scroll
	var w := sz.x - x - em * 1.8
	var total := 0.0
	for g in groups():
		var G: Array = []
		for i in list.size():
			if grp(list[i]) == g: G.append(i)
		if G.is_empty(): continue
		var gc := gcol(g).darkened(0.28)
		if yy > top - em and yy < bottom:
			ci.draw_string(UI.noto(), Vector2(x, yy + em * 0.75), gname(g), HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.72), gc)
			var gw := tw(UI.noto(), gname(g), int(em * 0.72)) + em * 0.4
			ci.draw_line(Vector2(x + gw, yy + em * 0.5), Vector2(x + w, yy + em * 0.5), Color(gc, 0.35), 1.0)
		yy += em * 1.25
		for i in G:
			var k: String = list[i]
			var s := seen(k)
			if yy > top - em * 0.4 and yy < bottom - em * 0.6:
				var fc := INK if s else INK3
				var ex := x + em * 0.2
				gem(ci, Vector2(ex + em * 0.3, yy + em * 0.42), em * 0.28, gcol(g).darkened(0.2), false)
				var lab := label(k) if s else "???"
				var fs := int(em * 0.86)
				ci.draw_string(UI.noto(), Vector2(ex + em * 0.85, yy + em * 0.75), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fc)
				var lx := ex + em * 0.85 + tw(UI.noto(), lab, fs) + em * 0.3
				var bd := badge(k)
				if bd != "":
					ci.draw_string(UI.anton(), Vector2(lx, yy + em * 0.74), bd, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.7), RED)
					lx += tw(UI.anton(), bd, int(em * 0.7)) + em * 0.3
				var fol := str(3 + i * 2)
				var fx := x + w - tw(SERIF, fol, int(em * 0.72))
				ci.draw_string(SERIF, Vector2(fx, yy + em * 0.75), fol, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.72), INK3)
				var dx := lx
				while dx < fx - em * 0.4:
					ci.draw_rect(Rect2(dx, yy + em * 0.62, 1, 1), Color(INK3, 0.6))
					dx += 3.0
				var ii: int = i
				_ph(n, Rect2(x, yy, w, em * 1.1), func(): go(ii))
			yy += em * 1.35
	total = yy + ix_scroll - top
	ix_scroll = clampf(ix_scroll, 0.0, maxf(0.0, total - (bottom - top)))
	# the page's bottom edge covers the overflow
	ci.draw_rect(Rect2(0, bottom, sz.x, sz.y - bottom), PAPER)
	if total > bottom - top:
		var k2 := (bottom - top) / total
		ci.draw_rect(Rect2(sz.x - em * 1.2, top + (bottom - top) * (ix_scroll / total), 2, (bottom - top) * k2), Color(INK3, 0.5))
	_folio(ci, sz, 1, true)

func _face_left(ci: Control, sz: Vector2, i: int, n: String) -> void:
	var k: String = list[i]
	var g := grp(k)
	var gc := gcol(g).darkened(0.28)
	_run(ci, sz, BOOK[book]["en"], false)
	var x := em * 1.8
	var w := sz.x - em * 4.0
	var y := em * 3.0
	var s := seen(k)
	if book == "rune":
		var Rd: Dictionary = RN.RUNE[k]
		var who: String = (RN.pname(Rd["who"]) + " 전용") if Rd.has("who") else ((Rd["cls"] + " 무기") if Rd.has("cls") else "")
		ci.draw_string(UI.noto(), Vector2(x, y), RN.gname(Rd["g"]) + " · " + SLOT[Rd["k"]] + (" · " + who if who != "" else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.72), gc)
		y += em * 2.0
		ci.draw_string(SERIF, Vector2(x, y), Rd["n"] if s else "???", HORIZONTAL_ALIGNMENT_LEFT, w, int(em * 1.75), INK)
		var sig_c := Vector2(sz.x / 2.0, (y + sz.y - em * 4.0) / 2.0 + em * 0.6)
		var sr := minf(w * 0.39, (sz.y - em * 4.0 - y) * 0.5) * 0.98
		if s:
			_sigil(ci, sig_c, sr, Rd["n"], RN.gcol(Rd["g"]))
			var rip := ICON.rune_file(k, String(Rd["g"]))
			if ResourceLoader.exists(rip):
				# the rune stone itself at the heart of the drawn sigil
				var rs := sr * 0.62
				ci.draw_texture_rect(load(rip), Rect2(sig_c - Vector2(rs, rs) / 2.0, Vector2(rs, rs)), false)
		else:
			for q in 24:
				if q % 2 == 0: ci.draw_arc(sig_c, sr * 0.62, q * TAU / 24.0, (q + 1) * TAU / 24.0, 4, INK3, 2.0)
			ctext(ci, SERIF, sig_c + Vector2(0, em * 0.5), "?", int(em * 1.4), INK3)
		var ly := sz.y - em * 3.2
		ci.draw_line(Vector2(x, ly), Vector2(x + w, ly), Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.3), 1.0)
		var own := int(R().runebag.get(k, 0))
		var lx := x
		if own > 0:
			var os := "보유 ×%d" % own
			ci.draw_string(UI.anton(), Vector2(lx, ly + em * 1.1), os, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.8), RED)
			lx += tw(UI.anton(), os, int(em * 0.8))
			ci.draw_string(UI.noto(), Vector2(lx, ly + em * 1.1), " · ", HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.78), INK2)
			lx += tw(UI.noto(), " · ", int(em * 0.78))
		ci.draw_string(UI.noto(), Vector2(lx, ly + em * 1.1), SLOT[Rd["k"]] + " 룬" + (" · " + who if who != "" else ""), HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.78), INK2)
	else:
		var E: Dictionary = RN.ENEMY[k]
		ci.draw_string(UI.noto(), Vector2(x, y), "No.%03d · %s" % [i + 1, gname(g)], HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.72), gc)
		y += em * 2.0
		ci.draw_string(SERIF, Vector2(x, y), E["name"] if s else "???", HORIZONTAL_ALIGNMENT_LEFT, w, int(em * 1.75), INK)
		y += em * 0.8
		var desc: String = E["desc"] if s else "아직 만나지 못한 적이다."
		var dh := paras_h(w, [[desc, int(em * 0.8), INK2, UI.noto()]], em * 0.3)
		var bottom := sz.y - em * 3.2 - dh - em * 0.6
		var box := Rect2(x, y, w, bottom - y)
		ci.draw_rect(box, Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.03))
		var dd := -box.size.y
		while dd < box.size.x:
			var a0 := Vector2(box.position.x + maxf(0.0, dd), box.position.y + maxf(0.0, -dd))
			var a1 := Vector2(box.position.x + minf(box.size.x, dd + box.size.y), box.position.y + minf(box.size.y, box.size.x - dd))
			ci.draw_line(a0, a1, Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.06), em * 0.6)
			dd += em * 1.7
		ci.draw_rect(box, Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.35), false, 1.0)
		_sprite(ci, k, box, s)
		paras(ci, x, bottom + em * 0.4, w, [[desc, int(em * 0.8), INK2, UI.noto()]], em * 0.3)
		var ly := sz.y - em * 3.2
		ci.draw_line(Vector2(x, ly), Vector2(x + w, ly), Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.3), 1.0)
		ci.draw_string(UI.noto(), Vector2(x, ly + em * 1.1), "출현 · %s · 처치 %d" % [E["where"] if s else "???", int(R().best_kills.get(k, 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.78), INK2)
	_folio(ci, sz, 3 + i * 2, false)
	_corner(ci, sz, false, n)

## a mob's idle loop (or the dummy), black when not met yet
func _sprite(ci: Control, k: String, box: Rect2, s: bool) -> void:
	var col := Color.WHITE if s else Color(0, 0, 0, 0.55)
	if SPR.has(k):
		var sp: Array = SPR[k]
		var tt := tx("res://assets/mobs/%s.png" % sp[0])
		var fw: float = tt.get_width() / float(sp[1])
		var fh: float = tt.get_height()
		var fr := int(Time.get_ticks_msec() / float(sp[2])) % int(sp[1])
		# the strips are 150px cells with the body low in the middle: crop to it
		var src := Rect2(fr * fw + fw * 0.25, fh * 0.3, fw * 0.5, fh * 0.45)
		var h := box.size.y * 0.95
		var w := h * src.size.x / src.size.y
		var tint := col
		if k == "boss" and s: tint = Color(1.25, 0.72, 0.95)
		ci.draw_texture_rect_region(tt, Rect2(box.get_center().x - w / 2.0 + 3, box.end.y - h + 3, w, h), src, Color(46 / 255.0, 33 / 255.0, 22 / 255.0, 0.35 * col.a))
		ci.draw_texture_rect_region(tt, Rect2(box.get_center().x - w / 2.0, box.end.y - h, w, h), src, tint)
	elif k == "dummy":
		var h2 := box.size.y * 0.85
		var w2 := h2 * DUMMY.get_width() / DUMMY.get_height()
		ci.draw_texture_rect(DUMMY, Rect2(box.get_center().x - w2 / 2.0, box.end.y - h2 - 4.0, w2, h2), false, col)
	else:
		# the training ghost has no art in this port: a small drawn ghost
		var c := box.get_center() + Vector2(0, sin(Time.get_ticks_msec() / 300.0) * 4.0)
		var gc := Color(0.75, 0.85, 1.0, 0.9) if s else col
		ci.draw_circle(c, box.size.y * 0.22, gc)            # PLACEHOLDER: ghost art
		ci.draw_rect(Rect2(c.x - box.size.y * 0.22, c.y, box.size.y * 0.44, box.size.y * 0.2), gc)
		if s:
			ci.draw_circle(c + Vector2(-8, -4), 3.0, INK)
			ci.draw_circle(c + Vector2(8, -4), 3.0, INK)

## the rune's sigil (codex.js sigil: a seeded stand-in for rune art)
func _sigil(ci: Control, c: Vector2, r: float, nm: String, col: Color) -> void:
	var h := 0
	for ch in nm: h = (h * 31 + ch.unicode_at(0)) & 0xFFFFFFFF
	var rnd := func() -> float:
		h = (h * 1103515245 + 12345) & 0xFFFFFFFF
		return float(h >> 8) / 16777216.0
	var k := r / 50.0
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x - 50.0, y - 50.0) * k
	ci.draw_arc(c, 38.0 * k, 0, TAU, 48, Color(col, 0.7), 1.6 * k)
	ci.draw_arc(c, 31.0 * k, 0, TAU, 48, INK, 2.2 * k)
	ci.draw_line(P.call(50, 8), P.call(50, 92), INK, 3.0 * k)
	ci.draw_colored_polygon(PackedVector2Array([P.call(50, 4), P.call(54, 11), P.call(50, 15), P.call(46, 11)]), INK)
	ci.draw_colored_polygon(PackedVector2Array([P.call(50, 96), P.call(54, 89), P.call(50, 85), P.call(46, 89)]), INK)
	for i in 3:
		var y: float = 26.0 + rnd.call() * 48.0
		var dx: float = 10.0 + rnd.call() * 22.0
		var dy: float = (rnd.call() - 0.5) * 30.0
		ci.draw_line(P.call(50, y), P.call(50 - dx, y + dy), INK, 2.6 * k)
		ci.draw_line(P.call(50, y), P.call(50 + dx, y + dy), INK, 2.6 * k)
	var cy: float = 38.0 + rnd.call() * 24.0
	var dia := PackedVector2Array([P.call(50, cy - 7), P.call(57, cy), P.call(50, cy + 7), P.call(43, cy)])
	ci.draw_colored_polygon(dia, col)
	dia.append(dia[0])
	ci.draw_polyline(dia, INK, 1.6 * k)

func _face_right(ci: Control, sz: Vector2, i: int, n: String) -> void:
	var k: String = list[i]
	var s := seen(k)
	_run(ci, sz, label(k).substr(0, 16) if s else "???", true)
	var x := em * 2.2
	var w := sz.x - x - em * 1.8
	var y := em * 2.6
	var fs := int(em * 0.82)
	if book == "rune":
		var Rd: Dictionary = RN.RUNE[k]
		y = _sec(ci, x, y, "효과")
		var eff: String = Rd["d"] if s else "아직 손에 넣은 적 없는 룬. 효과는 얻으면 알 수 있다. (도서관 서가를 복구하면 미리 볼 수 있다)"
		var eh := paras_h(w - em * 1.6, [[eff, int(em * 0.9), INK, UI.noto()]], 0.0) + em * 1.2
		ci.draw_rect(Rect2(x, y, w, eh), Color(1, 1, 1, 0.5))
		ci.draw_rect(Rect2(x, y, em * 0.25, eh), RN.gcol(Rd["g"]))
		paras(ci, x + em * 0.8, y + em * 0.6, w - em * 1.6, [[eff, int(em * 0.9), INK, UI.noto()]], 0.0)
		y += eh + em * 0.3
		y = _sec(ci, x, y, "얻는 곳")
		var src := rune_src(k)
		if src.is_empty(): src = [["아직 얻는 곳이 알려지지 않았다.", "", false]]
		for q in src:
			var line: String = q[0] + (" · " + q[1] if q[1] != "" else "")
			var hh := paras_h(w, [[line, int(em * 0.8), INK2, UI.noto()]], 0.0)
			ci.draw_multiline_string(UI.noto(), Vector2(x, y + UI.noto().get_ascent(int(em * 0.8))), line, HORIZONTAL_ALIGNMENT_LEFT, w, int(em * 0.8), -1, INK3 if q[2] else INK2)
			if not q[2]: ci.draw_string(UI.noto_k(), Vector2(x, y + UI.noto().get_ascent(int(em * 0.8))), q[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.8), INK)
			y += hh + em * 0.2
		if Rd["g"] != "unique":
			var on: bool = R().track == k
			var st := "추적 중 · 그만두기" if on else "이 룬 추적하기"
			var sw := tw(UI.noto(), st, int(em * 0.78)) + em * 1.8
			var sr := Rect2(x, y + em * 0.5, sw, em * 1.5)
			var c0 := sr.get_center()
			ci.draw_set_transform(c0, deg_to_rad(-3.0))
			var lr := Rect2(-sr.size / 2.0, sr.size)
			if on: ci.draw_rect(lr, RED)
			ci.draw_rect(lr, RED, false, 2.0)
			ctext(ci, UI.noto(), Vector2(0, em * 0.28), st, int(em * 0.78), Color("#fbe7c8") if on else RED)
			ci.draw_set_transform(Vector2.ZERO)
			_ph(n, sr, func():
				R().track = "" if R().track == k else k
				var F = arena.get("fame")
				if F != null and F.get("track") != null: F.set("track", R().track)
				sfx("slam", 0.3)
				vps[n].get_child(0).queue_redraw())
		var fl := "추적하면 화면 위 목표 줄에 얻는 곳이 뜨고, 손에 넣으면 알려 준다."
		var fh := paras_h(w, [[fl, int(em * 0.76), INK2, UI.noto()]], 0.0)
		var fy := sz.y - em * 2.4 - fh
		ci.draw_line(Vector2(x, fy - em * 0.5), Vector2(x + w, fy - em * 0.5), Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.25), 1.0)
		paras(ci, x, fy, w, [[fl, int(em * 0.76), INK2, UI.noto()]], 0.0)
	else:
		y = _sec(ci, x, y, "관찰 기록")
		if not s:
			var eh2 := em * 2.4
			ci.draw_rect(Rect2(x, y, w, eh2), Color(1, 1, 1, 0.5))
			ci.draw_rect(Rect2(x, y, em * 0.25, eh2), INK3)
			ci.draw_string(UI.noto(), Vector2(x + em * 0.8, y + em * 1.5), "만나면 기록이 시작된다.", HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.9), INK)
		else:
			y = _obs(ci, x, y, w, k)
			var weak := _weak(k)
			ci.draw_string(UI.noto_k(), Vector2(x, sz.y - em * 2.6), weak, HORIZONTAL_ALIGNMENT_LEFT, w, int(em * 0.78), RED)
	_folio(ci, sz, 4 + i * 2, true)
	if i < list.size() - 1: _corner(ci, sz, true, n)

func _sec(ci: Control, x: float, y: float, s: String) -> float:
	ci.draw_string(UI.spaced(UI.noto(), int(em * 0.1)), Vector2(x, y + em * 0.9), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.7), INK3)
	return y + em * 1.4

## bsObs: every stage opens a sealed part of the page
func _obs(ci: Control, x: float, y: float, w: float, k: String) -> float:
	var E: Dictionary = RN.ENEMY[k]
	var st: int = R().best_stage_of(k)
	var th: Array = R().best_th(k)
	var fs := int(em * 0.82)
	var f := UI.noto()
	var fb := UI.noto_k()
	# 관찰 등급 Ⅰ Ⅱ Ⅲ Ⅳ
	ci.draw_string(fb, Vector2(x, y + em * 0.7), "관찰 등급", HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.7), INK3)
	var bx := x + tw(fb, "관찰 등급", int(em * 0.7)) + em * 0.4
	for i in 4:
		var on := i + 1 <= st
		var lab: String = ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ"][i]
		var bw := tw(UI.noto(), lab, int(em * 0.7)) + em * 0.6
		var br := Rect2(bx, y, bw, em * 0.95)
		if on: ci.draw_rect(br, RED, false, 2.0)
		else:
			var dx := 0.0
			while dx < bw:
				ci.draw_line(br.position + Vector2(dx, 0), br.position + Vector2(minf(bw, dx + 3), 0), INK3, 1.5)
				ci.draw_line(br.position + Vector2(dx, br.size.y), br.position + Vector2(minf(bw, dx + 3), br.size.y), INK3, 1.5)
				dx += 6.0
		ci.draw_string(UI.noto(), br.position + Vector2(em * 0.3, em * 0.75), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.7), RED if on else INK3)
		bx += bw + em * 0.3
	y += em * 1.4
	var kills := int(R().best_kills.get(k, 0))
	y += _rich(ci, x, y, w, [["출현 ", true], [E["where"] + " · ", false], ["처치 ", true], [str(kills), false]])
	if st >= 2:
		var defs: Array = E["defEl"]
		var dl: Array = []
		for d in defs: dl.append(RN.ELN[d])
		y += _rich(ci, x, y, w, [["공격 ", true], [RN.ELN[E["atkEl"]] + " · ", false], ["내성 ", true], [" · ".join(dl), false]])
		var xx := x
		for c in arena.player.roster():     # ROSTER (8382)
			var m := 0.0
			for e in RN.ATKEL[c]: m += RN.eff_mul(e, defs) / RN.ATKEL[c].size()
			var rr := roundf(m * 100.0) / 100.0
			var s := "%s ×%s" % [RN.pname(c), RN.fmt(rr)]
			ci.draw_string(f, Vector2(xx, y + em * 0.75), s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.74), Color("#2f7a3a") if rr > 1.0 else (RED if rr < 1.0 else INK2))
			xx += tw(f, s, int(em * 0.74)) + em * 0.6
		y += em * 1.2
	else:
		y = _lock(ci, x, y, w, "Ⅱ 전투 기록", "처치 1회")
	if st >= 3:
		for b in [["체력", float(E["hp"]), maxf(100.0, E["hp"])], ["공격", float(E["atk"]), 20.0], ["속도", roundf(E["ms"] / 0.09 * 100.0), 200.0]]:
			ci.draw_string(f, Vector2(x, y + em * 0.7), b[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.74), INK)
			var bw2 := w - em * 4.6
			ci.draw_rect(Rect2(x + em * 2.4, y + em * 0.3, bw2, em * 0.45), Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.18))
			ci.draw_rect(Rect2(x + em * 2.4, y + em * 0.3, bw2 * minf(1.0, b[1] / b[2]), em * 0.45), INK2)
			ci.draw_string(SERIF, Vector2(x + w - em * 1.8, y + em * 0.75), RN.fmt(b[1]) if b[1] > 0.0 else "-", HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.72), INK)
			y += em * 1.1
	else:
		y = _lock(ci, x, y, w, "Ⅲ 능력치 · 약점", "처치 %d회" % th[0])
	if st >= 4:
		var note: String = RN.OBSNOTE.get(k, "기록 없음.")
		var ps: Array = [["Ⅳ 관리 기록", int(em * 0.78), INK, fb], [note, int(em * 0.76), INK2, f], ["관찰 완료 · 이 적에게 주는 피해 +5%", int(em * 0.7), INK3, f]]
		var hh := paras_h(w - em * 1.4, ps, 2.0) + em * 0.8
		ci.draw_rect(Rect2(x, y, w, hh), Color(1, 1, 1, 0.45))
		ci.draw_rect(Rect2(x, y, em * 0.22, hh), RED)
		paras(ci, x + em * 0.7, y + em * 0.4, w - em * 1.4, ps, 2.0)
		y += hh + em * 0.3
	else:
		y = _lock(ci, x, y, w, "Ⅳ 관리 기록", "처치 %d회" % th[1])
	var nxt: String = ["만나면", "처치 1", "처치 %d" % th[0], "처치 %d" % th[1], ""][st]
	var stn: String = ["미등록", "Ⅰ 만남", "Ⅱ 첫 처치", "Ⅲ 숙련", "Ⅳ 완료"][st]
	var expn: int = (RN.BSTEPB if RN.is_boss(k) else RN.BSTEP)[mini(4, st + 1)]
	var line := "관찰 " + stn + ((" · 다음: %s (EXP +%d)" % [nxt, expn]) if st < 4 else " · 모두 밝혀냈다")
	y += _rich(ci, x, y, w, [[line, false]])
	return y

func _rich(ci: Control, x: float, y: float, w: float, segs: Array) -> float:
	var xx := x
	var fs := int(em * 0.8)
	for sgm in segs:
		var f: Font = UI.noto_k() if sgm[1] else UI.noto()
		ci.draw_string(f, Vector2(xx, y + em * 0.8), sgm[0], HORIZONTAL_ALIGNMENT_LEFT, x + w - xx, fs, INK if sgm[1] else INK2)
		xx += tw(f, sgm[0], fs)
	return em * 1.25

## a sealed part: redacted bars and what opens it
func _lock(ci: Control, x: float, y: float, w: float, title: String, need: String) -> float:
	var h := em * 3.6
	var r := Rect2(x, y + em * 0.2, w, h)
	var dx := 0.0
	while dx < w:
		ci.draw_line(r.position + Vector2(dx, 0), r.position + Vector2(minf(w, dx + 4), 0), Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.4), 1.0)
		ci.draw_line(r.position + Vector2(dx, h), r.position + Vector2(minf(w, dx + 4), h), Color(90 / 255.0, 70 / 255.0, 50 / 255.0, 0.4), 1.0)
		dx += 7.0
	ci.draw_string(UI.noto_k(), r.position + Vector2(em * 0.6, em * 1.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.74), INK3)
	var bx := r.position.x + em * 0.6
	for n in [5, 3, 7]:
		ci.draw_rect(Rect2(bx, r.position.y + em * 1.4, n * em * 0.55, em * 0.7), Color(INK, 0.8))
		bx += n * em * 0.55 + em * 0.3
	bx = r.position.x + em * 0.6
	for n in [4, 6]:
		ci.draw_rect(Rect2(bx, r.position.y + em * 2.3, n * em * 0.55, em * 0.7), Color(INK, 0.8))
		bx += n * em * 0.55 + em * 0.3
	var lk := r.position + Vector2(em * 0.6, h - em * 0.62)
	ci.draw_arc(lk + Vector2(em * 0.25, 0), em * 0.18, PI, TAU, 8, INK3, 1.5)
	ci.draw_rect(Rect2(lk + Vector2(0, 0), Vector2(em * 0.5, em * 0.38)), INK3)
	ci.draw_string(UI.noto(), lk + Vector2(em * 0.75, em * 0.38), need, HORIZONTAL_ALIGNMENT_LEFT, -1, int(em * 0.66), INK3)
	return y + h + em * 0.5

func _weak(k: String) -> String:
	if R().best_stage_of(k) < 3: return "약점 · ???"
	var defs: Array = RN.ENEMY[k]["defEl"]
	var L: Array = []
	for e in RN.ELN:
		if RN.eff_mul(e, defs) > 1.0: L.append(RN.ELN[e])
	return ("약점 · " + " ".join(L)) if not L.is_empty() else "약점 없음"
