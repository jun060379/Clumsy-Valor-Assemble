extends "res://scripts/ui_page.gd"
## Bran's choices (prototype branTalk: the talk box keeps his last line, choices stack on the right):
## 장비를 맡기고 싶어요 (the forge; its back button returns here) · 잡담한다 (BRAN_CHAT + his line for the leader) · 그만 가볼게요.
## Before he has joined the guild (fame.bran) he only sends you to Eilin first.

const POR := preload("res://assets/bran/por.png")
const BRAN := preload("res://scripts/bran.gd")

var line := ""
var choices: Array = []          # [icon, label, Callable]
var sel := 0


func _ready() -> void:
	super()
	keys = ["bran"]

## who decides: the fame system when it is here (fame.bran); open until then
func joined() -> bool:
	var F = arena.get("fame")
	if F == null: return true
	var v = F.get("bran")
	if v == null and F is Object and F.has_method("get_flag"): v = F.get_flag("bran")
	return v == null or bool(v)

func setup(back: bool, ln: String) -> void:
	sel = 0
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
	elif k in [KEY_UP, KEY_W]: sel = (sel + choices.size() - 1) % choices.size()
	elif k in [KEY_DOWN, KEY_S]: sel = (sel + 1) % choices.size()
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_X, KEY_Z]:
		sfx("ready", 0.3)
		choices[sel][2].call()
	else:
		# the attack key as bound
		for e in InputMap.action_get_events("attack"):
			if e is InputEventKey and (e.physical_keycode == k or e.keycode == k):
				sfx("ready", 0.3)
				choices[sel][2].call()
				return

func _paint(vs: Vector2) -> void:
	# the same talk box as dialog.gd, his line held, choices on the right
	var bh := 118.0
	var bx := 16.0
	var bw := vs.x - 32.0
	var by := vs.y - bh - 16.0
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.25 * clampf(t / 200.0, 0.0, 1.0)))
	var ph := minf(250.0, vs.y * 0.52)
	var pw := POR.get_width() * ph / POR.get_height()
	draw_texture_rect(POR, Rect2(bx + 6.0, by - ph + 30.0, pw, ph), false)
	var px := bx + 170.0 if vs.x > 560.0 else bx + 12.0
	draw_rect(Rect2(bx, by, bw, bh), Color(0.06, 0.05, 0.07, 0.9))
	draw_rect(Rect2(bx, by, bw, bh), Color(1.0, 0.91, 0.66, 0.5), false, 2.0)
	draw_rect(Rect2(bx, by, 4.0, bh), Color("#8fcf8a"))
	var fb: Font = arena.font_black
	var fr: Font = arena.font_bold
	draw_string(fb, Vector2(px, by + 28.0), "브랜", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ffe9a8"))
	draw_string(fr, Vector2(px + tw(fb, "브랜", 17) + 10.0, by + 28.0), "길드 대장장이", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))
	var n := mini(line.length(), int(t / 32.0))
	draw_multiline_string(fr, Vector2(px, by + 58.0), line.substr(0, n), HORIZONTAL_ALIGNMENT_LEFT, bx + bw - px - 20.0, 16, 3, Color("#fff6df"))
	# choices: slanted black plates, the chosen one white
	var cw := 260.0
	var ch := 40.0
	var cy := by - 14.0 - choices.size() * (ch + 8.0)
	for i in choices.size():
		var d := t - i * 60.0
		var e := UI.bk(clampf(d / 260.0, 0.0, 1.0))
		if d <= 0.0: continue
		var on := i == sel
		var x := vs.x - cw - 30.0 + 40.0 * (1.0 - e) - (12.0 if on else 0.0)
		var y := cy + i * (ch + 8.0)
		var poly := PackedVector2Array([Vector2(x + 10, y), Vector2(x + cw + 10, y), Vector2(x + cw, y + ch), Vector2(x, y + ch)])
		if on: draw_colored_polygon(PackedVector2Array([poly[0] + Vector2(4, 4), poly[1] + Vector2(4, 4), poly[2] + Vector2(4, 4), poly[3] + Vector2(4, 4)]), tcol())
		draw_colored_polygon(poly, Color(1, 1, 1, e) if on else Color(0.05, 0.04, 0.06, 0.92 * e))
		var ic := Vector2(x + 28, y + ch / 2.0)
		draw_circle(ic, 13.0, Color(0, 0, 0, e) if on else Color(1, 1, 1, 0.12 * e))
		_icon(choices[i][0], ic, Color(1, 1, 1, e))
		draw_string(UI.noto_k(), Vector2(x + 52, y + 26), choices[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0, e) if on else Color(1, 1, 1, e))
		var ii := i
		hit(poly, func():
			sel = ii
			sfx("ready", 0.3)
			choices[ii][2].call())

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
