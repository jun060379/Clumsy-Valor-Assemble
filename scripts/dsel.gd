extends Control
## Dungeon select (SORTIE v2 in the prototype: #sx2 openDsel / sxFill / sxGo / sxLaunch): the 출격 title, area tabs, the
## dungeon name, its monsters on a black stage with their element chips, the request card, the party faces and 출격!.
## 출격! plays the launch: the party's coloured bands with their standing art slam in diagonally, "SORTIE!" flies in
## letter by letter, then the bands stretch out along their line and are eaten from the tail, the word blinks out,
## and sortie.sortie_go() takes over. Esc / ✕ closes, Enter / pad A launches, ←/→ change the tab.

const UI := preload("res://scripts/ui_kit.gd")
const EL := preload("res://scripts/elements.gd")
const MOB := preload("res://scripts/mob.gd")
const SK := preload("res://scripts/skins.gd")       # member art through the worn costume
const GRADE := {"common": ["일반", Color("#b9b2a3")], "uncommon": ["고급", Color("#7fc77a")], "rare": ["레어", Color("#6aa7ff")], "elite": ["엘리트", Color("#b48cff")]}
## DUNGEONS + SXD
const DUN := [
	{"id": "cave", "ok": true, "name": "버섯 동굴", "lv": "★", "en": "MUSHROOM CAVE", "col": Color("#3a2414"), "acc": Color("#ffb04a"), "req": "갱도 정리 의뢰",
		"sub": "폐광과 버섯 군락이 뒤엉킨 미로. 감독관 해골이 가장 깊은 갱도를 지킨다.", "lvl": "Lv 1 – 6", "rooms": "방 10개 · 미로", "boss": "감독관 해골",
		"rw": ["common", "uncommon", "rare", "elite"], "mobs": ["goblin", "mush", "skel", "eye"], "rank": 1},
	{"id": "x1", "ok": false, "name": "???", "lv": "★★", "en": "UNKNOWN", "col": Color("#18181e"), "acc": Color("#8a8a9a"), "sub": "아직 아무것도 알려지지 않았다.", "rank": 1},
	{"id": "x2", "ok": false, "name": "???", "lv": "★★★", "en": "UNKNOWN", "col": Color("#18181e"), "acc": Color("#8a8a9a"), "sub": "아직 아무것도 알려지지 않았다.", "rank": 1},
]
const SEN := {"estelle": "ESTELLE", "aida": "AYDA", "luce": "LUCE"}
const SFY := {"estelle": -0.15, "aida": -0.15, "luce": -0.25}
const SCROP := {"estelle": Vector2(0.58, 0.09), "aida": Vector2(0.58, 0.09), "luce": Vector2(0.5, 0.11)}

var arena
var sortie
var open := false
var sel := 0
var t := 0.0                     # since opened (entry animation)
var body_t := 0.0                # since the body was (re)filled
var wipe_t := -1.0               # tab change wipe (ms), -1 = none
var wipe_col := Color.BLACK
var wipe_to := 0
var launch := -1.0               # launch animation clock, -1 = not launching
var launched := false
var press_go := 0.0
var shake_go := 0.0
var r_tabs: Array = []
var r_go := Rect2()
var r_x := Rect2()
var r_faces: Array = []
var mobs := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	visible = false

func show_it() -> void:
	sel = 0
	open = true
	visible = true
	t = 0.0
	body_t = 0.0
	launch = -1.0
	launched = false
	wipe_t = -1.0
	arena.sfx("ready", 0.4)

func close() -> void:
	if launch >= 0.0: return
	open = false
	visible = false
	sortie.dsel_cd = 1500.0
	arena.sfx("ready", 0.25)

func _ok() -> bool:
	return DUN[sel]["ok"]

## sxGo: a tab change wipes in the new dungeon's colour
func go_tab(i: int) -> void:
	if i == sel or wipe_t >= 0.0 or launch >= 0.0: return
	wipe_to = i
	wipe_col = DUN[i]["col"]
	wipe_t = 0.0
	arena.sfx("ready", 0.25)

