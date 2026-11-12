shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float width = 6.0; // in texels
const int SAMPLES = 12;

void vertex() {
	// Billboard, keeping the node's scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 c = texture(tex, UV);
	vec2 px = width / vec2(textureSize(tex, 0));
	float ring = 0.0;
	for (int i = 0; i < SAMPLES; i++) {
		float a = TAU * float(i) / float(SAMPLES);
		ring = max(ring, texture(tex, UV + vec2(cos(a), sin(a)) * px).a);
	}
	ALBEDO = mix(outline_color.rgb, c.rgb, c.a);
	ALPHA = max(c.a, ring * outline_color.a);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}