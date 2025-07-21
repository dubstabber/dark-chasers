shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Atlas and direction uniforms
uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform vec2 atlas_dimensions = vec2(1.0, 1.0);
uniform vec2 frame_size = vec2(1.0, 1.0);
uniform int direction_count : hint_range(1, 8) = 3;
uniform int current_frame : hint_range(0, 15) = 0;

// Direction calculation uniforms
uniform vec3 target_position = vec3(0.0, 0.0, 0.0);
uniform bool auto_direction = true;

// Godot editor properties support
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform bool billboard_enabled = true;

varying vec3 world_position;
varying vec3 world_normal;
varying float calculated_direction;
varying float calculated_flip;

void vertex() {
	if (billboard_enabled) {
		// Extract scale and position from model matrix
		vec3 model_scale = vec3(
			length(MODEL_MATRIX[0].xyz),
			length(MODEL_MATRIX[1].xyz),
			length(MODEL_MATRIX[2].xyz)
		);
		vec3 model_pos = MODEL_MATRIX[3].xyz;

		// Extract camera's right and up vectors directly from view matrix
		// This keeps the sprite parallel to the camera view plane
		vec3 camera_right = normalize(INV_VIEW_MATRIX[0].xyz);
		vec3 camera_up = normalize(INV_VIEW_MATRIX[1].xyz);
		vec3 camera_forward = normalize(INV_VIEW_MATRIX[2].xyz);

		// Create billboard rotation matrix using camera's orientation
		// This ensures the sprite stays parallel to the camera view
		mat4 billboard_model = mat4(
			vec4(camera_right * model_scale.x, 0.0),
			vec4(camera_up * model_scale.y, 0.0),
			vec4(-camera_forward * model_scale.z, 0.0),
			vec4(model_pos, 1.0)
		);

		// Apply billboard transformation
		vec4 world_vertex = billboard_model * vec4(VERTEX, 1.0);
		world_position = world_vertex.xyz;
		world_normal = -camera_forward;

		// Let Godot handle the rest of the transformation pipeline
		VERTEX = VERTEX; // Keep original vertex, but override MODELVIEW
		MODELVIEW_MATRIX = VIEW_MATRIX * billboard_model;
	} else {
		// Standard transformation
		world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}

	// Calculate direction based on current rendering camera (works for all camera types)
	if (auto_direction) {
		// Get camera position from view matrix (works for editor, mirrors, etc.)
		vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;

		// Use target position (object center) for direction calculation
		vec3 to_camera = normalize(camera_pos - target_position);

		// Get target's forward direction (assuming Z-forward, Y-up)
		vec3 target_forward = normalize(MODEL_MATRIX[2].xyz);
		vec3 target_right = normalize(MODEL_MATRIX[0].xyz);

		// Calculate dot products for direction determination
		float forward_dot = dot(target_forward, to_camera);
		float right_dot = dot(target_right, to_camera);

		// Determine direction (THREE_DIRECTIONAL system)
		if (forward_dot < -0.5) {
			calculated_direction = 0.0; // front
		} else if (forward_dot > 0.5) {
			calculated_direction = 2.0; // back
		} else {
			calculated_direction = 1.0; // side
		}

		// Calculate horizontal flip for side view
		calculated_flip = (calculated_direction == 1.0 && right_dot > 0.0) ? 1.0 : 0.0;
	} else {
		// Fallback: use front direction and no flip
		calculated_direction = 0.0; // front
		calculated_flip = 0.0; // no flip
	}
}

void fragment() {
	// Calculate UV coordinates for the specific atlas region
	vec2 atlas_uv = UV;

	// Use calculated direction from vertex shader
	int direction_index = int(calculated_direction);

	// Calculate frame position in atlas
	vec2 frame_pos = vec2(
		float(current_frame) * frame_size.x,
		float(direction_index) * frame_size.y
	);

	// Normalize frame position to atlas coordinates
	vec2 normalized_frame_pos = frame_pos / atlas_dimensions;
	vec2 normalized_frame_size = frame_size / atlas_dimensions;

	// Apply horizontal flipping if needed (from vertex shader calculation)
	if (calculated_flip > 0.5) {
		atlas_uv.x = 1.0 - atlas_uv.x;
	}

	// Map UV to the specific atlas region
	vec2 final_uv = normalized_frame_pos + (atlas_uv * normalized_frame_size);

	// Sample the atlas texture
	vec4 tex_color = texture(atlas_texture, final_uv);

	// Apply albedo color
	ALBEDO = tex_color.rgb * albedo_color.rgb;
	ALPHA = tex_color.a * albedo_color.a;

	// Apply alpha cut (alpha testing)
	if (ALPHA < alpha_cut) {
		discard;
	}
}
