class_name FuwattyDashAbility
extends EnemyAbility

## Phase 1/2: dash cadence, pre-dash halt, and dash execution.

enum DashState {
	IDLE_COUNTING,
	PRE_DASH_HALT,
	DASHING,
}

@export var step_interval: float = 8.0
@export var pre_dash_halt_seconds: float = 1.0
@export var dash_tiles: float = 6.0
@export var tile_size_meters: float = 1.0
@export var dash_speed_multiplier: float = 2.5
@export var min_dash_target_distance_m: float = 0.0
@export var max_dash_target_distance_m: float = 12.0
@export var dash_hop_vertical_speed: float = 2.2
@export var require_clear_dash_path: bool = true
@export var obstacle_clearance_margin: float = 0.05
@export var enable_dash_indicator: bool = false
@export var debug_logs: bool = false
@export var stuck_timeout_seconds: float = 0.08

var _state: DashState = DashState.IDLE_COUNTING
var _accumulated_distance_m: float = 0.0
var _has_last_position := false
var _last_position := Vector3.ZERO
var _halt_remaining: float = 0.0
var _dash_distance_remaining: float = 0.0
var _dash_direction := Vector3.ZERO
var _dash_stuck_time: float = 0.0


func _init() -> void:
	ability_name = "fuwatty_dash"
	cooldown = 0.0


func can_activate(context: EnemyAbilityContext) -> bool:
	if not _is_chasing_target(context):
		_reset_step_tracking()
		return false

	if not _is_target_in_context_dash_range(context):
		_sync_last_position(context.enemy_position)
		return false

	_accumulate_distance(context.enemy_position)

	if not super.can_activate(context):
		return false

	return _accumulated_distance_m >= _step_interval_distance_m()


func activate(enemy: CharacterBody3D) -> void:
	_state = DashState.IDLE_COUNTING
	_halt_remaining = 0.0
	_dash_distance_remaining = _dash_distance_m()
	_dash_direction = Vector3.ZERO
	_dash_stuck_time = 0.0

	if not _can_commit_to_dash(enemy):
		return

	_consume_step_interval()
	_state = DashState.PRE_DASH_HALT
	_halt_remaining = maxf(0.0, pre_dash_halt_seconds)


func process(enemy: CharacterBody3D, delta: float) -> AbilityStatus:
	if _state == DashState.PRE_DASH_HALT:
		if not _enemy_has_target(enemy):
			return AbilityStatus.CANCELLED

		_process_pre_dash_halt(enemy, delta)
		_halt_remaining -= delta
		if _halt_remaining > 0.0:
			return AbilityStatus.RUNNING

		if not _begin_dash(enemy):
			_state = DashState.IDLE_COUNTING
			return AbilityStatus.COMPLETED

		_apply_dash_hop(enemy)
		_state = DashState.DASHING
		_dash_stuck_time = 0.0
		return AbilityStatus.RUNNING

	if _state == DashState.DASHING:
		if not _enemy_has_target(enemy):
			return AbilityStatus.CANCELLED
		return _process_dash(enemy, delta)

	return AbilityStatus.COMPLETED


func deactivate(enemy: CharacterBody3D) -> void:
	_state = DashState.IDLE_COUNTING
	_halt_remaining = 0.0
	_dash_distance_remaining = 0.0
	_dash_direction = Vector3.ZERO
	_dash_stuck_time = 0.0
	if enemy:
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0
		_last_position = enemy.global_position
		_has_last_position = true


func get_state_name() -> StringName:
	match _state:
		DashState.IDLE_COUNTING:
			return &"idle_counting"
		DashState.PRE_DASH_HALT:
			return &"pre_dash_halt"
		DashState.DASHING:
			return &"dashing"
		_:
			return &"unknown"


func get_accumulated_distance_m() -> float:
	return _accumulated_distance_m


func get_dash_direction() -> Vector3:
	return _dash_direction


func _is_chasing_target(context: EnemyAbilityContext) -> bool:
	return context != null and context.has_target


func _accumulate_distance(current_position: Vector3) -> void:
	if _has_last_position:
		var delta := current_position - _last_position
		delta.y = 0.0
		_accumulated_distance_m += delta.length()
		var max_accumulated := _step_interval_distance_m()
		if max_accumulated > 0.0:
			_accumulated_distance_m = minf(_accumulated_distance_m, max_accumulated)
	_last_position = current_position
	_has_last_position = true


func _sync_last_position(current_position: Vector3) -> void:
	_last_position = current_position
	_has_last_position = true


