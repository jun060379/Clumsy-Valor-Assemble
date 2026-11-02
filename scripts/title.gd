extends Control
## Title (prototype #title) in the persona skin; the hero select is gone (a fresh game is 에스텔 alone, the seniors join in play).
## docs/title_storyboard.md has the whole timeline. The title is music-driven: every move is a function of the title
## track's clock (beat.gd, `mt` seconds into assets/bgm/title.ogg, looping), never a one-shot timer, so it survives
## loops, tab switches and headless captures. Section A "모인다": the field slashes in on the first hit, paint splats
## pop, the brush logo lands on its blob, the painted hall springs in, the members drop onto its steps one per pulse
## (one of them lands short and shuffles up), the menu rows stamp in one per beat, the brush cursor slaps 시작, the
## lights come on one per bar and the crowd sprints in as coloured lines that unfold into paper figures. Section B: an
## ink wedge sweeps and the members take turns on a slanted cut-in panel. Section C: the village wide and small under
## the sky. Section D "ASSEMBLE": everyone on the beat. The outro settles, a wedge sweeps from the right and the loop
## replays the intro. 시작 bursts from the logo, the pink field grows over the screen and the sweep carries it into town.
##
## The title grows with the save ("자라는 타이틀"): the hall's lights climb a 7-step ladder with the restored
## facilities (fame.fac), every member in fame.rec stands on the steps and gets a cut-in, and the guild's rank fills the
## steps with a crowd of nameless silhouettes, each rimmed in its own hue.
##
## Layers: this Control (nearest filtering) draws the ground: the fields, the specks and the guide lines (and the gate);
## `bg` (linear) draws the hall plate with its lights and sign, the cut-in panel, the crowd and the back fog; `sil`
## (UI.solid_mat) draws the people's white / ink cut-outs; `fg` draws the logo, the people, the front fog, the menu,
## the name slabs, the bursts and the wedge.

const UI := preload("res://scripts/ui_kit.gd")
const DEV := preload("res://scripts/dev.gd")
const UIA := preload("res://scripts/ui_anim.gd")
const CH := preload("res://scripts/chars.gd")
const SK := preload("res://scripts/skins.gd")
const LIT := preload("res://scripts/lit.gd")
const BEAT := preload("res://scripts/beat.gd")
const SHEET := preload("res://scripts/ui_char.gd").SHEET      # the members' full names and one-line roles (the 캐릭터 screen's)
const PINK := Color("#ff3d7f")
const INK := Color("#0d0b10")
const CREAM := Color("#f3e9d2")
const HALL := preload("res://assets/title/hall.png")      # the painted plate (1920×1088; the ground is its y 1000, the grass lies under it)
const LOGO := preload("res://assets/title/logo.png")      # Clumsy Valor / 어설픈 용맹 / Assemble, brush
const BLOB := preload("res://assets/title/blob.png")      # the plum blob the logo lands on
const BRUSH := preload("res://assets/title/brush.png")    # the menu cursor
const BURST := preload("res://assets/title/burst.png")    # 시작's burst, the wedges' and the intro's splats
const EMBLEM := preload("res://assets/title/emblem.png")  # the guild's flower
const GROUND := 0.86                 # the ground line (fraction of H): the hall's foot, the people's feet (section C: 0.80)
const PERSON_H := 0.38               # one common height for every standing picture, framed knee-up (fraction of H)
const FULL_CROP := 0.72              # a full-body st_full is cut to its knees (this much of its height) to match the st_base framing
const KNEE_SINK := 0.1               # the knee line sits this far below the ground line (the fog and the screen's edge hide the cut)
const HALL_NIGHT := Color(0.5, 0.43, 0.72)      # the plate keeps its own colours by day and cools toward violet at night
const C_SCALE := 0.55                # section C: the hall (and everyone on its steps) at this much of the A size
const C_GROUND := 0.80
## the sky (the pink field) by the hour: never grey — day pink, dusk magenta, night plum
const SKY_K := [[0.0, Color("#4a1740")], [4.5, Color("#4a1740")], [6.3, Color("#c8246c")], [8.0, Color("#ff3d7f")], [16.5, Color("#ff3d7f")], [18.5, Color("#c8246c")], [20.5, Color("#4a1740")], [24.0, Color("#4a1740")]]
## the plate's features (hall.png px)
const HALL_GROUND := 1000.0                      # the plate's row that stands on the ground line
const HALL_TOP := 90.0                           # the spire's tip (the building is HALL_GROUND - HALL_TOP tall)
const WIN_R := Rect2(1348, 660, 117, 122)        # the right wing's panes (Eilin's)
const WIN_L := Rect2(432, 660, 116, 122)         # the left wing's panes
const LANT_DOOR := Vector2(1103, 722)            # the lantern by the door (its glass)
const LANT_R := Vector2(1776, 715)               # the lantern on the right bracket
const DOOR_CRACK := Rect2(931, 652, 8, 210)      # the seam between the door's leaves
const CHIM_L := Vector2(340, 170)                # the chimney tops
const CHIM_R := Vector2(1510, 172)
const SIGN := Rect2(56, 616, 120, 150)           # the board hanging from the left bracket (with its chains)
const SIGN_PIV := Vector2(116, 600)              # where it hangs from
const DOOR_X := 935.0                            # the door's centre
const LIGHT_STEPS := 7                           # the light ladder: right window, left window, door lantern, bracket lantern, door crack, left smoke, right smoke
## where the members stand: [x offset from the door in W, feet above the ground in H, parallax weight], by their place in the row
const SPOTS := [[0.0, -0.01, 1.0], [-0.115, 0.03, 0.7], [0.12, 0.03, 0.7], [-0.23, 0.05, 0.55], [0.23, 0.05, 0.55], [-0.32, 0.06, 0.45], [0.32, 0.06, 0.45]]
## guide lines: [y, length] in fractions of the viewport, period (ms), phase (ms), where the right end stops (fraction of W)
const LINES := [[0.15, 0.23, 5200.0, 0.0, 0.40], [0.47, 0.10, 6800.0, 1700.0, 0.44], [0.06, 0.17, 4400.0, 900.0, 0.30]]
## the dashed figure of the empty chair (feet at the origin, height 1), a closed loop
const CHAIR := [[0.0, -0.98], [0.07, -0.95], [0.09, -0.86], [0.05, -0.79], [0.16, -0.74], [0.2, -0.6], [0.17, -0.4], [0.13, -0.42], [0.12, -0.22], [0.1, 0.0], [0.03, 0.0], [0.02, -0.25],
	[-0.02, -0.25], [-0.03, 0.0], [-0.1, 0.0], [-0.12, -0.22], [-0.13, -0.42], [-0.17, -0.4], [-0.2, -0.6], [-0.16, -0.74], [-0.05, -0.79], [-0.09, -0.86], [-0.07, -0.95]]

## ---- the timeline (music seconds; beat.gd has the grid) ----
const T_FIELD := 0.09                # the pink field slashes in (lands by 0.42)
const T_SPLAT := [0.42, 0.75, 1.07]  # the three paint splats behind the logo's spot, one per beat
const T_LOGO := 1.39                 # the logo and its blob land (bar 2) with the slam
const T_HALL := 2.69                 # the hall springs in from the right, landing on 3.23
const T_HALL_LAND := 3.23
const T_DROP := 4.11                 # 에스텔 lands; the next member every pulse (0.65 s)
const T_MENU := [6.43, 7.08, 7.08, 7.41]   # the menu rows, one per beat; the 2nd one beat late (and it takes two stamps)
const T_CURSOR := 9.22               # the brush slaps 시작, the emblem pops, the lights start (one per bar)
const T_CROWD := 17.09               # the crowd sprints in (bar 13), one per beat
const WEDGE := 0.26                  # s for the ink wedge's leading edge to cross the screen (the composition switches then)
const LOOP_WEDGE := 1.34             # s before the wrap the loop's wedge starts from the right

var arena
var ui_root
var active := true
var beat := BEAT.new()           # the music clock
var mt := 0.0                    # beat.music_t, cached each frame (s)
var sec := "A"                   # the section mt is in
var gate := false                # the quiet gate before the first tap (the web: audio needs the gesture)
var skip := false                # a tap during the intro: its moves settle at once (until the next lap)
var menu_in := false             # the menu rows have entered (they never leave, laps included)
var slam_lap := -1               # the lap the logo's slam was played on
var intro_done := false
var outro := -1.0                # outro clock (ms), -1 = not running
var handed := false              # the sweep into the game has been started
var clock := 0.0                 # wall clock (ms): ambient motion, the menu's springs, the outro
var trn := UIA.Tr.new()
var bg_layer: Control
var sil_layer: Control
var fg_layer: Control
var sp_sil := UIA.Spring.new(0.0, 0.75, 0.6)   # the outro: the cut-outs trail the people (1.5 = off right)
var sp_px := UIA.Spring.new(0.0, 0.9, 0.9)     # pointer parallax
var sp_py := UIA.Spring.new(0.0, 0.9, 0.9)
var sp_cur := UIA.Spring.new(0.0, 0.3, 0.8)    # the menu cursor's row (the brush slides between items)
var sil_out := false
var burst_t := -1.0                            # clock when 시작's burst popped (-1: none)
var specks: Array = []
var crowd_seed: Array = []       # per crowd figure: [u (0..1 along the steps), row 0..2, kind, hue, phase]
var smoke_seed: Array = []       # chimney puffs: [chimney 0/1, phase, drift, size]
var drift := Vector2.ZERO        # the pink field's halftone scroll (doubles in section D)
## framing weights for the frame being drawn (from mt): fB the cut-in panel, fC the village wide, the rest is A
var fB := 0.0
var fC := 0.0
var kF := 1.0                    # the hall's (and its people's) scale: 1 in A, C_SCALE in C
var gy := GROUND                 # the ground line (fraction of H)
var lights_on := 0               # steps of the light ladder lit now
var wedge: Array = []            # the ink wedge in flight: [leading edge x (fraction of W), dir, u, biggest]
## the menu: 시작 · 불러오기 · 설정 · 끝내기 (no 끝내기 on the web, where a tab cannot close itself)
var items: Array = []            # [key, label]
var sel := 0
var item_rects: Array = []       # Rect2 per item, as last drawn (taps)
var has_save := false
var confirm := false             # 시작 over a saved game: "지우고 새로 시작할까요?" row
var confirm_sel := 1             # 0 = 새로 시작, 1 = 돌아가기
var confirm_rects: Array = []
var confirm_t := 0.0              # clock when the confirm card opened
var fresh := false               # 시작 chosen: the save goes and the scene reloads into a new game
var in_opts := false             # the settings page is open over the title
static var pending_fresh := false   # set across the reload: the new game starts without the title

