extends Control
## On-screen controls for phones (prototype #padL / #padR / #bUlt in the hud3 look): a stick on the left half (follows the
## thumb, or fixed: settings), four glass circles on the right and the ULT tag above them.
## Each finger is tracked on its own, so moving and attacking at the same time works.
## Shown by the prototype's TOUCHUI rule (settings.gd touch_ui): on touch-first devices, or when forced in 설정;
## once a keyboard or mouse is used they hide until a real touch.
##
## Parity with the prototype (H3 CSS 8640-8669, SKICON 7041, switchChar 1422, interUI 3544, cooldown 3384):
## - labels show at first and fade out 6 s after the controls are first seen ('seen');
## - a pressed button turns white and shrinks to 0.88;
## - the skill button carries each member's own icon (sk_*_skill.png) and label (가드 / 균열 / 힐) and a cooldown sweep
##   (루체 heal_cd / 9000, 아이다 tp_cd / 3000);
## - the attack button turns the leader's colour and names what it will do near a door, a person or the fountain;
## - the ULT tag fills with 기력, turns white with a sweep shine and a wobble when ready, shows the seconds left while
##   cooling down, and fires the ultimate when tapped;
## - everything dims to half after 3 s without input (the ready ULT tag stays lit).
## The prototype's "town mode" (fewer buttons in town) is an empty rule in its final CSS: all four buttons stay in town.

const UI := preload("res://scripts/ui_kit.gd")
const CH := preload("res://scripts/chars.gd")
const DEAD := 18.0
const STICK_R := 60.0
## CSS layout of #padR (right 18, bottom 10): centre measured from the bottom-right corner, radius, icon size
const BTN := [
	{"a": "dash", "label": "대시", "c": Vector2(135, 119), "r": 31.0, "ic": 24.0},
	{"a": "guard", "label": "가드", "c": Vector2(55, 133), "r": 31.0, "ic": 34.0},
	{"a": "jump", "label": "점프", "c": Vector2(141, 43), "r": 31.0, "ic": 24.0},
	{"a": "attack", "label": "공격", "c": Vector2(58, 50), "r": 40.0, "ic": 32.0},
]
## #bUlt: right 18 + 64, bottom 10 + 178, 100 x 40, rotated -6deg
const ULT_C := Vector2(132, 208)
const ULT_W := 100.0
const ULT_H := 40.0
const SK_LBL := {"estelle": "가드", "aida": "균열", "luce": "힐"}
const SK_ICON := {"estelle": preload("res://assets/ui/icons/sk_est_skill.png"), "aida": preload("res://assets/ui/icons/sk_aida_skill.png"), "luce": preload("res://assets/ui/icons/sk_luce_skill.png")}
## SVG strokes on a 24 x 24 box (the prototype's button icons)
const ICON := {
	"dash": [[Vector2(5, 6), Vector2(11, 12), Vector2(5, 18)], [Vector2(12, 6), Vector2(18, 12), Vector2(12, 18)]],
	"jump": [[Vector2(12, 19), Vector2(12, 6)], [Vector2(6, 11), Vector2(12, 5), Vector2(18, 11)]],
	"attack": [[Vector2(4, 20), Vector2(13, 11)], [Vector2(13, 11), Vector2(18, 4), Vector2(20, 6), Vector2(13, 11)], [Vector2(6, 15), Vector2(9, 18)], [Vector2(3, 21), Vector2(5, 19)]],
}
const SEEN_MS := 6000.0
const IDLE_MS := 3000.0

var stick_id := -1
var stick_o := Vector2.ZERO
var stick_p := Vector2.ZERO
var held := {}            # finger index -> action
var shown := false
var arena
var seen_t := 0.0         # ms the controls have been on screen (labels fade at 6 s)
var lbl_a := 0.75         # label opacity (.75 -> 0 over .6 s once seen)
var idle_t := 0.0
var dim := 1.0            # 1 awake -> .5 idle (.6 s)
var press := {}           # action -> 0..1 (the .88 press, .12 s)
var clock := 0.0
var _sig := ""
var _last_ms := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false
	add_to_group("touch_controls")
	if OS.has_feature("web"):
		_js_cb = JavaScriptBridge.create_callback(func(a: Array): test_cmd(str(a[0]) if a.size() > 0 else ""))
		JavaScriptBridge.get_interface("window").cvaP1 = _js_cb

