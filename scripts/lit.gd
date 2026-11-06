extends Node2D
## The prototype's drawLighting composite (estelle-prototype.html 3128-3180), in the world canvas so the bloom sees it:
##   [shade mask x 0.62 (shade.gd, town)] -> ambient multiply -> "pre" (hall windows) -> lights added (lightShape, 'lighter')
##   -> "post" (dawn fog).
## The level fills `L` (light dicts) and `amb` every step and calls redraw(). A light dict:
##   {k: lamp|fire|bulb|win|soft, x, y, gy (floor under it), r, a, c: Color, oy (fire), boost}
## Lights are drawn additively over everything (characters included, as the prototype does); nothing here is a Light2D,
## so no sprite is lit "through" its albedo. Characters keep their rim light from char_pix (rim_lights()).
## All nodes sit at z 9, ahead of the other z-9 items (they are moved to the front of the arena's children).

const STOPS := [[0.0, 1.0], [0.18, 0.62], [0.45, 0.24], [0.75, 0.07], [1.0, 0.0]]
const BULBS := [[0.0655, 29.5], [0.2141, 39.5], [0.3577, 44.5], [0.5013, 47.5], [0.6474, 45.5], [0.7909, 39.5], [0.9370, 29.5]]

static var _blob: Texture2D
static var _soft: Texture2D

var arena
var L: Array = []
var amb := Color.WHITE
var shade: Node2D = null          # shade.gd composite (town only)
var amb_node: Node2D
var pre: Node2D                   # drawn after the ambient, before the lights (pre_fn)
var glow: Node2D
var post: Node2D                  # after the lights (post_fn)
var pre_fn := Callable()
var post_fn := Callable()


## the prototype's blob gradient (stops 1 / .62 / .24 / .07 / 0), white, alpha only
static func blob_tex() -> Texture2D:
	if _blob == null:
		var n := 128
		var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
				var a := 0.0
				if d < 1.0:
					for i in STOPS.size() - 1:
						if d <= STOPS[i + 1][0]:
							var u: float = (d - STOPS[i][0]) / (STOPS[i + 1][0] - STOPS[i][0])
							a = lerpf(STOPS[i][1], STOPS[i + 1][1], u)
							break
				im.set_pixel(x, y, Color(1, 1, 1, a))
		_blob = ImageTexture.create_from_image(im)
	return _blob

## a plain linear radial falloff (fog banks, the moon's glow)
static func soft_tex() -> Texture2D:
	if _soft == null:
		var n := 64
		var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in n:
			for x in n:
				var d := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0).length() / (n / 2.0)
				im.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - (d - 0.03) / 0.97, 0.0, 1.0)))
		_soft = ImageTexture.create_from_image(im)
	return _soft

## the flicker every flame shares: fl(k)
static func fl(t: float, k: float) -> float:
	return 0.85 + 0.1 * sin(t * 7.0 + k) + 0.05 * sin(t * 19.0 + k * 3.0)

## The one sun every light and shadow in the town follows (owner 2026-11-07: "빛과 그림자 이론을 기반 삼아서"): the
## direction TOWARD the sun, x right, y up, z toward the viewer. It rises on the left (the sprite bakes' "_m" light,
## tools/light_proxy.py) and sets on the right ("_e"), always a little on the viewer's side of the town so the fronts take
## the sun (docs/work/town-art/LIGHT.md), low at both ends of the day, high at noon. tools/light_proxy.py sun3 = this.
static func sun3(h: float) -> Vector3:
	var hh := fposmod(h, 24.0)
	var day := clampf((hh - 5.5) / 13.5, 0.0, 1.0)
	var ang := day * PI
	var el := deg_to_rad(16.0 + 46.0 * sin(ang))
	var hz := Vector2(-cos(ang), 0.45 + 0.25 * sin(ang)).normalized()
	return Vector3(hz.x * cos(el), sin(el), hz.y * cos(el))

## the shadow's way down a standing surface: screen x per px of drop (away from the sun), y = 1
## (this used to point the other way: shadows fell left in the morning while the sprites were lit from the left)
static func sun_dir(h: float) -> Vector2:
	var v := sun3(h)
	return Vector2(clampf(-v.x / v.y, -2.6, 2.6), 1.0)