## the title's clock is running (bgm.gd starts the track with it)
var live: bool:
	get: return beat.live


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	items = [["start", "시작"], ["load", "불러오기"], ["opts", "설정"]]
	if not OS.has_feature("web"): items.append(["quit", "끝내기"])
	gate = OS.has_feature("web")                  # the browser's audio waits for a gesture: so does the title
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED     # halftone tiles through polygon uvs
	for i in 3:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		c.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
		if i == 0:
			c.draw.connect(_draw_bg)
			bg_layer = c
		elif i == 1:
			c.material = UI.solid_mat()
			c.draw.connect(_draw_sil)
			sil_layer = c
		else:
			c.draw.connect(_draw_fg)
			fg_layer = c
		add_child(c)
	for i in 12:
		specks.append([randf(), randf(), 0.5 + randf() * 0.7, 2600.0 + randf() * 3000.0])
	for i in 10:
		smoke_seed.append([i % 2, float(i / 2) / 5.0, randf() * 2.0 - 1.0, 0.8 + randf() * 0.5])

## the title goes live: the timeline (and the track) start from 0
func go_live() -> void:
	gate = false
	skip = false
	menu_in = false
	beat.start(0.0)
	_tick()
	if arena != null and arena.bgm != null: arena.bgm.poke()

func _process(delta: float) -> void:
	if pending_fresh and arena != null and arena.world_started:
		# the reload after 시작: straight into the new game, no title
		pending_fresh = false
		active = false
		visible = false
		ui_root.start_game("estelle")
		return
	if in_opts:
		# the settings page over the title: the title waits (input off) until it closes
		if not ui_root.menu.is_open() and not ui_root.sweep.active:
			in_opts = false
			active = true
			visible = true
		return
	if not active:
		return
	if not has_save and arena != null and arena.save != null and FileAccess.file_exists(arena.save.path):
		has_save = true
	var dt := minf(delta * 1000.0, 250.0)   # real time, like the prototype's CSS / rAF clocks
	clock += dt
	trn.step(dt)
	if not gate and not beat.live and outro < 0.0:
		go_live()                            # the desktop: straight in
	# the music clock: the track's position while it really plays, else the wall clock
	var pos := -1.0
	if arena != null and arena.bgm != null: pos = arena.bgm.title_pos()
	beat.step(dt / 1000.0, pos)
	if beat.wrapped:
		skip = false                         # the loop replays the intro
	_tick()
	drift += Vector2(-dt / 120.0, dt / 170.0) * (2.0 if sec == "D" else 1.0)
	drift = Vector2(fposmod(drift.x, 1100.0), fposmod(drift.y, 1100.0))      # the 11 px tile's period: seamless, and never huge
	if outro < 0.0 and beat.live and slam_lap != beat.lap and mt >= T_LOGO and mt < T_LOGO + 1.0:
		slam_lap = beat.lap
		if arena != null: arena.sfx("slam", 0.5)
	if outro >= 0.0:
		outro += dt
		if outro >= 80.0 and not sil_out:
			sil_out = true
			sp_sil.to(1.5, 2.0)
		# the field has swallowed the screen: the menu sweep carries the pink on into the town (no hero select —
		# a fresh game is 에스텔 alone, a saved one keeps its leader)
		if outro >= 650.0 and not handed:
			handed = true
			ui_root.sweep.run(func(): _go(), PINK)
	sp_sil.step(dt)
	# parallax: the pointer (the last touch on a phone) as -1..1
	var vs := get_viewport_rect().size
	var mp := get_viewport().get_mouse_position()
	sp_px.to(clampf((mp.x / maxf(1.0, vs.x) - 0.5) * 2.0, -1.0, 1.0))
	sp_py.to(clampf((mp.y / maxf(1.0, vs.y) - 0.5) * 2.0, -1.0, 1.0))
	sp_px.step(dt)
	sp_py.step(dt)
	sp_cur.to(float(sel))
	sp_cur.step(dt)
	queue_redraw()
	bg_layer.queue_redraw()
	sil_layer.queue_redraw()
	fg_layer.queue_redraw()

## everything the frame derives from the music clock: the section, the framing weights, the lights, the wedge
func _tick() -> void:
	mt = beat.music_t
	sec = beat.section()
	var tB := BEAT.sec_t("B")
	var tC := BEAT.sec_t("C")
	var tD := BEAT.sec_t("D")
	# framing: 0 → 1 over 0.4 s after a wedge's switch, back the same way at the next
	fB = 0.0
	fC = 0.0
	if beat.live:
		fB = mu(tB + WEDGE, 0.4, "ease") * (1.0 - mu(tC + WEDGE, 0.4, "ease"))
		fC = mu(tC + WEDGE, 0.4, "ease") * (1.0 - mu(tD + WEDGE, 0.4, "ease"))
	kF = lerpf(1.0, C_SCALE, fC)
	gy = lerpf(GROUND, C_GROUND, fC)
	if not intro_done and (skip or beat.lap >= 1 or (beat.live and mt >= T_CURSOR)): intro_done = true
	if not menu_in and (skip or beat.lap >= 1 or (beat.live and mt >= T_MENU[3] + 0.45)): menu_in = true
	# the light ladder: one more step per bar from the cursor's slap (laps and later sections: all the save has)
	var n := lit_windows()
	if sec != "A" or beat.lap >= 1 or skip: lights_on = n
	elif mt < T_CURSOR: lights_on = 0
	else: lights_on = mini(n, floori((mt - T_CURSOR) / BEAT.BAR) + 1)
	if not beat.live: lights_on = 0
	# the wedge: at each section's start and each cut-in slot (left → right), and the loop's (from the right)
	wedge = []
	if beat.live:
		for tb in _wedge_times():
			var u: float = (mt - float(tb)) / WEDGE
			if u >= 0.0 and u < 2.0:
				wedge = [lerpf(-0.3, 1.3, UIA.ez("mv", u)) if u < 1.0 else lerpf(1.3, 2.9, UIA.ez("mv", u - 1.0)), 1, u, is_equal_approx(float(tb), tD)]
				break
		var tl := BEAT.LEN - LOOP_WEDGE
		if mt >= tl:
			wedge = [lerpf(1.3, -0.3, UIA.ez("in", (mt - tl) / LOOP_WEDGE)), -1, 0.0, false]
		elif beat.lap >= 1 and mt < WEDGE:
			wedge = [lerpf(-0.3, -1.9, mt / WEDGE), -1, 1.0, false]

## the wedges' start times: the sections B, C, D and the cut-in slots inside B
func _wedge_times() -> Array:
	var tB := BEAT.sec_t("B")
	return [tB, tB + BEAT.PHRASE, tB + 2.0 * BEAT.PHRASE, tB + 3.0 * BEAT.PHRASE, BEAT.sec_t("C"), BEAT.sec_t("D")]

## progress (0..1, eased) of a music-timed move that starts at t0 (s) and lasts dur (s); the intro's moves are done at
## once after a tap skipped the intro
func mu(t0: float, dur: float, name = "bk") -> float:
	if skip and t0 <= T_CURSOR: return 1.0
	return UIA.ez(name, (mt - t0) / maxf(0.001, dur))


# ---------- input ----------
func _input(ev: InputEvent) -> void:
	if not active:
		return
	var tap := Vector2.INF
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		tap = ev.position
	var key := -1
	if ev is InputEventKey and ev.pressed and not ev.echo:
		key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
	var padb := -1
	if ev is InputEventJoypadButton and ev.pressed:
		padb = ev.button_index
	if tap == Vector2.INF and key < 0 and padb < 0:
		return
	get_viewport().set_input_as_handled()
	if outro >= 0.0:
		return
	if gate:
		go_live()                # the gate's tap: the track and the timeline start
		return
	if not intro_done:
		_finish_intro()
		return             # the first press only settles the logo
	var up := key in [KEY_UP, KEY_W] or padb == JOY_BUTTON_DPAD_UP
	var down := key in [KEY_DOWN, KEY_S] or padb == JOY_BUTTON_DPAD_DOWN
	var left := key in [KEY_LEFT, KEY_A] or padb == JOY_BUTTON_DPAD_LEFT
	var right := key in [KEY_RIGHT, KEY_D] or padb == JOY_BUTTON_DPAD_RIGHT
	var ok := key in [KEY_ENTER, KEY_SPACE] or padb == JOY_BUTTON_A
	var back := key == KEY_ESCAPE or padb == JOY_BUTTON_B
	if confirm:
		if left or right or up or down:
			confirm_sel = 1 - confirm_sel
			arena.sfx("step", 0.4)
		elif ok: _confirm_pick(confirm_sel)
		elif back: _confirm_pick(1)
		elif tap != Vector2.INF:
			for k in confirm_rects.size():
				if confirm_rects[k].has_point(tap): _confirm_pick(k)
		return
	if up or down:
		sel = posmod(sel + (1 if down else -1), items.size())
		arena.sfx("step", 0.4)
	elif ok:
		_pick(sel)
	elif tap != Vector2.INF:
		for k in item_rects.size():
			if item_rects[k].has_point(tap):
				sel = k
				_pick(k)

## a menu item chosen
func _pick(k: int) -> void:
	match String(items[k][0]):
		"start":
			if has_save:
				confirm = true
				confirm_sel = 1
				confirm_t = clock
				arena.sfx("ready", 0.4)
			else: _begin()
		"load":
			if has_save: _begin()
			else: arena.sfx("step", 0.2)
		"opts":
			in_opts = true
			active = false
			visible = false          # the settings page is drawn under this layer: step aside until it closes
			arena.sfx("ready", 0.4)
			ui_root.menu.open_page("opts")
		"quit":
			get_tree().quit()

func _confirm_pick(k: int) -> void:
	confirm = false
	if k == 0:
		fresh = true
		_begin()
	else: arena.sfx("step", 0.3)

