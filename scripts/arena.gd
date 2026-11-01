extends Node2D
## Training ground: flat ground, one-way platforms, practice dummies on the left, monster waves on the right.
## Owns the camera, hitstop, screen shake, sound, slow-motion (perfect dodge) and the hit effects.

const PLAYER := preload("res://scripts/player.gd")
const DUMMY := preload("res://scripts/dummy.gd")
const TOUCH := preload("res://scripts/touch_controls.gd")
const MOB := preload("res://scripts/mob.gd")
const HUD := preload("res://scripts/hud.gd")
const WAVES := [["goblin", "goblin", "eye"], ["mush", "goblin", "goblin"], ["mush", "mush", "eye", "goblin"], ["skel", "goblin", "eye", "mush"], ["skel", "skel", "eye", "eye", "goblin"]]

const H := 500.0
var ground_y := H - 70.0
var world_w := 2800.0
var platforms: Array = []
var player
var dummies: Array = []
var cam: Camera2D
var hitstop := 0.0
var flash := 0.0
var shake_amt := 0.0
var shake_dir := 1
var fx: Array = []           # {k, ...}
var mobs: Array = []
var proj: Array = []         # monster projectiles
var wave := 0
var wave_t := 1500.0         # countdown to the next wave
var witch := 0.0             # perfect-dodge slow motion (ms left)
var witch_max := 1.0
var was_dash := false
var big_words: Array = []    # PARRY! / 극한 회피! cut-in words
var sfx_cache := {}
var sfx_pool: Array = []
var font_bold: Font = preload("res://assets/fonts/NotoSansKR-Bold.otf")
var font_black: Font = preload("res://assets/fonts/NotoSansKR-Black.otf")
var font_anton: Font = preload("res://assets/fonts/Anton.woff2")
var flash_mat := ShaderMaterial.new()
var t_proj: Texture2D = preload("res://assets/mobs/eye_proj.png")
var witch_rect: ColorRect

var t_sky: Texture2D = preload("res://assets/bg/bg_sky.png")
var t_mtn: Texture2D = preload("res://assets/bg/bg_mountains.png")
var t_forest: Texture2D = preload("res://assets/bg/bg_forest.png")
var t_ground: Texture2D = preload("res://assets/bg/k_ground.png")
var t_dirt: Texture2D = preload("res://assets/bg/k_dirt.png")
var fx_layer: Node2D
var flash_rect: ColorRect


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0d0b10"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_input()
	platforms = [
		{"x": 520.0, "y": ground_y - 150.0, "w": 190.0},
		{"x": 170.0, "y": ground_y - 120.0, "w": 150.0},
		{"x": 960.0, "y": ground_y - 130.0, "w": 170.0},
		{"x": 1700.0, "y": ground_y - 140.0, "w": 220.0},
		{"x": 2250.0, "y": ground_y - 120.0, "w": 180.0},
	]
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float flash = 0.0;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV) * COLOR; c.rgb = mix(c.rgb, vec3(1.0), flash); COLOR = c; }"
	flash_mat.shader = sh
	for i in 8:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		sfx_pool.append(ap)
	var spots := [[80.0, ground_y], [250.0, ground_y - 120.0], [600.0, ground_y - 150.0]]
	for s in spots:
		var d := Node2D.new()
		d.set_script(DUMMY)
		d.position = Vector2(s[0], s[1])
		d.arena = self
		add_child(d)
		dummies.append(d)
	player = Node2D.new()
	player.set_script(PLAYER)
	player.arena = self
	player.position = Vector2(380, ground_y)
	add_child(player)
	fx_layer = Node2D.new()
	fx_layer.z_index = 10
	fx_layer.draw.connect(_draw_fx)
	add_child(fx_layer)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(world_w)
	cam.limit_top = 0
	cam.limit_bottom = int(H)
	add_child(cam)
	cam.position = player.position
	cam.make_current()
	var ui := CanvasLayer.new()
	add_child(ui)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(flash_rect)
	witch_rect = ColorRect.new()
	witch_rect.color = Color(0.25, 0.4, 0.85, 0)
	witch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	witch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(witch_rect)
	var hud := Control.new()
	hud.set_script(HUD)
	hud.arena = self
	ui.add_child(hud)
	var tc := Control.new()
	tc.set_script(TOUCH)
	ui.add_child(tc)
	var stamp := Label.new()
	stamp.text = "STEP 2 · 전투  ·  " + _stamp()
	stamp.add_theme_font_override("font", font_bold)
	stamp.add_theme_font_size_override("font_size", 11)
	stamp.modulate = Color(1, 1, 1, 0.45)
	stamp.position = Vector2(12, 480)
	ui.add_child(stamp)


