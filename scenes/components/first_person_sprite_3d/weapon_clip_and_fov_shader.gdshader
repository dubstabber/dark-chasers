// Sprite3D Weapon Shader with FOV control and wall clipping prevention
// Optimized for weapon sprites that need to maintain visibility and proper FOV

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// Main texture control (will be automatically set from Sprite3D properties)
uniform sampler2D texture_albedo : source_color;

// Sprite3D integration - these will sync with Sprite3D properties
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.0;
uniform float alpha_cut_threshold : hint_range(0.0, 1.0) = 0.5;
uniform bool use_sprite3d_shaded = true;
uniform int texture_filter_mode : hint_range(0, 5) = 1;
uniform bool has_texture = false;

// FOV and positioning controls
uniform float viewmodel_fov : hint_range(30.0, 120.0) = 70.0;
uniform float weapon_distance : hint_range(0.1, 2.0) = 0.5;
uniform vec2 weapon_offset = vec2(0.0, 0.0);

// Wall clipping prevention
uniform float clip_prevention_strength : hint_range(0.0, 1.0) = 0.9;
uniform bool enable_depth_override = true;

// Environmental lighting controls (since you want 3D lighting)
uniform float lighting_influence : hint_range(0.0, 1.0) = 1.0;
uniform vec4 ambient_light_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);

// UV controls
uniform vec3 uv1_scale = vec3(1.0, 1.0, 1.0);
uniform vec3 uv1_offset = vec3(0.0, 0.0, 0.0);

void vertex() {
	// Apply UV transformations
	UV = UV * uv1_scale.xy + uv1_offset.xy;

	// Apply weapon positioning offset
	vec3 modified_vertex = VERTEX;
	modified_vertex.xy += weapon_offset * weapon_distance;

	/* SPRITE3D WEAPON FOV AND CLIPPING CONTROL */
	if (viewmodel_fov > 0.0) {
		// Calculate FOV-based projection matrix modifications
		float fov_rad = viewmodel_fov * PI / 180.0;
		float onetanfov = 1.0 / tan(0.5 * fov_rad);
		float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;

		// Modify projection matrix for custom weapon FOV
		PROJECTION_MATRIX[1][1] = -onetanfov;
		PROJECTION_MATRIX[0][0] = onetanfov / aspect;
	}

	// Transform vertex to clip space
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(modified_vertex, 1.0);

	/* WALL CLIPPING PREVENTION FOR SPRITE3D WEAPONS */
	if (enable_depth_override) {
		// For Godot 4.3+ with reversed Z-buffer:
		// Mix Z towards POSITION.w so after perspective division it approaches 1.0 (near plane)
		// This prevents weapons from clipping through walls when player looks at them
		POSITION.z = mix(POSITION.z, POSITION.w, clip_prevention_strength);
	}

	// Store original vertex position for lighting calculations in fragment shader
	VERTEX = modified_vertex;
}

// POSITION.xyz = POSITION.xyz / POSITION.w;

void fragment() {
	vec2 base_uv = UV;

	// Sample texture with proper filtering to prevent white borders
	vec4 albedo_tex;

	// If texture isn't bound yet (e.g. editor before script runs), avoid drawing the quad.
	if (!has_texture) {
		ALPHA = 0.0;
		discard;
	}

	if (texture_filter_mode == 0) {
		// Nearest filtering - use texelFetch for pixel-perfect sampling
		ivec2 tex_size = textureSize(texture_albedo, 0);
		ivec2 pixel_coord = ivec2(base_uv * vec2(tex_size));
		pixel_coord = clamp(pixel_coord, ivec2(0), tex_size - ivec2(1));
		albedo_tex = texelFetch(texture_albedo, pixel_coord, 0);
	} else {
		// Linear filtering - use standard texture sampling
		albedo_tex = texture(texture_albedo, base_uv);
	}

	// Set alpha from texture
	ALPHA = albedo_tex.a;

	// Always discard fully transparent pixels to avoid drawing background quad
	if (albedo_tex.a < 0.01) {
		discard;
	}
	// Optional alpha cut for masked transparency
	if (alpha_cut > 0.0 && albedo_tex.a < alpha_cut_threshold) {
		discard;
	}

	// Set basic material properties
	METALLIC = 0.0;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;

	// Apply lighting based on Sprite3D shaded property
	if (use_sprite3d_shaded) {
		// Shaded mode - blend between lit and unlit using lighting_influence
		// When lighting_influence = 1.0 -> fully lit by scene lights
		// When lighting_influence = 0.0 -> fully unlit (pure emission)
		ALBEDO = albedo_tex.rgb * lighting_influence;
		EMISSION = albedo_tex.rgb * (1.0 - lighting_influence);
		// ALPHA already set earlier
	} else {
		// Unshaded mode - use emission for pure texture display
		EMISSION = albedo_tex.rgb;
		ALBEDO = vec3(0.0);
		// ALPHA already set earlier
	}
}

void light() {
	// Two-sided, rotation-independent diffuse lighting for first-person sprite
	// Use a constant camera-facing normal in view space so sprite rotation does not affect lighting
	vec3 N = vec3(0.0, 0.0, 1.0);
	vec3 L = normalize(LIGHT);
	// Symmetric response: front or back receives the same intensity
	float ndl = abs(dot(N, L));
	DIFFUSE_LIGHT += ndl * ATTENUATION * LIGHT_COLOR / PI;
}
