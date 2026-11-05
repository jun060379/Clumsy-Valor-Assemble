extends RefCounted
## The town's small life: wind and gusts, trampled grass, footstep dust, rustling bushes, props that jig when struck (and spill
## apples), the cat on the crate, butterflies, fish in the river, wading splashes, pigeons, fireflies, and the weather (rain / snow). Ported from the prototype's LIFE / lifeUpdate /
## drawLife / BIRDS / drawFlies / drawWeather. Everything here works in world coordinates and only for what is near the screen.

const BLADE_C := [Color("#4f6b34"), Color("#6f8f44"), Color("#97ad58"), Color("#bccd78")]

var town
var arena
# wind
var gust := 0.0
var gust_t := 2500.0
var prev_gust := 0.0
# the player's last landing (grass flattens around it)
var land := {}
var prev_on := true
var rust := {}               # deco_back index -> 0..1
var jig := {}                # deco_props index -> 0..1
var jcd := {}
var apples: Array = []
var fish: Array = []
var fish_t := 4000.0
var birds: Array = []
var bird_t := 4000.0
var rain: Array = []
var snow: Array = []
var flies: Array = []        # fireflies (two meadows: the lower plaza / the valley)
var sil = null               # someone walking past a lit hall window: {wx, wy, t, dir, life} (town.gd draws it)
var sil_t := 5000.0
var prev_f := -1
var cat = null               # the cat on the second crate (town only): {x, y, st: sleep|sit|startle, t, dir, yawn, z}
var bflies: Array = []       # butterflies by day in fair weather: {ax, ay, x, y, ph, t, flee, c}
const BFLY_C := [Color("#f3efe0"), Color("#f2d36b"), Color("#9fc6f0")]


func _init(tn) -> void:
	town = tn
	arena = tn.arena
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 24:
		var z: Array = [2600.0, 6000.0] if i < 12 else [6650.0, 9350.0]
		flies.append({"x0": rng.randf_range(z[0], z[1]), "y0": town.LOWF - 200.0 + rng.randf() * 170.0, "ph": rng.randf() * 99.0, "sp": 0.3 + rng.randf() * 0.5})

func now() -> float:
	return Time.get_ticks_msec()

func weather() -> String:
	return arena.weather

## 0 by day .. 1 at night (from the sky tint)
func night_k() -> float:
	var T: Dictionary = arena.tod_now()
	var sky: Color = T["sky"]
	return clampf((sky.a - 0.33) / 0.33, 0.0, 1.0)


