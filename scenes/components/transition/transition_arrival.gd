class_name TransitionArrival
extends RefCounted

## Shared helper for applying arrival position/rotation from marker-like nodes.

enum RotationMode {
	KEEP_CURRENT,
	MATCH_MARKER_YAW,
	MATCH_MARKER_FULL,
}

const ARRIVAL_ROTATION_PROPERTY := &"arrival_rotation_mode"


static func apply(target: Node3D, marker: Node3D) -> bool:
	if target == null:
		push_warning("TransitionArrival: target is null")
		return false
	if marker == null:
		push_warning("TransitionArrival: marker is null for %s" % target.name)
		return false

	target.global_position = marker.global_position

	match _get_rotation_mode(marker):
		RotationMode.KEEP_CURRENT:
			return true
		RotationMode.MATCH_MARKER_YAW:
			var target_rotation := target.global_rotation
			target_rotation.y = marker.global_rotation.y
			target.global_rotation = target_rotation
			return true
		RotationMode.MATCH_MARKER_FULL:
			target.global_rotation = marker.global_rotation
			return true
		_:
			return true


static func _get_rotation_mode(marker: Node3D) -> int:
	if not (ARRIVAL_ROTATION_PROPERTY in marker):
		return RotationMode.KEEP_CURRENT

	var mode_value: Variant = marker.get(ARRIVAL_ROTATION_PROPERTY)
	if mode_value is int and mode_value >= RotationMode.KEEP_CURRENT and mode_value <= RotationMode.MATCH_MARKER_FULL:
		return mode_value

	push_warning(
		"TransitionArrival: Invalid arrival_rotation_mode '%s' on %s; defaulting to KEEP_CURRENT"
		% [str(mode_value), marker.name]
	)
	return RotationMode.KEEP_CURRENT
