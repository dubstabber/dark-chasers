class_name ArmorProcessor
extends RefCounted

## Interface for components that can process damage through armor.
## Used by HealthComponent to reduce incoming damage.
##
## Implementers: ArmorComponent
## Usage: Use ArmorProcessor.process_damage() to apply armor reduction.

static func check(node: Node) -> bool:
	"""Check if a node can process damage through armor"""
	if node == null:
		return false
	return node.has_method("process_damage")


static func process_damage(node: Node, amount: int) -> int:
	"""
	Process damage through armor, returning the remaining damage after reduction.
	If the node doesn't support armor processing, returns the original amount.
	"""
	if node == null or not check(node):
		return amount
	return node.process_damage(amount)

