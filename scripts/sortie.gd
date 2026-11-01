extends Control
## Sortie / return (sortie.js): the dungeon select (dsel.gd, from the 출격 마차 or by walking off either end of the village),
## the layered band sweep (white → colour → black, sweep()), the run-out from a village edge (RUN), the dungeon entry dash
## that skids to a stop (dinPrep / dinGo / DIN) and the Eva "출격" deploy cut, the 'dun' and 'boss' title cards (title_card.gd),
## the dungeon clear screen (clear_screen.gd), and the RETURN sweep with the run-in from the edge she left by (goTown / RIN).
## Also hosts the ult cut-in overlay (ult_cut.gd) and the fountain party screen (party_edit.gd) on the same canvas layer.
## Room-to-room changes inside the cave keep the plain fade.

const UI := preload("res://scripts/ui_kit.gd")
const DSEL := preload("res://scripts/dsel.gd")
const TCARD := preload("res://scripts/title_card.gd")
const CLEAR := preload("res://scripts/clear_screen.gd")
const UCUT := preload("res://scripts/ult_cut.gd")
const PARTY := preload("res://scripts/party_edit.gd")
const CH := preload("res://scripts/chars.gd")
const BLACK := Color("#0d0b10")
const TOWN_W := 9450.0

var arena
var dsel
var tc
var clear
var ucut
var party_ui
var dpl_layer: Control
var swp_layer: Control

var dir := 0                     # S.dir: the village edge she is leaving by (0 = the wagon)
var town_x := 5107.0             # townX: where she left the village
var dsel_cd := 0.0
var run := {"on": false, "dir": 0, "t": 0.0, "x": 0.0, "go": false}
var rin := {"on": false, "dir": 0, "x": 0.0, "to": 0.0}
var din := {"on": 0, "dir": 1, "to": 0.0, "t": 0.0, "x": 0.0, "v": 1.6}
var dpl := {"on": false, "t": 0.0, "nm": "", "sq": ""}
var swp := {"on": false}
var last_cur := ""
var sh_start := 0                # shilling when the sortie began (the clear screen's 실링 +n)
var tones := {}
var tone_pool: Array = []
var dots_w: Texture2D
var speed := 1.0                 # ?slowtx in the page URL plays the transitions at 1/10 speed (screenshots)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	party_ui = _child(PARTY)
	dsel = _child(DSEL)
	clear = _child(CLEAR)
	ucut = _child(UCUT)
	dpl_layer = _layer(_draw_dpl)
	swp_layer = _layer(_draw_swp)
	swp_layer.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tc = _child(TCARD)
	for i in 4:
		var ap := AudioStreamPlayer.new()
		add_child(ap)
		tone_pool.append(ap)
	var im := Image.create(11, 11, false, Image.FORMAT_RGBA8)
	for y in 11:
		for x in 11:
			var d := Vector2(x + 0.5 - 5.5, y + 0.5 - 5.5).length() / 5.5
			im.set_pixel(x, y, Color(1, 1, 1, 0.06 * clampf((0.31 - d) / 0.03, 0.0, 1.0)))
	dots_w = ImageTexture.create_from_image(im)
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search", true)
		if q is String and q.contains("slowtx"): speed = 0.1
		if q is String and q.contains("tsctl"): ts_ctl = true     # test hook: the page sets window.__ts to slow the game (screenshots)