func _step_interval_distance_m() -> float:
	return maxf(0.0, step_interval) * _tile_size_meters()


func _dash_distance_m() -> float:
	return maxf(0.0, dash_tiles) * _tile_size_meters()


func _tile_size_meters() -> float:
	return maxf(0.01, tile_size_meters)


func _consume_step_interval() -> void:
	var consumed := _step_interval_distance_m()
	if consumed <= 0.0:
		return
	_accumulated_distance_m = maxf(0.0, _accumulated_distance_m - consumed)


func _reset_step_tracking() -> void:
	_accumulated_distance_m = 0.0
	_has_last_position = false
	_last_position = Vector3.ZERO


func _enemy_has_target(enemy: CharacterBody3D) -> bool:
	if enemy == null:
		return false
	return enemy.get("current_target") is Node3D


func _is_target_in_context_dash_range(context: EnemyAbilityContext) -> bool:
	if context == null:
		return false

	return _is_distance_in_dash_range(context.distance_to_target)


func _resolve_target_direction(enemy: CharacterBody3D) -> Vector3:
	if enemy == null:
		return Vector3.ZERO

	var target: Node3D = enemy.get("current_target") as Node3D
	if target == null:
		return Vector3.ZERO

	var target_position := target.global_position
	var dash_direction := target_position - enemy.global_position
	dash_direction.y = 0.0
	if dash_direction.length_squared() <= 0.000001:
		return Vector3.ZERO

	return dash_direction.normalized()


func _can_commit_to_dash(enemy: CharacterBody3D) -> bool:
	if not _enemy_has_target(enemy):
		return false

	if not _is_target_in_enemy_dash_range(enemy):
		return false

	if require_clear_dash_path and not _is_dash_path_clear_to_target(enemy):
		return false

	return true


func _begin_dash(enemy: CharacterBody3D) -> bool:
	_dash_direction = _resolve_target_direction(enemy)
	if _dash_direction == Vector3.ZERO:
		return false

	return true


func _is_target_in_enemy_dash_range(enemy: CharacterBody3D) -> bool:
	if enemy == null:
		return false

	var target: Node3D = enemy.get("current_target") as Node3D
	if target == null:
		return false

	return _is_distance_in_dash_range(_horizontal_distance(enemy.global_position, target.global_position))


func _is_distance_in_dash_range(distance: float) -> bool:
	if distance < maxf(0.0, min_dash_target_distance_m):
		return false

	if max_dash_target_distance_m > 0.0 and distance > max_dash_target_distance_m:
		return false

	return true


func _process_pre_dash_halt(enemy: CharacterBody3D, delta: float) -> void:
	if enemy == null:
		return

	var look_direction := _resolve_target_direction(enemy)
	if look_direction != Vector3.ZERO:
		enemy.rotation.y = atan2(look_direction.x, look_direction.z) + PI

	_apply_gravity(enemy, delta)
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.move_and_slide()


func _apply_dash_hop(enemy: CharacterBody3D) -> void:
	if enemy == null:
		return

	var hop_speed := maxf(0.0, dash_hop_vertical_speed)
	if hop_speed <= 0.0:
		return

	var is_flying_value: Variant = enemy.get("is_flying")
	if is_flying_value is bool and is_flying_value:
		return

	enemy.velocity.y = maxf(enemy.velocity.y, hop_speed)


func _process_dash(enemy: CharacterBody3D, delta: float) -> AbilityStatus:
	if enemy == null:
		return AbilityStatus.CANCELLED

	if _dash_distance_remaining <= 0.0:
		return AbilityStatus.COMPLETED

	var start_position := enemy.global_position
	_apply_gravity(enemy, delta)

	var dash_speed := _resolve_dash_speed(enemy)
	var expected_forward := maxf(0.0, dash_speed * delta)
	var probe_distance := maxf(expected_forward, maxf(0.05, obstacle_clearance_margin))
	if _is_dash_motion_blocked(enemy, _dash_direction * probe_distance):
		return AbilityStatus.COMPLETED

	enemy.velocity.x = _dash_direction.x * dash_speed
	enemy.velocity.z = _dash_direction.z * dash_speed
	if _dash_direction != Vector3.ZERO:
		enemy.rotation.y = atan2(_dash_direction.x, _dash_direction.z) + PI
	enemy.move_and_slide()

	var displacement := enemy.global_position - start_position
	displacement.y = 0.0
	var moved_forward := maxf(0.0, displacement.dot(_dash_direction))
	_dash_distance_remaining = maxf(0.0, _dash_distance_remaining - moved_forward)

	if moved_forward <= 0.001:
		_dash_stuck_time += delta
	else:
		_dash_stuck_time = 0.0

	if _is_hitting_front_wall(enemy):
		return AbilityStatus.COMPLETED

	if enemy.is_on_wall():
		return AbilityStatus.COMPLETED

	if enemy.get_slide_collision_count() > 0 and expected_forward > 0.0 and moved_forward < expected_forward * 0.35:
		return AbilityStatus.COMPLETED

	if _dash_stuck_time >= maxf(0.01, stuck_timeout_seconds):
		return AbilityStatus.COMPLETED

	if _dash_distance_remaining <= 0.0:
		return AbilityStatus.COMPLETED

	return AbilityStatus.RUNNING


