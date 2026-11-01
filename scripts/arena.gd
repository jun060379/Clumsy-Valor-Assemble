extends Node2D
## Training ground (훈련장): the yard drawn by training.gd, one-way platforms, practice dummies (an unbreakable row on the right)
## and the ghost (ghost.gd), as in the prototype's arena.
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
const SLOWBUS := preload("res://scripts/slow_bus.gd")
const DEV := preload("res://scripts/dev.gd")
const POSTFX := preload("res://scripts/post_fx.gd")
const PFX := preload("res://scripts/pfx.gd")
const SPK := {"estelle": Color("#ffd9ea"), "aida": Color("#c9a6ff"), "luce": Color("#fff3c4")}             # PAL[].sp
const SLC := {"estelle": Color(1, 120 / 255.0, 190 / 255.0, 0.9), "aida": Color(150 / 255.0, 90 / 255.0, 230 / 255.0, 0.95), "luce": Color(1, 215 / 255.0, 110 / 255.0, 0.95)}   # PAL[].slash
const BUC := {"estelle": Color8(255, 200, 230), "aida": Color8(190, 150, 255), "luce": Color8(255, 240, 200)}   # PAL[].burst
const FATIGUE := preload("res://scripts/fatigue.gd")
const UIROOT := preload("res://scripts/ui_root.gd")
const RUNES := preload("res://scripts/runes.gd")
const FAME := preload("res://scripts/fame.gd")
const SORTIE := preload("res://scripts/sortie.gd")
const ULT := preload("res://scripts/ult.gd")
const SAVE := preload("res://scripts/save_game.gd")
const ELEM := preload("res://scripts/elements.gd")
const GHOST := preload("res://scripts/ghost.gd")
const TRAINING := preload("res://scripts/training.gd")
const AW := 2000.0            # training ground width

const H := 500.0
var ground_y := H - 70.0
var world_w := AW
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
var ghost                     # the training ground's ghost (ghost.gd)
var train                     # the training ground's scenery, lamps and gate (training.gd), while she is there
var score := 0                # training ground SCORE / BEST (hits, breaks, banishing the ghost, parrying it)
var best := 0
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
var shilling := 12              # prototype IRON = 12 at the start
var fade_rect: ColorRect
var fade := 0.0
var fade_dir := 0
var fade_cb = null
var train_platforms: Array = []
# front end (step 4): settings, 피로도, title / menus
var cfg                       # settings.gd: device, stick, key bindings (saved)
var fatigue                   # fatigue.gd: 피로도 160, +1 / 6 min (nothing spends it yet)
var ambient := true           # 환경음 (ambience.gd)
var post                      # post_fx.gd: shockwaves, colour fringes, vignette, the dodge grade (화면 효과)
var low_end := false          # a phone (web + touch-first): fewer, wider lights
var amb                       # ambience.gd: wind / rain / water loops, birds, crickets, fires, the hall's creaks and clock
var slow_bus
var screen_fx := true         # 화면 효과 (post_fx.gd)
var pix := "shade"            # 캐릭터 도트화 (charPix, default 도트+셰이딩 as PIXCH): off / dot / shade (player.gd pix_mat, shaders/char_pix.gdshader)
var ui_root                   # ui_root.gd: title, top-right buttons, main menu, transitions
var runes                     # runes.gd: runes, gear, shillings' drops, the boss chest, the bestiary record
var fame                      # fame.gd: guild fame, quests, adventurer level, the guild / adventure books' data, cut-ins
# step 4-2 / 5-3: sortie flow, 궁극기, elements, save
var sortie                    # sortie.gd: dungeon select, band sweeps, entry dash, deploy cut, title cards, clear screen, party screen
var ult                       # ult.gd: 기력 gauges, the ult moves and their world effects
var save                      # save_game.gd: user://save.json
var hit_by := ""              # who a delayed hit (Luce's light) belongs to, for its element
var last_e := {}              # the last elemDamage result, so damage_text can split a hybrid hit per element

