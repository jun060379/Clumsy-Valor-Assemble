// lit.gd's ambient multiply (the night's dark over the whole screen), eased where the lamps and fires reach so the
// light the sprites, tiles and people carry themselves shows (tools/bake_ground_light.py: ground_n blue, traced past
// the pixel3d outlines). In steps on the 2-px grid with an ordered dither, never a soft gradient (owner 2026-11-08).
shader_type canvas_item;
render_mode blend_mul;
uniform sampler2D gmap : filter_nearest, repeat_disable;
uniform vec2 gmap_org = vec2(0.0, 120.0);
uniform vec2 gmap_cell = vec2(2.0, 2.0);
uniform float lift = 0.0;
uniform vec3 warm = vec3(1.0, 0.86, 0.64);
varying vec2 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
float bayer4(ivec2 p) {
	int x = p.x & 3; int y = p.y & 3;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0 - 0.5;
}
void fragment() {
	float w = 0.0;
	vec2 cell = floor(wp / 2.0) * 2.0;
	if (lift > 0.0) {
		ivec2 gi = ivec2(floor((cell - gmap_org) / gmap_cell));
		ivec2 gs = textureSize(gmap, 0);
		if (gi.x >= 0 && gi.y >= 0 && gi.x < gs.x && gi.y < gs.y) w = texelFetch(gmap, gi, 0).b * lift;
	}
	float q = w + bayer4(ivec2(cell / 2.0)) * 0.25;
	float st = q > 0.5 ? 0.6 : q > 0.2 ? 0.35 : 0.0;          // two steps, no gradient
	COLOR = vec4(mix(COLOR.rgb, warm, st), 1.0);
}
