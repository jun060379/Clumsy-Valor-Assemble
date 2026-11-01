extends Control
## The guild system's screen effects, on their own canvas layer over the menus:
##   · notice feed (prototype notice(): glitch-typed lines with a tag, top left)
##   · lvCut (sortie.js): letterbox slam, white flash, three bands with the number glitch-assembling, rays, Eva flicker
##   · rankCut (sortie.js): the bureau's letter is stamped, the guild colour sweeps in, Eilin smiles, the stamp flies
##     to the new rank's name, the unlock tags drop in; tap to close → the guild book
##   · title cards (sortie.js tcPlay) 'letter' (the bureau's review) and 'ch' (a new chapter of the 모험 일지)
## The world holds still under the rank cut and the cards (fame.holds()).

const S := preload("res://scripts/fame_skin.gd")
const FD := preload("res://scripts/fame_data.gd")
const SMILE := preload("res://assets/fame/eilin_smile.png")
const AC := Color("#7fd0ff")
const FA := Color("#ffd34d")
const RED := Color("#d52a36")
const GL := "0123456789#%▓▒░"
const GLY := "▓▒░█■□◆◇╳#%&ㄱㄴㄷㄹㅁㅂㅅㅇ"

var fame
var arena
var clock := 0.0
# notices
var feed: Array = []            # {s, tag, col, big, life, t}
# lvCut
var lv := {}                    # {a, b, t, nx}
# rankCut
var rk := {}                    # {r, t, ready, out}
# title card
var tc := {}                    # {kind, o, t, cut, ...}
var vig: GradientTexture2D


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 0.8, 1.0])
	g.colors = PackedColorArray([Color(0.02, 0.016, 0.04, 0), Color(0.02, 0.016, 0.04, 0), Color(0.02, 0.016, 0.04, 0.75), Color(0.02, 0.016, 0.04, 0.75)])
	vig = GradientTexture2D.new()
	vig.gradient = g
	vig.fill = GradientTexture2D.FILL_RADIAL
	vig.fill_from = Vector2(0.5, 0.5)
	vig.fill_to = Vector2(1.0, 0.5)
	vig.width = 256
	vig.height = 256

func blocking() -> bool:
	return not rk.is_empty() or not tc.is_empty()

func busy() -> bool:
	return blocking() or not lv.is_empty()

func _snd(n: String, v := 0.6) -> void:
	if arena != null: arena.sfx(n, v)

func _beep(f: float, d: float, v := 0.05, ty := "square") -> void:
	S.play(self, S.beep_wav(f, d, ty), v)


# ---------- notices ----------
func notice(s: String, tag := "", col := Color.WHITE, big := false, life := 2600.0) -> void:
	feed.append({"s": s, "tag": tag, "col": col, "big": big, "life": life, "t": 0.0})
	while feed.size() > 4: feed.pop_front()

func _feed_hidden() -> bool:
	if arena == null: return true
	if arena.dlg != null and arena.dlg.active: return true
	if arena.ui_root != null and (arena.ui_root.title.active or arena.ui_root.menu.is_open()): return true
	return false


# ---------- per frame ----------
func _process(delta: float) -> void:
	var dt := minf(delta * 1000.0, 250.0)
	clock += dt
	for n in feed: n["t"] += dt
	feed = feed.filter(func(n): return n["t"] < n["life"] + 320.0)
	if not lv.is_empty():
		lv["t"] += dt
		_lv_events()
		if lv["t"] > 3420.0: lv = {}
	if not rk.is_empty():
		rk["t"] += dt
		_rk_events()
	if not tc.is_empty():
		tc["t"] += dt
		_tc_step()
	queue_redraw()

func _draw() -> void:
	var vs := get_viewport_rect().size
	if not _feed_hidden(): _draw_feed(vs)
	if not lv.is_empty(): _draw_lv(vs)
	if not rk.is_empty(): _draw_rk(vs)
	if not tc.is_empty(): _draw_tc(vs)


func _draw_feed(vs: Vector2) -> void:
	var y := 100.0 if arena.level_kind() in ["town", "dungeon"] else 64.0
	for n in feed:
		var t: float = n["t"]
		var fs := 21 if n["big"] else 14
		var h := fs + 10.0
		var tag: String = n["tag"]
		var s: String = n["s"]
		var chars := s.length()
		var i := int(t / 24.0)
		var shown := s.substr(0, mini(i, chars))
		if i < chars:
			for j in 3:
				if i + j < chars: shown += " " if s[i + j] == " " else GLY[randi() % GLY.length()]
		# in: steps(3) slide from the left with a skew; out: steps(4) jitter and wipe
		var x := 14.0
		var a := 1.0
		var u_in := floorf(clampf(t / 250.0, 0.0, 1.0) * 3.0) / 3.0
		x += (-24.0 if u_in < 0.34 else (6.0 if u_in < 0.67 else 0.0)) if u_in < 1.0 else 0.0
		var life: float = n["life"]
		if t > life:
			var u := floorf(clampf((t - life) / 300.0, 0.0, 1.0) * 4.0) / 4.0
			x += [0.0, 4.0, -6.0, -30.0, -30.0][int(u * 4.0)]
			a = 1.0 - u
		var bf := S.bhs()
		var w := S.tw(bf, shown, fs) + 30.0 + (S.tw(S.anton(false, 2), tag, 10) + 8.0 if tag != "" else 0.0)
		for k in 12:
			draw_rect(Rect2(x + w * k / 12.0, y, w / 12.0 + 1.0, h), Color(0, 0, 0, 0.72 * (1.0 - k / 12.0) * a))
		draw_rect(Rect2(x, y, 3.0, h), Color(n["col"], a))
		var tx := x + 11.0
		if tag != "":
			draw_string(S.anton(false, 2), Vector2(tx, y + h / 2.0 + 4.0), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(n["col"], a))
			tx += S.tw(S.anton(false, 2), tag, 10) + 8.0
		var by := y + h / 2.0 + fs * 0.36
		if i <= chars:
			draw_string(bf, Vector2(tx - 1.5, by), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.16, 0.35, 0.85 * a))
			draw_string(bf, Vector2(tx + 1.5, by), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.16, 0.86, 1, 0.85 * a))
		else:
			draw_string(bf, Vector2(tx + 1, by + 1), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a))
		draw_string(bf, Vector2(tx, by), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))
		y += h + 4.0