var ts_ctl := false
var ts_t := 0.0
func _ts_poll(delta: float) -> void:
	ts_t += delta / maxf(0.01, Engine.time_scale)
	if ts_t < 0.2: return
	ts_t = 0.0
	var v = JavaScriptBridge.eval("window.__ts||1", true)
	if v is float or v is int: Engine.time_scale = clampf(float(v), 0.02, 4.0)
	# and what is on screen, for the screenshot script to wait on
	var gs := {"lk": arena.level_kind(), "tc": tc.kind if tc.active else "", "dsel": dsel.open, "launch": dsel.launch, "clear": clear.open,
		"party": party_ui.open, "swp": swp["on"], "run": run["on"], "rin": rin["on"], "din": din["on"], "dpl": dpl["on"],
		"ult": arena.ult.state, "x": arena.player.position.x, "who": arena.player.who, "title": arena.ui_root.title.active,
		"room": arena.level.room()["type"] if arena.level_kind() == "dungeon" else "", "cleared": arena.level.room()["cleared"] if arena.level_kind() == "dungeon" else false,
		"mobs": arena.mobs.filter(func(m): return not m.is_dead()).size(), "gate": arena.level.near_gate != null if arena.level_kind() == "dungeon" else false}
	JavaScriptBridge.eval("window.__gs=" + JSON.stringify(gs), true)

func _child(scr: Script) -> Control:
	var c := Control.new()
	c.set_script(scr)
	c.set("arena", arena)
	c.set("sortie", self)
	add_child(c)
	return c

