# A leaner, universal 2D/3D sprite animator that picks an animation based on the
# camera-to-object angle. Supports 3-, 4-, 8-directional sprites as well as the
# common "5 sprites + horizontal flip" variant.
#
# Public API kept identical where needed so existing scenes keep working.
# Author: refactored by Cascade 2025-07-17

class_name DirectionalSpriteAnimator extends Node

# ────────────────────────────────────────────────────────────────────────────────
#  ENUMS & EXPORTED PROPERTIES
# ────────────────────────────────────────────────────────────────────────────────

signal sprite_changed(new_sprite_name: String)

enum DirectionMode {
	THREE_DIRECTIONAL, # front, side, back (uses 3 sprites, side can flip)
	FOUR_DIRECTIONAL, # front, right, back, left (uses 4 sprites)
	EIGHT_DIRECTIONAL, # 8 individual sprites (45° segments)
	EIGHT_DIRECTIONAL_FLIP # 5 sprites, left-side variants are flipped
}

@export var sprite_node_path: NodePath
@export var reference_node_path: NodePath
@export var direction_mode: DirectionMode = DirectionMode.EIGHT_DIRECTIONAL
# When enabled, if the camera is extremely close to the reference point (e.g. first-person view),
# treat it as looking straight at the object to avoid angle jitter that causes sprite flipping.
@export var front_on_close_camera: bool = false
# Distance (in world units) below which the close-camera override kicks in.
@export var close_camera_distance: float = 0.35
# If true, the animator checks the camera every frame even if the segment did not change
@export var always_check_camera: bool = false
@export var camera_yaw_only: bool = false

# Order must match segments (see _default_sprite_names)
@export var sprite_names: Array[String] = [
	"front", "front-right", "right", "back-right",
	"back", "back-left", "left", "front-left"
]

# ────────────────────────────────────────────────────────────────────────────────
#  TUNING PARAMETERS
# ────────────────────────────────────────────────────────────────────────────────
# In THREE_DIRECTIONAL mode the cutoff between front↔side and back↔side can be
# tweaked. 45° means the front sprite is used when the camera is within ±45° of
# the object’s forward vector (so a 90° cone in total). Increase this to make
# the front sprite appear for a wider range, decrease to switch to side sooner.

@export_range(5.0, 89.0, 1.0, "degrees") var three_dir_front_half_deg: float = 45.0

# In FOUR_DIRECTIONAL mode, the angle offset for the quadrant boundaries.
# Default 45° means boundaries are at 45°, 135°, 225°, 315°.
# Adjust this to fine-tune when transitions occur between front/right/back/left.
@export_range(0.0, 89.0, 1.0, "degrees") var four_dir_angle_offset: float = 45.0

# ────────────────────────────────────────────────────────────────────────────────
#  INTERNAL STATE
# ────────────────────────────────────────────────────────────────────────────────

var _sprite_node: Object = null
var _reference_node: Node3D = null
var _last_segment := -1
var _current_flip_h := false
var _is_mirror_camera := false
var _active_camera: Camera3D = null

# Segment smoothing for mirrors
var _mirror_segment_buffer: Array[int] = []
var _mirror_buffer_size := 5

# We don’t need to track a separate main camera anymore – just tag if we’re in a
# SubViewport-render pass and reset the smoothing buffer accordingly.
func _detect_mirror_camera(camera: Camera3D) -> void:
	var was_mirror := _is_mirror_camera
	_is_mirror_camera = false
	var node := camera as Node
	while node:
		if node is SubViewport:
			_is_mirror_camera = true
			break
		node = node.get_parent()

	# Reset smoothing when switching in/out of mirror rendering
	if was_mirror != _is_mirror_camera:
		_mirror_segment_buffer.clear()
		# Start with an empty buffer – we will populate it with real
		# segment values as they come in. Pre-filling with zeros biased the
		# smoothing toward the front segment and produced incorrect angles
		# for the first few frames when a mirror camera began rendering.

