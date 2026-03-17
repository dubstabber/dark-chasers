class_name StairStepHelper
extends Node

const EPSILON := 0.000001
const FLOOR_ANGLE_EPSILON := 0.05

var _last_debug_message := ""
var _last_debug_time_msec := 0

func try_step_up(body: CharacterBody3D, delta: float, max_step_height: float, min_horizontal_speed: float, down_probe_distance: float, debug_enabled: bool = false) -> bool:
	if body == null:
		return false
	if delta <= 0.0 or max_step_height <= 0.0:
		return false
	var up_direction := body.up_direction.normalized()
	if up_direction.length_squared() <= EPSILON:
		return false
	if not body.is_on_floor():
		return false
	if body.velocity.dot(up_direction) > 0.05:
		return false
	var horizontal_velocity := body.velocity.slide(up_direction)
	if horizontal_velocity.length() < min_horizontal_speed:
		return false
	var horizontal_motion := horizontal_velocity * delta
	if horizontal_motion.length_squared() <= EPSILON:
		return false
	var horizontal_direction := horizontal_motion.normalized()
	var motion_collision := KinematicCollision3D.new()
	var margin := maxf(0.001, body.safe_margin)
	var blocked := body.test_move(body.global_transform, horizontal_motion, motion_collision, margin, false)
	if not blocked:
		return false
	var body_horizontal_extent: float = _get_body_horizontal_extent(body)
	var current_floor := _find_current_support_floor(
		body,
		body.global_transform.origin,
		up_direction,
		max_step_height,
		down_probe_distance,
		horizontal_direction,
		body_horizontal_extent,
		margin
	)
	if current_floor.is_empty():
		_debug_log(debug_enabled, "fail current_floor support=false motion=%.3f extent=%.3f" % [horizontal_motion.length(), body_horizontal_extent])
		return false
	var current_floor_position: Vector3 = current_floor["position"]
	var debug_info := {
		"forward_distances": [],
		"landing_floor_hits": 0,
		"landing_floor_misses": 0,
		"rejected_too_low": 0,
		"rejected_too_high": 0,
		"fallback_hits": 0,
		"fallback_misses": 0
	}
	var step_candidate := _find_step_candidate(
		body,
		body.global_transform.origin,
		current_floor_position,
		motion_collision,
		horizontal_direction,
		up_direction,
		body_horizontal_extent,
		horizontal_motion.length(),
		max_step_height,
		down_probe_distance,
		margin,
		debug_info
	)
	if step_candidate.is_empty():
		_debug_log(
			debug_enabled,
			"fail step_candidate support_hits=%d support_misses=%d low=%d high=%d fallback_hits=%d fallback_misses=%d forward=%s collision=%s" % [
				debug_info["landing_floor_hits"],
				debug_info["landing_floor_misses"],
				debug_info["rejected_too_low"],
				debug_info["rejected_too_high"],
				debug_info["fallback_hits"],
				debug_info["fallback_misses"],
				str(debug_info["forward_distances"]),
				_str_vec3(motion_collision.get_position())
			]
		)
		return false
	var step_height: float = step_candidate["height"]
	var step_target_forward_distance: float = step_candidate["forward_distance"]
	if step_height <= margin:
		_debug_log(debug_enabled, "fail step_height low=%.3f margin=%.4f" % [step_height, margin])
		return false
	if step_height > max_step_height + margin:
		_debug_log(debug_enabled, "fail step_height high=%.3f max=%.3f" % [step_height, max_step_height])
		return false
	var stepped_transform := body.global_transform
	stepped_transform.origin += up_direction * step_height
	var step_forward_distance: float = _find_step_in_distance(
		body,
		stepped_transform,
		horizontal_direction,
		body_horizontal_extent,
		horizontal_motion.length(),
		step_target_forward_distance,
		margin
	)
	if step_forward_distance <= margin:
		_debug_log(
			debug_enabled,
			"fail step_in height=%.3f target_forward=%.3f motion=%.3f" % [
				step_height,
				step_target_forward_distance,
				horizontal_motion.length()
			]
		)
		return false
	var remaining_horizontal_distance: float = maxf(horizontal_motion.length() - step_forward_distance, 0.0)
	var vertical_velocity: float = body.velocity.dot(up_direction)
	body.global_position += up_direction * step_height
	body.global_position += horizontal_direction * step_forward_distance
	body.velocity = (horizontal_direction * (remaining_horizontal_distance / delta)) + (up_direction * vertical_velocity)
	_debug_log(
		debug_enabled,
		"success height=%.3f step_in=%.3f remaining=%.3f forward=%s" % [
			step_height,
			step_forward_distance,
			remaining_horizontal_distance,
			str(debug_info["forward_distances"])
		]
	)
	return true


