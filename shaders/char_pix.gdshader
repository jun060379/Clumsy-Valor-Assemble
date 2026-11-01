shader_type canvas_item;
// 캐릭터 도트화 (prototype charPix / PIXCH): the painted sprite is box-filtered onto the world-pixel grid, alpha cut hard,
// colours stepped to 32 levels with the line-work contrast won back ("dot"); "shade" adds cel-banded luminance (hue kept),
// light from above, a 1-px dark outline, and the directional rim from nearby lights (rimEntity).
// marked: only draws whose modulate carries r > 1.5 (r - 1 is the real red) are processed — for nodes that draw
// a character among other things (Eilin inside the town / hall drawing).
uniform int mode = 2;              // 0 off, 1 dot, 2 dot + shading
uniform bool marked = false;
uniform float zoom = 1.0;          // screen px per world px
uniform int nl = 0;                // rim lights (world space): xy, radius, strength
uniform vec4 lp[8];
uniform vec4 lc[8];
varying vec4 vcol;
varying vec2 wp;
varying float on;

void vertex() {
	vcol = COLOR;
	on = 1.0;
	if (marked) {
		on = vcol.r > 1.5 ? 1.0 : 0.0;
		if (on > 0.5) vcol.r -= 1.0;
	}
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// box filter of one world-pixel cell: premultiplied average of four taps
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
	if (mode == 0 || on < 0.5) {
		// leave COLOR as the default (texture x modulate); a marked draw takes its marker back out
		if (marked && on > 0.5) COLOR.r *= vcol.r / (vcol.r + 1.0);
	} else {
		const float TH = 100.0 / 255.0;
		vec2 fw = vec2(abs(dFdx(UV.x)) + abs(dFdy(UV.x)), abs(dFdx(UV.y)) + abs(dFdy(UV.y)));
		vec2 cs = max(fw * zoom, TEXTURE_PIXEL_SIZE * 0.5);          // one world pixel in UV
		vec2 su = (floor(UV / cs) + 0.5) * cs;
		vec4 c = cell(TEXTURE, su, cs);
		if (c.a < TH) {
			bool rim = mode == 2 && (cell(TEXTURE, su + vec2(cs.x, 0.0), cs).a >= TH || cell(TEXTURE, su - vec2(cs.x, 0.0), cs).a >= TH
				|| cell(TEXTURE, su + vec2(0.0, cs.y), cs).a >= TH || cell(TEXTURE, su - vec2(0.0, cs.y), cs).a >= TH);
			COLOR = rim ? vec4(24.0 / 255.0, 14.0 / 255.0, 36.0 / 255.0, vcol.a) : vec4(0.0);
		} else {
			vec3 col = c.rgb * 255.0;
			if (mode == 2) {
				// the sprite's height in its cell: sheets hold whole rows of 352 px cells, the body sits in the lower half
				float rows = max(1.0, floor(1.0 / (TEXTURE_PIXEL_SIZE.y * 352.0) + 0.5));
				float vy = clamp((fract(su.y * rows) - 0.45) / 0.53, 0.0, 1.0);
				float lit = 1.08 - 0.22 * vy;
				float L = dot(col, vec3(0.299, 0.587, 0.114)) / 255.0 * lit;
				float q = 0.1;
				float cel[6] = float[](0.1, 0.26, 0.44, 0.64, 0.84, 1.0);
				for (int i = 0; i < 6; i++) { if (abs(cel[i] - L) < abs(q - L)) q = cel[i]; }
				float kk = 1.0 + 0.4 * (clamp(q / max(0.04, L / lit), 0.55, 1.6) - 1.0);
				float m = (col.r + col.g + col.b) / 3.0;
				col = (vec3(m) + (col - vec3(m)) * 1.12) * kk;
			}
			col = (col - 128.0) * 1.06 + vec3(126.0, 120.0, 120.0);
			col = clamp(floor(col / 8.0 + 0.5) * 8.0, 0.0, 255.0) / 255.0;
			vec4 o = vec4(col, 1.0) * vcol;
			// rimEntity: the 1-2 px of outline facing each nearby light, added
			if (mode == 2 && nl > 0) {
				for (int i = 0; i < 8; i++) {
					if (i >= nl) break;
					vec2 dv = lp[i].xy - wp;
					float d = length(dv);
					float R = lp[i].z * 2.2;
					if (d >= R) continue;
					float k = pow(1.0 - d / R, 1.3) * lp[i].w;
					vec2 u = dv / max(d, 1e-3);
					// the pixel two world px toward the light is empty: this is the lit edge
					if (cell(TEXTURE, su + vec2(u.x * sign(dFdx(UV.x) * dFdx(wp.x) + dFdy(UV.x) * dFdy(wp.x)), u.y) * cs * 2.0, cs).a < TH)
						o.rgb += lc[i].rgb * min(0.9, k * 2.4);
				}
			}
			COLOR = o;
		}
	}
}
