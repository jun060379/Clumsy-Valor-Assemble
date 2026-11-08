// lit.gd's ambient multiply (the night's dark over the whole screen), eased where the lamps and fires reach so the
// light the sprites, tiles and people carry themselves shows (tools/bake_ground_light.py: ground_n blue, traced past
// the pixel3d outlines). In two hard steps on the 2-px grid, never a soft gradient (owner 2026-11-08).
shader_type canvas_item;
render_mode blend_mul;
uniform sampler2D gmap : filter_nearest, repeat_disable;
uniform vec2 gmap_org = vec2(0.0, 120.0);
uniform vec2 gmap_cell = vec2(2.0, 2.0);
uniform float lift = 0.0;
uniform vec3 warm = vec3(1.0, 0.86, 0.64);
// the stars (sky.gd STAR) are drawn in three exact marker colours: where one still shows on screen (nothing in front
// of it) the night's dark leaves it alone, so the stars stay crisp (owner 2026-11-08: "반짝반짝 선명해지기도하고")
uniform sampler2D scr : hint_screen_texture, filter_nearest;
const vec3 STAR0 = vec3(150.0, 156.0, 196.0) / 255.0;
const vec3 STAR1 = vec3(205.0, 208.0, 226.0) / 255.0;
const vec3 STAR2 = vec3(255.0, 250.0, 236.0) / 255.0;
// the fire's own colours (pixelfx town fire ramp and the forge hearth's lit back wall, tools/pixelfx_fx/
// town-forge-hearth.js; none of them is in the town palette, white left out): fire is its own light, the night's dark
// leaves it alone (owner 2026-11-08, the forge hearth)
const vec3 FIRE[11] = vec3[](vec3(74.0, 23.0, 18.0), vec3(138.0, 31.0, 23.0), vec3(201.0, 40.0, 31.0), vec3(242.0, 86.0, 29.0),
	vec3(255.0, 138.0, 42.0), vec3(255.0, 194.0, 61.0), vec3(255.0, 226.0, 107.0), vec3(255.0, 243.0, 166.0),
	vec3(86.0, 26.0, 20.0), vec3(127.0, 38.0, 23.0), vec3(168.0, 56.0, 26.0));
bool same(vec3 a, vec3 b) { return all(lessThan(abs(a - b), vec3(0.6 / 255.0))); }
bool is_star(vec3 c) {
	if (same(c, STAR0) || same(c, STAR1) || same(c, STAR2)) return true;
	for (int i = 0; i < 11; i++) if (same(c, FIRE[i] / 255.0)) return true;
	return false;
}
varying vec2 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
float bayer4(ivec2 p) {
	int x = p.x & 3; int y = p.y & 3;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0 - 0.5;
}
void fragment() {
	if (is_star(texture(scr, SCREEN_UV).rgb)) { COLOR = vec4(1.0); }
	else {
	float w = 0.0;
	vec2 cell = floor(wp / 2.0) * 2.0;
	if (lift > 0.0) {
		ivec2 gi = ivec2(floor((cell - gmap_org) / gmap_cell));
		ivec2 gs = textureSize(gmap, 0);
		if (gi.x >= 0 && gi.y >= 0 && gi.x < gs.x && gi.y < gs.y) w = texelFetch(gmap, gi, 0).b * lift;
	}
	float st = w > 0.45 ? 0.5 : w > 0.15 ? 0.25 : 0.0;        // two hard steps on the 2-px grid, no gradient, no dither
	COLOR = vec4(mix(COLOR.rgb, warm, st), 1.0);
	}
}
