extends Node2D
## The boss treasure chest (prototype LOOT: lootUpdate / chestHit / chestBreak / lootGet / lootTownGate, with sortie.js's
## 피로도 gate): 1.25 s after the boss falls a chest drops from the sky next to the leader. The grade it ends at is rolled
## when it lands (legendary 1% · unique 8% · epic 20% · rare 40% · common 31%, capped by the dungeon); every blow can
## reveal the next grade (at least three blows per grade), 18 blows break it, and what it held flies out and homes in on her.
## The first blow spends 40 피로도; without enough it stays shut (hint) and the town door lets you leave anyway.
## Opening it after the boss has been cleared before pays adventurer EXP 60 (fame.gain_exp).

const CHEST := [preload("res://assets/loot/chest_0.png"), preload("res://assets/loot/chest_1.png"), preload("res://assets/loot/chest_2.png"), preload("res://assets/loot/chest_3.png"), preload("res://assets/loot/chest_4.png")]
const CHK := 4.0
const CGN := ["커먼", "레어", "에픽", "유니크", "레전더리"]
const CGC := [Color("#d8d0bf"), Color("#5fa8ff"), Color("#b46cff"), Color("#ff8a3d"), Color("#ffe066")]
const HP0 := 18

var arena
var runes
var t := 0.0                 # since the boss fell
var chest = null             # {x, y, vy, landed, gi, goal, kT, hp, hits, wob, flashT, broken, hintT, doneT}
var items: Array = []        # flying loot
var vfx: Array = []
var paid := false
var got: Array = []          # what this chest gave, for the results
var grade := 0
var done := false
var swing_key := ""          # one blow per swing
var clock := 0.0


func _ready() -> void:
	z_index = 3
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena.sfx("slam", 0.9)

func fat():
	return arena.fatigue

func chest_dims(gi: int) -> Vector2:
	return Vector2(CHEST[gi].get_width(), CHEST[gi].get_height()) * CHK

## chestRoll: decided when it lands
func roll() -> int:
	var r: float = runes.rand() * 100.0
	return mini(runes.DUN["chest_cap"], 4 if r < 1.0 else (3 if r < 9.0 else (2 if r < 29.0 else (1 if r < 69.0 else 0))))

func _process(delta: float) -> void:
	if arena.ui_root != null and arena.ui_root.holds(): return
	if arena.dlg.active: return
	var dt := minf(delta * 1000.0, 50.0)
	clock += dt
	step(dt)
	queue_redraw()

func step(dt: float) -> void:
	t += dt
	var P = arena.player
	var G: float = arena.ground_y
	if t > 1250.0 and chest == null:
		var w: float = arena.world_w
		var x := clampf(P.position.x + P.dir * 230.0, 160.0, w - 160.0)
		chest = {"x": x, "y": G - 700.0, "vy": 0.0, "landed": false, "gi": 0, "goal": roll(), "kT": 0.0, "hp": HP0, "hits": 0, "wob": 0.0, "flashT": 0.0, "broken": false, "hintT": 0.0, "doneT": 0.0}
		arena.sfx("dive", 0.8)
	var C = chest
	if C != null and not C["broken"]:
		if not C["landed"]:
			C["vy"] += 0.0032 * dt
			C["y"] += C["vy"] * dt
			if C["y"] >= G:
				C["y"] = G
				C["landed"] = true
				arena.shake(14, 1)
				arena.flash = maxf(arena.flash, 0.2)
				arena.hitstop = maxf(arena.hitstop, 70.0)
				arena.sfx("slam", 1.0)
				arena.dust(Vector2(C["x"] + 20.0, G), 1, true)
				arena.dust(Vector2(C["x"] - 20.0, G), -1, true)
				arena.ring(Vector2(C["x"], G), 30.0)
		if C["wob"] > 0.0: C["wob"] = maxf(0.0, C["wob"] - dt / 260.0)
		if C["flashT"] > 0.0: C["flashT"] -= dt
		if C["kT"] > 0.0: C["kT"] = maxf(0.0, C["kT"] - dt)
		if C["hintT"] > 0.0: C["hintT"] -= dt
		if C["landed"]: _swing_check()
	# loot in the air, then homing in on her
	var keep: Array = []
	for o in items:
		o["t"] += dt
		if o["t"] < o["mag"]:
			o["vy"] += 0.0026 * dt
			o["x"] += o["vx"] * dt
			o["y"] += o["vy"] * dt
			if o["y"] >= G - 6.0:
				o["y"] = G - 6.0
				if absf(o["vy"]) > 0.12:
					o["vy"] *= -0.38
					o["vx"] *= 0.6
				else:
					o["vy"] = 0.0
					o["vx"] *= 0.85
			keep.append(o)
		else:
			var to := Vector2(P.position.x, P.position.y - 60.0 * P.CSCALE) - Vector2(o["x"], o["y"])
			var d := to.length()
			var st := minf(2.4, 0.25 + (o["t"] - o["mag"]) * 0.004) * dt
			if d < 26.0 or st >= d:
				_collect(o)
				continue
			o["x"] += to.x / d * st
			o["y"] += to.y / d * st
			keep.append(o)
	items = keep
	for e in vfx:
		e["t"] += dt
		for q in e["p"]:
			q["vy"] += 0.0011 * dt
			q["x"] += q["vx"] * dt
			q["y"] += q["vy"] * dt
			if e["y"] + q["y"] > G:
				q["y"] = G - e["y"]
				q["vy"] *= -0.3
				q["vx"] *= 0.6
	vfx = vfx.filter(func(e): return e["t"] < (1200.0 if e["k"] == "brk" else 700.0))
	if C != null and C["broken"] and items.is_empty() and not done:
		C["doneT"] += dt
		if C["doneT"] > 700.0:
			done = true

