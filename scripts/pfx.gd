extends Node2D
## PFX (prototype PFXL / pfxCtx / pfxRng and every pfx* effect): pixel-art effects drawn in code. Every mark is one whole
## art pixel (2 world px), a few colours per palette, time stepped in 40 ms frames (effects move "on twos").
## Effects live on the world canvas above everything (z 11), unshaded, so the night / cave ambient does not dim them
## (the prototype drew them after the darkness pass) and the bloom pass (post_fx.gd) sees them. Big per-pixel rasters (the swing crescent, Aida's tears, the Hollow,
## Luce's pillar) are fragment shaders on a quad (shaders/pfx_*.gdshader); the rest are rects drawn here.
## The clock: frozen in hitstop, slowed with the world in the perfect-dodge slow time, held under menus.
##
## Spawners (world coords, ms): slash(), thrust(), dust(), hit(), djump(), dash_start(), dive_start(), slam(), charge(),
## gate() -> Dictionary (release with e["rel"] = true), bolt(), pillar(), heal_cross(), heal_burst(), rose_burst(), vow(),
## hollow(), utear(); afterimages: dodge_snap() / trail; perfect parry: parry_at(). Drawing helpers that other nodes call
## onto their own canvas: luce_bolt(), twinkle(), reticle(), ult_burst(), ult_star(), beam().

const CH := preload("res://scripts/chars.gd")
const CH_PLAYER := preload("res://scripts/player.gd")
const S := 2.0
const FR := 40.0
## Aida's 처형 slam, baked from pixelfx (tools/pixelfx_fx/rewind-slam.js): 56 frames of 440x176 at 30 fps, pivot (220, 140)
const AIDA_SLAM := preload("res://assets/fx/aida_rewind_slam.png")
## Aida's swing tears, baked from pixelfx (tools/pixelfx_fx/aida-tear-slash.js) per attack arc: 37 frames of 232x232 at
## 50 fps, pivot at the arc's centre; each has a mask sheet for the afterimage, a window onto the game in negative
const SH_NEG := preload("res://shaders/pfx_negmask.gdshader")
const AIDA_GATE := preload("res://assets/fx/aida_gate.png")
const AIDA_GATE_M := preload("res://assets/fx/aida_gate_mask.png")
## the dive landing, baked (tools/pixelfx_fx/aida-dive-land.js): 37 frames of 200x70 at 50 fps, pivot (100, 46)
const AIDA_DIVE := preload("res://assets/fx/aida_dive.png")
const AIDA_DIVE_M := preload("res://assets/fx/aida_dive_mask.png")
## the thrust, baked (tools/pixelfx_fx/aida-thrust-tear.js) at two lengths, 98 and 163 art px: 37 frames of 200x72
const AIDA_THR := [preload("res://assets/fx/aida_thrust_s.png"), preload("res://assets/fx/aida_thrust_s_mask.png"), preload("res://assets/fx/aida_thrust_l.png"), preload("res://assets/fx/aida_thrust_l_mask.png")]
const ASL := {"-100,30": "a1", "205,-12": "a2", "10,-190": "ah", "170,10": "ka", "60,-110": "air2", "-120,70": "air3"}
var asl_tex := {}
## Estelle's swing, baked from pixelfx (tools/pixelfx_fx/estelle-slash.js) per attack arc: 16 frames of 260x260 at
## 50 fps, pivot (130, 126) at the arc's centre; her thrust (estelle-thrust.js, 15 frames of 240x64, pivot (12, 32),
## 69 / 122 art px long) and her dive landing (estelle-dive-land.js, 19 frames of 240x80, pivot (120, 60))
var esl_tex := {}
const ETHR := [preload("res://assets/fx/estelle_thrust_s.png"), preload("res://assets/fx/estelle_thrust_l.png")]
const EDIVE := preload("res://assets/fx/estelle_dive.png")
const HITS := [preload("res://assets/fx/hit/hit_1.png"), preload("res://assets/fx/hit/hit_2.png"), preload("res://assets/fx/hit/hit_3.png")]     # tools/pixelfx_fx/clumsy-hit.js, seeds 1-3
func _asl(k: String) -> Array:
	if not asl_tex.has(k):
		asl_tex[k] = [load("res://assets/fx/aida_slash/aida_slash_%s.png" % k), load("res://assets/fx/aida_slash/aida_slash_%s_mask.png" % k)]
	return asl_tex[k]
const SH_SLASH := preload("res://shaders/pfx_slash.gdshader")
const SH_AIDA := preload("res://shaders/pfx_aida_swing.gdshader")
const SH_TEAR := preload("res://shaders/pfx_tear.gdshader")
const SH_HOL := preload("res://shaders/pfx_hollow.gdshader")
const SH_PIL := preload("res://shaders/pfx_pillar.gdshader")
const SH_AFX := preload("res://shaders/afx.gdshader")
const SPARK := preload("res://assets/fx/tear_spark.png")

## the prototype's stepped hashes fract(sin(n * 12.9898 + seed * m + o2) * 43758.5453), in double precision, as a float
## texture the effect shaders read (pfx_common hT): groups of o2 offsets, one row each, column n + 16 (n = -16 .. 239)
static func _hash_tex(m: float, seed: float, groups: Array) -> ImageTexture:
	var rows: Array = []
	for g in groups: rows.append_array(g)
	var im := Image.create(256, rows.size(), false, Image.FORMAT_RF)
	for r in rows.size():
		for c in 256:
			var v: float = sin((c - 16) * 12.9898 + seed * m + rows[r]) * 43758.5453
			im.set_pixel(c, r, Color(v - floorf(v), 0, 0))
	return ImageTexture.create_from_image(im)

static func _p(a: Array) -> Array:
	var o: Array = []
	for h in a: o.append(Color(h))
	return o

static var HIT := _p(["#ffffff", "#fff3b0", "#ffd34d", "#ff8a3d", "#c2304a", "#3a1424"])
static var TELL := _p(["#ffffff", "#ffd6d6", "#ff5a5a", "#e0213a", "#8a0f2a", "#2a0814"])
static var PARRY := _p(["#ffffff", "#fff3c4", "#ffd34d", "#f0a020", "#b8641a", "#3a2008", "#ff5a5a"])
static var DODGE := _p(["#e8fbff", "#9fe8ff", "#6fb8ff", "#7a6cff", "#4a3a9a", "#1c1640"])
static var DUSTP := _p(["#e8dcc4", "#c8b89a", "#9c8c74", "#6e604f", "#463c33"])
## PXPAL.blade: rim, core, body, outer, dark (+ jag for Aida's torn edge)
static var BLADE := {
	"estelle": _p(["#ffffff", "#ffffff", "#ff96d2", "#d650aa", "#7a2a66"]),
	"aida": _p(["#e6c8ff", "#cda0ff", "#601ea0", "#2a0a4c", "#12021f"]),
	"luce": _p(["#ffffff", "#ffffff", "#ffecaa", "#ffc85a", "#a8742a"]),
}
static var UPL := {"w": Color("#ffffff"), "p1": Color("#ffd3ea"), "p2": Color("#ff96d2"), "p3": Color("#d650aa"), "p4": Color("#7a2a66"), "g1": Color("#fff3b0"), "g2": Color("#ffd34d"), "g3": Color("#c98a1e")}
static var LPL := _p(["#ffffff", "#fff6d6", "#ffe9a0", "#ffd34d", "#e8a33a", "#a8742a", "#4a3010"])   # w c1 c2 c3 c4 c5 c6
static var TEARL := _p(["#ffffff", "#e8d4ff", "#c9a0ff", "#9a62e0", "#5a2a9e"])
static var TVOID := Color("#06020a")
static var HOL := {"zap": Color("#ff5a8a")}
static var IRIS := _p(["#ff6fae", "#ffa96b", "#ffe97a", "#86ffb4", "#6fd8ff", "#8f8cff", "#e07aff"])
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var arena
var L: Array = []          # live effects (PFXL)
var cpu: Node2D            # draws the rect-built effects
var pool: Array = []       # spare shader quads
var trail: Array = []      # perfect-dodge path echoes {snap, t}
var ghost_i = null         # the shell left where she dodged {snap, t}
var pp = null              # perfect parry burst {x, y, t, dir, seed}
var tr_t := 0.0
var heal_q: Array = []
var dtw := 0.0             # the world clock this frame (ms)
var dbg_k := 1.0           # test: the effect clock scale (0 = hold a frame for a screenshot)


func _ready() -> void:
	z_index = 11
	cpu = Node2D.new()
	cpu.z_index = 1
	var um := CanvasItemMaterial.new()
	um.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	cpu.material = um
	cpu.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cpu.draw.connect(_draw_cpu)
	add_child(cpu)