# ---------- update ----------
func step(dt: float) -> void:
	var P = arena.player
	var t := now()
	var vr: Rect2 = arena.view_rect()
	# wind: gusts come and go; a strong one throws leaves across the screen
	gust_t -= dt
	if gust_t <= 0.0:
		gust = 1.6 if randf() < 0.35 else 1.0
		gust_t = 2500.0 + randf() * 4500.0
	gust *= pow(0.9993, dt)
	if gust > 0.95 and prev_gust <= 0.95:
		var n := 22 if gust > 1.2 else 10
		for i in n:
			town.tfx.append({"k": "leaf", "x": vr.position.x - 40.0 - randf() * 200.0, "y": vr.position.y + 60.0 + randf() * (vr.size.y - 100.0), "vx": 0.12 + randf() * 0.15,
				"vy": 0.01 + randf() * 0.03, "t": 0.0, "life": 5000.0 + randf() * 2000.0, "ph": randf() * 9.0, "c": Color("#6f8f44") if randf() < 0.5 else Color("#b8a64a")})
	prev_gust = gust
	# someone walks past a lit window now and then
	sil_t -= dt
	if sil_t <= 0.0:
		sil_t = 5000.0 + randf() * 7000.0
		if town.hall_win() > 0.5:
			var w: Array = town.HALL_WIN[randi() % town.HALL_WIN.size()]
			sil = {"wx": float(w[0]), "wy": float(w[1]), "t": 0.0, "dir": -1.0 if randf() < 0.5 else 1.0, "life": 2200.0 + randf() * 1200.0}
	if sil != null:
		sil["t"] += dt
		if sil["t"] > sil["life"]: sil = null
	# landing flattens the grass around you
	if P.on and not prev_on: land = {"x": P.position.x, "y": P.position.y, "t": t}
	prev_on = P.on
	# footsteps kick up a little dust
	if P.on and P.anim == "run" and P.f != prev_f and P.f in P.SK.steps(P.who, "run"): puff(arena, P.position.x - P.dir * 8.0, P.position.y, 2)
	prev_f = P.f
	# bushes rustle as you push through
	for i in town.deco_back.size():
		var d: Array = town.deco_back[i]
		var k: String = d[0]
		if k.contains("tree"): continue
		var im: Texture2D = town.tex[k]
		var cx: float = d[1] + im.get_width() / 2.0
		var r: float = rust.get(i, 0.0) * pow(0.996, dt)
		if absf(P.position.x - cx) < im.get_width() * 0.5 and absf(P.position.y - d[2]) < 24.0 and absf(P.vx) > 0.05:
			r = minf(1.0, r + dt / 180.0)
			if randf() < dt / 90.0:
				town.tfx.append({"k": "leaf", "x": cx + (randf() - 0.5) * im.get_width() * 0.6, "y": d[2] - im.get_height() * 0.6, "vx": (randf() - 0.5) * 0.05, "vy": -0.03,
					"t": 0.0, "life": 2200.0, "ph": randf() * 9.0, "c": Color("#6f8f44")})
		rust[i] = r
	# barrels and crates jump when struck; some spill an apple
	var at = P.cur_atk() if P.attacking() else null
	if at != null and P.f >= at["hit"][0] and P.f <= at["hit"][1]:
		var b: Array = at["box"]
		var bw: float = b[2] * P.CSCALE * P.MELEE_K
		var bx: float = P.position.x + b[0] * P.CSCALE * P.MELEE_K if P.dir > 0 else P.position.x - b[0] * P.CSCALE * P.MELEE_K - bw
		var by: float = P.position.y + b[1] * P.CSCALE
		var bh: float = b[3] * P.CSCALE
		for i in town.deco_props.size():
			var d: Array = town.deco_props[i]
			if jcd.get(i, 0.0) > t: continue
			var im: Texture2D = town.tex[d[0]]
			var s: float = town.ks(d[0])
			var iw: float = im.get_width() * s
			var x0: float = d[1]
			var y0: float = d[2] - im.get_height() * s
			if bx < x0 + iw and bx + bw > x0 and by < d[2] and by + bh > y0:
				jig[i] = 1.0
				jcd[i] = t + 380.0
				arena.sfx("guard", 0.25)
				puff(arena, x0 + iw / 2.0, d[2], 3)
				var dk: String = d[0]
				if (dk.contains("barrel") or dk.contains("crate")) and randf() < 0.3:
					apples.append({"x": x0 + iw / 2.0, "y": y0 + 4.0, "vx": P.dir * (0.08 + randf() * 0.1), "vy": -0.35 - randf() * 0.15, "t": 0.0})
	for i in jig.keys():
		jig[i] = jig[i] * pow(0.99, dt)
		if jig[i] < 0.01: jig.erase(i)
	_cat(dt, P)
	# fish jump in the river
	fish_t -= dt
	if fish_t <= 0.0:
		fish_t = 4500.0 + randf() * 6000.0
		if town.RIV1 > vr.position.x and town.RIV0 < vr.end.x:
			var fx: float = town.RIV0 + 30.0 + randf() * (town.RIV1 - town.RIV0 - 90.0)
			fish.append({"x": fx, "dx": (-1.0 if randf() < 0.5 else 1.0) * (40.0 + randf() * 30.0), "t": 0.0})
			_splash(fx, 0.18)
	for f in fish:
		f["t"] += dt
		if f["t"] >= 700.0: _splash(f["x"] + f["dx"], 0.15)
	fish = fish.filter(func(f): return f["t"] < 700.0)
	# wading the river: town_fx.gd (splashes and rings)
	# apples roll and fade
	for a in apples:
		a["t"] += dt
		a["vy"] += 0.0016 * dt
		a["x"] += a["vx"] * dt
		a["y"] += a["vy"] * dt
		var gy: float = town.floor_at(a["x"])
		if a["y"] > gy - 3.0:
			a["y"] = gy - 3.0
			a["vy"] = -a["vy"] * 0.35
			a["vx"] *= 0.92
			if absf(a["vy"]) < 0.03: a["vy"] = 0.0
	apples = apples.filter(func(a): return a["t"] < 6000.0)
	_bflies(dt, vr, P)
	_birds(dt, vr)
	_weather(dt, vr)

