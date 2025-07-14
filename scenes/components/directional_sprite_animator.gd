class_name DirectionalSpriteAnimator extends Node

## A reusable component for animating sprites based on camera viewing angle
## Supports both 4-directional and 8-directional sprite animation with equal angle segments

signal sprite_changed(new_sprite_name: String)

enum DirectionMode {
	FOUR_DIRECTIONAL, ## 4 directions: front, right, back, left (90° segments)
	EIGHT_DIRECTIONAL, ## 8 directions: front, front-right, right, back-right, back, back-left, left, front-left (45° segments)
	EIGHT_DIRECTIONAL_WITH_FLIPPING ## 8 directions using 5 sprites with horizontal flipping: front, front-side, side, back-side, back (45° segments)
}

@export_group("Configuration")
@export var sprite_node_path: NodePath
@export var reference_node_path: NodePath
@export var direction_mode: DirectionMode = DirectionMode.EIGHT_DIRECTIONAL
@export var sprite_names: Array[String] = ["front", "front-right", "right", "back-right", "back", "back-left", "left", "front-left"]
@export var enabled := true

@export_group("Performance")
@export var max_update_distance := 25.0
@export var close_update_interval := 0.05
@export var far_update_interval := 0.2
@export var close_distance_threshold := 10.0
@export var always_check_camera := false ## If true, checks for camera changes every frame (more responsive but less performant)

var _sprite_node: Node
var _reference_node: Node3D
var _cached_camera: Camera3D
var _cached_camera_id: int = -1 # Track camera instance ID for change detection
var _last_segment := -1
var _update_timer := 0.0
var _update_interval := 0.1
var _current_sprite_name := ""
var _current_flip_h := false # Track current horizontal flip state

func _ready():
	_initialize_nodes()
	_validate_sprite_configuration()

func _process(delta):
	if not enabled:
		return
		
	_update_timer += delta
	if _update_timer >= _update_interval:
		_update_timer = 0.0
		_update_sprite_animation()

func _initialize_nodes():
	if sprite_node_path.is_empty():
		_sprite_node = get_parent().get_node_or_null("AnimatedSprite3D")
		if not _sprite_node:
			_sprite_node = get_parent().get_node_or_null("Sprite3D")
	else:
		_sprite_node = get_node(sprite_node_path)
	
	if reference_node_path.is_empty():
		_reference_node = get_parent()
	else:
		_reference_node = get_node(reference_node_path)
	
	if not _sprite_node:
		push_error("DirectionalSpriteAnimator: No sprite node found")
	if not _reference_node:
		push_error("DirectionalSpriteAnimator: No reference node found")

func _validate_sprite_configuration():
	var expected_count = _get_expected_sprite_count()

	if sprite_names.size() != expected_count:
		push_warning("DirectionalSpriteAnimator: Expected %d sprite names for %s mode, but got %d. Using default names." % [
			expected_count,
			"4-directional" if direction_mode == DirectionMode.FOUR_DIRECTIONAL else "8-directional",
			sprite_names.size()
		])
		sprite_names = _get_default_sprite_names()

func _get_expected_sprite_count() -> int:
	match direction_mode:
		DirectionMode.FOUR_DIRECTIONAL:
			return 4
		DirectionMode.EIGHT_DIRECTIONAL:
			return 8
		DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING:
			return 5 # front, front-side, side, back-side, back
		_:
			return 8

func _get_default_sprite_names() -> Array[String]:
	match direction_mode:
		DirectionMode.FOUR_DIRECTIONAL:
			return ["front", "right", "back", "left"]
		DirectionMode.EIGHT_DIRECTIONAL:
			return ["front", "front-right", "right", "back-right", "back", "back-left", "left", "front-left"]
		DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING:
			return ["front", "front-side", "side", "back-side", "back"]
		_:
			return ["front", "front-right", "right", "back-right", "back", "back-left", "left", "front-left"]

