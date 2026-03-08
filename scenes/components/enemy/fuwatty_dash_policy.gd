class_name FuwattyDashPolicy
extends RefCounted

const DASH_VERTICAL_REACH_PER_METER := 0.2


func enemy_has_target(enemy: CharacterBody3D) -> bool:
	if enemy == null:
		return false
	return enemy.get("current_target") is Node3D


func resolve_target(enemy: CharacterBody3D) -> Node3D:
	if enemy == null:
		return null
	return enemy.get("current_target") as Node3D


func resolve_target_direction(enemy: CharacterBody3D) -> Vector3:
	var target := resolve_target(enemy)
	if enemy == null or target == null:
		return Vector3.ZERO
	var dash_direction := target.global_position - enemy.global_position
	dash_direction.y = 0.0
	if dash_direction.length_squared() <= 0.000001:
		return Vector3.ZERO
	return dash_direction.normalized()


func can_commit_to_dash(
	enemy: CharacterBody3D,
	min_dash_target_distance_m: float,
	max_dash_target_distance_m: float,
	require_clear_dash_path: bool,
	obstacle_clearance_margin: float,
	dash_distance_m: float,
	height_offsets: Array,
	require_path_clearance: bool = true
) -> bool:
	if not enemy_has_target(enemy):
		return false
	if not is_target_in_enemy_room(enemy):
		return false
	if not is_target_in_enemy_dash_range(enemy, min_dash_target_distance_m, max_dash_target_distance_m):
		return false
	if not is_target_height_reachable_for_dash(enemy, dash_distance_m, height_offsets):
		return false
	if require_path_clearance and require_clear_dash_path and not is_dash_path_clear_to_target(enemy, obstacle_clearance_margin, dash_distance_m, height_offsets):
		return false
	return true


func is_target_in_enemy_room(enemy: CharacterBody3D) -> bool:
	if enemy == null:
		return false
	var target := resolve_target(enemy)
	if target == null:
		return false
	var enemy_room := get_room_name(enemy)
	if enemy_room == "":
		return true
	var target_room := get_room_name(target)
	if target_room == "":
		return true
	return target_room == enemy_room


func get_room_name(node: Object) -> String:
	if node == null:
		return ""
	for property in node.get_property_list():
		if String(property.get("name", "")) == "current_room":
			var room_value = node.get("current_room")
			return "" if room_value == null else String(room_value)
	return ""


func is_target_in_enemy_dash_range(enemy: CharacterBody3D, min_dash_target_distance_m: float, max_dash_target_distance_m: float) -> bool:
	if enemy == null:
		return false
	var target := resolve_target(enemy)
	if target == null:
		return false
	return is_distance_in_dash_range(_horizontal_distance(enemy.global_position, target.global_position), min_dash_target_distance_m, max_dash_target_distance_m)


func is_target_height_reachable_for_dash(enemy: CharacterBody3D, _dash_distance_m: float, height_offsets: Array) -> bool:
	if enemy == null:
		return false
	var target := resolve_target(enemy)
	if target == null:
		return false
	var horizontal_distance := _horizontal_distance(enemy.global_position, target.global_position)
	var clearance_height := _max_height_offset(height_offsets)
	var max_vertical_delta := clearance_height + (horizontal_distance * DASH_VERTICAL_REACH_PER_METER)
	return absf(target.global_position.y - enemy.global_position.y) <= max_vertical_delta


func is_distance_in_dash_range(distance: float, min_dash_target_distance_m: float, max_dash_target_distance_m: float) -> bool:
	if distance < maxf(0.0, min_dash_target_distance_m):
		return false
	if max_dash_target_distance_m > 0.0 and distance > max_dash_target_distance_m:
		return false
	return true


func is_dash_motion_blocked(enemy: CharacterBody3D, motion: Vector3, obstacle_clearance_margin: float, height_offsets: Array) -> bool:
	if enemy == null:
		return true
	if motion.length_squared() <= 0.000001:
		return false
	var target := resolve_target(enemy)
	var collision := KinematicCollision3D.new()
	var collides := enemy.test_move(enemy.global_transform, motion, collision, maxf(0.001, obstacle_clearance_margin), false)
	if not collides:
		return false
	var collider_node: Node = collision.get_collider() as Node
	if collider_node == null:
		if target == null:
			return true
		return not raycast_path_hits_only_target(enemy, target, motion, height_offsets)
	if target == null:
		return true
	return not is_allowed_target_hit(collider_node, target)


