shader_type canvas_item;
render_mode unshaded;
// pillarFx: Luce's column of light — the top melts into dither, the whole column dissolves at the end
#include "res://shaders/pfx_common.gdshaderinc"
uniform int f = 0;
uniform float H = 100.0;
uniform float W = 1.0;
uniform float top = -100.0;
uniform float dis = 0.0;
void vertex() { lp = VERTEX; }
void fragment() {
	float xx = floor(lp.x / S), yy = floor(lp.y / S);
	vec4 o = vec4(0.0);
	if (W > 0.0 && yy >= floor(top + 0.5) && yy <= 0.0) {
		float up = -yy / H;
		float cap = up > 0.72 ? 1.0 - (up - 0.72) / 0.28 : 1.0, foot = up < 0.08 ? 1.0 + (0.08 - up) * 6.0 : 1.0;
		float w = max(0.4, W * cap * foot + (sin(yy * 0.5 + float(f) * 1.7) > 0.6 ? 1.0 : 0.0));
		float q = abs(xx) / max(0.5, w);
		if (abs(xx) <= ceil(w) && q <= 1.0) {
			float hsh = float((int(xx) * 7 + int(yy) * 13 + f * 5) & 7) / 8.0;
			if (!(up > 0.72 && hsh < (up - 0.72) / 0.28) && !(hsh < dis * 1.15)) {
				vec4 c2 = vec4(1.0, 0.914, 0.627, 1.0);
				o = q < 0.3 ? (dis > 0.5 ? c2 : vec4(1.0)) : q < 0.6 ? c2 : q < 0.85 ? vec4(1.0, 0.827, 0.302, 1.0) : vec4(0.910, 0.639, 0.227, 1.0);
			}
		}
	}
	COLOR = o;
}