## the outro: the burst, the logo leaves, the field grows, the sweep carries on into the game
func _begin() -> void:
	outro = 0.0
	burst_t = clock
	if arena != null: arena.sfx("parry", 1.0)

## the intro's moves settle at once (a tap during the intro); the music plays on
func _finish_intro() -> void:
	skip = true
	intro_done = true
	menu_in = true
	slam_lap = beat.lap
	_tick()

func _go() -> void:
	active = false
	visible = false
	beat.stop()                  # bgm.gd cross-fades to the town from here
	if fresh:
		# 시작 over a saved game: the save goes, the scene reloads and starts the new game under the sweep
		if arena.save != null and FileAccess.file_exists(arena.save.path):
			DirAccess.remove_absolute(arena.save.path)
		if get_tree().current_scene != null:
			pending_fresh = true
			get_tree().reload_current_scene()
			return
	var c: String = arena.player.who if arena.save != null and arena.save.loaded else "estelle"
	ui_root.start_game(c)


# ---------- what the save shows ----------
func _fame():
	return arena.fame if arena != null and "fame" in arena else null

## the members on the steps: everyone in fame.rec, 에스텔 first (a fresh game: her alone)
func people() -> Array:
	var F = _fame()
	var out: Array = ["estelle"]
	if F != null and "rec" in F:
		for c in F.rec:
			if not out.has(c): out.append(c)
	return out

## lights on the facade: Eilin's window and one more step of the ladder per restored facility (LIGHT_STEPS at most)
func lit_windows() -> int:
	var F = _fame()
	var n := 1
	if F != null and "fac" in F: n += F.fac.size()
	return mini(n, LIGHT_STEPS)

## the nameless crowd behind them: three per rank above the first, at most 18
func crowd_n() -> int:
	var F = _fame()
	var r: int = F.rank() if F != null and F.has_method("rank") else 1
	return mini(18, maxi(0, r - 1) * 3)

## there is room on the steps for someone who has not come yet (the cut-ins' empty chair)
func open_spots() -> bool:
	return people().size() < SPOTS.size()

## the hour the sky is painted for
func hour() -> float:
	return fposmod(arena.tod_h, 24.0) if arena != null and "tod_h" in arena else 12.0

## the sky colour by the hour (SKY_K, piecewise)
func sky(h: float) -> Color:
	for i in SKY_K.size() - 1:
		if h <= SKY_K[i + 1][0]:
			var u: float = (h - SKY_K[i][0]) / (SKY_K[i + 1][0] - SKY_K[i][0])
			return (SKY_K[i][1] as Color).lerp(SKY_K[i + 1][1], UIA.ez("ease-in-out", clampf(u, 0.0, 1.0)))
	return PINK

## how deep the night is (0 day .. 1 night): the hall cooler, the lights brighter, stars out
func night() -> float:
	var h := hour()
	return clampf((h - 17.0) / 3.5, 0.0, 1.0) if h >= 12.0 else clampf(1.0 - (h - 4.5) / 3.0, 0.0, 1.0)

func _sync_crowd() -> void:
	var m := crowd_n()
	while crowd_seed.size() < m:
		var i := crowd_seed.size()
		var rs := RandomNumberGenerator.new()
		rs.seed = 7919 * (i + 1)
		crowd_seed.append([rs.randf(), i % 3, rs.randi_range(0, 3), fposmod(i * 47.0 + 20.0, 360.0), rs.randf() * TAU])
	while crowd_seed.size() > m: crowd_seed.pop_back()

## the cut-in slot (0..3) mt is in and who it shows: a member id, "" for the empty chair, by `_slot_who`
func slot() -> int:
	return clampi(floori((mt - BEAT.sec_t("B")) / BEAT.PHRASE), 0, 3)

## who slot k shows: 에스텔, then the rest of rec; after them, while there is room on the steps, the empty chair on
## every other slot (the members again in between), else the members again
func slot_who(k: int) -> String:
	var P := people()
	if k < P.size(): return P[k]
	var j := k - P.size()
	if open_spots():
		if j % 2 == 0: return ""
		return P[(j / 2) % P.size()]
	return P[j % P.size()]

## the current section for a time (tests)
func section_at(t: float) -> String:
	return BEAT.section_at(t)


# ---------- layout ----------
## the pink field's edge x at the top and the bottom (home: 44 % / 64 % of the width; a thin band in section C), with the
## intro slash, the breathing, the parallax and the outro growth
func _field(vs: Vector2) -> Array:
	var sh := 0.0
	var u := mu(T_FIELD, 0.33, [0.3, 0.6, 0.3, 1.0]) if beat.live else 0.0
	sh = 0.7 * vs.x * (1.0 - u)
	if outro >= 0.0:
		sh -= (0.64 * vs.x + 0.12 * vs.x) * UI.bez(0.6, 0.0, 0.9, 0.4, (outro - 150.0) / 500.0)
	sh += sin(clock / 7000.0 * TAU) * 6.0 + sp_px.x * 4.0
	return [lerpf(0.44, 0.70, fC) * vs.x + sh, lerpf(0.64, 0.88, fC) * vs.x + sh]

## the hall plate's home rect: A — its right lantern a hair past the right edge, the ground row on the ground line, the
## building ~0.74 H tall or the plate ~0.76 W wide, whichever is smaller; C — C_SCALE of that, centred on 0.68 W with
## the ground at C_GROUND; in between by fC
func _hall_rect(vs: Vector2) -> Rect2:
	var sa := minf(0.74 * vs.y / (HALL_GROUND - HALL_TOP), 0.76 * vs.x / HALL.get_width())
	var ra := Rect2(vs.x + 0.06 * vs.x - HALL.get_width() * sa, GROUND * vs.y - HALL_GROUND * sa, HALL.get_width() * sa, HALL.get_height() * sa)
	var sc := sa * C_SCALE
	var rc := Rect2(0.68 * vs.x - HALL.get_width() * sc / 2.0, C_GROUND * vs.y - HALL_GROUND * sc, HALL.get_width() * sc, HALL.get_height() * sc)
	return Rect2(ra.position.lerp(rc.position, fC), ra.size.lerp(rc.size, fC))

## how far the hall has left in the outro (0..1), i = its place in the stagger
func _out(i: int) -> float:
	if outro < 0.0: return 0.0
	return UIA.p(outro, i * 40.0, 280.0, "in")

## the hall's motion: [translation, rotation (rad), scale, alpha] — the intro's spring from the right (first lap), the
## loop's 1.03 bump, the slide out right behind section B's wedge, the outro's exit, a hair of breath and parallax
func _hall_motion(vs: Vector2, par: float) -> Array:
	var s := 0.0
	var a := 1.0
	if beat.lap == 0:
		s = 1.0 - mu(T_HALL, T_HALL_LAND - T_HALL, "bk")
		a = mu(T_HALL, 0.15, "linear")
	var bump := 1.0
	if beat.lap >= 1 and mt >= T_HALL_LAND: bump = 1.0 + 0.03 * (1.0 - mu(T_HALL_LAND, 0.2, "out"))
	var tr := Vector2(0.5 * vs.x * s + 0.9 * vs.x * fB + 0.7 * vs.x * UIA.p(outro, 0.0, 480.0, "in"), 0) + Vector2(sp_px.x, sp_py.x) * Vector2(4.0, 2.0) * par
	var br := 0.004 * (0.5 - 0.5 * cos(clock / 5200.0 * TAU))
	if not beat.live: a = 0.0
	return [tr, deg_to_rad(-3.0 * s), (1.0 + 0.06 * s + br) * bump, a]

## member i's standing picture, its rect and the source region: one common knee-up height (times the framing's scale),
## the knee line just under the ground line
func _person(vs: Vector2, i: int, c: String) -> Array:
	var tex := SK.tex(c, "st_full")
	var src := Rect2()
	if tex != null: src = Rect2(0, 0, tex.get_width(), tex.get_height() * FULL_CROP)
	else:
		tex = SK.tex(c, "st_base")
		if tex == null: return [null, Rect2(), Rect2()]
		src = Rect2(0, 0, tex.get_width(), tex.get_height())
	var sp: Array = SPOTS[mini(i, SPOTS.size() - 1)]
	var hr := _hall_rect(vs)
	var h := PERSON_H * vs.y * kF
	var w := h * src.size.x / src.size.y
	var cx: float = hr.position.x + DOOR_X * (hr.size.x / HALL.get_width()) + sp[0] * vs.x * kF
	var fy: float = gy * vs.y + (KNEE_SINK - sp[1]) * vs.y * kF
	return [tex, Rect2(cx - w / 2.0, fy - h, w, h), src]

## when member i lands on the steps (s)
func _drop_t(i: int) -> float:
	return T_DROP + i * BEAT.PULSE

## member i's motion on the steps: [translation, rotation, scale, alpha, lit] — the drop from above landing on its beat
## (`lag` s later for the cut-out), the short landing and two shuffles of the clumsy one, the bob on its own beat of the
## bar (in unison in section D), the breathing, the parallax, the slide out behind section B and the outro's exit
func _person_motion(vs: Vector2, i: int, lag: float, par: float) -> Array:
	var sp: Array = SPOTS[mini(i, SPOTS.size() - 1)]
	var tl := _drop_t(i)
	var u := mu(tl - 0.33 + lag, 0.33, "bk6" if lag > 0.0 else "bk")
	var a := mu(tl - 0.33 + lag, 0.12, "linear")
	var lit: float = clampf((mu(tl - 0.33, 0.33, "linear") - 0.45) / 0.15, 0.0, 1.0)
	var s := 1.0 - u
	var tr := Vector2(0, -0.3 * vs.y * s) + Vector2(sp_px.x, sp_py.x) * Vector2(11.0, 5.0) * float(sp[2]) * par * kF
	# the clumsy one (the second member) lands 0.03 W short and shuffles up in two hops
	if i == 1:
		var h1 := mu(tl + 0.33, 0.25, "out")
		var h2 := mu(tl + 0.66, 0.25, "out")
		tr.x -= 0.03 * vs.x * kF * (1.0 - 0.5 * h1 - 0.5 * h2)
		tr.y -= 6.0 * kF * (sin(h1 * PI) + sin(h2 * PI))
	# the bob: 2 px on its own beat of the bar; section D: 4 px in unison on the bar (back out of step in the outro)
	var uni := 0.0
	if sec == "D": uni = 1.0
	elif sec == "out": uni = 1.0 - mu(BEAT.bar_t(117), 0.3, "linear")
	var own := BEAT.bump(fposmod((mt - BEAT.T0 - i * BEAT.BEAT) / BEAT.PULSE, 1.0), 0.3)
	tr.y -= 2.0 * kF * own * (1.0 - uni) + 4.0 * kF * BEAT.bump(beat.bar_phase(), 0.3) * uni
	var br := 0.5 - 0.5 * cos(clock / (3400.0 + i * 310.0) * TAU + i * 1.7)
	tr.y -= 2.5 * br * kF
	tr.x += 0.9 * vs.x * fB + 0.7 * vs.x * UIA.p(outro, 40.0 + i * 40.0, 480.0, "in")
	if not beat.live: a = 0.0
	return [tr, deg_to_rad(-2.0 * s), Vector2(1.0 - 0.004 * br, 1.0 + 0.007 * br), a, lit]