# ────────────────────────────────────────────────────────────────────────────────
#  LIFECYCLE
# ────────────────────────────────────────────────────────────────────────────────

func _ready():
	_sprite_node = get_node(sprite_node_path) if sprite_node_path != NodePath("") else null
	_reference_node = (get_node(reference_node_path)
		if reference_node_path != NodePath("")
		else get_parent())

	if _sprite_node == null:
		push_error("DirectionalSpriteAnimator: sprite_node_path is invalid")
	if _reference_node == null:
		push_error("DirectionalSpriteAnimator: reference_node_path is invalid")
	
	# Initialize mirror buffer
	# Start with an empty buffer – we will populate it with real
	# segment values as they come in. Pre-filling with zeros biased the
	# smoothing toward the front segment and produced incorrect angles
	# for the first few frames when a mirror camera began rendering.

# Utility: pick closest camera (main or mirror) to evaluate sprite direction
func _get_relevant_camera() -> Camera3D:
	var main_cam := get_viewport().get_camera_3d()
	var chosen_cam := main_cam
	var closest_dist_sq := INF
	var obj_pos: Vector3 = _reference_node.global_position if _reference_node else Vector3.ZERO
	for mcam in get_tree().get_nodes_in_group("mirror_camera"):
		if not (mcam is Camera3D):
			continue
		var d := obj_pos.distance_squared_to(mcam.global_transform.origin)
		if d < closest_dist_sq:
			closest_dist_sq = d
			chosen_cam = mcam
	return chosen_cam

# Modify _process to use relevant camera
func _process(_delta):
	if _reference_node == null:
		return
	var prev_is_mirror := _is_mirror_camera
	var camera := _get_relevant_camera()
	if camera == null:
		return
	_active_camera = camera
	
	# Detect if this is a mirror camera (belongs to group)
	_is_mirror_camera = camera.is_in_group("mirror_camera")
	# Reset smoothing buffer when switching in/out of mirror camera
	if _is_mirror_camera != prev_is_mirror:
		_mirror_segment_buffer.clear()
		# Start with an empty buffer – we will populate it with real
		# segment values as they come in. Pre-filling with zeros biased the
		# smoothing toward the front segment and produced incorrect angles
		# for the first few frames when a mirror camera began rendering.

	# Debug print for mirror detection
	if _is_mirror_camera and OS.is_debug_build():
		printt("Processing mirror camera for:", _reference_node.name)

	var segment = _calculate_segment(camera)

	# Apply smoothing for mirror cameras to prevent rapid flipping
	if _is_mirror_camera:
		segment = _smooth_mirror_segment(segment)

	# When always_check_camera is off, skip further work if the segment is unchanged
	if not always_check_camera and segment == _last_segment:
		return

	_last_segment = segment
	_apply_segment(segment)

# ────────────────────────────────────────────────────────────────────────────────
#  MIRROR SMOOTHING
# ────────────────────────────────────────────────────────────────────────────────

func _smooth_mirror_segment(new_segment: int) -> int:
	# Add new segment to buffer
	_mirror_segment_buffer.push_back(new_segment)
	if _mirror_segment_buffer.size() > _mirror_buffer_size:
		_mirror_segment_buffer.pop_front()
	
	# Count occurrences of each segment
	var segment_counts = {}
	for seg in _mirror_segment_buffer:
		if seg in segment_counts:
			segment_counts[seg] += 1
		else:
			segment_counts[seg] = 1
	
	# Find the most common segment
	var most_common_segment = new_segment
	var highest_count = 0
	for seg in segment_counts:
		if segment_counts[seg] > highest_count:
			highest_count = segment_counts[seg]
			most_common_segment = seg
	
	return most_common_segment

# ────────────────────────────────────────────────────────────────────────────────
#  MIRROR DETECTION
# ────────────────────────────────────────────────────────────────────────────────

