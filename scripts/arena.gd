extends Node2D
## Training ground: flat ground, one-way platforms, practice dummies on the left, monster waves on the right.
## Owns the camera, hitstop, screen shake, sound, slow-motion (perfect dodge) and the hit effects.

const PLAYER := preload("res://scripts/player.gd")
const DUMMY := preload("res://scripts/dummy.gd")
const TOUCH := preload("res://scripts/touch_controls.gd")
const MOB := preload("res://scripts/mob.gd")
const HUD := preload("res://scripts/hud.gd")
const DUNGEON := preload("res://scripts/dungeon.gd")
const TOWN := preload("res://scripts/town.gd")
const HALL := preload("res://scripts/hall.gd")
const EILIN := preload("res://scripts/eilin.gd")
const DIALOG := preload("res://scripts/dialog.gd")
const FOLK := preload("res://scripts/townsfolk.gd")
const WEATHERS := ["clear", "rain", "snow"]
const SETTINGS := preload("res://scripts/settings.gd")
const AMBIENCE := preload("res://scripts/ambience.gd")
const POSTFX := preload("res://scripts/post_fx.gd")
const FATIGUE := preload("res://scripts/fatigue.gd")
const UIROOT := preload("res://scripts/ui_root.gd")
const RUNES := preload("res://scripts/runes.gd")
const FAME := preload("res://scripts/fame.gd")
const SORTIE := preload("res://scripts/sortie.gd")
const ULT := preload("res://scripts/ult.gd")
const SAVE := preload("res://scripts/save_game.gd")
const ELEM := preload("res://scripts/elements.gd")
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
var t_wave: Texture2D = preload("res://assets/mobs/skel_proj.png")
var witch_rect: ColorRect
var luce_fx: Array = []
var mark_pos := Vector2.INF
var solids: Array = []        # raised rock {x,w,top}
var ceil_y := -1.0e9
var level = null              # the dungeon, the town or the hall (level.kind); null = training ground
var tod_h := 18.5             # one clock for the whole world (town, hall, Eilin's day)
var tod_auto := true
var weather := "clear"         # "clear" / "rain" / "snow" (town sky, rain and snow; F10 cycles it)
var eil                       # Eilin lives across maps
var dlg                       # talk box
var shilling := 0
var fade_rect: ColorRect
var fade := 0.0
var fade_dir := 0
var fade_cb = null
var near_entry := false
var near_exit := false
var train_platforms: Array = []
# front end (step 4): settings, 피로도, title / menus
var cfg                       # settings.gd: device, stick, key bindings (saved)
var fatigue                   # fatigue.gd: 피로도 160, +1 / 6 min (nothing spends it yet)
var ambient := true           # 환경음 (ambience.gd)
var post                      # post_fx.gd: shockwaves, colour fringes, vignette, the dodge grade (화면 효과)
var low_end := false          # a phone (web + touch-first): fewer, wider lights
var amb                       # ambience.gd: wind / rain / water loops, birds, crickets, fires, the hall's creaks and clock
var screen_fx := true         # 화면 효과 (post_fx.gd)
var pix := "off"              # 캐릭터 도트화 (off until the faithful charPix port lands): off / dot / shade (player.gd pix_mat)
var ui_root                   # ui_root.gd: title, top-right buttons, main menu, transitions
var runes                     # runes.gd: runes, gear, shillings' drops, the boss chest, the bestiary record
var fame                      # fame.gd: guild fame, quests, adventurer level, the guild / adventure books' data, cut-ins
# step 4-2 / 5-3: sortie flow, 궁극기, elements, save
var sortie                    # sortie.gd: dungeon select, band sweeps, entry dash, deploy cut, title cards, clear screen, party screen
var ult                       # ult.gd: 기력 gauges, the ult moves and their world effects
var save                      # save_game.gd: user://save.json
var hit_by := ""              # who a delayed hit (Luce's light) belongs to, for its element

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
	cfg = SETTINGS.new(self)
	cfg.apply_keys()
	PLAYER.set_pix(pix)
	low_end = OS.has_feature("mobile") or (OS.has_feature("web") and cfg.touch_auto())
	fatigue = FATIGUE.new()
	platforms = [
		{"x": 520.0, "y": ground_y - 150.0, "w": 190.0},
		{"x": 170.0, "y": ground_y - 120.0, "w": 150.0},
		{"x": 960.0, "y": ground_y - 130.0, "w": 170.0},
		{"x": 1700.0, "y": ground_y - 140.0, "w": 220.0},
		{"x": 2250.0, "y": ground_y - 120.0, "w": 180.0},
	]
	train_platforms = platforms.duplicate()
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
	runes = RUNES.new()
	add_child(runes)
	runes.setup(self)
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
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.03, 0.02, 0.05, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(fade_rect)
	var hud := Control.new()
	hud.set_script(HUD)
	hud.arena = self
	ui.add_child(hud)
	dlg = Control.new()
	dlg.set_script(DIALOG)
	dlg.arena = self
	ui.add_child(dlg)
	ui.move_child(dlg, fade_rect.get_index())
	eil = Node.new()
	eil.set_script(EILIN)
	eil.arena = self
	add_child(eil)
	var tc := Control.new()
	tc.set_script(TOUCH)
	tc.arena = self
	ui.add_child(tc)
	fame = Node.new()
	fame.set_script(FAME)
	fame.arena = self
	add_child(fame)
	var ui2 := CanvasLayer.new()
	ui2.layer = 5
	add_child(ui2)
	ui_root = Control.new()
	ui_root.set_script(UIROOT)
	ui_root.arena = self
	ui2.add_child(ui_root)
	ult = Node2D.new()
	ult.set_script(ULT)
	ult.arena = self
	add_child(ult)
	var ui4 := CanvasLayer.new()
	ui4.layer = 4
	add_child(ui4)
	sortie = Control.new()
	sortie.set_script(SORTIE)
	sortie.arena = self
	ui4.add_child(sortie)
	post = CanvasLayer.new()
	post.set_script(POSTFX)
	post.arena = self
	add_child(post)
	move_child(post, ui.get_index())      # same layer as the HUD, ahead of it: the HUD stays out of the pass
	amb = Node.new()
	amb.set_script(AMBIENCE)
	amb.arena = self
	add_child(amb)
	save = SAVE.new(self)
	if get_tree().get_script() != null:
		save.path = "user://save_test.json"     # test runs never touch the real save
	call_deferred("_start_world")
	var stamp := Label.new()
	stamp.text = "STEP 4 · UI  ·  " + _stamp()
	stamp.add_theme_font_override("font", font_bold)
	stamp.add_theme_font_size_override("font_size", 11)
	stamp.modulate = Color(1, 1, 1, 0.45)
	stamp.position = Vector2(12, 480)
	ui.add_child(stamp)