## the logo block's breathing and the slam jolt (on the landing)
func _logo_xf(vs: Vector2) -> Transform2D:
	var br := 1.0 + 0.006 * (0.5 - 0.5 * cos(clock / 4200.0 * TAU))
	var j := Vector2.ZERO
	if beat.live and not skip and mt >= T_LOGO and mt < T_LOGO + 0.16:
		var k: Array = UIA.kf((mt - T_LOGO) * 1000.0, [[0.0, [0.0, 0.0]], [0.3, [-3.0, -1.5]], [0.65, [2.0, 0.0]], [1.0, [0.0, 0.0]]], 160.0)
		j = Vector2(k[0], k[1])
	var piv := Vector2(0.25 * vs.x, 0.5 * vs.y)
	return UIA.xf(piv, j, 0.0, Vector2(br, br))

## the logo's home rect: the left column, ~0.4 W wide (capped at 0.54 H tall), above the menu; docked small top-left in B
func _logo_rect(vs: Vector2) -> Rect2:
	var w := 0.4 * vs.x
	var h := w * LOGO.get_height() / LOGO.get_width()
	if h > 0.54 * vs.y:
		h = 0.54 * vs.y
		w = h * LOGO.get_width() / LOGO.get_height()
	var ra := Rect2(0.04 * vs.x, 0.1 * vs.y, w, h)
	var rb := Rect2(0.03 * vs.x, 0.04 * vs.y, w * 0.6, h * 0.6)
	return Rect2(ra.position.lerp(rb.position, fB), ra.size.lerp(rb.size, fB))


# ---------- draw: ground ----------
func _draw() -> void:
	var vs := get_viewport_rect().size
	if gate:
		_gate(vs)
		return
	var nk := night()
	draw_rect(Rect2(Vector2.ZERO, vs), INK.lerp(sky(hour()), 0.3 * fC))
	# faint white halftone over the black, drifting
	var scr := Vector2(clock / 90.0, clock / 140.0)
	_tiled(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]), UI.dot_tile(0.07, Color.WHITE), scr, Color.WHITE)
	# the pink field with its dark halftone (the drift eases out in the outro so the select screen's fixed dots take over)
	var f := _field(vs)
	# (the first slash frames put both edges past the right side: no polygon then, a clamped one while only the top is)
	var pts := PackedVector2Array([Vector2(minf(f[0], vs.x), 0), Vector2(vs.x, 0), Vector2(vs.x, vs.y), Vector2(minf(f[1], vs.x), vs.y)])
	if minf(f[0], f[1]) < vs.x - 0.5:
		# the sky: the field in the hour's pink, eased to the plain pink as the outro grows it (the sweep's colour)
		draw_colored_polygon(pts, sky(hour()).lerp(PINK, UIA.p(outro, 150.0, 500.0, "ease") if outro >= 0.0 else 0.0))
		var k := 1.0 - UIA.p(outro, 150.0, 500.0, "ease") if outro >= 0.0 else 1.0
		# the halftone breathes on the bar (section A), drifts twice as fast in D
		var breathe := 1.0 - 0.3 * BEAT.bump(beat.bar_phase(), 0.5) * (1.0 if sec == "A" else 0.0)
		_tiled(pts, UI.dot_tile(0.24), drift * k, Color(1, 1, 1, breathe))
	# stars over the village at night (section C), else white specks rising through the pink
	_specks(self, vs, f, nk)
	# guide lines: travel in, stop on the logo, leave
	var ox := vs.x * UIA.p(outro, 0.0, 400.0, "in") if outro >= 0.0 else 0.0
	for L in LINES:
		var ln: float = L[1] * vs.x
		var ph: float = fmod(clock + L[3], L[2]) / L[2]
		var stop: float = L[4] * vs.x - ln
		var x: float
		if ph < 0.42: x = lerpf(-ln - 20.0, stop, UIA.ez("mv", ph / 0.42))
		elif ph < 0.62: x = stop
		else: x = lerpf(stop, vs.x + 20.0, UIA.ez("in", (ph - 0.62) / 0.38))
		draw_rect(Rect2(x + ox, L[0] * vs.y, ln, 2.0), Color(1, 1, 1, 0.6))

## the quiet gate (the web, before the first tap): ink and paper, the flower pulsing, 터치하여 시작
func _gate(vs: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vs), INK)
	_tiled(PackedVector2Array([Vector2.ZERO, Vector2(vs.x, 0), vs, Vector2(0, vs.y)]), UI.dot_tile(0.07, Color.WHITE), Vector2(clock / 90.0, clock / 140.0), Color.WHITE)
	var pu := 1.0 + 0.04 * UIA.pulse(clock, 1300.0)
	var eh := 0.22 * vs.y
	var ew := eh * EMBLEM.get_width() / EMBLEM.get_height()
	var c := Vector2(vs.x * 0.5, vs.y * 0.44)
	draw_set_transform_matrix(UIA.xf(c, Vector2.ZERO, 0.0, Vector2(pu, pu)))
	draw_texture_rect(EMBLEM, Rect2(c - Vector2(ew, eh) / 2.0, Vector2(ew, eh)), false)
	draw_set_transform(Vector2.ZERO)
	var fn := UI.noto()
	var s := "터치하여 시작"
	var fs := int(0.03 * vs.y)
	draw_string(fn, Vector2(vs.x * 0.5 - UI.text_w(fn, s, fs) / 2.0, vs.y * 0.44 + eh * 0.62 + fs), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CREAM, 0.7 + 0.3 * UIA.pulse(clock, 1300.0)))

## white specks rising through the pink (and, in section C's night, stars twinkling over the whole sky)
func _specks(ci: CanvasItem, vs: Vector2, f: Array, nk: float) -> void:
	var stars := fC * nk
	for s in specks:
		var y: float = fposmod(s[1] - clock / s[3], 1.0) * vs.y
		var x: float = vs.x * (0.42 + 0.6 * s[0]) + sin(clock / 1900.0 + s[1] * 7.0) * 6.0
		var edge: float = lerpf(f[0], f[1], y / vs.y)
		if x > edge + 12.0 and x < vs.x - 4.0:
			var r: float = 1.5 + 1.5 * s[2]
			ci.draw_rect(Rect2(x - r, y - r, r * 2.0, r * 2.0), Color(1, 1, 1, 0.5 * s[2]))
		if stars > 0.01:
			var sx: float = vs.x * (0.02 + 0.96 * fposmod(s[0] * 3.7 + s[1], 1.0))
			var sy: float = vs.y * (0.04 + 0.6 * fposmod(s[1] * 2.3 + s[0], 1.0))
			var tw: float = 0.5 + 0.5 * sin(clock / 700.0 + s[0] * 40.0)
			ci.draw_rect(Rect2(sx - 1.5, sy - 1.5, 3.0, 3.0), Color(1, 1, 1, (0.3 + 0.5 * tw) * stars))

## a polygon filled with a repeating 11 px tile (uv = position / 11, scrolled), tinted
func _tiled(pts: PackedVector2Array, tex: Texture2D, scroll: Vector2, col: Color) -> void:
	var uvs := PackedVector2Array()
	for v in pts: uvs.append((v + scroll) / 11.0)
	draw_colored_polygon(pts, col, uvs, tex)


# ---------- draw: the plate, the lights, the panel, the crowd ----------
func _draw_bg() -> void:
	if not active or gate or outro > 1050.0: return
	var vs := get_viewport_rect().size
	var nk := night()
	if fB < 1.0:
		_hall(vs, nk)
		_crowd(vs)
		_walkers(vs)
		_fog(bg_layer, vs, 0)
	if fB > 0.0: _panel(vs)

