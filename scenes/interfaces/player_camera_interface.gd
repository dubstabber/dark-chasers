class_name PlayerCameraInterface
extends RefCounted

## Interface for player camera functionality.
## Used by PlayerDeathComponent for death camera effects.
##
## Implementers: PlayerCamera
## Usage: Use PlayerCameraInterface methods for camera death effects.

static func check(node: Node) -> bool:
	"""Check if a node implements the player camera interface"""
	if node == null:
		return false
	# Check for the key methods that define a player camera
	return node.has_method("orient_toward_position") or \
		   node.has_method("apply_death_camera_lowering") or \
		   node.has_method("center_pitch")


static func orient_toward_position(camera: Node, target_pos: Vector3, delta: float) -> bool:
	"""
	Orient the camera toward a target position.
	Returns true if the method was called, false if not supported.
	"""
	if camera == null or not camera.has_method("orient_toward_position"):
		return false
	camera.orient_toward_position(target_pos, delta)
	return true


static func apply_death_camera_lowering(camera: Node, delta: float) -> bool:
	"""
	Apply death camera lowering effect.
	Returns true if the method was called, false if not supported.
	"""
	if camera == null or not camera.has_method("apply_death_camera_lowering"):
		return false
	camera.apply_death_camera_lowering(delta)
	return true


static func center_pitch(camera: Node) -> bool:
	"""
	Center the camera pitch (for fall deaths).
	Returns true if the method was called, false if not supported.
	"""
	if camera == null or not camera.has_method("center_pitch"):
		return false
	camera.center_pitch()
	return true


static func reset_camera(camera: Node) -> bool:
	"""
	Reset the camera to default state.
	Returns true if the method was called, false if not supported.
	"""
	if camera == null or not camera.has_method("reset_camera"):
		return false
	camera.reset_camera()
	return true


static func set_sprint_fov(camera: Node, is_sprinting: bool) -> bool:
	"""
	Set the camera FOV for sprinting.
	Returns true if the method was called, false if not supported.
	"""
	if camera == null or not camera.has_method("set_sprint_fov"):
		return false
	camera.set_sprint_fov(is_sprinting)
	return true

