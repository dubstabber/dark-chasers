class_name WeatherRainAudioZone
extends Area3D

enum RainAudioTier {
	RAIN_LOUD,
	RAIN_MEDIUM,
	RAIN_LOW,
	RAIN_NONE,
}

@export var enabled := true
@export_enum("rain_loud", "rain_medium", "rain_low", "rain_none") var rain_audio_tier: int = RainAudioTier.RAIN_MEDIUM
@export var debug_label := ""

var _warned_unsupported_shape := false


func contains_listener_position(world_position: Vector3) -> bool:
	if not enabled:
		return false

	var collision_shape := _get_primary_collision_shape()
	if collision_shape == null or collision_shape.disabled or collision_shape.shape == null:
		return false

	var shape_transform := _get_node_world_transform(collision_shape)
	var local_point := shape_transform.affine_inverse() * world_position
	return _shape_contains_local_point(collision_shape.shape, local_point)


func get_zone_priority() -> int:
	return priority


func get_rain_audio_tier_name() -> StringName:
	match rain_audio_tier:
		RainAudioTier.RAIN_LOUD:
			return &"rain_loud"
		RainAudioTier.RAIN_LOW:
			return &"rain_low"
		RainAudioTier.RAIN_NONE:
			return &"rain_none"
		_:
			return &"rain_medium"


func _get_primary_collision_shape() -> CollisionShape3D:
	for child in get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


func _get_node_world_transform(node_3d: Node3D) -> Transform3D:
	if node_3d.is_inside_tree():
		return node_3d.global_transform

	var world_transform := node_3d.transform
	var current := node_3d.get_parent()
	while current is Node3D:
		world_transform = (current as Node3D).transform * world_transform
		current = current.get_parent()
	return world_transform


func _shape_contains_local_point(shape: Shape3D, local_point: Vector3) -> bool:
	if shape is BoxShape3D:
		var box_shape := shape as BoxShape3D
		var half_size := box_shape.size * 0.5
		return absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y and absf(local_point.z) <= half_size.z
	if shape is SphereShape3D:
		var sphere_shape := shape as SphereShape3D
		return local_point.length_squared() <= sphere_shape.radius * sphere_shape.radius
	if not _warned_unsupported_shape:
		_warned_unsupported_shape = true
		push_warning("WeatherRainAudioZone supports BoxShape3D and SphereShape3D volumes in v1: %s" % name)
	return false