# Mirror segment: use position-based angle calculation for accurate reflection
func _calculate_mirror_segment(mirror_camera: Camera3D) -> int:
	# For mirrors, we want to calculate what the mirror sees
	# This is the angle from the player TO the mirror camera
	var obj_pos: Vector3 = _reference_node.global_position
	var cam_pos: Vector3 = mirror_camera.global_position
	
	# Calculate vector FROM player TO mirror camera
	var to_camera := cam_pos - obj_pos
	to_camera.y = 0 # Project to XZ plane
	to_camera = to_camera.normalized()
	
	# Check for close-camera override for mirrors
	if front_on_close_camera:
		var dist := (cam_pos - obj_pos).length()
		if dist < close_camera_distance:
			if OS.is_debug_build():
				print("Close camera override triggered! Distance: ", dist)
			return 0 # Always return front segment for close mirror cameras
	
	# Get player's forward and right vectors
	var basis := _reference_node.global_transform.basis
	var forward: Vector3 = - basis.z
	var right: Vector3 = basis.x
	
	# Project to XZ plane
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	# Calculate dot products to determine angle
	var forward_dot: float = forward.dot(to_camera)
	var right_dot: float = right.dot(to_camera)
	
	# Calculate base angle in degrees
	var base_angle := rad_to_deg(atan2(right_dot, forward_dot))
	if base_angle < 0:
		base_angle += 360.0

	# CRITICAL FIX: Account for main camera rotation affecting the viewport
	# When the main external camera is rotated, it affects how mirrors should display sprites
	var main_camera := get_viewport().get_camera_3d()
	var angle := base_angle

	if main_camera != null and main_camera != mirror_camera:
		# Get main camera's Y rotation
		var main_cam_y_rotation := rad_to_deg(main_camera.rotation.y)

		# The key insight: when camera rotates 180°, we need to flip the entire perspective
		# This means adding 180° to flip both front↔back AND left↔right correctly
		if abs(main_cam_y_rotation - 180.0) < 1.0: # Camera rotated ~180°
			angle = base_angle + 180.0
		else:
			# For other rotations, use the standard transformation
			angle = base_angle - main_cam_y_rotation

		# Normalize to 0-360 range
		while angle < 0:
			angle += 360.0
		while angle >= 360.0:
			angle -= 360.0

	# Debug prints
	if OS.is_debug_build():
		print("=== Mirror Debug ===")
		print("Player position: ", obj_pos)
		print("Mirror camera position: ", cam_pos)
		print("To camera vector: ", to_camera)
		print("Player forward: ", forward)
		print("Player right: ", right)
		print("Forward dot: ", forward_dot)
		print("Right dot: ", right_dot)
		print("Base angle: %.2f°" % base_angle)
		if main_camera != null and main_camera != mirror_camera:
			print("Main camera Y rotation: %.2f°" % rad_to_deg(main_camera.rotation.y))
			print("Adjusted angle: %.2f°" % angle)
		else:
			print("No main camera adjustment needed")
		print("Player rotation Y: ", rad_to_deg(_reference_node.rotation.y))

	# Get base segment from angle
	var base_seg := _get_segment_from_angle(angle)

	if OS.is_debug_build():
		print("Base segment: ", base_seg)
		print("Direction mode: ", direction_mode)

	# For mirrors, we typically want to mirror left/right but the calculation
	# should already give us the correct view since we're calculating from
	# the mirror camera's perspective
	return base_seg

# -----------------------------------------------------------------------------
#  SEGMENT CALCULATION HELPERS
# -----------------------------------------------------------------------------

