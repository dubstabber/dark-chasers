shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Atlas configuration
uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform vec2 atlas_dimensions = vec2(1.0, 1.0);
uniform vec2 frame_size = vec2(1.0, 1.0);
uniform vec2 padded_frame_size = vec2(1.0, 1.0);
uniform bool has_compressed_textures = false;
uniform int direction_count : hint_range(1, 8) = 3;
uniform int current_frame : hint_range(0, 15) = 0;

// Direction and billboard settings
uniform vec3 target_position = vec3(0.0, 0.0, 0.0);
uniform bool auto_direction = true;
uniform bool billboard_enabled = true;

// Material properties
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying flat int sprite_direction;
varying flat int flip_horizontal;

void vertex() {
	vec3 model_pos = MODEL_MATRIX[3].xyz;
	vec3 model_scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);

	if (billboard_enabled) {
		// Use camera orientation directly for perfect billboard alignment
		vec3 cam_right = normalize(INV_VIEW_MATRIX[0].xyz);
		vec3 cam_up = normalize(INV_VIEW_MATRIX[1].xyz);
		vec3 cam_forward = normalize(INV_VIEW_MATRIX[2].xyz);

		mat4 billboard_matrix = mat4(
			vec4(cam_right * model_scale.x, 0.0),
			vec4(cam_up * model_scale.y, 0.0),
			vec4(-cam_forward * model_scale.z, 0.0),
			vec4(model_pos, 1.0)
		);

		MODELVIEW_MATRIX = VIEW_MATRIX * billboard_matrix;
	}

	// Calculate sprite direction based on camera position
	if (auto_direction) {
		vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
		vec3 to_camera = normalize(camera_pos - target_position);
		
		// Get target's local axes (assuming Z-forward, X-right)
		vec3 target_forward = normalize(MODEL_MATRIX[2].xyz);
		vec3 target_right = normalize(MODEL_MATRIX[0].xyz);
		
		float forward_dot = dot(target_forward, to_camera);
		float right_dot = dot(target_right, to_camera);
		
		// Determine direction (optimized for THREE_DIRECTIONAL system)
		if (forward_dot < -0.5) {
			sprite_direction = 0; // front
			flip_horizontal = 0;
		} else if (forward_dot > 0.5) {
			sprite_direction = 2; // back
			flip_horizontal = 0;
		} else {
			sprite_direction = 1; // side
			flip_horizontal = (right_dot > 0.0) ? 1 : 0;
		}
	} else {
		sprite_direction = 0;
		flip_horizontal = 0;
	}
}

void fragment() {
	// Calculate atlas cell position using padded frame size
	vec2 atlas_cell_pos = vec2(
		float(current_frame) * padded_frame_size.x,
		float(sprite_direction) * padded_frame_size.y
	);

	// Since sprites are now padded to fill the entire cell, use the full padded area
	// No need for padding offset - sprites fill the entire padded cell
	vec2 sprite_pos = atlas_cell_pos;

	// Normalize positions and sizes - use padded frame size since sprites now fill the entire cell
	vec2 normalized_sprite_pos = sprite_pos / atlas_dimensions;
	vec2 normalized_frame_size = padded_frame_size / atlas_dimensions;

	// Apply horizontal flipping if needed
	vec2 uv = UV;
	if (flip_horizontal > 0) {
		uv.x = 1.0 - uv.x;
	}

	// Clamp UV coordinates to valid range
	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// Calculate final UV coordinates within the actual sprite area
	vec2 final_uv = normalized_sprite_pos + (uv * normalized_frame_size);

	// For compressed textures, apply conservative clamping to prevent bleeding
	if (has_compressed_textures) {
		// Add a very small inset to avoid sampling edge pixels
		vec2 pixel_size = vec2(1.0) / atlas_dimensions;
		vec2 safe_inset = pixel_size * 0.5; // Half pixel inset for better safety

		// Clamp to sprite boundaries with inset (using padded frame size since sprites fill the cell)
		vec2 sprite_min = normalized_sprite_pos + safe_inset;
		vec2 sprite_max = normalized_sprite_pos + normalized_frame_size - safe_inset;
		final_uv = clamp(final_uv, sprite_min, sprite_max);
	}

	// Ensure final UV stays within atlas bounds as a safety measure
	final_uv = clamp(final_uv, vec2(0.0), vec2(1.0));

	vec4 tex_color = texture(atlas_texture, final_uv);

	// Apply material properties
	ALBEDO = tex_color.rgb * albedo_color.rgb;
	ALPHA = tex_color.a * albedo_color.a;

	// Alpha testing
	if (ALPHA < alpha_cut) {
		discard;
	}
}
