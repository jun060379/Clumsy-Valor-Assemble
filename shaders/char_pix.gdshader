shader_type canvas_item;
// 캐릭터 도트화 (prototype charPix / PIXCH / rimEntity), reproduced pixel for pixel:
//  · the painted sheet is resampled onto the WORLD pixel grid (integer world coordinates, like charPix's canvas at
//    ox = round(cx - 200)), the way Chrome's 2D canvas does it: premultiplied 8-bit texels, bilinear with 1/16 weights,
//    the source rect sampled strictly; then read back as straight 8-bit colour (getImageData)
//  · alpha < 100 is cut, colours: (shade) cel-banded luminance lit from above over the sprite's own height, (both) the
//    line-work contrast won back and stepped to 32 levels; (shade) a 1-px dark outline
//  · rimEntity: for each of the (up to 3) strongest lights near the body, the outline pixels whose neighbour two world px
//    toward the light is empty get the light's colour added (lighter) at min(0.9, k * 2.4)
// Each pixelated draw carries a slot (player.gd pix_slot) in its colour: b = b0 + 4 * (slot + 1). The slot holds the exact
// world -> texel mapping (up to three bands: the idle breathing stretches the chest), the lit ramp's top and bottom
// rows and the rim lights. Other flags in the colour: r > 1.5 = marked (Eilin among props, r - 1), g >= 2: 1 = hurt flash
// (white source-atop 0.8), 2 / 3 = afterimage (never pixelated: rgb is the tint, 0.75 / 0.8 of it over the sprite).
uniform int mode = 2;              // 0 off, 1 dot, 2 dot + shading
uniform bool marked = false;
uniform float zoom = 1.0;          // screen px per world px (draws without a slot)
const int NS = 16;
uniform vec4 s_o[16];              // slot: integer world origin xy, fractional part xy
uniform vec4 s_m[16];              // texel per world px (x signed by facing), anchor texel x, cell left texel
uniform vec4 s_l[16];              // lit ramp top / bottom (world rows rel. origin), band count, rim light count
uniform ivec4 s_t[80];             // tie bits: where the canvas's own coordinate lands just under an exact 1/16 step
                                   // (x: 300 columns from origin - 150, ints 0..9; y: 256 rows from origin - 240, ints 10..17)
uniform vec4 s_b[48];              // bands: dest top (world, rel. origin), dest height (world px), src top / bottom texel row
uniform vec4 r_l[48];              // rim lights: offset xy (world px), strength
uniform vec4 r_c[48];              // rim light colours
// the town's lamps and fires on the pixel3d sprites (owner 2026-11-08, SLYNYRD's light-source sheet: the side turned to
// the light lit, the edge toward it a rim, the far side left in shade): their normal maps (assets/town/nrm, alpha 128
// marks one: alpha 77) lit by each light near, the colour taken one or two warm steps up on the palette (light/pal_fx)
uniform int pl_n = 0;
uniform vec4 pl_a[12];             // world x, y, reach (px), strength
uniform sampler2D pal_lut : filter_nearest, repeat_disable;
uniform sampler2D pal_fx : filter_nearest, repeat_disable;
varying vec4 vcol;
varying vec2 wp;
varying float on;
varying float slot;
varying float fl;