func can_step_up_for_motion(body: CharacterBody3D, horizontal_motion: Vector3, max_step_height: float, down_probe_distance: float, min_horizontal_speed: float = 0.0, debug_enabled: bool = false) -> bool:
	if body == null:
		return false
	if max_step_height <= 0.0:
		return false
	var up_direction := body.up_direction.normalized()
	if up_direction.length_squared() <= EPSILON:
		return false
	if not body.is_on_floor():
		return false
	if body.velocity.dot(up_direction) > 0.05:
		return false
	var horizontal_velocity := body.velocity.slide(up_direction)
	if horizontal_velocity.length() < min_horizontal_speed:
		return false
	if horizontal_motion.length_squared() <= EPSILON:
		return false
	var horizontal_direction := horizontal_motion.normalized()
	var motion_collision := KinematicCollision3D.new()
	var margin := maxf(0.001, body.safe_margin)
	var blocked := body.test_move(body.global_transform, horizontal_motion, motion_collision, margin, false)
	if not blocked:
		return false
	var body_horizontal_extent: float = _get_body_horizontal_extent(body)
	var current_floor := _find_current_support_floor(
		body,
		body.global_transform.origin,
		up_direction,
		max_step_height,
		down_probe_distance,
		horizontal_direction,
		body_horizontal_extent,
		margin
	)
	if current_floor.is_empty():
		_debug_log(debug_enabled, "probe fail current_floor support=false motion=%.3f extent=%.3f" % [horizontal_motion.length(), body_horizontal_extent])
		return false
	var current_floor_position: Vector3 = current_floor["position"]
	var debug_info := {
		"forward_distances": [],
		"landing_floor_hits": 0,
		"landing_floor_misses": 0,
		"rejected_too_low": 0,
		"rejected_too_high": 0,
		"fallback_hits": 0,
		"fallback_misses": 0
	}
	var step_candidate := _find_step_candidate(
		body,
		body.global_transform.origin,
		current_floor_position,
		motion_collision,
		horizontal_direction,
		up_direction,
		body_horizontal_extent,
		horizontal_motion.length(),
		max_step_height,
		down_probe_distance,
		margin,
		debug_info
	)
	if step_candidate.is_empty():
		_debug_log(
			debug_enabled,
			"probe fail step_candidate support_hits=%d support_misses=%d low=%d high=%d fallback_hits=%d fallback_misses=%d forward=%s collision=%s" % [
				debug_info["landing_floor_hits"],
				debug_info["landing_floor_misses"],
				debug_info["rejected_too_low"],
				debug_info["rejected_too_high"],
				debug_info["fallback_hits"],
				debug_info["fallback_misses"],
				str(debug_info["forward_distances"]),
				_str_vec3(motion_collision.get_position())
			]
		)
		return false
	var step_height: float = step_candidate["height"]
	var step_target_forward_distance: float = step_candidate["forward_distance"]
	if step_height <= margin:
		return false
	if step_height > max_step_height + margin:
		return false
	var stepped_transform := body.global_transform
	stepped_transform.origin += up_direction * step_height
	var step_forward_distance: float = _find_step_in_distance(
		body,
		stepped_transform,
		horizontal_direction,
		body_horizontal_extent,
		horizontal_motion.length(),
		step_target_forward_distance,
		margin
	)
	return step_forward_distance > margin


