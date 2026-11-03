extends CanvasLayer
## 화면 효과 (prototype POST): a screen pass over the world, under the HUD — bloom (빛 번짐), shockwave rings, chromatic
## aberration on hits, a soft hit flash at the edges, the vignette, and the perfect-dodge colour grade (drained, pushed cold).
## Bloom as the prototype builds it: a bright pass (bright AND saturated colours only) at a quarter of the screen, blurred,
## then again at a sixteenth, added back as b * 0.9 + b2 * 1.3. Here the quarter-res world is a SubViewport sharing the
## game's World2D (the world canvas only: the HUD never blooms; the pixel effects live on it, so slashes, sparks and Luce's
## light do), and the blur chain is small SubViewports. Refreshed every frame (no stale halo trailing a running sprite).
## The perfect-dodge slow time also draws its overlay here (drawWitchTint: vignette, drifting streaks, the sweeping ring,
## the frame) under the pass, and the heroine on top of the grade (drawWitchHero), so she keeps her colours.
## 타격감 lives here too (impact / punch / ca_pulse / zoom_punch / kick / invert / hurt, FEEL by weight): the punch
## distortion at the hit point, the chromatic pulse, the zoom punch and the camera kick, the parry's negative frame,
## the hurt vignette with its low-HP pulse, the death desaturation — shader uniforms animated on real time.
## Off (arena.screen_fx false): nothing is drawn, the feel is inert and the dodge falls back to the plain blue tint.