# ================= lvCut =================
func lv_cut(a: int, b: int) -> void:
	var nx := []
	if a < 3 and b >= 3: nx.append(["일일 훈련 개방", true])
	nx.append(["레벨 보상 %d개 · 모험 수첩" % (b - a), false])
	lv = {"a": a, "b": b, "t": 0.0, "nx": nx, "ev": {}}
	_snd("slam", 0.6)

func _once(D: Dictionary, key: String, at: float) -> bool:
	if D["t"] >= at and not D["ev"].has(key):
		D["ev"][key] = true
		return true
	return false

func _lv_events() -> void:
	if _once(lv, "rd", 560.0): _snd("ready", 0.5)
	if _once(lv, "land", 940.0): _snd("slam", 0.9)

func _draw_lv(vs: Vector2) -> void:
	var t: float = lv["t"]
	var W := vs.x
	var H := vs.y
	# shake on landing
	var sh := Vector2.ZERO
	if t >= 940.0 and t < 1140.0:
		var u := (t - 940.0) / 200.0
		sh = Vector2(5, 4).lerp(Vector2(-4, -3), u * 2.0) if u < 0.5 else Vector2(-4, -3).lerp(Vector2.ZERO, (u - 0.5) * 2.0)
	draw_set_transform(sh)
	# vignette
	var va := S.k(t, 0.0, 260.0) * (1.0 - S.k(t, 2900.0, 400.0))
	draw_texture_rect(vig, Rect2(-W * 0.2, -H * 0.4, W * 1.4, H * 1.8), false, Color(1, 1, 1, va))
	# rays
	if t >= 940.0 and t < 2240.0:
		var u := (t - 940.0) / 1300.0
		var ra := u / 0.3 if u < 0.3 else 1.0 - (u - 0.3) / 0.7
		var rot := deg_to_rad(8.0 * u / 0.3 if u < 0.3 else 8.0 + 6.0 * (u - 0.3) / 0.7)
		var sc := 0.8 + 0.2 * u / 0.3 if u < 0.3 else 1.0 + 0.1 * (u - 0.3) / 0.7
		_rays(Vector2(W / 2.0, H / 2.0), maxf(W, H) * 1.556 * sc, rot, 0.16 * ra)
	# the band group, rotated -6°
	var gw := W * 1.2
	var gh := H * 0.46
	var gc := Vector2(W / 2.0, H * 0.47)
	var xf := Transform2D(deg_to_rad(-6.0), gc + sh)
	var cols := [Color.WHITE, AC, Color("#0d0b10")]
	var ys := [[-0.07, 1.07], [-0.02, 1.02], [0.03, 0.97]]
	for i in 3:
		var e_in := S.ez(S.k(t, 120.0 + i * 55.0, 280.0))
		var e_out := S.ez(S.k(t, 2770.0 + (2 - i) * 60.0, 340.0))
		var ox := -1.2 * gw * (1.0 - e_in) + 1.2 * gw * e_out
		var r := Rect2(-gw / 2.0 + ox, -gh / 2.0 + gh * ys[i][0], gw, gh * (ys[i][1] - ys[i][0]))
		draw_set_transform_matrix(xf)
		draw_rect(r, cols[i])
		if i == 2:
			S.dots(self, r.grow(-2), 10.0, 1.2, Color(1, 1, 1, 0.07))
			var off := fmod(t / 350.0, 1.0) * 140.0
			var x := r.position.x - off + 60.0
			while x < r.end.x:
				if x > r.position.x: draw_rect(Rect2(x, r.position.y, 2.0, r.size.y), Color(AC, 0.12))
				x += 140.0
	# the content
	var ca := S.k(t, 260.0, 320.0) * (1.0 - S.k(t, 2700.0, 240.0))
	var cx := -140.0 * (1.0 - S.ez(S.k(t, 260.0, 320.0))) + 180.0 * S.ein(S.k(t, 2700.0, 240.0))
	var hidden := false
	for d in [0.0, 70.0, 140.0]:
		if t >= 1060.0 + d and t < 1095.0 + d: hidden = true
	if ca > 0.0 and not hidden:
		_lv_content(xf * Transform2D(0.0, Vector2(cx, 0)), H, ca, t)
	draw_set_transform(Vector2.ZERO)
	# letterbox
	var lh := H * 0.13
	var lb := S.ein(S.k(t, 0.0, 180.0)) * (1.0 - S.ein(S.k(t, 2960.0, 260.0)))
	draw_rect(Rect2(0, -lh + lh * lb, W, lh), Color.BLACK)
	draw_rect(Rect2(0, H - lh * lb, W, lh), Color.BLACK)
	var sf := S.anton(false, 5)
	draw_string(sf, Vector2(W * 0.03, -lh + lh * lb + lh * 0.82 - 2.0), "ADVENTURER · RECORD UPDATED", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, AC)
	var bt := "CLUMSY VALOR · GUILD"
	draw_string(sf, Vector2(W * 0.97 - S.tw(sf, bt, 9), H - lh * lb + lh * 0.18 + 10.0), bt, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, AC)
	# flashes
	var fl := 0.85 * (1.0 - S.k(t, 0.0, 140.0))
	if t >= 940.0: fl = maxf(fl, 0.7 * (1.0 - S.k(t, 940.0, 160.0)))
	if fl > 0.0: draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, fl))

