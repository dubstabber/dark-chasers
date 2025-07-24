shader_type spatial;
// Invisible volume that writes depth to occlude everything behind it.
render_mode unshaded, depth_draw_always, cull_disabled, blend_mix;

void fragment() {
    // Transparent colour so the mesh itself is invisible
    ALBEDO = vec3(0.0);
    ALPHA = 0.0;
}