# Calculate segment using only yaw difference between object forward and camera
# forward (ignores distance), useful for first-person and our mirror logic.
func _calculate_segment_by_yaw(cam: Camera3D) -> int:
	var obj_fwd: Vector3 = - _reference_node.global_transform.basis.z
	var obj_yaw := rad_to_deg(atan2(obj_fwd.x, obj_fwd.z))
	var cam_fwd: Vector3 = - cam.global_transform.basis.z
	var cam_yaw := rad_to_deg(atan2(cam_fwd.x, cam_fwd.z))

	# Debug the yaw calculation
	if OS.is_debug_build():
		print("=== Yaw-Based Debug ===")
		print("Object forward: ", obj_fwd)
		print("Object yaw: %.2f°" % obj_yaw)
		print("Camera forward: ", cam_fwd)
		print("Camera yaw: %.2f°" % cam_yaw)
		print("Raw angle (cam_yaw - obj_yaw): %.2f°" % (cam_yaw - obj_yaw))

	var angle := fmod(cam_yaw - obj_yaw + 360.0, 360.0)

	if OS.is_debug_build():
		print("Final angle: %.2f°" % angle)
		print("Calculated segment: %d" % _get_segment_from_angle(angle))
		print("====================")

	return _get_segment_from_angle(angle)

# Calculate segment for non-mirror cameras (full position-based version)
func _calculate_segment(camera: Camera3D) -> int:
	# Mirror pass – always use position-based calculation for mirrors
	if _is_mirror_camera:
		return _calculate_mirror_segment(camera)
	
	# Force yaw-only path if requested (but not for mirrors)
	if camera_yaw_only:
		return _calculate_segment_by_yaw(camera)

	# -------- Simple approach: Use mirror logic but account for camera rotation --------
	# Start with the same calculation as mirrors (which works), then adjust for camera rotation

	var obj_pos: Vector3 = _reference_node.global_position
	var cam_pos: Vector3 = camera.global_position

	# Calculate vector FROM object TO camera (same as mirror logic)
	var to_camera := cam_pos - obj_pos
	to_camera.y = 0 # Project to XZ plane

	# If camera is effectively inside the object (first-person), use view direction
	if to_camera.length_squared() < 0.0004: # 0.02^2
		return _calculate_segment_by_yaw(camera)

	# Close-camera override
	var dist_sq := to_camera.length_squared()
	if front_on_close_camera and dist_sq < close_camera_distance * close_camera_distance:
		_debug_last_angle = 0.0
		_debug_forward_comp = 0.0
		_debug_right_comp = 0.0
		return 0

	# Normalize the to_camera vector
	to_camera = to_camera.normalized()

	# Get object's forward and right vectors (same as mirror logic)
	var obj_basis := _reference_node.global_transform.basis
	var obj_forward: Vector3 = - obj_basis.z
	var obj_right: Vector3 = obj_basis.x

	# Project to XZ plane and normalize
	obj_forward.y = 0
	obj_right.y = 0
	obj_forward = obj_forward.normalized()
	obj_right = obj_right.normalized()

	# Calculate dot products to determine angle (same as mirror logic)
	var forward_dot: float = obj_forward.dot(to_camera)
	var right_dot: float = obj_right.dot(to_camera)

	# Calculate the base angle (same as mirror logic)
	var base_angle := rad_to_deg(atan2(right_dot, forward_dot))
	if base_angle < 0:
		base_angle += 360.0

	# HERE'S THE KEY: Transform coordinate system based on camera rotation
	# Instead of adjusting angles, transform the to_camera vector based on camera rotation
	var cam_y_rotation := rad_to_deg(camera.rotation.y)
	var cam_global_y_rotation := rad_to_deg(camera.global_rotation.y)

	# Use whichever rotation value is more significant
	var effective_rotation = cam_y_rotation
	if abs(cam_global_y_rotation) > abs(cam_y_rotation):
		effective_rotation = cam_global_y_rotation

	# Transform the to_camera vector by rotating it by the camera's rotation
	# This properly handles the coordinate system transformation
	var transformed_to_camera = to_camera
	if abs(effective_rotation) > 1.0: # Camera has significant rotation
		var rotation_rad = deg_to_rad(-effective_rotation) # Negative to counter-rotate
		var cos_rot = cos(rotation_rad)
		var sin_rot = sin(rotation_rad)

		# Apply 2D rotation matrix to XZ components
		var new_x = to_camera.x * cos_rot - to_camera.z * sin_rot
		var new_z = to_camera.x * sin_rot + to_camera.z * cos_rot
		transformed_to_camera = Vector3(new_x, 0, new_z).normalized()

	# Recalculate dot products with the transformed vector
	var transformed_forward_dot: float = obj_forward.dot(transformed_to_camera)
	var transformed_right_dot: float = obj_right.dot(transformed_to_camera)

	# Calculate angle using the transformed vector
	var angle := rad_to_deg(atan2(transformed_right_dot, transformed_forward_dot))
	if angle < 0:
		angle += 360.0

	_debug_forward_comp = transformed_forward_dot
	_debug_right_comp = transformed_right_dot
	_debug_last_angle = angle

	var segment = _get_segment_from_angle(angle)

	# Debug output for normal cameras
	if OS.is_debug_build():
		print("=== Normal Camera Debug (Coordinate Transform) ===")
		print("Player position: ", obj_pos)
		print("Camera position: ", cam_pos)
		print("Original to_camera vector: ", to_camera)
		print("Effective camera rotation: %.2f°" % effective_rotation)
		print("Transformed to_camera vector: ", transformed_to_camera)
		print("Object forward: ", obj_forward)
		print("Object right: ", obj_right)
		print("Original forward dot: %.3f" % forward_dot)
		print("Original right dot: %.3f" % right_dot)
		print("Transformed forward dot: %.3f" % transformed_forward_dot)
		print("Transformed right dot: %.3f" % transformed_right_dot)
		print("Base angle: %.2f°" % base_angle)
		print("Final transformed angle: %.2f°" % angle)
		print("Calculated segment: ", segment)
		print("Direction mode: ", direction_mode)
		print("==================================================")

	return segment