## a blow from the leader's swing on the chest (chestTry / chestTryRange)
func _swing_check() -> void:
	var P = arena.player
	if not P.attacking():
		swing_key = ""
		return
	var atk = P.cur_atk()
	if atk == null: return
	var key := "%s|%d" % [P.anim, P.f if P.anim == "air_combo" else 0]
	if P.anim == "air_combo": key = "%s|%d" % [P.anim, 0 if P.f < 3 else (1 if P.f < 6 else 2)]
	if key == swing_key: return
	if P.f < atk["hit"][0] or P.f > atk["hit"][1]: return
	var C = chest
	var hgt := chest_dims(C["gi"]).y
	var hit := false
	if P.who == "luce":
		hit = absf(C["x"] - P.position.x) < 260.0 and absf(C["y"] - P.position.y) < 160.0
	else:
		var b: Array = atk["box"]
		var K: float = P.CSCALE * P.MELEE_K
		var bw: float = b[2] * K
		var bx: float = P.position.x + b[0] * K if P.dir > 0 else P.position.x - b[0] * K - bw
		var by: float = P.position.y + b[1] * P.CSCALE
		var bh: float = b[3] * P.CSCALE
		var cw := chest_dims(C["gi"]).x * 0.5
		hit = C["x"] + cw > bx and C["x"] - cw < bx + bw and C["y"] > by and C["y"] - hgt < by + bh
	if hit:
		swing_key = key
		hit_chest()

func hit_chest() -> void:
	var C = chest
	if C == null or C["broken"] or not C["landed"]: return
	if not paid:
		var F = fat()
		var cost: int = F.COST if F != null else 40
		if F != null and F.value() < cost:
			if C["hintT"] <= 0.0:
				C["hintT"] = 1200.0
				arena.text(Vector2(C["x"], C["y"] - 200.0), "피로도가 부족하다 · %d 필요" % cost, Color("#ff9d9d"))
				arena.sfx("guard", 0.5)
			return
		if F != null: F.spend(cost)
		paid = true
		arena.text(Vector2(C["x"], C["y"] - 220.0), "피로도 -%d" % cost, Color("#7fd0ff"))
	C["hp"] -= 1
	C["hits"] += 1
	C["wob"] = 1.0
	arena.sfx("hit", 0.9)
	_vfx("hit", Vector2(C["x"] + (runes.rand() - 0.5) * 30.0, C["y"] - chest_dims(C["gi"]).y * 0.55), C["gi"], 7)
	arena.shake(5, 1)
	var left: int = C["goal"] - C["gi"]
	if left > 0 and C["hits"] >= 3 and (runes.rand() < 0.45 or C["hp"] <= left * 3 + 1):
		C["gi"] += 1
		C["hits"] = 0
		C["kT"] = 260.0
		C["flashT"] = 200.0
		arena.hitstop = maxf(arena.hitstop, 130.0)
		arena.flash = maxf(arena.flash, 0.35)
		arena.shake(9, 1)
		arena.text(Vector2(C["x"], C["y"] - 170.0), CGN[C["gi"]] + "!", CGC[C["gi"]])
		_vfx("up", Vector2(C["x"], C["y"] - chest_dims(C["gi"]).y * 0.5), C["gi"], 0)
		arena.sfx("ready", 0.7 + C["gi"] * 0.08)
	if C["hp"] <= 0: break_chest()

