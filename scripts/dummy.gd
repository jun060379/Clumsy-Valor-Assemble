extends Node2D
## Training dummy: takes hits, flashes, rocks back. Never breaks (training ground).

var tex: Texture2D = preload("res://assets/props/dummy.png")
var arena
var flash := 0.0
var kx := 0.0
var wob := 0.0
var base_x := 0.0

func _ready() -> void:
	base_x = position.x
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func hit(dmg: int, kb: float) -> void:
	flash = 120.0
	kx = kb * 0.6
	wob = 1.0
	arena.damage_text(position + Vector2(0, -95), dmg, dmg > 1)
	arena.spark(position + Vector2(-signf(kb) * 10.0, -60), 14 if dmg > 1 else 8)

func step(dt: float) -> void:
	if flash > 0.0: flash -= dt
	wob = maxf(0.0, wob - dt / 600.0)
	position.x += kx * dt * 0.06
	kx *= pow(0.985, dt)
	position.x += (base_x - position.x) * minf(1.0, dt / 500.0)
	queue_redraw()

func _draw() -> void:
	var s := 0.82
	var w := tex.get_width() * s
	var h := tex.get_height() * s
	draw_set_transform(Vector2.ZERO, sin(wob * 9.0) * 0.12 * wob * signf(kx if kx != 0.0 else 1.0), Vector2.ONE)
	draw_texture_rect(tex, Rect2(-w / 2.0, -h, w, h), false, Color(2.4, 2.2, 2.3) if flash > 0.0 else Color.WHITE)
	draw_set_transform(Vector2.ZERO)
