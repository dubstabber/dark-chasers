# A leaner, universal 2D/3D sprite animator that picks an animation based on the
# camera-to-object angle. Supports 3-, 4-, 8-directional sprites as well as the
# common “5 sprites + horizontal flip” variant.
#
# Public API kept identical where needed so existing scenes keep working.
# Author: refactored by Cascade 2025-07-17

class_name DirectionalSpriteAnimator extends Node

# ────────────────────────────────────────────────────────────────────────────────
#  ENUMS & EXPORTED PROPERTIES
# ────────────────────────────────────────────────────────────────────────────────

signal sprite_changed(new_sprite_name: String)

enum DirectionMode {
	THREE_DIRECTIONAL,      # front, side, back (uses 3 sprites, side can flip)
	FOUR_DIRECTIONAL,       # front, right, back, left (uses 4 sprites)
	EIGHT_DIRECTIONAL,      # 8 individual sprites (45° segments)
	EIGHT_DIRECTIONAL_FLIP  # 5 sprites, left-side variants are flipped
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

func _process(_delta):
	var camera := get_viewport().get_camera_3d()
	if camera == null or _reference_node == null:
		return

	var segment = _calculate_segment(camera)
	# When always_check_camera is off, skip further work if the segment is unchanged
	if not always_check_camera and segment == _last_segment:
		return

	_last_segment = segment
	_apply_segment(segment)

# ────────────────────────────────────────────────────────────────────────────────
#  SEGMENT CALCULATION
# ────────────────────────────────────────────────────────────────────────────────

func _calculate_segment(camera: Camera3D) -> int:
	# Vector from object to camera (XZ plane)
	var obj_pos: Vector3 = _reference_node.global_position
	var cam_pos: Vector3 = camera.global_position
	var dx: float = cam_pos.x - obj_pos.x
	var dz: float = cam_pos.z - obj_pos.z

	# ------------------------------------------------------------------
	#  Close-camera override
	# ------------------------------------------------------------------
	var dist_sq: float = dx * dx + dz * dz
	if front_on_close_camera and dist_sq < close_camera_distance * close_camera_distance:
		_debug_last_angle = 0.0
		_debug_forward_comp = 0.0
		_debug_right_comp = 0.0
		return 0  # "front" segment for any mode

	# Basis vectors in world space
	var basis := _reference_node.global_transform.basis
	var forward: Vector3 = -basis.z   # local -Z
	var right: Vector3   =  basis.x   # local +X

	# Dot-products to project into object’s local 2D space
	var f_comp: float = forward.x * dx + forward.z * dz
	var r_comp: float = right.x   * dx + right.z   * dz

	# Save for debug utility
	_debug_forward_comp = f_comp
	_debug_right_comp = r_comp

	# Angle in degrees (0° = forward, clockwise positive when looking from above)
	var angle: float = rad_to_deg(atan2(r_comp, f_comp))
	if angle < 0:
		angle += 360.0
	_debug_last_angle = angle

	match direction_mode:
		DirectionMode.THREE_DIRECTIONAL:
			return _segment_3(angle)
		DirectionMode.FOUR_DIRECTIONAL:
			return _segment_4(angle)
		_:
			return _segment_8(angle)  # covers both 8-dir modes

func _segment_3(angle: float) -> int:
	if angle >= 315 or angle < 45:
		return 0  # front
	elif angle < 135 or angle >= 225 and angle < 315:
		return 1  # side
	else:
		return 2  # back

func _segment_4(angle: float) -> int:
	# 90° quadrants centered on axes
	if angle >= 315 or angle < 45:
		return 0  # front
	elif angle < 135:
		return 1  # right
	elif angle < 225:
		return 2  # back
	else:
		return 3  # left

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
			index = [0, 1, 2][segment]  # front/side/back order
			if segment == 1:
				# Determine side orientation: right halves (45-135°) need flip
				flip = _is_right_side()
		DirectionMode.FOUR_DIRECTIONAL:
			index = segment  # 0-3 match sprite order
		DirectionMode.EIGHT_DIRECTIONAL:
			index = segment  # 0-7 direct mapping
		DirectionMode.EIGHT_DIRECTIONAL_FLIP:
			var map = [0, 1, 2, 3, 4, 3, 2, 1]
			index = map[segment]
			flip = segment >= 5   # left/back-left/front-left
		_:
			pass

	if index >= sprite_names.size():
		push_error("DirectionalSpriteAnimator: sprite_names too short for mode")
		return

	_set_sprite(sprite_names[index], flip)

func _is_right_side() -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _reference_node == null:
		return false

	# Vector from object to camera in world space
	var delta := cam.global_position - _reference_node.global_position

	# Project that vector onto the object's local right axis
	var right_vec: Vector3 = _reference_node.global_transform.basis.x
	var right_component: float = right_vec.x * delta.x + right_vec.z * delta.z

	# Positive component ⇒ camera is on object's right side
	return right_component > 0

# ────────────────────────────────────────────────────────────────────────────────
#  PLAY / FLIP
# ────────────────────────────────────────────────────────────────────────────────

func _set_sprite(anim_name: String, flip: bool):
	if _sprite_node == null:
		return

	if _sprite_node.has_method("play"):
		if _sprite_node.animation != anim_name:
			_sprite_node.play(anim_name)
	elif _sprite_node.has_method("set_texture"):
		# For Sprite3D fallback (single frame)
		_sprite_node.set_texture(ResourceLoader.load(anim_name))

	if "flip_h" in _sprite_node:
		_sprite_node.flip_h = flip

	_current_flip_h = flip
	sprite_changed.emit(anim_name)

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
