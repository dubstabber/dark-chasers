shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;

uniform float scroll_axis : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform float step_size : hint_range(0.01, 1.0, 0.01) = 0.125;
uniform float step_rate : hint_range(0.1, 60.0, 0.1) = 8.0;

uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5;

uniform vec2 uv_scale = vec2(1.0, 1.0);

void fragment() {
	float steps_taken = floor(TIME * step_rate);
	float step_offset = steps_taken * step_size;
	vec2 scroll_dir = vec2(1.0 - scroll_axis, scroll_axis);
	vec2 scrolled_uv = UV * uv_scale + scroll_dir * step_offset;
	vec4 albedo_tex = texture(texture_albedo, scrolled_uv);

	ALBEDO = albedo.rgb * albedo_tex.rgb;
	ALPHA = albedo.a * albedo_tex.a;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
}