func _rays(c: Vector2, R: float, rot: float, a: float) -> void:
	if a <= 0.0: return
	var step := deg_to_rad(9.0)
	var w := deg_to_rad(1.2)
	var rs := [R * 0.09, R * 0.22, R * 0.6]
	var al := [0.0, a, 0.0]
	for i in 40:
		var a0 := rot + i * step
		var d0 := Vector2(cos(a0), sin(a0))
		var d1 := Vector2(cos(a0 + w), sin(a0 + w))
		for j in 2:
			draw_polygon(PackedVector2Array([c + d0 * rs[j], c + d1 * rs[j], c + d1 * rs[j + 1], c + d0 * rs[j + 1]]),
				PackedColorArray([Color(1, 1, 1, al[j]), Color(1, 1, 1, al[j]), Color(1, 1, 1, al[j + 1]), Color(1, 1, 1, al[j + 1])]))

func _lv_content(xf: Transform2D, H: float, ca: float, t: float) -> void:
	var b: int = lv["b"]
	var a: int = lv["a"]
	var fs_lb := clampi(int(H * 0.1), 34, 78)
	var fs_num := clampi(int(H * 0.3), 90, 240)
	var fs_old := clampi(int(H * 0.09), 30, 70)
	var fi := S.anton(true)
	var bf := S.spaced(S.bhs(), 4)
	var lbw := S.tw(bf, "레벨 업", fs_lb)
	var nums := str(b)
	var numw := maxf(S.tw(fi, nums, fs_num), fs_num * 0.55)
	var oldw := S.tw(fi, str(a), fs_old)
	var txs: Array = lv["nx"]
	var txw := 0.0
	for s in txs: txw = maxf(txw, S.tw(S.noto(), s[0], 12) + 26.0)
	var gap := clampf(get_viewport_rect().size.x * 0.034, 14.0, 40.0)
	var nmw := oldw + 12.0 + 22.0 + 12.0 + numw
	var total := lbw + gap + nmw + gap + txw
	var x0 := -total / 2.0
	draw_set_transform_matrix(xf)
	# lb
	draw_string(S.anton(false, 5), Vector2(x0, -fs_lb * 0.62), "ADVENTURER LV", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(AC, ca))
	var bs := 2.2 - 1.2 * S.ein(S.k(t, 300.0, 220.0))
	var ba := S.k(t, 300.0, 220.0) * ca
	draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(bs, 1.0), 0.0, Vector2(x0, 0)))
	draw_string(bf, Vector2(0, fs_lb * 0.32), "레벨 업", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_lb, Color(1, 1, 1, ba))
	var ea := S.k(t, 420.0, 260.0) * ca
	var ex := -30.0 * (1.0 - S.bk(S.k(t, 420.0, 260.0)))
	draw_set_transform_matrix(xf)
	var emw := S.tw(fi, "LEVEL UP!", 17) + 20.0
	S.para(self, Rect2(x0 + ex, fs_lb * 0.42, emw, 24), 4.0, Color(1, 1, 1, ea))
	draw_string(fi, Vector2(x0 + ex + 8.0, fs_lb * 0.42 + 19.0), "LEVEL UP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0, 0, 0, ea))
	# nm: old number struck, ▶, the new number glitching in
	var nx := x0 + lbw + gap
	draw_string(fi, Vector2(nx, fs_old * 0.36), str(a), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_old, Color(1, 1, 1, 0.35 * ca))
	var sk := S.k(t, 520.0, 160.0)
	if sk > 0.0:
		var sw := oldw * 1.24
		var p0 := Vector2(nx - oldw * 0.12, -fs_old * 0.0)
		var dir := Vector2(cos(deg_to_rad(-14.0)), sin(deg_to_rad(-14.0)))
		draw_line(p0 - dir * 0.0, p0 + dir * sw * sk, Color(Color("#e8243c"), ca), 5.0)
	nx += oldw + 12.0
	draw_string(S.anton(), Vector2(nx, 10.0), "▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(AC, ca))
	nx += 34.0
	var ns := str(a)
	var vis := true
	var col := AC
	var sc := 1.0
	var rot := 0.0
	if t >= 560.0 and t < 940.0:
		ns = GL[randi() % GL.length()] + (str(randi() % 10) if nums.length() > 1 else "")
		vis = randf() >= 0.2
	elif t >= 940.0:
		ns = nums
		var u := S.k(t, 940.0, 260.0)
		var e := S.bk(u)
		sc = 1.6 - 0.6 * e
		rot = deg_to_rad(-10.0) * (1.0 - e)
		col = Color.WHITE.lerp(AC, u)
	if vis:
		var nw := S.tw(fi, ns, fs_num)
		var cen := Vector2(nx + numw / 2.0, 0)
		draw_set_transform_matrix(xf * Transform2D(rot, Vector2(sc, sc), 0.0, cen))
		var p := Vector2(-nw / 2.0, fs_num * 0.36)
		draw_string(fi, p + Vector2(10, 10), ns, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_num, Color(0, 0, 0, ca))
		draw_string_outline(fi, p, ns, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_num, 8, Color(1, 1, 1, ca))
		draw_string(fi, p, ns, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_num, Color(col, ca))
		draw_set_transform_matrix(xf)
	# tx: what opened
	var tx := x0 + lbw + gap + nmw + gap
	var ty := -float(txs.size()) * 15.0
	for i in txs.size():
		var u := S.k(t, 1150.0 + i * 90.0, 320.0)
		if u <= 0.0: continue
		var e := S.bk(u)
		var s: String = txs[i][0]
		var w := S.tw(S.noto(), s, 12) + 20.0
		var y := ty + i * 30.0 - 26.0 * (1.0 - e)
		draw_set_transform_matrix(xf * Transform2D(deg_to_rad(2.0 if i % 2 else -2.0), Vector2(tx, y)))
		S.para(self, Rect2(0, 0, w, 22), 4.0, Color(Color.WHITE if txs[i][1] else AC, u * ca))
		draw_string(S.noto(), Vector2(10, 16), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, u * ca))
	draw_set_transform(Vector2.ZERO)


# ================= rankCut =================
const RK_T1 := 2080.0           # the letter gives way to the yellow scene

func rank_cut() -> void:
	rk = {"r": fame.r, "t": 0.0, "ready": 999999.0, "out": -1.0, "ev": {}}
	_release()
	S.play(self, S.noise_wav(0.16), 0.3)

func _rk_events() -> void:
	var t: float = rk["t"]
	if _once(rk, "slam", 1110.0): _snd("slam", 0.9)
	if _once(rk, "ready", 1500.0): _snd("ready", 0.8)
	if _once(rk, "num", RK_T1 + 1000.0): _snd("slam", 0.8)
	if rk["out"] >= 0.0 and t - rk["out"] > 500.0:
		rk = {}
		if fame != null: fame.rank_cut_done()

func _rk_close() -> void:
	if rk.is_empty() or rk["t"] < RK_T1 + 2000.0 or rk["out"] >= 0.0: return
	rk["out"] = rk["t"]
	_snd("ready", 0.5)

func _draw_rk(vs: Vector2) -> void:
	var t: float = rk["t"]
	var r: int = rk["r"]
	var R: Dictionary = FD.FRANK[r - 1]
	var W := vs.x
	var H := vs.y
	var sh := Vector2.ZERO
	if t >= 1110.0 and t < 1310.0:
		var u := (t - 1110.0) / 200.0
		sh = Vector2(6, 5).lerp(Vector2(-4, -3), u * 2.0) if u < 0.5 else Vector2(-4, -3).lerp(Vector2.ZERO, (u - 0.5) * 2.0)
	if t >= RK_T1 + 1000.0 and t < RK_T1 + 1180.0:
		sh.y += 6.0 * (1.0 - (t - RK_T1 - 1000.0) / 180.0)
	draw_set_transform(sh)
	var scene := t >= RK_T1
	if not scene:
		draw_rect(Rect2(-10, -10, W + 20, H + 20), Color("#0d0b10"))
		S.dots(self, Rect2(Vector2.ZERO, vs), 11.0, 1.4, Color(1, 1, 1, 0.05))
		_rk_doc(vs, t, r, R)
	else:
		_rk_scene(vs, t - RK_T1, r, R)
	_rk_stamp(vs, t)
	# the bands: in at 1500 (white, black, yellow — black on top), out at T1, in again on close
	var cols := {"w": Color.WHITE, "c": FA, "k": Color.BLACK}
	for key in ["w", "c", "k"]:
		var i: int = ["w", "k", "c"].find(key)
		var ox := 0.0
		if not scene:
			ox = -2.52 * W * (1.0 - S.ein(S.k(t, 1500.0 + i * 80.0, 420.0)))
		else:
			var j: int = ["c", "k", "w"].find(key)
			ox = 2.52 * W * S.ez(S.k(t, RK_T1 + j * 90.0, 480.0))
		if rk["out"] >= 0.0:
			ox = -2.52 * W * (1.0 - S.ein(S.k(t, rk["out"] + i * 60.0, 340.0)))
		var x0 := -0.4 * W + ox
		var top := -0.3 * H
		var bot := 1.3 * H
		var skw := tan(deg_to_rad(14.0)) * (bot - top)
		if x0 + 1.8 * W + skw < 0.0 or x0 - skw > W: continue
		draw_colored_polygon(PackedVector2Array([Vector2(x0 + skw / 2.0, top), Vector2(x0 + 1.8 * W + skw / 2.0, top), Vector2(x0 + 1.8 * W - skw / 2.0, bot), Vector2(x0 - skw / 2.0, bot)]), cols[key])
	draw_set_transform(Vector2.ZERO)

func _rk_doc_rect(vs: Vector2) -> Rect2:
	var w := minf(vs.x * 0.62, 520.0)
	return Rect2(-w / 2.0, -98.0, w, 196.0)

func _rk_doc(vs: Vector2, t: float, r: int, R: Dictionary) -> void:
	var u := S.ez(S.k(t, 0.0, 620.0))
	var a := clampf(t / 124.0, 0.0, 1.0)
	var c := Vector2(vs.x / 2.0, vs.y / 2.0).lerp(Vector2(vs.x / 2.0, vs.y / 2.0), u) + Vector2(0, (1.0 - u) * vs.y * 0.9 * 0.5)
	var rot := deg_to_rad(lerpf(6.0, -3.0, u))
	draw_set_transform(c, rot)
	var d := _rk_doc_rect(vs)
	draw_rect(Rect2(d.position + Vector2(10, 12), d.size), Color(0, 0, 0, a))
	draw_rect(d, Color(Color("#efe3c6"), a))
	var ly := d.position.y + 27.0
	while ly < d.end.y:
		draw_rect(Rect2(d.position.x, ly, d.size.x, 1), Color(0.24, 0.16, 0.08, 0.08 * a))
		ly += 28.0
	draw_rect(Rect2(d.position.x + 22.0, d.position.y, 1, d.size.y), Color(0.78, 0.27, 0.27, 0.25 * a))
	var ink := Color(Color("#2e2116"), a)
	var x := d.position.x + 36.0
	var y := d.position.y + 30.0
	draw_string(S.anton(false, 4), Vector2(x, y), "GUILD BUREAU · REVIEW RESULT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(Color("#8a7458"), a))
	y += 32.0
	draw_string(S.serif(), Vector2(x, y), "등급 심사 결과 통지", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
	y += 34.0
	draw_string(S.serif(), Vector2(x, y), "귀 길드 「어설픈 용맹」은 심사 과제를 모두 이행하였으므로,", HORIZONTAL_ALIGNMENT_LEFT, d.end.x - x - 16.0, 13, ink)
	y += 24.0
	var p1 := "길드 등급을 "
	var p2 := "%d등급 「%s」" % [r, R["n"]]
	draw_string(S.serif(), Vector2(x, y), p1, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	var w1 := S.tw(S.serif(), p1, 13)
	draw_string(S.serif(), Vector2(x + w1, y), p2, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Color("#000"), a))
	draw_string(S.serif(), Vector2(x + w1 + S.tw(S.serif(), p2, 14), y), "으로 승인한다.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ink)
	y += 34.0
	var sig := "길드 관리국"
	draw_string(S.serif(), Vector2(d.end.x - 30.0 - S.tw(S.serif(), sig, 12), y), sig, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Color("#5a4632"), a))
	draw_set_transform(Vector2.ZERO)

## where the name plate sits in the yellow scene (screen space), for the stamp's flight
func _rk_layout(vs: Vector2, r: int, R: Dictionary) -> Dictionary:
	var hx := maxf(18.0, vs.x * 0.04)
	var hy := vs.y * 0.09
	var fs_em := clampi(int(vs.y * 0.3), 90, 230)
	var fs_nm := clampi(int(vs.y * 0.065), 24, 46)
	var emw := S.tw(S.anton(true), str(r), fs_em)
	var row_y := hy + 14.0 + 44.0 + 32.0 + fs_em * 0.78
	var nmw := S.tw(S.bhs(), R["n"], fs_nm) + 30.0
	var nm := Rect2(hx + emw + 14.0, row_y - fs_nm - 30.0, nmw, fs_nm + 11.0)
	return {"hx": hx, "hy": hy, "fs_em": fs_em, "fs_nm": fs_nm, "row_y": row_y, "nm": nm}

func _rk_scene(vs: Vector2, t: float, r: int, R: Dictionary) -> void:
	var W := vs.x
	var H := vs.y
	draw_rect(Rect2(-10, -10, W + 20, H + 20), FA)
	# rays from 62 % / 60 %, slowly turning; dots drifting
	var c := Vector2(W * 0.62, H * 0.6)
	var spin := clock / 70000.0 * TAU
	for i in 24:
		var a0 := spin + i * deg_to_rad(15.0)
		var L := maxf(W, H) * 1.6
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * L, c + Vector2(cos(a0 + deg_to_rad(6.0)), sin(a0 + deg_to_rad(6.0))) * L]), Color(0, 0, 0, 0.1))
	var dof := fmod(clock / 9000.0, 1.0) * 11.0
	S.dots(self, Rect2(Vector2.ZERO, vs), 11.0, 1.8, Color(0, 0, 0, 0.22), Vector2(dof, dof))
	# big outlined RANK n
	var bu := S.k(t, 200.0, 900.0)
	var bfs := int(minf(W * 0.32, 320.0))
	var bs := "RANK %d" % r
	var bw := S.tw(S.anton(), bs, bfs)
	draw_set_transform(Vector2(W * 1.04 - bw / 2.0 + 0.25 * bw * (1.0 - S.ez(bu)), H * 1.1 - bfs * 0.45), deg_to_rad(-8.0))
	draw_string_outline(S.anton(), Vector2(-bw / 2.0, bfs * 0.36), bs, HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, 3, Color(0, 0, 0, 0.14 * bu))
	draw_set_transform(Vector2.ZERO)
	# the black slab on the left
	var su := S.ez(S.k(t, 120.0, 560.0))
	var slab := Rect2(-0.14 * W, -0.25 * H, 0.58 * W, 1.6 * H)
	var sc := slab.get_center()
	var srot := deg_to_rad(lerpf(-24.0, -10.0, su))
	var pts := PackedVector2Array()
	for p in [slab.position, Vector2(slab.end.x, slab.position.y), slab.end, Vector2(slab.position.x, slab.end.y)]:
		pts.append(sc + Vector2(-0.6 * slab.size.x * (1.0 - su), 0) + (p - sc).rotated(srot))
	draw_colored_polygon(pts, Color.BLACK)
	# the white slash
	var lu := S.ez(S.k(t, 300.0, 420.0))
	draw_set_transform(Vector2(-0.1 * W, 0.8 * H), deg_to_rad(-7.0))
	draw_rect(Rect2(0, 0, 0.9 * W * lu, 10), Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	# Eilin, smiling
	var eu := S.k(t, 200.0, 620.0)
	if eu > 0.0:
		var e := S.ez(eu)
		var ox := 0.4 if e < 0.0 else (lerpf(0.4, -0.02, e / 0.75) if e < 0.75 else lerpf(-0.02, 0.0, (e - 0.75) / 0.25))
		var eh := H
		var ew := eh * SMILE.get_width() / SMILE.get_height()
		var er := Rect2(W * 0.98 - ew + ox * ew, H * 1.06 - eh, ew, eh)
		var ea := clampf(eu / 0.75, 0.0, 1.0)
		draw_texture_rect(SMILE, Rect2(er.position + Vector2(10, 0), er.size), false, Color(0, 0, 0, ea))
		draw_texture_rect(SMILE, Rect2(er.position + Vector2(-3, 0), er.size), false, Color(1, 1, 1, ea))
		draw_texture_rect(SMILE, er, false, Color(1, 1, 1, ea))
	# heading
	var Lo := _rk_layout(vs, r, R)
	var hx: float = Lo["hx"]
	var hy: float = Lo["hy"]
	var u1 := S.k(t, 260.0, 320.0)
	draw_string(S.anton(false, 5), Vector2(hx - 60.0 * (1.0 - S.ez(u1)), hy + 11.0), "GUILD RANK UP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(FA, u1))
	var u2 := S.k(t, 340.0, 340.0)
	if u2 > 0.0:
		var e2 := S.bk(u2)
		var fsz := clampi(int(H * 0.065), 24, 48)
		var lw := S.tw(S.anton(true), "APPROVED!", fsz) + 26.0
		draw_set_transform_matrix(Transform2D(deg_to_rad(lerpf(-20.0, -5.0, e2)), Vector2.ONE * lerpf(1.6, 1.0, e2), 0.0, Vector2(hx + lw / 2.0, hy + 18.0 + fsz * 0.6)))
		draw_colored_polygon(S.clip(Rect2(-lw / 2.0, -fsz * 0.62, lw, fsz * 1.24), [[0, 5], [100, 0], [97, 100], [1, 92]]), Color(1, 1, 1, u2))
		draw_string(S.anton(true), Vector2(-lw / 2.0 + 10.0, fsz * 0.4), "APPROVED!", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, Color(0, 0, 0, u2))
		draw_set_transform(Vector2.ZERO)
	# the rank number (r-1 rolls to r) and the name plate
	var row_y: float = Lo["row_y"]
	var fs_em: int = Lo["fs_em"]
	var u3 := S.k(t, 520.0, 380.0)
	if u3 > 0.0:
		var e3 := S.bk(u3)
		var num := str(r) if t >= 1000.0 else str(r - 1)
		var ns := 1.4 - 0.4 * e3
		var nrot := deg_to_rad(-5.0)
		var ncol := FA
		if t >= 1000.0:
			var u4 := S.k(t, 1000.0, 320.0)
			ns *= 1.5 - 0.5 * S.bk(u4)
			nrot += deg_to_rad(-8.0) * (1.0 - S.bk(u4))
			ncol = Color.WHITE.lerp(FA, u4)
		var p := Vector2(hx, row_y - 40.0 * (1.0 - e3))
		draw_set_transform_matrix(Transform2D(nrot, Vector2(ns, ns), 0.0, p + Vector2(fs_em * 0.3, -fs_em * 0.35)))
		var o := Vector2(-fs_em * 0.3, fs_em * 0.35)
		draw_string(S.anton(true), o + Vector2(10, 10), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_em, Color(0, 0, 0, u3))
		draw_string_outline(S.anton(true), o, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_em, 8, Color(1, 1, 1, u3))
		draw_string(S.anton(true), o, num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_em, Color(ncol, u3))
		draw_set_transform(Vector2.ZERO)
	var u5 := S.k(t, 1100.0, 420.0)
	if u5 > 0.0:
		var e5 := S.bk(u5)
		var nm: Rect2 = Lo["nm"]
		var fs_nm: int = Lo["fs_nm"]
		draw_set_transform_matrix(Transform2D(deg_to_rad(-5.0 + 8.0 * (1.0 - e5)), nm.position + Vector2(80.0 * (1.0 - e5), 0)))
		var pr := Rect2(Vector2.ZERO, nm.size)
		draw_colored_polygon(S.clip(Rect2(pr.position + Vector2(6, 6), pr.size), [[0, 5], [100, 0], [98, 100], [1, 93]]), Color(FA.darkened(0.15), u5))
		draw_colored_polygon(S.clip(pr, [[0, 5], [100, 0], [98, 100], [1, 93]]), Color(1, 1, 1, u5))
		draw_string(S.bhs(), Vector2(14, nm.size.y * 0.5 + fs_nm * 0.36), R["n"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs_nm, Color(0, 0, 0, u5))
		draw_set_transform(Vector2.ZERO)
	# what the rank opens
	var items: Array = FD.FUNLOCK[r - 1]
	var uy := H * 0.89 - items.size() * 30.0
	for i in items.size():
		var u := S.k(t, 1400.0 + i * 110.0, 340.0)
		if u <= 0.0: continue
		var s: String = items[i]
		var lk := s.contains("향후")
		var w := S.tw(S.noto(), s, 12) + 30.0
		draw_set_transform_matrix(Transform2D(deg_to_rad(1.5 if i % 2 else -2.0), Vector2(hx - 60.0 * (1.0 - S.bk(u)), uy + i * 30.0)))
		S.para(self, Rect2(0, 0, w, 24), 3.0, Color(0, 0, 0, u))
		draw_rect(Rect2(3, 0, 5, 24), Color(FA, u))
		draw_string(S.noto(), Vector2(16, 17), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Color(0.73, 0.73, 0.73) if lk else Color.WHITE, u))
		draw_set_transform(Vector2.ZERO)
	var ta := 0.7 * S.k(t, 2200.0, 400.0)
	var tt := "TAP TO CLOSE"
	draw_string(S.anton(false, 4), Vector2(W - 16.0 - S.tw(S.anton(false, 4), tt, 11), H - 12.0), tt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, ta))

## the stamp: slams onto the letter, then is lifted and carried beside the new rank's name
func _rk_stamp(vs: Vector2, t: float) -> void:
	if t < 900.0: return
	var r: int = rk["r"]
	var fs := clampi(int(vs.y * 0.07), 26, 48)
	var bf := S.bhs()
	var w := S.tw(bf, "승인", fs) + fs * 1.1
	var h := fs * 1.55
	var p0 := Vector2(vs.x * 0.58, vs.y * 0.52)
	var rot := deg_to_rad(-14.0)
	var sc := 1.0
	var a := 1.0
	var lifted := t >= RK_T1
	if t < 1120.0:
		var u := S.ein(S.k(t, 900.0, 220.0))
		sc = 3.0 - 2.0 * u
		rot = deg_to_rad(lerpf(-30.0, -14.0, u))
		a = u
	var p := p0
	if lifted:
		var Lo := _rk_layout(vs, r, FD.FRANK[r - 1])
		var nm: Rect2 = Lo["nm"]
		var p1 := Vector2(nm.end.x + 18.0, nm.position.y - 10.0)
		var u := clampf((t - RK_T1 - 600.0) / 760.0, 0.0, 1.0)
		var e := S.bez(0.45, 0.0, 0.2, 1.0, u)
		var mid := p0.lerp(p1, 0.6) + Vector2(0, -60)
		if e < 0.6:
			p = p0.lerp(mid, e / 0.6)
			rot = deg_to_rad(lerpf(-14.0, 10.0, e / 0.6))
			sc = lerpf(1.0, 1.15, e / 0.6)
		else:
			p = mid.lerp(p1, (e - 0.6) / 0.4)
			rot = deg_to_rad(lerpf(10.0, 12.0, (e - 0.6) / 0.4))
			sc = lerpf(1.15, 0.62, (e - 0.6) / 0.4)
	draw_set_transform_matrix(Transform2D(rot, Vector2(sc, sc), 0.0, p))
	var rr := Rect2(-w / 2.0, -h / 2.0, w, h)
	if lifted: draw_rect(rr, Color(1, 1, 1, a))
	draw_rect(rr, Color(RED, a), false, 2.0)
	draw_rect(rr.grow(-4.0), Color(RED, a), false, 1.5)
	draw_string(bf, Vector2(-S.tw(bf, "승인", fs) / 2.0, fs * 0.22), "승인", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(RED, a))
	var sm := maxi(8, int(fs * 0.3))
	draw_string(S.noto(), Vector2(-S.tw(S.noto(), "길드 관리국", sm) / 2.0, fs * 0.22 + sm + 4.0), "길드 관리국", HORIZONTAL_ALIGNMENT_LEFT, -1, sm, Color(RED, a))
	draw_set_transform(Vector2.ZERO)


# ================= title cards =================
## kind: "letter" (길드 관리국 · 등급 · 심사 · 개시) or "ch" ({no, n, d}: 제N장 · the chapter's name · its line)
func title_card(kind: String, o: Dictionary) -> void:
	tc = {"kind": kind, "o": o, "t": 0.0, "i": 0, "cut": {}, "flash": -1.0, "end": -1.0}
	_release()

func _release() -> void:
	if arena != null and arena.ui_root != null: arena.ui_root.menu._release_keys()

## the card scripts: [ms, action] — actions set the current cut, beep, flash, glitch
func _script() -> Array:
	var o: Dictionary = tc["o"]
	if tc["kind"] == "letter":
		return [[0.0, {"cut": [["E", "GUILD BUREAU", "yl"]], "beep": [660, 0.04, 0.04]}],
			[560.0, {"cut": [["T", "길드 관리국", "w", 0.3]], "beep": [440, 0.05, 0.05]}],
			[960.0, {"cut": [["T", "등급", "w", 0.4]], "beep": [440, 0.05, 0.05]}],
			[1260.0, {"cut": [["T", "심사", "w", 0.4]], "beep": [440, 0.05, 0.05]}],
			[1560.0, {"cut": [["T", "개시", "k", 0.4, 260.0], ["S", "접수대의 에일린에게 서신이 도착했다", "k"]], "inv": true, "frm": true, "flash": 80.0}],
			[2860.0, {"cut": [["T", "개시", "yl", 0.4]], "flick": [2, 90.0]}],
			[3160.0, {"end": true}]]
	var no: int = o.get("no", 1)
	var n: String = o.get("n", "")
	var d: String = o.get("d", "")
	return [[0.0, {"cut": [["E", "CHAPTER", "w60"]], "beep": [330, 0.05, 0.03]}],
		[480.0, {"cut": [["Tsf", "제%d장" % no, "w", 0.4]], "slam": true}],
		[1300.0, {"cut": [["Tsf", n, "w", 0.3]]}],
		[2500.0, {"cut": [["Tsf", n, "w", 0.3], ["S", d, "w"]], "beep": [330, 0.05, 0.03]}],
		[3700.0, {"end": true}]]

func _tc_step() -> void:
	var sc := _script()
	var t: float = tc["t"]
	while tc["i"] < sc.size() and t >= sc[tc["i"]][0]:
		var A: Dictionary = sc[tc["i"]][1]
		tc["i"] += 1
		if A.has("end"):
			_tc_end()
			return
		tc["cut"] = A.duplicate()
		tc["cut"]["t0"] = sc[tc["i"] - 1][0]
		if A.has("beep"): _beep(A["beep"][0], A["beep"][1], A["beep"][2])
		if A.has("slam"): _snd("slam", 0.9)
		if A.has("flash"): tc["flash"] = t
	# a glitching word lands with a hit and a flash
	var C: Dictionary = tc["cut"]
	for L in C.get("cut", []):
		if L[0] == "T" and L.size() > 4 and not C.has("hit") and t - C["t0"] >= L[4]:
			C["hit"] = true
			_snd("slam", 0.9)
			tc["flash2"] = t
		if L[0] == "T" and L.size() > 4 and t - C["t0"] < L[4] and randf() < 0.4:
			_beep(700.0 + randf() * 900.0, 0.02, 0.025)

func _tc_end() -> void:
	if tc.is_empty(): return
	if tc["end"] < 0.0: tc["end"] = tc["t"]

func _draw_tc(vs: Vector2) -> void:
	var t: float = tc["t"]
	var a := 1.0
	if tc["end"] >= 0.0:
		a = 1.0 - (t - tc["end"]) / 220.0
		if a <= 0.0:
			tc = {}
			return
	var C: Dictionary = tc["cut"]
	var inv: bool = C.get("inv", false)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, a) if inv else Color(0, 0, 0, a))
	if C.get("frm", false):
		draw_rect(Rect2(vs.x * 0.03, vs.y * 0.05, vs.x * 0.94, vs.y * 0.9), Color(0, 0, 0, 0.6 * a), false, 3.0)
	var hide := false
	if C.has("flick"):
		var dt0: float = t - C["t0"]
		var n: int = C["flick"][0]
		var gap: float = C["flick"][1]
		for i in n:
			if dt0 >= i * gap and dt0 < i * gap + gap / 2.0: hide = true
	var lines: Array = C.get("cut", [])
	# lay the lines out centred, 2.4vh apart
	var sizes := []
	var total := 0.0
	for L in lines:
		var fs := _tc_fs(L, vs)
		sizes.append(fs)
		total += fs
	total += maxf(0, lines.size() - 1) * vs.y * 0.024
	var y := vs.y / 2.0 - total / 2.0
	for i in lines.size():
		var L: Array = lines[i]
		var fs: int = sizes[i]
		var s: String = L[1]
		var f := _tc_font(L)
		var col := _tc_col(L[2])
		if L[0] == "T" and L.size() > 4:
			var dur: float = L[4]
			var u: float = (t - C["t0"]) / dur
			if u < 1.0:
				var fx2 := int(u * s.length() * 1.15)
				var out := ""
				for j in s.length():
					if s[j] == " ": out += " "
					elif j < fx2: out += s[j]
					else: out += " " if randf() < 0.3 else GLY[randi() % GLY.length()]
				s = out
		var w := S.tw(f, s, fs)
		if not hide:
			draw_string(f, Vector2(vs.x / 2.0 - w / 2.0, y + fs * 0.8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, a))
		y += fs + vs.y * 0.024
	for k in ["flash", "flash2"]:
		if tc.get(k, -1.0) >= 0.0:
			var fa: float = 0.9 * (1.0 - (t - tc[k]) / (80.0 if k == "flash" else 150.0))
			if fa > 0.0: draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, fa * a))
	var sk := "TAP TO SKIP"
	draw_string(S.anton(false, 3), Vector2(vs.x - 14.0 - S.tw(S.anton(false, 3), sk, 10), vs.y - 10.0), sk, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.53, 0.53, 0.53, a))