## dust(x, y, n): the prototype's soft dust puffs (arena fx 'dust')
static func puff(ar, x: float, y: float, n: int) -> void:
	for i in n:
		ar.fx.append({"k": "dust", "x": x + (randf() - 0.5) * 40.0, "y": y - randf() * 8.0, "vx": (randf() - 0.5) * 0.12, "vy": -0.05 - randf() * 0.08,
			"r": 4.0 + randf() * 5.0, "t": 0.0, "life": 300.0})

## the cat on the second crate: sleeps (breathing, z's); within 160 px it sits up and watches you, sometimes yawning;
## a swing within 140 px startles it (puffed up), then it sits; left alone 3.5 s it curls up again
func _cat(dt: float, P) -> void:
	if town.kind != "town": return
	if cat == null:
		var cr: Array = town.deco_props[2]
		var im: Texture2D = town.tex[cr[0]]
		var s: float = town.ks(cr[0])
		cat = {"x": cr[1] + im.get_width() * s / 2.0, "y": cr[2] - im.get_height() * s + 2.0, "st": "sleep", "t": 0.0, "dir": -1.0, "yawn": 0.0, "z": 0.0}
	var c: Dictionary = cat
	c["t"] += dt
	var d := Vector2(P.position.x - c["x"], (P.position.y - c["y"]) * 1.2).length()
	var atk_near: bool = P.attacking() and d < 140.0
	if atk_near and c["st"] != "startle":
		c["st"] = "startle"
		c["t"] = 0.0
		arena.sfx("guard", 0.15)
	elif c["st"] == "startle":
		if c["t"] > 700.0:
			c["st"] = "sit"
			c["t"] = 0.0
	elif d < 160.0:
		if c["st"] == "sleep":
			c["st"] = "sit"
			c["t"] = 0.0
			c["yawn"] = 600.0 if randf() < 0.6 else 0.0
		c["dir"] = -1.0 if P.position.x < c["x"] else 1.0
	elif c["st"] == "sit" and c["t"] > 3500.0:
		c["st"] = "sleep"
		c["t"] = 0.0
	if c["yawn"] > 0.0: c["yawn"] -= dt
	c["z"] += dt

## butterflies by day in clear weather: up to three, they wander on two sines and flee from you (and from the weather)
func _bflies(dt: float, vr: Rect2, P) -> void:
	var T: Dictionary = arena.tod_now()
	var fair: bool = weather() == "clear" and T["sun"] > 0.25
	if fair and bflies.size() < 3 and randf() < dt / 2500.0:
		var x := vr.position.x + 60.0 + randf() * (vr.size.x - 120.0)
		var gy: float = town.floor_at(x)
		bflies.append({"ax": x, "ay": gy - 30.0 - randf() * 40.0, "x": x, "y": gy - 40.0, "ph": randf() * 9.0, "t": 0.0, "flee": false, "c": BFLY_C[randi() % 3]})
	var keep := []
	for b in bflies:
		b["t"] += dt
		if not fair: b["flee"] = true
		if not b["flee"] and Vector2(P.position.x - b["x"], P.position.y - 60.0 - b["y"]).length() < 80.0: b["flee"] = true
		if b["flee"]:
			b["x"] += (-1.0 if b["x"] < P.position.x else 1.0) * 0.1 * dt
			b["y"] -= 0.08 * dt
			if b["y"] > vr.position.y - 60.0 and b["x"] > vr.position.x - 80.0 and b["x"] < vr.end.x + 80.0: keep.append(b)
			continue
		var s: float = b["t"] / 1000.0
		b["x"] = b["ax"] + sin(s * 0.7 + b["ph"]) * 50.0 + sin(s * 1.9 + b["ph"]) * 12.0
		b["y"] = b["ay"] + sin(s * 1.3 + b["ph"] * 2.0) * 18.0 + sin(s * 3.1) * 4.0
		if b["x"] > vr.position.x - 200.0 and b["x"] < vr.end.x + 200.0: keep.append(b)
	bflies = keep

func _splash(x: float, v: float) -> void:
	if town.fxa != null: town.fxa.splash(x, town.LOWF + 20.0, 6, v > 0.17)

## rain and snow fall to the upper surface (the lower plaza sits under the terrace and stays dry)
func surf_top(x: float) -> float:
	if x < town.SX0: return town.G
	if x < town.STX1 + town.SL: return town.up_y(x)
	return town.LOWF

