class_name EnemyRuntimeCoordinator
extends Node

const DIRECT_TARGET_FALLBACK_MAX_VERTICAL_DELTA := 0.35

var _enemy
var _ai_component: EnemyAIComponent
var _motor_component: EnemyMotorComponent
var _nav_component: EnemyNavigationComponent
var _wandering_component: EnemyWanderingComponent
var _disappear_zone_component: EnemyDisappearZoneComponent
var _transition_component
var _path_timing_controller: EnemyPathTimingController
var _find_path_timer: Timer
var _is_flying := false
var _debug_prints := false
var _timing_stagger_factor := 0.5


func setup(
	enemy,
	ai_component: EnemyAIComponent,
	motor_component: EnemyMotorComponent,
	nav_component: EnemyNavigationComponent,
	wandering_component: EnemyWanderingComponent,
	disappear_zone_component: EnemyDisappearZoneComponent,
	transition_component,
	path_timing_controller: EnemyPathTimingController,
	find_path_timer: Timer,
	is_flying: bool,
	debug_prints: bool
) -> void:
	_enemy = enemy
	_ai_component = ai_component
	_motor_component = motor_component
	_nav_component = nav_component
	_wandering_component = wandering_component
	_disappear_zone_component = disappear_zone_component
	_transition_component = transition_component
	_path_timing_controller = path_timing_controller
	_find_path_timer = find_path_timer
	_is_flying = is_flying
	_debug_prints = debug_prints
	if _enemy and _path_timing_controller:
		_timing_stagger_factor = _path_timing_controller.compute_stagger_factor(_enemy.get_instance_id())


func process_physics(delta: float) -> void:
	if not _enemy or not _motor_component:
		return

	_motor_component.apply_gravity(delta)

	if not _enemy.is_killed:
		if _ai_component:
			_ai_component.update_scanning(delta)
		if _enemy.current_target or not _enemy.waypoints.is_empty():
			_process_chase_movement(delta)
		elif _enemy.is_wandering:
			_process_wandering_movement(delta)
		else:
			_stop_movement()

	_motor_component.move_and_slide(delta)

	if _disappear_zone_component:
		_disappear_zone_component.update(delta)


func on_target_acquired(target: Node3D) -> void:
	if not _enemy:
		return
	_enemy.current_target = target
	_enemy.makepath()
	if _debug_prints:
		Services.utils.debug_log("Enemy: detected new target, immediately calculating path")


func on_target_died() -> void:
	if not _enemy:
		return
	_enemy.current_target = null
	_enemy.velocity = Vector3.ZERO
	if _find_path_timer:
		_find_path_timer.wait_time = 0.1


func on_navigation_target_reached() -> void:
	if not _enemy:
		return

	if _transition_component and _transition_component.handle_target_reached():
		return

	if not _enemy.waypoints.is_empty():
		_enemy.waypoints.pop_front()
		if _enemy.waypoints.is_empty():
			_stop_movement()


func on_find_path_timer_timeout() -> void:
	if not _enemy or not _find_path_timer or not _path_timing_controller:
		return

	var distance_to_target := 0.0
	if _nav_component:
		distance_to_target = _nav_component.distance_to_target()

	_find_path_timer.wait_time = _path_timing_controller.compute_staggered_wait_time(
		distance_to_target,
		not _enemy.waypoints.is_empty(),
		_timing_stagger_factor
	)
	_enemy.makepath()


func _process_chase_movement(delta: float) -> void:
	if not _enemy or not _motor_component:
		return

	if _enemy.current_target and Mortal.is_dead(_enemy.current_target):
		_enemy.current_target = null
		if _ai_component:
			_ai_component.clear_target()
		_stop_movement()
		if _find_path_timer:
			_find_path_timer.wait_time = 0.1
		return

	var move_direction := _get_navigation_direction()
	if _is_recovering_vertical_navigation_stall():
		_schedule_finished_navigation_repath()
	elif _should_fallback_to_direct_target():
		move_direction = _get_horizontal_direction_to(_enemy.current_target.global_position)
	elif move_direction == Vector3.ZERO and _should_request_finished_navigation_repath():
		_schedule_finished_navigation_repath()

	_motor_component.move_in_direction(move_direction, delta)
	_enemy.direction = _motor_component.direction

	if _enemy.is_on_floor() or _is_flying:
		_motor_component.look_forward()


func _process_wandering_movement(delta: float) -> void:
	if not _enemy or not _motor_component:
		return

	if _wandering_component:
		_wandering_component.update(delta)
		_enemy.direction = _wandering_component.direction

	_motor_component.move_in_direction(_enemy.direction, delta)

	if _enemy.is_on_floor() or _is_flying:
		_motor_component.look_forward()


func _stop_movement() -> void:
	if _motor_component:
		_motor_component.stop()


func _get_next_path_position() -> Vector3:
	if _nav_component:
		return _nav_component.get_next_path_position()
	push_warning("EnemyRuntimeCoordinator: No navigation component found")
	return _enemy.global_position if _enemy else Vector3.ZERO


func _get_navigation_direction() -> Vector3:
	if _nav_component:
		return _nav_component.get_horizontal_direction()
	push_warning("EnemyRuntimeCoordinator: No navigation component found")
	return Vector3.ZERO


func _is_recovering_vertical_navigation_stall() -> bool:
	if _nav_component == null:
		return false
	return _nav_component.is_vertical_horizontal_direction_fallback_active()


func _should_fallback_to_direct_target() -> bool:
	if not _enemy or _enemy.current_target == null or _nav_component == null:
		return false

	if not _nav_component.is_navigation_finished():
		return false

	if _transition_component:
		if _transition_component.has_pending_transition():
			return false
		if not _transition_component.is_target_in_same_room():
			return false

	if _has_significant_vertical_gap_to_target():
		return false

	return true


func _should_request_finished_navigation_repath() -> bool:
	if not _has_same_room_finished_navigation_target():
		return false
	return _has_significant_vertical_gap_to_target()


func _has_same_room_finished_navigation_target() -> bool:
	if not _enemy or _enemy.current_target == null or _nav_component == null:
		return false

	if not _nav_component.is_navigation_finished():
		return false

	if _transition_component:
		if _transition_component.has_pending_transition():
			return false
		if not _transition_component.is_target_in_same_room():
			return false

	return true


func _has_significant_vertical_gap_to_target() -> bool:
	if not _enemy or _enemy.current_target == null:
		return false
	return absf(_enemy.current_target.global_position.y - _enemy.global_position.y) > DIRECT_TARGET_FALLBACK_MAX_VERTICAL_DELTA


func _has_significant_vertical_gap_to_position(position: Vector3) -> bool:
	if not _enemy:
		return false
	return absf(position.y - _enemy.global_position.y) > DIRECT_TARGET_FALLBACK_MAX_VERTICAL_DELTA


func _schedule_finished_navigation_repath() -> void:
	if not _find_path_timer:
		return
	var finished_navigation_repath_delay := 0.1
	if _path_timing_controller:
		finished_navigation_repath_delay = _path_timing_controller.compute_finished_navigation_repath_delay(_timing_stagger_factor)
	if not _find_path_timer.is_stopped() and _find_path_timer.time_left <= finished_navigation_repath_delay:
		return
	_find_path_timer.stop()
	_find_path_timer.wait_time = finished_navigation_repath_delay
	_find_path_timer.start()


func _get_horizontal_direction_to(target_pos: Vector3) -> Vector3:
	if not _enemy:
		return Vector3.ZERO
	var delta: Vector3 = target_pos - _enemy.global_position
	delta.y = 0.0
	return delta.normalized()
