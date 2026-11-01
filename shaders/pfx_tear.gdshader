shader_type canvas_item;
render_mode unshaded;
// tearLineFx: up to four eye-tears laid along a straight cut (rift gates, Aida's dive / slam / thrust, the ult's cut)
#include "res://shaders/pfx_common.gdshaderinc"
uniform float tt = 0.0;
uniform vec2 ud = vec2(1.0, 0.0);      // unit direction (art px)
uniform vec2 nrm = vec2(0.0);          // the across direction when it is not ud turned (aidaThrust keeps it down for either facing)
uniform float L = 10.0;                // length in art px
uniform float seed = 0.0;
uniform vec3 nf = vec3(30.0, 22.0, 56.0);   // noise frequencies (wobble, width, rim)
uniform vec2 ur = vec2(-0.02, 1.02);        // u range drawn
uniform int n = 3;
uniform vec4 sa[4];   // o0, o1, lo, hi
uniform vec4 sb[4];   // W, dl, prof (0 tearProf, 1 almond, 2 dive, 3 almond(0.15+0.85v)), unused
void vertex() { lp = VERTEX; }
float prof(float k, float v) {
	if (k < 0.5) return tear_prof(v);
	if (k < 1.5) return almond(v);
	if (k < 2.5) return 0.15 + 0.85 * pow(v, 1.2);
	return almond(0.15 + v * 0.85);
}
void fragment() {
	float xx = floor(lp.x / S), yy = floor(lp.y / S);
	vec2 nn = nrm != vec2(0.0) ? nrm : vec2(-ud.y, ud.x);
	float al = xx * ud.x + yy * ud.y, pd = xx * nn.x + yy * nn.y, u = al / L;
	vec4 o = vec4(0.0);
	if (u >= ur.x && u <= ur.y) {
		for (int si = 0; si < 4; si++) {
			if (si >= n) break;
			float t2 = tt - sb[si].y;
			if (t2 < 0.0 || t2 > 10.5) continue;
			vec4 st = tear_state(t2);
			float v = (u - sa[si].z) / (sa[si].w - sa[si].z);
			if (v < st.y || v > st.x || v < 0.0 || v > 1.0) continue;
			float fs = float(si);
			float oc = sa[si].x + (sa[si].y - sa[si].x) * v + (hT(u, nf.x, si) - 0.5) * 1.2;
			float hw = sb[si].x * prof(sb[si].z, v) * tear_ov(t2, v) * (0.6 + 0.8 * hT(u, nf.y, si + 4));
			if (abs(pd - oc) > hw + 3.0) continue;
			vec4 c = tear_px(xx, yy, pd - oc, hw, st, hT(u, nf.z, si + 8));
			if (c.a > 0.0) { o = c; break; }
		}
	}
	COLOR = o;
}