func _layer(fn: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	c.draw.connect(fn)
	add_child(c)
	return c


# ---------- what the world asks ----------
## the world holds still under a title card, the dungeon select, the clear screen or the party screen
func holds() -> bool:
	return tc.active or dsel.open or clear.open or party_ui.open

## full-screen pages (the top-right buttons hide under them)
func covers() -> bool:
	return dsel.open or clear.open or party_ui.open or tc.active or ucut.on or swp["on"]

## keys forced during a scripted run: null = the player's own
func forced() -> Variant:
	if din["on"] > 0: return {}
	if run["on"]: return {"left": run["dir"] < 0, "right": run["dir"] > 0}
	if rin["on"]: return {"left": rin["dir"] < 0, "right": rin["dir"] > 0}
	return null

## every world frame, before anything moves: the boss card when an uncleared boss room is entered (once per run)
func pre_step() -> bool:
	if arena.level_kind() == "dungeon":
		var D = arena.level
		if D.cur != last_cur and arena.fade_dir != 1:     # once the room behind the fade has been entered
			last_cur = D.cur
			var r: Dictionary = D.room()
			if r["type"] == "boss" and not r["cleared"] and not r.get("tc", false):
				r["tc"] = true
				tc.play("boss")
				return true
	else:
		last_cur = ""
	return false

## after the player moved: the scripted runs set her x
func post_player(dt: float) -> void:
	var P = arena.player
	if dsel_cd > 0.0: dsel_cd -= dt
	if run["on"]:
		run["t"] += dt
		dsel_cd = 1.0e9
		var sp := minf(1.7, 0.55 + run["t"] * 0.004)
		run["x"] += run["dir"] * sp * dt
		P.position.x = run["x"]
		P.dir = run["dir"]
		if run["t"] > 620.0 and not run["go"]:
			run["go"] = true
			var d: int = run["dir"]
			sweep(d, [], func():
				run["on"] = false
				dsel_cd = 1500.0
				_enter_dungeon(), Callable(), _hold_dun)
		return
	if din["on"] == 1:
		din["t"] += dt
		if P.anim != "dash": P.set_anim("dash")
		P.dir = din["dir"]
		P.vx = 0.0
		din["x"] += din["dir"] * din["v"] * dt
		P.position.x = din["x"]
		if fmod(din["t"], 60.0) < dt: arena.dust(P.position + Vector2(-din["dir"] * 20.0, 0), din["dir"], false)
		if (din["dir"] > 0 and P.position.x >= din["to"]) or (din["dir"] < 0 and P.position.x <= din["to"]) or din["t"] > 900.0:
			P.position.x = din["to"]
			din["on"] = 2
			din["t"] = 0.0
			P.set_anim("stop")
			P.vx = 0.0
			arena.sfx("skid", 0.7)
			arena.dust(P.position + Vector2(-din["dir"] * 10.0, 0), din["dir"], true)
			deploy_cut()
		return
	if din["on"] == 2:
		din["t"] += dt
		if (P.anim != "stop" and din["t"] > 260.0) or din["t"] > 900.0: din["on"] = 0
		return
	if rin["on"]:
		rin["x"] += rin["dir"] * 0.75 * dt
		if (rin["dir"] > 0 and rin["x"] >= rin["to"]) or (rin["dir"] < 0 and rin["x"] <= rin["to"]):
			rin["x"] = rin["to"]
			rin["on"] = false
			dsel_cd = 1200.0
			P.vx = 0.0
			P.set_anim("stop")
		P.position.x = rin["x"]
		P.dir = rin["dir"]
		if arena.level_kind() == "town" and P.on:
			P.position.y = arena.level.floor_at(clampf(rin["x"], 1.0, TOWN_W - 1.0))
		return
	# walking off either end of the village opens the dungeon select (dselEdge)
	if arena.level_kind() == "town" and arena.fade_dir == 0 and dsel_cd <= 0.0 and not swp["on"]:
		var W: float = arena.world_w
		if (P.position.x <= 34.0 and P.keys.get("left", false)) or (P.position.x >= W - 34.0 and P.keys.get("right", false)):
			dsel_cd = 2500.0
			open_dsel(-1 if P.position.x < W / 2.0 else 1)


# ---------- the flow ----------
## openDsel: dir = the edge she walked off (0 from the wagon)
func open_dsel(d := 0) -> void:
	dir = d
	_release()
	dsel.show_it()

## sortieGo: called by the launch animation when it finishes; `clean` hides the dungeon select
func sortie_go(clean: Callable) -> void:
	var P = arena.player
	town_x = P.position.x
	sh_start = arena.shilling
	if dir != 0 and arena.level_kind() == "town":
		clean.call()
		run = {"on": true, "dir": dir, "t": 0.0, "x": P.position.x, "go": false}
		arena.dust(P.position, -dir, true)
		arena.sfx("dash", 0.7)
		return
	sweep(1, [], func():
		clean.call()
		_enter_dungeon(), Callable(), _hold_dun)

func _enter_dungeon() -> void:
	arena.fade = 0.0
	arena.fade_dir = 0
	arena.enter_dungeon()
	din_prep()

## the 'dun' card plays on the black band, then the bands peel and she dashes in
func _hold_dun(go: Callable) -> void:
	tc.play("dun", func():
		go.call()
		get_tree().create_timer(0.17 / speed).timeout.connect(din_go), true)

## dinPrep: placed back at the very edge of the entrance room
func din_prep() -> void:
	if arena.level_kind() != "dungeon": return
	var P = arena.player
	var d: int = P.dir if P.dir != 0 else 1
	var W: float = arena.world_w
	din = {"on": 0, "dir": d, "to": clampf(P.position.x + d * 260.0, 120.0, W - 120.0), "t": 0.0, "x": 0.0, "v": 1.6}
	P.position.x = 32.0 if d > 0 else W - 32.0
	P.vx = 0.0
	P.set_anim("idle")
	arena.snap_camera()

## dinGo: the dash in
func din_go() -> void:
	if arena.level_kind() != "dungeon": return
	var P = arena.player
	din["on"] = 1
	din["t"] = 0.0
	din["x"] = P.position.x
	din["v"] = maxf(1.6, absf(din["to"] - P.position.x) / 240.0)
	arena.sfx("dash", 0.8)
	arena.dust(P.position, -din["dir"], true)

## sortieTown / goTown: back to the village with the RETURN sweep; if she left by an edge she runs back in from it
func go_town() -> void:
	var edge := -1 if town_x <= 90.0 else (1 if town_x >= TOWN_W - 90.0 else 0)
	sweep(-1, ["RETURN", "길드 마을", "귀환"], func():
		arena.fade = 0.0
		arena.fade_dir = 0
		var G: float = arena.ground_y
		if edge != 0:
			var x0 := -220.0 if edge < 0 else TOWN_W + 220.0
			arena.go_town(Vector2(160.0 if edge < 0 else TOWN_W - 160.0, G), -edge)
			var P = arena.player
			P.position = Vector2(x0, arena.level.floor_at(clampf(x0, 1.0, TOWN_W - 1.0)))
			rin = {"on": true, "dir": -edge, "to": 160.0 if edge < 0 else TOWN_W - 160.0, "x": x0}
			arena.snap_camera()
		else:
			arena.go_town(Vector2(town_x, G), -1)
			arena.player.position.y = arena.level.floor_at(town_x))

## the dungeon's town door: in the cleared boss room it opens the clear screen (lootTownGate), elsewhere it goes home
func town_door() -> void:
	var D = arena.level
	var rm: Dictionary = D.room()
	if rm["type"] == "boss" and rm["cleared"]:
		clear.show_it()
	else:
		go_town()

func _release() -> void:
	for a in ["left", "right", "up", "down", "jump", "attack", "guard", "dash", "ult", "swap"]:
		if InputMap.has_action(a): Input.action_release(a)


# ---------- the layered band sweep ----------
## sweep(dir, title, mid, done, hold): bands in (white, colour, black, 70 ms apart), mid under the black, then a title
## [small, big, em] shows and the layers peel off; with `hold` something (a title card) plays on the black first.
func sweep(d: int, title: Array, mid: Callable, done := Callable(), hold := Callable()) -> void:
	if swp["on"]:
		mid.call()
		if done.is_valid(): done.call()
		return
	swp = {"on": true, "dir": d, "title": title, "t": 0.0, "mid": mid, "done": done, "hold": hold, "ph": "in", "wait": 0.0, "pt": 0.0, "col": UI.col(arena.player.who)}
	arena.sfx("dash", 0.5)

func _process(delta: float) -> void:
	if ts_ctl: _ts_poll(delta)
	var dt := minf(delta * 1000.0, 100.0) * speed
	if swp["on"]:
		swp["t"] += dt
		if swp["ph"] == "in" and swp["t"] >= 520.0:
			swp["mid"].call()
			swp["col"] = UI.col(arena.player.who)
			if swp["hold"].is_valid():
				swp["ph"] = "hold"
				swp["hold"].call(func(): _peel(0.0))
			else:
				swp["ph"] = "title"
				swp["tt"] = 0.0
		elif swp["ph"] == "title":
			swp["tt"] += dt
			if swp["tt"] >= 620.0 and swp["ph"] == "title":
				_peel(100.0)
		elif swp["ph"] == "peel":
			swp["pt"] += dt
			swp["tt"] = swp.get("tt", 0.0) + dt
			if swp["pt"] >= swp["wait"] + 160.0 + 460.0:
				swp["on"] = false
				if swp["done"].is_valid(): swp["done"].call()
		swp_layer.queue_redraw()
	if dpl["on"]:
		dpl["t"] += dt
		if dpl["t"] >= 1320.0: dpl["on"] = false
		dpl_layer.queue_redraw()

func _peel(wait: float) -> void:
	if not swp["on"] or swp["ph"] == "peel": return
	swp["ph"] = "peel"
	swp["wait"] = wait
	swp["pt"] = 0.0

## band x (percent of its own width) of layer k (0 white, 1 colour, 2 black)
func _band_x(k: int) -> float:
	var d: int = swp["dir"]
	var off := -140.0 if d > 0 else 140.0
	if swp["ph"] == "in":
		return off * (1.0 - UI.bez(0.6, 0.0, 0.9, 0.4, (swp["t"] - k * 70.0) / 380.0))
	if swp["ph"] == "peel":
		var j := 2 - k                    # black leaves first, then colour, then white
		var out := 140.0 if d > 0 else -140.0
		return out * UI.bez(0.2, 0.9, 0.25, 1.0, (swp["pt"] - swp["wait"] - j * 80.0) / 440.0)
	return 0.0

func _band_poly(p: float, vs: Vector2) -> PackedVector2Array:
	var w := vs.x * 1.6
	var cx := vs.x * 0.5 + p / 100.0 * w
	var top := -0.2 * vs.y
	var bot := 1.2 * vs.y
	var cy := vs.y * 0.5
	var tk := tan(deg_to_rad(-14.0 if swp["dir"] > 0 else 14.0))
	return PackedVector2Array([Vector2(cx - w / 2.0 - tk * (top - cy), top), Vector2(cx + w / 2.0 - tk * (top - cy), top),
		Vector2(cx + w / 2.0 - tk * (bot - cy), bot), Vector2(cx - w / 2.0 - tk * (bot - cy), bot)])

func _draw_swp() -> void:
	if not swp["on"]: return
	var ci := swp_layer
	var vs := get_viewport_rect().size
	var col: Color = swp["col"]
	for k in 3:
		var pts := _band_poly(_band_x(k), vs)
		if k == 0:
			ci.draw_colored_polygon(pts, Color.WHITE)
		elif k == 1:
			ci.draw_colored_polygon(pts, col)
			# the colour band's scan lines (white 22–24, black 61–64 of every 64 px)
			var x0: float = minf(pts[0].x, pts[3].x)
			var x1: float = maxf(pts[1].x, pts[2].x)
			if x1 > 0.0 and x0 < vs.x:
				var y := 0.0
				while y < vs.y:
					var l := _span(pts, y + 23.0)
					ci.draw_rect(Rect2(l.x, y + 22.0, l.y - l.x, 2.0), Color(1, 1, 1, 0.22))
					var l2 := _span(pts, y + 62.0)
					ci.draw_rect(Rect2(l2.x, y + 61.0, l2.y - l2.x, 3.0), Color(0, 0, 0, 0.18))
					y += 64.0
		else:
			ci.draw_colored_polygon(pts, BLACK)
			var uvs := PackedVector2Array()
			for v in pts: uvs.append(v / 11.0)
			ci.draw_colored_polygon(pts, Color.WHITE, uvs, dots_w)
	# the title over the black (RETURN / 길드 마을 / 귀환)
	var title: Array = swp["title"]
	if title.size() >= 2 and swp["ph"] in ["title", "peel"]:
		var tt: float = swp.get("tt", 0.0)
		var d: int = swp["dir"]
		var a := 0.0
		var ox := 0.0
		if tt < 620.0:
			var k := UI.bez(0.2, 0.9, 0.25, 1.0, tt / 300.0)
			a = k
			ox = -d * 90.0 * (1.0 - k)
		else:
			var k2 := UI.bez(0.6, 0.0, 0.9, 0.4, (tt - 620.0) / 260.0)
			a = 1.0 - k2
			ox = d * 140.0 * k2
		if a > 0.0:
			ci.draw_set_transform(vs / 2.0 + Vector2(ox, 0), deg_to_rad(-6.0))
			var fs := UI.anton(false, 6)
			var sw := UI.text_w(fs, title[0], 13)
			ci.draw_string(fs, Vector2(-sw / 2.0, -30), title[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(col, a))
			var bf := UI.bhs()
			var bs := clampi(int(vs.y * 0.09), 30, 64)
			var bw := UI.text_w(bf, title[1], bs)
			var r := Rect2(-bw / 2.0 - 12.0, -22.0, bw + 30.0, bs + 8.0)
			ci.draw_colored_polygon(UI.clip(r, [[0, 5], [100, 0], [98, 100], [1, 93]]), Color(1, 1, 1, a))
			ci.draw_string(bf, Vector2(-bw / 2.0, -22.0 + bs * 0.86), title[1], HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Color(0, 0, 0, a))
			if title.size() > 2:
				var ew := UI.text_w(UI.noto(), title[2], 12)
				ci.draw_string(UI.noto(), Vector2(-ew / 2.0, r.end.y + 20.0), title[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8 * a))
			ci.draw_set_transform(Vector2.ZERO)

## x range of the parallelogram at height y
static func _span(pts: PackedVector2Array, y: float) -> Vector2:
	var u := (y - pts[0].y) / (pts[3].y - pts[0].y)
	return Vector2(lerpf(pts[0].x, pts[3].x, u), lerpf(pts[1].x, pts[2].x, u))


# ---------- deploy cut (Eva): "출격" as a thin hollow outline over the whole screen ----------
func deploy_cut() -> void:
	var nm := "버섯 동굴"
	var sq: Array = arena.player.party.map(func(c): return CH.NAME[c])
	dpl = {"on": true, "t": 0.0, "nm": nm, "sq": " · ".join(sq)}
	arena.sfx("slam", 0.9)
	arena.shake(9, 1)
	arena.flash = maxf(arena.flash, 0.2)

func _draw_dpl() -> void:
	if not dpl["on"]: return
	var t: float = dpl["t"]
	# hard-cut flicker: hidden 120–160, 220–250, 1150–1190, 1250–1280
	if (t >= 120.0 and t < 160.0) or (t >= 220.0 and t < 250.0) or (t >= 1150.0 and t < 1190.0) or (t >= 1250.0 and t < 1280.0):
		return
	var ci := dpl_layer
	var vs := get_viewport_rect().size
	var solid := t < 60.0 or t >= 1280.0
	var bf := UI.bhs()
	var fs := int(minf(vs.y * 0.74, vs.x * 0.8 / 2.0))
	var sc := 1.12 - 0.12 * UI.bez(0.2, 0.9, 0.25, 1.0, t / 140.0)
	var w := UI.text_w(bf, "출격", fs)
	var asc := bf.get_ascent(fs)
	var desc := bf.get_descent(fs)
	ci.draw_set_transform(vs / 2.0, 0.0, Vector2(sc, sc))
	var p := Vector2(-w / 2.0, (asc - desc) / 2.0 - fs * 0.04)
	if solid:
		ci.draw_string(bf, p, "출격", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	else:
		ci.draw_string_outline(bf, p, "출격", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color.WHITE)
	ci.draw_set_transform(Vector2.ZERO)
	var fa := UI.anton(false, 8)
	ci.draw_string(fa, Vector2(vs.x * 0.03, vs.y * 0.05 + 14.0), "DEPLOY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	var fn := UI.spaced(UI.noto(), 4)
	var l1: String = dpl["nm"]
	var l2: String = dpl["sq"]
	ci.draw_string(fn, Vector2(vs.x * 0.97 - UI.text_w(fn, l1, 13), vs.y * 0.95 - 20.0), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	ci.draw_string(fn, Vector2(vs.x * 0.97 - UI.text_w(fn, l2, 13), vs.y * 0.95), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


# ---------- tbeep: tiny synthesized beeps for the title cards ----------
func beep(f: float, d: float, v := 0.05, kind := "square") -> void:
	var key := "%d_%d_%s" % [int(f), int(d * 1000.0), kind]
	if not tones.has(key):
		var rate := 22050
		var n := int(rate * (d + 0.02))
		var data := PackedByteArray()
		data.resize(n * 2)
		var ph := 0.0
		for i in n:
			var tt := float(i) / rate
			ph = fposmod(ph + f / rate, 1.0)
			var s := (1.0 if ph < 0.5 else -1.0) if kind == "square" else (ph * 2.0 - 1.0)
			var env := exp(-tt / maxf(0.005, d) * 9.2) if tt < d else 0.0
			data.encode_s16(i * 2, int(clampf(s * env * 0.5, -1.0, 1.0) * 32000.0))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = rate
		w.data = data
		tones[key] = w
	var best = tone_pool[0]
	for ap in tone_pool:
		if not ap.playing:
			best = ap
			break
	best.stream = tones[key]
	best.volume_db = linear_to_db(maxf(0.01, v * 6.0)) - 4.0
	best.play()