## the hall plate (its own colours by day, cooled toward violet at night), the sign board swinging on its chains, and
## the light ladder (lights_on steps): the right window, the left window, the lantern by the door, the bracket lantern,
## warm light through the door's crack, smoke from the left chimney, then the right. Section D flares the lit windows on
## the bar; section C's walkers brighten the door lantern as they go in.
func _hall(vs: Vector2, nk: float) -> void:
	var ci := bg_layer
	var m: Array = _hall_motion(vs, 1.0)
	var a: float = m[3]
	if a <= 0.0: return
	var r := _hall_rect(vs)
	var sc := r.size.x / HALL.get_width()
	var piv := Vector2(r.get_center().x, r.end.y)
	var base := UIA.xf(piv, m[0], m[1], Vector2(m[2], m[2]))
	ci.draw_set_transform_matrix(base)
	var tint := Color.WHITE.lerp(HALL_NIGHT, nk)
	var col := Color(tint, a)
	# the plate in three pieces around the sign's region (the sign comes separately, swinging)
	var W := float(HALL.get_width())
	var H := float(HALL.get_height())
	var sx := SIGN.end.x
	for reg in [Rect2(0, 0, sx, SIGN.position.y), Rect2(0, SIGN.end.y, sx, H - SIGN.end.y), Rect2(sx, 0, W - sx, H)]:
		ci.draw_texture_rect_region(HALL, Rect2(r.position + reg.position * sc, reg.size * sc), reg, col)
	var n := lights_on
	var warm := Color("#ffcf7a")
	var ts := clock / 1000.0
	var glow := UI.glow()
	var flare := BEAT.bump(beat.bar_phase(), 0.4) * (1.0 if sec == "D" else 0.0)
	# 1-2) the windows: a warm fill over the panes, a candle's flicker (on the 8ths), a soft glow
	for i in mini(n, 2):
		var wr: Rect2 = WIN_R if i == 0 else WIN_L
		var pr := Rect2(r.position + wr.position * sc, wr.size * sc)
		var fl := 0.88 + 0.12 * LIT.fl(ts, i * 2.3) + 0.08 * BEAT.bump(fposmod(beat.beat_phase() * 2.0 + i * 0.5, 1.0), 0.4) + 0.3 * flare
		var on := _light_on(i)
		ci.draw_texture_rect(glow, pr.grow(pr.size.y * (0.7 + 0.5 * nk + 0.4 * flare)), false, Color(warm, (0.16 + 0.24 * nk) * fl * a * on))
		ci.draw_rect(pr, Color(warm, (0.62 + 0.1 * fl) * a * on))
	# 3-4) the lanterns: a warm dot and a halo (the door's brightens for section C's walkers)
	for i in [2, 3]:
		if n <= i: continue
		var c: Vector2 = r.position + (LANT_DOOR if i == 2 else LANT_R) * sc
		var fl := 0.85 + 0.15 * LIT.fl(ts, i * 1.9) + (0.6 * _door_flash() if i == 2 else 0.0)
		var on := _light_on(i)
		var rad := 48.0 * sc
		ci.draw_texture_rect(glow, Rect2(c - Vector2(rad, rad) * (2.6 + 1.4 * nk), Vector2(rad, rad) * (5.2 + 2.8 * nk)), false, Color(warm, (0.18 + 0.22 * nk) * fl * a * on))
		ci.draw_texture_rect(glow, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, Color(1.0, 0.93, 0.75, 0.9 * fl * a * on))
	# 5) the door's crack: warm light leaking out
	if n > 4:
		var cr := Rect2(r.position + DOOR_CRACK.position * sc, DOOR_CRACK.size * sc)
		var fl := 0.85 + 0.15 * LIT.fl(ts, 7.0)
		var on := _light_on(4)
		ci.draw_texture_rect(glow, cr.grow_individual(cr.size.x * 4.0, cr.size.x * 2.0, cr.size.x * 4.0, cr.size.x * 2.0), false, Color(warm, (0.22 + 0.2 * nk) * fl * a * on))
		ci.draw_rect(cr, Color(1.0, 0.9, 0.7, 0.85 * fl * a * on))
	# the sign board on its chains, swinging ±2°
	var sw := deg_to_rad(2.0) * sin(clock / 2300.0 * TAU)
	ci.draw_set_transform_matrix(base * UIA.xf(r.position + SIGN_PIV * sc, Vector2.ZERO, sw))
	ci.draw_texture_rect_region(HALL, Rect2(r.position + SIGN.position * sc, SIGN.size * sc), SIGN, col)
	ci.draw_set_transform_matrix(base)
	# 6-7) chimney smoke: soft puffs rising, drifting with the breeze, fading as they grow
	var tx := LIT.soft_tex()
	for sm in smoke_seed:
		var ch: int = sm[0]
		if n < 6 + ch: continue
		var u: float = fposmod(ts / 4.2 + sm[1], 1.0)
		var top: Vector2 = r.position + (CHIM_L if ch == 0 else CHIM_R) * sc
		var rise := u * 0.26 * vs.y * kF
		var px: float = top.x + (sin(ts * 0.4 + sm[1] * 9.0) * 0.5 + 0.5 + sm[2] * 0.3) * 0.03 * vs.x * u * kF + sin(ts * 1.3 + sm[1] * 20.0) * 3.0
		var sz: float = (0.035 + 0.06 * u) * vs.y * sm[3] * kF
		var al: float = (0.26 if u < 0.15 else 0.26 * (1.0 - (u - 0.15) / 0.85)) * (1.0 - 0.2 * nk) * _light_on(5 + ch)
		ci.draw_texture_rect(tx, Rect2(px - sz, top.y - rise - sz, sz * 2.0, sz * 2.0), false, Color(0.96, 0.92, 0.97, al * a))
	ci.draw_set_transform(Vector2.ZERO)

## a light's switch-on (0..1): step i comes on one bar after the one before it (the ladder from the cursor's slap)
func _light_on(i: int) -> float:
	if sec != "A" or beat.lap >= 1 or skip: return 1.0
	return mu(T_CURSOR + i * BEAT.BAR, 0.3, "out")

## section C, bar 80: two tiny figures walk along the ground from the far right to the door and go in
const WALK_BAR := 80
const WALK_S := 6.0
func _walkers(vs: Vector2) -> void:
	if fC <= 0.0: return
	var ci := bg_layer
	var hr := _hall_rect(vs)
	var door := hr.position.x + DOOR_X * hr.size.x / HALL.get_width()
	var t0 := BEAT.bar_t(WALK_BAR)
	for k in 2:
		var ts := t0 + k * 0.45
		var u := (mt - ts) / WALK_S
		if u <= 0.0 or u >= 1.0: continue
		var x := lerpf(vs.x + 0.03 * vs.x, door + (0.004 if k == 0 else -0.004) * vs.x, UIA.ez("linear", u))
		var h := 0.06 * vs.y * (1.0 - 0.1 * k)
		var step := absf(sin((mt - ts) * 11.0 + k))
		var a := (1.0 if u < 0.92 else (1.0 - u) / 0.08) * fC
		var xf := Transform2D(0.0, Vector2(x, gy * vs.y + 1.0 - 1.5 * step))
		_figure(xf, h, 0, Color(INK, a), 1.0)
	ci.draw_set_transform(Vector2.ZERO)

## the door lantern's extra glow as a walker goes in (0..1)
func _door_flash() -> float:
	if fC <= 0.0: return 0.0
	var t0 := BEAT.bar_t(WALK_BAR)
	var f := 0.0
	for k in 2:
		var tin := t0 + k * 0.45 + WALK_S * 0.92
		if mt >= tin and mt < tin + 0.8: f = maxf(f, sin((mt - tin) / 0.8 * PI))
	return f * fC

## the crowd's arrival for figure j in the section drawn: [sprint start (s), present already]
func _crowd_start(j: int) -> Array:
	match sec:
		"A": return [T_CROWD + j * BEAT.BEAT, false]
		"B": return [INF, false]
		"C": return [BEAT.sec_t("C") + WEDGE + j * BEAT.BAR, false]
	return [-INF, true]

## the nameless members: paper cut-out silhouettes on the steps behind the people, flat ink, each with a thin rim in
## its own hue (same saturation and value: a crowd of colours), in three rows that drift a hair. Each arrives as a
## thin line in its hue sprinting in from the right edge along the ground (120 ms), then unfolds into the figure
## (120 ms). Section D: the rims brighten and pulse on the bar (fading out of step in the outro). Rank 1: no crowd —
## a single faint pink line sprints to 아이다's empty spot and fades (the first-run hint).
func _crowd(vs: Vector2) -> void:
	if not beat.live: return
	_sync_crowd()
	var ci := bg_layer
	var hr := _hall_rect(vs)
	var m: Array = _hall_motion(vs, 1.4)
	var piv := Vector2(hr.get_center().x, hr.end.y)
	var base := UIA.xf(piv, m[0], m[1], Vector2(m[2], m[2]))
	var o := 1.0 - 0.9 * fB
	if crowd_seed.is_empty():
		# the hint: a pink line to the empty spot
		if sec == "A" and mt >= T_CROWD and mt < T_CROWD + 1.6:
			var u := mu(T_CROWD, 0.12, "mv")
			var sp: Array = SPOTS[1]
			var x: float = hr.position.x + DOOR_X * hr.size.x / HALL.get_width() + sp[0] * vs.x * kF
			var lx := lerpf(vs.x + 10.0, x, u)
			var la := 0.5 * (1.0 if mt < T_CROWD + 0.7 else 1.0 - (mt - T_CROWD - 0.7) / 0.9)
			var h := PERSON_H * vs.y * kF * 0.8
			ci.draw_set_transform_matrix(base)
			ci.draw_rect(Rect2(lx - 1.0, gy * vs.y - h, 2.0, h), Color(PINK.lerp(Color.WHITE, 0.6), la))
			ci.draw_set_transform(Vector2.ZERO)
		return
	var pulse := BEAT.bump(beat.bar_phase(), 0.35)
	var dk := 0.0
	if sec == "D": dk = 1.0
	elif sec == "out": dk = 1.0 - mu(BEAT.bar_t(116), 0.3, "linear")
	var order := crowd_seed.duplicate()
	order.sort_custom(func(p, q): return p[1] > q[1])       # back rows first
	for cs in order:
		var j := crowd_seed.find(cs)
		var st: Array = _crowd_start(j)
		var t0: float = st[0]
		if mt < t0: continue
		var row: int = cs[1]
		var x: float = hr.position.x + hr.size.x * (-0.02 + 1.04 * cs[0])
		var fy: float = gy * vs.y - (0.02 + 0.03 * row) * vs.y * kF
		var h: float = (0.18 - 0.022 * row) * vs.y * kF
		var bob := sin(clock / 2900.0 * TAU + cs[4]) * 1.2 * kF
		var rim := Color.from_hsv(cs[3] / 360.0, 0.7 - 0.2 * pulse * dk, 0.95 + 0.05 * pulse * dk)
		var sprint := 1.0 if st[1] else mu(t0, 0.12, "mv")
		var unfold := 1.0 if st[1] else mu(t0 + 0.12, 0.12, "bk")
		var xx := lerpf(vs.x + 10.0, x, sprint)
		var xf := base * Transform2D(0.0, Vector2(xx, fy + bob))
		if sprint < 1.0 or unfold <= 0.0:
			ci.draw_set_transform_matrix(xf)
			ci.draw_rect(Rect2(-1.0, -h, 2.0, h), Color(rim, o))
			continue
		xf = xf * Transform2D(0.0, Vector2(maxf(0.05, unfold), 1.0), 0.0, Vector2.ZERO)
		_figure(xf, h, cs[2], Color(rim, o), 1.0 + (2.2 + 1.8 * pulse * dk) / h)
		_figure(xf, h, cs[2], Color(INK, o), 1.0)
		if unfold < 1.0:
			ci.draw_set_transform_matrix(base * Transform2D(0.0, Vector2(xx, fy + bob)))
			ci.draw_rect(Rect2(-1.0, -h, 2.0, h), Color(rim, o * (1.0 - unfold)))
	ci.draw_set_transform(Vector2.ZERO)