var fx_layer: Node2D
var pfx                       # pfx.gd: the pixel-art effects (swings, hits, tells, rifts, Luce's light, dodge afterimages)
var flash_rect: ColorRect


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0d0b10"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fit_view()
	get_tree().root.size_changed.connect(fit_view)
	setup_input()
	cfg = SETTINGS.new(self)
	cfg.apply_keys()
	PLAYER.set_pix(pix)
	cfg.apply_qk()
	get_tree().root.size_changed.connect(func(): cfg.apply_qk())
	low_end = OS.has_feature("mobile") or (OS.has_feature("web") and cfg.touch_auto())
	fatigue = FATIGUE.new()
	platforms = [
		{"x": 520.0, "y": ground_y - 150.0, "w": 190.0},
		{"x": 170.0, "y": ground_y - 120.0, "w": 150.0},
		{"x": 960.0, "y": ground_y - 130.0, "w": 170.0},
	]
	train_platforms = platforms.duplicate()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float flash = 0.0;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV) * COLOR; c.rgb = mix(c.rgb, vec3(1.0), flash); COLOR = c; }"
	flash_mat.shader = sh
	for i in 8:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		sfx_pool.append(ap)
	# spawnDummy: two on platforms, two on the ground, then a row of six that never break (damage testing)
	var spots := [[600.0, ground_y - 150.0], [760.0, ground_y], [250.0, ground_y - 120.0], [80.0, ground_y]]
	for i in 6: spots.append([1300.0 + i * 115.0, ground_y, true])
	for s in spots:
		var d := Node2D.new()
		d.set_script(DUMMY)
		d.position = Vector2(s[0], s[1])
		d.arena = self
		d.inv = s.size() > 2
		add_child(d)
		dummies.append(d)
	ghost = Node2D.new()
	ghost.set_script(GHOST)
	ghost.arena = self
	ghost.visible = false
	add_child(ghost)
	shadow_node = Node2D.new()
	shadow_node.draw.connect(_draw_shadow)
	add_child(shadow_node)
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
	# Aida's rift sigil: the diamonds glow additively ('lighter'), the eye, range ring, thread and landing mark draw normally
	sigil_add = Node2D.new()
	sigil_add.z_index = 10
	var am := CanvasItemMaterial.new()
	am.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sigil_add.material = am
	sigil_add.draw.connect(_draw_sigil_add)
	add_child(sigil_add)
	sigil_top = Node2D.new()
	sigil_top.z_index = 10
	sigil_top.draw.connect(_draw_sigil_top)
	add_child(sigil_top)
	pfx = Node2D.new()
	pfx.set_script(PFX)
	pfx.arena = self
	add_child(pfx)
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(world_w)
	cam.limit_top = -100000
	cam.limit_bottom = 100000
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
	# parryWord sits over the HUD (z-index 92 over the page)
	var pl3 := CanvasLayer.new()
	pl3.layer = 3
	add_child(pl3)
	pryw_node = Control.new()
	pryw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pryw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	pryw_node.draw.connect(_draw_pryw)
	pl3.add_child(pryw_node)
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
	slow_bus = Node.new()                 # witch time: every sound through the "Slow" bus (slow_bus.gd)
	slow_bus.set_script(SLOWBUS)
	slow_bus.arena = self
	add_child(slow_bus)
	save = SAVE.new(self)
	if get_tree().get_script() != null:
		save.path = "user://save_test.json"     # test runs never touch the real save
	call_deferred("_start_world")
	if DEV.on:                            # the build stamp: debug builds only (dev.gd)
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
	go_town(Vector2(380.0, ground_y), 1)

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
	if ult != null: ult.gain(n * (runes.ult_k() if runes != null else 1.0))   # ultGain wraps: 고요한 기도, 기력 획득 gear, memory nodes

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
	last_e = E
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
	# the keyboard keys come from settings.gd (apply_keys: KB_PRE / the player's own binding); this is the pad.
	# PADBTN (standard mapping): A = jump (+Enter), B = dash (+Esc), X = attack, Y and LT = skill (KeyC → guard),
	# LB and RB = swap (Tab → partyInput), RT = ult (KeyQ), the d-pad = arrows. Start / Back (menu / 설정) are read by menu.gd.
	# padPoll: a button counts once it is pressed or past .5; the left stick moves past .45 across and .6 up / down.
	var dz := {"left": 0.45, "right": 0.45, "up": 0.6, "down": 0.6, "jump": 0.5, "attack": 0.5, "guard": 0.5, "dash": 0.5, "ult": 0.5, "swap": 0.5}
	var pad := {"jump": [JOY_BUTTON_A], "attack": [JOY_BUTTON_X], "dash": [JOY_BUTTON_B], "guard": [JOY_BUTTON_Y], "ult": [],
		"swap": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER],
		"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN]}
	for a in pad:
		if not InputMap.has_action(a):
			InputMap.add_action(a, dz[a])
		InputMap.action_set_deadzone(a, dz[a])
		for e in InputMap.action_get_events(a):
			if e is InputEventJoypadButton or e is InputEventJoypadMotion:
				InputMap.action_erase_event(a, e)
		for b in pad[a]:
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(a, j)
	for ax in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["up", JOY_AXIS_LEFT_Y, -1.0], ["down", JOY_AXIS_LEFT_Y, 1.0],
			["guard", JOY_AXIS_TRIGGER_LEFT, 1.0], ["ult", JOY_AXIS_TRIGGER_RIGHT, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = ax[1]
		m.axis_value = ax[2]
		InputMap.action_add_event(ax[0], m)


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
		if not P.roster().has(c): return     # not in the guild yet (Eilin introduces Aida and Luce)
		P.party.append(c)
		FOLK.of(self).join_party(c)

func foes() -> Array:
	var out: Array = mobs.filter(func(m): return m.alive())
	if level == null:
		out = dummies.filter(func(d): return d.alive()) + out
		if ghost != null and ghost.alive(): out.append(ghost)
	return out

func view_rect() -> Rect2:
	var vs := get_viewport_rect().size
	var c := cam.get_screen_center_position()
	return Rect2(c - vs / 2.0, vs)

## enterScene's camera: cam = P.x - VW/2 (no lead), camY by scene (town: (P.y - GROUND) * 0.9 within -720..320)
func snap_camera() -> void:
	cam.limit_right = int(world_w)
	cam.limit_top = -100000            # the vertical framing is the prototype's camY rule below, not a hard limit
	cam.limit_bottom = 100000
	var vw := get_viewport_rect().size.x
	cam.position = Vector2(clampf(player.position.x, vw / 2.0, maxf(vw / 2.0, world_w - vw / 2.0)), cam_y_target(true))
	cam.reset_smoothing()

func cam_x_target() -> float:
	var vw := get_viewport_rect().size.x
	var x: float = player.cam_focus["x"] if player.cam_focus["t"] > 0.0 else player.position.x + player.dir * 70.0
	return clampf(x, vw / 2.0, maxf(vw / 2.0, world_w - vw / 2.0))

## the ground shadow: rgba(0,0,0,.25), 34 x 6, narrowing with height (to 0.4 at 240 px up) on the floor below her
var shadow_node: Node2D
func shadow_y() -> float:
	var P = player
	var x: float = P.position.x
	var y: float = P.position.y
	var shy := ground_y
	if level != null and level.kind == "town":
		shy = level.terr_y(x)
		for p in level.tpl:
			if x >= p.x0 - 8.0 and x <= p.x1 + 8.0:
				var py: float = level.plat_y(p, x)
				if py >= y - 2.0 and py < shy: shy = py
		return shy
	# elsewhere: GROUND (raised cave rock is not a floor here, as in the prototype), or a plank / the hall landing below
	var pls: Array = platforms.duplicate()
	if level != null and level.kind == "hall" and level.landing != null:
		pls.append({"x": level.landing["x0"], "y": level.landing["y"], "w": level.landing["x1"] - level.landing["x0"]})
	for pl in pls:
		if x > pl.x - 2.0 and x < pl.x + pl.w + 2.0 and pl.y >= y - 2.0 and pl.y < shy: shy = pl.y
	if P.plat is Dictionary and P.plat.has("ramp"): shy = y      # on the hall stairs (P.ramp): at her feet
	return shy

func shadow_rx(shy: float) -> float:
	return 34.0 * maxf(0.4, 1.0 - (shy - player.position.y) / 400.0)

func _draw_shadow() -> void:
	if player == null or not player.visible: return
	var shy := shadow_y()
	var rx := shadow_rx(shy)
	shadow_node.draw_set_transform(Vector2(player.position.x, shy), 0.0, Vector2(1.0, 6.0 / rx))
	shadow_node.draw_circle(Vector2.ZERO, rx, Color(0, 0, 0, 0.25))
	shadow_node.draw_set_transform(Vector2.ZERO)

## the prototype's camY (screen top in world y; ZM() is 1 everywhere): town camTY((P.y - GROUND) x 1.05 below / 0.9 above,
## -720..340; 320 on entry), the hall -90 when she is up on the gallery, the cave P.y - GROUND + 150 within
## -(top + 40)..0, the training ground 0. Returned as the camera's centre.
func cam_y_top(snap := false) -> float:
	var P = player
	var d: float = P.position.y - ground_y
	if level == null: return 0.0
	match String(level.kind):
		"town":
			return clampf(d * 0.9, -720.0, 320.0) if snap else clampf(d * (1.05 if d > 0.0 else 0.9), -720.0, 340.0)
		"hall":
			return -90.0 if P.position.y < ground_y - 120.0 else 0.0
		"dungeon":
			return 0.0 if snap else clampf(d + 150.0, -(float(level.tpl["top"]) + 40.0), 0.0)
	return 0.0

func cam_y_target(snap := false) -> float:
	return cam_y_top(snap) + get_viewport_rect().size.y / 2.0

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
	if train != null:
		train.cleanup()
		train = null
	if ghost != null: ghost.leave()
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

## enterScene('arena'): dummies stand again, the ghost is up at x 700, she comes in at x 530
func go_training() -> void:
	_drop_level()
	for dm in dummies:
		dm.visible = true
		dm.reset()
	world_w = AW
	platforms = train_platforms.duplicate()
	player.position = Vector2(530.0, ground_y)
	player.dir = 1
	player.on = true
	player.vy = 0.0
	train = TRAINING.new()
	train.arena = self
	add_child(train)
	ghost.enter()
	snap_camera()
	_autosave()

func party_wiped() -> void:
	if level_kind() == "dungeon":
		fade_then(func(): go_town(Vector2(5107.0, ground_y), -1))

func try_interact() -> bool:
	if level != null:
		return level.try_interact()
	if train != null:
		return train.try_interact()      # the gate: 길드 마을로
	return false

func platform_under(p: Vector2):
	for pl in platforms:
		if absf(p.y - pl.y) < 1.0 and p.x > pl.x - 2.0 and p.x < pl.x + pl.w + 2.0:
			return pl
	return null


## setAspect / fit: the view is always 500 world px tall and as wide as the screen's shape, clamped to 1.6..2.8
## (outside that it letterboxes). The prototype caps at 2.4; phone browsers in landscape (address bar showing) run
## past that, so the cap is raised to 2.8 = the narrowest dungeon room (1400 px) and the phone fills edge to edge.
const ASPECT_MAX := 2.8
static func view_w(win: Vector2) -> int:
	return roundi(H * clampf(win.x / maxf(1.0, win.y), 1.6, ASPECT_MAX))

func fit_view() -> void:
	var r := get_tree().root
	var win := Vector2(r.size)
	if win.x < 1.0 or win.y < 1.0: return
	r.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	r.content_scale_size = Vector2i(view_w(win), int(H))

func _process(delta: float) -> void:
	# qWatch: long frames lower the render quality (menus and the title don't count)
	cfg.qwatch(minf(delta * 1000.0, 50.0), ui_root == null or ui_root.holds() or DisplayServer.get_name() == "headless")
	if pryw_t0 >= 0.0:
		pryw_node.queue_redraw()          # on its own real-time clock, even while the world holds
		if Time.get_ticks_msec() - pryw_t0 > 700.0: pryw_t0 = -1.0
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
		dlg.hold_keys()
		player.step(dt)
		if sortie != null: sortie.post_player(dt)
		if ult != null:
			ult.tick(dt)
			ult.step(dt)
		for d in dummies:
			d.step(dt)
		if ghost != null: ghost.step(dt * wk)
		for m in mobs:
			m.step(dt * wk)
		step_proj(dt * wk)
		step_luce(dt)
		dodge_check()
		eil.world(dt)
		var lk := level_kind()
		if lk == "hall" or lk == "town": eil.upd(dt)
		if level != null:
			level.step(dt)
		elif train != null:
			train.step(dt)
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
	# camera: a lead of 70 px in the facing direction; CAMF (a tag-in's focus) whips over at 16/45 instead of 16/90
	var vw := get_viewport_rect().size.x
	var camf: bool = player.cam_focus["t"] > 0.0
	var target := Vector2(cam_x_target(), cam_y_target())
	cam.position.x = clampf(lerpf(cam.position.x, target.x, minf(1.0, (16.0 / 45.0 if camf else 16.0 / 90.0) * (dt / 16.0))), vw / 2.0, maxf(vw / 2.0, world_w - vw / 2.0))
	cam.position.y = lerpf(cam.position.y, target.y, minf(1.0, dt / 140.0))
	cam.offset = Vector2(randf_range(-1, 1) * shake_amt * 0.6 + shake_dir * shake_amt * 0.3, randf_range(-1, 1) * shake_amt * 0.4)
	queue_redraw()
	fx_layer.queue_redraw()
	shadow_node.queue_redraw()
	sigil_add.queue_redraw()
	sigil_top.queue_redraw()


# ---------- background & ground ----------
## the training ground draws itself (training.gd); the town, hall and cave are their own levels


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
	var raw := n == "boom" or n == "witch_end"     # the slow-down's own cues play dry (boom / witchEnd: __raw)
	best.bus = &"Master" if raw else SLOWBUS.BUS
	best.pitch_scale = 0.62 if witch > 0.0 and not raw else 1.0
	best.play()

## text(): floating text, 600 ms. Numbers pop as tilted condensed italics (H2.txt), words sit on a small black tag.
## Pickup words (실링 / 기억석 / 룬 · / 장비) go to the notice feed with a GET tag instead of floating over the world.
const PICKUP_RE := "^(실링|기억석|룬 · |장비)"
static var _pick_re: RegEx
func text(p: Vector2, s: String, col: Color, ic := "") -> void:
	if _pick_re == null: _pick_re = RegEx.create_from_string(PICKUP_RE)
	if _pick_re.search(s) != null and fame != null:
		fame.notice(s, "GET", col)
		return
	fx.append({"k": "txt", "x": p.x, "y": p.y, "s": s, "col": col, "ic": ic, "t": 0.0, "life": 600.0})

## H2.txt's rule: a number is anything starting with a digit (after a sign); "!" or 치명 makes it the big crit slab
static func txt_num(s: String) -> bool:
	var i := 1 if s.begins_with("-") or s.begins_with("+") else 0
	return s.length() > i and s.unicode_at(i) >= 48 and s.unicode_at(i) <= 57

static func txt_big(s: String) -> bool:
	return s.contains("!") or s.contains("치명")

## Anton with the browser's synthetic italic (Skia skews by 1/4)
var _anton_i: FontVariation
func anton_italic() -> Font:
	if _anton_i == null:
		_anton_i = FontVariation.new()
		_anton_i.base_font = font_anton
		_anton_i.fallbacks = [font_black]
		_anton_i.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.25, 1), Vector2.ZERO)
	return _anton_i

