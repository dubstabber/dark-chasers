class_name DirectionalDamageable
extends RefCounted

## Interface for entities that can take directional damage.
## Extends the Damageable concept with position and direction information.
##
## This interface provides a priority-based damage application:
## 1. take_damage_with_direction(amount, position, direction) - full directional info
## 2. take_damage_at_position(amount, position) - positional damage
## 3. take_damage(amount) - basic damage
##
## Usage: Use DirectionalDamageable.deal_damage() for weapon hits.

enum DamageCapability {
	NONE,
	BASIC,           # take_damage(amount)
	POSITIONAL,      # take_damage_at_position(amount, position)
	DIRECTIONAL      # take_damage_with_direction(amount, position, direction)
}


static func get_capability(node: Node) -> DamageCapability:
	"""Check what level of damage the node can receive"""
	if node == null:
		return DamageCapability.NONE
	
	if node.has_method("take_damage_with_direction"):
		return DamageCapability.DIRECTIONAL
	elif node.has_method("take_damage_at_position"):
		return DamageCapability.POSITIONAL
	elif Damageable.check(node):
		return DamageCapability.BASIC
	return DamageCapability.NONE


static func check(node: Node) -> bool:
	"""Check if a node can take any form of damage"""
	return get_capability(node) != DamageCapability.NONE


static func deal_damage(node: Node, amount: int, hit_position: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> bool:
	"""
	Deal damage to a node using the best available method.
	Returns true if damage was applied.
	"""
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
			return Damageable.deal_damage(node, amount)
		_:
			return false

