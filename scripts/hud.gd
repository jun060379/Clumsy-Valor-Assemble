extends Control
## Screen HUD in the prototype's v3 language (hud3.js): the leader's standing art hugged by a crescent HP band with the
## 기력 arc outside it (bottom left), the location tag with an objective line (top left), the 피로도 chip (sortie.js #stm),
## the bench as round faces with ring HP (right; tap = switch, glowing = tag-in chance), dash pips, wave count,
## slow-motion frame, screen-centre words, and the dungeon's room banner, minimap, boss bar.

const CH = preload("res://scripts/chars.gd")
const UI := preload("res://scripts/ui_kit.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const A0 := PI * 1.18
const A1 := PI * 2.12
const RR := 86.0
const TMIN := 3.0
const TMAX := 17.0
const RU := RR + TMAX / 2.0 + 7.0
const PW := 150.0
const SKY := Color("#7ae0ff")
const ST := ["base", "sup", "cl"]

var arena
var faces := {}
var art := {}                    # c -> [base, sup (hurt), cl (blink)]
var slots: Array = []            # [{c, rect}]
var sil: Control
var front: Control
# portrait state (prototype PH)
var ph_ch := ""
var last_hp := 0.0
var hit_t := 0.0
var shk := 0.0
var pop := 0.0
var pant := 0.0
var ph := 0.0
var alpha := 1.0
var ghost := -1.0
var lf := -1.0
var gw := 0.0
var hf := 0.0
var bl_t := 2500.0
var jx := 0.0
var idle_t := 0.0                # ms since the last input (things dim after 3 s)
# objective line: shows on change, slides away after 4 s
var objective := ""
var obj_shown := ""
var obj_t := 99999.0
var clock := 0.0


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventJoypadButton:
		idle_t = 0.0
	if not _live():
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for sl in slots:
			if sl["rect"].grow(6).has_point(ev.position):
				arena.player.party_input(sl["c"])
				get_viewport().set_input_as_handled()
				return

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for c in ["estelle", "aida", "luce"]:
		faces[c] = load("res://assets/ui/faces/%s.png" % c)
		art[c] = ST.map(func(e): return load("res://assets/ui/st/%s_%s.webp" % [c, e]))
	sil = Control.new()
	sil.set_anchors_preset(Control.PRESET_FULL_RECT)
	sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sil.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sil.material = UI.solid_mat()
	sil.draw.connect(_draw_art.bind(true))
	add_child(sil)
	var fr := Control.new()
	fr.set_anchors_preset(Control.PRESET_FULL_RECT)
	fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fr.draw.connect(_draw_art.bind(false))
	add_child(fr)
	front = Control.new()
	front.set_anchors_preset(Control.PRESET_FULL_RECT)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	front.draw.connect(_draw_front)
	add_child(front)

## HUD shows in play: not under the title, a menu page or a talk box
func _live() -> bool:
	if arena.ui_root != null and (arena.ui_root.title.active or arena.ui_root.menu.is_open()):
		return false
	return not arena.dlg.active

func _process(delta: float) -> void:
	var dt := minf(delta * 1000.0, 50.0)
	clock += dt
	idle_t += dt
	obj_t += dt
	var P = arena.player
	if ph_ch != P.who:
		ph_ch = P.who
		last_hp = P.hp
		hit_t = 0.0
		shk = 0.0
		pop = 0.0
		ghost = -1.0
		lf = -1.0
	if P.hp < last_hp:
		hit_t = 1600.0
		shk = 1.0
		pop = 1100.0
	last_hp = P.hp
	hit_t = maxf(0.0, hit_t - dt)
	shk = maxf(0.0, shk - dt / 260.0)
	pop = maxf(0.0, pop - dt)
	var hurt: bool = P.hp <= P.MAX_HP * 0.35 or hit_t > 0.0
	pant += ((1.0 if hurt else 0.0) - pant) * minf(1.0, dt / 400.0)
	ph += dt / 1000.0 * TAU / (3.6 - 2.5 * pant)
	var f: float = clampf(maxf(0.0, P.hp) / P.MAX_HP, 0.0, 1.0)
	_ghost(f, dt)
	if arena.ult != null:
		u_show += (arena.ult.frac() - u_show) * minf(1.0, dt / 120.0)
	bl_t -= dt
	if bl_t < -130.0:
		bl_t = 260.0 if randf() < 0.2 else 2400.0 + randf() * 2800.0
	jx = (randf() - 0.5) * shk * 5.0
	_room_feed(dt)
	# fade the portrait when she walks behind it
	var vs := get_viewport_rect().size
	var sp: Vector2 = P.get_global_transform_with_canvas().origin
	var over: bool = sp.x < 300.0 and sp.y > vs.y - 230.0
	alpha += ((0.3 if over else 1.0) - alpha) * minf(1.0, dt / 160.0)
	# objective line
	var ob := _objective()
	if ob != obj_shown:
		obj_shown = ob
		obj_t = 0.0
	queue_redraw()
	sil.queue_redraw()
	get_child(1).queue_redraw()
	front.queue_redraw()

## prototype ghostOf: a white lag bar that holds a beat after a hit, then drains
func _ghost(f: float, dt: float) -> void:
	if ghost < 0.0 or f > ghost: ghost = f
	if lf >= 0.0 and f < lf - 0.0005:
		gw = 380.0
		hf = 90.0
	lf = f
	if gw > 0.0: gw -= dt
	else: ghost = maxf(f, ghost - dt / 700.0)
	if hf > 0.0: hf -= dt

## 기력 shown (eases toward the gauge, PH.uShow) and whether the ult is ready
var u_show := 0.0
func _ult_show() -> float:
	return u_show

func _ult_full() -> bool:
	return arena.ult != null and arena.ult.ready_now()

## what the objective line says: the cave's name and foes left, the training ground's ghost / dummies; town objectives come later
func _objective() -> String:
	if objective != "": return objective
	var lk: String = arena.level_kind()
	if lk == "dungeon":
		var n := 0
		for m in arena.mobs:
			if not m.is_dead(): n += 1
		return "버섯 동굴 · 남은 적 %d" % n
	if lk == "":
		return "유령 퇴치 0 / 1" if arena.ghost != null and arena.ghost.alive() else "허수아비 부수기"
	if arena.fame != null: return arena.fame.fame_obj()     # fameObj: letters, reports, the trial
	return ""

func _tc() -> Color:
	return UI.col(arena.player.who)


# ---------- crescent (under the art) ----------
static func _thk(a: float) -> float:
	return TMIN + (TMAX - TMIN) * clampf((0.4 - sin(a)) / 1.4, 0.0, 1.0)

static func _band(fe: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	fe = clampf(fe, 0.0, 1.0)
	if fe <= 0.0: return pts
	var n := maxi(6, roundi(36.0 * fe))
	for i in n + 1:
		var a := A0 + (A1 - A0) * fe * i / n
		pts.append(Vector2(cos(a), sin(a)) * (RR + _thk(a) / 2.0))
	for i in range(n, -1, -1):
		var a := A0 + (A1 - A0) * fe * i / n
		pts.append(Vector2(cos(a), sin(a)) * (RR - _thk(a) / 2.0))
	return pts

func _centre(vs: Vector2) -> Vector2:
	return Vector2(82.0 + jx, vs.y - 92.0)

func _draw() -> void:
	if not _live(): return
	var vs := get_viewport_rect().size
	var P = arena.player
	var c := _centre(vs)
	var a := alpha
	# 기력: thin outer arc with its own black shadow, filled to the gauge (white when ready)
	draw_arc(c + Vector2(4, 3), RU, A0, A1, 48, Color(0, 0, 0, a), 5.0)
	draw_arc(c, RU, A0, A1, 48, Color(0, 0, 0, 0.4 * a), 3.0)
	var uk := _ult_show()
	if uk > 0.002:
		draw_arc(c, RU, A0, A0 + (A1 - A0) * uk, maxi(4, int(48 * uk)), Color(Color.WHITE if _ult_full() else SKY, a), 3.0)
	# crescent: black shadow, track, white ghost, colour
	var full := _band(1.0)
	draw_colored_polygon(_off(full, c + Vector2(6, 5)), Color(0, 0, 0, a))
	draw_colored_polygon(_off(full, c), Color(0, 0, 0, 0.42 * a))
	var g := _band(ghost)
	if g.size() > 2: draw_colored_polygon(_off(g, c), Color(1, 1, 1, a))
	var f: float = maxf(0.0, P.hp) / P.MAX_HP
	var pf := _band(f)
	if pf.size() > 2:
		var low := f <= 0.3
		var col := Color.WHITE if hf > 0.0 else (Color("#e8243c") if low and sin(clock / 120.0) > 0.0 else _tc())
		draw_colored_polygon(_off(pf, c), Color(col, a))

static func _off(p: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p: out.append(v + o)
	return out

## standing art in front of the band, its solid black shadow 5 px to the right (sil = true draws the shadow)
func _draw_art(shadow: bool) -> void:
	if not _live(): return
	var ci: CanvasItem = sil if shadow else get_child(1)
	var vs := get_viewport_rect().size
	var P = arena.player
	var set_: Array = art[P.who]
	var hurt: bool = P.hp <= P.MAX_HP * 0.35 or hit_t > 0.0
	var blink := bl_t < 0.0
	var im: Texture2D = set_[2] if blink and not hurt else (set_[1] if hurt else set_[0])
	var b := sin(ph)
	var amp := 0.006 + 0.014 * pant
	var s := 1.0 + b * amp
	var bx := sin(ph * 0.5) * 0.6 if pant > 0.5 else 0.0
	var ih := PW * im.get_height() / im.get_width()
	var pb := vs.y + 34.0
	var r := Rect2(4.0 + bx + jx, pb - ih * s, PW, ih * s)
	if shadow:
		ci.draw_texture_rect(im, Rect2(r.position + Vector2(5, 0), r.size), false, Color(0, 0, 0, alpha))
	else:
		ci.draw_texture_rect(im, r, false, Color(1, 1, 1, alpha))


# ---------- everything over the art ----------
func _draw_front() -> void:
	var ci := front
	var vs := get_viewport_rect().size
	var lk: String = arena.level_kind()
	var live := _live()
	if live:
		_draw_portrait_top(ci, vs)
		_draw_loc(ci, vs)
		if lk == "town" or lk == "dungeon":
			_draw_fatigue(ci, Vector2(10, 60))
		_draw_party(ci, vs)
		_draw_pips(ci, vs)
	else:
		slots.clear()
	if lk == "dungeon":
		_draw_dungeon_ui(ci, vs, live)
	var fa: Font = arena.font_anton
	# slow motion: thin frame lines at the edge
	if arena.witch > 0.0:
		var k: float = minf(1.0, arena.witch / 300.0)
		ci.draw_rect(Rect2(14, 14, vs.x - 28, vs.y - 28), Color(0.67, 0.9, 1.0, 0.3 * k), false, 2.0)
	# screen words (WAVE n): slam in, hold, slide out
	for wd in arena.big_words:
		if not wd["screen"]:
			continue
		var u: float = wd["t"] / wd["life"]
		var a := 1.0 - maxf(0.0, (u - 0.7) / 0.3)
		var fs := 64
		var tw := fa.get_string_size(wd["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var slide := (1.0 - minf(1.0, u * 6.0)) * 120.0
		var pos := Vector2(vs.x / 2.0 - tw / 2.0 - slide, vs.y * 0.38)
		ci.draw_rect(Rect2(0, pos.y - 52, vs.x, 66), Color(0.05, 0.04, 0.07, 0.55 * a))
		ci.draw_string(fa, pos, wd["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(wd["col"], a))

## diamond caps, the name tag at the arc's end, HP number, 기력 line, skill readiness
func _draw_portrait_top(ci: CanvasItem, vs: Vector2) -> void:
	var P = arena.player
	var c := _centre(vs)
	var tc := _tc()
	var a := alpha
	for an in [A0, A1]:
		ci.draw_set_transform(c + Vector2(cos(an), sin(an)) * RR, PI / 4.0)
		ci.draw_rect(Rect2(-3, -3, 9, 9), Color(0, 0, 0, a))
		ci.draw_rect(Rect2(-4.5, -4.5, 9, 9), Color(1, 1, 1, a))
	var e := c + Vector2(cos(A1), sin(A1)) * RR + Vector2(12, 6)
	ci.draw_set_transform(e, -0.07)
	var bf := UI.bhs()
	var nm: String = CH.NAME[P.who]
	var nw := UI.text_w(bf, nm, 14) + 18.0
	ci.draw_rect(Rect2(3, -14, nw, 19), Color(tc, a))
	ci.draw_rect(Rect2(0, -17, nw, 19), Color(0, 0, 0, a))
	ci.draw_string(bf, Vector2(9, -3), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a))
	# HP number: pops on a hit
	var pk := pop / 1100.0 if pop > 0.0 else 0.0
	var ps := 1.0 + 1.3 * pk * pk
	var idle := idle_t > 3000.0 and pk <= 0.0
	var na := a * (0.65 if idle else 1.0)
	var fi := UI.anton(true)
	var cur := str(ceili(maxf(0.0, P.hp)))
	var xf := Transform2D(-0.07, e) * Transform2D(-0.12 * pk, Vector2(0, 22)) * Transform2D(0.0, Vector2(ps, ps), 0.0, Vector2.ZERO)
	ci.draw_set_transform_matrix(xf)
	var cw := UI.text_w(fi, cur, 18)
	if pk > 0.0:
		ci.draw_string(fi, Vector2(4, 4), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, na))
		ci.draw_string(fi, Vector2(2, 2), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(tc, na))
	else:
		ci.draw_string(fi, Vector2(2, 2), cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, na))
	ci.draw_string(fi, Vector2.ZERO, cur, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, na))
	ci.draw_string(fi, Vector2(cw + 2.0, 0), "/" + str(int(P.MAX_HP)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, na * 0.75))
	ci.draw_set_transform(e, -0.07)
	var us := "기력 MAX" if _ult_full() else "기력 %d%%" % int(floorf(_ult_show() * 100.0))
	if _ult_full() and not arena.cfg.touch_ui():
		us += "  [" + arena.cfg.key_name(int(arena.cfg.kb["ult"][0])) + "]"
	UI.shadow_text(ci, UI.anton(true), Vector2(0, 37), us, 11, Color(SKY, a))
	if P.who != "estelle":
		var cdv: float = P.heal_cd if P.who == "luce" else P.tp_cd
		var sk := "힐" if P.who == "luce" else "균열"
		var s := sk + (" %.1fs" % (cdv / 1000.0) if cdv > 0.0 else " 준비")
		ci.draw_string(UI.noto(), Vector2(nw + 8.0, -4.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, (0.55 if cdv > 0.0 else 1.0) * a))
	ci.draw_set_transform(Vector2.ZERO)

## location tag: name chip with a colour spine, the clock, the objective line under it
func _draw_loc(ci: CanvasItem, vs: Vector2) -> void:
	var lk: String = arena.level_kind()
	var nm := "훈련장"
	if lk == "town": nm = "길드 마을"
	elif lk == "dungeon": nm = "버섯 동굴"
	elif lk == "hall": nm = "길드 본관 · " + String(arena.HALL.HD.FLN[arena.level.fl])
	var hh := int(fposmod(arena.tod_h, 24.0))
	var mm := int(roundf((fposmod(arena.tod_h, 24.0) - hh) * 60.0)) % 60
	var tm := "%02d:%02d" % [hh, mm]
	var idle := idle_t > 3000.0
	var a := 0.5 if idle else 1.0
	ci.draw_set_transform(Vector2(12, 10), deg_to_rad(-2.0))
	var bf := UI.bhs()
	var w := UI.text_w(bf, nm, 14) + 20.0
	ci.draw_rect(Rect2(0, 0, w + 3.0, 21), Color(0, 0, 0, 0.6 * a))
	ci.draw_rect(Rect2(0, 0, 3, 21), Color(_tc(), a))
	ci.draw_string(bf, Vector2(13, 16), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, a))
	var fi := UI.anton(true, 1)
	ci.draw_string(fi, Vector2(w + 15.0, 18), tm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.85 * a))
	ci.draw_string(fi, Vector2(w + 13.0, 16), tm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85 * a))
	if obj_shown != "":
		var k := clampf((obj_t - 4000.0) / 500.0, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3)
		var oa := (1.0 - e) * a
		if oa > 0.0:
			var ox := -20.0 * e
			UI.shadow_text(ci, UI.noto(), Vector2(ox, 40), "▶ ", 11, Color(_tc(), oa))
			UI.shadow_text(ci, UI.noto(), Vector2(ox + UI.text_w(UI.noto(), "▶ ", 11), 40), obj_shown, 11, Color(1, 1, 1, oa))
	ci.draw_set_transform(Vector2.ZERO)