## load silently (the title has no 이어하기): the saved scene, or the village street
var world_started := false
func _start_world() -> void:
	_start_world2()
	world_started = true

func _start_world2() -> void:
	var d = save.read() if get_tree().get_script() == null else null
	if d != null:
		var s: Array = save.apply(d)
		match s[0]:
			"hall":
				go_hall(clampi(s[3], 0, 3), s[1], s[2])
				return
			"training":
				go_training()
				return
		go_town(s[1], s[2])
		return
	go_town(Vector2(700.0, ground_y), 1)

func save_now() -> void:
	if save != null: save.save()

func _autosave() -> void:
	if save != null and player != null: save.save()

## the prototype wrote localStorage on every change; here: every 30 s of play, and whenever the page is hidden,
## the app loses focus or the window closes (a phone tab can be killed without warning)
var save_clock := 0.0
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST]:
		if world_started: _autosave()

# ---------- what the player / mobs ask (sortie, ult, elements) ----------
## keys forced by a scripted moment (ult move, sortie run / dash): null = her own
func forced_keys() -> Variant:
	if ult != null and ult.state != "": return {}
	if sortie != null: return sortie.forced()
	return null

func ult_gain(n: float) -> void:
	if ult != null: ult.gain(n)

## Estelle's vow (auto-parry) time left
func auto_parry() -> float:
	return ult.auto_t if ult != null else 0.0

func ult_busy() -> bool:
	return ult != null and ult.state != ""

func ult_alpha() -> float:
	return ult.ualpha if ult != null and ult.state == "act" else 1.0

func ucut():
	return sortie.ucut

## elemDamage + effTag + ultGain for a hit landing on a target with elements `defs`; returns the damage dealt
func elem_hit(p: Vector2, base: float, defs: Array) -> float:
	var who: String = hit_by if hit_by != "" else player.who
	var E: Dictionary = ELEM.damage(base, who, defs)
	ELEM.tag(self, p, E["mul"])
	ult_gain(E["dmg"] * 0.7)
	post_ca(0.003 + E["dmg"] * 0.0002)
	return E["dmg"]

## 화면 효과 (post_fx.gd): a shockwave ring at a world point / colour fringes on a hit
func post_wave(p: Vector2, strength := 1.0, life := 520.0, rad := 0.35) -> void:
	if post != null: post.wave(p, strength, life, rad)

func post_ca(v: float) -> void:
	if post != null: post.aberr(v)

## a mob's attack element against the member's own elements (hurtAmt)
func taken_mul(m) -> float:
	var el := "phys"
	if m != null and m.get("M") != null: el = String(m.M.get("atkEl", "phys"))
	return ELEM.taken_mul(el, player.who)

func _stamp() -> String:
	var f := FileAccess.open("res://build.txt", FileAccess.READ)
	return f.get_as_text().strip_edges() if f else "local"