func break_chest() -> void:
	var C = chest
	var gi: int = C["gi"]
	C["broken"] = true
	grade = gi
	arena.hitstop = maxf(arena.hitstop, 170.0)
	arena.shake(18, 1)
	arena.flash = maxf(arena.flash, 0.55)
	arena.sfx("break", 1.0)
	arena.sfx("slam", 0.9)
	arena.post_wave(Vector2(C["x"], C["y"] - 50.0), 1.4, 600.0, 0.3)
	arena.post_ca(0.02)
	_vfx("brk", Vector2(C["x"], C["y"] - chest_dims(gi).y * 0.5), gi, 30)
	var D: Dictionary = runes.DUN
	var top: bool = gi >= D["chest_cap"]
	var out: Array = []
	for i in 2 + gi: out.append({"kind": "sh", "v": runes.dmul(4.0 + gi * 2 + runes.rng.randi() % 3)})
	for i in 1 + gi: out.append({"kind": "mem", "v": maxi(1, runes.dmul(1.0 + floorf(gi / 2.0)))})
	var nR := 1 + int(floor(gi / 1.5)) + (1 if gi >= 4 else 0)
	for i in nR:
		var g: String = runes.roll_grade(minf(1.0, 0.2 + gi * 0.2))
		if top and i == 0: g = D["bonus"]       # the jackpot: one grade over the dungeon's cap
		out.append({"kind": "rune", "v": runes.rand_rune(g)})
	var nG := (1 + (1 if gi >= 3 else 0)) if gi >= 1 else 0
	for i in nG:
		out.append({"kind": "gear", "v": runes.make_gear(D["bonus"] if top and i == 0 else runes.roll_grade(minf(1.0, 0.3 + gi * 0.15)))})
	for i in out.size():
		var o: Dictionary = out[i]
		var a: float = -PI / 2.0 + (runes.rand() - 0.5) * 2.4
		o["x"] = C["x"]
		o["y"] = C["y"] - 40.0
		o["vx"] = cos(a) * (0.25 + runes.rand() * 0.45)
		o["vy"] = -0.75 - runes.rand() * 0.55
		o["t"] = 0.0
		o["mag"] = 1050.0 + i * 45.0
		o["ph"] = runes.rand() * 6.0
		items.append(o)
	if gi >= 1:
		get_tree().create_timer(1.4).timeout.connect(func(): runes.mat_get("lamp", 1))
	# repeat clears: opening with fatigue pays adventurer EXP
	if paid and runes.boss_count() > 1 and arena.get("fame") != null and arena.fame.has_method("gain_exp"):
		arena.fame.gain_exp(60)

func _collect(o: Dictionary) -> void:
	match o["kind"]:
		"sh": runes.iron += o["v"]
		"mem": runes.mem += o["v"]
		"rune": runes.add_rune(o["v"])
		"gear": runes.gearbag.append(o["v"])
	got.append({"kind": o["kind"], "v": o["v"]})
	runes.changed()
	arena.sfx("step", 0.25)

## lootTownGate: true = the town door stays shut for now
func town_gate() -> bool:
	var C = chest
	if C != null and not C["broken"] and not paid and fat() != null and fat().value() < fat().COST: return false
	if C == null and t < 1250.0: return true
	if C != null and not C["broken"]:
		arena.text(arena.player.position + Vector2(0, -170.0 * arena.player.CSCALE), "보물 상자를 열어 보세요!", Color("#ffe066"))
		return true
	return not items.is_empty()