## one paper figure (feet at the origin, `h` tall): kind 0 plain, 1 pointed hat, 2 hood, 3 a staff
func _figure(xf: Transform2D, h: float, kind: int, col: Color, grow: float) -> void:
	var ci := bg_layer
	ci.draw_set_transform_matrix(xf * Transform2D(0.0, Vector2(grow, grow), 0.0, Vector2.ZERO))
	var sw := h * 0.17
	var bh := h * 0.72
	var body := PackedVector2Array([Vector2(-sw, 0), Vector2(sw, 0), Vector2(sw * 0.95, -bh * 0.55), Vector2(sw * 1.25, -bh * 0.8),
		Vector2(sw * 0.55, -bh), Vector2(-sw * 0.55, -bh), Vector2(-sw * 1.25, -bh * 0.8), Vector2(-sw * 0.95, -bh * 0.55)])
	ci.draw_colored_polygon(body, col)
	var hr := h * 0.11
	var hc := Vector2(0, -bh - hr * 0.9)
	ci.draw_circle(hc, hr, col)
	match kind:
		1: ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-hr * 1.4, -hr * 0.3), hc + Vector2(hr * 1.4, -hr * 0.3), hc + Vector2(hr * 0.2, -hr * 3.2)]), col)
		2: ci.draw_colored_polygon(PackedVector2Array([hc + Vector2(-hr * 1.3, hr * 0.8), hc + Vector2(-hr * 1.1, -hr * 1.3), hc + Vector2(0, -hr * 1.6), hc + Vector2(hr * 1.1, -hr * 1.3), hc + Vector2(hr * 1.3, hr * 0.8)]), col)
		3: ci.draw_rect(Rect2(sw * 1.15, -h * 1.02, h * 0.025, h * 1.02), col)

## drifting fog bands across the lower screen (layer 0 behind the people, 1 in front): soft blobs stretched wide,
## in the sky's whitened pink, thicker when the steps are still empty; they rise a little through the outro
func _fog(ci: CanvasItem, vs: Vector2, layer: int) -> void:
	if outro > 1050.0 or not beat.live: return
	var a := mu(0.42, 0.6, "linear") * (1.0 if people().size() <= 1 else 0.5) * (1.0 - fB)
	if a <= 0.0: return
	var tx := LIT.soft_tex()
	var col := sky(hour()).lerp(Color.WHITE, 0.75)
	var ts := clock / 1000.0
	var rise := 0.03 * mu(BEAT.sec_t("out"), 6.0, "ease") if sec == "out" else 0.0
	var bands: Array = [[0.84, 0.2, 7.0, 0.0], [0.93, 0.16, 11.0, 300.0]] if layer == 0 else [[0.9, 0.1, 5.0, 150.0]]
	for b in bands:
		var bw := 0.72 * vs.x
		var off := fmod(ts * b[2] + b[3], bw)
		var x := -bw + off
		var cy: float = (b[0] - rise - 0.03 * fC) * vs.y + sin(ts * 0.3 + b[3]) * 4.0
		while x < vs.x + bw:
			ci.draw_texture_rect(tx, Rect2(x - bw * 0.5, cy - 0.11 * vs.y, bw, 0.22 * vs.y), false, Color(col, b[1] * a))
			x += bw * 0.5
	ci.draw_set_transform(Vector2.ZERO)

## section B's cut-in panel: a slanted parallelogram over the right ~62 % with an ink shadow, pink on even slots and ink
## with a pink rim on odd ones, the flower as a watermark, the halftone drifting over it
func _panel(vs: Vector2) -> void:
	var ci := bg_layer
	var k := slot()
	var tsw := BEAT.sec_t("B") + k * BEAT.PHRASE + WEDGE
	var slide := (1.0 - mu(tsw, 0.3, "mv")) * 0.1 * vs.x + 0.7 * vs.x * UIA.p(outro, 0.0, 480.0, "in")
	var x0 := 0.28 * vs.x + slide + (1.0 - fB) * 0.8 * vs.x
	var pts := PackedVector2Array([Vector2(x0, 0), Vector2(vs.x + 0.3 * vs.x, 0), Vector2(vs.x + 0.3 * vs.x, vs.y), Vector2(x0 + 0.2 * vs.x, vs.y)])
	var shadow := PackedVector2Array()
	for p in pts: shadow.append(p + Vector2(0.02 * vs.x, 0.015 * vs.y))
	ci.draw_colored_polygon(shadow, Color(INK, 0.85))
	var pink := sky(hour())
	ci.draw_colored_polygon(pts, pink)
	if k % 2 == 1:
		var inset := PackedVector2Array([pts[0] + Vector2(0.012 * vs.x, 0), pts[1], pts[2], pts[3] + Vector2(0.012 * vs.x, 0)])
		ci.draw_colored_polygon(inset, INK)
	# the flower, a watermark behind the figure
	var eh := 0.9 * vs.y
	var ew := eh * EMBLEM.get_width() / EMBLEM.get_height()
	var ec := Vector2(0.72 * vs.x + slide, 0.5 * vs.y)
	ci.draw_texture_rect(EMBLEM, Rect2(ec - Vector2(ew, eh) / 2.0, Vector2(ew, eh)), false, Color(INK, 0.14) if k % 2 == 0 else Color(pink, 0.14))
	var uvs := PackedVector2Array()
	for v in pts: uvs.append((v + drift) / 11.0)
	ci.draw_colored_polygon(pts, Color(1, 1, 1, 0.8), uvs, UI.dot_tile(0.24))

## the cut-in's figure: who, the picture, its rect (0.95 H tall, bottom at 1.02 H, centred on 0.70 W) and source region
func _panel_figure(vs: Vector2) -> Array:
	var who := slot_who(slot())
	if who == "": return ["", null, Rect2(), Rect2()]
	var tex := SK.tex(who, "st_full")
	var h := 0.95 * vs.y
	if tex == null:
		tex = SK.tex(who, "st_base")
		h = 0.72 * vs.y
	if tex == null: return [who, null, Rect2(), Rect2()]
	var w := h * tex.get_width() / tex.get_height()
	return [who, tex, Rect2(0.70 * vs.x - w / 2.0, 1.02 * vs.y - h, w, h), Rect2(0, 0, tex.get_width(), tex.get_height())]

## the cut-in figure's motion: [translation, scale] — in from the right on its slot's switch (`lag` s later for the
## cut-out), breathing on the pulse, out right in the outro
func _panel_motion(vs: Vector2, lag: float) -> Array:
	var tsw := BEAT.sec_t("B") + slot() * BEAT.PHRASE + WEDGE
	var u := mu(tsw + lag, 0.45, "bk6" if lag > 0.0 else "bk")
	var tr := Vector2(0.5 * vs.x * (1.0 - u) + 0.7 * vs.x * UIA.p(outro, 0.0, 480.0, "in") + (1.0 - fB) * 0.8 * vs.x, 0)
	var sy := 1.0 + 0.007 * sin(beat.pulse_phase() * TAU)
	return [tr, Vector2(1.0, sy)]


# ---------- draw: silhouettes ----------
func _draw_sil() -> void:
	if not active or gate or outro > 1050.0: return
	var ci := sil_layer
	var vs := get_viewport_rect().size
	if fB < 1.0:
		var P := people()
		for i in P.size():
			var pr: Array = _person(vs, i, P[i])
			var tex: Texture2D = pr[0]
			if tex == null: continue
			var r: Rect2 = pr[1]
			var piv := Vector2(r.get_center().x, r.end.y)
			# the white cut-out, trailing the drop by 80 ms (and the outro's trailing sp_sil)
			var m: Array = _person_motion(vs, i, 0.08, 1.6)
			if m[3] <= 0.0: continue
			var tr: Vector2 = m[0] + Vector2(0.022 * vs.x, 0.014 * vs.y) * kF + Vector2(0.4 * vs.x * sp_sil.x if sil_out else 0.0, 0)
			ci.draw_set_transform_matrix(UIA.xf(piv, tr, m[1], m[2]))
			ci.draw_texture_rect_region(tex, r, pr[2], Color(1, 1, 1, m[3]))
			# the thin ink copy, glued to the picture
			var m2: Array = _person_motion(vs, i, 0.0, 1.0)
			ci.draw_set_transform_matrix(UIA.xf(piv, m2[0] + Vector2(-0.004 * vs.x, 0.004 * vs.y) * kF, m2[1], m2[2]))
			ci.draw_texture_rect_region(tex, r, pr[2], Color(INK, m2[3]))
	if fB > 0.0:
		var pf: Array = _panel_figure(vs)
		if pf[1] != null:
			var r: Rect2 = pf[2]
			var piv := Vector2(r.get_center().x, r.end.y)
			var m: Array = _panel_motion(vs, 0.08)
			ci.draw_set_transform_matrix(UIA.xf(piv, m[0] + Vector2(0.02 * vs.x, 0.012 * vs.y) + Vector2(0.4 * vs.x * sp_sil.x if sil_out else 0.0, 0), 0.0, m[1]))
			ci.draw_texture_rect_region(pf[1], r, pf[3], Color(1, 1, 1, fB))
			var m2: Array = _panel_motion(vs, 0.0)
			ci.draw_set_transform_matrix(UIA.xf(piv, m2[0] + Vector2(-0.004 * vs.x, 0.004 * vs.y), 0.0, m2[1]))
			ci.draw_texture_rect_region(pf[1], r, pf[3], Color(INK, fB))
	ci.draw_set_transform(Vector2.ZERO)