## web test hook for screenshots: window.cvaP1("touch") / ("ult <0..1> <cd ms>") / ("qte") / ("wall") / ("boss") / ("clear <ms>") / ("wagon")
var _js_cb
func test_cmd(cmd: String) -> void:
	var w := cmd.split(" ")
	var P = arena.player
	match w[0]:
		"touch":
			arena.cfg.dev = "touch"
		"ult":
			arena.ult.v[P.who] = arena.ult.ULTMAX[P.who] * float(w[1])
			arena.ult.cd[P.who] = float(w[2]) if w.size() > 2 else 0.0
		"qte":
			for c in ["aida", "luce"]:
				if not P.party.has(c): arena.toggle_member(c)
			if P.who == "estelle": P.switch_char("aida")
			arena.ult.v["luce"] = arena.ult.ULTMAX["luce"]
			P.qte["cd"] = 0.0
			P.qte_offer("hit", {"raw": 5.0, "taken": 5.0, "victim": P.who})
		"qtet":
			P.qte["t"] = P.QTE_T * float(w[1])
		"wall":
			var G: Dictionary = arena.runes.gear[P.who]
			G[G.keys()[0]] = {"rune": "wall", "g": "rare", "n": "철벽 테스트", "lv": 0}
			P.hp = P.MAX_HP * float(w[1]) if w.size() > 1 else P.MAX_HP * 0.4
		"boss":
			arena.enter_dungeon()
			var D = arena.level
			for k in D.rooms:
				if D.rooms[k]["type"] == "boss": D.cur = k
			D.from = "L"
			D.enter()
		"clear":
			var L = arena.runes.loot
			if L != null and is_instance_valid(L):
				L.t = float(w[1])
				L.hold = true
			if arena.fame != null and arena.fame.fx != null:
				arena.fame.fx.lv = {}           # no level-up cut over the shot
				arena.fame.fx.rk = {}
				arena.fame.fx.feed.clear()
		"go":
			var L2 = arena.runes.loot
			if L2 != null and is_instance_valid(L2): L2.hold = false
		"skip":
			if arena.sortie.tc.active: arena.sortie.tc.finish()
		"heal":
			P.heal_cd = float(w[1])
		"sw":
			P.switch_char(w[1])
		"train":
			arena.go_training()
		"wagon":
			P.position = Vector2(4820.0 + 287.0, arena.ground_y)
			arena.snap_camera()

func _on() -> bool:
	if not arena.cfg.touch_ui(): return false
	if arena.ui_root != null and arena.ui_root.holds(): return false
	if arena.dlg != null and arena.dlg.active: return false     # #wrap.talk hides the pads
	return true

func _process(delta: float) -> void:
	var on := _on()
	if on != shown:
		shown = on
		visible = on
		if not on: _release_all()
		queue_redraw()
	if not shown:
		_last_ms = 0
		return
	# UI timers run on wall time: slow frames must not stretch the 6 s / 3 s
	var now := Time.get_ticks_msec()
	step(clampf(float(now - _last_ms), 0.0, 1000.0) if _last_ms > 0 else delta * 1000.0)
	_last_ms = now
	# redraw only when something moved: phones
	var s := _state_sig()
	if s != _sig or _animating():
		_sig = s
		queue_redraw()

## timers: first-sight labels, idle dim, press scale (split out for the tests: headless frames are tiny)
func step(dt: float) -> void:
	clock += dt
	seen_t += dt
	idle_t += dt
	var la := 0.0 if seen_t >= SEEN_MS else 0.75
	lbl_a = move_toward(lbl_a, la, dt / 600.0 * 0.75)
	var dm := 0.5 if idle_t >= IDLE_MS else 1.0
	dim = move_toward(dim, dm, dt / 600.0 * 0.5)
	for b in BTN:
		var a: String = b["a"]
		var tgt := 1.0 if held.values().has(a) else 0.0
		press[a] = move_toward(press.get(a, 0.0), tgt, dt / 120.0)

