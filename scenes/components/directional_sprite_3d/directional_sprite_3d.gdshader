shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas_texture : source_color, filter_nearest;
uniform vec2 atlas_dimensions = vec2(1.0, 1.0);
uniform vec2 max_sprite_size = vec2(1.0, 1.0);
uniform int current_frame = 0;

uniform int direction_mode : hint_range(0, 3) = 0; // 0=THREE, 1=FOUR, 2=FIVE, 3=EIGHT
uniform vec3 target_position = vec3(0.0, 0.0, 0.0);

uniform int billboard_mode = 0; // 0 = none, 1 = full, 2 = y

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

varying flat int sprite_direction;
varying flat int flip_horizontal;


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

	vec3 camera_pos = INV_VIEW_MATRIX[3].xyz;
		vec3 to_camera = normalize(camera_pos - target_position);

		// Get target's local axes (assuming Z-forward, X-right)
		vec3 target_forward = normalize(MODEL_MATRIX[2].xyz);
		vec3 target_right = normalize(MODEL_MATRIX[0].xyz);

		float forward_dot = dot(target_forward, to_camera);
		float right_dot = dot(target_right, to_camera);

		// Direction calculation based on mode
		if (direction_mode == 0) { // THREE_DIRECTIONS
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
		} else if (direction_mode == 1) { // FOUR_DIRECTIONS
			// front, left, right, back - no flipping needed
			flip_horizontal = 0;
			if (forward_dot < -0.5) {
				sprite_direction = 0; // front
			} else if (forward_dot > 0.5) {
				sprite_direction = 3; // back
			} else if (right_dot > 0.0) {
				sprite_direction = 2; // right
			} else {
				sprite_direction = 1; // left
			}
		} else if (direction_mode == 2) { // FIVE_DIRECTIONS
			// front, side, back, front_side, back_side - uses flipping for side directions
			if (forward_dot < -0.5) {
				sprite_direction = 0; // front
				flip_horizontal = 0;
			} else if (forward_dot > 0.5) {
				sprite_direction = 2; // back
				flip_horizontal = 0;
			} else {
				// Side directions - check if it's more front-side or back-side
				if (forward_dot < 0.0) {
					sprite_direction = 3; // front_side
				} else {
					sprite_direction = 4; // back_side
				}
				flip_horizontal = (right_dot > 0.0) ? 1 : 0;
			}
		} else if (direction_mode == 3) { // EIGHT_DIRECTIONS
			// front, left, right, back, front_left, front_right, back_left, back_right - no flipping
			flip_horizontal = 0;

			// Use 8-direction calculation with 45-degree sectors
			float angle = atan(right_dot, -forward_dot); // atan2 equivalent

			// Convert angle to 0-2π range
			if (angle < 0.0) {
				angle += 6.28318530718; // 2π
			}

			// Determine direction based on angle (8 sectors of 45 degrees each)
			float sector = angle / 0.78539816339; // angle / (π/4)
			int direction_index = int(sector + 0.5) % 8;

			// Map to sprite directions: front, left, right, back, front_left, front_right, back_left, back_right
			if (direction_index == 0) {
				sprite_direction = 0; // front
			} else if (direction_index == 1) {
				sprite_direction = 4; // front_left
			} else if (direction_index == 2) {
				sprite_direction = 1; // left
			} else if (direction_index == 3) {
				sprite_direction = 6; // back_left
			} else if (direction_index == 4) {
				sprite_direction = 3; // back
			} else if (direction_index == 5) {
				sprite_direction = 7; // back_right
			} else if (direction_index == 6) {
				sprite_direction = 2; // right
			} else { // direction_index == 7
				sprite_direction = 5; // front_right
			}
		} else {
			// Default fallback for unsupported modes
			sprite_direction = 0;
			flip_horizontal = 0;
		}
}


void fragment() {
	// Calculate atlas UV coordinates
	vec2 atlas_frame_pos = vec2(
		float(current_frame) * max_sprite_size.x,
		float(sprite_direction) * max_sprite_size.y
	);

	vec2 normalized_frame_pos = atlas_frame_pos / atlas_dimensions;
	vec2 normalized_frame_size = max_sprite_size / atlas_dimensions;

	// Apply horizontal flipping if needed
	vec2 uv = UV;
	if (flip_horizontal > 0) {
		uv.x = 1.0 - uv.x;
	}

	// Sample atlas texture
	vec2 final_uv = normalized_frame_pos + (uv * normalized_frame_size);
	vec4 tex_color = texture(atlas_texture, final_uv);

	// Apply material properties
	ALBEDO = tex_color.rgb * albedo_color.rgb;
	ALPHA = tex_color.a * albedo_color.a;
}

// ------------------------------------------------------------------
// Custom lighting pass
// Makes billboard brightness depend only on distance/energy, not angle
// ------------------------------------------------------------------
void light() {
	// Distance fall-off and light energy
	float attenuation = ATTENUATION;

	// Apply light colour & energy uniformly
	DIFFUSE_LIGHT = LIGHT_COLOR.rgb * attenuation;

	// Disable specular highlights on flat sprites
	SPECULAR_LIGHT = vec3(0.0);
}
