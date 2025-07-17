class_name DirectionalSpriteAnimator extends Node

## A reusable component for animating sprites based on camera viewing angle
## Supports both 4-directional and 8-directional sprite animation with equal angle segments

signal sprite_changed(new_sprite_name: String)

enum DirectionMode {
	THREE_DIRECTIONAL, ## 3 directions: front, side, back
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

@export_group("State-Based Animation")
@export var current_state: String = "" ## Optional state prefix for animations (e.g., "run", "idle")
@export var state_separator: String = "-" ## Separator between state and direction (e.g., "run-front")

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
		var mode_name: String
		match direction_mode:
			DirectionMode.THREE_DIRECTIONAL:
				mode_name = "3-directional"
			DirectionMode.FOUR_DIRECTIONAL:
				mode_name = "4-directional"
			DirectionMode.EIGHT_DIRECTIONAL:
				mode_name = "8-directional"
			DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING:
				mode_name = "8-directional-flipping"
			_:
				mode_name = "unknown"

		push_warning("DirectionalSpriteAnimator: Expected %d sprite names for %s mode, but got %d. Using default names." % [
			expected_count,
			mode_name,
			sprite_names.size()
		])
		sprite_names = _get_default_sprite_names()

	# Validate that animations exist (only if sprite node is available)
	_validate_animations_exist()


## Validate that the required animations exist in the sprite node
func _validate_animations_exist():
	if not _sprite_node:
		return

	var missing_animations: Array[String] = []

	# Check base directional animations
	for sprite_name in sprite_names:
		var animation_name = _get_animation_name(sprite_name)
		if not _animation_exists(animation_name):
			missing_animations.append(animation_name)

	# Report missing animations
	if not missing_animations.is_empty():
		if current_state.is_empty():
			push_warning("DirectionalSpriteAnimator: Missing animations: %s" % str(missing_animations))
		else:
			push_warning("DirectionalSpriteAnimator: Missing state-based animations: %s. Consider using base directional names or ensuring all state animations exist." % str(missing_animations))


func _get_expected_sprite_count() -> int:
	match direction_mode:
		DirectionMode.THREE_DIRECTIONAL:
			return 3
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
		DirectionMode.THREE_DIRECTIONAL:
			return ["front", "side", "back"]
		DirectionMode.FOUR_DIRECTIONAL:
			return ["front", "right", "back", "left"]
		DirectionMode.EIGHT_DIRECTIONAL:
			return ["front", "front-right", "right", "back-right", "back", "back-left", "left", "front-left"]
		DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING:
			return ["front", "front-side", "side", "back-side", "back"]
		_:
			return ["front", "front-right", "right", "back-right", "back", "back-left", "left", "front-left"]


## Constructs the final animation name by combining state and direction
## If state is provided, returns "state-direction", otherwise returns just "direction"
func _get_animation_name(base_direction: String, state: String = "") -> String:
	if state.is_empty():
		state = current_state

	if state.is_empty():
		return base_direction
	else:
		return state + state_separator + base_direction


## Check if an animation exists in the sprite node
func _animation_exists(animation_name: String) -> bool:
	if not _sprite_node:
		return false

	# For AnimatedSprite3D and AnimatedSprite2D
	if _sprite_node.has_method("has_animation"):
		return _sprite_node.has_animation(animation_name)

	# For AnimationPlayer
	if _sprite_node.has_method("has_animation"):
		return _sprite_node.has_animation(animation_name)

	# Fallback: check if sprite_frames resource exists and has the animation
	if "sprite_frames" in _sprite_node and _sprite_node.sprite_frames:
		return _sprite_node.sprite_frames.has_animation(animation_name)

	# If we can't determine, assume it exists to avoid breaking existing functionality
	return true


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
			DirectionMode.THREE_DIRECTIONAL:
				_handle_sprite_flipping_3_directional(segment)
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

	# Get the object's local coordinate system
	var ref_basis = _reference_node.global_transform.basis
	var object_forward = - ref_basis.z # Object's forward direction (negative Z)
	var object_right = ref_basis.x # Object's right direction (positive X)

	var forward_component: float
	var right_component: float