## parryWord: a huge hollow "PARRY" across the screen, cut on and off on a hard timeline (ms, visible?)
const PRYW_CUTS := [[0, 1], [50, 0], [90, 1], [140, 0], [170, 1], [520, 0], [560, 1], [600, 0]]
var pryw_t0 := -1.0           # real-time ms when it started (setTimeout clock: hitstop and slow time don't touch it)
func parry_word() -> void:
	pryw_t0 = Time.get_ticks_msec()
	if pryw_node != null: pryw_node.queue_redraw()

static func pryw_visible(ms: float) -> bool:
	if ms < 0.0 or ms >= 620.0: return false
	var v := 0
	for c in PRYW_CUTS:
		if ms >= c[0]: v = c[1]
	return v == 1

var pryw_node: Control
func _draw_pryw() -> void:
	var ms := Time.get_ticks_msec() - pryw_t0 if pryw_t0 >= 0.0 else -1.0
	if not pryw_visible(ms): return
	var vs := pryw_node.get_viewport_rect().size
	var fs := int(floor(minf(vs.y * 0.4, vs.x * 0.9 / 5.0)))
	var fnt: Font = font_anton             # outlines ignore a FontVariation's slant: skew the canvas instead (1/4, like Skia)
	var sp := fs * 0.02                       # letter-spacing .02em (after every letter, the last one too)
	var s := "PARRY"
	var w := 0.0
	for ch in s: w += fnt.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + sp
	var base := vs.y / 2.0 + (fnt.get_ascent(fs) - fnt.get_descent(fs)) / 2.0
	var x := vs.x / 2.0 - w / 2.0
	pryw_node.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.25, 1), Vector2(base * 0.25, 0)))
	for ch in s:
		# -webkit-text-stroke 1.5px #fff over a transparent fill: only the outline
		pryw_node.draw_string_outline(fnt, Vector2(x, base), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color.WHITE)
		x += fnt.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + sp
	pryw_node.draw_set_transform_matrix(Transform2D.IDENTITY)