void vertex() {
	vcol = COLOR;
	on = 1.0;
	if (marked) {
		on = vcol.r > 1.5 ? 1.0 : 0.0;
		if (on > 0.5) vcol.r -= 1.0;
	}
	slot = -1.0;
	if (vcol.b >= 2.0) {
		slot = floor(vcol.b / 4.0) - 1.0;
		vcol.b -= 4.0 * (slot + 1.0);
	}
	fl = 0.0;
	if (vcol.g >= 2.0) {
		fl = floor(vcol.g / 2.0);
		vcol.g -= 2.0 * fl;
	}
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// premultiplied 8-bit texel (0..255), Chrome's decode: p = round(c * a / 255); the hurt flash paints white over it first
vec4 tx(sampler2D t, ivec2 p) {
	vec4 c = texelFetch(t, p, 0);
	vec4 c8 = floor(c * 255.0 + 0.5);
	vec4 o = vec4(floor((c8.rgb * c8.a + 127.0) / 255.0), c8.a);
	if (fl == 1.0) o.rgb = floor(o.rgb * 0.2 + o.a * 0.8 + 0.5);
	return o;
}

// Skia's bilinear (lowp): 1/16 weights; t = texel coordinate of the sample, lo / hi = the source rect (strict)
bool tbit(int si, int k) {
	if (k < 0 || k >= 576) return false;
	ivec4 v = s_t[si * 5 + k / 128];
	int w = (k / 32) % 4;
	int x = w == 0 ? v.x : w == 1 ? v.y : w == 2 ? v.z : v.w;
	return ((x >> (k % 32)) & 1) != 0;
}
// Skia's legacy bilinear: 4-bit (1/16) weights from a 16.16 coordinate; on an exact 1/16 step its float / fixed-point
// mapping lands a hair over or under — the slot's tie bits say which (bx, by: this pixel's column / row bit, -1 none)
vec4 bil(sampler2D t, vec2 c, vec4 r, int si, int bx, int by) {
	vec2 q = c - 0.5;
	vec2 i0 = floor(q);
	vec2 f16 = (q - i0) * 16.0;
	vec2 fq = floor(f16 + 0.004);
	if (abs(f16.x - floor(f16.x + 0.5)) < 0.004 && tbit(si, bx)) fq.x = floor(f16.x + 0.5) - 1.0;
	if (abs(f16.y - floor(f16.y + 0.5)) < 0.004 && by >= 0 && tbit(si, by)) fq.y = floor(f16.y + 0.5) - 1.0;
	if (fq.x < 0.0) { fq.x += 16.0; i0.x -= 1.0; }
	if (fq.y < 0.0) { fq.y += 16.0; i0.y -= 1.0; }
	if (fq.x > 15.0) { fq.x -= 16.0; i0.x += 1.0; }
	if (fq.y > 15.0) { fq.y -= 16.0; i0.y += 1.0; }
	ivec2 a = ivec2(clamp(i0, r.xy, r.zw));
	ivec2 b = ivec2(clamp(i0 + 1.0, r.xy, r.zw));
	vec4 s = tx(t, a) * (16.0 - fq.x) * (16.0 - fq.y) + tx(t, ivec2(b.x, a.y)) * fq.x * (16.0 - fq.y)
		+ tx(t, ivec2(a.x, b.y)) * (16.0 - fq.x) * fq.y + tx(t, b) * fq.x * fq.y;
	return floor(s / 256.0);
}

// one world pixel (integer cell c, relative to the slot origin) of the resampled sprite: straight 8-bit RGBA
vec4 wpx(sampler2D t, ivec2 cl, int si) {
	vec4 O = s_o[si], M = s_m[si], Lt = s_l[si];
	vec2 c = vec2(cl) + 0.5 - O.zw;
	float txx = M.z + c.x * M.x;
	if (txx < M.w || txx >= M.w + 448.0) return vec4(0.0);
	vec4 acc = vec4(0.0);
	int nb = int(Lt.z);
	for (int b = 0; b < 3; b++) {
		if (b >= nb) break;
		vec4 B = s_b[si * 3 + b];
		// coverage of this pixel row by the band's destination rect (the canvas antialiases rect edges)
		float y0 = float(cl.y) - O.w, cov = clamp(min(y0 + 1.0, B.x + B.y) - max(y0, B.x), 0.0, 1.0);
		if (cov <= 0.0) continue;
		float ty = B.z + (c.y - B.x) * (B.w - B.z) / B.y;
		vec4 s = bil(t, vec2(txx, ty), vec4(M.w, B.z, M.w + 447.0, B.w - 1.0), si, cl.x + 150, nb == 1 ? 320 + cl.y + 240 : -1);
		s = floor(s * cov + 0.5);
		acc = s + acc * (1.0 - s.a / 255.0);
		acc = floor(acc + 0.5);
	}
	if (acc.a <= 0.0) return vec4(0.0);
	return vec4(min(floor((acc.rgb * 255.0 + floor(acc.a / 2.0)) / acc.a), 255.0), acc.a);
}

bool solid(sampler2D t, ivec2 cl, int si) { return wpx(t, cl, si).a >= 100.0; }
// charPix's output alpha (shade mode adds the outline ring)
bool filled(sampler2D t, ivec2 cl, int si) {
	if (solid(t, cl, si)) return true;
	if (mode != 2) return false;
	return solid(t, cl + ivec2(1, 0), si) || solid(t, cl - ivec2(1, 0), si) || solid(t, cl + ivec2(0, 1), si) || solid(t, cl - ivec2(0, 1), si);
}

vec3 grade(vec3 col, float lit) {
	if (mode == 2) {
		float L = dot(col, vec3(0.299, 0.587, 0.114)) / 255.0 * lit;
		float q = 0.1;
		float cel[6] = float[](0.1, 0.26, 0.44, 0.64, 0.84, 1.0);
		for (int i = 0; i < 6; i++) { if (abs(cel[i] - L) < abs(q - L)) q = cel[i]; }
		float kk = 1.0 + 0.4 * (clamp(q / max(0.04, L / lit), 0.55, 1.6) - 1.0);
		float m = (col.r + col.g + col.b) / 3.0;
		col = (vec3(m) + (col - vec3(m)) * 1.12) * kk;
	}
	col = (col - 128.0) * 1.06 + vec3(126.0, 120.0, 120.0);
	return clamp(floor(col / 8.0 + 0.5) * 8.0, 0.0, 255.0);
}

// cell-shaped box filter for draws without a slot (Eilin's own sheets): four taps per world pixel
vec4 cell(sampler2D t, vec2 c, vec2 cs) {
	vec4 a = texture(t, c + cs * vec2(-0.25, -0.25));
	vec4 b = texture(t, c + cs * vec2(0.25, -0.25));
	vec4 d = texture(t, c + cs * vec2(-0.25, 0.25));
	vec4 e = texture(t, c + cs * vec2(0.25, 0.25));
	float al = (a.a + b.a + d.a + e.a) * 0.25;
	vec3 rgb = (a.rgb * a.a + b.rgb * b.a + d.rgb * d.a + e.rgb * e.a) * 0.25 / max(al, 1e-4);
	return vec4(rgb, al);
}

void fragment() {
	if (fl >= 2.0) {
		// afterimage (prototype ghostFx): the frame tinted source-atop, drawn smooth at the given alpha
		vec4 tc = texture(TEXTURE, UV);
		COLOR = vec4(mix(tc.rgb, vcol.rgb, fl == 3.0 ? 0.8 : 0.75), tc.a * vcol.a);
	} else if (mode == 0 || on < 0.5) {
		vec4 tc = texture(TEXTURE, UV);
		if (fl == 1.0) tc.rgb = tc.rgb * 0.2 + 0.8;
		COLOR = tc * vcol;
		vec4 nm = texture(NORMAL_TEXTURE, UV);
		if (pl_n > 0 && tc.a > 0.5 && abs(nm.a - 77.0 / 255.0) < 0.03) {
			vec3 N = normalize(nm.rgb * 2.0 - 1.0); N.y = -N.y;          // rendered y up; the screen's y runs down
			vec2 cell = floor(wp / 2.0) * 2.0 + 1.0;
			float w = 0.0; bool rim = false;
			for (int i = 0; i < 12; i++) {
				if (i >= pl_n) break;
				vec3 Lv = vec3(pl_a[i].xy - cell, 40.0);
				float f = 1.0 - length(Lv.xy) / pl_a[i].z;
				if (f <= 0.0) continue;
				float ndl = dot(N, normalize(Lv));
				w += max(ndl, 0.0) * f * pl_a[i].w;
				// a rim: the edge cell whose neighbour toward the light is empty
				vec2 dir = normalize(Lv.xy);
				vec2 st = vec2(abs(dir.x) > 0.38 ? sign(dir.x) : 0.0, abs(dir.y) > 0.38 ? sign(dir.y) : 0.0);
				if (f > 0.35 && texture(TEXTURE, UV + st * TEXTURE_PIXEL_SIZE * 2.0).a < 0.5) rim = true;
			}
			int col = rim ? 5 : w > 0.55 ? 5 : w > 0.22 ? 4 : 2;
			if (col != 2) {
				ivec3 q = ivec3(clamp(floor(tc.rgb * 255.0 / 8.0), 0.0, 31.0));
				int idx = int(texelFetch(pal_lut, ivec2(q.r * 32 + q.g, q.b), 0).r * 255.0 + 0.5);
				COLOR.rgb = texelFetch(pal_fx, ivec2(col, idx), 0).rgb * vcol.rgb;
			}
		}
		if (mode == 0 && on > 0.5 && slot >= 0.0) {
			// off: the rim still follows the raw sprite's edge, one world pixel at a time
			int si = int(slot);
			ivec2 cl = ivec2(floor(wp - s_o[si].xy));
			float ac = wpx(TEXTURE, cl, si).a / 255.0;
			for (int i = 0; i < 3; i++) {
				if (float(i) >= s_l[si].w) break;
				vec4 R = r_l[si * 3 + i];
				float an = wpx(TEXTURE, cl + ivec2(R.xy), si).a / 255.0;
				COLOR.rgb += r_c[si * 3 + i].rgb * R.z * ac * (1.0 - an) / max(COLOR.a, 1e-3);
			}
		}
	} else if (slot >= 0.0) {
		int si = int(slot);
		ivec2 cl = ivec2(floor(wp - s_o[si].xy));
		vec4 c = wpx(TEXTURE, cl, si);
		vec4 o = vec4(0.0);
		bool any = true;
		if (c.a < 100.0) {
			any = mode == 2 && (solid(TEXTURE, cl + ivec2(1, 0), si) || solid(TEXTURE, cl - ivec2(1, 0), si)
				|| solid(TEXTURE, cl + ivec2(0, 1), si) || solid(TEXTURE, cl - ivec2(0, 1), si));
			if (any) o = vec4(24.0, 14.0, 36.0, 255.0) / 255.0;
		} else {
			vec4 Lt = s_l[si];
			float vy = Lt.y > Lt.x ? (float(cl.y) - Lt.x) / (Lt.y - Lt.x) : 0.5;
			o = vec4(grade(c.rgb, mode == 2 ? 1.08 - 0.22 * vy : 1.0) / 255.0, 1.0);
		}
		o *= vcol;
		for (int i = 0; i < 3; i++) {
			if (!any || float(i) >= s_l[si].w) break;
			vec4 R = r_l[si * 3 + i];
			if (!filled(TEXTURE, cl + ivec2(R.xy), si)) o.rgb += r_c[si * 3 + i].rgb * R.z;
		}
		COLOR = o;
	} else {
		const float TH = 100.0 / 255.0;
		vec2 fw = vec2(abs(dFdx(UV.x)) + abs(dFdy(UV.x)), abs(dFdx(UV.y)) + abs(dFdy(UV.y)));
		vec2 cs = max(fw * zoom, TEXTURE_PIXEL_SIZE * 0.5);
		vec2 su = (floor(UV / cs) + 0.5) * cs;
		vec4 c = cell(TEXTURE, su, cs);
		if (c.a < TH) {
			bool rim = mode == 2 && (cell(TEXTURE, su + vec2(cs.x, 0.0), cs).a >= TH || cell(TEXTURE, su - vec2(cs.x, 0.0), cs).a >= TH
				|| cell(TEXTURE, su + vec2(0.0, cs.y), cs).a >= TH || cell(TEXTURE, su - vec2(0.0, cs.y), cs).a >= TH);
			COLOR = rim ? vec4(24.0 / 255.0, 14.0 / 255.0, 36.0 / 255.0, vcol.a) : vec4(0.0);
		} else {
			float vy = clamp((fract(su.y * max(1.0, floor(1.0 / (TEXTURE_PIXEL_SIZE.y * 352.0) + 0.5))) - 0.45) / 0.53, 0.0, 1.0);
			COLOR = vec4(grade(c.rgb * 255.0, mode == 2 ? 1.08 - 0.22 * vy : 1.0) / 255.0, 1.0) * vcol;
		}
	}
}
