@tool
extends Node3D
class_name Openable


signal door_locked(text)

@export var time_to_close := 1.2
@export var open_only := false
@export var key_needed: String
@export var locked_message: String
@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var stop_sound: AudioStream
@export var locked_sound: AudioStream
@export var can_interrupt := true

@export_group("Side selection")
@export var allow_front: bool = true: set = _set_allow_front # +-Z (local forward)
@export var allow_back: bool = true: set = _set_allow_back # –Z
@export var allow_left: bool = false: set = _set_allow_left # –X
@export var allow_right: bool = false: set = _set_allow_right # +X
@export var allow_top: bool = false: set = _set_allow_top # +Y
@export var allow_bottom: bool = false: set = _set_allow_bottom # –Y

@export_group("Debug Visualization")
@export var show_debug_faces: bool = false: set = _set_show_debug_faces

const _SIDE_NAMES := {
	"front": "FrontSide",
	"back": "BackSide",
	"left": "LeftSide",
	"right": "RightSide",
	"top": "TopSide",
	"bottom": "BottomSide",
}

var _is_open := false
var _map: Node3D
var _playing_forward := true
var _has_reversed_due_block := false
var _current_open_sound: AudioStreamPlayer3D
var _current_close_sound: AudioStreamPlayer3D

# Debug visualization variables
var _debug_face_meshes: Array[MeshInstance3D] = []
var _debug_materials: Dictionary = {}

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

	# Initialize debug visualization in editor
	if Engine.is_editor_hint():
		_update_debug_visualization()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		_clear_debug_faces()


func _is_sound_looping(audio_stream: AudioStream) -> bool:
	# Check if the audio stream is set to loop
	if audio_stream is AudioStreamOggVorbis:
		return audio_stream.loop
	elif audio_stream is AudioStreamWAV:
		return audio_stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
	elif audio_stream is AudioStreamMP3:
		return audio_stream.loop
	# Add other audio stream types as needed
	return false


func _update_current_sound_reference(new_sound: AudioStreamPlayer3D, is_open_sound: bool) -> void:
	# Stop the previous sound only if it's looping, otherwise let it finish naturally
	if is_open_sound:
		if _current_open_sound and is_instance_valid(_current_open_sound):
			if _is_sound_looping(_current_open_sound.stream):
				_current_open_sound.stop()
		_current_open_sound = new_sound
	else:
		if _current_close_sound and is_instance_valid(_current_close_sound):
			if _is_sound_looping(_current_close_sound.stream):
				_current_close_sound.stop()
		_current_close_sound = new_sound


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

		if _anim.current_animation == "Open" and _anim.speed_scale < 0:
			_anim.speed_scale = abs(_anim.speed_scale)
			_playing_forward = true
			_has_reversed_due_block = true
			if open_sound:
				var new_sound = Utils.play_sound(open_sound, self)
				_update_current_sound_reference(new_sound, true)
		elif _playing_forward:
			_anim.play_backwards("Open")
			_playing_forward = false
			if close_sound:
				var new_sound = Utils.play_sound(close_sound, self)
				_update_current_sound_reference(new_sound, false)
		else:
			_anim.play("Open")
			_playing_forward = true
			if open_sound:
				var new_sound = Utils.play_sound(open_sound, self)
				_update_current_sound_reference(new_sound, true)
		return

	if _is_open:
		if (not can_interrupt) and not force:
			return
		_anim.play_backwards("Open")
		_playing_forward = false
		if close_sound:
			var new_sound = Utils.play_sound(close_sound, self)
			_update_current_sound_reference(new_sound, false)
	else:
		_anim.play("Open")
		_playing_forward = true
		if open_sound:
			var new_sound = Utils.play_sound(open_sound, self)
			_update_current_sound_reference(new_sound, true)


