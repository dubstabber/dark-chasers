class_name DirectionalDamageable
extends RefCounted

## DEPRECATED: Use Damageable instead. This class is kept for backwards compatibility.
## All functionality has been merged into Damageable.

static func check(node: Node) -> bool:
	return Damageable.check(node)


static func deal_damage(node: Node, amount: int, hit_position: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> bool:
	return Damageable.deal_damage(node, amount, hit_position, direction)
