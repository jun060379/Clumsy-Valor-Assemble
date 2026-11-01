shader_type canvas_item;
render_mode unshaded;
// SLASHFX.ref: the swing crescent (sharp head, needle tail, ragged edges), air wake outside, two speed arcs inside
#include "res://shaders/pfx_common.gdshaderinc"
uniform int f = 0;
uniform float a0 = 0.0;
uniform float a1 = 1.0;
uniform float ro = 40.0;
uniform float thick = 20.0;
uniform float sy = 1.0;
uniform float dir = 1.0;
uniform float seed = 0.0;
uniform float jag = 0.0;
uniform vec4 K = vec4(1.0, 0.0, 1.0, 0.0);    // h, tl, w, dk
uniform vec4 pal[5];
void vertex() { lp = VERTEX; }
vec4 col(int n) { return pal[min(4, n + int(K.w))]; }
float hn(float u, float k, float o2) { return fract(sin(floor(u * k) * 12.9898 + seed * 7.1 + o2) * 43758.5453); }
float prof(float u) {
	float v = u < 0.8 ? 0.04 + 0.96 * pow(u / 0.8, 1.7) : pow(max(0.0, 1.0 - (u - 0.8) / 0.2), 0.55);
	float w = thick * v * K.z;
	bool jg = jag > 0.5;
	w *= 1.0 + (jg ? 0.5 : 0.24) * abs(sin(u * (jg ? 21.0 : 13.0) + seed)) * pow(u, 0.6) + (jg ? 0.0 : 0.12 * abs(sin(u * 47.0 + seed * 3.0)));
	return w;
}
void fragment() {
	float xx = floor(lp.x / S), yy = floor(lp.y / S);
	vec4 o = vec4(0.0);
	float ye = yy / sy, rr = length(vec2(xx, ye)), span0 = a1 - a0;
	if (rr <= ro + 8.0 && rr >= ro - thick * 1.6 - 9.0) {
		float ang = atan(ye, xx * dir);
		float d = span0 > 0.0 ? mod(ang - a0, TT) : -mod(a0 - ang, TT);
		float s0 = d / span0;
		if (s0 >= K.y && s0 <= K.x) {
			float u = (s0 - K.y) / max(1e-3, K.x - K.y);
			if (K.z == 0.0) {
				if (abs(rr - ro) < 0.7) o = col(1);
			} else {
				float w = prof(u) * (0.72 + 0.56 * hn(u, 24.0, 1.0)), dep = ro + (hn(u, 16.0, 2.0) - 0.5) * 2.2 - rr;
				if (!(dep > 0.8 && dep < 2.6 && hn(u, 90.0, 3.0) < 0.12)) {
					if (dep >= -0.5 && dep <= max(0.9, w)) {
						float q = dep / max(1.0, w);
						o = dep < 0.6 ? col(0) : q < 0.38 ? col(1) : q < 0.82 ? col(2) : col(3);
					} else {
						if (f >= 2 && f <= 5) for (int n = 1; n <= 2; n++) {
							float rw = ro + 1.5 + float(n) * 2.2; if (abs(rr - rw) > 0.5) continue;
							float hi = K.x - 0.12 * float(n) - 0.06 * float(f - 2), lo = max(K.y, hi - 0.35 + 0.05 * float(f));
							if (s0 < lo || s0 > hi) continue;
							if (int(mod(floor(s0 * 40.0) + float(n), 5.0)) == 0) continue;
							o = f < 4 ? col(1) : col(3);
						}
						if (f >= 1 && f <= 5) for (int n = 1; n <= 2; n++) {
							float rw = ro - thick - 1.5 - float(n) * 2.6; if (abs(rr - rw) > 0.5) continue;
							float lo = K.y + 0.08 * float(n), hi = K.x - 0.18 * float(n);
							if (s0 < lo || s0 > hi) continue;
							o = n == 1 ? col(2) : col(3);
						}
					}
				}
			}
		}
	}
	COLOR = o;
}