## lootGet's tink: a triangle at 1.4-1.9 kHz, 5 ms up to 0.06, gone by 120 ms
static var _tinks: Array = []
func loot_tink() -> void:
	if _tinks.is_empty():
		var rate := 22050
		for v in 6:
			var f0 := 1400.0 + v * 100.0
			var n := int(rate * 0.14)
			var data := PackedByteArray()
			data.resize(n * 2)
			var ph := 0.0
			for i in n:
				var tt := float(i) / rate
				ph += f0 / rate
				var tri := 4.0 * absf(fmod(ph, 1.0) - 0.5) - 1.0
				var env := 0.0001 * pow(600.0, tt / 0.005) if tt < 0.005 else (0.06 * pow(0.0001 / 0.06, (tt - 0.005) / 0.115) if tt < 0.12 else 0.0)
				data.encode_s16(i * 2, int(clampf(tri * env, -1.0, 1.0) * 32767.0))
			var w := AudioStreamWAV.new()
			w.format = AudioStreamWAV.FORMAT_16_BITS
			w.mix_rate = rate
			w.data = data
			_tinks.append(w)
	var best = sfx_pool[0]
	for ap in sfx_pool:
		if not ap.playing:
			best = ap
			break
	best.stream = _tinks[randi() % _tinks.size()]
	best.volume_db = 0.0
	best.pitch_scale = 1.0
	best.play()


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
			if runes != null: runes.ev("pdodge")       # memory nodes (극한 회피에 성공하면 …)
	was_dash = d