## 피로도 chip (sortie.js #stm)
var stm_last := -1
var stm_hit_t := 1e9               # stmHit: the chip jolts and flashes when fatigue is spent
var stm_drop := {}                 # segment -> ms since it emptied (stmDrop)
func _draw_fatigue(ci: CanvasItem, at: Vector2) -> void:
	var F = arena.fatigue
	var v: int = F.value()
	var now := Time.get_ticks_msec()
	if stm_last >= 0 and v < stm_last:
		stm_hit_t = now
		for i in range(roundi(float(F.MAX) / F.COST)):
			if v < (i + 1) * F.COST and stm_last > i * F.COST and v <= i * F.COST + F.COST: stm_drop[i] = now
	stm_last = v
	var ht := float(now - stm_hit_t)
	var jx: float = UIA.kf(ht, [[0.0, 6.0], [1.0, 0.0]], 500.0, 0.0, [0.2, 0.8, 0.3, 1.0]) if ht < 500.0 else 0.0
	at.x += jx
	var full: bool = v >= F.MAX
	var low: bool = v < F.COST
	var sc := Color("#ff3d5a") if low else Color("#5fd4ff")
	var fa := UI.anton()
	var fk := UI.spaced(UI.noto_k(), 1)
	var h := 36.0
	# measure: 13 | hd | 10 | nm | 10 | sg | 10 | nx | 22
	var hd_w := maxf(UI.text_w(fk, "피로도", 11), UI.text_w(UI.anton(false, 3), "FATIGUE", 8))
	var num := str(v)
	var nmw := maxf(UI.text_w(fa, num, 24), UI.text_w(fa, "000", 24) * 0.7)
	var den := "/" + str(F.MAX)
	var nm_w := nmw + 2.0 + UI.text_w(fa, den, 11)
	var n := roundi(float(F.MAX) / F.COST)
	var sg_w := n * 17.0 + (n - 1) * 3.0
	var nx := "가득" if full else "%d분 뒤" % ceili(F.next_ms() / 60000.0)
	var nx_w := UI.text_w(UI.noto(), nx, 10) + (0.0 if full else UI.text_w(fa, "+1", 11) + 3.0)
	var w := 13.0 + hd_w + 10.0 + nm_w + 10.0 + sg_w + 10.0 + nx_w + 22.0
	var r := Rect2(at, Vector2(w, h))
	var poly := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x - 11.0, r.end.y), Vector2(r.position.x, r.end.y)])
	var bg0 := Color(13 / 255.0, 11 / 255.0, 16 / 255.0, 0.9)
	var bg1 := Color(13 / 255.0, 11 / 255.0, 16 / 255.0, 0.72)
	ci.draw_polygon(poly, PackedColorArray([bg0, bg1, bg1, bg0]))
	if ht < 500.0:
		var fl: float = UIA.kf(ht, [[0.0, 1.0], [0.25, 0.55], [1.0, 0.0]], 500.0, 0.0, [0.2, 0.8, 0.3, 1.0])
		ci.draw_colored_polygon(poly, Color(1, 1, 1, fl))
	var ba := 1.0
	if low: ba = 0.25 + 0.75 * (0.5 + 0.5 * cos(clock / 1100.0 * TAU))
	ci.draw_rect(Rect2(r.position.x, r.position.y, 6, h), Color(sc, 0.25 * ba))
	ci.draw_rect(Rect2(r.position.x, r.position.y, 3, h), Color(sc, ba))
	var x := r.position.x + 13.0
	var my := r.position.y + h / 2.0
	ci.draw_string(fk, Vector2(x, my - 1.0), "피로도", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	ci.draw_string(UI.anton(false, 3), Vector2(x, my + 10.0), "FATIGUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, sc)
	x += hd_w + 10.0
	# number, skewed
	ci.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-tan(deg_to_rad(9.0)), 1), Vector2(x, my + 9.0)) * Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(0, 0)))
	ci.draw_string(fa, Vector2(nmw - UI.text_w(fa, num, 24), 0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#ff5a72") if low else Color.WHITE)
	ci.draw_string(fa, Vector2(nmw + 2.0, 0), den, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))
	ci.draw_set_transform(Vector2.ZERO)
	x += nm_w + 10.0
	# four segments
	var sk := tan(deg_to_rad(24.0)) * 9.0
	for i in n:
		var fr := clampf(float(v - i * F.COST) / F.COST, 0.0, 1.0)
		var sx := x + i * 20.0
		var dk := float(now - int(stm_drop.get(i, -100000)))
		var sa := 0.13 + 0.87 * (1.0 - UIA.p(dk, 0.0, 600.0, "ease-out")) if dk < 600.0 else 0.13
		UI.para(ci, sx, my - 4.5, 17.0, 9.0, sk, Color(1, 1, 1, sa))
		if fr > 0.0:
			UI.para(ci, sx, my - 4.5, 17.0 * fr, 9.0, sk, sc)
			if fr >= 1.0:
				UI.para(ci, sx + sk * (1.0 - 0.18), my - 4.5, 17.0, 9.0 * 0.18, sk * 0.18, Color.WHITE)
	x += sg_w + 10.0
	if full:
		ci.draw_string(UI.noto(), Vector2(x, my + 4.0), nx, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))
	else:
		ci.draw_string(fa, Vector2(x, my + 5.0), "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, sc)
		ci.draw_string(UI.noto(), Vector2(x + UI.text_w(fa, "+1", 11) + 3.0, my + 4.0), nx, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))

