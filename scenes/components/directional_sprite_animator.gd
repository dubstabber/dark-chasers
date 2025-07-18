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
		for i in range(_mirror_buffer_size):
			_mirror_segment_buffer.append(0)

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
	for i in range(_mirror_buffer_size):
		_mirror_segment_buffer.append(0)

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
		for i in range(_mirror_buffer_size):
			_mirror_segment_buffer.append(0)

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
	to_camera.y = 0  # Project to XZ plane
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
	var forward: Vector3 = -basis.z
	var right: Vector3 = basis.x
	
	# Project to XZ plane
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	# Calculate dot products to determine angle
	var forward_dot: float = forward.dot(to_camera)
	var right_dot: float = right.dot(to_camera)
	
	# Calculate angle in degrees
	var angle := rad_to_deg(atan2(right_dot, forward_dot))
	if angle < 0:
		angle += 360.0
	
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
		print("Calculated angle: ", angle)
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
	var angle := fmod(cam_yaw - obj_yaw + 360.0, 360.0)
	return _get_segment_from_angle(angle)

# Calculate segment for non-mirror cameras (full position-based version)
func _calculate_segment(camera: Camera3D) -> int:
	# Mirror pass – always use position-based calculation for mirrors
	if _is_mirror_camera:
		return _calculate_mirror_segment(camera)
	
	# Force yaw-only path if requested (but not for mirrors)
	if camera_yaw_only:
		return _calculate_segment_by_yaw(camera)
	
	# -------- Normal camera calculation (position based) --------
	var obj_pos: Vector3 = _reference_node.global_position
	var cam_pos: Vector3 = camera.global_position
	var dx: float = cam_pos.x - obj_pos.x
	var dz: float = cam_pos.z - obj_pos.z

	# If camera is effectively inside the object (first-person), use view direction
	if abs(dx) < 0.02 and abs(dz) < 0.02:
		var cam_forward: Vector3 = - camera.global_transform.basis.z
		cam_forward.y = 0
		if cam_forward.length_squared() > 0.0001:
			return _segment_from_direction(cam_forward.normalized())

	# Close-camera override
	var dist_sq := dx * dx + dz * dz
	if front_on_close_camera and dist_sq < close_camera_distance * close_camera_distance:
		_debug_last_angle = 0.0
		_debug_forward_comp = 0.0
		_debug_right_comp = 0.0
		return 0

	# Project camera vector into object local space
	var basis := _reference_node.global_transform.basis
	var forward: Vector3 = - basis.z
	var right: Vector3 = basis.x
	var f_comp: float = forward.x * dx + forward.z * dz
	var r_comp: float = right.x * dx + right.z * dz
	_debug_forward_comp = f_comp
	_debug_right_comp = r_comp
	var angle := rad_to_deg(atan2(r_comp, f_comp))
	if angle < 0:
		angle += 360.0
	_debug_last_angle = angle
	return _get_segment_from_angle(angle)

# Helper: derive segment from an arbitrary XZ-plane direction vector
func _segment_from_direction(dir: Vector3) -> int:
	var basis := _reference_node.global_transform.basis
	var forward: Vector3 = - basis.z
	var right: Vector3 = basis.x
	var f_comp := forward.x * dir.x + forward.z * dir.z
	var r_comp := right.x * dir.x + right.z * dir.z
	var angle := rad_to_deg(atan2(r_comp, f_comp))
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
	if angle >= 315 or angle < 45:
		return 0 # front
	elif (angle >= 45 and angle < 135) or (angle >= 225 and angle < 315):
		return 1 # side
	else:
		return 2 # back

func _segment_4(angle: float) -> int:
	# 90° quadrants centered on axes
	if angle >= 315 or angle < 45:
		return 0 # front
	elif angle < 135:
		return 1 # right
	elif angle < 225:
		return 2 # back
	else:
		return 3 # left

func _segment_8(angle: float) -> int:
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
	return {
		"angle_degrees": _debug_last_angle,
		"forward_component": _debug_forward_comp,
		"right_component": _debug_right_comp,
		"segment": seg,
		"direction_mode": direction_mode,
		"sprite_name": (seg >= 0 and seg < sprite_names.size()) and sprite_names[seg] or "",
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
