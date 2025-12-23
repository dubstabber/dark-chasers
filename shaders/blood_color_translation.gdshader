shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;


uniform vec4 blood_color : source_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform sampler2D texture_albedo : source_color, filter_nearest, hint_default_transparent;

void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	float bright = max(max(tex.r, tex.g), tex.b);
	ALBEDO = blood_color.rgb * bright;
	ALPHA = tex.a;
}