func _weather(dt: float, vr: Rect2) -> void:
	var vx0 := vr.position.x - 60.0
	var vx1 := vr.end.x + 60.0
	var cy := vr.position.y
	var k := weather()
	if k == "rain":
		while rain.size() < 170:
			rain.append({"x": randf_range(vx0, vx1), "y": cy - 20.0 - randf() * vr.size.y, "v": 0.9 + randf() * 0.35})
		for d in rain:
			d["y"] += d["v"] * dt
			d["x"] += (0.12 + gust * 0.15) * dt
			var gy := minf(surf_top(d["x"]), town.fxa.roof_y(d["x"]) if town.fxa != null else INF)
			if d["x"] > vx1 + 400.0 or d["x"] < vx0 - 400.0 or d["y"] > vr.end.y + 400.0:
				# the view jumped (a teleport): fill the screen again
				d["x"] = randf_range(vx0, vx1)
				d["y"] = cy - 20.0 - randf() * vr.size.y
				continue
			if d["y"] > gy or d["x"] > vx1 or d["x"] < vx0 - 80.0:
				if d["y"] > gy and randf() < 0.6 and town.fxa != null: town.fxa.rain_hit(d["x"], gy)
				d["x"] = randf_range(vx0, vx1) - 60.0
				d["y"] = cy - 20.0 - randf() * 60.0
	else:
		rain.clear()
	if k == "snow":
		var t := now()
		while snow.size() < 160:
			snow.append({"x": randf_range(vx0, vx1), "y": cy + randf() * vr.size.y, "v": 0.03 + randf() * 0.04, "ph": randf() * 9.0, "s": 2 if randf() < 0.3 else 1})
		for d in snow:
			d["y"] += d["v"] * dt
			d["x"] += (sin(t / 900.0 + d["ph"]) * 0.02 + gust * 0.05) * dt
			if d["x"] > vx1 + 400.0 or d["x"] < vx0 - 400.0 or d["y"] > vr.end.y + 400.0:
				d["x"] = randf_range(vx0, vx1)
				d["y"] = cy + randf() * vr.size.y
			elif d["y"] > surf_top(d["x"]) or d["x"] > vx1 + 40.0 or d["x"] < vx0 - 40.0:
				d["x"] = randf_range(vx0, vx1)
				d["y"] = cy - 10.0
	else:
		snow.clear()


# ---------- pigeons: drop in now and then, peck about, scatter when you come close or swing ----------
func _perches(vr: Rect2) -> Array:
	var s := []
	var x0 := vr.position.x - 60.0
	var x1 := vr.end.x + 60.0
	for i in 6:
		var x := randf_range(x0, x1)
		s.append(Vector2(x, town.floor_at(x)))
	for p in town.tpl:
		if p.has("climb") and p.x1 > x0 and p.x0 < x1 and absf(p.y1 - p.y0) < (p.x1 - p.x0) * 0.25:
			var x2 := clampf(randf_range(x0, x1), p.x0 + 6.0, p.x1 - 6.0)
			if x2 > p.x0 and x2 < p.x1: s.append(Vector2(x2, town.plat_y(p, x2)))
	return s

