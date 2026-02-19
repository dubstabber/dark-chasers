class_name Damageable
extends RefCounted

## Unified interface for entities that can take damage.
## Supports three levels of damage capability:
## 1. DIRECTIONAL — take_damage_with_direction(amount, position, direction)
## 2. POSITIONAL  — take_damage_at_position(amount, position)
## 3. BASIC       — take_damage(amount) via HealthComponent or direct method
##
## Usage:
##   Damageable.check(node)  — can this node receive any damage?
##   Damageable.deal_damage(node, amount, hit_pos, direction) — apply best-fit damage

enum DamageCapability {
	NONE,
	BASIC, # take_damage(amount)
	POSITIONAL, # take_damage_at_position(amount, position)
	DIRECTIONAL # take_damage_with_direction(amount, position, direction)
}


static func get_capability(node: Node) -> DamageCapability:
	"""Check what level of damage the node can receive"""
	if node == null:
		return DamageCapability.NONE
	if node.has_method("take_damage_with_direction"):
		return DamageCapability.DIRECTIONAL
	elif node.has_method("take_damage_at_position"):
		return DamageCapability.POSITIONAL
	elif _has_basic_damage(node):
		return DamageCapability.BASIC
	return DamageCapability.NONE


static func check(node: Node) -> bool:
	"""Check if a node can take any form of damage"""
	return get_capability(node) != DamageCapability.NONE


static func deal_damage(node: Node, amount: int, hit_position: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> bool:
	"""Deal damage using the best available method. Returns true if damage was applied."""
	if node == null:
		return false

	var capability = get_capability(node)
	match capability:
		DamageCapability.DIRECTIONAL:
			node.take_damage_with_direction(amount, hit_position, direction)
			return true
		DamageCapability.POSITIONAL:
			node.take_damage_at_position(amount, hit_position)
			return true
		DamageCapability.BASIC:
			return _apply_basic_damage(node, amount)
		_:
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


static func _has_basic_damage(node: Node) -> bool:
	var health_comp = node.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		return true
	return node.has_method("take_damage")


static func _apply_basic_damage(node: Node, amount: int) -> bool:
	var health_comp = node.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_method("take_damage"):
		health_comp.take_damage(amount)
		return true
	if node.has_method("take_damage"):
		node.take_damage(amount)
		return true
	return false
