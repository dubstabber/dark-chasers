shader_type spatial;

uniform sampler2D albedo: source_color;
uniform float distortion: hint_range(0.0,1.0);
uniform vec2 time_scale = vec2(1.0,1.0);



void fragment() {
	vec2 uv = UV * 0.4;
	vec2 wavesoffset = vec2(
		cos(TIME * time_scale.x + (uv.x + uv.y)*2.0),
		sin(TIME * time_scale.y + (uv.x + uv.y)*1.0)
	);
	ALBEDO = texture(albedo, uv + wavesoffset * distortion).rgb;
	//ALPHA *= albedo.a * albedo_tex.a;
}