func _birds(dt: float, vr: Rect2) -> void:
	var P = arena.player
	bird_t -= dt
	var on := birds.filter(func(b): return b["st"] != "out").size()
	if bird_t <= 0.0:
		bird_t = 5000.0 + randf() * 9000.0
		if on < 6 and weather() == "clear":
			var ps := _perches(vr)
			var n := 1 + randi() % 3
			var base: Vector2 = ps[randi() % ps.size()]
			var from := -1.0 if randf() < 0.5 else 1.0
			var on_ground := absf(base.y - town.floor_at(base.x)) <= 2.0
			for i in n:
				var tx := base.x + (i - n / 2.0) * 14.0 + randf() * 6.0
				var ty: float = town.floor_at(tx) if on_ground else base.y
				birds.append({"x": vr.get_center().x + from * (vr.size.x / 2.0 + 60.0 + i * 30.0), "y": vr.position.y - 40.0 - randf() * 60.0, "tx": tx, "ty": ty, "st": "in",
					"t": randf() * 1000.0, "dir": -from, "peck": 0.0, "hop": 0.0, "next": 800.0 + randf() * 1500.0, "vx": 0.0, "vy": 0.0})
	var atk: bool = P.attacking() or P.anim == "dash" or P.anim == "airdash"
	var keep := []
	for b in birds:
		b["t"] += dt
		if b["st"] == "in":
			var dv := Vector2(b["tx"] - b["x"], b["ty"] - b["y"])
			var d := dv.length()
			var sp := minf(0.35, 0.08 + d * 0.0012)
			b["dir"] = 1.0 if dv.x >= 0.0 else -1.0
			if d < 3.0:
				b["x"] = b["tx"]
				b["y"] = b["ty"]
				b["st"] = "ground"
				b["t"] = 0.0
			else:
				b["x"] += dv.x / d * sp * dt
				b["y"] += dv.y / d * sp * dt
		elif b["st"] == "ground":
			var pd := Vector2(P.position.x - b["x"], (P.position.y - b["y"]) * 1.5).length()
			if pd < 110.0 or (atk and pd < 260.0):
				_flee(b, P.position.x, 0.0)
				for o in birds:
					if not is_same(o, b) and o["st"] == "ground" and absf(o["x"] - b["x"]) < 80.0:
						_flee(o, P.position.x, -randf() * 120.0)
			else:
				b["next"] -= dt
				if b["peck"] > 0.0: b["peck"] -= dt
				if b["hop"] > 0.0:
					b["hop"] -= dt
					b["x"] += b["dir"] * 0.03 * dt
				if b["next"] <= 0.0:
					var r := randf()
					if r < 0.5: b["peck"] = 380.0
					elif r < 0.75: b["hop"] = 220.0
					else: b["dir"] = -b["dir"]
					b["next"] = 500.0 + randf() * 1600.0
		elif b["t"] >= 0.0:
			b["x"] += b["vx"] * dt
			b["y"] += b["vy"] * dt
			b["vy"] -= 0.00012 * dt
			if b["y"] < vr.position.y - 120.0 or b["x"] < vr.position.x - 150.0 or b["x"] > vr.end.x + 150.0: continue
		keep.append(b)
	birds = keep

func _flee(b: Dictionary, px: float, t0: float) -> void:
	b["st"] = "out"
	b["vx"] = (-1.0 if b["x"] < px else 1.0) * (0.16 + randf() * 0.14)
	b["vy"] = -0.25 - randf() * 0.15
	b["dir"] = 1.0 if b["vx"] > 0.0 else -1.0
	b["t"] = t0


# ---------- drawing ----------
## grass in front of the feet: single-colour blades bend with the wind (gusts roll across as a wave) and part around you
var bl_r := PackedFloat32Array()
var bl_h := PackedByteArray()
var bl_c := PackedByteArray()

func _hsh(n: float) -> float:
	var s := sin(n * 12.9898) * 43758.5453
	return s - floorf(s)

func build_blades() -> void:
	var n := int(town.TOWN_W / 2.0) + 8
	bl_r.resize(n)
	bl_h.resize(n)
	bl_c.resize(n)
	for i in n:
		var r := _hsh(i * 2.0)
		bl_r[i] = r
		if r < 0.45:
			bl_h[i] = 0
			continue
		var r2 := _hsh(i * 2.0 + 0.37)
		var tall := r2 > 0.93
		bl_h[i] = 7 + int(_hsh(i * 2.0 + 1.1) * 4.0) if tall else 2 + int(r2 * 5.0)
		bl_c[i] = mini(3, int(r2 * 3.2) + (1 if tall else 0))

func draw_blades(ci: CanvasItem, x0: float, x1: float, f: Callable) -> void:
	if bl_h.is_empty(): build_blades()
	var P = arena.player
	var vr: Rect2 = arena.view_rect()
	var t := now() / 1000.0
	var i0 := maxi(0, ceili(maxf(x0, vr.position.x - 10.0) / 2.0))
	var i1 := mini(bl_h.size() - 1, ceili(minf(x1, vr.end.x + 10.0) / 2.0))
	var lt: float = now() - float(land.get("t", -1e9))
	for i in range(i0, i1):
		var hg: int = bl_h[i]
		if hg == 0: continue
		var x := i * 2.0
		var fy: float = f.call(x)
		if fy < vr.position.y - 20.0 or fy > vr.end.y + 30.0: continue
		var base := roundf((fy - town.SURFR + 7.0) / 2.0) * 2.0
		var w := 0.25 + 0.5 * sin(x * 0.011 - t * 1.6) + 0.3 * sin(x * 0.037 - t * 2.9 + bl_r[i] * 3.0) + gust * 1.1 * (0.5 + 0.5 * sin(x * 0.006 - t * 4.2))
		var bend := w * pow(hg / 4.0, 1.4) * 1.4
		var dxp: float = x - P.position.x
		if absf(dxp) < 30.0 and absf(P.position.y - fy) < 14.0:
			var kk := 1.0 - absf(dxp) / 30.0
			bend += (1.0 if dxp >= 0.0 else -1.0) * kk * kk * 5.5
		if lt < 450.0 and absf(x - land["x"]) < 70.0 and absf(land["y"] - fy) < 14.0:
			var k2: float = (1.0 - absf(x - land["x"]) / 70.0) * (1.0 - lt / 450.0)
			bend += (1.0 if x >= land["x"] else -1.0) * k2 * 7.0
		var c: Color = BLADE_C[bl_c[i]]
		for y in hg:
			var u := (y + 1.0) / hg
			ci.draw_rect(Rect2(x + roundf(bend * u * u) * 2.0, base - (y + 1) * 2.0, 2.0, 2.0), BLADE_C[0] if y == 0 else c)