func perfect_dodge() -> void:
	witch = 1500.0
	witch_max = 1500.0
	player.charges = mini(2, player.charges + 1)
	player.inv = maxf(player.inv, 400.0)
	text(player.position + Vector2(0, -170.0 * player.CSCALE), "극한 회피!", Color("#bfe8ff"))
	flash = maxf(flash, 0.16)
	post_wave(player.position + Vector2(0, -60.0 * 1.3), 1.4, 600.0, 0.3)
	post_ca(0.02)
	pfx.dodge_snap()
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
	text(P.position + Vector2(0, -130.0 * P.CSCALE), "PARRY!", Color("#ffd34d"))
	parry_word()                  # runeEv('parry') -> parryWord: every parry
	post_wave(P.position + Vector2(d * 50.0 * 1.3, -70.0 * 1.3), 1.1, 480.0, 0.22)
	post_ca(0.012)

func perfect_parry(m) -> void:
	witch = maxf(witch, 560.0)
	witch_max = maxf(witch_max, 560.0)
	m.hurt_t = maxf(m.hurt_t, 1400.0)
	m.kx = player.dir * 2.2
	m.flare_t = -1.0
	sfx("heavy", 0.7)
	var fp: Vector2 = m.flare_pos()
	pfx.parry_at(Vector2((player.position.x + player.dir * 40.0 * player.CSCALE + fp.x) / 2.0, player.position.y - 72.0 * player.CSCALE), player.dir)
	post_wave(Vector2((player.position.x + player.dir * 52.0 + m.position.x) / 2.0, player.position.y - 72.0 * 1.3), 1.8, 700.0, 0.35)

func big_word(s: String, col: Color, life: float, off: Vector2, at := Vector2.INF) -> void:
	var p: Vector2 = at if at != Vector2.INF else player.position + off
	big_words.append({"s": s, "col": col, "t": 0.0, "life": life, "x": p.x, "y": p.y, "screen": off == Vector2.ZERO and at == Vector2.INF})

func shake(amt: float, d: int) -> void:
	shake_amt = maxf(shake_amt, amt)
	shake_dir = d

func slash_fx(c: Vector2, r: float, a0: float, a1: float, d: int, _col := Color.WHITE, sy := 1.0) -> void:
	pfx.slash(c, r, a0, a1, d, player.who, sy)          # pfxSlash: the pixel swing (Aida: the dimension tears)

## streakFx: the pixel spear wedge (Aida: tears along the jab) + kicked dust
func streak_fx(x0: float, x1: float, y: float, _d: int, _col := Color.WHITE) -> void:
	pfx.thrust(x0, x1, y, player.who)
	if player.on: pfx.dust(player.position.x - player.dir * 6.0 * player.CSCALE, player.position.y, -player.dir, true)
	air_push((x0 + x1) / 2.0, y, signf(x1 - x0) if x1 != x0 else float(player.dir), 360.0, 0.6)

