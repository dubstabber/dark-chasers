class_name EnemyAIComponent
extends Node

signal target_acquired(target: Node3D)
signal target_lost()
signal target_died()

@export var detection_enabled: bool = true
@export var chase_player: bool = true
@export var check_line_of_sight: bool = true

var current_target: CharacterBody3D = null
var players_node: Node3D = null

var _owner_enemy: CharacterBody3D = null
var _enemy_context: Node = null


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D
	_find_players_node()


func _find_players_node() -> void:
	if not _enemy_context:
		_enemy_context = get_node_or_null("/root/EnemyContext")
	
	if _enemy_context and _enemy_context.has_method("get_players_node"):
		players_node = _enemy_context.get_players_node()
	else:
		players_node = get_tree().get_first_node_in_group("players")


func check_targets() -> void:
	if current_target and current_target.has_method("is_dead") and current_target.is_dead():
		current_target = null
		target_died.emit()
	
	if not detection_enabled or not chase_player or not players_node:
		return
	
	if not _owner_enemy:
		return
	
	if not is_instance_valid(players_node):
		_find_players_node()
		if not players_node:
			return
	
	var space_state = _owner_enemy.get_world_3d().direct_space_state
	
	for target in players_node.get_children():
		if not target.has_method("is_dead") or target.is_dead():
			continue
		
		if not _has_aim_point(target):
			continue
		
		if check_line_of_sight:
			var params = PhysicsRayQueryParameters3D.new()
			params.from = _owner_enemy.global_position
			params.to = _get_aim_point(target)
			params.exclude = [_owner_enemy]
			params.collision_mask = _owner_enemy.collision_mask
			
			var result = space_state.intersect_ray(params)
			if result and result.collider.is_in_group("player"):
				_set_target(result.collider)
				return
		else:
			_set_target(target)
			return


func _has_aim_point(target: Node3D) -> bool:
	return target.has_method("get_aim_point") or ("camera_3d" in target and target.camera_3d != null)


func _get_aim_point(target: Node3D) -> Vector3:
	if target.has_method("get_aim_point"):
		return target.get_aim_point()
	elif "camera_3d" in target and target.camera_3d != null:
		return target.camera_3d.global_position
	return target.global_position + Vector3(0, 1.6, 0)


func _set_target(new_target: CharacterBody3D) -> void:
	var should_signal = current_target == null or current_target != new_target
	current_target = new_target
	if should_signal:
		target_acquired.emit(current_target)


func clear_target() -> void:
	if current_target != null:
		current_target = null
		target_lost.emit()


func check_target_alive() -> bool:
	if current_target and current_target.has_method("is_dead") and current_target.is_dead():
		current_target = null
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