func _update_sprite_animation():
	# Smart camera detection - handle dynamic camera changes
	var current_camera: Camera3D
	var camera_changed = false

	if always_check_camera:
		# Always get current camera for maximum responsiveness
		current_camera = get_viewport().get_camera_3d()
		if current_camera and current_camera != _cached_camera:
			_cached_camera = current_camera
			_cached_camera_id = current_camera.get_instance_id() if current_camera else -1
			camera_changed = true
	else:
		# Use cached camera with change detection for better performance
		current_camera = get_viewport().get_camera_3d()

		if current_camera:
			var current_camera_id = current_camera.get_instance_id()

			if not _cached_camera or not is_instance_valid(_cached_camera) or _cached_camera_id != current_camera_id:
				_cached_camera = current_camera
				_cached_camera_id = current_camera_id
				camera_changed = true
		else:
			_cached_camera = null
			_cached_camera_id = -1

	if not _cached_camera or not _reference_node:
		return

	# Force sprite update when camera changes for immediate response
	if camera_changed:
		_last_segment = -1

	var distance_to_camera = _reference_node.global_position.distance_to(_cached_camera.global_position)
	
	if distance_to_camera > max_update_distance:
		return

	_update_interval = close_update_interval if distance_to_camera < close_distance_threshold else far_update_interval
	
	var segment = _calculate_viewing_segment(_cached_camera)
	
	if segment == _last_segment:
		return
	
	_last_segment = segment
	
	if segment >= 0:
		match direction_mode:
			DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING:
				_handle_sprite_flipping_8_directional(segment)
			_:
				if segment < sprite_names.size():
					var new_sprite_name = sprite_names[segment]
					_set_sprite_animation(new_sprite_name)

func _calculate_viewing_segment(camera: Camera3D) -> int:
	var ref_pos = _reference_node.global_position
	var camera_pos = camera.global_position

	# Calculate horizontal direction vector from object to camera
	var dx = camera_pos.x - ref_pos.x
	var dz = camera_pos.z - ref_pos.z

	# Handle edge case where camera is at same horizontal position
	if abs(dx) < 0.001 and abs(dz) < 0.001:
		return 0 # Default to front

	# Get the object's local coordinate system
	var ref_basis = _reference_node.global_transform.basis
	var object_forward = - ref_basis.z # Object's forward direction (negative Z)
	var object_right = ref_basis.x # Object's right direction (positive X)

	# Calculate the angle from object's perspective to camera
	var forward_component = object_forward.x * dx + object_forward.z * dz
	var right_component = object_right.x * dx + object_right.z * dz

	# Get angle in radians (-PI to PI)
	var angle_radians = atan2(right_component, forward_component)

	# Convert to degrees for easier calculation
	var angle_degrees = rad_to_deg(angle_radians)

	# Normalize to 0-360 range
	if angle_degrees < 0:
		angle_degrees += 360

	# Calculate segment based on direction mode
	if direction_mode == DirectionMode.FOUR_DIRECTIONAL:
		return _calculate_4_directional_segment(angle_degrees)
	else:
		return _calculate_8_directional_segment(angle_degrees)

func _calculate_4_directional_segment(angle_degrees: float) -> int:
	# 4-directional: 90-degree segments
	# front: 315° - 45° (wraps around 0°)
	# right: 45° - 135°
	# back: 135° - 225°
	# left: 225° - 315°
	# Add 45 degrees offset so front is centered at 0°
	var adjusted_angle = angle_degrees + 45.0
	if adjusted_angle >= 360:
		adjusted_angle -= 360

	# Divide by 90 to get segment (0-3.99...)
	var segment = int(adjusted_angle / 90.0)

	# Ensure we stay in 0-3 range
	return segment % 4

func _calculate_8_directional_segment(angle_degrees: float) -> int:
	# 8-directional: 45-degree segments
	# Same logic as before but kept separate for clarity
	# Add 22.5 degrees offset so front is centered at 0°
	var adjusted_angle = angle_degrees + 22.5
	if adjusted_angle >= 360:
		adjusted_angle -= 360

	# Divide by 45 to get segment (0-7.99...)
	var segment = int(adjusted_angle / 45.0)

	# Ensure we stay in 0-7 range
	return segment % 8

func _handle_sprite_flipping_8_directional(segment: int):
	# Map 8 segments to 5 sprite names with flipping
	# Segments: 0=front, 1=front-right, 2=right, 3=back-right, 4=back, 5=back-left, 6=left, 7=front-left
	# Sprite mapping with flipping:
	# 0: front (no flip)
	# 1: front-side (no flip)
	# 2: side (no flip)
	# 3: back-side (no flip)
	# 4: back (no flip)
	# 5: back-side (flip)
	# 6: side (flip)
	# 7: front-side (flip)
	var sprite_index: int
	var flip_h: bool = false

	match segment:
		0: # front
			sprite_index = 0
		1: # front-right -> front-side
			sprite_index = 1
		2: # right -> side
			sprite_index = 2
		3: # back-right -> back-side
			sprite_index = 3
		4: # back
			sprite_index = 4
		5: # back-left -> back-side (flipped)
			sprite_index = 3
			flip_h = true
		6: # left -> side (flipped)
			sprite_index = 2
			flip_h = true
		7: # front-left -> front-side (flipped)
			sprite_index = 1
			flip_h = true

	if sprite_index < sprite_names.size():
		var sprite_name = sprite_names[sprite_index]
		_set_sprite_animation(sprite_name, flip_h)


