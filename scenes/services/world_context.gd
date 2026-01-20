extends Node

## Provides centralized access to world/level references for non-enemy systems.
## This decouples game systems from direct group lookups and scene topology.
##
## Usage:
##   - Add as autoload named "WorldContext" in Project Settings
##   - Or inject manually via set_level_node()

signal level_changed(level_node: Node3D)

var _level_node: Node3D = null
var _use_group_fallback: bool = true


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
	if not is_instance_valid(_level_node) and _use_group_fallback:
		_try_find_from_groups()
	return _level_node


func get_keys_collected() -> Array:
	var level = get_level_node()
	if level and "keys_collected" in level:
		return level.keys_collected
	return []


func has_key(key_type: String) -> bool:
	return key_type in get_keys_collected()


func set_level_node(node: Node3D) -> void:
	_level_node = node
	level_changed.emit(node)


func set_use_group_fallback(enabled: bool) -> void:
	_use_group_fallback = enabled
