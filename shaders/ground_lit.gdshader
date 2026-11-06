// The ground's light and shade from what stands around it, on the map palette (owner 2026-11-07; maps and tables
// from tools/bake_ground_light.py). Every ground pixel is a palette colour: look up which (pal_lut), read the light
// at its 2-px cell (gmap: R shade, G sun, B warm light), and take that colour's lit / shaded version (pal_fx).
// A 4x4 ordered dither on the thresholds breaks the edges into pixel steps instead of hard lines.
shader_type canvas_item;

uniform sampler2D gmap : filter_nearest, repeat_disable;
uniform sampler2D pal_lut : filter_nearest, repeat_disable;
uniform sampler2D pal_fx : filter_nearest, repeat_disable;
uniform vec2 gmap_org = vec2(0.0, 120.0);
uniform vec2 gmap_cell = vec2(4.0, 2.0);
uniform float on = 1.0;

varying vec2 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float bayer4(ivec2 p) {
	int x = p.x & 3; int y = p.y & 3;
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0 - 0.5;
}

void fragment() {
	vec4 c = COLOR;
	if (on < 0.5 || c.a < 0.01) { COLOR = c; }
	else {
		ivec3 q = ivec3(clamp(floor(c.rgb * 255.0 / 8.0), 0.0, 31.0));
		int idx = int(texelFetch(pal_lut, ivec2(q.r * 32 + q.g, q.b), 0).r * 255.0 + 0.5);
		vec2 cell = floor(wp / 2.0) * 2.0;
		ivec2 gi = ivec2(floor((cell - gmap_org) / gmap_cell));
		ivec2 gs = textureSize(gmap, 0);
		vec4 L = (gi.x >= 0 && gi.y >= 0 && gi.x < gs.x && gi.y < gs.y) ? texelFetch(gmap, gi, 0) : vec4(0.0);
		float b = bayer4(ivec2(cell / 2.0)) * 0.3;
		float s = L.r + b; float su = L.g + b; float w = L.b + b;
		int col = 2;
		if (w > 0.55) col = 5;
		else if (w > 0.16) col = 4;
		else if (s > 0.55) col = 0;
		else if (s > 0.2) col = 1;
		else if (su > 0.3) col = 3;
		COLOR = vec4(texelFetch(pal_fx, ivec2(col, idx), 0).rgb, c.a);
	}
}