# Helper: derive segment from an arbitrary XZ-plane direction vector
func _segment_from_direction(dir: Vector3) -> int:
	# Use consistent approach with normalized vectors and dot products
	var basis := _reference_node.global_transform.basis
	var forward: Vector3 = - basis.z
	var right: Vector3 = basis.x

	# Project to XZ plane and normalize
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	# Ensure direction is also normalized and projected to XZ plane
	dir.y = 0
	dir = dir.normalized()

	# Calculate dot products
	var forward_dot: float = forward.dot(dir)
	var right_dot: float = right.dot(dir)

	# Calculate angle using dot products
	var angle := rad_to_deg(atan2(right_dot, forward_dot))
	if angle < 0:
		angle += 360.0
	return _get_segment_from_angle(angle)

func _get_segment_from_angle(angle: float) -> int:
	match direction_mode:
		DirectionMode.THREE_DIRECTIONAL:
			return _segment_3(angle)
		DirectionMode.FOUR_DIRECTIONAL:
			return _segment_4(angle)
		_:
			return _segment_8(angle) # covers both 8-dir modes

func _segment_3(angle: float) -> int:
	# Improved THREE_DIRECTIONAL logic with better boundary handling
	var front_half: float = clamp(three_dir_front_half_deg, 5.0, 89.0)

	# Normalize angle to 0-360 range
	while angle < 0:
		angle += 360.0
	while angle >= 360.0:
		angle -= 360.0

	# Front range: within ±front_half degrees of forward (0°)
	# Handle wraparound at 0°/360° boundary more explicitly
	if angle <= front_half or angle >= (360.0 - front_half):
		return 0 # front

	# Back range: within ±front_half degrees of 180° (object facing away)
	elif angle >= (180.0 - front_half) and angle <= (180.0 + front_half):
		return 2 # back

	# Everything else is considered side (left or right)
	else:
		return 1 # side

func _segment_4(angle: float) -> int:
	# Improved FOUR_DIRECTIONAL logic with configurable boundaries
	# Normalize angle to 0-360 range
	while angle < 0:
		angle += 360.0
	while angle >= 360.0:
		angle -= 360.0

	var offset: float = clamp(four_dir_angle_offset, 0.0, 89.0)
	var boundary1 = offset # Default: 45°
	var boundary2 = 90.0 + offset # Default: 135°
	var boundary3 = 180.0 + offset # Default: 225°
	var boundary4 = 270.0 + offset # Default: 315°

	# 90° quadrants with configurable boundaries
	if angle >= boundary4 or angle < boundary1:
		return 0 # front
	elif angle < boundary2:
		return 1 # right
	elif angle < boundary3:
		return 2 # back
	else:
		return 3 # left

