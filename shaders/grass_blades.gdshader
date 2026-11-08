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
// the ground's light map (tools/bake_ground_light.py): a blade in a building's shade or a lamp's pool takes the same
// palette move as the ground under it
uniform sampler2D gmap : filter_nearest, repeat_disable;
uniform sampler2D pal_lut : filter_nearest, repeat_disable;
uniform sampler2D pal_fx : filter_nearest, repeat_disable;
uniform vec2 gmap_org = vec2(0.0, -360.0);     // tools/bake_ground_light.py Y0 (up to the hall's windows)
uniform vec2 gmap_cell = vec2(4.0, 2.0);
uniform float lit_on = 0.0;

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
	if (tip && pressed > 0.0) c = vec3(176.0, 195.0, 121.0) / 255.0;   // the tip catches the gust light: the leaf ramp's top step
	if (lit_on > 0.5) {
		ivec3 q = ivec3(clamp(floor(c * 255.0 / 8.0), 0.0, 31.0));
		int idx = int(texelFetch(pal_lut, ivec2(q.r * 32 + q.g, q.b), 0).r * 255.0 + 0.5);
		ivec2 gi = ivec2(floor((vec2(x, base) - gmap_org) / gmap_cell));
		ivec2 gs = textureSize(gmap, 0);
		vec4 L = (gi.x >= 0 && gi.y >= 0 && gi.x < gs.x && gi.y < gs.y) ? texelFetch(gmap, gi, 0) : vec4(0.0);
		int col = 2;
		if (L.b > 0.55) col = 5; else if (L.b > 0.16) col = 4; else if (L.r > 0.55) col = 0; else if (L.r > 0.2) col = 1; else if (L.g > 0.3) col = 3;
		c = texelFetch(pal_fx, ivec2(col, idx), 0).rgb;
	}
	COLOR = vec4(c, 1.0);
}
