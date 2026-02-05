class_name PathfindingEntity
extends RefCounted

## Interface for entities that use pathfinding with a timer-based update system.
## Used for adjusting pathfinding responsiveness during transitions.
##
## Implementers: Enemy (find_path_timer)
## Usage: Use PathfindingEntity.make_responsive() after room transitions.

const RESPONSIVE_WAIT_TIME := 0.1
const DEFAULT_WAIT_TIME := 0.5


static func check(node: Node) -> bool:
	"""Check if a node has pathfinding timer"""
	if node == null:
		return false
	return "find_path_timer" in node and node.find_path_timer != null


static func get_timer(node: Node) -> Timer:
	"""Get the pathfinding timer. Returns null if not available."""
	if node == null or not check(node):
		return null
	return node.find_path_timer


static func make_responsive(node: Node) -> bool:
	"""
	Make the pathfinding more responsive (shorter timer interval).
	Used after room transitions to quickly update the path.
	Returns true if successful.
	"""
	var timer = get_timer(node)
	if timer == null:
		return false
	timer.wait_time = RESPONSIVE_WAIT_TIME
	timer.start()
	return true


static func reset_to_default(node: Node) -> bool:
	"""
	Reset the pathfinding timer to default interval.
	Returns true if successful.
	"""
	var timer = get_timer(node)
	if timer == null:
		return false
	timer.wait_time = DEFAULT_WAIT_TIME
	return true

