extends Control
## Dungeon clear screen (sortie.js clearFx, #lootres.cl2): the member's colour with spinning rays and dots, a black slab,
## a white slash, a huge hollow CLEAR; the leader's ult splash art slides in on the left; on the right "던전 클리어",
## the dungeon · boss line, the chest-grade stamp, the REWARDS tiles, an info panel, the tally tokens (실링 · 기억석 ·
## 룬 · 장비, numbers rolling up) and "마을로 돌아가기", which plays the leave animation and the RETURN sweep.
## The rewards come from the inventory system when it is there (see run_loot below); otherwise only the shillings
## picked up during this sortie are counted.

const UI := preload("res://scripts/ui_kit.gd")
const SK := preload("res://scripts/skins.gd")       # member art through the worn costume
const CGN := ["커먼", "레어", "에픽", "유니크", "레전더리"]
const CGC := [Color("#d8d0bf"), Color("#5fa8ff"), Color("#b46cff"), Color("#ff8a3d"), Color("#ffe066")]
const SHC := Color("#ffd34d")
const MEMC := Color("#8ff0e0")
const EZ := [0.2, 0.9, 0.25, 1.0]
const BK := [0.2, 1.5, 0.4, 1.0]
const IN := [0.6, 0.0, 0.9, 0.4]

var arena
var sortie
var open := false
var t := 0.0
var out_t := -1.0                # leave animation clock
var loot := {}
var sel := -1
var info_t := 9999.0
var r_go := Rect2()
var r_tiles: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false

## lootList and friends. With the inventory system present: inventory.run_loot() -> {items: [{n, g (grade 0-4), k}], sh, mem, runes, gear, grade}
func _gather() -> Dictionary:
	var L := {"items": [], "sh": maxi(0, arena.shilling - sortie.sh_start), "mem": 0, "runes": 0, "gear": 0, "grade": 0}
	var inv = arena.get("inventory")
	if inv != null and inv.has_method("run_loot"):
		var r = inv.run_loot()
		if r is Dictionary:
			for k in r: L[k] = r[k]
	return L

func show_it() -> void:
	if open: return
	loot = _gather()
	open = true
	visible = true
	t = 0.0
	out_t = -1.0
	sel = -1
	info_t = 9999.0
	for a in ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "ult", "swap"]:
		if InputMap.has_action(a): Input.action_release(a)
	arena.sfx("ui_ok", 0.9)

## the go button: art and panel leave, the slab swings away, then the RETURN sweep; the page goes once it is covered
func leave() -> void:
	if out_t >= 0.0: return
	out_t = 0.0
	arena.sfx("ui_back", 0.5)


func _input(ev: InputEvent) -> void:
	if not open: return
	var handled := ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton or ev is InputEventScreenTouch
	if out_t < 0.0:
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
			leave()
		elif ev is InputEventJoypadButton and ev.pressed and ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_B]:
			leave()
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if r_go.grow(4).has_point(ev.position): leave()
			for i in r_tiles.size():
				if r_tiles[i].has_point(ev.position):
					sel = i
					info_t = 0.0
	if handled: get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not open: return
	var dt: float = minf(delta * 1000.0, 100.0) * sortie.speed
	var was := t
	t += dt
	info_t += dt
	if was < 560.0 and t >= 560.0: arena.sfx("slam", 0.7)
	if was < 1000.0 and t >= 1000.0: arena.sfx("hit", 0.6)
	var n: int = loot["items"].size()
	for i in n:
		var at := 900.0 + i * 85.0 + 200.0
		if was < at and t >= at: arena.sfx("ui_move", 0.3 + minf(0.2, i * 0.02))
	if out_t >= 0.0:
		var w := out_t
		out_t += dt
		if w < 220.0 and out_t >= 220.0:
			sortie.go_town()
		if out_t >= 220.0 + 600.0:
			open = false
			visible = false
	queue_redraw()
	_sil_node.queue_redraw()
	_front.queue_redraw()


