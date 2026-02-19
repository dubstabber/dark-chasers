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

var pending_transit: Marker3D = null


func _ready():
	_validate_node_references()


func _validate_node_references() -> void:
	"""Validate that required node references are set and log warnings for missing ones"""
	if not interaction_raycast:
		push_warning("InteractionComponent: 'interaction_raycast' is not set. Interactions will be disabled.")
	if not player:
		push_warning("InteractionComponent: 'player' is not set. Transit teleportation will be disabled.")
	if not interact_sound:
		push_warning("InteractionComponent: 'interact_sound' is not set. Interaction sounds will be disabled.")


func try_interact() -> bool:
	if not interaction_raycast:
		return false
	
	var collider = interaction_raycast.get_collider()
	if collider:
		interacted.emit(collider)

		# Handle door interaction using Openable interface
		var root_node = collider.get_parent()
		if root_node is Openable:
			root_node.open_with_point(interaction_raycast.get_collision_point(), player)
			door_opened.emit(root_node)
			return true

		# Handle button interaction - buttons are in "button" group and have press() method
		# Note: Button is a known scene type, so we can call press() directly
		if collider.is_in_group("button"):
			collider.press(player)
			button_pressed.emit(collider)
			return true

		# If we hit a non-interactable collider (wall/prop/etc), still allow transit usage.
		if pending_transit:
			_use_transit()
			return true
		return false

	# No collider hit: check for pending transit
	if pending_transit:
		_use_transit()
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
