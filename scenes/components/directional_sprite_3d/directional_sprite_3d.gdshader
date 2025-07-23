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
uniform bool debug_mode = false;

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

		// Get target's local axes (Godot uses -Z as forward, X as right)
		vec3 target_forward = -normalize(MODEL_MATRIX[2].xyz); // Negate because Godot's Z is backwards
		vec3 target_right = normalize(MODEL_MATRIX[0].xyz);

		float forward_dot = dot(target_forward, to_camera);
		float right_dot = dot(target_right, to_camera);

		// Calculate 8-sector direction index for modes that need it
		float angle = atan(right_dot, forward_dot); // atan2 equivalent
		if (angle < 0.0) {
			angle += 6.28318530718; // 2π
		}
		float sector = angle / 0.78539816339; // angle / (π/4)
		int direction_index = int(sector + 0.5) % 8;

		// Direction calculation based on mode
		if (direction_mode == 0) { // THREE_DIRECTIONS
			// Uses 4 angular sectors like 4-directional, but maps left/right to "side" with flipping
			if (abs(forward_dot) > abs(right_dot)) {
				// Front/back dominant
				if (forward_dot > 0.0) {
					sprite_direction = 0; // front
					flip_horizontal = 0;
				} else {
					sprite_direction = 2; // back
					flip_horizontal = 0;
				}
			} else {
				// Left/right becomes "side" with flipping
				sprite_direction = 1; // side
				flip_horizontal = (right_dot > 0.0) ? 1 : 0; // flip for right side
			}
		} else if (direction_mode == 1) { // FOUR_DIRECTIONS
			// Uses 4 angular sectors with 4 separate sprites
			flip_horizontal = 0;
			if (abs(forward_dot) > abs(right_dot)) {
				// Front/back dominant
				if (forward_dot > 0.0) {
					sprite_direction = 0; // front
				} else {
					sprite_direction = 3; // back
				}
			} else {
				// Left/right
				if (right_dot > 0.0) {
					sprite_direction = 2; // right
				} else {
					sprite_direction = 1; // left
				}
			}
		} else if (direction_mode == 2) { // FIVE_DIRECTIONS
			// Uses 8 angular sectors like 8-directional, but maps diagonals to front-side/back-side with flipping
			if (direction_index == 0) {
				sprite_direction = 0; // front
				flip_horizontal = 0;
			} else if (direction_index == 1) {
				sprite_direction = 3; // front_side (left)
				flip_horizontal = 0;
			} else if (direction_index == 2) {
				sprite_direction = 1; // side (left)
				flip_horizontal = 0;
			} else if (direction_index == 3) {
				sprite_direction = 4; // back_side (left)
				flip_horizontal = 0;
			} else if (direction_index == 4) {
				sprite_direction = 2; // back
				flip_horizontal = 0;
			} else if (direction_index == 5) {
				sprite_direction = 4; // back_side (right, flipped)
				flip_horizontal = 1;
			} else if (direction_index == 6) {
				sprite_direction = 1; // side (right, flipped)
				flip_horizontal = 1;
			} else { // direction_index == 7
				sprite_direction = 3; // front_side (right, flipped)
				flip_horizontal = 1;
			}
		} else if (direction_mode == 3) { // EIGHT_DIRECTIONS
			// Uses the same 8 angular sectors as calculated above
			flip_horizontal = 0;

			// Map to sprite directions: front(0), left(1), right(2), back(3), front_left(4), front_right(5), back_left(6), back_right(7)
			if (direction_index == 0) {
				sprite_direction = 0; // front
			} else if (direction_index == 1) {
				sprite_direction = 5; // front_right
			} else if (direction_index == 2) {
				sprite_direction = 2; // right
			} else if (direction_index == 3) {
				sprite_direction = 7; // back_right
			} else if (direction_index == 4) {
				sprite_direction = 3; // back
			} else if (direction_index == 5) {
				sprite_direction = 6; // back_left
			} else if (direction_index == 6) {
				sprite_direction = 1; // left
			} else { // direction_index == 7
				sprite_direction = 4; // front_left
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

	// Debug mode: color-code directions
	if (debug_mode) {
		vec3 debug_color;
		if (sprite_direction == 0) debug_color = vec3(1.0, 0.0, 0.0); // front = red
		else if (sprite_direction == 1) debug_color = vec3(0.0, 1.0, 0.0); // side/left = green
		else if (sprite_direction == 2) debug_color = vec3(0.0, 0.0, 1.0); // back/right = blue
		else if (sprite_direction == 3) debug_color = vec3(1.0, 1.0, 0.0); // back/front_side = yellow
		else if (sprite_direction == 4) debug_color = vec3(1.0, 0.0, 1.0); // front_left/back_side = magenta
		else if (sprite_direction == 5) debug_color = vec3(0.0, 1.0, 1.0); // front_right = cyan
		else if (sprite_direction == 6) debug_color = vec3(0.5, 0.5, 0.5); // back_left = gray
		else debug_color = vec3(1.0, 1.0, 1.0); // back_right = white

		ALBEDO = debug_color;
		ALPHA = 1.0;
	} else {
		// Apply material properties
		ALBEDO = tex_color.rgb * albedo_color.rgb;
		ALPHA = tex_color.a * albedo_color.a;
	}
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