## what this chest gave: {sh, mem, runes: [r..], gear: [item..], grade}
func summary() -> Dictionary:
	var s := {"sh": 0, "mem": 0, "runes": [], "gear": [], "grade": grade}
	for o in got:
		if o["kind"] == "sh": s["sh"] += o["v"]
		elif o["kind"] == "mem": s["mem"] += o["v"]
		elif o["kind"] == "rune": s["runes"].append(o["v"])
		else: s["gear"].append(o["v"])
	return s

func _vfx(k: String, p: Vector2, gi: int, n: int) -> void:
	var cols := [CGC[gi], Color.WHITE, Color("#ffd34d")]
	var R: Array = []
	for i in n:
		var a: float = -PI / 2.0 + (runes.rand() - 0.5) * (3.4 if k == "brk" else 2.4)
		var v: float = (0.35 if k == "brk" else 0.22) + runes.rand() * (0.5 if k == "brk" else 0.3)
		R.append({"x": 0.0, "y": 0.0, "vx": cos(a) * v, "vy": sin(a) * v - 0.1, "s": (4.0 + 2.0 * (runes.rng.randi() % 2)) if k == "brk" else 2.0, "c": cols[runes.rng.randi() % 3]})
	vfx.append({"k": k, "x": p.x, "y": p.y, "gi": gi, "t": 0.0, "p": R})