func _segment_8(angle: float) -> int:
	# Improved EIGHT_DIRECTIONAL logic with better angle normalization
	# Normalize angle to 0-360 range
	while angle < 0:
		angle += 360.0
	while angle >= 360.0:
		angle -= 360.0

	# Calculate segment with 45° boundaries, offset by 22.5° to center on axes
	var seg := int(floor((angle + 22.5) / 45.0)) % 8
	return seg

# ────────────────────────────────────────────────────────────────────────────────
#  APPLY SEGMENT → SPRITE NAME + FLIP
# ────────────────────────────────────────────────────────────────────────────────

func _apply_segment(segment: int):
	var flip := false
	var index := segment

	match direction_mode:
		DirectionMode.THREE_DIRECTIONAL:
			index = [0, 1, 2][segment] # front/side/back order
			if segment == 1:
				# Determine side orientation: right halves (45-135°) need flip
				flip = _is_right_side()
		DirectionMode.FOUR_DIRECTIONAL:
			index = segment # 0-3 match sprite order
		DirectionMode.EIGHT_DIRECTIONAL:
			index = segment # 0-7 direct mapping
		DirectionMode.EIGHT_DIRECTIONAL_FLIP:
			var map = [0, 1, 2, 3, 4, 3, 2, 1]
			index = map[segment]
			flip = segment >= 5 # left/back-left/front-left
		_:
			pass

	if index >= sprite_names.size():
		push_error("DirectionalSpriteAnimator: sprite_names too short for mode")
		return

	if OS.is_debug_build() and _is_mirror_camera:
		print("=== Apply Segment Debug (Mirror) ===")
		print("Segment: ", segment)
		print("Index: ", index)
		print("Sprite name to play: ", sprite_names[index])
		print("Should flip: ", flip)
		print("Available animations: ", _sprite_node.sprite_frames.get_animation_names() if _sprite_node.has_method("get_sprite_frames") else "N/A")

	_set_sprite(sprite_names[index], flip)

func _is_right_side() -> bool:
	var cam: Camera3D = _active_camera if _active_camera else get_viewport().get_camera_3d()
	if cam == null or _reference_node == null:
		return _current_flip_h # keep previous if uncertain

	# MIRROR CAMERA: decide side based on orientation, not position
	if _is_mirror_camera:
		var cam_forward: Vector3 = - cam.global_transform.basis.z
		var obj_forward: Vector3 = - _reference_node.global_transform.basis.z
		# Project to XZ plane
		cam_forward.y = 0
		obj_forward.y = 0
		if cam_forward.length_squared() == 0 or obj_forward.length_squared() == 0:
			return _current_flip_h
		cam_forward = cam_forward.normalized()
		obj_forward = obj_forward.normalized()
		var side_val := obj_forward.cross(cam_forward).y
		const ORIENT_DEAD := 0.05
		if abs(side_val) < ORIENT_DEAD:
			return _current_flip_h
		return side_val > 0 # positive = camera sees player's right side

	# NORMAL CAMERA: use position-based logic with dead zone
	var delta: Vector3 = cam.global_position - _reference_node.global_position
	delta.y = 0
	var right_vec: Vector3 = _reference_node.global_transform.basis.x
	var right_component: float = right_vec.x * delta.x + right_vec.z * delta.z
	const POS_DEAD := 0.15
	if abs(right_component) < POS_DEAD:
		return _current_flip_h
	return right_component > 0

# ────────────────────────────────────────────────────────────────────────────────
#  PLAY / FLIP
# ────────────────────────────────────────────────────────────────────────────────