## the bench, right edge: round faces with ring HP; swap cooldown sweep; a tag-in chance grows the face and glows
func _draw_party(ci: CanvasItem, vs: Vector2) -> void:
	slots.clear()
	var P = arena.player
	var bench: Array = P.party.filter(func(c): return c != P.who)
	var y := 50.0
	var idle := idle_t > 3000.0
	for c in bench:
		var r := Rect2(vs.x - 10.0 - 48.0, y, 48.0, 48.0)
		slots.append({"c": c, "rect": r})
		var col := UI.col(c)
		var on: bool = P.qte["t"] > 0.0 and P.qte["who"].has(c)
		var down: bool = P.hpm[c] <= 0.0
		var a := 1.0 if on or not idle else 0.55
		var ctr := r.get_center()
		var R := 24.0 * (1.12 if on else 1.0)
		var hk: float = clampf(P.hpm[c] / (arena.runes.max_hp(c) if arena.get("runes") != null else CH.STATS[c]["hp"]), 0.0, 1.0)
		ci.draw_circle(ctr, R, Color(0, 0, 0, 0.55 * a))
		if hk > 0.0:
			var pts := PackedVector2Array([ctr])
			var nseg := maxi(2, int(40 * hk))
			for i in nseg + 1:
				var an := -PI / 2.0 + TAU * hk * i / nseg
				pts.append(ctr + Vector2(cos(an), sin(an)) * R)
			ci.draw_colored_polygon(pts, Color(col, a))
		ci.draw_circle(ctr, R - 4.0 + 2.0, Color(0, 0, 0, a))
		_face(ci, faces[c], ctr, R - 4.0, Color(0.35, 0.35, 0.35, a) if down else Color(1, 1, 1, a))
		if P.swap_cd > 0.0 and not down and not on:
			var k: float = clampf(P.swap_cd / 2200.0, 0.0, 1.0)
			var pts2 := PackedVector2Array([ctr])
			for i in 33:
				var an2 := -PI / 2.0 + TAU * k * i / 32.0
				pts2.append(ctr + Vector2(cos(an2), sin(an2)) * (R - 4.0))
			ci.draw_colored_polygon(pts2, Color(10 / 255.0, 8 / 255.0, 16 / 255.0, 0.72 * a))
		if on:
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0)
			ci.draw_arc(ctr, R + 3.0, 0, TAU, 40, Color(1, 1, 1, 0.6 + 0.4 * pulse), 3.0, true)
			ci.draw_arc(ctr, R + 8.0, -PI / 2.0, -PI / 2.0 + TAU * P.qte["t"] / P.QTE_T, 40, Color.WHITE, 2.0, true)
			var lbl: String = CH.QTE_LBL[c]
			var lw := UI.text_w(UI.bhs(), lbl, 16) + 18.0
			ci.draw_set_transform(Vector2(r.position.x - lw - 6.0, ctr.y), deg_to_rad(-6.0))
			UI.para(ci, 4, -10, lw, 22, 4.0, col)
			UI.para(ci, 0, -13, lw, 22, 4.0, Color.BLACK)
			ci.draw_string(UI.bhs(), Vector2(9, 4), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			ci.draw_set_transform(Vector2.ZERO)
		else:
			var nm: String = CH.NAME[c]
			var nw := UI.text_w(UI.bhs(), nm, 11)
			UI.shadow_text(ci, UI.bhs(), Vector2(r.position.x - 6.0 - nw, ctr.y + 4.0), nm, 11, Color(1, 1, 1, a))
		y += 64.0

## a texture clipped to a circle (polygon with UVs)
func _face(ci: CanvasItem, tex: Texture2D, c: Vector2, r: float, mod: Color) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 32:
		var an := TAU * i / 32.0
		var d := Vector2(cos(an), sin(an))
		pts.append(c + d * r)
		uvs.append(Vector2(0.5, 0.5) + d * 0.5)
	ci.draw_polygon(pts, PackedColorArray([mod]), uvs, tex)

## dash charges: two small diamonds, bottom right (above the dash button on touch screens)
func _draw_pips(ci: CanvasItem, vs: Vector2) -> void:
	var P = arena.player
	var base := Vector2(vs.x - 30.0, vs.y - 22.0)
	if arena.cfg.touch_ui():
		base = Vector2(vs.x - 206.0 - 8.0, vs.y - 158.0 - 40.0)
	for i in 2:
		var c := base + Vector2(i * 14.0, 0)
		var full: bool = i < P.charges
		var k: float = 1.0 if full else (clampf(P.recharge / 1300.0, 0.0, 1.0) if i == P.charges else 0.0)
		ci.draw_set_transform(c, PI / 4.0)
		ci.draw_rect(Rect2(-4.5, -4.5, 9, 9), Color(14 / 255.0, 11 / 255.0, 20 / 255.0, 0.85))
		ci.draw_rect(Rect2(-4.5, -4.5, 9, 9), Color(0.95, 0.87, 0.68, 0.85), false, 1.0)
		if k > 0.0:
			ci.draw_rect(Rect2(-3.5 * k, -3.5 * k, 7 * k, 7 * k), Color("#e8cf98"))
		ci.draw_set_transform(Vector2.ZERO)


## dungeon: room banner, minimap, boss bar, shilling
func _draw_dungeon_ui(ci: CanvasItem, vs: Vector2, live: bool) -> void:
	var D = arena.level
	var fb: Font = arena.font_black
	if D.msg_t > 0.0 and (arena.fame == null or arena.fame.fx == null):
		# (the feed below normally carries the room names: HUD v3 replaced this banner with one notice line)
		var a := minf(1.0, D.msg_t / 400.0) * minf(1.0, (2600.0 - D.msg_t) / 200.0 + 0.3)
		var tw := fb.get_string_size(D.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var y := vs.y * 0.24
		ci.draw_rect(Rect2(vs.x / 2.0 - tw / 2.0 - 30.0, y - 28.0, tw + 60.0, 40.0), Color(0.04, 0.03, 0.06, 0.7 * a))
		ci.draw_rect(Rect2(vs.x / 2.0 - tw / 2.0 - 30.0, y - 28.0, 4.0, 40.0), Color(1, 0.83, 0.3, a))
		ci.draw_string(fb, Vector2(vs.x / 2.0 - tw / 2.0, y), D.msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.95, 0.85, a))
	if not live:
		return
	# minimap, under the top-right buttons, left of the bench
	var R: Dictionary = D.rooms
	var seen: Array = R.values().filter(func(r): return r["seen"])
	if not seen.is_empty():
		var gx0: int = seen.map(func(r): return r["x"]).min()
		var gx1: int = seen.map(func(r): return r["x"]).max()
		var gy0: int = seen.map(func(r): return r["y"]).min()
		var gy1: int = seen.map(func(r): return r["y"]).max()
		var cw := 24.0
		var chh := 15.0
		var gap := 5.0
		var bw := (gx1 - gx0 + 1) * (cw + gap) + 8.0
		var bh := (gy1 - gy0 + 1) * (chh + gap) + 8.0
		var x0 := vs.x - 96.0 - bw
		var y0 := 58.0
		ci.draw_rect(Rect2(x0 - 6.0, y0 - 6.0, bw, bh), Color(0.04, 0.03, 0.06, 0.55))
		ci.draw_rect(Rect2(x0 - 6.0, y0 - 6.0, bw, bh), Color(0.91, 0.83, 0.63, 0.35), false, 1.0)
		for r in seen:
			var px: float = x0 + (r["x"] - gx0) * (cw + gap)
			var py: float = y0 + (r["y"] - gy0) * (chh + gap)
			for d in ["R", "D"]:
				if r["doors"].has(d):
					var nb = R.get(D.rkey(r["x"] + D.DIRS[d][0], r["y"] + D.DIRS[d][1]))
					if nb != null and (r["visited"] or nb["visited"]):
						if d == "R": ci.draw_line(Vector2(px + cw, py + chh / 2.0), Vector2(px + cw + gap, py + chh / 2.0), Color(0.91, 0.83, 0.63, 0.5), 2.0)
						else: ci.draw_line(Vector2(px + cw / 2.0, py + chh), Vector2(px + cw / 2.0, py + chh + gap), Color(0.91, 0.83, 0.63, 0.5), 2.0)
		for r in seen:
			var px2: float = x0 + (r["x"] - gx0) * (cw + gap)
			var py2: float = y0 + (r["y"] - gy0) * (chh + gap)
			var col := Color("#f3dfae") if r["k"] == D.cur else (Color(0.63, 0.57, 0.7, 0.85) if r["visited"] else Color(0.27, 0.24, 0.33, 0.8))
			ci.draw_rect(Rect2(px2, py2, cw, chh), col)
			var ic = {"boss": Color("#ff5a6a"), "camp": Color("#ffa04a"), "vault": Color("#ffd34d"), "start": Color("#9fe3a0")}.get(r["type"])
			if ic != null and (r["visited"] or r["type"] == "boss"):
				ci.draw_circle(Vector2(px2 + cw / 2.0, py2 + chh / 2.0), 3.5, ic)
			if r["visited"] and r["type"] == "fight" and not r["cleared"]:
				ci.draw_rect(Rect2(px2 + cw / 2.0 - 2.0, py2 + chh / 2.0 - 2.0, 4, 4), Color("#ff6f6f"))
	# boss (HUD v3 H2.boss): a WARNING slam the first time, then a slim quiet bar across the top
	for m in arena.mobs:
		if m.M.has("boss") and not m.is_dead() and m.spawn_t <= 0.0:
			_draw_boss(ci, vs, m)
			break
	# shilling, under the fatigue chip
	UI.shadow_text(ci, arena.font_bold, Vector2(14, 116), "실링 %d" % arena.shilling, 12, Color("#ffd34d"))


## H2.boss + ghostOf: the hp trail lags white behind the bar and the bar flashes white on a hit
var boss_st := {}
func _draw_boss(ci: CanvasItem, vs: Vector2, b) -> void:
	var id: int = b.get_instance_id()
	if not boss_st.has(id): boss_st = {id: {"g": -1.0, "lf": -1.0, "gw": 0.0, "hf": 0.0, "slam": clock, "last": clock}}
	var S: Dictionary = boss_st[id]
	var dt: float = clampf(clock - S["last"], 0.0, 100.0)
	S["last"] = clock
	var f: float = clampf(b.hp / b.max_hp, 0.0, 1.0)
	if S["g"] < 0.0 or f > S["g"]: S["g"] = f
	if S["lf"] >= 0.0 and f < S["lf"] - 0.0005:
		S["gw"] = 380.0
		S["hf"] = 90.0
	S["lf"] = f
	if S["gw"] > 0.0: S["gw"] -= dt
	else: S["g"] = maxf(f, S["g"] - dt / 700.0)
	if S["hf"] > 0.0: S["hf"] -= dt
	var g: float = S["g"]
	var age: float = clock - S["slam"]
	var nm: String = b.M["name"]
	var bhs := UI.bhs()
	var W := vs.x
	if age < 1900.0:
		var k := age / 1900.0
		var in_k := minf(1.0, k / 0.18)
		var out_k := (k - 0.78) / 0.22 if k > 0.78 else 0.0
		var e := 1.0 - pow(1.0 - in_k, 3.0)
		var base := Transform2D(-0.07, Vector2(W / 2.0, vs.y * 0.4))
		ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2((1.0 - e) * W * 1.1 - out_k * W * 1.1, 0)))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-W * 0.7, -30), Vector2(W * 0.7, -46), Vector2(W * 0.7, 30), Vector2(-W * 0.7, 46)]), Color("#e8243c"))
		ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(-(1.0 - e) * W * 1.1 + out_k * W * 1.1, 0)))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-W * 0.7, -30), Vector2(W * 0.7, -36), Vector2(W * 0.7, 32), Vector2(-W * 0.7, 36)]), Color.BLACK)
		var ta := minf(1.0, in_k * 1.4) * (1.0 - out_k)
		var sc := 1.0 + (1.0 - in_k) * 0.8
		var tb := base * Transform2D(0.0, Vector2(sc, sc), 0.0, Vector2.ZERO)
		ci.draw_set_transform_matrix(tb)
		var wf := UI.anton(true)
		var wt := "W A R N I N G"
		ci.draw_string(wf, Vector2(-UI.text_w(wf, wt, 13) / 2.0, -14), wt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e8243c", ta))
		var K := [[Color.WHITE, Color.BLACK], [Color.BLACK, Color.WHITE], [Color("#e8243c"), Color.BLACK]]
		var cws: Array = []
		var tw := 0.0
		for c in nm:
			var cw: float = 12.0 if c == " " else UI.text_w(bhs, c, 28) + 8.0
			cws.append(cw)
			tw += cw + 2.0
		var px2 := -tw / 2.0
		for i in nm.length():
			var c := nm[i]
			var w: float = cws[i]
			if c != " ":
				var r := (((i * 7919) % 13) - 6) * 0.02
				ci.draw_set_transform_matrix(tb * Transform2D(r, Vector2(px2 + w / 2.0, 10)))
				ci.draw_rect(Rect2(-w / 2.0 + 3.0, -24, w, 32), Color(0, 0, 0, ta))
				ci.draw_rect(Rect2(-w / 2.0, -27, w, 32), Color(K[i % 3][0], ta))
				ci.draw_string(bhs, Vector2(-UI.text_w(bhs, c, 28) / 2.0, 0), c, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(K[i % 3][1], ta))
			px2 += w + 2.0
		ci.draw_set_transform(Vector2.ZERO)
	var ba := clampf((age - 1500.0) / 400.0, 0.0, 1.0)
	if ba <= 0.0: return
	var bw := minf(420.0, W * 0.46)
	var x := (W - bw) / 2.0
	# keep clear of the top-right buttons (a narrow phone screen would run it under them)
	var tbl := W
	if arena.ui_root != null:
		for r in arena.ui_root.menu.tb_rects.values(): tbl = minf(tbl, r.position.x)
	if x + bw > tbl - 16.0:
		x = maxf(150.0, tbl - 16.0 - bw)
		bw = minf(bw, tbl - 16.0 - x)
	var y := 30.0
	ci.draw_string(bhs, Vector2(x + 1, y + 1), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, ba))
	ci.draw_string(bhs, Vector2(x, y), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, ba))
	var nw := UI.text_w(bhs, nm, 14)
	ci.draw_string(UI.anton(), Vector2(x + nw + 8.0, y), "B O S S", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, ba * 0.7))
	if b.phase == 1:
		ci.draw_set_transform_matrix(Transform2D(-0.14, Vector2(x + nw + 56.0, y - 5.0)))
		ci.draw_rect(Rect2(-2, -8, 40, 13), Color("#e8243c", ba))
		ci.draw_string(UI.anton(), Vector2(4, 2), "RAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, ba))
		ci.draw_set_transform(Vector2.ZERO)
	var pf := UI.anton(true)
	var pct := "%d%%" % ceili(f * 100.0)
	var pw := UI.text_w(pf, pct, 15)
	ci.draw_string(pf, Vector2(x + bw - pw + 1, y + 1), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, ba))
	ci.draw_string(pf, Vector2(x + bw - pw, y), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1, 1, 1, ba))
	var sk := 3.0
	var by := y + 5.0
	var bh := 7.0
	var pg := func(x0: float, w0: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(x0 + sk, by), Vector2(x0 + w0 + sk, by), Vector2(x0 + w0, by + bh), Vector2(x0, by + bh)])
	ci.draw_colored_polygon(pg.call(x - 2.0, bw + 4.0), Color(0, 0, 0, 0.6 * ba))
	if g > 0.0: ci.draw_colored_polygon(pg.call(x, bw * g), Color(1, 1, 1, ba))
	if f > 0.0: ci.draw_colored_polygon(pg.call(x, bw * f), Color(1, 1, 1, ba) if S["hf"] > 0.0 else Color("#e8243c", ba))


