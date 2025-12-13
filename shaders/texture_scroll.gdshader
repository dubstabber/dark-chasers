// DOOM-style stepped/quantized scrolling texture shader for hazard floors/conveyors
// Texture "snaps" to discrete positions at regular intervals (classic DOOM style)

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Texture and color
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

// Scroll control uniforms
// scroll_axis: 0.0 = horizontal (U), 1.0 = vertical (V), in-between = diagonal
uniform float scroll_axis : hint_range(0.0, 1.0, 0.01) = 0.0;

// Stepped scrolling parameters (DOOM-style)
// step_size: how far the texture jumps each step (in texture units, e.g., 0.125 = 1/8th)
uniform float step_size : hint_range(0.01, 1.0, 0.01) = 0.125;
// step_rate: how often the texture steps (steps per second)
uniform float step_rate : hint_range(0.1, 60.0, 0.1) = 8.0;

// Material properties
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5;

// UV scaling for tiling
uniform vec2 uv_scale = vec2(1.0, 1.0);

void fragment() {
	// Calculate stepped/quantized scroll offset (DOOM-style)
	// floor() quantizes the time to create discrete "ticks"
	float steps_taken = floor(TIME * step_rate);
	float step_offset = steps_taken * step_size;

	// Build scroll direction from scroll_axis:
	// 0.0 -> (1, 0) horizontal, 1.0 -> (0, 1) vertical
	vec2 scroll_dir = vec2(1.0 - scroll_axis, scroll_axis);

	// Apply UV scaling and add stepped scrolling offset
	vec2 scrolled_uv = UV * uv_scale + scroll_dir * step_offset;

	// Sample texture with scrolled UVs (repeat_enable ensures seamless wrap)
	vec4 albedo_tex = texture(texture_albedo, scrolled_uv);

	// Output
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	ALPHA = albedo.a * albedo_tex.a;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
}
