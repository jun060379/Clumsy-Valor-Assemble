shader_type canvas_item;
render_mode unshaded;
// AFX: the perfect-dodge afterimages. The pose is sampled on the art grid (1 art px = 2 world px), alpha cut hard (snapArt);
// mode 0 echo: one flat colour faded by ordered dither; 1 outline: only the 1-px outline; 2 the outline broken into rising pixels
uniform sampler2D tex : filter_linear;
uniform vec4 reg;          // source cell in texels
uniform vec2 tsz;          // sheet size
uniform vec4 geo;          // drawn w, h, feet line (base), facing
uniform int mode = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float keep = 16.0;
uniform float v = 0.0;
varying vec2 lp;
void vertex() { lp = VERTEX; }
float A(vec2 ap) {
	vec2 l = ap * 2.0 + 1.0;
	float lx = l.x * geo.w;
	vec2 tp = vec2(reg.x + (lx + geo.x * 0.5) / geo.x * reg.z, reg.y + (l.y + geo.z) / geo.y * reg.w);
	if (tp.x < reg.x || tp.y < reg.y || tp.x > reg.x + reg.z || tp.y > reg.y + reg.w) return 0.0;
	return texture(tex, tp / tsz).a >= 110.0 / 255.0 ? 1.0 : 0.0;
}
bool edge(vec2 ap) {
	if (A(ap) < 0.5) return false;
	return A(ap + vec2(1.0, 0.0)) < 0.5 || A(ap - vec2(1.0, 0.0)) < 0.5 || A(ap + vec2(0.0, 1.0)) < 0.5 || A(ap - vec2(0.0, 1.0)) < 0.5;
}
int bayer(int i) {
	int B[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return B[i];
}
void fragment() {
	vec2 ap = floor(lp / 2.0);
	vec4 o = vec4(0.0);
	if (mode == 0) {
		if (A(ap) > 0.5) {
			int i = ((int(ap.y) & 3) << 2) | (int(ap.x) & 3);
			if (float(bayer(i)) < clamp(floor(keep + 0.5), 0.0, 16.0)) o = tint;
		}
	} else if (mode == 1) {
		if (edge(ap)) o = tint;
	} else {
		// every other outline pixel (checkered) drifts up and sideways; a share of them is gone each step
		float dy0 = floor(v * v * 14.0 + 0.5);
		for (int j = 0; j < 5 && o.a == 0.0; j++) {
			float sy = ap.y + dy0 + float(j);
			if (mod(sy, 2.0) != 0.0) continue;
			for (int sxo = -4; sxo <= 4; sxo++) {
				float sx = ap.x - float(sxo);
				if (mod(sx, 2.0) != mod(sy / 2.0, 2.0)) continue;
				int k = int(mod(abs(sx * 37.0 + sy * 101.0), 997.0));
				if (k % 5 != j) continue;
				if (floor(sin(float(k)) * v * 4.0 + 0.5) != float(sxo)) continue;
				if (float((k * 37) % 100) / 100.0 < v) continue;
				if (!edge(vec2(sx, sy))) continue;
				o = tint;
				break;
			}
		}
	}
	COLOR = o;
}
