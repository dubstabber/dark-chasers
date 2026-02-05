class_name RoomAware
extends RefCounted

## Interface for entities that have room awareness (current_room property).
## Used for room-based transitions and enemy pathfinding.
##
## Implementers: Player, Enemy
## Usage: Use RoomAware.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node has room awareness"""
	if node == null:
		return false
	# Check for current_room property
	return "current_room" in node


static func get_current_room(node: Node) -> String:
	"""Get the current room of a node. Returns empty string if not room-aware."""
	if node == null or not check(node):
		return ""
	return node.current_room


static func set_current_room(node: Node, room: String) -> bool:
	"""Set the current room of a node. Returns true if successful."""
	if node == null or not check(node):
		return false
	node.current_room = room
	return true

