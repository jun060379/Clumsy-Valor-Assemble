// The river as a mirror (owner 2026-11-08: "물에 미러효과 넣고 이런식으로", Kingdom's water): the water shows what
// stands over it - the people passing too - upside down about the waterline, every 2-px row slid sideways by the
// ripples (more the further from the line), its colours a little darker and drawn toward the river's; short dashes
// of the river's colour and now and then a light ripple line. Off the palette here by the owner's leave; whole
// cells only.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float wl = 0.0;                         // the waterline (world y)
uniform vec4 deep : source_color = vec4(0.047, 0.345, 0.384, 1.0);   // the river's body (palette)
uniform vec4 lite : source_color = vec4(0.373, 0.576, 0.624, 1.0);   // a ripple's light (palette)
uniform float t = 0.0;

varying vec2 wp;
varying vec2 muv;        // the screen uv of the mirrored point
varying vec2 du;         // the screen uv of one world px along x

vec2 to_uv(vec2 p, mat4 cm, mat4 sm) {
	vec4 c = sm * cm * vec4(p, 0.0, 1.0);
	return vec2(c.x * 0.5 + 0.5, c.y * 0.5 + 0.5);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vec2 m = vec2(wp.x, 2.0 * wl - wp.y);
	muv = to_uv(m, CANVAS_MATRIX, SCREEN_MATRIX);
	du = to_uv(m + vec2(1.0, 0.0), CANVAS_MATRIX, SCREEN_MATRIX) - muv;
}

void fragment() {
	vec2 cell = floor(wp / 2.0);
	float d = wp.y - wl;
	float row = cell.y;
	// the ripple: each 2-px row slides a whole number of cells, more the deeper below the line
	float amp = 0.3 + d * 0.02;
	float s = sin(row * 0.9 + t * 2.1) * 0.6 + sin(row * 2.3 - t * 3.3 + cell.x * 0.02) * 0.4;
	float dx = round(s * amp) * 2.0;
	vec2 uv = muv + du * dx;
	vec3 o = deep.rgb;
	if (uv.y > 0.0 && uv.y < 1.0 && uv.x > 0.0 && uv.x < 1.0) {
		// the reflection as it is, a little darker and drawn toward the river's colour: the one place off the
		// palette (owner 2026-11-08: "이건 좀 팔레트 밖 색 써도 될듯. 반사율을 래퍼런스에 가깝게")
		vec3 c = texture(screen_tex, uv).rgb;
		o = mix(c * 0.9, deep.rgb, 0.16 + clamp(d / 400.0, 0.0, 0.14));
	}
	// the water between: now and then a short dash of the river's own colour where the ripple runs
	if (d > 3.0 && mod(row, 4.0) < 1.0 && sin(cell.x * 0.21 + row * 1.7 + t * 1.1) > 0.55) o = deep.rgb;
	// a light ripple line now and then, short, drifting
	float hl = sin(cell.x * 0.11 + row * 5.1 + t * 0.9) + 0.5 * sin(cell.x * 0.29 - t * 1.7);
	if (mod(row, 6.0) < 1.0 && hl > 1.15 && d > 2.0) o = lite.rgb;
	COLOR = vec4(o, 1.0);
}
