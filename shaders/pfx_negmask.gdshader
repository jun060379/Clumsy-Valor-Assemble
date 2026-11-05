shader_type canvas_item;
render_mode unshaded;
// a window onto the game in negative: inside the mask (a frame of a baked sprite sheet), the screen behind is inverted
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D mask : filter_nearest;
uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);     // the quad's local rect (pos, size)
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);   // the frame in the mask, in uv (pos, size)
uniform float flip = 1.0;
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 u = (lp - rect.xy) / rect.zw;
	if (flip < 0.0) u.x = 1.0 - u.x;
	float a = texture(mask, region.xy + u * region.zw).a;
	if (a < 0.5) discard;
	COLOR = vec4(vec3(1.0) - texture(screen_tex, SCREEN_UV).rgb, 1.0);
}