func _find_step_candidate(body: CharacterBody3D, origin: Vector3, current_floor_position: Vector3, motion_collision: KinematicCollision3D, horizontal_direction: Vector3, up_direction: Vector3, body_horizontal_extent: float, motion_distance: float, max_step_height: float, down_probe_distance: float, margin: float, debug_info: Dictionary) -> Dictionary:
	var forward_distances: Array[float] = _get_forward_probe_distances(origin, motion_collision, horizontal_direction, up_direction, body_horizontal_extent, motion_distance, margin)
	debug_info["forward_distances"] = forward_distances.duplicate()
	var lateral_direction := up_direction.cross(horizontal_direction)
	var lateral_offsets: Array[float] = [0.0]
	if lateral_direction.length_squared() > EPSILON:
		lateral_direction = lateral_direction.normalized()
		var lateral_extent: float = maxf(body_horizontal_extent * 0.6, 0.08)
		var outer_lateral_extent: float = maxf(body_horizontal_extent * 0.9, lateral_extent)
		lateral_offsets.append(lateral_extent)
		lateral_offsets.append(-lateral_extent)
		lateral_offsets.append(outer_lateral_extent)
		lateral_offsets.append(-outer_lateral_extent)
		var collision_lateral_offset: float = (motion_collision.get_position() - origin).dot(lateral_direction)
		if absf(collision_lateral_offset) > margin:
			lateral_offsets.append(clampf(collision_lateral_offset, -outer_lateral_extent, outer_lateral_extent))
	var best_step_height: float = -1.0
	var best_forward_distance: float = INF
	for forward_distance in forward_distances:
		for lateral_offset in lateral_offsets:
			var probe_origin: Vector3 = origin + (horizontal_direction * forward_distance) + (lateral_direction * lateral_offset)
			var landing_floor := _find_support_floor(
				body,
				probe_origin,
				up_direction,
				max_step_height,
				down_probe_distance,
				horizontal_direction,
				body_horizontal_extent,
				margin
			)
			if landing_floor.is_empty():
				debug_info["landing_floor_misses"] += 1
				continue
			debug_info["landing_floor_hits"] += 1
			var landing_floor_position: Vector3 = landing_floor["position"]
			var step_height: float = (landing_floor_position - current_floor_position).dot(up_direction)
			if step_height <= margin:
				debug_info["rejected_too_low"] += 1
				continue
			if step_height > max_step_height + margin:
				debug_info["rejected_too_high"] += 1
				continue
			if best_step_height < 0.0:
				best_step_height = step_height
				best_forward_distance = forward_distance
				continue
			if step_height < best_step_height - margin:
				best_step_height = step_height
				best_forward_distance = forward_distance
				continue
			if absf(step_height - best_step_height) <= margin and forward_distance < best_forward_distance:
				best_step_height = step_height
				best_forward_distance = forward_distance
	if best_step_height < 0.0:
		return _find_collision_face_step_candidate(
			body,
			origin,
			current_floor_position,
			motion_collision,
			horizontal_direction,
			up_direction,
			body_horizontal_extent,
			max_step_height,
			down_probe_distance,
			margin,
			debug_info
		)
	return {
		"height": best_step_height,
		"forward_distance": best_forward_distance
	}


func _find_step_in_distance(body: CharacterBody3D, stepped_transform: Transform3D, horizontal_direction: Vector3, body_horizontal_extent: float, motion_distance: float, desired_forward_distance: float, margin: float) -> float:
	var min_step_in_distance: float = minf(motion_distance, maxf(body_horizontal_extent * 0.2, 0.03))
	var max_step_in_distance: float = minf(motion_distance, maxf(desired_forward_distance, min_step_in_distance))
	if max_step_in_distance <= margin:
		return 0.0
	var candidate_distances: Array[float] = []
	candidate_distances.append(max_step_in_distance)
	candidate_distances.append(minf(max_step_in_distance, maxf(body_horizontal_extent * 0.9, min_step_in_distance)))
	candidate_distances.append(minf(max_step_in_distance, maxf(body_horizontal_extent * 0.6, min_step_in_distance)))
	candidate_distances.append(minf(max_step_in_distance, maxf(body_horizontal_extent * 0.35, min_step_in_distance)))
	candidate_distances.append(min_step_in_distance)
	for candidate_distance in candidate_distances:
		if candidate_distance <= margin:
			continue
		var candidate_collision := KinematicCollision3D.new()
		if not body.test_move(stepped_transform, horizontal_direction * candidate_distance, candidate_collision, margin, false):
			return candidate_distance
	return 0.0


