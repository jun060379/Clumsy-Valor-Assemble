shader_type canvas_item;
render_mode unshaded;
// aidaSwing: layered dimension tears along the swing (four torn strokes, each opening like an eye and zipping shut)
#include "res://shaders/pfx_common.gdshaderinc"
uniform float F = 0.0;
uniform float a0 = 0.0;
uniform float a1 = 1.0;
uniform float ro = 40.0;
uniform float sy = 1.0;
uniform float sc = 1.0;
uniform float dir = 1.0;
uniform float seed = 0.0;
void vertex() { lp = VERTEX; }
void fragment() {
	// strokes: rc, lo, hi, W, dl, dr
	float RC[4] = float[](1.0, 0.8, 1.14, 0.62);
	float LO[4] = float[](0.0, 0.12, 0.26, 0.2);
	float HI[4] = float[](1.0, 1.04, 0.93, 0.9);
	float WW[4] = float[](7.5, 4.5, 1.4, 3.0);
	float DL[4] = float[](0.0, 0.8, 1.2, 1.7);
	float DR[4] = float[](-0.06, -0.1, 0.04, -0.14);
	float xx = floor(lp.x / S), yy = floor(lp.y / S);
	vec4 o = vec4(0.0);
	float span = a1 - a0, ye = yy / sy, rr = length(vec2(xx, ye));
	if (rr >= ro * 0.45 && rr <= ro * 1.28) {
		float ang = atan(ye, xx * dir);
		float d = span > 0.0 ? mod(ang - a0, TT) : -mod(a0 - ang, TT), u = d / span;
		if (u > 1.3) u -= TT / abs(span);
		if (u >= -0.1 && u <= 1.12) {
			for (int si = 0; si < 4; si++) {
				float tt = F - DL[si];
				if (tt < 0.0 || tt > 10.5) continue;
				vec4 st = tear_state(tt);
				float v = (u - LO[si]) / (HI[si] - LO[si]);
				if (v < st.y || v > st.x || v < 0.0 || v > 1.0) continue;
				float fs = float(si);
				float wob = (hT(u, 40.0, si) - 0.5) * 1.4, rc = ro * (RC[si] + DR[si] * v) + wob;
				float hw = WW[si] * sc * 1.2 * tear_prof(v) * tear_ov(tt, v) * (0.6 + 0.8 * hT(u, 26.0, si + 4));
				if (abs(rr - rc) > hw + 3.0) continue;
				vec4 c = tear_px(xx, yy, rr - rc, hw, st, hT(u, 64.0, si + 8));
				if (c.a > 0.0) { o = c; break; }
			}
		}
	}
	COLOR = o;
}
