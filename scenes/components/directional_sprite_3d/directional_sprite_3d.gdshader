shader_type spatial;

uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform int billboard_mode = 0; // 0 = none, 1 = full, 2 = y

void vertex() {
    vec3 scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);

	if (billboard_mode == 1) {
		// Full billboard (facing camera completely)
		vec4 x = vec4(normalize(INV_VIEW_MATRIX[0].xyz) * scale.x, 0.0);
		vec4 y = vec4(normalize(INV_VIEW_MATRIX[1].xyz) * scale.y, 0.0);
		vec4 z = vec4(normalize(INV_VIEW_MATRIX[2].xyz) * scale.z, 0.0);
		vec4 w = MODEL_MATRIX[3]; // object position

		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(x, y, z, w);
	}
	else if (billboard_mode == 2) {
		// Billboard-Y (rotate only around Y axis)
		vec3 cam_forward = normalize(INV_VIEW_MATRIX[2].xyz);
		cam_forward.y = 0.0;
		cam_forward = normalize(cam_forward);

		vec3 cam_right = normalize(cross(vec3(0.0, 1.0, 0.0), cam_forward));
		vec3 cam_up = vec3(0.0, 1.0, 0.0);

		vec4 x = vec4(cam_right * scale.x, 0.0);
		vec4 y = vec4(cam_up * scale.y, 0.0);
		vec4 z = vec4(-cam_forward * scale.z, 0.0);
		vec4 w = MODEL_MATRIX[3];

		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(x, y, z, w);
	}
}


void fragment() {
	vec4 tex = texture(atlas_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}


//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
