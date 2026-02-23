class_name EnemyRuntimeCoordinator
extends Node

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

	_motor_component.move_and_slide()

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

	_find_path_timer.wait_time = _path_timing_controller.compute_wait_time(
		distance_to_target,
		not _enemy.waypoints.is_empty()
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

	var next_pos := _get_next_path_position()
	if _enemy.current_target and _nav_component and _nav_component.is_navigation_finished():
		next_pos = _enemy.current_target.global_position

	_motor_component.move_toward_position(next_pos, delta)
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
