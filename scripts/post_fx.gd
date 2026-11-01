extends CanvasLayer
## 화면 효과 (prototype POST): a screen pass over the world, under the HUD — shockwave rings, chromatic aberration on
## hits, a soft hit flash at the edges, the vignette, and the perfect-dodge colour grade (drained, pushed cold).
## Phones: the screen-reading pass only runs while something is happening; the vignette alone is a plain overlay.
## The prototype's bloom is left out (the compatibility renderer has no cheap blurred screen copy).
## Off (arena.screen_fx false): nothing is drawn and the dodge falls back to the plain blue tint.

const WAVE_SH := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float ca = 0.0;
uniform float hit = 0.0;
uniform float wd = 0.0;
uniform vec4 w[4];
uniform vec2 asp = vec2(1.8, 1.0);
void fragment() {
	vec2 u = SCREEN_UV;
	for (int i = 0; i < 4; i++) {
		vec4 q = w[i];
		if (q.w <= 0.0) continue;
		vec2 dd = (u - q.xy) * asp;
		float r = length(dd);
		float band = exp(-pow((r - q.z) / 0.035, 2.0));
		u -= normalize(dd + 1e-5) / asp * band * 0.04 * q.w;
	}
	vec2 dir = u - 0.5;
	float cc = ca * (0.3 + length(dir) * 2.2);
	float vg0 = smoothstep(0.95, 0.35, length(dir * vec2(1.1, 1.25)));
	vec3 col = vec3(texture(scr, u + dir * cc).r, texture(scr, u).g, texture(scr, u - dir * cc).b);
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), 0.62 * wd);
	col *= mix(vec3(1.0), vec3(0.47, 0.63, 0.92), 0.55 * wd);
	col = (col - 0.5) * 1.03 + 0.5;
	col += vec3(1.0, 0.85, 0.95) * hit * 0.18 * (1.0 - vg0);
	COLOR = vec4(col, 1.0);
}
"""
const VIG_SH := """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 dir = UV - 0.5;
	float vg0 = smoothstep(0.95, 0.35, length(dir * vec2(1.1, 1.25)));
	COLOR = vec4(0.0, 0.0, 0.0, 1.0 - mix(0.72, 1.0, vg0));
}
"""

var arena
var ca := 0.0
var hit := 0.0
var wd := 0.0
var waves: Array = []          # {x, y (world), t, life, str, rad}
var pass_rect: ColorRect
var vig: ColorRect
var mat: ShaderMaterial


func _ready() -> void:
	layer = 1
	pass_rect = ColorRect.new()
	pass_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	pass_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = WAVE_SH
	mat.shader = sh
	pass_rect.material = mat
	pass_rect.visible = false
	add_child(pass_rect)
	vig = ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	var vs := Shader.new()
	vs.code = VIG_SH
	vm.shader = vs
	vig.material = vm
	add_child(vig)

func on() -> bool:
	return arena.screen_fx

## postWave: a shockwave ring at a world point
func wave(p: Vector2, strength := 1.0, life := 520.0, rad := 0.35) -> void:
	if not on(): return
	waves.append({"x": p.x, "y": p.y, "t": 0.0, "life": life, "str": strength, "rad": rad})
	if waves.size() > 4: waves.pop_front()

## postCA: colour fringes and a flash at the edges
func aberr(v: float) -> void:
	if not on(): return
	ca = maxf(ca, v * 1.6)
	hit = maxf(hit, minf(1.0, v * 40.0))

## true when the plain tint should stand in for the grade
func grades() -> bool:
	return on()

func _process(delta: float) -> void:
	var dt := minf(delta * 1000.0, 100.0)
	var o := on()
	visible = o
	if not o:
		waves.clear()
		ca = 0.0
		hit = 0.0
		return
	# the world under the title, a menu or a full-screen page stays plain
	var cover: bool = arena.ui_root != null and arena.ui_root.holds()
	vig.visible = not cover
	hit *= pow(0.985, dt)
	ca *= pow(0.992, dt)
	wd = 0.0
	if arena.witch > 0.0:
		wd = minf(1.0, arena.witch / 300.0) * minf(1.0, (arena.witch_max - arena.witch) / 90.0 + 0.15)
	for q in waves: q["t"] += dt
	waves = waves.filter(func(q): return q["t"] < q["life"])
	var busy := ca > 0.0004 or hit > 0.01 or wd > 0.0 or not waves.is_empty()
	pass_rect.visible = busy and not cover
	if not pass_rect.visible: return
	var vs := get_viewport().get_visible_rect().size
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var arr := PackedVector4Array()
	arr.resize(4)
	for i in waves.size():
		var q: Dictionary = waves[i]
		var k: float = q["t"] / q["life"]
		var sp: Vector2 = xf * Vector2(q["x"], q["y"])
		arr[i] = Vector4(sp.x / vs.x, sp.y / vs.y, q["rad"] * pow(k, 0.6), q["str"] * (1.0 - k) * (1.0 - k))
	mat.set_shader_parameter("w", arr)
	mat.set_shader_parameter("ca", minf(0.05, ca))
	mat.set_shader_parameter("hit", minf(1.0, hit))
	mat.set_shader_parameter("wd", wd)
	mat.set_shader_parameter("asp", Vector2(vs.x / vs.y, 1.0))
