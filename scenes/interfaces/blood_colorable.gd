class_name BloodColorable
extends RefCounted

## Interface for nodes that can have their blood color set.
## Used by BloodEffectComponent for particles and decals.
##
## Implementers: Blood particle scenes, blood decal scenes
## Usage: Use BloodColorable.set_color() to apply blood color.

static func check(node: Node) -> bool:
	"""Check if a node can have its blood color set"""
	if node == null:
		return false
	return node.has_method("set_blood_color")


static func set_color(node: Node, color: Color) -> bool:
	"""
	Set the blood color on a node.
	Returns true if the color was set via the interface method.
	Returns false if the node doesn't support the interface (caller should use fallback).
	"""
	if node == null or not check(node):
		return false
	node.set_blood_color(color)
	return true

