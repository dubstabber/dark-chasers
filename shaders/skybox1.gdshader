shader_type sky;

uniform sampler2D source_panorama : filter_linear, repeat_enable, source_color, hint_default_black;
uniform float texture_width = 190.0;

// Half-sphere / dome: EYEDIR.y is up. Below horizon_cutoff_y = ground tint; at/above dome_cap_y = solid cap from texture top row.
uniform float horizon_cutoff_y : hint_range(-1.0, 0.2, 0.001) = -0.08;
uniform float dome_cap_y : hint_range(0.05, 1.0, 0.01) = 0.7;
uniform float cap_edge_softness : hint_range(0.001, 0.25, 0.001) = 0.06;
// Panorama V at eye level (y≈0); lower V samples higher on the texture strip toward zenith.
uniform float horizon_panorama_v : hint_range(0.0, 1.0, 0.001) = 0.92;

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
	
	float cap_y = max(dome_cap_y, horizon_cutoff_y + 0.001);
	
	vec3 final_color;
	
	if (eyedir.y < horizon_cutoff_y) {
		final_color = vec3(0.05, 0.05, 0.05);
	}
	else if (eyedir.y >= cap_y) {
		final_color = cap_color;
	}
	else {
		float v = horizon_panorama_v - (eyedir.y / cap_y);
		v = clamp(v, 0.001, 0.999);
		
		vec3 tex_color = texture(source_panorama, vec2(u, v)).rgb;
		float fade = max(cap_edge_softness, 1e-4);
		float cap_blend = smoothstep(cap_y - fade, cap_y, eyedir.y);
		final_color = mix(tex_color, cap_color, cap_blend);
	}
	
	COLOR = final_color;
}
