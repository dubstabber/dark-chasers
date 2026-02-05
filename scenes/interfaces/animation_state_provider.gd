class_name AnimationStateProvider
extends RefCounted

## Interface for entities that provide animation state information.
## Used by DirectionalSprite3D to determine which animation frame to display.
##
## Implementers: Enemy (moving_state, shooting_state)
## Usage: Use AnimationStateProvider.get_state_priority() for sprite animation.

enum StatePriority {
	IDLE = 0,
	MOVING = 1,
	SHOOTING = 2
}


static func check(node: Node) -> bool:
	"""Check if a node provides animation state"""
	if node == null:
		return false
	return "moving_state" in node or "shooting_state" in node


static func get_moving_state(node: Node) -> String:
	"""Get the moving state of a node. Returns empty string if not available."""
	if node == null or not "moving_state" in node:
		return ""
	return node.moving_state


static func get_shooting_state(node: Node) -> String:
	"""Get the shooting state of a node. Returns empty string if not available."""
	if node == null or not "shooting_state" in node:
		return ""
	return node.shooting_state


static func get_state_priority(node: Node) -> int:
	"""
	Get the animation state priority for a node.
	Returns: 0 = idle, 1 = moving, 2 = shooting
	"""
	if node == null:
		return StatePriority.IDLE
	
	# Check for shooting state first (highest priority)
	if "shooting_state" in node and node.shooting_state != "":
		return StatePriority.SHOOTING
	
	# Check for movement state
	if "moving_state" in node:
		var state = node.moving_state
		# Movement states that should return MOVING
		if state in ["walk", "run", "walking", "running", "moving"]:
			return StatePriority.MOVING
	
	return StatePriority.IDLE