## HUD v3: room names go to the notice feed (H2.room), and the objective — "남은 적 N" on entering a room with
## enemies, "방 정리 완료" when the last one falls
var feed_msg_t := 0.0
var feed_room := ""
var feed_left := -1
var feed_later := -1.0
var feed_n := 0
func _room_feed(dt: float) -> void:
	var F = arena.fame
	if arena.level_kind() != "dungeon" or F == null:
		feed_room = ""
		feed_left = -1
		feed_msg_t = 0.0
		return
	var S = arena.sortie
	if (S != null and (S.covers() or S.last_cur != arena.level.cur)) or (arena.ui_root != null and arena.ui_root.holds()) or arena.fade > 0.05:
		return          # under a title card / the clear screen / a menu: the feed waits (the room clock waits too)
	var D = arena.level
	if D.msg_t > feed_msg_t + 50.0 and D.msg != "":
		F.notice(D.msg, "AREA", _tc(), true, 3000.0)
	feed_msg_t = D.msg_t
	var rk: String = D.cur
	var left: int = arena.mobs.filter(func(m): return not m.is_dead()).size()
	if rk != feed_room:
		feed_room = rk
		feed_left = left
		if left > 0:
			feed_later = 260.0
			feed_n = left
	elif left == 0 and feed_left > 0:
		feed_left = 0
		F.notice("방 정리 완료", "CLEAR", Color("#7ae0ff"))
	else:
		feed_left = left
	if feed_later > 0.0:
		feed_later -= dt
		if feed_later <= 0.0: F.notice("남은 적 %d" % feed_n, "", Color("#e8243c"), false, 2700.0)