## airPush: blown air moves the cave spores (only the dungeon has any)
func air_push(x: float, y: float, d: float, R: float, F: float) -> void:
	if level != null and level.has_method("air_push"): level.air_push(x, y, d, R, F)

## swingWorld's air: every swing on the ground (and the air / high swings) pushes the motes ahead of it
func swing_air(P) -> void:
	var a: String = P.anim
	if not P.on and not ("attack_high" in a or "air" in a): return
	var heavy: bool = "attack3" in a or "cthrust" in a or "cwave" in a
	air_push(P.position.x + P.dir * 60.0 * P.CSCALE, P.position.y - 70.0 * P.CSCALE, P.dir, 320.0 if heavy else 220.0, 0.5 if heavy else 0.3)

## pfxDust: pixel puffs kicked along the floor (d = 0: both ways, as on a landing)
func dust(p: Vector2, d: int, heavy: bool) -> void:
	if d == 0:
		pfx.dust(p.x + 8.0, p.y, 1, heavy)
		pfx.dust(p.x - 8.0, p.y, -1, heavy)
	else:
		pfx.dust(p.x, p.y, d, heavy)

func ring(p: Vector2, r: float, col := Color("#ff9fd0"), life := 300.0) -> void:
	fx.append({"k": "ring", "x": p.x, "y": p.y, "r": r, "col": col, "t": 0.0, "life": life})