func _on_animation_finished(anim_name: String) -> void:
	if anim_name != "Open":
		return

	_is_open = _playing_forward

	# Only stop sounds that are set to loop - let non-looping sounds finish naturally
	if _current_open_sound and is_instance_valid(_current_open_sound):
		if _is_sound_looping(_current_open_sound.stream):
			_current_open_sound.stop()
		_current_open_sound = null

	if _current_close_sound and is_instance_valid(_current_close_sound):
		if _is_sound_looping(_current_close_sound.stream):
			_current_close_sound.stop()
		_current_close_sound = null

	if stop_sound:
		Utils.play_sound(stop_sound, self)

	if _is_open and not open_only:
		await get_tree().create_timer(time_to_close).timeout
		if _is_open and not _anim.is_playing():
			_anim.play_backwards("Open")
			_playing_forward = false
			if close_sound:
				var new_sound = Utils.play_sound(close_sound, self)
				_update_current_sound_reference(new_sound, false)


func _get_door_aabb() -> AABB:
	var has_mesh := false
	var merged_aabb: AABB

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
		"FrontSide": return allow_front
		"BackSide": return allow_back
		"LeftSide": return allow_left
		"RightSide": return allow_right
		"TopSide": return allow_top
		"BottomSide": return allow_bottom
		_: return false


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

		var dist_left = abs((-half_size.x) - delta.x)
		var dist_right = abs((+half_size.x) - delta.x)
		var dist_front = abs((-half_size.z) - delta.z)
		var dist_back = abs((+half_size.z) - delta.z)
		var dist_bottom = abs((-half_size.y) - delta.y)
		var dist_top = abs((+half_size.y) - delta.y)

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


# --- Blocking & Auto-reopen logic -------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _anim and _anim.is_playing() and not _playing_forward and can_interrupt and not _has_reversed_due_block:
		if _is_blocked():
			_toggle_door()


func _is_blocked() -> bool:
	var global_aabb: AABB = _get_global_door_aabb()

	var box_shape := BoxShape3D.new()
	box_shape.size = global_aabb.size

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box_shape
	query.transform = Transform3D(Basis.IDENTITY, global_aabb.position + global_aabb.size * 0.5)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if _body:
		query.exclude = [_body.get_rid()]

	var space_state := get_world_3d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(query, 8)
	for hit in results:
		var collider: Object = hit.get("collider")
		if collider and _is_blocking_body(collider):
			if collider is Node3D:
				var local_p: Vector3 = _body.to_local(collider.global_transform.origin)
				var side_name: String = _get_side_from_local_point(local_p)
				if not is_side_allowed(side_name):
					continue
			return true
	return false


func _is_blocking_body(body: Object) -> bool:
	var node: Node = body
	while node:
		if node is CharacterBody3D or node is RigidBody3D:
			return true
		node = node.get_parent()
	return false


func _get_global_door_aabb() -> AABB:
	var local_aabb := _get_door_aabb()
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	for x_sel in [0.0, 1.0]:
		for y_sel in [0.0, 1.0]:
			for z_sel in [0.0, 1.0]:
				var corner_local := local_aabb.position + Vector3(local_aabb.size.x * x_sel,
					local_aabb.size.y * y_sel,
					local_aabb.size.z * z_sel)
				var corner_global: Vector3 = _body.to_global(corner_local)
				min_v = min_v.min(corner_global)
				max_v = max_v.max(corner_global)
	return AABB(min_v, max_v - min_v)


# --- Debug Visualization Methods ---

func _set_allow_front(value: bool) -> void:
	allow_front = value
	_update_debug_visualization()

func _set_allow_back(value: bool) -> void:
	allow_back = value
	_update_debug_visualization()

func _set_allow_left(value: bool) -> void:
	allow_left = value
	_update_debug_visualization()

func _set_allow_right(value: bool) -> void:
	allow_right = value
	_update_debug_visualization()

func _set_allow_top(value: bool) -> void:
	allow_top = value
	_update_debug_visualization()

func _set_allow_bottom(value: bool) -> void:
	allow_bottom = value
	_update_debug_visualization()

func _set_show_debug_faces(value: bool) -> void:
	show_debug_faces = value
	_update_debug_visualization()

func _update_debug_visualization() -> void:
	if not Engine.is_editor_hint():
		return

	_clear_debug_faces()

	if show_debug_faces:
		_create_debug_faces()

func _clear_debug_faces() -> void:
	for debug_mesh in _debug_face_meshes:
		if is_instance_valid(debug_mesh):
			debug_mesh.queue_free()
	_debug_face_meshes.clear()

