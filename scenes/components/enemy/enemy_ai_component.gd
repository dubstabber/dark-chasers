class_name EnemyAIComponent
extends Node

signal target_acquired(target: Node3D)
signal target_lost()
signal target_died()

@export var detection_enabled: bool = true
@export var chase_player: bool = true
@export var check_line_of_sight: bool = true
@export var line_of_sight_origin: Node3D
@export var scan_interval: float = 0.2
@export var scan_jitter: float = 0.05
@export var visibility_check_interval: float = 0.15
@export var visibility_check_jitter: float = 0.05

var current_target: CharacterBody3D = null
var players_node: Node3D = null

var _owner_enemy: CharacterBody3D = null
var _enemy_context: Node = null
var _scan_timer: float = 0.0
var _cached_target_visible := false
var _next_visibility_refresh_time_msec := 0


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D
	_find_players_node()
	_scan_timer = randf_range(0.0, scan_interval)
	_schedule_next_visibility_refresh(true)


func _find_players_node() -> void:
	if not _enemy_context:
		_enemy_context = Services.enemy_context
	
	if _enemy_context:
		players_node = _enemy_context.get_players_node()
	# Note: EnemyContext handles group fallback internally; no need to duplicate here


func update_scanning(delta: float) -> void:
	if current_target:
		# Already have a target — just check if it's still alive
		if Mortal.is_dead(current_target):
			current_target = null
			_reset_visibility_cache()
			target_died.emit()
		else:
			_refresh_target_visibility_if_needed()
		return

	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = scan_interval + randf_range(-scan_jitter, scan_jitter)
		_scan_for_targets()


func _scan_for_targets() -> void:
	if current_target and Mortal.is_dead(current_target):
		current_target = null
		_reset_visibility_cache()
		target_died.emit()
	
	if not detection_enabled or not chase_player:
		return
	
	if not _owner_enemy:
		return
	
	# Retry finding players_node if null or invalid (handles timing with Level._ready())
	if not is_instance_valid(players_node):
		_find_players_node()
		if not players_node:
			return
	
	var space_state = _owner_enemy.get_world_3d().direct_space_state
	
	for target in players_node.get_children():
		if not Mortal.is_alive(target):
			continue
		
		if not Aimable.check(target):
			continue
		
		if check_line_of_sight:
			if _compute_target_visibility(target, space_state):
				_set_target(target as CharacterBody3D)
				return
		else:
			_set_target(target as CharacterBody3D)
			return


func _has_aim_point(target: Node3D) -> bool:
	# Use typed interfaces: Aimable for get_aim_point(), CameraOwner for camera_3d
	return Aimable.check(target) or CameraOwner.check(target)


func _get_line_of_sight_origin() -> Vector3:
	if line_of_sight_origin:
		return line_of_sight_origin.global_position
	return _owner_enemy.global_position


func _get_aim_point(target: Node3D) -> Vector3:
	return Aimable.get_aim_point(target)


func _set_target(new_target: CharacterBody3D) -> void:
	var should_signal = current_target == null or current_target != new_target
	current_target = new_target
	_cached_target_visible = true
	_schedule_next_visibility_refresh()
	if should_signal:
		target_acquired.emit(current_target)


func clear_target() -> void:
	if current_target != null:
		current_target = null
		_reset_visibility_cache()
		target_lost.emit()


func check_target_alive() -> bool:
	if current_target and Mortal.is_dead(current_target):
		current_target = null
		_reset_visibility_cache()
		target_died.emit()
		return false
	return current_target != null


func get_target() -> CharacterBody3D:
	return current_target


func get_target_position() -> Vector3:
	if current_target:
		return current_target.global_position
	return Vector3.ZERO


func has_target() -> bool:
	return current_target != null


func is_target_visible() -> bool:
	if not current_target or not is_instance_valid(current_target):
		return false

	if not check_line_of_sight:
		return true

	if not _owner_enemy:
		return false

	return _refresh_target_visibility_if_needed(true)


func _refresh_target_visibility_if_needed(force: bool = false) -> bool:
	if not current_target or not is_instance_valid(current_target):
		_cached_target_visible = false
		return false
	if not check_line_of_sight:
		_cached_target_visible = true
		return true
	if not _owner_enemy:
		_cached_target_visible = false
		return false

	var now_msec := Time.get_ticks_msec()
	if force or now_msec >= _next_visibility_refresh_time_msec:
		_cached_target_visible = _compute_target_visibility(current_target)
		_schedule_next_visibility_refresh()
	return _cached_target_visible


func _compute_target_visibility(target: Node3D, space_state: PhysicsDirectSpaceState3D = null) -> bool:
	if target == null or not is_instance_valid(target) or not _owner_enemy:
		return false
	if space_state == null:
		space_state = _owner_enemy.get_world_3d().direct_space_state

	var params = PhysicsRayQueryParameters3D.new()
	params.from = _get_line_of_sight_origin()
	params.to = _get_aim_point(target)
	params.exclude = [_owner_enemy]
	params.collision_mask = _owner_enemy.collision_mask

	var result = space_state.intersect_ray(params)
	if not result:
		return false

	if result.collider == target:
		return true

	return result.collider != null and result.collider.is_in_group("player")


func _schedule_next_visibility_refresh(force_immediate: bool = false) -> void:
	if force_immediate:
		_next_visibility_refresh_time_msec = Time.get_ticks_msec()
		return
	var wait_time := maxf(0.01, visibility_check_interval + randf_range(-visibility_check_jitter, visibility_check_jitter))
	_next_visibility_refresh_time_msec = Time.get_ticks_msec() + int(round(wait_time * 1000.0))


func _reset_visibility_cache() -> void:
	_cached_target_visible = false
	_schedule_next_visibility_refresh(true)