	# Special case: if reference node is the camera itself (or very close to it),
	# use camera's rotation direction instead of position-based calculation
	if abs(dx) < 0.001 and abs(dz) < 0.001:
		# Use camera's forward direction to determine which way the player is looking
		var camera_forward = - camera.global_transform.basis.z

		# Calculate the angle between camera forward and object forward
		forward_component = object_forward.x * camera_forward.x + object_forward.z * camera_forward.z
		right_component = object_right.x * camera_forward.x + object_right.z * camera_forward.z
	else:
		# Normal case: calculate direction from reference node to camera
		# Calculate the angle from object's perspective to camera
		forward_component = object_forward.x * dx + object_forward.z * dz
		right_component = object_right.x * dx + object_right.z * dz

	# Get angle in radians (-PI to PI)
	var angle_radians = atan2(right_component, forward_component)

	# Convert to degrees for easier calculation
	var angle_degrees = rad_to_deg(angle_radians)

	# Normalize to 0-360 range
	if angle_degrees < 0:
		angle_degrees += 360

	# Calculate segment based on direction mode
	if direction_mode == DirectionMode.THREE_DIRECTIONAL:
		return _calculate_3_directional_segment(angle_degrees)
	elif direction_mode == DirectionMode.FOUR_DIRECTIONAL:
		return _calculate_4_directional_segment(angle_degrees)
	else:
		return _calculate_8_directional_segment(angle_degrees)


func _calculate_3_directional_segment(angle_degrees: float) -> int:
	# Reworked 3-directional segmentation so that directions are evenly distributed and intuitive:
	#   • Front : 315°‒360° and 0°‒45°   (segment 0)
	#   • Side  : 45°‒135°  and 225°‒315° (segment 1)
	#   • Back  : 135°‒225°                (segment 2)
	# This guarantees that looking directly opposite to the camera plays the back animation
	# and both left and right views map to the side animation.
	# We can simply check explicit angle ranges instead of relying on an offset.

	if angle_degrees >= 315.0 or angle_degrees < 45.0:
		return 0 # front
	elif (angle_degrees >= 45.0 and angle_degrees < 135.0) or (angle_degrees >= 225.0 and angle_degrees < 315.0):
		return 1 # side (left or right – flipping handled separately)
	else:
		return 2 # back


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


func _handle_sprite_flipping_3_directional(segment: int):
	# Map 3 segments to 3 sprite names with flipping for left/right directions
	# Based on the angle calculation in _calculate_3_directional_segment:
	# Segment 0: front (300° - 60°, centered at 0°)
	# Segment 1: right side (60° - 180°, centered at 120°)
	# Segment 2: back (180° - 300°, centered at 240°)
	#
	# Expected behavior:
	# - Camera looking forward → "front" animation
	# - Camera looking backward → "back" animation
	# - Camera looking left → "side" animation (not flipped)
	# - Camera looking right → "side" animation (horizontally flipped)
	var sprite_index: int
	var flip_h: bool = false

	# Get the raw angle to determine left vs right for the side view
	var ref_pos = _reference_node.global_position
	var camera_pos = _cached_camera.global_position
	var dx = camera_pos.x - ref_pos.x
	var dz = camera_pos.z - ref_pos.z

	var ref_basis = _reference_node.global_transform.basis
	var object_forward = - ref_basis.z
	var object_right = ref_basis.x

	var forward_component: float
	var right_component: float

	# Use same logic as _calculate_viewing_segment for consistency
	if abs(dx) < 0.001 and abs(dz) < 0.001:
		# Camera is the reference - use camera rotation
		var camera_forward = - _cached_camera.global_transform.basis.z
		forward_component = object_forward.x * camera_forward.x + object_forward.z * camera_forward.z
		right_component = object_right.x * camera_forward.x + object_right.z * camera_forward.z
	else:
		# Normal position-based calculation
		forward_component = object_forward.x * dx + object_forward.z * dz
		right_component = object_right.x * dx + object_right.z * dz

	var angle_radians = atan2(right_component, forward_component)
	var angle_degrees = rad_to_deg(angle_radians)
	if angle_degrees < 0:
		angle_degrees += 360

