class_name EnemyContext
extends Node

const TransitionsDataScript = preload("res://scenes/interfaces/transitions_data.gd")

## Provides centralized access to world references for enemy systems.
## This decouples enemies from direct group lookups and scene topology.
##
## Usage:
##   - Add as autoload named "EnemyContext" in Project Settings
##   - Or inject manually via set_players_node() / set_transitions_node()
##
## Group fallbacks are gated behind _use_group_fallback (dev-only; disabled by default).
## Production scenes should use explicit registration via Level._ready().

signal players_changed(players_node: Node3D)
signal transitions_changed(transitions_node: Node3D)

var _players_node: Node3D = null
var _transitions_node: Node3D = null
## Group fallback is disabled by default. Enable only for debugging legacy scenes.
var _use_group_fallback: bool = false


func _ready() -> void:
	if _use_group_fallback:
		_try_find_from_groups()


func _try_find_from_groups() -> void:
	if not _players_node:
		_players_node = get_tree().get_first_node_in_group("players")
	if not _transitions_node:
		_transitions_node = get_tree().get_first_node_in_group("transitions")


func get_players_node() -> Node3D:
	if not is_instance_valid(_players_node) and _use_group_fallback:
		_players_node = get_tree().get_first_node_in_group("players")
		if _players_node:
			push_warning("EnemyContext: Auto-discovered players via group fallback. Use Level._ready() for explicit wiring.")
	return _players_node


func get_players() -> Array[Node3D]:
	var players_node = get_players_node()
	if players_node:
		var result: Array[Node3D] = []
		for child in players_node.get_children():
			if child is Node3D:
				result.append(child)
		return result
	return []


func get_transitions_node() -> Node3D:
	if not is_instance_valid(_transitions_node) and _use_group_fallback:
		_transitions_node = get_tree().get_first_node_in_group("transitions")
		if _transitions_node:
			push_warning("EnemyContext: Auto-discovered transitions via group fallback. Use Level._ready() for explicit wiring.")
	return _transitions_node


func get_transition_graph() -> Dictionary:
	var transitions = get_transitions_node()
	if not transitions:
		return {}
	# Use TransitionsData interface for typed access
	return TransitionsDataScript.get_map_transitions(transitions)


func get_enemy_exceptions() -> Array:
	var transitions = get_transitions_node()
	if not transitions:
		return []
	# Use TransitionsData interface for typed access
	return TransitionsDataScript.get_enemy_exceptions(transitions)


func set_players_node(node: Node3D) -> void:
	_players_node = node
	players_changed.emit(node)


func set_transitions_node(node: Node3D) -> void:
	_transitions_node = node
	transitions_changed.emit(node)


func set_use_group_fallback(enabled: bool) -> void:
	_use_group_fallback = enabled