func _find_collision_face_step_candidate(body: CharacterBody3D, origin: Vector3, current_floor_position: Vector3, motion_collision: KinematicCollision3D, horizontal_direction: Vector3, up_direction: Vector3, body_horizontal_extent: float, max_step_height: float, down_probe_distance: float, margin: float, debug_info: Dictionary) -> Dictionary:
	var collision_position: Vector3 = motion_collision.get_position()
	var collision_offset: Vector3 = collision_position - origin
	var collision_forward_distance: float = collision_offset.slide(up_direction).dot(horizontal_direction)
	if collision_forward_distance <= margin:
		return {}
	var lateral_direction := up_direction.cross(horizontal_direction)
	var lateral_offsets: Array[float] = [0.0]
	if lateral_direction.length_squared() > EPSILON:
		lateral_direction = lateral_direction.normalized()
		var collision_lateral_offset: float = collision_offset.dot(lateral_direction)
		var inner_lateral_extent: float = maxf(body_horizontal_extent * 0.25, 0.04)
		var outer_lateral_extent: float = maxf(body_horizontal_extent * 0.55, 0.08)
		lateral_offsets = [
			clampf(collision_lateral_offset, -body_horizontal_extent, body_horizontal_extent),
			clampf(collision_lateral_offset + inner_lateral_extent, -body_horizontal_extent, body_horizontal_extent),
			clampf(collision_lateral_offset - inner_lateral_extent, -body_horizontal_extent, body_horizontal_extent),
			clampf(collision_lateral_offset + outer_lateral_extent, -body_horizontal_extent, body_horizontal_extent),
			clampf(collision_lateral_offset - outer_lateral_extent, -body_horizontal_extent, body_horizontal_extent),
			0.0
		]
	var forward_offsets: Array[float] = [
		maxf(margin * 2.0, 0.02),
		maxf(body_horizontal_extent * 0.18, 0.04),
		maxf(body_horizontal_extent * 0.35, 0.08),
		maxf(body_horizontal_extent * 0.6, 0.12),
		maxf(body_horizontal_extent * 0.9, 0.18)
	]
	var best_step_height: float = -1.0
	var best_forward_distance: float = INF
	for forward_offset in forward_offsets:
		for lateral_offset in lateral_offsets:
			var probe_origin: Vector3 = collision_position + (horizontal_direction * forward_offset) + (lateral_direction * lateral_offset)
			var landing_floor := _find_floor(body, probe_origin, up_direction, max_step_height, down_probe_distance)
			if landing_floor.is_empty():
				debug_info["fallback_misses"] += 1
				continue
			debug_info["fallback_hits"] += 1
			var landing_floor_position: Vector3 = landing_floor["position"]
			var step_height: float = (landing_floor_position - current_floor_position).dot(up_direction)
			if step_height <= margin:
				continue
			if step_height > max_step_height + margin:
				continue
			var forward_distance: float = collision_forward_distance + forward_offset
			if best_step_height < 0.0:
				best_step_height = step_height
				best_forward_distance = forward_distance
				continue
			if step_height < best_step_height - margin:
				best_step_height = step_height
				best_forward_distance = forward_distance
				continue
			if absf(step_height - best_step_height) <= margin and forward_distance < best_forward_distance:
				best_step_height = step_height
				best_forward_distance = forward_distance
	if best_step_height < 0.0:
		return {}
	return {
		"height": best_step_height,
		"forward_distance": best_forward_distance
	}


func _debug_log(enabled: bool, message: String) -> void:
	if not enabled:
		return
	var now := Time.get_ticks_msec()
	if message == _last_debug_message and now - _last_debug_time_msec < 250:
		return
	_last_debug_message = message
	_last_debug_time_msec = now
	print("[StairStepHelper] %s" % message)


func _str_vec3(value: Vector3) -> String:
	return "(%.3f, %.3f, %.3f)" % [value.x, value.y, value.z]


func _find_current_support_floor(body: CharacterBody3D, origin: Vector3, up_direction: Vector3, max_step_height: float, down_probe_distance: float, horizontal_direction: Vector3, body_horizontal_extent: float, margin: float) -> Dictionary:
	var backward_distances: Array[float] = [
		maxf(body_horizontal_extent * 0.7, 0.05),
		maxf(body_horizontal_extent * 0.35, margin * 2.0),
		0.0
	]
	var lateral_direction := up_direction.cross(horizontal_direction)
	var lateral_offsets: Array[float] = [0.0]
	if lateral_direction.length_squared() > EPSILON:
		lateral_direction = lateral_direction.normalized()
		var side_offset: float = maxf(body_horizontal_extent * 0.45, 0.06)
		lateral_offsets.append(side_offset)
		lateral_offsets.append(-side_offset)
	var best_floor: Dictionary = {}
	var best_backward_distance := -1.0
	var best_floor_height := -INF
	for backward_distance in backward_distances:
		var base_origin: Vector3 = origin - (horizontal_direction * backward_distance)
		for lateral_offset in lateral_offsets:
			var sample_origin := base_origin + (lateral_direction * lateral_offset)
			var floor_result := _find_floor(body, sample_origin, up_direction, max_step_height, down_probe_distance)
			if floor_result.is_empty():
				continue
			var floor_position: Vector3 = floor_result["position"]
			var floor_height: float = floor_position.dot(up_direction)
			if backward_distance > best_backward_distance + margin:
				best_backward_distance = backward_distance
				best_floor_height = floor_height
				best_floor = floor_result
				continue
			if absf(backward_distance - best_backward_distance) <= margin and floor_height > best_floor_height:
				best_floor_height = floor_height
				best_floor = floor_result
	return best_floor