# ---------- draw: logo, people, menu, wedge ----------
func _draw_fg() -> void:
	if not active or gate or outro > 1050.0: return
	var ci := fg_layer
	var vs := get_viewport_rect().size
	_logo(ci, vs)
	if fB < 1.0: _people(ci, vs)
	if fB > 0.0:
		_panel_front(ci, vs)
	_fog(ci, vs, 1)
	_prompt(ci, vs)
	_burst(ci, vs)
	# the white slash as the logo lands (cx_flash)
	if beat.live and not skip and mt >= T_LOGO and mt < T_LOGO + 0.38:
		var u := UIA.ez("mv", (mt - T_LOGO) / 0.38)
		var fr := Rect2(-0.2 * vs.x, vs.y * 0.5, vs.x * 1.4, 0.05 * vs.y)
		var fm := UIA.xf(fr.get_center(), Vector2(lerpf(-1.2, 1.2, u) * fr.size.x, 0), deg_to_rad(-12.0))
		ci.draw_colored_polygon(fm * UI.clip(fr, [[0, 45], [100, 0], [100, 25], [0, 100]]), Color.WHITE)
	_wedge(ci, vs)
	if not DEV.on or arena == null: return   # the build stamp: debug builds only (dev.gd)
	var ver: String = arena._stamp()
	var sf := UI.spaced(UI.noto(), 1)
	ci.draw_string(sf, Vector2(vs.x - 12.0 - UI.text_w(sf, ver, 11), vs.y - 12.0), ver, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))

## the members on the steps: each drops in on its beat, dark until it lands, then bobs, breathes and follows the pointer
func _people(ci: CanvasItem, vs: Vector2) -> void:
	var P := people()
	var order := range(P.size())
	order.reverse()                                  # the back of the row first, 에스텔 (0) on top
	for i in order:
		var pr: Array = _person(vs, i, P[i])
		var tex: Texture2D = pr[0]
		if tex == null: continue
		var r: Rect2 = pr[1]
		var m: Array = _person_motion(vs, i, 0.0, 1.0)
		if m[3] <= 0.0: continue
		var lit: float = m[4]
		ci.draw_set_transform_matrix(UIA.xf(Vector2(r.get_center().x, r.end.y), m[0], m[1], m[2]))
		ci.draw_texture_rect_region(tex, r, pr[2], Color(lit, lit, lit, m[3]))
	ci.draw_set_transform(Vector2.ZERO)

## the cut-in's front: the figure (or the empty chair), the name slab stamped twice, the specks in front
func _panel_front(ci: CanvasItem, vs: Vector2) -> void:
	var k := slot()
	var tsw := BEAT.sec_t("B") + k * BEAT.PHRASE + WEDGE
	var pf: Array = _panel_figure(vs)
	var who: String = pf[0]
	var lab := ""
	var role := ""
	if pf[1] != null:
		var r: Rect2 = pf[2]
		var m: Array = _panel_motion(vs, 0.0)
		var lit: float = clampf((mu(tsw, 0.45, "linear") - 0.45) / 0.15, 0.0, 1.0)
		ci.draw_set_transform_matrix(UIA.xf(Vector2(r.get_center().x, r.end.y), m[0], 0.0, m[1]))
		ci.draw_texture_rect_region(pf[1], r, pf[3], Color(lit, lit, lit, fB))
		ci.draw_set_transform(Vector2.ZERO)
		var sh: Array = SHEET.get(who, [CH.NAME.get(who, who), ""])
		lab = sh[0]
		role = sh[1]
	elif who == "":
		_chair(ci, vs, tsw)
		lab = "아직 오지 않은 동료"      # placeholder copy for the empty chair's slab
		role = ""
	# the name slab at the panel's top-left, stamped in two hits (0.85× at 90 % on the beat, 1× on the next)
	var u1 := mu(tsw + 0.15, 0.12, "bk")
	var u2 := mu(tsw + 0.15 + BEAT.BEAT, 0.12, "bk")
	if u1 <= 0.0 or lab == "": return
	var fb := UI.bhs()
	var fs := int(0.06 * vs.y)
	var fs2 := int(0.028 * vs.y)
	var tw := UI.text_w(fb, lab, fs)
	var rw := maxf(tw, UI.text_w(UI.noto(), role, fs2) if role != "" else 0.0) + 0.05 * vs.x
	var rh := (0.085 if role != "" else 0.065) * vs.y
	var slab := Rect2(0.33 * vs.x + 0.7 * vs.x * UIA.p(outro, 0.0, 480.0, "in"), 0.09 * vs.y, rw, rh)
	var sc := lerpf(0.85, 1.0, u2) if u2 > 0.0 else 0.85 * u1
	var al := lerpf(0.9, 1.0, u2) if u2 > 0.0 else 0.9 * u1
	ci.draw_set_transform_matrix(UIA.xf(slab.position + Vector2(0, rh * 0.5), Vector2.ZERO, deg_to_rad(-2.0), Vector2(sc, sc)))
	UI.para(ci, slab.position.x, slab.position.y, rw, rh, -rh * 0.25, Color(INK, al))
	ci.draw_string(fb, Vector2(slab.position.x + 0.025 * vs.x, slab.position.y + fs * 0.92), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CREAM, al))
	if role != "":
		ci.draw_string(UI.noto(), Vector2(slab.position.x + 0.027 * vs.x, slab.position.y + fs * 0.92 + fs2 * 1.2), role, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(CREAM, 0.85 * al))
	ci.draw_set_transform(Vector2.ZERO)
	# the specks in front of the panel
	_specks(ci, vs, [0.28 * vs.x, 0.48 * vs.x], 0.0)

## the empty chair: a dashed cream outline of someone standing where the figure would, and a big brush "?"
func _chair(ci: CanvasItem, vs: Vector2, tsw: float) -> void:
	var u := mu(tsw, 0.45, "bk")
	if u <= 0.0: return
	var h := 0.95 * vs.y
	var foot := Vector2(0.70 * vs.x + 0.5 * vs.x * (1.0 - u) + 0.7 * vs.x * UIA.p(outro, 0.0, 480.0, "in"), 1.02 * vs.y)
	var dash := 0.012 * vs.y
	var col := Color(CREAM, 0.8 * fB)
	for i in CHAIR.size():
		var p0: Vector2 = foot + Vector2(CHAIR[i][0], CHAIR[i][1]) * h
		var p1: Vector2 = foot + Vector2(CHAIR[(i + 1) % CHAIR.size()][0], CHAIR[(i + 1) % CHAIR.size()][1]) * h
		var seg := p1 - p0
		var n := int(seg.length() / (dash * 2.0))
		for d in maxi(1, n):
			var a := p0 + seg * (float(d) * 2.0 * dash / maxf(seg.length(), 0.001))
			var b := a + seg.normalized() * minf(dash, (p1 - a).length())
			ci.draw_line(a, b, col, 2.0)
	var af := UI.anton(true, 0)
	var fs := int(0.42 * vs.y)
	var q := "?"
	var qc := foot + Vector2(-UI.text_w(af, q, fs) / 2.0, -h * 0.38)
	ci.draw_set_transform_matrix(UIA.xf(qc, Vector2.ZERO, deg_to_rad(-6.0), Vector2(u, u)))
	ci.draw_string(af, qc + Vector2(0.012 * vs.x, 0.012 * vs.y), q, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(PINK, 0.9 * fB))
	ci.draw_string(af, qc, q, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CREAM, fB))
	ci.draw_set_transform(Vector2.ZERO)

## the brush logo on its blob: three paint splats pop behind it one per beat, then it lands from 1.25× with a short
## overshoot, 2° over-rotated and settling in 150 ms; the blob rolls ±1° under it; it pulses on the bar in section D
## (first to stop in the outro), docks small top-left behind section B's wedge and leaves left in the outro
func _logo(ci: CanvasItem, vs: Vector2) -> void:
	if not beat.live: return
	var r := _logo_rect(vs)
	var base := _logo_xf(vs)
	var o := _out(0)
	if o >= 1.0: return
	var c := r.get_center()
	var leave := Vector2(-0.7 * vs.x * o, 0)
	# the splats (a fresh set each lap), and section D's phrase bursts
	var bursts: Array = []
	for i in T_SPLAT.size():
		bursts.append([T_SPLAT[i], 0.26, [0.18, 0.3, 0.22][i], [0.3, 0.22, 0.26][i], [25.0, -70.0, 140.0][i], 0.9, false])
	if sec == "D" or sec == "out":
		for b in [91, 99, 107]:
			bursts.append([BEAT.bar_t(b), 0.4, 0.5, 1.6, -15.0 * b, 1.0, true])
	for sp in bursts:
		var u := mu(sp[0], sp[1], "bk" if not sp[6] else "out")
		if u <= 0.0 or (sp[6] and u >= 1.0): continue
		var sz: float = r.size.x * (sp[3] * u if not sp[6] else lerpf(0.3, sp[3], u))
		var at := r.position + Vector2(sp[2], 0.3 if not sp[6] else 0.5) * r.size + leave if not sp[6] else c + leave
		var al: float = sp[5] * (1.0 if not sp[6] or u < 0.5 else 1.0 - (u - 0.5) / 0.5)
		ci.draw_set_transform_matrix(base * UIA.xf(at, Vector2.ZERO, deg_to_rad(sp[4]) + deg_to_rad(-4.0 * o)))
		ci.draw_texture_rect(BURST, Rect2(at - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, al))
	# the blob and the logo land together
	var u := mu(T_LOGO - 0.39, 0.39, "bk")
	if u <= 0.0:
		ci.draw_set_transform(Vector2.ZERO)
		return
	var al := mu(T_LOGO - 0.39, 0.1, "linear")
	var sc := 1.0 + 0.25 * (1.0 - u)
	var over := deg_to_rad(-2.0) * (1.0 - mu(T_LOGO, 0.15, "ease"))
	var pk := 0.0
	if sec == "D": pk = 1.0
	elif sec == "out": pk = 1.0 - mu(BEAT.bar_t(115), 0.3, "linear")
	sc *= 1.0 + 0.02 * BEAT.bump(beat.bar_phase(), 0.4) * pk
	var roll := deg_to_rad(1.0) * sin(clock / 6400.0 * TAU)
	var bw := r.size.x * 1.15
	var bh := bw * BLOB.get_height() / BLOB.get_width()
	ci.draw_set_transform_matrix(base * UIA.xf(c, leave, roll + over - deg_to_rad(6.0 * o), Vector2(sc * 1.02, sc * 1.02)))
	ci.draw_texture_rect(BLOB, Rect2(c - Vector2(bw, bh) / 2.0, Vector2(bw, bh)), false, Color(1, 1, 1, al))
	ci.draw_set_transform_matrix(base * UIA.xf(c, leave, over - deg_to_rad(6.0 * o), Vector2(sc, sc)))
	ci.draw_texture_rect(LOGO, r, false, Color(1, 1, 1, al))
	ci.draw_set_transform(Vector2.ZERO)

