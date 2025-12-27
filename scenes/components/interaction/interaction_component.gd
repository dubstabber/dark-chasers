class_name InteractionComponent
extends Node

## Handles player interaction with doors, buttons, and transit points

signal interacted(collider: Node)
signal door_opened(door: Node)
signal button_pressed(button: Node)
signal transit_used(transit_pos: Marker3D)

@export_group("Node References")
@export var interaction_raycast: RayCast3D
@export var player: CharacterBody3D
@export var interact_sound: AudioStreamPlayer3D
@export var auto_discover: bool = true

var pending_transit: Marker3D = null


func _ready():
	if auto_discover:
		_auto_discover_dependencies()


func _auto_discover_dependencies() -> void:
	"""Auto-discover player from parent if not set"""
	var parent = get_parent()
	if not parent:
		return
	
	# Auto-discover player (parent if it's a CharacterBody3D)
	if not player and parent is CharacterBody3D:
		player = parent
	
	# Auto-discover interaction raycast
	if not interaction_raycast and player:
		interaction_raycast = player.get_node_or_null("nek/head/eyes/Camera3D/Interaction")
	
	# Auto-discover interact sound
	if not interact_sound and player:
		interact_sound = player.get_node_or_null("InteractSound")


func try_interact() -> bool:
	if not interaction_raycast:
		return false
	
	var collider = interaction_raycast.get_collider()
	if not collider:
		# Check for pending transit
		if pending_transit:
			_use_transit()
			return true
		return false
	
	interacted.emit(collider)
	
	# Handle door interaction
	var root_node = collider.get_parent()
	if root_node.has_method("open_with_point") and (root_node is Openable or root_node.is_in_group("door")):
		root_node.open_with_point(interaction_raycast.get_collision_point(), player)
		door_opened.emit(root_node)
		return true
	
	# Handle button interaction
	if collider.is_in_group("button") and collider.has_method("press"):
		collider.press(player)
		button_pressed.emit(collider)
		return true
	
	return false


func _use_transit() -> void:
	if pending_transit and player:
		player.position = pending_transit.global_position
		transit_used.emit(pending_transit)
		pending_transit = null


func set_transit_point(transit: Marker3D) -> void:
	pending_transit = transit


func clear_transit_point() -> void:
	pending_transit = null


func has_pending_transit() -> bool:
	return pending_transit != null


func get_current_target() -> Node:
	if interaction_raycast:
		return interaction_raycast.get_collider()
	return null
