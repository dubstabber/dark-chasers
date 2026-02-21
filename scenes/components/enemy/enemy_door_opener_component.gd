class_name EnemyDoorOpenerComponent
extends Node

const DoorScript = preload("res://scenes/objects/door.gd")

## Handles door interaction for enemies.
## Extracts the door detection and opening logic from enemy.gd.

signal door_opened(door: Node)
signal door_blocked()

@export var enabled: bool = true

var _owner_enemy: CharacterBody3D = null
var _interaction_ray: RayCast3D = null


func _ready() -> void:
	_owner_enemy = owner as CharacterBody3D
	if _owner_enemy:
		_interaction_ray = _owner_enemy.get_node_or_null("Interaction")


func set_interaction_ray(ray: RayCast3D) -> void:
	_interaction_ray = ray


func check_and_open_door() -> bool:
	if not enabled or not _interaction_ray:
		return false
	
	var collider = _interaction_ray.get_collider()
	if not collider:
		return false
	
	var root_node = collider.get_parent()
	if root_node is DoorScript:
		root_node.open_with_point(_interaction_ray.get_collision_point())
		door_opened.emit(root_node)
		return true
	
	door_blocked.emit()
	return false


func is_facing_door() -> bool:
	if not _interaction_ray:
		return false
	
	var collider = _interaction_ray.get_collider()
	if not collider:
		return false
	
	var root_node = collider.get_parent()
	return root_node is DoorScript