func _set_sprite(anim_name: String, flip: bool) -> void:
	if _sprite_node == null:
		return

	# Use the flip value as calculated by _is_right_side() which now properly handles mirrors
	var final_flip := flip

	if _sprite_node.has_method("play") and _sprite_node.animation != anim_name:
			_sprite_node.play(anim_name)

	if "flip_h" in _sprite_node:
		_sprite_node.flip_h = final_flip

	_current_flip_h = flip
	sprite_changed.emit(anim_name)

	if _sprite_node is Node3D:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var target_pos = cam.global_transform.origin
			var sprite_pos = _sprite_node.global_transform.origin
			var direction = (target_pos - sprite_pos).normalized()

			# Avoid look_at when vectors are collinear (causing the warning)
			if abs(direction.dot(Vector3.UP)) < 0.99:
				_sprite_node.look_at(target_pos, Vector3.UP)

# ────────────────────────────────────────────────────────────────────────────────
#  UTILITY
# ────────────────────────────────────────────────────────────────────────────────

# ────────────────────────────────────────────────────────────────────────────────
#  DEBUG UTILITIES
# ────────────────────────────────────────────────────────────────────────────────

var _debug_last_angle := 0.0
var _debug_forward_comp := 0.0
var _debug_right_comp := 0.0

func debug_angle_info() -> Dictionary:
	# Re-compute without altering state to provide up-to-date info
	var cam := get_viewport().get_camera_3d()
	if cam == null or _reference_node == null:
		return {}

	var seg := _calculate_segment(cam)
	var mode_name := ""
	var threshold_info := {}

	match direction_mode:
		DirectionMode.THREE_DIRECTIONAL:
			mode_name = "THREE_DIRECTIONAL"
			threshold_info = {
				"front_half_deg": three_dir_front_half_deg,
				"front_range": "0° ±%.1f° (%.1f° - %.1f°, %.1f° - 360°)" % [
					three_dir_front_half_deg,
					0.0, three_dir_front_half_deg,
					360.0 - three_dir_front_half_deg
				],
				"back_range": "180° ±%.1f° (%.1f° - %.1f°)" % [
					three_dir_front_half_deg,
					180.0 - three_dir_front_half_deg,
					180.0 + three_dir_front_half_deg
				]
			}
		DirectionMode.FOUR_DIRECTIONAL:
			mode_name = "FOUR_DIRECTIONAL"
			threshold_info = {
				"angle_offset": four_dir_angle_offset,
				"boundaries": "%.1f°, %.1f°, %.1f°, %.1f°" % [
					four_dir_angle_offset,
					90.0 + four_dir_angle_offset,
					180.0 + four_dir_angle_offset,
					270.0 + four_dir_angle_offset
				]
			}
		DirectionMode.EIGHT_DIRECTIONAL, DirectionMode.EIGHT_DIRECTIONAL_FLIP:
			mode_name = "EIGHT_DIRECTIONAL" if direction_mode == DirectionMode.EIGHT_DIRECTIONAL else "EIGHT_DIRECTIONAL_FLIP"
			threshold_info = {
				"segment_size": 45.0,
				"boundaries": "22.5°, 67.5°, 112.5°, 157.5°, 202.5°, 247.5°, 292.5°, 337.5°"
			}

	return {
		"angle_degrees": _debug_last_angle,
		"forward_component": _debug_forward_comp,
		"right_component": _debug_right_comp,
		"segment": seg,
		"direction_mode": direction_mode,
		"mode_name": mode_name,
		"sprite_name": (seg >= 0 and seg < sprite_names.size()) and sprite_names[seg] or "",
		"is_mirror_camera": _is_mirror_camera,
		"threshold_info": threshold_info
	}