func _animating() -> bool:
	if ult_ready(): return true
	if lbl_a > 0.0 and lbl_a < 0.75: return true
	if dim > 0.5 and dim < 1.0: return true
	for a in press:
		if press[a] > 0.0 and press[a] < 1.0: return true
	return false

func _state_sig() -> String:
	var P = arena.player
	var u := 0
	var cd := 0
	if arena.ult != null:
		u = int(arena.ult.frac() * 100.0)
		cd = ceili(arena.ult.cd[P.who] / 1000.0)
	return "%s|%d|%d|%d|%s|%s|%d" % [P.who, u, cd, int(skill_cd() * 50.0), inter_label(), str(held.values()), int(get_viewport_rect().size.x)]

func _release_all() -> void:
	for i in held:
		Input.action_release(held[i])
	held.clear()
	if stick_id >= 0:
		stick_id = -1
		_apply_stick()


# ---------- layout ----------
## the prototype's CSS pixels in this viewport's units: 1 on a desktop window; on a phone the prototype page is laid out
## 980 px wide and zoomed out (no viewport meta), which is a little larger than the 500-unit-tall view here
static func k_of(vp: Viewport) -> float:
	var win := Vector2(DisplayServer.window_get_size())
	var sc: float = maxf(1.0, DisplayServer.screen_get_scale())
	var css := win / sc
	if css.y <= 1.0: return 1.0
	var logical_per_css: float = vp.get_visible_rect().size.y / css.y
	return clampf(logical_per_css * minf(1.0, css.x / 980.0), 1.0, 1.3)

func K() -> float:
	return k_of(get_viewport())

func btn_center(b: Dictionary) -> Vector2:
	var s := get_viewport_rect().size
	return s - b["c"] * K()

func btn_r(b: Dictionary) -> float:
	return b["r"] * K()

func ult_center() -> Vector2:
	return get_viewport_rect().size - ULT_C * K()

## where the dash pips sit: a row centred just above the dash button (#dashui top -7)
static func pip_base(vp: Viewport) -> Vector2:
	var k := k_of(vp)
	var s := vp.get_visible_rect().size
	var c: Vector2 = s - BTN[0]["c"] * k
	return Vector2(c.x - 8.0, c.y - BTN[0]["r"] * k - 1.5 * k)

## where the stick rests (and stays, in fixed mode)
func _home() -> Vector2:
	var s := get_viewport_rect().size
	return Vector2(110.0, s.y - 110.0)


# ---------- state ----------
func ult_ready() -> bool:
	return arena.ult != null and arena.ult.ready_now()

## the skill button's cooldown sweep (draw() tail 3384)
func skill_cd() -> float:
	var P = arena.player
	if P.who == "luce": return clampf(maxf(0.0, P.heal_cd) / 9000.0, 0.0, 1.0)
	if P.who == "aida": return clampf(maxf(0.0, P.tp_cd) / 3000.0, 0.0, 1.0)
	return 0.0

## interUI: what the attack button says when it will interact ('' = attack)
func inter_label() -> String:
	var lk: String = arena.level_kind()
	var L = arena.level
	if lk == "town":
		var d = L.near_door
		if d == null: return ""
		match d.get("act", ""):
			"npc", "eilin": return "대화"
			"party": return "편성"
			"bran": return "대장간"
		var nm: String = d.get("name", "")
		if nm == "대장간": return "대장간"
		if nm == "출격 마차": return "출격"
		return "입장" if String(d.get("to", "")) != "" else "문"
	if lk == "hall":
		var d2 = L.near_door
		if d2 == null: return ""
		if d2.get("act", "") == "town": return "나가기"
		return String(d2.get("k", "문"))
	if lk == "dungeon":
		return "이동" if L.near_gate != null else ""
	if arena.get("near_entry") or arena.get("near_exit"): return "입장"
	return ""


