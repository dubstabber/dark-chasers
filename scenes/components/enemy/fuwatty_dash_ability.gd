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

const DASH_PATH_CLEARANCE_HEIGHT_OFFSETS := [0.45]
const DASH_MAX_DURATION_MULTIPLIER := 2.75
const FAILED_COMMIT_RETRY_DISTANCE_TILES := 0.5

var _dash_policy: FuwattyDashPolicy = FuwattyDashPolicy.new()
var _state: DashState = DashState.IDLE_COUNTING
var _accumulated_distance_m: float = 0.0
var _has_last_position := false
var _last_position := Vector3.ZERO
var _halt_remaining: float = 0.0
var _dash_distance_remaining: float = 0.0
var _dash_time_remaining: float = 0.0
var _dash_direction := Vector3.ZERO
var _dash_stuck_time: float = 0.0
var _has_failed_commit_retry := false
var _failed_commit_retry_position := Vector3.ZERO


func _init() -> void:
	ability_name = "fuwatty_dash"
	cooldown = 0.0


func can_activate(context: EnemyAbilityContext) -> bool:
	if not _is_chasing_target(context):
		_reset_step_tracking()
		return false

	if not _is_target_in_context_dash_range(context):
		_clear_failed_commit_retry()
		_sync_last_position(context.enemy_position)
		return false

	_accumulate_distance(context.enemy_position)
	if _is_waiting_to_retry_failed_commit(context.enemy_position):
		return false

	if not super.can_activate(context):
		return false

	if _accumulated_distance_m < _step_interval_distance_m():
		return false

	var enemy := _get_context_enemy(context)
	if enemy != null and not _can_commit_to_dash(enemy):
		_arm_failed_commit_retry(enemy)
		return false

	_clear_failed_commit_retry()
	return true


func activate(enemy: CharacterBody3D) -> void:
	_state = DashState.IDLE_COUNTING
	_halt_remaining = 0.0
	_dash_distance_remaining = _dash_distance_m()
	_dash_time_remaining = 0.0
	_dash_direction = Vector3.ZERO
	_dash_stuck_time = 0.0

	if not _can_commit_to_dash(enemy):
		_arm_failed_commit_retry(enemy)
		return

	_clear_failed_commit_retry()
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
			_request_chase_path_refresh(enemy)
			_state = DashState.IDLE_COUNTING
			_dash_direction = Vector3.ZERO
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
	_dash_time_remaining = 0.0
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
	_clear_failed_commit_retry()


func _arm_failed_commit_retry(enemy: CharacterBody3D) -> void:
	if enemy == null:
		return

	_failed_commit_retry_position = enemy.global_position
	_has_failed_commit_retry = true


func _clear_failed_commit_retry() -> void:
	_has_failed_commit_retry = false
	_failed_commit_retry_position = Vector3.ZERO


func _is_waiting_to_retry_failed_commit(current_position: Vector3) -> bool:
	if not _has_failed_commit_retry:
		return false

	var retry_delta := current_position - _failed_commit_retry_position
	retry_delta.y = 0.0
	if retry_delta.length() < _failed_commit_retry_distance_m():
		return true

	_clear_failed_commit_retry()
	return false


func _failed_commit_retry_distance_m() -> float:
	return maxf(0.25, _tile_size_meters() * FAILED_COMMIT_RETRY_DISTANCE_TILES)


func _enemy_has_target(enemy: CharacterBody3D) -> bool:
	return _dash_policy.enemy_has_target(enemy)


func _get_context_enemy(context: EnemyAbilityContext) -> CharacterBody3D:
	if context == null:
		return null

	return context.enemy_body


func _is_target_in_context_dash_range(context: EnemyAbilityContext) -> bool:
	if context == null:
		return false

	return _is_distance_in_dash_range(context.distance_to_target)


func _resolve_target_direction(enemy: CharacterBody3D) -> Vector3:
	return _dash_policy.resolve_target_direction(enemy)


func _is_target_in_enemy_room(enemy: CharacterBody3D) -> bool:
	return _dash_policy.is_target_in_enemy_room(enemy)


func _can_commit_to_dash(enemy: CharacterBody3D, require_path_clearance: bool = true) -> bool:
	return _dash_policy.can_commit_to_dash(
		enemy,
		min_dash_target_distance_m,
		max_dash_target_distance_m,
		require_clear_dash_path,
		obstacle_clearance_margin,
		_dash_distance_m(),
		DASH_PATH_CLEARANCE_HEIGHT_OFFSETS,
		require_path_clearance
	)


