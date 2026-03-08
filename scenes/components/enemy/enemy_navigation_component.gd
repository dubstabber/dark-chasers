@abstract
class_name EnemyNavigationComponent
extends Node

const VERTICAL_DIRECTION_FALLBACK_MIN_DELTA := 0.35

## Signals emitted by concrete subclasses (e.g., GodotNavigationComponent)
@warning_ignore("unused_signal") signal target_reached()
@warning_ignore("unused_signal") signal link_reached(details: Dictionary)
@warning_ignore("unused_signal") signal waypoint_reached(details: Dictionary)

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
	var next_pos := get_next_path_position()
	var horizontal_delta := _get_horizontal_delta_to(next_pos)
	if horizontal_delta != Vector3.ZERO:
		return horizontal_delta.normalized()
	if not is_vertical_horizontal_direction_fallback_active():
		return Vector3.ZERO
	return _get_horizontal_delta_to(target_position).normalized()


func is_vertical_horizontal_direction_fallback_active() -> bool:
	if not _owner_enemy or is_navigation_finished():
		return false
	if _get_horizontal_delta_to(get_next_path_position()) != Vector3.ZERO:
		return false
	var target_delta := _get_horizontal_delta_to(target_position)
	if target_delta == Vector3.ZERO:
		return false
	return (
		_has_meaningful_vertical_delta(get_next_path_position())
		or _has_meaningful_vertical_delta(target_position)
	)


func _get_horizontal_delta_to(position: Vector3) -> Vector3:
	if not _owner_enemy:
		return Vector3.ZERO
	return Vector3(
		position.x - _owner_enemy.global_position.x,
		0.0,
		position.z - _owner_enemy.global_position.z
	)


func _has_meaningful_vertical_delta(position: Vector3) -> bool:
	if not _owner_enemy:
		return false
	return absf(position.y - _owner_enemy.global_position.y) > VERTICAL_DIRECTION_FALLBACK_MIN_DELTA


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


func handle_owner_teleported() -> void:
	pass
