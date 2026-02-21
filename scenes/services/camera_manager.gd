class_name CameraManager
extends Node

## Centralized camera management service.
## Provides event-driven camera switching instead of per-frame polling.
##
## Usage:
##   - Access via Services.camera_manager (owned/created by Services singleton)
##   - Call set_active_camera() to switch cameras
##   - Listen to active_camera_changed signal for visibility updates

signal active_camera_changed(new_camera: Camera3D)

var _active_camera: Camera3D = null
var _debug_camera: Camera3D = null
var _player_camera: Camera3D = null


func get_active_camera() -> Camera3D:
	return _active_camera


func set_debug_camera(camera: Camera3D) -> void:
	_debug_camera = camera


func set_player_camera(camera: Camera3D) -> void:
	_player_camera = camera


func toggle_debug_camera() -> bool:
	"""Toggle between debug and player camera. Returns true if debug camera is now active."""
	if not _debug_camera or not _player_camera:
		return false
	
	if _active_camera == _debug_camera:
		set_active_camera(_player_camera)
		return false
	else:
		set_active_camera(_debug_camera)
		return true


func set_active_camera(camera: Camera3D) -> void:
	if camera == _active_camera:
		return
	
	_active_camera = camera
	if camera:
		camera.make_current()
	active_camera_changed.emit(camera)


func is_camera_active(camera: Camera3D) -> bool:
	return camera == _active_camera


func register_camera(camera: Camera3D) -> void:
	"""Register a camera and set it as active if it's marked as current."""
	if camera.current:
		_active_camera = camera
		active_camera_changed.emit(camera)
