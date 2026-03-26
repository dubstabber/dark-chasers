class_name ProceduralOverlayShapeHelper
extends RefCounted

const MAX_POLYGON_POINTS := 16


static func apply_polygon(material: ShaderMaterial, points: PackedVector2Array) -> bool:
	if material == null:
		push_warning("ProceduralOverlayShapeHelper.apply_polygon: material is null.")
		return false

	var clamped_count := mini(points.size(), MAX_POLYGON_POINTS)
	if clamped_count < 3:
		push_warning("ProceduralOverlayShapeHelper.apply_polygon: polygon requires at least 3 points.")
		return false

	var padded_points: Array[Vector2] = []
	padded_points.resize(MAX_POLYGON_POINTS)
	for i in MAX_POLYGON_POINTS:
		padded_points[i] = Vector2.ZERO
	for i in clamped_count:
		padded_points[i] = points[i]

	material.set_shader_parameter("polygon_points", padded_points)
	material.set_shader_parameter("point_count", clamped_count)
	return true


static func apply_default_arrow(material: ShaderMaterial) -> bool:
	return apply_polygon(material, get_default_arrow_points())


static func get_default_arrow_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-0.70, 0.00),
		Vector2(-0.28, 0.30),
		Vector2(-0.28, 0.14),
		Vector2(0.30, 0.14),
		Vector2(0.30, -0.14),
		Vector2(-0.28, -0.14),
		Vector2(-0.28, -0.30),
	])
