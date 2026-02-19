class_name DoorBlockingComponent
extends Node

var _body: AnimatableBody3D
var _meshes: Array[MeshInstance3D] = []
var _allowed_sides_checker: Callable


func setup(body: AnimatableBody3D, meshes: Array[MeshInstance3D], allowed_sides_checker: Callable) -> void:
	_body = body
	_meshes = meshes
	_allowed_sides_checker = allowed_sides_checker


func is_blocked() -> bool:
	if not _body:
		return false

	var global_aabb: AABB = _get_global_door_aabb()

	var box_shape := BoxShape3D.new()
	box_shape.size = global_aabb.size

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box_shape
	query.transform = Transform3D(Basis.IDENTITY, global_aabb.position + global_aabb.size * 0.5)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_body.get_rid()]

	var space_state := _body.get_world_3d().direct_space_state
	var results: Array[Dictionary] = space_state.intersect_shape(query, 8)
	for hit in results:
		var collider: Object = hit.get("collider")
		if collider and _is_blocking_body(collider):
			if collider is Node3D:
				var local_p: Vector3 = _body.to_local(collider.global_transform.origin)
				var side_name: String = _get_side_from_local_point(local_p)
				if _allowed_sides_checker.is_valid() and not _allowed_sides_checker.call(side_name):
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

	for mi in _meshes:
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
