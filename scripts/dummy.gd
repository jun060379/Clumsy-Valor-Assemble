extends Node2D
## Training dummy (spawnDummy / hitDummy / drawDummy): 60 HP of straw. Breaks, tips over, fades, and stands back up
## 3 s later with a ring. The row on the right (inv) never breaks: it only shows the numbers, for damage testing,
## and slides back to its post after a knock.

const RUNES := preload("res://scripts/runes.gd")
const EL := preload("res://scripts/elements.gd")
const DEF_EL := ["phys"]

var tex: Texture2D = preload("res://assets/props/dummy.png")
var arena
var kind := "dummy"
var elite := false
var M := {"atkEl": "phys", "defEl": DEF_EL}   # what other code reads off a foe (element tag, fly test)
var hp := 60.0
var max_hp := 60.0
var dead := 0.0                # ms since it broke (0 = standing)
var flash := 0.0
var kx := 0.0
var wob := 0.0
var inv := false               # the unbreakable row
var base_x := 0.0
var dir := 1
var bar_st := {}

func _ready() -> void:
	base_x = position.x
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hp = float(RUNES.ENEMY["dummy"]["hp"])
	max_hp = hp

func alive() -> bool:
	return dead <= 0.0

func is_dead() -> bool:
	return dead > 0.0

## back on its feet (entering the training ground)
func reset() -> void:
	dead = 0.0
	hp = max_hp
	flash = 0.0
	kx = 0.0
	wob = 0.0
	position.x = base_x
	bar_st = {}

func hit(dmg: float, kb: float, mul := 1.0) -> void:
	if dead > 0.0:
		return
	var R = arena.get("runes")
	if R != null: mul *= R.out_mul(self)
	var p := position + Vector2(0, -95)
	var d: float = arena.elem_hit(p, dmg * 10.0 * mul, DEF_EL)
	flash = 120.0
	kx = kb * 0.6
	wob = 1.0
	if inv:
		arena.last_e = {}
		arena.text(p, "-%d" % roundi(d), Color("#ffe9a8"))     # the unbreakable row: a plain number, no element split
		return
	arena.damage_text(p, roundi(d), dmg > 1.0)
	hp -= d
	arena.spark(position + Vector2(-signf(kb) * 10.0, -60), 14 if dmg > 1 else 8)
	if arena.get("pfx") != null: arena.pfx.hit(position.x - signf(kb) * 10.0, position.y - 60.0, 1 if kb >= 0.0 else -1, 1.25 if dmg >= 2 else 1.0)
	if R != null: hp -= R.after_hit(self)
	arena.score += roundi(d / 10.0)
	if hp <= 0.0:
		dead = 1.0
		arena.sfx("break", 1.0)
		arena.shake(8, 1 if kb >= 0.0 else -1)
		arena.spark(position + Vector2(0, -40), 20)
		arena.dust(position, 0, true)
		arena.score += 5
		arena.text(position + Vector2(0, -110), "BREAK", Color("#ff6fb0"))
		if R != null: R.on_kill(self)        # 도감, the kill event, the drop
	arena.best = maxi(arena.best, arena.score)

func step(dt: float) -> void:
	if flash > 0.0: flash -= dt
	if wob > 0.0: wob *= pow(0.995, dt)
	if kx != 0.0:
		position.x += kx * dt * 0.12
		kx *= pow(0.985, dt)
		if absf(kx) < 0.05: kx = 0.0
	if inv and kx == 0.0:
		position.x += (base_x - position.x) * minf(1.0, dt / 300.0)
	if dead > 0.0:
		dead += dt
		if dead > 3000.0:
			dead = 0.0
			hp = max_hp
			arena.ring(position + Vector2(0, -30), 18.0)
	queue_redraw()

func _draw() -> void:
	var s := 0.82
	var w := tex.get_width() * s
	var h := tex.get_height() * s
	var sg := -1.0 if kx < 0.0 else 1.0
	var a := 1.0
	var rot := 0.0
	if dead > 0.0:
		rot = 0.9 * minf(1.0, dead / 400.0) * sg
		a = 1.0 - maxf(0.0, (dead - 2200.0) / 800.0)
	else:
		rot = sin(wob * 9.0) * 0.12 * wob * sg
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE)
	# a hit flashes it: the sprite added onto itself at 0.7 (an overbright modulate)
	var k := 1.7 if flash > 0.0 else 1.0
	draw_texture_rect(tex, Rect2(-w / 2.0, -h, w, h), false, Color(k, k, k, a))
	draw_set_transform(Vector2.ZERO)
	if dead <= 0.0 and not inv:
		bar(self, bar_st, 0.0, -108.0, 44.0, hp / max_hp, false)
		EL.draw_tag(self, 0.0, -113.0, DEF_EL)

## H2.mob + ghostOf: a slim slanted bar over a foe's head; the lost part lingers white, the bar flashes white on a hit
static func bar(ci: CanvasItem, st: Dictionary, x: float, y: float, w: float, f: float, elite: bool) -> void:
	f = clampf(f, 0.0, 1.0)
	var now := float(Time.get_ticks_msec())
	var dt: float = clampf(now - st.get("last", now), 0.0, 100.0)
	st["last"] = now
	if not st.has("g") or f > st["g"]: st["g"] = f
	if st.has("lf") and f < st["lf"] - 0.0005:
		st["gw"] = 380.0
		st["hf"] = 90.0
	st["lf"] = f
	if st.get("gw", 0.0) > 0.0: st["gw"] -= dt
	else: st["g"] = maxf(f, st["g"] - dt / 700.0)
	if st.get("hf", 0.0) > 0.0: st["hf"] -= dt
	var g: float = maxf(f, st["g"])
	var h := 5.0
	var sk := 3.0
	var pd := 2.0
	var x0 := x - w / 2.0
	var col := Color.WHITE if st.get("hf", 0.0) > 0.0 else (Color("#c58cff") if elite else Color("#ff3b4e"))
	ci.draw_colored_polygon(_para(x0 - pd, y - pd, w + pd * 2.0, h + pd * 2.0, sk), Color.BLACK)
	var body := _para(x0, y, w, h, sk)
	ci.draw_colored_polygon(body, Color(1, 1, 1, 0.08))
	if g > f: _clip_fill(ci, body, x0 + (w + sk) * f, x0 + (w + sk) * g, y, h, Color.WHITE)
	if f > 0.0: _clip_fill(ci, body, x0, x0 + (w + sk) * f, y, h, col)
	_clip_fill(ci, body, x0, x0 + w + sk, y, maxf(1.0, h * 0.28), Color(1, 1, 1, 0.22))    # bar(): the top sheen strip

static func _para(x: float, y: float, w: float, h: float, sk: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x + sk, y), Vector2(x + w + sk, y), Vector2(x + w, y + h), Vector2(x, y + h)])

static func _clip_fill(ci: CanvasItem, body: PackedVector2Array, xa: float, xb: float, y: float, h: float, c: Color) -> void:
	var r := PackedVector2Array([Vector2(xa, y), Vector2(xb, y), Vector2(xb, y + h), Vector2(xa, y + h)])
	for poly in Geometry2D.intersect_polygons(body, r):
		ci.draw_colored_polygon(poly, c)