func spark(p: Vector2, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var s := 0.25 + randf() * 0.4
		fx.append({"k": "sp", "x": p.x, "y": p.y, "vx": cos(a) * s, "vy": sin(a) * s, "c": player.who, "t": 0.0, "life": 140.0 + randf() * 120.0})

## slashMark: the cross-cut and the ring at the point a swing lands
func slash_mark(p: Vector2, ang: float, big: float) -> void:
	fx.append({"k": "smark", "x": p.x, "y": p.y, "ang": deg_to_rad(ang) + (PI if player.dir < 0 else 0.0), "big": big, "c": player.who, "t": 0.0, "life": 220.0})
	fx.append({"k": "burst", "x": p.x, "y": p.y, "big": big, "c": player.who, "t": 0.0, "life": 260.0})

## dmgText: one number in its colour (weak #ffd34d / resist #aab / the target's own) with the element icon; a hybrid hit
## splits into one number per element, 44 px apart, every other one 6 px lower, each in ELC (weak / resist override)
func damage_text(p: Vector2, value: int, _big := false, col := Color("#ffd1e6")) -> void:
	var E: Dictionary = last_e if not last_e.is_empty() and roundi(last_e["dmg"]) == value else {"dmg": value, "mul": 1.0, "parts": [{"el": "", "dmg": value, "mul": 1.0}]}
	last_e = {}
	damage_text_e(p, E, col)

## dmgText(x, y, E, col) itself
func damage_text_e(p: Vector2, E: Dictionary, col: Color) -> void:
	var value := roundi(E["dmg"])
	var parts: Array = E["parts"]
	if parts.size() < 2:
		var m: float = E["mul"]
		text(p, "-%d" % value, Color("#ffd34d") if m >= 1.3 else (Color("#aaaabb") if m <= 0.6 else col), String(parts[0]["el"]))
		return
	var n := parts.size()
	for i in n:
		var q: Dictionary = parts[i]
		var m2: float = q["mul"]
		var c2: Color = Color("#ffd34d") if m2 >= 1.3 else (Color("#8f97a8") if m2 <= 0.6 else ELEM.ELC.get(q["el"], col))
		text(p + Vector2((i - (n - 1) / 2.0) * 44.0, (i % 2) * 6.0), "-%d" % roundi(q["dmg"]), c2, String(q["el"]))

func charge_fx(_p: Vector2, _t: float, _col := Color.WHITE) -> void:
	pfx.charge(player)          # pfxCharge: motes streak in to the hilt, the glint grows


# ---------- Luce's light ----------
## a light bolt: rises up-and-back, holds a beat, then shoots and homes in on the target
func bolt(o: Vector2, tg, sz: float, hold: float, d: int) -> void:
	var b := {"by": player.who, "k": "bolt", "x": o.x, "y": o.y, "vx": d * 0.001, "vy": 0.0, "tg": tg, "sz": sz, "hold": hold, "hits": [], "home": 0.011, "dmg": 1.0, "mul": player.atk_mul(), "d": d, "t": 0.0, "life": 1100.0 + hold, "tr": [], "hold0": hold, "trT": 0.0}
	if tg == null:
		b["home"] = 0.0
	luce_fx.append(b)

func pillar(x: float, y: float, dmg: float, d: int) -> void:
	luce_fx.append({"by": player.who, "k": "pillar", "x": x, "y": y, "dmg": dmg, "d": d, "hits": [], "mul": player.atk_mul(), "t": 0.0, "life": 420.0})
	pfx.pillar(x, y, player.CSCALE)
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
	pfx.bolt(x, y, sz)

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
			f["trT"] += dt
			if f["trT"] >= PFX.FR:
				f["trT"] = 0.0
				f["tr"].push_front(Vector2(f["x"], f["y"]))       # newest first, one a pixel-frame
				if f["tr"].size() > 10: f["tr"].pop_back()
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
	for f in luce_fx:
		if f["k"] == "bolt":
			# luceBoltFx: the holy spear; while it holds it gathers inside a ring
			var hold: float = f["hold"]
			var ap := minf(1.0, 1.0 - hold / maxf(1.0, f["hold0"]) + 0.2) if hold > 0.0 else 1.0
			var ang := atan2(f["vy"], f["vx"]) if Vector2(f["vx"], f["vy"]).length() > 0.01 else (0.0 if f["d"] > 0 else PI)
			PFX.luce_bolt(fx_layer, f["t"], f["x"], f["y"], ang, f["sz"], null if hold > 0.0 else f["tr"], ap)
		# the pillar and the lightning are pfx.gd's (pfxPillar / pfxBolt)

## the sigil shows while she aims (P.anim mark / amark); t = P.t / 1000, k = (P.t / 500) % 1
var sigil_add: Node2D
var sigil_top: Node2D
func sigil_on() -> bool:
	return mark_pos != Vector2.INF and player != null and player.anim in ["mark", "amark"]

static func _dia(ci: CanvasItem, c: Vector2, r: float, rot: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for v in [Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0), Vector2(0, -r)]:
		pts.append(c + v.rotated(rot))
	ci.draw_polyline(pts, col, w, true)

## a dashed path along points (closed or not), pattern [on, off] in px
static func _dashed(ci: CanvasItem, pts: PackedVector2Array, on: float, off: float, col: Color, w: float) -> void:
	var acc := 0.0
	var draw_on := true
	var seg := PackedVector2Array([pts[0]])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var L := a.distance_to(b)
		var u := 0.0
		while u < L:
			var lim := (on if draw_on else off) - acc
			var step := minf(lim, L - u)
			u += step
			acc += step
			var p := a.lerp(b, u / L)
			if draw_on: seg.append(p)
			if acc >= (on if draw_on else off) - 0.001:
				if draw_on and seg.size() > 1: ci.draw_polyline(seg, col, w, true)
				draw_on = not draw_on
				acc = 0.0
				seg = PackedVector2Array([p])
	if draw_on and seg.size() > 1: ci.draw_polyline(seg, col, w, true)

static func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _draw_sigil_add() -> void:
	if not sigil_on(): return
	var t: float = player.t / 1000.0
	var k: float = fmod(player.t / 500.0, 1.0)
	var g := mark_pos + Vector2(0, -30)
	var ds := [[22.0, t * 2.2, Color8(201, 166, 255), 0.9, 2.0], [14.0, -t * 3.1 + 0.78, Color8(230, 210, 255), 0.9, 1.5], [30.0 + k * 10.0, t * 0.8, Color8(150, 90, 255), 0.5 - k * 0.5, 1.5]]
	# shadowBlur 14 in rgba(140,80,255): soft wide passes under each stroke
	for d in ds:
		for gw in [[12.0, 0.04], [7.0, 0.07], [3.5, 0.11]]:
			_dia(sigil_add, g, d[0], d[1], Color(Color8(140, 80, 255), gw[1] * d[3] / 0.9), d[4] + gw[0])
	for d in ds:
		_dia(sigil_add, g, d[0], d[1], Color(d[2], d[3]), d[4])

func _draw_sigil_top() -> void:
	if not sigil_on(): return
	var P = player
	var t: float = P.t / 1000.0
	# the 400 px reach, dashed 6 / 8
	_dashed(sigil_top, _ellipse_pts(P.position, 400.0, 400.0, 180), 6.0, 8.0, Color(Color8(201, 166, 255), 0.25), 1.5)
	# the thread from her chest to the sigil
	sigil_top.draw_line(P.position + Vector2(0, -60.0 * P.CSCALE), mark_pos + Vector2(0, -30), Color(Color8(201, 166, 255), 0.35), 1.0, true)
	# the dark eye and its pulsing pupil
	var g := mark_pos + Vector2(0, -30)
	sigil_top.draw_circle(g, 6.0, Color("#190f23"))
	sigil_top.draw_circle(g, 2.2 + sin(t * 9.0) * 0.8, Color("#e6d2ff"))
	# the landing mark on the floor, dashed 4 / 5 at 0.6
	_dashed(sigil_top, _ellipse_pts(mark_pos, 26.0, 8.0, 48), 4.0, 5.0, Color(Color("#c9a6ff"), 0.6), 1.5)

func _draw_txt(e: Dictionary, k: float) -> void:
	var ci := fx_layer
	var s: String = e["s"]
	var y: float = e["y"] - k * 28.0
	var al := 1.0 - (k - 0.7) / 0.3 if k > 0.7 else 1.0
	var col: Color = e["col"]
	if txt_num(s):
		var big := txt_big(s)
		var sc := 1.0 + (0.12 - k) / 0.12 * (0.9 if big else 0.5) if k < 0.12 else 1.0
		if not e.has("rot"): e["rot"] = (randf() - 0.5) * 0.22
		var fnt := anton_italic()
		var fs := 32 if big else 21
		var w := fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ci.draw_set_transform(Vector2(e["x"], y), e["rot"], Vector2(sc, sc))
		if big:
			# the crit slab: a red copy 4 px down-right, the black slab over it
			var sw := w + 30.0
			var q := PackedVector2Array([Vector2(-sw / 2.0 + 6.0, -30.0), Vector2(sw / 2.0, -28.0), Vector2(sw / 2.0 - 6.0, 8.0), Vector2(-sw / 2.0, 6.0)])
			var qr := PackedVector2Array()
			for v in q: qr.append(v + Vector2(4, 4))
			ci.draw_colored_polygon(qr, Color(Color("#e8243c"), al))
			ci.draw_colored_polygon(q, Color(0, 0, 0, al))
		ci.draw_string(fnt, Vector2(-w / 2.0 + 2.0, 2.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, al))
		ci.draw_string(fnt, Vector2(-w / 2.0, 0.0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, col.a * al))
		var ic: String = e.get("ic", "")
		if ic != "":
			var t := ELEM.icon(ic)
			if t != null: ci.draw_texture_rect(t, Rect2(-w / 2.0 - 18.0, -17.0, 15.0, 15.0), false, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO)
	else:
		# a word: 700 12px on a black tag (rgba 0,0,0,.75, skewed 5), a 3 px bar in its colour, white letters
		var fb := font_bold
		var tw := fb.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var w2 := tw + 18.0
		var x0: float = e["x"] - w2 / 2.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 5.0, y - 15.0), Vector2(x0 + w2 + 5.0, y - 15.0), Vector2(x0 + w2, y + 5.0), Vector2(x0, y + 5.0)]), Color(0, 0, 0, 0.75 * al))
		ci.draw_rect(Rect2(x0 + 2.0, y - 12.0, 3.0, 14.0), Color(col, col.a * al))
		ci.draw_string(fb, Vector2(e["x"] + 3.0 - tw / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, al))

