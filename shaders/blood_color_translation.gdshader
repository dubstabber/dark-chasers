shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;


uniform vec4 blood_color : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D texture_albedo : source_color, filter_nearest, hint_default_transparent;
uniform int billboard_mode : hint_range(0, 2) = 2;

void vertex() {
	if (billboard_mode == 1) {
		// Full billboard - always face camera
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0],
			INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]
		);
	} else if (billboard_mode == 2) {
		// Y-billboard - rotate around Y axis only
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]
		);
	}
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	float bright = max(max(tex.r, tex.g), tex.b);
	ALBEDO = blood_color.rgb * bright;
	ALPHA = tex.a;
}