# ---------- the art-pixel raster helpers (pfxCtx) ----------
class PX:
	var ci: CanvasItem
	var bx := 0.0
	var by := 0.0
	var s := 2.0
	func _init(c: CanvasItem, ox: float, oy: float, sz := 2.0) -> void:
		ci = c
		s = sz
		bx = floorf(ox / sz + 0.5) * sz
		by = floorf(oy / sz + 0.5) * sz
	func px(x: float, y: float, c: Color) -> void:
		ci.draw_rect(Rect2(bx + floorf(x + 0.5) * s, by + floorf(y + 0.5) * s, s, s), c)
	func rect(x: float, y: float, w: float, h: float, c: Color) -> void:
		ci.draw_rect(Rect2(bx + floorf(x + 0.5) * s, by + floorf(y + 0.5) * s, maxf(1.0, floorf(w + 0.5)) * s, maxf(1.0, floorf(h + 0.5)) * s), c)
	func line(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
		var ax := int(floorf(x0 + 0.5))
		var ay := int(floorf(y0 + 0.5))
		var ex := int(floorf(x1 + 0.5))
		var ey := int(floorf(y1 + 0.5))
		if ay == ey:
			ci.draw_rect(Rect2(bx + mini(ax, ex) * s, by + ay * s, (absi(ex - ax) + 1) * s, s), c)
			return
		if ax == ex:
			ci.draw_rect(Rect2(bx + ax * s, by + mini(ay, ey) * s, s, (absi(ey - ay) + 1) * s), c)
			return
		var dx := absi(ex - ax)
		var sx := 1 if ax < ex else -1
		var dy := -absi(ey - ay)
		var sy := 1 if ay < ey else -1
		var e := dx + dy
		var n := 0
		while true:
			ci.draw_rect(Rect2(bx + ax * s, by + ay * s, s, s), c)
			if (ax == ex and ay == ey) or n > 400: break
			n += 1
			var e2 := 2 * e
			if e2 >= dy:
				e += dy
				ax += sx
			if e2 <= dx:
				e += dx
				ay += sy
	func circle(cx: float, cy: float, r: float, c: Color) -> void:
		var ri := int(floorf(r + 0.5))
		var x := ri
		var y := 0
		var d := 1 - ri
		while x >= y:
			for q in [[x, y], [y, x], [-y, x], [-x, y], [-x, -y], [-y, -x], [y, -x], [x, -y]]:
				px(cx + q[0], cy + q[1], c)
			y += 1
			if d < 0: d += 2 * y + 1
			else:
				x -= 1
				d += 2 * (y - x) + 1
	func disc(cx: float, cy: float, r: float, c: Color) -> void:
		var y := -r
		while y <= r:
			var w := floorf(sqrt(maxf(0.0, r * r - y * y)))
			rect(cx - w, cy + y, w * 2.0 + 1.0, 1.0, c)
			y += 1.0
	func poly(pts: Array, c: Color) -> void:
		var y0 := INF
		var y1 := -INF
		for p in pts:
			y0 = minf(y0, p.y)
			y1 = maxf(y1, p.y)
		for yi in range(int(floorf(y0)), int(ceilf(y1)) + 1):
			var yc := yi + 0.5
			var xs: Array = []
			for i in pts.size():
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[(i + 1) % pts.size()]
				if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
					xs.append(a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			var i2 := 0
			while i2 + 1 < xs.size():
				var l := floorf(xs[i2] + 0.5)
				rect(l, yi, floorf(xs[i2 + 1] + 0.5) - l + 1.0, 1.0, c)
				i2 += 2

## pfxRng: xorshift32, the same stream as the prototype for the same seed
class Rng:
	var s := 1
	func _init(seed: float) -> void:
		s = int(seed) & 0xffffffff
		if s == 0: s = 1
	## pfxRng's xorshift exactly as JS runs it: s>>17 is a SIGNED 32-bit shift (s is unsigned only after each >>>0)
	func r() -> float:
		s = (s ^ (s << 13)) & 0xffffffff
		var t := s - 0x100000000 if s >= 0x80000000 else s
		t ^= t >> 17
		s = (t ^ (t << 5)) & 0xffffffff
		return float(s % 10000) / 10000.0

static func fr(t: float) -> int:
	return int(floorf(t / FR))

static func jr(x: float) -> float:
	return floorf(x + 0.5)

static func pick(a: Array, i: int):
	return a[clampi(i, 0, a.size() - 1)]


# ---------- clock ----------
func _held() -> bool:
	var A = arena
	if A.ui_root != null and A.ui_root.holds(): return true
	if A.fame != null and A.fame.holds(): return true
	if A.sortie != null and A.sortie.holds(): return true
	if A.ult != null and A.ult.state == "cut": return true
	return false

func _process(delta: float) -> void:
	if arena == null: return
	var dt := minf(delta * 1000.0, 50.0)
	var held: bool = _held() or (arena.dlg != null and arena.dlg.active)
	dtw = (0.0 if (held or arena.hitstop > 0.0) else dt * (0.22 if arena.witch > 0.0 else 1.0)) * dbg_k
	var dtr := 0.0 if held else dt
	for e in L:
		e["t"] += dtw
	# perfect dodge: echoes along the path for the first 340 ms, the shell where she was, the parry burst
	if arena.witch > 0.0 and not held:
		var el: float = arena.witch_max - arena.witch
		tr_t -= dtr
		if el < 340.0 and tr_t <= 0.0:
			tr_t = 60.0
			var sn = snap_player()
			if sn != null: trail.append({"s": sn, "t": 0.0})
		arena.post_ca(0.004)
	for g in trail: g["t"] += dtr
	trail = trail.filter(func(g): return g["t"] < 620.0)
	if ghost_i != null:
		ghost_i["t"] += dtr
		if ghost_i["t"] > 760.0: ghost_i = null
	if pp != null:
		pp["t"] += dtr
		if pp["t"] > 560.0: pp = null
	_pix_frame()
	cpu.queue_redraw()

## the character shader's per-frame inputs: screen px per world px, and rimLights() — the lights the directional rim
## reads, as the prototype lists them [pos, r, a, colour]: the dungeon's (no player light, no small glows), the hall's
## (its lamps), elsewhere the lamps and fires (faint by day) plus the sky — the sun by day, the moon by night, from where
## it sits in the sky
func _pix_frame() -> void:
	var vp := get_viewport()
	var z: float = (vp.get_final_transform() * vp.get_canvas_transform()).x.length()
	CH_PLAYER.pix_frame(z, rim_lights())

func rim_lights() -> Array:
	var Ls: Array = []
	var lv = arena.level if arena.level != null else arena.get("train")
	var P = arena.player
	if P == null: return Ls
	if lv != null and lv.has_method("rim_lights"):
		# levels drawn by lit.gd hand over their whole light list [pos, r, strength, colour] (town / training add the
		# sky); the shader picks the strongest per body, as rimEntity does
		return lv.rim_lights()
	var kind := "" if lv == null else String(lv.kind)
	var tt := Time.get_ticks_msec() / 1000.0
	var nk := 0.0
	if kind != "dungeon" and kind != "hall":
		var sky: Color = arena.tod_now()["sky"]
		nk = clampf((sky.a - 0.33) / 0.33, 0.0, 1.0)
	if lv != null and lv.get("lights") != null:
		for l in lv.lights.get_children():
			if not (l is PointLight2D) or l.has_meta("player"): continue
			var r: float = l.texture_scale * float(l.texture.get_width() if l.texture != null else 64) / 2.2
			var a: float = l.energy
			if kind == "dungeon":
				if r <= 100.5 and l.energy < 1.0: continue        # the small mushroom / crystal glows
				if l.has_meta("flick") and l.get_meta("flick"): a *= 1.25 / 1.15
			elif kind == "hall":
				var kd: String = l.get_meta("kind", "soft")
				var ph: float = l.get_meta("ph", 0.0)
				a = l.get_meta("a", 0.8)
				if kd == "fire" or kd == "chand": a *= 0.85 + 0.1 * sin(tt * 7.0 + ph) + 0.05 * sin(tt * 19.0 + ph * 3.0)
			else:
				if not l.visible or l.energy <= 0.01: continue
				a = minf(1.1, l.energy) * (0.12 + 0.88 * nk)
			if a <= 0.0: continue
			Ls.append([l.position, r, a, l.color])
	if kind != "dungeon" and kind != "hall":
		var h := fposmod(arena.tod_h, 24.0)
		var day := h >= 6.0 and h < 18.0
		var u := (h - 6.0) / 12.0 if day else fposmod(h - 18.0 + 24.0, 24.0) / 12.0
		var ang := PI * (1.0 - u)
		var warm := day and (h < 8.5 or h > 16.0)
		var col := (Color8(255, 165, 105) if warm else Color8(255, 238, 210)) if day else Color8(150, 175, 255)
		Ls.append([Vector2(P.position.x + cos(ang) * 1600.0, P.position.y - 200.0 - sin(ang) * 1400.0), 4000.0, (0.95 if warm else 0.75) if day else 0.6, col])
	return Ls


# ---------- spawners ----------
func _push(e: Dictionary) -> Dictionary:
	e["t"] = 0.0
	if not e.has("seed"): e["seed"] = 1.0 + floorf(randf() * 1.0e5)
	L.append(e)
	if L.size() > 60:
		_kill(L[0])
		L.remove_at(0)
	return e

func _pal(ch: String) -> Array:
	return BLADE.get(ch, BLADE["estelle"])

## pfxSlash: the swing crescent (Aida: the layered dimension tears) — r already includes the 1.12 of arcFx
func slash(c: Vector2, r: float, a0: float, a1: float, d: int, ch: String, sy := 1.0) -> void:
	var ak := "%d,%d" % [int(roundf(a0)), int(roundf(a1))]
	if ch == "estelle" and ASL.has(ak):
		if not esl_tex.has(ak): esl_tex[ak] = load("res://assets/fx/estelle_slash/estelle_slash_%s.png" % ASL[ak])
		_push({"k": "bk", "tex": esl_tex[ak], "x": c.x, "y": c.y, "d": d, "n": 16, "fw": 260.0, "fh": 260.0, "cols": 4, "px": 130.0, "py": 126.0, "sc": S})
		return
	if ch == "aida" and ASL.has(ak):
		var T := _asl(ASL[ak])
		_push({"k": "asl", "tex": T[0], "mask": T[1], "x": c.x, "y": c.y, "d": d})
		return
	_push({"k": "slash", "ch": ch, "x": c.x, "y": c.y, "d": d, "r": r, "a0": a0, "a1": a1, "sy": sy, "seed": randf() * 9.0})

func thrust(x0: float, x1: float, y: float, ch: String) -> void:
	if ch == "estelle":
		var ed := signf(x1 - x0) if x1 != x0 else 1.0
		var Lw := absf(x1 - x0) * 1.25 / S
		var lg := Lw > 95.0
		_push({"k": "bk", "tex": ETHR[1 if lg else 0], "x": x0, "y": y, "d": ed, "n": 15, "fw": 240.0, "fh": 64.0, "cols": 2, "px": 12.0, "py": 32.0, "sc": S * Lw / (122.0 if lg else 69.0)})
		return
	if ch == "aida":
		var dir := signf(x1 - x0) if x1 != x0 else 1.0
		var Ll := maxf(90.0, absf(x1 - x0) * 1.6) / S + 13.0
		var lg := Ll > 130.0
		_push({"k": "athr", "tex": AIDA_THR[2 if lg else 0], "mask": AIDA_THR[3 if lg else 1], "x": x0 - dir * 13.0 * S, "y": y, "d": dir, "sc": S * Ll / (163.0 if lg else 98.0)})
		return
	_push({"k": "thrust", "ch": ch, "x": x0, "x1": x1, "y": y, "seed": randf() * 99.0})

func dust(x: float, y: float, d: int, big: bool) -> void:
	_push({"k": "dust", "x": x, "y": y, "d": d, "big": big, "seed": 1.0 + floorf(randf() * 1.0e6)})

## pfxSpawn('hit'): the impact ring + spark streaks flying the way the blow travels (six at most at once)
func hit(x: float, y: float, d: int, sz := 1.0) -> void:
	var n := 0
	for e in L:
		if e.get("hit", false) and e["t"] < 80.0: n += 1
	if n >= 6: return
	# the baked hit (owner 2026-11-05): ink star + cut line, gold crescents, flares and chips; tagged "hit" for the cap above
	_push({"k": "bk", "hit": true, "tex": HITS[randi() % 3], "x": x, "y": y, "d": d, "n": 16, "fw": 120.0, "fh": 90.0, "cols": 4, "px": 48.0, "py": 45.0, "sc": S * 0.85 * sz})

const L_SHIT := preload("res://assets/fx/luce/luce-spear-hit.png")
const L_SLAUNCH := preload("res://assets/fx/luce/luce-spear-launch.png")
const L_OEJECT := preload("res://assets/fx/luce/luce-orb-eject.png")
## Luce's spear kicking off / striking home, baked (tools/pixelfx_fx/luce-spear-launch.js, luce-spear-hit.js), turned to the flight
func spear_fx(kind: String, at: Vector2, ang: float, sz: float) -> void:
	if kind == "hit":
		_push({"k": "bk", "tex": L_SHIT, "x": at.x, "y": at.y, "d": 1.0, "ang": ang, "n": 18, "fw": 120.0, "fh": 96.0, "cols": 4, "px": 44.0, "py": 48.0, "sc": S * sz})
	elif kind == "eject":
		_push({"k": "bk", "tex": L_OEJECT, "x": at.x, "y": at.y, "d": 1.0, "ang": ang, "n": 11, "fw": 64.0, "fh": 48.0, "cols": 3, "px": 40.0, "py": 24.0, "sc": S * sz})
	else:
		_push({"k": "bk", "tex": L_SLAUNCH, "x": at.x, "y": at.y, "d": 1.0, "ang": ang, "n": 10, "fw": 96.0, "fh": 48.0, "cols": 3, "px": 64.0, "py": 24.0, "sc": S * sz})

func djump(P) -> void:
	_push({"k": "djump", "C": _pal(P.who), "x": P.position.x, "y": P.position.y + 2.0})

func dash_start(P, air: bool) -> void:
	var cs: float = P.CSCALE
	_push({"k": "dashl", "C": _pal(P.who), "d": P.dir, "x0": P.position.x - P.dir * 12.0 * cs, "y0": P.position.y})
	if air: _push({"k": "airb", "C": _pal(P.who), "d": P.dir, "x": P.position.x - P.dir * 14.0 * cs, "y": P.position.y - 56.0 * cs})
	else: dust(P.position.x - P.dir * 10.0 * cs, P.position.y, -P.dir, false)

func dive_start(P) -> void:
	var cs: float = P.CSCALE
	_push({"k": "dive", "ch": P.who, "C": _pal(P.who), "x": P.position.x, "y0": P.position.y - 80.0 * cs, "y1": P.position.y - 30.0 * cs})

func slam(x: float, y: float, ch: String, up := false) -> void:
	if ch == "estelle" and not up:
		_push({"k": "bk", "tex": EDIVE, "x": x, "y": y, "d": 1.0, "n": 19, "fw": 240.0, "fh": 80.0, "cols": 3, "px": 120.0, "py": 60.0, "sc": S})
		dust(x + 14.0, y, 1, true)
		dust(x - 14.0, y, -1, true)
		if arena != null:
			arena.air_push(x, y - 20.0, 1.0, 300.0, 0.5)
			arena.air_push(x, y - 20.0, -1.0, 300.0, 0.5)
		return
	if ch == "aida" and not up:
		_push({"k": "dland", "tex": AIDA_DIVE, "mask": AIDA_DIVE_M, "x": x, "y": y})
		dust(x + 14.0, y, 1, true)
		dust(x - 14.0, y, -1, true)
		if arena != null:
			arena.air_push(x, y - 20.0, 1.0, 300.0, 0.5)
			arena.air_push(x, y - 20.0, -1.0, 300.0, 0.5)
		return
	_push({"k": "slam", "ch": ch, "C": _pal(ch), "x": x, "y": y, "up": up})
	dust(x + 14.0, y, 1, true)
	dust(x - 14.0, y, -1, true)
	if arena != null:
		arena.air_push(x, y - 20.0, 1.0, 300.0, 0.5)
		arena.air_push(x, y - 20.0, -1.0, 300.0, 0.5)

## the floor breaks under the slam, a dome of air thumps out, glowing chunks float and rewind into the floor
func rewind_slam(x: float, y: float) -> void:
	_push({"k": "sheet", "tex": AIDA_SLAM, "x": x, "y": y, "fw": 440, "fh": 176, "cols": 5, "n": 56, "fps": 30.0, "px": 220.0, "py": 140.0, "sc": S})
	if arena != null:
		arena.air_push(x, y - 20.0, 1.0, 300.0, 0.5)
		arena.air_push(x, y - 20.0, -1.0, 300.0, 0.5)

func charge(P) -> void:
	for e in L:
		if e["k"] == "chg" and not e.has("endT"): return
	_push({"k": "chg", "C": _pal(P.who), "m": []})

## Aida's rift gate: opens like an eye from the top down, holds while she passes, closes once released (e["rel"])
func gate(x: float, y: float, h: float, k := 1.0, w := 1.0) -> Dictionary:
	return _push({"k": "gate", "x": x, "y": y, "h": h, "kk": k, "w": w, "seed": randf() * 99.0})

## Luce's third blow, baked (tools/pixelfx_fx/luce-pillar.js, owner 2026-11-05): the pillar of judgement, 31 frames of 180x260
const L_PILLAR := preload("res://assets/fx/luce/luce-pillar.png")
func pillar(x: float, y: float, _cs: float) -> void:
	_push({"k": "bk", "tex": L_PILLAR, "x": x, "y": y, "d": 1.0, "n": 31, "fw": 180.0, "fh": 260.0, "cols": 7, "px": 90.0, "py": 236.0, "sc": S})

## Luce's holy thunder, baked (tools/pixelfx_fx/luce-thunder2.js on luce-strike.js, the library strike in her gold,
## owner 2026-11-05): 51 frames of 240x264, pivot (120, 228), three bolt shapes
const L_THUNDER := [preload("res://assets/fx/luce/luce-thunder_5.png"), preload("res://assets/fx/luce/luce-thunder_8.png"), preload("res://assets/fx/luce/luce-thunder_11.png")]
func bolt(x: float, y: float, _sz: float) -> void:
	_push({"k": "bk", "tex": L_THUNDER[randi() % 3], "x": x, "y": y, "d": 1.0 if randf() < 0.5 else -1.0, "n": 51, "fw": 240.0, "fh": 264.0, "cols": 8, "px": 120.0, "py": 228.0, "sc": S})

## Luce's prayer, baked (tools/pixelfx_fx/luce-pray.js, owner 2026-11-05): 36 frames of 120x120 — the sigil, rising
## motes, the halo gathering over her head, over the 0.7 s cast
const L_PRAY := preload("res://assets/fx/luce/luce-pray.png")
func pray(x: float, y: float) -> void:
	_push({"k": "bk", "tex": L_PRAY, "x": x, "y": y, "d": 1.0, "n": 36, "fw": 120.0, "fh": 120.0, "cols": 6, "px": 60.0, "py": 108.0, "sc": S})

## ...and let go (tools/pixelfx_fx/luce-bless.js): 46 frames of 320x180 — halo flash, the bell-stroke ring, light rain
const L_BLESSFX := preload("res://assets/fx/luce/luce-bless.png")
func bless(x: float, y: float) -> void:
	_push({"k": "bk", "tex": L_BLESSFX, "x": x, "y": y, "d": 1.0, "n": 46, "fw": 320.0, "fh": 180.0, "cols": 6, "px": 160.0, "py": 160.0, "sc": S})

## Kenin's gun, baked (tools/pixelfx_fx/kenin-muzzle*.js, kenin-impact.js, owner 2026-11-05), turned to the shot
const K_MZ := preload("res://assets/fx/kenin/kenin-muzzle.png")
const K_MZB := preload("res://assets/fx/kenin/kenin-muzzle-big.png")
const K_IMP := preload("res://assets/fx/kenin/kenin-impact.png")
func _kang(d: Vector2) -> Array:
	# heading -> [mirror, angle] so a shot to the left is the right-facing art mirrored, not upside down
	if d.x < 0.0: return [-1.0, d.angle() - PI]
	return [1.0, d.angle()]
func kmuzzle(o: Vector2, d: Vector2, big: bool) -> void:
	var m := _kang(d)
	if big: _push({"k": "bk", "tex": K_MZB, "x": o.x, "y": o.y, "d": m[0], "ang": m[1], "n": 26, "fw": 160.0, "fh": 104.0, "cols": 5, "px": 44.0, "py": 52.0, "sc": S})
	else: _push({"k": "bk", "tex": K_MZ, "x": o.x, "y": o.y, "d": m[0], "ang": m[1], "n": 19, "fw": 96.0, "fh": 72.0, "cols": 4, "px": 36.0, "py": 36.0, "sc": S})
func kimpact(x: float, y: float, d: Vector2, sz := 1.0) -> void:
	var m := _kang(d)
	_push({"k": "bk", "tex": K_IMP, "x": x, "y": y, "d": m[0], "ang": m[1], "n": 16, "fw": 72.0, "fh": 64.0, "cols": 4, "px": 40.0, "py": 32.0, "sc": S * sz})

func heal_cross(px: float, py: float, s: float) -> void:
	var x := 0.0
	var y := 0.0
	var ok := false
	var tries := 0
	while tries < 8 and not ok:
		var a := randf() * TAU
		var rr := 0.65 + randf() * 0.45
		x = px + cos(a) * 38.0 * s * rr
		y = py - (48.0 + sin(a) * 34.0) * s * rr - 6.0 * s
		ok = heal_q.all(func(q): return Vector2(q).distance_to(Vector2(x, y)) > 16.0 * s)
		tries += 1
	heal_q.append(Vector2(x, y))
	if heal_q.size() > 6: heal_q.pop_front()
	var near := absf(x - px) < 20.0 * s
	_push({"k": "hcr", "x": x, "y": y, "vx": signf(x - px) * 0.012 * s, "rise": (46.0 + randf() * 30.0) * s, "life": 640.0 + randf() * 260.0, "sz": 2 if near or randf() < 0.3 else 1, "ph": randf() * 6.0})

func heal_burst(px: float, py: float, s: float) -> void:
	var n := 7
	for i in n:
		var u := (float(i) / (n - 1)) * 2.0 - 1.0
		var j := (randf() - 0.5) * 0.18
		_push({"k": "hcr", "x": px + (u + j) * 44.0 * s, "y": py - (78.0 - absf(u) * 26.0 + randf() * 6.0) * s, "vx": u * 0.02 * s, "rise": (56.0 + randf() * 24.0 - absf(u) * 10.0) * s,
			"life": 760.0 + randf() * 200.0, "dl": absf(u) * 150.0 + randf() * 40.0, "sz": 2 if absf(u) < 0.5 else 1, "ph": randf() * 6.0})

func rose_burst(x: float, y: float) -> void:
	_push({"k": "rburst", "x": x, "y": y})

## Estelle's ult: the oath (crest stamped, shield rising) and the rose citadel while the vow lasts
func vow(P) -> void:
	_push({"k": "vowA", "x": P.position.x, "y": P.position.y, "s": P.CSCALE * 0.9})
	_push({"k": "vowC"})

func hollow(x: float, y: float, h: float, life: float) -> void:
	_push({"k": "hol", "x": x, "y": y, "r": h * 0.27, "life": life, "seed": randf() * 9.0})

func utear(x: float, y: float, len: float) -> void:
	var k: float = [-0.96, 0.96, PI / 2.0, 0.0][randi() % 4] + (randf() - 0.5) * 0.25
	_push({"k": "utear", "x": x, "y": y, "ang": k, "len": len, "seed": randf() * 99.0})

## the perfect parry's gold clash (PARRYFX.clangp), between her guard and the attacker
func parry_at(p: Vector2, d: int) -> void:
	pp = {"x": p.x, "y": p.y, "t": 0.0, "dir": d, "seed": 1.0 + floorf(randf() * 1.0e6)}

## the perfect dodge: the shell left where she stood (snapArt)
func dodge_snap() -> void:
	var sn = snap_player()
	if sn != null: ghost_i = {"s": sn, "t": 0.0}
	trail.clear()
	tr_t = 0.0


# ---------- drawing (drawPfx) ----------
func _draw_cpu() -> void:
	var g := cpu
	var i := L.size() - 1
	while i >= 0:
		var e: Dictionary = L[i]
		var alive := false
		match e["k"]:
			"hit": alive = _hitfx(g, e)
			"slash": alive = _slash(e)
			"thrust": alive = _thrust(g, e)
			"dust": alive = _dust(g, e["t"], e["x"], e["y"], e["d"], e["seed"], e["big"])
			"djump": alive = _djump(g, e)
			"dashl": alive = _dash(g, e)
			"airb": alive = _airb(g, e)
			"dive": alive = _dive(g, e)
			"slam": alive = _slam(g, e)
			"sheet": alive = _sheet(g, e)
			"asl": alive = _asl_draw(g, e)
			"dland": alive = _dland(g, e)
			"athr": alive = _athr(g, e)
			"bk": alive = _bk(g, e)
			"chg": alive = _charge(g, e)
			"gate": alive = _gate_b(g, e)
			"pil": alive = _pillar(g, e)
			"bolt2": alive = _bolt(g, e)
			"hcr": alive = _heal(g, e)
			"rburst": alive = _rose_burst(g, e)
			"vowA": alive = _vow_oath(g, e)
			"vowC": alive = _vow_rose(g, e)
			"hol": alive = _hollow(g, e)
			"utear": alive = _utear(e)
		if not alive:
			_kill(e)
			L.remove_at(i)
		i -= 1
	_draw_shards(g)
	_draw_ult(g)
	_draw_combat(g)

## the ult's world effects (ult.gd keeps their logic and timing; they are drawn here in pixels)
const ULT_KINDS := ["oath", "rose", "rburst", "burst", "star", "beam", "twinkle", "hollow", "tear"]
var uq := {}
var upid := 0

func owns(k: String) -> bool:
	return k in ULT_KINDS

func _draw_ult(g: CanvasItem) -> void:
	var U = arena.ult
	if U == null: return
	var seen := {}
	for f in U.fx:
		var k: String = f["k"]
		if not k in ULT_KINDS: continue
		var kk: float = f["t"] / f["life"]
		match k:
			"oath": _vow_oath(g, f)
			"rose": _vow_rose(g, f)
			"rburst":
				if not f.has("pseed"): f["pseed"] = 1.0 + floorf(randf() * 1.0e5)
				_rose_burst(g, {"t": f["t"], "x": f["x"], "y": f["y"], "seed": f["pseed"]})
			"burst": ult_burst(g, U.who, f["x"], f["y"], f["r"], f["t"], kk)
			"star": ult_star(g, f["x"], f["y"], f["s"], f["spin"], f["t"])
			"beam": beam(g, f["x"], f["y"], f["dir"], f["len"], f["w"], f["t"], f["life"])
			"twinkle": twinkle(g, f["x"], f["y"], kk)
			"hollow", "tear":
				if not f.has("_pid"):
					upid += 1
					f["_pid"] = upid
				var id: int = f["_pid"]
				if not uq.has(id):
					uq[id] = {"k": k, "seed": randf() * 9.0, "x": f["x"], "y": f["y"]}
					if k == "hollow":
						uq[id]["r"] = f["r"]
						uq[id]["life"] = f["life"]
					else:
						uq[id]["ang"] = f["ang"]
						uq[id]["len"] = f["len"]
				var e: Dictionary = uq[id]
				e["t"] = f["t"]
				seen[id] = true
				var ok := _hollow(g, e) if k == "hollow" else _utear(e)
				if not ok: _hide(e)
	for id in uq.keys():
		if not seen.has(id):
			_kill(uq[id])
			uq.erase(id)

## drawCombatFx: attack tells on the mobs' weapon points, the dodge afterimages, the parry clash
func _draw_combat(g: CanvasItem) -> void:
	for m in arena.mobs:
		if m.flare_t < 0.0 or not m.alive(): continue
		if not m.has_meta("tseed"): m.set_meta("tseed", 1.0 + floorf(randf() * 1.0e6))
		if m.flare_t < 1.0: m.set_meta("tseed", 1.0 + floorf(randf() * 1.0e6))
		var p: Vector2 = m.flare_pos()
		tell(g, m.flare_t, p.x, p.y, m.dir, m.get_meta("tseed"))
	_afx_sync()
	if pp != null: clangp(g, pp["t"], pp["x"], pp["y"], pp["dir"], pp["seed"])
	var P = arena.player
	if P != null and P.who == "luce" and P.has_method("target"):
		var tg = P.target(420.0)
		if tg != null: reticle(g, tg.position.x, tg.position.y - 50.0, P.t)
	if P != null: _halo(g, P)

## 빛의 가호: the library halo (tools/pixelfx_fx/luce-halo.js, the library halo less its head light and dust, gold, 60 frames of 56x80, pivot 28,70) over the one in control while
## it lasts; blinks over its last 3 s, flares when a bench bolt goes out (P.halo_glint)
const L_HALO := preload("res://assets/fx/luce/luce-halo.png")
const HALO_Y := 44.0         # lift above the sheet's own head height, x CSCALE, world px PLACEHOLDER
func _halo(g: CanvasItem, P) -> void:
	if P.l_bless_t <= 0.0 or P.anim == "death": return
	if P.l_bless_t < 3000.0 and int(P.l_bless_t / 110.0) % 2 == 0: return
	var i := int(P.t / 1000.0 * 30.0) % 60
	var src := Rect2((i % 10) * 56.0, (i / 10) * 80.0, 56.0, 80.0)
	var org: Vector2 = P.position + Vector2(-28.0 * S, -70.0 * S - HALO_Y * P.CSCALE)
	g.draw_texture_rect_region(L_HALO, Rect2(org, Vector2(56.0, 80.0) * S), src)
	if P.halo_glint > 0.0:
		var k: float = P.halo_glint / 160.0
		var hc: Vector2 = P.position + Vector2(0, -57.0 * S - HALO_Y * P.CSCALE)
		var L := 14.0 * k + 4.0
		g.draw_rect(Rect2(hc + Vector2(-L, -1), Vector2(L * 2.0, 2)), Color(1, 1, 0.9, k))
		g.draw_rect(Rect2(hc + Vector2(-1, -L * 0.6), Vector2(2, L * 1.2)), Color(1, 1, 0.9, k))
		g.draw_texture_rect_region(L_HALO, Rect2(org, Vector2(56.0, 80.0) * S), src, Color(1, 1, 1, 0.6 * k))


# ---------- HIT: C's impact ring (a size smaller) + E's spark streaks ----------
func _hitfx(g: CanvasItem, e: Dictionary) -> bool:
	var a := _ring(g, e["t"], e["x"], e["y"], e["seed"], 0.75 * e["sz"])
	var b := _streaks(g, e["t"], e["x"], e["y"], e["d"], e["seed"] + 7.0, e["sz"])
	return a or b

func _ring(g: CanvasItem, t: float, x: float, y: float, seed: float, sz: float) -> bool:
	var f := fr(t)
	if f > 8: return false
	var C := HIT
	var p := PX.new(g, x, y)
	var R := Rng.new(seed)
	var Q := func(v: float) -> float: return maxf(1.0, jr(v * sz))
	if f == 0:
		p.disc(0, 0, Q.call(6.0), C[0])
		return true
	if f == 1:
		p.disc(0, 0, Q.call(8.0), C[1])
		p.disc(0, 0, Q.call(5.0), C[0])
	var r: float = Q.call([0, 9, 12, 14, 16, 17, 18, 19, 19][f])
	var col: Color = [C[0], C[1], C[2], C[2], C[3], C[3], C[4], C[4], C[5]][f]
	p.circle(0, 0, r, col)
	if f < 4: p.circle(0, 0, r - 1.0, col)
	for i in 8:
		var a := i * 0.785 + R.r() * 0.3
		var rr := r + 2.0 + (i % 2) * 2.0
		if f >= 2 and f < 7:
			p.line(cos(a) * rr, sin(a) * rr, cos(a) * (rr + 3.0 - f * 0.3), sin(a) * (rr + 3.0 - f * 0.3), C[1] if f < 4 else C[3])
	return true

func _streaks(g: CanvasItem, t: float, x: float, y: float, d: int, seed: float, sz: float) -> bool:
	var f := fr(t)
	if f > 8: return false
	var C := HIT
	var p := PX.new(g, x, y)
	var R := Rng.new(seed)
	if f < 2: p.disc(0, 0, 3 - f, C[0])
	for i in 9:
		var a := (R.r() - 0.5) * 2.6 + (0.0 if d > 0 else PI)
		var v := (2.2 + R.r() * 2.4) * sz
		var h := mini(f + 1, 6) * v
		var tl := maxf(0.0, (f - 2) * v * 0.9)
		var hx := cos(a) * h
		var hy := sin(a) * h * 0.8 + 0.12 * f * f
		var tx := cos(a) * tl
		var ty := sin(a) * tl * 0.8 + 0.08 * f * f
		if f < 7:
			p.line(tx, ty, hx, hy, C[2] if f < 3 else (C[3] if f < 5 else C[4]))
			p.px(hx, hy, C[0] if f < 4 else C[1])
	return true


# ---------- ATTACK TELL (TELLFX.df): the slit flashes open, the diamond blooms, the long line cuts through ----------
func tell(g: CanvasItem, t: float, x: float, y: float, _d: int, seed: float) -> bool:
	var f := fr(t)
	if f > 8: return false
	var C := TELL
	var p := PX.new(g, x, y)
	var R := Rng.new(seed)
	var r: float = [0, 5, 9, 12, 13, 14, 14, 14, 14][f]
	if r > 0:
		var col: Color = [C[0], C[0], C[1], C[2], C[2], C[3], C[3], C[4], C[4]][f]
		p.line(0, -r, r, 0, col); p.line(r, 0, 0, r, col); p.line(0, r, -r, 0, col); p.line(-r, 0, 0, -r, col)
		if f < 4 and r > 3:
			var q := r - 2.0
			p.line(0, -q, q, 0, C[1]); p.line(q, 0, 0, q, C[1]); p.line(0, q, -q, 0, C[1]); p.line(-q, 0, 0, -q, C[1])
	var V: float = [10, 14, 12, 8, 4, 2, 0, 0, 0][f]
	if V > 0:
		p.line(0, -V, 0, V, C[0] if f < 2 else C[1])
		p.line(-1, -V + 3, -1, V - 3, C[2])
		p.line(1, -V + 3, 1, V - 3, C[2])
	var Ll: float = [0, 14, 28, 36, 36, 30, 20, 10, 4][f]
	if Ll > 0:
		p.line(-Ll, 0, Ll, 0, C[0] if f < 5 else C[2])
		if f < 6:
			p.line(-Ll + 6, -1, Ll - 6, -1, C[2])
			p.line(-Ll + 6, 1, Ll - 6, 1, C[2])
	for i in 6:
		var sd := 1.0 if i % 2 else -1.0
		var v := 3.0 + R.r() * 4.0
		var yy := (R.r() - 0.5) * 8.0
		if f >= 2: p.px(sd * (12.0 + (f - 2) * v), yy + (f - 2) * 0.3, C[2] if f < 5 else C[4])
	if f < 2: p.disc(0, 0, 2, C[0])
	return true


# ---------- PERFECT PARRY (PARRYFX.clangp): clash arcs, sparks as particles shedding dotted trails ----------
func clangp(g: CanvasItem, t: float, x: float, y: float, d: int, seed: float) -> bool:
	var F := t / FR
	var f := int(floorf(F))
	if f > 13: return false
	var C := PARRY
	var p := PX.new(g, x, y)
	var R := Rng.new(seed)
	var r: float = [4, 9, 13, 16, 18, 19, 20, 20, 20][f] if f < 9 else 0.0
	if r > 0.0 and f < 9:
		var col: Color = [C[0], C[0], C[1], C[2], C[2], C[3], C[3], C[4], C[4]][f]
		for sd in [-1.0, 1.0]:
			var a := -0.9
			while a <= 0.9 + 1e-9:
				var ox: float = cos(a) * r * sd
				var oy := sin(a) * r * 1.25
				a += 0.05
				if f >= 5 and R.r() < (f - 4) * 0.2: continue
				p.px(ox, oy, col)
				if f < 4: p.px(ox * 0.9, oy * 0.9, C[1])
	if f < 2: p.disc(0, 0, 3 if f else 5, C[0])
	for i in 24:
		var a := PI * (1.0 if d > 0 else 0.0) + (R.r() - 0.5) * 2.0
		var v := 2.4 + R.r() * 3.2
		var g0 := 0.035 + R.r() * 0.045
		var life := 6.0 + R.r() * 7.0
		var big := R.r() < 0.3
		var split := R.r() < 0.35
		var tt := F - 0.5
		if tt < 0.0 or tt > life:
			R.r()
			continue
		var heat := tt / life
		var chc: Color = C[0] if heat < 0.25 else (C[1] if heat < 0.5 else (C[2] if heat < 0.75 else C[3]))
		for k in range(1, 5):
			var tb := tt - k * 0.55
			if tb < 0.0: break
			var hk := tb / life + k * 0.12
			p.px(cos(a) * v * tb, sin(a) * v * tb * 0.75 + g0 * tb * tb, C[2] if hk < 0.45 else (C[3] if hk < 0.75 else C[4]))
		var hx := cos(a) * v * tt
		var hy := sin(a) * v * tt * 0.75 + g0 * tt * tt
		if big and heat < 0.5: p.rect(hx - 1, hy - 1, 2, 2, chc)
		else: p.px(hx, hy, chc)
		if split and tt > life * 0.45:
			var ts := tt - life * 0.45
			var t4 := life * 0.45
			var sx := cos(a) * v * t4
			var sy := sin(a) * v * t4 * 0.75 + g0 * t4 * t4
			for da in [-0.5, 0.5]:
				var aa: float = a + da
				var vv := v * 0.55
				p.px(sx + cos(aa) * vv * ts, sy + sin(aa) * vv * ts * 0.75 + 0.07 * ts * ts, C[2] if ts < 2.0 else C[4])
	return true


# ---------- SLASH: the swing crescent (SLASHFX.ref), Aida's tears (aidaSwing) ----------
const REFK := [[0.35, 0.0, 0.0, 0], [0.8, 0.0, 0.85, 0], [1.04, 0.04, 1.0, 0], [1.04, 0.25, 0.7, 0], [1.04, 0.48, 0.45, 1], [1.04, 0.68, 0.26, 1], [1.04, 0.84, 0.12, 2]]

func _slash(e: Dictionary) -> bool:
	var t: float = e["t"]
	if e["ch"] == "aida":
		var F := t / FR
		if F > 13.0: return false
		var sy: float = e["sy"]
		var ro: float = e["r"] * 1.18 / S
		var Rm := ceilf(ro * 1.25 + 6.0)
		var Ry := ceilf(Rm * sy) + 3.0
		var q := _quad(e, SH_AIDA, Vector2(e["x"], e["y"]), Rect2(-Rm * S, -Ry * S, (2.0 * Rm + 1.0) * S, (2.0 * Ry + 1.0) * S))
		var m: ShaderMaterial = q.material
		m.set_shader_parameter("F", F)
		if not e.has("set"):
			e["set"] = true
			m.set_shader_parameter("a0", deg_to_rad(e["a0"]))
			m.set_shader_parameter("a1", deg_to_rad(e["a1"]))
			m.set_shader_parameter("ro", ro)
			m.set_shader_parameter("sy", sy)
			m.set_shader_parameter("sc", e["r"] / 100.0)
			m.set_shader_parameter("dir", float(e["d"]))
			m.set_shader_parameter("seed", e["seed"])
			m.set_shader_parameter("hsh", _hash_tex(3.3, e["seed"], [[0, 1, 2, 3], [9, 10, 11, 12], [3, 4, 5, 6]]))
		# glass shards breaking off along the swing
		var a0 := deg_to_rad(e["a0"])
		var span := deg_to_rad(e["a1"]) - a0
		var sh: Array = []
		for i in 10:
			var v := 0.2 + i * 0.07
			var am := a0 + span * v
			var r := ro * (1.0 - 0.06 * v)
			var sd := 1.0 if i % 2 else -1.0
			sh.append([cos(am) * r * e["d"], sin(am) * r * sy, cos(am) * e["d"] * sd * 2.0, sin(am) * sy * sd * 2.0])
		e["shards"] = [sh, 1.6]
		return true
	var f := fr(t)
	if f > 7: return false
	if f >= REFK.size():
		_hide(e)
		return true
	var K: Array = REFK[f]
	var ro2: float = e["r"] * 1.2 / S
	var thick: float = e["r"] * 0.62 / S
	var R := ceilf(ro2 + 3.0)
	var Ry2 := ceilf(R * e["sy"]) + 3.0
	var q2 := _quad(e, SH_SLASH, Vector2(e["x"], e["y"]), Rect2(-R * S, -Ry2 * S, (2.0 * R + 1.0) * S, (2.0 * Ry2 + 1.0) * S))
	var m2: ShaderMaterial = q2.material
	m2.set_shader_parameter("f", f)
	m2.set_shader_parameter("K", Vector4(K[0], K[1], K[2], K[3]))
	if not e.has("set"):
		e["set"] = true
		m2.set_shader_parameter("a0", deg_to_rad(e["a0"]))
		m2.set_shader_parameter("a1", deg_to_rad(e["a1"]))
		m2.set_shader_parameter("ro", ro2)
		m2.set_shader_parameter("thick", thick)
		m2.set_shader_parameter("sy", e["sy"])
		m2.set_shader_parameter("dir", float(e["d"]))
		m2.set_shader_parameter("seed", e["seed"])
		m2.set_shader_parameter("hsh", _hash_tex(7.1, e["seed"], [[1, 2, 3]]))
		m2.set_shader_parameter("jag", 0.0)
		var P: Array = _pal(e["ch"])
		var pv := PackedVector4Array()
		for c in P: pv.append(Vector4(c.r, c.g, c.b, 1.0))
		m2.set_shader_parameter("pal", pv)
	return true


# ---------- THRUST: the spear wedge (thrustFx); Aida: tears laid along the jab (aidaThrust) ----------
func _thrust(g: CanvasItem, e: Dictionary) -> bool:
	var t: float = e["t"]
	var x0: float = e["x"]
	var x1: float = e["x1"]
	var y: float = e["y"]
	var dir := signf(x1 - x0) if x1 != x0 else 1.0
	if e["ch"] == "aida":
		var F := t / FR
		if F > 13.0: return false
		var back := 26.0 / S
		var Ll := maxf(90.0, absf(x1 - x0) * 1.6) / S + back
		var o := Vector2(x0 - dir * back * S, y)
		_tear_quad(e, o, Vector2(dir, 0.0), Ll, F, [[0.0, -1.0, 0.0, 1.0, 7.0, 0.0, 0], [-9.0, -15.0, 0.22, 0.96, 3.6, 0.7, 0], [8.0, 12.0, 0.12, 0.82, 2.4, 1.1, 0], [-4.0, -6.0, 0.4, 1.04, 1.0, 0.4, 0]], Vector3(36, 24, 60), 24.0, Vector2(-2.0 / Ll, 1.06), "q", Vector2(0.0, 1.0))
		var sh: Array = []
		for i in 10:
			var v := 0.25 + i * 0.07
			sh.append([dir * v * Ll, (1.0 if i % 2 else -1.0) * 2.0, dir * 0.6, (1.0 if i % 2 else -1.0) * 1.6])
		var p0 := PX.new(g, o.x, o.y)
		_tear_shards(p0, F, 1.5, sh, e["seed"])
		return true
	var f := fr(t)
	if f > 8: return false
	var P: Array = _pal(e["ch"])
	var Lw := absf(x1 - x0) * 1.25
	var p := PX.new(g, x0, y)
	var R := Rng.new(e["seed"])
	var Lp := Lw / S
	var KK := [[0.5, 0.0, 0.35], [1.0, 0.0, 1.0], [1.06, 0.05, 1.0], [1.06, 0.3, 0.6], [1.06, 0.55, 0.35], [1.06, 0.75, 0.18], [1.06, 0.88, 0.08]]
	if f >= KK.size(): return true
	var K: Array = KK[f]
	var dk := 1 if f >= 4 else 0
	var col := func(n: int) -> Color: return P[mini(4, n + dk)]
	var W := maxf(3.0, Lp * 0.11)
	var i := int(floorf(K[1] * Lp))
	while i <= K[0] * Lp:
		var u := i / Lp
		var v := 0.06 + 0.94 * pow(u / 0.78, 1.4) if u < 0.78 else pow(maxf(0.0, 1.0 - (u - 0.78) / 0.28), 0.7)
		var hw: float = W * v * K[2] * (1.0 + 0.18 * absf(sin(i * 0.9 + e["seed"])))
		var ch := ceili(hw)
		# one column: bands are symmetric, drawn as runs
		var k := -ch
		while k <= ch:
			var q := absf(k) / maxf(1.0, hw)
			if q > 1.0:
				k += 1
				continue
			var c: Color = col.call(0 if f < 3 else 1) if q < 0.3 else (col.call(2) if q < 0.7 else col.call(3))
			var k2 := k
			while k2 + 1 <= ch:
				var q2 := absf(k2 + 1) / maxf(1.0, hw)
				if q2 > 1.0: break
				var c2: Color = col.call(0 if f < 3 else 1) if q2 < 0.3 else (col.call(2) if q2 < 0.7 else col.call(3))
				if c2 != c: break
				k2 += 1
			p.rect(dir * i, k, 1, k2 - k + 1, c)
			k = k2 + 1
		i += 1
	if f >= 1 and f <= 3:
		var tip: float = dir * K[0] * Lp
		var rr: float = [0, 4, 7, 9][f]
		p.circle(tip, 0, rr, col.call(0 if f < 2 else 1))
	if f >= 1 and f <= 6:
		for n in 6:
			var yy := (-1.0 if n < 3 else 1.0) * (W + 3.0 + (n % 3) * 3.0 + R.r() * 2.0)
			var len := Lp * (0.25 + R.r() * 0.25)
			var st := Lp * (0.1 + R.r() * 0.4) + f * Lp * 0.05
			if st > Lp: continue
			p.line(dir * st, yy, dir * minf(Lp * 1.05, st + len * (1.0 - f * 0.12)), yy, col.call(1) if f < 3 else col.call(3))
	return true


# ---------- the shader quads ----------
func _quad(e: Dictionary, sh: Shader, at: Vector2, r: Rect2) -> Node2D:
	var q: Node2D = e.get("q")
	if q == null:
		if pool.is_empty():
			q = Node2D.new()
			q.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var qq := q
			q.draw.connect(func(): qq.draw_rect(qq.get_meta("r"), Color.WHITE))
			add_child(q)
			move_child(q, 0)
		else:
			q = pool.pop_back()
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("spk", SPARK)
		q.material = m
		e["q"] = q
	q.visible = true
	q.position = Vector2(jr(at.x / S) * S, jr(at.y / S) * S)
	if not q.has_meta("r") or q.get_meta("r") != r:
		q.set_meta("r", r)
		q.queue_redraw()
	return q

func _hide(e: Dictionary) -> void:
	var q: Node2D = e.get("q")
	if q != null: q.visible = false

func _kill(e: Dictionary) -> void:
	var q: Node2D = e.get("q")
	if q != null:
		q.visible = false
		pool.append(q)
		e.erase("q")
	for k2 in ["q2", "q3", "q4"]:
		var q2: Node2D = e.get(k2)
		if q2 != null:
			q2.visible = false
			pool.append(q2)
			e.erase(k2)

func _sync_quads() -> void:
	pass

## one straight cut of eye-tears: strokes [o0, o1, lo, hi, W, dl, prof]
func _tear_quad(e: Dictionary, a: Vector2, ud: Vector2, Ll: float, tt: float, st: Array, nf := Vector3(30, 22, 56), Wm := 14.0, ur := Vector2(-0.02, 1.02), key := "q", nrm := Vector2.ZERO) -> void:
	var ex := ud * Ll
	var x0 := minf(0.0, ex.x) - Wm
	var x1 := maxf(0.0, ex.x) + Wm
	var y0 := minf(0.0, ex.y) - Wm
	var y1 := maxf(0.0, ex.y) + Wm
	var r := Rect2(floorf(x0) * S, floorf(y0) * S, (ceilf(x1) - floorf(x0) + 1.0) * S, (ceilf(y1) - floorf(y0) + 1.0) * S)
	var hold := {}
	if key != "q":
		hold["q"] = e.get(key)
	var q := _quad(e if key == "q" else hold, SH_TEAR, a, r)
	if key != "q": e[key] = hold["q"]
	var m: ShaderMaterial = q.material
	m.set_shader_parameter("tt", tt)
	if not q.has_meta("tset") or q.get_meta("tset") != e:
		q.set_meta("tset", e)
		m.set_shader_parameter("ud", ud)
		m.set_shader_parameter("nrm", nrm)
		m.set_shader_parameter("L", Ll)
		m.set_shader_parameter("seed", e["seed"])
		m.set_shader_parameter("hsh", _hash_tex(3.3, e["seed"], [[0, 1, 2, 3], [9, 10, 11, 12], [3, 4, 5, 6]]))
		m.set_shader_parameter("nf", nf)
		m.set_shader_parameter("ur", ur)
		m.set_shader_parameter("n", st.size())
		var sa := PackedVector4Array()
		var sb := PackedVector4Array()
		for s in st:
			sa.append(Vector4(s[0], s[1], s[2], s[3]))
			sb.append(Vector4(s[4], s[5], s[6], 0.0))
		while sa.size() < 4:
			sa.append(Vector4.ZERO)
			sb.append(Vector4.ZERO)
		m.set_shader_parameter("sa", sa)
		m.set_shader_parameter("sb", sb)

func _tear_shards(p: PX, F: float, born: float, pts: Array, seed: float) -> void:
	var R := Rng.new(seed)
	for i in 5:
		var P0 = pts[int(floorf(R.r() * pts.size()))]
		var sp := 0.6 + R.r() * 1.1
		var sz := 1.6 + R.r() * 2.2
		var rot := R.r() * 6.28
		var age := F - born - R.r() * 1.2
		if P0 == null or age < 0.0 or age > 6.0: continue
		var cx: float = P0[0] + P0[2] * (1.0 + age * sp * 1.5)
		var cy: float = P0[1] + P0[3] * (1.0 + age * sp * 1.5) + age * age * 0.05
		var r := sz * (1.0 - age / 8.0)
		var a := rot + age * 0.35
		var q: Array = []
		for k in 3:
			var ak := a + k * 2.1 + (0.5 if k == 1 else 0.0)
			q.append(Vector2(cx + cos(ak) * r, cy + sin(ak) * r))
		p.poly(q, TVOID)
		for k in 3:
			var A: Vector2 = q[k]
			var B: Vector2 = q[(k + 1) % 3]
			p.line(A.x, A.y, B.x, B.y, TEARL[0] if age < 2.0 else (TEARL[1] if age < 4.0 else TEARL[3]))

## shards of Aida's swing are drawn after the quads (on the rect layer)
func _draw_shards(g: CanvasItem) -> void:
	for e in L:
		if e["k"] == "slash" and e.has("shards"):
			_tear_shards(PX.new(g, e["x"], e["y"]), e["t"] / FR, e["shards"][1], e["shards"][0], e["seed"])


# ---------- DUST ----------
func _dust(g: CanvasItem, t: float, x: float, y: float, d: int, seed: float, big: bool) -> bool:
	var F := t / FR
	if F > 11.0: return false
	var p := PX.new(g, x, y)
	var R := Rng.new(seed)
	var n := 7 if big else 4
	for i in n:
		var sp := (0.6 + R.r() * 1.1) * (1.4 if big else 1.0)
		var lift := 0.25 + R.r() * 0.5
		var r0 := (3.0 if big else 2.0) + R.r() * 2.0
		var dl := R.r() * 1.5
		var tt := F - dl
		if tt < 0.0: continue
		var ee := 1.0 - pow(1.0 - minf(1.0, tt / 9.0), 2.0)
		var xx := d * (2.0 + sp * ee * 10.0) + (R.r() - 0.5) * 4.0
		var yy := -lift * ee * 8.0 - 1.0
		var r := maxf(0.0, jr(r0 * (1.0 - tt / 10.0) + (tt * 0.6 if tt < 2.0 else 0.0)))
		var c: Color = DUSTP[mini(4, int(floorf(tt / 2.2)))]
		if r > 0.0: p.disc(xx, yy, r, c)
		else: p.px(xx, yy, c)
	return true


# ---------- DOUBLE JUMP / DASH / AIR DASH ----------
func _djump(g: CanvasItem, e: Dictionary) -> bool:
	var f := fr(e["t"])
	if f > 8: return false
	var C: Array = e["C"]
	var p := PX.new(g, e["x"], e["y"])
	var rx := 5.0 + f * 3.6
	var ry := 1.5 + f * 0.9
	var dy := f * 0.9
	var c: Color = Color.WHITE if f < 2 else (C[1] if f < 4 else (C[2] if f < 6 else C[3]))
	for a in 64:
		var th := a / 64.0 * TAU
		var xx := cos(th) * rx
		var yy := sin(th) * ry + dy
		if f > 4 and a % 5 == 0: continue
		p.px(xx, yy, c)
		if f < 3 and sin(th) > 0.0: p.px(xx, yy + 1, c)
	if f >= 1 and f < 5:
		for k in [-1.0, -0.45, 0.45, 1.0]:
			var x: float = k * (rx + 1.0)
			var y0 := dy + ry * 0.5 + 1.0 + f
			p.line(x, y0, x + k * (2.0 + f), y0 + 1.0 + f, C[0] if f < 3 else C[2])
	if f < 2: p.rect(-3, -1, 7, 2, Color.WHITE)
	return true

func _dash(g: CanvasItem, e: Dictionary) -> bool:
	var P = arena.player
	var live: bool = (P.anim == "dash" or P.anim == "airdash") and e["t"] < 600.0
	if not live and not e.has("endT"): e["endT"] = e["t"]
	var end: float = 0.0 if not e.has("endT") else (e["t"] - e["endT"]) / FR
	if end > 4.0: return false
	var C: Array = e["C"]
	var dir: int = e["d"]
	var cs: float = P.CSCALE
	var k := minf(1.0, e["t"] / 70.0)
	var shr := maxf(0.0, 1.0 - end / 4.0)
	var R := Rng.new(e["seed"])
	var p := PX.new(g, P.position.x - dir * 16.0 * cs, P.position.y)
	var Hh := [-18.0, -40.0, -62.0, -84.0]
	var Lm := [62.0, 84.0, 70.0, 48.0]
	var X0 := [2.0, 10.0, 0.0, 14.0]
	for i in 4:
		var ph := R.r() * 0.6
		var Ll := jr((Lm[i] * cs / S) * k * shr * (0.7 + 0.3 * sin(e["t"] / 40.0 + i * 1.7 + ph)))
		if Ll < 2.0: continue
		var yy := jr(Hh[i] * cs / S) + float((i + int(floorf(e["t"] / 40.0))) % 2)
		var x0 := -dir * jr(X0[i] * cs / S)
		p.line(x0, yy, x0 - dir * Ll, yy, C[3] if end > 2.0 else (C[0] if i % 3 == 1 else C[2]))
		if Ll > 8.0: p.line(x0 - dir * jr(Ll * 0.25), yy, x0 - dir * jr(Ll * 0.55), yy, C[2] if end > 1.0 else Color.WHITE)
	var f := fr(e["t"])
	if f < 6:
		var q := PX.new(g, e["x0"], e["y0"])
		var r := 3.0 + f * 2.5
		for a in 11:
			var th := PI * 0.5 + (a / 10.0 - 0.5) * 1.9
			q.px(-dir * cos(th - PI * 0.5) * r * 0.7 - dir * f * 1.5, -sin(th) * r * 0.9 - 2.0, Color.WHITE if f < 2 else (C[2] if f < 4 else C[3]))
	return true

func _airb(g: CanvasItem, e: Dictionary) -> bool:
	var f := fr(e["t"])
	if f > 7: return false
	var C: Array = e["C"]
	var p := PX.new(g, e["x"], e["y"])
	var dir: int = e["d"]
	var rx := 2.0 + f * 1.6
	var ry := 6.0 + f * 4.2
	var c: Color = Color.WHITE if f < 2 else (C[1] if f < 4 else (C[2] if f < 6 else C[3]))
	for a in 48:
		var th := a / 48.0 * TAU
		var xx := cos(th) * rx - dir * f * 2.5
		var yy := sin(th) * ry
		if f > 3 and a % 6 == 0: continue
		p.px(xx, yy, c)
		if f < 3: p.px(xx - dir, yy, c)
	if f < 5:
		for yy in [-ry * 0.6, 0.0, ry * 0.6]:
			var Ll := 4.0 + f * 3.0
			p.line(-dir * (rx + 2.0 + f * 2.0), jr(yy), -dir * (rx + 2.0 + f * 2.0 + Ll), jr(yy), C[0] if f < 2 else C[2])
	return true


# ---------- PLUNGE: the trail of the dive, the floor taking the slam ----------
func _dive(g: CanvasItem, e: Dictionary) -> bool:
	var P = arena.player
	if not e.has("landT") and P.anim == "dive" and not P.on: e["y1"] = maxf(e["y1"], P.position.y - 30.0 * P.CSCALE)
	elif not e.has("landT"): e["landT"] = e["t"]
	var since: float = e["t"] - e["landT"] if e.has("landT") else 0.0
	if since > 520.0: return false
	var len: float = e["y1"] - e["y0"]
	if len < 8.0: return true
	if e["ch"] == "aida":
		var tt: float = 3.2 + since / FR if e.has("landT") else minf(3.2, e["t"] / FR)
		var Ll := (len + 20.0) / S
		_tear_quad(e, Vector2(e["x"], e["y0"]), Vector2(0, 1), Ll, tt, [[0.0, 0.0, 0.0, 1.0, 5.0, 0.0, 2], [-4.0, -6.0, 0.3, 0.95, 1.6, 0.5, 0], [4.0, 5.0, 0.15, 0.85, 1.2, 0.8, 0]])
		return true
	var C: Array = e["C"]
	var p := PX.new(g, e["x"], e["y0"])
	var f := fr(since)
	var Lp := len / S
	var fade := minf(1.0, f / 6.0) if e.has("landT") else 0.0
	if fade >= 1.0: return false
	var top := Lp * (0.2 + 0.8 * fade)
	var i := int(floorf(top))
	while i <= Lp:
		var v := i / Lp
		var hw := (0.8 + 5.0 * pow(v, 1.5)) * (1.0 - fade * 0.6)
		var ch := ceili(hw)
		for k in range(-ch, ch + 1):
			var q := absf(k) / maxf(1.0, hw)
			if q <= 1.0: p.px(k, i, (C[1] if fade < 0.4 else C[2]) if q < 0.35 else (C[2] if q < 0.75 else C[3]))
		i += 1
	var R := Rng.new(e["seed"])
	for n in 5:
		var xo := (1.0 if n % 2 else -1.0) * (6.0 + n * 2.5 + R.r() * 2.0)
		var st := Lp * (0.15 + R.r() * 0.5)
		var ln := Lp * (0.2 + R.r() * 0.25)
		var a := maxf(top, st)
		var b := minf(Lp, st + ln)
		if b > a: p.line(xo, a, xo, b, C[0] if fade < 0.3 else C[3])
	return true

## a baked sprite-sheet effect: frame by its own clock, drawn at the pixel scale from its pivot
func _sheet(g: CanvasItem, e: Dictionary) -> bool:
	var i := int(e["t"] / 1000.0 * float(e["fps"]))
	if i >= int(e["n"]): return false
	var fw: float = e["fw"]
	var fh: float = e["fh"]
	var sc: float = e["sc"]
	var c := i % int(e["cols"])
	var r := i / int(e["cols"])
	g.draw_texture_rect_region(e["tex"], Rect2(e["x"] - float(e["px"]) * sc, e["y"] - float(e["py"]) * sc, fw * sc, fh * sc), Rect2(c * fw, r * fh, fw, fh))
	return true

## a baked colour frame (flipped by d) plus its mask frame as a negative window onto the game (pfx_negmask quad)
func _baked(g: CanvasItem, e: Dictionary, i: int, fw: float, fh: float, cols: int, px: float, py: float, sc: float, d: float) -> void:
	var c := i % cols
	var r := i / cols
	if d < 0.0:                         # a negative-width rect does not mirror in place: flip with the transform instead
		g.draw_set_transform(Vector2(e["x"], e["y"]), 0.0, Vector2(-1.0, 1.0))
		g.draw_texture_rect_region(e["tex"], Rect2(-px * sc, -py * sc, fw * sc, fh * sc), Rect2(c * fw, r * fh, fw, fh))
		g.draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		g.draw_texture_rect_region(e["tex"], Rect2(e["x"] - px * sc, e["y"] - py * sc, fw * sc, fh * sc), Rect2(c * fw, r * fh, fw, fh))
	var mt: Texture2D = e["mask"]
	var lr := Rect2(-px * sc, -py * sc, fw * sc, fh * sc)
	if d < 0.0: lr.position.x = -(fw - px) * sc
	var q := _quad(e, SH_NEG, Vector2(e["x"], e["y"]), lr)
	var m: ShaderMaterial = q.material
	if not e.has("set") or e["set"] != lr:
		e["set"] = lr
		m.set_shader_parameter("mask", mt)
		m.set_shader_parameter("rect", Vector4(lr.position.x, lr.position.y, lr.size.x, lr.size.y))
		m.set_shader_parameter("flip", d)
	var ts := mt.get_size()
	m.set_shader_parameter("region", Vector4(c * fw / ts.x, r * fh / ts.y, fw / ts.x, fh / ts.y))

## a plain baked sheet (no mask), flipped by d, scaled by sc
func _bk(g: CanvasItem, e: Dictionary) -> bool:
	var i := int(e["t"] / 1000.0 * 50.0)
	if i >= int(e["n"]): return false
	var fw: float = e["fw"]
	var fh: float = e["fh"]
	var sc: float = e["sc"]
	var cols: int = e["cols"]
	var src := Rect2((i % cols) * fw, (i / cols) * fh, fw, fh)
	if e.has("ang"):                    # turned to a heading (d < 0: mirrored first, so down stays down)
		g.draw_set_transform(Vector2(e["x"], e["y"]), e["ang"], Vector2(sc * (-1.0 if float(e["d"]) < 0.0 else 1.0), sc))
		g.draw_texture_rect_region(e["tex"], Rect2(-float(e["px"]), -float(e["py"]), fw, fh), src)
		g.draw_set_transform_matrix(Transform2D.IDENTITY)
		return true
	if float(e["d"]) < 0.0:
		g.draw_set_transform(Vector2(e["x"], e["y"]), 0.0, Vector2(-1.0, 1.0))
		g.draw_texture_rect_region(e["tex"], Rect2(-float(e["px"]) * sc, -float(e["py"]) * sc, fw * sc, fh * sc), src)
		g.draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		g.draw_texture_rect_region(e["tex"], Rect2(e["x"] - float(e["px"]) * sc, e["y"] - float(e["py"]) * sc, fw * sc, fh * sc), src)
	return true

## Aida's thrust, baked, scaled to the jab's length
func _athr(g: CanvasItem, e: Dictionary) -> bool:
	var i := int(e["t"] / 1000.0 * 50.0)
	if i >= 37: return false
	_baked(g, e, i, 200.0, 72.0, 4, 10.0, 30.0, e["sc"], float(e["d"]))
	return true

## Aida's dive landing, baked
func _dland(g: CanvasItem, e: Dictionary) -> bool:
	var i := int(e["t"] / 1000.0 * 50.0)
	if i >= 37: return false
	_baked(g, e, i, 200.0, 70.0, 4, 100.0, 46.0, S, 1.0)
	return true

## Aida's baked swing tear, flipped to her facing
func _asl_draw(g: CanvasItem, e: Dictionary) -> bool:
	var i := int(e["t"] / 1000.0 * 50.0)
	if i >= 37: return false
	_baked(g, e, i, 232.0, 232.0, 7, 116.0, 116.0, S, float(e["d"]))
	return true

func _slam(g: CanvasItem, e: Dictionary) -> bool:
	var F: float = e["t"] / FR
	var f := int(floorf(F))
	if F > 13.0: return false
	var C: Array = e["C"]
	var p := PX.new(g, e["x"], e["y"])
	var R := Rng.new(e["seed"])
	if e["ch"] == "aida":
		# the floor tears open both ways, an eye lying on the ground
		var stp := [[0.0, -1.0, 0.0, 1.0, 5.5, 0.0, 3], [-6.0, -10.0, 0.2, 0.9, 1.8, 0.6, 0], [3.0, 4.0, 0.1, 0.7, 1.1, 0.9, 0]]
		var e2 := {"seed": e["seed"] + 1.0}
		var e3 := {"seed": e["seed"] - 1.0}
		if not e.has("tq1"): e["tq1"] = e2
		if not e.has("tq2"): e["tq2"] = e3
		# 처형 (owner 2026-11-04): the tears climb out of the floor, a V rising from the blow, not lying flat
		var up: bool = e.get("up", false)
		if up:
			# 처형: the floor bursts open wide, four tears thrown up and out from the blow
			if not e.has("tq3"): e["tq3"] = {"seed": e["seed"] + 2.0}
			if not e.has("tq4"): e["tq4"] = {"seed": e["seed"] - 2.0}
			_tear_quad(e["tq1"], Vector2(e["x"] + 10.0, e["y"] - 3.0), Vector2(0.86, -0.5), 200.0 / S, F, stp)
			_tear_quad(e["tq2"], Vector2(e["x"] - 10.0, e["y"] - 3.0), Vector2(-0.86, -0.5), 200.0 / S, F, stp)
			_tear_quad(e["tq3"], Vector2(e["x"] + 4.0, e["y"] - 3.0), Vector2(0.34, -0.94), 160.0 / S, F, stp)
			_tear_quad(e["tq4"], Vector2(e["x"] - 4.0, e["y"] - 3.0), Vector2(-0.34, -0.94), 160.0 / S, F, stp)
		else:
			_tear_quad(e["tq1"], Vector2(e["x"] + 6.0, e["y"] - 3.0), Vector2(1, 0), 144.0 / S, F, stp)
			_tear_quad(e["tq2"], Vector2(e["x"] - 6.0, e["y"] - 3.0), Vector2(-1, 0), 144.0 / S, F, stp)
		e["q"] = e["tq1"].get("q")
		e["q2"] = e["tq2"].get("q")
		if e.has("tq3"):
			e["q3"] = e["tq3"].get("q")
			e["q4"] = e["tq4"].get("q")
		if f < 2: p.rect(-4, -2, 9, 2, Color.WHITE)
		var sh: Array = []
		for i in (14 if up else 8):
			var d := 1.0 if i % 2 else -1.0
			if up: sh.append([d * (6.0 + i * 5.0), -6.0, d * (0.6 + R.r() * 0.9), -2.8 - R.r() * 1.8])        # thrown up and wide
			else: sh.append([d * (10.0 + i * 7.0), -3.0, d * 0.8, -1.6 - R.r() * 0.8])
		_tear_shards(p, F, 0.8, sh, e["seed"])
		return true
	var pal: Array = C
	if f < 2:
		var w: float = [34.0, 26.0][f]
		p.rect(-w, -1, w * 2.0 + 1.0, 2, Color.WHITE)
		p.rect(-3, -6 + f * 2, 7, 5 - f * 2, Color.WHITE)
	for kd in [[0, 0], [1, 2]]:
		var k: int = kd[0]
		var ff: int = f - kd[1]
		if ff < 0 or ff > 7: continue
		var rx := 12.0 + ff * 10.0 + k * 5.0
		var ry := rx * 0.26
		var c: Color = Color.WHITE if ff < 1 and k == 0 else pal[mini(4, mini(4, ff >> 1) + k)]
		for a in 41:
			var th := PI * (a / 40.0)
			var xx := cos(th) * rx
			var yy := -sin(th) * ry
			if absf(cos(th)) < 0.25 and ff > 2: continue
			p.px(xx, yy, c)
			if ff < 5: p.px(xx, yy - 1, c)
			if ff < 2 and k == 0: p.px(xx, yy - 2, c)
	for d in [1.0, -1.0]:
		var cx := 0.0
		var cy := 0.0
		var n := mini(12, 3 + f * 3)
		var R2 := Rng.new(e["seed"] + (7.0 if d > 0 else 13.0))
		for i in n:
			var nx: float = cx + d * (3.0 + R2.r() * 3.0)
			var ny := maxf(0.0, minf(2.0, cy + (1.0 if R2.r() < 0.5 else -1.0)))
			if f < 8: p.line(cx, cy + 1, nx, ny + 1, C[3] if f < 3 else C[4])
			cx = nx
			cy = ny
	for i in 10:
		var d := 1.0 if i % 2 else -1.0
		var v := 1.2 + R.r() * 2.2
		var up := 2.2 + R.r() * 2.6
		var tt := F - R.r() * 0.8
		if tt < 0.0: continue
		var xx := d * (4.0 + v * tt * 2.0)
		var yy := -up * tt * 1.6 + 0.3 * tt * tt
		if yy > 1.0: continue
		var s2 := 2.0 if tt < 4.0 else 1.0
		p.rect(xx, yy, s2, s2, pal[mini(4, 1 + int(floorf(tt / 2.5)))])
	if e["ch"] == "luce" and f < 6:
		var h: float = [22, 30, 30, 24, 14, 6][f]
		var w2: float = [5, 4, 3, 2, 1, 1][f]
		p.rect(-floorf(w2 / 2.0), -h, w2, h, Color.WHITE if f < 2 else C[2])
		p.rect(-w2 * 2.0, -jr(h * 0.72), w2 * 4.0 + 1.0, maxf(1.0, w2 - 1.0), Color.WHITE if f < 2 else C[2])
	return true


# ---------- CHARGE: motes streak in to the hilt, a glint grows, a burst at full charge ----------
func _charge(g: CanvasItem, e: Dictionary) -> bool:
	var P = arena.player
	var live: bool = P.anim in ["charge", "acharge", "lgather", "gcharge", "kcharge"]
	if not live and not e.has("endT"): e["endT"] = e["t"]
	if e.has("endT") and e["t"] - e["endT"] > 160.0: return false
	var C: Array = e["C"]
	var cs: float = P.CSCALE
	var tx: float = P.position.x + P.dir * {"estelle": 4.0, "aida": -21.0, "luce": 0.0}.get(P.who, 0.0) * cs
	var ty: float = P.position.y - {"estelle": 33.0, "aida": 94.0, "luce": 50.0}.get(P.who, 50.0) * cs
	var p := PX.new(g, tx, ty)
	var lv := minf(1.0, P.charge_t / 650.0)
	var fade := 1.0 if not e.has("endT") else maxf(0.0, 1.0 - (e["t"] - e["endT"]) / 160.0)
	var dt := dtw
	if live and dt > 0.0:
		e["acc"] = e.get("acc", 0.0) + dt
		var stp := 60.0 if P.cfull else 30.0
		while e["acc"] > stp:
			e["acc"] -= stp
			e["m"].append({"a": randf() * 6.28, "r": (22.0 + randf() * 18.0) * (1.0 + 0.4 * lv), "t": 0.0, "v": 0.5 + randf() * 0.4})
	var ms: Array = e["m"]
	var i := ms.size() - 1
	while i >= 0:
		var m: Dictionary = ms[i]
		m["t"] += dt
		var k: float = m["t"] / (260.0 / m["v"])
		if k >= 1.0:
			ms.remove_at(i)
			i -= 1
			continue
		var r: float = m["r"] * (1.0 - k * k)
		var r2: float = minf(m["r"], r + 4.0 + 8.0 * (1.0 - k))
		var ca := cos(m["a"])
		var sa := sin(m["a"]) * 0.8
		p.line(ca * r, sa * r, ca * r2, sa * r2, Color.WHITE if k > 0.7 else (C[1] if k > 0.35 else C[2]))
		if k < 0.6: p.line(ca * r - sa * 0.9, sa * r + ca * 0.9, ca * r2 - sa * 0.9, sa * r2 + ca * 0.9, C[3])
		i -= 1
	if fade > 0.0:
		var pul := 1.0 if sin(e["t"] / 70.0) > 0.0 else 0.0
		var Ll := jr((3.0 + lv * 7.0 + (3.0 * pul if P.cfull else 0.0)) * fade)
		var cc: Color = Color.WHITE if P.cfull else C[1]
		p.line(-Ll, 0, Ll, 0, cc)
		p.line(0, -Ll, 0, Ll, cc)
		if Ll > 3.0:
			p.rect(-1, -1, 3, 3, Color.WHITE)
			var d := jr(Ll * 0.4)
			p.line(-d, -d, d, d, C[2]); p.line(-d, d, d, -d, C[2])
			p.line(-Ll + 2, -1, Ll - 2, -1, cc); p.line(-Ll + 2, 1, Ll - 2, 1, cc)
			p.line(-1, -Ll + 2, -1, Ll - 2, cc); p.line(1, -Ll + 2, 1, Ll - 2, cc)
	if P.cfull and not e.has("fullT"): e["fullT"] = e["t"]
	if e.has("fullT"):
		var f := fr(e["t"] - e["fullT"])
		if f < 8:
			var r := 5.0 + f * 5.0
			var c: Color = Color.WHITE if f < 2 else (C[1] if f < 4 else (C[2] if f < 6 else C[3]))
			p.circle(0, 0, r, c)
			if f < 5: p.circle(0, 0, r - 1.0, c)
			if f < 2: p.disc(0, 0, 4 - f, Color.WHITE)
			for k in 8:
				var a := k * PI / 4.0 + 0.2
				var r0 := r + 2.0
				var r1 := r + 2.0 + (5.0 if k % 2 else 10.0) * (1.0 - f / 8.0)
				p.line(cos(a) * r0, sin(a) * r0, cos(a) * r1, sin(a) * r1, Color.WHITE if f < 3 else C[2])
	return true


# ---------- AIDA's rift gate / ult cut / Hollow ----------
## the gate, baked (tools/pixelfx_fx/aida-gate.js, 57 frames of 128x150 at 50 fps, pivot (64, 134), drawn 100 art px
## tall): opening 0-0.12 s, a seamless stare 0.12-0.52 s looped until released, then the snap, cooling and the
## negative afterimage from 0.52 s; scaled to the gate's height, its clock sped up by kk like the old one
func _gate_b(g: CanvasItem, e: Dictionary) -> bool:
	if e.get("rel", false) and not e.has("relT"): e["relT"] = e["t"]
	var kk: float = e["kk"]
	var ts: float
	var t: float = e["t"] / 1000.0
	if e.has("relT"): ts = 0.52 + (e["t"] - e["relT"]) / 1000.0 * kk
	elif t * kk < 0.12: ts = t * kk
	else: ts = 0.12 + fmod(t * kk - 0.12, 0.4)
	var i := int(ts * 50.0)
	if i >= 57 or e["t"] > 5000.0: return false
	if not e.has("tex"):
		e["tex"] = AIDA_GATE
		e["mask"] = AIDA_GATE_M
	_baked(g, e, i, 128.0, 150.0, 9, 64.0, 134.0, S * (e["h"] / S) / 100.0, 1.0)
	return true

func _gate(e: Dictionary) -> bool:
	if e.get("rel", false) and not e.has("relT"): e["relT"] = e["t"]
	var F: float = e["t"] / FR * e["kk"]
	var tt: float = minf(F, 3.0) if not e.has("relT") else 3.0 + (e["t"] - e["relT"]) / FR * e["kk"]
	if tt > 10.5 or e["t"] > 4000.0: return false
	var w: float = e["w"]
	var Ll: float = (e["h"] + 4.0) / S
	_tear_quad(e, Vector2(e["x"], e["y"] - e["h"]), Vector2(0, 1), Ll, tt, [[0.0, 0.0, 0.0, 1.0, 7.5 * w, 0.0, 1], [-6.0 * w, -4.0 * w, 0.08, 0.8, 2.0 * w, 0.5, 1], [5.0 * w, 7.0 * w, 0.3, 0.98, 1.3 * w, 0.8, 1]])
	return true

func _utear(e: Dictionary) -> bool:
	var tt: float = e["t"] / FR * 1.15
	if tt > 10.5: return false
	var c := cos(e["ang"])
	var s := sin(e["ang"])
	var h: float = e["len"] / 2.0
	var a := Vector2(e["x"] - c * h, e["y"] - s * h)
	_tear_quad(e, a, Vector2(c, s), e["len"] / S, tt, [[0.0, 0.0, 0.0, 1.0, 7.5, 0.0, 1], [-6.0, -4.0, 0.12, 0.82, 1.8, 0.5, 1], [4.0, 6.0, 0.3, 1.0, 1.1, 0.8, 1]])
	return true

func _hollow(g: CanvasItem, e: Dictionary) -> bool:
	var T: float = e["t"]
	var Lf: float = e["life"]
	if T > Lf: return false
	var ph := T / 1000.0
	var op := 1.0
	if T < 150.0:
		var x := T / 150.0
		op = 1.0 + 3.2 * pow(x - 1.0, 3.0) + 2.2 * pow(x - 1.0, 2.0)
	elif T > Lf - 150.0: op = maxf(0.0, (Lf - T) / 150.0)
	var R0: float = e["r"] / S * op
	var p := PX.new(g, e["x"], e["y"])
	if R0 < 1.0:
		_hide(e)
		p.px(0, 0, Color.WHITE)
		return true
	if not e.has("b"):
		var R := Rng.new(floorf(e["seed"] * 997.0))
		var b: Array = [[0.0, 0.0, 1.0, R.r() * 6.0, 1.0]]
		var n := 3 + int(floorf(R.r() * 2.0))
		for i in n:
			b.append([i / float(n) * 6.28 + R.r(), 0.45 + R.r() * 0.25, 0.5 + R.r() * 0.25, R.r() * 6.0, (-1.0 if R.r() < 0.5 else 1.0) * (1.2 + R.r() * 1.6)])
		e["b"] = b
	var B: Array = []
	var pv := PackedVector4Array()
	for b in e["b"]:
		var a: float = b[0] + ph * b[4]
		var pul: float = 1.0 + 0.12 * sin(ph * (7.0 + b[3]) + b[3])
		var bb := Vector4(cos(a) * b[1] * R0, sin(a) * b[1] * R0 * 0.9, b[2] * R0 * pul, b[3])
		B.append(bb)
		pv.append(bb)
	while pv.size() < 6: pv.append(Vector4.ZERO)
	var M := ceilf(R0 * 1.7) + 3.0
	var q := _quad(e, SH_HOL, Vector2(e["x"], e["y"]), Rect2(-M * S, -M * S, (2.0 * M + 1.0) * S, (2.0 * M + 1.0) * S))
	var m: ShaderMaterial = q.material
	m.set_shader_parameter("T", T)
	m.set_shader_parameter("nb", B.size())
	m.set_shader_parameter("B", pv)
	var R2 := Rng.new(floorf(e["seed"] * 1000.0))
	for i in 4:
		var b: Vector4 = B[int(floorf(R2.r() * B.size()))]
		var a0 := R2.r() * 6.28 + ph * (2.0 + R2.r() * 2.0) * (1.0 if i % 2 else -1.0)
		if int(floorf(T / 50.0 + i * 3)) % 3 == 0: continue
		p.line(b.x + cos(a0) * b.z, b.y + sin(a0) * b.z, b.x + cos(a0 + 0.3) * (b.z + 3.0), b.y + sin(a0 + 0.3) * (b.z + 3.0), HOL["zap"] if i % 2 else IRIS[(i * 2 + int(floorf(T / 80.0))) % IRIS.size()])
	for i in 6:
		var a := R2.r() * 6.28 + ph * (1.0 + R2.r() * 1.5)
		var rr := R0 * (1.35 + R2.r() * 0.5)
		p.px(cos(a) * rr, sin(a) * rr, IRIS[(i + int(floorf(T / 90.0))) % IRIS.size()])
	return true


# ---------- LUCE: pillar, lightning, heal crosses ----------
static func _lring(p: PX, cx: float, cy: float, rx: float, ry: float, c: Color, gap: Callable) -> void:
	var n := maxi(16, int(jr((rx + ry) * 3.0)))
	for i in n:
		if gap.is_valid() and gap.call(i): continue
		var a := i / float(n) * 6.283
		p.px(cx + cos(a) * rx, cy + sin(a) * ry, c)

func _pillar(g: CanvasItem, e: Dictionary) -> bool:
	var f := fr(e["t"])
	if f > 15: return false
	var p := PX.new(g, e["x"], e["y"])
	var R := Rng.new(e["seed"])
	var H: float = e["H"]
	var k: float = e["kk"]
	var W: float = [0.5, 1, 4, 7, 8, 8, 7, 6, 5, 4, 3, 2, 1, 0.5, 0, 0][f] * k
	var top := -H * (f + 1) / 2.0 if f < 2 else -H
	var dis := 0.0 if f < 9 else (f - 8) / 6.0
	var wq := (W * 1.6 + 3.0) * S
	var q := _quad(e, SH_PIL, Vector2(e["x"], e["y"]), Rect2(-wq, (floorf(top) - 1.0) * S, wq * 2.0 + S, (-floorf(top) + 2.0) * S))
	var m: ShaderMaterial = q.material
	m.set_shader_parameter("f", f)
	m.set_shader_parameter("H", H)
	m.set_shader_parameter("W", W)
	m.set_shader_parameter("top", top)
	m.set_shader_parameter("dis", dis)
	if f >= 2 and f < 10:
		var r := (6.0 + (f - 2) * 4.0) * k
		_lring(p, 0, 0, r, r * 0.25, LPL[0] if f < 4 else (LPL[3] if f < 7 else LPL[5]), func(i): return f > 5 and (i % 3 == 0 or (f > 7 and i % 2 == 1)))
		if f < 5: p.rect(-r + 2.0, -1, r * 2.0 - 3.0, 2, LPL[1])
	for i in 16:
		var x := (R.r() - 0.5) * 26.0 * k
		var v := 0.6 + R.r() * 1.2
		var dl := R.r() * 3.0
		var tt := f - 2 - dl
		if tt < 0.0: continue
		var y := -tt * v * 2.2 - R.r() * 4.0
		if -y > H * 0.8: continue
		p.px(x, y, LPL[0] if tt < 3.0 else (LPL[3] if tt < 6.0 else LPL[5]))
	return true

static func _lzig(R: Rng, x0: float, y0: float, x1: float, y1: float, n: int, amp: float) -> Array:
	var pts: Array = [Vector2(x0, y0)]
	for i in range(1, n):
		var u := float(i) / n
		pts.append(Vector2(x0 + (x1 - x0) * u + (R.r() - 0.5) * amp * 2.0, y0 + (y1 - y0) * u + (R.r() - 0.5) * 2.0))
	pts.append(Vector2(x1, y1))
	return pts

static func _lpath(p: PX, pts: Array, c: Color, w := 0, ox := 0.0) -> void:
	for i in pts.size() - 1:
		var A: Vector2 = pts[i]
		var B: Vector2 = pts[i + 1]
		p.line(A.x + ox, A.y, B.x + ox, B.y, c)
		for k in range(1, w + 1): p.line(A.x + ox + k, A.y, B.x + ox + k, B.y, c)

func _bolt(g: CanvasItem, e: Dictionary) -> bool:
	var f := fr(e["t"])
	if f > 11: return false
	var p := PX.new(g, e["x"], e["y"])
	var R := Rng.new(e["seed"])
	var Rf := Rng.new(e["seed"] + (0.0 if f < 2 else 7.0))
	var k: float = e["kk"]
	var H: float = e["H"]
	var pts := _lzig(Rf, (Rf.r() - 0.5) * 30.0 * k, -H, 0, 0, 12, 7.0 * k)
	if f < 5 and f != 2:
		_lpath(p, pts, LPL[0] if f < 2 else LPL[2], int(jr(1.0 + k)))
		_lpath(p, pts, LPL[3] if f < 2 else LPL[4], 0, -1.0)
		_lpath(p, pts, LPL[3] if f < 2 else LPL[4], 0, jr(2.0 + k))
		var j := 2
		while j < 10:
			var A: Vector2 = pts[j]
			var br := _lzig(Rf, A.x, A.y, A.x + (-1.0 if Rf.r() < 0.5 else 1.0) * (12.0 + Rf.r() * 16.0) * k, A.y + (14.0 + Rf.r() * 12.0) * k, 4, 3)
			_lpath(p, br, LPL[2] if f < 2 else LPL[4], 1 if f < 2 else 0)
			j += 2
	if f >= 5 and f < 9: _lpath(p, pts, LPL[5] if f < 7 else LPL[6], 1)
	if f < 4:
		var Ll: float = [16, 12, 9, 5][f] * k
		p.line(-Ll, 0, Ll, 0, LPL[0]); p.line(-Ll * 0.8, -1, Ll * 0.8, -1, LPL[0]); p.line(0, -Ll, 0, 2, LPL[0]); p.rect(-2, -2, 5, 3, LPL[0])
	if f >= 1 and f < 7:
		var r := (6.0 + (f - 1) * 5.0) * k
		_lring(p, 0, 0, r, r * 0.22, LPL[0] if f < 3 else LPL[4], func(i): return f > 3 and i % 3 == 0)
	for i in 16:
		var d := 1.0 if i % 2 else -1.0
		var v := 1.0 + R.r() * 2.4
		var tt := f - 1
		if tt < 0: continue
		p.px(d * v * tt * 2.4 * k, -R.r() * 5.0 - tt * R.r() * 1.4 + 0.15 * tt * tt, LPL[0] if tt < 3 else (LPL[3] if tt < 6 else LPL[5]))
	return true

func _heal(g: CanvasItem, e: Dictionary) -> bool:
	var T: float = e["t"] - e.get("dl", 0.0)
	if T < 0.0: return true
	if T > e["life"]: return false
	var k: float = T / e["life"]
	var e2 := 1.0 - pow(1.0 - k, 1.6)
	var x: float = e["x"] + e["vx"] * T + sin(T / 140.0 + e["ph"]) * 3.0
	var y: float = e["y"] - e["rise"] * e2
	if k > 0.72 and int(floorf(T / 60.0)) % 2 == 1: return true
	var p := PX.new(g, x, y)
	var c: Color = LPL[0] if k < 0.22 else (LPL[3] if k < 0.55 else LPL[4])
	if e["sz"] >= 2:
		p.rect(0, -3, 1, 7, c); p.rect(-2, -1, 5, 1, c); p.px(0, -3, LPL[0])
	else:
		p.rect(0, -2, 1, 5, c); p.rect(-1, -1, 3, 1, c)
	return true


# ---------- ESTELLE's ult: the oath, the rose citadel, the rose burst on a parry ----------
static func _uez(v: float) -> float:
	return 1.0 - pow(1.0 - clampf(v, 0.0, 1.0), 3.0)

static func _uell(p: PX, cx: float, cy: float, rx: float, ry: float, c: Color, skip: Callable) -> void:
	var n := maxi(16, int(jr((rx + ry) * 3.0)))
	for i in n:
		if skip.is_valid() and skip.call(i): continue
		var a := i / float(n) * 6.283
		p.px(cx + cos(a) * rx, cy + sin(a) * ry, c)

func _vow_oath(g: CanvasItem, e: Dictionary) -> bool:
	var t: float = e["t"]
	if t > 1000.0: return false
	var s: float = e["s"]
	var p := PX.new(g, e["x"], e["y"])
	var k := _uez(t / 220.0)
	var rx := jr((5.0 + 15.0 * k) * s)
	var ry := maxf(2.0, jr(rx * 0.28))
	var fd := (t - 700.0) / 300.0 if t > 700.0 else 0.0
	var c: Color = UPL["w"] if t < 120.0 else (UPL["g1"] if t < 300.0 else (UPL["p4"] if fd > 0.5 else UPL["g2"]))
	_uell(p, 0, 0, rx, ry, c, func(i): return t > 500.0 and (i + int(floorf(t / 90.0))) % 3 == 0)
	if t < 500.0: _uell(p, 0, 0, rx - 3.0, maxf(1.0, ry - 1.0), UPL["w"] if t < 200.0 else UPL["p2"], Callable())
	if t < 700.0:
		var q: Color = UPL["w"] if t < 120.0 else UPL["g2"]
		p.line(-3 * s, 0, 3 * s, 0, q); p.line(0, -1, 0, 1, q); p.px(-5 * s, 0, q); p.px(5 * s, 0, q)
	if t < 160.0:
		p.line(4 * s, -30 * s, 4 * s, 1, UPL["w"]); p.line(4 * s + 1, -30 * s, 4 * s + 1, 1, UPL["p1"]); p.rect(1 * s, -26 * s, 6 * s, 1, UPL["g2"])
	if t >= 120.0:
		var rise := _uez((t - 120.0) / 260.0)
		var a := clampf(1.0 - (t - 600.0) / 250.0, 0.0, 1.0)
		if a > 0.0:
			var oy := (-27.0 + 10.0 * (1.0 - rise)) * s
			var S0: Array = []
			for v in [[-15, -19], [15, -19], [15, 1], [0, 18], [-15, 1]]: S0.append(Vector2(v[0] * s, v[1] * s + oy))
			var col: Color = UPL["w"] if t < 300.0 else UPL["p2"]
			for i in 5:
				var A: Vector2 = S0[i]
				var B: Vector2 = S0[(i + 1) % 5]
				var n := ceili(maxf(absf(B.x - A.x), absf(B.y - A.y)))
				for kk in n + 1:
					if a < 1.0 and (kk + int(floorf(t / 120.0))) % 2 == 1: continue
					var x := A.x + (B.x - A.x) * kk / n
					var y := A.y + (B.y - A.y) * kk / n
					p.px(x, y, col)
					p.px(x + (1.0 if x < 0.0 else -1.0), y, UPL["p4"])
			if t < 650.0:
				var cc: Color = UPL["w"] if t < 300.0 else UPL["g2"]
				p.line(0, oy - 14 * s, 0, oy + 12 * s, cc)
				p.line(-9 * s, oy - 6 * s, 9 * s, oy - 6 * s, cc)
	return true

func _vow_rose(g: CanvasItem, e: Dictionary) -> bool:
	var P = arena.player
	var ap: float = arena.auto_parry() if arena.has_method("auto_parry") else 0.0
	if not (ap > 0.0) and not e.has("endT"): e["endT"] = e["t"]
	var ex: float = 0.0 if not e.has("endT") else (e["t"] - e["endT"]) / 450.0
	if ex > 1.0: return false
	var t: float = e["t"]
	var s: float = P.CSCALE * 0.9
	var p := PX.new(g, P.position.x, P.position.y)
	var K := clampf(ap / 8000.0, 0.0, 1.0)
	var n: int = e.get("last", 30) if ex > 0.0 else ceili(30.0 * K)
	e["last"] = n
	var k := _uez(t / 300.0)
	_uell(p, 0, 0, 16 * k * s, 4.5 * k * s, UPL["w"] if t < 150.0 else UPL["p3"], func(i): return (t > 450.0 and (i + int(floorf(t / 100.0))) % 3 == 0) or ex > 0.3)
	if ex == 0.0:
		for i in 5:
			var a := i / 5.0 * 6.283 + t * 0.001
			p.rect(cos(a) * 4 * k * s - 1, sin(a) * 1.2 * k * s, 2, 1, UPL["p2"])
	p.px(0, 0, UPL["g2"])
	var blink := ap < 1500.0 and ex == 0.0 and int(floorf(t / 120.0)) % 2 == 0
	for i in 30:
		if i >= n: continue
		var sp := _uez((t - 120.0 - i * 12.0) / 300.0)
		if sp <= 0.0: continue
		var a := t * 0.0042 * (1.0 + (i % 3) * 0.18) + i * 1.37
		var z := sin(a)
		var hh := (-4.0 - ((i * 37) % 46)) * s
		var r := (17.0 + (i % 4) * 4.0) * sp * s
		var x := cos(a) * r
		var y := hh + z * r * 0.28
		if ex > 0.0:
			x += cos(a) * ex * 40.0
			y += ex * ex * 50.0
		if blink and i % 2 == 1: continue
		var c: Color = (UPL["p4"] if i % 2 else UPL["p3"]) if z < 0.0 else (UPL["w"] if i % 5 == 0 else (UPL["p2"] if i % 2 else UPL["p3"]))
		p.rect(x, y, 2, 2, c)
		if z > 0.0: p.px(x + 2, y + 1, UPL["p3"] if i % 2 else UPL["p4"])
	return true

func _rose_burst(g: CanvasItem, e: Dictionary) -> bool:
	var f: float = e["t"] / FR
	if f > 11.0: return false
	var p := PX.new(g, e["x"], e["y"])
	var R := Rng.new(e["seed"])
	if f < 2.0: p.disc(0, 0, jr(4.0 - f * 1.5), UPL["w"])
	if f < 4.0:
		var Ll: float = [9, 11, 7, 4][int(floorf(f))]
		p.line(-Ll, 0, Ll, 0, UPL["w"] if f < 2.0 else UPL["g1"])
		p.line(0, -Ll, 0, Ll, UPL["w"] if f < 2.0 else UPL["g1"])
	for i in 14:
		var a := i / 14.0 * 6.283 + R.r() * 0.4
		var v := 1.3 + R.r() * 1.5
		var x := cos(a) * v * f * 1.8
		var y := sin(a) * v * f * 1.3 + 0.18 * f * f
		p.rect(x, y, 2, 2, UPL["p1"] if f < 3.0 else (UPL["p2"] if i % 2 else UPL["p3"]))
		if f < 6.0: p.px(x + 2, y + 1, UPL["p4"])
	return true


# ---------- drawn by other nodes on their own canvas ----------
## LUCE's holy spear bolt (luceBoltFx): long blade forward, crossbar hilt behind, light streaks trailing
static func luce_bolt(g: CanvasItem, t: float, x: float, y: float, ang: float, sz: float, trail, ap := 1.0) -> void:
	var p := PX.new(g, x, y)
	var C := [LPL[0], LPL[1], LPL[3], LPL[4], LPL[5]]
	var ca := cos(ang)
	var sa := sin(ang)
	var F := t / FR
	var f := int(floorf(F))
	var Ll := jr(36.0 * sz * ap)
	var B := jr(10.0 * sz * minf(1.0, ap * 1.6))
	var T := jr(11.0 * sz * ap)
	var P2 := func(u: float, v: float) -> Vector2: return Vector2(u * ca - v * sa, u * sa + v * ca)
	var seg := func(u0: float, v0: float, u1: float, v1: float, c: Color) -> void:
		var a: Vector2 = P2.call(u0, v0)
		var b: Vector2 = P2.call(u1, v1)
		p.line(a.x, a.y, b.x, b.y, c)
	if ap < 1.0:
		var rr := jr(6.0 + ap * 8.0)
		p.circle(0, 0, rr, C[2])
		p.circle(0, 0, rr - 2.0, C[3])
		for i in 8:
			var a2 := i * 0.785 + F * 0.25
			p.px(cos(a2) * (rr + 2.0), sin(a2) * (rr + 2.0), C[1])
	for k in range(1, 4):
		var o := k * 5.0
		seg.call(-T - o - Ll * 0.7, 0, -T - o, 0, C[2] if k == 1 else (C[3] if k == 2 else C[4]))
	if trail != null:
		var tr: Array = trail
		for i in tr.size():
			if i < 2 or i > 8: continue
			var q: Vector2 = tr[i]
			if (i + f) % 2 == 1: p.px((q.x - x) / S, (q.y - y) / S, C[2] if i < 5 else C[3])
	for v in [-2.0, 2.0]: seg.call(-T * 0.4, v, Ll * 0.8, v, C[3])
	for v in [-1.0, 1.0]: seg.call(-T * 0.6, v, Ll, v, C[2])
	seg.call(-T, 0, Ll, 0, C[0])
	var cu := -jr(T * 0.35)
	for du in [-2, -1, 0, 1, 2]:
		seg.call(cu + du, -B + absi(du), cu + du, B - absi(du), C[0] if du == 0 else (C[1] if absi(du) == 1 else C[3]))
	for u in int(T) + 1:
		var hw := jr(2.5 * (1.0 - u / maxf(1.0, T)))
		for v in range(-int(hw), int(hw) + 1):
			var q2: Vector2 = P2.call(Ll + u, v)
			p.px(q2.x, q2.y, C[1] if absf(v) < hw or hw == 0.0 else C[3])
	var gl := 3.0 + (f % 2) * 2.0
	var c0: Vector2 = P2.call(cu, 0)
	p.line(c0.x - gl, c0.y, c0.x + gl, c0.y, C[0])
	p.line(c0.x, c0.y - gl, c0.x, c0.y + gl, C[0])

static func twinkle(g: CanvasItem, x: float, y: float, k: float) -> void:
	var p := PX.new(g, x, y)
	var Ll := 3.0 if k < 0.25 else (2.0 if k < 0.6 else 1.0)
	var c: Color = LPL[0] if k < 0.3 else (LPL[2] if k < 0.65 else LPL[4])
	p.line(-Ll, 0, Ll, 0, c)
	p.line(0, -Ll, 0, Ll, c)
	if k < 0.3: p.px(0, 0, LPL[3])

## Luce's target brackets
static func reticle(g: CanvasItem, x: float, y: float, t: float) -> void:
	var p := PX.new(g, x, y)
	var r := 12.0 + (int(floorf(t / 260.0)) % 2)
	for q in [[1, 1], [-1, 1], [1, -1], [-1, -1]]:
		var sx: float = q[0]
		var sy: float = q[1]
		p.line(sx * r, sy * r, sx * (r - 4.0), sy * r, LPL[3])
		p.line(sx * r, sy * r, sx * r, sy * (r - 4.0), LPL[3])
		p.px(sx * r, sy * r, LPL[1])
	if int(floorf(t / 180.0)) % 3 != 0:
		p.px(0, -1, LPL[0]); p.px(0, 1, LPL[3]); p.px(-1, 0, LPL[3]); p.px(1, 0, LPL[3])

static func ult_pal(who: String) -> Array:
	if who == "aida": return _p(["#ffffff", "#e9d2ff", "#b06cff", "#7a3ad0", "#3a1260"])
	if who == "estelle": return _p(["#ffffff", "#ffd3ea", "#ff96d2", "#d650aa", "#7a2a66"])
	return [LPL[0], LPL[2], LPL[3], LPL[4], LPL[5]]

static func ult_burst(g: CanvasItem, who: String, x: float, y: float, rad: float, t: float, k: float) -> void:
	var p := PX.new(g, x, y)
	var C := ult_pal(who)
	var f := fr(t)
	var r := (rad / S) * (0.3 + k * 0.9)
	var c: Color = C[mini(4, int(floorf(k * 5.0)))]
	if f < 2: p.disc(0, 0, maxf(1.0, jr(r * 0.35)), C[0])
	p.circle(0, 0, jr(r), c)
	if k < 0.5: p.circle(0, 0, jr(r) - 1.0, c)
	for i in 12:
		var a := i / 12.0 * 6.283 + 0.13
		var r0 := r + 2.0
		var r1 := r + 2.0 + (3.0 if i % 2 else 7.0) * (1.0 - k)
		if k < 0.8: p.line(cos(a) * r0, sin(a) * r0, cos(a) * r1, sin(a) * r1, C[0] if k < 0.3 else C[2])
	var ry := maxf(1.0, jr(r * 0.3))
	var rx := jr(r * 1.2)
	for i in 64:
		if k > 0.5 and i % 3 == 0: continue
		var a := i / 64.0 * 6.283
		p.px(cos(a) * rx, 20.0 / S + sin(a) * ry, C[0] if k < 0.4 else C[2])

static func ult_star(g: CanvasItem, x: float, y: float, s: float, spin: float, t: float) -> void:
	var p := PX.new(g, x, y)
	var R1 := maxf(2.0, jr(13.0 * s))
	var step := int(floorf(spin * 4.0)) % 2
	var pul := int(floorf(t / 90.0)) % 2
	var r := R1 * 3.0
	while r > R1 * 1.6:
		for i in 48:
			if (i + int(floorf(t / 60.0))) % 2 == 1: continue
			var a := i / 48.0 * 6.283
			p.px(cos(a) * r, sin(a) * r, LPL[5] if r > R1 * 2.4 else LPL[4])
		r -= 3.0
	var pts: Array = []
	for q in 16:
		var rr := R1 * 0.42 if q % 2 else (R1 if q % 4 == 0 else R1 * 0.72)
		var a := q * PI / 8.0 - PI / 2.0 + (PI / 8.0 if step else 0.0)
		pts.append(Vector2(cos(a) * rr, sin(a) * rr))
	p.poly(pts, LPL[2])
	for q in 16:
		var A: Vector2 = pts[q]
		var B: Vector2 = pts[(q + 1) % 16]
		p.line(A.x, A.y, B.x, B.y, LPL[0])
	p.disc(0, 0, maxf(1.0, jr(R1 * 0.3)), LPL[0])
	var Ll := jr(R1 * (2.2 + 0.3 * pul))
	for dd in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		p.line(dd[0] * R1 * 1.2, dd[1] * R1 * 1.2, dd[0] * Ll, dd[1] * Ll, LPL[1])

## Luce's punch beam (beamPx)
static func beam(g: CanvasItem, x: float, y: float, dir: int, len: float, wd: float, t: float, life: float) -> void:
	var u := t / life
	var grow := minf(1.0, t / 90.0)
	var Ll := jr(len * grow / S)
	var f := fr(t)
	var p := PX.new(g, x, y)
	var d := -1.0 if dir < 0 else 1.0
	var w0 := wd / S * (1.0 + u * 2.0 if u < 0.15 else 1.3 - u * 0.5) / 2.0
	var tail := 0.0 if u < 0.55 else jr(Ll * pow((u - 0.55) / 0.45, 1.6))
	var heat := 0 if u < 0.55 else mini(2, int(floorf((u - 0.55) / 0.15)))
	var TIP := jr(w0 * 2.2)
	var B5 := [LPL[0], LPL[2], LPL[3], LPL[4], LPL[5]]
	var i := tail
	while i <= Ll + TIP:
		var tipk := 1.0 - (i - Ll) / TIP if i > Ll else 1.0
		var tailk := minf(1.0, (i - tail) / maxf(4.0, w0 * 1.5)) if tail > 0.0 else 1.0
		var base := sqrt(maxf(0.0, 1.0 - pow((w0 - i) / w0, 2.0))) * 0.35 + 0.65 if i < w0 else 1.0
		var w := maxf(0.5, w0 * tipk * tailk * base * (1.0 + 0.08 * sin(i * 0.35 - f * 1.3)))
		# a column, in colour runs
		var yy := -ceilf(w)
		while yy <= ceilf(w):
			var q := absf(yy) / w
			if q > 1.0:
				yy += 1.0
				continue
			var band := 0 if q < 0.28 else (1 if q < 0.55 else (2 if q < 0.82 else 3))
			var y2 := yy
			while y2 + 1.0 <= ceilf(w):
				var q2 := absf(y2 + 1.0) / w
				if q2 > 1.0: break
				var b2 := 0 if q2 < 0.28 else (1 if q2 < 0.55 else (2 if q2 < 0.82 else 3))
				if b2 != band: break
				y2 += 1.0
			p.rect(d * i, yy, 1, y2 - yy + 1.0, B5[mini(4, band + heat)])
			yy = y2 + 1.0
		i += 1.0
	if tail == 0.0:
		var R0 := jr(w0 * (1.15 + 0.1 * (f % 2)))
		p.disc(0, 0, R0, LPL[3]); p.disc(0, 0, jr(R0 * 0.7), LPL[2]); p.disc(0, 0, jr(R0 * 0.4), LPL[0])
	var tx := d * (Ll + TIP)
	var sL := 3.0 + (f % 2) * 2.0
	p.line(tx - sL, 0, tx + sL, 0, LPL[0])
	p.line(tx, -sL, tx, sL, LPL[0])
	for q in 10:
		var span := maxf(1.0, Ll - tail)
		var xx := tail + fmod(q * 137.0 + t * 0.8, span)
		var yy2 := fmod(q * 53.0, maxf(1.0, jr(w0 * 2.0))) - w0
		if xx + 12.0 > Ll: continue
		p.line(d * xx, yy2 * 0.7, d * (xx + 12.0 + q * 2.0), yy2 * 0.7, LPL[0] if heat < 1 else LPL[3])


# ---------- PERFECT DODGE afterimages (AFX echo / outline) ----------
## snapArt: the pose she has now, to be drawn later on the art grid
func snap_player() -> Variant:
	var P = arena.player
	if P == null: return null
	var an: String = P.anim
	var variant := ""
	if an == "tp_in" or an == "dig_out":
		variant = "_air" if P.dig_air else ("_q" if P.rift_q else "")
	var rf: Array = P.SK.resolve(P.who, an, P.f, variant)
	var row: int = rf[0]
	var sheet: Texture2D = P.SK.sheet_row(P.who, row)
	var sc: float = CH.SCALE[P.who] * (CH.ROWFIX_AIDA.get(row, 1.0) if P.who == "aida" else 1.0)
	return {"tex": sheet, "reg": Rect2(rf[1] * CH.CELL_W, (row % CH.ROWS_PER_SHEET) * CH.CELL_H, CH.CELL_W, CH.CELL_H),
		"w": P.CW * sc, "h": P.CHH * sc, "base": P.BASE * sc, "d": float(P.dir), "x": P.position.x, "y": P.position.y}

var afx_nodes: Array = []

func _afx_node(i: int) -> Node2D:
	while afx_nodes.size() <= i:
		var n := Node2D.new()
		n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var m := ShaderMaterial.new()
		m.shader = SH_AFX
		n.material = m
		var nn := n
		n.draw.connect(func(): nn.draw_rect(nn.get_meta("r"), Color.WHITE))
		n.set_meta("r", Rect2())
		add_child(n)
		move_child(n, 0)
		afx_nodes.append(n)
	return afx_nodes[i]

func _afx_set(n: Node2D, s: Dictionary, mode: int, tint: Color, keep: float, v: float) -> void:
	n.visible = true
	n.position = Vector2(jr(s["x"] / 2.0) * 2.0, jr(s["y"] / 2.0) * 2.0)
	var r := Rect2(-s["w"] / 2.0 - 12.0, -s["base"] - 44.0, s["w"] + 24.0, s["h"] + 48.0)
	if n.get_meta("r") != r:
		n.set_meta("r", r)
		n.queue_redraw()
	var m: ShaderMaterial = n.material
	m.set_shader_parameter("tex", s["tex"])
	var rg: Rect2 = s["reg"]
	m.set_shader_parameter("reg", Vector4(rg.position.x, rg.position.y, rg.size.x, rg.size.y))
	m.set_shader_parameter("tsz", Vector2(s["tex"].get_width(), s["tex"].get_height()))
	m.set_shader_parameter("geo", Vector4(s["w"], s["h"], s["base"], s["d"]))
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("keep", keep)
	m.set_shader_parameter("v", v)

## the path leaves A·echo copies (dithered cyan→violet); the spot she left keeps C·outline, a shell that breaks into rising pixels
func _afx_sync() -> void:
	var n := 0
	var P = arena.player
	for g in trail:
		var s: Dictionary = g["s"]
		if absf(s["x"] - P.position.x) <= 34.0: continue
		var u := minf(0.999, g["t"] / 620.0)
		var C := DODGE
		var col: Color = C[1] if u < 0.25 else (C[2] if u < 0.5 else (C[3] if u < 0.75 else C[4]))
		_afx_set(_afx_node(n), s, 0, col, 16.0 * (1.0 - u) * (1.0 - u) + 1.0, u)
		n += 1
	if ghost_i != null:
		var u2 := minf(0.999, ghost_i["t"] / 760.0)
		if u2 < 0.45: _afx_set(_afx_node(n), ghost_i["s"], 1, DODGE[0] if u2 < 0.2 else DODGE[1], 16.0, u2)
		else:
			var v := (u2 - 0.45) / 0.55
			_afx_set(_afx_node(n), ghost_i["s"], 2, DODGE[2] if v < 0.5 else DODGE[3], 16.0, v)
		n += 1
	for i in range(n, afx_nodes.size()):
		afx_nodes[i].visible = false

## drop every live effect (scene changes, tests)
func clear() -> void:
	for e in L: _kill(e)
	L.clear()
	for id in uq.keys(): _kill(uq[id])
	uq.clear()
	trail.clear()
	ghost_i = null
	pp = null
