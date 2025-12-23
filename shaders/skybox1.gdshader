shader_type sky;

uniform sampler2D source_panorama : filter_linear, repeat_enable, source_color, hint_default_black;
uniform float texture_width = 190.0;

void sky() {
	vec3 eyedir = normalize(EYEDIR);
	
	float times_repeat = floor(4.0 * (256.0 / texture_width));
	if (times_repeat < 1.0) times_repeat = 1.0;
	
	// Calculate horizontal angle (theta) for cylindrical mapping
	float theta = atan(eyedir.z, eyedir.x);
	float u = (theta / (2.0 * PI)) * times_repeat;
	
	// Get cap color from top row of texture (sample once)
	vec3 cap_color = (
		texture(source_panorama, vec2(0.125, 0.001)).rgb +
		texture(source_panorama, vec2(0.375, 0.001)).rgb +
		texture(source_panorama, vec2(0.625, 0.001)).rgb +
		texture(source_panorama, vec2(0.875, 0.001)).rgb
	) * 0.25;
	
	// Cap threshold - texture ends here, solid cap above
	// Value of 1.0 means texture goes all the way to the zenith
	float cap_threshold = 0.7;
	
	vec3 final_color;
	
	if (eyedir.y < -0.08) {
		// Below horizon (lower hemisphere): dark blue-gray
		final_color = vec3(0.05, 0.05, 0.05);
	}
	else if (eyedir.y >= cap_threshold) {
		// Above cap threshold: solid cap color (no hole possible)
		final_color = cap_color;
	}
	else {
		// Textured region: from horizon (y=0) up to cap_threshold
		// Map so that: horizon -> v=1 (bottom of texture), cap_threshold -> v=0 (top of texture)
		float v = 0.92 - (eyedir.y / cap_threshold);
		// Clamp v to avoid any edge issues
		v = clamp(v, 0.001, 0.999);
		
		vec3 tex_color = texture(source_panorama, vec2(u, v)).rgb;
		float cap_fade = 0.06;
		float cap_blend = smoothstep(cap_threshold - cap_fade, cap_threshold, eyedir.y);
		final_color = mix(tex_color, cap_color, cap_blend);
	}
	
	COLOR = final_color;
}