func _create_debug_faces() -> void:
	if not _body:
		return

	# Create debug materials if they don't exist
	if not _debug_materials.has("allowed"):
		var allowed_material := StandardMaterial3D.new()
		allowed_material.albedo_color = Color.GREEN
		allowed_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		allowed_material.albedo_color.a = 0.5
		allowed_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		allowed_material.no_depth_test = true
		allowed_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		allowed_material.flags_unshaded = true
		allowed_material.flags_do_not_use_vertex_lighting = true
		_debug_materials["allowed"] = allowed_material

	if not _debug_materials.has("not_allowed"):
		var not_allowed_material := StandardMaterial3D.new()
		not_allowed_material.albedo_color = Color.RED
		not_allowed_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		not_allowed_material.albedo_color.a = 0.5
		not_allowed_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		not_allowed_material.no_depth_test = true
		not_allowed_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		not_allowed_material.flags_unshaded = true
		not_allowed_material.flags_do_not_use_vertex_lighting = true
		_debug_materials["not_allowed"] = not_allowed_material

	# Get the door's AABB to create face planes
	var door_aabb := _get_door_aabb()
	if door_aabb.size == Vector3.ZERO:
		return

	# Create debug faces for each side
	_create_debug_face_for_side("FrontSide", door_aabb, allow_front)
	_create_debug_face_for_side("BackSide", door_aabb, allow_back)
	_create_debug_face_for_side("LeftSide", door_aabb, allow_left)
	_create_debug_face_for_side("RightSide", door_aabb, allow_right)
	_create_debug_face_for_side("TopSide", door_aabb, allow_top)
	_create_debug_face_for_side("BottomSide", door_aabb, allow_bottom)

func _create_debug_face_for_side(side_name: String, aabb: AABB, is_allowed: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()

	# Calculate face position and orientation based on side
	var face_transform := Transform3D.IDENTITY
	var center := aabb.position + aabb.size * 0.5
	var offset_distance := 0.02 # Small offset to prevent z-fighting and ensure visibility

	match side_name:
		"FrontSide": # -Z
			quad_mesh.size = Vector2(aabb.size.x * 1.1, aabb.size.y * 1.1) # Slightly larger for better visibility
			face_transform.origin = center + Vector3(0, 0, -aabb.size.z * 0.5 - offset_distance)
			face_transform.basis = Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)
		"BackSide": # +Z
			quad_mesh.size = Vector2(aabb.size.x * 1.1, aabb.size.y * 1.1)
			face_transform.origin = center + Vector3(0, 0, aabb.size.z * 0.5 + offset_distance)
			face_transform.basis = Basis(Vector3.LEFT, Vector3.UP, Vector3.BACK)
		"LeftSide": # -X
			quad_mesh.size = Vector2(aabb.size.z * 1.1, aabb.size.y * 1.1)
			face_transform.origin = center + Vector3(-aabb.size.x * 0.5 - offset_distance, 0, 0)
			face_transform.basis = Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
		"RightSide": # +X
			quad_mesh.size = Vector2(aabb.size.z * 1.1, aabb.size.y * 1.1)
			face_transform.origin = center + Vector3(aabb.size.x * 0.5 + offset_distance, 0, 0)
			face_transform.basis = Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)
		"TopSide": # +Y
			quad_mesh.size = Vector2(aabb.size.x * 1.1, aabb.size.z * 1.1)
			face_transform.origin = center + Vector3(0, aabb.size.y * 0.5 + offset_distance, 0)
			face_transform.basis = Basis(Vector3.RIGHT, Vector3.BACK, Vector3.UP)
		"BottomSide": # -Y
			quad_mesh.size = Vector2(aabb.size.x * 1.1, aabb.size.z * 1.1)
			face_transform.origin = center + Vector3(0, -aabb.size.y * 0.5 - offset_distance, 0)
			face_transform.basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN)

	mesh_instance.mesh = quad_mesh
	mesh_instance.transform = face_transform

	# Apply appropriate material based on whether the side is allowed
	var material_key := "allowed" if is_allowed else "not_allowed"
	mesh_instance.material_override = _debug_materials[material_key]

	# Set rendering properties for better visibility
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_begin_margin = 0.0
	mesh_instance.visibility_range_end_margin = 0.0

	# Add to the body so it moves with the door
	_body.add_child(mesh_instance)
	_debug_face_meshes.append(mesh_instance)