func is_dash_path_clear_to_target(enemy: CharacterBody3D, obstacle_clearance_margin: float, dash_distance_m: float, height_offsets: Array) -> bool:
	if enemy == null:
		return false
	var target := resolve_target(enemy)
	if target == null:
		return false
	var to_target := target.global_position - enemy.global_position
	to_target.y = 0.0
	var target_distance := to_target.length()
	if target_distance <= 0.000001:
		return true
	var motion := to_target.normalized() * minf(target_distance, dash_distance_m)
	var collision := KinematicCollision3D.new()
	var collides := enemy.test_move(enemy.global_transform, motion, collision, maxf(0.001, obstacle_clearance_margin), false)
	if not collides:
		return true
	var collider_node: Node = collision.get_collider() as Node
	if collider_node != null and is_allowed_target_hit(collider_node, target):
		return true
	if has_elevated_dash_path_clearance(enemy, target, motion, obstacle_clearance_margin, height_offsets):
		return true
	if collider_node == null:
		return raycast_path_hits_only_target(enemy, target, motion, height_offsets)
	return false


func has_elevated_dash_path_clearance(enemy: CharacterBody3D, target: Node3D, motion: Vector3, obstacle_clearance_margin: float, height_offsets: Array) -> bool:
	if enemy == null or target == null:
		return false
	for height_offset in height_offsets:
		var probe_transform := enemy.global_transform
		probe_transform.origin += Vector3.UP * float(height_offset)
		var probe_collision := KinematicCollision3D.new()
		var probe_collides := enemy.test_move(probe_transform, motion, probe_collision, maxf(0.001, obstacle_clearance_margin), false)
		if not probe_collides:
			return true
		var probe_collider: Node = probe_collision.get_collider() as Node
		if probe_collider != null and is_allowed_target_hit(probe_collider, target):
			return true
	return false


func raycast_path_hits_only_target(enemy: CharacterBody3D, target: Node3D, motion: Vector3, height_offsets: Array) -> bool:
	if enemy == null or target == null:
		return false
	if motion.length_squared() <= 0.000001:
		return true
	var world := enemy.get_world_3d()
	if world == null:
		return false
	var space_state := world.direct_space_state
	if space_state == null:
		return false
	for height_offset in height_offsets:
		if raycast_path_hits_only_target_at_height(space_state, enemy, target, motion, float(height_offset)):
			return true
	return false


func raycast_path_hits_only_target_at_height(space_state: PhysicsDirectSpaceState3D, enemy: CharacterBody3D, target: Node3D, motion: Vector3, height_offset: float) -> bool:
	if space_state == null or enemy == null or target == null:
		return false
	var params := PhysicsRayQueryParameters3D.new()
	params.from = enemy.global_position + Vector3.UP * height_offset
	params.to = params.from + motion
	params.exclude = [enemy]
	params.collision_mask = enemy.collision_mask
	var result := space_state.intersect_ray(params)
	if result.is_empty():
		return true
	var hit_node: Node = result.get("collider") as Node
	if hit_node == null:
		return false
	return is_allowed_target_hit(hit_node, target)


func is_allowed_target_hit(collider_node: Node, target: Node3D) -> bool:
	if collider_node == null or target == null:
		return false
	if collider_node == target:
		return true
	if collider_node.is_in_group("player"):
		return true
	if target.is_ancestor_of(collider_node):
		return true
	return collider_node.is_ancestor_of(target)


func _max_height_offset(height_offsets: Array) -> float:
	var max_height_offset := 0.0
	for height_offset in height_offsets:
		max_height_offset = maxf(max_height_offset, float(height_offset))
	return max_height_offset


func _horizontal_distance(from_pos: Vector3, to_pos: Vector3) -> float:
	var delta := to_pos - from_pos
	delta.y = 0.0
	return delta.length()
