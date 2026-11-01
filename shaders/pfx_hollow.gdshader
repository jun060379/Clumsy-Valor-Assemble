shader_type canvas_item;
render_mode unshaded;
// hollowFx: small dark spheres jostling into one, the union rimmed with a shifting rainbow
#include "res://shaders/pfx_common.gdshaderinc"
uniform float T = 0.0;
uniform int nb = 1;
uniform vec4 B[6];      // x, y, r, w (art px)
void vertex() { lp = VERTEX; }
vec4 iris(int i) {
	if (i <= 0) return vec4(1.0, 0.435, 0.682, 1.0);
	if (i == 1) return vec4(1.0, 0.663, 0.420, 1.0);
	if (i == 2) return vec4(1.0, 0.914, 0.478, 1.0);
	if (i == 3) return vec4(0.525, 1.0, 0.706, 1.0);
	if (i == 4) return vec4(0.435, 0.847, 1.0, 1.0);
	if (i == 5) return vec4(0.561, 0.549, 1.0, 1.0);
	return vec4(0.878, 0.478, 1.0, 1.0);
}
void fragment() {
	float xx = floor(lp.x / S), yy = floor(lp.y / S), ph = T / 1000.0;
	float q = 9.0, th = 0.0; int bi = 0;
	for (int i = 0; i < 6; i++) {
		if (i >= nb) break;
		vec4 b = B[i];
		float dx = xx - b.x, dy = yy - b.y, t2 = atan(dy, dx);
		float rr = b.z * (1.0 + 0.07 * sin(3.0 * t2 + ph * 8.0 + b.w) + 0.04 * sin(5.0 * t2 - ph * 11.0));
		float qq = length(vec2(dx, dy)) / rr;
		if (qq < q) { q = qq; bi = i; th = t2; }
	}
	vec4 o = vec4(0.0);
	if (q < 1.0) {
		if (q > 0.8) {
			float hue = mod(th / 6.283 + ph * 0.9 + float(bi) * 0.17 + (xx + yy) * 0.01, 1.0);
			o = q > 0.88 ? iris(int(floor(hue * 7.0))) : vec4(0.690, 0.424, 1.0, 1.0);
		} else {
			float sw = sin(th * 2.0 + q * 6.0 - ph * 7.0 + float(bi)) + 0.5 * sin(th * 3.0 - q * 4.0 + ph * 5.0);
			o = q < 0.4 ? vec4(0.020, 0.008, 0.031, 1.0) : sw > 1.0 ? vec4(0.227, 0.071, 0.376, 1.0) : sw > 0.2 ? vec4(0.133, 0.035, 0.227, 1.0) : vec4(0.071, 0.024, 0.122, 1.0);
		}
	} else if (q < 1.16 && (int(xx + yy + floor(T / 60.0)) & 1) == 0) {
		o = vec4(0.353, 0.118, 0.620, 1.0);
	}
	COLOR = o;
}