## lightShape: one shaped light. `cut` draws it for the shade mask (the cut material reads alpha only).
static func shape(ci: CanvasItem, l: Dictionary, mul: float) -> void:
	var A: float = l["a"] * mul
	if A <= 0.003: return
	var c: Color = l["c"]
	var x: float = l["x"]
	var y: float = l["y"]
	var r: float = l["r"]
	match l["k"]:
		"lamp":
			_blob_at(ci, x, y, r * 0.42, r * 0.38, c, A * 0.9)
			var gy: float = l["gy"]
			var top := y + 6.0
			var hgt := maxf(10.0, gy - top)
			ci.draw_polygon(PackedVector2Array([Vector2(x - 8.0, top), Vector2(x + 8.0, top), Vector2(x + hgt * 0.42, gy), Vector2(x - hgt * 0.42, gy)]),
				PackedColorArray([Color(c, A * 0.30), Color(c, A * 0.30), Color(c, A * 0.06), Color(c, A * 0.06)]))
			_blob_at(ci, x, gy - 2.0, hgt * 0.55, 14.0, c, A * 0.45)
		"fire":
			_blob_at(ci, x, y - l.get("oy", 6.0), r * 0.75, r * 0.62, c, A * 0.75)
			_blob_at(ci, x, l["gy"] - 2.0, r * 0.8, 16.0, c, A * 0.35)
		"win": _blob_at(ci, x, y, r * 0.5, r * 0.6, c, A * 0.7)
		"bulb": _blob_at(ci, x, y, r * 0.6, r * 0.55, c, A * 0.8)
		_: _blob_at(ci, x, y, r, r * 0.8, c, A * 0.6)

static func _blob_at(ci: CanvasItem, x: float, y: float, rx: float, ry: float, c: Color, a: float) -> void:
	ci.draw_texture_rect(blob_tex(), Rect2(x - rx, y - ry, rx * 2.0, ry * 2.0), false, Color(c, a))

## how far a light's shape reaches (for culling)
static func reach(l: Dictionary) -> float:
	var r: float = l["r"]
	if l["k"] == "lamp": return maxf(r * 0.42, (l["gy"] - l["y"]) * 0.55)
	if l["k"] == "fire": return r * 0.8
	return r


func _init(a) -> void:
	arena = a
	z_index = 9
	amb_node = _sub(CanvasItemMaterial.BLEND_MODE_MUL, _draw_amb)
	pre = _sub(-1, func(): if pre_fn.is_valid(): pre_fn.call(pre))
	glow = _sub(CanvasItemMaterial.BLEND_MODE_ADD, _draw_glow)
	post = _sub(-1, func(): if post_fn.is_valid(): post_fn.call(post))

func attach() -> void:
	arena.add_child(self)
	arena.move_child(self, 0)

func _sub(blend: int, fn: Callable) -> Node2D:
	var n := Node2D.new()
	n.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if blend >= 0:
		var m := CanvasItemMaterial.new()
		m.blend_mode = blend
		n.material = m
	n.draw.connect(fn)
	add_child(n)
	return n

## the shade composite goes first (before the ambient)
func set_shade(s: Node2D) -> void:
	shade = s
	add_child(s)
	move_child(s, 0)

func redraw() -> void:
	amb_node.queue_redraw()
	pre.queue_redraw()
	glow.queue_redraw()
	post.queue_redraw()
	if shade != null: shade.redraw()

func _draw_amb() -> void:
	if amb.r > 0.995 and amb.g > 0.995 and amb.b > 0.995: return
	amb_node.draw_rect(arena.view_rect().grow(40.0), Color(amb.r, amb.g, amb.b, 1.0))

func in_view(l: Dictionary, vr: Rect2) -> bool:
	var R := reach(l)
	return l["x"] + R > vr.position.x and l["x"] - R < vr.end.x and l.get("gy", l["y"]) + R > vr.position.y and l["y"] - R < vr.end.y

## direct light: warm pools you can see (and the bloom picks up); lamps and bulbs get a hot 3x3 pixel
func _draw_glow() -> void:
	var vr: Rect2 = arena.view_rect()
	for l in L:
		if l["k"] == "win" or not in_view(l, vr): continue
		var b: float = l.get("boost", 1.0)
		shape(glow, l, 1.15 * b)
		if l["k"] == "lamp" or l["k"] == "bulb":
			glow.draw_rect(Rect2(roundf(l["x"]) - 1.0, roundf(l["y"]) - 1.0, 3.0, 3.0), Color(1.0, 250.0 / 255.0, 230.0 / 255.0, 0.8 * l["a"] * b))

## the rim lights for the character shader (pfx.gd _pix_frame): [pos, r, strength, colour]
## (rimLights: the town scales them by night, `k` = 0.12 + 0.88 nightK)
func rim_lights(k := 1.0) -> Array:
	var out: Array = []
	for l in L:
		out.append([Vector2(l["x"], l["y"]), l["r"], minf(1.2, l["a"] * k), l["c"]])
	return out

func cleanup() -> void:
	queue_free()
