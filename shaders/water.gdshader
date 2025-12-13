shader_type spatial;
// Animated water shader with wave distortion
// Use this as the PRIMARY material on a mesh (not as next_pass)
// This shader distorts the texture UV coordinates to create a wave animation effect

// Render modes for transparent rendering with lighting
// - blend_mix: Standard alpha blending
// - depth_prepass_alpha: Allows proper depth sorting for transparency
// - cull_back: Standard backface culling
render_mode blend_mix, depth_prepass_alpha, cull_back;

// The texture to apply wave distortion to (assign your material's albedo texture here)
uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_enable;

// Controls the intensity of the wave distortion effect (0 = no distortion, 1 = max)
uniform float distortion : hint_range(0.0, 1.0) = 0.1;

// Speed and direction multipliers for the wave animation
uniform vec2 time_scale = vec2(1.0, 1.0);

// Controls the strength of the distortion effect (0 = no effect, 1 = full effect)
// This allows runtime control of distortion intensity without changing the distortion amount
uniform float effect_strength : hint_range(0.0, 1.0) = 1.0;

// Tint color multiplied with the texture
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// UV tiling for the texture
uniform vec2 uv_scale = vec2(1.0, 1.0);

// PBR properties (to match StandardMaterial3D functionality)
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform float specular : hint_range(0.0, 1.0) = 0.5;

// Optional normal map for surface detail
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform bool use_normal_map = false;


void fragment() {
	// Scale UVs for tiling control
	vec2 scaled_uv = UV * uv_scale;

	// Wave offset computation (matches water-old.gdshader)
	vec2 wavesoffset = vec2(
		cos(TIME * time_scale.x + (scaled_uv.x + scaled_uv.y) * 0.5),
		sin(TIME * time_scale.y + (scaled_uv.x + scaled_uv.y) * 2.0)
	);

	// Apply distortion to the UV coordinates, scaled by effect_strength
	// This distorts the texture sampling itself, making the texture appear to wobble
	vec2 distorted_uv = scaled_uv + wavesoffset * distortion * effect_strength;

	// Sample the texture with distorted UVs
	vec4 albedo_color = texture(albedo, distorted_uv);

	// Apply tint (rgb for color, alpha for transparency)
	ALBEDO = albedo_color.rgb * tint.rgb;

	// Alpha: combine texture alpha with tint alpha for full transparency control
	ALPHA = albedo_color.a * tint.a;

	// PBR properties
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;

	// Optional normal map (also distorted for consistent wave effect)
	if (use_normal_map) {
		vec3 normal = texture(normal_map, distorted_uv).rgb;
		normal = normalize(normal * 2.0 - 1.0);
		normal.xy *= normal_strength;
		NORMAL_MAP = normalize(normal) * 0.5 + 0.5;
	}
}
