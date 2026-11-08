// The grass tufts on the back of the ground plane (owner 2026-11-08: "아래 풀은 두고 위 영역의 포기는 전환"): palette
// sprites (assets/town/grass, tools/bake_grass_sway.py) lit like the blades - every pixel takes the palette move of
// the ground under the tuft's root (gmap: R shade, G sun, B warm light), so a tuft in a tree's shadow is in it whole.
// The sway frames are side by side, so UV.y runs the tuft's full height: its root is (1 - UV.y) texture heights below.
shader_type canvas_item;

uniform sampler2D gmap : filter_nearest, repeat_disable;
uniform sampler2D pal_lut : filter_nearest, repeat_disable;
uniform sampler2D pal_fx : filter_nearest, repeat_disable;
uniform vec2 gmap_org = vec2(0.0, -360.0);     // tools/bake_ground_light.py Y0
uniform vec2 gmap_cell = vec2(2.0, 2.0);       // tools/bake_ground_light.py CX, CY
uniform float lit_on = 0.0;

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.5) discard;
	vec3 o = c.rgb;
	if (lit_on > 0.5) {
		ivec3 q = ivec3(clamp(floor(o * 255.0 / 8.0), 0.0, 31.0));
		int idx = int(texelFetch(pal_lut, ivec2(q.r * 32 + q.g, q.b), 0).r * 255.0 + 0.5);
		vec2 root = vec2(wp.x, wp.y + (1.0 - UV.y) / TEXTURE_PIXEL_SIZE.y - 1.0);
		ivec2 gi = ivec2(floor((root - gmap_org) / gmap_cell));
		ivec2 gs = textureSize(gmap, 0);
		vec4 L = (gi.x >= 0 && gi.y >= 0 && gi.x < gs.x && gi.y < gs.y) ? texelFetch(gmap, gi, 0) : vec4(0.0);
		int col = 2;
		if (L.b > 0.55) col = 5; else if (L.b > 0.16) col = 4; else if (L.r > 0.55) col = 0; else if (L.r > 0.2) col = 1; else if (L.g > 0.3) col = 3;
		o = texelFetch(pal_fx, ivec2(col, idx), 0).rgb;
	}
	COLOR = vec4(o, 1.0);
}