func _tc_font(L: Array) -> Font:
	match String(L[0]):
		"T": return S.bhs()
		"Tsf": return S.serif()
		"S": return S.spaced(S.noto(), 3)
	return S.anton(false, 8)

## fit(): the word fills up to ~88 % of the width and hk of the height
func _tc_fs(L: Array, vs: Vector2) -> int:
	match String(L[0]):
		"T", "Tsf":
			var hk: float = L[3] if L.size() > 3 else 0.3
			var n := maxi(1, String(L[1]).length())
			return int(minf(vs.y * hk, vs.x * 0.88 / (n * 0.98)))
		"S": return clampi(int(vs.y * 0.036), 14, 26)
	return clampi(int(vs.y * 0.038), 14, 28)

func _tc_col(k: String) -> Color:
	match k:
		"yl": return FA
		"k": return Color.BLACK
		"w60": return Color(1, 1, 1, 0.6)
		"rd": return Color("#e8243c")
		"or": return Color("#ff6a1a")
	return Color.WHITE


# ---------- input: tap / Enter / Esc skips a card; the rank cut closes once it has settled ----------
func _input(ev: InputEvent) -> void:
	if not blocking(): return
	var hit := false
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: hit = true
	elif ev is InputEventScreenTouch and ev.pressed: hit = true
	elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE, KEY_X, KEY_Z]: hit = true
	elif ev is InputEventJoypadButton and ev.pressed and ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X]: hit = true
	if not hit:
		if ev is InputEventKey or ev is InputEventMouseButton: get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if not tc.is_empty(): _tc_end()
	elif not rk.is_empty(): _rk_close()
