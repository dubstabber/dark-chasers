class_name Armorable
extends RefCounted

## Interface for entities that can receive armor/shields.
## Classes implementing this should have an add_armor() method.
##
## Usage: Use Armorable.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node can receive armor"""
	return node != null and node.has_method("add_armor")


static func add_armor(node: Node, amount: int) -> bool:
	"""Add armor to a node. Returns true if armor was added."""
	if not check(node):
		return false
	return node.add_armor(amount)