## apples, fish, pigeons and the weather, over the scene
func draw_front(ci: CanvasItem) -> void:
	var t := now()
	for a in apples:
		var al: float = 1.0 - (a["t"] - 5000.0) / 1000.0 if a["t"] > 5000.0 else 1.0
		var x := roundf(a["x"] / 2.0) * 2.0
		var y := roundf(a["y"] / 2.0) * 2.0
		ci.draw_rect(Rect2(x - 3, y - 3, 6, 6), Color(Color("#b8322c"), al))
		ci.draw_rect(Rect2(x - 1, y - 3, 2, 2), Color(Color("#e2665a"), al))
		ci.draw_rect(Rect2(x, y - 5, 2, 2), Color(Color("#5a3a1a"), al))
	for f in fish:
		var u: float = f["t"] / 700.0
		var x: float = f["x"] + f["dx"] * u
		var y: float = town.LOWF + 18.0 - sin(u * PI) * 46.0
		var sx := -1.0 if f["dx"] < 0.0 else 1.0
		var rot: float = atan2(-cos(u * PI) * 46.0 * PI, f["dx"]) * sx
		ci.draw_set_transform(Vector2(roundf(x), roundf(y)), rot, Vector2(sx, 1))
		ci.draw_rect(Rect2(-6, -2, 10, 4), Color("#c9d6dc"))
		ci.draw_rect(Rect2(-6, 0, 10, 2), Color("#8aa0aa"))
		ci.draw_rect(Rect2(4, -1, 2, 2), Color("#222222"))
		ci.draw_rect(Rect2(-10, -3, 4, 6), Color("#9fb4bd"))
	ci.draw_set_transform(Vector2.ZERO)
	# butterflies: wings open / shut every 90 ms
	for b in bflies:
		var x := roundf(b["x"] / 2.0) * 2.0
		var y := roundf(b["y"] / 2.0) * 2.0
		var bc: Color = b["c"]
		ci.draw_rect(Rect2(x, y - 2, 2, 5), Color("#3a2a20"))
		if int((t + b["ph"] * 100.0) / 90.0) % 2 == 1:
			ci.draw_rect(Rect2(x - 4, y - 4, 4, 4), bc)
			ci.draw_rect(Rect2(x + 2, y - 4, 4, 4), bc)
			ci.draw_rect(Rect2(x - 2, y + 1, 2, 2), bc)
			ci.draw_rect(Rect2(x + 2, y + 1, 2, 2), bc)
		else:
			ci.draw_rect(Rect2(x - 2, y - 6, 2, 5), bc)
			ci.draw_rect(Rect2(x + 2, y - 6, 2, 5), bc)
	_draw_birds(ci, t)
	# weather
	if weather() == "rain" and not rain.is_empty():
		# streaks on the 1-px grid (owner 2026-11-06): a bright head, a fainter tail stepping back along the wind
		var sl := 0.12 + gust * 0.15
		var hc := Color(200 / 255.0, 220 / 255.0, 240 / 255.0, 0.6)
		var tc := Color(170 / 255.0, 195 / 255.0, 225 / 255.0, 0.3)
		for d in rain:
			var X := roundf(d["x"])
			var Y := roundf(d["y"])
			ci.draw_rect(Rect2(X, Y - 3.0, 1, 3), hc)
			ci.draw_rect(Rect2(X - roundf(sl * 6.0), Y - 9.0, 1, 6), tc)
	elif weather() == "snow":
		for d in snow:
			var s := 4.0 if d["s"] > 1 else 2.0
			ci.draw_rect(Rect2(roundf(d["x"] / 2.0) * 2.0, roundf(d["y"] / 2.0) * 2.0, s, s), Color(1, 1, 1, 0.95) if d["s"] > 1 else Color(0.94, 0.957, 1.0, 0.75))

