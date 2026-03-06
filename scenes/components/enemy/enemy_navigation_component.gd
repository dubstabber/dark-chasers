@abstract
class_name EnemyNavigationComponent
extends Node

## Signals emitted by concrete subclasses (e.g., GodotNavigationComponent)
signal target_reached()
signal link_reached(details: Dictionary)
signal waypoint_reached(details: Dictionary)

@export var enabled: bool = true

var target_position: Vector3 = Vector3.ZERO

var _owner_enemy: CharacterBody3D = null
var _navigation_active: bool = true


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D
	_navigation_active = enabled


@abstract
func get_navigation_mode_id() -> StringName


func set_target(pos: Vector3) -> void:
	target_position = pos
	_on_target_set(pos)


func set_navigation_active(active: bool) -> void:
	_navigation_active = active
	enabled = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	_on_navigation_active_changed(active)


func is_navigation_active() -> bool:
	return _navigation_active


func _on_navigation_active_changed(_active: bool) -> void:
	pass


@abstract
func _on_target_set(_pos: Vector3) -> void


@abstract
func get_next_path_position() -> Vector3


func get_next_movement_direction() -> Vector3:
	if not _owner_enemy:
		return Vector3.ZERO
	var next_pos = get_next_path_position()
	return (next_pos - _owner_enemy.global_position).normalized()


func get_horizontal_direction() -> Vector3:
	if not _owner_enemy:
		return Vector3.ZERO
	var next_pos = get_next_path_position()
	return Vector3(
		next_pos.x - _owner_enemy.global_position.x,
		0,
		next_pos.z - _owner_enemy.global_position.z
	).normalized()


@abstract
func is_target_reached() -> bool


@abstract
func distance_to_target() -> float


func is_navigation_finished() -> bool:
	return is_target_reached()


func handle_link_reached(_details: Dictionary, _motor_component: EnemyMotorComponent, _gravity: float, _jump_velocity: float) -> void:
	pass


func handle_waypoint_reached(_details: Dictionary, _motor_component: EnemyMotorComponent) -> void:
	pass
