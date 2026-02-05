class_name GroundTypeReceiver
extends RefCounted

## Interface for entities that can receive ground type information.
## Used by footstep areas to set the ground material for footstep sounds.
##
## Implementers: Player, Enemy (ground_type property)
## Usage: Use GroundTypeReceiver.set_ground_type() in footstep areas.

static func check(node: Node) -> bool:
	"""Check if a node can receive ground type"""
	if node == null:
		return false
	return "ground_type" in node


static func get_ground_type(node: Node) -> String:
	"""Get the current ground type. Returns empty string if not available."""
	if node == null or not check(node):
		return ""
	return node.ground_type


static func set_ground_type(node: Node, ground_type: String) -> bool:
	"""Set the ground type on a node. Returns true if successful."""
	if node == null or not check(node):
		return false
	node.ground_type = ground_type
	return true