## sxLaunch
func do_launch() -> void:
	if launch >= 0.0: return
	if not _ok():
		shake_go = 200.0
		arena.sfx("guard", 0.4)
		return
	launch = 0.0
	press_go = 220.0
	arena.sfx("ready", 0.8)


func _input(ev: InputEvent) -> void:
	if not open or sortie.party_ui.open: return     # the party page (a face tapped) is over it
	var handled := ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventJoypadButton or ev is InputEventScreenTouch
	if launch < 0.0:
		if ev is InputEventKey and ev.pressed and not ev.echo:
			var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			if k == KEY_ESCAPE: close()
			elif k in [KEY_ENTER, KEY_KP_ENTER]: do_launch()
			elif k == KEY_LEFT: go_tab(maxi(0, sel - 1))
			elif k == KEY_RIGHT: go_tab(mini(DUN.size() - 1, sel + 1))
		elif ev is InputEventJoypadButton and ev.pressed:
			if ev.button_index == JOY_BUTTON_B: close()
			elif ev.button_index == JOY_BUTTON_A: do_launch()
			elif ev.button_index == JOY_BUTTON_DPAD_LEFT: go_tab(maxi(0, sel - 1))
			elif ev.button_index == JOY_BUTTON_DPAD_RIGHT: go_tab(mini(DUN.size() - 1, sel + 1))
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var p: Vector2 = ev.position
			if r_x.grow(4).has_point(p): close()
			elif r_go.grow(4).has_point(p): do_launch()
			else:
				for i in r_tabs.size():
					if r_tabs[i].has_point(p): go_tab(i)
				for r in r_faces:
					if r.has_point(p):
						sortie.party_ui.show_it()
	if handled: get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not open: return
	var dt: float = minf(delta * 1000.0, 100.0) * sortie.speed
	t += dt
	body_t += dt
	if press_go > 0.0: press_go -= dt
	if shake_go > 0.0: shake_go -= dt
	if wipe_t >= 0.0:
		wipe_t += dt
		if wipe_t >= 480.0 and sel != wipe_to:
			sel = wipe_to
			body_t = 0.0
		if wipe_t >= 560.0: wipe_t = -1.0
	if launch >= 0.0:
		var was := launch
		launch += dt
		var slam := 400.0 + 6 * 38.0 + 230.0
		if was < slam and launch >= slam:
			arena.sfx("slam", 0.7)
		# the black under it: from the wagon it closes to full black (the sweep follows), off an edge it clears
		var lb_end := 1500.0 + (380.0 if sortie.dir == 0 else 700.0)
		if launch >= lb_end and not launched:
			launched = true
			sortie.sortie_go(func():
				open = false
				visible = false
				launch = -1.0)
	queue_redraw()


# ---------- drawing ----------
func _draw() -> void:
	if not open: return
	var vs := get_viewport_rect().size
	var D: Dictionary = DUN[sel]
	var acc: Color = D["acc"]
	var hide_ui := launch >= 1500.0
	if not hide_ui or sortie.dir == 0:
		_draw_page(vs, D, acc)
	if launch >= 0.0:
		_draw_launch(vs)

