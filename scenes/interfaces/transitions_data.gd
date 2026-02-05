class_name TransitionsData
extends RefCounted

## Interface for typed access to map transition data.
## Replaces duck-typing ("map_transitions" in node, "enemy_exceptions" in node).
##
## Implementations should provide:
##   - get_map_transitions() -> Dictionary
##   - get_enemy_exceptions() -> Array

static func check(node: Node) -> bool:
	"""Check if a node implements the TransitionsData interface."""
	return node != null and node.has_method("get_map_transitions") and node.has_method("get_enemy_exceptions")


static func get_map_transitions(node: Node) -> Dictionary:
	"""Get the map transitions dictionary from a TransitionsData-implementing node."""
	if check(node):
		return node.get_map_transitions()
	# Fallback: direct property access for legacy nodes
	if node and "map_transitions" in node:
		return node.map_transitions
	return {}


static func get_enemy_exceptions(node: Node) -> Array:
	"""Get the enemy exceptions array from a TransitionsData-implementing node."""
	if check(node):
		return node.get_enemy_exceptions()
	# Fallback: direct property access for legacy nodes
	if node and "enemy_exceptions" in node:
		return node.enemy_exceptions
	return []