const CH := preload("res://scripts/chars.gd")
const WAVE_SH := """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform sampler2D b : filter_linear;
uniform sampler2D b2 : filter_linear;
uniform float bl = 1.0;
uniform float ca = 0.0;
uniform float hit = 0.0;
uniform float wd = 0.0;
uniform vec4 w[4];
uniform vec4 pn[4];
uniform float neg = 0.0;
uniform float hv = 0.0;
uniform float ds = 0.0;
uniform vec2 asp = vec2(1.8, 1.0);
void fragment() {
	vec2 u = SCREEN_UV;
	// 타격감: the punch — a ring of displacement racing out from the hit point (radius 0.12 of the screen height),
	// the picture shoved outward then let back (pn: xy centre, z phase 0..1, w strength)
	for (int i = 0; i < 4; i++) {
		vec4 q = pn[i];
		if (q.w <= 0.0) continue;
		vec2 dd = (u - q.xy) * asp;
		float r = length(dd);
		float band = exp(-pow((r - 0.12 * q.z) / 0.05, 2.0));
		u -= normalize(dd + 1e-5) / asp * band * 0.035 * q.w * sin(q.z * 3.14159);
	}
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
	vec3 bloom = texture(b, u).rgb * 0.9 + texture(b2, u).rgb * 1.3;
	col += bloom * bl;
	col = (col - 0.5) * 1.03 + 0.5;
	col += vec3(1.0, 0.85, 0.95) * hit * 0.18 * (1.0 - vg0);
	col *= mix(0.72, 1.0, vg0);
	// the hurt vignette: red bleeding in from the edges
	float edge = smoothstep(0.42, 0.98, length(dir * vec2(1.05, 1.2)) * 1.3);
	col = mix(col, vec3(0.78, 0.04, 0.08), hv * edge);
	// death: the colour drains; the parry: one frame in the negative
	col = mix(col, vec3(dot(col, vec3(0.299, 0.587, 0.114))), ds);
	col = mix(col, vec3(1.0) - col, neg);
	COLOR = vec4(col, 1.0);
}
"""
## FS_BRIGHT + FS_BLUR of the prototype: one 5-tap gaussian along d; `bright` runs the bright pass on every tap first
const BLUR_SH := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D t : filter_linear;
uniform vec2 d;
uniform bool bright = false;
vec3 tap(vec2 uv) {
	vec3 c = texture(t, uv).rgb;
	if (bright) {
		float m = max(c.r, max(c.g, c.b));
		float s = m - min(c.r, min(c.g, c.b));
		float k = smoothstep(0.84, 1.0, m) * smoothstep(0.25, 0.55, s);
		k = k * k * 1.4;
		c *= k;
	}
	return c;
}
void fragment() {
	vec3 a = tap(UV);
	if (d != vec2(0.0)) {
		a *= 0.227;
		a += (tap(UV + d * 1.38) + tap(UV - d * 1.38)) * 0.316;
		a += (tap(UV + d * 3.23) + tap(UV - d * 3.23)) * 0.070;
	}
	COLOR = vec4(a, 1.0);
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
const WT_SH := """
shader_type canvas_item;
render_mode unshaded;
uniform float k = 0.0;
void fragment() {
	// the slow-time vignette: rgba(10,18,50,0) at 0.3 h -> rgba(10,18,50,0.6 k) at 0.6 w
	vec2 p = (UV - 0.5) / vec2(1.0, 1.0);
	float r = length((UV - 0.5) * vec2(1.8, 1.0));
	float g = clamp((r - 0.3) / (1.08 - 0.3), 0.0, 1.0);
	COLOR = vec4(10.0 / 255.0, 18.0 / 255.0, 50.0 / 255.0, 0.6 * k * g);
}
"""

var arena
var ca := 0.0
var hit := 0.0
var wd := 0.0
var waves: Array = []          # {x, y (world), t, life, str, rad}
# 타격감 (the hit feel): every impact answers on the screen, scaled by its weight; all of it gated by 화면 효과
const PUNCH_MS := 90.0
const PUNCH_R := 0.12
var punches: Array = []        # {x, y (world), t, str}: the ring distortions, at most 4 live, the oldest dropped
var punch_due: Array = []      # {x, y, str, at}: punches still to fire (the boss's three in sequence)
var cap := 0.0                 # the chromatic pulse's peak ...
var cap_t := 0.0               # ... its age (ms) ...
var cap_ms := 0.0              # ... and its length; cap_now() decays it to 0
var zoom_peak := 1.0           # the zoom punch: 1 -> peak over ZOOM_IN, back to 1 over ZOOM_OUT
var zoom_t := -1.0             # ms since it started; -1 = idle
const ZOOM_IN := 40.0
const ZOOM_OUT := 180.0
var kick_v := Vector2.ZERO     # the camera kick: a nudge in the hit direction ...
var kick_t := -1.0             # ... easing back over KICK_MS
const KICK_MS := 120.0
var neg_frames := 0            # frames left in the negative (the parry's one)
var hv_a := 0.0                # the hurt vignette's flash alpha ...
var hv_t := 0.0                # ... and its age
const HV_MS := 220.0
var pulse_t := 0.0             # the low-HP pulse's own clock when no music clock is live (0.65 s a cycle)
const PULSE_MS := 650.0
var ds := 0.0                  # the death desaturation 0..1 (1.2 s up; reset the moment she is not dying)
const DS_MS := 1200.0
# the weights: hitstop ms, punch strength, chromatic pulse (peak, ms), zoom peak, camera kick px
const FEEL := {
	"light": {"stop": 40.0, "punch": 0.35, "ca": 0.0, "ca_ms": 0.0, "zoom": 1.0, "kick": 4.0},
	"hit3": {"stop": 90.0, "punch": 0.6, "ca": 0.012, "ca_ms": 60.0, "zoom": 1.0, "kick": 4.0},
	"heavy": {"stop": 120.0, "punch": 1.0, "ca": 0.03, "ca_ms": 110.0, "zoom": 1.025, "kick": 4.0},
	"parry": {"stop": 140.0, "punch": 1.0, "ca": 0.03, "ca_ms": 110.0, "zoom": 1.025, "kick": 4.0},
	"ult": {"stop": 160.0, "punch": 1.0, "ca": 0.05, "ca_ms": 160.0, "zoom": 1.04, "kick": 4.0},
	"hurt": {"stop": 0.0, "punch": 0.0, "ca": 0.02, "ca_ms": 80.0, "zoom": 1.0, "kick": 4.0},
	"boss": {"stop": 0.0, "punch": 1.0, "ca": 0.03, "ca_ms": 600.0, "zoom": 1.025, "kick": 0.0},
}
var pass_rect: ColorRect
var vig: ColorRect
var mat: ShaderMaterial
var witch_over: Control        # drawWitchTint
var witch_vig: ColorRect
var hero: Node2D               # drawWitchHero
var bsv: Array = []            # [world full-res, bright 1/4, h, v (b), h 1/16, h, v (b2)]
var fr := 0
var bq := Vector2i.ZERO
var bpx := Vector2i.ZERO       # the screen in device pixels the chain was built for


func _ready() -> void:
	layer = 1
	witch_over = Control.new()
	witch_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	witch_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	witch_over.draw.connect(_draw_witch)
	add_child(witch_over)
	witch_vig = ColorRect.new()
	witch_vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	witch_vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wm := ShaderMaterial.new()
	var ws := Shader.new()
	ws.code = WT_SH
	wm.shader = ws
	witch_vig.material = wm
	witch_over.add_child(witch_vig)
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
	hero = Node2D.new()
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	hero.draw.connect(_draw_hero)
	add_child(hero)
	call_deferred("_bloom_setup")

## the bloom chain as the prototype's POST builds it: the 2D canvas at full device resolution is the source (a LINEAR
## texture); the bright pass renders it into a buffer a quarter of that size, so every quarter-res texel is a bilinear tap
## of the full-res image (small bright pixels and the dot-filtered sprites are averaged, never point-sampled), then one
## 5-tap blur across and one down (b); from b a sixteenth-size level blurred once more (b2). Here the full-res world is
## a SubViewport sharing the game's World2D (the world canvas only: the HUD never blooms); on phones it renders at half
## the device resolution. Every texture in the chain is sampled linear.
func _dev_px() -> Vector2i:
	var vp := get_viewport()
	var base: Vector2 = vp.get_visible_rect().size
	var k: float = vp.get_final_transform().x.length()
	return Vector2i(maxi(4, roundi(base.x * k)), maxi(4, roundi(base.y * k)))

func _bloom_setup() -> void:
	for sv in bsv: sv.queue_free()
	bsv.clear()
	_bg_att.clear()
	bpx = _dev_px()
	var src := bpx / 2 if arena != null and arena.get("low_end") else bpx
	bq = Vector2i(maxi(1, bpx.x >> 2), maxi(1, bpx.y >> 2))
	var cq := Vector2i(maxi(1, bq.x >> 2), maxi(1, bq.y >> 2))
	var bsh := Shader.new()
	bsh.code = BLUR_SH
	var prev: SubViewport = null
	var sizes := [src, bq, bq, bq, cq, cq, cq]
	var dirs := [Vector2.ZERO, Vector2.ZERO, Vector2(1.0 / bq.x, 0), Vector2(0, 1.0 / bq.y), Vector2(1.0 / bq.x, 0), Vector2(1.6 / cq.x, 0), Vector2(0, 1.6 / cq.y)]
	for i in 7:
		var sv := SubViewport.new()
		sv.size = sizes[i]
		sv.disable_3d = true
		sv.transparent_bg = false
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		if i == 0:
			sv.world_2d = get_viewport().world_2d
			sv.canvas_cull_mask = 0xFFFFFFFF
		else:
			var tr := ColorRect.new()
			tr.size = Vector2(sizes[i])
			var m := ShaderMaterial.new()
			m.shader = bsh
			m.set_shader_parameter("t", prev.get_texture())
			m.set_shader_parameter("d", dirs[i])
			# the bright pass reads the full-res source; its first tap is the bilinear sample at the texel centre
			m.set_shader_parameter("bright", i == 1)
			tr.material = m
			sv.add_child(tr)
		add_child(sv)
		bsv.append(sv)
		prev = sv
	mat.set_shader_parameter("b", bsv[3].get_texture())
	mat.set_shader_parameter("b2", bsv[6].get_texture())

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

# ---------- 타격감 ----------
## the punch: a ring distortion at a world point, 90 ms, at most four live (the oldest gives way)
func punch(p: Vector2, strength := 1.0) -> void:
	if not on(): return
	punches.append({"x": p.x, "y": p.y, "t": 0.0, "str": strength})
	while punches.size() > 4: punches.pop_front()

## punches to come: the boss goes down to three, spread over `span` ms
func punch_seq(p: Vector2, n: int, span: float, strength := 1.0) -> void:
	if not on(): return
	for i in n:
		var at: float = span * i / maxf(1.0, n - 1)
		if at <= 0.0: punch(p, strength)
		else: punch_due.append({"x": p.x, "y": p.y, "str": strength, "at": at})

## the chromatic pulse: `v` at once, decaying to nothing over `ms` (on top of the slow aberr fringes)
func ca_pulse(v: float, ms: float) -> void:
	if not on() or v <= 0.0 or ms <= 0.0: return
	if v >= cap_now():
		cap = v
		cap_t = 0.0
		cap_ms = ms

func cap_now() -> float:
	if cap_ms <= 0.0 or cap_t >= cap_ms: return 0.0
	var k: float = 1.0 - cap_t / cap_ms
	return cap * k * k

## the zoom punch: 1.0 -> peak over 40 ms, back over 180 ms
func zoom_punch(peak: float) -> void:
	if not on() or peak <= 1.0: return
	if zoom_t < 0.0 or peak >= zoom_peak:
		zoom_peak = peak
		zoom_t = 0.0

func zoom_now() -> float:
	if zoom_t < 0.0: return 1.0
	if zoom_t < ZOOM_IN: return lerpf(1.0, zoom_peak, zoom_t / ZOOM_IN)
	var k: float = (zoom_t - ZOOM_IN) / ZOOM_OUT
	if k >= 1.0: return 1.0
	return lerpf(zoom_peak, 1.0, 1.0 - (1.0 - k) * (1.0 - k))

## the camera kick: a nudge of `px` in direction d, easing back over 120 ms (on top of the shake)
func kick(d: Vector2, px: float) -> void:
	if not on() or px <= 0.0 or d == Vector2.ZERO: return
	kick_v = d.normalized() * px
	kick_t = 0.0

func kick_off() -> Vector2:
	if kick_t < 0.0: return Vector2.ZERO
	var k: float = kick_t / KICK_MS
	if k >= 1.0: return Vector2.ZERO
	return kick_v * (1.0 - k) * (1.0 - k)

## one frame in the negative: the parry's "합 승리"
func invert() -> void:
	if not on(): return
	neg_frames = 1

## the hurt vignette: red at the edges at alpha `a`, fading over 220 ms
func hurt(a := 0.35) -> void:
	if not on(): return
	hv_a = maxf(hurt_fade(), a)
	hv_t = 0.0

func hurt_fade() -> float:
	if hv_t >= HV_MS: return 0.0
	return hv_a * (1.0 - hv_t / HV_MS)

## true while the low-HP pulse should breathe: in the dungeon, alive, under 30 %
func low_hp() -> bool:
	var P = arena.player
	if P == null or arena.level_kind() != "dungeon": return false
	return P.hp > 0.0 and P.hp < P.MAX_HP * 0.3

## 0..1 of the pulse: the music's pulse when a clock is live, else a 0.65 s cycle of its own
func pulse_phase() -> float:
	var B = arena.get("bgm")
	var c = B.clock() if B != null else null
	if c != null and c.live: return c.pulse_phase()
	return fposmod(pulse_t / PULSE_MS, 1.0)

## the vignette alpha this frame: the hit's flash, or the soft low-HP pulse, whichever is stronger
func hurt_a() -> float:
	if not on(): return 0.0
	var a := hurt_fade()
	if low_hp():
		a = maxf(a, 0.1 + 0.12 * (0.5 - 0.5 * cos(pulse_phase() * TAU)))
	return a

## the whole impact at a world point: hitstop by weight, the punch, the chromatic pulse, the zoom punch, the kick
func impact(kind: String, p: Vector2, d: int) -> void:
	if not on() or not FEEL.has(kind): return
	var F: Dictionary = FEEL[kind]
	if F["stop"] > 0.0: arena.hitstop = maxf(arena.hitstop, F["stop"])
	if kind == "boss":
		punch_seq(p, 3, 500.0, F["punch"])
	elif kind != "hurt" and F["punch"] > 0.0:
		punch(p, F["punch"])
	ca_pulse(F["ca"], F["ca_ms"])
	zoom_punch(F["zoom"])
	if F["kick"] > 0.0: kick(Vector2(d, 0), F["kick"])
	match kind:
		"parry":
			invert()
			arena.spark_ring(p, 12)
		"ult":
			arena.shake(10, d)
		"hurt":
			hurt(0.35)
			arena.shake(3, d)

func feel_reset() -> void:
	punches.clear()
	punch_due.clear()
	cap = 0.0
	cap_ms = 0.0
	zoom_t = -1.0
	zoom_peak = 1.0
	kick_t = -1.0
	neg_frames = 0
	hv_a = 0.0
	hv_t = HV_MS
	ds = 0.0
	if arena.cam != null and arena.cam.zoom != Vector2.ONE: arena.cam.zoom = Vector2.ONE

## the feel's clocks, real time (they run through a hitstop: the freeze is theirs to fill)
func feel_step(dt: float) -> void:
	for q in punches: q["t"] += dt
	punches = punches.filter(func(q): return q["t"] < PUNCH_MS)
	if not punch_due.is_empty():
		var fire: Array = []
		for q in punch_due:
			q["at"] -= dt
			if q["at"] <= 0.0: fire.append(q)
		for q in fire:
			punch_due.erase(q)
			punch(Vector2(q["x"], q["y"]), q["str"])
	cap_t += dt
	if zoom_t >= 0.0:
		zoom_t += dt
		if zoom_t >= ZOOM_IN + ZOOM_OUT: zoom_t = -1.0
	if kick_t >= 0.0:
		kick_t += dt
		if kick_t >= KICK_MS: kick_t = -1.0
	hv_t += dt
	pulse_t += dt
	var P = arena.player
	var dying: bool = P != null and P.anim == "death" and P.hp <= 0.0
	ds = minf(1.0, ds + dt / DS_MS) if dying else 0.0
	var z := zoom_now()
	if arena.cam != null: arena.cam.zoom = Vector2(z, z)

func _bloom_step(run: bool) -> void:
	if bsv.is_empty(): return
	if run and _dev_px() != bpx: _bloom_setup()
	fr += 1
	# every frame. The prototype refreshes every other frame and lives with a one-frame-stale halo; here a stale halo
	# shows as a trail of pink copies behind her bright hair while she runs (the camera follows her, the world doesn't),
	# and pinning it to the world only moves the trail onto her. Fresh each frame, nothing can trail.
	var go := run
	for sv in bsv:
		sv.render_target_update_mode = SubViewport.UPDATE_ONCE if go else SubViewport.UPDATE_DISABLED
	if go and not _pre_hooked:
		_pre_hooked = true
		RenderingServer.frame_pre_draw.connect(_bloom_xf, CONNECT_ONE_SHOT)

## the source's camera is copied just before drawing, after every node (and the Camera2D) has moved this frame, so the
## halo sits exactly on what the screen shows
var _pre_hooked := false
func _bloom_xf() -> void:
	_pre_hooked = false
	if bsv.is_empty() or not is_inside_tree(): return
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var base: Vector2 = get_viewport().get_visible_rect().size
	bsv[0].canvas_transform = Transform2D.IDENTITY.scaled(Vector2(bsv[0].size) / base) * xf
	_bloom_bg(Transform2D.IDENTITY.scaled(Vector2(bsv[0].size) / base))

## the prototype's bloom reads the whole canvas, sky and mountains included: attach the background CanvasLayers
## (layer < 0) to the source viewport too, so bright, thin things (the damage numbers, sparks) average against the
## sky in the quarter-res bright pass as they do there, instead of against black
var _bg_att := {}              # canvas RID -> its CanvasLayer
func _bloom_bg(sc: Transform2D) -> void:
	var vp: RID = bsv[0].get_viewport_rid()
	var want := {}
	for c in arena.get_children():
		if c is CanvasLayer and c.layer < 0 and c.visible: want[c.get_canvas()] = c
	for rid in _bg_att.keys():
		if not want.has(rid):
			if is_instance_valid(_bg_att[rid]): RenderingServer.viewport_remove_canvas(vp, rid)
			_bg_att.erase(rid)
	for rid in want:
		var L: CanvasLayer = want[rid]
		if not _bg_att.has(rid):
			RenderingServer.viewport_attach_canvas(vp, rid)
			_bg_att[rid] = L
		RenderingServer.viewport_set_canvas_stacking(vp, rid, L.layer, 0)
		RenderingServer.viewport_set_canvas_transform(vp, rid, sc * L.transform)

func _process(delta: float) -> void:
	var dt := minf(delta * 1000.0, 100.0)
	var o := on()
	visible = o
	if not o:
		waves.clear()
		ca = 0.0
		hit = 0.0
		feel_reset()
		_bloom_step(false)
		return
	# the world under the title, a menu or a full-screen page stays plain
	var cover: bool = arena.ui_root != null and arena.ui_root.holds()
	feel_step(dt)
	hit *= pow(0.985, dt)
	ca *= pow(0.992, dt)
	wd = 0.0
	if arena.witch > 0.0:
		wd = minf(1.0, arena.witch / 300.0) * minf(1.0, (arena.witch_max - arena.witch) / 90.0 + 0.15)
	for q in waves: q["t"] += dt
	waves = waves.filter(func(q): return q["t"] < q["life"])
	# bloom runs all the time, so the pass always reads the screen (it carries the vignette too)
	pass_rect.visible = not cover
	vig.visible = false
	_bloom_step(not cover)
	witch_over.visible = arena.witch > 0.0 and not cover
	hero.visible = witch_over.visible
	if witch_over.visible:
		(witch_vig.material as ShaderMaterial).set_shader_parameter("k", _wk())
		witch_over.queue_redraw()
		hero.queue_redraw()
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
	var pa := PackedVector4Array()
	pa.resize(4)
	for i in punches.size():
		var q: Dictionary = punches[i]
		var sp: Vector2 = xf * Vector2(q["x"], q["y"])
		pa[i] = Vector4(sp.x / vs.x, sp.y / vs.y, q["t"] / PUNCH_MS, q["str"])
	mat.set_shader_parameter("pn", pa)
	mat.set_shader_parameter("ca", minf(0.06, ca + cap_now()))
	mat.set_shader_parameter("hit", minf(1.0, hit))
	mat.set_shader_parameter("wd", wd)
	mat.set_shader_parameter("neg", 1.0 if neg_frames > 0 else 0.0)
	if neg_frames > 0: neg_frames -= 1
	mat.set_shader_parameter("hv", hurt_a())
	mat.set_shader_parameter("ds", ds)
	mat.set_shader_parameter("asp", Vector2(vs.x / vs.y, 1.0))

func _wk() -> float:
	var el: float = arena.witch_max - arena.witch
	return minf(1.0, arena.witch / 300.0) * minf(1.0, el / 90.0 + 0.15)

## drawWitchTint (without the grade, which is the pass's): streaks drifting across, the ring sweeping out, a thin frame
func _draw_witch() -> void:
	var c := witch_over
	var vs := c.size
	var k := _wk()
	var el: float = arena.witch_max - arena.witch
	var t := Time.get_ticks_msec() / 1000.0
	var cw := vs.x
	var ch := vs.y
	for i in 9:
		var y := fmod(fmod(i * 131.7, 1.0) * ch + fmod(i * 97.0, ch), ch)
		var x := fmod(t * 60.0 * (0.4 + (i % 3) * 0.3) + i * 331.0, cw + 600.0) - 300.0
		var Ll := 120.0 + (i % 4) * 90.0
		var cols := PackedColorArray([Color8(160, 220, 255, 0), Color(160 / 255.0, 220 / 255.0, 1.0, 0.13 * k), Color(160 / 255.0, 220 / 255.0, 1.0, 0.13 * k), Color8(160, 220, 255, 0)])
		var half := Ll / 2.0
		c.draw_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + half, y), Vector2(x + half, y + 1.5), Vector2(x, y + 1.5)]), PackedColorArray([cols[0], cols[1], cols[1], cols[0]]))
		c.draw_polygon(PackedVector2Array([Vector2(x + half, y), Vector2(x + Ll, y), Vector2(x + Ll, y + 1.5), Vector2(x + half, y + 1.5)]), PackedColorArray([cols[1], cols[0], cols[0], cols[1]]))
	if el < 420.0:
		var u := el / 420.0
		var R := u * cw * 0.9
		c.draw_arc(Vector2(cw * 0.5, ch * 0.55), R, 0, TAU, 96, Color(190 / 255.0, 240 / 255.0, 1.0, 0.55 * (1.0 - u)), 6.0 * (1.0 - u) + 1.0)
		c.draw_arc(Vector2(cw * 0.5, ch * 0.55), R * 0.86, 0, TAU, 96, Color(150 / 255.0, 120 / 255.0, 1.0, 0.35 * (1.0 - u)), 2.0)
	c.draw_rect(Rect2(14, 14, cw - 28, ch - 28), Color(170 / 255.0, 230 / 255.0, 1.0, 0.25 * k), false, 2.0)

