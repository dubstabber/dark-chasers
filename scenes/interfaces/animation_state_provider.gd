class_name AnimationStateProvider
extends RefCounted

enum StatePriority {
	IDLE = 0,
	MOVING = 1,
	SHOOTING = 2
}


static func check(node: Node) -> bool:
	if node == null:
		return false
	return "moving_state" in node or "shooting_state" in node


static func get_moving_state(node: Node) -> String:
	if node == null or not "moving_state" in node:
		return ""
	return node.moving_state


static func get_shooting_state(node: Node) -> String:
	if node == null or not "shooting_state" in node:
		return ""
	return node.shooting_state


static func get_state_priority(node: Node) -> int:
	if node == null:
		return StatePriority.IDLE
	
	if "shooting_state" in node and _is_active_shooting_state(str(node.shooting_state)):
		return StatePriority.SHOOTING
	
	if "moving_state" in node:
		var state := str(node.moving_state).to_lower()
		if state in ["walk", "run", "walking", "running", "moving", "move"]:
			return StatePriority.MOVING
	
	return StatePriority.IDLE


static func _is_active_shooting_state(state: String) -> bool:
	var normalized_state := state.to_lower()
	return normalized_state != "" and normalized_state not in ["idle", "none"]