func _find_support_floor(body: CharacterBody3D, origin: Vector3, up_direction: Vector3, max_step_height: float, down_probe_distance: float, horizontal_direction: Vector3, body_horizontal_extent: float, margin: float) -> Dictionary:
	var sample_origins: Array[Vector3] = [origin]
	var backward_distances: Array[float] = [
		maxf(body_horizontal_extent * 0.35, margin * 2.0),
		maxf(body_horizontal_extent * 0.7, 0.05)
	]
	var lateral_direction := up_direction.cross(horizontal_direction)
	var lateral_offsets: Array[float] = [0.0]
	if lateral_direction.length_squared() > EPSILON:
		lateral_direction = lateral_direction.normalized()
		lateral_offsets.append(maxf(body_horizontal_extent * 0.45, 0.06))
		lateral_offsets.append(-maxf(body_horizontal_extent * 0.45, 0.06))
	for backward_distance in backward_distances:
		var base_origin: Vector3 = origin - (horizontal_direction * backward_distance)
		sample_origins.append(base_origin)
		for lateral_offset in lateral_offsets:
			if absf(lateral_offset) <= margin:
				continue
			sample_origins.append(base_origin + (lateral_direction * lateral_offset))
	var best_floor: Dictionary = {}
	var best_floor_height := -INF
	for sample_origin in sample_origins:
		var floor_result := _find_floor(body, sample_origin, up_direction, max_step_height, down_probe_distance)
		if floor_result.is_empty():
			continue
		var floor_position: Vector3 = floor_result["position"]
		var floor_height: float = floor_position.dot(up_direction)
		if floor_height > best_floor_height:
			best_floor_height = floor_height
			best_floor = floor_result
	return best_floor


func _get_forward_probe_distances(origin: Vector3, motion_collision: KinematicCollision3D, horizontal_direction: Vector3, up_direction: Vector3, body_horizontal_extent: float, motion_distance: float, margin: float) -> Array[float]:
	var front_edge_distance: float = body_horizontal_extent + margin
	var distances: Array[float] = [
		front_edge_distance + 0.02,
		front_edge_distance + (maxf(motion_distance, 0.05) * 0.5),
		front_edge_distance + maxf(motion_distance, 0.05)
	]
	var collision_offset: Vector3 = motion_collision.get_position() - origin
	var collision_forward_distance: float = collision_offset.slide(up_direction).dot(horizontal_direction)
	if collision_forward_distance > margin:
		distances.append(clampf(collision_forward_distance + margin, distances[0], distances[distances.size() - 1]))
	distances.sort()
	var unique_distances: Array[float] = []
	for distance in distances:
		if unique_distances.is_empty() or absf(distance - unique_distances[unique_distances.size() - 1]) > margin:
			unique_distances.append(distance)
	return unique_distances


func _get_body_horizontal_extent(body: CharacterBody3D) -> float:
	var max_extent := 0.25
	for child in body.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null:
			max_extent = max(max_extent, _get_shape_horizontal_extent(child.shape))
	return max_extent


func _get_shape_horizontal_extent(shape: Shape3D) -> float:
	if shape is CapsuleShape3D:
		return shape.radius
	if shape is SphereShape3D:
		return shape.radius
	if shape is CylinderShape3D:
		return shape.radius
	if shape is BoxShape3D:
		return max(shape.size.x, shape.size.z) * 0.5
	return 0.25


func _find_floor(body: CharacterBody3D, origin: Vector3, up_direction: Vector3, max_step_height: float, down_probe_distance: float) -> Dictionary:
	if body == null:
		return {}
	var world := body.get_world_3d()
	if world == null:
		return {}
	var space_state := world.direct_space_state
	if space_state == null:
		return {}
	var params := PhysicsRayQueryParameters3D.new()
	params.from = origin + (up_direction * max_step_height)
	params.to = origin - (up_direction * maxf(0.05, down_probe_distance))
	params.exclude = [body]
	params.collision_mask = body.collision_mask
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var result := space_state.intersect_ray(params)
	if result.is_empty():
		return {}
	var normal: Vector3 = result.normal
	if up_direction.angle_to(normal) > body.floor_max_angle + FLOOR_ANGLE_EPSILON:
		return {}
	return result
