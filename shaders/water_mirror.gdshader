// The river as a mirror (owner 2026-11-08: "물에 미러효과 넣고 이런식으로", Kingdom's water): the water shows what
// stands over it, upside down about the waterline, every 2-px row slid sideways by the ripples (more the further
// from the line), each colour taken one shade step down its own palette ramp (pal_fx, never "a darker mix"), and
// now and then a light ripple line. Every pixel a palette
// colour; whole cells only.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D pal_lut : filter_nearest, repeat_disable;
uniform sampler2D pal_fx : filter_nearest, repeat_disable;
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
	float amp = 0.6 + d * 0.035;
	float s = sin(row * 0.9 + t * 2.1) * 0.6 + sin(row * 2.3 - t * 3.3 + cell.x * 0.02) * 0.4;
	float dx = round(s * amp) * 2.0;
	vec2 uv = muv + du * dx;
	vec3 o = deep.rgb;
	if (uv.y > 0.0 && uv.y < 1.0 && uv.x > 0.0 && uv.x < 1.0) {
		vec3 c = texture(screen_tex, uv).rgb;
		ivec3 q = ivec3(clamp(floor(c * 255.0 / 8.0), 0.0, 31.0));
		int idx = int(texelFetch(pal_lut, ivec2(q.r * 32 + q.g, q.b), 0).r * 255.0 + 0.5);
		o = texelFetch(pal_fx, ivec2(0, idx), 0).rgb;
	}
	// the water between: every third row the river's own colour, broken where the ripple runs (Kingdom's look)
	if (d > 3.0 && mod(row, 3.0) < 1.0 && sin(cell.x * 0.21 + row * 1.7 + t * 1.1) > -0.4) o = deep.rgb;
	// a light ripple line now and then, short, drifting
	float hl = sin(cell.x * 0.11 + row * 5.1 + t * 0.9) + 0.5 * sin(cell.x * 0.29 - t * 1.7);
	if (mod(row, 6.0) < 1.0 && hl > 1.15 && d > 2.0) o = lite.rgb;
	COLOR = vec4(o, 1.0);
}