# Debug function to print detailed angle information
func print_debug_info():
	var debug_info = debug_angle_info()
	if debug_info.is_empty():
		print("DirectionalSpriteAnimator: No debug info available")
		return

	print("=== DirectionalSpriteAnimator Debug Info ===")
	print("Mode: %s (%d)" % [debug_info.get("mode_name", "unknown"), debug_info.get("direction_mode", -1)])
	print("Current angle: %.2f°" % debug_info.get("angle_degrees", 0))
	print("Forward component: %.3f" % debug_info.get("forward_component", 0))
	print("Right component: %.3f" % debug_info.get("right_component", 0))
	print("Calculated segment: %d" % debug_info.get("segment", -1))
	print("Current sprite: %s" % debug_info.get("sprite_name", "unknown"))
	print("Is mirror camera: %s" % debug_info.get("is_mirror_camera", false))

	var threshold_info = debug_info.get("threshold_info", {})
	if not threshold_info.is_empty():
		print("Threshold info:")
		for key in threshold_info:
			print("  %s: %s" % [key, threshold_info[key]])
	print("==========================================")

# Test function to see what segment a specific angle would produce
func test_angle(angle_degrees: float) -> Dictionary:
	var segment = _get_segment_from_angle(angle_degrees)
	return {
		"input_angle": angle_degrees,
		"calculated_segment": segment,
		"sprite_name": (segment >= 0 and segment < sprite_names.size()) and sprite_names[segment] or "invalid",
		"direction_mode": direction_mode
	}

# Test multiple angles to see the boundaries
func test_angle_boundaries():
	print("=== Angle Boundary Test ===")
	var test_angles = [0, 22.5, 45, 67.5, 90, 112.5, 135, 157.5, 180, 202.5, 225, 247.5, 270, 292.5, 315, 337.5]
	for angle in test_angles:
		var result = test_angle(angle)
		print("%.1f° -> segment %d (%s)" % [angle, result.calculated_segment, result.sprite_name])
	print("===========================")

# Compare old vs new angle calculation methods for debugging
func compare_calculation_methods(camera: Camera3D) -> Dictionary:
	if not camera or not _reference_node:
		return {}

	var obj_pos: Vector3 = _reference_node.global_position
	var cam_pos: Vector3 = camera.global_position

	# OLD METHOD (the problematic position-based one)
	var dx: float = cam_pos.x - obj_pos.x
	var dz: float = cam_pos.z - obj_pos.z
	var basis_old := _reference_node.global_transform.basis
	var forward_old: Vector3 = - basis_old.z
	var right_old: Vector3 = basis_old.x
	var f_comp_old: float = forward_old.x * dx + forward_old.z * dz
	var r_comp_old: float = right_old.x * dx + right_old.z * dz
	var angle_old := rad_to_deg(atan2(r_comp_old, f_comp_old))
	if angle_old < 0:
		angle_old += 360.0

	# NEW METHOD (yaw-based, handles camera rotation correctly)
	var obj_fwd: Vector3 = - _reference_node.global_transform.basis.z
	var obj_yaw := rad_to_deg(atan2(obj_fwd.x, obj_fwd.z))
	var cam_fwd: Vector3 = - camera.global_transform.basis.z
	var cam_yaw := rad_to_deg(atan2(cam_fwd.x, cam_fwd.z))
	var angle_new := fmod(cam_yaw - obj_yaw + 360.0, 360.0)

	return {
		"old_angle": angle_old,
		"new_angle": angle_new,
		"angle_difference": abs(angle_new - angle_old),
		"old_segment": _get_segment_from_angle(angle_old),
		"new_segment": _get_segment_from_angle(angle_new),
		"segments_match": _get_segment_from_angle(angle_old) == _get_segment_from_angle(angle_new),
		"obj_yaw": obj_yaw,
		"cam_yaw": cam_yaw,
		"method": "yaw_based"
	}

# ────────────────────────────────────────────────────────────────────────────────
func _default_sprite_names() -> Array[String]:
	match direction_mode:
		DirectionMode.THREE_DIRECTIONAL:
			return ["front", "side", "back"]
		DirectionMode.FOUR_DIRECTIONAL:
			return ["front", "right", "back", "left"]
		DirectionMode.EIGHT_DIRECTIONAL_FLIP:
			return ["front", "front-side", "side", "back-side", "back"]
		_:
			return ["front", "front-right", "right", "back-right", "back", "back-left", "left", "front-left"]
