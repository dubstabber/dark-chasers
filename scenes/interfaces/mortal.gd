class_name Mortal
extends RefCounted

## Interface for entities that can die.
## Classes implementing this should have is_dead() and is_alive() methods.
##
## Usage: Use Mortal.check(node) to verify a node implements this interface.

static func check(node: Node) -> bool:
	"""Check if a node implements the Mortal interface"""
	return node != null and node.has_method("is_dead") and node.has_method("is_alive")


static func is_dead(node: Node) -> bool:
	"""Safely check if a node is dead, returns true if node is invalid or dead"""
	if not check(node):
		return true
	return node.is_dead()


static func is_alive(node: Node) -> bool:
	"""Safely check if a node is alive, returns false if node is invalid or dead"""
	if not check(node):
		return false
	return node.is_alive()


static func can_kill(node: Node) -> bool:
	"""Check if a node can be killed (has kill method)"""
	return node != null and node.has_method("kill")


static func kill(node: Node, killed_pos: Vector3 = Vector3.ZERO, message: String = "") -> bool:
	"""
	Kill a node if it supports the kill method.
	Returns true if the kill was executed, false if not supported.
	"""
	if not can_kill(node):
		return false
	node.kill(killed_pos, message)
	return true
