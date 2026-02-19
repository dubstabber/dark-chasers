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


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D


func set_target(pos: Vector3) -> void:
	target_position = pos
	_on_target_set(pos)


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