func _begin_dash(enemy: CharacterBody3D) -> bool:
	if not _enemy_has_target(enemy):
		return false

	if not _is_target_in_enemy_room(enemy):
		return false

	_dash_direction = _resolve_target_direction(enemy)
	if _dash_direction == Vector3.ZERO:
		return false

	_dash_time_remaining = _resolve_dash_phase_timeout(enemy)
	return true


func _request_chase_path_refresh(enemy: CharacterBody3D) -> void:
	if enemy == null:
		return

	enemy.call("makepath")


func _get_room_name(node: Object) -> String:
	return _dash_policy.get_room_name(node)


func _is_target_in_enemy_dash_range(enemy: CharacterBody3D) -> bool:
	return _dash_policy.is_target_in_enemy_dash_range(enemy, min_dash_target_distance_m, max_dash_target_distance_m)


func _is_distance_in_dash_range(distance: float) -> bool:
	return _dash_policy.is_distance_in_dash_range(distance, min_dash_target_distance_m, max_dash_target_distance_m)


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
		return _complete_dash(enemy)

	var start_position := enemy.global_position
	_apply_gravity(enemy, delta)

	var dash_speed := _resolve_dash_speed(enemy)
	var expected_forward := maxf(0.0, dash_speed * delta)
	var probe_distance := maxf(expected_forward, maxf(0.05, obstacle_clearance_margin))
	if _is_dash_motion_blocked(enemy, _dash_direction * probe_distance):
		return _complete_dash(enemy)

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

	_dash_time_remaining = maxf(0.0, _dash_time_remaining - delta)

	if _is_hitting_front_wall(enemy):
		return _complete_dash(enemy)

	if enemy.is_on_wall():
		return _complete_dash(enemy)

	if enemy.get_slide_collision_count() > 0 and expected_forward > 0.0 and moved_forward < expected_forward * 0.35:
		return _complete_dash(enemy)

	if _dash_stuck_time >= maxf(0.01, stuck_timeout_seconds):
		return _complete_dash(enemy)

	if _dash_time_remaining <= 0.0:
		return _complete_dash(enemy)

	if _dash_distance_remaining <= 0.0:
		return _complete_dash(enemy)

	return AbilityStatus.RUNNING


func _complete_dash(enemy: CharacterBody3D) -> AbilityStatus:
	if enemy:
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0
	return AbilityStatus.COMPLETED


func _is_dash_motion_blocked(enemy: CharacterBody3D, motion: Vector3) -> bool:
	return _dash_policy.is_dash_motion_blocked(enemy, motion, obstacle_clearance_margin, DASH_PATH_CLEARANCE_HEIGHT_OFFSETS)


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
	return _dash_policy.is_dash_path_clear_to_target(enemy, obstacle_clearance_margin, _dash_distance_m(), DASH_PATH_CLEARANCE_HEIGHT_OFFSETS)


func _has_elevated_dash_path_clearance(enemy: CharacterBody3D, target: Node3D, motion: Vector3) -> bool:
	return _dash_policy.has_elevated_dash_path_clearance(enemy, target, motion, obstacle_clearance_margin, DASH_PATH_CLEARANCE_HEIGHT_OFFSETS)


func _raycast_path_hits_only_target(enemy: CharacterBody3D, target: Node3D, motion: Vector3) -> bool:
	return _dash_policy.raycast_path_hits_only_target(enemy, target, motion, DASH_PATH_CLEARANCE_HEIGHT_OFFSETS)


func _raycast_path_hits_only_target_at_height(space_state: PhysicsDirectSpaceState3D, enemy: CharacterBody3D, target: Node3D, motion: Vector3, height_offset: float) -> bool:
	return _dash_policy.raycast_path_hits_only_target_at_height(space_state, enemy, target, motion, height_offset)


func _is_allowed_target_hit(collider_node: Node, target: Node3D) -> bool:
	return _dash_policy.is_allowed_target_hit(collider_node, target)


func _resolve_dash_speed(enemy: CharacterBody3D) -> float:
	var base_speed := 7.0
	var speed_value: Variant = enemy.get("speed")
	if speed_value is float or speed_value is int:
		base_speed = float(speed_value)

	return maxf(0.0, base_speed * maxf(0.0, dash_speed_multiplier))


func _resolve_dash_phase_timeout(enemy: CharacterBody3D) -> float:
	var dash_speed := _resolve_dash_speed(enemy)
	if dash_speed <= 0.0:
		return 0.0

	var expected_duration := _dash_distance_remaining / dash_speed
	return (expected_duration * DASH_MAX_DURATION_MULTIPLIER) + maxf(0.01, stuck_timeout_seconds)


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
	return _dash_policy._horizontal_distance(from_pos, to_pos)
