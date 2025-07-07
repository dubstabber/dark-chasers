
// NOTE: Shader automatically converted from Godot Engine 4.2.stable's PanoramaSkyMaterial.

shader_type sky;
uniform float horizon_height;
uniform sampler2D source_panorama : filter_linear, source_color, hint_default_black;

void sky() {
	vec3 eyedir = normalize(EYEDIR);
    if (eyedir.y > horizon_height) {
        float phi = acos(eyedir.y);
        float theta = atan(eyedir.z, eyedir.x);

        float vertical_scale = 0.48 - horizon_height;
        vec2 uv = vec2(theta / (2.0 * PI), phi * vertical_scale / (0.5 * PI));
		COLOR = texture(source_panorama, uv).rgb;
    } else {
        COLOR = vec3(0.54, 0.42, 0.32); // Sky color below horizon (optional)
    }
	//COLOR = texture(source_panorama, SKY_COORDS).rgb;
}