func _set_sprite_animation(sprite_name: String, flip_h: bool = false):
	if _current_sprite_name == sprite_name and _current_flip_h == flip_h:
		return

	_current_sprite_name = sprite_name
	_current_flip_h = flip_h

	if _sprite_node.has_method("play"):
		if _sprite_node.animation != sprite_name:
			_sprite_node.play(sprite_name)
	elif _sprite_node.has_method("set_texture"):
		push_warning("DirectionalSpriteAnimator: Sprite3D texture switching not implemented")

	# Apply horizontal flipping if the sprite node supports it
	if "flip_h" in _sprite_node:
		_sprite_node.flip_h = flip_h

	sprite_changed.emit(sprite_name)

func set_enabled(value: bool):
	enabled = value

func get_current_sprite_name() -> String:
	return _current_sprite_name

func force_update():
	_last_segment = -1
	_update_sprite_animation()

## Call this when you know the camera has changed for immediate response
func on_camera_changed():
	_cached_camera = null
	_cached_camera_id = -1
	_last_segment = -1
	_update_sprite_animation()

## Get the currently tracked camera (useful for debugging)
func get_current_camera() -> Camera3D:
	return _cached_camera

## Configure the component for 4-directional mode with default sprite names
func setup_4_directional(custom_sprite_names: Array[String] = []):
	direction_mode = DirectionMode.FOUR_DIRECTIONAL
	if custom_sprite_names.is_empty():
		sprite_names = _get_default_sprite_names()
	else:
		sprite_names = custom_sprite_names
	_validate_sprite_configuration()
	force_update()

## Configure the component for 8-directional mode with default sprite names
func setup_8_directional(custom_sprite_names: Array[String] = []):
	direction_mode = DirectionMode.EIGHT_DIRECTIONAL
	if custom_sprite_names.is_empty():
		sprite_names = _get_default_sprite_names()
	else:
		sprite_names = custom_sprite_names
	_validate_sprite_configuration()
	force_update()

## Configure the component for 8-directional mode with sprite flipping (uses 5 sprites)
func setup_8_directional_flipping(custom_sprite_names: Array[String] = []):
	direction_mode = DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING
	if custom_sprite_names.is_empty():
		sprite_names = _get_default_sprite_names()
	else:
		sprite_names = custom_sprite_names
	_validate_sprite_configuration()
	force_update()


func debug_angle_info() -> Dictionary:
	if not _cached_camera or not _reference_node:
		return {}

	var ref_pos = _reference_node.global_position
	var camera_pos = _cached_camera.global_position
	var dx = camera_pos.x - ref_pos.x
	var dz = camera_pos.z - ref_pos.z

	var ref_basis = _reference_node.global_transform.basis
	var object_forward = - ref_basis.z
	var object_right = ref_basis.x

	var forward_component = object_forward.x * dx + object_forward.z * dz
	var right_component = object_right.x * dx + object_right.z * dz

	var angle_radians = atan2(right_component, forward_component)
	var angle_degrees = rad_to_deg(angle_radians)
	if angle_degrees < 0:
		angle_degrees += 360

	# Calculate segment using the same logic as the main function
	var segment = _calculate_viewing_segment(_cached_camera)

	# Calculate adjusted angle based on mode for debug info
	var adjusted_angle: float
	var segment_size: float

	if direction_mode == DirectionMode.FOUR_DIRECTIONAL:
		adjusted_angle = angle_degrees + 45.0
		segment_size = 90.0
	else:
		adjusted_angle = angle_degrees + 22.5
		segment_size = 45.0

	if adjusted_angle >= 360:
		adjusted_angle -= 360

	var mode_name: String
	match direction_mode:
		DirectionMode.FOUR_DIRECTIONAL:
			mode_name = "4-directional"
		DirectionMode.EIGHT_DIRECTIONAL:
			mode_name = "8-directional"
		DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING:
			mode_name = "8-directional-flipping"
		_:
			mode_name = "unknown"

	return {
		"direction_mode": mode_name,
		"angle_degrees": angle_degrees,
		"adjusted_angle": adjusted_angle,
		"segment_size": segment_size,
		"segment": segment,
		"sprite_name": _current_sprite_name,
		"sprite_flipping": direction_mode == DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING,
		"flip_h": _current_flip_h,
		"forward_component": forward_component,
		"right_component": right_component
	}
