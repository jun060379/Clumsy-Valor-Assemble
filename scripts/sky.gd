extends RefCounted
## The night sky and the dawn fog (estelle-prototype.html drawNightSky 3081-3087, drawFog 3075-3078, nightK 3005).

const LIT := preload("res://scripts/lit.gd")
## the stars' three brightness steps: exact colours shaders/amb_light.gdshader recognises (keep the two in step)
const STAR := [Color8(150, 156, 196), Color8(205, 208, 226), Color8(255, 250, 236)]

## how much of the night sky shows: from the clear sky's tint (arena.tod_now "nk"; the weather's grey doesn't count)
static func night_k(T: Dictionary) -> float:
	return T["nk"] if T.has("nk") else clampf((T["sky"].a - 0.33) / 0.33, 0.0, 1.0)

## 90 twinkling stars on seeded spots above the mountains, and a moon crossing from 18:30 for 11.5 h with a glow and
## two craters. Screen coordinates (the background canvas); `mtop` is the mountains' top, `w` the screen width.
## Stars (owner 2026-11-08: "밤 되면 서서히 나타나고. 반짝반짝 선명해지기도하고"): none under cloud; at dusk they come
## out one by one, the brightest first, each fading in; each twinkles, and now and then a bright one flares into a
## small cross for a moment.
static func draw_night(ci: CanvasItem, T: Dictionary, h: float, cam_x: float, mtop: float, w: float) -> void:
	var nk := night_k(T)
	if nk <= 0.02: return
	var sk: float = T.get("stars", nk)
	var t := Time.get_ticks_msec() / 1000.0
	for i in (90 if sk > 0.02 else 0):
		var r1 := sin(i * 12.9898) * 43758.5453
		var h1 := r1 - floorf(r1)
		var r2 := sin(i * 78.233) * 43758.5453
		var h2 := r2 - floorf(r2)
		var r3 := sin(i * 39.346) * 43758.5453
		var h3 := r3 - floorf(r3)
		var x := fposmod(h1 * 1400.0 - cam_x * 0.03, 1000.0) - 50.0
		var y := 8.0 + h2 * (mtop - 20.0)
		if y > mtop - 6.0 or x > w: continue
		# its turn to come out: the bright ones (h1 high) first; then its brightness in three steps (exact marker
		# colours, shaders/amb_light.gdshader keeps them out of the night's dark)
		var on := clampf((sk - (1.0 - h1) * 0.75) / 0.25, 0.0, 1.0)
		if on <= 0.0: continue
		var tw := 0.5 + 0.5 * sin(t * (1.2 + h2 * 2.5) + i * 1.7)
		var lv := int(floorf(on * (0.35 + 0.65 * h1) * (0.45 + 0.55 * tw) * 3.99)) - 1
		var px := roundf(x)
		var py := roundf(y)
		var s := 2.0 if h1 > 0.9 else 1.0
		# the flare: a bright star's moment (every 3-7 s, 0.4 s): full white, a small cross
		if h1 > 0.6 and on >= 1.0:
			var per := 3.0 + h3 * 4.0
			var ph := fposmod(t + h3 * 11.0, per)
			if ph < 0.4:
				var f := 1.0 - absf(ph / 0.4 * 2.0 - 1.0)
				lv = 2
				var arm := 2.0 if f > 0.5 else 1.0
				var ac: Color = STAR[1] if f > 0.5 else STAR[0]
				var m := floorf(s / 2.0)
				ci.draw_rect(Rect2(px - arm, py + m, arm, 1.0), ac)
				ci.draw_rect(Rect2(px + s, py + m, arm, 1.0), ac)
				ci.draw_rect(Rect2(px + m, py - arm, 1.0, arm), ac)
				ci.draw_rect(Rect2(px + m, py + s, 1.0, arm), ac)
		if lv >= 0: ci.draw_rect(Rect2(px, py, s, s), STAR[lv])
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
