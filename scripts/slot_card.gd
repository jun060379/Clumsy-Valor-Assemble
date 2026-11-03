extends RefCounted
## The save-slot card, shared by the title's 불러오기 list (title.gd) and the hub's 저장 picker (menu.gd): an ink card with
## a pink rim and spine leaning −2°, its heading (Korean in UI.bhs, the English small in Anton), one leaning row per save
## file — the file's name, the place, the in-game day and time, the adventurer level, the party's names and the real
## timestamp (save_game.gd header) — and a row of buttons under it (닫기, or a confirm's two). The picked row is pink with
## ink text and slides right a little; an empty row is greyed "비어 있음" (and on the title, unselectable).
## Everything here is drawing; the callers keep the state (which row is picked / pressed, when the card opened) and hit-
## test the rects this returns.

const UI := preload("res://scripts/ui_kit.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const PINK := Color("#ff3d7f")
const INK := Color("#0d0b10")
const CREAM := Color("#f3e9d2")
const ROSE := Color("#c48aa0")
const ROW_H := 0.105            # a row's height (fraction of H)
const ROW_GAP := 0.014

## the card's rect for n rows (fractions of the screen): to the right of the title's menu / the hub's list, its bottom
## at 0.95 H
static func rect(vs: Vector2, n: int, x0 := 0.42, w := 0.54) -> Rect2:
	var h := (0.11 + n * (ROW_H + ROW_GAP) + 0.085) * vs.y
	return Rect2(x0 * vs.x, 0.95 * vs.y - h, w * vs.x, h)

## the transform the card pops in with (u: 0..1 since it opened, `bk`)
static func xf(r: Rect2, vs: Vector2, u: float) -> Transform2D:
	return UIA.xf(r.get_center(), Vector2(0, 0.06 * vs.y * (1.0 - u)), deg_to_rad(-2.0), Vector2(0.9 + 0.1 * u, 0.9 + 0.1 * u))

## draw the card. rows: [{label, h (header or {}), on (selectable)}]; sel / press: row indices (-1 none); btns: button
## labels under the rows; bsel / bpress the same for them. Returns {"rows": [Rect2], "btns": [Rect2]} in screen space
## (the pop-in's transform applied to the hit areas' centres, so taps land where the eye sees them).
static func draw(ci: CanvasItem, vs: Vector2, r: Rect2, title: String, en: String, rows: Array, sel: int, press: int, btns: Array, bsel: int, bpress: int, u: float, note := "") -> Dictionary:
	var W := vs.x
	var H := vs.y
	var m := xf(r, vs, u)
	var a := clampf(u * 1.6, 0.0, 1.0)
	ci.draw_set_transform_matrix(m)
	# the card: the pink rim, the ink body, the spine
	var shape := [[0, 3], [100, 0], [99, 100], [1, 97]]
	ci.draw_colored_polygon(UI.clip(Rect2(r.position + Vector2(5, 5), r.size), shape), Color(PINK, 0.9 * a))
	ci.draw_colored_polygon(UI.clip(r, shape), Color(INK, 0.96 * a))
	ci.draw_colored_polygon(UI.clip(Rect2(r.position, Vector2(0.006 * W, r.size.y)), [[0, 2], [100, 2], [100, 98], [0, 98]]), Color(PINK, a))
	# the heading
	var fb := UI.bhs()
	var fs_t := int(0.045 * H)
	var tx := r.position.x + 0.03 * W
	var ty := r.position.y + 0.07 * H
	ci.draw_string(fb, Vector2(tx, ty), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_t, Color(CREAM, a))
	var fe := UI.anton(false, 3)
	ci.draw_string(fe, Vector2(tx + UI.text_w(fb, title, fs_t) + 0.016 * W, ty), en, HORIZONTAL_ALIGNMENT_LEFT, -1, int(0.022 * H), Color(PINK, a))
	if note != "":
		var fn := UI.noto()
		var fsn := int(0.026 * H)
		ci.draw_string(fn, Vector2(r.end.x - 0.03 * W - UI.text_w(fn, note, fsn), ty), note, HORIZONTAL_ALIGNMENT_LEFT, -1, fsn, Color(ROSE, a))
	# the rows
	var out_rows: Array = []
	var rh := ROW_H * H
	var lean := rh * tan(deg_to_rad(8.0))
	var fn2 := UI.noto()
	var fs_l := int(0.034 * H)
	var fs_s := int(0.025 * H)
	var fa := UI.anton(false, 1)
	var y := r.position.y + 0.11 * H
	for i in rows.size():
		var row: Dictionary = rows[i]
		var hd: Dictionary = row.get("h", {})
		var empty := hd.is_empty()
		var en_on: bool = row.get("on", true)
		var picked := i == sel
		var x := r.position.x + 0.03 * W + (0.012 * W if picked else 0.0)
		var w := r.size.x - 0.06 * W - lean
		var sc := 0.97 if press == i else 1.0
		var ra := a * (1.0 if picked else (0.85 if en_on else 0.45))
		var rr := Rect2(x, y, w, rh)
		ci.draw_set_transform_matrix(m * UIA.xf(rr.get_center() + Vector2(lean * 0.5, 0), Vector2.ZERO, 0.0, Vector2(sc, sc)))
		UI.para(ci, x + 3.0, y + 3.0, w, rh, lean, Color(PINK if not picked else CREAM, 0.55 * ra))
		UI.para(ci, x, y, w, rh, lean, Color(PINK if picked else Color(0.16, 0.13, 0.19), ra))
		var tc := INK if picked else CREAM
		var sc2 := Color(INK, 0.8) if picked else ROSE
		var lx := x + lean + 0.018 * W
		var l1 := y + rh * 0.42
		var l2 := y + rh * 0.82
		ci.draw_string(fb, Vector2(lx, l1), String(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_l, Color(tc, ra))
		var lw := UI.text_w(fb, String(row["label"]), fs_l)
		if empty:
			ci.draw_string(fn2, Vector2(lx + lw + 0.02 * W, l1), "비어 있음", HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s, Color(sc2, ra))
		else:
			ci.draw_string(fn2, Vector2(lx + lw + 0.02 * W, l1), String(hd["place"]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s, Color(tc, ra))
			var lv := "LV %d" % int(hd["lv"])
			var fs_lv := int(0.032 * H)
			ci.draw_string(fa, Vector2(x + w + lean * 0.4 - 0.02 * W - UI.text_w(fa, lv, fs_lv), l1), lv, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_lv, Color(INK if picked else PINK, ra))
			var who := " · ".join(hd["party"])
			var s2 := "%d일째 %s  ·  %s" % [int(hd["day"]), String(hd["time"]), who]
			ci.draw_string(fn2, Vector2(lx - lean * 0.45, l2), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s, Color(sc2, ra))
			var wh := String(hd["when"])
			ci.draw_string(fn2, Vector2(x + w - 0.02 * W - UI.text_w(fn2, wh, fs_s), l2), wh, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_s, Color(sc2, ra))
		ci.draw_set_transform_matrix(m)
		out_rows.append(_hit(m, Rect2(x, y, w + lean, rh)))
		y += rh + ROW_GAP * H
	# the buttons, right-aligned under the rows
	var out_btns: Array = []
	var bh := 0.058 * H
	var bw := 0.14 * W
	var bx := r.end.x - 0.03 * W - btns.size() * bw - (btns.size() - 1) * 0.015 * W
	var by := r.end.y - 0.075 * H
	var fs_b := int(0.03 * H)
	for k in btns.size():
		var br := Rect2(bx + k * (bw + 0.015 * W), by, bw, bh)
		var on := k == bsel
		var s := 0.96 if bpress == k else 1.0
		ci.draw_set_transform_matrix(m * UIA.xf(br.get_center(), Vector2.ZERO, 0.0, Vector2(s, s)))
		UI.para(ci, br.position.x, br.position.y, bw, bh, bh * 0.3, Color(PINK if on else CREAM, a))
		var lab := String(btns[k])
		ci.draw_string(fb, Vector2(br.get_center().x + bh * 0.15 - UI.text_w(fb, lab, fs_b) / 2.0, br.position.y + bh * 0.5 + fs_b * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs_b, Color(INK, a))
		ci.draw_set_transform_matrix(m)
		out_btns.append(_hit(m, Rect2(br.position, br.size + Vector2(bh * 0.3, 0))))
	ci.draw_set_transform(Vector2.ZERO)
	return {"rows": out_rows, "btns": out_btns}

## a hit rect in screen space: the rect, moved by where the card's transform puts its centre (the slight tilt ignored)
static func _hit(m: Transform2D, r: Rect2) -> Rect2:
	var c := m * r.get_center()
	return Rect2(c - r.size / 2.0, r.size).grow(3.0)

## the 불러오기 / 저장 rows from the save files: [{key, label, file, h, on}]; `empty_on`: empty rows can be picked (저장)
static func rows_of(save, with_auto: bool, empty_on: bool) -> Array:
	var out: Array = []
	for e in save.files():
		if e[0] == "auto" and not with_auto: continue
		var h: Dictionary = save.header(e[2])
		out.append({"key": e[0], "label": e[1], "file": e[2], "h": h, "on": empty_on or not h.is_empty()})
	return out

## the next selectable row from i in direction d (wrapping), i itself when none other is
static func step(rows: Array, i: int, d: int) -> int:
	var n := rows.size()
	for k in range(1, n + 1):
		var j := posmod(i + d * k, n)
		if rows[j]["on"]: return j
	return i
