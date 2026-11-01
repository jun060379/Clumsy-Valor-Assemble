extends RefCounted
## The night sky and the dawn fog (estelle-prototype.html drawNightSky 3081-3087, drawFog 3075-3078, nightK 3005).

const LIT := preload("res://scripts/lit.gd")

## how much of the night sky shows: from the sky tint's strength
static func night_k(T: Dictionary) -> float:
	return clampf((T["sky"].a - 0.33) / 0.33, 0.0, 1.0)

## 90 twinkling stars on seeded spots above the mountains, and a moon crossing from 18:30 for 11.5 h with a glow and
## two craters. Screen coordinates (the background canvas); `mtop` is the mountains' top, `w` the screen width.
static func draw_night(ci: CanvasItem, T: Dictionary, h: float, cam_x: float, mtop: float, w: float) -> void:
	var nk := night_k(T)
	if nk <= 0.02: return
	var t := Time.get_ticks_msec() / 1000.0
	for i in 90:
		var r1 := sin(i * 12.9898) * 43758.5453
		var h1 := r1 - floorf(r1)
		var r2 := sin(i * 78.233) * 43758.5453
		var h2 := r2 - floorf(r2)
		var x := fposmod(h1 * 1400.0 - cam_x * 0.03, 1000.0) - 50.0
		var y := 8.0 + h2 * (mtop - 20.0)
		if y > mtop - 6.0 or x > w: continue
		var tw := 0.55 + 0.45 * sin(t * (1.0 + h2 * 2.0) + i)
		var s := 2.0 if h1 > 0.9 else 1.0
		ci.draw_rect(Rect2(roundf(x), roundf(y), s, s), Color(1.0, 250.0 / 255.0, 235.0 / 255.0, nk * tw * (0.5 + 0.5 * h1)))
	var u := fposmod(fposmod(h, 24.0) - 18.5 + 24.0, 24.0) / 11.5
	if u > 1.0: return
	var mx := 80.0 + u * (w - 160.0)
	var my := mtop - 30.0 - sin(u * PI) * (mtop - 70.0)
	if my >= mtop - 14.0: return
	ci.draw_texture_rect(LIT.soft_tex(), Rect2(mx - 46.0, my - 46.0, 92.0, 92.0), false, Color(1.0, 248.0 / 255.0, 220.0 / 255.0, 0.35 * nk))
	mx = roundf(mx)
	my = roundf(my)
	ci.draw_circle(Vector2(mx, my), 11.0, Color(Color("#f4ecd0"), nk))
	ci.draw_rect(Rect2(mx - 4.0, my - 3.0, 3.0, 3.0), Color(Color("#d9cfae"), nk))
	ci.draw_rect(Rect2(mx + 3.0, my + 2.0, 4.0, 3.0), Color(Color("#d9cfae"), nk))

## dawn fog: soft flat banks drifting along each ground level around 06:20 (world coordinates; `levels` = [[y, a], ...])
static func draw_fog(ci: CanvasItem, lv, levels: Array) -> void:
	var hh := fposmod(lv.arena.tod_h, 24.0)
	var f := clampf(1.0 - absf(hh - 6.3) / 2.0, 0.0, 1.0)
	if f <= 0.01: return
	var t := Time.get_ticks_msec() / 1000.0
	var vr: Rect2 = lv.arena.view_rect()
	var tx := LIT.soft_tex()
	for gl in levels:
		var gy: float = gl[0]
		var a: float = gl[1]
		for i in 3:
			var cy := gy - 10.0 - i * 18.0
			if cy + 80.0 < vr.position.y or cy - 80.0 > vr.end.y: continue
			var off := fmod(t * (6.0 + i * 4.0), 600.0)
			var x := floorf((vr.position.x - off) / 600.0) * 600.0 + off - 600.0
			while x < vr.end.x + 600.0:
				ci.draw_texture_rect(tx, Rect2(x - 20.0, cy - 70.4, 640.0, 140.8), false, Color(225.0 / 255.0, 232.0 / 255.0, 245.0 / 255.0, 0.22 * f * a))
				x += 600.0
