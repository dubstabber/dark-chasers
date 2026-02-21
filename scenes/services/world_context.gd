class_name WorldContext
extends Node

## Provides centralized access to world/level references for non-enemy systems.
## This decouples game systems from direct group lookups and scene topology.
##
## Usage:
##   - Access via Services.world_context (owned/created by Services singleton)
##   - Or inject manually via set_level_node()
##
## Group fallbacks are gated behind _use_group_fallback (dev-only; disabled by default).
## Production scenes should use explicit registration via Level._ready().

signal level_changed(level_node: Node3D)

var _level_node: Node3D = null
## Group fallback is disabled by default. Enable only for debugging legacy scenes.
var _use_group_fallback: bool = false


func _ready() -> void:
	if _use_group_fallback:
		_try_find_from_groups()


func _try_find_from_groups() -> void:
	if not _level_node:
		# Try "level" first (set programmatically by Level class), then "map" (set in tscn)
		_level_node = get_tree().get_first_node_in_group("level")
		if not _level_node:
			_level_node = get_tree().get_first_node_in_group("map")


func get_level_node() -> Node3D:
	if not is_instance_valid(_level_node):
		_level_node = null
		if _use_group_fallback:
			_try_find_from_groups()
			if _level_node:
				push_warning("WorldContext: Auto-discovered level via group fallback. Use Level._ready() for explicit wiring.")
	return _level_node


func get_keys_collected() -> Array:
	var level = get_level_node()
	# Level is a known class with keys_collected property
	if level and level is Level:
		return level.keys_collected
	return []


func has_key(key_type: String) -> bool:
	return key_type in get_keys_collected()


func set_level_node(node: Node3D) -> void:
	_level_node = node
	level_changed.emit(node)


func set_use_group_fallback(enabled: bool) -> void:
	_use_group_fallback = enabled


func get_hud() -> CanvasLayer:
	"""Get the HUD from the current level.
	
	Returns:
		CanvasLayer: The HUD node, or null if not available.
	"""
	var level = get_level_node()
	if level and level is Level:
		return level.hud
	return null


func get_enemies_node() -> Node3D:
	"""Get the enemies container from the current level.
	
	Returns:
		Node3D: The enemies container node, or null if not available.
	"""
	var level = get_level_node()
	if level and level is Level:
		return level.enemies
	return null


func get_corpses_node() -> Node3D:
	"""Get the corpses container from the current level.
	
	Returns:
		Node3D: The corpses container node, or null if not available.
	"""
	var level = get_level_node()
	if level and level is Level:
		return level.corpses
	return null