func _draw_fx() -> void:
	_draw_luce()
	for e in fx:
		var k: float = e["t"] / e["life"]
		match e["k"]:
			"dust":
				fx_layer.draw_circle(Vector2(e["x"], e["y"]), e["r"] * (1.0 + k), Color8(190, 176, 150, int(255 * 0.7 * (1.0 - k))))
			"ring":
				# the impact ring lying on the floor: a white ellipse and an inner one in colour
				var rr: float = e["r"] + k * 140.0
				fx_layer.draw_set_transform(Vector2(e["x"], e["y"]), 0.0, Vector2(1.0, 0.35))
				fx_layer.draw_arc(Vector2.ZERO, rr, 0, TAU, 48, Color(1, 1, 1, 1.0 - k), (6.0 * (1.0 - k) + 1.0) / 0.35 * 0.5)
				fx_layer.draw_set_transform(Vector2(e["x"], e["y"]), 0.0, Vector2(1.0, 0.35))
				fx_layer.draw_arc(Vector2.ZERO, rr * 0.8, 0, TAU, 48, Color(e["col"], 1.0 - k), 2.0)
				fx_layer.draw_set_transform(Vector2.ZERO)
			"sp":
				var sc: Color = SPK[e.get("c", "estelle")]
				fx_layer.draw_rect(Rect2(e["x"] - 2, e["y"] - 2, 4, 4), (Color("#e6d2ff") if e.get("c", "") == "aida" else Color.WHITE) if k < 0.5 else sc)
			"smark":
				var Ls: float = (70.0 if e["big"] > 1 else 48.0) * (0.6 + minf(1.0, k * 3.0) * 0.4)
				fx_layer.draw_set_transform(Vector2(e["x"], e["y"]), e["ang"])
				for wc in [[5.0, SLC[e["c"]]], [2.0, Color("#e9dcff") if e["c"] == "aida" else Color.WHITE]]:
					var c2: Color = Color(wc[1], wc[1].a * (1.0 - k))
					fx_layer.draw_line(Vector2(-Ls, -Ls * 0.35), Vector2(Ls, Ls * 0.35), c2, wc[0])
					fx_layer.draw_line(Vector2(-Ls * 0.5, Ls * 0.5), Vector2(Ls * 0.5, -Ls * 0.5), c2, wc[0])
				fx_layer.draw_set_transform(Vector2.ZERO)
			"burst":
				var rb: float = (26.0 if e["big"] > 1 else 16.0) + k * (90.0 if e["big"] > 1 else 55.0)
				fx_layer.draw_arc(Vector2(e["x"], e["y"]), rb, 0, TAU, 40, Color(BUC[e["c"]], (1.0 - k) * 0.9), 2.5 * (1.0 - k) + 0.5)
			"txt":
				_draw_txt(e, k)
	# attack tells, dodge afterimages and the parry clash are pfx.gd's (drawCombatFx)
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



## test keys (debug builds only, dev.gd): F2 = straight into the cave, F3 = clear the room, F4 = next room, F5 = jump around town, F6 = +3 hours,
## F7 = straight into the guild hall, F8 = next hall floor, F9 = Eilin straight to where her day says she should be,
## F10 = weather (clear / rain / snow), F11 = Luce leaves / rejoins the party (she lives in town meanwhile), Shift+F11 = the same for Aida,
## Insert = fill the 기력 gauge, Shift+F4 = straight to the boss room
var tp_i := 0
func _unhandled_input(ev: InputEvent) -> void:
	if not DEV.on: return
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
