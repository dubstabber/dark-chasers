extends Node3D

class_name DoorTest

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
@onready var _meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	if not is_in_group("door"):
		add_to_group("door")

	_map = get_tree().get_first_node_in_group("map")
	if _anim:
		_anim.connect("animation_finished", _on_animation_finished)

	if _body:
		_meshes.clear()
		for child in _body.get_children():
			if child is MeshInstance3D:
				_meshes.append(child)


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
			_anim.play_backwards("Open")
			_playing_forward = false
			Utils.play_sound(close_sound, self)
		else:
			_anim.play("Open")
			_playing_forward = true
			Utils.play_sound(open_sound, self)
		return

	if _is_open:
		_anim.play_backwards("Open")
		_playing_forward = false
		Utils.play_sound(close_sound, self)
	else:
		_anim.play("Open")
		_playing_forward = true
		Utils.play_sound(open_sound, self)


func _on_animation_finished(anim_name: String) -> void:
	if anim_name != "Open":
		return

	_is_open = _playing_forward

	if stop_sound:
		Utils.play_sound(stop_sound, self)

	if _is_open and not open_only:
		await get_tree().create_timer(time_to_close).timeout
		if _is_open and not _anim.is_playing():
			_anim.play_backwards("Open")
			_playing_forward = false
			Utils.play_sound(close_sound, self)


func _get_door_aabb() -> AABB:
	var has_mesh := false
	var merged_aabb : AABB

	var mesh_list: Array[MeshInstance3D] = _meshes
	for mi in mesh_list:
		if mi:
			var aabb := mi.get_aabb()
			aabb.position += mi.transform.origin
			if not has_mesh:
				merged_aabb = aabb
				has_mesh = true
			else:
				merged_aabb = merged_aabb.merge(aabb)

	if has_mesh:
		return merged_aabb

	push_warning("DoorTest: MeshInstance3D reference(s) not found – ensure MeshInstance3D children exist or update the script.")
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


func _get_mesh_aabb_in_body_space(mi: MeshInstance3D) -> AABB:
	var local_aabb := mi.get_aabb()
	var to_body: Transform3D = _body.global_transform.affine_inverse() * mi.global_transform

	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)

	for x_sel in [0.0, 1.0]:
		for y_sel in [0.0, 1.0]:
			for z_sel in [0.0, 1.0]:
				var corner := local_aabb.position + Vector3(local_aabb.size.x * x_sel,
					local_aabb.size.y * y_sel,
					local_aabb.size.z * z_sel)
				var corner_body := to_body * corner
				min_v = min_v.min(corner_body)
				max_v = max_v.max(corner_body)
	return AABB(min_v, max_v - min_v)


func _get_side_from_local_point(local_p: Vector3) -> String:
	var best_side := ""
	var min_dist := INF

	var mesh_list: Array[MeshInstance3D] = _meshes

	for mi in mesh_list:
		if mi == null:
			continue
		var aabb: AABB = _get_mesh_aabb_in_body_space(mi)
		var half_size: Vector3 = aabb.size * 0.5
		var centre: Vector3 = aabb.position + half_size
		var delta: Vector3 = local_p - centre

		var dist_left   = abs((-half_size.x) - delta.x)
		var dist_right  = abs((+half_size.x) - delta.x)
		var dist_front  = abs((-half_size.z) - delta.z)
		var dist_back   = abs((+half_size.z) - delta.z)
		var dist_bottom = abs((-half_size.y) - delta.y)
		var dist_top    = abs((+half_size.y) - delta.y)

		# Check six distances for this mesh
		if dist_left < min_dist:
			min_dist = dist_left
			best_side = "LeftSide"
		if dist_right < min_dist:
			min_dist = dist_right
			best_side = "RightSide"
		if dist_front < min_dist:
			min_dist = dist_front
			best_side = "FrontSide"
		if dist_back < min_dist:
			min_dist = dist_back
			best_side = "BackSide"
		if dist_bottom < min_dist:
			min_dist = dist_bottom
			best_side = "BottomSide"
		if dist_top < min_dist:
			min_dist = dist_top
			best_side = "TopSide"

	return best_side


func open_with_point(hit_pos: Vector3) -> void:
	var local_p: Vector3 = _body.to_local(hit_pos)

	var side: String = _get_side_from_local_point(local_p)

	if is_side_allowed(side):
		_toggle_door()
	else:
		if locked_sound:
			Utils.play_sound(locked_sound, self)
		door_locked.emit(locked_message)