# ---------- input ----------
func _hit_button(p: Vector2) -> Variant:
	var best = null
	var bd := 1e9
	for b in BTN:
		var d := p.distance_to(btn_center(b))
		if d < btn_r(b) + 12.0 and d < bd:
			bd = d
			best = b
	return best

func hit_ult(p: Vector2) -> bool:
	var q := (p - ult_center()).rotated(deg_to_rad(6.0)) / K()
	return absf(q.x) <= ULT_W / 2.0 + 8.0 and absf(q.y) <= ULT_H / 2.0 + 8.0

func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch or ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton:
		if ev.is_pressed() and idle_t > 0.0:
			idle_t = 0.0
			queue_redraw()
	if ev is InputEventScreenTouch:
		if not shown:
			return
		if ev.pressed:
			if hit_ult(ev.position):
				held[ev.index] = "ult"
				Input.action_press("ult")
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
			var b = _hit_button(ev.position)
			if b != null:
				held[ev.index] = b["a"]
				Input.action_press(b["a"])
				queue_redraw()
				return
			if ev.position.x < get_viewport_rect().size.x * 0.5 and stick_id < 0:
				stick_id = ev.index
				stick_o = ev.position if arena.cfg.stick == "float" else _home()
				stick_p = ev.position
				_apply_stick()
		else:
			if held.has(ev.index):
				var a: String = held[ev.index]
				held.erase(ev.index)
				if not held.values().has(a):
					Input.action_release(a)
			if ev.index == stick_id:
				stick_id = -1
				_apply_stick()
		queue_redraw()
	elif ev is InputEventScreenDrag and ev.index == stick_id:
		stick_p = ev.position
		var d := stick_p - stick_o
		if d.length() > STICK_R and arena.cfg.stick == "float":   # the base follows the thumb when it drags too far
			stick_o = stick_p - d.normalized() * STICK_R
		_apply_stick()
		queue_redraw()


func _apply_stick() -> void:
	var d := stick_p - stick_o if stick_id >= 0 else Vector2.ZERO
	set_act("left", d.x < -DEAD)
	set_act("right", d.x > DEAD)
	set_act("up", d.y < -DEAD * 1.6)
	set_act("down", d.y > DEAD * 1.6)


func set_act(a: String, on: bool) -> void:
	if on and not Input.is_action_pressed(a):
		Input.action_press(a)
	elif not on and Input.is_action_pressed(a):
		Input.action_release(a)


