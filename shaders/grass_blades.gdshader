// The town's grass blades on the GPU (owner 2026-11-06 "렉": the per-blade GDScript draw was most of the frame).
// town_life.build_blade_meshes bakes every blade once as 4 segment quads at rest; this bends them each frame exactly
// as town_life.draw_blades does on the CPU: wind sway + gust wave, the walking push field, landings.
// Per vertex:  VERTEX = (root x + side * w, base)   UV = (u of this end of the segment, height + r / 2)
//              COLOR.rgb = the segment colour   COLOR.a = (code + 0.5) / 16, code bits: 1 side, 2 wide (w 2 px), 4 tip
shader_type canvas_item;
render_mode blend_mix;

uniform float t = 0.0;            // seconds (town_life.now() / 1000)
uniform float gust = 0.0;
uniform float py = 0.0;           // the player's feet
uniform vec3 land = vec3(0.0, 0.0, 1e9);   // x, y, ms since landing
uniform sampler2D pushtex : filter_nearest, repeat_disable;
uniform float push_n = 1.0;

void vertex() {
	int code = int(COLOR.a * 16.0);
	float side = float(code & 1);
	float w = (code & 2) != 0 ? 2.0 : 1.0;
	bool tip = (code & 4) != 0;
	float x = VERTEX.x - side * w;
	float base = VERTEX.y;
	float u = UV.x;
	float hg = floor(UV.y);
	float r = fract(UV.y) * 2.0;
	float ph = x * 0.021 - t * 1.7 + r * 6.0;
	float sw = sin(ph) + 0.3 * sin(ph * 0.4 + 1.3);
	float g = sin(x * 0.0065 - t * 2.4) * 0.6 + sin(x * 0.017 - t * 3.1 + 2.0) * 0.4;
	float gw = max(0.0, g - 0.35) * (0.6 + gust);
	float bend = (sw * 1.4 + 0.9 + gw * 6.0) * (hg / 14.0);
	float pv = texelFetch(pushtex, ivec2(clamp(int(x / 4.0), 0, int(push_n) - 1), 0), 0).r;
	if (abs(py - base) < 16.0 && abs(pv) > 0.05) {
		bend += sign(pv) * (1.0 - exp(-abs(pv) * 0.9)) * 7.0 * (hg / 14.0);
	}
	if (land.z < 450.0 && abs(x - land.x) < 70.0 && abs(land.y - base) < 20.0) {
		bend += (x >= land.x ? 1.0 : -1.0) * (1.0 - abs(x - land.x) / 70.0) * (1.0 - land.z / 450.0) * 7.0;
	}
	float pressed = gw > 0.25 ? 1.0 : 0.0;
	float h2 = hg - pressed;
	VERTEX = vec2(x + round(bend * u * u * u * 1.5) + side * w, base - round(h2 * u));
	vec3 c = COLOR.rgb;
	if (tip && pressed > 0.0) c = clamp(c * vec3(1.237, 1.176, 1.542), 0.0, 1.0);   // the tip catches the gust light
	COLOR = vec4(c, 1.0);
}