static func _e(c: Array, u: float) -> float:
	return UI.bez(c[0], c[1], c[2], c[3], clampf(u, 0.0, 1.0))

func _draw() -> void:
	if not open: return
	var vs := get_viewport_rect().size
	var P = arena.player
	var pc := UI.col(P.who)
	var tt := Time.get_ticks_msec() / 1000.0
	var xk := 0.0
	xk = _xk()
	# background
	var bga := clampf(t / 180.0, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, vs), Color(pc, bga))
	var rk := _e(EZ, t / 900.0)
	UI.burst(self, Vector2(vs.x * 0.24, vs.y * 0.58), maxf(vs.x, vs.y) * 1.6 * (0.6 + 0.4 * rk), 0.1 * rk, tt * TAU / 80.0)
	UI.dots(self, Rect2(-22, -22, vs.x + 44, vs.y + 44), 0.24, 1.0, Vector2(fposmod(tt * 11.0 / 9.0, 11.0), fposmod(tt * 11.0 / 9.0, 11.0)))
	# slab
	var sk := _e(EZ, (t - 40.0) / 520.0)
	var sx := vs.x * (0.70 * (1.0 - sk) + 0.80 * xk) + sin(tt * TAU / 8.0) * -5.0 - 5.0
	var srot := deg_to_rad(lerpf(24.0, 10.0, sk) + 14.0 * xk)
	var slab := Rect2(vs.x * (1.16 - 0.66), -vs.y * 0.25, vs.x * 0.66, vs.y * 1.6)
	var piv := slab.get_center()
	var pts := UI.rot(PackedVector2Array([slab.position, Vector2(slab.end.x, slab.position.y), slab.end, Vector2(slab.position.x, slab.end.y)]), piv, srot)
	for i in pts.size(): pts[i].x += sx
	draw_colored_polygon(pts, Color.BLACK)
	# slash
	var lk := _e(EZ, (t - 220.0) / 420.0)
	if lk > 0.0:
		draw_set_transform(Vector2(-0.1 * vs.x, vs.y * 0.76), deg_to_rad(-8.0))
		draw_rect(Rect2(0, -4.5, vs.x * 0.72 * lk, 9), Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	# CLEAR
	var bk := _e(EZ, (t - 200.0) / 900.0)
	if bk > 0.0:
		var fa := UI.anton()
		var fs := int(minf(vs.x * 0.3, 300.0))
		var w := UI.text_w(fa, "CLEAR", fs)
		draw_set_transform(Vector2(vs.x * 1.03 - w + w * 0.3 * (1.0 - bk), vs.y * 1.09 - fs * 0.12), deg_to_rad(-8.0))
		draw_string_outline(fa, Vector2.ZERO, "CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(1, 1, 1, 0.09 * bk))
		draw_set_transform(Vector2.ZERO)

## the splash art's transform (slides in skewed, leaves left) -> [xf, size, alpha]
func _art_xf(vs: Vector2, tex: Texture2D, xk: float) -> Array:
	var u := (t - 90.0) / 620.0
	if u <= 0.0: return []
	var h := vs.y * 1.04
	var w := minf(h * tex.get_width() / tex.get_height(), vs.x * 0.56)
	h = w * tex.get_height() / tex.get_width()
	var a := clampf(u / 0.3, 0.0, 1.0) * (1.0 - xk)
	var tx := 0.0
	var skx := 0.0
	var e := _e(EZ, u)
	if e < 0.75:
		tx = lerpf(-0.55, 0.03, e / 0.75)
		skx = lerpf(10.0, -3.0, e / 0.75)
	else:
		tx = lerpf(0.03, 0.0, (e - 0.75) / 0.25)
		skx = lerpf(-3.0, 0.0, (e - 0.75) / 0.25)
	tx -= 0.7 * xk
	skx += 8.0 * xk
	var pos := Vector2(-0.06 * vs.x + tx * w, vs.y * 1.04 - h)
	var xf := Transform2D(Vector2(1, 0), Vector2(-tan(deg_to_rad(skx)), 1), pos + Vector2(0, h)) * Transform2D(0.0, Vector2(0, -h))
	return [xf, Vector2(w, h), a]

func _xk() -> float:
	return _e(IN, out_t / 300.0) if out_t >= 0.0 else 0.0

## drop-shadow(10px 0 0 #000) drop-shadow(-3px 0 0 #fff): flat silhouettes behind the art (solid-colour material)
func _draw_sil() -> void:
	if not open: return
	var vs := get_viewport_rect().size
	var tex: Texture2D = SK.tex(arena.player.who, "ult_art")
	var X := _art_xf(vs, tex, _xk())
	if X.is_empty(): return
	_sil_node.draw_set_transform_matrix(X[0])
	_sil_node.draw_texture_rect(tex, Rect2(Vector2(10, 0), X[1]), false, Color(0, 0, 0, X[2]))
	_sil_node.draw_texture_rect(tex, Rect2(Vector2(-3, 0), X[1]), false, Color(1, 1, 1, X[2]))
	_sil_node.draw_set_transform(Vector2.ZERO)

func _draw_front() -> void:
	if not open: return
	var vs := get_viewport_rect().size
	var tex: Texture2D = SK.tex(arena.player.who, "ult_art")
	var X := _art_xf(vs, tex, _xk())
	if not X.is_empty():
		_front.draw_set_transform_matrix(X[0])
		_front.draw_texture_rect(tex, Rect2(Vector2.ZERO, X[1]), false, Color(1, 1, 1, X[2]))
		_front.draw_set_transform(Vector2.ZERO)
	_draw_main(vs, UI.col(arena.player.who), _xk())

var _sil_node: Control
var _front: Control
func _enter_tree() -> void:
	_sil_node = Control.new()
	_sil_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sil_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sil_node.material = UI.solid_mat()
	_sil_node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sil_node.draw.connect(_draw_sil)
	add_child(_sil_node)
	_front = Control.new()
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_front.draw.connect(_draw_front)
	add_child(_front)

func _draw_main(vs: Vector2, pc: Color, xk: float) -> void:
	var mw := minf(vs.x * 0.53, 620.0)
	var mx := vs.x - maxf(18.0, 0.0) - mw + mw * 0.6 * _e(IN, (out_t - 40.0) / 300.0) * (1.0 if out_t >= 0.0 else 0.0)
	var ma := 1.0 - (_e(IN, (out_t - 40.0) / 300.0) if out_t >= 0.0 else 0.0)
	var y := clampf(vs.y * 0.04, 14.0, 30.0)
	var fa := UI.anton(false, 5)
	# DUNGEON CLEAR
	var k1 := _e(EZ, (t - 300.0) / 320.0)
	_front.draw_string(fa, Vector2(mx + 60.0 * (1.0 - k1), y + 12.0), "DUNGEON CLEAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(pc, k1 * ma))
	# 던전 클리어 (drops in big and rotated, overshoots)
	var k2 := clampf((t - 340.0) / 380.0, 0.0, 1.0)
	if k2 > 0.0:
		var e2 := _e(BK, k2)
		var bf := UI.bhs()
		var fs := int(clampf(vs.y * 0.085, 30.0, 58.0))
		var w := UI.text_w(bf, "던전 클리어", fs) + 32.0
		var hh := fs + 10.0
		var c := Vector2(mx + w / 2.0, y + 22.0 + hh / 2.0) + Vector2(0, -70.0 * (1.0 - e2))
		var rot := deg_to_rad(lerpf(-16.0, -4.0, e2))
		var sc := lerpf(1.35, 1.0, e2)
		var xf := Transform2D(rot, Vector2(sc, sc), 0.0, c) * Transform2D(Vector2(1, 0), Vector2(-tan(deg_to_rad(10.0)), 1), Vector2.ZERO)
		var r := Rect2(-w / 2.0, -hh / 2.0, w, hh)
		var a := clampf(k2 * 3.0, 0.0, 1.0) * ma
		_front.draw_set_transform_matrix(xf)
		_front.draw_colored_polygon(UI.clip(Rect2(r.position + Vector2(7, 7), r.size), [[0, 5], [100, 0], [98.5, 100], [1, 93]]), Color(pc, a))
		_front.draw_colored_polygon(UI.clip(r, [[0, 5], [100, 0], [98.5, 100], [1, 93]]), Color(1, 1, 1, a))
		_front.draw_string(bf, Vector2(r.position.x + 12.0, r.position.y + fs * 0.92), "던전 클리어", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a))
		_front.draw_set_transform(Vector2.ZERO)
	var hy := y + 22.0 + clampf(vs.y * 0.085, 30.0, 58.0) + 10.0
	# sub line
	var k3 := _e(EZ, (t - 560.0) / 300.0)
	_front.draw_string(UI.noto(), Vector2(mx + 30.0 * (1.0 - k3), hy + 28.0), "버섯 동굴 · 감독관 해골 격파", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.87, 0.87, 0.87, k3 * ma))
	# stamp
	var k4 := clampf((t - 760.0) / 260.0, 0.0, 1.0)
	if k4 > 0.0:
		var e4 := UI.bez(0.5, 0.0, 0.7, 0.4, k4)
		var gi: int = clampi(int(loot.get("grade", 0)), 0, 4)
		var gc: Color = CGC[gi]
		var bf2 := UI.bhs()
		var gfs := int(clampf(vs.y * 0.046, 18.0, 28.0))
		var gw := maxf(UI.text_w(bf2, CGN[gi], gfs), UI.text_w(UI.noto(), "보물 상자", 10)) + 22.0
		var gh := gfs + 26.0
		var c4 := Vector2(mx + mw * 0.98 - gw / 2.0, y + gh / 2.0)
		var sc4 := lerpf(2.4, 1.0, e4)
		_front.draw_set_transform(c4, deg_to_rad(lerpf(30.0, 11.0, e4)), Vector2(sc4, sc4))
		var r4 := Rect2(-gw / 2.0, -gh / 2.0, gw, gh)
		_front.draw_rect(r4, Color(0, 0, 0, 0.55 * e4 * ma))
		_front.draw_rect(r4, Color(gc, e4 * ma), false, 3.0)
		var lw := UI.text_w(UI.noto(), "보물 상자", 10)
		_front.draw_string(UI.noto(), Vector2(-lw / 2.0, -gh / 2.0 + 15.0), "보물 상자", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, e4 * ma))
		var nw := UI.text_w(bf2, CGN[gi], gfs)
		_front.draw_string(bf2, Vector2(-nw / 2.0, gh / 2.0 - 6.0), CGN[gi], HORIZONTAL_ALIGNMENT_LEFT, -1, gfs, Color(gc, e4 * ma))
		_front.draw_set_transform(Vector2.ZERO)
	# REWARDS
	var sy := hy + 52.0
	var k5 := _e(EZ, (t - 820.0) / 300.0)
	var ra := k5 * ma
	_front.draw_string(UI.anton(false, 4), Vector2(mx + 40.0 * (1.0 - k5), sy), "REWARDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.58, 0.64, ra))
	var rw := UI.text_w(UI.anton(false, 4), "REWARDS", 11)
	_front.draw_rect(Rect2(mx + rw + 8.0, sy - 5.0, mw - rw - 8.0, 1.0), Color(1, 1, 1, 0.18 * ra))
	# tiles
	r_tiles.clear()
	var items: Array = loot["items"]
	var ty := sy + 14.0
	var ts := clampf(vs.y * 0.15, 52.0, 104.0) * 0.8
	if items.is_empty():
		_front.draw_string(UI.noto(), Vector2(mx + 4.0, ty + 26.0), "획득한 아이템이 없어요", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.6 * ra))
		ty += 40.0
	else:
		var per := maxi(1, int(mw / (ts + 12.0)))
		for i in items.size():
			var it: Dictionary = items[i]
			var ki := clampf((t - 900.0 - i * 85.0) / 380.0, 0.0, 1.0)
			if ki <= 0.0: continue
			var ek := _e(BK, ki)
			var col := i % per
			var row := i / per
			var r := Rect2(mx + 4.0 + col * (ts + 12.0), ty + row * (ts + 12.0), ts, ts)
			r_tiles.append(r)
			var gc2: Color = CGC[clampi(int(it.get("g", 0)), 0, 4)]
			var c := r.get_center() + Vector2(0, -40.0 * (1.0 - ek))
			var sc5 := lerpf(0.5, 1.0, ek) * (1.1 if i == sel else 1.0)
			_front.draw_set_transform(c + (Vector2(0, -6) if i == sel else Vector2.ZERO), deg_to_rad(lerpf(-18.0, 0.0, ek) - (4.0 if i == sel else 0.0)), Vector2(sc5, sc5))
			var rr := Rect2(-ts / 2.0, -ts / 2.0, ts, ts)
			var poly := UI.clip(rr, [[6, 0], [100, 0], [94, 100], [0, 100]])
			if i == sel: _front.draw_colored_polygon(UI.clip(rr.grow(3), [[6, 0], [100, 0], [94, 100], [0, 100]]), Color.WHITE)
			_front.draw_colored_polygon(poly, Color(0.07, 0.07, 0.07, ma))
			_front.draw_rect(Rect2(rr.position.x + 4.0, rr.end.y - 5.0, ts - 8.0, 5.0), Color(gc2, ma))
			var nm: String = String(it.get("n", "?"))
			var nfs := 11
			var nw2 := UI.text_w(UI.noto(), nm, nfs)
			_front.draw_string(UI.noto(), Vector2(-minf(nw2, ts - 8.0) / 2.0, 4.0), nm, HORIZONTAL_ALIGNMENT_LEFT, ts - 8.0, nfs, Color(1, 1, 1, ma))
			_front.draw_set_transform(Vector2.ZERO)
		ty += (ceili(float(items.size()) / per)) * (ts + 12.0)
	# info panel
	var t_end := 900.0 + items.size() * 85.0 + 300.0
	var k6 := _e(EZ, (t - t_end + 150.0) / 320.0)
	var ir := Rect2(mx, ty + 6.0 + 16.0 * (1.0 - k6), mw, 54.0)
	var ia := k6 * ma
	var slide := 18.0 * (1.0 - _e(EZ, info_t / 240.0)) if info_t < 240.0 else 0.0
	_front.draw_colored_polygon(UI.clip(Rect2(ir.position + Vector2(slide, 0), ir.size), [[0, 0], [100, 6], [99, 100], [0, 94]]), Color(0.07, 0.07, 0.07, ia))
	_front.draw_rect(Rect2(ir.position.x + slide, ir.position.y, 5, ir.size.y), Color(pc, ia))
	var info := "칸을 눌러 자세히 보기"
	if sel >= 0 and sel < items.size():
		info = String(items[sel].get("n", "")) + ("  ·  " + String(items[sel].get("d", "")) if items[sel].has("d") else "")
	_front.draw_string(UI.noto(), Vector2(ir.position.x + 14.0 + slide, ir.position.y + 32.0), info, HORIZONTAL_ALIGNMENT_LEFT, mw - 24.0, 12, Color(1, 1, 1, ia))
	# tally tokens
	var toks := [["실링", "+", int(loot["sh"]), SHC, -3.0], ["기억석", "+", int(loot["mem"]), MEMC, 2.0], ["룬", "", int(loot["runes"]), Color("#b48cff"), -1.0], ["장비", "", int(loot["gear"]), Color("#6aa7ff"), 3.0]]
	var tx := mx
	var tyy := ir.end.y + 14.0
	var fa2 := UI.anton()
	var tfs := int(clampf(vs.y * 0.034, 16.0, 22.0))
	for i in toks.size():
		var tk: Array = toks[i]
		var d0 := t_end + i * 70.0
		var kt := clampf((t - d0) / 420.0, 0.0, 1.0)
		var roll := 1.0 - pow(1.0 - clampf((t - d0 - 120.0) / 700.0, 0.0, 1.0), 3.0)
		var num: String = String(tk[1]) + str(roundi(float(tk[2]) * roll))
		var lw2 := UI.text_w(UI.noto(), tk[0], 10)
		var w := 9.0 + 14.0 + 6.0 + lw2 + 4.0 + UI.text_w(fa2, num, tfs) + 16.0
		if kt > 0.0:
			var ek := _e(BK, kt)
			_front.draw_set_transform(Vector2(tx + w / 2.0, tyy + 16.0 - 30.0 * (1.0 - ek)), deg_to_rad(tk[4]))
			var r := Rect2(-w / 2.0, -16.0, w, 32.0)
			var a := clampf(kt * 3.0, 0.0, 1.0) * ma
			_front.draw_colored_polygon(UI.clip(r, [[9, 0], [100, 0], [91, 100], [0, 100]]), Color(1, 1, 1, a))
			var dx := r.position.x + 9.0 + 7.0
			_front.draw_set_transform_matrix(Transform2D(deg_to_rad(tk[4]), Vector2(tx + w / 2.0, tyy + 16.0 - 30.0 * (1.0 - ek))) * Transform2D(PI / 4.0, Vector2(dx, 0)))
			_front.draw_rect(Rect2(-8, -8, 16, 16), Color(0, 0, 0, a))
			_front.draw_rect(Rect2(-6, -6, 12, 12), Color(tk[3], a))
			_front.draw_set_transform(Vector2(tx + w / 2.0, tyy + 16.0 - 30.0 * (1.0 - ek)), deg_to_rad(tk[4]))
			_front.draw_string(UI.noto(), Vector2(dx + 13.0, 4.0), tk[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.7 * a))
			_front.draw_string(fa2, Vector2(dx + 13.0 + lw2 + 4.0, tfs * 0.38), num, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, Color(0, 0, 0, a))
			_front.draw_set_transform(Vector2.ZERO)
		tx += w + 4.0
	# 마을로 돌아가기
	var kg := clampf((t - t_end - 380.0) / 460.0, 0.0, 1.0)
	var bf3 := UI.bhs()
	var gw2 := UI.text_w(bf3, "마을로 돌아가기", 19) + 52.0
	r_go = Rect2(mx + mw - gw2, vs.y - clampf(vs.y * 0.03, 12.0, 22.0) - 42.0, gw2, 42.0)
	if kg > 0.0:
		var eg := _e(BK, kg)
		var pressed := out_t >= 0.0
		var c := r_go.get_center() + Vector2(120.0 * (1.0 - eg), 0)
		var sc := 0.94 if pressed else 1.0
		_front.draw_set_transform(c, deg_to_rad(lerpf(-14.0, 0.0, eg) - (3.0 if pressed else 0.0)), Vector2(sc, sc))
		var r := Rect2(-gw2 / 2.0, -21.0, gw2, 42.0)
		var cp := [[0, 0], [93, 0], [100, 100], [7, 100]] if pressed else [[7, 0], [100, 0], [93, 100], [0, 100]]
		var a := clampf(kg * 3.0, 0.0, 1.0) * ma
		_front.draw_colored_polygon(UI.clip(Rect2(r.position + Vector2(5, 5), r.size), cp), Color(pc, a))
		_front.draw_colored_polygon(UI.clip(r, cp), Color(1, 1, 1, a))
		var w3 := UI.text_w(bf3, "마을로 돌아가기", 19)
		_front.draw_string(bf3, Vector2(-w3 / 2.0, 7.0), "마을로 돌아가기", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0, 0, 0, a))
		_front.draw_set_transform(Vector2.ZERO)