func _draw_birds(ci: CanvasItem, t: float) -> void:
	var body := Color("#8d93a3")
	var dark := Color("#5f6474")
	var wing := Color("#737989")
	var belly := Color("#a9aebb")
	var beak := Color("#c9a07a")
	var eye := Color("#111111")
	for b in birds:
		var X := roundf(b["x"] / 2.0) * 2.0
		var Y := roundf(b["y"] / 2.0) * 2.0
		ci.draw_set_transform(Vector2(X, Y), 0.0, Vector2(b["dir"] * 2.0, 2.0))
		var neck := Color("#5f8f7e") if int(t / 300.0 + b["x"]) % 2 == 1 else Color("#7d6292")
		if b["st"] == "ground" and not (b["hop"] > 0.0 and int(t / 60.0) % 2 == 1):
			var pk: bool = b["peck"] > 0.0 and int(b["peck"] / 95.0) % 2 == 0
			ci.draw_rect(Rect2(-1, -1, 1, 1), Color("#d48a8a"))
			ci.draw_rect(Rect2(1, -1, 1, 1), Color("#d48a8a"))
			ci.draw_rect(Rect2(-5, -4, 2, 1), dark)
			ci.draw_rect(Rect2(-3, -5, 6, 3), body)
			ci.draw_rect(Rect2(-2, -3, 4, 1), belly)
			ci.draw_rect(Rect2(-3, -5, 4, 2), wing)
			ci.draw_rect(Rect2(-2, -4, 3, 1), dark)
			if pk:
				ci.draw_rect(Rect2(3, -4, 1, 2), neck)
				ci.draw_rect(Rect2(4, -3, 2, 2), dark)
				ci.draw_rect(Rect2(6, -2, 1, 1), beak)
				ci.draw_rect(Rect2(5, -3, 1, 1), eye)
			else:
				ci.draw_rect(Rect2(2, -7, 2, 2), neck)
				ci.draw_rect(Rect2(2, -9, 3, 2), dark)
				ci.draw_rect(Rect2(4, -8, 1, 1), eye)
				ci.draw_rect(Rect2(5, -8, 1, 1), beak)
		else:
			var up := int((t + b["x"] * 7.0) / (70.0 if b["st"] == "out" else 110.0)) % 2 == 0
			ci.draw_rect(Rect2(-5, -5, 2, 1), dark)
			ci.draw_rect(Rect2(-3, -6, 6, 3), body)
			ci.draw_rect(Rect2(-2, -4, 4, 1), belly)
			ci.draw_rect(Rect2(3, -7, 2, 2), dark)
			ci.draw_rect(Rect2(5, -6, 1, 1), beak)
			ci.draw_rect(Rect2(4, -7, 1, 1), eye)
			if up:
				ci.draw_rect(Rect2(-2, -10, 3, 4), wing)
				ci.draw_rect(Rect2(-1, -11, 2, 1), dark)
			else:
				ci.draw_rect(Rect2(-2, -3, 3, 3), wing)
				ci.draw_rect(Rect2(-1, 0, 2, 1), dark)
	ci.draw_set_transform(Vector2.ZERO)

## fireflies: drawn on the label canvas (not dimmed by the night ambient), brighter the darker the sky
func draw_flies(ci: CanvasItem, glow_tex: Texture2D) -> void:
	var t := now() / 1000.0
	var vr: Rect2 = arena.view_rect()
	var fk := 0.15 + 0.85 * night_k()
	for f in flies:
		var x: float = f["x0"] + sin(t * f["sp"] + f["ph"]) * 40.0 + sin(t * f["sp"] * 2.3 + f["ph"]) * 12.0
		var y: float = f["y0"] + cos(t * f["sp"] * 1.3 + f["ph"]) * 22.0
		if x < vr.position.x - 20.0 or x > vr.end.x + 20.0 or y < vr.position.y - 20.0 or y > vr.end.y + 20.0: continue
		var b := maxf(0.0, sin(t * 2.2 + f["ph"] * 3.0)) * fk
		if b < 0.05: continue
		ci.draw_texture_rect(glow_tex, Rect2(x - 10.0, y - 10.0, 20.0, 20.0), false, Color(210 / 255.0, 1.0, 140 / 255.0, 0.45 * b))
		ci.draw_rect(Rect2(roundf(x / 2.0) * 2.0, roundf(y / 2.0) * 2.0, 2, 2), Color(240 / 255.0, 1.0, 190 / 255.0, b))

