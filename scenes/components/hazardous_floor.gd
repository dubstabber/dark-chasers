class_name HazardousFloor
extends Node3D

## Attach this script to any floor node (MeshInstance3D, StaticBody3D, etc.)
## to make it deal damage to entities standing on it.
##
## Uses Area3D-based detection instead of group scans for better performance.
## Entities entering the detection area are tracked and damaged on interval.

@export_group("Damage Settings")
@export var damage_per_tick: int = 10
@export var damage_interval: float = 1.0
var _damage_on_contact: bool = true
@export var damage_on_contact: bool = true: set = set_damage_on_contact ## Deal damage immediately when stepping on

@export_group("Target Settings")
@export var damage_players: bool = true
@export var damage_enemies: bool = false

@export_group("Detection Area")
@export var detection_height_offset: float = 0.1 ## How far above the floor to place detection area
@export var detection_height: float = 1.0 ## Height of the detection area above the floor

var _timer: Timer
var _detection_area: Area3D
var _entities_on_floor: Dictionary = {} # entity -> first_contact_handled


func _ready():
	_detection_area = _create_detection_area()
	
	if _detection_area:
		_detection_area.body_entered.connect(_on_body_entered)
		_detection_area.body_exited.connect(_on_body_exited)
	else:
		push_warning("HazardousFloor: Could not create detection area - no CollisionShape3D found in parent hierarchy")
	
	_timer = Timer.new()
	_timer.wait_time = damage_interval
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_timer.start()


func _create_detection_area() -> Area3D:
	var source_shape := _find_collision_shape()
	if not source_shape or not source_shape.shape:
		return null
	
	var area := Area3D.new()
	area.name = "HazardDetectionArea"
	area.collision_layer = 0
	area.collision_mask = 1 | 2 # Detect players (layer 1) and entities (layer 2)
	
	var shape_copy := CollisionShape3D.new()
	shape_copy.shape = source_shape.shape.duplicate()
	
	# Offset upward to detect entities standing on the floor
	shape_copy.position = Vector3(0, detection_height_offset + detection_height * 0.5, 0)
	
	# If the shape is a box, extend its height to cover the detection range
	if shape_copy.shape is BoxShape3D:
		var box: BoxShape3D = shape_copy.shape
		box.size.y = detection_height
	
	area.add_child(shape_copy)
	add_child(area)
	
	return area


func _find_collision_shape() -> CollisionShape3D:
	# First check siblings (common case: HazardousFloor is child of StaticBody3D)
	var parent := get_parent()
	if parent:
		for sibling in parent.get_children():
			if sibling is CollisionShape3D:
				return sibling
	
	# Check children
	for child in get_children():
		if child is CollisionShape3D:
			return child
	
	# Check parent if it's the collision shape holder
	if parent is CollisionShape3D:
		return parent
	
	return null


func _on_body_entered(body: Node3D) -> void:
	if not _should_damage_entity(body):
		return
	
	if body not in _entities_on_floor:
		_entities_on_floor[body] = false
		if _damage_on_contact:
			_deal_damage(body)
			_entities_on_floor[body] = true


func _on_body_exited(body: Node3D) -> void:
	_entities_on_floor.erase(body)


func _on_timer_timeout():
	_damage_tracked_entities()


func set_damage_on_contact(value: bool) -> void:
	_damage_on_contact = value


func _should_damage_entity(entity: Node) -> bool:
	if not is_instance_valid(entity):
		return false
	if damage_players and entity is Player:
		return true
	if damage_enemies and entity is Enemy:
		return true
	return false


func _damage_tracked_entities() -> void:
	var entities_to_remove: Array[Node] = []
	
	for entity in _entities_on_floor.keys():
		if not is_instance_valid(entity):
			entities_to_remove.append(entity)
			continue
		
		if entity is CharacterBody3D and not entity.is_on_floor():
			continue
		
		_deal_damage(entity)
	
	for entity in entities_to_remove:
		_entities_on_floor.erase(entity)


func _deal_damage(entity: Node) -> void:
	var was_dead := Damageable.is_dead(entity)
	
	if Damageable.deal_damage(entity, damage_per_tick):
		if entity is Player and not was_dead and Damageable.is_dead(entity):
			_log_player_mutated(entity)


func _log_player_mutated(_player: Node) -> void:
	# HUD is a known scene with add_log method
	var hud = Services.world_context.get_hud()
	if hud:
		hud.add_log("Player mutated.")
