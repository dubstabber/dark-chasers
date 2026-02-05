class_name Aimable
extends RefCounted

## Interface for entities that can be aimed at.
## Classes implementing this should have a get_aim_point() method.
##
## Usage: Use Aimable.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node implements the Aimable interface"""
	return node != null and node.has_method("get_aim_point")


static func get_aim_point(node: Node) -> Vector3:
	"""Get the aim point for a node, falls back to global_position + offset if not implemented"""
	if node == null:
		return Vector3.ZERO
	if check(node):
		return node.get_aim_point()
	# Fallback: use CameraOwner interface for camera position
	var camera_pos = CameraOwner.get_camera_position(node)
	if camera_pos != Vector3.ZERO:
		return camera_pos
	# Default fallback: head height offset
	return node.global_position + Vector3(0, 1.6, 0)
