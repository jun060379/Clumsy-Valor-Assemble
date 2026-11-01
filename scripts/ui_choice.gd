extends "res://scripts/ui_page.gd"
## Bran's choices (prototype branTalk: the talk box keeps his last line, choices stack on the right):
## 장비를 맡기고 싶어요 (the forge; its back button returns here) · 잡담한다 (BRAN_CHAT + his line for the leader) · 그만 가볼게요.
## Before he has joined the guild (fame.bran) he only sends you to Eilin first.

const POR := preload("res://assets/bran/por.png")
const BRAN := preload("res://scripts/bran.gd")
const TALK := preload("res://scripts/talk_fx.gd")

var line := ""
var choices: Array = []          # [icon, label, Callable]
var sel := 0
var talk = TALK.new()
var _lay: Array = []


func _ready() -> void:
	super()
	keys = ["bran"]
	for i in 3:
		var c := Control.new()
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if i == 1: c.material = UI.solid_mat()
		var k := i
		c.draw.connect(func(): _draw_layer(k, c))
		add_child(c)
		_lay.append(c)

func _opened() -> void:
	# it follows a talk with him straight on: the scene is already up, only the choices come in
	talk.reset("bran", POR, "브랜", "길드 대장장이", tcol())
	talk.open_t = 5000.0

func _tick(dt: float) -> void:
	talk.step(dt)

## who decides: the fame system when it is here (fame.bran); open until then
func joined() -> bool:
	var F = arena.get("fame")
	if F == null: return true
	var v = F.get("bran")
	if v == null and F is Object and F.has_method("get_flag"): v = F.get_flag("bran")
	return v == null or bool(v)

func setup(back: bool, ln: String) -> void:
	sel = -1
	if not joined():
		line = ln if ln != "" else "접수대의 에일린한테 먼저 인사부터 하고 오쇼. 일 하나 끝내고 오면, 그때 얘기합시다. 흐흐."
		choices = [["leave", "알겠어요", func(): _leave()]]
		return
	line = ln if ln != "" else ("또 맡길 거 있습니까? 흐흐." if back else "")
	choices = [
		["hammer", "장비를 맡기고 싶어요", func():
			menu.page = ""
			menu.forge.set_from_dlg(true)
			menu.open_page("forge")],
		["talk", "잡담한다", func():
			menu.page = ""
			var pool: Array = BRAN.CHAT + BRAN.CHAT_C.get(arena.player.who, [])
			var L: Array = pool[randi() % pool.size()]
			_bran_talk()
			arena.open_dialog("bran", POR, "브랜", "길드 대장장이", L, func(): menu.open_bran(false, L[L.size() - 1]))],
		["leave", "그만 가볼게요", func():
			menu.page = ""
			_bran_talk()
			arena.open_dialog("bran", POR, "브랜", "길드 대장장이", ["또 오십쇼. 필요하면요. 흐흐."], null)],
	]

func _leave() -> void:
	menu.page = ""
	sfx("ready", 0.25)

func _bran_talk() -> void:
	if arena.level_kind() == "town" and arena.level.get("bran") != null:
		arena.level.bran.talk_t = 2000.0
		arena.level.bran.play("talk")

func back() -> void:
	choices[choices.size() - 1][2].call()

func _key(k: int) -> void:
	if k == KEY_ESCAPE: back()
	elif k in [KEY_UP, KEY_W]: sel = choices.size() - 1 if sel < 0 else (sel + choices.size() - 1) % choices.size()
	elif k in [KEY_DOWN, KEY_S]: sel = 0 if sel < 0 else (sel + 1) % choices.size()
	elif k >= KEY_1 and k <= KEY_9 and k - KEY_1 < choices.size():
		sel = k - KEY_1
		sfx("ready", 0.3)
		choices[sel][2].call()
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_X, KEY_Z]:
		if sel < 0:
			sel = 0
			sfx("ready", 0.15)
			return
		sfx("ready", 0.3)
		choices[sel][2].call()
	else:
		# the attack key as bound
		for e in InputMap.action_get_events("attack"):
			if e is InputEventKey and (e.physical_keycode == k or e.keycode == k):
				if sel < 0:
					sel = 0
					sfx("ready", 0.15)
					return
				sfx("ready", 0.3)
				choices[sel][2].call()
				return

func _paint(vs: Vector2) -> void:
	# the talk scene of dialog.gd (talk_fx.gd), his line held, the choices on the right
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25 * clampf(t / 200.0, 0.0, 1.0)))
	for c in _lay: c.queue_redraw()
	for i in talk.ch_polys.size():
		var ii: int = i
		if talk.ch_polys[i].size() > 2:
			hit(talk.ch_polys[i], func():
				sfx("ready", 0.3)
				sel = ii
				choices[ii][2].call())

func _draw_layer(k: int, c: Control) -> void:
	if not live(): return
	var vs := get_viewport_rect().size
	match k:
		0: talk.draw_back(c, vs)
		1: talk.draw_sil(c, vs)
		2:
			talk.show(line, int(t / 32.0))
			var hv: int = talk.choice_at(hover)
			if hv >= 0 and hv != sel:
				sel = hv
				sfx("ready", 0.15)
			talk.set_choices(choices.map(func(x): return String(x[1])), sel)
			talk.draw_front(c, vs)

func _icon(k: String, c: Vector2, col: Color) -> void:
	match k:
		"hammer":
			draw_line(c + Vector2(-6, 7), c + Vector2(2, -1), col, 2.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-1, -6), c + Vector2(3, -9), c + Vector2(8, -4), c + Vector2(4, 0)]), col)
		"talk":
			draw_rect(Rect2(c + Vector2(-7, -6), Vector2(14, 9)), col, false, 2.0)
			draw_line(c + Vector2(-4, 3), c + Vector2(-7, 7), col, 2.0)
		_:
			draw_line(c + Vector2(-6, -7), c + Vector2(-6, 7), col, 2.0)
			draw_line(c + Vector2(-1, 0), c + Vector2(7, 0), col, 2.0)
			draw_line(c + Vector2(4, -3), c + Vector2(7, 0), col, 2.0)
			draw_line(c + Vector2(4, 3), c + Vector2(7, 0), col, 2.0)
