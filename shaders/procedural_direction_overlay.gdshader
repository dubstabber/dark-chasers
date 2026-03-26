shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

const int MAX_POLYGON_POINTS = 16;
const float EPSILON = 0.00001;

uniform int point_count : hint_range(3, 16) = 7;
uniform vec2 polygon_points[MAX_POLYGON_POINTS];

uniform vec2 shape_scale = vec2(1.0, 1.0);
uniform vec2 shape_offset = vec2(0.0, 0.0);
uniform float shape_rotation : hint_range(-3.14159, 3.14159) = 0.0;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.45;
uniform float edge_softness : hint_range(0.001, 0.4) = 0.08;
uniform float center_falloff : hint_range(0.0, 2.0) = 0.25;
uniform float glow_boost : hint_range(0.0, 5.0) = 1.8;

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.32;
uniform float scanline_density : hint_range(1.0, 120.0) = 40.0;
uniform float drift_speed : hint_range(-4.0, 4.0) = 0.45;


float distance_to_segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	float denom = max(dot(ab, ab), EPSILON);
	float t = clamp(dot(p - a, ab) / denom, 0.0, 1.0);
	return length(p - (a + ab * t));
}


bool point_in_polygon(vec2 p, int active_count) {
	bool inside = false;
	vec2 previous = polygon_points[active_count - 1];

	for (int i = 0; i < MAX_POLYGON_POINTS; i++) {
		if (i >= active_count) {
			break;
		}

		vec2 current = polygon_points[i];
		bool intersects = ((current.y > p.y) != (previous.y > p.y))
			&& (p.x < (previous.x - current.x) * (p.y - current.y) / ((previous.y - current.y) + EPSILON) + current.x);
		if (intersects) {
			inside = !inside;
		}
		previous = current;
	}

	return inside;
}


float polygon_edge_distance(vec2 p, int active_count) {
	float min_distance = 1e8;
	vec2 previous = polygon_points[active_count - 1];

	for (int i = 0; i < MAX_POLYGON_POINTS; i++) {
		if (i >= active_count) {
			break;
		}

		vec2 current = polygon_points[i];
		min_distance = min(min_distance, distance_to_segment(p, previous, current));
		previous = current;
	}

	return min_distance;
}


void fragment() {
	int active_count = clamp(point_count, 3, MAX_POLYGON_POINTS);

	vec2 p = UV * 2.0 - 1.0;
	p -= shape_offset;

	if (abs(shape_rotation) > EPSILON) {
		float cs = cos(shape_rotation);
		float sn = sin(shape_rotation);
		p = vec2(
			p.x * cs - p.y * sn,
			p.x * sn + p.y * cs
		);
	}
	p /= max(shape_scale, vec2(EPSILON));

	bool inside = point_in_polygon(p, active_count);
	float edge_distance = polygon_edge_distance(p, active_count);
	float signed_distance = inside ? -edge_distance : edge_distance;
	float shape_mask = 1.0 - smoothstep(0.0, edge_softness, signed_distance);

	float radial = length(p);
	float center_mask = 1.0 - center_falloff * smoothstep(0.0, 1.15, radial);
	center_mask = clamp(center_mask, 0.0, 1.0);

	float scan_wave = 0.5 + 0.5 * sin((UV.y + TIME * drift_speed) * scanline_density * TAU);
	float sweep_wave = 0.5 + 0.5 * sin((UV.x * 0.35 - UV.y + TIME * drift_speed * 0.5) * scanline_density * 0.35 * TAU);
	float stripe_mod = mix(1.0, 0.82 + scan_wave * 0.26 + sweep_wave * 0.10, scanline_strength);

	float alpha = shape_mask * center_mask * opacity * stripe_mod;
	alpha = clamp(alpha * base_color.a, 0.0, 1.0);

	vec3 lit_color = base_color.rgb * (0.82 + scan_wave * 0.18);
	ALBEDO = lit_color * 0.06;
	EMISSION = lit_color * (glow_boost + scan_wave * 0.25) * alpha;
	ALPHA = alpha;
}
