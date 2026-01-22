class_name Healable
extends RefCounted

## Interface for entities that can be healed.
## Classes implementing this should have a HealthComponent with heal() method,
## or implement heal() directly.
##
## Usage: Use Healable.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node can be healed"""
	if node == null:
		return false
	# Check for HealthComponent first
	var health_comp = node.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("heal"):
		return true
	# Fallback to direct heal method
	return node.has_method("heal")


static func heal(node: Node, amount: int) -> bool:
	"""Heal a node by the given amount. Returns true if healing was applied."""
	if node == null:
		return false
	# Try HealthComponent first
	var health_comp = node.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("heal"):
		return health_comp.heal(amount)
	# Fallback to direct heal method
	if node.has_method("heal"):
		return node.heal(amount)
	return false