# ---------- drawing ----------
func _draw() -> void:
	if not shown:
		return
	var k := K()
	var P = arena.player
	var tc := UI.col(P.who)
	var inter := inter_label()
	for b in BTN:
		_draw_button(b, k, tc, inter, P.who)
	_draw_ult(k, tc)
	# stick
	if stick_id >= 0:
		draw_arc(stick_o, STICK_R, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(stick_o + (stick_p - stick_o).limit_length(STICK_R), 24.0, Color(1, 1, 1, 0.35))
	else:
		var a := (0.35 if arena.cfg.stick == "fixed" else 0.15) * dim
		draw_arc(_home(), STICK_R, 0, TAU, 40, Color(1, 1, 1, a), 2.0)
		draw_circle(_home(), 24.0, Color(1, 1, 1, a))

func _draw_button(b: Dictionary, k: float, tc: Color, inter: String, who: String) -> void:
	var a: String = b["a"]
	var c := btn_center(b)
	var pk: float = press.get(a, 0.0)
	var s := k * (1.0 - 0.12 * pk)
	var r: float = b["r"] * s
	var on := pk > 0.5
	var is_int := a == "attack" and inter != ""
	var al := dim
	# glass circle with a thin rim (H3); white when pressed; the leader's colour when it will interact
	var bg := Color(0, 0, 0, 0.35)
	if is_int: bg = tc
	if on: bg = Color.WHITE
	draw_circle(c, r, Color(bg, bg.a * al))
	draw_arc(c, r - 1.0 * s, 0, TAU, 48, Color(1, 1, 1, (1.0 if is_int else 0.75) * al), 2.0 * s, true)
	var fg := Color.BLACK if on else Color.WHITE
	# cooldown sweep on the skill button (inset -2px)
	if a == "guard":
		var cd := skill_cd()
		if cd > 0.001:
			var pts := PackedVector2Array([c])
			var n := maxi(3, int(40 * cd))
			for i in n + 1:
				var an := -PI / 2.0 + TAU * cd * i / n
				pts.append(c + Vector2(cos(an), sin(an)) * (r + 2.0 * s))
			draw_colored_polygon(pts, Color(0, 0, 0, 0.6 * al))
	# label: shown at first, gone once seen; always on the interacting attack button
	var lbl: String = SK_LBL.get(who, "가드") if a == "guard" else b["label"]
	var la := lbl_a
	if is_int:
		lbl = inter
		la = 1.0
		fg = Color.BLACK
	var fs := maxi(8, roundi(9.5 * s))
	var f := UI.spaced(UI.bhs(), 1)
	var lh := 13.0 * s
	if is_int:
		var w := UI.text_w(f, lbl, fs)
		draw_string(f, c + Vector2(-w / 2.0, fs * 0.36), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fg, la * al))
		return
	# icon over the label (flex column: icon, 1px gap, label)
	var ic: float = b["ic"] * s
	var gap := (1.0 - 3.0 if a == "guard" else 1.0) * s
	var top := c.y - (ic + gap + lh) / 2.0
	var icc := Vector2(c.x, top + ic / 2.0)
	if a == "guard":
		var tex: Texture2D = SK_ICON.get(who, SK_ICON["estelle"])
		draw_texture_rect(tex, Rect2(icc - Vector2(ic, ic) / 2.0, Vector2(ic, ic)), false, Color(1, 1, 1, al))
	else:
		var u := ic / 24.0
		for seg in ICON[a]:
			var pl := PackedVector2Array()
			for p in seg:
				pl.append(icc + (p - Vector2(12, 12)) * u)
			draw_polyline(pl, Color(fg, al), 2.0 * u, true)
	if la > 0.01:
		var w2 := UI.text_w(f, lbl, fs)
		draw_string(f, Vector2(c.x - w2 / 2.0, top + ic + gap + lh * 0.8), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(fg, la * al))