## Arrow-key preset from the prototype: arrows move, Z jump, X attack, A guard, Shift dash. Pads too.
func setup_input() -> void:
	var map := {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": [KEY_Z], "attack": [KEY_X], "guard": [KEY_A], "dash": [KEY_SHIFT], "swap": [KEY_CTRL, KEY_C],
	}
	var pad := {"jump": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "dash": JOY_BUTTON_B, "guard": JOY_BUTTON_RIGHT_SHOULDER, "swap": JOY_BUTTON_Y,
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
	if not InputMap.has_action("ult"): InputMap.add_action("ult", 0.3)   # 궁극기: D (settings.gd binds the keys) / RT; no ult yet
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	InputMap.action_add_event("ult", rt)


## "town" / "hall" / "dungeon", or "" on the training ground
func level_kind() -> String:
	return "" if level == null else String(level.kind)

func open_dialog(who: String, por: Texture2D, nm: String, role: String, lines: Array, cb = null) -> void:
	dlg.open(who, por, nm, role, lines, cb)

## the shared clock's light: sky tint, ambient, sun and lamp strength (town.gd TODK)
func tod_now() -> Dictionary:
	var hh := fposmod(tod_h, 24.0)
	var K: Array = TOWN.TODK
	var i := 0
	while i < K.size() - 2 and K[i + 1][0] <= hh: i += 1
	var a: Array = K[i]
	var b: Array = K[i + 1]
	var k: float = (hh - a[0]) / maxf(0.001, b[0] - a[0])
	var sky := Color(lerpf(a[1][0], b[1][0], k) / 255.0, lerpf(a[1][1], b[1][1], k) / 255.0, lerpf(a[1][2], b[1][2], k) / 255.0, lerpf(a[1][3], b[1][3], k))
	var amb := Color(lerpf(a[2][0], b[2][0], k), lerpf(a[2][1], b[2][1], k), lerpf(a[2][2], b[2][2], k))
	if weather != "clear":
		# overcast: the sky greys over, the light drops, lamps stay lit
		var r := weather == "rain"
		sky = Color(sky.r * 0.5 + 110.0 / 255.0 * 0.5, sky.g * 0.5 + 118.0 / 255.0 * 0.5, sky.b * 0.5 + 132.0 / 255.0 * 0.5, maxf(sky.a, 0.42 if r else 0.3))
		amb = Color(amb.r * (0.78 if r else 0.92), amb.g * (0.78 if r else 0.92), amb.b * (0.78 if r else 0.92))
		if not r: amb.b = minf(1.0, amb.b * 1.06)
		return {"sky": sky, "amb": amb, "sun": lerpf(a[3], b[3], k) * 0.25, "lamp": maxf(lerpf(a[4], b[4], k), 0.5)}
	return {"sky": sky, "amb": amb, "sun": lerpf(a[3], b[3], k), "lamp": lerpf(a[4], b[4], k)}

## a member leaves the party for town (or comes back); the townsfolk take over whoever is not along
func toggle_member(c: String) -> void:
	var P = player
	if P.party.has(c):
		if P.party.size() < 2: return
		if P.who == c:
			P.swap_cd = 0.0
			P.swap(false, P.party.filter(func(x): return x != c)[0])
		P.party.erase(c)
		FOLK.of(self).leave_party(c)
	else:
		P.party.append(c)
		FOLK.of(self).join_party(c)

func foes() -> Array:
	return (dummies if level == null else []) + mobs.filter(func(m): return m.alive())

func view_rect() -> Rect2:
	var vs := get_viewport_rect().size
	var c := cam.get_screen_center_position()
	return Rect2(c - vs / 2.0, vs)

func snap_camera() -> void:
	cam.limit_right = int(world_w)
	cam.limit_top = int(ceil_y + 100.0) if level != null else 0
	cam.limit_bottom = int(H) if level == null else 100000
	cam.position = Vector2(player.position.x, cam_y_target())
	cam.reset_smoothing()

func cam_y_target() -> float:
	if level == null:
		return H / 2.0
	if level.kind == "hall":
		return H / 2.0 + (-90.0 if player.position.y < ground_y - 120.0 else 0.0)
	if level.kind == "town":
		return clampf(player.position.y - 110.0, level.TTOP - 460.0 + H / 2.0, level.LOWF + 120.0 - H / 2.0)
	return clampf(player.position.y - 110.0, ceil_y + 100.0 + H / 2.0, ground_y + 70.0 - H / 2.0)

## black out, run cb, come back
func fade_then(cb: Callable) -> void:
	if fade_dir != 0: return
	fade_dir = 1
	fade_cb = cb

func clear_room() -> void:
	for m in mobs: m.queue_free()
	mobs.clear()
	proj.clear()
	luce_fx.clear()
	fx.clear()
	big_words.clear()
	witch = 0.0
	player.ghosts.clear()
	player.outs.clear()

func _drop_level() -> void:
	clear_room()
	if level != null:
		level.cleanup()
	level = null
	solids = []
	ceil_y = -1.0e9
	player.plat = null

func enter_dungeon() -> void:
	_drop_level()
	for d in dummies: d.visible = false
	level = Node2D.new()
	level.set_script(DUNGEON)
	level.arena = self
	add_child(level)
	level.generate()
	level.enter()
	_autosave()

## back from the cave: the party comes out by the sortie wagon
func leave_dungeon() -> void:
	go_town(Vector2(5107.0, ground_y), -1)

func go_town(at: Vector2, d: int) -> void:
	_drop_level()
	for dm in dummies: dm.visible = false
	platforms = []
	level = Node2D.new()
	level.set_script(TOWN)
	level.arena = self
	add_child(level)
	world_w = level.TOWN_W
	player.position = at
	player.dir = d
	player.on = true
	player.vy = 0.0
	snap_camera()
	_autosave()

## into the guild hall: floor fl, standing at `at`
func go_hall(fl: int, at: Vector2, d: int) -> void:
	_drop_level()
	for dm in dummies: dm.visible = false
	platforms = []
	player.position = at
	player.dir = d
	player.on = true
	player.vy = 0.0
	level = Node2D.new()
	level.set_script(HALL)
	level.arena = self
	level.fl = fl
	add_child(level)
	world_w = level.W
	snap_camera()
	_autosave()

func go_training() -> void:
	_drop_level()
	for dm in dummies: dm.visible = true
	world_w = 2800.0
	platforms = train_platforms.duplicate()
	player.position = Vector2(560.0, ground_y)
	player.dir = 1
	player.on = true
	wave = 0
	wave_t = 1500.0
	snap_camera()
	_autosave()

func party_wiped() -> void:
	if level_kind() == "dungeon":
		fade_then(func(): go_town(Vector2(5107.0, ground_y), -1))

func try_interact() -> bool:
	if level != null:
		return level.try_interact()
	if near_entry:
		sfx("ready", 0.6)
		fade_then(func(): enter_dungeon())
		return true
	if near_exit:
		sfx("ready", 0.6)
		fade_then(func(): go_town(Vector2(820.0 + 378.0, ground_y), 1))
		return true
	return false

func platform_under(p: Vector2):
	for pl in platforms:
		if absf(p.y - pl.y) < 1.0 and p.x > pl.x - 2.0 and p.x < pl.x + pl.w + 2.0:
			return pl
	return null


func _process(delta: float) -> void:
	if ui_root != null and ui_root.holds():
		return            # the world holds still under the title, a menu page or a transition
	if fame != null and fame.holds():
		return            # …and under the rank cut and the guild's title cards
	var dt := minf(delta * 1000.0, 50.0)
	save_clock += dt
	if save_clock > 30000.0:
		save_clock = 0.0
		_autosave()
	if sortie != null and (sortie.holds() or sortie.pre_step()):
		return            # a title card, the dungeon select, the clear screen or the party screen holds the world
	if ult != null:
		if Input.is_action_just_pressed("ult") and not dlg.active: ult.try_ult()
		if ult.state == "cut":
			ult.cut_step(dt)          # the cut-in holds the world
			return
	if witch > 0.0:
		witch -= dt
		if witch <= 0.0:
			sfx("witch_end", 0.8)
	var wk := 0.22 if witch > 0.0 else 1.0   # the world slows; Estelle does not
	if tod_auto and not dlg.active:
		tod_h = fposmod(tod_h + dt / 1000.0 / 60.0, 24.0)      # one in-game hour per real minute
	if dlg.active:
		# a talk box holds the world still; she keeps talking (her loop runs)
		dlg.step(dt)
		eil.upd(dt)
		if level != null: level.step(dt)
	elif hitstop > 0.0:
		hitstop -= dt
	else:
		player.step(dt)
		if sortie != null: sortie.post_player(dt)
		if ult != null:
			ult.tick(dt)
			ult.step(dt)
		for d in dummies:
			d.step(dt)
		for m in mobs:
			m.step(dt * wk)
		step_proj(dt * wk)
		step_luce(dt)
		dodge_check()
		step_waves(dt)
		eil.world(dt)
		var lk := level_kind()
		if lk == "hall" or lk == "town": eil.upd(dt)
		if level != null:
			level.step(dt)
		else:
			near_entry = absf(player.position.x - (world_w - 110.0)) < 90.0 and player.on and absf(player.position.y - ground_y) < 4.0
			near_exit = absf(player.position.x - 450.0) < 46.0 and player.on and absf(player.position.y - ground_y) < 4.0
	# fades between rooms
	if fade_dir == 1:
		fade = minf(1.0, fade + dt / 260.0)
		if fade >= 1.0:
			var cb = fade_cb
			fade_cb = null
			if cb != null: cb.call()
			fade_dir = -1
	elif fade_dir == -1:
		fade = maxf(0.0, fade - dt / 260.0)
		if fade <= 0.0: fade_dir = 0
	fade_rect.color.a = fade
	if ult != null: ult.fx_step(dt)
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
	witch_rect.color.a = 0.0 if screen_fx else wa     # with 화면 효과 on the post pass grades it instead
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
	var target := Vector2(player.position.x, cam_y_target())
	if player.cam_focus["t"] > 0.0:
		target.x = player.cam_focus["x"]
	cam.position.x = lerpf(cam.position.x, target.x, minf(1.0, dt / 90.0))
	cam.position.y = lerpf(cam.position.y, target.y, minf(1.0, dt / 140.0))
	cam.offset = Vector2(randf_range(-1, 1) * shake_amt * 0.6 + shake_dir * shake_amt * 0.3, randf_range(-1, 1) * shake_amt * 0.4)
	queue_redraw()
	fx_layer.queue_redraw()


# ---------- background & ground ----------
func _draw() -> void:
	if level != null:
		return
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
	# the way back to town
	var tl := "길드 마을로" + ("  ·  공격 키" if near_exit else "")
	var tlw := font_black.get_string_size(tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0
	draw_rect(Rect2(450.0 - tlw / 2.0, ground_y - 200.0, tlw, 24.0), Color(0, 0, 0, 0.6))
	draw_string(font_black, Vector2(450.0 - tlw / 2.0 + 10.0, ground_y - 183.0), tl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffe9a8"))
	draw_rect(Rect2(440.0, ground_y - 170.0, 4.0, 170.0), Color(0.35, 0.28, 0.2))
	# the way into the cave: a dark mouth at the right end of the training ground
	var ex := world_w - 110.0
	draw_rect(Rect2(ex - 60.0, ground_y - 150.0, 120.0, 150.0), Color(0.08, 0.06, 0.1))
	draw_circle(Vector2(ex, ground_y - 150.0), 60.0, Color(0.08, 0.06, 0.1))
	draw_rect(Rect2(ex - 60.0, ground_y - 150.0, 6.0, 150.0), Color(0.35, 0.3, 0.25))
	draw_rect(Rect2(ex + 54.0, ground_y - 150.0, 6.0, 150.0), Color(0.35, 0.3, 0.25))
	var lbl := "버섯 동굴" + ("  ·  공격 키로 입장" if near_entry else "")
	var lw := font_black.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0
	draw_rect(Rect2(ex - lw / 2.0, ground_y - 250.0, lw, 24.0), Color(0, 0, 0, 0.6))
	draw_string(font_black, Vector2(ex - lw / 2.0 + 10.0, ground_y - 233.0), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ffe9a8"))
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
func spawn(k: String, x: float, delay: float, y := -1.0, pl = null, elite := false, tier := 0):
	var m := Node2D.new()
	m.set_script(MOB)
	m.arena = self
	if y < 0.0: y = ground_y
	add_child(m)
	m.setup(k, Vector2(x, y), delay, elite, tier)
	m.pl = pl
	m.z_index = 1
	mobs.append(m)
	return m

func step_waves(dt: float) -> void:
	if level != null:
		return
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

func shoot(m, p: Vector2, v: Vector2, big := false) -> void:
	proj.append({"x": p.x, "y": p.y, "vx": v.x, "vy": v.y, "t": 0.0, "life": 1800.0 if big else 2600.0, "m": m, "big": big})

func step_proj(dt: float) -> void:
	var P = player
	proj = proj.filter(func(p):
		p["t"] += dt
		p["x"] += p["vx"] * dt
		p["y"] += p["vy"] * dt
		var R: float = 74.0 if p["big"] else 32.0
		if absf(P.position.x - p["x"]) < R and p["y"] > P.position.y - 130.0 * 1.3 and p["y"] < P.position.y + 4.0:
			var r: String = P.take_hit(p["m"], p["m"].M["atk"] * (1.2 if p["big"] else 0.8))
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
	post_wave(player.position + Vector2(0, -60.0 * 1.3), 1.4, 600.0, 0.3)
	post_ca(0.02)
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
	post_wave(P.position + Vector2(d * 50.0 * 1.3, -70.0 * 1.3), 1.1, 480.0, 0.22)
	post_ca(0.012)

func perfect_parry(m) -> void:
	witch = maxf(witch, 560.0)
	witch_max = maxf(witch_max, 560.0)
	m.hurt_t = maxf(m.hurt_t, 1400.0)
	m.kx = player.dir * 2.2
	m.flare_t = -1.0
	sfx("heavy", 0.7)
	post_wave(Vector2((player.position.x + player.dir * 52.0 + m.position.x) / 2.0, player.position.y - 72.0 * 1.3), 1.8, 700.0, 0.35)

func big_word(s: String, col: Color, life: float, off: Vector2, at := Vector2.INF) -> void:
	var p: Vector2 = at if at != Vector2.INF else player.position + off
	big_words.append({"s": s, "col": col, "t": 0.0, "life": life, "x": p.x, "y": p.y, "screen": off == Vector2.ZERO and at == Vector2.INF})

func shake(amt: float, d: int) -> void:
	shake_amt = maxf(shake_amt, amt)
	shake_dir = d

func slash_fx(c: Vector2, r: float, a0: float, a1: float, d: int, col := Color(1.0, 0.55, 0.82)) -> void:
	fx.append({"k": "slash", "x": c.x, "y": c.y, "r": r, "a0": a0, "a1": a1, "d": d, "col": col, "t": 0.0, "life": 170.0})

func streak_fx(x0: float, x1: float, y: float, d: int, col := Color(1, 0.8, 0.93)) -> void:
	fx.append({"k": "streak", "x": x0, "x1": x1, "y": y, "d": d, "col": col, "t": 0.0, "life": 160.0})

func dust(p: Vector2, d: int, heavy: bool) -> void:
	for i in (8 if heavy else 4):
		var sx := (randf() - 0.5) * 0.12 + d * 0.08
		fx.append({"k": "dust", "x": p.x + (randf() - 0.5) * 30.0, "y": p.y - randf() * 6.0, "vx": sx, "vy": -0.04 - randf() * 0.06, "r": 4.0 + randf() * 5.0, "t": 0.0, "life": 320.0})

func ring(p: Vector2, r: float, col := Color(1, 0.8, 0.95)) -> void:
	fx.append({"k": "ring", "x": p.x, "y": p.y, "r": r, "col": col, "t": 0.0, "life": 260.0})

func spark(p: Vector2, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var s := 0.25 + randf() * 0.4
		fx.append({"k": "sp", "x": p.x, "y": p.y, "vx": cos(a) * s, "vy": sin(a) * s, "t": 0.0, "life": 140.0 + randf() * 120.0})

func damage_text(p: Vector2, value: int, big: bool) -> void:
	fx.append({"k": "txt", "x": p.x + randf_range(-10, 10), "y": p.y, "s": str(value), "big": big, "t": 0.0, "life": 600.0})

func charge_fx(p: Vector2, t: float, col := Color(1.0, 0.47, 0.75)) -> void:
	if randf() < 0.35:
		var a := randf() * TAU
		var r := 40.0 + randf() * 20.0
		fx.append({"k": "mote", "x": p.x + cos(a) * r, "y": p.y + sin(a) * r, "tx": p.x, "ty": p.y, "full": t >= 650.0, "col": col, "t": 0.0, "life": 220.0})


# ---------- Luce's light ----------
## a light bolt: rises up-and-back, holds a beat, then shoots and homes in on the target
func bolt(o: Vector2, tg, sz: float, hold: float, d: int) -> void:
	var b := {"by": player.who, "k": "bolt", "x": o.x, "y": o.y, "vx": d * 0.001, "vy": 0.0, "tg": tg, "sz": sz, "hold": hold, "hits": [], "home": 0.011, "dmg": 1.0, "mul": player.atk_mul(), "d": d, "t": 0.0, "life": 1100.0 + hold, "tr": []}
	if tg == null:
		b["home"] = 0.0
	luce_fx.append(b)

func pillar(x: float, y: float, dmg: float, d: int) -> void:
	luce_fx.append({"by": player.who, "k": "pillar", "x": x, "y": y, "dmg": dmg, "d": d, "hits": [], "mul": player.atk_mul(), "t": 0.0, "life": 420.0})
	sfx("ready", 0.4)

func lightning(x: float, y: float, sz: float, dmg: float, d: int) -> void:
	post_wave(Vector2(x, y - 20.0), 0.5 * sz, 420.0, 0.12 + 0.06 * sz)
	post_ca(0.004 * sz)
	var pts := PackedVector2Array()
	var px := x + (randf() - 0.5) * 60.0
	var py := -20.0
	while py < y - 30.0:
		pts.append(Vector2(px, py))
		py += 30.0 + randf() * 30.0
		px += (x - px) * 0.35 + (randf() - 0.5) * 50.0 * sz
	pts.append(Vector2(x, y))
	luce_fx.append({"by": player.who, "k": "lightning", "x": x, "y": y, "sz": sz, "dmg": dmg, "d": d, "pts": pts, "hits": [], "mul": player.atk_mul(), "t": 0.0, "life": 380.0})
	flash = maxf(flash, 0.12 + 0.06 * sz)

func step_luce(dt: float) -> void:
	for f in luce_fx:
		hit_by = String(f.get("by", ""))
		f["t"] += dt
		if f["k"] == "bolt":
			var tg = f["tg"]
			var live: bool = tg != null and is_instance_valid(tg) and tg.alive()
			if f["hold"] > 0.0:
				f["hold"] -= dt
				var tp: Vector2 = (tg.position + Vector2(0, -50)) if live else Vector2(f["x"] + f["d"] * 400.0, f["y"] + 40.0)
				var dv := (tp - Vector2(f["x"], f["y"])).normalized()
				f["y"] -= 0.01 * dt
				if f["hold"] <= 0.0:
					f["vx"] = dv.x * 1.35
					f["vy"] = dv.y * 1.35
					if not live: f["tg"] = null
					sfx("thrust", 0.5)
				continue
			if live:
				var tp2: Vector2 = tg.position + Vector2(0, -50)
				var dv2 := (tp2 - Vector2(f["x"], f["y"])).normalized()
				var sp := minf(1.25, Vector2(f["vx"], f["vy"]).length() + 0.0012 * dt)
				var k2 := minf(1.0, dt * f["home"] * (1.0 + f["t"] / 250.0))
				var v := Vector2(f["vx"], f["vy"]).lerp(dv2 * sp, k2).normalized() * sp
				f["vx"] = v.x
				f["vy"] = v.y
			f["x"] += f["vx"] * dt
			f["y"] += f["vy"] * dt
			f["tr"].append(Vector2(f["x"], f["y"]))
			if f["tr"].size() > 8: f["tr"].pop_front()
			var R: float = 16.0 * f["sz"]
			for m in foes():
				if f["hits"].has(m): continue
				if absf(m.position.x - f["x"]) < R + 20.0 and m.position.y - 95.0 < f["y"] + R and m.position.y > f["y"] - R:
					f["hits"].append(m)
					m.hit(f["dmg"], signf(f["vx"]) * 4.0, f["mul"])
					spark(Vector2(f["x"], f["y"]), 8)
					sfx("hit", 0.6)
					f["t"] = f["life"] + 1.0
					break
			if f["y"] > ground_y + 10.0 or f["x"] < -60.0 or f["x"] > world_w + 60.0:
				f["t"] = f["life"] + 1.0
		elif f["t"] < 120.0:
			var R2: float = 48.0 if f["k"] == "pillar" else 40.0 * f["sz"]
			for m in foes():
				if f["hits"].has(m): continue
				if absf(m.position.x - f["x"]) < R2 + 20.0 and m.position.y > f["y"] - 220.0 and m.position.y - 95.0 < f["y"] + 10.0:
					f["hits"].append(m)
					m.hit(f["dmg"], f["d"] * 6.0, f["mul"])
					spark(m.position + Vector2(0, -50), 12)
	hit_by = ""
	luce_fx = luce_fx.filter(func(f): return f["t"] < f["life"])

func _draw_luce() -> void:
	var gold := Color(1.0, 0.86, 0.45)
	for f in luce_fx:
		var k: float = f["t"] / f["life"]
		match f["k"]:
			"bolt":
				var tr: Array = f["tr"]
				for i in tr.size():
					var a := float(i + 1) / tr.size()
					fx_layer.draw_circle(tr[i], 5.0 * f["sz"] * a, Color(1, 0.8, 0.4, 0.35 * a))
				var c := Vector2(f["x"], f["y"])
				fx_layer.draw_circle(c, 11.0 * f["sz"], Color(1, 0.78, 0.3, 0.45))
				fx_layer.draw_circle(c, 6.0 * f["sz"], Color(1, 0.95, 0.75))
				fx_layer.draw_circle(c, 3.0 * f["sz"], Color.WHITE)
			"pillar":
				var e := minf(1.0, k / 0.2)
				var fade := 1.0 - maxf(0.0, (k - 0.55) / 0.45)
				var w := 46.0 * e
				var top: float = f["y"] - 420.0 * e
				fx_layer.draw_rect(Rect2(f["x"] - w, top, w * 2.0, f["y"] - top), Color(1, 0.8, 0.35, 0.35 * fade))
				fx_layer.draw_rect(Rect2(f["x"] - w * 0.45, top, w * 0.9, f["y"] - top), Color(1, 0.95, 0.75, 0.8 * fade))
				fx_layer.draw_rect(Rect2(f["x"] - w * 1.3, f["y"] - 6.0, w * 2.6, 6.0), Color(1, 1, 1, 0.8 * fade))
			"lightning":
				var fade2 := 1.0 if k < 0.15 else 1.0 - (k - 0.15) / 0.85
				fx_layer.draw_polyline(f["pts"], Color(1, 0.85, 0.4, 0.5 * fade2), 10.0 * f["sz"])
				fx_layer.draw_polyline(f["pts"], Color(1, 1, 0.9, fade2), 3.0 * f["sz"])
				fx_layer.draw_circle(Vector2(f["x"], f["y"]), 40.0 * f["sz"] * (0.5 + k), Color(1, 0.9, 0.5, 0.4 * fade2))
	# Aida's rift sigil while aiming
	if mark_pos != Vector2.INF:
		var tt := Time.get_ticks_msec() / 1000.0
		fx_layer.draw_arc(mark_pos + Vector2(0, -40), 26.0, tt * 3.0, tt * 3.0 + TAU * 0.8, 24, Color(0.75, 0.55, 1.0, 0.9), 3.0)
		fx_layer.draw_arc(mark_pos + Vector2(0, -40), 16.0, -tt * 4.0, -tt * 4.0 + TAU * 0.6, 18, Color(0.95, 0.85, 1.0, 0.9), 2.0)
		fx_layer.draw_line(player.position + Vector2(0, -60), mark_pos + Vector2(0, -40), Color(0.75, 0.55, 1.0, 0.35), 2.0)

func _draw_fx() -> void:
	_draw_luce()
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
					fx_layer.draw_colored_polygon(pts, Color(e["col"], 0.75 * (1.0 - k)))
					fx_layer.draw_polyline(pts.slice(0, n + 1), Color(1, 1, 1, 1.0 - k), 2.0)
			"streak":
				var w: float = (e["x1"] - e["x"]) * minf(1.0, k * 3.0)
				fx_layer.draw_rect(Rect2(minf(e["x"], e["x"] + w), e["y"] - 5.0 * (1.0 - k), absf(w), 10.0 * (1.0 - k)), Color(e["col"], 1.0 - k))
				fx_layer.draw_rect(Rect2(minf(e["x"], e["x"] + w), e["y"] - 1.0, absf(w), 2.0), Color(1, 1, 1, 1.0 - k))
			"dust":
				fx_layer.draw_circle(Vector2(e["x"], e["y"]), e["r"] * (1.0 + k), Color(0.85, 0.78, 0.68, 0.5 * (1.0 - k)))
			"ring":
				fx_layer.draw_arc(Vector2(e["x"], e["y"]), e["r"] * (0.5 + k), 0, TAU, 24, Color(e["col"], 1.0 - k), 2.0)
			"sp":
				fx_layer.draw_rect(Rect2(e["x"] - 2, e["y"] - 2, 4, 4), Color(1, 0.85, 0.92, 1.0 - k))
			"mote":
				var p := Vector2(e["x"], e["y"]).lerp(Vector2(e["tx"], e["ty"]), k)
				fx_layer.draw_rect(Rect2(p.x - 1.5, p.y - 1.5, 3, 3), Color(1, 1, 1, 0.9) if e["full"] else e["col"])
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
		fx_layer.draw_set_transform(Vector2(p["x"], p["y"]), 0.0, Vector2(-1.0 if p["vx"] < 0.0 else 1.0, 1.0))
		if p["big"]:
			fx_layer.draw_texture_rect_region(t_wave, Rect2(-92.0, -102.0, 184.0, 204.0), Rect2(fr * 92, 0, 92, 102))
		else:
			fx_layer.draw_texture_rect_region(t_proj, Rect2(-24.0 * 2.2, -24.0 * 2.2, 48.0 * 2.2, 48.0 * 2.2), Rect2(fr * 48, 0, 48, 48))
		fx_layer.draw_set_transform(Vector2.ZERO)
	# PARRY / 극한 회피 words over her head
	for w in big_words:
		if w["screen"]:
			continue
		var u2: float = w["t"] / w["life"]
		var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - u2 * 6.0)
		var al := 1.0 - maxf(0.0, (u2 - 0.65) / 0.35)
		var fs2 := int(40 * pop)
		var fnt: Font = font_anton if String(w["s"]).unicode_at(0) < 128 else font_black
		var ww := fnt.get_string_size(w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var pos := Vector2(w["x"] - ww / 2.0, w["y"] - 10.0 * u2)
		fx_layer.draw_string_outline(fnt, pos, w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, 10, Color(0.05, 0.02, 0.06, al))
		fx_layer.draw_string(fnt, pos, w["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(w["col"], al))



## test keys: F2 = straight into the cave, F3 = clear the room, F4 = next room, F5 = jump around town, F6 = +3 hours,
## F7 = straight into the guild hall, F8 = next hall floor, F9 = Eilin straight to where her day says she should be,
## F10 = weather (clear / rain / snow), F11 = Luce leaves / rejoins the party (she lives in town meanwhile), Shift+F11 = the same for Aida,
## F12 = fill the 기력 gauge, Shift+F4 = straight to the boss room
var tp_i := 0
func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_F2 and level == null:
			fade_then(func(): enter_dungeon())
		elif ev.keycode == KEY_F3:
			for m in mobs:
				if not m.is_dead(): m.hit(999.0, 0.0)
		elif ev.keycode == KEY_F5 and level_kind() == "town":
			var spots := [700.0, 2100.0, 3024.0, 4400.0, 5107.0, 3000.0, 7550.0, 8750.0]
			tp_i = (tp_i + 1) % spots.size()
			var x: float = spots[tp_i]
			var y: float = level.LOWF if tp_i >= 5 else level.floor_at(x)
			player.position = Vector2(x, y)
			player.plat = null
			player.vy = 0.0
			snap_camera()
		elif ev.keycode == KEY_F6:
			tod_h = fposmod(tod_h + 3.0, 24.0)
		elif ev.keycode == KEY_F7 and not dlg.active:
			var s0: Array = HALL.HD.SPAWN[0]
			fade_then(func(): go_hall(0, Vector2(s0[0], s0[1]), s0[2]))
		elif ev.keycode == KEY_F8 and level_kind() == "hall" and not dlg.active:
			var n: int = (level.fl + 1) % 4
			var s1: Array = HALL.HD.SPAWN[n]
			fade_then(func(): go_hall(n, Vector2(s1[0], s1[1]), s1[2]))
		elif ev.keycode == KEY_F9:
			eil.snap()
		elif ev.keycode == KEY_F10:
			weather = WEATHERS[(WEATHERS.find(weather) + 1) % WEATHERS.size()]
		elif ev.keycode == KEY_F11 and not dlg.active:
			toggle_member("aida" if ev.shift_pressed else "luce")
		elif ev.keycode == KEY_INSERT and ult != null:
			ult.v[player.who] = ult.ULTMAX[player.who]     # test: fill the 기력 gauge, clear the cooldown
			ult.cd[player.who] = 0.0
			sfx("ready", 0.8)
		elif ev.keycode == KEY_F4 and ev.shift_pressed and level_kind() == "dungeon":
			for k in level.rooms:                          # test: straight to the boss room
				if level.rooms[k]["type"] == "boss":
					level.from = "L"
					level.cur = k
					fade_then(func(): level.enter())
		elif ev.keycode == KEY_F4 and level_kind() == "dungeon":
			var rm = level.room()
			for d in level.doors:
				if d["town"]: continue
				var n = level.rooms[level.rkey(rm["x"] + level.DIRS[d["d"]][0], rm["y"] + level.DIRS[d["d"]][1])]
				if not n["visited"]:
					level.near_gate = d
					level.try_interact()
					return


## fame rewards a rune by grade (fame.gd pay_out): a random non-unique rune of that grade goes into the bag
func give_rune(g: String) -> String:
	if runes == null: return ""
	var pool: Array = runes.RUNE.keys().filter(func(r): return runes.RUNE[r]["g"] == g)
	if pool.is_empty(): return ""
	var r: String = pool[randi() % pool.size()]
	runes.add_rune(r)
	return r