# ---------- drawing ----------
func _draw() -> void:
	var C = chest
	var f: Font = arena.font_black
	if C != null and not C["broken"]:
		var gi: int = C["gi"]
		var col: Color = CGC[gi]
		var dims := chest_dims(gi)
		var cx: float = C["x"]
		var cy: float = C["y"]
		if C["landed"]:
			# glow: a dotted halo, rays from epic up, a pulsing ring of dots under it
			var cyg := cy - dims.y / 3.0
			if gi >= 2:
				var n := 8 + gi * 2
				for i in n:
					var a := clock / 1600.0 + float(i) / n * TAU
					var L := 66.0 + gi * 24.0 + (0.0 if i % 2 else 24.0)
					var r := 24.0
					while r < L:
						if int(r / 6.0 + i + clock / 60.0) % 3 != 0:
							draw_rect(Rect2(cx + cos(a) * r - 1.5, cyg + sin(a) * r * 0.8 - 1.5, 3, 3), Color.WHITE if r < 42.0 else Color(col, 0.8))
						r += 6.0
			var R := 30.0 + gi * 12.0
			for i in 40:
				var a2 := float(i) / 40.0 * TAU + clock / 2400.0
				if (i + int(clock / 100.0)) % 2: continue
				draw_rect(Rect2(cx + cos(a2) * R * 1.3 - 1.5, cyg + sin(a2) * R - 1.5, 3, 3), Color(col, 0.55))
			var rx := dims.x / 2.0 + 8.0
			var x := -rx
			while x <= rx:
				var yy := sqrt(maxf(0.0, 1.0 - pow(x / rx, 2))) * 6.0
				if int(x / 2.0 + clock / 120.0) % 2 == 0:
					draw_rect(Rect2(cx + x, cy + yy - 1, 2, 2), col)
					draw_rect(Rect2(cx + x, cy - yy + 1, 2, 2), col)
				x += 2.0
			var ph := int(clock / 700.0)
			var u := fmod(clock, 700.0) / 700.0
			if u < 0.35:
				var sx := ((ph * 37) % 10 - 5) / 10.0 * dims.x / 2.0
				var sy := -dims.y / 2.0 * (0.4 + ((ph * 13) % 5) / 10.0)
				var L2 := 6.0 if u < 0.12 else (4.0 if u < 0.24 else 2.0)
				draw_line(Vector2(cx + sx - L2, cy + sy), Vector2(cx + sx + L2, cy + sy), Color.WHITE, 2.0)
				draw_line(Vector2(cx + sx, cy + sy - L2), Vector2(cx + sx, cy + sy + L2), Color.WHITE, 2.0)
		var kup: float = 1.0 + 0.35 * sin((1.0 - C["kT"] / 260.0) * PI) if C["kT"] > 0.0 else 1.0
		var squash: float = sin(C["wob"] * 12.0) * C["wob"] if C["wob"] > 0.0 else 0.0
		var dw := roundf(dims.x * kup * (1.0 + squash * 0.06))
		var dh := roundf(dims.y * kup * (1.0 - squash * 0.06))
		var r2 := Rect2(roundf(cx - dw / 2.0 + squash * 6.0), roundf(cy - dh), dw, dh)
		draw_texture_rect(CHEST[gi], r2, false)
		if C["flashT"] > 0.0:
			draw_texture_rect(CHEST[gi], r2, false, Color(4, 4, 4, minf(1.0, C["flashT"] / 200.0)))
		if C["landed"] and C["hp"] == HP0 and int(clock / 400.0) % 2 == 0:
			var s := "공격해서 열기!"
			var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var p := Vector2(cx - w / 2.0, cy - dims.y - 30.0)
			draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
			draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		if C["landed"]:
			var s2: String = CGN[gi]
			var w2 := f.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string_outline(f, Vector2(cx - w2 / 2.0, cy + 18.0), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.85))
			draw_string(f, Vector2(cx - w2 / 2.0, cy + 18.0), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
			if not paid and fat() != null:
				var s3 := "피로도 %d 소모" % fat().COST if fat().value() >= fat().COST else "피로도 부족 · 그냥 돌아가도 된다"
				var w3: float = arena.font_bold.get_string_size(s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				draw_string_outline(arena.font_bold, Vector2(cx - w3 / 2.0, cy + 34.0), s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.85))
				draw_string(arena.font_bold, Vector2(cx - w3 / 2.0, cy + 34.0), s3, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#7fd0ff") if fat().value() >= fat().COST else Color("#ff9d9d"))
	for e in vfx:
		var fr := int(e["t"] / 40.0)
		var col2: Color = CGC[e["gi"]]
		var c := Vector2(e["x"], e["y"])
		if e["k"] == "hit" and fr <= 4:
			var L3: float = [12.0, 16.0, 10.0, 6.0, 0.0][fr]
			draw_line(c - Vector2(L3, 0), c + Vector2(L3, 0), Color.WHITE, 2.0)
			draw_line(c - Vector2(0, L3), c + Vector2(0, L3), Color.WHITE, 2.0)
		elif e["k"] == "up" and fr <= 16:
			var r3 := 8.0 + fr * 8.0
			if fr < 9: draw_arc(c, r3, 0, TAU, 32, Color.WHITE if fr < 3 else col2, 2.0)
			if fr < 12:
				var hh := minf(120.0, fr * 20.0)
				draw_rect(Rect2(c.x - maxf(1.0, 4.0 - fr / 3.0), c.y - hh - 16.0, maxf(2.0, 8.0 - fr * 0.6), hh), Color(col2, 0.8))
		elif e["k"] == "brk" and fr < 6:
			draw_arc(c, 12.0 + fr * 14.0, 0, TAU, 32, Color.WHITE if fr < 2 else col2, 2.0)
		for q in e["p"]:
			draw_rect(Rect2(c.x + q["x"], c.y + q["y"], q["s"], q["s"]), Color(q["c"], clampf(1.0 - e["t"] / 1200.0, 0.0, 1.0)))
	for o in items:
		var col3 := _item_col(o)
		var tier := _tier(o)
		var p2 := Vector2(o["x"], o["y"])
		var pul := 1.0 if sin(clock / 140.0 + o["ph"]) > 0.0 else 0.0
		var R2 := (3.0 + tier + pul) * 2.0
		draw_circle(p2, R2 + 3.0, Color(col3, 0.35))
		draw_circle(p2, R2 * 0.6, Color(col3, 0.9))
		draw_rect(Rect2(p2.x - 2, p2.y - 2, 4, 4), Color.WHITE)
		if tier >= 1:
			var H := (8.0 + tier * 7.0) * 2.0
			draw_rect(Rect2(p2.x - 1, p2.y - H - 4.0, 2, H), Color(col3, 0.7))

func _item_col(o: Dictionary) -> Color:
	match o["kind"]:
		"sh": return runes.SHC
		"mem": return runes.MEMC
		"rune": return runes.gcol(runes.RUNE[o["v"]]["g"])
	return runes.gcol(o["v"]["g"])

func _tier(o: Dictionary) -> int:
	if o["kind"] == "sh": return 0
	if o["kind"] == "mem": return 1
	var g: String = runes.RUNE[o["v"]]["g"] if o["kind"] == "rune" else o["v"]["g"]
	return {"common": 0, "uncommon": 1, "rare": 1, "elite": 2, "epic": 3, "legend": 4, "unique": 4}.get(g, 0)