## the slanted ULT tag (H3 #bUlt: .ush / .ubd / .ul / .up / .ug / .usw, data-cd)
func _draw_ult(k: float, tc: Color) -> void:
	if arena.ult == null: return
	var P = arena.player
	var ready := ult_ready()
	var cdms: float = arena.ult.cd[P.who]
	var u: float = arena.ult.frac()
	var rot := deg_to_rad(-6.0)
	var sc := k
	var al := 1.0 if ready else dim
	if ready:
		# h3ulb .9s ease-in-out alternate: rotate -6 -> -8deg, scale 1 -> 1.06
		var ph := fmod(clock / 900.0, 2.0)
		var e := UI.bez(0.42, 0.0, 0.58, 1.0, ph if ph < 1.0 else 2.0 - ph)
		rot = deg_to_rad(-6.0 - 2.0 * e)
		sc = k * (1.0 + 0.06 * e)
	draw_set_transform(ult_center(), rot, Vector2(sc, sc))
	var hw := ULT_W / 2.0
	var hh := ULT_H / 2.0
	var poly := PackedVector2Array([Vector2(-hw + 10, -hh), Vector2(hw, -hh), Vector2(hw - 10, hh), Vector2(-hw, hh)])
	# shadow slab (black; the leader's colour when ready), then the body
	draw_colored_polygon(_shift(poly, Vector2(4, 4)), Color(tc if ready else Color.BLACK, al))
	draw_colored_polygon(poly, Color(1, 1, 1, al) if ready else Color(0, 0, 0, 0.6 * al))
	if not ready:
		# inset 2px rim (top and bottom survive the slanted clip)
		draw_colored_polygon(PackedVector2Array([Vector2(-hw + 10, -hh), Vector2(hw, -hh), Vector2(hw - 0.5, -hh + 2), Vector2(-hw + 9.5, -hh + 2)]), Color(1, 1, 1, 0.6 * al))
		draw_colored_polygon(PackedVector2Array([Vector2(-hw + 0.5, hh - 2), Vector2(hw - 9.5, hh - 2), Vector2(hw - 10, hh), Vector2(-hw, hh)]), Color(1, 1, 1, 0.6 * al))
	var txt := Color.BLACK if ready else Color.WHITE
	# ULT
	var fa := UI.anton(true, 1)
	var asc := fa.get_ascent(18)
	var dsc := fa.get_descent(18)
	var base := -hh + 3.0 + (21.6 - asc - dsc) / 2.0 + asc
	draw_string(fa, Vector2(-hw + 16, base), "ULT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(txt, al))
	# percent / MAX (eased like the HUD's 기력 number)
	var ush := u
	for n in get_parent().get_children():
		if n.has_method("_ult_show"):
			ush = n._ult_show()
			break
	var ps := "MAX" if ready else "%d%%" % int(floorf(minf(1.0, ush) * 100.0))
	var fp := UI.anton(true)
	var pw := UI.text_w(fp, ps, 11)
	draw_string(fp, Vector2(hw - 16 - pw, -hh + 7 + fp.get_ascent(11)), ps, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(txt, 0.8 * al))
	# gauge: skewed -30deg; fills with the leader's colour (black when ready, on an empty track)
	var gx0 := -hw + 12.0
	var gx1 := hw - 16.0
	var gy0 := hh - 6.0 - 5.0
	var gy1 := hh - 6.0
	if not ready:
		draw_colored_polygon(_skew(gx0, gx1, gy0, gy1), Color(1, 1, 1, 0.18 * al))
	var fw := (gx1 - gx0) * clampf(u, 0.0, 1.0)
	if fw > 0.2:
		draw_colored_polygon(_skew(gx0, gx0 + fw, gy0, gy1), Color(Color.BLACK if ready else tc, al))
	# sweep shine across the white tag (h3sweep 1.3s)
	if ready:
		var sp := fmod(clock / 1300.0, 1.0)
		var e2 := UI.bez(0.42, 0.0, 0.58, 1.0, sp)
		var bx := lerpf(-0.8, 0.8, e2) * ULT_W * 1.2
		_sweep(poly, bx)
	# cooldown seconds
	if cdms > 0.0:
		draw_colored_polygon(poly, Color(0, 0, 0, 0.55))
		var s := str(ceili(cdms / 1000.0))
		var f18 := UI.anton(true)
		var w := UI.text_w(f18, s, 18)
		draw_string(f18, Vector2(-w / 2.0, (f18.get_ascent(18) - f18.get_descent(18)) / 2.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_set_transform(Vector2.ZERO)

static func _shift(p: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in p: out.append(v + o)
	return out

## a rect sheared by skewX(-30deg) about its own centre
static func _skew(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	var t := tan(deg_to_rad(30.0))
	var yc := (y0 + y1) / 2.0
	var o: Array[Vector2] = [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]
	var out := PackedVector2Array()
	for p in o:
		out.append(Vector2(p.x - (p.y - yc) * t, p.y))
	return out

## a white band (105deg gradient: transparent 40% / white .9 50% / transparent 60%) clipped to the tag
func _sweep(poly: PackedVector2Array, bx: float) -> void:
	var dir := Vector2(cos(deg_to_rad(15.0)), sin(deg_to_rad(15.0)))   # across the band
	var half := ULT_W * 1.2 * 0.1
	for side in [-1.0, 1.0]:
		var a0 := Vector2(bx, 0)
		var a1: Vector2 = Vector2(bx, 0) + dir * half * float(side)
		var along := Vector2(-dir.y, dir.x) * 60.0
		var band := PackedVector2Array([a0 - along, a0 + along, a1 + along, a1 - along])
		for piece in Geometry2D.intersect_polygons(band, poly):
			var cols := PackedColorArray()
			for v in piece:
				var d := absf((v - Vector2(bx, 0)).dot(dir)) / half
				cols.append(Color(1, 1, 1, 0.9 * clampf(1.0 - d, 0.0, 1.0)))
			draw_polygon(piece, cols)
