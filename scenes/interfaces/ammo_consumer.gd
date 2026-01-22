class_name AmmoConsumer
extends RefCounted

## Interface for entities that can receive ammo.
## Classes implementing this should have a PlayerAmmoComponent with add_ammo(),
## or implement add_ammo() directly.
##
## Usage: Use AmmoConsumer.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node can receive ammo"""
	if node == null:
		return false
	# Check for ammo_component property first
	var ammo_comp = node.get("ammo_component")
	if ammo_comp and ammo_comp.has_method("add_ammo"):
		return true
	# Fallback to direct add_ammo method
	return node.has_method("add_ammo")


static func add_ammo(node: Node, ammo_type: String, amount: int) -> bool:
	"""Add ammo to a node. Returns true if ammo was added."""
	if node == null:
		return false
	# Try ammo_component first
	var ammo_comp = node.get("ammo_component")
	if ammo_comp and ammo_comp.has_method("add_ammo"):
		return ammo_comp.add_ammo(ammo_type, amount)
	# Fallback to direct add_ammo method (universal ammo)
	if node.has_method("add_ammo"):
		return node.add_ammo(amount, true)
	return false


static func add_universal_ammo(node: Node, amount: int) -> bool:
	"""Add universal ammo to all weapon types. Returns true if ammo was added."""
	if node == null:
		return false
	if node.has_method("add_ammo"):
		return node.add_ammo(amount, true)
	return false
