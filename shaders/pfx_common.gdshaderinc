// shared by the pixel-effect shaders: every mark is one art pixel (2 world px); lp = node-local position
const float S = 2.0;
const float TT = 6.28318530718;
varying vec2 lp;
float hn3(float u, float k, float seed, float o2) { float v = sin(floor(u * k) * 12.9898 + seed * 3.3 + o2) * 43758.5453; return fract(v); }
float eo(float x) { return 1.0 - pow(1.0 - clamp(x, 0.0, 1.0), 3.0); }
float smo(float x) { x = clamp(x, 0.0, 1.0); return x * x * (3.0 - 2.0 * x); }
// tearState(tt): x = ext, y = tl, z = cool, w = snap; valid when tt in [0, 10.5]
vec4 tear_state(float tt) {
	float cool = tt < 6.1 ? 0.0 : tt < 7.2 ? 1.0 : tt < 8.4 ? 2.0 : tt < 9.4 ? 3.0 : 4.0;
	float snap = (tt >= 5.5 && tt < 6.1) ? 1.0 : 0.0;
	return vec4(eo(tt / 0.8), tt < 9.0 ? 0.0 : eo((tt - 9.0) / 1.4), cool, snap);
}
float tear_ov(float tt, float v) { float edge = min(1.0, abs(v - 0.55) / 0.5); float op = smo((tt - 0.45 - 0.55 * edge) / 1.7); float sh = smo((tt - 3.9 - 0.5 * (1.0 - edge)) / 1.25); return op * (1.0 - sh); }
float tear_prof(float v) { return v < 0.74 ? 0.07 + 0.93 * pow(v / 0.74, 1.5) : pow(max(0.0, 1.0 - (v - 0.74) / 0.26), 0.5); }
float almond(float v) { return pow(sin(3.14159265 * clamp(v, 0.0, 1.0)), 0.8); }
const vec4 T_LIP0 = vec4(1.0, 1.0, 1.0, 1.0);
// TEAR palette: lip ramp, rims, the void
vec4 tear_lip(int i) {
	if (i <= 0) return vec4(1.0);
	if (i == 1) return vec4(0.910, 0.831, 1.0, 1.0);
	if (i == 2) return vec4(0.788, 0.627, 1.0, 1.0);
	if (i == 3) return vec4(0.604, 0.384, 0.878, 1.0);
	return vec4(0.353, 0.165, 0.620, 1.0);
}
const vec4 T_RIM = vec4(0.690, 0.478, 1.0, 1.0);
const vec4 T_RIM2 = vec4(0.353, 0.118, 0.620, 1.0);
const vec4 T_VOID = vec4(0.024, 0.008, 0.039, 1.0);
// tearPx: returns a colour with a > 0 when the pixel is painted
vec4 tear_px(float xx, float yy, float dist, float hw, vec4 st, float hn) {
	float ad = abs(dist);
	if (hw > 0.6 && ad < hw) { float h2 = fract(sin(xx * 12.9898 + yy * 78.233) * 43758.5453); return h2 < 0.02 ? T_RIM : T_VOID; }
	float lip = hw > 0.6 ? ad - hw : ad;
	if (lip < (st.w > 0.5 ? 1.3 : 0.8)) return tear_lip(int(min(4.0, st.z)));
	if (st.z < 3.0 && lip < 1.9 && hw > 0.8 && hn > 0.15) return T_RIM;
	if (st.z < 2.0 && lip < 2.9 && hw > 2.2 && hn > 0.6) return T_RIM2;
	return vec4(0.0);
}