func _is_dash_motion_blocked(enemy: CharacterBody3D, motion: Vector3) -> bool:
	if enemy == null:
		return true

	if motion.length_squared() <= 0.000001:
		return false

	var target: Node3D = enemy.get("current_target") as Node3D
	var collision := KinematicCollision3D.new()
	var collides := enemy.test_move(
		enemy.global_transform,
		motion,
		collision,
		maxf(0.001, obstacle_clearance_margin),
		false
	)
	if not collides:
		return false

	var collider_node: Node = collision.get_collider() as Node
	if collider_node == null:
		if target == null:
			return true
		return not _raycast_path_hits_only_target(enemy, target)

	if target == null:
		return true

	return not _is_allowed_target_hit(collider_node, target)


func _is_hitting_front_wall(enemy: CharacterBody3D) -> bool:
	if enemy == null:
		return false

	for i in range(enemy.get_slide_collision_count()):
		var collision := enemy.get_slide_collision(i)
		if collision == null:
			continue
		var normal := collision.get_normal()
		normal.y = 0.0
		if normal.length_squared() <= 0.000001:
			continue
		normal = normal.normalized()
		if normal.dot(_dash_direction) < -0.5:
			return true

	return false


func _is_dash_path_clear_to_target(enemy: CharacterBody3D) -> bool:
	if enemy == null:
		return false

	var target: Node3D = enemy.get("current_target") as Node3D
	if target == null:
		return false

	var motion := target.global_position - enemy.global_position
	motion.y = 0.0
	if motion.length_squared() <= 0.000001:
		return true

	var collision := KinematicCollision3D.new()
	var collides := enemy.test_move(
		enemy.global_transform,
		motion,
		collision,
		maxf(0.001, obstacle_clearance_margin),
		false
	)
	if not collides:
		return true

	var collider_node: Node = collision.get_collider() as Node
	if collider_node == null:
		return _raycast_path_hits_only_target(enemy, target)

	return _is_allowed_target_hit(collider_node, target)


func _raycast_path_hits_only_target(enemy: CharacterBody3D, target: Node3D) -> bool:
	if enemy == null or target == null:
		return false

	var space_state := enemy.get_world_3d().direct_space_state
	if space_state == null:
		return false

	var params := PhysicsRayQueryParameters3D.new()
	params.from = enemy.global_position
	params.to = target.global_position
	params.exclude = [enemy]
	params.collision_mask = enemy.collision_mask

	var result := space_state.intersect_ray(params)
	if result.is_empty():
		return true

	var hit_node: Node = result.get("collider") as Node
	if hit_node == null:
		return false

	return _is_allowed_target_hit(hit_node, target)


func _is_allowed_target_hit(collider_node: Node, target: Node3D) -> bool:
	if collider_node == null or target == null:
		return false

	if collider_node == target:
		return true

	if collider_node.is_in_group("player"):
		return true

	if target.is_ancestor_of(collider_node):
		return true

	return collider_node.is_ancestor_of(target)


func _resolve_dash_speed(enemy: CharacterBody3D) -> float:
	var base_speed := 7.0
	var speed_value: Variant = enemy.get("speed")
	if speed_value is float or speed_value is int:
		base_speed = float(speed_value)

	return maxf(0.0, base_speed * maxf(0.0, dash_speed_multiplier))


func _apply_gravity(enemy: CharacterBody3D, delta: float) -> void:
	if enemy == null:
		return

	var is_flying_value: Variant = enemy.get("is_flying")
	var is_flying := false
	if is_flying_value is bool:
		is_flying = is_flying_value

	if enemy.is_on_floor() or is_flying:
		return

	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	enemy.velocity.y -= gravity * delta


func _horizontal_distance(from_pos: Vector3, to_pos: Vector3) -> float:
	var delta := to_pos - from_pos
	delta.y = 0.0
	return delta.length()