	match segment:
		0:
			# Front view → ``front`` animation (no flip)
			sprite_index = 0
		1:
			# Side view → ``side`` animation – determine whether to flip
			sprite_index = 1
			# Right side (45°‒135°) should be flipped so the character faces right
			if angle_degrees >= 45.0 and angle_degrees < 135.0:
				flip_h = true # facing right (camera on character’s right)
			# Left side (225°‒315°) keeps default orientation (flip_h = false)
		2:
			# Back view → ``back`` animation (no flip)
			sprite_index = 2

	if sprite_index < sprite_names.size():
		var sprite_name = sprite_names[sprite_index]
		_set_sprite_animation(sprite_name, flip_h)


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


func _set_sprite_animation(sprite_name: String, flip_h: bool = false, state: String = ""):
	# Construct the final animation name with state support
	var final_animation_name = _get_animation_name(sprite_name, state)

	if _current_sprite_name == final_animation_name and _current_flip_h == flip_h:
		return

	if _sprite_node.has_method("play"):
		# Check if the animation exists before trying to play it
		if not _animation_exists(final_animation_name):
			# Try fallback to base animation without state if state-based animation doesn't exist
			if not state.is_empty() and _animation_exists(sprite_name):
				push_warning("DirectionalSpriteAnimator: Animation '%s' not found, falling back to '%s'" % [final_animation_name, sprite_name])
				final_animation_name = sprite_name
			else:
				push_warning("DirectionalSpriteAnimator: Animation '%s' not found, skipping" % final_animation_name)
				return

		if _sprite_node.animation != final_animation_name:
			_sprite_node.play(final_animation_name)
	elif _sprite_node.has_method("set_texture"):
		push_warning("DirectionalSpriteAnimator: Sprite3D texture switching not implemented")

	_current_sprite_name = final_animation_name
	_current_flip_h = flip_h

	# Apply horizontal flipping if the sprite node supports it
	if "flip_h" in _sprite_node:
		_sprite_node.flip_h = flip_h

	sprite_changed.emit(final_animation_name)


func set_enabled(value: bool):
	enabled = value


func get_current_sprite_name() -> String:
	return _current_sprite_name


## Set the current state for state-based animations
## This will be used as a prefix for all subsequent directional animations
func set_state(state: String):
	if current_state != state:
		current_state = state
		force_update()


## Play a specific directional animation with optional state
## If state is provided, plays "state-direction", otherwise uses current_state
## If no state is set, plays just the direction name (backward compatibility)
func play_animation(direction: String, state: String = ""):
	var final_animation_name = _get_animation_name(direction, state)

	if _sprite_node and _sprite_node.has_method("play"):
		# Check if the animation exists before trying to play it
		if not _animation_exists(final_animation_name):
			# Try fallback to base animation without state if state-based animation doesn't exist
			if not state.is_empty() and _animation_exists(direction):
				push_warning("DirectionalSpriteAnimator: Animation '%s' not found, falling back to '%s'" % [final_animation_name, direction])
				final_animation_name = direction
			else:
				push_warning("DirectionalSpriteAnimator: Animation '%s' not found, skipping" % final_animation_name)
				return