func _stamp() -> String:
	var f := FileAccess.open("res://build.txt", FileAccess.READ)
	return f.get_as_text().strip_edges() if f else "local"


## Arrow-key preset from the prototype: arrows move, Z jump, X attack, A guard, Shift dash. Pads too.
func setup_input() -> void:
	var map := {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": [KEY_Z], "attack": [KEY_X], "guard": [KEY_A], "dash": [KEY_SHIFT],
	}
	var pad := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "dash": JOY_BUTTON_B, "guard": JOY_BUTTON_RIGHT_SHOULDER,
		"left": JOY_BUTTON_DPAD_LEFT, "right": JOY_BUTTON_DPAD_RIGHT, "up": JOY_BUTTON_DPAD_UP, "down": JOY_BUTTON_DPAD_DOWN}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.3)
		for k in map[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
			var e2 := InputEventKey.new()   # some browsers report modifier keys only by key label
			e2.keycode = k
			InputMap.action_add_event(a, e2)
		var j := InputEventJoypadButton.new()
		j.button_index = pad[a]
		InputMap.action_add_event(a, j)
	for ax in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["up", JOY_AXIS_LEFT_Y, -1.0], ["down", JOY_AXIS_LEFT_Y, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = ax[1]
		m.axis_value = ax[2]
		InputMap.action_add_event(ax[0], m)


func foes() -> Array:
	return dummies + mobs.filter(func(m): return m.alive())

func platform_under(p: Vector2):
	for pl in platforms:
		if absf(p.y - pl.y) < 1.0 and p.x > pl.x - 2.0 and p.x < pl.x + pl.w + 2.0:
			return pl
	return null


func _process(delta: float) -> void:
	var dt := minf(delta * 1000.0, 50.0)
	if witch > 0.0:
		witch -= dt
		if witch <= 0.0:
			sfx("witch_end", 0.8)
	var wk := 0.22 if witch > 0.0 else 1.0   # the world slows; Estelle does not
	if hitstop > 0.0:
		hitstop -= dt
	else:
		player.step(dt)
		for d in dummies:
			d.step(dt)
		for m in mobs:
			m.step(dt * wk)
		step_proj(dt * wk)
		dodge_check()
		step_waves(dt)
	for m in mobs:
		m.queue_redraw()
	mobs = mobs.filter(func(m):
		if m.dead > 2400.0:
			m.queue_free()
			return false
		return true)
	for w in big_words:
		w["t"] += dt
	big_words = big_words.filter(func(w): return w["t"] < w["life"])
	var wa := 0.0
	if witch > 0.0:
		wa = minf(1.0, witch / 300.0) * minf(1.0, (witch_max - witch) / 90.0 + 0.15) * 0.28
	witch_rect.color.a = wa
	for e in fx:
		e["t"] += dt
		if e.has("vx"):
			e["x"] += e["vx"] * dt
			e["y"] += e["vy"] * dt
			if e["k"] == "sp": e["vy"] += 0.0012 * dt
	fx = fx.filter(func(e): return e["t"] < e["life"])
	if shake_amt > 0.0: shake_amt = maxf(0.0, shake_amt - dt * 0.05)
	if flash > 0.0: flash = maxf(0.0, flash - dt * 0.004)
	flash_rect.color.a = flash
	# camera: follow the feet horizontally, fixed height (the room is one screen tall)
	var target := Vector2(player.position.x, H / 2.0)
	cam.position = cam.position.lerp(target, minf(1.0, dt / 90.0))
	cam.position.y = H / 2.0
	cam.offset = Vector2(randf_range(-1, 1) * shake_amt * 0.6 + shake_dir * shake_amt * 0.3, randf_range(-1, 1) * shake_amt * 0.4)
	queue_redraw()
	fx_layer.queue_redraw()


# ---------- background & ground ----------
func _draw() -> void:
	var vs := get_viewport_rect().size
	var c := cam.get_screen_center_position() if cam else Vector2(vs.x / 2, H / 2)
	var left := c.x - vs.x / 2.0
	# sky: one image stretched to the screen
	var sk := H / t_sky.get_height()
	var sw := t_sky.get_width() * sk
	var sx := left - fmod(left * 0.05, sw)
	while sx < left + vs.x:
		draw_texture_rect(t_sky, Rect2(sx, 0, sw, H), false)
		sx += sw
	_tile(t_mtn, 2.0, 0.2, ground_y - 40.0, left, vs.x, Color(0.85, 0.85, 0.95))
	_tile(t_forest, 1.6, 0.45, ground_y + 10.0, left, vs.x, Color(0.75, 0.8, 0.75))
	# ground strip + dirt below
	var gx := floorf(left / t_ground.get_width()) * t_ground.get_width()
	while gx < left + vs.x:
		draw_texture(t_ground, Vector2(gx, ground_y - 8.0))
		var dy := ground_y - 8.0 + t_ground.get_height()
		while dy < H:
			draw_texture(t_dirt, Vector2(gx, dy))
			dy += t_dirt.get_height()
		gx += t_ground.get_width()
	# one-way platforms: plank with a lit top edge
	for pl in platforms:
		draw_rect(Rect2(pl.x, pl.y, pl.w, 14), Color("#5a3b24"))
		draw_rect(Rect2(pl.x, pl.y, pl.w, 3), Color("#c8915a"))
		draw_rect(Rect2(pl.x, pl.y + 14, pl.w, 3), Color(0, 0, 0, 0.35))

func _tile(tex: Texture2D, s: float, par: float, bottom: float, left: float, width: float, mod: Color) -> void:
	var w := tex.get_width() * s
	var h := tex.get_height() * s
	var off := left * (1.0 - par)
	var x := off + floorf((left - off) / w) * w
	while x < left + width:
		draw_texture_rect(tex, Rect2(x, bottom - h, w, h), false, mod)
		x += w


# ---------- effects ----------
func sfx(n: String, vol := 1.0) -> void:
	if not sfx_cache.has(n):
		sfx_cache[n] = load("res://assets/sfx/%s.wav" % n) if ResourceLoader.exists("res://assets/sfx/%s.wav" % n) else null
	var st: AudioStream = sfx_cache[n]
	if st == null:
		return
	var best = sfx_pool[0]
	for ap in sfx_pool:
		if not ap.playing:
			best = ap
			break
	best.stream = st
	best.volume_db = linear_to_db(maxf(0.01, vol)) - 4.0
	best.pitch_scale = 0.62 if witch > 0.0 else 1.0
	best.play()

func text(p: Vector2, s: String, col: Color) -> void:
	fx.append({"k": "say", "x": p.x, "y": p.y, "s": s, "col": col, "t": 0.0, "life": 900.0})


# ---------- monsters ----------
func spawn(k: String, x: float, delay: float):
	var m := Node2D.new()
	m.set_script(MOB)
	m.arena = self
	var y := ground_y
	add_child(m)
	m.setup(k, Vector2(x, y), delay)
	m.z_index = 1
	mobs.append(m)
	return m

func step_waves(dt: float) -> void:
	if mobs.any(func(m): return not m.is_dead()):
		return
	wave_t -= dt
	if wave_t > 0.0:
		return
	var list: Array = WAVES[wave % WAVES.size()]
	wave += 1
	for j in list.size():
		var x := 1500.0 + randf() * 1100.0
		var m = spawn(list[j], x, 150.0 + j * 140.0)
		if wave > 1 and j == 0:
			m.notice(false)
	big_word("WAVE %d" % wave, Color("#ffd34d"), 900.0, Vector2(0, 0))
	sfx("ready", 0.7)
	wave_t = 2500.0

func shoot(m, p: Vector2, v: Vector2) -> void:
	proj.append({"x": p.x, "y": p.y, "vx": v.x, "vy": v.y, "t": 0.0, "life": 2600.0, "m": m})

func step_proj(dt: float) -> void:
	var P = player
	proj = proj.filter(func(p):
		p["t"] += dt
		p["x"] += p["vx"] * dt
		p["y"] += p["vy"] * dt
		if absf(P.position.x - p["x"]) < 32.0 and p["y"] > P.position.y - 130.0 * 1.3 and p["y"] < P.position.y + 4.0:
			var r: String = P.take_hit(p["m"], p["m"].M["atk"] * 0.8)
			if r != "miss":
				spark(Vector2(p["x"], p["y"]), 8)
				return false
		return p["t"] < p["life"] and p["x"] > -50.0 and p["x"] < world_w + 50.0 and p["y"] < ground_y + 20.0)

## a mob mid-swing whose glint has shown, close enough to land on her
func threatened():
	var P = player
	for m in mobs:
		if not m.alive() or m.st != "atk" or not m.flared or m.atk_clock > m.hit_at + 140.0:
			continue
		var adx: float = absf(P.position.x - m.position.x)
		var dy: float = absf(P.position.y - (m.position.y + m.M.get("fly", 0)))
		if m.M.has("ranged"):
			if adx < m.M["range"] + 120.0 and dy < 220.0: return m
		elif adx < m.M.get("reach", 100) + 90.0 and dy < 120.0:
			return m
	for p in proj:
		if absf(p["x"] - P.position.x) < 130.0 and p["y"] > P.position.y - 200.0 and p["y"] < P.position.y + 20.0 and signf(p["vx"]) == signf(P.position.x - p["x"]):
			return p["m"]
	return null

func dodge_check() -> void:
	var d: bool = player.anim in ["dash", "airdash", "backstep"]
	if d and not was_dash and witch <= 0.0:
		var m = threatened()
		if m != null:
			perfect_dodge()
	was_dash = d

func perfect_dodge() -> void:
	witch = 1500.0
	witch_max = 1500.0
	player.charges = mini(2, player.charges + 1)
	player.inv = maxf(player.inv, 400.0)
	big_word("극한 회피!", Color("#bfe8ff"), 900.0, Vector2(0, -170))
	flash = maxf(flash, 0.16)
	sfx("boom", 0.9)
	sfx("dash", 0.6)

func parry_fx(P, _m) -> void:
	var d: int = P.dir
	sfx("parry", 1.0)
	hitstop = 95.0
	flash = 0.45
	shake(12, d)
	spark(P.position + Vector2(d * 40.0 * 1.3, -70.0 * 1.3), 18)
	streak_fx(P.position.x + d * 20.0 * 1.3, P.position.x + d * 150.0 * 1.3, P.position.y - 70.0 * 1.3, d)
	ring(P.position + Vector2(d * 55.0 * 1.3, -70.0 * 1.3), 30.0)
	big_word("PARRY", Color("#ffd34d"), 700.0, Vector2(0, -150))

func perfect_parry(m) -> void:
	witch = maxf(witch, 560.0)
	witch_max = maxf(witch_max, 560.0)
	m.hurt_t = maxf(m.hurt_t, 1400.0)
	m.kx = player.dir * 2.2
	m.flare_t = -1.0
	sfx("heavy", 0.7)

func big_word(s: String, col: Color, life: float, off: Vector2) -> void:
	big_words.append({"s": s, "col": col, "t": 0.0, "life": life, "x": player.position.x + off.x, "y": player.position.y + off.y, "screen": off == Vector2.ZERO})

func shake(amt: float, d: int) -> void:
	shake_amt = maxf(shake_amt, amt)
	shake_dir = d

func slash_fx(c: Vector2, r: float, a0: float, a1: float, d: int) -> void:
	fx.append({"k": "slash", "x": c.x, "y": c.y, "r": r, "a0": a0, "a1": a1, "d": d, "t": 0.0, "life": 170.0})

func streak_fx(x0: float, x1: float, y: float, d: int) -> void:
	fx.append({"k": "streak", "x": x0, "x1": x1, "y": y, "d": d, "t": 0.0, "life": 160.0})

func dust(p: Vector2, d: int, heavy: bool) -> void:
	for i in (8 if heavy else 4):
		var sx := (randf() - 0.5) * 0.12 + d * 0.08
		fx.append({"k": "dust", "x": p.x + (randf() - 0.5) * 30.0, "y": p.y - randf() * 6.0, "vx": sx, "vy": -0.04 - randf() * 0.06, "r": 4.0 + randf() * 5.0, "t": 0.0, "life": 320.0})

func ring(p: Vector2, r: float) -> void:
	fx.append({"k": "ring", "x": p.x, "y": p.y, "r": r, "t": 0.0, "life": 260.0})

func spark(p: Vector2, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var s := 0.25 + randf() * 0.4
		fx.append({"k": "sp", "x": p.x, "y": p.y, "vx": cos(a) * s, "vy": sin(a) * s, "t": 0.0, "life": 140.0 + randf() * 120.0})

func damage_text(p: Vector2, dmg: int, big: bool) -> void:
	fx.append({"k": "txt", "x": p.x + randf_range(-10, 10), "y": p.y, "s": str(dmg * 10), "big": big, "t": 0.0, "life": 600.0})

func charge_fx(p: Vector2, t: float) -> void:
	if randf() < 0.35:
		var a := randf() * TAU
		var r := 40.0 + randf() * 20.0
		fx.append({"k": "mote", "x": p.x + cos(a) * r, "y": p.y + sin(a) * r, "tx": p.x, "ty": p.y, "full": t >= 650.0, "t": 0.0, "life": 220.0})

func _draw_fx() -> void:
	var pink := Color(1.0, 0.47, 0.75)
	for e in fx:
		var k: float = e["t"] / e["life"]
		match e["k"]:
			"slash":
				var pts := PackedVector2Array()
				var a0: float = deg_to_rad(e["a0"])
				var a1: float = deg_to_rad(e["a1"])
				var span := minf(1.0, k * 2.2)        # the arc sweeps in, then the tail eats it
				var tail := maxf(0.0, (k - 0.35) / 0.65)
				var n := 18
				for i in n + 1:
					var u: float = lerpf(tail, span, float(i) / n)
					var a: float = lerpf(a0, a1, u)
					pts.append(Vector2(e["x"] + cos(a) * e["r"] * e["d"], e["y"] + sin(a) * e["r"]))
				for i in range(n, -1, -1):
					var u2: float = lerpf(tail, span, float(i) / n)
					var a2: float = lerpf(a0, a1, u2)
					var thick := 0.88 + 0.06 * (1.0 - sin(PI * float(i) / n))
					pts.append(Vector2(e["x"] + cos(a2) * e["r"] * thick * e["d"], e["y"] + sin(a2) * e["r"] * thick))
				if span - tail > 0.02:
					fx_layer.draw_colored_polygon(pts, Color(1.0, 0.55, 0.82, 0.75 * (1.0 - k)))
					fx_layer.draw_polyline(pts.slice(0, n + 1), Color(1, 1, 1, 1.0 - k), 2.0)
			"streak":
				var w: float = (e["x1"] - e["x"]) * minf(1.0, k * 3.0)
				fx_layer.draw_rect(Rect2(minf(e["x"], e["x"] + w), e["y"] - 5.0 * (1.0 - k), absf(w), 10.0 * (1.0 - k)), Color(1, 0.8, 0.93, 1.0 - k))
				fx_layer.draw_rect(Rect2(minf(e["x"], e["x"] + w), e["y"] - 1.0, absf(w), 2.0), Color(1, 1, 1, 1.0 - k))
			"dust":
				fx_layer.draw_circle(Vector2(e["x"], e["y"]), e["r"] * (1.0 + k), Color(0.85, 0.78, 0.68, 0.5 * (1.0 - k)))
			"ring":
				fx_layer.draw_arc(Vector2(e["x"], e["y"]), e["r"] * (0.5 + k), 0, TAU, 24, Color(1, 0.8, 0.95, 1.0 - k), 2.0)
			"sp":
				fx_layer.draw_rect(Rect2(e["x"] - 2, e["y"] - 2, 4, 4), Color(1, 0.85, 0.92, 1.0 - k))
			"mote":
				var p := Vector2(e["x"], e["y"]).lerp(Vector2(e["tx"], e["ty"]), k)
				fx_layer.draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), Color(1, 1, 1, 0.9) if e["full"] else pink)
			"txt":
				var y: float = e["y"] - 40.0 * (1.0 - pow(1.0 - minf(1.0, k * 2.0), 3))
				var fs := 26 if e["big"] else 20
				var col := Color(1, 0.82, 0.9, 1.0 - maxf(0.0, (k - 0.6) / 0.4))
				fx_layer.draw_string_outline(font_anton, Vector2(e["x"] - 12, y), e["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.1, 0.02, 0.08, col.a))
				fx_layer.draw_string(font_anton, Vector2(e["x"] - 12, y), e["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			"say":
				var a: float = 1.0 - maxf(0.0, (k - 0.7) / 0.3)
				var yy: float = e["y"] - 24.0 * minf(1.0, k * 3.0)
				var w2 := font_black.get_string_size(e["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
				fx_layer.draw_string_outline(font_black, Vector2(e["x"] - w2 / 2.0, yy), e["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 5, Color(0.08, 0.03, 0.07, a))
				fx_layer.draw_string(font_black, Vector2(e["x"] - w2 / 2.0, yy), e["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(e["col"], a))
	# attack tells: a red-white glint at the weapon point, ~0.26 s before the blow lands
	for m in mobs:
		if m.flare_t < 0.0 or not m.alive():
			continue
		var u: float = m.flare_t / 420.0
		var c: Vector2 = m.flare_pos()
		var r := 26.0 * (1.0 - u) + 6.0
		var a2 := 1.0 - u
		fx_layer.draw_line(c + Vector2(-r * 2.2, 0), c + Vector2(r * 2.2, 0), Color(1, 0.25, 0.3, a2), 2.0)
		fx_layer.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.35, 0), c + Vector2(0, r), c + Vector2(-r * 0.35, 0)]), Color(1, 0.92, 0.92, a2))
		fx_layer.draw_arc(c, r * 0.9, 0, TAU, 20, Color(1, 0.2, 0.28, a2 * 0.8), 2.0)
	# projectiles (8-frame strip, 48x48)
	for p in proj:
		var fr := int(p["t"] / 70.0) % 8
		var sc := 2.2
		fx_layer.draw_set_transform(Vector2(p["x"], p["y"]), 0.0, Vector2(-1.0 if p["vx"] < 0.0 else 1.0, 1.0))
		fx_layer.draw_texture_rect_region(t_proj, Rect2(-24.0 * sc, -24.0 * sc, 48.0 * sc, 48.0 * sc), Rect2(fr * 48, 0, 48, 48))
		fx_layer.draw_set_transform(Vector2.ZERO)
	# PARRY / 극한 회피 words over her head
	for w in big_words:
		if w["screen"]:
			continue
		var u2: float = w["t"] / w["life"]
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - u2 * 6.0)
		var al := 1.0 - maxf(0.0, (u2 - 0.65) / 0.35)
		var fs2 := int(40 * pop)
		var fnt: Font = font_anton if w["s"].is_ascii() else font_black
		var ww := fnt.get_string_size(w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var pos := Vector2(w["x"] - ww / 2.0, w["y"] - 10.0 * u2)
		fx_layer.draw_string_outline(fnt, pos, w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 10, Color(0.05, 0.02, 0.06, al))
		fx_layer.draw_string(fnt, pos, w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(w["col"], al))

