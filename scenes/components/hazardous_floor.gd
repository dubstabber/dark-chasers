class_name HazardousFloor
extends Node3D

## Attach this script to any floor node (MeshInstance3D, StaticBody3D, etc.)
## to make it deal damage to entities standing on it.

@export_group("Damage Settings")
@export var damage_per_tick: int = 10
@export var damage_interval: float = 1.0
var _damage_on_contact: bool = true
@export var damage_on_contact: bool = true: set = set_damage_on_contact ## Deal damage immediately when stepping on

@export_group("Target Settings")
@export var damage_players: bool = true
@export var damage_enemies: bool = false

@export_group("Collision Settings")
@export var collision_root: NodePath ## Optional: set to the StaticBody3D/Collision root if different from this node

var _timer: Timer
var _floor_node: Node3D
var _entities_on_floor: Array[Node] = []
var _hazard_id: int


func _ready():
	if collision_root != NodePath(""):
		var n = get_node_or_null(collision_root)
		if n and n is Node3D:
			_floor_node = n
		else:
			push_warning("HazardousFloor: collision_root is invalid; falling back to self")
			_floor_node = self
	else:
		_floor_node = self

	_hazard_id = get_instance_id()
	_mark_hazard_subtree(_floor_node)
	set_physics_process(_damage_on_contact)
	_timer = Timer.new()
	_timer.wait_time = damage_interval
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_timer.start()


func _on_timer_timeout():
	_check_entities_on_floor(false)


func _physics_process(_delta: float) -> void:
	if _damage_on_contact:
		_check_entities_on_floor(true)


func _mark_hazard_subtree(root: Node) -> void:
	if not root:
		return
	root.set_meta("hazard_floor_id", _hazard_id)
	for child in root.get_children():
		if child is Node:
			_mark_hazard_subtree(child)


func set_damage_on_contact(value: bool) -> void:
	_damage_on_contact = value
	set_physics_process(value)


func _check_entities_on_floor(immediate_only: bool):
	var world = _floor_node.get_world_3d()
	if not world:
		return
	
	var space_state = world.direct_space_state
	var entities_to_check: Array[Node] = []
	
	if damage_players:
		var players = get_tree().get_nodes_in_group("player")
		entities_to_check.append_array(players)
	
	if damage_enemies:
		var enemies = get_tree().get_nodes_in_group("entity")
		entities_to_check.append_array(enemies)
	
	var entities_currently_on: Array[Node] = []
	
	for entity in entities_to_check:
		if not is_instance_valid(entity):
			continue
		if not entity is Node3D:
			continue
		
		if entity is CharacterBody3D and (not immediate_only) and not entity.is_on_floor():
			continue
		
		var ray_origin = entity.global_position + Vector3(0, 0.2, 0)
		var ray_end = entity.global_position + Vector3(0, -1.0, 0)
		
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		if entity is CollisionObject3D:
			query.exclude = [entity.get_rid()]
		
		var result = space_state.intersect_ray(query)
		if result and result.collider:
			if _is_this_floor(result.collider):
				entities_currently_on.append(entity)
				
				var is_new_contact = entity not in _entities_on_floor
				
				if is_new_contact:
					if _damage_on_contact and immediate_only:
						_deal_damage(entity)
				else:
					if not immediate_only:
						_deal_damage(entity)
	
	_entities_on_floor = entities_currently_on


func _is_this_floor(collider: Node) -> bool:
	var node: Node = collider
	while node:
		if node.has_meta("hazard_floor_id") and int(node.get_meta("hazard_floor_id")) == _hazard_id:
			return true
		node = node.get_parent()
	return false


func _deal_damage(entity: Node):
	var health_component = entity.get_node_or_null("HealthComponent")
	var was_dead := false
	if health_component:
		was_dead = bool(health_component.is_dead)
	if health_component and health_component.has_method("take_damage"):
		health_component.take_damage(damage_per_tick)
		if entity.is_in_group("player") and not was_dead and health_component.is_dead:
			_log_player_mutated(entity)
		return
	if entity.has_method("take_damage"):
		entity.take_damage(damage_per_tick)


func _log_player_mutated(_player: Node) -> void:
	var levels = get_tree().get_nodes_in_group("level")
	if levels.size() == 0:
		return
	var level = levels[0]
	if level and "hud" in level and level.hud and level.hud.has_method("add_log"):
		level.hud.add_log("Player mutated.")