## drawWitchHero: she is drawn again over the graded world, at 0.85 k
func _draw_hero() -> void:
	var P = arena.player
	if P == null or arena.level_kind() != "dungeon": return
	var k := minf(1.0, arena.witch / 300.0)
	hero.material = P.material
	var xf: Transform2D = get_viewport().get_canvas_transform()
	var an: String = P.anim
	var variant := ""
	if an == "tp_in" or an == "dig_out":
		variant = "_air" if P.dig_air else ("_q" if P.rift_q else "")
	var col := Color(1, 1, 1, 0.85 * k)
	var rf: Array = P.SK.resolve(P.who, an, P.f, variant)
	var row: int = rf[0]
	var sheet: Texture2D = P.SK.sheet_row(P.who, row)
	var src := Rect2(rf[1] * CH.CELL_W, (row % CH.ROWS_PER_SHEET) * CH.CELL_H, CH.CELL_W, CH.CELL_H)
	var sc: float = CH.SCALE[P.who] * (CH.ROWFIX_AIDA.get(row, 1.0) if P.who == "aida" else 1.0)
	var w: float = P.CW * sc
	var h: float = P.CHH * sc
	hero.draw_set_transform_matrix(xf * Transform2D(0.0, P.position + Vector2(P.gdx, 0)) * Transform2D(0.0, Vector2(P.dir, 1), 0.0, Vector2.ZERO))
	hero.draw_texture_rect_region(sheet, Rect2(-w / 2.0, -P.BASE * sc, w, h), src, col)
	hero.draw_set_transform(Vector2.ZERO)
