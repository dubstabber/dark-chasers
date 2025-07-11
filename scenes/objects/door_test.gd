extends Node3D

class_name Openable

signal door_locked(text)

@export var time_to_close := 1.2
@export var open_only := false
@export var key_needed: String
@export var locked_message: String
@export var open_sound  : AudioStream
@export var close_sound : AudioStream
@export var stop_sound  : AudioStream
@export var locked_sound : AudioStream
@export var can_interrupt := true

@export_group("Side selection")
@export var allow_front  : bool = true  # +-Z (local forward)
@export var allow_back   : bool = true  # –Z
@export var allow_left   : bool = false # –X
@export var allow_right  : bool = false # +X
@export var allow_top    : bool = false # +Y
@export var allow_bottom : bool = false # –Y

const _SIDE_NAMES := {
	"front":  "FrontSide",
	"back":   "BackSide",
	"left":   "LeftSide",
	"right":  "RightSide",
	"top":    "TopSide",
	"bottom": "BottomSide",
}

var _is_open := false
var _map: Node3D
var _playing_forward := true

@onready var _body = $"AnimatableBody3D"
@onready var _anim: AnimationPlayer = $"AnimationPlayer"
@onready var _mesh: MeshInstance3D = $"AnimatableBody3D/MeshInstance3D"


func _ready() -> void:
	if not is_in_group("door"):
		add_to_group("door")

	_map = get_tree().get_first_node_in_group("map")
	if _anim:
		_anim.connect("animation_finished", _on_animation_finished)


func _toggle_door(force := false) -> void:
	var is_unlocked := true
	if not force and _map and key_needed and key_needed not in _map.keys_collected:
		is_unlocked = false

	if not is_unlocked:
		door_locked.emit(locked_message)
		if locked_sound:
			Utils.play_sound(locked_sound, self)
		return

	if not _anim:
		push_warning("AnimationPlayer not found under door node, cannot animate")
		return

	if _anim.is_playing():
		if not can_interrupt:
			return
		
		if _playing_forward:
			_anim.play_backwards("Move up")
			_playing_forward = false
			Utils.play_sound(close_sound, self)
		else:
			_anim.play("Move up")
			_playing_forward = true
			Utils.play_sound(open_sound, self)
		return

	if _is_open:
		_anim.play_backwards("Move up")
		_playing_forward = false
		Utils.play_sound(close_sound, self)
	else:
		_anim.play("Move up")
		_playing_forward = true
		Utils.play_sound(open_sound, self)


func _on_animation_finished(anim_name: String) -> void:
	if anim_name != "Move up":
		return

	_is_open = _playing_forward

	if stop_sound:
		Utils.play_sound(stop_sound, self)

	if _is_open and not open_only:
		await get_tree().create_timer(time_to_close).timeout
		if _is_open and not _anim.is_playing():
			_anim.play_backwards("Move up")
			_playing_forward = false
			Utils.play_sound(close_sound, self)


func _get_door_aabb() -> AABB:
	if _mesh:
		return _mesh.get_aabb()
	push_warning("DoorTest: MeshInstance3D reference not found – ensure a child named 'MeshInstance3D' exists or update the script.")
	return AABB(Vector3.ZERO, Vector3.ONE)


func is_side_allowed(side_name: String) -> bool:
	match side_name:
		"FrontSide":  return allow_front
		"BackSide":   return allow_back
		"LeftSide":   return allow_left
		"RightSide":  return allow_right
		"TopSide":    return allow_top
		"BottomSide": return allow_bottom
		_:             return false


func open():
	_toggle_door(true)


func open_with_point(hit_pos: Vector3) -> void:
	var local_p: Vector3 = _body.to_local(hit_pos)

	var aabb: AABB = _get_door_aabb()
	var half_size: Vector3 = aabb.size * 0.5
	var centre: Vector3 = aabb.position + half_size
	var delta: Vector3 = local_p - centre

	var dist_left   = abs((-half_size.x) - delta.x)
	var dist_right  = abs((+half_size.x) - delta.x)
	var dist_front  = abs((-half_size.z) - delta.z)
	var dist_back   = abs((+half_size.z) - delta.z)
	var dist_bottom = abs((-half_size.y) - delta.y)
	var dist_top    = abs((+half_size.y) - delta.y)

	var min_dist = dist_left
	var side = "LeftSide"

	if dist_right < min_dist:
		min_dist = dist_right
		side = "RightSide"
	if dist_front < min_dist:
		min_dist = dist_front
		side = "FrontSide"
	if dist_back < min_dist:
		min_dist = dist_back
		side = "BackSide"
	if dist_bottom < min_dist:
		min_dist = dist_bottom
		side = "BottomSide"
	if dist_top < min_dist:
		side = "TopSide"

	if is_side_allowed(side):
		_toggle_door()
	else:
		if locked_sound:
			Utils.play_sound(locked_sound, self)
		door_locked.emit(locked_message)