func _draw_page(vs: Vector2, D: Dictionary, acc: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), D["col"])
	# sray: slow diagonal light bands
	var tt := Time.get_ticks_msec() / 1000.0
	var off := fposmod(tt * 40.0, 130.0)
	var dx := vs.y / tan(deg_to_rad(62.0))
	var x := -dx - 260.0 + off
	while x < vs.x + 130.0:
		draw_colored_polygon(PackedVector2Array([Vector2(x + 70.0, 0), Vector2(x + 130.0, 0), Vector2(x + 130.0 - dx, vs.y), Vector2(x + 70.0 - dx, vs.y)]), Color(1, 1, 1, 0.045))
		x += 130.0
	UI.dots(self, Rect2(Vector2.ZERO, vs), 0.26 * 0.35, 1.0)
	# svig
	for i in 8:
		var k := float(i) / 8.0
		draw_rect(Rect2(0, vs.y * (0.55 + 0.45 * k), vs.x, vs.y * 0.45 / 8.0 + 1.0), Color(0, 0, 0, 0.45 * k))
	draw_rect(Rect2(vs.x * 0.82, 0, vs.x * 0.18, vs.y), Color(0, 0, 0, 0.18))
	_draw_body(vs, D, acc)
	# title
	draw_set_transform(Vector2(20, 14), deg_to_rad(-6.0))
	draw_string(UI.anton(false, 3), Vector2(0, 10), "SORTIE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	var bf := UI.bhs()
	var tw := UI.text_w(bf, "출격", 34)
	UI.para(self, 0, 14, tw + 26.0, 38.0, 8.0, Color.BLACK)
	draw_string(bf, Vector2(12, 45), "출격", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	_draw_tabs(vs, acc)
	# ✕
	r_x = Rect2(vs.x - 14.0 - 36.0, 12.0, 36.0, 36.0)
	var cx := r_x.get_center()
	draw_circle(cx + Vector2(3, 3), 18.0, UI.col(arena.player.who))
	draw_circle(cx, 18.0, Color.WHITE)
	draw_circle(cx, 16.0, Color.BLACK)
	UI.cross(self, cx, 5.5, Color.WHITE, 2.0)
	# tab wipe: a huge panel swings in from the bottom-left corner (rotate 0 → 91°)
	if wipe_t >= 0.0 and wipe_t < 480.0:
		var k := UI.bez(0.6, 0.02, 0.3, 1.0, wipe_t / 480.0)
		var S := maxf(vs.x, vs.y) * 2.5
		var piv := Vector2(0, vs.y)
		var pts := PackedVector2Array([piv, piv + Vector2(-S, 0), piv + Vector2(-S, -S), piv + Vector2(0, -S)])
		draw_colored_polygon(UI.rot(pts, piv, deg_to_rad(91.0) * k), wipe_col)

func _draw_tabs(vs: Vector2, acc: Color) -> void:
	r_tabs.clear()
	var x := 150.0
	var bf := UI.bhs()
	var fa := UI.anton(true)
	for i in DUN.size():
		var D: Dictionary = DUN[i]
		var on := i == sel
		var nm: String = D["name"] if D["ok"] else "???"
		var w := 12.0 + UI.text_w(fa, "0%d" % (i + 1), 18) + (8.0 + UI.text_w(bf, nm, 15) + 22.0 if on else 12.0)
		var r := Rect2(x, 14.0 + (5.0 if on else 0.0), w, 34.0)
		r_tabs.append(r)
		if on:
			draw_colored_polygon(UI.clip(Rect2(r.position + Vector2(0, -3), r.size), [[10, 0], [100, 0], [90, 100], [0, 100]]), acc)
		draw_colored_polygon(UI.clip(r, [[10, 0], [100, 0], [90, 100], [0, 100]]), Color.WHITE if on else Color.BLACK)
		var nc := Color.BLACK if on else (acc if D["ok"] else Color("#777777"))
		draw_string(fa, Vector2(r.position.x + 12.0, r.position.y + 25.0), "0%d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, nc)
		if on:
			draw_string(bf, Vector2(r.position.x + 20.0 + UI.text_w(fa, "0%d" % (i + 1), 18), r.position.y + 24.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)
		x += w + 6.0

## .it entry: slides 60 px in from the right and fades in, 60 ms apart, with the overshoot ease
func _it(i: int) -> Array:
	var k := clampf((body_t - i * 60.0) / 500.0, 0.0, 1.0)
	return [60.0 * (1.0 - UI.bk(k)), clampf((body_t - i * 60.0) / 300.0, 0.0, 1.0)]

func _draw_body(vs: Vector2, D: Dictionary, acc: Color) -> void:
	var ok: bool = D["ok"]
	# hero: AREA 0n · EN / name / ★
	var e0 := _it(0)
	draw_set_transform(Vector2(22.0 + e0[0], maxf(82.0, vs.y * 0.23)), deg_to_rad(-5.0))
	var a0: float = e0[1]
	draw_string(UI.anton(false, 4), Vector2(0, 0), "AREA 0%d · %s" % [sel + 1, D["en"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(acc, a0))
	var bf := UI.bhs()
	var fs := int(minf(58.0, vs.y * 0.15))
	var xf := Transform2D(Vector2(1, 0), Vector2(-tan(deg_to_rad(12.0)), 1), Vector2.ZERO)
	draw_set_transform_matrix(Transform2D(deg_to_rad(-5.0), Vector2(22.0 + e0[0], maxf(82.0, vs.y * 0.23))) * xf)
	draw_string(bf, Vector2(0, fs + 2.0), D["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a0))
	var nw := UI.text_w(bf, D["name"], fs)
	var fa := UI.anton(false, 2)
	var lw := UI.text_w(fa, D["lv"], 15) + 20.0
	UI.para(self, nw + 12.0, fs * 0.25, lw, 21.0, 3.0, Color(acc, a0))
	draw_string(fa, Vector2(nw + 22.0, fs * 0.25 + 17.0), D["lv"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, a0))
	draw_set_transform(Vector2.ZERO)
	# stage: black slanted band with the monsters on it
	var e1 := _it(1)
	var sh := maxf(150.0, vs.y * 0.47)
	var sr := Rect2(-0.02 * vs.x + e1[0], vs.y - sh, vs.x * 0.54, sh)
	var band := Rect2(sr.position.x, sr.end.y - sh * 0.44, sr.size.x, sh * 0.44)
	draw_colored_polygon(UI.clip(band, [[0, 22], [100, 0], [94, 100], [0, 100]]), Color(0, 0, 0, e1[1]))
	var list: Array = D["mobs"] if ok else ["goblin", "skel", "mush"]
	var n := list.size()
	var fbh := UI.bhs()
	for i in n:
		var k: String = list[i]
		var M: Dictionary = MOB.DEF[k]
		var cx: float = sr.position.x + sr.size.x * (0.06 + (0.86) * (i + 0.5) / n)
		var by: float = band.position.y + 30.0 - sh * 0.0
		var A: Array = M["anims"]["idle"]
		var tex := MOB.tex(A[0])
		var fr := int(Time.get_ticks_msec() / (700.0 / A[1] if A[1] == 8 else 200.0)) % int(A[1])
		var s := 1.1
		var col := Color(1, 1, 1, e1[1]) if ok else Color(0, 0, 0, 0.8 * e1[1])
		draw_texture_rect_region(tex, Rect2(cx - 75.0 * s, by - 120.0 * s, 150.0 * s, 150.0 * s), Rect2(fr * 150, 0, 150, 150), col)
		var nm: String = M["name"] if ok else "???"
		var tw := UI.text_w(fbh, nm, 13)
		UI.shadow_text(self, fbh, Vector2(cx - tw / 2.0, by + 32.0), nm, 13, Color(1, 1, 1, e1[1]))
		var de: String = M["defEl"][0] if ok else ""
		var en: String = EL.ELN.get(de, "?")
		var ew := UI.text_w(UI.noto(), en, 10) + 14.0
		UI.para(self, cx - ew / 2.0, by + 37.0, ew, 15.0, 2.5, Color(EL.ECOL.get(de, Color("#666666")), e1[1]))
		draw_string(UI.noto(), Vector2(cx - ew / 2.0 + 7.0, by + 49.0), en, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, e1[1]))
	# request card
	var e2 := _it(2)
	_draw_req(vs, D, acc, e2)
	# party faces + EDIT, and 출격!
	_draw_party(vs)
	_draw_go(vs, acc, ok)

func _draw_req(vs: Vector2, D: Dictionary, acc: Color, e: Array) -> void:
	var ok: bool = D["ok"]
	var w := minf(vs.x * 0.34, 286.0)
	var x: float = vs.x - 16.0 - w + e[0]
	var y := maxf(56.0, vs.y * 0.15)
	var h := 196.0 if ok else 150.0
	var a: float = e[1]
	draw_set_transform(Vector2(x, y), deg_to_rad(2.0))
	var r := Rect2(0, 0, w, h)
	draw_colored_polygon(UI.clip(r, [[0, 3], [100, 0], [98, 100], [2, 96]]), Color(1, 1, 1, a))
	draw_rect(Rect2(0, 3, 7, h - 7), Color(acc, a))
	var fa := UI.anton(false, 3)
	draw_string(fa, Vector2(20, 18), "REQUEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.55 * a))
	draw_string(UI.bhs(), Vector2(20, 40), D.get("req", "정보 없음") if ok else "정보 없음", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0, 0, 0, a))
	var ty := 58.0
	for ln in _wrap(D["sub"], w - 40.0, 11):
		draw_string(UI.noto(), Vector2(20, ty), ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.2, 0.2, a))
		ty += 16.0
	ty += 6.0
	var rows: Array = [["LEVEL", D.get("lvl", "?")], ["AREA", D.get("rooms", "?")], ["BOSS", D.get("boss", "?")]]
	if ok:
		rows.append(["LOOT", ""])
		rows.append(["RANK", "명성 %d등급" % D["rank"]])
	for rw in rows:
		draw_string(fa, Vector2(20, ty), rw[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0, 0, 0, 0.55 * a))
		var vx := 70.0
		if rw[0] == "LOOT":
			for g in D["rw"]:
				var gc: Color = GRADE[g][1]
				draw_set_transform_matrix(Transform2D(deg_to_rad(2.0), Vector2(x, y)) * Transform2D(PI / 4.0, Vector2(vx + 5.0, ty - 4.0)))
				draw_rect(Rect2(-4, -4, 8, 8), Color(gc, a))
				draw_set_transform(Vector2(x, y), deg_to_rad(2.0))
				vx += 17.0
			draw_string(UI.noto_k(), Vector2(vx, ty), "실링 · 기억석", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, a))
		else:
			if rw[0] == "RANK":
				if _rank_ok(D):            # ✓ (the fonts lack the glyph)
					draw_polyline(PackedVector2Array([Vector2(vx, ty - 5.0), Vector2(vx + 3.5, ty - 1.5), Vector2(vx + 10.0, ty - 9.0)]), Color(0, 0, 0, a), 2.0)
				else:                      # a small padlock
					draw_rect(Rect2(vx, ty - 7.0, 9.0, 7.0), Color(0, 0, 0, a))
					draw_arc(Vector2(vx + 4.5, ty - 7.0), 3.0, PI, TAU, 8, Color(0, 0, 0, a), 1.5)
				vx += 15.0
			draw_string(UI.noto_k(), Vector2(vx, ty), rw[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#cc2233") if rw[0] == "BOSS" and ok else Color(0, 0, 0, a))
		ty += 17.0
	if not ok:
		draw_set_transform_matrix(Transform2D(deg_to_rad(2.0), Vector2(x, y)) * Transform2D(deg_to_rad(-14.0), Vector2(w - 120.0, h * 0.7)))
		var lf := UI.anton(false, 5)
		var lw := UI.text_w(lf, "LOCKED", 26)
		draw_rect(Rect2(-12, -30, lw + 24.0, 38), Color("#cc2233"), false, 4.0)
		draw_string(lf, Vector2(0, 0), "LOCKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#cc2233"))
	draw_set_transform(Vector2.ZERO)

## the dungeon's fame rank: asks the fame system when it is there (fameDunOk), otherwise the first rank is open
func _rank_ok(D: Dictionary) -> bool:
	var F = arena.get("fame")
	if F != null and F.has_method("dun_ok"): return bool(F.dun_ok(D["id"]))
	return int(D["rank"]) <= 1

func _wrap(s: String, w: float, fs: int) -> Array:
	var out: Array = []
	var cur := ""
	for word in s.split(" "):
		var nx := word if cur == "" else cur + " " + word
		if UI.text_w(UI.noto(), nx, fs) > w and cur != "":
			out.append(cur)
			cur = word
		else:
			cur = nx
	if cur != "": out.append(cur)
	return out

func _draw_party(vs: Vector2) -> void:
	r_faces.clear()
	var P = arena.player
	var n: int = P.party.size()
	var x0 := vs.x - 16.0 - 200.0 - n * 57.0
	var y := vs.y - 12.0 - 52.0
	var fa := UI.anton(false, 3)
	draw_set_transform(Vector2(x0 - 12.0, y + 52.0), -PI / 2.0)
	draw_string(fa, Vector2(0, 0), "PARTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	draw_string(UI.anton(false, 2), Vector2(x0 + 14.0, y - 4.0), "EDIT", HORIZONTAL_ALIGNMENT_LEFT, n * 57.0 - 14.0, 9, Color(1, 1, 1, 0.7))
	for i in n:
		var c: String = P.party[i]
		var r := Rect2(x0 + i * 57.0, y, 52.0, 52.0)
		r_faces.append(r)
		var poly := UI.clip(r, [[10, 0], [100, 0], [90, 100], [0, 100]])
		draw_colored_polygon(poly, Color.BLACK)
		var tex: Texture2D = SK.tex(c, "st_base")
		# background-size 300% auto at the face crop
		var tw := 52.0 * 3.0
		var th := tw * tex.get_height() / tex.get_width()
		var cp: Vector2 = SCROP[c]
		var ox := (52.0 - tw) * cp.x
		var oy := (52.0 - th) * cp.y
		var uvs := PackedVector2Array()
		for p in poly:
			uvs.append(Vector2((p.x - r.position.x - ox) / tw, (p.y - r.position.y - oy) / th))
		draw_colored_polygon(poly, Color.WHITE, uvs, tex)
		draw_rect(Rect2(r.position.x + 2.0, r.end.y - 6.0, 48.0, 6.0), UI.col(c))

func _draw_go(vs: Vector2, acc: Color, ok: bool) -> void:
	var bf := UI.bhs()
	var w := UI.text_w(bf, "출격!", 30) + 80.0
	var h := 46.0
	r_go = Rect2(vs.x - 18.0 - w, vs.y - 12.0 - h, w, h)
	var sx := 0.0
	if shake_go > 0.0: sx = sin(shake_go / 200.0 * PI * 3.0) * 8.0
	var sc := 1.0
	if press_go > 0.0:
		var k := 1.0 - press_go / 220.0
		sc = 1.0 - 0.12 * sin(k * PI) if k < 0.5 else 1.0 + 0.06 * sin((k - 0.5) * 2.0 * PI)
	var c := r_go.get_center() + Vector2(sx, 0)
	var xf := Transform2D(deg_to_rad(-3.0), Vector2(sc, sc), 0.0, c) * Transform2D(Vector2(1, 0), Vector2(-tan(deg_to_rad(12.0)), 1), Vector2.ZERO)
	draw_set_transform_matrix(xf)
	var r := Rect2(-w / 2.0, -h / 2.0, w, h)
	var a := 1.0 if ok else 0.35
	draw_rect(Rect2(r.position + Vector2(10, 10), r.size), Color(1, 1, 1, a))
	draw_rect(Rect2(r.position + Vector2(6, 6), r.size), Color(0, 0, 0, a))
	draw_rect(r, Color(acc, a))
	draw_rect(r, Color(0, 0, 0, a), false, 3.0)
	var tw := UI.text_w(bf, "출격!", 30)
	draw_string(bf, Vector2(-tw / 2.0, 11), "출격!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0, 0, 0, a))
	draw_set_transform(Vector2.ZERO)


# ---------- the launch ----------
func _draw_launch(vs: Vector2) -> void:
	var L := launch
	var P = arena.player
	var party: Array = P.party
	# lbg
	var la := 0.85 * clampf(L / 200.0, 0.0, 1.0)
	if L >= 1500.0:
		if sortie.dir == 0:
			la = lerpf(0.85, 1.0, clampf((L - 1500.0) / 380.0, 0.0, 1.0))
		else:
			var u := (L - 1500.0) / 700.0
			la = 0.85 if u < 0.45 else 0.85 * (1.0 - clampf((u - 0.45) / 0.55, 0.0, 1.0))
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, la))
	var E := func(u: float) -> float: return UI.bez(0.16, 1.0, 0.3, 1.0, u)
	var tops := [0.02, 0.35, 0.68]
	for k in party.size():
		var c: String = party[k]
		var d0 := 60.0 + k * 90.0
		var u: float = E.call(clampf((L - d0) / 300.0, 0.0, 1.0))
		var odd := k % 2 == 1
		var from := Vector2(1.4 * vs.x, -0.197 * vs.x) if odd else Vector2(-1.4 * vs.x, 0.197 * vs.x)
		var off: Vector2 = from * (1.0 - u)
		if L < d0: continue
		var stretch := 1.0
		var clip := 0.0
		if L >= 1500.0:
			var v := clampf((L - 1500.0 - k * 80.0) / 720.0, 0.0, 1.0)
			var ve := UI.bez(0.45, 0.0, 0.55, 1.0, v)
			var tgt := Vector2(-0.70 * vs.x, 0.098 * vs.x) if odd else Vector2(0.70 * vs.x, -0.098 * vs.x)
			var mid := Vector2(-0.14 * vs.x, 0.02 * vs.x) if odd else Vector2(0.14 * vs.x, -0.02 * vs.x)
			if ve < 0.45:
				off = mid * (ve / 0.45)
				stretch = 1.0 + 0.3 * ve / 0.45
				clip = 0.3 * ve / 0.45
			else:
				var w2 := (ve - 0.45) / 0.55
				off = mid.lerp(tgt, w2)
				stretch = 1.3 + 0.25 * w2
				clip = 0.3 + 0.7 * w2
			if clip >= 1.0: continue
		_stand(vs, c, k, tops[k] if k < 3 else 0.5, off, stretch, clip, odd, L - d0)
	# SORTIE!
	var word := "SORTIE!"
	var fa := UI.anton(true)
	var fs := int(minf(vs.y * 0.34, vs.x * 0.19))
	var tot := UI.text_w(fa, word, fs)
	var vis := true
	if L >= 1500.0:
		var bk := (L - 1500.0) / 240.0
		vis = bk < 0.2 or (bk >= 0.4 and bk < 0.6) or (bk >= 0.75 and bk < 1.0)
		if bk >= 1.0: vis = false
	if vis:
		var slam := 400.0 + 6 * 38.0 + 230.0
		var bright := clampf(1.0 - (L - slam) / 180.0, 0.0, 1.0) if L >= slam else 0.0
		var shake := Vector2.ZERO
		if L >= slam and L < slam + 180.0:
			var q := (L - slam) / 180.0
			shake = Vector2(7, 4).lerp(Vector2(-5, -3), minf(1.0, q * 2.0)) * (1.0 - q)
		draw_set_transform(vs / 2.0 + shake, deg_to_rad(-8.0))
		var x := -tot / 2.0
		for i in word.length():
			var ch := word[i]
			var cw := UI.text_w(fa, ch, fs)
			var u2 := clampf((L - 400.0 - i * 38.0) / 300.0, 0.0, 1.0)
			if u2 > 0.0:
				var e2 := UI.bez(0.2, 0.8, 0.3, 1.0, u2)
				var ox := 0.0
				if e2 < 0.75: ox = lerpf(0.38 * vs.x, -0.012 * vs.x, e2 / 0.75)
				else: ox = lerpf(-0.012 * vs.x, 0.0, (e2 - 0.75) / 0.25)
				var a := clampf(e2 / 0.4, 0.0, 1.0)
				var p := Vector2(x + ox, fs * 0.36)
				draw_string(fa, p + Vector2(7, 7), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, a))
				draw_string(fa, p, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a).lerp(Color(1, 1, 0.9, a), bright))
			x += cw
		draw_set_transform(Vector2.ZERO)

## one party member's band: rotated -8°, the member's colour, standing art drifting, big name; it stretches and is clipped from its tail on the way out
func _stand(vs: Vector2, c: String, k: int, top: float, off: Vector2, stretch: float, clip: float, odd: bool, lt: float) -> void:
	var bw := vs.x * 1.3
	var bh := vs.y * 0.31
	var centre := Vector2(-0.15 * vs.x + bw / 2.0, vs.y * top + bh / 2.0) + off
	var xf := Transform2D(deg_to_rad(-8.0), centre) * Transform2D(0.0, Vector2(stretch, 1.0), 0.0, Vector2.ZERO)
	var x0 := -bw / 2.0
	var x1 := bw / 2.0
	if odd: x1 -= bw * clip     # inset from the right (tail) for the band that leaves left
	else: x0 += bw * clip
	draw_set_transform_matrix(xf)
	draw_rect(Rect2(x0, -bh / 2.0 - 4.0, x1 - x0, bh + 8.0), Color.BLACK)
	draw_rect(Rect2(x0, -bh / 2.0, x1 - x0, bh), UI.col(c))
	# the art: left at 14% (52% for the middle one), 46% wide, shifted up by --fy, mirrored for the middle one
	var tex: Texture2D = SK.tex(c, "st_base")
	var iw := bw * 0.46
	var ih := iw * tex.get_height() / tex.get_width()
	var fx := 0.52 if k == 1 else 0.14
	var drift := clampf(lt / 1400.0, 0.0, 1.0)
	var dv := Vector2(-0.06, 0.03) if odd else Vector2(0.06, -0.03)
	var ix := -bw / 2.0 + bw * fx + iw * dv.x * (1.0 - drift)
	var iy: float = ih * SFY[c] + ih * dv.y * (1.0 - drift)
	# clip the art to the band rect (and the tail clip)
	var cl := Rect2(x0, -bh / 2.0, x1 - x0, bh)
	var ar := Rect2(ix, iy, iw, ih)
	var inter := ar.intersection(cl)
	if inter.size.x > 0.0 and inter.size.y > 0.0:
		if k == 1:
			# scaleX(-1) about the art's own centre: draw the unmirrored region that lands on `inter` after the flip
			var mx := ar.position.x + ar.size.x / 2.0
			var R := Rect2(2.0 * mx - inter.end.x, inter.position.y, inter.size.x, inter.size.y)
			var src2 := Rect2((R.position - ar.position) / ar.size * tex.get_size(), R.size / ar.size * tex.get_size())
			draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(-1, 1), 0.0, Vector2(2.0 * mx, 0)))
			draw_texture_rect_region(tex, R, src2)
			draw_set_transform_matrix(xf)
		else:
			var src := Rect2((inter.position - ar.position) / ar.size * tex.get_size(), inter.size / ar.size * tex.get_size())
			draw_texture_rect_region(tex, inter, src)
	# the big name
	var fa := UI.anton(true)
	var nm: String = SEN[c]
	var nw := UI.text_w(fa, nm, 64)
	var nx := (-bw / 2.0 + bw * 0.20) if k == 1 else (bw / 2.0 - bw * 0.16 - nw)
	if nx + nw > x0 and nx < x1:
		draw_string(fa, Vector2(maxf(nx, x0 - 1000.0), 24.0), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Color(0, 0, 0, 0.85))
	draw_set_transform(Vector2.ZERO)
