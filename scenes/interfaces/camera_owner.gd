class_name CameraOwner
extends RefCounted

## Interface for entities that own a camera (camera_3d property).
## Used for camera switching, aim point calculation, and HUD visibility.
##
## Implementers: Player
## Usage: Use CameraOwner.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node owns a camera"""
	if node == null:
		return false
	return "camera_3d" in node and node.camera_3d != null


static func get_camera(node: Node) -> Camera3D:
	"""Get the camera owned by a node. Returns null if not a camera owner."""
	if node == null or not check(node):
		return null
	return node.camera_3d


static func get_camera_position(node: Node) -> Vector3:
	"""Get the global position of the owned camera. Returns Vector3.ZERO if not available."""
	var camera = get_camera(node)
	if camera == null:
		return Vector3.ZERO
	return camera.global_position

