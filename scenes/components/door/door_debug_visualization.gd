@tool
class_name DoorDebugVisualization
extends Node

var _body: AnimatableBody3D
var _meshes: Array[MeshInstance3D] = []
var _debug_face_meshes: Array[MeshInstance3D] = []
var _debug_materials: Dictionary = {}
var _side_states: Dictionary = {
	"FrontSide": true,
	"BackSide": true,
	"LeftSide": false,
	"RightSide": false,
	"TopSide": false,
	"BottomSide": false,
}
var _show_debug_faces: bool = false


func setup(body: AnimatableBody3D, meshes: Array[MeshInstance3D]) -> void:
	_body = body
	_meshes = meshes


func set_show_debug_faces(value: bool) -> void:
	_show_debug_faces = value
	update_visualization()


func set_side_allowed(side_name: String, allowed: bool) -> void:
	_side_states[side_name] = allowed
	update_visualization()


func update_visualization() -> void:
	if not Engine.is_editor_hint():
		return

	_clear_debug_faces()

	if _show_debug_faces:
		_create_debug_faces()


func cleanup() -> void:
	_clear_debug_faces()


func _clear_debug_faces() -> void:
	for debug_mesh in _debug_face_meshes:
		if is_instance_valid(debug_mesh):
			debug_mesh.queue_free()
	_debug_face_meshes.clear()


func _create_debug_faces() -> void:
	if not _body:
		return

	_ensure_debug_materials()

	var door_aabb := _get_door_aabb()
	if door_aabb.size == Vector3.ZERO:
		return

	_create_debug_face_for_side("FrontSide", door_aabb, _side_states.get("FrontSide", false))
	_create_debug_face_for_side("BackSide", door_aabb, _side_states.get("BackSide", false))
	_create_debug_face_for_side("LeftSide", door_aabb, _side_states.get("LeftSide", false))
	_create_debug_face_for_side("RightSide", door_aabb, _side_states.get("RightSide", false))
	_create_debug_face_for_side("TopSide", door_aabb, _side_states.get("TopSide", false))
	_create_debug_face_for_side("BottomSide", door_aabb, _side_states.get("BottomSide", false))


func _ensure_debug_materials() -> void:
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


func _get_door_aabb() -> AABB:
	var has_mesh := false
	var merged_aabb: AABB

	for mi in _meshes:
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

	return AABB(Vector3.ZERO, Vector3.ONE)


func _create_debug_face_for_side(side_name: String, aabb: AABB, is_allowed: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	var quad_mesh := QuadMesh.new()

	var face_transform := Transform3D.IDENTITY
	var center := aabb.position + aabb.size * 0.5
	var offset_distance := 0.02

	match side_name:
		"FrontSide":
			quad_mesh.size = Vector2(aabb.size.x * 1.1, aabb.size.y * 1.1)
			face_transform.origin = center + Vector3(0, 0, -aabb.size.z * 0.5 - offset_distance)
			face_transform.basis = Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)
		"BackSide":
			quad_mesh.size = Vector2(aabb.size.x * 1.1, aabb.size.y * 1.1)
			face_transform.origin = center + Vector3(0, 0, aabb.size.z * 0.5 + offset_distance)
			face_transform.basis = Basis(Vector3.LEFT, Vector3.UP, Vector3.BACK)
		"LeftSide":
			quad_mesh.size = Vector2(aabb.size.z * 1.1, aabb.size.y * 1.1)
			face_transform.origin = center + Vector3(-aabb.size.x * 0.5 - offset_distance, 0, 0)
			face_transform.basis = Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
		"RightSide":
			quad_mesh.size = Vector2(aabb.size.z * 1.1, aabb.size.y * 1.1)
			face_transform.origin = center + Vector3(aabb.size.x * 0.5 + offset_distance, 0, 0)
			face_transform.basis = Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)
		"TopSide":
			quad_mesh.size = Vector2(aabb.size.x * 1.1, aabb.size.z * 1.1)
			face_transform.origin = center + Vector3(0, aabb.size.y * 0.5 + offset_distance, 0)
			face_transform.basis = Basis(Vector3.RIGHT, Vector3.BACK, Vector3.UP)
		"BottomSide":
			quad_mesh.size = Vector2(aabb.size.x * 1.1, aabb.size.z * 1.1)
			face_transform.origin = center + Vector3(0, -aabb.size.y * 0.5 - offset_distance, 0)
			face_transform.basis = Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN)

	mesh_instance.mesh = quad_mesh
	mesh_instance.transform = face_transform

	var material_key := "allowed" if is_allowed else "not_allowed"
	mesh_instance.material_override = _debug_materials[material_key]

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.visibility_range_begin_margin = 0.0
	mesh_instance.visibility_range_end_margin = 0.0

	_body.add_child(mesh_instance)
	_debug_face_meshes.append(mesh_instance)
