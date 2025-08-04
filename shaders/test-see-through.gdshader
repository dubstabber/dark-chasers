shader_type spatial;
render_mode depth_prepass_alpha, depth_draw_always, cull_back;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 0.5);
uniform sampler2D texture_albedo : source_color;
uniform float alpha_clip_threshold : hint_range(0, 1) = 0.5;

void fragment() {
    vec4 tex_color = texture(texture_albedo, UV);
    float final_alpha = albedo.a * tex_color.a;

    // Use alpha clipping to ensure proper depth writing
    if (final_alpha < alpha_clip_threshold) {
        discard;
    }

    ALBEDO = albedo.rgb * tex_color.rgb;
    ALPHA = final_alpha;
}