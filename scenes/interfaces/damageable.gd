class_name Damageable
extends RefCounted

## Interface for entities that can take damage.
## Classes implementing this should have a HealthComponent with take_damage() method,
## or implement take_damage() directly.
##
## Usage: Use Damageable.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node can take damage"""
	if node == null:
		return false
	# Check for HealthComponent first
	var health_comp = node.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		return true
	# Fallback to direct take_damage method
	return node.has_method("take_damage")


static func deal_damage(node: Node, amount: int) -> bool:
	"""Deal damage to a node. Returns true if damage was applied."""
	if node == null:
		return false
	# Try HealthComponent first
	var health_comp = node.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(amount)
		return true
	# Fallback to direct take_damage method
	if node.has_method("take_damage"):
		node.take_damage(amount)
		return true
	return false


static func is_dead(node: Node) -> bool:
	"""Check if a damageable node is dead"""
	if node == null:
		return true
	var health_comp = node.get_node_or_null("HealthComponent")
	if health_comp and "is_dead" in health_comp:
		return health_comp.is_dead
	if node.has_method("is_dead"):
		return node.is_dead()
	return false