## 시작's burst: the splash pops from the logo's centre, 0.2× → 2.4× over 350 ms, fading out at the end
func _burst(ci: CanvasItem, vs: Vector2) -> void:
	if burst_t < 0.0: return
	var u := UIA.p(clock - burst_t, 0.0, 350.0, "out")
	if u >= 1.0: return
	var c := _logo_rect(vs).get_center()
	var sz: float = _logo_rect(vs).size.x * lerpf(0.2, 2.4, u)
	var al := 1.0 if u < 0.6 else 1.0 - (u - 0.6) / 0.4
	ci.draw_set_transform_matrix(UIA.xf(c, Vector2.ZERO, deg_to_rad(-20.0 * u)))
	ci.draw_texture_rect(BURST, Rect2(c - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, al))
	ci.draw_set_transform(Vector2.ZERO)

## the ink wedge: a slanted band (the field's angle) crossing the screen with a burst on its leading edge; left → right
## at each section's start and each cut-in slot (the composition switches once it covers the screen), from the right
## at the end of the track (it covers the screen exactly at the wrap and uncovers the intro)
func _wedge(ci: CanvasItem, vs: Vector2) -> void:
	if wedge.is_empty(): return
	var xl: float = wedge[0] * vs.x
	var dir: int = wedge[1]
	var bw := 1.6 * vs.x
	var sl := 0.2 * vs.x
	var pts: PackedVector2Array
	if dir > 0: pts = PackedVector2Array([Vector2(xl, 0), Vector2(xl - bw, 0), Vector2(xl - bw + sl, vs.y), Vector2(xl + sl, vs.y)])
	else: pts = PackedVector2Array([Vector2(xl, 0), Vector2(xl + bw, 0), Vector2(xl + bw + sl, vs.y), Vector2(xl + sl, vs.y)])
	ci.draw_colored_polygon(pts, INK)
	var uvs := PackedVector2Array()
	for v in pts: uvs.append((v + Vector2(clock / 90.0, clock / 140.0)) / 11.0)
	ci.draw_colored_polygon(pts, Color.WHITE, uvs, UI.dot_tile(0.07, Color.WHITE))
	if dir > 0:
		var u: float = wedge[2]
		var big: bool = wedge[3]
		var sz := (0.9 if big else 0.5) * vs.y * (1.0 if u < 1.0 else 1.0 + 0.6 * (u - 1.0))
		var al := 1.0 if u < 1.0 else 1.0 - (u - 1.0)
		var c := Vector2(xl + 0.5 * sl, 0.5 * vs.y)
		ci.draw_set_transform_matrix(UIA.xf(c, Vector2.ZERO, deg_to_rad(30.0 * u)))
		ci.draw_texture_rect(BURST, Rect2(c - Vector2(sz, sz) / 2.0, Vector2(sz, sz)), false, Color(1, 1, 1, al))
		ci.draw_set_transform(Vector2.ZERO)

## the motto above the logo, the emblem by the menu, the menu rows (one per beat), the brush cursor and the confirm card
func _prompt(ci: CanvasItem, vs: Vector2) -> void:
	var W := vs.x
	var H := vs.y
	var lx := 0.089 * W
	var o := UIA.p(outro, 0.0, 280.0, "in") if outro >= 0.0 else 0.0
	# the motto, small above the logo (hidden while the logo is docked in section B)
	var ua := mu(T_LOGO, 1.3, "ease") * (1.0 - o) * (1.0 - fB) if beat.live else 0.0
	if ua > 0.0:
		var fn := UI.noto()
		var motto := "서툴지만, 물러서지 않는다"
		var fs := int(0.026 * H)
		ci.draw_string(fn, Vector2(lx + 0.02 * W * (1.0 - ua), 0.082 * H), motto, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.78, 0.78, 0.82, ua))
	var fb := UI.bhs()
	var fs2 := int(0.03 * H)
	var ih := 0.052 * H
	var gap := 0.012 * H
	var y0 := 0.96 * H - items.size() * (ih + gap) + gap
	var sw0 := 0.19 * W
	# the guild's flower, small at the menu column's top right, popping with the cursor
	var ucur := 1.0 if menu_in else (mu(T_CURSOR, 0.25, "bk") if beat.live else 0.0)
	if ucur > 0.0 and o < 1.0:
		var eh := 0.16 * H
		var ew := eh * EMBLEM.get_width() / EMBLEM.get_height()
		var er := Rect2(lx + sw0 + 0.012 * W, y0 - eh * 0.1, ew, eh)
		ci.draw_set_transform_matrix(UIA.xf(er.get_center(), Vector2(0, 0.25 * H * o), 0.0, Vector2(ucur, ucur)))
		ci.draw_texture_rect(EMBLEM, er, false, Color(1, 1, 1, minf(1.0, ucur)))
		ci.draw_set_transform(Vector2.ZERO)
	item_rects.clear()
	confirm_rects.clear()
	var pulse := BEAT.bump(beat.pulse_phase(), 0.45) if intro_done else 0.0
	# the cursor: the brush stroke is the picked row's slab, sliding between rows on its spring; it slaps onto 시작
	# from 1.3× and pulses ±2 % on the pulse
	if ucur > 0.0 and o < 1.0 and not confirm:
		var bw := sw0 * 1.3
		var bh := ih * 2.3
		var cy := y0 + sp_cur.x * (ih + gap) + ih * 0.5
		var cc := Vector2(lx + 0.014 * W + sw0 * 0.5, cy)
		var psc := (1.0 + 0.02 * pulse) * (1.0 + 0.3 * (1.0 - minf(1.0, ucur)))
		ci.draw_set_transform_matrix(UIA.xf(cc, Vector2(0, 0.25 * H * o), 0.0, Vector2(psc, psc)))
		ci.draw_texture_rect(BRUSH, Rect2(cc - Vector2(bw, bh) / 2.0, Vector2(bw, bh)), false, Color(1, 1, 1, minf(1.0, ucur)))
		ci.draw_set_transform(Vector2.ZERO)
	for k in items.size():
		var u := 1.0 if menu_in else (mu(T_MENU[k], 0.4, "bk") if beat.live else 0.0)
		if u <= 0.0 or o >= 1.0:
			item_rects.append(Rect2())
			continue
		var on := k == sel and not confirm and ucur > 0.0     # until the brush slaps it, the picked row is a slab too
		var dim: bool = items[k][0] == "load" and not has_save
		var lab: String = items[k][1]
		var r := Rect2(lx + (0.014 * W if on else 0.0), y0 + k * (ih + gap), sw0, ih)
		var sc := 1.0 + (0.02 * pulse if on else 0.0)
		# the second row takes two stamps: a 0.01 W push on the beat after it lands
		var push := 0.0
		if k == 1 and not menu_in: push = 0.01 * W * sin(PI * mu(T_MENU[1] + BEAT.BEAT, 0.25, "linear"))
		ci.draw_set_transform_matrix(UIA.xf(r.get_center(), Vector2(-0.3 * W * (1.0 - u) + push, 0.25 * H * o), deg_to_rad(-3.0 * (1.0 - u)), Vector2(sc, sc)))
		if not on:
			# a white slab; the picked row rides the brush stroke instead, its label white with an ink shadow
			UI.para(ci, r.position.x, r.position.y, sw0, ih, -ih * 0.3, Color(1, 1, 1, 0.35) if dim else Color.WHITE)
		var tc := Color.WHITE if on else INK
		if dim: tc = Color(0.1, 0.1, 0.12, 0.5)
		var tp := Vector2(r.position.x + 0.022 * W, r.position.y + ih * 0.5 + fs2 * 0.36)
		if on: tp.x = r.position.x + sw0 * 0.5 - UI.text_w(fb, lab, fs2) * 0.5 + 0.01 * W    # on the stroke's thick middle
		if on: ci.draw_string(fb, tp + Vector2(1.5, 1.5), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(INK, 0.8))
		ci.draw_string(fb, tp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, tc)
		ci.draw_set_transform(Vector2.ZERO)
		item_rects.append(Rect2(r.position + Vector2(-0.012 * W, 0), r.size + Vector2(0.024 * W, gap)))
	if not confirm: return
	# 시작 over a save: a black card beside the menu asks before the save goes
	var cw := 0.36 * W
	var chh := 0.2 * H
	var cr := Rect2(lx + 0.24 * W, 0.96 * H - chh, cw, chh)
	var cu := UIA.p(clock - confirm_t, 0.0, 260.0, "bk")
	ci.draw_set_transform_matrix(UIA.xf(cr.get_center(), Vector2(0, 0.08 * H * (1.0 - cu)), deg_to_rad(-2.0), Vector2(cu, cu)))
	ci.draw_colored_polygon(UI.clip(cr, [[0, 4], [100, 0], [99, 100], [1, 96]]), INK)
	ci.draw_colored_polygon(UI.clip(Rect2(cr.position.x, cr.position.y, 0.006 * W, chh), [[0, 0], [100, 0], [100, 100], [0, 100]]), PINK)
	var fn2 := UI.noto()
	var fsq := int(0.03 * H)
	ci.draw_string(fn2, Vector2(cr.position.x + 0.03 * W, cr.position.y + 0.06 * H), "저장된 진행이 있어요.", HORIZONTAL_ALIGNMENT_LEFT, -1, fsq, Color.WHITE)
	ci.draw_string(fn2, Vector2(cr.position.x + 0.03 * W, cr.position.y + 0.1 * H), "지우고 처음부터 시작할까요?", HORIZONTAL_ALIGNMENT_LEFT, -1, fsq, Color(0.8, 0.8, 0.85))
	var labs := ["새로 시작", "돌아가기"]
	for k in 2:
		var bw := 0.13 * W
		var br := Rect2(cr.position.x + 0.03 * W + k * (bw + 0.02 * W), cr.end.y - 0.07 * H, bw, 0.05 * H)
		var bon := k == confirm_sel
		UI.para(ci, br.position.x, br.position.y, bw, br.size.y, -br.size.y * 0.3, PINK if bon else Color.WHITE)
		ci.draw_string(fb, Vector2(br.position.x + 0.02 * W, br.position.y + br.size.y * 0.5 + fs2 * 0.36), labs[k], HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color.WHITE if bon else INK)
		confirm_rects.append(br.grow(6.0))
	ci.draw_set_transform(Vector2.ZERO)
