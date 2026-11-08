// lit.gd's ambient multiply (the night's dark over the whole screen), lifted where the lamps and fires reach - their
// light baked with its shadows (tools/bake_ground_light.py: ground_n blue, each light traced past the pixel3d
// outlines; owner 2026-11-08: "빛이 실제로 타일과 오브젝트의 영역에 빛과 그림자로 영역에 영향을 주게")
shader_type canvas_item;
render_mode blend_mul;
uniform sampler2D gmap : filter_nearest, repeat_disable;
uniform vec2 gmap_org = vec2(0.0, 120.0);
uniform vec2 gmap_cell = vec2(2.0, 2.0);
uniform float lift = 0.0;
uniform vec3 warm = vec3(1.0, 0.86, 0.64);
varying vec2 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	float w = 0.0;
	if (lift > 0.0) {
		ivec2 gi = ivec2(floor((floor(wp / 2.0) * 2.0 - gmap_org) / gmap_cell));
		ivec2 gs = textureSize(gmap, 0);
		if (gi.x >= 0 && gi.y >= 0 && gi.x < gs.x && gi.y < gs.y) w = texelFetch(gmap, gi, 0).b * lift;
	}
	COLOR = vec4(mix(COLOR.rgb, warm, clamp(w * 1.3, 0.0, 0.85)), 1.0);
}