## the cat on the crate (drawn behind the player, on the town canvas)
func draw_cat(ci: CanvasItem) -> void:
	if cat == null: return
	var c: Dictionary = cat
	var vr: Rect2 = arena.view_rect()
	if c["x"] < vr.position.x - 60.0 or c["x"] > vr.end.x + 60.0: return
	var t := now()
	ci.draw_set_transform(Vector2(roundf(c["x"]), roundf(c["y"])), 0.0, Vector2(2.0 * c["dir"], 2.0))
	if c["st"] == "sleep":
		cat_sleep(ci, t)
		ci.draw_set_transform(Vector2.ZERO)
		if int(c["z"] / 900.0) % 3 == 0:
			ci.draw_string(arena.font_black, Vector2(c["x"] + c["dir"] * 10.0, c["y"] - 16.0 - fmod(c["z"], 900.0) / 60.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.75))
		return
	cat_sit(ci, t, c["st"] == "startle", c["yawn"] > 0.0 and c["yawn"] < 450.0)
	ci.draw_set_transform(Vector2.ZERO)

const CAT_O := Color("#c9813f")
const CAT_S := Color("#9a5a2a")
const CAT_L := Color("#e9b678")
const CAT_K := Color("#2a1a12")

## curled up asleep: the back rises and falls (art px, in the caller's transform; feet at 0)
static func cat_sleep(ci: CanvasItem, t: float) -> void:
	var br := 0.0 if sin(t / 700.0) > 0.0 else -1.0
	ci.draw_rect(Rect2(-7, -5 + br, 13, 5 - br), CAT_O)
	ci.draw_rect(Rect2(-5, -5 + br, 2, 1), CAT_S)
	ci.draw_rect(Rect2(-1, -5 + br, 2, 1), CAT_S)
	ci.draw_rect(Rect2(3, -5 + br, 2, 1), CAT_S)
	ci.draw_rect(Rect2(4, -7 + br, 5, 4), CAT_O)
	ci.draw_rect(Rect2(4, -8 + br, 1, 1), CAT_O)
	ci.draw_rect(Rect2(8, -8 + br, 1, 1), CAT_O)
	ci.draw_rect(Rect2(6, -5 + br, 2, 1), CAT_K)
	ci.draw_rect(Rect2(-9, -2, 4, 2), CAT_O)
	ci.draw_rect(Rect2(-9, -1, 9, 1), CAT_S)

## sitting up, tail twitching; puffed up when startled; mouth open mid-yawn
static func cat_sit(ci: CanvasItem, t: float, puffed: bool, yawn: bool) -> void:
	var pf := 1.0 if puffed else 0.0
	var tw := sin(t / 220.0) * 2.0
	ci.draw_rect(Rect2(-4 - pf, -8 - pf, 8 + pf * 2.0, 8 + pf), CAT_O)
	ci.draw_rect(Rect2(-3, -8, 2, 1), CAT_S)
	ci.draw_rect(Rect2(1, -8, 2, 1), CAT_S)
	ci.draw_rect(Rect2(-3, -3, 6, 3), CAT_L)
	ci.draw_rect(Rect2(-6, -4 + roundf(tw / 2.0), 2, 4), CAT_O)
	ci.draw_rect(Rect2(-8, -6 + roundf(tw), 2, 3), CAT_O)
	ci.draw_rect(Rect2(1, -14, 7, 6), CAT_O)
	ci.draw_rect(Rect2(1, -16 + pf * 2.0, 2, 2), CAT_O)
	ci.draw_rect(Rect2(6, -16 + pf * 2.0, 2, 2), CAT_O)
	ci.draw_rect(Rect2(5, -11, 2, 1), CAT_K)
	ci.draw_rect(Rect2(2, -11, 2, 1), CAT_K)
	if yawn: ci.draw_rect(Rect2(4, -9, 3, 2), Color("#7a2a2a"))
	ci.draw_rect(Rect2(-1, -1, 2, 1), CAT_O)
	ci.draw_rect(Rect2(3, -1, 2, 1), CAT_O)