		if _sprite_node.animation != final_animation_name:
			_sprite_node.play(final_animation_name)
			_current_sprite_name = final_animation_name
			sprite_changed.emit(final_animation_name)


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


## Configure the component for 3-directional mode with default sprite names
func setup_3_directional(custom_sprite_names: Array[String] = [], initial_state: String = ""):
	direction_mode = DirectionMode.THREE_DIRECTIONAL
	if custom_sprite_names.is_empty():
		sprite_names = _get_default_sprite_names()
	else:
		sprite_names = custom_sprite_names
	current_state = initial_state
	_validate_sprite_configuration()
	force_update()


## Configure the component for 4-directional mode with default sprite names
func setup_4_directional(custom_sprite_names: Array[String] = [], initial_state: String = ""):
	direction_mode = DirectionMode.FOUR_DIRECTIONAL
	if custom_sprite_names.is_empty():
		sprite_names = _get_default_sprite_names()
	else:
		sprite_names = custom_sprite_names
	current_state = initial_state
	_validate_sprite_configuration()
	force_update()


## Configure the component for 8-directional mode with default sprite names
func setup_8_directional(custom_sprite_names: Array[String] = [], initial_state: String = ""):
	direction_mode = DirectionMode.EIGHT_DIRECTIONAL
	if custom_sprite_names.is_empty():
		sprite_names = _get_default_sprite_names()
	else:
		sprite_names = custom_sprite_names
	current_state = initial_state
	_validate_sprite_configuration()
	force_update()


## Configure the component for 8-directional mode with sprite flipping (uses 5 sprites)
func setup_8_directional_flipping(custom_sprite_names: Array[String] = [], initial_state: String = ""):
	direction_mode = DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING
	if custom_sprite_names.is_empty():
		sprite_names = _get_default_sprite_names()
	else:
		sprite_names = custom_sprite_names
	current_state = initial_state
	_validate_sprite_configuration()
	force_update()


## Get the current state being used for animations
func get_current_state() -> String:
	return current_state


## Check if the component is currently using state-based animations
func is_using_state_based_animations() -> bool:
	return not current_state.is_empty()


## Get the base direction name from the current sprite (removes state prefix if present)
func get_current_direction() -> String:
	if current_state.is_empty():
		return _current_sprite_name

	var prefix = current_state + state_separator
	if _current_sprite_name.begins_with(prefix):
		return _current_sprite_name.substr(prefix.length())

	return _current_sprite_name


## Get a list of all available animations in the sprite node
func get_available_animations() -> Array[String]:
	if not _sprite_node:
		return []

	var animations: Array[String] = []

	# For AnimatedSprite3D and AnimatedSprite2D
	if "sprite_frames" in _sprite_node and _sprite_node.sprite_frames:
		animations = _sprite_node.sprite_frames.get_animation_names()

	return animations


## Check if a specific animation exists
func has_animation(animation_name: String) -> bool:
	return _animation_exists(animation_name)


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

	var forward_component: float
	var right_component: float
	var is_camera_reference = false

	# Use the same logic as _calculate_viewing_segment
	if abs(dx) < 0.001 and abs(dz) < 0.001:
		# Camera is the reference - use camera rotation
		var camera_forward = - _cached_camera.global_transform.basis.z
		forward_component = object_forward.x * camera_forward.x + object_forward.z * camera_forward.z
		right_component = object_right.x * camera_forward.x + object_right.z * camera_forward.z
		is_camera_reference = true
	else:
		# Normal position-based calculation
		forward_component = object_forward.x * dx + object_forward.z * dz
		right_component = object_right.x * dx + object_right.z * dz

	var angle_radians = atan2(right_component, forward_component)
	var angle_degrees = rad_to_deg(angle_radians)
	if angle_degrees < 0:
		angle_degrees += 360

	# Calculate segment using the same logic as the main function
	var segment = _calculate_viewing_segment(_cached_camera)

	# Calculate adjusted angle based on mode for debug info
	var adjusted_angle: float
	var segment_size: float

	if direction_mode == DirectionMode.THREE_DIRECTIONAL:
		adjusted_angle = angle_degrees + 60.0
		segment_size = 120.0
	elif direction_mode == DirectionMode.FOUR_DIRECTIONAL:
		adjusted_angle = angle_degrees + 45.0
		segment_size = 90.0
	else:
		adjusted_angle = angle_degrees + 22.5
		segment_size = 45.0

	if adjusted_angle >= 360:
		adjusted_angle -= 360

	var mode_name: String
	match direction_mode:
		DirectionMode.THREE_DIRECTIONAL:
			mode_name = "3-directional"
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
		"current_state": current_state,
		"current_direction": get_current_direction(),
		"using_state_based": is_using_state_based_animations(),
		"sprite_flipping": direction_mode == DirectionMode.EIGHT_DIRECTIONAL_WITH_FLIPPING,
		"flip_h": _current_flip_h,
		"forward_component": forward_component,
		"right_component": right_component,
		"is_camera_reference": is_camera_reference,
		"distance_to_camera": ref_pos.distance_to(camera_pos)
	}
