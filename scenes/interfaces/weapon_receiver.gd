class_name WeaponReceiver
extends RefCounted

## Interface for entities that can receive weapons.
## Classes implementing this should have a weapon_added signal.
##
## Usage: Use WeaponReceiver.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node can receive weapons"""
	if node == null:
		return false
	return node.has_signal("weapon_added")


static func add_weapon(node: Node, weapon: WeaponResource) -> bool:
	"""Add a weapon to a node by emitting its weapon_added signal.
	Returns true if the signal was emitted successfully."""
	if not check(node):
		return false
	node.weapon_added.emit(weapon)
	return true
